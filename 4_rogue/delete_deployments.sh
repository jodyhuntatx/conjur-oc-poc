#!/bin/bash

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh
source ./rogue.config

oc login -u $OSHIFT_CLUSTER_ADMIN_USERNAME >& /dev/null
set_namespace $TEST_APP_NAMESPACE_NAME

announce "Deleting image pull secret."
$cli delete --ignore-not-found secrets dockerpullsecret

announce "Deleting test app/sidecar deployment."
$cli delete dc/test-app-summon-sidecar
$cli delete dc/test-app-summon-init

echo "Waiting for pods to terminate"
until [[ "$(oc get pods 2>&1)" == "No resources found." ]]; do
  sleep 4
  echo -n '.'
done
echo

echo "Test app deleted."
