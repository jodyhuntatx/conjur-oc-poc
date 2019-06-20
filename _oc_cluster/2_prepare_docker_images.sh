#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  
  docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH

  prepare_conjur_appliance_image
  prepare_conjur_cli_image

  echo "Docker images pushed."
}

########################
prepare_conjur_appliance_image() {
  announce "Tagging and pushing Conjur appliance"

  conjur_appliance_image=$(platform_image conjur-appliance)
  docker tag $CONJUR_APPLIANCE_IMAGE $conjur_appliance_image

  if ! is_minienv; then
    docker push $conjur_appliance_image
  fi
}

########################
prepare_conjur_cli_image() {
  announce "Pushing Conjur CLI image."

  cli_app_image=$(platform_image conjur-cli)
  docker tag $CLI_IMAGE_NAME $cli_app_image

  if ! is_minienv; then
    docker push $cli_app_image
  fi
}

main "$@"
