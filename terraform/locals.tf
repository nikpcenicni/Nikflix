locals {
  talos_iso_filename = "talos-${var.talos_version}-metal-amd64.iso"
  talos_iso_url      = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.iso"

  # Cluster topology table from docs/architecture/talos.md. vmid follows the
  # same last-octet convention as the mgmt/storage IPs (.101-.106).
  #
  # mgmt_ip/storage_ip are NOT applied by this config - Talos ignores
  # cloud-init and takes its network config from a talosctl-applied machine
  # config instead, so VMs come up on DHCP in maintenance mode until that's
  # run. They're carried here purely as a reference for generating that
  # machine config afterward (see outputs.tf).
  talos_vms = {
    talos-cp-helium = {
      vmid             = 101
      node             = "helium"
      role             = "controlplane"
      vcpu             = 5
      memory_mib       = 14 * 1024
      boot_disk_gb     = 64
      longhorn_disk_gb = 1024
      mgmt_ip          = "192.168.10.101"
      storage_ip       = "192.168.80.101"
      enabled          = true
    }
    talos-cp-neon = {
      vmid             = 102
      node             = "neon"
      role             = "controlplane"
      vcpu             = 5
      memory_mib       = 14 * 1024
      boot_disk_gb     = 64
      longhorn_disk_gb = 1024
      mgmt_ip          = "192.168.10.102"
      storage_ip       = "192.168.80.102"
      enabled          = true
    }
    talos-cp-argon = {
      vmid             = 103
      node             = "argon"
      role             = "controlplane"
      vcpu             = 5
      memory_mib       = 14 * 1024
      boot_disk_gb     = 64
      longhorn_disk_gb = 1024
      mgmt_ip          = "192.168.10.103"
      storage_ip       = "192.168.80.103"
      enabled          = true
    }
    talos-worker-krypton = {
      vmid             = 104
      node             = "krypton"
      role             = "worker"
      vcpu             = 8
      memory_mib       = 16 * 1024
      boot_disk_gb     = 32
      longhorn_disk_gb = 2048
      mgmt_ip          = "192.168.10.104"
      storage_ip       = "192.168.80.104"
      enabled          = var.enable_worker_vms
    }
    talos-worker-xenon = {
      vmid             = 105
      node             = "xenon"
      role             = "worker"
      vcpu             = 8
      memory_mib       = 16 * 1024
      boot_disk_gb     = 32
      longhorn_disk_gb = 2048
      mgmt_ip          = "192.168.10.105"
      storage_ip       = "192.168.80.105"
      enabled          = var.enable_worker_vms
    }
    talos-worker-radon = {
      vmid             = 106
      node             = "radon"
      role             = "worker"
      vcpu             = 8
      memory_mib       = 16 * 1024
      boot_disk_gb     = 32
      longhorn_disk_gb = 2048
      mgmt_ip          = "192.168.10.106"
      storage_ip       = "192.168.80.106"
      enabled          = var.enable_worker_vms
    }
  }

  talos_vms_enabled = { for k, v in local.talos_vms : k => v if v.enabled }

  # ISO is downloaded once per distinct Proxmox node that has an enabled VM,
  # not once per VM - multiple control-plane/worker VMs never share a node
  # today, but this keeps it correct if that ever changes.
  talos_iso_nodes = toset([for vm in local.talos_vms_enabled : vm.node])
}
