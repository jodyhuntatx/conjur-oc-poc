#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/$PLATFORM.config
source ../config/utils.sh

main() {
  set_namespace $FOLLOWER_NAMESPACE_NAME

  docker_login

  deploy_conjur_master_cluster
  deploy_conjur_cli
  master_pod_name=$(get_master_pod_name) # name used by several functions
  wait_for_running_pod $master_pod_name
  create_service_routes
  configure_master_pod
  create_conjur_config_map
  configure_cli_pod
  load_authn_policies
  load_demo_policy

  echo "Master cluster created."
}

######################
docker_login() {
  announce "Creating image pull secret."
    
  $CLI delete --ignore-not-found secrets dockerpullsecret
    
  $CLI secrets new-dockercfg dockerpullsecret \
         --docker-server=${DOCKER_REGISTRY_PATH} \
         --docker-username=_ \
         --docker-password=$($CLI whoami -t) \
         --docker-email=_
    
  $CLI secrets add serviceaccount/conjur-cluster secrets/dockerpullsecret --for=pull
}

######################
deploy_conjur_master_cluster() {
  announce "Deploying Conjur Master cluster pods."

  conjur_appliance_image=$(conjur_image "conjur-appliance")

  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$conjur_appliance_image#g" "./deploy-configs/templates/conjur-master.template.yaml" |
      sed -e "s#{{ CONJUR_MASTER_TAINT_KEY }}#$CONJUR_MASTER_TAINT_KEY#g" |
      sed -e "s#{{ CONJUR_MASTER_TAINT_VALUE }}#$CONJUR_MASTER_TAINT_VALUE#g" |
      sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
      sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
      $CLI create -f -

}

######################
deploy_conjur_cli() {
  announce "Deploying Conjur CLI pod."
  cli_app_image=$(conjur_image conjur-cli)
  sed -e "s#{{ DOCKER_IMAGE }}#$cli_app_image#g" ./deploy-configs/templates/conjur-cli.template.yaml |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_MASTER_TAINT_KEY }}#$CONJUR_MASTER_TAINT_KEY#g" |
    sed -e "s#{{ CONJUR_MASTER_TAINT_VALUE }}#$CONJUR_MASTER_TAINT_VALUE#g" |
    $CLI create -f -
}

###################
create_service_routes() {
  announce "Creating routes to Master & Follower services.."

  $CLI create route passthrough --service=conjur-master
  conjur_master_route=$($CLI get routes | grep conjur-master | awk '{ print $2 }')
  MASTER_ALTNAMES="$MASTER_ALTNAMES,conjur-master.$FOLLOWER_NAMESPACE_NAME.svc.cluster.local,$conjur_master_route"
  echo "Added conjur-master service route ($conjur_master_route) to Master cert altnames."

  $CLI create route passthrough --service=conjur-follower --port=https
  conjur_follower_route=$($CLI get routes | grep conjur-follower | awk '{ print $2 }')
  FOLLOWER_ALTNAME="$FOLLOWER_ALTNAMES,$conjur_follower_route"
  echo "Added conjur-follower service route ($conjur_follower_route) to Follower cert altnames."
}

###################
configure_master_pod() {
  announce "Configuring master pod."

  $CLI label --overwrite pod $master_pod_name role=master

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
  set +e
  $CLI exec $master_pod_name -- \
     chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init["conjur/authn-k8s/$AUTHENTICATOR_ID"] \
     >& /dev/null
  set -e

  echo "Caching Conjur Follower seed files..."
  rm -f $FOLLOWER_SEED_FILE
  $CLI exec $master_pod_name -- \
     evoke seed follower conjur-follower > $FOLLOWER_SEED_FILE

  echo "Waiting for Master service to come up."
  conjur_master_route=$($CLI get routes | grep conjur-master | awk '{ print $2 }')
  wait_for_service_200 "https://$conjur_master_route/health"

  echo "Master pod configured."
}

###################################
create_conjur_config_map() {
  echo "Creating Conjur config map."

  # Config map used for Follower deployments, then re-created once Followers deployed
  $CLI delete --ignore-not-found=true -n default configmap $CONJUR_CONFIG_MAP

  # Set Conjur Master URL to service URL
  master_url="https://$CONJUR_MASTER_SERVICE_NAME"
  master_cert=$(cat "$MASTER_CERT_FILE")

  conjur_seed_file_url=$master_url/configuration/$CONJUR_ACCOUNT/seed/follower

  $CLI create configmap $CONJUR_CONFIG_MAP \
	-n default \
       --from-literal=follower-namespace-name="$FOLLOWER_NAMESPACE_NAME" \
        --from-literal=conjur-master-url=$master_url                    \
        --from-literal=master-certificate="$master_cert"                \
        --from-literal=conjur-seed-file-url="$conjur_seed_file_url"     \
        --from-literal=conjur-authn-login-cluster="$CONJUR_CLUSTER_LOGIN" \
        --from-literal=conjur-account="$CONJUR_ACCOUNT"                 \
        --from-literal=conjur-version="$CONJUR_VERSION"                 \
        --from-literal=conjur-authenticators="$CONJUR_AUTHENTICATORS"   \
        --from-literal=authenticator-id="$AUTHENTICATOR_ID"             \
        --from-literal=conjur-authn-token-file="/run/conjur/access-token"

  echo "Conjur config map created."
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
