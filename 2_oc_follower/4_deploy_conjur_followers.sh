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
copy_conjur_config_map() {
  $CLI delete --ignore-not-found cm $CONJUR_CONFIG_MAP
  $CLI get cm $CONJUR_CONFIG_MAP -n default -o yaml \
    | sed "s/namespace: default/namespace: $FOLLOWER_NAMESPACE_NAME/" \
    | $CLI create -f -
}

###########################
enable_conjur_authentication() {
  # if FOLLOWER_SEED env var begins with http...
  if [[ "${FOLLOWER_SEED}" =~ ^http[s]?:// ]]; then
    announce "Creating conjur service account and authenticator role binding."

    sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" "./deploy-configs/conjur-authenticator-role-binding.yaml" |
        $CLI create -f -
  fi
}

###########################
deploy_conjur_followers() {
  announce "Deploying Conjur Follower pods."

  conjur_appliance_image=$(conjur_image "conjur-appliance")
  seed_fetcher_image=$(conjur_image "seed-fetcher")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/conjur-follower.yaml" |
    sed -e "s#{{ CONJUR_CONFIG_MAP }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_NAME }}#$CONJUR_MASTER_HOST_NAME#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_IP }}#$CONJUR_MASTER_HOST_IP#g" |
    sed -e "s#{{ CONJUR_MASTER_PORT }}#$CONJUR_MASTER_PORT#g" |
    sed -e "s#{{ CONJUR_SEED_FETCHER_IMAGE }}#$seed_fetcher_image#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_FOLLOWER_COUNT }}#${CONJUR_FOLLOWER_COUNT}#g" |
    $CLI create -f -

    echo "Creating passthrough route for conjur-follower service."
    $CLI create route passthrough --service=conjur-follower
}

main $@
