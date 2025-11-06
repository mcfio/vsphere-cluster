# Get vSphere Common Data Elements
terraform {
  required_version = ">= 1.10"
}

data "vsphere_datacenter" "main" {
  name = var.datacenter_name
}

data "vsphere_datastore" "main" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_resource_pool" "main" {
  name          = var.resource_pool_name
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_network" "main" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.main.id
}

