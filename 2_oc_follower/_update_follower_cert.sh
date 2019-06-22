#!/bin/bash 

# NOTE: ==>> REQUIRES "exec" ACCESS TO CONJUR MASTER <<==

source ../config/cluster.config
source ../config/utils.sh

echo "Updating Follower cert and seed file with OC route SAN."

# get route endpoint
conjur_follower_route=$(oc get routes | grep conjur-follower | awk '{ print $2 }')

if $CONJUR_MASTER_IN_OSHIFT ; then
  conjur_master_pod=$(get_master_pod_name)
  exec_command="$CLI exec $conjur_master_pod --"
else
  exec_command="docker exec $CONJUR_MASTER_CONTAINER_NAME"
fi

echo "Master CA reissuing conjur-follower cert w/ OpenShift route SAN"
$exec_command evoke ca issue --force conjur-follower $conjur_follower_route

echo "Updated conjur-follower cert SAN:"
$exec_command openssl x509 -in /opt/conjur/etc/ssl/conjur-follower.pem -text | grep DNS

echo "Regenerating seed file..."
$exec_command evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE
