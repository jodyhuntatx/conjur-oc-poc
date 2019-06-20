# conjur-oc-poc

Install & configuration scripts for a simple Conjur OpenShift POC.

Contents:
 - config/ - Environment variable definitions and utility functions. Sourced by all deployment scripts.
 - shell.config - source to set environment vars in shell for interactive work.
 - 1_docker_master/ - Installs Master, Follower and CLI container in local Docker demon. Assumes the Conjur appliance & CLI tarfiles have been loaded.
 - 2_ext_follower/ - Initializes OpenShift for authentication to Follower running on Conjur Master host
 - 2_oc_follower/ - Creates project, pushes tarfile to OpenShift registry, deploys and configures Follower(s).
 - 3_oc_app/ - Builds and pushes test application images, deploys app pods w/ Conjur K8s authenticator container deployed as sidecar and init container.
 - _oc_cluster/ - (deprecated) Installs Master, Follower and CLI container in OpenShift project. Assumes the Conjur appliance & CLI tarfiles have been loaded in a local docker daemon.
