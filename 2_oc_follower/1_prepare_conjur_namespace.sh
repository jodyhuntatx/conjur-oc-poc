#!/bin/bash 
set -euo pipefail

# This scripts requires running w/ cluster admin privileges

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace default
  create_conjur_namespace
  create_service_account
  create_cluster_role
  configure_oc_rbac
}

create_conjur_namespace() {
  announce "Creating Conjur namespace."
  
  if has_namespace "$CONJUR_NAMESPACE_NAME"; then
    echo "Namespace '$CONJUR_NAMESPACE_NAME' exists, not going to create it."
    set_namespace $CONJUR_NAMESPACE_NAME
  else
    echo "Creating '$CONJUR_NAMESPACE_NAME' namespace."
    oc new-project $CONJUR_NAMESPACE_NAME
    set_namespace $CONJUR_NAMESPACE_NAME
  fi
}

create_service_account() {
    if has_serviceaccount $CONJUR_SERVICEACCOUNT_NAME; then
        echo "Service account '$CONJUR_SERVICEACCOUNT_NAME' exists, not going to create it."
    else
        $CLI create serviceaccount $CONJUR_SERVICEACCOUNT_NAME -n $CONJUR_NAMESPACE_NAME
    fi
}

create_cluster_role() {
  $CLI delete --ignore-not-found clusterrole conjur-authenticator-$CONJUR_NAMESPACE_NAME

  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" ./deploy-configs/conjur-authenticator-role.yaml > ./deploy-configs/conjur-authenticator-role-$CONJUR_NAMESPACE_NAME.yaml
    $CLI apply -f ./deploy-configs/conjur-authenticator-role-$CONJUR_NAMESPACE_NAME.yaml
}

configure_oc_rbac() {
  echo "Configuring OpenShift admin permissions."
  
  # allow pods with conjur-cluster serviceaccount to run as root
  oc adm policy add-scc-to-user anyuid "system:serviceaccount:$CONJUR_NAMESPACE_NAME:$CONJUR_SERVICEACCOUNT_NAME"

  # add permissions for Conjur admin user on registry, default & Conjur cluster namespaces
  oc adm policy add-role-to-user system:registry $OSHIFT_CONJUR_ADMIN_USERNAME
  oc adm policy add-role-to-user system:image-builder $OSHIFT_CONJUR_ADMIN_USERNAME
  oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n default
  oc adm policy add-role-to-user admin $OSHIFT_CONJUR_ADMIN_USERNAME -n $CONJUR_NAMESPACE_NAME

  echo "Logging in as Conjur admin user, provide password as needed..."
  oc login -u $OSHIFT_CONJUR_ADMIN_USERNAME
}

main $@
