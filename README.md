[![dagger](https://github.com/zephyros-dev/media-server/actions/workflows/deployment.yaml/badge.svg)](https://github.com/zephyros-dev/media-server/actions/workflows/deployment.yaml)

# Introduction

Code for running self-hosted services using podman and ansible

# Infrastructure graph

## Networking

```mermaid
flowchart TB
  subgraph internet
    http_client
    wireguard_client
    subgraph github[Github]
      github_action_runner
    end
    dns_name_server[DNS Name Server]
  end
  subgraph lan_network
    subgraph media_server
      subgraph container_network
        caddy -- reverse proxy --> applications
      end
      server_port -- 80 and 443 --> caddy
    end
    subgraph pc
      windows
    end
  end
  subgraph openwrt_router
    http_client --> port_forward
    github_action_runner --> wireguard
    wireguard_client --> wireguard
    port_forward -- 80 and 443 --> server_port
    dns_name_server <-- update dynamic public IPv4 -->  ddns_client_v4
    dns_name_server <-- update dynamic public IPv6 prefix -->  ddns_client_v6
  end
  wireguard --> lan_network
```

## Data

```mermaid
flowchart TB
  subgraph media_server
    subgraph os_disk
    end
    subgraph data_disk
      subgraph storage_disk
      storage_disk_1
      storage_disk_2
      end
      subgraph parity_disk
      parity_disk_1
      end
    end
  end
```

# Note

- Always run partition playbook with --check first

```
ansible-playbook partition --check
```

# Troubleshooting

## Pymedusa

### Pymedusa failed create hardlink

- Check [this](roles/pymedusa/README.md)

### Check failed to hardlink file

- Run this command in the Video folder

```
find . -type f -links 1 ! -name "*.srt" -print
```

<!-- TODO: Write a scheduled monitoring for this -->

## Nextcloud

### Stuck in maintenance mode

1. Rebuild nextcloud

```
ansible-playbook container_run.yaml --tags nextcloud
```
