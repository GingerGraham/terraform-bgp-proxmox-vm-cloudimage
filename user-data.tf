resource "proxmox_virtual_environment_file" "user_data" {
  count = local.using_custom_cloud_init && var.cloud_init_custom.user_data != null ? 1 : 0

  node_name    = local.selected_node
  datastore_id = var.cloud_init_custom.datastore_id
  content_type = "snippets"

  source_raw {
    data      = var.cloud_init_custom.user_data
    file_name = "${var.vm_name}-user-data.yaml"
  }
}

# Built-in standard user-data file (when cloud_init_mode = "builtin")
resource "proxmox_virtual_environment_file" "builtin_user_data" {
  count = local.using_builtin_cloud_init ? 1 : 0

  node_name    = local.selected_node
  datastore_id = var.cloud_init_builtin.datastore_id
  content_type = "snippets"

  source_raw {
    data      = local.builtin_cloud_init_user_data
    file_name = "${var.vm_name}-user-data.yaml"
  }
}

# Custom cloud-init meta-data file (if provided)
resource "proxmox_virtual_environment_file" "meta_data" {
  count = local.using_custom_cloud_init && var.cloud_init_custom.meta_data != null ? 1 : 0

  node_name    = local.selected_node
  datastore_id = var.cloud_init_custom.datastore_id
  content_type = "snippets"

  source_raw {
    data      = var.cloud_init_custom.meta_data
    file_name = "${var.vm_name}-meta-data.yaml"
  }
}

# Custom cloud-init network-data file (if provided)
resource "proxmox_virtual_environment_file" "network_data" {
  count = local.using_custom_cloud_init && var.cloud_init_custom.network_data != null ? 1 : 0

  node_name    = local.selected_node
  datastore_id = var.cloud_init_custom.datastore_id
  content_type = "snippets"

  source_raw {
    data      = var.cloud_init_custom.network_data
    file_name = "${var.vm_name}-network-data.yaml"
  }
}

# Custom cloud-init vendor-data file (if provided)
resource "proxmox_virtual_environment_file" "vendor_data" {
  count = local.using_custom_cloud_init && var.cloud_init_custom.vendor_data != null ? 1 : 0

  node_name    = local.selected_node
  datastore_id = var.cloud_init_custom.datastore_id
  content_type = "snippets"

  source_raw {
    data      = var.cloud_init_custom.vendor_data
    file_name = "${var.vm_name}-vendor-data.yaml"
  }
}