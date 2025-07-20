
#region staging-iot
resource "libvirt_volume" "this" {
  for_each = local.disk_set
  name     = each.key
  size     = 6 * 1024 * 1024 * 1024
  format   = "raw"
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

resource "libvirt_volume" "root" {
  name   = "staging-root"
  size   = 36 * 1024 * 1024 * 1024
  format = "raw"
}

# Define KVM domain to create
resource "libvirt_domain" "this" {
  name   = "staging"
  memory = "8192"
  vcpu   = 2

  autostart = true
  cpu {
    mode = "host-passthrough"
  }

  firmware = "/usr/share/OVMF/OVMF_CODE.fd"

  network_interface {
    bridge = "bridge0"
    mac    = var.secret.mac_address
  }

  disk {
    file = var.secret.iot_image_path
  }

  disk {
    volume_id = libvirt_volume.root.id
    scsi      = true
  }

  dynamic "disk" {
    for_each = local.disk_set
    content {
      volume_id = libvirt_volume.this[disk.key].id
      scsi      = true
      wwn       = disk.value
    }
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }

  lifecycle {
    ignore_changes = [
      nvram
    ]
  }
}
#endregion
