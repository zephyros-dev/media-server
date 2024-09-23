#region libvirt storage pool
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  path = "/var/lib/libvirt/images"
  # Default path for the libvirt storage pool
  # https://wiki.archlinux.org/title/Libvirt
}
#endregion

module "staging" {
  depends_on = [
    libvirt_pool.default
  ]
  source = "./staging"
  secret = local.secret
}

#region guix

# resource "libvirt_volume" "guix" {
#   name   = "guix-server.qcow2"
#   pool   = "default"
#   source = ".decrypted/guix.qcow2"
#   format = "qcow2"
# }

# resource "libvirt_domain" "guix" {
#   name   = "guix-server"
#   memory = "2048"
#   vcpu   = 2

#   network_interface {
#     bridge = "bridge0"
#   }

#   disk {
#     volume_id = libvirt_volume.guix.id
#   }

#   graphics {
#     type        = "vnc"
#     listen_type = "address"
#   }
# }

#endregion
