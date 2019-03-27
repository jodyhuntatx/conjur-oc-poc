#!/bin/bash

source ../config/cluster.config
source ../config/utils.sh

echo "Updating Follower cert and seed file with OC route SAN."

# get route endpoint
conjur_follower_route=$(oc get routes | grep conjur-follower | awk '{ print $2 }')

announce "==>> REQUIRES "docker exec" ACCESS TO CONJUR MASTER <<=="

# reissue cert w/ additional SAN
docker exec $CONJUR_MASTER_CONTAINER_NAME evoke ca issue --force conjur-follower $FOLLOWER_ALTNAMES $conjur_follower_route

echo "Updated conjur-follower cert SAN:"
docker exec $CONJUR_MASTER_CONTAINER_NAME openssl x509 -in /opt/conjur/etc/ssl/conjur-follower.pem -text | grep DNS

echo "Regenerating seed file..."
docker exec $CONJUR_MASTER_CONTAINER_NAME evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE
