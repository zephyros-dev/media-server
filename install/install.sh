#!/bin/bash
# Ansible
# sudo dnf install -y ansible
# pip install ansible
# For ansible enter password
sudo dnf install -y sshpass
# Extra package for ansible
ansible-galaxy install -r requirements.yaml --force