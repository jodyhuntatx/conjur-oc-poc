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


POLICY_FILE_LIST="
project-authn-defs.yml
cluster-authn-defs.yml
app-identity-defs.yml
resource-access-grants.yml
"
for i in $POLICY_FILE_LIST; do
  echo "Loading policy file: $i"
  ./load_policy_REST.sh root ./policy/$i
done

# create initial value for variables
./var_value_add_REST.sh k8s-secrets/db-username the-db-username
./var_value_add_REST.sh k8s-secrets/db-password $(openssl rand -hex 12)

announce "Conjur policies loaded."
