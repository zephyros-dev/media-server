#!/bin/bash
# We have to make the symlink for docker to podman since moby engine is installed in ucore
# https://github.com/ublue-os/ucore?tab=readme-ov-file#dockermoby-and-podman
rm ~/.local/bin/docker
ln -s /usr/bin/podman ~/.local/bin/docker
# https://docs.dagger.io/troubleshooting/#dagger-restarts-with-a-cni-setup-error
# The instruction is wrong though, the file needs to have .conf
# https://www.man7.org/linux/man-pages/man5/modules-load.d.5.html
echo iptable_nat | sudo tee -a /etc/modules-load.d/modules.conf
