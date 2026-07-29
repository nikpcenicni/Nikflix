# Nikflix

This repository holds the configuration for the Nikflix home lab. The lab
runs a Talos Linux Kubernetes cluster on Proxmox and a self-hosted media
stack on top of it. The network in this document connects the physical
hardware for the lab.

## Repository layout

| Directory | Content |
| --------- | ------- |
| [terraform/](terraform) | The Terraform configuration for the original, single-stage cluster. See the `NOTE:` in [terraform/README.md](terraform/README.md) for its status relative to `development/terraform/`. |
| [ansible/](ansible) | The Ansible playbooks and roles that provision and harden the Proxmox nodes. |
| [development/](development) | The interim development Talos cluster: Terraform for the VM shells and Talos machine configs. Start at [development/README.md](development/README.md). |
| [argocd/](argocd) | The ArgoCD app-of-apps tree that runs on every cluster once it's up, shared between the development and production clusters via a `shared/` subdirectory plus one subdirectory per cluster (`dev/`, `prod/`). Start at [argocd/README.md](argocd/README.md). |
| [docs/architecture/](docs/architecture) | Design documents for the target-state architecture: Proxmox host layout, the Talos cluster, and the media stack. |

## Networking

### Port mapping

The table below shows each physical port, the device connected to it, and
the Virtual Local Area Network (VLAN) assigned to the port. An empty cell
means the port has no connected device or no assigned VLAN.

| Hardware | Port # | Destination device | VLAN |
| -------- | ------ | ------------------ | ------- |
| UniFi Fiber Gateway | 1 | NAS 2.5 GbE (Port 1) | |
| UniFi Fiber Gateway | 2 | NAS 2.5 GbE (Port 2) | |
| UniFi Fiber Gateway | 3 | | |
| UniFi Fiber Gateway | 4 | U7 Lite | |
| UniFi Fiber Gateway | 5 | WAN | |
| UniFi Fiber Gateway | 6 | UniFi Switch Pro XG 8 PoE (Port 9) | |
| UniFi Fiber Gateway | 7 | UniFi Switch Pro XG 8 PoE (Port 10) | |
| UniFi Switch Pro XG 8 PoE | 1 | NAS SFP 10 GbE RJ45 (Port 1) | |
| UniFi Switch Pro XG 8 PoE | 2 | NAS SFP 10 GbE RJ45 (Port 2) | |
| UniFi Switch Pro XG 8 PoE | 3 | Mac Mini | |
| UniFi Switch Pro XG 8 PoE | 4 | | |
| UniFi Switch Pro XG 8 PoE | 5 | | |
| UniFi Switch Pro XG 8 PoE | 6 | | |
| UniFi Switch Pro XG 8 PoE | 7 | UniFi Switch Flex 2.5 GbE | |
| UniFi Switch Pro XG 8 PoE | 8 | UniFi Switch Flex 2.5 GbE PoE | |
| UniFi Switch Pro XG 8 PoE | 9 | UniFi Fiber Gateway (Port 6) | |
| UniFi Switch Pro XG 8 PoE | 10 | UniFi Fiber Gateway (Port 7) | |
| UniFi Switch Flex 2.5 GbE PoE | 1 | pi-Hole 01 | |
| UniFi Switch Flex 2.5 GbE PoE | 2 | pi-Hole 02 | |
| UniFi Switch Flex 2.5 GbE PoE | 3 | pi-Hole 03 | |
| UniFi Switch Flex 2.5 GbE PoE | 4 | Home assistant | |
| UniFi Switch Flex 2.5 GbE PoE | 5 | | |
| UniFi Switch Flex 2.5 GbE PoE | 6 | | |
| UniFi Switch Flex 2.5 GbE PoE | 7 | | |
| UniFi Switch Flex 2.5 GbE PoE | 8 | UniFi Flex Mini | |
| UniFi Switch Flex 2.5 GbE PoE | 9 | UniFi Switch Pro XG 8 PoE (Port 8) | |
| UniFi Switch Flex 2.5 GbE | 1 | Talos-04 2.5 GbE Expansion | |
| UniFi Switch Flex 2.5 GbE | 2 | Talos-03 2.5 GbE Expansion | |
| UniFi Switch Flex 2.5 GbE | 3 | Talos-02 2.5 GbE Expansion | |
| UniFi Switch Flex 2.5 GbE | 4 | Talos-01 2.5 GbE USB | |
| UniFi Switch Flex 2.5 GbE | 5 | Talos-01 2.5 GbE USB | |
| UniFi Switch Flex 2.5 GbE | 6 | Talos-02 2.5 GbE USB | |
| UniFi Switch Flex 2.5 GbE | 7 | Talos-03 2.5 GbE USB | |
| UniFi Switch Flex 2.5 GbE | 8 | Talos-04 2.5 GbE USB | |
| UniFi Switch Flex 2.5 GbE | 9 | UniFi Switch Pro XG 8 PoE (Port 7) | |
| UniFi Switch Flex Mini | 1 | Talos-01 On-Board | |
| UniFi Switch Flex Mini | 2 | Talos-02 On-Board | |
| UniFi Switch Flex Mini | 3 | Talos-03 On-Board | |
| UniFi Switch Flex Mini | 4 | Talos-04 On-Board | |
| UniFi Switch Flex Mini | 5 | UniFi Flex 2.5 GbE PoE (Port 8) | |



