output "talos_vms" {
  description = "Per-VM reference info for generating talosctl machine configs afterward (node/vmid/planned IPs - not applied by this config, see vms.tf)."
  value = {
    for name, vm in local.talos_vms_enabled : name => {
      vmid       = vm.vmid
      node       = vm.node
      role       = vm.role
      mgmt_ip    = vm.mgmt_ip
      storage_ip = vm.storage_ip
    }
  }
}
