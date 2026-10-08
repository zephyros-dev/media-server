terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }
    ct = {
      source = "poseidon/ct"
    }
    http = {
      source = "hashicorp/http"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
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
  uri = "qemu:///system"
  # We use system instead of session because we want to use host network
  # https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html
}
