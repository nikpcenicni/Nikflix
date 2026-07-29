variable "proxmox_endpoint" {
  description = "Proxmox API URL of any node in the `noble` cluster, e.g. https://192.168.10.10:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in `user@realm!token-id=uuid` form. Create with a role scoped to VM.Allocate/VM.Config.*/VM.Console/Datastore.AllocateSpace on the relevant nodes, not root@pam."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification of the Proxmox API cert. The `noble` nodes use the self-signed cert Proxmox generates on install (see ansible/ - no cert management happens there)."
  type        = bool
  default     = true
}

variable "talos_version" {
  description = "Talos release to install, e.g. v1.13.7. Not pinned by docs/architecture/talos.md yet (see its Open Questions) - check https://github.com/siderolabs/talos/releases and update here when you decide."
  type        = string
  default     = "v1.13.7"
}

variable "talos_schematic_id" {
  description = <<-EOT
    Talos Image Factory (https://factory.talos.dev) schematic ID used to build the installer ISO.
    Defaults to the factory's "no extensions" schematic (the ID for an empty customization block -
    regenerate with `curl -X POST https://factory.talos.dev/schematics -d '{"customization":{}}'`
    if the factory ever changes its hashing and this stops resolving). Generate a custom one at
    https://factory.talos.dev if you want the qemu-guest-agent system extension baked in (needed
    for Proxmox to see the VM's IP/status without waiting for Talos to expose it another way).
  EOT
  type        = string
  default     = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
}

variable "iso_storage" {
  description = "Proxmox storage ID to hold the downloaded Talos ISO on each node. ISOs aren't shared storage in this cluster (see docs/architecture/proxmox.md), so one copy is downloaded per node that needs it."
  type        = string
  default     = "local"
}

variable "vm_storage" {
  description = "Proxmox storage ID backing VM boot disks, EFI disks, and the 'Longhorn' data disk. Unlike ../terraform's target-state config, this dev cluster deliberately keeps every disk on local-lvm rather than a dedicated per-node SSD pool - see the README for why."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_bridge_mgmt" {
  description = "Bridge carrying VLAN 10 (management) traffic - vmbr0, already present on all three existing nodes per docs/architecture/proxmox.md."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_bridge_storage" {
  description = "Bridge carrying VLAN 80 (Longhorn storage) traffic - vmbr2, which docs/architecture/talos.md says must be added on nic2 on every node before its VM(s) can get a second NIC. Not created by this Terraform config - see the README."
  type        = string
  default     = "vmbr2"
}

variable "enable_storage_nic" {
  description = "Whether to attach the second NIC (VLAN 80, Longhorn storage) to each VM. Requires the vmbr2 bridge to already exist on the target node (see README prerequisites). Defaults off for this dev cluster - it has no dedicated storage pool to route over that network anyway (see vm_storage)."
  type        = bool
  default     = false
}

variable "cpu_type" {
  description = "QEMU CPU type for the Talos VMs. x86-64-v2-AES is a portable baseline across the noble nodes' hardware, at some cost vs. `host`; revisit once actual CPU models are confirmed identical across all three nodes."
  type        = string
  default     = "x86-64-v2-AES"
}
