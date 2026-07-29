# Talos virtual machine provisioning

This Terraform configuration creates six Talos Linux virtual machines (VMs)
on the Proxmox cluster named `noble`. The cluster and the VM layout come
from [docs/architecture/talos.md](../docs/architecture/talos.md) and
[docs/architecture/proxmox.md](../docs/architecture/proxmox.md).

This configuration creates the VM shell only: central processing unit
(CPU), random-access memory (RAM), disks, and network interface
controllers (NICs). Each VM boots from the Talos installer image in
maintenance mode. This configuration does not configure Talos itself.
Talos does not use cloud-init. You configure Talos on each VM afterward,
with `talosctl`, as a separate step after `terraform apply`.

## What this configuration creates

The configuration creates one `proxmox_download_file` resource per Proxmox
node that hosts an enabled VM, and one `proxmox_virtual_environment_vm`
resource per enabled VM.

| VM name | Proxmox node | Role | vCPU | Memory | Boot disk | Longhorn disk | Management IP | Storage IP | Enabled by default |
|---|---|---|---|---|---|---|---|---|---|
| talos-cp-helium | helium | control plane | 5 | 14 GiB | 64 GB | 1024 GB | 192.168.10.101 | 192.168.80.101 | yes |
| talos-cp-neon | neon | control plane | 5 | 14 GiB | 64 GB | 1024 GB | 192.168.10.102 | 192.168.80.102 | yes |
| talos-cp-argon | argon | control plane | 5 | 14 GiB | 64 GB | 1024 GB | 192.168.10.103 | 192.168.80.103 | yes |
| talos-worker-krypton | krypton | worker | 8 | 16 GiB | 32 GB | 2048 GB | 192.168.10.104 | 192.168.80.104 | no |
| talos-worker-xenon | xenon | worker | 8 | 16 GiB | 32 GB | 2048 GB | 192.168.10.105 | 192.168.80.105 | no |
| talos-worker-radon | radon | worker | 8 | 16 GiB | 32 GB | 2048 GB | 192.168.10.106 | 192.168.80.106 | no |

The worker VMs are disabled by default. Set `enable_worker_vms = true` to
create them (see [Variables](#variables)).

NOTE: The management IP and storage IP in the table are reference values
only. This configuration does not apply them. Talos ignores cloud-init, so
each VM comes up with a Dynamic Host Configuration Protocol (DHCP) address
in maintenance mode until you apply a machine configuration with
`talosctl`.

## Prerequisites

1. Install Terraform version 1.5.0 or later.
2. Check that the bridge `vmbr2` exists on `nic2` on every Proxmox node
   that will host a VM. This bridge must carry virtual local area network
   (VLAN) 80. This configuration does not create `vmbr2`. No automation in
   this repository creates it yet.
3. Create a Proxmox API token for a role that is not `root@pam`. The role
   must include the privileges in the table below.
4. Check which Proxmox nodes exist today. The talos.md document's phased
   rollout lists only `helium`, `neon`, and `argon` as built today.
   `krypton`, `xenon`, and `radon` are still planned. Leave
   `enable_worker_vms` at its default of `false` until those three nodes
   exist and join the `noble` cluster.

| Required privilege | Scope |
|---|---|
| `VM.Allocate` | relevant nodes/storage |
| `VM.Config.*` | relevant nodes/storage |
| `VM.PowerMgmt` | relevant nodes/storage |
| `VM.Console` | relevant nodes/storage |
| `Datastore.AllocateSpace` | relevant nodes/storage |
| `Datastore.Audit` | relevant nodes/storage |

CAUTION: If `vmbr2` does not exist on a node and `enable_storage_nic` is
`true`, the VM's second network device has no bridge to attach to.
`terraform apply` then fails on that node.

## Variables

Set `proxmox_endpoint` in `terraform.tfvars`. Set `proxmox_api_token` as an
environment variable instead — `export TF_VAR_proxmox_api_token="user@realm!token-id=uuid"`
— rather than in the file. Terraform maps any `TF_VAR_<name>` environment
variable to the matching declared variable automatically, so the token
never needs to sit in plaintext on disk. All other variables have defaults
in `variables.tf`.

| Variable | Type | Default | Required | Description |
|---|---|---|---|---|
| `proxmox_endpoint` | string | none | yes | Proxmox API URL of a node in the `noble` cluster, for example `https://192.168.10.10:8006/`. |
| `proxmox_api_token` | string (sensitive) | none | yes | Proxmox API token in `user@realm!token-id=uuid` form. Set via the `TF_VAR_proxmox_api_token` environment variable, not in `terraform.tfvars`. |
| `proxmox_insecure` | bool | `true` | no | Skip TLS certificate verification for the Proxmox API. |
| `talos_version` | string | `v1.13.7` | no | Talos release to install. |
| `talos_schematic_id` | string | `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba` | no | Talos Image Factory schematic ID for the installer image. The default is the schematic for no extensions. |
| `iso_storage` | string | `local` | no | Proxmox storage ID for the downloaded Talos installer image on each node. |
| `vm_storage` | string | `local-lvm` | no | Proxmox storage ID for VM boot disks, EFI disks, and the Longhorn data disk. |
| `proxmox_bridge_mgmt` | string | `vmbr0` | no | Bridge for VLAN 10 (management) traffic. |
| `proxmox_bridge_storage` | string | `vmbr2` | no | Bridge for VLAN 80 (Longhorn storage) traffic. |
| `enable_storage_nic` | bool | `true` | no | Attach the second NIC (VLAN 80, Longhorn storage) to each VM. |
| `cpu_type` | string | `x86-64-v2-AES` | no | QEMU CPU type for the VMs. |
| `enable_worker_vms` | bool | `false` | no | Create the three worker VMs (`talos-worker-krypton`/`xenon`/`radon`). |

## Apply procedure

1. Change to the `terraform` directory.
2. Copy `terraform.tfvars.example` to `terraform.tfvars`.
3. In `terraform.tfvars`, set `proxmox_endpoint`. Leave the other variables
   at their defaults unless your setup differs from the talos.md and
   proxmox.md documents.
4. Export `TF_VAR_proxmox_api_token` in your shell with your Proxmox API
   token. Do not put it in `terraform.tfvars`.
5. Run `terraform init`.
6. Run `terraform plan`.
7. Review the plan output.
8. Run `terraform apply`.
9. Run `terraform output talos_vms` to get each VM's Proxmox node, VM ID,
   and planned IP addresses.
9. For each VM, generate a Talos machine configuration with `talosctl gen
   config`.
10. Apply that configuration to the VM with `talosctl apply-config`,
    against the VM's DHCP-assigned maintenance-mode address.

NOTE: `terraform apply` downloads the Talos installer image to each
Proxmox node that needs it before it creates the VMs. Steps 9 and 10 are
not part of this repository yet.

## Output

The `talos_vms` output returns a map of VM name to node, VM ID, role,
management IP, and storage IP, for every enabled VM. Use this output in
the `talosctl` steps above.

## Design notes and open questions

These notes carry over from talos.md.

- **Longhorn disk backing.** The second disk on each VM (`scsi1`) is a
  Proxmox-managed virtual disk on `var.vm_storage`, not a passthrough of
  the physical device. The talos.md document leaves passthrough versus a
  storage pool as an open question.

CAUTION: Passthrough is simpler for Longhorn, but a storage pool keeps
live migration available. Change the `scsi1` disk block in `vms.tf` to
passthrough before any VM holds real Longhorn data. A later change is
disruptive.

- **CPU type.** `var.cpu_type` defaults to `x86-64-v2-AES`, not `host`,
  because you have not yet confirmed that the six nodes' CPUs are
  identical. `host` gives better performance but blocks live migration
  across nodes with different CPUs. Revisit this default once you confirm
  the CPU models match.
- **VLAN tagging.** Both `network_device` blocks in `vms.tf` leave the
  VLAN untagged. The proxmox.md document states that VLANs 10, 80, and
  100 are native, untagged VLANs on the switch ports in this cluster, not
  802.1Q trunks. If the switch configuration ever changes to tagged
  trunking, add `vlan_id` to the matching `network_device` block.
- **qemu-guest-agent.** Each VM enables `agent.enabled = true`, but the
  agent only reports status if the Talos image includes the
  `qemu-guest-agent` extension. Build a custom schematic at
  https://factory.talos.dev to include that extension. Set
  `talos_schematic_id` to the resulting schematic ID.
- **VM ID numbering.** VM IDs 101 through 106 match the last octet of
  each VM's management IP from talos.md's topology table. This is a
  convention for cross-reference, not a Proxmox requirement.
