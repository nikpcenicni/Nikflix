# Talos VM provisioning - development cluster

Scaled-down variant of [../terraform](../terraform), for standing up a real,
usable interim Talos cluster on the three Proxmox nodes that exist today
(`helium`/`neon`/`argon`), while waiting to buy the `krypton`/`xenon`/`radon`
hardware described in
[docs/architecture/talos.md](../docs/architecture/talos.md).

Same premise as the target-state config, but doubled up: instead of one
control-plane VM per existing node and three (not-yet-real) worker nodes,
each of the three existing nodes gets **two** VMs — one control-plane, one
worker — for 6 VMs total, keeping the same 1:1 control-plane:worker ratio as
the target design. Sizing reuses the exact spec proven out in `../terraform`'s
smoke test (2 vCPU / 2GiB RAM / 20GB boot + 20GB "Longhorn" disk) rather than
the full target sizing (5 vCPU/14GiB/64GB+1TB for control-plane, 8 vCPU/16GiB/
32GB+2TB for workers) — three nodes couldn't fit six VMs at full size.

Like `../terraform`, this only provisions VM shells; Talos machine config is
a separate `talosctl` step afterward.

## Storage: local-lvm only, not a dedicated SSD pool

The target-state design gives every node a dedicated physical SSD for
Longhorn, separate from the boot disk. This dev cluster does **not** do
that — every VM's disks live on `var.vm_storage` (`local-lvm`,
Proxmox-managed, same pool the boot disk uses). That was a deliberate choice
after checking the three nodes' actual 1TB SSD hardware while building this:

- **helium** — had an old standalone Proxmox install on it (`pve-OLD-*` LVM
  VG, matching a prior-migration leftover). Wiped and rebuilt as a clean
  931GB LVM-thin pool (Proxmox storage ID `longhorn`) — this one's real and
  working, just not wired into this dev config.
- **argon** — same old-install pattern, wiped the same way, but the disk
  itself is failing: real write I/O timeouts/errors during rebuild, and
  `smartctl` shows `Program_Fail_Cnt_Total` around 700,000
  (`UDMA_CRC_Error_Count` is 0, so it's not the cable — the drive itself is
  bad). **Needs replacement before use.**
- **neon** — no second disk detected at all (`ata2: SATA link down` in
  `dmesg`). Either not physically installed or a cabling/seating issue —
  needs a look before it has any SSD to use.

Since only one of three nodes has a usable dedicated SSD, every VM here uses
local-lvm for both disks for consistency, rather than splitting helium off
onto its real pool while argon/neon fall back. Revisit `vm_storage` (and
wire the already-built `longhorn` pool back in for helium, at least) once
argon/neon's disks are sorted.

## Prerequisites

- A Proxmox API token — the same `terraform@pve!terraform` token created for
  `../terraform`'s smoke test works here too (same role, scoped to
  VM/datastore management, not root).
- `var.enable_storage_nic` defaults to `false` here (no `vmbr2` bridge exists
  yet, and there's no dedicated storage network to route over it anyway
  without real per-node SSDs). Flip it on once both are true.

## Usage

```sh
cd development
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: proxmox_endpoint, proxmox_api_token

terraform init
terraform plan
terraform apply
```

`terraform output talos_vms` afterward gives each VM's node/vmid/planned IP
for the `talosctl gen config` / `talosctl apply-config` step, same as
`../terraform`.

## Design notes carried over from ../terraform

See [../terraform/README.md](../terraform/README.md#design-notes--open-questions-carried-over-from-talosmd)
for the rest (CPU type, untagged VLANs, qemu-guest-agent, vmid convention) —
all apply here unchanged. The one thing that differs is storage, covered
above.
