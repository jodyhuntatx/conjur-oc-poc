#!/bin/bash
set -o pipefail

. ../utils.sh

main() {
  follower_up
}

############################
follower_up() {
  echo "-----"
  announce "Initializing Conjur Follower"
  docker run -d \
    --name conjur_follower \
    --label role=conjur_node \
    -p "$CONJUR_FOLLOWER_PORT:443" \
    --restart always \
    --security-opt seccomp:unconfined \
    $CONJUR_APPLIANCE_IMAGE

  if [[ $NO_DNS ]]; then
    # add entry to follower's /etc/hosts so $CONJUR_MASTER_HOST_NAME resolves
    docker exec -it conjur_follower bash -c "echo \"$CONJUR_MASTER_HOST_IP    $CONJUR_MASTER_HOST_NAME\" >> /etc/hosts"
  fi

  docker cp $FOLLOWER_SEED_FILE conjur_follower:/tmp/follower-seed.tar
  docker exec conjur_follower evoke unpack seed /tmp/follower-seed.tar
  docker exec conjur_follower evoke configure follower -p $CONJUR_MASTER_PORT
}

main "$@"
