# proxmox_vm_linux_cloudinit

Reusable Terraform module for provisioning cloud-init VMs on Proxmox VE with the `bpg/proxmox` provider.

## Public module usage

This module is designed to be consumed as a standalone public module:

- No dependency on private/local helper modules
- All deployment-specific settings are exposed as input variables
- Provider configuration is expected in the caller (root module)

## Minimal example

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = false
}

module "vm" {
  source = "<org>/proxmox-vm-linux-cloudinit/proxmox"

  vm_name       = "app-01"
  cluster_nodes = ["pve1", "pve2"]

  cloud_image_reference = {
    node_name    = "pve1"
    datastore_id = "local"
    content_type = "import"
    file_name    = "debian-12-genericcloud-amd64.qcow2"
  }

  cloud_init_mode = "builtin"
  cloud_init_builtin = {
    datastore_id   = "local"
    distro_profile = "ubuntu"
    username       = "ops"
    ssh_keys       = ["ssh-ed25519 AAAA..."]
    timezone       = "UTC"
    dns_domain     = "example.internal"
  }

  disk_datastore = "local-lvm"
  network_bridge = "vmbr0"

  efi_disk = {
    datastore_id = "local-lvm"
  }
}
```

## Cloud-init modes

- `builtin`: module renders cloud-init from structured inputs (`cloud_init_builtin`)
- `custom`: caller passes rendered cloud-init payloads (`cloud_init_custom`)
- `native`: uses Proxmox native cloud-init fields only (`cloud_init_native`)

## Migration from Earlier Versions

**Important:** This module has been updated to support `bpg/proxmox` provider version `0.97.1` with expanded VM configuration options.

See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for:

- List of variables with changed defaults
- Migration strategies for existing deployments
- Details on the new `strict_provider_defaults` compatibility toggle

**Quick summary:** By default, legacy module defaults are preserved (`strict_provider_defaults = false`). No immediate action is required for existing deployments, but explicitly setting values is recommended for production workloads.

## Advanced Features

This module now supports the full feature set of the `proxmox_virtual_environment_vm` resource, including:

- **Advanced CPU options**: architecture, flags, hotplug, NUMA, affinity
- **Advanced memory options**: shared memory, hugepages
- **Advanced disk options**: AIO mode, cache policy, speed limits, backup control
- **Additional disks**: attach multiple disks with per-disk configuration
- **Additional network devices**: multi-NIC VMs with VLAN tagging and rate limiting
- **Hardware passthrough**: PCIe devices, USB devices, virtiofs mappings
- **Security**: TPM state device, AMD SEV encryption
- **System devices**: audio, VGA, watchdog, RNG
- **NUMA topology**: explicit NUMA node configuration
- **Lifecycle control**: startup order, reboot behavior, protection flags
- **Timeouts**: per-operation timeout customization

Refer to the inputs table below for the complete list of available options.

## Disk interface expectations and behavior

The module supports a primary disk (`disk_interface`) and optional additional
disks (`additional_disks`). Disk interfaces are handled with the following
rules.

- Primary disk accepts `scsi`, `sata`, or `virtio` with optional index.
  - Bus-only values are normalized to index `0`.
  - Examples: `scsi` -> `scsi0`, `virtio` -> `virtio0`, `sata2` stays `sata2`.
- Additional disks accept `ide`, `sata`, `scsi`, or `virtio` with optional
  index.
  - `interface` may be omitted (or set to empty string) for auto-assignment.
  - Bus-only values are normalized to index `0` (for example `virtio` ->
    `virtio0`).
  - `datastore_id` is optional; when omitted, the disk inherits
    `disk_datastore`.

### Auto-assignment for additional disks

When an additional disk omits `interface`, the module auto-assigns the next
available index on the same bus family as the primary disk interface.

- Primary disk `virtio0` with additional disks omitting interface will assign
  `virtio1`, `virtio2`, and so on, skipping any already-explicitly-used
  indexes.
- If no free index is available on that bus, planning fails with a clear error.

### Validation and safety checks

Before apply, the module enforces:

- Every resolved disk interface must match `ideN`, `sataN`, `scsiN`, or
  `virtioN`.
- Interface names must be unique across primary and additional disks.
- Auto-assignment must have enough free indexes for all disks with omitted
  interfaces.

### Datastore behavior for additional disks

- Primary disk always uses `disk_datastore`.
- Additional disks use `additional_disks[*].datastore_id` when provided.
- If `additional_disks[*].datastore_id` is omitted, it defaults to
  `disk_datastore`.

### Example: mixed explicit and auto-assigned additional disks

```hcl
module "vm" {
  # ...

  disk_interface = "virtio0"

  additional_disks = [
    {
      size = 50
      # interface omitted -> auto-assigned (virtio1)
    },
    {
      interface = "virtio3"
      size      = 100
    },
    {
      size = 200
      # interface omitted -> auto-assigned (virtio2)
    }
  ]
}
```

## Recommended consumer patterns

Use these defaults as a safe baseline for most deployments.

- Set the primary disk explicitly to index `0` (for example `virtio0` or
  `scsi0`).
- Prefer omitting `additional_disks[*].interface` unless you need deterministic
  device naming.
- Keep all additional disks on one bus family per VM unless you have a specific
  hardware/guest requirement.
- Set `disk_datastore` explicitly and only override per-disk `datastore_id`
  when required.
- Use explicit disk sizes and avoid relying on implied defaults in production.

### Recommended baseline (copy/paste)

```hcl
module "vm" {
  # ...

  disk_datastore = "local-lvm"
  disk_interface = "virtio0"
  disk_size_gb   = 40
  disk_discard   = "on"
  disk_iothread  = true
  disk_ssd       = true

  additional_disks = [
    {
      size = 100
    },
    {
      size = 200
    }
  ]
}
```

### When to set explicit additional disk interfaces

Set explicit `additional_disks[*].interface` only when you need stable,
predefined device addresses for guest-level automation, monitoring, or strict
OS mount mapping expectations.

### Common anti-patterns to avoid

- Setting primary disk to a non-zero index without a clear reason.
- Manually assigning additional disk indexes that collide with primary or other
  additional disks.
- Mixing auto-assigned and manually assigned interfaces without checking index
  gaps and intent.
- Using bus-only values expecting non-zero indexes (for example `virtio` always
  normalizes to `virtio0`).

## Documentation workflow (`terraform-docs`)

This repository uses `terraform-docs` to keep variable and output references accurate.

- Config file: `.terraform-docs.yml`
- Injection markers are present near the end of this README

Preferred commands from repository root:

```bash
make docs
make docs-check
```

Equivalent script commands:

```bash
./scripts/terraform-docs-generate.sh
./scripts/terraform-docs-check.sh
```

Underlying Podman invocation:

```bash
podman run --rm \
  -v "$PWD:/terraform-docs:Z" \
  -w /terraform-docs \
  quay.io/terraform-docs/terraform-docs:latest \
  markdown table --config /terraform-docs/.terraform-docs.yml .
```

<!-- BEGIN_TF_DOCS -->
## Terraform Reference

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| proxmox | ~> 0.97.1 |

## Providers

| Name | Version |
|------|---------|
| proxmox | ~> 0.97.1 |
| random | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_file.builtin_user_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_file.meta_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_file.network_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_file.user_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_file.vendor_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.vm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [random_shuffle.node_selection](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/shuffle) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| acpi | Whether to enable ACPI | `bool` | `true` | no |
| additional\_disks | Additional disk blocks | <pre>list(object({<br/>    interface         = optional(string)<br/>    datastore_id      = optional(string)<br/>    file_id           = optional(string)<br/>    import_from       = optional(string)<br/>    path_in_datastore = optional(string)<br/>    size              = optional(number)<br/>    aio               = optional(string)<br/>    backup            = optional(bool)<br/>    cache             = optional(string)<br/>    discard           = optional(string)<br/>    file_format       = optional(string)<br/>    iothread          = optional(bool)<br/>    replicate         = optional(bool)<br/>    serial            = optional(string)<br/>    ssd               = optional(bool)<br/>    speed = optional(object({<br/>      iops_read            = optional(number)<br/>      iops_read_burstable  = optional(number)<br/>      iops_write           = optional(number)<br/>      iops_write_burstable = optional(number)<br/>      read                 = optional(number)<br/>      read_burstable       = optional(number)<br/>      write                = optional(number)<br/>      write_burstable      = optional(number)<br/>    }))<br/>  }))</pre> | `[]` | no |
| additional\_network\_devices | Additional network\_device blocks | <pre>list(object({<br/>    bridge       = optional(string)<br/>    disconnected = optional(bool)<br/>    enabled      = optional(bool)<br/>    firewall     = optional(bool)<br/>    mac_address  = optional(string)<br/>    model        = optional(string)<br/>    mtu          = optional(number)<br/>    queues       = optional(number)<br/>    rate_limit   = optional(number)<br/>    vlan_id      = optional(number)<br/>    trunks       = optional(string)<br/>  }))</pre> | `[]` | no |
| agent\_enabled | Enable QEMU guest agent | `bool` | `null` | no |
| agent\_timeout | How long to wait for QEMU guest agent during create/update | `string` | `null` | no |
| agent\_trim | Enable QEMU agent FSTRIM | `bool` | `false` | no |
| agent\_type | QEMU agent interface type | `string` | `"virtio"` | no |
| agent\_wait\_for\_ipv4 | Wait for at least one non-link-local IPv4 address from guest agent | `bool` | `false` | no |
| agent\_wait\_for\_ipv6 | Wait for at least one non-link-local IPv6 address from guest agent | `bool` | `false` | no |
| amd\_sev | Optional AMD SEV configuration | <pre>object({<br/>    type           = optional(string)<br/>    allow_smt      = optional(bool)<br/>    kernel_hashes  = optional(bool)<br/>    no_debug       = optional(bool)<br/>    no_key_sharing = optional(bool)<br/>  })</pre> | `null` | no |
| assigned\_memory | Assigned memory in MB | `number` | `null` | no |
| audio\_device | Optional audio device configuration | <pre>object({<br/>    enabled = optional(bool)<br/>    device  = optional(string)<br/>    driver  = optional(string)<br/>  })</pre> | `null` | no |
| auto\_dhcp\_on\_builtin\_custom | Automatically set IPv4 DHCP in Proxmox ip\_config for builtin mode and for custom mode when network\_data is not supplied | `bool` | `true` | no |
| bios\_type | BIOS type (seabios or ovmf) | `string` | `null` | no |
| boot\_order | Optional explicit boot order list (for example ["scsi0", "ide2"]) | `list(string)` | `null` | no |
| cdrom | Optional CD-ROM configuration | <pre>object({<br/>    file_id   = optional(string)<br/>    interface = optional(string, "ide3")<br/>  })</pre> | `null` | no |
| clone | Optional clone configuration | <pre>object({<br/>    vm_id        = number<br/>    full         = optional(bool)<br/>    datastore_id = optional(string)<br/>    node_name    = optional(string)<br/>    retries      = optional(number)<br/>  })</pre> | `null` | no |
| cloud\_image\_lookup\_enabled | Whether to resolve cloud image by filename on each plan/apply. Set to false after initial create to avoid lookup failures when image files are later removed from datastore. | `bool` | `true` | no |
| cloud\_image\_reference | Reference to cloud image file for cloning | <pre>object({<br/>    node_name    = string # Node where the image is stored<br/>    datastore_id = string # Datastore where image is located<br/>    content_type = string # Usually "import"<br/>    file_name    = string # Filename of the cloud image<br/>  })</pre> | n/a | yes |
| cloud\_init\_builtin | Built-in standard cloud-init configuration rendered by the module. Use with cloud\_init\_mode = 'builtin'. | <pre>object({<br/>    datastore_id            = string               # Where to store the snippet file<br/>    username                = string               # Primary user to create<br/>    password                = optional(string, "") # User password (empty = no password auth)<br/>    ssh_keys                = optional(list(string), [])<br/>    timezone                = optional(string, "UTC")<br/>    dns_domain              = optional(string, "local")<br/>    lock_passwd             = optional(bool, false)<br/>    distro_profile          = optional(string, "generic")<br/>    user_shell              = optional(string, "/bin/bash")<br/>    sudo_groups             = optional(list(string))<br/>    packages                = optional(list(string), [])<br/>    extra_packages          = optional(list(string), [])<br/>    enable_firewall         = optional(bool, false)<br/>    manage_qemu_guest_agent = optional(bool)<br/>    runcmd                  = optional(list(string), [])<br/>    extra_runcmd            = optional(list(string), [])<br/>    write_files = optional(list(object({<br/>      path        = string<br/>      content     = string<br/>      owner       = optional(string, "root:root")<br/>      permissions = optional(string, "0644")<br/>    })), [])<br/>    extra_write_files = optional(list(object({<br/>      path        = string<br/>      content     = string<br/>      owner       = optional(string, "root:root")<br/>      permissions = optional(string, "0644")<br/>    })), [])<br/>  })</pre> | `null` | no |
| cloud\_init\_custom | Custom cloud-init data files | <pre>object({<br/>    user_data    = optional(string) # Cloud-config YAML content<br/>    meta_data    = optional(string) # Meta-data content<br/>    network_data = optional(string) # Network configuration<br/>    vendor_data  = optional(string) # Vendor-specific data<br/>    datastore_id = string           # Where to store snippet files<br/>  })</pre> | `null` | no |
| cloud\_init\_interface | Interface for cloud-init drive (defaults based on BIOS type: sata0 for OVMF, ide2 for SeaBIOS) | `string` | `null` | no |
| cloud\_init\_mode | Cloud-init mode: 'native' for Proxmox native, 'custom' for caller-rendered YAML, 'builtin' for module standard template | `string` | `"custom"` | no |
| cloud\_init\_native | Native Proxmox cloud-init configuration | <pre>object({<br/>    user_name     = optional(string)<br/>    user_password = optional(string)<br/>    ssh_keys      = optional(list(string), [])<br/>    dns_domain    = optional(string)<br/>    dns_servers   = optional(list(string), [])<br/>    ipv4_address  = optional(string, "dhcp")<br/>    ipv4_gateway  = optional(string)<br/>    ipv6_address  = optional(string)<br/>    ipv6_gateway  = optional(string)<br/>  })</pre> | `null` | no |
| cluster\_nodes | List of cluster nodes for random selection (required if node\_name is null) | `list(string)` | `[]` | no |
| cpu\_additional | Additional CPU options | <pre>object({<br/>    architecture = optional(string)<br/>    flags        = optional(list(string), [])<br/>    hotplugged   = optional(number)<br/>    limit        = optional(number)<br/>    numa         = optional(bool)<br/>    sockets      = optional(number)<br/>    units        = optional(number)<br/>    affinity     = optional(string)<br/>  })</pre> | `null` | no |
| cpu\_cores | Number of CPU cores | `number` | `null` | no |
| cpu\_type | CPU type | `string` | `null` | no |
| delete\_unreferenced\_disks\_on\_destroy | Delete unreferenced disks on destroy | `bool` | `true` | no |
| description | VM description | `string` | `""` | no |
| disk\_advanced | Advanced settings for the primary disk | <pre>object({<br/>    aio         = optional(string)<br/>    backup      = optional(bool)<br/>    cache       = optional(string)<br/>    file_format = optional(string)<br/>    replicate   = optional(bool)<br/>    serial      = optional(string)<br/>    speed = optional(object({<br/>      iops_read            = optional(number)<br/>      iops_read_burstable  = optional(number)<br/>      iops_write           = optional(number)<br/>      iops_write_burstable = optional(number)<br/>      read                 = optional(number)<br/>      read_burstable       = optional(number)<br/>      write                = optional(number)<br/>      write_burstable      = optional(number)<br/>    }))<br/>  })</pre> | `null` | no |
| disk\_datastore | Datastore for VM disks | `string` | n/a | yes |
| disk\_discard | Enable discard/TRIM | `string` | `null` | no |
| disk\_interface | Primary disk interface (indexed form like scsi0/virtio1, or bus-only scsi/sata/virtio which normalizes to index 0) | `string` | `"scsi0"` | no |
| disk\_iothread | Enable iothread | `bool` | `null` | no |
| disk\_size\_gb | Disk size in GB | `number` | `20` | no |
| disk\_ssd | Mark disk as SSD | `bool` | `null` | no |
| efi\_disk | EFI disk configuration for OVMF BIOS | <pre>object({<br/>    datastore_id      = string<br/>    file_format       = optional(string, "raw")<br/>    type              = optional(string, "4m")<br/>    pre_enrolled_keys = optional(bool, false)<br/>  })</pre> | `null` | no |
| hook\_script\_file\_id | Optional hook script file ID | `string` | `null` | no |
| hostname | Hostname for cloud-init (defaults to vm\_name if not specified) | `string` | `null` | no |
| hostpci | Optional host PCI passthrough mappings | <pre>list(object({<br/>    device   = string<br/>    id       = optional(string)<br/>    mapping  = optional(string)<br/>    mdev     = optional(string)<br/>    pcie     = optional(bool)<br/>    rombar   = optional(bool)<br/>    rom_file = optional(string)<br/>    xvga     = optional(bool)<br/>  }))</pre> | `[]` | no |
| hotplug | Hotplug feature string (for example 'network,disk,usb', '1', or '0') | `string` | `null` | no |
| initialization\_advanced | Advanced initialization block controls | <pre>object({<br/>    datastore_id = optional(string)<br/>    interface    = optional(string)<br/>    file_format  = optional(string)<br/>  })</pre> | `null` | no |
| keyboard\_layout | Keyboard layout | `string` | `"en-us"` | no |
| kvm\_arguments | Arbitrary arguments passed to KVM | `string` | `null` | no |
| machine | VM machine type | `string` | `"pc"` | no |
| memory\_additional | Additional memory options | <pre>object({<br/>    shared         = optional(number)<br/>    hugepages      = optional(string)<br/>    keep_hugepages = optional(bool)<br/>  })</pre> | `null` | no |
| migrate | Allow VM migration | `bool` | `null` | no |
| minimum\_memory | Minimum memory in MB (defaults to assigned\_memory when null) | `number` | `null` | no |
| network\_advanced | Advanced settings for the primary network device | <pre>object({<br/>    disconnected = optional(bool)<br/>    enabled      = optional(bool)<br/>    firewall     = optional(bool)<br/>    mac_address  = optional(string)<br/>    mtu          = optional(number)<br/>    queues       = optional(number)<br/>    rate_limit   = optional(number)<br/>    vlan_id      = optional(number)<br/>    trunks       = optional(string)<br/>  })</pre> | `null` | no |
| network\_bridge | Network bridge | `string` | n/a | yes |
| network\_model | Network device model | `string` | `"virtio"` | no |
| node\_name | Proxmox node to deploy to (null for random selection from cluster) | `string` | `null` | no |
| numa | Optional NUMA topology configuration | <pre>list(object({<br/>    device    = string<br/>    cpus      = string<br/>    memory    = number<br/>    hostnodes = optional(string)<br/>    policy    = optional(string)<br/>  }))</pre> | `[]` | no |
| on\_boot | Start VM on host boot | `bool` | `null` | no |
| os\_type | Operating system type | `string` | `"l26"` | no |
| pool\_id | Optional Proxmox pool ID to assign the VM | `string` | `null` | no |
| protection | Sets the protection flag for the VM and disables the remove VM and remove disk operations | `bool` | `false` | no |
| purge\_on\_destroy | Purge VM from backup jobs on destroy | `bool` | `true` | no |
| reboot | Reboot VM after initial creation | `bool` | `false` | no |
| reboot\_after\_update | Reboot VM after update if needed | `bool` | `true` | no |
| rng | Optional random number generator configuration | <pre>object({<br/>    source    = string<br/>    max_bytes = optional(number)<br/>    period    = optional(number)<br/>  })</pre> | `null` | no |
| scsi\_hardware | SCSI hardware type | `string` | `"virtio-scsi-pci"` | no |
| serial\_devices | Serial devices. Empty list keeps a single default socket serial device for backwards compatibility. | <pre>list(object({<br/>    device = optional(string)<br/>  }))</pre> | `[]` | no |
| smbios | Optional SMBIOS type1 configuration | <pre>object({<br/>    family       = optional(string)<br/>    manufacturer = optional(string)<br/>    product      = optional(string)<br/>    serial       = optional(string)<br/>    sku          = optional(string)<br/>    uuid         = optional(string)<br/>    version      = optional(string)<br/>  })</pre> | `null` | no |
| started | Whether to start VM | `bool` | `true` | no |
| startup | Optional startup/shutdown behavior | <pre>object({<br/>    order      = number<br/>    up_delay   = optional(number)<br/>    down_delay = optional(number)<br/>  })</pre> | `null` | no |
| stop\_on\_destroy | Stop VM on destroy instead of shutdown | `bool` | `null` | no |
| strict\_provider\_defaults | When true, unset module inputs resolve to documented bpg/proxmox provider defaults instead of legacy module defaults | `bool` | `false` | no |
| tablet\_device | Enable USB tablet device | `bool` | `true` | no |
| tags | VM tags | `list(string)` | `[]` | no |
| tags\_environment | Environment tags merged before tags | `list(string)` | `[]` | no |
| tags\_global | Global tags merged before tags | `list(string)` | <pre>[<br/>  "server",<br/>  "linux"<br/>]</pre> | no |
| tags\_instance | Instance-specific tags merged before tags | `list(string)` | `[]` | no |
| tags\_role | Role tags merged before tags | `list(string)` | `[]` | no |
| template | Whether to create as VM template | `bool` | `false` | no |
| timeout\_clone | Timeout for cloning VM in seconds | `number` | `1800` | no |
| timeout\_create | Timeout for creating VM in seconds | `number` | `1800` | no |
| timeout\_migrate | Timeout for migrating VM in seconds | `number` | `1800` | no |
| timeout\_reboot | Timeout for rebooting VM in seconds | `number` | `1800` | no |
| timeout\_shutdown\_vm | Timeout for shutting down VM in seconds | `number` | `1800` | no |
| timeout\_start\_vm | Timeout for starting VM in seconds | `number` | `1800` | no |
| timeout\_stop\_vm | Timeout for stopping VM in seconds | `number` | `300` | no |
| tpm\_state | Optional TPM state device | <pre>object({<br/>    datastore_id = optional(string)<br/>    version      = optional(string)<br/>  })</pre> | `null` | no |
| usb | Optional USB passthrough mappings | <pre>list(object({<br/>    host    = optional(string)<br/>    mapping = optional(string)<br/>    usb3    = optional(bool)<br/>  }))</pre> | `[]` | no |
| vga | Optional VGA configuration | <pre>object({<br/>    type      = optional(string)<br/>    memory    = optional(number)<br/>    clipboard = optional(string)<br/>  })</pre> | `null` | no |
| virtiofs | Optional virtiofs mappings | <pre>list(object({<br/>    mapping      = string<br/>    cache        = optional(string)<br/>    direct_io    = optional(bool)<br/>    expose_acl   = optional(bool)<br/>    expose_xattr = optional(bool)<br/>  }))</pre> | `[]` | no |
| vm\_id | VM ID (null for auto-assignment) | `number` | `null` | no |
| vm\_name | Name of the VM in Proxmox (will be used as default hostname if hostname not specified) | `string` | n/a | yes |
| watchdog | Optional watchdog configuration | <pre>object({<br/>    enabled = optional(bool)<br/>    model   = optional(string)<br/>    action  = optional(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| ipv4\_addresses | IPv4 addresses of the VM |
| ipv6\_addresses | IPv6 addresses of the VM |
| mac\_addresses | MAC addresses of the VM |
| node\_name | The Proxmox node where the VM is deployed |
| vm\_id | The ID of the created VM |
| vm\_name | The name of the created VM |
<!-- END_TF_DOCS -->
