#!/bin/bash
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
PATH=$HOME/.local/bin:$PATH
uv run .devcontainer/main.py --profile="ci-host"
uv run ci/deployment.py
