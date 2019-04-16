#!/bin/bash
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

$cli login -u $OSHIFT_CLUSTER_ADMIN_USERNAME
set_namespace default

if has_namespace $CONJUR_NAMESPACE_NAME; then
  $cli delete namespace $CONJUR_NAMESPACE_NAME

  printf "Waiting for $CONJUR_NAMESPACE_NAME namespace deletion to complete"

  while : ; do
    printf "..."
    
    if has_namespace "$CONJUR_NAMESPACE_NAME"; then
      sleep 5
    else
      break
    fi
  done

  echo ""
fi

echo "Conjur environment purged."
