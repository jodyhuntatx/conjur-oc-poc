#!/bin/bash 

source ../config/cluster.config
source ../config/$PLATFORM.config

# This scripts requires running w/ cluster admin privileges

#################
main() {
  apply_manifest
  initialize_variables
  initialize_config_map
}

###################################
apply_manifest() {
  echo "Applying manifest in cluster..."

  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$CONJUR_NAMESPACE_NAME#g" \
     ./deploy-configs/conjur-follower-authn.template.yaml \
    > ./deploy-configs/conjur-follower-authn.yaml
  $CLI apply -f ./deploy-configs/conjur-follower-authn.yaml

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

  TOKEN_SECRET_NAME="$($CLI get secrets -n $CONJUR_NAMESPACE_NAME \
    | grep 'conjur.*service-account-token' \
    | head -n1 \
    | awk '{print $1}')"

  echo "Initializing cluster ca cert..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/ca-cert \
    "$($CLI get secret -n $CONJUR_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r '.data["ca.crt"]' \
      | $BASE64D)"

  echo "Initializing service-account token..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/service-account-token \
    "$($CLI get secret -n $CONJUR_NAMESPACE_NAME $TOKEN_SECRET_NAME -o json \
      | jq -r .data.token \
      | $BASE64D)"

  echo "Initializing cluster API URL..."
  ./var_value_add_REST.sh \
    conjur/authn-k8s/$AUTHENTICATOR_ID/kubernetes/api-url \
    "$($CLI config view --minify -o yaml | grep server | awk '{print $2}')"

  echo "Variables initialized."
}

###################################
initialize_config_map() {
  echo "Storing Conjur cert in config map for cluster apps to use."

  $CLI delete --ignore-not-found=true -n default configmap $CONJUR_CONFIG_MAP

  # Fetch Conjur Follower cert and store in a ConfigMap in the default project.
  # follower_cert=$(./get_cert_REST.sh $CONJUR_MASTER_HOST_NAME $CONJUR_FOLLOWER_PORT)
  follower_cert=$(cat "$FOLLOWER_CERT_FILE")
  $CLI create configmap -n default $CONJUR_CONFIG_MAP --from-literal=ssl-certificate="$follower_cert"

  echo "Conjur cert stored."
}

main "$@"
