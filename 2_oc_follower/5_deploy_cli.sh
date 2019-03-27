#!/bin/bash 
set -eo pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

main() {
  set_namespace $CONJUR_NAMESPACE_NAME
  announce "Deploying Conjur CLI pod."

  cli_app_image=$(platform_image conjur-cli)
  sed -e "s#{{ DOCKER_IMAGE }}#$cli_app_image#g" ./deploy-configs/conjur-cli.yml |
    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
    $cli create -f -

  # wait for pod deployment to finish
  sleep 10
  conjur_cli_pod=$(get_conjur_cli_pod_name)
  if [[ $NO_DNS == true ]]; then
    # add entry for master host name to cli container's /etc/hosts
    $cli exec -it $conjur_cli_pod -- bash -c "echo \"$CONJUR_MASTER_HOST_IP    $CONJUR_MASTER_HOST_NAME\" >> /etc/hosts"
  fi

  $cli exec $conjur_cli_pod -- bash -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $CONJUR_APPLIANCE_URL"

  $cli exec $conjur_cli_pod -- conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD

  echo "CLI container created."
}

main $@
