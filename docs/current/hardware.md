# Hardware

<p class="lead">The physical equipment and what each piece does.</p>

## Compute

| Host | Role | CPU / RAM | NICs | Status |
|---|---|---|---|---|
| helium | Proxmox node 1 (cluster founder) | 6 cores / 15.5 GiB | 1GbE + 2.5GbE onboard, 2.5GbE USB | <span class="pill ok">Running</span> |
| neon | Proxmox node 3 | 6 cores / 15.5 GiB | same | <span class="pill ok">Running</span> |
| argon | Proxmox node 2 | 6 cores / 15.5 GiB | same | <span class="pill ok">Running</span> |
| krypton, xenon, radon | Future worker nodes | - | same layout | <span class="pill plan">Planned</span> |
| Mac Mini | Jellyfin media server (hardware transcoding) | - | 1 | <span class="pill ok">Running</span> |

Node IDs follow join order, not the naming order. helium is node 1, argon
node 2, and neon node 3.

### Disks

| Node | Boot / `local-lvm` | Extra SSD for Longhorn |
|---|---|---|
| helium | OK | Works |
| neon | OK | Not detected |
| argon | OK | Write errors (`Program_Fail_Cnt_Total` high) |

Because of these disks, every VM disk lives on `local-lvm`. Longhorn waits
until all nodes have healthy SSDs. See [Future stack](../future/index.md).

## Network equipment

| Device | Role |
|---|---|
| UniFi Cloud Gateway Fiber | Router and WAN. Its LAN ports carry the corosync network (VLAN 100) |
| UniFi Flex 2.5GbE #1 | Management network (VLAN 10) |
| UniFi Flex 2.5GbE #2 | Storage network (VLAN 80) |

Each network has its own switch, so a fault on one network cannot affect
the others. The full cabling is in the
[port map](../reference/networking.md#physical-port-map).

## Storage and services outside the cluster

| Device | Address | Role |
|---|---|---|
| NAS (OpenMediaVault, interim) | `192.168.50.105` | NFS exports for media, torrents, and Usenet downloads |
| Pi-hole | `192.168.1.127` | LAN DNS, with the `*.lab.pcenicni.dev` wildcard |

## VM sizing per node

Each Proxmox node runs two Talos VMs:

| VM | vCPU | RAM | Boot disk | Data disk |
|---|---|---|---|---|
| `talos-dev-cp-<node>` | 3 | 6 GiB | 20 GB | 20 GB |
| `talos-dev-worker-<node>` | 3 | 6 GiB | 20 GB | 20 GB |

This sizing uses 12 GiB of each host's 15.5 GiB.
