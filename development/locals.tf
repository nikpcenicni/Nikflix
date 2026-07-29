locals {
  talos_iso_filename = "talos-${var.talos_version}-metal-amd64.iso"
  talos_iso_url      = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.iso"

  # Interim/dev topology: same 1-controlplane-to-1-worker ratio as the
  # target state in docs/architecture/talos.md, but doubled up 2-per-node on
  # the three nodes that actually exist today (krypton/xenon/radon are still
  # "planned" per docs/architecture/proxmox.md) instead of one role per node.
  # Sizing reuses the exact spec proven out in ../terraform's smoke test
  # (2 vCPU / 2GiB / 20GB+20GB) rather than the full target sizing - this is
  # meant to be a real, usable interim cluster while waiting on the
  # krypton/xenon/radon hardware, not another one-off smoke test.
  #
  # mgmt_ip/storage_ip are NOT applied by this config - see ../terraform's
  # locals.tf for why (Talos ignores cloud-init; talosctl applies network
  # config afterward). Picked a distinct .121-.126 range purely so these
  # never get confused with the real target VMs' .101-.106 if both are ever
  # up at once.
  talos_vms = {
    talos-dev-cp-helium = {
      vmid             = 201
      node             = "helium"
      role             = "controlplane"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.121"
      storage_ip       = "192.168.80.121"
      enabled          = true
    }
    talos-dev-worker-helium = {
      vmid             = 202
      node             = "helium"
      role             = "worker"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.122"
      storage_ip       = "192.168.80.122"
      enabled          = true
    }
    talos-dev-cp-neon = {
      vmid             = 203
      node             = "neon"
      role             = "controlplane"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.123"
      storage_ip       = "192.168.80.123"
      enabled          = true
    }
    talos-dev-worker-neon = {
      vmid             = 204
      node             = "neon"
      role             = "worker"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.124"
      storage_ip       = "192.168.80.124"
      enabled          = true
    }
    talos-dev-cp-argon = {
      vmid             = 205
      node             = "argon"
      role             = "controlplane"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.125"
      storage_ip       = "192.168.80.125"
      enabled          = true
    }
    talos-dev-worker-argon = {
      vmid             = 206
      node             = "argon"
      role             = "worker"
      vcpu             = 2
      memory_mib       = 2 * 1024
      boot_disk_gb     = 20
      longhorn_disk_gb = 20
      mgmt_ip          = "192.168.10.126"
      storage_ip       = "192.168.80.126"
      enabled          = true
    }
  }

  talos_vms_enabled = { for k, v in local.talos_vms : k => v if v.enabled }

  # ISO is downloaded once per distinct Proxmox node - all three dev nodes
  # host two VMs each, so this de-dupes to exactly 3 downloads, not 6.
  talos_iso_nodes = toset([for vm in local.talos_vms_enabled : vm.node])
}
