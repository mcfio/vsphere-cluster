terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.15"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
  }
}

provider "vsphere" {
  vsphere_server       = "vcsa.milton.mcf.io"
  allow_unverified_ssl = true
  api_timeout          = 10
}

provider "talos" {}

