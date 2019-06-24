#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

check_env_var "CONJUR_APPLIANCE_IMAGE"
check_env_var "FOLLOWER_NAMESPACE_NAME"
check_env_var "AUTHENTICATOR_ID"

if [ ! is_minienv ]; then
  check_env_var "DOCKER_REGISTRY_PATH"
fi

check_env_var "CLUSTER_ADMIN_USERNAME"
check_env_var "FOLLOWER_ADMIN_USERNAME"
check_env_var "DEVELOPER_USERNAME"

check_env_var "FOLLOWER_SEED_FILE"
if [[ ! -f "${FOLLOWER_SEED_FILE}" ]]; then
  echo "ERROR! Follower seed path '${FOLLOWER_SEED_FILE}' does not point to a file!"
  exit 1
fi
