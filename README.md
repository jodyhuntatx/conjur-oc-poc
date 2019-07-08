# conjur-oc-poc

Install & configuration scripts for a simple Conjur OpenShift POC.

Contents:
 - config/ - Environment variable definitions and utility functions. Sourced by all deployment scripts.
 - shell.config - source to set environment vars in shell for interactive work.
 - 1_docker_master/ - Installs Master, Follower and CLI container in local Docker demon. Assumes the Conjur appliance & CLI tarfiles have been loaded. Assumes no access to cluster ClI (oc or kubectl).
 - 2_oc_follower/ - Creates project, pushes image to OpenShift registry, deploys Follower. Assumes no access to Conjur Master.
 - 3_oc_app/ - Builds and pushes test application images, deploys app pods w/ Conjur K8s authenticator container deployed as sidecar and init container.
 - _oc_cluster/ - Installs Master, Follower and CLI container in OpenShift project. Assumes the Conjur appliance & CLI tarfiles have been loaded in a local docker daemon.
