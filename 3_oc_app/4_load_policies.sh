#!/bin/bash 
#set -eou pipefail

source ../config/cluster.config
source ../config/openshift.config
source ../config/utils.sh

announce "Initializing Conjur authorization policies..."

sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
    ./policy/templates/project-authn-defs.template.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" \
  > ./policy/project-authn-defs.yml

sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
     ./policy/templates/cluster-authn-defs.template.yml \
   > ./policy/cluster-authn-defs.yml

sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
    ./policy/templates/app-identity-defs.template.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" \
  > ./policy/app-identity-defs.yml

sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" \
    ./policy/templates/resource-access-grants.template.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" \
  > ./policy/resource-access-grants.yml


set_namespace $CONJUR_NAMESPACE_NAME

conjur_cli_pod=$(get_conjur_cli_pod_name)

$cli exec $conjur_cli_pod -- mkdir -p /policy
$cli exec $conjur_cli_pod -- bash -c "conjur authn login -u admin -p $CONJUR_ADMIN_PASSWORD"

POLICY_FILE_LIST="
project-authn-defs.yml
cluster-authn-defs.yml
app-identity-defs.yml
resource-access-grants.yml
"
for i in $POLICY_FILE_LIST; do
        echo "Loading policy file: $i"
        $cli cp ./policy/$i $conjur_cli_pod:/policy/
        $cli exec $conjur_cli_pod -- bash -c "conjur policy load root /policy/$i"
done

# create initial value for variables
$cli exec $conjur_cli_pod -- bash -c "conjur variable values add k8s-secrets/db-username the-db-username"
$cli exec $conjur_cli_pod -- bash -c "conjur variable values add k8s-secrets/db-password $(openssl rand -hex 12)"

set_namespace $TEST_APP_NAMESPACE_NAME

announce "Conjur policies loaded."
