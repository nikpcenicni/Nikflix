# Proxmox node management

This project holds Ansible playbooks for the three Proxmox Virtual
Environment (PVE) nodes in the `noble` cluster: `helium`, `neon`, and
`argon`. The playbooks patch, harden, configure the network of, and
cluster these nodes. See
[docs/architecture/proxmox.md](../docs/architecture/proxmox.md) for the
network topology, cluster membership, and the planned six-node layout.

All tasks use `ansible.builtin` modules. This project needs no extra
Ansible collections.

| Host | Management IP | Corosync IP | Storage IP |
|---|---|---|---|
| helium | 192.168.10.10 | 10.10.100.10 | 192.168.80.10 |
| neon | 192.168.10.20 | 10.10.100.20 | 192.168.80.20 |
| argon | 192.168.10.30 | 10.10.100.30 | 192.168.80.30 |

## Inventory structure

| File | Purpose |
|---|---|
| `inventory/hosts.yml` | Defines the `noble` group and its three hosts, each host's management IP (`ansible_host`), and the connection settings shared by all three: `ansible_user` (`root`), `ansible_port` (`22`), `ansible_ssh_private_key_file` (`~/.ssh/id_ed25519_proxmox`), and `ansible_python_interpreter`. |
| `inventory/group_vars/all.yml` | Default variables for every role: `common` (packages, repository management, reboot behavior), `hardening` (SSH, sysctl, fail2ban, auditd settings), `network` (corosync and storage VLAN IDs), and `cluster` (`pve_cluster_name` and link settings). |
| `inventory/host_vars/<host>.yml` | Per-node values: `pve_corosync_ip` and `pve_storage_ip` for every host, plus `pve_nic2_mac_override` on `helium` only (see [Roles](#roles)). |

`ansible.cfg` sets the inventory path to `inventory/hosts.yml`, the remote
user to `root`, and `become` to `False`. Playbooks connect as `root`
directly. They do not use privilege escalation.

## Playbooks

| Playbook | Role(s) used | What it does | When to run it |
|---|---|---|---|
| `ssh_bootstrap.yml` | none (inline tasks) | Generates a local SSH key pair if one does not already exist, and installs the public key into root's `authorized_keys` on each node with the node's current root password. | Run first, against a node that has no dedicated SSH key installed yet. |
| `update.yml` | `common` | Disables the PVE enterprise repositories, adds the no-subscription repository, updates and fully upgrades all packages, installs baseline packages, and configures unattended security upgrades. | Run after key-based SSH access works, before `harden.yml`. |
| `harden.yml` | `hardening` | Applies SSH hardening, sysctl hardening, `fail2ban`, and `auditd`. | Run after `update.yml`. Confirm key-based SSH access on all three nodes first. This playbook disables SSH password authentication. |
| `site.yml` | `common`, `hardening` | Runs `update.yml` and then `harden.yml` against the `noble` hosts, one node at a time. | Run for a combined patch-and-harden pass on nodes that already have key-based SSH access. |
| `network.yml` | `network` | Configures the dedicated corosync network on `nic0` and the storage network on `nic2` on every node, then pings every node from every other node over both networks. | Run after `harden.yml` and before `cluster.yml`. The matching switch ports must already carry the corosync and storage VLANs. |
| `cluster.yml` | `cluster` | Sets up SSH trust between all three nodes, then forms or joins the `noble` PVE cluster, one node at a time. | Run after `network.yml`. The corosync network must already be live and reachable. |
| `uncluster.yml` | `cluster` | Dissolves the `noble` cluster and returns every node to a standalone install. This playbook does not change local VM and container configuration. | Run only when you must remove cluster membership. Requires `-e uncluster_confirm=true`. |
| `bootstrap.yml` | `ssh_bootstrap.yml`, `common`, `hardening`, `network`, `cluster` (chained with `import_playbook`) | Runs `ssh_bootstrap.yml`, `update.yml`, `harden.yml`, `network.yml`, and `cluster.yml` in order. | Run for the full setup of a brand-new node, from first SSH access through cluster membership. |

NOTE: `bootstrap.yml` tags each stage with its playbook name
(`ssh_bootstrap`, `update`, `harden`, `network`, `cluster`). Use
`--tags <name>` to run one stage, or `--skip-tags ssh_bootstrap` to skip
the password prompt on a node that already has key-based SSH access.

## Roles

- **`common`** (used by `update.yml`) — configures repositories,
  packages, the timezone, time sync, and unattended upgrades.
- **`hardening`** (used by `harden.yml`) — configures SSH, sysctl,
  `fail2ban`, and `auditd`.
- **`network`** (used by `network.yml`) — configures the corosync and
  storage networks on `nic0` and `nic2`. On `helium`, this role also
  gives the second network interface controller (NIC) a persistent name,
  `nic2`, based on the Media Access Control (MAC) address in
  `pve_nic2_mac_override`. The PVE installer did not set this name for
  `helium`'s second gigabit Ethernet (GbE) NIC, unlike `neon` and
  `argon`.
- **`cluster`** (used by `cluster.yml` and `uncluster.yml`) — sets up SSH
  trust between nodes, forms or joins the cluster, and dissolves the
  cluster.

## Prerequisites

1. Install `sshpass` locally. `ssh_bootstrap.yml` uses `sshpass` to
   script password-based SSH the first time it installs your key
   (`brew install hudochenkov/sshpass/sshpass` on macOS, `apt install
   sshpass` on Debian/Ubuntu).
2. Before you run `network.yml`, configure the switch ports for `nic0`
   and `nic2` on all three nodes for the corosync and storage VLANs.
   Ansible configures only the Proxmox side of this network.

## Usage

1. Change to the `ansible` directory.
2. For a brand-new node with no SSH key installed, run:
   `ansible-playbook playbooks/bootstrap.yml`. This prompts once for the
   node's current root password.
3. For a node that already has key-based SSH access, run:
   `ansible-playbook playbooks/bootstrap.yml --skip-tags ssh_bootstrap`.
4. To run one stage only, add `--tags <stage>`, for example
   `ansible-playbook playbooks/bootstrap.yml --tags network`.
5. Add `--check --diff` to any command for a dry run before you apply a
   change.

CAUTION: `harden.yml` disables SSH password authentication
(`PasswordAuthentication no`, `PermitRootLogin prohibit-password`).
Confirm key-based SSH access works on all three nodes before you run it,
or you lock yourself out.

NOTE: Every playbook that touches the `noble` hosts runs with `serial: 1`
(one node at a time), so a failure on one node stops before it reaches the
rest.

All tunables live in `inventory/group_vars/all.yml`. Per-node corosync and
storage IP addresses live in `inventory/host_vars/`.
