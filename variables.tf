variable "vm_name" {
  description = "Name of the VM in Proxmox (will be used as default hostname if hostname not specified)"
  type        = string
}

variable "strict_provider_defaults" {
  description = "When true, unset module inputs resolve to documented bpg/proxmox provider defaults instead of legacy module defaults"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Hostname for cloud-init (defaults to vm_name if not specified)"
  type        = string
  default     = null
}

variable "vm_id" {
  description = "VM ID (null for auto-assignment)"
  type        = number
  default     = null
}

variable "node_name" {
  description = "Proxmox node to deploy to (null for random selection from cluster)"
  type        = string
  default     = null
}

variable "cluster_nodes" {
  description = "List of cluster nodes for random selection (required if node_name is null)"
  type        = list(string)
  default     = []
}

# Cloud image configuration
variable "cloud_image_reference" {
  description = "Reference to cloud image file for cloning"
  type = object({
    node_name    = string # Node where the image is stored
    datastore_id = string # Datastore where image is located
    content_type = string # Usually "import"
    file_name    = string # Filename of the cloud image
  })
}

variable "cloud_image_lookup_enabled" {
  description = "Whether to resolve cloud image by filename on each plan/apply. Set to false after initial create to avoid lookup failures when image files are later removed from datastore."
  type        = bool
  default     = true
}

# Cloud-init configuration mode
variable "cloud_init_mode" {
  description = "Cloud-init mode: 'native' for Proxmox native, 'custom' for caller-rendered YAML, 'builtin' for module standard template"
  type        = string
  default     = "custom"
  validation {
    condition     = contains(["native", "custom", "builtin"], var.cloud_init_mode)
    error_message = "cloud_init_mode must be 'native', 'custom', or 'builtin'"
  }

  validation {
    condition = (
      (var.cloud_init_mode == "native" && var.cloud_init_native != null && var.cloud_init_custom == null && var.cloud_init_builtin == null) ||
      (var.cloud_init_mode == "custom" && var.cloud_init_custom != null && var.cloud_init_native == null && var.cloud_init_builtin == null) ||
      (var.cloud_init_mode == "builtin" && var.cloud_init_builtin != null && var.cloud_init_native == null && var.cloud_init_custom == null)
    )
    error_message = "Exactly one cloud-init configuration object must be set for the selected cloud_init_mode"
  }
}

# Native cloud-init configuration (used when cloud_init_mode = "native")
variable "cloud_init_native" {
  description = "Native Proxmox cloud-init configuration"
  type = object({
    user_name     = optional(string)
    user_password = optional(string)
    ssh_keys      = optional(list(string), [])
    dns_domain    = optional(string)
    dns_servers   = optional(list(string), [])
    ipv4_address  = optional(string, "dhcp")
    ipv4_gateway  = optional(string)
    ipv6_address  = optional(string)
    ipv6_gateway  = optional(string)
  })
  default = null
}

# Custom cloud-init configuration (used when cloud_init_mode = "custom")
variable "cloud_init_custom" {
  description = "Custom cloud-init data files"
  type = object({
    user_data    = optional(string) # Cloud-config YAML content
    meta_data    = optional(string) # Meta-data content
    network_data = optional(string) # Network configuration
    vendor_data  = optional(string) # Vendor-specific data
    datastore_id = string           # Where to store snippet files
  })
  default = null
}

# Built-in cloud-init configuration (used when cloud_init_mode = "builtin")
# The module renders its standard template internally from these parameters.
variable "cloud_init_builtin" {
  description = "Built-in standard cloud-init configuration rendered by the module. Use with cloud_init_mode = 'builtin'."
  type = object({
    datastore_id            = string               # Where to store the snippet file
    username                = string               # Primary user to create
    password                = optional(string, "") # User password (empty = no password auth)
    ssh_keys                = optional(list(string), [])
    timezone                = optional(string, "UTC")
    dns_domain              = optional(string, "local")
    lock_passwd             = optional(bool, false)
    distro_profile          = optional(string, "generic")
    user_shell              = optional(string, "/bin/bash")
    sudo_groups             = optional(list(string))
    packages                = optional(list(string), [])
    extra_packages          = optional(list(string), [])
    enable_firewall         = optional(bool, false)
    manage_qemu_guest_agent = optional(bool)
    runcmd                  = optional(list(string), [])
    extra_runcmd            = optional(list(string), [])
    write_files = optional(list(object({
      path        = string
      content     = string
      owner       = optional(string, "root:root")
      permissions = optional(string, "0644")
    })), [])
    extra_write_files = optional(list(object({
      path        = string
      content     = string
      owner       = optional(string, "root:root")
      permissions = optional(string, "0644")
    })), [])
  })
  default = null

  validation {
    condition = var.cloud_init_builtin == null ? true : contains([
      "generic",
      "fedora",
      "ubuntu",
      "opensuse"
    ], lower(var.cloud_init_builtin.distro_profile))
    error_message = "cloud_init_builtin.distro_profile must be one of: generic, fedora, ubuntu, opensuse"
  }
}

# Compute resources
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = null
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = null
}

variable "assigned_memory" {
  description = "Assigned memory in MB"
  type        = number
  default     = null
}

variable "minimum_memory" {
  description = "Minimum memory in MB (defaults to assigned_memory when null)"
  type        = number
  default     = null
}

# Storage configuration
variable "disk_datastore" {
  description = "Datastore for VM disks"
  type        = string
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "disk_interface" {
  description = "Disk interface type"
  type        = string
  default     = "scsi0"
}

variable "disk_ssd" {
  description = "Mark disk as SSD"
  type        = bool
  default     = null
}

variable "disk_discard" {
  description = "Enable discard/TRIM"
  type        = string
  default     = null
}

variable "disk_iothread" {
  description = "Enable iothread"
  type        = bool
  default     = null
}

# Network configuration
variable "network_bridge" {
  description = "Network bridge"
  type        = string
}

variable "network_model" {
  description = "Network device model"
  type        = string
  default     = "virtio"
}

# System configuration
variable "bios_type" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = null
}

variable "cloud_init_interface" {
  description = "Interface for cloud-init drive (defaults based on BIOS type: sata0 for OVMF, ide2 for SeaBIOS)"
  type        = string
  default     = null # null means auto-select based on bios_type
}

variable "auto_dhcp_on_builtin_custom" {
  description = "Automatically set IPv4 DHCP in Proxmox ip_config for builtin mode and for custom mode when network_data is not supplied"
  type        = bool
  default     = true
}

variable "efi_disk" {
  description = "EFI disk configuration for OVMF BIOS"
  type = object({
    datastore_id      = string
    file_format       = optional(string, "raw")
    type              = optional(string, "4m")
    pre_enrolled_keys = optional(bool, false)
  })
  default = null
}

variable "os_type" {
  description = "Operating system type"
  type        = string
  default     = "l26" # Linux 2.6+ kernel
}

variable "keyboard_layout" {
  description = "Keyboard layout"
  type        = string
  default     = "en-us"
}

# VM behavior
variable "on_boot" {
  description = "Start VM on host boot"
  type        = bool
  default     = null
}

variable "stop_on_destroy" {
  description = "Stop VM on destroy instead of shutdown"
  type        = bool
  default     = null
}

variable "migrate" {
  description = "Allow VM migration"
  type        = bool
  default     = null
}

variable "protection" {
  description = "Sets the protection flag for the VM and disables the remove VM and remove disk operations"
  type        = bool
  default     = false
}

# QEMU agent
variable "agent_enabled" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = null
}

variable "agent_timeout" {
  description = "How long to wait for QEMU guest agent during create/update"
  type        = string
  default     = null
}

# Tags and metadata
variable "tags" {
  description = "VM tags"
  type        = list(string)
  default     = []
}

variable "tags_global" {
  description = "Global tags merged before tags"
  type        = list(string)
  default     = ["server", "linux"]
}

variable "tags_environment" {
  description = "Environment tags merged before tags"
  type        = list(string)
  default     = []
}

variable "tags_role" {
  description = "Role tags merged before tags"
  type        = list(string)
  default     = []
}

variable "tags_instance" {
  description = "Instance-specific tags merged before tags"
  type        = list(string)
  default     = []
}

variable "description" {
  description = "VM description"
  type        = string
  default     = ""
}

variable "acpi" {
  description = "Whether to enable ACPI"
  type        = bool
  default     = true
}

variable "boot_order" {
  description = "Optional explicit boot order list (for example [\"scsi0\", \"ide2\"])"
  type        = list(string)
  default     = null
}

variable "delete_unreferenced_disks_on_destroy" {
  description = "Delete unreferenced disks on destroy"
  type        = bool
  default     = true
}

variable "purge_on_destroy" {
  description = "Purge VM from backup jobs on destroy"
  type        = bool
  default     = true
}

variable "reboot" {
  description = "Reboot VM after initial creation"
  type        = bool
  default     = false
}

variable "reboot_after_update" {
  description = "Reboot VM after update if needed"
  type        = bool
  default     = true
}

variable "started" {
  description = "Whether to start VM"
  type        = bool
  default     = true
}

variable "tablet_device" {
  description = "Enable USB tablet device"
  type        = bool
  default     = true
}

variable "template" {
  description = "Whether to create as VM template"
  type        = bool
  default     = false
}

variable "pool_id" {
  description = "Optional Proxmox pool ID to assign the VM"
  type        = string
  default     = null
}

variable "machine" {
  description = "VM machine type"
  type        = string
  default     = "pc"

  validation {
    condition     = can(regex("^(pc|q35(,viommu=(virtio|intel))?)$", var.machine))
    error_message = "machine must be 'pc', 'q35', 'q35,viommu=virtio', or 'q35,viommu=intel'"
  }
}

variable "scsi_hardware" {
  description = "SCSI hardware type"
  type        = string
  default     = "virtio-scsi-pci"

  validation {
    condition = contains([
      "lsi",
      "lsi53c810",
      "virtio-scsi-pci",
      "virtio-scsi-single",
      "megasas",
      "pvscsi"
    ], var.scsi_hardware)
    error_message = "scsi_hardware must be one of: lsi, lsi53c810, virtio-scsi-pci, virtio-scsi-single, megasas, pvscsi"
  }
}

variable "hotplug" {
  description = "Hotplug feature string (for example 'network,disk,usb', '1', or '0')"
  type        = string
  default     = null
}

variable "kvm_arguments" {
  description = "Arbitrary arguments passed to KVM"
  type        = string
  default     = null
}

variable "hook_script_file_id" {
  description = "Optional hook script file ID"
  type        = string
  default     = null
}

variable "agent_trim" {
  description = "Enable QEMU agent FSTRIM"
  type        = bool
  default     = false
}

variable "agent_type" {
  description = "QEMU agent interface type"
  type        = string
  default     = "virtio"

  validation {
    condition     = contains(["virtio", "isa"], var.agent_type)
    error_message = "agent_type must be 'virtio' or 'isa'"
  }
}

variable "agent_wait_for_ipv4" {
  description = "Wait for at least one non-link-local IPv4 address from guest agent"
  type        = bool
  default     = false
}

variable "agent_wait_for_ipv6" {
  description = "Wait for at least one non-link-local IPv6 address from guest agent"
  type        = bool
  default     = false
}

variable "cpu_additional" {
  description = "Additional CPU options"
  type = object({
    architecture = optional(string)
    flags        = optional(list(string), [])
    hotplugged   = optional(number)
    limit        = optional(number)
    numa         = optional(bool)
    sockets      = optional(number)
    units        = optional(number)
    affinity     = optional(string)
  })
  default = null
}

variable "memory_additional" {
  description = "Additional memory options"
  type = object({
    shared         = optional(number)
    hugepages      = optional(string)
    keep_hugepages = optional(bool)
  })
  default = null

  validation {
    condition = var.memory_additional == null || var.memory_additional.hugepages == null || contains([
      "2",
      "1024",
      "any"
    ], var.memory_additional.hugepages)
    error_message = "memory_additional.hugepages must be one of: 2, 1024, any"
  }
}

variable "disk_advanced" {
  description = "Advanced settings for the primary disk"
  type = object({
    aio         = optional(string)
    backup      = optional(bool)
    cache       = optional(string)
    file_format = optional(string)
    replicate   = optional(bool)
    serial      = optional(string)
    speed = optional(object({
      iops_read            = optional(number)
      iops_read_burstable  = optional(number)
      iops_write           = optional(number)
      iops_write_burstable = optional(number)
      read                 = optional(number)
      read_burstable       = optional(number)
      write                = optional(number)
      write_burstable      = optional(number)
    }))
  })
  default = null

  validation {
    condition = var.disk_advanced == null || var.disk_advanced.aio == null || contains([
      "io_uring",
      "native",
      "threads"
    ], var.disk_advanced.aio)
    error_message = "disk_advanced.aio must be one of: io_uring, native, threads"
  }

  validation {
    condition = var.disk_advanced == null || var.disk_advanced.cache == null || contains([
      "none",
      "directsync",
      "writethrough",
      "writeback",
      "unsafe"
    ], var.disk_advanced.cache)
    error_message = "disk_advanced.cache must be one of: none, directsync, writethrough, writeback, unsafe"
  }

  validation {
    condition = var.disk_advanced == null || var.disk_advanced.file_format == null || contains([
      "qcow2",
      "raw",
      "vmdk"
    ], var.disk_advanced.file_format)
    error_message = "disk_advanced.file_format must be one of: qcow2, raw, vmdk"
  }
}

variable "additional_disks" {
  description = "Additional disk blocks"
  type = list(object({
    interface         = string
    datastore_id      = optional(string)
    file_id           = optional(string)
    import_from       = optional(string)
    path_in_datastore = optional(string)
    size              = optional(number)
    aio               = optional(string)
    backup            = optional(bool)
    cache             = optional(string)
    discard           = optional(string)
    file_format       = optional(string)
    iothread          = optional(bool)
    replicate         = optional(bool)
    serial            = optional(string)
    ssd               = optional(bool)
    speed = optional(object({
      iops_read            = optional(number)
      iops_read_burstable  = optional(number)
      iops_write           = optional(number)
      iops_write_burstable = optional(number)
      read                 = optional(number)
      read_burstable       = optional(number)
      write                = optional(number)
      write_burstable      = optional(number)
    }))
  }))
  default = []
}

variable "network_advanced" {
  description = "Advanced settings for the primary network device"
  type = object({
    disconnected = optional(bool)
    enabled      = optional(bool)
    firewall     = optional(bool)
    mac_address  = optional(string)
    mtu          = optional(number)
    queues       = optional(number)
    rate_limit   = optional(number)
    vlan_id      = optional(number)
    trunks       = optional(string)
  })
  default = null
}

variable "additional_network_devices" {
  description = "Additional network_device blocks"
  type = list(object({
    bridge       = optional(string)
    disconnected = optional(bool)
    enabled      = optional(bool)
    firewall     = optional(bool)
    mac_address  = optional(string)
    model        = optional(string)
    mtu          = optional(number)
    queues       = optional(number)
    rate_limit   = optional(number)
    vlan_id      = optional(number)
    trunks       = optional(string)
  }))
  default = []
}

variable "audio_device" {
  description = "Optional audio device configuration"
  type = object({
    enabled = optional(bool)
    device  = optional(string)
    driver  = optional(string)
  })
  default = null
}

variable "cdrom" {
  description = "Optional CD-ROM configuration"
  type = object({
    file_id   = optional(string)
    interface = optional(string, "ide3")
  })
  default = null

  validation {
    condition     = var.cdrom == null || var.cdrom.interface == null || can(regex("^(ide|sata|scsi)[0-9]+$", var.cdrom.interface))
    error_message = "cdrom.interface must match ideN, sataN, or scsiN (for example ide3, sata2, scsi0)"
  }
}

variable "initialization_advanced" {
  description = "Advanced initialization block controls"
  type = object({
    datastore_id = optional(string)
    interface    = optional(string)
    file_format  = optional(string)
  })
  default = null

  validation {
    condition = var.initialization_advanced == null || var.initialization_advanced.file_format == null || contains([
      "qcow2",
      "raw",
      "vmdk"
    ], var.initialization_advanced.file_format)
    error_message = "initialization_advanced.file_format must be one of: qcow2, raw, vmdk"
  }
}

variable "vga" {
  description = "Optional VGA configuration"
  type = object({
    type      = optional(string)
    memory    = optional(number)
    clipboard = optional(string)
  })
  default = null
}

variable "watchdog" {
  description = "Optional watchdog configuration"
  type = object({
    enabled = optional(bool)
    model   = optional(string)
    action  = optional(string)
  })
  default = null
}

variable "startup" {
  description = "Optional startup/shutdown behavior"
  type = object({
    order      = number
    up_delay   = optional(number)
    down_delay = optional(number)
  })
  default = null
}

variable "rng" {
  description = "Optional random number generator configuration"
  type = object({
    source    = string
    max_bytes = optional(number)
    period    = optional(number)
  })
  default = null
}

variable "tpm_state" {
  description = "Optional TPM state device"
  type = object({
    datastore_id = optional(string)
    version      = optional(string)
  })
  default = null

  validation {
    condition = var.tpm_state == null || var.tpm_state.version == null || contains([
      "v1.2",
      "v2.0"
    ], var.tpm_state.version)
    error_message = "tpm_state.version must be one of: v1.2, v2.0"
  }
}

variable "smbios" {
  description = "Optional SMBIOS type1 configuration"
  type = object({
    family       = optional(string)
    manufacturer = optional(string)
    product      = optional(string)
    serial       = optional(string)
    sku          = optional(string)
    uuid         = optional(string)
    version      = optional(string)
  })
  default = null
}

variable "clone" {
  description = "Optional clone configuration"
  type = object({
    vm_id        = number
    full         = optional(bool)
    datastore_id = optional(string)
    node_name    = optional(string)
    retries      = optional(number)
  })
  default = null
}

variable "amd_sev" {
  description = "Optional AMD SEV configuration"
  type = object({
    type           = optional(string)
    allow_smt      = optional(bool)
    kernel_hashes  = optional(bool)
    no_debug       = optional(bool)
    no_key_sharing = optional(bool)
  })
  default = null

  validation {
    condition = var.amd_sev == null || var.amd_sev.type == null || contains([
      "std",
      "es",
      "snp"
    ], var.amd_sev.type)
    error_message = "amd_sev.type must be one of: std, es, snp"
  }
}

variable "hostpci" {
  description = "Optional host PCI passthrough mappings"
  type = list(object({
    device   = string
    id       = optional(string)
    mapping  = optional(string)
    mdev     = optional(string)
    pcie     = optional(bool)
    rombar   = optional(bool)
    rom_file = optional(string)
    xvga     = optional(bool)
  }))
  default = []
}

variable "usb" {
  description = "Optional USB passthrough mappings"
  type = list(object({
    host    = optional(string)
    mapping = optional(string)
    usb3    = optional(bool)
  }))
  default = []
}

variable "virtiofs" {
  description = "Optional virtiofs mappings"
  type = list(object({
    mapping      = string
    cache        = optional(string)
    direct_io    = optional(bool)
    expose_acl   = optional(bool)
    expose_xattr = optional(bool)
  }))
  default = []
}

variable "numa" {
  description = "Optional NUMA topology configuration"
  type = list(object({
    device    = string
    cpus      = string
    memory    = number
    hostnodes = optional(string)
    policy    = optional(string)
  }))
  default = []
}

variable "serial_devices" {
  description = "Serial devices. Empty list keeps a single default socket serial device for backwards compatibility."
  type = list(object({
    device = optional(string)
  }))
  default = []
}

variable "timeout_clone" {
  description = "Timeout for cloning VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_create" {
  description = "Timeout for creating VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_migrate" {
  description = "Timeout for migrating VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_reboot" {
  description = "Timeout for rebooting VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_shutdown_vm" {
  description = "Timeout for shutting down VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_start_vm" {
  description = "Timeout for starting VM in seconds"
  type        = number
  default     = 1800
}

variable "timeout_stop_vm" {
  description = "Timeout for stopping VM in seconds"
  type        = number
  default     = 300
}
