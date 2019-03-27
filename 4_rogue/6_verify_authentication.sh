#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh
source ./rogue.config

clear

set_namespace $TEST_APP_NAMESPACE_NAME

announce "Retrieving secrets with access token using sidecar config."
sidecar_api_pod=$($cli get pods --no-headers -l app=test-app-summon-sidecar | awk '{ print $1 }')
if [[ "$sidecar_api_pod" != "" ]]; then
    echo "Sidecar + REST API: $($cli exec -c test-app $sidecar_api_pod -- /webapp.sh)"
    echo "Sidecar + Summon:"
    echo "$($cli exec -c test-app $sidecar_api_pod -- summon /webapp_summon.sh)"
fi

announce "Retrieving secrets with access token using init container config."
init_api_pod=$($cli get pods --no-headers -l app=test-app-summon-init | awk '{ print $1 }')
if [[ "$init_api_pod" != "" ]]; then
    echo
    echo "Init Container + REST API: $($cli exec -c test-app $init_api_pod -- /webapp.sh)"
    echo "Init Container + Summon:"
    echo "$($cli exec -c test-app $init_api_pod -- summon /webapp_summon.sh)"
fi
