terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.2.0"
    }
  }
}


data "sops_file" "this" {
  source_file = "secret.sops.yaml"
}

locals {
  secret = data.sops_file.this.data
}

provider "libvirt" {
  # User need to be in the libvirt group
  # https://github.com/teemtee/tmt/issues/329
  uri = "qemu+ssh://${local.secret.user}@${local.secret.host_machine}/system"
  # We use system instead of session because we want to use host network
  # https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html
}
