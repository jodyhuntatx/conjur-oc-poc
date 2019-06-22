#!/bin/bash
## Write Minishift docker & oc config values as env var inits
OUTPUT_FILE=./mini.config
minishift oc-env > $OUTPUT_FILE
minishift docker-env >> $OUTPUT_FILE
echo "export DOCKER_REGISTRY_PATH=$(minishift openshift registry)" >> $OUTPUT_FILE
echo "export CONJUR_MASTER_HOST_IP=$(minishift ip)" >> $OUTPUT_FILE
