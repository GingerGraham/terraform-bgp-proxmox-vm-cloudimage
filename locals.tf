locals {
  selected_node       = var.node_name != null ? var.node_name : random_shuffle.node_selection[0].result[0]
  cloud_image_file_id = var.cloud_image_lookup_enabled ? data.proxmox_virtual_environment_file.cloud_image[0].id : null

  # Normalize legacy disk interface values (for example "virtio") to indexed
  # Proxmox device names expected by qm/proxmox APIs (for example "virtio0").
  disk_interface = contains(["ide", "sata", "scsi", "virtio"], var.disk_interface) ? "${var.disk_interface}0" : var.disk_interface

  primary_disk_match = regexall("^(ide|sata|scsi|virtio)([0-9]+)$", local.disk_interface)
  primary_disk_bus   = length(local.primary_disk_match) > 0 ? local.primary_disk_match[0][0] : "virtio"
  primary_disk_index = length(local.primary_disk_match) > 0 ? tonumber(local.primary_disk_match[0][1]) : 0

  normalized_additional_disk_interfaces = [
    for disk in var.additional_disks : (
      try(disk.interface, null) == null || trimspace(try(disk.interface, "")) == "" ? null : (
        contains(["ide", "sata", "scsi", "virtio"], lower(trimspace(disk.interface))) ?
        "${lower(trimspace(disk.interface))}0" :
        lower(trimspace(disk.interface))
      )
    )
  ]

  explicit_additional_primary_bus_indexes = [
    for iface in local.normalized_additional_disk_interfaces : tonumber(regexall("^(ide|sata|scsi|virtio)([0-9]+)$", iface)[0][1])
    if iface != null &&
    length(regexall("^(ide|sata|scsi|virtio)([0-9]+)$", iface)) > 0 &&
    regexall("^(ide|sata|scsi|virtio)([0-9]+)$", iface)[0][0] == local.primary_disk_bus
  ]

  used_primary_bus_indexes = distinct(concat([local.primary_disk_index], local.explicit_additional_primary_bus_indexes))

  auto_assigned_disk_positions = [
    for index, iface in local.normalized_additional_disk_interfaces : index
    if iface == null
  ]

  available_primary_bus_indexes = [
    for index in range(0, 31) : index
    if !contains(local.used_primary_bus_indexes, index)
  ]

  can_auto_assign_all_additional_disk_indexes = length(local.available_primary_bus_indexes) >= length(local.auto_assigned_disk_positions)

  auto_assigned_disk_interfaces_by_position = {
    for offset, position in local.auto_assigned_disk_positions :
    position => "${local.primary_disk_bus}${local.available_primary_bus_indexes[offset]}"
  }

  resolved_additional_disks = [
    for index, disk in var.additional_disks : merge(disk, {
      interface = (
        local.normalized_additional_disk_interfaces[index] != null
        ? local.normalized_additional_disk_interfaces[index]
        : try(local.auto_assigned_disk_interfaces_by_position[index], "${local.primary_disk_bus}0")
      )
    })
  ]

  resolved_all_disk_interfaces = concat(
    [local.disk_interface],
    [for disk in local.resolved_additional_disks : disk.interface]
  )

  all_resolved_disk_interfaces_valid = alltrue([
    for iface in local.resolved_all_disk_interfaces : can(regex("^(ide|sata|scsi|virtio)[0-9]+$", iface))
  ])

  resolved_disk_interfaces_are_unique = length(local.resolved_all_disk_interfaces) == length(distinct(local.resolved_all_disk_interfaces))

  # Use vm_name as hostname if hostname not explicitly provided
  effective_hostname_input = var.hostname != null ? var.hostname : var.vm_name

  effective_cpu_cores       = var.cpu_cores != null ? var.cpu_cores : (var.strict_provider_defaults ? 1 : 2)
  effective_cpu_type        = var.cpu_type != null ? var.cpu_type : (var.strict_provider_defaults ? "qemu64" : "host")
  effective_assigned_memory = var.assigned_memory != null ? var.assigned_memory : (var.strict_provider_defaults ? 512 : 4096)
  effective_minimum_memory  = var.minimum_memory != null ? var.minimum_memory : (var.strict_provider_defaults ? 0 : local.effective_assigned_memory)

  effective_bios_type     = var.bios_type != null ? var.bios_type : (var.strict_provider_defaults ? "seabios" : "ovmf")
  effective_disk_ssd      = var.disk_ssd != null ? var.disk_ssd : (var.strict_provider_defaults ? false : true)
  effective_disk_discard  = var.disk_discard != null ? var.disk_discard : (var.strict_provider_defaults ? "ignore" : "on")
  effective_disk_iothread = var.disk_iothread != null ? var.disk_iothread : (var.strict_provider_defaults ? false : true)

  effective_on_boot         = var.on_boot != null ? var.on_boot : (var.strict_provider_defaults ? true : false)
  effective_stop_on_destroy = var.stop_on_destroy != null ? var.stop_on_destroy : (var.strict_provider_defaults ? false : true)
  effective_migrate         = var.migrate != null ? var.migrate : (var.strict_provider_defaults ? false : true)
  effective_agent_enabled   = var.agent_enabled != null ? var.agent_enabled : (var.strict_provider_defaults ? false : true)
  effective_agent_timeout   = var.agent_timeout != null ? var.agent_timeout : (var.strict_provider_defaults ? "15m" : "10m")

  # Auto-select cloud-init interface based on BIOS type if not explicitly set
  cloud_init_interface = var.cloud_init_interface != null ? var.cloud_init_interface : (
    local.effective_bios_type == "ovmf" ? "sata0" : null # null lets provider use default ide2
  )

  effective_boot_order = var.boot_order

  serial_devices = length(var.serial_devices) > 0 ? var.serial_devices : [
    {
      device = "socket"
    }
  ]

  # Determine if we're using custom cloud-init
  using_custom_cloud_init = var.cloud_init_mode == "custom" && var.cloud_init_custom != null

  # Determine if we're using the built-in module template
  using_builtin_cloud_init = var.cloud_init_mode == "builtin" && var.cloud_init_builtin != null

  builtin_profiles = {
    generic = {
      sudo_groups        = ["sudo"]
      firewall_package   = ""
      firewall_enable    = ""
      firewall_open_ssh  = ""
      firewall_reload    = ""
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = null
    }
    fedora = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
    rhel = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
    centos_stream = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
    rocky = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
    almalinux = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
    ubuntu = {
      sudo_groups        = ["sudo"]
      firewall_package   = "ufw"
      firewall_enable    = "ufw --force enable"
      firewall_open_ssh  = "ufw allow OpenSSH"
      firewall_reload    = ""
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony/conf.d/makestep.conf"
    }
    debian = {
      sudo_groups        = ["sudo"]
      firewall_package   = "ufw"
      firewall_enable    = "ufw --force enable"
      firewall_open_ssh  = "ufw allow OpenSSH"
      firewall_reload    = ""
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony/conf.d/makestep.conf"
    }
    arch = {
      sudo_groups        = ["wheel"]
      firewall_package   = ""
      firewall_enable    = ""
      firewall_open_ssh  = ""
      firewall_reload    = ""
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = null
    }
    opensuse = {
      sudo_groups        = ["wheel"]
      firewall_package   = "firewalld"
      firewall_enable    = "systemctl enable --now firewalld"
      firewall_open_ssh  = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload    = "firewall-cmd --reload"
      qga_package        = "qemu-guest-agent"
      qga_service        = "qemu-guest-agent"
      chrony_dropin_path = "/etc/chrony.d/makestep.conf"
    }
  }

  builtin_profile_key = local.using_builtin_cloud_init ? lower(var.cloud_init_builtin.distro_profile) : "generic"
  builtin_profile     = local.using_builtin_cloud_init ? local.builtin_profiles[local.builtin_profile_key] : local.builtin_profiles.generic

  builtin_manage_qga = local.using_builtin_cloud_init ? (
    var.cloud_init_builtin.manage_qemu_guest_agent != null ?
    var.cloud_init_builtin.manage_qemu_guest_agent :
    local.effective_agent_enabled
  ) : false

  builtin_enable_firewall = local.using_builtin_cloud_init ? var.cloud_init_builtin.enable_firewall : false

  builtin_sudo_groups = local.using_builtin_cloud_init ? (
    var.cloud_init_builtin.sudo_groups != null && length(var.cloud_init_builtin.sudo_groups) > 0 ?
    var.cloud_init_builtin.sudo_groups :
    local.builtin_profile.sudo_groups
  ) : []

  builtin_chrony_write_files = local.using_builtin_cloud_init && local.builtin_profile.chrony_dropin_path != null ? [
    {
      path        = local.builtin_profile.chrony_dropin_path
      content     = "makestep 1.0 -1\n"
      owner       = "root:root"
      permissions = "0644"
    }
  ] : []

  builtin_chrony_inline_runcmd = local.using_builtin_cloud_init && local.builtin_profile.chrony_dropin_path == null ? [
    "grep -Eq '^[[:space:]]*makestep[[:space:]]+1\\.0[[:space:]]+-1([[:space:]]|$)' /etc/chrony.conf || printf '\\nmakestep 1.0 -1\\n' >> /etc/chrony.conf"
  ] : []

  builtin_write_files = local.using_builtin_cloud_init ? concat(
    local.builtin_chrony_write_files,
    var.cloud_init_builtin.write_files,
    var.cloud_init_builtin.extra_write_files
  ) : []

  builtin_packages = local.using_builtin_cloud_init ? distinct(concat(
    var.cloud_init_builtin.packages,
    var.cloud_init_builtin.extra_packages,
    local.builtin_enable_firewall && local.builtin_profile.firewall_package != "" ? [local.builtin_profile.firewall_package] : [],
    local.builtin_manage_qga ? [local.builtin_profile.qga_package] : []
  )) : []

  builtin_runcmd = local.using_builtin_cloud_init ? compact(concat(
    local.builtin_profile_key == "opensuse" && length(local.builtin_packages) > 0 ? [
      "command -v zypper >/dev/null 2>&1 && zypper --non-interactive refresh && zypper --non-interactive install --no-confirm ${join(" ", local.builtin_packages)} || true"
    ] : [],
    local.builtin_manage_qga ? [
      "systemctl list-unit-files ${local.builtin_profile.qga_service}.service >/dev/null 2>&1 && systemctl enable --now ${local.builtin_profile.qga_service} || true"
    ] : [],
    ["hostnamectl set-hostname ${local.effective_hostname_input}"],
    local.builtin_enable_firewall ? [
      local.builtin_profile.firewall_enable,
      local.builtin_profile.firewall_open_ssh,
      local.builtin_profile.firewall_reload
    ] : [],
    local.builtin_chrony_inline_runcmd,
    var.cloud_init_builtin.runcmd,
    var.cloud_init_builtin.extra_runcmd,
    ["chronyc makestep 2>/dev/null || true"]
  )) : []

  effective_tags = distinct(concat(
    var.tags_global,
    var.tags_environment,
    var.tags_role,
    var.tags_instance,
    var.tags
  ))

  # Rendered content for the built-in template (null when not in builtin mode)
  builtin_cloud_init_user_data = local.using_builtin_cloud_init ? templatefile(
    "${path.module}/templates/user-data-standard.yaml.tpl",
    {
      hostname    = split(".", local.effective_hostname_input)[0]
      fqdn        = length(split(".", local.effective_hostname_input)) > 1 ? local.effective_hostname_input : "${split(".", local.effective_hostname_input)[0]}.${var.cloud_init_builtin.dns_domain}"
      username    = var.cloud_init_builtin.username
      password    = var.cloud_init_builtin.password
      ssh_keys    = var.cloud_init_builtin.ssh_keys
      user_shell  = var.cloud_init_builtin.user_shell
      sudo_groups = local.builtin_sudo_groups
      timezone    = var.cloud_init_builtin.timezone
      dns_domain  = var.cloud_init_builtin.dns_domain
      lock_passwd = var.cloud_init_builtin.lock_passwd
      packages    = local.builtin_packages
      runcmd      = local.builtin_runcmd
      write_files = local.builtin_write_files
    }
  ) : null
}