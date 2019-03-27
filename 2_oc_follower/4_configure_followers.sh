#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $CONJUR_NAMESPACE_NAME
  announce "Configuring followers."
  configure_followers
  echo "Followers configured."
}

configure_followers() {
  pod_list=$($cli get pods -l role=follower --no-headers | awk '{ print $1 }')
  
  for pod_name in $pod_list; do
    configure_follower $pod_name &
  done
  
  wait # for parallel configuration of followers
}

configure_follower() {
  local pod_name=$1

  printf "Configuring follower %s...\n" $pod_name
  copy_file_to_container $FOLLOWER_SEED_FILE "/tmp/follower-seed.tar" "$pod_name"
  $cli exec $pod_name -- evoke unpack seed /tmp/follower-seed.tar
  if [[ $NO_DNS == true ]]; then
    $cli exec -it $pod_name -- bash -c "echo \"$CONJUR_MASTER_HOST_IP    $CONJUR_MASTER_HOST_NAME\" >> /etc/hosts"
  fi

  $cli exec $pod_name -- evoke configure follower -p $CONJUR_MASTER_PORT
}

main $@
