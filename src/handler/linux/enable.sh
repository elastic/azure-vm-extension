#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

service_name="elastic-agent"

# for status install
name="Install elastic agent"
first_operation="installing elastic agent"
second_operation="enrolling elastic agent"
message="Install elastic agent"
sub_name="Elastic Agent"


# for status enable
name_en="Enable elastic agent"
operation_en="starting elastic agent"
message_en="Enable elastic agent"

# for status uninstall old
name_un="Uninstall elastic agent"
first_operation_un="unenrolling elastic agent"
second_operation_un="uninstalling elastic agent and removing any elastic agent related folders"
message_un="Uninstall elastic agent"

checkOS

# Install Elastic Agent

Install_ElasticAgent_DEB()
{
    local OS_SUFFIX="-amd64"
    local ALGORITHM="512"
    get_cloud_stack_version
    if [ $STACK_VERSION = "" ]; then
       log "ERROR" "[install_es_ag_deb] Stack version could not be found"
       return 1
    else
    log "INFO" "[Install_ElasticAgent_DEB] installing Elastic Agent $STACK_VERSION"
    local PACKAGE="elastic-agent-${STACK_VERSION}${OS_SUFFIX}.deb"
    local SHASUM="$PACKAGE.sha$ALGORITHM"
    local DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}"
    local SHASUM_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}.sha512"
    wget --retry-connrefused --waitretry=1 "$SHASUM_URL" -O "$SHASUM"
    local EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_DEB] error downloading Elastic Agent $STACK_VERSION sha$ALGORITHM checksum"
        return $EXIT_CODE
    fi
    log "[Install_ElasticAgent_DEB] download location - $DOWNLOAD_URL" "INFO"
    wget --retry-connrefused --waitretry=1 "$DOWNLOAD_URL" -O $PACKAGE
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
    log "ERROR" "[Install_ElasticAgent_DEB] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi
    log "INFO" "[Install_ElasticAgent_DEB] downloaded Elastic Agent $STACK_VERSION"
    write_status "$name" "$first_operation" "transitioning" "$message" "$sub_name" "success" "Elastic Agent package has been downloaded"
    #checkShasum $PACKAGE $SHASUM
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_DEB] error validating checksum for Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi

    sudo dpkg -i $PACKAGE
    sudo apt-get install -f
    log "INFO" "[Install_ElasticAgent_DEB] installed Elastic Agent $STACK_VERSION"
    write_status "$name" "$first_operation" "success" "$message" "$sub_name" "success" "Elastic Agent has been installed"
 fi
}

Install_ElasticAgent_RPM()
{
    local OS_SUFFIX="-x86_64"
    local ALGORITHM="512"
    get_cloud_stack_version
    if [[ $STACK_VERSION = "" ]]; then
       log "ERROR" "[Install_ElasticAgent_RPM] Stack version could not be found"
       return 1
    else
      local PACKAGE="elastic-agent-${STACK_VERSION}${OS_SUFFIX}.rpm"
      local SHASUM="$PACKAGE.sha$ALGORITHM"
      local DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}"
      local SHASUM_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}.sha512"
      log "INFO" "[Install_ElasticAgent_RPM] installing Elastic Agent $STACK_VERSION"
      wget --retry-connrefused --waitretry=1 "$SHASUM_URL" -O "$SHASUM"
      local EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_RPM] error downloading Elastic Agent $STACK_VERSION sha$ALGORITHM checksum"
        return $EXIT_CODE
      fi
      log "INFO" "[Install_ElasticAgent_RPM] download location - $DOWNLOAD_URL"
      wget --retry-connrefused --waitretry=1 "$DOWNLOAD_URL" -O $PACKAGE
      EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_RPM] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
      fi
      log "INFO" "[Install_ElasticAgent_RPM] downloaded Elastic Agent $STACK_VERSION"
      write_status "$name" "$first_operation" "transitioning" "$message" "$sub_name" "success" "Elastic Agent package has been downloaded"
      #checkShasum $PACKAGE $SHASUM
      EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_RPM] error validating checksum for Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
      fi
      sudo rpm -vi $PACKAGE
      log "INFO" "[Install_ElasticAgent_RPM] installed Elastic Agent $STACK_VERSION"
      write_status "$name" "$first_operation" "success" "$message" "$sub_name" "success" "Elastic Agent has been installed"
    fi
}

Install_ElasticAgent_OTHER()
{
    local OS_SUFFIX="-linux-x86_64"
    local PACKAGE="elastic-agent-${STACK_VERSION}${OS_SUFFIX}.tar.gz"
    local ALGORITHM="512"
    local SHASUM="$PACKAGE.sha$ALGORITHM"
    local DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}"
    local SHASUM_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/${PACKAGE}.sha512"
    log "INFO" "[Install_ElasticAgent_OTHER] installing Elastic Agent $STACK_VERSION"
    wget --retry-connrefused --waitretry=1 "$SHASUM_URL" -O "$SHASUM"
    local EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error downloading Elastic Agent $STACK_VERSION sha$ALGORITHM checksum"
        return $EXIT_CODE
    fi
    log "INFO" "[Install_ElasticAgent_OTHER] download location - $DOWNLOAD_URL"
    wget --retry-connrefused --waitretry=1 "$DOWNLOAD_URL" -O $PACKAGE
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi
    log "INFO" "[Install_ElasticAgent_OTHER] downloaded Elastic Agent $STACK_VERSION"
    #checkShasum $PACKAGE $SHASUM
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error validating checksum for Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi
    tar xzvf $PACKAGE
    log "INFO" "[Install_ElasticAgent_OTHER] installed Elastic Agent $STACK_VERSION"
}



# Enroll Elastic Agent
Enroll_ElasticAgent() {
  get_kibana_host
  if [[ "$KIBANA_URL" = "" ]]; then
    log "ERROR" "[Enroll_ElasticAgent] Kibana URL could not be found/parsed"
    return 1
  fi
  get_password
  get_base64Auth
   if [ "$PASSWORD" = "" ] && [ "$BASE64_AUTH" = "" ]; then
    log "ERROR" "[Enroll_ElasticAgent] Password could not be found/parsed"
    return 1
  fi
  local cred=""
  if [[ "$PASSWORD" != "" ]] && [[ "$PASSWORD" != "null" ]]; then
    get_username
    if [[ "$USERNAME" = "" ]]; then
      log "ERROR" "[Enroll_ElasticAgent] Username could not be found/parsed"
      return 1
    fi
    cred=${USERNAME}:${PASSWORD}
  else
    cred=$(echo "$BASE64_AUTH" | base64 --decode)
  fi
  #enable Fleet
  result=$(curl -X POST "${KIBANA_URL}"/api/fleet/setup  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/setup in order to enable Kibana Fleet $result"
    return $EXITCODE
  fi
  result=$(curl -X POST "${KIBANA_URL}"/api/fleet/agents/setup  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/setup in order to enable Kibana Fleet Agents $result"
    return $EXITCODE
  fi
  #end enable Fleet
  local ENROLLMENT_TOKEN=""
  jsonResult=$(curl "${KIBANA_URL}"/api/fleet/enrollment-api-keys  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/enrollment-api-keys in order to retrieve the ENROLLMENT_TOKEN"
    return $EXITCODE
  fi
  get_default_policy "\${jsonResult}"
  if [[ "$POLICY_ID" = "" ]]; then
    log "WARN" "[Enroll_ElasticAgent] Default policy could not be found or is not active. Will select any active policy instead"
    get_any_active_policy "\${jsonResult}"
  fi
  if [[ "$POLICY_ID" = "" ]]; then
    log "ERROR" "[Enroll_ElasticAgent] No active policies were found. Please create a policy in Kibana Fleet"
    return 1
  fi
  log "INFO" "[Enroll_ElasticAgent] ENROLLMENT_TOKEN_ID is $POLICY_ID"
  jsonResult=$(curl ${KIBANA_URL}/api/fleet/enrollment-api-keys/$POLICY_ID \
        -H 'Content-Type: application/json' \
        -H 'kbn-xsrf: true' \
        -u "$cred" )
  EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/enrollment-api-keys in order to retrieve the ENROLLMENT_TOKEN"
    return $EXITCODE
  fi
  ENROLLMENT_TOKEN=$(echo $jsonResult | jq -r '.item.api_key')
  if [[ "$ENROLLMENT_TOKEN" = "" ]]; then
    log "ERROR" "[Enroll_ElasticAgent] ENROLLMENT_TOKEN could not be found/parsed"
    return 1
  fi
  log "INFO" "[Enroll_ElasticAgent] ENROLLMENT_TOKEN is $ENROLLMENT_TOKEN"
  log "INFO" "[Enroll_ElasticAgent] Enrolling the Elastic Agent to Fleet ${KIBANA_URL}"
    if [[ $STACK_VERSION = "" ]]; then
         get_cloud_stack_version
       fi
       echo $STACK_VERSION
  if [[ $STACK_VERSION = 7.12*  ]]; then
    sudo elastic-agent enroll  --kibana-url="${KIBANA_URL}" --enrollment-token="$ENROLLMENT_TOKEN" -f
  else
    sudo elastic-agent enroll  "${KIBANA_URL}" "$ENROLLMENT_TOKEN" -f
  fi

  write_status "$name" "$second_operation" "success" "$message" "$sub_name" "success" "Elastic Agent has been enrolled"
  set_sequence_to_file
}


Install_ElasticAgent() {
  if [ "$DISTRO_OS" = "DEB" ]; then
    retry_backoff  Install_ElasticAgent_DEB
  elif [ "$DISTRO_OS" = "RPM" ]; then
    retry_backoff  Install_ElasticAgent_RPM
  else
    retry_backoff  Install_ElasticAgent_OTHER
  fi
  log "INFO" "[Install_ElasticAgent] enrolling Elastic Agent $STACK_VERSION"
  retry_backoff Enroll_ElasticAgent
  log "INFO" "[Install_ElasticAgent] Elastic Agent $STACK_VERSION enrolled"
  retry_backoff Start_ElasticAgent
}

# Start Elastic Agent
Start_ElasticAgent()
{
  if [[ $(systemctl) =~ -\.mount ]]; then
    log "INFO" "[Start_ElasticAgent] enabling and starting Elastic Agent"
    sudo systemctl enable elastic-agent
    sudo systemctl start elastic-agent
    log "INFO" "[Start_ElasticAgent] Elastic Agent started"
    write_status "$name_en" "$operation_en" "success" "$message_en" "$sub_name" "success" "Elastic Agent service has started"
  else
    log "INFO" "[Start_ElasticAgent] starting Elastic Agent"
    sudo service elastic-agent start
    log "INFO" "[Start_ElasticAgent] Elastic Agent started"
    write_status "$name_en" "$operation_en" "success" "$message_en" "$sub_name" "success" "Elastic Agent service has started"
  fi
}

Reconfigure_Elastic_agent_DEB_RPM() {
   log "INFO" "[Reconfigure_Elastic_agent_DEB_RPM] Stopping Elastic Agent"
   sudo systemctl stop elastic-agent
   log "INFO" "[Reconfigure_Elastic_agent_DEB_RPM] Elastic Agent stopped"
   Uninstall_Old_ElasticAgent
   Install_ElasticAgent
   write_status "$name_en" "$operation_en" "success" "$message_en" "$sub_name" "success" "Elastic Agent service has started"
}

Run_Agent_Other() {
  log "INFO" "[Run_Agent_Other] prepare elastic agent for install/enable for other Linux os"
  if sudo service --status-all | grep -Fq "$service_name"; then
      log "INFO" "[Run_Agent_Other] start Elastic Agent"
      retry_backoff Start_ElasticAgent
    else
      log "INFO" "[Run_Agent_Other] install Elastic Agent"
      Install_ElasticAgent
    fi
}

Run_Agent_DEB_RPM() {
  log "INFO" "[Start_ElasticAgent] starting Elastic Agent"
  log "INFO" "[Run_Agent_DEB_RPM] Prepare elastic agent for DEB/RPM systems"

  if [[ $(systemctl) =~ -\.mount ]]; then
    if [[ $(systemctl list-units --all -t service --full --no-legend "$service_name.service" | cut -f1 -d' ') == $service_name.service ]] && [[ $(systemctl list-units --all -t service --full --no-legend "$service_name.service" | cut -f2 -d' ') != "not-found" ]]; then
      service_status="$(sudo systemctl is-active --quiet elastic-agent && echo Running || echo Stopped)"
      is_new_config
      if [[ $IS_NEW_CONFIG = true ]]; then
        log "INFO" "[Run_Agent_DEB_RPM] New configuration has been added, the elastic agent will be reinstalled"
        retry_backoff Reconfigure_Elastic_agent_DEB_RPM
      fi
      if [[ "$service_status" = "Running" ]]; then
        log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is running"
      else
        log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is not running"
        retry_backoff Start_ElasticAgent
     fi
    else
      log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is not installed"
      Install_ElasticAgent
    fi
  else
    if sudo service --status-all | grep -q "elastic-agent" ;then
      status=$(sudo service "elastic-agent" status)
      is_new_config
      if [[ $IS_NEW_CONFIG = true ]]; then
        log "INFO" "[Run_Agent_DEB_RPM] New configuration has been added, the elastic agent will be reinstalled"
        retry_backoff Reconfigure_Elastic_agent_DEB_RPM
      fi
      if [[ $status == *"running"* ]]; then
        log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is running"
      else
        log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is not running"
        retry_backoff Start_ElasticAgent
      fi
    else
      log "INFO" "[Run_Agent_DEB_RPM] Elastic Agent is not installed"
      Install_ElasticAgent
    fi
  fi
}

#update config

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
  jsonResult=$(curl -X POST "${OLD_KIBANA_URL}/api/fleet/agents/$agent_id/unenroll"  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" --data '{"force":"true"}' )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Unenroll_Old_ElasticAgent_DEB_RPM] error calling $OLD_KIBANA_URL/api/fleet/agents/$agent_id/unenroll in order to unenroll the agent"
    return $EXITCODE
  fi
  log "INFO" "[Unenroll_Old_ElasticAgent_DEB_RPM] Agent has been unenrolled"
  write_status "$name_un" "$first_operation_un" "success" "$message_un" "$sub_name" "success" "Elastic Agent service has been unenrolled"
}

Uninstall_Old_ElasticAgent_DEB_RPM() {
   if [ "$DISTRO_OS" = "RPM" ]; then
      sudo rpm -e elastic-agent
   fi
   log "INFO" "[Uninstall_Old_ElasticAgent_DEB_RPM] removing Elastic Agent directories"
   sudo systemctl stop elastic-agent
   sudo systemctl disable elastic-agent
   sudo rm -rf /usr/share/elastic-agent
   sudo rm -rf /etc/elastic-agent
   sudo rm -rf /var/lib/elastic-agent
   sudo rm -rf /usr/bin/elastic-agent
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
   if [ "$DISTRO_OS" = "DEB" ]; then
     sudo dpkg -r elastic-agent
     sudo dpkg -P elastic-agent
   fi
   log "INFO" "[Uninstall_Old_ElasticAgent_DEB_RPM] Elastic Agent removed"
}


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
  write_status "$name_un" "$second_operation_un" "success" "$message_un" "$sub_name" "error" "Elastic Agent service has been uninstalled"
}

Run_Agent()
{
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    Run_Agent_DEB_RPM
  else
   Run_Agent_Other
  fi
}

Run_Agent




