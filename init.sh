#!/bin/bash
sudo dnf install \
    git \
    podman \
    podman-docker \
    slirp4netns
systemctl --user start podman.socket
systemctl --user enable podman.socket
