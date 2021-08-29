#!/bin/bash
rm -r ~/.config/systemd/user/*
systemctl --user daemon-reload
podman pod stop --all
podman pod rm --all
podman stop --all
podman rm --all
