#!/bin/bash
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
uv run ci/deployment.py
