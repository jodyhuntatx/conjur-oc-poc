#!/bin/bash

CLI=oc

if [[ $# != 1 ]]; then
  echo "specify 'init' or 'side'"
  exit -1
fi

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

set_namespace $TEST_APP_NAMESPACE_NAME
app_pod=$($CLI get pods | grep $1 | awk '{print $1}')
$CLI exec -it $app_pod -- bash
