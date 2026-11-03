#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# disable script is ran at disable time, during an uninstall or update

# var for vm extension status
name="Disable elastic agent"
operation="stopping elastic agent"
message="Disable elastic agent"
sub_name="Elastic Agent"

# Stop_ElasticAgent stops the Elastic Agent
Stop_ElasticAgent()
{
  if [[ $(systemctl) =~ -\.mount ]]; then
    log "INFO" "[Stop_ElasticAgent] stopping  Elastic Agent"
    sudo systemctl stop elastic-agent
    log "INFO" "[Stop_ElasticAgent] Elastic Agent stopped"
    write_status "$name" "$operation" "success" "$message" "$sub_name" "success" "Elastic Agent service has stopped"
  else
    log "INFO" "[Stop_ElasticAgent] stopping Elastic Agent"
    sudo service elastic-agent stop
    log "INFO" "[Stop_ElasticAgent] Elastic Agent stopped"
    write_status "$name" "$operation" "success" "$message" "$sub_name" "success" "Elastic Agent service has stopped"
  fi
}

retry_backoff Stop_ElasticAgent
