#!/bin/bash

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

# This script requires OpenShift/K8s cluster admin privileges

#################
main() {
  announce "Initializing Follower authentication."

  whitelist_authenticators
  apply_manifest
  initialize_variables
}

###################################
whitelist_authenticators() {
  echo "Updating list of whitelisted authenticators..."

  master_pod_name=$(get_master_pod_name)

  $CLI exec $master_pod_name -- bash -c \
    "echo CONJUR_AUTHENTICATORS=\"authn,authn-k8s/$AUTHENTICATOR_ID\" >> \
      /opt/conjur/etc/conjur.conf && \
        sv restart conjur"

  echo "Waiting for Master service to come back up after restart."
  conjur_master_route=$($CLI get routes | grep conjur-master | awk '{ print $2 }')
  wait_for_service_200 "https://$conjur_master_route/health"

  echo "Authenticators updated."
}

###################################
apply_manifest() {
  echo "Applying manifest in cluster..."

  sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" \
     ./deploy-configs/templates/conjur-follower-authn.template.yaml  \
     > ./deploy-configs/conjur-follower-authn-$FOLLOWER_NAMESPACE_NAME.yaml

  $CLI apply -f ./deploy-configs/conjur-follower-authn-$FOLLOWER_NAMESPACE_NAME.yaml

  echo "Manifest applied."
}

###################################
initialize_variables() {
  echo "Initializing variables..."

  # Use a cap-D for decoding on Macs
  if [[ "$(uname -s)" == "Linux" ]]; then
    BASE64D="base64 -d"
  else
    BASE64D="base64 -D"
  fi

  TOKEN_SECRET_NAME="$($CLI get secrets -n $FOLLOWER_NAMESPACE_NAME \
    | grep 'conjur.*service-account-token' \
    | head -n1 \
    | awk '{print $1}')"

  echo "Initializing cluster ca cert..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/ca-cert \
    "$($CLI get secret -n $FOLLOWER_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r '.data["ca.crt"]' \
      | $BASE64D)"

  echo "Initializing service-account token..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/service-account-token \
    "$($CLI get secret -n $FOLLOWER_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r .data.token \
      | $BASE64D)"

  echo "Initializing cluster API URL..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/api-url \
    "$($CLI config view --minify -o yaml | grep server | awk '{print $2}')"
}

main "$@"
