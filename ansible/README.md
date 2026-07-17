# Proxmox update & hardening

Ansible playbooks to patch and harden the `noble` cluster:

| Host   | IP             |
|--------|----------------|
| helium | 192.168.10.10  |
| neon   | 192.168.10.20  |
| argon  | 192.168.10.30  |

No extra collections required - everything uses `ansible.builtin`.

## Quick start

For brand new nodes with nothing set up yet, `bootstrap.yml` runs
everything in order - SSH key install, patching, hardening, network config,
cluster formation:

```sh
cd ansible
ansible-playbook playbooks/bootstrap.yml
```

It prompts once for the root password currently set on the nodes (used
only to install your SSH key) and requires `sshpass` locally for that step
(`brew install hudochenkov/sshpass/sshpass` on macOS, `apt install sshpass`
on Debian/Ubuntu). Everything after that uses key auth. See
[What each role does](#what-each-role-does) below for what each stage
actually does and its specific caveats (switch VLAN config needed before
`network`, password-auth lockout risk in `harden`, etc) - read those before
your first real run.

Re-running later, once key auth already works:

```sh
ansible-playbook playbooks/bootstrap.yml --skip-tags ssh_bootstrap
```

Run just one stage:

```sh
ansible-playbook playbooks/bootstrap.yml --tags network
```

Each stage is also its own standalone playbook (`ssh_bootstrap.yml`,
`update.yml`, `harden.yml`, `network.yml`, `cluster.yml`) if you'd rather
run/inspect them individually - `bootstrap.yml` just chains them in the
right order with `import_playbook`. The rest of this README walks through
that manual, step-by-step path.

## 1. Bootstrap SSH access

These nodes have no dedicated key yet. Generate one and install it before
running anything - or skip this whole section and use
`playbooks/ssh_bootstrap.yml` (also included in `bootstrap.yml` above),
which does the same thing without leaving your shell:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_proxmox -C "ansible-proxmox"
```

Trust the hosts' SSH keys (first connection):

```sh
ssh-keyscan -H 192.168.10.10 192.168.10.20 192.168.10.30 >> ~/.ssh/known_hosts
```

Copy the public key to each node (uses the root password you set at install
time):

```sh
ssh-copy-id -i ~/.ssh/id_ed25519_proxmox.pub root@192.168.10.10
ssh-copy-id -i ~/.ssh/id_ed25519_proxmox.pub root@192.168.10.20
ssh-copy-id -i ~/.ssh/id_ed25519_proxmox.pub root@192.168.10.30
```

If `ssh-copy-id` isn't available or password auth is already off, paste the
contents of `~/.ssh/id_ed25519_proxmox.pub` into `/root/.ssh/authorized_keys`
via the Proxmox web UI's `> Shell` console for each node instead.

Verify key-based login works for all three before continuing:

```sh
for h in 192.168.10.10 192.168.10.20 192.168.10.30; do
  ssh -i ~/.ssh/id_ed25519_proxmox root@$h hostname
done
```

`inventory/hosts.yml` already points at `~/.ssh/id_ed25519_proxmox` - update
that path if you used a different filename.

## 2. Sanity check

```sh
cd ansible
ansible all -m ping
```

## 3. Run

```sh
# Patch + fix apt repos only
ansible-playbook playbooks/update.yml

# Harden only (SSH, sysctl, fail2ban, auditd) - run update.yml first
ansible-playbook playbooks/harden.yml

# Both, one node at a time
ansible-playbook playbooks/site.yml

# Configure the dedicated corosync network (run before cluster.yml)
ansible-playbook playbooks/network.yml

# Form/join the Proxmox cluster (run after update.yml + harden.yml + network.yml)
ansible-playbook playbooks/cluster.yml

# Dissolve the cluster back to 3 standalone nodes (destructive, requires confirmation)
ansible-playbook playbooks/uncluster.yml -e uncluster_confirm=true
```

Dry run first if you want to see what would change: add `--check --diff`.

**Important:** `harden.yml` disables SSH password authentication
(`PasswordAuthentication no`, `PermitRootLogin prohibit-password`). Do not
run it until you've confirmed key-based SSH works on all three nodes (step
1), or you will lock yourself out.

Playbooks run with `serial: 1` (one node at a time) since this is a cluster -
if something goes wrong on a node, you find out before it touches the rest.

## What each role does

**`ssh_bootstrap`** (`playbooks/ssh_bootstrap.yml`)
- Generates `~/.ssh/id_ed25519_proxmox` locally if it doesn't already exist,
  trusts each node's SSH host key locally (`ssh-keyscan`), then installs
  the public key into root's `authorized_keys` on each node - using the
  node's current root password, prompted once (`vars_prompt`, not stored
  anywhere).
- Idempotent and safe to re-run: leave the password prompt blank once key
  auth already works, and it just re-confirms the `authorized_keys` entry
  over the existing key - no password/`sshpass` needed at that point.
- Requires `sshpass` installed locally for the password-auth step (Ansible
  scripts password-based SSH through it).

**`common`** (`playbooks/update.yml`)
- Disables the Proxmox/Ceph enterprise repos (both classic `.list` and the
  deb822 `.sources` format used by PVE 8.1+/9) and adds
  `pve-no-subscription` (set `manage_pve_repos: false` in
  `group_vars/all.yml` if you have a subscription).
- `apt update && apt full-upgrade`, autoremove/autoclean.
- Installs `chrony` (important for cluster/corosync time sync) and a small
  set of baseline packages.
- Configures `unattended-upgrades` for **Debian security updates only**,
  with automatic reboot disabled - kernel/PVE package upgrades stay a
  deliberate action via this playbook, not something that happens at 3am on
  a node running VMs.
- Reports (but does not act on) `/var/run/reboot-required`. Reboot nodes
  manually, one at a time, after checking cluster quorum / migrating guests
  off. To let Ansible reboot automatically instead, pass
  `-e reboot_if_required=true`.

**`hardening`** (`playbooks/harden.yml`)
- SSH: drop-in config at `/etc/ssh/sshd_config.d/99-hardening.conf`
  (key-only root login, no password auth, tighter timeouts). Deliberately
  leaves `AllowTcpForwarding`/`GatewayPorts` untouched - Proxmox tunnels VM
  live-migration over SSH by default.
- sysctl: `/etc/sysctl.d/99-hardening.conf` - standard network/kernel
  hardening. Deliberately does **not** touch `net.ipv4.ip_forward` or
  `net.bridge.bridge-nf-call-*`, which Proxmox networking depends on.
  Uses loose (not strict) `rp_filter` to avoid breaking multi-NIC/asymmetric
  routing setups.
- `fail2ban`: bans repeated SSH auth failures. `fail2ban_ignoreip` includes
  your `192.168.10.0/24` management subnet by default - adjust in
  `group_vars/all.yml` if you manage these nodes from elsewhere too.
- `auditd`: watches `/etc/passwd`, `/etc/shadow`, sudoers, SSH config, and
  cron for changes.

**`network`** (`playbooks/network.yml`)
- Configures a dedicated corosync-only network on `nic0` (the 1GbE NIC) on
  every node, using a per-node IP from `inventory/host_vars/<host>.yml`
  (`pve_corosync_ip`) and the subnet in `group_vars/all.yml`
  (`pve_corosync_subnet_prefix`).
- The switch port for `nic0` on all three nodes carries VLAN
  `pve_corosync_vlan` (default `100`) as the **native/untagged** VLAN, so
  the config puts the IP directly on `nic0` - no 802.1Q tagging on the
  Proxmox side. (This was diagnosed with tcpdump - a first attempt using a
  tagged `nic0.100` sub-interface silently failed because the switch was
  sending/expecting untagged frames for this VLAN.) If you ever reconfigure
  the switch side to trunk+tag VLAN 100 instead, this template needs to
  change to match.
- Applies via `ifreload -a` (Proxmox/ifupdown2's live-reload), one node at a
  time (`serial: 1`), then a second play pings every node from every other
  node over this network to confirm end-to-end connectivity before you run
  `cluster.yml`.
- **Heads up:** this VLAN/subnet is shared with existing UniFi network
  infrastructure (a live gateway at the `.1` address was observed doing
  IGMP/mDNS reflection on it) - it is not a freshly isolated segment.
  Double-check `pve_corosync_ip` values in `inventory/host_vars/` are
  outside your UniFi DHCP range and reserved so nothing else can claim them.
- Also configures a storage network on `nic2` (the second, USB-attached
  2.5GbE NIC - Realtek `0bda:8156`, distinct from `nic1` which carries
  management), using `pve_storage_ip` (host_vars) and `pve_storage_vlan`/
  `pve_storage_subnet_prefix` (default VLAN `80`, `/24`, `group_vars/all.yml`).
  Same deal as corosync: native/untagged VLAN (confirmed via tcpdump), and
  the same UniFi-collision caveat applies (a live gateway answers on this
  VLAN too) - reserve `pve_storage_ip` values in your DHCP server.
- `helium`'s installer never created a `nic2` naming rule for its second
  2.5GbE NIC (neon/argon's did) - fixed via `pve_nic2_mac_override` in
  `inventory/host_vars/helium.yml`, which deploys a matching
  `/usr/local/lib/systemd/network/50-pmx-nic2.link` (same convention the
  Proxmox installer itself uses) and renames the live interface immediately.

**`cluster`** (`playbooks/cluster.yml`)
- Forms a Proxmox cluster (`pve_cluster_name`, default `noble`) out of
  the `noble` hosts, using the **first host listed in
  `inventory/hosts.yml`** (currently `helium`) as the founding node. Nodes
  join in inventory order, one at a time (`serial: 1`).
- Idempotent: a node already in that cluster is left alone. A node found in
  some *other* cluster fails the play instead of touching it - resolve that
  manually.
- `pvecm add` needs either a root password or pre-existing root-to-root SSH
  trust between the nodes to run non-interactively; the first play in this
  playbook generates an SSH keypair for root on each node (if it doesn't
  already have one) and exchanges keys/host-key trust between all three, so
  the join can use `pvecm add --use_ssh` without prompting.
- Run this **after** `update.yml`/`harden.yml`/`network.yml`, not before -
  corosync needs `pve_corosync_ip` to already be live and reachable, and
  joining before hardening is more likely to hit ordering surprises (e.g.
  password auth getting disabled mid-bootstrap on a node that hasn't
  finished exchanging keys yet).
- Uses two corosync links: `link0` on the dedicated corosync network
  (`pve_corosync_ip`), `link1` on the management network (`ansible_host`)
  as a fallback if `link0`/its switch has a problem.
- `pvecm add`/`pvecm create` have been observed to exit `0` while silently
  failing a step (no `corosync.conf` ever created) - both commands are
  chained with a check that the file actually exists afterward and retried
  (3x, 10s apart) if not, rather than trusting the exit code alone.

**`uncluster`** (`playbooks/uncluster.yml`)
- The reverse of `cluster.yml`: dissolves the cluster entirely, returning
  every node to a standalone install. Follows Proxmox's documented
  node-separation procedure (stop `pve-cluster`/`corosync`, restart pmxcfs
  in local mode to remove `corosync.conf`, restart normally). Each node's
  own local VM/CT configs are untouched - only cluster membership goes.
- **Refuses to run without explicit confirmation:**
  `ansible-playbook playbooks/uncluster.yml -e uncluster_confirm=true`
- One node at a time, `any_errors_fatal: true` - a failure halts before
  touching the rest rather than leaving a half-dissolved cluster.
- Also cleans up stale peer node directories under `/etc/pve/nodes/` that
  pmxcfs leaves behind after leaving a cluster.

All tunables live in `group_vars/all.yml`; per-node corosync IPs live in
`inventory/host_vars/`.
