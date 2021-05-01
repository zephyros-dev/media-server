#!/bin/bash
echo "Use this script to generate hash password for caddy basic-auth"
podman exec -it caddy caddy hash-password