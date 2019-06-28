#!/bin/bash 
set -eo pipefail

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME

  docker_login

  deploy_conjur_followers

  sleep 10

  echo "Followers created."
}

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

deploy_conjur_followers() {
  announce "Deploying Conjur Follower pods."

  conjur_appliance_image=$(conjur_image "conjur-appliance")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/conjur-follower.yaml" |
    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_FOLLOWER_COUNT }}#${CONJUR_FOLLOWER_COUNT}#g" |
    $CLI create -f -
}

main $@
