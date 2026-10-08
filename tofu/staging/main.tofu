#region libvirt storage pool
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target = {
    path = "/var/lib/libvirt/images"
  }
  # Default path for the libvirt storage pool
  # https://wiki.archlinux.org/title/Libvirt
}
#endregion

#region staging-ucore
resource "libvirt_volume" "this" {
  for_each = local.disk_set
  name     = each.key
  pool     = libvirt_pool.default.name
  capacity = 5 * 1024 * 1024 * 1024
  target = {
    format = {
      type = "raw"
    }
  }
}

locals {
  # Use specific
  disk = {
    data = [
      "0x05abcd1fb3191a0d",
      "0x05abcdd9f6a92032"
    ]
    parity = [
      "0x05abcd6b765b3899"
    ]
  }
  disk_set = merge(flatten([
    for type, wwn_list in local.disk : [
      for index, wwn in wwn_list : {
        "staging-${type}-${index}" : wwn
      }
    ]
  ])...)
}

# Blank root disk: coreos-installer partitions and formats this fresh from the
# live ISO, so no base/backing image is needed here.
resource "libvirt_volume" "staging_root" {
  name     = "staging-root"
  pool     = libvirt_pool.default.name
  capacity = 64 * 1024 * 1024 * 1024
  target = {
    format = {
      type = "raw"
    }
  }
}

data "ct_config" "staging" {
  content = templatefile("${path.module}/ignition/staging.bu.yaml.tftpl", {
    # Stable SSH host key across rebuilds (generated once with `ssh-keygen -t
    # ed25519 -N ""`, stored in secret.sops.yaml) so a from-scratch reinstall
    # doesn't force a known_hosts fixup every time.
    ssh_host_ed25519_key     = local.secret.staging_ssh_host_ed25519_key
    ssh_host_ed25519_key_pub = local.secret.staging_ssh_host_ed25519_key_pub
    ssh_authorized_key       = local.secret.staging_ssh_authorized_key
  })
  strict = true
}

resource "libvirt_ignition" "staging" {
  name    = "staging.ign"
  content = data.ct_config.staging.rendered
}

# Always reflects the current Fedora CoreOS "stable" stream release; no
# version number to keep up to date by hand.
data "http" "fcos_stream" {
  url = "https://builds.coreos.fedoraproject.org/streams/stable.json"
}

locals {
  fcos_stream = jsondecode(data.http.fcos_stream.response_body)
  fcos_iso    = local.fcos_stream.architectures.x86_64.artifacts.metal.formats.iso.disk
}

# Downloads the current live ISO and runs it through `coreos-installer iso
# customize` (via the official container image, so no local coreos-installer
# binary is needed) to embed our Ignition config and target disk, producing an
# unattended-install ISO. Only re-runs when the upstream release or the
# rendered Ignition config actually changes.
locals {
  # staging_root is the sole virtio disk, so it's reliably /dev/vda in the
  # live installer environment — no wwn needed for unambiguous targeting.
  # Defined once and referenced by both triggers_replace and the environment
  # below so a future change here can't silently go stale the way it just did
  # (DEST_DEVICE wasn't part of triggers_replace, so changing it didn't
  # invalidate the already-built, cached ISO).
  install_dest_device = "/dev/vda"
}

resource "terraform_data" "install_iso_build" {
  triggers_replace = {
    base_iso_sha256 = local.fcos_iso.sha256
    ignition_sha256 = sha256(data.ct_config.staging.rendered)
    dest_device     = local.install_dest_device
  }

  provisioner "local-exec" {
    environment = {
      IGNITION_CONTENT = data.ct_config.staging.rendered
      BASE_ISO_URL     = local.fcos_iso.location
      BASE_ISO_SHA256  = local.fcos_iso.sha256
      DEST_DEVICE      = local.install_dest_device
      # Matches the repo's existing `*.decrypted*` gitignore convention
      # (see .decrypted.kickstart in this same directory) instead of adding
      # a separate ignore rule for a generated-artifacts folder.
      OUTPUT_PATH = "${path.module}/.decrypted.staging-install.iso"
      CACHE_DIR   = "${path.module}/.decrypted.fcos-cache"
      # TEMPORARY DEBUG: a root password for the *live installer environment*
      # itself (distinct from --dest-ignition, which only applies to the
      # destination system after a successful install — useless for
      # debugging a failure inside coreos-installer-service itself, which is
      # what's currently happening). The password is noted next to its hash in
      # secret.sops.yaml. Remove this whole LIVE_IGNITION_CONTENT block plus
      # the --live-ignition flag below once done debugging.
      LIVE_IGNITION_CONTENT = jsonencode({
        ignition = {
          version = "3.4.0"
        }
        passwd = {
          users = [{
            name         = "root"
            passwordHash = local.secret.staging_live_root_password_hash
          }]
        }
      })
    }
    command = <<-EOT
      set -euo pipefail
      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT

      printf '%s' "$IGNITION_CONTENT" > "$workdir/staging.ign"
      printf '%s' "$LIVE_IGNITION_CONTENT" > "$workdir/live-debug.ign"

      # Content-addressed cache: skip the (large) download entirely if we
      # already have a copy verified against this exact sha256, so changing
      # unrelated things (e.g. just the Ignition config) doesn't force a
      # redundant re-download of an unchanged base ISO.
      mkdir -p "$CACHE_DIR"
      cached_iso="$CACHE_DIR/$BASE_ISO_SHA256.iso"
      if [ ! -f "$cached_iso" ]; then
        tmp_download="$cached_iso.part"
        curl -fL --retry 3 -o "$tmp_download" "$BASE_ISO_URL"
        echo "$BASE_ISO_SHA256  $tmp_download" | sha256sum -c -
        mv "$tmp_download" "$cached_iso"
      else
        echo "$BASE_ISO_SHA256  $cached_iso" | sha256sum -c -
      fi

      podman run --rm -v "$workdir:/data:z" -v "$CACHE_DIR:/cache:z,ro" -w /data \
        quay.io/coreos/coreos-installer:release \
        iso customize --force \
        --dest-ignition staging.ign \
        --dest-device "$DEST_DEVICE" \
        --live-ignition live-debug.ign \
        -o custom.iso "/cache/$BASE_ISO_SHA256.iso"

      mkdir -p "$(dirname "$OUTPUT_PATH")"
      mv "$workdir/custom.iso" "$OUTPUT_PATH"
    EOT
  }
}

# The customized installer ISO, built by terraform_data.install_iso_build above.
resource "libvirt_volume" "install_iso" {
  depends_on = [terraform_data.install_iso_build]
  name       = "staging-install.iso"
  pool       = libvirt_pool.default.name
  target = {
    format = {
      # Actual ISO9660 content, not a raw disk image — libvirt detects/reports
      # this as "iso" regardless of what's declared here, so declaring
      # anything else causes a provider consistency error after apply.
      type = "iso"
    }
  }
  create = {
    content = {
      url = "file://${path.module}/.decrypted.staging-install.iso"
    }
  }
}

# Define KVM domain to create
resource "libvirt_domain" "this" {
  name = "staging"
  type = "kvm"
  # memory defaults to KiB when memory_unit is unset (libvirt's own XML
  # default) — without this, 5120 was being read as 5120 KiB (~5MB), not
  # the intended 5GB.
  memory      = 5120
  memory_unit = "MiB"
  vcpu        = 2
  autostart   = false

  cpu = {
    mode = "host-passthrough"
  }

  # UEFI (os.firmware = "efi" below) requires ACPI on x86_64.
  features = {
    acpi = true
  }

  os = {
    # Required libvirt domain XML element (<os><type>); this provider version
    # doesn't default it, and libvirt rejects the domain definition without it.
    type = "hvm"
    # "efi" is libvirt's firmware auto-select keyword (not a file path — that
    # goes in `loader` instead); lets libvirt pick the matching OVMF files
    # from its own firmware descriptors rather than hardcoding a path that
    # may not exist identically on every host.
    firmware = "efi"
    # NOTE: os.boot_devices (the global hd/cdrom boot-order list) does not
    # reliably apply to SCSI-attached disks — observed in practice: OVMF
    # skipped both configured devices entirely and fell through to PXE
    # network boot. Using explicit per-device `boot.order` below instead,
    # which is SCSI-aware.
  }

  # Standard CoreOS-family fw_cfg mechanism for passing an Ignition config to
  # the guest on first boot; see https://libvirt.org/formatdomain.html#smbios-system-information
  sys_info = [
    {
      fw_cfg = {
        entry = [
          {
            name  = "opt/com.coreos/config"
            file  = libvirt_ignition.staging.path
            value = ""
          }
        ]
      }
    }
  ]

  devices = {
    interfaces = [
      {
        source = {
          bridge = {
            bridge = "bridge0"
          }
        }
        mac = {
          address = local.secret.mac_address
        }
      }
    ]

    # Enables `virsh -c qemu:///system console staging` for interactive
    # debugging — without this, there's no PTY-backed console device at all,
    # only the VNC framebuffer (which can only be driven via screenshot +
    # send-key, much more painful).
    serials = [
      {
        target = {
          type = "isa-serial"
          port = 0
        }
        source = {
          pty = {
            path = ""
          }
        }
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]

    disks = concat([
      {
        source = {
          volume = {
            pool   = libvirt_pool.default.name
            volume = libvirt_volume.staging_root.name
          }
        }
        target = {
          # virtio has solid, well-known OVMF boot-ROM support. scsi (used
          # originally here) turned out not to reliably expose a boot ROM in
          # practice — OVMF silently skipped both the scsi root disk and scsi
          # cdrom entirely and fell through to PXE network boot despite
          # correct boot.order on both. The pre-rewrite config also only ever
          # put non-bootable secondary disks on scsi, for what turns out to
          # be exactly this reason.
          bus = "virtio"
          dev = "vda"
        }
        # Disk tried first: UEFI skips non-bootable entries automatically, so
        # this falls through to the cdrom on the very first (blank-disk) boot
        # and self-corrects to booting straight off the disk on every boot
        # after the install completes. Getting this order backwards would
        # mean the self-installing, auto-overwriting cdrom takes priority
        # forever, re-wiping the disk on every single boot.
        boot = {
          order = 1
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.default.name
            volume = libvirt_volume.install_iso.name
          }
        }
        target = {
          # sata (AHCI) also has reliable OVMF CD-ROM boot-ROM support, unlike
          # scsi here — see note on the root disk above.
          bus = "sata"
          dev = "sda"
        }
        boot = {
          order = 2
        }
      }
      ], [
      # Non-bootable disks only, so scsi (no boot-ROM concern) is fine here.
      # Target dev names continue sdb/sdc/sdd since sda is now taken by the
      # sata cdrom above; libvirt requires an explicit target dev per disk
      # even though the provider schema marks it optional.
      for idx, key in sort(keys(local.disk_set)) : {
        source = {
          volume = {
            pool   = libvirt_pool.default.name
            volume = libvirt_volume.this[key].name
          }
        }
        target = {
          bus = "scsi"
          dev = "sd${substr("bcdefghijklmnopqrstuvwxyz", idx, 1)}"
        }
        wwn = local.disk_set[key]
      }
    ])

    graphics = [
      {
        vnc = {
          # `listen` is a literal bind address here, not a mode keyword (the
          # old classic-schema "address" listen_type doesn't carry over) —
          # 0.0.0.0 listens on all interfaces, same effective behavior the
          # old config had.
          listen = "0.0.0.0"
        }
      }
    ]
  }

  lifecycle {
    # The new provider schema nests the old top-level "nvram" attribute under
    # os.nv_ram; scope the ignore to just that (not all of "os") so changes to
    # firmware/boot_devices are still tracked normally.
    ignore_changes = [
      os.nv_ram
    ]
  }
}
#endregion
