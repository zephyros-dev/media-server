#!/bin/bash
sudo chown $USER:$USER ~/.local ~/.config
ansible-galaxy install -r requirements.yaml