#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

check_env_var "CONJUR_VERSION"
check_env_var "FOLLOWER_NAMESPACE_NAME"
check_env_var "TEST_APP_NAMESPACE_NAME"
check_env_var "DOCKER_REGISTRY_PATH"
check_env_var "CONJUR_ACCOUNT"
check_env_var "CONJUR_ADMIN_PASSWORD"
check_env_var "AUTHENTICATOR_ID"
