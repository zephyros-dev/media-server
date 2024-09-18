#!/bin/bash
eval `ssh-agent`
sops -d secret/deployment/ssh_key.sops | ssh-add - &> /dev/null
python ci/deployment.py
