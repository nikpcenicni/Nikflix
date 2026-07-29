# Talos VM provisioning - development cluster

This Terraform configuration creates the Virtual Machine (VM) shells for the
interim development Talos cluster. It runs on the three Proxmox nodes that
exist today: `helium`, `neon`, and `argon`. The target-state design in
[docs/architecture/talos.md](../../docs/architecture/talos.md) uses three
more nodes (`krypton`, `xenon`, `radon`) that are not yet available. This
configuration is the scaled-down stand-in for that design. See
[../../terraform](../../terraform) for the target-state configuration.

This configuration provisions VM shells only. It does not configure Talos
itself. After `terraform apply` finishes, you must generate a Talos
machine config for each VM. Then you must apply each config with
`talosctl`. See [../talos/README.md](../talos/README.md) for that step.

## What this configuration provisions

The configuration creates six VMs, two on each of the three Proxmox nodes:
one control plane VM and one worker VM per node. Each VM boots from a Talos
installer image in ISO format. The configuration downloads this image once
per node. The table below lists each VM's node, ID, virtual CPU (vCPU)
count, memory, disk sizes, and planned IP addresses.

| VM name | Node | Role | VM ID | vCPU | Memory | Boot disk | Storage disk | Management IP | Storage IP |
|---|---|---|---|---|---|---|---|---|---|
| talos-dev-cp-helium | helium | controlplane | 201 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.121 | 192.168.80.121 |
| talos-dev-worker-helium | helium | worker | 202 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.122 | 192.168.80.122 |
| talos-dev-cp-neon | neon | controlplane | 203 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.123 | 192.168.80.123 |
| talos-dev-worker-neon | neon | worker | 204 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.124 | 192.168.80.124 |
| talos-dev-cp-argon | argon | controlplane | 205 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.125 | 192.168.80.125 |
| talos-dev-worker-argon | argon | worker | 206 | 2 | 2 GiB | 20 GB | 20 GB | 192.168.10.126 | 192.168.80.126 |

NOTE: The `mgmt_ip` and `storage_ip` values above show the intended
address for each VM. This Terraform configuration does not apply them.
Talos ignores cloud-init. You must set the network config for each VM
later, with `talosctl` (see [../talos/README.md](../talos/README.md)).

Each VM has this shape:

- Machine type `q35`, with `ovmf` (UEFI) BIOS. Talos requires UEFI boot.
- One EFI disk and two data disks (`scsi0` for the Talos boot/install disk,
  `scsi1` as a placeholder for a future Longhorn storage disk). Both disks
  sit on the storage pool in `var.vm_storage`.
- One Network Interface Card (NIC) on the management bridge
  (`var.proxmox_bridge_mgmt`, Virtual Local Area Network (VLAN) 10). A
  second NIC on the storage bridge (`var.proxmox_bridge_storage`, VLAN 80)
  is optional. See `var.enable_storage_nic` below.
- A CD-ROM device (`ide2`) that holds the Talos installer ISO. The boot
  order is `scsi0` first, then `ide2`. Talos installs itself onto the
  `scsi0` disk on first boot. The VM boots from that disk on every later
  boot.

CAUTION: Every VM in this configuration uses `var.vm_storage`
(`local-lvm`) for both disks. No dedicated per-node SSD pool for Longhorn
exists yet. During setup, the `argon` node's second disk showed write
errors and a high `Program_Fail_Cnt_Total` value, and the `neon` node did
not detect a second disk at all. Only `helium` has a working dedicated SSD
pool, but this configuration does not use it. Read the resource comments in
`vms.tf` for the full story before you change `vm_storage`.

## Talos installer image

The configuration downloads the Talos installer ISO from the Talos Image
Factory (`https://factory.talos.dev`) directly to each Proxmox node's local
storage, one download per node. The image URL combines three values:

- `var.talos_version` - the Talos release, for example `v1.13.7`.
- `var.talos_schematic_id` - the schematic ID from the Image Factory. The
  default value builds an image with no extensions. Generate a custom
  schematic ID at `https://factory.talos.dev` if you need the
  `qemu-guest-agent` system extension. With that extension, Proxmox can
  report the VM's IP address and status.
- `var.iso_storage` - the Proxmox storage ID for the downloaded ISO.

## Prerequisites

Before you run this configuration, complete these steps:

1. Create a Proxmox Application Programming Interface (API) token with a
   role scoped to `VM.Allocate`, `VM.Config.*`, `VM.Console`, and
   `Datastore.AllocateSpace` on the target nodes.
2. Check that the management bridge (`vmbr0` by default) exists on all
   three Proxmox nodes.
3. If you plan to set `enable_storage_nic` to `true`, create the storage
   bridge (`vmbr2` by default) on the target nodes first.

CAUTION: Do not use the `root@pam` account for the API token in step 1.

NOTE: This configuration does not create the storage bridge in step 3. You
must create it yourself before you enable `enable_storage_nic`.

## Variables

Set these variables in `terraform.tfvars`. Create this file by copying
`terraform.tfvars.example`. The repository's `.gitignore` excludes
`terraform.tfvars` from version control, but it does track
`terraform.tfvars.example`.

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `proxmox_endpoint` | Yes | none | Proxmox API URL of any node in the cluster, for example `https://192.168.10.10:8006/`. |
| `proxmox_api_token` | Yes | none | Proxmox API token, in `user@realm!token-id=uuid` form. |
| `proxmox_insecure` | No | `true` | Skip Transport Layer Security (TLS) certificate verification against the Proxmox API. |
| `talos_version` | No | `v1.13.7` | Talos release to install. |
| `talos_schematic_id` | No | Image Factory "no extensions" ID | Schematic ID from the Talos Image Factory, for the installer image. |
| `iso_storage` | No | `local` | Proxmox storage ID for the downloaded Talos ISO. |
| `vm_storage` | No | `local-lvm` | Proxmox storage ID for the EFI disk, boot disk, and storage disk. |
| `proxmox_bridge_mgmt` | No | `vmbr0` | Bridge for the management NIC (VLAN 10). |
| `proxmox_bridge_storage` | No | `vmbr2` | Bridge for the optional storage NIC (VLAN 80). |
| `enable_storage_nic` | No | `false` | Attach a second NIC on `proxmox_bridge_storage` to each VM. |
| `cpu_type` | No | `x86-64-v2-AES` | QEMU CPU type for the VMs. |

## Apply procedure

1. Change to this directory: `cd development/terraform`.
2. Copy the example variable file: `cp terraform.tfvars.example terraform.tfvars`.
3. Open `terraform.tfvars` and set `proxmox_endpoint` to your Proxmox API
   URL.
4. Set `proxmox_api_token` to your Proxmox API token in the same file.
5. Run `terraform init` to download the `bpg/proxmox` provider.
6. Run `terraform plan` to check the planned changes.
7. Run `terraform apply` to create the VMs.
8. Run `terraform output talos_vms` to list each VM's node, VM ID, role,
   and planned IP addresses.

NOTE: Leave the variables not listed in steps 3 and 4 at their defaults,
unless your setup differs from the defaults described in the table above.

NOTE: Use the values from `terraform output talos_vms` as input when you
generate the machine config with `talosctl`. See
[../talos/README.md](../talos/README.md) for that procedure.

## Design notes carried over from ../../terraform

For background on open questions this configuration inherits from the
target-state design (CPU type, untagged VLANs, the `qemu-guest-agent`
extension, and the VM ID convention), see
[../../terraform/README.md](../../terraform/README.md#design-notes-and-open-questions).
The one difference is storage: this configuration keeps every disk on
`local-lvm` instead of a dedicated SSD pool, as covered above.
