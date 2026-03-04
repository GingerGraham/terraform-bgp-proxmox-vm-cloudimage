resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = local.selected_node

  acpi = var.acpi

  stop_on_destroy                      = local.effective_stop_on_destroy
  purge_on_destroy                     = var.purge_on_destroy
  delete_unreferenced_disks_on_destroy = var.delete_unreferenced_disks_on_destroy

  reboot              = var.reboot
  reboot_after_update = var.reboot_after_update
  started             = var.started
  tablet_device       = var.tablet_device
  template            = var.template

  pool_id             = var.pool_id
  machine             = var.machine
  scsi_hardware       = var.scsi_hardware
  hotplug             = var.hotplug
  kvm_arguments       = var.kvm_arguments
  hook_script_file_id = var.hook_script_file_id

  boot_order = local.effective_boot_order

  agent {
    enabled = local.effective_agent_enabled
    timeout = local.effective_agent_timeout
    trim    = var.agent_trim
    type    = var.agent_type

    wait_for_ip {
      ipv4 = var.agent_wait_for_ipv4
      ipv6 = var.agent_wait_for_ipv6
    }
  }

  cpu {
    cores = local.effective_cpu_cores
    type  = local.effective_cpu_type

    architecture = try(var.cpu_additional.architecture, null)
    flags        = try(var.cpu_additional.flags, null)
    hotplugged   = try(var.cpu_additional.hotplugged, null)
    limit        = try(var.cpu_additional.limit, null)
    numa         = try(var.cpu_additional.numa, null)
    sockets      = try(var.cpu_additional.sockets, null)
    units        = try(var.cpu_additional.units, null)
    affinity     = try(var.cpu_additional.affinity, null)
  }

  memory {
    dedicated = local.effective_assigned_memory
    floating  = local.effective_minimum_memory

    shared         = try(var.memory_additional.shared, null)
    hugepages      = try(var.memory_additional.hugepages, null)
    keep_hugepages = try(var.memory_additional.keep_hugepages, null)
  }

  disk {
    datastore_id = var.disk_datastore
    file_id      = local.cloud_image_file_id
    interface    = local.disk_interface
    size         = var.disk_size_gb
    discard      = local.effective_disk_discard
    ssd          = local.effective_disk_ssd
    iothread     = local.effective_disk_iothread

    aio         = try(var.disk_advanced.aio, null)
    backup      = try(var.disk_advanced.backup, null)
    cache       = try(var.disk_advanced.cache, null)
    file_format = try(var.disk_advanced.file_format, null)
    replicate   = try(var.disk_advanced.replicate, null)
    serial      = try(var.disk_advanced.serial, null)

    dynamic "speed" {
      for_each = try(var.disk_advanced.speed, null) != null ? [var.disk_advanced.speed] : []
      content {
        iops_read            = try(speed.value.iops_read, null)
        iops_read_burstable  = try(speed.value.iops_read_burstable, null)
        iops_write           = try(speed.value.iops_write, null)
        iops_write_burstable = try(speed.value.iops_write_burstable, null)
        read                 = try(speed.value.read, null)
        read_burstable       = try(speed.value.read_burstable, null)
        write                = try(speed.value.write, null)
        write_burstable      = try(speed.value.write_burstable, null)
      }
    }
  }

  dynamic "disk" {
    for_each = local.resolved_additional_disks
    content {
      interface         = disk.value.interface
      datastore_id      = try(disk.value.datastore_id, null)
      file_id           = try(disk.value.file_id, null)
      import_from       = try(disk.value.import_from, null)
      path_in_datastore = try(disk.value.path_in_datastore, null)
      size              = try(disk.value.size, null)
      aio               = try(disk.value.aio, null)
      backup            = try(disk.value.backup, null)
      cache             = try(disk.value.cache, null)
      discard           = try(disk.value.discard, null)
      file_format       = try(disk.value.file_format, null)
      iothread          = try(disk.value.iothread, null)
      replicate         = try(disk.value.replicate, null)
      serial            = try(disk.value.serial, null)
      ssd               = try(disk.value.ssd, null)

      dynamic "speed" {
        for_each = try(disk.value.speed, null) != null ? [disk.value.speed] : []
        content {
          iops_read            = try(speed.value.iops_read, null)
          iops_read_burstable  = try(speed.value.iops_read_burstable, null)
          iops_write           = try(speed.value.iops_write, null)
          iops_write_burstable = try(speed.value.iops_write_burstable, null)
          read                 = try(speed.value.read, null)
          read_burstable       = try(speed.value.read_burstable, null)
          write                = try(speed.value.write, null)
          write_burstable      = try(speed.value.write_burstable, null)
        }
      }
    }
  }

  network_device {
    bridge = var.network_bridge
    model  = var.network_model

    disconnected = try(var.network_advanced.disconnected, null)
    enabled      = try(var.network_advanced.enabled, null)
    firewall     = try(var.network_advanced.firewall, null)
    mac_address  = try(var.network_advanced.mac_address, null)
    mtu          = try(var.network_advanced.mtu, null)
    queues       = try(var.network_advanced.queues, null)
    rate_limit   = try(var.network_advanced.rate_limit, null)
    vlan_id      = try(var.network_advanced.vlan_id, null)
    trunks       = try(var.network_advanced.trunks, null)
  }

  dynamic "network_device" {
    for_each = var.additional_network_devices
    content {
      bridge       = coalesce(try(network_device.value.bridge, null), var.network_bridge)
      model        = coalesce(try(network_device.value.model, null), var.network_model)
      disconnected = try(network_device.value.disconnected, null)
      enabled      = try(network_device.value.enabled, null)
      firewall     = try(network_device.value.firewall, null)
      mac_address  = try(network_device.value.mac_address, null)
      mtu          = try(network_device.value.mtu, null)
      queues       = try(network_device.value.queues, null)
      rate_limit   = try(network_device.value.rate_limit, null)
      vlan_id      = try(network_device.value.vlan_id, null)
      trunks       = try(network_device.value.trunks, null)
    }
  }

  operating_system {
    type = var.os_type
  }

  dynamic "audio_device" {
    for_each = var.audio_device != null ? [var.audio_device] : []
    content {
      enabled = try(audio_device.value.enabled, null)
      device  = try(audio_device.value.device, null)
      driver  = try(audio_device.value.driver, null)
    }
  }

  dynamic "cdrom" {
    for_each = var.cdrom != null ? [var.cdrom] : []
    content {
      file_id   = try(cdrom.value.file_id, null)
      interface = try(cdrom.value.interface, null)
    }
  }

  bios = local.effective_bios_type

  dynamic "efi_disk" {
    for_each = var.efi_disk != null ? [var.efi_disk] : []
    content {
      datastore_id      = efi_disk.value.datastore_id
      file_format       = efi_disk.value.file_format
      type              = efi_disk.value.type
      pre_enrolled_keys = try(efi_disk.value.pre_enrolled_keys, null)
    }
  }

  dynamic "tpm_state" {
    for_each = var.tpm_state != null ? [var.tpm_state] : []
    content {
      datastore_id = try(tpm_state.value.datastore_id, null)
      version      = try(tpm_state.value.version, null)
    }
  }

  dynamic "rng" {
    for_each = var.rng != null ? [var.rng] : []
    content {
      source    = rng.value.source
      max_bytes = try(rng.value.max_bytes, null)
      period    = try(rng.value.period, null)
    }
  }

  dynamic "smbios" {
    for_each = var.smbios != null ? [var.smbios] : []
    content {
      family       = try(smbios.value.family, null)
      manufacturer = try(smbios.value.manufacturer, null)
      product      = try(smbios.value.product, null)
      serial       = try(smbios.value.serial, null)
      sku          = try(smbios.value.sku, null)
      uuid         = try(smbios.value.uuid, null)
      version      = try(smbios.value.version, null)
    }
  }

  dynamic "startup" {
    for_each = var.startup != null ? [var.startup] : []
    content {
      order      = startup.value.order
      up_delay   = try(startup.value.up_delay, null)
      down_delay = try(startup.value.down_delay, null)
    }
  }

  dynamic "watchdog" {
    for_each = var.watchdog != null ? [var.watchdog] : []
    content {
      enabled = try(watchdog.value.enabled, null)
      model   = try(watchdog.value.model, null)
      action  = try(watchdog.value.action, null)
    }
  }

  dynamic "vga" {
    for_each = var.vga != null ? [var.vga] : []
    content {
      type      = try(vga.value.type, null)
      memory    = try(vga.value.memory, null)
      clipboard = try(vga.value.clipboard, null)
    }
  }

  dynamic "clone" {
    for_each = var.clone != null ? [var.clone] : []
    content {
      vm_id        = clone.value.vm_id
      full         = try(clone.value.full, null)
      datastore_id = try(clone.value.datastore_id, null)
      node_name    = try(clone.value.node_name, null)
      retries      = try(clone.value.retries, null)
    }
  }

  dynamic "amd_sev" {
    for_each = var.amd_sev != null ? [var.amd_sev] : []
    content {
      type           = try(amd_sev.value.type, null)
      allow_smt      = try(amd_sev.value.allow_smt, null)
      kernel_hashes  = try(amd_sev.value.kernel_hashes, null)
      no_debug       = try(amd_sev.value.no_debug, null)
      no_key_sharing = try(amd_sev.value.no_key_sharing, null)
    }
  }

  dynamic "hostpci" {
    for_each = var.hostpci
    content {
      device   = hostpci.value.device
      id       = try(hostpci.value.id, null)
      mapping  = try(hostpci.value.mapping, null)
      mdev     = try(hostpci.value.mdev, null)
      pcie     = try(hostpci.value.pcie, null)
      rombar   = try(hostpci.value.rombar, null)
      rom_file = try(hostpci.value.rom_file, null)
      xvga     = try(hostpci.value.xvga, null)
    }
  }

  dynamic "usb" {
    for_each = var.usb
    content {
      host    = try(usb.value.host, null)
      mapping = try(usb.value.mapping, null)
      usb3    = try(usb.value.usb3, null)
    }
  }

  dynamic "virtiofs" {
    for_each = var.virtiofs
    content {
      mapping      = virtiofs.value.mapping
      cache        = try(virtiofs.value.cache, null)
      direct_io    = try(virtiofs.value.direct_io, null)
      expose_acl   = try(virtiofs.value.expose_acl, null)
      expose_xattr = try(virtiofs.value.expose_xattr, null)
    }
  }

  dynamic "numa" {
    for_each = var.numa
    content {
      device    = numa.value.device
      cpus      = numa.value.cpus
      memory    = numa.value.memory
      hostnodes = try(numa.value.hostnodes, null)
      policy    = try(numa.value.policy, null)
    }
  }

  keyboard_layout = var.keyboard_layout

  dynamic "serial_device" {
    for_each = local.serial_devices
    content {
      device = try(serial_device.value.device, null)
    }
  }

  # Cloud-init initialization block
  dynamic "initialization" {
    for_each = [1]
    content {
      datastore_id = coalesce(try(var.initialization_advanced.datastore_id, null), var.disk_datastore)
      interface    = coalesce(try(var.initialization_advanced.interface, null), local.cloud_init_interface)
      file_format  = try(var.initialization_advanced.file_format, null)

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

  migrate    = local.effective_migrate
  on_boot    = local.effective_on_boot
  protection = var.protection

  timeout_clone       = var.timeout_clone
  timeout_create      = var.timeout_create
  timeout_migrate     = var.timeout_migrate
  timeout_reboot      = var.timeout_reboot
  timeout_shutdown_vm = var.timeout_shutdown_vm
  timeout_start_vm    = var.timeout_start_vm
  timeout_stop_vm     = var.timeout_stop_vm

  tags = local.effective_tags

  description = var.description

  lifecycle {
    precondition {
      condition     = local.can_auto_assign_all_additional_disk_indexes
      error_message = "Unable to auto-assign additional disk interfaces because no free indices remain on the primary disk bus. Provide explicit additional_disks[*].interface values to continue."
    }

    precondition {
      condition     = local.all_resolved_disk_interfaces_valid
      error_message = "All resolved disk interfaces must match ideN, sataN, scsiN, or virtioN."
    }

    precondition {
      condition     = local.resolved_disk_interfaces_are_unique
      error_message = "Duplicate disk interfaces detected across primary and additional disks. Each disk interface must be unique."
    }

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