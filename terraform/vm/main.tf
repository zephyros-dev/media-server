# Defining VM Volume
resource "libvirt_volume" "guix" {
  name   = "guix-server.qcow2"
  pool   = "default"
  source = ".decrypted/guix.qcow2"
  format = "qcow2"
}

# Define KVM domain to create
resource "libvirt_domain" "guix" {
  name   = "guix-server"
  memory = "2048"
  vcpu   = 2

  network_interface {
    bridge = "bridge0"
  }

  disk {
    volume_id = libvirt_volume.guix.id
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}
