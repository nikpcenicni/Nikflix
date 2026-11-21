# 0. Prerequisites

## Hardware

| Item | Quantity | Notes |
|---|---|---|
| Proxmox host (mini PC) | 3 | 6 cores and 15.5 GiB RAM each is enough for the dev cluster. Each needs **three NICs**: one 1GbE and two 2.5GbE (onboard or USB) |
| Router / gateway with VLAN support | 1 | The lab uses a UniFi Cloud Gateway Fiber. Its LAN ports carry the corosync network |
| Managed 2.5GbE switch | 2 | One for management (VLAN 10), one for storage (VLAN 80). The lab uses UniFi Flex 2.5GbE switches |
| NAS with NFS | 1 | Holds the media library and download staging |
| DNS server you control | 1 | The lab uses Pi-hole. Needs wildcard (dnsmasq `address=`) support |
| Mac Mini or other host | optional | Runs Jellyfin outside the cluster |

## Accounts and external services

- [ ] A **GitHub** fork of this repository. ArgoCD pulls from it.
- [ ] A domain in **Cloudflare** and an API token with `Zone:DNS:Edit` on
      that zone. cert-manager uses it for Let's Encrypt DNS-01.
- [ ] A **PIA VPN** account, for the qBittorrent sidecar (optional).
- [ ] A **Usenet provider** and indexers (optional).

## Workstation tools

Install these on the machine you run the build from:

| Tool | Used in step |
|---|---|
| `ansible` (core 2.15+) | 2 |
| `terraform` | 3 |
| `talosctl` (same minor version as `talos_version`, today `v1.13.x`) | 4 |
| `kubectl` | 4, 5, 6 |
| `sops` and `age` | 5 |
| `git` | all |

```sh
# macOS example
brew install ansible terraform siderolabs/tap/talosctl kubectl sops age
```

## Secrets you will create (keep them safe)

You create these during the build. **Git never stores them.** Save every
one in a password manager as you create it. You need all of them for
[disaster recovery](../../operations/disaster-recovery.md).

| Secret | Created in step |
|---|---|
| Proxmox root passwords | 2 |
| SSH key `~/.ssh/id_ed25519_proxmox` | 2 |
| Proxmox API token for Terraform | 3 |
| `development/talos/controlplane.yaml`, `worker.yaml`, `talosconfig` | 4 |
| `age-key.txt` (SOPS private key) | 5 |
| Cloudflare API token | 5 |
| authentik `akadmin` password | 6 |
