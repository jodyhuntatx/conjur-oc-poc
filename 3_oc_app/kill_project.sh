#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

set_namespace default

$CLI login -u $CLUSTER_ADMIN_USERNAME

if has_namespace $TEST_APP_NAMESPACE_NAME; then
  $CLI delete namespace $TEST_APP_NAMESPACE_NAME >& /dev/null &

  printf "Waiting for $TEST_APP_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "..."
    
    if has_namespace "$TEST_APP_NAMESPACE_NAME"; then
      sleep 5
    else
      break
    fi
  done

  echo ""
fi

set +e
test_sidecar_app_docker_image=$(app_image test-sidecar-app)
test_init_app_docker_image=$(app_image test-init-app)
docker rmi $test_sidecar_app_docker_image $test_init_app_docker_image &> /dev/null

echo "Test app environment purged."
