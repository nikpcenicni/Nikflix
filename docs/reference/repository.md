# Repository layout

```text
Nikflix/
├── ansible/                  Proxmox nodes: inventory, playbooks, roles
│   ├── inventory/            hosts.yml, group_vars/, host_vars/
│   ├── playbooks/            bootstrap, update, harden, network, cluster, uncluster
│   └── roles/                common, hardening, network, cluster
├── development/
│   ├── terraform/            dev cluster VMs (applied)
│   └── talos/patches/        per-VM Talos patches
├── terraform/                production VMs (scaffold, not applied)
├── argocd/
│   ├── bootstrap/            root Applications, applied once by hand
│   ├── shared/               Applications for every cluster (empty)
│   ├── dev/                  apps/ · values/ · manifests/ for dev-noble
│   └── prod/                 production (empty)
├── docs/                     this site (MkDocs Material)
├── .github/workflows/        security scan, auto-merge, docs site
├── .sops.yaml                SOPS encryption rules
└── renovate.json             dependency update config
```

## Where to change things

| To change | Edit |
|---|---|
| Node IPs, VLANs | `ansible/inventory/` |
| VM size, count, IDs | `development/terraform/locals.tf` |
| Talos version, hostnames, API OIDC | `development/talos/patches/*.yaml` |
| An app's settings | `argocd/dev/values/<app>-values.yaml` |
| Add or remove an app | `argocd/dev/apps/<app>.yaml` |
| A secret | `sops argocd/dev/manifests/secrets/<file>.yaml` |
| MetalLB range | `argocd/dev/manifests/metallb-pool/` |
| Docs site | `docs/`, `mkdocs.yml` |

## Never in git

These files are git-ignored. Keep copies as described in
[disaster recovery](../operations/disaster-recovery.md#what-you-must-have-before-a-disaster).

| File | Holds |
|---|---|
| `development/talos/controlplane.yaml`, `worker.yaml` | Cluster CA and join token |
| `development/talos/talosconfig`, `kubeconfig` | Admin credentials |
| `**/terraform.tfvars`, `*.tfstate` | Endpoint settings, VM state |
| `age-key.txt` | SOPS private key |
| `.env` | Local API keys |

## Per-folder READMEs

Each main folder has its own detailed README on GitHub:
[ansible](https://github.com/nikpcenicni/Nikflix/blob/main/ansible/README.md) ·
[development/terraform](https://github.com/nikpcenicni/Nikflix/blob/main/development/terraform/README.md) ·
[development/talos](https://github.com/nikpcenicni/Nikflix/blob/main/development/talos/README.md) ·
[terraform](https://github.com/nikpcenicni/Nikflix/blob/main/terraform/README.md) ·
[argocd](https://github.com/nikpcenicni/Nikflix/blob/main/argocd/README.md)
