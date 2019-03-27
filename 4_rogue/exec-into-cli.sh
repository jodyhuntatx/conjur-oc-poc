#!/bin/bash -x

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh
source ./rogue.config

set_namespace $CONJUR_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)
$cli exec -it $conjur_cli_pod -- bash
