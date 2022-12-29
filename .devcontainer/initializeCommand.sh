#!/bin/bash
touch ~/.gitconfig
mkdir -p \
    ~/.ansible \
    ~/.config/sops/age \
    ~/.local/share/fish

touch ~/.config/sops/age/keys.txt

cat << EOF >> ${HOME}/.config/containers/registries.conf
unqualified-search-registries = ["docker.io"]

EOF
