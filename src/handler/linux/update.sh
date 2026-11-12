#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

#update script is ran at update time during a vm extension update, will set flag that this is an update operation

# continueOnUpdateFailure allows recovery from the old handler's uninstall,
# but a failed disable must still stop the upgrade before uninstall runs.
# On retries the old handler may already be disabled; Azure then passes "None".
case "${AZURE_GUEST_AGENT_DISABLE_CMD_EXIT_CODE:-NOT_RUN}" in
  ""|0|NOT_RUN|None) ;;
  *)
    log "ERROR" "[Update_ElasticAgent] Previous handler failed to disable; stopping update"
    exit 1
    ;;
esac

log "INFO" "[Update_ElasticAgent] set update environment variable"
set_update_var
