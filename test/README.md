# Test

## terraform folder

How to test this particular extension using terraform.

## ats folder

Run the Acceptance Tests for this particular extension.

## Linux upgrade regression tests

Run `python3 -B -m unittest discover -s test/upgrade -v` from the repository root.
The tests require Python 3 and Bash 4.2 or newer. They use vendored,
checksum-verified `1.2.0.0` scripts from `test/upgrade/fixtures/1.2.0.0`; no Git
history, tags, network access, VM, or credentials are needed. The suite replays
the old disable/uninstall scripts, current update/install cleanup, and enable
path with host operations and Fleet requests mocked. It covers DEB/RPM package
removal, absent-agent and partial-purge retries, genuine cleanup failures,
recovery markers, and rejection of recovery on other package types.

Buildkite runs `bash .buildkite/run-tests.sh`, which checks Linux handler Bash
syntax and runs this suite in `python:3.12-bookworm` through the pinned Docker
plugin. The container supplies Linux Bash, including the existing retry loop's
negative-length substring support, which macOS Bash 3.2 lacks.

The lifecycle follows the Azure Linux Agent's
[`_update_extension_handler_and_return_if_failed`](https://github.com/Azure/WALinuxAgent/blob/master/azurelinuxagent/ga/exthandlers.py):
disable old, update new, uninstall old, install new, then enable new. The new
manifest's `continueOnUpdateFailure` flag permits recovery after the old
uninstall fails; `AZURE_GUEST_AGENT_UNINSTALL_CMD_EXIT_CODE` identifies that
failure to the install command. A real Azure upgrade remains a release check.
