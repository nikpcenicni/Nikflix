# Questions

<p class="lead">Common questions about the lab, and the design decisions
that are still open.</p>

## FAQ

??? question "Why Talos instead of Ubuntu or Debian for Kubernetes?"
    Talos is immutable and API-managed. It has no SSH and no package
    manager, and one YAML file defines each machine. This matches the
    rest of the lab, where every layer is declarative.

??? question "Why does Jellyfin run on a Mac Mini and not in the cluster?"
    Hardware transcoding is easy on bare metal. In the cluster it would
    need GPU passthrough into a VM. The Mac Mini mounts the same NAS
    library over SMB.

??? question "Why native (untagged) VLANs instead of tagged trunks?"
    Each NIC carries only one network, so tagging adds nothing. The first
    tries with tagged sub-interfaces (`nic0.100`) came up but passed no
    traffic. See [Proxmox lessons learned](reference/architecture/proxmox.md#notable-design-decisions--lessons-learned).

??? question "Why does each network have its own switch?"
    A fault or a busy link on one network cannot affect corosync or
    storage. Corosync, in particular, needs low and steady latency.

??? question "Why is it called a development cluster if it runs real apps?"
    It stands in for the six-node production design until the new
    hardware exists. See [Future stack](future/index.md).

??? question "Why `dash.lab.pcenicni.dev` and not `lab.pcenicni.dev` for Homepage?"
    A public `*.pcenicni.dev` wildcard (Pangolin) covers the bare
    `lab.pcenicni.dev` name. Any client that asks public DNS would reach
    the wrong place. `dash.` fails cleanly instead.

??? question "Is my app data backed up?"
    Not by the cluster. App data is on `local-path` volumes on each VM.
    Use each app's own backup to the NAS until Longhorn backups exist. See
    [Disaster recovery](operations/disaster-recovery.md).

??? question "Can I build this with different hardware or addresses?"
    Yes. Fork the repository and replace the values listed in each
    **Change for your lab** box in the [build tutorial](tutorials/build/index.md).

??? question "How do I get into an app from outside the house?"
    Connect to the WireGuard VPN (`wg.lab.pcenicni.dev` makes peer
    configs). No web app is exposed to the internet.

??? question "A Renovate update broke an app. What now?"
    Revert the merge commit on `main`. ArgoCD rolls the app back within
    a few minutes. See [Maintenance](operations/maintenance.md#renovate-and-auto-merge).

## Open design decisions

| Decision | Options | Needed before | Status |
|---|---|---|---|
| Longhorn SSD attachment | PCIe passthrough (simple, no live migration) or a Proxmox-managed pool | First production VM | <span class="pill open">Open</span> |
| Longhorn on tainted control-plane nodes | Toleration only for Longhorn's DaemonSets | Workers join | <span class="pill open">Open</span> |
| S3 backup target on the NAS | Garage or SeaweedFS | Longhorn backups | <span class="pill open">Open</span> |
| Production Talos/Kubernetes versions | Pin at build time | Production cluster | <span class="pill open">Open</span> |
| Talos provisioning tooling | Ansible role, or Terraform + `talosctl` | Production cluster | <span class="pill open">Open</span> |
| VM CPU type | `x86-64-v2-AES` (portable) or `host` (faster) | Confirm all CPUs match | <span class="pill open">Open</span> |
| Cluster traffic VLAN | Keep VLAN 10, or a dedicated VLAN | If traffic grows | <span class="pill open">Open</span> |
| Quorum tie-breaker | QDevice (for example a Raspberry Pi) | 6 Proxmox nodes | <span class="pill wip">Agreed, not built</span> |
| Certificate issuer | Let's Encrypt via Cloudflare DNS-01 | - | <span class="pill ok">Decided</span> |
| VPN for torrents | PIA through a gluetun sidecar | - | <span class="pill ok">Decided</span> |
| NAS protocols | NFS for Talos, SMB for the Mac Mini | - | <span class="pill ok">Decided</span> |

Have a question that is not here?
[Open an issue](https://github.com/nikpcenicni/Nikflix/issues/new).
