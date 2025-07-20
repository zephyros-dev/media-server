#region libvirt storage pool
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images"
  }
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
