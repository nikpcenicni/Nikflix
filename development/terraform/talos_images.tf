# Downloads the Talos installer ISO directly into each Proxmox node's local
# storage via the API (no shared/NFS ISO storage exists in this cluster yet -
# see docs/architecture/proxmox.md). One download per node, reused by every
# VM resource on that node via its `id`.
resource "proxmox_download_file" "talos_iso" {
  for_each = local.talos_iso_nodes

  content_type = "iso"
  datastore_id = var.iso_storage
  node_name    = each.value
  url          = local.talos_iso_url
  file_name    = local.talos_iso_filename

  overwrite = false
}
