#!/usr/bin/env bash
set -eo pipefail

###############
### Arguments
###############
ES_USERNAME=${1:?'Missing the Username:Password'}
ES_PASSWORD=${2:?'Missing the Username:Password'}
ES_URL=${3:?'Missing the Elasticsearch URL'}
VM_NAME=${4:?'Missing the name of the Virtual Machine'}
IS_WINDOWS=${5:?'Missing whether it is a windows VM'}

###############
### Functions
###############
function count() {
  INDEX=$1
  RESULT=0
  temp_file=$(mktemp)
  curl -s -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/"${INDEX}"/_count -H 'Content-Type: application/json' -d"
  {
    \"query\": {
      \"match\": {
        \"agent.hostname\": \"${VM_NAME}\"
      }
    }
  }
  " > "${temp_file}" || RESULT=1
  jq -e '.count >= 1' "${temp_file}" > /dev/null || RESULT=1
  verify "$INDEX" $RESULT "${temp_file}"
}

function search() {
  INDEX=$1
  RESULT=0
  temp_file=$(mktemp)
  IT=0
  while [[ $RESULT == 1 || IT -le 30 ]]; do
    curl \
      --fail \
      -s -X GET \
      -u "${ES_USERNAME}:${ES_PASSWORD}" \
      "${ES_URL}"/"${INDEX}"/_search -H 'Content-Type: application/json' -d"
    {
      \"query\": {
        \"bool\": {
          \"must\": [],
          \"filter\": [
            {
              \"match_all\": {}
            },
            {
              \"match_phrase\": {
                \"local_metadata.host.hostname\": \"${VM_NAME}\"
              }
            },
            {
              \"match_phrase\": {
                \"active\": true
              }
            }
          ],
          \"must_not\": [
            {
              \"match_phrase\": {
                \"policy_id\": \"policy-elastic-agent-on-cloud\"
              }
            }
          ]
        }
      }
    }
    " > "${temp_file}" || RESULT=1
    IT=$((IT+1))
    sleep 5
  done
  jq -e '.hits.total.value >= 1' "${temp_file}" > /dev/null || RESULT=1
  verify "$INDEX" $RESULT "${temp_file}"
}

function verify() {
  INDEX=$1
  RESULT=$2
  FILE=$3
  if [ $RESULT -gt 0 ]; then
    printf '\tTest assertion FAILED for%s\n' "$INDEX"
    STATUS=1
  else
    printf '\tTest assertion PASSED for%s\n' "$INDEX"
  fi
  printf '\t\toutput\n'
  cat "${FILE}"
}

###############
### Main
###############

### Default status
STATUS=0

### Print indices
curl -s -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/_cat/indices

INDEX='.fleet-agents-7'
echo "Validate the agent enrolment ${VM_NAME} in ${INDEX}"
search "${INDEX}"

for INDEX in '.ds-metrics-system.memory-default-*' '.ds-metrics-system.cpu-default-*' '.ds-metrics-system.diskio-default-*' ; do
  echo "Validate whether the metric data streams are sending data for ${VM_NAME} in ${INDEX}"
  count "${INDEX}"
done

if [ "${IS_WINDOWS}" == "true" ] ; then
  for INDEX in '.ds-logs-system.application-default-*' ; do
    echo "Validate whether the logs are coming in for ${VM_NAME} in ${INDEX}"
    count "${INDEX}"
  done
else
  for INDEX in '.ds-logs-system.syslog-default-*' ; do
    echo "Validate whether the logs are coming in for ${VM_NAME} in ${INDEX}"
    count "${INDEX}"
  done
fi

exit $STATUS
