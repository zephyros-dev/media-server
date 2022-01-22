# Introduction
Code for running self-hosted services using podman and ansible
# Scope
TODO
# Requirement
TODO
# Installation
TODO
# Operation
TODO
# Security
TODO
# Resources
TODO
# Note
- Pods options
  - infra: no cannot be used with custom network
- When using podman with systemd, restart-policy cannot be on-failure:3
- Always run partition playbook with --check first
```
ansible-playbook partition --check
```
# Troubleshooting
## Nextcloud
### Stuck in maintenance mode
1. Run these commands
```
podman exec --user www-data -it nextcloud-web /bin/sh
php occ
php occ upgrade
php occ maintenance:mode --off
```
# Misc
## MPV
- [Anime4K](https://github.com/bloc97/Anime4K)
- To use with jellyfin shim on Windows:
  - Turn on external mpv in mpv shim settings [here](https://github.com/jellyfin/jellyfin-mpv-shim#external-mpv)
  - Change the input.conf file in mpv shim settings according to Anime4K
  - Copy the shaders folder of Anime4K to %APPDATA%/mpv/