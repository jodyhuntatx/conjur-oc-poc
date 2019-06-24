#!/bin/bash
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

$CLI login -u $CLUSTER_ADMIN_USERNAME

set_namespace default

if has_namespace $FOLLOWER_NAMESPACE_NAME; then
  $CLI delete namespace $FOLLOWER_NAMESPACE_NAME >& /dev/null &

  printf "Waiting for $FOLLOWER_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "..."
    
    if has_namespace "$FOLLOWER_NAMESPACE_NAME"; then
      sleep 5
    else
      break
    fi
  done

  echo ""
fi

echo "Conjur environment purged."
