# 2. Proxmox nodes

This step installs Proxmox VE, then uses Ansible to patch, harden, set up
the corosync and storage networks, and form the `noble` cluster. The full
reference is
[`ansible/README.md`](https://github.com/nikpcenicni/Nikflix/blob/main/ansible/README.md).

## Install Proxmox VE

On each node, install Proxmox VE from the ISO:

| Node | Hostname | Management interface | IP | Gateway |
|---|---|---|---|---|
| helium | `helium` | `nic1` (installer creates `vmbr0`) | `192.168.10.10/24` | `192.168.10.1` |
| neon | `neon` | `nic1` | `192.168.10.20/24` | `192.168.10.1` |
| argon | `argon` | `nic1` | `192.168.10.30/24` | `192.168.10.1` |

After install, check that `/usr/local/lib/systemd/network/` has
`50-pmx-nic0.link`, `50-pmx-nic1.link`, and `50-pmx-nic2.link`. If
`nic2` is missing (the USB NIC was not detected at install time, as on
helium), set `pve_nic2_mac_override` in that host's
`ansible/inventory/host_vars/<host>.yml`.

## Run Ansible

```sh
brew install hudochenkov/sshpass/sshpass   # used once by ssh_bootstrap.yml
cd ansible
ansible-playbook playbooks/bootstrap.yml   # prompts once for the root password
```

To re-run later without the password prompt, add
`--skip-tags ssh_bootstrap`.

`bootstrap.yml` runs these stages in order. Each stage has a tag, so you
can re-run one stage with `--tags <tag>`:

| Stage | Tag | Result |
|---|---|---|
| `ssh_bootstrap.yml` | `ssh_bootstrap` | Installs `~/.ssh/id_ed25519_proxmox` on each node (uses the root password once) |
| `update.yml` | `update` | No-subscription repos, full upgrade, unattended upgrades |
| `harden.yml` | `harden` | SSH key-only login, sysctl, fail2ban, auditd |
| `network.yml` | `network` | `nic0` → corosync IP, `nic2` → storage IP, full-mesh ping test |
| `cluster.yml` | `cluster` | `pvecm create` on helium, `pvecm add` on the others, dual-link corosync |

!!! warning
    `harden.yml` disables SSH password login. Confirm key login works
    on every node before it runs.

## Check

```sh
ssh -i ~/.ssh/id_ed25519_proxmox root@192.168.10.10 pvecm status
```

The output must show `Quorate: Yes` and 3 nodes.

!!! note "Change for your lab"
    Edit `ansible/inventory/hosts.yml` (node names and management IPs),
    `ansible/inventory/host_vars/*.yml` (corosync and storage IPs), and
    `fail2ban_ignoreip` in `group_vars/all.yml`.
