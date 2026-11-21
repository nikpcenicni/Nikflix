# Nikflix

[![Docs site](https://github.com/nikpcenicni/Nikflix/actions/workflows/pages.yml/badge.svg)](https://pcenicni.dev/Nikflix/)
[![Security Scan](https://github.com/nikpcenicni/Nikflix/actions/workflows/security-scan.yml/badge.svg)](https://github.com/nikpcenicni/Nikflix/actions/workflows/security-scan.yml)

Nikflix is a home lab defined as code. A three-node Proxmox cluster hosts
Talos Linux VMs that run Kubernetes. ArgoCD deploys every workload from
this repository: the platform (ingress, TLS, SSO, secrets, monitoring),
a self-hosted media stack, and a few household apps.

**Documentation site: <https://pcenicni.dev/Nikflix/>**

The site is the place to start if you want to:

- [build your own copy of the lab](https://pcenicni.dev/Nikflix/tutorials/build/), step by step, or
- [recover the lab after a failure](https://pcenicni.dev/Nikflix/operations/disaster-recovery/).

The site source is in [`docs/`](docs). It publishes from `main` through
[`.github/workflows/pages.yml`](.github/workflows/pages.yml).

## Clusters

| Cluster | State | Runs on |
|---|---|---|
| Development (`dev-noble`) | **Running.** Every procedure in the docs uses it | Six Talos VMs, two on each of `helium`, `neon`, `argon` |
| Production | Design only | Needs three more Proxmox nodes (`krypton`, `xenon`, `radon`) |

## Repository layout

| Path | Content |
|---|---|
| [`ansible/`](ansible) | Playbooks that patch, harden, network, and cluster the Proxmox nodes |
| [`development/terraform/`](development/terraform) | Creates the dev cluster's Talos VMs on Proxmox |
| [`development/talos/`](development/talos) | Per-node Talos patches (base configs and secrets are git-ignored) |
| [`terraform/`](terraform) | Production VM definitions (scaffold, not applied) |
| [`argocd/`](argocd) | App-of-apps tree: `bootstrap/`, `shared/`, `dev/`, `prod/` |
| [`docs/`](docs) | Documentation site: build guide, disaster recovery, networking, architecture |

## Build order

1. **Network** - VLANs 10, 80, and 100, set as native VLANs on node ports.
2. **Proxmox** - `ansible-playbook playbooks/bootstrap.yml` forms the `noble` cluster.
3. **VMs** - `terraform apply` in `development/terraform/`.
4. **Kubernetes** - `talosctl apply-config` with the per-node patches, then bootstrap once.
5. **GitOps** - install the SOPS age key and Cloudflare token, install
   ArgoCD, apply `argocd/bootstrap/root-app-{shared,dev}.yaml`.
6. **Apps** - set up authentik and each app's own settings.

The [build guide](https://pcenicni.dev/Nikflix/tutorials/build/) gives
the full commands and checks for each step.

## What is running

- **Platform:** ArgoCD, Traefik, MetalLB, cert-manager (Let's Encrypt via
  Cloudflare DNS-01), authentik SSO, sops-secrets-operator, Kyverno,
  Harbor, Headlamp, Ballast, WireGuard.
- **Monitoring:** kube-prometheus-stack (Prometheus and Grafana), Loki,
  Alloy, Proxmox exporter.
- **Media:** Seerr, Sonarr, Radarr, Prowlarr, qBittorrent (through a VPN),
  SABnzbd, Bazarr, Profilarr. Jellyfin runs on a Mac Mini outside the
  cluster.
- **Other:** Homepage, Vikunja, OpenGym, Spoolman, Bambuddy.

The [applications reference](https://pcenicni.dev/Nikflix/current/apps/)
lists every Application with its namespace, URL, and login method.

## Networking

### VLANs

| VLAN | Purpose | Subnet |
|---|---|---|
| 10 | Management: Proxmox, Talos VMs, Kubernetes API, MetalLB | `192.168.10.0/24` |
| 80 | Storage | `192.168.80.0/24` |
| 100 | Corosync (Proxmox cluster heartbeat) | `10.10.100.0/24` |

All node-facing ports carry their VLAN **native (untagged)**. Tagged
sub-interfaces do not work with this setup.

### Port mapping

Each Proxmox node has three NICs. Each NIC connects to a different
network on a different switch:

| Node | `nic0` · 1GbE → Cloud Gateway Fiber (VLAN 100) | `nic1` / `vmbr0` · 2.5GbE → Flex 2.5GbE #1 (VLAN 10) | `nic2` · 2.5GbE USB → Flex 2.5GbE #2 (VLAN 80) |
|---|---|---|---|
| helium | `10.10.100.10` | `192.168.10.10` | `192.168.80.10` |
| neon | `10.10.100.20` | `192.168.10.20` | `192.168.80.20` |
| argon | `10.10.100.30` | `192.168.10.30` | `192.168.80.30` |

| Address | Use |
|---|---|
| `192.168.10.121`-`.126` | Talos dev VMs (CP and worker, helium/neon/argon) |
| `192.168.10.160:6443` | Kubernetes API endpoint |
| `192.168.10.240`-`.245` | MetalLB pool. `.240` Traefik, `.244` WireGuard, `.245` Bambuddy |
| `192.168.1.127` | Pi-hole. Wildcard `*.lab.pcenicni.dev` → `192.168.10.240` |
| `192.168.50.105` | Interim NAS (NFS for the media stack) |

The [networking reference](https://pcenicni.dev/Nikflix/reference/networking/)
has the full IP plan, the per-switch port table, and the DNS setup.

## Secrets

Secrets in git are SOPS-encrypted with age (see [`.sops.yaml`](.sops.yaml)).
The age private key, the Talos base configs, `talosconfig`, and Terraform
state are **never** in git. Keep them outside the lab, as listed in
[disaster recovery](https://pcenicni.dev/Nikflix/operations/disaster-recovery/#what-you-must-have-before-a-disaster).

## Local docs preview

```sh
pip install -r docs/requirements.txt
mkdocs serve
```
