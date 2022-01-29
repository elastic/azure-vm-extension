#!/usr/bin/env bash
set -euo pipefail

# global vars
DISTRO_OS=""
LOGS_FOLDER=""
CONFIG_FILE=""
STATUS_FOLDER=""
CLOUD_ID=""
USERNAME=""
PASSWORD=""
BASE64_AUTH=""
ELASTICSEARCH_URL=""
STACK_VERSION=""
KIBANA_URL=""
POLICY_ID=""
LINUX_CERT_PATH="/var/lib/waagent"
IS_NEW_CONFIG=""
OLD_STACK_VERSION=""
OLD_ELASTICSEARCH_URL=""
OLD_KIBANA_URL=""
OLD_USERNAME=""
OLD_PASSWORD=""
OLD_BASE64_AUTH=""
OLD_CONFIG_FILE=""
OLD_CLOUD_ID=""
OLD_PROTECTED_SETTINGS=""
OLD_THUMBPRINT=""
IS_FLEET_SERVER=""
HAS_FLAG_VERSION=""
ID=""

# checkOS checks distro
checkOS()
{
  if dpkg -S /bin/ls >/dev/null 2>&1
  then
    DISTRO_OS="DEB"
    echo "[checkOS] distro is $DISTRO_OS" "INFO"
  elif rpm -q -f /bin/ls >/dev/null 2>&1
  then
    DISTRO_OS="RPM"
    echo "[checkOS] distro is $DISTRO_OS" "INFO"
  else
    DISTRO_OS="OTHER"
    echo "[checkOS] distro is $DISTRO_OS" "INFO"
  fi
}

# get_logs_location gets log path from the HandlerEnvironment file
get_logs_location()
{
  SCRIPT=$(readlink -f "$0")
  ES_EXT_DIR=$(dirname "$SCRIPT")
   if [ -e $ES_EXT_DIR/HandlerEnvironment.json ]; then
    LOGS_FOLDER=$(jq -r '.[0].handlerEnvironment.logFolder' $ES_EXT_DIR/HandlerEnvironment.json)
  else
    exit 1
  fi
}

# get_status_location gets status path from the HandlerEnvironment file
get_status_location()
{
  SCRIPT=$(readlink -f "$0")
  ES_EXT_DIR=$(dirname "$SCRIPT")
   if [ -e $ES_EXT_DIR/HandlerEnvironment.json ]
then
    STATUS_FOLDER=$(jq -r '.[0].handlerEnvironment.statusFolder' $ES_EXT_DIR/HandlerEnvironment.json)
else
    exit 1
fi
}

# log will log events in the azure logs
log()
{
  if [ "$LOGS_FOLDER" = "" ]; then
    get_logs_location
  fi
  echo \[$(date +%H:%M:%ST%d-%m-%Y)\]  "$1" "$2"
  echo \[$(date +%H:%M:%ST%d-%m-%Y)\]  "$1" "$2" >> "$LOGS_FOLDER"/es-agent.log
}

# checkShasum checks shasum
checkShasum()
{
  local archive_file_name="${1}"
  local authentic_checksum_file="${2}"
  echo  --check <(grep "\s${archive_file_name}$" "${authentic_checksum_file}")
  if $(which shasum >/dev/null 2>&1); then
    shasum \
      -a 256 \
      --check <(grep "\s${archive_file_name}$" "${authentic_checksum_file}")
  else
    echo "shasum is not available for use" >&2
    return 1
  fi
}

#get_configuration_location retrieves configuration file path from HandlerEnvironment file
get_configuration_location()
{
  SCRIPT=$(readlink -f "$0")
  ES_EXT_DIR=$(dirname "$SCRIPT")
  if [ -e "$ES_EXT_DIR/HandlerEnvironment.json" ]; then
    config_folder=$(jq -r '.[0].handlerEnvironment.configFolder' "$ES_EXT_DIR/HandlerEnvironment.json")
    config_files_path="$config_folder/*.settings"
    CONFIG_FILE=$(ls $config_files_path 2>/dev/null | sort -V | tail -1)
    log "INFO" "[get_configuration_location] configuration file $CONFIG_FILE found"
  else
    log "ERROR" "[get_configuration_location] HandlerEnvironment.json file not found"
    exit 1
  fi
}

# get_cloud_id retrieves the cloudID from the current configuration file
get_cloud_id()
{
  get_configuration_location
  if [ "$CONFIG_FILE" != "" ]; then
    CLOUD_ID=$(jq -r '.runtimeSettings[0].handlerSettings.publicSettings.cloudId' $CONFIG_FILE)
    log "INFO" "[get_cloud_id] Found cloud id $CLOUD_ID"
  else
    log "[get_cloud_id] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_protected_settings retrieves the private/protected settings from the current configuration file
get_protected_settings()
{
  get_configuration_location
  if [ "$CONFIG_FILE" != "" ]; then
    PROTECTED_SETTINGS=$(jq -r '.runtimeSettings[0].handlerSettings.protectedSettings' $CONFIG_FILE)
    log "INFO" "[get_protected_settings] Found protected settings"
  else
    log "[get_protected_settings] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_thumbprint retrieves the thumbprint value from the protected settings
get_thumbprint()
{
  get_configuration_location
  if [ "$CONFIG_FILE" != "" ]; then
    THUMBPRINT=$(jq -r '.runtimeSettings[0].handlerSettings.protectedSettingsCertThumbprint' $CONFIG_FILE)
    log "INFO" "[get_thumbprint] Found thumbprint $THUMBPRINT"
  else
    log "[get_thumbprint] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_username retrieves the username from the current configuration file n.settings
get_username()
{
  get_configuration_location
  if [ "$CONFIG_FILE" != "" ]; then
    USERNAME=$(jq -r '.runtimeSettings[0].handlerSettings.publicSettings.username' $CONFIG_FILE)
    log "INFO" "[get_username] Found username  $USERNAME"
  else
    log "ERROR" "[get_username] Configuration file not found"
    exit 1
  fi
}

# get_kibana_host retrieves the kibana URL from the cloud ID value (encoding and parsing it)
get_kibana_host () {
  get_cloud_id
  if [ "$CLOUD_ID" != "" ]; then
    cloud_hash=$(echo $CLOUD_ID | cut -f2 -d:)
    cloud_tokens=$(echo $cloud_hash | base64 -d -)
    host_port=$(echo $cloud_tokens | cut -f1 -d$)
    KIBANA_URL="https://$(echo $cloud_tokens | cut -f3 -d$).${host_port}"
    log "INFO" "[get_kibana_host] Found Kibana uri $KIBANA_URL"
 else
    log "ERROR" "[get_kibana_host] Cloud ID could not be parsed"
    exit 1
  fi

}

# get_elasticsearch_host retrieves the es URL from the cloud ID value (encoding and parsing it)
get_elasticsearch_host () {
  get_cloud_id
  if [ "$CLOUD_ID" != "" ]; then
    cloud_hash=$(echo $CLOUD_ID | cut -f2 -d:)
    cloud_tokens=$(echo $cloud_hash | base64 -d -)
    host_port=$(echo $cloud_tokens | cut -f1 -d$)
    ELASTICSEARCH_URL="https://$(echo $cloud_tokens | cut -f2 -d$).${host_port}"
    log "INFO" "[get_elasticsearch_host] Found ES uri $ELASTICSEARCH_URL"
  else
    log "ERROR" "[get_elasticsearch_host] Cloud ID could not be parsed"
    exit 1
  fi
}

# get_cloud_stack_version retrieves the stack version by pinging the es cluster and parsing the result
get_cloud_stack_version () {
  log "INFO" "[get_cloud_stack_version] Get ES cluster URL"
  get_elasticsearch_host
  if [ "$ELASTICSEARCH_URL" = "" ]; then
    log "ERROR" "[get_cloud_stack_version] Elasticsearch URL could not be found"
    exit 1
  fi
  get_password
  get_base64Auth
   if [ "$PASSWORD" = "" ] && [ "$BASE64_AUTH" = "" ]; then
    log "ERROR" "[get_cloud_stack_version] Both PASSWORD and BASE64AUTH key could not be found"
    exit 1
  fi
  local cred=""
  if [ "$PASSWORD" != "" ] && [ "$PASSWORD" != "null" ]; then
    get_username
    if [ "$USERNAME" = "" ]; then
      log "ERROR" "[get_cloud_stack_version] USERNAME could not be found"
      exit 1
    fi
    cred=${USERNAME}:${PASSWORD}
  else
    cred=$(echo "$BASE64_AUTH" | base64 --decode)
  fi
  json_result=$(curl "${ELASTICSEARCH_URL}"  -H 'Content-Type: application/json' -u $cred)
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
      log "ERROR" "[get_cloud_stack_version] error pinging $ELASTICSEARCH_URL"
      exit $EXITCODE
  fi
  STACK_VERSION=$(echo $json_result | jq -r '.version.number')
  log "INFO" "[get_cloud_stack_version] Stack version found is $STACK_VERSION"
}

# parse_yaml used for reading the agent id from the fleet.yml file
function parse_yaml {
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s=\"%s\"\n",vn, $2, $3);
      }
   }'
}

# has_fleet_server will check if the new version uses the Fleet Server or Kibana Fleet, starting from 7.13 is Fleet Server
function has_fleet_server {
  eval es_version="$1"
  IS_FLEET_SERVER=false
  major=$(echo $es_version | cut -f1 -d.)
  minor=$(echo $es_version | cut -f2 -d.)
  if [[ $major -gt 7 ]];then
    IS_FLEET_SERVER=true
  fi
  if [[ $minor -gt 12 ]]; then
    IS_FLEET_SERVER=true
  fi
}

# has_flag_version checks if stack version is 7.12, changes on the enroll cmd have been done for this version
function has_flag_version {
  eval es_version="$1"
  HAS_FLAG_VERSION=false
  major=$(echo $es_version | cut -f1 -d.)
  minor=$(echo $es_version | cut -f2 -d.)
  if [[ $major -eq 7 ]] && [[ $minor -eq 12 ]] ;then
    HAS_FLAG_VERSION=true
  fi
}

# retry_backoff will run the function 3 times until giving up and exiting with code 1
function retry_backoff() {
  local attempts=3
  local sleep_millis=20000
  # shift 3
  for attempt in $(seq 1 $attempts); do
    if [[ $attempt -gt 1 ]]; then
      log "ERROR" "[retry_backoff] Function failed on attempt $attempt, retrying in 20 sec ..."
    fi
    "$@" && local rc=$? || local rc=$?
    if [[ ! $rc -gt 0 ]]; then
      return $rc
    fi
    if [[ $attempt -eq $attempts ]]; then
      log "ERROR" "[retry_backoff] Function failed on last attempt $attempt."
      exit 1
    fi
    local sleep_ms="$(($sleep_millis))"
    sleep "${sleep_ms:0:-3}.${sleep_ms: -3}"
  done
}

# create_azure_policy will create an Azure VM extension policy
create_azure_policy() {
  result=$(curl -X POST "${KIBANA_URL}"/api/fleet/agent_policies?sys_monitoring=true -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -u "$cred" -d '{"name":"Azure VM extension policy","description":"Dedicated agent policy for Azure VM extension","namespace":"default","monitoring_enabled":["logs","metrics"]}' )
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    log "ERROR" "[create_azure_policy] error calling $KIBANA_URL/api/fleet/agent_policies to create Azure VM extension policy $result"
    return $EXITCODE
  fi

  # get new policy id
  item=$(echo "$result" | jq -r '.item | @base64')
  _jq() {
    echo ${item} | base64 --decode | jq -r ${1}
  }
  name=$(_jq '.name')
  status=$(_jq '.status')
  policy_id=$(_jq '.id')
  if [[ "$name" == *"Azure VM extension"* ]] && [[ "$status" == "active" ]] && [[ "$policy_id" != *"elastic-agent-on-cloud"* ]]; then
    ID=$(_jq '.id')
  fi
}

# get_azure_policy will retrieve the Azure VM extension policy from a list of policies
get_azure_policy() {
   eval result="$1"
   items=$(echo "$result" | jq -r '.items')
   for row in $(echo "${items}" | jq -r '.[] | @base64'); do
   _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
  name=$(_jq '.name')
  status=$(_jq '.status')
  id=$(_jq '.id')
  if [[ "$name" == *"Azure VM extension"* ]]  && [[ "$status" = "active" ]] && [[ "$id" != *"elastic-agent-on-cloud"* ]]; then
    ID=$(_jq '.id')
  fi
done
}

# get_any_active_policy will retrieve the first active policy
get_any_active_policy() {
   eval result="$1"
   items=$(echo "$result" | jq -r '.items')
   for row in $(echo "${items}" | jq -r '.[] | @base64'); do
   _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
  status=$(_jq '.status')
  id=$(_jq '.id')
  if [[ "$status" = "active" ]] && [[ "$id" != *"elastic-agent-on-cloud"* ]]; then
    ID=$(_jq '.id')
  fi
done
}

# write_status will write an event in the status file, required for azure vm extension
write_status() {
  local name="${1}"
  local operation="${2}"
  local mainStatus="${3}"
  local message="${4}"
  local subName="${5}"
  local subStatus="${6}"
  local subMessage="${7}"
  local sequenceNumber="0"
  local code=0
  get_status_location
  #2013-11-17T16:05:14Z
  timestampUTC=$(date +"%Y-%m-%dT%H:%M:%S%z")
  if [[ $subStatus = "error" ]]; then
        code=1
  fi
  if [[ "$STATUS_FOLDER" != "" ]]; then
    get_configuration_location
    if [ "$CONFIG_FILE" != "" ]; then
      filename="$(basename -- $CONFIG_FILE)"
      sequenceNumber=$(echo $filename | cut -f1 -d.)
    else
    log "[write_status] Configuration file not found" "ERROR"
    exit 1
    fi
  json="[{\"version\":\"1.0\",\"timestampUTC\":\"$timestampUTC\",\"status\":{\"name\":\"$name\",\"operation\":\"$operation\",\"status\":\"$mainStatus\",\"formattedMessage\": { \"lang\":\"en-US\", \"message\":\"$message\"},\"substatus\": [{ \"name\":\"$subName\", \"status\":\"$subStatus\",\"code\":\"$code\",\"formattedMessage\": { \"lang\":\"en-US\", \"message\":\"$subMessage\"}}]}} ]"
  echo $json > "$STATUS_FOLDER"/"$sequenceNumber".status
  fi
}

# encrypt will encrypt text
encrypt() {
  cert_path=".../waagent/$1.crt"
  private_key_path=".../waagent/$1.prv"
  if [[ -f "$cert_path" ]] && [[ -f "$private_key_path" ]]; then
    openssl cms -encrypt -in <(echo "$2") -inkey $private_key_path -recip $cert_path -inform dem
  else
    echo "ERROR" "[decrypt] Decryption failed. Could not find certificates"
  exit 1
  fi
}

# get_password will retrieve the password from the protected settings and decrypt the value
get_password() {
  get_protected_settings
  get_thumbprint
  cert_path="$LINUX_CERT_PATH/$THUMBPRINT.crt"
  private_key_path="$LINUX_CERT_PATH/$THUMBPRINT.prv"
  if [[ -f "$cert_path" ]] && [[ -f "$private_key_path" ]]; then
    protected_settings=$(openssl cms -decrypt -in <(echo "$PROTECTED_SETTINGS" | base64 --decode) -inkey "$private_key_path" -recip "$cert_path" -inform dem)
    PASSWORD=$(echo "$protected_settings" | jq -r '.password')
  else
    log "ERROR" "[get_password] Decryption failed. Could not find certificates"
    exit 1
  fi
}

# get_base64Auth will retrieve the base64auth from the protected settings and decrypt the value
get_base64Auth() {
  get_protected_settings
  get_thumbprint
  cert_path="$LINUX_CERT_PATH/$THUMBPRINT.crt"
  private_key_path="$LINUX_CERT_PATH/$THUMBPRINT.prv"
  if [[ -f "$cert_path" ]] && [[ -f "$private_key_path" ]]; then
    protected_settings=$(openssl cms -decrypt -in <(echo "$PROTECTED_SETTINGS" | base64 --decode) -inkey "$private_key_path" -recip "$cert_path" -inform dem)
    BASE64_AUTH=$(echo "${protected_settings}" | jq -r '.base64Auth')
  else
    log "ERROR" "[get_base64Auth] Decryption failed. Could not find certificates"
    exit 1
  fi
}

#is_new_config will check if is an extension update/ clean installation/configuration update
is_new_config(){
  log "INFO" "[is_new_config] Check if new config"
  currentSequence=""
  newSequence=""
  isUpdate=""
  get_configuration_location
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

# set_update_var will set a flag that the operation is a vm extension update
set_update_var() {
  log "INFO" "[set_update_var] Verified update"
  if [ "$LOGS_FOLDER" = "" ]; then
      get_logs_location
  fi
  echo "1" > "$LOGS_FOLDER/update.txt"
}

# set_sequence_to_file will set sequence flag for current configuration sequence file n.settings
function set_sequence_to_file
{
  log "INFO" "[set_sequence_to_file] Setting new sequence"
  get_configuration_location
  if [ "$CONFIG_FILE" != "" ]; then
    filename="$(basename -- $CONFIG_FILE)"
    newSequence=$(echo $filename | cut -f1 -d.)
    if [ "$LOGS_FOLDER" = "" ]; then
      get_logs_location
    fi
    #json="{\"sequence\":\"$newSequence\",\"update\":\"false\"}"
    echo "$newSequence" > "$LOGS_FOLDER/current.sequence"
    rm "$LOGS_FOLDER/update.txt"
    log "INFO" "[set_sequence_to_file] Sequence has been set"
  else
    log "[set_sequence_to_file] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_prev_configuration_location retrieves previous configuration file
get_prev_configuration_location()
{
  SCRIPT=$(readlink -f "$0")
  ES_EXT_DIR=$(dirname "$SCRIPT")
  log "INFO" "[get_prev_configuration_location] main directory found $ES_EXT_DIR"
  if [ -e "$ES_EXT_DIR/HandlerEnvironment.json" ]; then
    config_folder=$(jq -r '.[0].handlerEnvironment.configFolder' "$ES_EXT_DIR/HandlerEnvironment.json")
    log "INFO" "[get_prev_configuration_location]  configuration folder $config_folder found"
    config_files_path="$config_folder/*.settings"
    OLD_CONFIG_FILE=$(ls $config_files_path 2>/dev/null | sort -V | tail -n 2 | head -n 1)
    log "INFO" "[get_prev_configuration_location] configuration file $OLD_CONFIG_FILE found"
  else
    log "ERROR" "[get_prev_configuration_location] HandlerEnvironment.json file not found"
    exit 1
  fi
}

# get_prev_username retrieves previous username configuration option
get_prev_username()
{
  get_prev_configuration_location
  if [ "$OLD_CONFIG_FILE" != "" ]; then
    OLD_USERNAME=$(jq -r '.runtimeSettings[0].handlerSettings.publicSettings.username' $OLD_CONFIG_FILE)
    log "INFO" "[get_prev_username] Found username  OLD_USERNAME"
  else
    log "ERROR" "[get_prev_username] Configuration file not found"
    exit 1
  fi
}

# get_prev_cloud_id retrieves previous cloudID configuration option
get_prev_cloud_id()
{
  get_prev_configuration_location
  if [ "$OLD_CONFIG_FILE" != "" ]; then
    OLD_CLOUD_ID=$(jq -r '.runtimeSettings[0].handlerSettings.publicSettings.cloudId' $OLD_CONFIG_FILE)
    log "INFO" "[get_prev_cloud_id] Found cloud id $OLD_CLOUD_ID"
  else
    log "[get_prev_cloud_id] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_prev_kibana_host retrieves previous kibana URL configuration option
get_prev_kibana_host () {
  get_prev_cloud_id
  if [ "$OLD_CLOUD_ID" != "" ]; then
    cloud_hash=$(echo $OLD_CLOUD_ID | cut -f2 -d:)
    cloud_tokens=$(echo $cloud_hash | base64 -d -)
    host_port=$(echo $cloud_tokens | cut -f1 -d$)
    OLD_KIBANA_URL="https://$(echo $cloud_tokens | cut -f3 -d$).${host_port}"
    log "INFO" "[get_prev_kibana_host] Found Kibana uri $OLD_KIBANA_URL"
 else
    log "ERROR" "[get_prev_kibana_host] Cloud ID could not be parsed"
    exit 1
  fi

}

# get_prev_elasticsearch_host retrieves previous es URL configuration option
get_prev_elasticsearch_host () {
  get_prev_cloud_id
  if [ "$OLD_CLOUD_ID" != "" ]; then
    cloud_hash=$(echo $OLD_CLOUD_ID | cut -f2 -d:)
    cloud_tokens=$(echo $cloud_hash | base64 -d -)
    host_port=$(echo $cloud_tokens | cut -f1 -d$)
    OLD_ELASTICSEARCH_URL="https://$(echo $cloud_tokens | cut -f2 -d$).${host_port}"
    log "INFO" "[get_prev_elasticsearch_host] Found ES uri $OLD_ELASTICSEARCH_URL"
  else
    log "ERROR" "[get_prev_elasticsearch_host] Cloud ID could not be parsed"
    exit 1
  fi
}

# get_prev_protected_settings retrieves previous protected settings configuration option
get_prev_protected_settings()
{
  get_prev_configuration_location
  if [ "$OLD_CONFIG_FILE" != "" ]; then
    OLD_PROTECTED_SETTINGS=$(jq -r '.runtimeSettings[0].handlerSettings.protectedSettings' $OLD_CONFIG_FILE)
    log "INFO" "[get_prev_protected_settings] Found protected settings $OLD_PROTECTED_SETTINGS"
  else
    log "[get_prev_protected_settings] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_prev_thumbprint retrieves previous thumbprint configuration option
get_prev_thumbprint()
{
  get_prev_configuration_location
  if [ "$OLD_CONFIG_FILE" != "" ]; then
    OLD_THUMBPRINT=$(jq -r '.runtimeSettings[0].handlerSettings.protectedSettingsCertThumbprint' $OLD_CONFIG_FILE)
    log "INFO" "[get_prev_thumbprint] Found thumbprint $OLD_THUMBPRINT"
  else
    log "[get_prev_thumbprint] Configuration file not found" "ERROR"
    exit 1
  fi
}

# get_prev_password retrieves previous password configuration option
get_prev_password() {
  get_prev_protected_settings
  get_prev_thumbprint
  cert_path="$LINUX_CERT_PATH/$OLD_THUMBPRINT.crt"
  private_key_path="$LINUX_CERT_PATH/$OLD_THUMBPRINT.prv"
  log "INFO" "Found cerficate $cert_path and $private_key_path"
  if [[ -f "$cert_path" ]] && [[ -f "$private_key_path" ]]; then
    protected_settings=$(openssl cms -decrypt -in <(echo "$OLD_PROTECTED_SETTINGS" | base64 --decode) -inkey "$private_key_path" -recip "$cert_path" -inform dem)
    OLD_PASSWORD=$(echo "$protected_settings" | jq -r '.password')
  else
    log "ERROR" "[get_prev_password] Decryption failed. Could not find certificates"
    exit 1
  fi
}

# get_prev_base64Auth retrieves previous base64auth configuration option
get_prev_base64Auth() {
  get_prev_protected_settings
  get_prev_thumbprint
  cert_path="$LINUX_CERT_PATH/$OLD_THUMBPRINT.crt"
  private_key_path="$LINUX_CERT_PATH/$OLD_THUMBPRINT.prv"
  if [[ -f "$cert_path" ]] && [[ -f "$private_key_path" ]]; then
    protected_settings=$(openssl cms -decrypt -in <(echo "$OLD_PROTECTED_SETTINGS" | base64 --decode) -inkey "$private_key_path" -recip "$cert_path" -inform dem)
    OLD_BASE64_AUTH=$(echo "${protected_settings}" | jq -r '.base64Auth')
  else
    log "ERROR" "[get_prev_base64Auth] Decryption failed. Could not find certificates"
    exit 1
  fi
}

# get_prev_cloud_stack_version retrieves previous stack version
get_prev_cloud_stack_version () {
  log "INFO" "[get_prev_cloud_stack_version] Get ES cluster URL"
  get_prev_elasticsearch_host
  if [ "$OLD_ELASTICSEARCH_URL" = "" ]; then
    log "ERROR" "[get_prev_cloud_stack_version] Elasticsearch URL could not be found"
    exit 1
  fi
  get_prev_password
  get_prev_base64Auth
   if [ "$OLD_PASSWORD" = "" ] && [ "$OLD_BASE64_AUTH" = "" ]; then
    log "ERROR" "[get_prev_cloud_stack_version] Both PASSWORD and BASE64AUTH key could not be found"
    exit 1
  fi
  local cred=""
  if [ "$OLD_PASSWORD" != "" ] && [ "$OLD_PASSWORD" != "null" ]; then
    get_prev_username
    if [ "$OLD_USERNAME" = "" ]; then
      log "ERROR" "[get_prev_cloud_stack_version] USERNAME could not be found"
      exit 1
    fi
    cred=${OLD_USERNAME}:${OLD_PASSWORD}
  else
    cred=$(echo "$OLD_BASE64_AUTH" | base64 --decode)
  fi
  json_result=$(curl "${OLD_ELASTICSEARCH_URL}"  -H 'Content-Type: application/json' -u $cred)
  local EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
      log "ERROR" "[get_prev_cloud_stack_version] error pinging $OLD_ELASTICSEARCH_URL"
      exit $EXITCODE
  fi
  OLD_STACK_VERSION=$(echo $json_result | jq -r '.version.number')
  log "INFO" "[get_prev_cloud_stack_version] Stack version found is $OLD_STACK_VERSION"
}