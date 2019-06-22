#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

announce "Logging in as cluster admin:" $OSHIFT_CLUSTER_ADMIN_USERNAME
oc login -u $OSHIFT_CLUSTER_ADMIN_USERNAME

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

announce "Creating authenticator role binding."
$CLI delete --ignore-not-found rolebinding test-app-conjur-authenticator-role-binding-$CONJUR_NAMESPACE_NAME
sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" ./deploy-configs/test-app-conjur-authenticator-role-binding.yml |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" |
  $CLI create -f -

announce "Setting RBAC privileges."
# add permissions for Conjur admin user
oc adm policy add-role-to-user system:registry $OSHIFT_CONJUR_ADMIN_USERNAME
oc adm policy add-role-to-user system:image-builder $OSHIFT_CONJUR_ADMIN_USERNAME
oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n default
oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n $TEST_APP_NAMESPACE_NAME

announce "Logging in as Conjur admin:" $OSHIFT_CONJUR_ADMIN_USERNAME
oc login -u $OSHIFT_CONJUR_ADMIN_USERNAME
