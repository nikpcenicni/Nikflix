# Applications

ArgoCD deploys every Application below from `argocd/dev/apps/`. Every
Application syncs automatically with `prune` and `selfHeal`, except
`cilium` (manual). Per-Application details are in the
[argocd README](https://github.com/nikpcenicni/Nikflix/blob/main/argocd/README.md#applications-dev).

All web URLs are under `lab.pcenicni.dev` and resolve to Traefik at
`192.168.10.240`. **SSO** shows how users log in: *OIDC* is the app's
own authentik login, *forward-auth* is the shared authentik middleware
in front of the app.

## Platform

| Application | Namespace | Source | URL | SSO |
|---|---|---|---|---|
| argocd, argocd-config | `argocd` | Vendored manifest + config patches | `argocd.` | OIDC |
| authentik, authentik-outpost | `authentik` | `authentik` chart + manifests | `auth.` | - |
| secrets | (per secret) | SOPS-encrypted `SopsSecret` manifests | - | - |
| sops-secrets-operator | `sops` | `sops-secrets-operator` chart | - | - |
| cert-manager, cluster-issuers | `cert-manager` | `cert-manager` chart + ClusterIssuers (Let's Encrypt, Cloudflare DNS-01) | - | - |
| traefik | `traefik` | `traefik` chart | - | - |
| ingress-apps | (per ingress) | Ingress manifests for ArgoCD, authentik, Grafana, Headlamp | - | - |
| media-forward-auth | `media` | Traefik Middleware for forward-auth | - | - |
| metallb, metallb-pool | `metallb-system` | `metallb` chart + pool `192.168.10.240-245` | - | - |
| coredns | `kube-system` | ConfigMap patch | - | - |
| cilium | `kube-system` | `cilium` chart (manual sync, migration pending) | - | - |
| metrics-server | `kube-system` | `metrics-server` chart | - | - |
| kyverno | `kyverno` | `kyverno` chart + policies in `manifests/kyverno-policies/` | - | - |
| network-policies | (per namespace) | NetworkPolicy manifests | - | - |
| oidc-rbac | cluster-scoped | ClusterRoleBindings for OIDC users | - | - |
| ballast | `ballast` | `ballast` chart (auto-rightsizing) | - | - |
| harbor | `harbor` | `harbor` chart | `registry.` | OIDC |
| headlamp | `headlamp` | `headlamp` chart | `headlamp.` | OIDC |
| wireguard | `wireguard` | app-template (wg-easy); tunnel UDP 51820 on `192.168.10.244` | `wg.` | forward-auth |

## Monitoring

| Application | Namespace | Source | URL | SSO |
|---|---|---|---|---|
| kube-prometheus-stack | `monitoring` | Prometheus + Grafana (no Alertmanager) | `grafana.` | OIDC |
| loki | `monitoring` | Single-binary, filesystem storage | - | - |
| alloy | `monitoring` | DaemonSet log shipper → Loki | - | - |
| prometheus-pve-exporter | `monitoring` | Scrapes the Proxmox API at `192.168.10.10:8006` | - | - |

## Media stack

All use the bjw-s `app-template` chart in the `media` namespace. Config is
on `local-path`. Media and downloads are NFS from `192.168.50.105`.

| Application | Purpose | URL | SSO |
|---|---|---|---|
| seerr | Request portal | `seerr.` | Own login |
| sonarr | TV | `sonarr.` | forward-auth |
| radarr | Movies | `radarr.` | forward-auth |
| prowlarr | Indexers | `prowlarr.` | forward-auth |
| qbittorrent | Torrents, through a gluetun PIA VPN sidecar | `qbittorrent.` | forward-auth |
| sabnzbd | Usenet | `sabnzbd.` | forward-auth |
| bazarr | Subtitles | `bazarr.` | forward-auth |
| profilarr | Quality profiles | `profilarr.` | forward-auth |

Jellyfin runs on the Mac Mini, outside the cluster.

## Other apps

| Application | Namespace | Purpose | URL | SSO |
|---|---|---|---|---|
| homepage | `homepage` | Admin dashboard | `dash.` | forward-auth |
| vikunja | `vikunja` | Task manager | `vikunja.` | OIDC |
| opengym | `opengym` | Workout tracker | `gym.` | Passkeys |
| spoolman | `spoolman` | Filament inventory | `spoolman.` | forward-auth |
| bambuddy | `bambuddy` | Bambu printer manager; virtual printer on `192.168.10.245` | `bambuddy.` | forward-auth |
