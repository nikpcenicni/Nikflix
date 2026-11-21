# Platform

<p class="lead">The shared services every app relies on: how traffic gets
in, how apps get certificates and logins, and how the cluster is
watched.</p>

## Request path

```mermaid
sequenceDiagram
    participant B as Browser (LAN)
    participant D as Pi-hole
    participant M as MetalLB VIP<br/>192.168.10.240
    participant T as Traefik
    participant A as authentik outpost
    participant S as App
    B->>D: sonarr.lab.pcenicni.dev?
    D-->>B: 192.168.10.240 (wildcard)
    B->>M: HTTPS
    M->>T: route to Traefik pod
    T->>A: forward-auth check
    A-->>T: OK (or redirect to login)
    T->>S: proxied request
```

## Components

=== "Delivery"

    | Component | Job |
    |---|---|
    | **Talos Linux** `v1.13.7` | Immutable, API-managed OS for every Kubernetes node. No SSH |
    | **ArgoCD** | App-of-apps GitOps. Manages itself and every other Application |
    | **Renovate** | Opens dependency PRs. CI then auto-merges them |
    | **Ballast** | Rightsizes CPU and memory requests for opted-in apps |
    | **Harbor** | Container registry at `registry.lab.pcenicni.dev` |

=== "Networking"

    | Component | Job |
    |---|---|
    | **Flannel** | Pod network (Talos default) |
    | **MetalLB** | Gives `LoadBalancer` services addresses `192.168.10.240`-`.245` |
    | **Traefik** | Ingress controller and TLS termination |
    | **CoreDNS patch** | Pods resolve lab hostnames straight to Traefik |
    | **WireGuard** (wg-easy) | Remote access VPN on `192.168.10.244` UDP 51820 |
    | **Cilium** | <span class="pill wip">Staged</span> replacement for Flannel and kube-proxy |

=== "Identity and TLS"

    | Component | Job |
    |---|---|
    | **authentik** | SSO. OIDC for ArgoCD, Grafana, Headlamp, Harbor, Vikunja. Forward-auth for apps without login |
    | **Kubernetes OIDC** | kube-apiserver trusts authentik for `kubectl` and Headlamp |
    | **cert-manager** | Let's Encrypt certificates through a Cloudflare DNS-01 challenge |
    | **sops-secrets-operator** | Decrypts `SopsSecret` resources from git into Secrets |

=== "Observability"

    | Component | Job |
    |---|---|
    | **Prometheus** | Metrics from the cluster, ArgoCD, authentik, and Proxmox |
    | **Grafana** | Dashboards at `grafana.lab.pcenicni.dev` |
    | **Loki + Alloy** | Log collection from every pod |
    | **pve-exporter** | Proxmox metrics through a read-only API token |
    | **Headlamp** | Web UI for Kubernetes at `headlamp.lab.pcenicni.dev` |

## GitOps flow

```mermaid
flowchart LR
    Dev["git push / Renovate PR"] --> GH["GitHub main"]
    GH --> Root["root-app-dev<br/>(argocd/bootstrap)"]
    Root --> Apps["argocd/dev/apps/*.yaml"]
    Apps --> Helm["Helm chart + values"]
    Apps --> Raw["Raw manifests"]
    Helm --> C[(Cluster)]
    Raw --> C
```

Every Application uses automated sync with `prune` and `selfHeal`, so
manual changes in the cluster are reverted. The exception is `cilium`,
which syncs by hand only.

## Storage

| Data | Where it lives | Backed up? |
|---|---|---|
| App config and databases | `local-path` PVC on the VM's disk | <span class="pill wip">No</span> - see [DR](../operations/disaster-recovery.md) |
| Media library and downloads | NFS from the NAS | On the NAS only |
| Prometheus and Loki data | `local-path` | No (rebuildable) |
| Declarative config | Git | Yes |
