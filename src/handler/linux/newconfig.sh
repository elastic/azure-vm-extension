#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# neconfig script used during enable time, will help will uninstalling the elastic agent previously configured, it will try to retrieve the previous configuration and uninstall/remove folders for the elastic agent

# var for uninstall status
name="Uninstall elastic agent"
first_operation="unenrolling elastic agent"
second_operation="uninstalling elastic agent and removing any elastic agent related folders"
message="Uninstall elastic agent"
sub_name="Elastic Agent"

checkOS

# Uninstall_Old_ElasticAgent_DEB_RPM uninstalls the elastic agent and removes directories for Debian and RPM os's
Uninstall_Old_ElasticAgent_DEB_RPM() {
  if [ "$DISTRO_OS" = "RPM" ]; then
    sudo rpm -e elastic-agent
  fi
  log "INFO" "[Uninstall_Old_ElasticAgent_DEB_RPM] removing Elastic Agent directories"
  if [[ $(systemctl) =~ -\.mount ]]; then
    sudo systemctl stop elastic-agent
    sudo systemctl disable elastic-agent
  fi
  sudo rm -rf /usr/share/elastic-agent
  sudo rm -rf /etc/elastic-agent
  sudo rm -rf /var/lib/elastic-agent
  sudo rm -rf /usr/bin/elastic-agent
  if [[ $(systemctl) =~ -\.mount ]]; then
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
  fi
  if [ "$DISTRO_OS" = "DEB" ]; then
   sudo dpkg -r elastic-agent
   sudo dpkg -P elastic-agent
  fi
  log "INFO" "[Uninstall_Old_ElasticAgent_DEB_RPM] Elastic Agent removed"
}

# Uninstall_Old_ElasticAgent checks distro and removes previous installation of the elastic agent
Uninstall_Old_ElasticAgent()
{
  log "INFO" "[Uninstall_Old_ElasticAgent] Uninstalling Elastic Agent"
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    retry_backoff Uninstall_Old_ElasticAgent_DEB_RPM
  else
    sudo elastic-agent uninstall
    log "INFO" "[Uninstall_Old_ElasticAgent] Elastic Agent removed"
  fi
  log "INFO" "Elastic Agent is uninstalled"
  write_status "$name" "$second_operation" "success" "$message" "$sub_name" "error" "Elastic Agent service has been uninstalled"
}
