#!/bin/bash 
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $CONJUR_NAMESPACE_NAME
  docker_login
  deploy_conjur_followers

  sleep 10

  update_follower_san  # NOTE: requires docker access to Conjur master

  echo "Followers created."
}

docker_login() {
  announce "Creating image pull secret."

  $cli delete --ignore-not-found secrets dockerpullsecret

  $cli secrets new-dockercfg dockerpullsecret \
         --docker-server=${DOCKER_REGISTRY_PATH} \
         --docker-username=_ \
         --docker-password=$($cli whoami -t) \
         --docker-email=_

  $cli secrets add serviceaccount/conjur-cluster secrets/dockerpullsecret --for=pull
}

deploy_conjur_followers() {
  announce "Deploying Conjur Follower pods."

  conjur_appliance_image=$(platform_image "conjur-appliance")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/conjur-follower.yaml" |
    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_FOLLOWER_COUNT }}#${CONJUR_FOLLOWER_COUNT}#g" |
    $cli create -f -

    echo "Creating passthrough route for conjur-follower service."
    $cli create route passthrough --service=conjur-follower
}

update_follower_san() {
  announce "Updating Follower cert and seed file with OC route SAN."

  # get route endpoint
  conjur_follower_route=$(oc get routes | grep conjur-follower | awk '{ print $2 }')

  # reissue cert w/ additional SAN
  docker exec $CONJUR_MASTER_CONTAINER_NAME evoke ca issue --force conjur-follower $FOLLOWER_ALTNAMES $conjur_follower_route

  echo "Updated conjur-follower cert SAN:"
  docker exec $CONJUR_MASTER_CONTAINER_NAME openssl x509 -in /opt/conjur/etc/ssl/conjur-follower.pem -text | grep DNS

  echo "Regenerating seed file..."
  docker exec $CONJUR_MASTER_CONTAINER_NAME evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE
}

main $@
