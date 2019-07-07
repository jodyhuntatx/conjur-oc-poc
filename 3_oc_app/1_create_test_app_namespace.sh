#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

announce "Creating Test App namespace."
set_namespace default
if has_namespace "$TEST_APP_NAMESPACE_NAME"; then
  echo "Namespace '$TEST_APP_NAMESPACE_NAME' exists, not going to create it."
  set_namespace $TEST_APP_NAMESPACE_NAME
else
  echo "Creating '$TEST_APP_NAMESPACE_NAME' namespace."
  $CLI new-project $TEST_APP_NAMESPACE_NAME
  set_namespace $TEST_APP_NAMESPACE_NAME
fi

# taint nodes
$CLI adm taint nodes --overwrite=true $CONJUR_APP_NODES $CONJUR_APP_TAINT=$CONJUR_APP_TAINT:NoSchedule  

announce "Creating authenticator role binding."
$CLI delete --ignore-not-found rolebinding test-app-conjur-authenticator-role-binding-$FOLLOWER_NAMESPACE_NAME
sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" ./deploy-configs/test-app-conjur-authenticator-role-binding.yml |
  sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" |
  $CLI create -f -

# add permissions for Conjur admin user
announce "Setting RBAC privileges."
oc adm policy add-role-to-user system:registry $DEVELOPER_USERNAME
oc adm policy add-role-to-user system:image-builder $DEVELOPER_USERNAME
oc adm policy add-role-to-user admin $DEVELOPER_USERNAME -n $TEST_APP_NAMESPACE_NAME
