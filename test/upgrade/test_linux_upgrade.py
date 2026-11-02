"""Replay issue #98 using shipped 1.2 scripts and mocked host operations.

Run: python3 -B -m unittest discover -s test/upgrade -v
The local git checkout must contain tag 1.2.0.0. No VM or credentials are used.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HANDLER = ROOT / "src/handler/linux"

# Only host/configuration boundaries are mocked. The old uninstall, its YAML
# parser, the new lifecycle commands and their retry/error handling stay real.
MOCKS = r'''
log() { printf '%s %s\n' "$1" "$2"; }
checkOS() { DISTRO_OS=DEB; }
get_kibana_host() { KIBANA_URL=https://example.invalid; }
get_password() { PASSWORD=fixture; }
get_base64Auth() { BASE64_AUTH=; }
get_username() { USERNAME=fixture; }
write_status() { printf 'status: %s\n' "$*" >> "$CALLS"; }
clean_and_exit() { exit "$1"; }
sleep() { :; }
systemctl() {
  case "$*" in
    '') printf '%s\n' '-.mount' ;;
    'list-units '*)
      if [ -f "$PACKAGE_FILE" ]; then
        printf '%s\n' 'elastic-agent.service loaded inactive dead'
      fi ;;
    *) return 99 ;;
  esac
}
sudo() {
  printf '%s\n' "$*" >> "$CALLS"
  case "$*" in
    'systemctl stop elastic-agent') printf stopped > "$SERVICE_FILE" ;;
    'systemctl start elastic-agent') printf running > "$SERVICE_FILE" ;;
    'systemctl is-active --quiet elastic-agent')
      [ "$(cat "$SERVICE_FILE")" = running ] ;;
    'dpkg -r elastic-agent')
      [ "${FAIL_CLEANUP:-0}" = 0 ] || return 7
      rm -f "$PACKAGE_FILE" ;;
    'dpkg -P elastic-agent'|'systemctl disable elastic-agent'|\
    'systemctl enable elastic-agent'|'systemctl daemon-reload'|\
    'systemctl reset-failed'|'rm -rf /usr/'*|'rm -rf /etc/'*|\
    'rm -rf /var/'*) : ;;
    *) printf 'Unexpected privileged command: %s\n' "$*" >&2; return 99 ;;
  esac
}
'''


class LinuxUpgradeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="elastic-upgrade-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.new = self.path / "current-handler"
        shutil.copytree(HANDLER, self.new)
        self.old = self.path / "Elastic.ElasticAgent.linux-1.2.0.0"
        self.old.mkdir()
        for name in ("uninstall.sh", "disable.sh", "helper.sh"):
            content = subprocess.check_output(
                ["git", "show", f"1.2.0.0:src/handler/linux/{name}"],
                cwd=ROOT, text=True,
            )
            if name == "helper.sh":
                # Isolate the missing file even on hosts with an agent installed.
                content = content.replace("function parse_yaml {",
                                          "function parse_yaml_fixture {")
                content += '\nparse_yaml() { parse_yaml_fixture "$TEST_LOGS/missing/fleet.yml"; }\n'
            (self.old / name).write_text(content)
        for directory in (self.old, self.new):
            with (directory / "helper.sh").open("a") as helper:
                helper.write('\nLOGS_FOLDER="$TEST_LOGS"\n' + MOCKS)
        self.env = dict(os.environ, TEST_LOGS=str(self.path),
                        CALLS=str(self.path / "calls"),
                        PACKAGE_FILE=str(self.path / "package"),
                        SERVICE_FILE=str(self.path / "service"))
        Path(self.env["PACKAGE_FILE"]).touch()
        Path(self.env["SERVICE_FILE"]).write_text("running")

    def run_bash(self, command, **env):
        return subprocess.run(["bash", "-c", command], text=True,
                              capture_output=True, env=dict(self.env, **env))

    def run_script(self, directory, name, **env):
        return self.run_bash(f'bash "{directory / name}"', **env)

    def install(self, code=None):
        # Exercise the install entry function, stubbing dependency installation
        # so the test cannot use the host package manager.
        env = {} if code is None else {"AZURE_GUEST_AGENT_UNINSTALL_CMD_EXIT_CODE": code}
        return self.run_bash(
            f'source "{self.new / "install.sh"}"\n'
            'install_dependencies() { echo dependencies >> "$CALLS"; }\n'
            'Install_Extension',
            **env,
        )

    def test_failed_legacy_uninstall_is_recovered_before_enable(self):
        disabled = self.run_script(self.old, "disable.sh")
        self.assertEqual(disabled.returncode, 0, disabled.stderr)
        updated = self.run_script(self.new, "update.sh",
                                  AZURE_GUEST_AGENT_DISABLE_CMD_EXIT_CODE="0")
        self.assertEqual(updated.returncode, 0, updated.stderr)
        uninstalled = self.run_script(self.old, "uninstall.sh")
        self.assertEqual(uninstalled.returncode, 1)
        self.assertIn("agent_id: unbound variable", uninstalled.stderr)
        manifest = json.loads((self.new / "HandlerManifest.json").read_text())
        self.assertTrue(manifest[0]["handlerManifest"].get("continueOnUpdateFailure"),
                        "Azure stops at the legacy uninstall without this flag")
        installed = self.install(str(uninstalled.returncode))
        self.assertEqual(installed.returncode, 0, installed.stdout + installed.stderr)
        self.assertFalse(Path(self.env["PACKAGE_FILE"]).exists())
        # Actual enable routing, enrollment orchestration and service start;
        # only the package download/install and Fleet request are stubbed.
        enabled = self.run_bash(
            f'source "{self.new / "enable.sh"}"\n'
            'Install_ElasticAgent_DEB_RPM() { touch "$PACKAGE_FILE"; }\n'
            'Enroll_ElasticAgent() { echo enrolled >> "$CALLS"; }\n'
            'Run_Agent_DEB_RPM'
        )
        self.assertEqual(enabled.returncode, 0, enabled.stdout + enabled.stderr)
        self.assertEqual(Path(self.env["SERVICE_FILE"]).read_text(), "running")
        calls = Path(self.env["CALLS"]).read_text()
        self.assertIn("dpkg -P elastic-agent", calls)
        self.assertIn("enrolled", calls)

    def test_failed_recovery_does_not_continue_to_dependencies(self):
        self.env["FAIL_CLEANUP"] = "1"
        installed = self.install("1")
        self.assertNotEqual(installed.returncode, 0)
        self.assertNotIn("dependencies", Path(self.env["CALLS"]).read_text())
        self.assertTrue((self.new / ".uninstall-recovery-required").exists())
        # A later Azure install attempt may no longer carry the old exit code.
        retried = self.install("NOT_RUN")
        self.assertNotEqual(retried.returncode, 0)
        self.assertNotIn("dependencies", Path(self.env["CALLS"]).read_text())
        self.env["FAIL_CLEANUP"] = "0"
        recovered = self.install("NOT_RUN")
        self.assertEqual(recovered.returncode, 0, recovered.stderr)
        self.assertFalse((self.new / ".uninstall-recovery-required").exists())
        self.assertFalse(Path(self.env["PACKAGE_FILE"]).exists())

    def test_no_recovery_on_fresh_install_or_successful_uninstall(self):
        for code in (None, "", "NOT_RUN", "0"):
            with self.subTest(code=code):
                installed = self.install(code)
                self.assertEqual(installed.returncode, 0, installed.stderr)
                self.assertTrue(Path(self.env["PACKAGE_FILE"]).exists())
        self.assertNotIn("dpkg -r", Path(self.env["CALLS"]).read_text())

    def test_disable_failure_stops_update(self):
        updated = self.run_script(self.new, "update.sh",
                                  AZURE_GUEST_AGENT_DISABLE_CMD_EXIT_CODE="7")
        self.assertNotEqual(updated.returncode, 0)
        self.assertFalse((self.path / "update.txt").exists())

    def test_update_without_disable_still_sets_update_flag(self):
        for code in ("", "NOT_RUN", "0"):
            with self.subTest(code=code):
                updated = self.run_script(self.new, "update.sh",
                                          AZURE_GUEST_AGENT_DISABLE_CMD_EXIT_CODE=code)
                self.assertEqual(updated.returncode, 0, updated.stderr)
                self.assertEqual((self.path / "update.txt").read_text().strip(), "1")


if __name__ == "__main__":
    unittest.main()
