resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = local.selected_node

  stop_on_destroy = var.stop_on_destroy

  agent {
    enabled = var.agent_enabled
    timeout = var.agent_timeout
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.assigned_memory
    floating  = coalesce(var.minimum_memory, var.assigned_memory)
  }

  disk {
    datastore_id = var.disk_datastore
    file_id      = local.cloud_image_file_id
    interface    = local.disk_interface
    size         = var.disk_size_gb
    discard      = var.disk_discard
    ssd          = var.disk_ssd
    iothread     = var.disk_iothread
  }

  network_device {
    bridge = var.network_bridge
    model  = var.network_model
  }

  operating_system {
    type = var.os_type
  }

  bios = var.bios_type

  dynamic "efi_disk" {
    for_each = var.efi_disk != null ? [var.efi_disk] : []
    content {
      datastore_id = efi_disk.value.datastore_id
      file_format  = efi_disk.value.file_format
      type         = efi_disk.value.type
    }
  }

  keyboard_layout = var.keyboard_layout

  serial_device {}

  # Cloud-init initialization block
  dynamic "initialization" {
    for_each = [1]
    content {
      datastore_id = var.disk_datastore
      interface    = local.cloud_init_interface

      # Native cloud-init configuration
      dynamic "user_account" {
        for_each = var.cloud_init_mode == "native" && var.cloud_init_native != null && var.cloud_init_native.user_name != null ? [1] : []
        content {
          username = var.cloud_init_native.user_name
          password = var.cloud_init_native.user_password
          keys     = var.cloud_init_native.ssh_keys
        }
      }

      dynamic "dns" {
        for_each = var.cloud_init_mode == "native" && var.cloud_init_native != null && var.cloud_init_native.dns_domain != null ? [1] : []
        content {
          domain  = var.cloud_init_native.dns_domain
          servers = var.cloud_init_native.dns_servers
        }
      }

      dynamic "ip_config" {
        for_each = (
          var.cloud_init_mode == "native" ||
          (
            var.auto_dhcp_on_builtin_custom &&
            (
              local.using_builtin_cloud_init ||
              (local.using_custom_cloud_init && var.cloud_init_custom.network_data == null)
            )
          )
        ) ? [1] : []
        content {
          dynamic "ipv4" {
            for_each = [1]
            content {
              address = var.cloud_init_mode == "native" && var.cloud_init_native != null ? var.cloud_init_native.ipv4_address : "dhcp"
              gateway = var.cloud_init_mode == "native" && var.cloud_init_native != null ? var.cloud_init_native.ipv4_gateway : null
            }
          }

          dynamic "ipv6" {
            for_each = var.cloud_init_mode == "native" && var.cloud_init_native != null && var.cloud_init_native.ipv6_address != null ? [1] : []
            content {
              address = var.cloud_init_native.ipv6_address
              gateway = var.cloud_init_native.ipv6_gateway
            }
          }
        }
      }

      # Custom cloud-init file references
      user_data_file_id = (
        local.using_custom_cloud_init && var.cloud_init_custom.user_data != null ? proxmox_virtual_environment_file.user_data[0].id :
        local.using_builtin_cloud_init ? proxmox_virtual_environment_file.builtin_user_data[0].id :
        null
      )
      meta_data_file_id    = local.using_custom_cloud_init && var.cloud_init_custom.meta_data != null ? proxmox_virtual_environment_file.meta_data[0].id : null
      network_data_file_id = local.using_custom_cloud_init && var.cloud_init_custom.network_data != null ? proxmox_virtual_environment_file.network_data[0].id : null
      vendor_data_file_id  = local.using_custom_cloud_init && var.cloud_init_custom.vendor_data != null ? proxmox_virtual_environment_file.vendor_data[0].id : null
    }
  }

  migrate = var.migrate
  on_boot = var.on_boot
  protection = var.protection

  tags = local.effective_tags

  description = var.description

  lifecycle {
    # Ignore cloud-init configuration changes after initial creation
    # This is the expected behavior - cloud-init runs once at creation time
    ignore_changes = [
      # Ignore cloud image source after initial creation. This allows
      # day-2 updates to proceed even if source image files are rotated out.
      disk[0].file_id,
      # Custom cloud-init file references
      initialization[0].user_data_file_id,
      initialization[0].meta_data_file_id,
      initialization[0].network_data_file_id,
      initialization[0].vendor_data_file_id,
      # Native cloud-init parameters
      initialization[0].user_account,
      initialization[0].dns,
      initialization[0].ip_config,
    ]
  }
}