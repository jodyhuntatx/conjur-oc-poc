#!/bin/bash 

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

set_namespace $CONJUR_NAMESPACE_NAME

announce "Deleting Conjur deployments"

echo "Deleting Follower pods."
$cli delete dc/conjur-follower
$cli delete svc/conjur-follower

echo "Deleting CLI pod."
$cli delete deploy/conjur-cli

echo "Deleting Route to Follower service."
$cli delete route conjur-follower

echo "Waiting for Conjur pods to terminate..."
while [[ "$($cli get pods 2>&1)" != "No resources found." ]]; do
  echo -n '.'
  sleep 3
done 
echo

echo "All deployments deleted."
