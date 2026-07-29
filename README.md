# Nikflix

This repository holds the configuration for the Nikflix home lab. The lab
runs Talos Linux and Kubernetes on Proxmox, managed with Terraform,
Ansible, and ArgoCD. A self-hosted media stack runs on top of the
cluster. The network section of this document connects the physical
hardware for the lab.

Two clusters exist in this repository:

- **The development cluster.** This cluster runs today, on the three
  Proxmox nodes that exist today: `helium`, `neon`, and `argon`. Every
  procedure in [Bring up a cluster](#bring-up-a-cluster) below uses this
  cluster as its example.
- **The production cluster.** This cluster is a target-state design, not
  yet provisioned. It needs three more Proxmox nodes (`krypton`, `xenon`,
  `radon`) that do not exist yet. See
  [docs/architecture/talos.md](docs/architecture/talos.md) for the full
  design and [terraform/README.md](terraform/README.md) for its current,
  scaffold-only state.

## Repository layout

| Directory | Content |
| --------- | ------- |
| [ansible/](ansible) | Playbooks and roles that patch, harden, network-configure, and cluster the Proxmox nodes. Start at [ansible/README.md](ansible/README.md). |
| [terraform/](terraform) | Provisions the production cluster's Talos VM shells on Proxmox. Scaffold only today — see [terraform/README.md](terraform/README.md). |
| [development/terraform/](development/terraform) | Provisions the development cluster's Talos VM shells on Proxmox. See [development/terraform/README.md](development/terraform/README.md). |
| [development/talos/](development/talos) | Talos machine configs and cluster secrets for the development cluster. See [development/talos/README.md](development/talos/README.md). |
| [argocd/](argocd) | The ArgoCD app-of-apps tree that runs on every cluster once Kubernetes is up: `shared/` for Applications common to every cluster, `dev/` for Applications specific to the development cluster, `prod/` for Applications specific to the production cluster. Start at [argocd/README.md](argocd/README.md). |
| [docs/architecture/](docs/architecture) | Target-state design documents: [proxmox.md](docs/architecture/proxmox.md) (Proxmox host layout and network), [talos.md](docs/architecture/talos.md) (the Talos and Kubernetes cluster), [media-stack.md](docs/architecture/media-stack.md) (the *arr stack and Jellyfin — design only, not deployed yet). |
| [development/README.md](development/README.md) | An overview of the development cluster's bring-up: Terraform, then Talos. |

## Bring up a cluster

This procedure brings up the development cluster, the cluster that runs
today. Follow the same four stages for the production cluster once
`krypton`, `xenon`, and `radon` exist: use `terraform/` instead of
`development/terraform/`, and `argocd/prod/` instead of `argocd/dev/`.

1. **Prepare the Proxmox nodes, with Ansible.** Run the Ansible playbooks
   in [ansible/](ansible) against `helium`, `neon`, and `argon`. This
   stage patches each node, hardens it, configures the corosync and
   storage networks, and forms the `noble` Proxmox cluster. See
   [ansible/README.md](ansible/README.md) for the full procedure and
   prerequisites.
2. **Provision the Talos VM shells, with Terraform.** Run
   `terraform apply` in [development/terraform/](development/terraform).
   This stage creates the VM shells only: CPU, memory, disks, and network
   interfaces. It does not configure Talos itself. See
   [development/terraform/README.md](development/terraform/README.md)
   for the variables you must set and the full apply procedure.
3. **Configure Talos and bring up Kubernetes, with `talosctl`.** Generate
   a Talos machine config for each VM, apply it with `talosctl`, then
   bootstrap the cluster and retrieve `kubeconfig`. See
   [development/talos/README.md](development/talos/README.md) for the
   full procedure, including the base-config-plus-patch pattern this
   repository uses for each node.
4. **Install ArgoCD and hand off to GitOps.** Install ArgoCD by hand
   against the running cluster. Then apply the `shared` and `dev` root
   Application manifests in [argocd/bootstrap/](argocd/bootstrap). After
   this step, ArgoCD manages every other Application from git
   automatically. See [argocd/README.md](argocd/README.md) for the exact
   commands, and for the table of Applications ArgoCD then installs:
   metrics and dashboards, log storage and shipping, cert-manager
   issuers, MetalLB, and ingress.

NOTE: This procedure brings up the Kubernetes cluster and its core
platform Applications only. The media stack (Jellyfin and the *arr
stack) described in
[docs/architecture/media-stack.md](docs/architecture/media-stack.md) is
a target-state design. No Terraform, Ansible, or ArgoCD configuration for
the media stack exists in this repository yet.

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



