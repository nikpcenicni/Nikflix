# Add a Proxmox node

<p class="lead">Add a new node (for example <code>krypton</code>) to the
<code>noble</code> cluster. The node names come from the noble gases, in
periodic-table order.</p>

## 1. Reserve addresses

Follow the `.10 / .20 / .30` pattern. In UniFi, reserve outside DHCP:

| Node | Management | Corosync | Storage |
|---|---|---|---|
| krypton | `192.168.10.40` | `10.10.100.40` | `192.168.80.40` |
| xenon | `192.168.10.50` | `10.10.100.50` | `192.168.80.50` |
| radon | `192.168.10.60` | `10.10.100.60` | `192.168.80.60` |

## 2. Cable it

| NIC | Goes to | Native VLAN |
|---|---|---|
| `nic0` 1GbE | Cloud Gateway Fiber LAN port | 100 |
| `nic1` 2.5GbE | Flex 2.5GbE #1 | 10 |
| `nic2` 2.5GbE | Flex 2.5GbE #2 | 80 |

Record the port numbers in the
[port table](../reference/port-map.md#per-switch-port-tables).

## 3. Install Proxmox

Install Proxmox VE with hostname `krypton` and the management IP on
`nic1`. Then check the NIC names:

```sh
ls /usr/local/lib/systemd/network/   # expect 50-pmx-nic0/1/2.link
```

If `50-pmx-nic2.link` is missing, note the USB NIC's MAC address for the
next step.

## 4. Add it to the inventory

```yaml title="ansible/inventory/hosts.yml"
        krypton:
          ansible_host: 192.168.10.40
```

```yaml title="ansible/inventory/host_vars/krypton.yml"
---
pve_corosync_ip: 10.10.100.40
pve_storage_ip: 192.168.80.40
# only if 50-pmx-nic2.link was missing:
# pve_nic2_mac_override: "xx:xx:xx:xx:xx:xx"
```

## 5. Bootstrap and join

```sh
cd ansible
ansible-playbook playbooks/bootstrap.yml -l krypton --skip-tags cluster
ansible-playbook playbooks/cluster.yml        # whole group; skips existing members
```

## Check

```sh
ssh root@192.168.10.10 pvecm status
```

`Quorate: Yes`, with one more node and one more vote than before.

!!! warning "Even node counts"
    At 4 or 6 nodes, a half-and-half split loses quorum on both sides.
    Add a QDevice when you reach an even count. The playbooks do not set
    one up yet.

The Proxmox exporter reads the whole cluster through one API endpoint, so
the new node shows up in Grafana with no change.
