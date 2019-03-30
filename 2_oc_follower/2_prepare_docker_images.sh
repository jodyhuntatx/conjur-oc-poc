#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
  prepare_conjur_appliance_image
  echo "Docker images pushed."
}

prepare_conjur_appliance_image() {
  announce "Tagging and pushing Conjur appliance"

  conjur_appliance_image=$(platform_image conjur-appliance)
  docker tag $CONJUR_APPLIANCE_IMAGE $conjur_appliance_image

  if ! is_minienv; then
    docker push $conjur_appliance_image
  fi
}

main $@
