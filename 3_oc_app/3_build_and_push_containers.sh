#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH

announce "Building and pushing test app images."

authenticator_image=$(app_image conjur-authn-k8s-client)
docker tag $AUTHENTICATOR_CLIENT_IMAGE $authenticator_image
docker push $authenticator_image

readonly APPS=(
  "init"
  "sidecar"
)

pushd test-app
  ./build.sh
  for app_type in "${APPS[@]}"; do
    test_app_image=$(app_image "test-$app_type-app")
    docker tag test-app:$TEST_APP_NAMESPACE_NAME $test_app_image
    docker push $test_app_image
  done
popd
