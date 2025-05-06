#!/usr/bin/env bash
eval `ssh-agent`
export PATH="$(aqua root-dir)/bin:$HOME/.local/bin:$PATH"
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
export CONTAINER_HOST=$(sops -d secret/deployment/podman.sops)
uv run ci/deployment.py
