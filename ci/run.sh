#!/usr/bin/env bash
eval $(ssh-agent)
eval $(mise activate --shims)
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
# export CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
# uv run ci/deployment.py
uv run ansible-playbook main.yaml
