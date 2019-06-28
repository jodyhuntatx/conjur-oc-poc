#!/bin/bash
set -uo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME
  configure_master_pod
  sleep 15
  configure_cli_pod
  load_authn_policies
  load_demo_policy
}

###################
configure_master_pod() {
  announce "Configuring master pod."

  master_pod_name=$(get_master_pod_name)

  $CLI label --overwrite pod $master_pod_name role=master

  echo "Creating passthrough routes for conjur-master & follower services."
  $CLI create route passthrough --service=conjur-master
  conjur_master_route=$($CLI get routes | grep conjur-master | awk '{ print $2 }')
  MASTER_ALTNAMES="$MASTER_ALTNAMES,conjur-master.$FOLLOWER_NAMESPACE_NAME.svc.cluster.local,$conjur_master_route"
  echo "Added conjur-master service route ($conjur_master_route) to Master cert altnames."

  $CLI create route passthrough --service=conjur-follower
  conjur_follower_route=$($CLI get routes | grep conjur-follower | awk '{ print $2 }')
  FOLLOWER_ALTNAMES="$FOLLOWER_ALTNAMES,$conjur_follower_route"
  echo "Added conjur-follower service route ($conjur_follower_route) to Follower cert altnames."

  # Configure Conjur master server using evoke.
  $CLI exec $master_pod_name -- evoke configure master \
     -h conjur-master \
     --master-altnames "$MASTER_ALTNAMES" \
     --follower-altnames "$FOLLOWER_ALTNAMES" \
     -p $CONJUR_ADMIN_PASSWORD \
     $CONJUR_ACCOUNT

  mkdir -p $CACHE_DIR
  echo "Caching Conjur master cert ..."
  rm -f $MASTER_CERT_FILE
  $CLI cp $master_pod_name:/opt/conjur/etc/ssl/conjur-master.pem $MASTER_CERT_FILE

  echo "Initializing Conjur K8s authenticator service..."
  $CLI exec $master_pod_name -- \
     chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init["conjur/authn-k8s/$AUTHENTICATOR_ID"]

  echo "Caching Conjur Follower seed files..."
  rm -f $FOLLOWER_SEED_FILE
  $CLI exec $master_pod_name -- \
     evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE

  echo "Master pod configured."
}

###################
configure_cli_pod() {
  announce "Configuring Conjur CLI."

  
  conjur_url=https://conjur-master.$FOLLOWER_NAMESPACE_NAME.svc.cluster.local
  conjur_cli_pod=$(get_conjur_cli_pod_name)
  $CLI exec $conjur_cli_pod -- bash -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $conjur_url"
  $CLI exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD
}

###################################
load_authn_policies() {
  echo "Initializing Conjur authorization policies..."

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
     ./policy/templates/cluster-authn-defs.template.yml |
    sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONJUR_SERVICEACCOUNT_NAME }}#$CONJUR_SERVICEACCOUNT_NAME#g" \
    > ./policy/cluster-authn-defs.yml

  sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
    ./policy/templates/seed-service.template.yml |
    sed -e "s#{{ FOLLOWER_NAMESPACE_NAME }}#$FOLLOWER_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONJUR_SERVICEACCOUNT_NAME }}#$CONJUR_SERVICEACCOUNT_NAME#g" \
    > ./policy/seed-service.yml

  POLICY_FILE_LIST="
  ./policy/cluster-authn-defs.yml
  ./policy/seed-service.yml
  "
  for i in $POLICY_FILE_LIST; do
        echo "Loading policy file: $i"
        ./load_policy_REST.sh root "$i"
  done

  echo "Conjur policies loaded."
}

###################
load_demo_policy() {
  conjur_cli_pod=$(get_conjur_cli_pod_name)

  # Load policy 
  ./load_policy_REST.sh root ./policy/demo-policy.yml

  # Initialize secrets created by policy
  ./var_value_add_REST.sh secrets/db-username "This-is-the-DB-username"
  ./var_value_add_REST.sh secrets/db-password $(openssl rand -hex 12)
}

main "$@"
