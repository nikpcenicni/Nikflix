# Development cluster

This directory holds the configuration for the interim development Talos
cluster. The cluster runs on the three Proxmox nodes that exist today:
`helium`, `neon`, and `argon`. See
[docs/architecture/talos.md](../docs/architecture/talos.md) for the
target-state design. This development cluster is a scaled-down stand-in
for that target-state design.

The directory has two subdirectories. You must apply them in order.

| Directory | Content | Applied by |
|-----------|---------|------------|
| [terraform/](terraform) | Provisions six Talos virtual machine (VM) shells on Proxmox: CPU, RAM, disks, and network interface cards (NICs), booted from the Talos ISO image | `terraform apply`, by hand |
| [talos/](talos) | Talos machine configs (control-plane and worker base configs, plus per-node patches) and the cluster secrets that `talosctl` and `kubectl` need to reach the cluster | `talosctl apply-config`, by hand |

Once both steps above are done, everything that runs on the cluster comes
from [../argocd/](../argocd): the ArgoCD app-of-apps tree, Helm values,
and raw Kubernetes manifests. That directory now lives at the repo root
because it is shared with the production cluster (see
[../argocd/README.md](../argocd/README.md)) — this development cluster's
apps live under its `dev/` subdirectory.

## Order of operations

1. Apply `terraform/` first. This step creates the VM shells only; Talos
   itself is not configured yet. See
   [terraform/README.md](terraform/README.md).
2. Apply `talos/` next. Generate and apply each VM's machine config
   against the IP addresses from `terraform output talos_vms`. This step
   produces `talos/kubeconfig`.
   NOTE: `talos/kubeconfig` is gitignored. This file grants full control
   of the cluster. You must never commit it.
3. Install ArgoCD last, against the running cluster. Install ArgoCD by
   hand, then apply the bootstrap manifests in
   [../argocd/bootstrap/](../argocd/bootstrap). After that, ArgoCD takes
   over every other deployment from git. See
   [../argocd/README.md](../argocd/README.md).

Each subdirectory's README file covers its own prerequisites and open
TODO items in more detail than this overview.
