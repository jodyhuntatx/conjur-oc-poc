#!/bin/bash
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH

announce "Building and pushing test app images."

# Tag authenticator image with registry/namespace prefix & namespace tag
authenticator_image_tag="$DOCKER_REGISTRY_PATH/$TEST_APP_NAMESPACE_NAME/conjur-authn-k8s-client:$TEST_APP_NAMESPACE_NAME"
docker tag $AUTHENTICATOR_CLIENT_IMAGE $authenticator_image_tag
docker push $authenticator_image_tag

readonly APPS=(
  "init"
  "sidecar"
)

pushd test-app
  if $CONNECTED; then
    ./build.sh
  fi
  for app_type in "${APPS[@]}"; do
    test_app_image="$DOCKER_REGISTRY_PATH/$TEST_APP_NAMESPACE_NAME/test-$app_type-app:$TEST_APP_NAMESPACE_NAME"
    docker tag test-app:latest $test_app_image
    docker push $test_app_image
  done
popd
