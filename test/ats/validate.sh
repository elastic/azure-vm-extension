#!/usr/bin/env bash
set -eo pipefail

ES_USERNAME=${1:?'Missing the Username:Password'}
ES_PASSWORD=${2:?'Missing the Username:Password'}
ES_URL=${3:?'Missing the Elasticsearch URL'}
VM_NAME=${4:?'Missing the VM name'}

RE='[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'
# shellcheck disable=SC2001
MAJOR=$(echo "$ELASTIC_STACK_VERSION" | sed -e "s#$RE#\1#")
# shellcheck disable=SC2001
MINOR=$(echo "$ELASTIC_STACK_VERSION" | sed -e "s#$RE#\2#")
if [ "${MAJOR}" -lt "8" ] && [ "${MINOR}" -le "12" ] ; then
	echo "Validation is enabled only from 7.13+"
	exit 0
fi

echo "(1/4) Query the agent enrollment ${VM_NAME}"
curl -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/.fleet-agents-7/_search -H 'Content-Type: application/json' -d"
   \"query\": {
    \"match\": {
      \"local_metadata.host.hostname\": \"${VM_NAME}\"
    }
  }
}
" --output query.json

echo "(2/4) Validate the agent enrollment ${VM_NAME}"
jq -e '._source.policy_id != "policy-elastic-agent-on-cloud" and ._source.active == false' query.json

echo "(3/4) Validate whether the metric data streams are sending data for ${VM_NAME}"
curl -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/.ds-metrics-system.memory-default-*/_count -H 'Content-Type: application/json' -d"
   \"query\": {
    \"match\": {
      \"agent.hostname\": \"${VM_NAME}\"
    }
  }
}
"

curl -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/.ds-metrics-system.cpu-default-*/_count -H 'Content-Type: application/json' -d"
   \"query\": {
    \"match\": {
      \"agent.hostname\": \"${VM_NAME}\"
    }
  }
}
"

curl -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/.ds-metrics-system.diskio-default-/_count -H 'Content-Type: application/json' -d"
   \"query\": {
    \"match\": {
      \"agent.hostname\": \"${VM_NAME}\"
    }
  }
}
"

echo "(4/4) Validate whether the logs are coming in for ${VM_NAME}"
curl -X GET -u "${ES_USERNAME}:${ES_PASSWORD}" "${ES_URL}"/.ds-logs-system.application-default-*/_count -H 'Content-Type: application/json' -d"
   \"query\": {
    \"match\": {
      \"agent.hostname\": \"${VM_NAME}\"
    }
  }
}
"
