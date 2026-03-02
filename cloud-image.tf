# Data source to reference the cloud image file
data "proxmox_virtual_environment_file" "cloud_image" {
  count = var.cloud_image_lookup_enabled ? 1 : 0

  node_name    = var.cloud_image_reference.node_name
  datastore_id = var.cloud_image_reference.datastore_id
  content_type = var.cloud_image_reference.content_type
  file_name    = var.cloud_image_reference.file_name
}
