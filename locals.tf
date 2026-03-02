locals {
  selected_node = var.node_name != null ? var.node_name : random_shuffle.node_selection[0].result[0]
  cloud_image_file_id = var.cloud_image_lookup_enabled ? data.proxmox_virtual_environment_file.cloud_image[0].id : null

  # Normalize legacy disk interface values (for example "virtio") to indexed
  # Proxmox device names expected by qm/proxmox APIs (for example "virtio0").
  disk_interface = contains(["ide", "sata", "scsi", "virtio"], var.disk_interface) ? "${var.disk_interface}0" : var.disk_interface

  # Use vm_name as hostname if hostname not explicitly provided
  effective_hostname_input = var.hostname != null ? var.hostname : var.vm_name

  # Auto-select cloud-init interface based on BIOS type if not explicitly set
  cloud_init_interface = var.cloud_init_interface != null ? var.cloud_init_interface : (
    var.bios_type == "ovmf" ? "sata0" : null  # null lets provider use default ide2
  )

  # Determine if we're using custom cloud-init
  using_custom_cloud_init = var.cloud_init_mode == "custom" && var.cloud_init_custom != null

  # Determine if we're using the built-in module template
  using_builtin_cloud_init = var.cloud_init_mode == "builtin" && var.cloud_init_builtin != null

  builtin_profiles = {
    generic = {
      sudo_groups      = ["sudo"]
      firewall_package = ""
      firewall_enable  = ""
      firewall_open_ssh = ""
      firewall_reload   = ""
      qga_package      = "qemu-guest-agent"
      qga_service      = "qemu-guest-agent"
    }
    fedora = {
      sudo_groups      = ["wheel"]
      firewall_package = "firewalld"
      firewall_enable  = "systemctl enable --now firewalld"
      firewall_open_ssh = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload   = "firewall-cmd --reload"
      qga_package      = "qemu-guest-agent"
      qga_service      = "qemu-guest-agent"
    }
    ubuntu = {
      sudo_groups      = ["sudo"]
      firewall_package = "ufw"
      firewall_enable  = "ufw --force enable"
      firewall_open_ssh = "ufw allow OpenSSH"
      firewall_reload   = ""
      qga_package      = "qemu-guest-agent"
      qga_service      = "qemu-guest-agent"
    }
    opensuse = {
      sudo_groups      = ["wheel"]
      firewall_package = "firewalld"
      firewall_enable  = "systemctl enable --now firewalld"
      firewall_open_ssh = "firewall-cmd --permanent --add-service=ssh"
      firewall_reload   = "firewall-cmd --reload"
      qga_package      = "qemu-guest-agent"
      qga_service      = "qemu-guest-agent"
    }
  }

  builtin_profile_key = local.using_builtin_cloud_init ? lower(var.cloud_init_builtin.distro_profile) : "generic"
  builtin_profile     = local.using_builtin_cloud_init ? local.builtin_profiles[local.builtin_profile_key] : local.builtin_profiles.generic

  builtin_manage_qga = local.using_builtin_cloud_init ? (
    var.cloud_init_builtin.manage_qemu_guest_agent != null ?
    var.cloud_init_builtin.manage_qemu_guest_agent :
    var.agent_enabled
  ) : false

  builtin_enable_firewall = local.using_builtin_cloud_init ? var.cloud_init_builtin.enable_firewall : false

  builtin_sudo_groups = local.using_builtin_cloud_init ? (
    var.cloud_init_builtin.sudo_groups != null && length(var.cloud_init_builtin.sudo_groups) > 0 ?
    var.cloud_init_builtin.sudo_groups :
    local.builtin_profile.sudo_groups
  ) : []

  builtin_write_files = local.using_builtin_cloud_init ? concat(
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
    var.cloud_init_builtin.runcmd,
    var.cloud_init_builtin.extra_runcmd
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
      hostname          = split(".", local.effective_hostname_input)[0]
      fqdn              = length(split(".", local.effective_hostname_input)) > 1 ? local.effective_hostname_input : "${split(".", local.effective_hostname_input)[0]}.${var.cloud_init_builtin.dns_domain}"
      username          = var.cloud_init_builtin.username
      password          = var.cloud_init_builtin.password
      ssh_keys          = var.cloud_init_builtin.ssh_keys
      user_shell        = var.cloud_init_builtin.user_shell
      sudo_groups       = local.builtin_sudo_groups
      timezone          = var.cloud_init_builtin.timezone
      dns_domain        = var.cloud_init_builtin.dns_domain
      lock_passwd       = var.cloud_init_builtin.lock_passwd
      packages          = local.builtin_packages
      runcmd            = local.builtin_runcmd
      write_files       = local.builtin_write_files
    }
  ) : null
}