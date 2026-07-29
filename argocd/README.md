# ArgoCD app-of-apps

This directory holds the GitOps configuration for every cluster's
[core platform applications](../docs/architecture/talos.md#core-platform-applications).
GitOps is a method that manages a cluster from files in a git
repository, instead of by hand. ArgoCD reads this repository and
applies its content to the cluster.

Every cluster shares this directory. Today that means the development
cluster only. The production cluster is still a Terraform-only
scaffold (see [../terraform/README.md](../terraform/README.md)).
Applications split into one subdirectory per cluster, plus a `shared/`
subdirectory for Applications common to every cluster:

```
argocd/
├── bootstrap/
│   ├── root-app-shared.yaml   # root Application for shared/, applied by hand in every cluster
│   ├── root-app-dev.yaml      # root Application for dev/, applied by hand in the dev cluster
│   └── root-app-prod.yaml     # root Application for prod/ - scaffold, no production cluster yet
├── shared/                    # Applications common to every cluster (empty so far)
│   ├── apps/
│   ├── values/
│   └── manifests/
├── dev/                       # Applications specific to the development cluster
│   ├── apps/
│   │   ├── alloy.yaml
│   │   ├── authentik.yaml
│   │   ├── kube-prometheus-stack.yaml
│   │   ├── loki.yaml
│   │   ├── argocd-config.yaml
│   │   ├── cluster-issuers.yaml
│   │   ├── ingress-apps.yaml
│   │   └── metallb-pool.yaml
│   ├── values/
│   │   ├── alloy-values.yaml
│   │   ├── authentik-values.yaml
│   │   ├── kube-prometheus-stack-values.yaml
│   │   └── loki-values.yaml
│   └── manifests/
│       ├── argocd-config/
│       ├── cluster-issuers/
│       ├── ingress-apps/
│       └── metallb-pool/
└── prod/                      # Applications specific to the production cluster (empty scaffold)
    ├── apps/
    ├── values/
    └── manifests/
```

ArgoCD manages the Applications in each `apps/` directory with the
app-of-apps pattern: one root Application manages a set of child
Applications, and each child Application manages one platform
component. An Application is a Custom Resource that tells ArgoCD what
to deploy and where to deploy it.

Every Application onboarded so far lives under `dev/`, because its
values are tuned to the development cluster: small VMs, the
development cluster's IP range, and `lab.`-prefixed hostnames. Move an
Application to `shared/` once its configuration stops differing
between clusters — see [shared/README.md](shared/README.md). Populate
`prod/` once the production cluster exists — see
[prod/README.md](prod/README.md).

The child Applications in each cluster's `apps/` split into two
groups:

- **Helm-chart Applications** (`alloy`, `kube-prometheus-stack`, `loki`
  in `dev/`) each use two sources: a Helm chart from an upstream chart
  repository, and this git repository for the matching values file in
  that cluster's `values/`. ArgoCD calls this a
  [multi-source Application](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/).
- **Raw-manifest Applications** (`cluster-issuers`, `ingress-apps`,
  `metallb-pool` in `dev/`) each use one source: a directory of plain
  Kubernetes manifests under that cluster's `manifests/`.

## Applications (dev)

| Application | Deploys | Namespace | Purpose |
|---|---|---|---|
| `alloy` | Helm chart `alloy` from the Grafana chart repository, values in `dev/values/alloy-values.yaml` | `monitoring` | Per-node log shipper. Alloy runs as a DaemonSet on every node and sends pod logs to Loki. |
| `kube-prometheus-stack` | Helm chart `kube-prometheus-stack` from the Prometheus Community chart repository, values in `dev/values/kube-prometheus-stack-values.yaml` | `monitoring` | Metrics and dashboards. The chart installs Prometheus and Grafana. The dev cluster's values file disables Alertmanager. |
| `loki` | Helm chart `loki` from the Grafana chart repository, values in `dev/values/loki-values.yaml` | `monitoring` | Log storage. Loki stores the logs that Alloy sends to it. The dev cluster's values file sets single-binary mode with filesystem storage. |
| `cluster-issuers` | Raw manifests in `dev/manifests/cluster-issuers/` | `cert-manager` | cert-manager `ClusterIssuer` resources. The manifests define a Let's Encrypt staging issuer and a Let's Encrypt production issuer, both through a Cloudflare DNS-01 challenge for the `pcenicni.dev` zone. |
| `ingress-apps` | Raw manifests in `dev/manifests/ingress-apps/` | `default` (each resource sets its own namespace) | `Ingress` resources for ArgoCD, Headlamp, and Grafana. Each resource routes traffic through Traefik and requests a certificate from the `letsencrypt-prod` cluster issuer. |
| `metallb-pool` | Raw manifests in `dev/manifests/metallb-pool/` | `metallb-system` | MetalLB `IPAddressPool` and `L2Advertisement` resources. These resources give MetalLB the address range `192.168.10.240`–`192.168.10.245` to assign to `LoadBalancer` services. |

Every Application above uses automated sync with `prune: true` and
`selfHeal: true`. This setting means ArgoCD applies matching changes
from git automatically, removes resources that git no longer defines,
and reverts manual changes made directly in the cluster.

## Bootstrap procedure

Use this procedure only once per cluster, when ArgoCD does not yet run
in that cluster. No GitOps method can deploy the first GitOps
controller, so this first step is a manual step.

1. Install ArgoCD in the cluster by hand.
2. Run these commands:
   ```sh
   kubectl apply -f argocd/bootstrap/root-app-shared.yaml
   kubectl apply -f argocd/bootstrap/root-app-dev.yaml
   ```
   Use `root-app-prod.yaml` instead of `root-app-dev.yaml` once the
   production cluster exists.

NOTE: Do not apply any other Application manifest in this repository
by hand. After step 2, ArgoCD creates and syncs every other
Application from git automatically.

After you apply the root Applications, ArgoCD reads them. Each root
Application points at one path in this git repository — `argocd/shared/apps`
or `argocd/dev/apps` (or `argocd/prod/apps`) — with `recurse: false`,
so it only reads Application manifests directly in that `apps/`
directory. It does not treat files under `values/` or `manifests/` as
separate Applications — each child Application reads those
directories as its own source. ArgoCD then creates each child
Application listed in the table above, and each child Application
syncs its own chart or manifests. This chain, from a root Application
down through the child Applications, is the app-of-apps pattern. It
also applies to the root Application manifests themselves: after the
first manual apply, ArgoCD reconciles future changes to them from git.

## Placeholders to check before you sync

Every Application manifest in `dev/apps/` and every
`bootstrap/root-app-*.yaml` sets `repoURL` to
`https://github.com/nikpcenicni/Nikflix.git`. If this repository is ever
forked or moved to a different remote, update `repoURL` in all of these
manifests to match — find every occurrence with `grep -rl 'repoURL:' argocd`.

NOTE: The Applications `alloy`, `kube-prometheus-stack`, and `loki` set
`targetRevision` to the placeholder `REPLACE_ME`. These three charts
already run in the dev cluster from a manual `helm install`. Find the
installed version with `helm list -n monitoring`. Set `targetRevision`
to that exact version before you enable sync for these Applications.
This step stops ArgoCD from upgrading a running Prometheus, Grafana,
or Loki release without warning.

NOTE: `dev/values/kube-prometheus-stack-values.yaml` sets
`grafana.adminPassword` to the placeholder value
`dev-admin-changeme`. Replace this value with a real secret before
you use this configuration outside development.

NOTE: The `cluster-issuers` Application needs cert-manager and a
secret named `cloudflare-api-token` already in the cluster. Install
both by hand before you sync this Application. Neither is tracked as
an Application yet.

NOTE: The `metallb-pool` Application needs MetalLB already installed
in the cluster. Install MetalLB by hand before you sync this
Application. MetalLB itself is not tracked as an Application yet.

## Applications not yet onboarded

ArgoCD, cert-manager, MetalLB, Traefik, and Headlamp already run in
the dev cluster. The Applications above depend on them, but each one
was installed by hand and is not yet tracked as an Application itself.
Bring each one under GitOps the same way as the Applications above,
with a chart and a values file, or with raw manifests, once you know
its currently installed chart version.
