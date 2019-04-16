#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

check_env_var "CONJUR_APPLIANCE_IMAGE"
check_env_var "CONJUR_NAMESPACE_NAME"
check_env_var "AUTHENTICATOR_ID"

if [ ! is_minienv ]; then
  check_env_var "DOCKER_REGISTRY_PATH"
fi

check_env_var "OSHIFT_CONJUR_ADMIN_USERNAME"
check_env_var "CONJUR_VERSION"
check_env_var "CONJUR_ACCOUNT"
check_env_var "CONJUR_ADMIN_PASSWORD"
