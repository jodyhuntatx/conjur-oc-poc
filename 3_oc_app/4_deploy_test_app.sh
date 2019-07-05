#!/bin/bash
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  announce "Deploying test apps for $TEST_APP_NAMESPACE_NAME."

  set_namespace $TEST_APP_NAMESPACE_NAME
  init_registry_creds
  init_connection_specs
  copy_conjur_config_map
  create_app_config_map

  IMAGE_PULL_POLICY='IfNotPresent'

  deploy_sidecar_app
  deploy_init_container_app
  sleep 15  # allow time for containers to initialize
}

###########################
init_registry_creds() {
  announce "Creating image pull secret."
    
  $CLI delete --ignore-not-found secrets dockerpullsecret
  
  $CLI secrets new-dockercfg dockerpullsecret \
      --docker-server=${DOCKER_REGISTRY_PATH} \
      --docker-username=_ \
      --docker-password=$($CLI whoami -t) \
      --docker-email=_
  
  $CLI secrets add serviceaccount/default secrets/dockerpullsecret --for=pull
}

###########################
init_connection_specs() {

  test_sidecar_app_docker_image="$(app_image test-sidecar-app)"
  test_init_app_docker_image="$(app_image test-init-app)"
  authenticator_client_image="$(app_image conjur-authn-k8s-client)"

  # If Followers are deployed in the cluster:
  #  - authenticate to Follower service in cluster
  #  - else authenticate to Follower running on master host
  if $CONJUR_FOLLOWERS_IN_CLUSTER; then
    conjur_appliance_url=https://$CONJUR_FOLLOWER_SERVICE_NAME
  else
    conjur_appliance_url=https://$CONJUR_MASTER_HOST_NAME:$CONJUR_FOLLOWER_PORT
  fi

  conjur_authenticator_url=$conjur_appliance_url/authn-k8s/$AUTHENTICATOR_ID

  conjur_authn_login_prefix=host/conjur/authn-k8s/$AUTHENTICATOR_ID/apps/$TEST_APP_NAMESPACE_NAME/service_account
}

###########################
# CONJUR_CONFIG_MAP defines values for connecting to Conjur service
copy_conjur_config_map() {
  $CLI delete --ignore-not-found configmap $CONJUR_CONFIG_MAP
  $CLI get configmap $CONJUR_CONFIG_MAP -n default -o yaml \
    | sed "s/namespace: default/namespace: $TEST_APP_NAMESPACE_NAME/" \
    | $CLI create -f -
}

###########################
# APP_CONFIG_MAP defines values for app authentication
create_app_config_map() {
  $CLI delete --ignore-not-found configmap $APP_CONFIG_MAP
  $CLI create configmap $APP_CONFIG_MAP \
	-n $TEST_APP_NAMESPACE_NAME \
        --from-literal=conjur-authn-url="$conjur_authenticator_url" \
        --from-literal=conjur-authn-login-init="$conjur_authn_login_prefix/oc-test-app-summon-init" \
        --from-literal=conjur-authn-login-sidecar="$conjur_authn_login_prefix/oc-test-app-summon-sidecar"
}

###########################
deploy_sidecar_app() {
  $CLI delete --ignore-not-found \
    deployment/test-app-summon-sidecar \
    service/test-app-summon-sidecar \
    serviceaccount/test-app-summon-sidecar \
    serviceaccount/oc-test-app-summon-sidecar

  oc delete --ignore-not-found deploymentconfig/test-app-summon-sidecar
  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_sidecar_app_docker_image#g" ./deploy-configs/test-app-summon-sidecar.yml |
    sed -e "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONFIG_MAP_NAME }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ APP_CONFIG_MAP_NAME }}#$APP_CONFIG_MAP#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_NAME }}#$CONJUR_MASTER_HOST_NAME#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_IP }}#$CONJUR_MASTER_HOST_IP#g" |
    $CLI create -f -

  echo "Test app/sidecar deployed."
}

###########################
deploy_init_container_app() {
  $CLI delete --ignore-not-found \
    deployment/test-app-summon-init \
    service/test-app-summon-init \
    serviceaccount/test-app-summon-init \
    serviceaccount/oc-test-app-summon-init

  oc delete --ignore-not-found deploymentconfig/test-app-summon-init
  sleep 5

  sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_init_app_docker_image#g" ./deploy-configs/test-app-summon-init.yml |
    sed -e "s#{{ AUTHENTICATOR_CLIENT_IMAGE }}#$authenticator_client_image#g" |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed -e "s#{{ CONFIG_MAP_NAME }}#$CONJUR_CONFIG_MAP#g" |
    sed -e "s#{{ APP_CONFIG_MAP_NAME }}#$APP_CONFIG_MAP#g" |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_NAME }}#$CONJUR_MASTER_HOST_NAME#g" |
    sed -e "s#{{ CONJUR_MASTER_HOST_IP }}#$CONJUR_MASTER_HOST_IP#g" |
    $CLI create -f -

  echo "Test app/init-container deployed."
}

main "$@"
