#!/bin/bash
# Wireguard: For the vpn local dns lookup to work, disable `Network > DHCP and DNS > Filter > Localise queries`
wg-quick down wg0 && wg-quick up wg0 &> /dev/null
# https://docs.dagger.io/manuals/user/troubleshooting/#dagger-is-unable-to-resolve-host-names-after-network-configuration-changes
DAGGER_ENGINE_DOCKER_CONTAINER="$(docker container list --all --filter 'name=^dagger-engine-*' --format '{{.Names}}')"
docker restart "$DAGGER_ENGINE_DOCKER_CONTAINER"
