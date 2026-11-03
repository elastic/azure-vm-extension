#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# uninstall script is ran at uninstall time, either triggered by user or during vm extension update

# var for reporting uninstall status
name="Uninstall elastic agent"
first_operation="unenrolling elastic agent"
second_operation="uninstalling elastic agent and removing any elastic agent related folders"
message="Uninstall elastic agent"
sub_name="Elastic Agent"

checkOS

# Uninstall_ElasticAgent_DEB_RPM uninstalls the elastic agent and removes directories for Debian and RPM os's
Uninstall_ElasticAgent_DEB_RPM() {
  # retry_backoff invokes this function in a conditional, which disables bash's
  # errexit inside it. Propagate failures explicitly, including during recovery.
  log "INFO" "[Uninstall_ElasticAgent_DEB_RPM] removing Elastic Agent directories"
  if [[ $(systemctl) =~ -\.mount ]]; then
    local load_state active_state
    load_state=$(systemctl show elastic-agent.service --property=LoadState) || return $?
    load_state=${load_state#LoadState=}
    if [ "$load_state" = "not-found" ]; then
      # A retry may find the package/unit already removed. A unit without a
      # backing file can still be running, so stop it unless it is inactive.
      active_state=$(systemctl show elastic-agent.service --property=ActiveState) || return $?
      active_state=${active_state#ActiveState=}
      if [ "$active_state" != "inactive" ]; then
        sudo systemctl stop elastic-agent || return $?
      fi
    else
      sudo systemctl stop elastic-agent || return $?
      sudo systemctl disable elastic-agent || return $?
    fi
  fi
  # Stop the service before package removal: RPM's scriptlets remove its unit
  # and reload systemd. Query the database successfully before treating an
  # absent RPM as completed cleanup; database errors must still propagate.
  if [ "$DISTRO_OS" = "RPM" ]; then
    local installed_packages
    installed_packages=$(rpm -qa --qf '%{NAME}\n') || return $?
    if grep -Fxq elastic-agent <<< "$installed_packages"; then
      sudo rpm -e elastic-agent || return $?
    fi
  elif [ "$DISTRO_OS" = "DEB" ]; then
    # dpkg tolerates an absent package and can retry purging config files after
    # removal succeeded on an earlier attempt.
    sudo dpkg -r elastic-agent || return $?
    sudo dpkg -P elastic-agent || return $?
  fi
  sudo rm -rf /usr/share/elastic-agent || return $?
  sudo rm -rf /etc/elastic-agent || return $?
  sudo rm -rf /var/lib/elastic-agent || return $?
  sudo rm -rf /usr/bin/elastic-agent || return $?
  if [[ $(systemctl) =~ -\.mount ]]; then
   sudo systemctl daemon-reload || return $?
   sudo systemctl reset-failed || return $?
  fi
  log "INFO" "[Uninstall_ElasticAgent_DEB_RPM] Elastic Agent removed"
}

# Uninstall_ElasticAgent checks distro and removes installation of the elastic agent
Uninstall_ElasticAgent()
{
  # Agent unenrollment is temporary removed from the uninstall script. It will be 
  # added back in a future release.
  #
  # To learn more, see https://github.com/elastic/azure-vm-extension/pull/88
  #
  log "INFO" "[Uninstall_ElasticAgent] Uninstalling Elastic Agent"
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    retry_backoff Uninstall_ElasticAgent_DEB_RPM
  else
    sudo elastic-agent uninstall
    log "INFO" "[Uninstall_ElasticAgent] Elastic Agent removed"
  fi
  log "INFO" "Elastic Agent is uninstalled"
  write_status "$name" "$second_operation" "success" "$message" "$sub_name" "error" "Elastic Agent service has been uninstalled"
}

Uninstall_ElasticAgent
