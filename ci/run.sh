#!/bin/bash
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
export CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
export DOCKER_HOST=$CONTAINER_HOST
uv run ci/deployment.py
