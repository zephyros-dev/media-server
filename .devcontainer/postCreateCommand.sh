#!/bin/bash
sudo chown ${USER}:${USER} ~/.local ~/.config
sudo chown -R ${USER}:${USER} ~/.local/share/fish
ansible-galaxy install -r requirements.yaml