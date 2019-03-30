#!/bin/bash

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

if [[ $# != 1 ]]; then
  echo "specify 'init' or 'side'"
  exit -1
fi
set_namespace $TEST_APP_NAMESPACE_NAME
app_pod=$($cli get pods | grep $1 | awk '{print $1}')
$cli exec -it $app_pod -- bash
