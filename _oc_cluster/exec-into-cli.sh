#!/bin/bash

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

set_namespace $FOLLOWER_NAMESPACE_NAME
conjur_cli_pod=$(get_conjur_cli_pod_name)
$CLI exec -it $conjur_cli_pod -- bash
