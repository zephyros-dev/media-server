#!/usr/bin/env bash
eval $(ssh-agent)
eval $(mise activate --shims)
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
# export CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
# uv run ci/deployment.py
export ANSIBLE_CALLBACKS_ENABLED="timer"
export ANSIBLE_DISPLAY_SKIPPED_HOSTS="False"
export ANSIBLE_STDOUT_CALLBACK="dense"
export ANSIBLE_HOST_KEY_CHECKING="False"
uv run ansible-playbook main.yaml
