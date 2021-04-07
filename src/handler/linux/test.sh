#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(realpath -s $0))
source $script_path/helper.sh

Run_Agent_DEB_RPM() {

  if [ "$(pidof systemd && echo "systemd" || echo "other")" = "other" ]; then
    log "INFO" "other "
  else
    log "INFO" "systemd "
  fi


  log "INFO" "hello "
  service_name="elastic-agent"
  if [[ $(systemctl list-units --all -t service --full --no-legend "$service_name.service" | cut -f1 -d' ') == $service_name.service ]] && [[ $(systemctl list-units --all -t service --full --no-legend "$service_name.service" | cut -f2 -d' ') != "not-found" ]]; then
      service_status="$(sudo systemctl is-active --quiet elastic-agent && echo Running || echo Stopped)"
    log "INFO" "exists "
    is_config
    if [[ $IS_NEW_CONFIG = true ]]; then
      log "INFO" "[Run_Agent_DEB_RPM] New configuration has been added, the elastic agent will be reinstalled"
    fi
    if [[ "$service_status" = "Running" ]]; then
      log "INFO"   "[Run_Agent_DEB_RPM] Elastic Agent is running"
    else
      log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is not running"

    fi
  else
    log "INFO"  "[Run_Agent_DEB_RPM] Elastic Agent is not installed"
    fi
}


is_config(){
  currentSequence=""
  newSequence=""
  isUpdate=""
  get_configuration_location
  echo $CONFIG_FILE
  if [ "$CONFIG_FILE" != "" ]; then
    filename="$(basename -- $CONFIG_FILE)"
    newSequence=$(echo $filename | cut -f1 -d.)
  else
    log "[get_sequence] Configuration file not found" "ERROR"
    exit 1
  fi
  if [ "$LOGS_FOLDER" = "" ]; then
      get_logs_location
  fi
  if [ -f "$LOGS_FOLDER/update.txt" ]; then
    isUpdate=true
  else
    isUpdate=false
  fi
  if [ -f "$LOGS_FOLDER/current.sequence" ]; then
    currentSequence=$(< "$LOGS_FOLDER/current.sequence")
  else
    currentSequence=""
  fi
  log "INFO" "[is_new_config] Current sequence is $currentSequence and new sequence is $newSequence"
  if [[ "$newSequence" = "" ]]; then
    IS_NEW_CONFIG=false
  elif   [[ "$isUpdate" = true ]]; then
    log "INFO" "[is_new_config] Part of the update"
    IS_NEW_CONFIG=false
  elif   [[ "$newSequence" = "$currentSequence" ]]; then
    IS_NEW_CONFIG=false
  else
      IS_NEW_CONFIG=true
  fi
}

Run_Agent_DEB_RPM
