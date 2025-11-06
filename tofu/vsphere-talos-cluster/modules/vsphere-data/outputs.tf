output "datacenter_id" {
  description = "The ID of the vSphere datacenter"
  value       = data.vsphere_datacenter.main.id
}

output "datastore_id" {
  description = "The ID of the vSphere datastore"
  value       = data.vsphere_datastore.main.id
}

output "resource_pool_id" {
  description = "The ID of the vSphere resource pool"
  value       = data.vsphere_resource_pool.main.id
}

output "network_id" {
  description = "The ID of the vSphere network"
  value       = data.vsphere_network.main.id
}
