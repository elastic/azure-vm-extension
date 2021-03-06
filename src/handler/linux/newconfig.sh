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

# Unenroll_Old_ElasticAgent_DEB_RPM unenrolls the elastic agent for debian and rpm os's
Unenroll_Old_ElasticAgent_DEB_RPM()
{
  log "INFO" "[Unenroll_Old_ElasticAgent_DEB_RPM] Unenrolling elastic agent"
  get_prev_kibana_host
  if [[ "$OLD_KIBANA_URL" = "" ]]; then
    log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] Kibana URL could not be found/parsed"
    return 1
  fi
  get_prev_password
  get_prev_base64Auth
  if [ "$OLD_PASSWORD" = "" ] && [ "$OLD_BASE64_AUTH" = "" ]; then
    log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] Password could not be found/parsed"
    return 1
  fi
  local cred=""
  if [[ "$OLD_PASSWORD" != "" ]] && [ "$OLD_PASSWORD" != "null" ]; then
    get_prev_username
    if [[ "$OLD_USERNAME" = "" ]]; then
      log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] Username could not be found/parsed"
      return 1
    fi
    cred=${OLD_USERNAME}:${OLD_PASSWORD}
  else
    cred=$(echo "$OLD_BASE64_AUTH" | base64 --decode)
  fi
  eval $(parse_yaml "/etc/elastic-agent/fleet.yml")
  if [[ "$agent_id" = "" ]]; then
    log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] Password could not be found/parsed"
    return 1
  fi
  log "INFO" "[Unenroll_Old_ElasticAgent_DEB_RPM] Agent ID is $agent_id"
  if [[ $OLD_STACK_VERSION = "" ]]; then
    get_prev_cloud_stack_version
  fi
  has_fleet_server $OLD_STACK_VERSION
  data='{"force":"true"}'
  if [[ $IS_FLEET_SERVER = true ]]; then
    data='{"revoke":"true"}'
  fi
  jsonResult=$(curl -X POST "${OLD_KIBANA_URL}/api/fleet/agents/$agent_id/unenroll"  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" --data $data )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] error calling $OLD_KIBANA_URL/api/fleet/agents/$agent_id/unenroll in order to unenroll the agent"
    return $EXITCODE
  fi
  log "INFO" "[Unenroll_Old_ElasticAgent_DEB_RPM] Agent has been unenrolled"
  write_status "$name" "$first_operation" "success" "$message" "$sub_name" "success" "Elastic Agent service has been unenrolled"
}

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
  log "INFO" "[Uninstall_Old_ElasticAgent] Unenrolling Elastic Agent"
  retry_backoff Unenroll_Old_ElasticAgent_DEB_RPM
  log "INFO" "[Uninstall_Old_ElasticAgent] Elastic Agent has been unenrolled"
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    retry_backoff Uninstall_Old_ElasticAgent_DEB_RPM
  else
    sudo elastic-agent uninstall
    log "INFO" "[Uninstall_Old_ElasticAgent] Elastic Agent removed"
  fi
  log "INFO" "Elastic Agent is uninstalled"
  write_status "$name" "$second_operation" "success" "$message" "$sub_name" "error" "Elastic Agent service has been uninstalled"
}


