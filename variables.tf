variable "vm_name" {
  description = "Name of the VM in Proxmox (will be used as default hostname if hostname not specified)"
  type        = string
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
    node_name    = string  # Node where the image is stored
    datastore_id = string  # Datastore where image is located
    content_type = string  # Usually "import"
    file_name    = string  # Filename of the cloud image
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
    user_data    = optional(string)  # Cloud-config YAML content
    meta_data    = optional(string)  # Meta-data content
    network_data = optional(string)  # Network configuration
    vendor_data  = optional(string)  # Vendor-specific data
    datastore_id = string            # Where to store snippet files
  })
  default = null
}

# Built-in cloud-init configuration (used when cloud_init_mode = "builtin")
# The module renders its standard template internally from these parameters.
variable "cloud_init_builtin" {
  description = "Built-in standard cloud-init configuration rendered by the module. Use with cloud_init_mode = 'builtin'."
  type = object({
    datastore_id             = string                    # Where to store the snippet file
    username                 = string                    # Primary user to create
    password                 = optional(string, "")     # User password (empty = no password auth)
    ssh_keys                 = optional(list(string), [])
    timezone                 = optional(string, "UTC")
    dns_domain               = optional(string, "local")
    lock_passwd              = optional(bool, false)
    distro_profile           = optional(string, "generic")
    user_shell               = optional(string, "/bin/bash")
    sudo_groups              = optional(list(string))
    packages                 = optional(list(string), [])
    extra_packages           = optional(list(string), [])
    enable_firewall          = optional(bool, false)
    manage_qemu_guest_agent = optional(bool)
    runcmd                   = optional(list(string), [])
    extra_runcmd             = optional(list(string), [])
    write_files              = optional(list(object({
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
  default     = 2
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "assigned_memory" {
  description = "Assigned memory in MB"
  type        = number
  default     = 4096
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
  default     = true
}

variable "disk_discard" {
  description = "Enable discard/TRIM"
  type        = string
  default     = "on"
}

variable "disk_iothread" {
  description = "Enable iothread"
  type        = bool
  default     = true
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
  default     = "ovmf"
}

variable "cloud_init_interface" {
  description = "Interface for cloud-init drive (defaults based on BIOS type: sata0 for OVMF, ide2 for SeaBIOS)"
  type        = string
  default     = null  # null means auto-select based on bios_type
}

variable "auto_dhcp_on_builtin_custom" {
  description = "Automatically set IPv4 DHCP in Proxmox ip_config for builtin mode and for custom mode when network_data is not supplied"
  type        = bool
  default     = true
}

variable "efi_disk" {
  description = "EFI disk configuration for OVMF BIOS"
  type = object({
    datastore_id = string
    file_format  = optional(string, "raw")
    type         = optional(string, "4m")
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
  default     = false
}

variable "stop_on_destroy" {
  description = "Stop VM on destroy instead of shutdown"
  type        = bool
  default     = true
}

variable "migrate" {
  description = "Allow VM migration"
  type        = bool
  default     = true
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
  default     = true
}

variable "agent_timeout" {
  description = "How long to wait for QEMU guest agent during create/update"
  type        = string
  default     = "10m"
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
