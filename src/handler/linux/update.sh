#!/usr/bin/env bash
set -euo pipefail
script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

#update script is ran at update time during a vm extension update, will set flag that this is an update operation

log "INFO" "[Update_ElasticAgent] set update environment variable"
set_update_var
