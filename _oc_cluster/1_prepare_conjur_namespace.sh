#!/bin/bash
set -euo pipefail

# This script must be run with cluster admin privileges

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

main() {
  set_namespace default
  taint_nodes
  initialize_namespace
  create_service_account
  create_cluster_role
  apply_follower_authn_manifest
  configure_oc_rbac
}

###################################
taint_nodes() {
  oc adm taint nodes --overwrite=true $CONJUR_MASTER_NODE \
	$CONJUR_MASTER_TAINT_KEY=$CONJUR_MASTER_TAINT_VALUE:NoSchedule  
  oc adm taint nodes --overwrite=true $CONJUR_FOLLOWER_NODES \
	$CONJUR_FOLLOWER_TAINT_KEY=$CONJUR_FOLLOWER_TAINT_VALUE:NoSchedule  
}

###################################
initialize_namespace() {
  announce "Creating Follower namespace."

  if has_namespace "$FOLLOWER_NAMESPACE_NAME"; then
    echo "Namespace '$FOLLOWER_NAMESPACE_NAME' exists, not going to create it."
    set_namespace $FOLLOWER_NAMESPACE_NAME
  else
    echo "Creating '$FOLLOWER_NAMESPACE_NAME' namespace."
    oc new-project $FOLLOWER_NAMESPACE_NAME
    set_namespace $FOLLOWER_NAMESPACE_NAME
  fi
}

###################################
create_service_account() {
    if has_serviceaccount $CONJUR_SERVICEACCOUNT_NAME; then
        echo "Service account '$CONJUR_SERVICEACCOUNT_NAME' exists, not going to create it."
    else
        $CLI create serviceaccount $CONJUR_SERVICEACCOUNT_NAME -n $FOLLOWER_NAMESPACE_NAME
    fi
}

###################################
create_cluster_role() {
  $CLI delete --ignore-not-found clusterrole conjur-authenticator-$FOLLOWER_NAMESPACE_NAME

  sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" ./deploy-configs/templates/conjur-authenticator-role.template.yaml \
    > ./deploy-configs/conjur-authenticator-role-$FOLLOWER_NAMESPACE_NAME.yaml

  $CLI apply -f ./deploy-configs/conjur-authenticator-role-$FOLLOWER_NAMESPACE_NAME.yaml
}

###################################
apply_follower_authn_manifest() {
  echo "Applying manifest in cluster..."

  sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" \
     ./deploy-configs/templates/conjur-follower-authn.template.yaml  \
     > ./deploy-configs/conjur-follower-authn-$FOLLOWER_NAMESPACE_NAME.yaml

  $CLI apply -f ./deploy-configs/conjur-follower-authn-$FOLLOWER_NAMESPACE_NAME.yaml

  echo "Manifest applied."
}

##################
configure_oc_rbac() {
  echo "Configuring OpenShift admin permissions."
  
  # allow pods with conjur-cluster serviceaccount to run as root
  oc adm policy add-scc-to-user anyuid "system:serviceaccount:$FOLLOWER_NAMESPACE_NAME:$CONJUR_SERVICEACCOUNT_NAME"

  # add permissions for Conjur admin user on registry, default & Conjur cluster namespaces
  oc adm policy add-role-to-user system:registry $FOLLOWER_ADMIN_USERNAME
  oc adm policy add-role-to-user system:image-builder $FOLLOWER_ADMIN_USERNAME
  oc adm policy add-role-to-user admin $FOLLOWER_ADMIN_USERNAME -n $FOLLOWER_NAMESPACE_NAME
}

main "$@"
