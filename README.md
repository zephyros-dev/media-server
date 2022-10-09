# Introduction
Code for running self-hosted services using podman and ansible
# Infrastructure graph
## Networking
```mermaid
flowchart TB
  subgraph internet
    client
    wireguard_client
  end
  subgraph dynv6
    dynv6_server
  end
  subgraph lan_network
    subgraph media_server
      subgraph container_network
        caddy -- reverse proxy --> applications
      end
      media_server_port -- 80 and 443 --> caddy
    end
    subgraph pc
      windows
    end
  end
  subgraph openwrt_router
    client --> port_forward
    wireguard_client --> wireguard
    port_forward -- 80 and 443 --> media_server_port
  end
  subgraph openwrt_router
    ddns_client_v4-- update dynamic public IPv4 --> dynv6_server
    ddns_client_v6 -- update dynamic public IPv6 prefix --> dynv6_server
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