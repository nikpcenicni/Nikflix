# Creates the VM shell only: CPU/RAM/disks/NICs, booted off the Talos ISO in
# maintenance mode. Talos itself - network config, disk encryption, the
# actual cluster bootstrap - is applied afterward with `talosctl`, per
# docs/architecture/talos.md ("API-managed and immutable... config applied as
# a single declarative machine config"). That step is intentionally not done
# here.
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_vms_enabled

  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vmid
  tags      = ["talos", each.value.role]

  # Talos requires UEFI boot; q35 is the recommended machine type for it.
  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"

  started = true
  on_boot = true

  cpu {
    cores = each.value.vcpu
    type  = var.cpu_type
  }

  memory {
    dedicated = each.value.memory_mib
  }

  efi_disk {
    datastore_id = var.vm_storage
    file_format  = "raw"
    type         = "4m"
  }

  # Boot/Talos-install disk.
  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = each.value.boot_disk_gb
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  # Dedicated Longhorn disk - see docs/architecture/talos.md's Storage
  # section. This is a Proxmox-managed virtual disk on `var.vm_storage`, not
  # raw PCIe/device passthrough of the physical SSD - that tradeoff (simpler
  # passthrough vs. live-migration-compatible pool) is still an open question
  # in that doc. Switch to passthrough by replacing this block with a
  # `disk` block using `path_in_datastore` pointed at the raw device, or a
  # `hostpci`/virtio-blk passthrough of the physical disk's by-id path.
  disk {
    datastore_id = var.vm_storage
    interface    = "scsi1"
    size         = each.value.longhorn_disk_gb
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso[each.value.node].id
    interface = "ide2"
  }

  # scsi0 first so a freshly-installed disk boots straight into Talos on
  # every subsequent boot; QEMU falls through to the CD only while scsi0 is
  # still empty (first boot, before `talosctl apply-config` installs Talos
  # to it).
  boot_order = ["scsi0", "ide2"]

  # VLAN 10 (management) - vmbr0, native/untagged, matching
  # docs/architecture/proxmox.md's per-node network layout.
  network_device {
    bridge = var.proxmox_bridge_mgmt
    model  = "virtio"
  }

  # VLAN 80 (Longhorn storage) - vmbr2, native/untagged. Requires the vmbr2
  # bridge to already exist on this node - see the README prerequisites.
  # Gated by var.enable_storage_nic so a node without vmbr2 yet (e.g. during
  # a smoke test before the bridge rollout) doesn't fail VM creation.
  dynamic "network_device" {
    for_each = var.enable_storage_nic ? [1] : []
    content {
      bridge = var.proxmox_bridge_storage
      model  = "virtio"
    }
  }

  # Only reports once the qemu-guest-agent extension is baked into the
  # image via var.talos_schematic_id - harmless no-op otherwise.
  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      # Talos ejects/detaches install media itself post-install; don't fight it.
      cdrom,
    ]
  }
}
