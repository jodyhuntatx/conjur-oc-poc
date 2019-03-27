#!/bin/bash 

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

set_namespace $CONJUR_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)
$cli exec -it $conjur_cli_pod -- bash
