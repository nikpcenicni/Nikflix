# 1. Network

This step creates the three networks and sets the switch ports. Ansible
assumes this step is complete. It does not configure switches.

## Procedure

1. In UniFi, create these networks. Use the subnets in
   [Networking](../../reference/networking.md#vlans):

    | Name | VLAN ID | Subnet | DHCP |
    |---|---|---|---|
    | Management | 10 | `192.168.10.0/24` | On, but keep `.10`-`.60`, `.101`-`.126`, `.160`, and `.240`-`.245` outside the range |
    | Storage | 80 | `192.168.80.0/24` | Off for node and VM addresses |
    | Corosync | 100 | `10.10.100.0/24` | Off |

2. Set the native VLAN of each node-facing port, as in the
   [port map](../../reference/networking.md#physical-port-map):

    - Gateway LAN ports for `nic0` → native VLAN **100**.
    - Flex switch #1 ports for `nic1` → native VLAN **10**.
    - Flex switch #2 ports for `nic2` → native VLAN **80**.

3. Cable each node: `nic0` (1GbE) to the gateway, `nic1` (2.5GbE onboard)
   to Flex #1, `nic2` (2.5GbE USB) to Flex #2.

4. Record the port numbers in the
   [per-switch table](../../reference/port-map.md#per-switch-port-tables).

5. In your DNS server, add a wildcard that points the lab domain at
   Traefik's future address. For Pi-hole v6, add this line to
   `misc.dnsmasq_lines`:

    ```text
    address=/.lab.pcenicni.dev/192.168.10.240
    ```

## Check

Install Proxmox on each node with its management IP on `vmbr0`/`nic1`
(step 2 starts from there). Then, from your workstation:

```sh
ping -c1 192.168.10.10 && ping -c1 192.168.10.20 && ping -c1 192.168.10.30
```

!!! note "Change for your lab"
    VLAN IDs and subnets are in `ansible/inventory/group_vars/all.yml`
    (`pve_corosync_vlan`, `pve_storage_vlan`) and
    `ansible/inventory/host_vars/*.yml`.
