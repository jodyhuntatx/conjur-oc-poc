#!/bin/bash

check_env_var() {
  var_name=$1

  if [ "${!var_name}" = "" ]; then
    echo "You must set $1 before running these scripts."
    exit 1
  fi
}

announce() {
  echo "++++++++++++++++++++++++++++++++++++++"
  echo ""
  echo "$@"
  echo ""
  echo "++++++++++++++++++++++++++++++++++++++"
}

conjur_image() {
  echo "$DOCKER_REGISTRY_PATH/$FOLLOWER_NAMESPACE_NAME/$1:$FOLLOWER_NAMESPACE_NAME"
}

app_image() {
  echo "$DOCKER_REGISTRY_PATH/$TEST_APP_NAMESPACE_NAME/$1:$TEST_APP_NAMESPACE_NAME"
}

has_namespace() {
  if $CLI get namespace "$1" &> /dev/null; then
    true
  else
    false
  fi
}

has_serviceaccount() {
  $CLI get serviceaccount "$1" &> /dev/null;
}

copy_file_to_container() {
  local from=$1
  local to=$2
  local pod_name=$3

  $CLI cp "$from" $pod_name:"$to"
}

get_master_pod_name() {
  pod_list=$($CLI get pods -l app=conjur-master-node --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

get_master_service_ip() {
  echo $($CLI get service conjur-master -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
}

get_conjur_cli_pod_name() {
  pod_list=$($CLI get pods -l app=conjur-cli --no-headers | awk '{ print $1 }')
  echo $pod_list | awk '{print $1}'
}

set_namespace() {
  if [[ $# != 1 ]]; then
    printf "Error in %s/%s - expecting 1 arg.\n" $(pwd) $0
    exit -1
  fi

  $CLI config set-context $($CLI config current-context) --namespace="$1" > /dev/null
}

######################
wait_for_running_pod() {
  local pod_name=$1; shift
  # until there's at least one pod with that substring in its name that's Running
  until [ "" != "$($CLI get pods --no-headers | grep $pod_name | grep Running)" ]; do
    echo -n '.'
    sleep 2
  done
  echo
}

wait_for_service_200() {
  local service_url=$1; shift
  # until the service returns HTTP 200
  until [ 200 == $(curl -sk -o /dev/null -w "%{http_code}" $service_url) ]; do
    echo -n '.'
    sleep 2
  done
  echo
}

######################
rotate_api_key() {
  set_namespace $FOLLOWER_NAMESPACE_NAME

  master_pod_name=$(get_master_pod_name)

  $CLI exec $master_pod_name -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD > /dev/null
  api_key=$($CLI exec $master_pod_name -- conjur user rotate_api_key)
  $CLI exec $master_pod_name -- conjur authn logout > /dev/null

  echo $api_key
}

######################
function is_minienv() {
  $THIS_IS_MINIKUBE
}

