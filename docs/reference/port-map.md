---
title: Port and VLAN map
description: Editable worksheet for the physical cabling, switch ports, and VLANs.
---

# Port and VLAN map

<p class="lead">The working record of what is plugged into which switch port,
and on which VLAN. This file is the source of truth for physical cabling.
Edit it in git (or with the edit button on this page) whenever a cable
moves.</p>

## How to use this page

- **Pre-filled rows** come from the repo: the Ansible inventory and
  [Proxmox architecture](architecture/proxmox.md). They are expected, not
  confirmed.
- **`TBD`** means the repo does not know the value. Read it from the UniFi
  console (*Devices → switch → Ports*) or the cable label. List every gap
  with `grep -n TBD docs/reference/port-map.md`.
- **Verified:** `no` until you check the port in UniFi and the link is up,
  then `yes`. Use `mismatch` if the port is cabled differently from the row.
- **Native VLAN** is the untagged VLAN on the port. Every Proxmox node port
  must be native, not tagged (see [why](../faq.md)).
- Add a line to the [change log](#change-log) each time you move a cable.

## VLAN plan

Three VLANs carry the Proxmox cluster. The others hold devices the cluster
depends on.

| VLAN | Name | Subnet | Gateway | DHCP | On node ports | Carries |
|---|---|---|---|---|---|---|
| 10 | Management | `192.168.10.0/24` | `192.168.10.1` | On; reserve `.10`-`.60`, `.101`-`.126`, `.160`, `.240`-`.245` | Native on `nic1` | Proxmox GUI/API/SSH, Talos VMs, K8s API, MetalLB, corosync fallback |
| 80 | Storage | `192.168.80.0/24` | `.1` (nodes do not use it) | Off for node and VM IPs | Native on `nic2` | Storage traffic; Longhorn later |
| 100 | Corosync | `10.10.100.0/24` | `.1` (nodes do not use it) | Off | Native on `nic0` | Proxmox cluster heartbeat (`link0`) |
| 50 | Legacy NAS | `192.168.50.0/24` | TBD | TBD | - | Interim OMV NAS `192.168.50.105` |
| 1 | Default LAN | `192.168.1.0/24` | TBD | TBD | - | Pi-hole `192.168.1.127`, TBD |
| TBD | TBD | TBD | TBD | TBD | - | Wi-Fi / IoT / guest? |

## Device inventory

Rows marked *June README* came from the old port table. They may be gone
or moved. Confirm or delete them.

| Device | Model | Role | Mgmt IP | Location | Source |
|---|---|---|---|---|---|
| Cloud Gateway Fiber | UniFi Cloud Gateway Fiber | Router, WAN, corosync ports (VLAN 100) | TBD | TBD | proxmox.md |
| Flex 2.5GbE #1 | UniFi Switch Flex 2.5G | Management switch (VLAN 10) | TBD | TBD | proxmox.md |
| Flex 2.5GbE #2 | UniFi Switch Flex 2.5G | Storage switch (VLAN 80) | TBD | TBD | proxmox.md |
| helium | TBD | Proxmox node 1 (founder) | `192.168.10.10` | TBD | Ansible inventory |
| neon | TBD | Proxmox node | `192.168.10.20` | TBD | Ansible inventory |
| argon | TBD | Proxmox node | `192.168.10.30` | TBD | Ansible inventory |
| NAS (OMV, interim) | TBD | NFS for the media stack | `192.168.50.105` | TBD | argocd README |
| Pi-hole (primary) | TBD | LAN DNS and lab wildcard | `192.168.1.127` | TBD | argocd README |
| Mac Mini | Mac Mini | Jellyfin | TBD | TBD | media-stack.md |
| Switch Pro XG 8 PoE | UniFi Switch Pro XG 8 PoE | Core switch? | TBD | TBD | *June README* |
| Flex 2.5GbE PoE | UniFi Switch Flex 2.5G PoE | Pi-holes, Home Assistant | TBD | TBD | *June README* |
| Flex Mini | UniFi Switch Flex Mini | 1GbE edge switch | TBD | TBD | *June README* |
| U7 Lite | UniFi U7 Lite | Wi-Fi access point | TBD | TBD | *June README* |
| Pi-hole 02, 03 | TBD | Secondary DNS | TBD | TBD | *June README* |
| Home Assistant | TBD | Home automation | TBD | TBD | *June README* |

## Proxmox node NIC map

Each node has three NICs, one per network, each on its own switch. The IPs
come from `ansible/inventory/`.

| Node | NIC | Hardware | MAC | Switch | Port | Native VLAN | IP |
|---|---|---|---|---|---|---|---|
| helium | `nic0` | 1GbE onboard (r8169) | TBD | Cloud Gateway Fiber | TBD | 100 | `10.10.100.10` |
| helium | `nic1` / `vmbr0` | 2.5GbE onboard (r8169) | TBD | Flex 2.5GbE #1 | TBD | 10 | `192.168.10.10` |
| helium | `nic2` | 2.5GbE USB (r8152) | `00:e0:4c:68:01:59` | Flex 2.5GbE #2 | TBD | 80 | `192.168.80.10` |
| neon | `nic0` | 1GbE onboard (r8169) | TBD | Cloud Gateway Fiber | TBD | 100 | `10.10.100.20` |
| neon | `nic1` / `vmbr0` | 2.5GbE onboard (r8169) | TBD | Flex 2.5GbE #1 | TBD | 10 | `192.168.10.20` |
| neon | `nic2` | 2.5GbE USB (r8152) | TBD | Flex 2.5GbE #2 | TBD | 80 | `192.168.80.20` |
| argon | `nic0` | 1GbE onboard (r8169) | TBD | Cloud Gateway Fiber | TBD | 100 | `10.10.100.30` |
| argon | `nic1` / `vmbr0` | 2.5GbE onboard (r8169) | TBD | Flex 2.5GbE #1 | TBD | 10 | `192.168.10.30` |
| argon | `nic2` | 2.5GbE USB (r8152) | TBD | Flex 2.5GbE #2 | TBD | 80 | `192.168.80.30` |

Planned nodes use the same layout: `krypton`, `xenon`, and `radon` get
`.40`, `.50`, and `.60` in each subnet. To read a node's MACs, run
`ip -br link` on the node, or
`cat /usr/local/lib/systemd/network/50-pmx-nic*.link`.

## Per-switch port tables

One table per switch, one row per cabled port. Fill in the port numbers,
then set **Verified**. In a rebuild, any free port works if you set its
native VLAN as listed.

### Cloud Gateway Fiber

| Port | Connected device | Device port | Native VLAN | Tagged VLANs | Speed | Verified |
|---|---|---|---|---|---|---|
| WAN | ISP | - | - | - | TBD | no |
| TBD | helium | `nic0` | 100 | none | 1G | no |
| TBD | neon | `nic0` | 100 | none | 1G | no |
| TBD | argon | `nic0` | 100 | none | 1G | no |
| TBD | Flex 2.5GbE #1 (uplink) | TBD | TBD | all | 2.5G | no |
| TBD | Flex 2.5GbE #2 (uplink) | TBD | TBD | all | 2.5G | no |

### Flex 2.5GbE #1 - management (VLAN 10)

| Port | Connected device | Device port | Native VLAN | Tagged VLANs | Speed | Verified |
|---|---|---|---|---|---|---|
| TBD | Cloud Gateway Fiber (uplink) | TBD | TBD | all | 2.5G | no |
| TBD | helium | `nic1` | 10 | none | 2.5G | no |
| TBD | neon | `nic1` | 10 | none | 2.5G | no |
| TBD | argon | `nic1` | 10 | none | 2.5G | no |

### Flex 2.5GbE #2 - storage (VLAN 80)

| Port | Connected device | Device port | Native VLAN | Tagged VLANs | Speed | Verified |
|---|---|---|---|---|---|---|
| TBD | Cloud Gateway Fiber (uplink) | TBD | TBD | all | 2.5G | no |
| TBD | helium | `nic2` | 80 | none | 2.5G | no |
| TBD | neon | `nic2` | 80 | none | 2.5G | no |
| TBD | argon | `nic2` | 80 | none | 2.5G | no |

Copy a table for any other switch still in use (see the legacy map below).

## Legacy map to reconcile

This is the README's port table as of 2026-06-28, before the node cabling
changed. The node rows (`Talos-01` to `Talos-04`) no longer match. The
other devices may still be cabled this way. Set **Still true?** to
`yes`, `changed`, or `gone`, and copy anything still true into the switch
tables above. Delete this section when every row is done.

| Switch | Port | Connected device (June) | Still true? | Now |
|---|---|---|---|---|
| Cloud Gateway Fiber | 1 | NAS 2.5GbE (port 1) | ? | |
| Cloud Gateway Fiber | 2 | NAS 2.5GbE (port 2) | ? | |
| Cloud Gateway Fiber | 4 | U7 Lite | ? | |
| Cloud Gateway Fiber | 5 | WAN | ? | |
| Cloud Gateway Fiber | 6 | Switch Pro XG 8 PoE (port 9) | ? | |
| Cloud Gateway Fiber | 7 | Switch Pro XG 8 PoE (port 10) | ? | |
| Switch Pro XG 8 PoE | 1 | NAS SFP 10GbE RJ45 (port 1) | ? | |
| Switch Pro XG 8 PoE | 2 | NAS SFP 10GbE RJ45 (port 2) | ? | |
| Switch Pro XG 8 PoE | 3 | Mac Mini | ? | |
| Switch Pro XG 8 PoE | 7 | Flex 2.5GbE | ? | |
| Switch Pro XG 8 PoE | 8 | Flex 2.5GbE PoE | ? | |
| Switch Pro XG 8 PoE | 9 | Cloud Gateway Fiber (port 6) | ? | |
| Switch Pro XG 8 PoE | 10 | Cloud Gateway Fiber (port 7) | ? | |
| Flex 2.5GbE PoE | 1 | Pi-hole 01 | ? | |
| Flex 2.5GbE PoE | 2 | Pi-hole 02 | ? | |
| Flex 2.5GbE PoE | 3 | Pi-hole 03 | ? | |
| Flex 2.5GbE PoE | 4 | Home Assistant | ? | |
| Flex 2.5GbE PoE | 8 | Flex Mini | ? | |
| Flex 2.5GbE PoE | 9 | Switch Pro XG 8 PoE (port 8) | ? | |
| Flex 2.5GbE | 1 | Talos-04 2.5GbE expansion | ? | |
| Flex 2.5GbE | 2 | Talos-03 2.5GbE expansion | ? | |
| Flex 2.5GbE | 3 | Talos-02 2.5GbE expansion | ? | |
| Flex 2.5GbE | 4 | Talos-01 2.5GbE USB | ? | |
| Flex 2.5GbE | 5 | Talos-01 2.5GbE USB | ? | |
| Flex 2.5GbE | 6 | Talos-02 2.5GbE USB | ? | |
| Flex 2.5GbE | 7 | Talos-03 2.5GbE USB | ? | |
| Flex 2.5GbE | 8 | Talos-04 2.5GbE USB | ? | |
| Flex 2.5GbE | 9 | Switch Pro XG 8 PoE (port 7) | ? | |
| Flex Mini | 1 | Talos-01 onboard | ? | |
| Flex Mini | 2 | Talos-02 onboard | ? | |
| Flex Mini | 3 | Talos-03 onboard | ? | |
| Flex Mini | 4 | Talos-04 onboard | ? | |
| Flex Mini | 5 | Flex 2.5GbE PoE (port 8) | ? | |

## Open items

- [ ] Record the port number for every node NIC (9 ports across 3 switches).
- [ ] Confirm the two Flex switches uplink to the Cloud Gateway Fiber
      directly. The June map routed them through the Switch Pro XG 8 PoE.
- [ ] Is the Switch Pro XG 8 PoE still in use? If yes, add its port table
      (the NAS 10GbE links and the Mac Mini were on it).
- [ ] Record the Flex 2.5GbE PoE and Flex Mini ports (Pi-holes, Home
      Assistant), or mark them gone.
- [ ] Fill in the VLAN 1 and VLAN 50 gateways and DHCP, and list any other
      VLANs (Wi-Fi, IoT, guest).
- [ ] Record the onboard NIC MACs for helium, neon, and argon.

## Change log

| Date | Change |
|---|---|
| 2026-11-21 | Page created from the repo and the June 2026 README map |
