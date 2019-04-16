#!/bin/bash 
set -euo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $CONJUR_NAMESPACE_NAME

  print_cluster_info
}

#######################
print_cluster_info() {

  conjur_master_route=$($cli get routes | grep conjur-master | awk '{ print $2 }')
  master_url=https://$conjur_master_route

  conjur_follower_route=$($cli get routes | grep conjur-follower | awk '{ print $2 }')
  follower_url=https://$conjur_follower_route

  password=$CONJUR_ADMIN_PASSWORD

  announce "
  Conjur cluster is ready.

  Conjur Master address:
    $master_url

  Conjur Follower address:
    $follower_url

  Conjur admin credentials:
    admin / $password
  "
}

main $@
