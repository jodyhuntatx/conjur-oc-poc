#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME

  announce "Configuring followers."

  seed_dir="tmp-$FOLLOWER_NAMESPACE_NAME"
  prepare_follower_seed

  configure_followers

  delete_follower_seed

  echo "Followers configured."
}

prepare_follower_seed() {
  echo "Preparing follower seed files..."

  master_pod_name=$(get_master_pod_name)

  # Create dir w/ guid from namespace name for parallel CI execution
  mkdir -p "$seed_dir"

  FOLLOWER_SEED_PATH="./$seed_dir/follower-seed.tar"

  $CLI exec $master_pod_name evoke seed follower conjur-follower > $FOLLOWER_SEED_PATH
}

configure_followers() {
  pod_list=$($CLI get pods -l role=follower --no-headers | awk '{ print $1 }')
  
  for pod_name in $pod_list; do
    configure_follower $pod_name &
  done
  
  wait # for parallel configuration of followers
}

configure_follower() {
  local pod_name=$1

  printf "Configuring follower %s...\n" $pod_name

  copy_file_to_container $FOLLOWER_SEED_PATH "/tmp/follower-seed.tar" "$pod_name"

  $CLI exec $pod_name -- evoke unpack seed /tmp/follower-seed.tar
  $CLI exec $pod_name -- evoke configure follower
  $CLI exec $pod_name -- cat /opt/conjur/etc/ssl/conjur-follower.pem > $FOLLOWER_CERT_FILE
}

delete_follower_seed() {
  echo "Deleting follower seed..."
  
  rm -rf $seed_dir
}

main $@
