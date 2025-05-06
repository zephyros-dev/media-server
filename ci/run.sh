#!/usr/bin/env bash
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
export CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
export PATH=$HOME/.local/bin:$PATH
uv run ci/deployment.py
