#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME
  docker_login

  copy_conjur_config_map
  deploy_conjur_followers
  enable_conjur_authentication
  re_create_conjur_config_map

  echo "Followers created."
}

###########################
docker_login() {
  announce "Creating image pull secret."

  $CLI delete --ignore-not-found secrets dockerpullsecret

  $CLI secrets new-dockercfg dockerpullsecret \
         --docker-server=${DOCKER_REGISTRY_PATH} \
         --docker-username=_ \
         --docker-password=$($CLI whoami -t) \
         --docker-email=_

  $CLI secrets add serviceaccount/conjur-cluster secrets/dockerpullsecret --for=pull
}

###########################
# Get copy of conjur configmap from default namespace
copy_conjur_config_map() {
  $CLI delete --ignore-not-found cm $CONJUR_CONFIG_MAP
  $CLI get cm $CONJUR_CONFIG_MAP -n default -o yaml \
    | sed "s/namespace: default/namespace: $FOLLOWER_NAMESPACE_NAME/" \
    | $CLI create -f -
}

###########################
enable_conjur_authentication() {
  echo "Creating seed-fetcher authenticator role binding."

  sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" "./deploy-configs/templates/conjur-authenticator-role-binding.template.yaml" \
    > ./deploy-configs/conjur-authenticator-role-binding-$FOLLOWER_NAMESPACE_NAME.yaml

  $CLI create -f ./deploy-configs/conjur-authenticator-role-binding-$FOLLOWER_NAMESPACE_NAME.yaml
}

###########################
deploy_conjur_followers() {
  announce "Deploying Conjur Follower pods."

  conjur_appliance_image=$(conjur_image "conjur-appliance")
  seed_fetcher_image=$(conjur_image "seed-fetcher")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/templates/conjur-follower.template.yaml" |
    sed -e "s#{{ CONJUR_CONFIG_MAP }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_NAME }}#$CONJUR_MASTER_HOST_NAME#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_IP }}#$CONJUR_MASTER_HOST_IP#g" |
    sed -e "s#{{ CONJUR_MASTER_PORT }}#$CONJUR_MASTER_PORT#g" |
    sed -e "s#{{ CONJUR_SEED_FETCHER_IMAGE }}#$seed_fetcher_image#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_FOLLOWER_COUNT }}#${CONJUR_FOLLOWER_COUNT}#g" \
    > ./deploy-configs/conjur-follower-$FOLLOWER_NAMESPACE_NAME.yaml

  $CLI create -f ./deploy-configs/conjur-follower-$FOLLOWER_NAMESPACE_NAME.yaml

  echo "Creating passthrough route for conjur-follower service."
  $CLI create route passthrough --service=conjur-follower

  echo "Waiting for Follower service to initialize - usually takes about 60 seconds."
  conjur_follower_route=$($CLI get routes | grep conjur-follower | awk '{ print $2 }')
  wait_for_service_200 "https://$conjur_follower_route/health"
}

###################################
# Adds follower url & cert to Conjur config map
#
re_create_conjur_config_map() {
  echo "Creating Conjur config map."

  $CLI delete --ignore-not-found=true -n default configmap $CONJUR_CONFIG_MAP

  # Get master cert from file
  master_url="https://$CONJUR_MASTER_HOST_NAME:$CONJUR_MASTER_PORT"
  master_cert=$(cat "$MASTER_CERT_FILE")
  conjur_seed_file_url=$master_url/configuration/$CONJUR_ACCOUNT/seed/follower

  # cat Follower cert to cert file
  follower_url="https://$CONJUR_FOLLOWER_SERVICE_NAME"
  follower_pod_name=$($CLI get pods | grep conjur-follower | tail -1 | awk '{print $1}')
  follower_cert="$($CLI exec $follower_pod_name -- cat /opt/conjur/etc/ssl/conjur.pem)"
  echo "$follower_cert" > $FOLLOWER_CERT_FILE

  $CLI create configmap $CONJUR_CONFIG_MAP \
	-n default \
	--from-literal=follower-namespace-name="$FOLLOWER_NAMESPACE_NAME" \
        --from-literal=conjur-master-url=$master_url 			\
	--from-literal=master-certificate="$master_cert" 		\
        --from-literal=conjur-seed-file-url="$conjur_seed_file_url" 	\
        --from-literal=conjur-follower-url=$follower_url 		\
	--from-literal=follower-certificate="$follower_cert" 		\
        --from-literal=conjur-authn-login-cluster="$CONJUR_CLUSTER_LOGIN" \
        --from-literal=conjur-account="$CONJUR_ACCOUNT" 		\
        --from-literal=conjur-version="$CONJUR_VERSION" 		\
        --from-literal=conjur-authenticators="$CONJUR_AUTHENTICATORS" 	\
        --from-literal=authenticator-id="$AUTHENTICATOR_ID" 		\
        --from-literal=conjur-authn-token-file="/run/conjur/access-token"

  echo "Conjur config map created."
}

main $@
