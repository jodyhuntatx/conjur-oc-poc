#!/bin/bash
set -uo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $CONJUR_NAMESPACE_NAME
  configure_master_pod
  sleep 15
  configure_cli_pod
  load_demo_policy
}

###################
configure_master_pod() {
  announce "Configuring master pod."

  master_pod_name=$(get_master_pod_name)

  $cli label --overwrite pod $master_pod_name role=master

  echo "Creating passthrough routes for conjur-master & follower services."
  $cli create route passthrough --service=conjur-master
  conjur_master_route=$($cli get routes | grep conjur-master | awk '{ print $2 }')
  MASTER_ALTNAMES="$MASTER_ALTNAMES,$conjur_master_route"
  echo "Added conjur-master service route ($conjur_master_route) to Master cert altnames."

  $cli create route passthrough --service=conjur-follower
  conjur_follower_route=$($cli get routes | grep conjur-follower | awk '{ print $2 }')
  FOLLOWER_ALTNAMES="$FOLLOWER_ALTNAMES,$conjur_follower_route"
  echo "Added conjur-follower service route ($conjur_follower_route) to Follower cert altnames."

  # Configure Conjur master server using evoke.
  $cli exec $master_pod_name -- evoke configure master \
     -h conjur-master \
     --master-altnames "$MASTER_ALTNAMES" \
     --follower-altnames "$FOLLOWER_ALTNAMES" \
     -p $CONJUR_ADMIN_PASSWORD \
     $CONJUR_ACCOUNT

  mkdir -p $CACHE_DIR
  echo "Caching Conjur master cert ..."
  rm -f $CONJUR_CERT_FILE
  $cli cp $master_pod_name:/opt/conjur/etc/ssl/conjur.pem $CONJUR_CERT_FILE

  echo "Initializing Conjur K8s authenticator service..."
  $cli exec $master_pod_name -- \
     chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init["conjur/authn-k8s/$AUTHENTICATOR_ID"]

  echo "Caching Conjur Follower seed files..."
  rm -f $FOLLOWER_SEED_FILE
  $cli exec $master_pod_name -- \
     evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE

  echo "Master pod configured."
}

###################
configure_cli_pod() {
  announce "Configuring Conjur CLI."

  
  conjur_url=https://conjur-master.$CONJUR_NAMESPACE_NAME.svc.cluster.local
  conjur_cli_pod=$(get_conjur_cli_pod_name)
  $cli exec $conjur_cli_pod -- bash -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $conjur_url"
  $cli exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD
}

###################
load_demo_policy() {
  conjur_cli_pod=$(get_conjur_cli_pod_name)

  # Copy policy into CLI
  $cli exec $conjur_cli_pod -- \
    bash -c "mkdir -p /policy"
  $cli cp ../policy/demo-policy.yml $conjur_cli_pod:/policy/demo-policy.yml

  # Load policy 
  $cli exec $conjur_cli_pod -- \
    conjur policy load root /policy/demo-policy.yml

  # Initialize secrets created by policy
  $cli exec $conjur_cli_pod -- \
    conjur variable values add secrets/db-username "This-is-the-DB-username"
  $cli exec $conjur_cli_pod -- \
    bash -c "conjur variable values add secrets/db-password $(openssl rand -hex 12)"
}

main "$@"
