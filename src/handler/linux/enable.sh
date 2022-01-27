#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh
source $script_path/newconfig.sh

# enable script will be run at enable time, will download artifacts, install elastic agent, enroll it to Fleet. Also, handles update configuration only.

# var for install status
name="Install elastic agent"
first_operation="installing elastic agent"
second_operation="enrolling elastic agent"
message="Install elastic agent"
sub_name="Elastic Agent"
service_name="elastic-agent"

# var enabling status
name_en="Enable elastic agent"
operation_en="starting elastic agent"
message_en="Enable elastic agent"

# Install_ElasticAgent_DEB_RPM function will download and install the elastic agent on Debian and RPM os's
Install_ElasticAgent_DEB_RPM()
{
  local algorithm="sha512"
  get_cloud_stack_version
  if [ $STACK_VERSION = "" ]; then
    log "ERROR" "[Install_ElasticAgent_DEB_RPM] Stack version could not be found"
    return 1
  else
    log "INFO" "[Install_ElasticAgent_DEB_RPM] installing Elastic Agent $STACK_VERSION"
    if [ "$DISTRO_OS" = "DEB" ]; then
      package="elastic-agent-${STACK_VERSION}-amd64.deb"
    elif [ "$DISTRO_OS" = "RPM" ]; then
      package="elastic-agent-${STACK_VERSION}-x86_64.rpm"
    fi
    local shasum="$package.$algorithm"
    local release_url="https://artifacts.elastic.co/downloads/beats/elastic-agent/"
    local staging_url="https://artifacts-api.elastic.co/v1/downloads/beats/"
    if [[ $(wget -S --spider "${release_url}${package}"  2>&1 | grep 'HTTP/1.1 200 OK') ]] ; then
      log "[Install_ElasticAgent_DEB_RPM] download location - ${release_url}${package}" "INFO"
      wget --retry-connrefused --waitretry=1 "${release_url}${package}" -O $package
      EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_DEB_RPM] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
      fi
      log "INFO" "[Install_ElasticAgent_DEB_RPM] downloaded Elastic Agent $STACK_VERSION"
      wget --retry-connrefused --waitretry=1 "${release_url}${package}.${algorithm}" -O "$shasum"
      local EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_DEB_RPM] error downloading Elastic Agent $STACK_VERSION $algorithm checksum"
        return $EXIT_CODE
      fi
      #checkShasum $package $shasum
      #EXIT_CODE=$?
      #if [[ $EXIT_CODE -ne 0 ]]; then
      #  log "ERROR" "[Install_ElasticAgent_DEB_RPM] error validating checksum for Elastic Agent $STACK_VERSION"
      #  return $EXIT_CODE
      #fi
    else
      log "[Install_ElasticAgent_DEB_RPM] download location - $staging_url" "INFO"
      wget --retry-connrefused --waitretry=1 "${staging_url}${package}" -O $package
      EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_DEB_RPM] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
      fi
      #no shasum version of the package
    fi
    write_status "$name" "$first_operation" "transitioning" "$message" "$sub_name" "success" "Elastic Agent package has been downloaded"
    if [ "$DISTRO_OS" = "DEB" ]; then
      sudo dpkg -i $package
      sudo apt-get install -f
    elif [ "$DISTRO_OS" = "RPM" ]; then
      sudo rpm -vi $package
    fi
    log "INFO" "[Install_ElasticAgent_DEB_RPM] installed Elastic Agent $STACK_VERSION"
    write_status "$name" "$first_operation" "success" "$message" "$sub_name" "success" "Elastic Agent has been installed"
  fi
}

# Install_ElasticAgent_OTHER will download and install the elastic agent in other os's
Install_ElasticAgent_OTHER()
{
    local os_suffix="-linux-x86_64"
    local package="elastic-agent-${STACK_VERSION}${os_suffix}.tar.gz"
    local algorithm="512"
    local shasum="$package.sha$algorithm"
    local download_url="https://artifacts.elastic.co/downloads/beats/elastic-agent/${package}"
    local shasum_url="https://artifacts.elastic.co/downloads/beats/elastic-agent/${package}.sha512"
    log "INFO" "[Install_ElasticAgent_OTHER] installing Elastic Agent $STACK_VERSION"
    wget --retry-connrefused --waitretry=1 "$shasum_url" -O "$shasum"
    local EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error downloading Elastic Agent $STACK_VERSION sha$algorithm checksum"
        return $EXIT_CODE
    fi
    log "INFO" "[Install_ElasticAgent_OTHER] download location - $download_url"
    wget --retry-connrefused --waitretry=1 "$download_url" -O $package
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error downloading Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi
    log "INFO" "[Install_ElasticAgent_OTHER] downloaded Elastic Agent $STACK_VERSION"
    #checkShasum $package $shasum
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "[Install_ElasticAgent_OTHER] error validating checksum for Elastic Agent $STACK_VERSION"
        return $EXIT_CODE
    fi
    tar xzvf $package
    log "INFO" "[Install_ElasticAgent_OTHER] installed Elastic Agent $STACK_VERSION"
}



# Enroll_ElasticAgent enrolls the elastic agent to Fleet
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
  if [[ $STACK_VERSION = "" ]]; then
    get_cloud_stack_version
  fi
  #enable Fleet
  has_fleet_server $STACK_VERSION
  result=$(curl -X POST "${KIBANA_URL}"/api/fleet/setup  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/setup in order to enable Kibana Fleet $result"
    return $EXITCODE
  fi
  if [[ $IS_FLEET_SERVER = false ]]; then
    result=$(curl -X POST "${KIBANA_URL}"/api/fleet/agents/setup  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
    local EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/setup in order to enable Kibana Fleet Agents $result"
      return $EXITCODE
    fi
  fi
  #end enable Fleet
  local enrolment_token=""
  jsonResult=$(curl "${KIBANA_URL}"/api/fleet/enrollment-api-keys  -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/enrollment-api-keys in order to retrieve the enrolment_token"
    return $EXITCODE
  fi

  get_azure_policy "\${jsonResult}"
  if [[ "$POLICY_ID" = "" ]]; then
    log "WARN" "[Enroll_ElasticAgent] Azure VM extension policy could not be found or is not active. Will create a VM extension policy instead"
    create_azure_policy "\${jsonResult}"
    get_azure_policy "\${jsonResult}"
      if [[ "$POLICY_ID" = "" ]]; then
        log "WARN" "[Enroll_ElasticAgent] Azure VM extension policy could not be found or is not active after creating it. Will select any active policy instead"
        get_any_active_policy "\${jsonResult}"
      fi
  fi

  if [[ "$POLICY_ID" = "" ]]; then
    log "ERROR" "[Enroll_ElasticAgent] No active policies were found. Please create a policy in Kibana Fleet"
    return 1
  fi
  log "INFO" "[Enroll_ElasticAgent] policy selected is $POLICY_ID"
  jsonResult=$(curl ${KIBANA_URL}/api/fleet/enrollment-api-keys/$POLICY_ID \
        -H 'Content-Type: application/json' \
        -H 'kbn-xsrf: true' \
        -u "$cred" )
  EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/enrollment-api-keys in order to retrieve the enrolment_token"
    return $EXITCODE
  fi
  enrolment_token=$(echo $jsonResult | jq -r '.item.api_key')
  if [[ "$enrolment_token" = "" ]]; then
    log "ERROR" "[Enroll_ElasticAgent] enrolment_token could not be found/parsed"
    return 1
  fi
  log "INFO" "[Enroll_ElasticAgent] enrolment_token is $enrolment_token"
  log "INFO" "[Enroll_ElasticAgent] Enrolling the Elastic Agent to Fleet ${KIBANA_URL}"
  has_flag_version $STACK_VERSION
  if [[ $IS_FLEET_SERVER = true ]]; then
    log "INFO" "[Enroll_ElasticAgent] Getting Fleet Server info"
    jsonResult=$(curl ${KIBANA_URL}/api/fleet/settings \
        -H 'Content-Type: application/json' \
        -H 'kbn-xsrf: true' \
        -u "$cred" )
    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      log "ERROR" "[Enroll_ElasticAgent] error calling $KIBANA_URL/api/fleet/settings in order to retrieve the Fleet Server URL"
      return $EXITCODE
    fi
    fleet_server=$(echo $jsonResult | jq -r '.item.fleet_server_hosts[0]')
    log "INFO" "[Enroll_ElasticAgent] Found fleet server $fleet_server"
    sudo elastic-agent enroll  --url="${fleet_server}" --enrollment-token="$enrolment_token" -f
  elif [[ $HAS_FLAG_VERSION = true  ]]; then
    sudo elastic-agent enroll  --kibana-url="${KIBANA_URL}" --enrollment-token="$enrolment_token" -f
  else
    sudo elastic-agent enroll  "${KIBANA_URL}" "$enrolment_token" -f
  fi
  write_status "$name" "$second_operation" "success" "$message" "$sub_name" "success" "Elastic Agent has been enrolled"
  set_sequence_to_file
}

#Install_ElasticAgent checks os distro and cllas the install, enroll functions
Install_ElasticAgent() {
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    retry_backoff  Install_ElasticAgent_DEB_RPM
  else
    retry_backoff  Install_ElasticAgent_OTHER
  fi
  log "INFO" "[Install_ElasticAgent] enrolling Elastic Agent $STACK_VERSION"
  retry_backoff Enroll_ElasticAgent
  log "INFO" "[Install_ElasticAgent] Elastic Agent $STACK_VERSION enrolled"
  retry_backoff Start_ElasticAgent
}

# Start_ElasticAgent starts the elastic agent based on systemd availability
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

# Run_Agent_Other checks os is other and then installs elastic agent
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

# Reconfigure_Elastic_agent_DEB_RPM will reinstall elastic agent based on new configuration options entered
Reconfigure_Elastic_agent_DEB_RPM() {
  log "INFO" "[Reconfigure_Elastic_agent_DEB_RPM] Stopping Elastic Agent"
  if [[ $(systemctl) =~ -\.mount ]]; then
    sudo systemctl stop elastic-agent
  else
    sudo service elastic-agent stop
  fi
  log "INFO" "[Reconfigure_Elastic_agent_DEB_RPM] Elastic Agent stopped"
  Uninstall_Old_ElasticAgent
  Install_ElasticAgent
  write_status "$name_en" "$operation_en" "success" "$message_en" "$sub_name" "success" "Elastic Agent service has started"
}

#Run_Agent_DEB_RPM will check if es agent service is installed or if is vm extension update, else will start a clean installation
Run_Agent_DEB_RPM() {
  log "INFO" "[Start_ElasticAgent] starting Elastic Agent"
  log "INFO" "[Run_Agent_DEB_RPM] Prepare elastic agent for DEB/RPM systems"
  if [[ $(systemctl) =~ -\.mount ]]; then
    log "INFO" "[Run_Agent_DEB_RPM]  Systemd detected"
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
    log "INFO" "[Run_Agent_DEB_RPM] No Systemd detected"
    if sudo service --status-all | grep -q "elastic-agent" ;then
      is_new_config
      if [[ $IS_NEW_CONFIG = true ]]; then
        log "INFO" "[Run_Agent_DEB_RPM] New configuration has been added, the elastic agent will be reinstalled"
        retry_backoff Reconfigure_Elastic_agent_DEB_RPM
      fi
      status=$(sudo service "elastic-agent" status || true)
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

# Run_Agent checks distro and calls corespondent functions
Run_Agent()
{
  if [ "$DISTRO_OS" = "DEB" ] || [ "$DISTRO_OS" = "RPM" ]; then
    Run_Agent_DEB_RPM
  else
   Run_Agent_Other
  fi
}

Run_Agent




