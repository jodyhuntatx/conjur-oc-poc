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

# check if CONJUR_VERSION is consistent with CONJUR_APPLIANCE_IMAGE
appliance_tag=${CONJUR_APPLIANCE_IMAGE//[A-Za-z.]*:/}
appliance_version=${appliance_tag//[.-][0-9A-Za-z.-]*/}
if [ "${appliance_version}" != "$CONJUR_VERSION" ]; then
  echo "ERROR! Your appliance does not match the specified Conjur version."
  exit 1
fi

check_env_var "FOLLOWER_SEED_FILE"
if [[ ! -f "${FOLLOWER_SEED_FILE}" ]]; then
  echo "ERROR! Follower seed path '${FOLLOWER_SEED_FILE}' does not point to a file!"
  exit 1
fi
