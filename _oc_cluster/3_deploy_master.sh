#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME

  docker_login

  deploy_conjur_master_cluster
  deploy_conjur_cli

  sleep 10

  wait_for_conjur
  
  echo "Master cluster created."
}

######################
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

######################
deploy_conjur_master_cluster() {
  announce "Deploying Conjur Master cluster pods."

  conjur_appliance_image=$(conjur_image "conjur-appliance")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/conjur-master.yaml" |
      sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
      sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
      $CLI create -f -

}

######################
deploy_conjur_cli() {
  announce "Deploying Conjur CLI pod."
  cli_app_image=$(conjur_image conjur-cli)
  sed -e "s#{{ DOCKER_IMAGE }}#$cli_app_image#g" ./deploy-configs/conjur-cli.yml |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    $CLI create -f -
}

######################
wait_for_conjur() {
  echo "Waiting for Conjur pods to launch..."
  conjur_pod_count=1
  wait_for_it 300 "$CLI describe po conjur-master | grep Status: | grep -c Running | grep -q $conjur_pod_count"
}

main "$@"
