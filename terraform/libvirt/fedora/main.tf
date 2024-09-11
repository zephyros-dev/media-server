
#region fedora-iot
resource "libvirt_volume" "data" {
  count  = 2
  name   = "fedora-data-${count.index}"
  size   = 10000000000
  format = "raw"
}

resource "libvirt_volume" "parity" {
  count  = 1
  name   = "fedora-parity-${count.index}"
  size   = 10000000000
  format = "raw"
}

resource "libvirt_volume" "root" {
  name   = "fedora-root"
  size   = 30000000000
  format = "raw"
}

# Define KVM domain to create
resource "libvirt_domain" "this" {
  name   = "fedora-iot"
  memory = "4096"
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
  }

  dynamic "disk" {
    for_each = libvirt_volume.data
    content {
      volume_id = disk.value.id
    }
  }

  dynamic "disk" {
    for_each = libvirt_volume.parity
    content {
      volume_id = disk.value.id
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
