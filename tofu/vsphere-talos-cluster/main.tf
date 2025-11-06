terraform {
  required_version = ">= 1.10"
}

module "vsphere" {
  source = "./modules/vsphere-data"

  datacenter_name    = "Milton"
  datastore_name     = "hddDatastore"
  resource_pool_name = "caladan.internal/Resources"
  network_name       = "VLAN60-vsphere-cluster"
}

resource "vsphere_content_library" "cluster" {
  name            = "vsphere-cluster"
  storage_backing = [module.vsphere.datastore_id]
}

resource "talos_image_factory_schematic" "cluster" {
  schematic = file("${path.module}/../../talos/schematic.yaml")
}

data "talos_image_factory_versions" "cluster" {
  filters = {
    stable_versions_only = true
  }
}

locals {
  latest_talos_version = data.talos_image_factory_versions.cluster.talos_versions[length(data.talos_image_factory_versions.cluster.talos_versions) - 1]
}

data "talos_image_factory_urls" "cluster" {
  talos_version = local.latest_talos_version
  schematic_id  = talos_image_factory_schematic.cluster.id
  platform      = "vmware"
}

resource "vsphere_content_library_item" "cluster" {
  name        = "talos-${data.talos_image_factory_urls.cluster.talos_version}-${substr(data.talos_image_factory_urls.cluster.schematic_id, 0, 8)}"
  description = "Schematic ID: ${data.talos_image_factory_urls.cluster.schematic_id}, Talos version: ${data.talos_image_factory_urls.cluster.talos_version}"
  file_url    = data.talos_image_factory_urls.cluster.urls.disk_image
  library_id  = resource.vsphere_content_library.cluster.id
}

resource "talos_machine_secrets" "cluster" {}

locals {
  node_cidr = "192.168.60.0/24"
}

data "talos_machine_configuration" "cluster" {
  cluster_name       = "vsphere-cluster"
  machine_type       = "controlplane"
  cluster_endpoint   = "https://192.168.60.15:6443"
  machine_secrets    = resource.talos_machine_secrets.cluster.machine_secrets
  talos_version      = data.talos_image_factory_urls.cluster.talos_version
  kubernetes_version = "v1.34.1"
  docs               = false
  examples           = false

  config_patches = [
    file("${path.module}/../../patches/annoyances.patch.yaml"),
    templatefile("${path.module}/../../talos/machineconfig.yaml", {
      machine_install_image = data.talos_image_factory_urls.cluster.urls.installer
    }),
    file("${path.module}/../../patches/controlplane.patch.yaml")
  ]
}

output "controlplane_machine_configuration" {
  sensitive = true
  value     = data.talos_machine_configuration.cluster.machine_configuration
}

locals {
  controlplane_count  = 3
  controlplane_prefix = "talos-cp-node"
  controlplane_attributes = {
    cpu    = 2
    memory = 8192
    disk   = 64
  }
  controlplane = { for i in range(local.controlplane_count) : "${local.controlplane_prefix}${format("%02d", i + 1)}" => local.controlplane_attributes }
}

resource "vsphere_folder" "cluster" {
  datacenter_id = module.vsphere.datacenter_id

  path = "vsphere-cluster"
  type = "vm"
}


resource "vsphere_virtual_machine" "cluster" {
  for_each = local.controlplane

  folder           = resource.vsphere_folder.cluster.path
  resource_pool_id = module.vsphere.resource_pool_id
  datastore_id     = module.vsphere.datastore_id

  firmware             = "efi"
  name                 = each.key
  num_cpus             = each.value.cpu
  num_cores_per_socket = each.value.cpu
  memory               = each.value.memory

  enable_logging   = false
  enable_disk_uuid = true

  wait_for_guest_net_timeout = 0

  clone {
    template_uuid = resource.vsphere_content_library_item.cluster.id
  }

  network_interface {
    network_id   = module.vsphere.network_id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = 64
    eagerly_scrub    = false
    thin_provisioned = true
  }

  vapp {
    properties = {
      "talos.config" = base64encode(data.talos_machine_configuration.cluster.machine_configuration)
    }
  }

  lifecycle {
    ignore_changes = [
      vapp[0].properties["talos.config"],
      clone,
      disk,
    ]
  }
}

resource "talos_machine_bootstrap" "cluster" {
  client_configuration = resource.talos_machine_secrets.cluster.client_configuration

  node = resource.vsphere_virtual_machine.cluster[element(keys(local.controlplane), 0)].default_ip_address
  depends_on = [
    resource.vsphere_virtual_machine.cluster
  ]
}
