# Talos VM provisioning

Terraform config that creates the six Talos VMs described in
[docs/architecture/talos.md](../docs/architecture/talos.md), on top of the
`noble` Proxmox cluster documented in
[docs/architecture/proxmox.md](../docs/architecture/proxmox.md).

This only provisions the VM shells (CPU/RAM/disks/NICs, booted off the Talos
installer ISO in maintenance mode) — it does not configure Talos itself.
Talos is API-managed and ignores cloud-init; generating and applying each
node's machine config is a separate `talosctl` step, done after `apply`
here. That split matches the "Provisioning tooling" open question in
talos.md, which this config answers for the VM layer only.

## Prerequisites

These come from talos.md's phased rollout and are **not** done by this
config:

1. `vmbr2` (a bridge on `nic2`, carrying VLAN 80) must exist on every
   Proxmox node that will host a VM — currently an Ansible/manual gap, not
   automated anywhere yet. Without it, the second `network_device` on each
   VM has no bridge to attach to.
2. A Proxmox API token with a role scoped to at least
   `VM.Allocate`, `VM.Config.*`, `VM.PowerMgmt`, `VM.Console`,
   `Datastore.AllocateSpace`, and `Datastore.Audit` on the relevant
   nodes/storage — don't use `root@pam`.
3. Per talos.md's phase 1, only `helium`/`neon`/`argon` exist today.
   `krypton`/`xenon`/`radon` are still "planned" in proxmox.md — leave
   `enable_worker_vms = false` (the default) until they've been built and
   joined the `noble` cluster, or `apply` will fail trying to reach a node
   that doesn't exist.

## Usage

```sh
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: proxmox_endpoint, proxmox_api_token

terraform init
terraform plan
terraform apply
```

`terraform apply` downloads the Talos ISO to each node that needs it, then
creates the enabled VMs. Check `terraform output talos_vms` afterward for
each VM's node/vmid/planned IP, then generate and apply Talos machine
configs with `talosctl gen config` / `talosctl apply-config` against each
VM's DHCP-assigned maintenance-mode address — that part isn't in this repo
yet.

## Design notes / open questions carried over from talos.md

- **Disk backing for the Longhorn SSD** (`scsi1` on each VM) is a
  Proxmox-managed virtual disk on `var.vm_storage`, not passthrough of the
  physical device. talos.md leaves passthrough-vs-pool as an explicit open
  question (passthrough is simpler for Longhorn but blocks live migration)
  — switch `vms.tf`'s second `disk` block to passthrough before any VM has
  real Longhorn data on it, since migrating afterward is disruptive.
- **CPU type** defaults to `x86-64-v2-AES` rather than `host`, on the
  assumption the six nodes' CPUs aren't guaranteed identical — revisit once
  confirmed, since `host` gives better performance at the cost of
  cross-node live migration.
- **VLANs are untagged on both `network_device`s.** proxmox.md found VLANs
  10/80/100 are native/untagged on their switch ports, not 802.1Q trunks —
  the VM NICs rely on that same behavior via `vmbr0`/`vmbr2` rather than
  setting a `vlan_id`. If the switch side ever moves to tagged trunking,
  this config needs `vlan_id` added to match.
- **qemu-guest-agent** is enabled on the VM side (`agent.enabled = true`)
  but only reports if the Talos image actually includes the extension —
  build a custom schematic at https://factory.talos.dev and set
  `talos_schematic_id` if you want that.
- **vmid** numbering (101–106) mirrors the last octet of each VM's
  management IP from talos.md's topology table, for easy cross-reference —
  not a Proxmox requirement.
