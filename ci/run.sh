#!/bin/bash
wg-quick down wg0 && wg-quick up wg0 &> /dev/null
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
# https://docs.dagger.io/manuals/user/troubleshooting/#dagger-is-unable-to-resolve-host-names-after-network-configuration-changes
DAGGER_ENGINE_DOCKER_CONTAINER="$(docker container list --all --filter 'name=^dagger-engine-*' --format '{{.Names}}')"
docker restart "$DAGGER_ENGINE_DOCKER_CONTAINER"
