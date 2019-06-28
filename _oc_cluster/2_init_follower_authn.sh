#!/bin/bash

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

# This script requires running w/ cluster admin privileges

#################
main() {
  announce "Initializing Follower authentication."

  initialize_conjur_config_map
  apply_manifest
  initialize_variables
}

###################################
initialize_conjur_config_map() {
  echo "Creating Conjur config map." 

  $CLI delete --ignore-not-found=true -n default configmap $CONJUR_CONFIG_MAP

  # Get master URL
  master_url="https://$($CLI get routes -n $FOLLOWER_NAMESPACE_NAME | grep conjur-master | awk '{ print $2 }')"
  # Get master cert
  # master_cert=$(./get_cert_REST.sh $CONJUR_MASTER_HOST_NAME $CONJUR_MASTER_PORT)
  master_cert=$(cat "$MASTER_CERT_FILE")

  # Get Follower URL
  follower_url="https://$CONJUR_FOLLOWER_SERVICE_NAME"
  # Get Follwer cert
  # follower_cert=$(./get_cert_REST.sh $CONJUR_MASTER_HOST_NAME $CONJUR_FOLLOWER_PORT)
  follower_cert=$(cat "$FOLLOWER_CERT_FILE")

  $CLI create configmap $CONJUR_CONFIG_MAP \
	-n default \
	--from-literal=follower-namespace-name="$FOLLOWER_NAMESPACE_NAME" \
        --from-literal=conjur-master-url=$master_url \
	--from-literal=master-certificate="$master_cert" \
        --from-literal=conjur-follower-url=$follower_url \
	--from-literal=follower-certificate="$follower_cert" \
        --from-literal=conjur-account="$CONJUR_ACCOUNT" \
        --from-literal=conjur-version="$CONJUR_VERSION" \
        --from-literal=conjur-authenticators="$CONJUR_AUTHENTICATORS" \
        --from-literal=authenticator-id="$AUTHENTICATOR_ID" \
        --from-literal=conjur-seed-file-url="$CONJUR_SEED_FILE_URL" \
        --from-literal=conjur-authn-token-file="/run/conjur/access-token" \
        --from-literal=conjur-authn-login-cluster="$CONJUR_CLUSTER_LOGIN"

  echo "Conjur cert stored."
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

  echo "Variables initialized."
}

main "$@"
