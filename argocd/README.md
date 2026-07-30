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
│   │   ├── bazarr.yaml
│   │   ├── cert-manager.yaml
│   │   ├── external-dns.yaml
│   │   ├── headlamp.yaml
│   │   ├── jellyseerr.yaml
│   │   ├── kube-prometheus-stack.yaml
│   │   ├── loki.yaml
│   │   ├── metallb.yaml
│   │   ├── prowlarr.yaml
│   │   ├── qbittorrent.yaml
│   │   ├── radarr.yaml
│   │   ├── sabnzbd.yaml
│   │   ├── sonarr.yaml
│   │   ├── sops-secrets-operator.yaml
│   │   ├── traefik.yaml
│   │   ├── argocd.yaml
│   │   ├── argocd-config.yaml
│   │   ├── authentik-outpost.yaml
│   │   ├── cluster-issuers.yaml
│   │   ├── coredns.yaml
│   │   ├── ingress-apps.yaml
│   │   ├── media-bootstrap.yaml
│   │   ├── media-forward-auth.yaml
│   │   ├── metallb-pool.yaml
│   │   └── secrets.yaml
│   ├── values/
│   │   ├── alloy-values.yaml
│   │   ├── authentik-values.yaml
│   │   ├── bazarr-values.yaml
│   │   ├── cert-manager-values.yaml
│   │   ├── external-dns-values.yaml
│   │   ├── headlamp-values.yaml
│   │   ├── jellyseerr-values.yaml
│   │   ├── kube-prometheus-stack-values.yaml
│   │   ├── loki-values.yaml
│   │   ├── metallb-values.yaml
│   │   ├── prowlarr-values.yaml
│   │   ├── qbittorrent-values.yaml
│   │   ├── radarr-values.yaml
│   │   ├── sabnzbd-values.yaml
│   │   ├── sonarr-values.yaml
│   │   ├── sops-secrets-operator-values.yaml
│   │   └── traefik-values.yaml
│   └── manifests/
│       ├── argocd/              # vendored copy of ArgoCD's own install manifest
│       ├── argocd-config/
│       ├── authentik-outpost/
│       ├── cluster-issuers/
│       ├── coredns/
│       ├── ingress-apps/
│       ├── media-bootstrap/
│       ├── media-forward-auth/
│       ├── metallb-pool/
│       └── secrets/            # SOPS-encrypted SopsSecret resources - see "Secrets management" below
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

- **Helm-chart Applications** (`alloy`, `authentik`, `external-dns`,
  `kube-prometheus-stack`, `loki`, `sops-secrets-operator` in `dev/`) each
  use two sources: a Helm chart from an upstream chart repository, and this
  git repository for the matching values file in that cluster's `values/`.
  ArgoCD calls this a
  [multi-source Application](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/).
- **Raw-manifest Applications** (`argocd`, `argocd-config`,
  `authentik-outpost`, `cluster-issuers`, `coredns`, `ingress-apps`,
  `media-bootstrap`, `media-forward-auth`, `metallb-pool`, `secrets` in
  `dev/`) each use one source: a directory of plain Kubernetes manifests
  under that cluster's `manifests/`.

## Applications (dev)

| Application | Deploys | Namespace | Purpose |
|---|---|---|---|
| `alloy` | Helm chart `alloy` from the Grafana chart repository, values in `dev/values/alloy-values.yaml` | `monitoring` | Per-node log shipper. Alloy runs as a DaemonSet on every node and sends pod logs to Loki. |
| `authentik` | Helm chart `authentik` from the authentik chart repository, values in `dev/values/authentik-values.yaml` | `authentik` | Identity provider (SSO). Serves `auth.lab.pcenicni.dev`. Its values file embeds a declarative [blueprint](https://docs.goauthentik.io/customize/blueprints/) (`authentik-blueprints` ConfigMap) that creates the OAuth2/OIDC provider, application, and RBAC groups for Grafana, ArgoCD, and Headlamp - see [SSO / authentik](#sso--authentik). Depends on `sops-secrets-operator` and `secrets` having synced first. |
| `bazarr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/bazarr-values.yaml` | `media` | Subtitle automation - watches the Sonarr/Radarr libraries and fetches matching subtitles. See [Media stack](#media-stack). |
| `cert-manager` | Helm chart `cert-manager` from the jetstack chart repository, values in `dev/values/cert-manager-values.yaml` | `cert-manager` | Issues and renews TLS certificates. Brought under GitOps at the chart version already running (`cert-manager-v1.21.0`) - see [Applications brought under GitOps](#applications-brought-under-gitops). `cluster-issuers` depends on this. Syncs with `ServerSideApply=true`, same annotation-size reasoning as `kube-prometheus-stack`. |
| `external-dns` | Helm chart `external-dns` from the official external-dns chart repository, values in `dev/values/external-dns-values.yaml` | `external-dns` | Watches Ingress resources cluster-wide and auto-creates/updates matching `*.lab.pcenicni.dev` records in pi-hole's custom DNS list - see [DNS / external-dns](#dns--external-dns). Depends on `sops-secrets-operator` and `secrets` having synced first. |
| `headlamp` | Helm chart `headlamp` from the Headlamp chart repository, values in `dev/values/headlamp-values.yaml` | `headlamp` | Web-based Kubernetes dashboard. Brought under GitOps at the chart version already running (`headlamp-0.43.0`). Not yet SSO-wired - see [SSO / authentik](#sso--authentik). |
| `jellyseerr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/jellyseerr-values.yaml` | `media` | User-facing request portal - approved requests get forwarded to Sonarr/Radarr. See [Media stack](#media-stack). |
| `kube-prometheus-stack` | Helm chart `kube-prometheus-stack` from the Prometheus Community chart repository, values in `dev/values/kube-prometheus-stack-values.yaml` | `monitoring` | Metrics and dashboards. The chart installs Prometheus and Grafana. The dev cluster's values file disables Alertmanager and configures Grafana's `auth.generic_oauth` against authentik, mapping the `Grafana Admins`/`Grafana Editors`/`Grafana Viewers` authentik groups to Grafana's Admin/Editor/Viewer org roles. Syncs with `ServerSideApply=true` - the prometheus-operator CRDs this chart installs are too large for client-side apply's `last-applied-configuration` annotation (hits Kubernetes' 262144-byte annotation limit). |
| `loki` | Helm chart `loki` from the Grafana chart repository, values in `dev/values/loki-values.yaml` | `monitoring` | Log storage. Loki stores the logs that Alloy sends to it. The dev cluster's values file sets single-binary mode with filesystem storage. |
| `metallb` | Helm chart `metallb` from the official metallb chart repository, values in `dev/values/metallb-values.yaml` | `metallb-system` | Assigns LoadBalancer IPs on bare metal. Brought under GitOps at the chart version already running (`metallb-0.16.1`) - see [Applications brought under GitOps](#applications-brought-under-gitops). `metallb-pool` depends on this. Syncs with `ServerSideApply=true`. |
| `prowlarr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/prowlarr-values.yaml` | `media` | Indexer manager - one place to configure trackers/indexers, pushed out to Sonarr, Radarr, and the downloaders. See [Media stack](#media-stack). |
| `qbittorrent` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/qbittorrent-values.yaml` | `media` | Torrent download client, routed through a PIA VPN via a gluetun sidecar container in the same pod. See [Media stack](#media-stack). Depends on the `qbittorrent-vpn-credentials` SopsSecret and `sops-secrets-operator` having synced first. |
| `radarr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/radarr-values.yaml` | `media` | Movie automation - same as Sonarr, for movies. See [Media stack](#media-stack). |
| `sabnzbd` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/sabnzbd-values.yaml` | `media` | Usenet download client - no VPN needed (provider-based, not peer-to-peer). See [Media stack](#media-stack). |
| `sonarr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/sonarr-values.yaml` | `media` | TV automation - tracks wanted episodes, searches indexers, sends grabs to a downloader, imports finished files. See [Media stack](#media-stack). |
| `sops-secrets-operator` | Helm chart `sops-secrets-operator` from the isindir chart repository, values in `dev/values/sops-secrets-operator-values.yaml` | `sops` | Watches `SopsSecret` custom resources cluster-wide and decrypts them into real Kubernetes Secrets - see [Secrets management](#secrets-management). |
| `traefik` | Helm chart `traefik` from the official traefik chart repository, values in `dev/values/traefik-values.yaml` | `traefik` | Ingress controller. Brought under GitOps at the chart version already running (`traefik-41.0.2`) - see [Applications brought under GitOps](#applications-brought-under-gitops). `ingress-apps` routes through this. Syncs with `ServerSideApply=true`. |
| `argocd` | Raw manifests (vendored upstream install manifest) in `dev/manifests/argocd/` | `argocd` | The rest of ArgoCD's own install, beyond what `argocd-config` manages - CRDs, controllers, RBAC. ArgoCD managing itself - see [Applications brought under GitOps](#applications-brought-under-gitops). |
| `argocd-config` | Raw manifests in `dev/manifests/argocd-config/` | `argocd` | Patches the `argocd-cm`, `argocd-rbac-cm`, and `argocd-cmd-params-cm` ConfigMaps that ArgoCD's own install created. Wires up OIDC login against authentik, maps the `ArgoCD Admins`/`ArgoCD Viewers` authentik groups to ArgoCD's built-in `admin`/`readonly` roles, and keeps `argocd-server` running in `--insecure` mode since Traefik terminates TLS. |
| `authentik-outpost` | Raw manifests in `dev/manifests/authentik-outpost/` | `authentik` | Deployment/Service for the media stack's authentik proxy outpost - see [SSO: authentik forward-auth](#sso-authentik-forward-auth-domain-level). Not authentik-managed (no service-connection configured), so tracked like any other by-hand Deployment. Depends on the `authentik` Application's blueprint and the `authentik-outpost-media-token` SopsSecret. |
| `cluster-issuers` | Raw manifests in `dev/manifests/cluster-issuers/` | `cert-manager` | cert-manager `ClusterIssuer` resources. The manifests define a Let's Encrypt staging issuer and a Let's Encrypt production issuer, both through a Cloudflare DNS-01 challenge for the `pcenicni.dev` zone. |
| `coredns` | Raw manifests in `dev/manifests/coredns/` | `kube-system` | Patches the `coredns` ConfigMap Talos's own bootstrap installed, so pods resolve the four `*.lab.pcenicni.dev` hostnames to Traefik's in-cluster IP directly instead of falling through to public DNS - see [SSO / authentik](#sso--authentik). |
| `ingress-apps` | Raw manifests in `dev/manifests/ingress-apps/` | `default` (each resource sets its own namespace) | `Ingress` resources for ArgoCD, Headlamp, Grafana, and authentik. Each resource routes traffic through Traefik and requests a certificate from the `letsencrypt-prod` cluster issuer. |
| `media-bootstrap` | Raw manifests in `dev/manifests/media-bootstrap/` | `media` | One-shot Job wiring Prowlarr/Sonarr/Radarr/Bazarr together via their REST APIs - see [Media stack](#media-stack)'s "First-time setup" section. Not automated-sync - sync it by hand when needed. |
| `media-forward-auth` | Raw manifests in `dev/manifests/media-forward-auth/` | `media` | Traefik `Middleware` for the media stack's authentik SSO - see [SSO: authentik forward-auth](#sso-authentik-forward-auth-domain-level). Depends on `authentik-outpost` having synced first. |
| `metallb-pool` | Raw manifests in `dev/manifests/metallb-pool/` | `metallb-system` | MetalLB `IPAddressPool` and `L2Advertisement` resources. These resources give MetalLB the address range `192.168.10.240`–`192.168.10.245` to assign to `LoadBalancer` services. |
| `secrets` | Raw manifests (SOPS-encrypted) in `dev/manifests/secrets/` | `authentik` (each resource sets its own namespace) | `SopsSecret` resources for authentik, Grafana, and ArgoCD's OIDC/database credentials, and pi-hole's API password - see [Secrets management](#secrets-management). Depends on `sops-secrets-operator` having synced first. |

Every Application above uses automated sync with `prune: true` and
`selfHeal: true`. This setting means ArgoCD applies matching changes
from git automatically, removes resources that git no longer defines,
and reverts manual changes made directly in the cluster.

## SSO / authentik

`authentik-blueprints` (in `dev/values/authentik-values.yaml`) declaratively
creates, for each of Grafana, ArgoCD, and Headlamp: an OAuth2/OIDC provider
and application in authentik, plus one or more RBAC groups. Group
*membership* is not managed by GitOps - after authentik first syncs, assign
real users to the `Grafana Admins`/`Editors`/`Viewers`, `ArgoCD
Admins`/`Viewers`, and `Headlamp Admins` groups by hand in the authentik UI.
The bootstrap `akadmin` superuser is seeded into each app's admin group
automatically, so it has working admin access to every app from the start.

Grafana and ArgoCD are fully wired: both read the `groups` claim authentik's
default `profile` scope mapping returns, from their own app-level OIDC
config (`grafana.ini`'s `auth.generic_oauth` and `argocd-cm`'s
`oidc.config`/`argocd-rbac-cm`'s `policy.csv` respectively) - no cluster-level
changes needed beyond `coredns` (below).

Both the OAuth2 authorization code exchange (Grafana → authentik) and the
OIDC callback validation (ArgoCD → authentik) happen server-to-server,
*from inside the cluster*, not from the user's browser. Pods therefore need
`auth.lab.pcenicni.dev` (and the other three `*.lab.pcenicni.dev` hosts) to
resolve to Traefik's in-cluster LoadBalancer IP the same way a LAN client's
browser does via split-horizon DNS on the LAN's own resolver - the `coredns`
Application (see the table above) makes the cluster self-sufficient for this
instead of depending on whatever DNS server the Talos node itself happens to
use. Without it, these hostnames fall through to public DNS from inside the
cluster and pods land on an unrelated host, which surfaces as a confusing
TLS certificate mismatch (Grafana) or a token/callback failure (ArgoCD), not
an obvious DNS error.

Headlamp is **not** fully wired. The authentik-side provider, application,
and `Headlamp Admins` group exist, but logging in via SSO also requires
configuring the Kubernetes API server's `--oidc-*` flags (a Talos machine
config change under `development/talos/`, applied by hand per
`development/README.md` - out of scope for this GitOps tree, and not yet
done) and giving Headlamp itself an OIDC client config (Headlamp is not yet
onboarded as a tracked Application at all - see "Applications not yet
onboarded" below). Until both of those happen, Headlamp keeps working the
same way it does today (in-cluster service account), unaffected by
authentik's presence.

## DNS / external-dns

`coredns` (above) makes hostnames resolve correctly *from inside* the
cluster. `external-dns` handles the other direction: it watches every
Ingress resource cluster-wide and keeps pi-hole's custom DNS list in sync,
so a LAN client (a browser, `curl`, another machine) gets a working record
for a new `*.lab.pcenicni.dev` hostname without anyone adding it to pi-hole
by hand - which is how `auth.lab.pcenicni.dev` almost didn't work the first
time authentik was added (see [Configuring the authentik admin
account](#configuring-the-authentik-admin-account) - that was fixed by hand
before external-dns existed).

Only one pi-hole exists today (`192.168.1.127` - see
`dev/values/external-dns-values.yaml`), even though the network has three
(see the root [README.md](../README.md)'s port mapping table). When the
other two join a synced pi-hole setup, update `pihole-server` to whichever
one becomes the source of truth - external-dns only writes to one target at
a time, so the sync mechanism between pi-holes (not this repo) is what
propagates records to the rest.

`policy: upsert-only` is deliberate, not a default left alone: this pi-hole
already has many hand-managed custom DNS entries for the rest of the home
lab (NAS, other VMs, non-Kubernetes services). external-dns only ever
creates or updates records for hosts it currently sees on a
`lab.pcenicni.dev` Ingress (`domainFilters`) - it never deletes anything,
even a stale record for an Ingress that's since been removed. Clean those up
by hand in pi-hole if that ever matters; the alternative (`policy: sync`)
risks deleting hand-managed records pi-hole has no way to tell apart from
ones external-dns created, since pi-hole's DNS API has no per-record
ownership tracking to begin with (`registry: noop`).

## Media stack

`jellyseerr`, `sonarr`, `radarr`, `prowlarr`, `qbittorrent`, `sabnzbd`, and
`bazarr` (all in the `media` namespace) are the Talos-side half of
[docs/architecture/media-stack.md](../docs/architecture/media-stack.md).
Jellyfin itself runs on a Mac Mini outside the cluster and outside this
GitOps tree entirely - see that doc for why. All seven Applications use the
generic [bjw-s/app-template](https://github.com/bjw-s-labs/helm-charts)
chart, since none of these images ship an official Helm chart.

### Storage: NAS-backed, not Longhorn

Each app's own config (SQLite databases, settings) uses a small `local-path`
PVC, the same stand-in every other dev-cluster app uses - see
[Applications brought under GitOps](#applications-brought-under-gitops).
Longhorn is deliberately not part of this: see
[talos.md's storage section](../docs/architecture/talos.md#storage-longhorn-on-dedicated-per-node-ssds)
and its Open Questions for why Longhorn stays deferred until real per-node
SSDs are working.

The shared library and download-staging areas are NFS mounts straight to
the NAS - `sonarr-values.yaml`, `radarr-values.yaml`, `bazarr-values.yaml`,
`qbittorrent-values.yaml`, and `sabnzbd-values.yaml` each declare these as
`persistence.<name>.type: nfs` entries (chart-native, no PVC/StorageClass
involved). The NFS server is `192.168.50.105` - an old NAS on VLAN 50
(OpenMediaVault), standing in until the target-state NAS (VLAN 80, per
[media-stack.md](../docs/architecture/media-stack.md#storage-shared-nas-library))
is built. This NAS already had an existing layout from a prior *arr setup,
so the mounts follow that instead of media-stack.md's simpler
`downloads/`+`library/` split:

| NFS export (OMV `/export/*` alias, not the raw `/srv/mergerfs/...` path) | Mounted at `/torrents` in | Mounted at `/usenet` in | Mounted at `/media` in |
|---|---|---|---|
| `/export/torrents` | qbittorrent, sonarr, radarr | - | - |
| `/export/usenet` | - | sabnzbd, sonarr, radarr | - |
| `/export/media` | - | - | sonarr, radarr, bazarr |

Sonarr and Radarr each mount all three, since either can import from
either download client, then move the finished file into `/media` (see
[media-stack.md's storage section](../docs/architecture/media-stack.md#storage-shared-nas-library)
for why the design moves completed downloads into the library instead of
hardlinking them). Sonarr's and Radarr's own root-folder settings get
pointed at `/media/tv` and `/media/movies` respectively through their web
UIs - see "First-time setup" below. `192.168.10.0/24` (the Talos VMs'
actual network) is already permitted on all three exports per
`/etc/exports` on the NAS - confirm against that file directly if a mount
ever fails unexpectedly.

`PUID`/`PGID` on every container are `1004`/`100`, matching the NAS's
`media` system account and the `users` group the existing data already
belongs to. `UMASK=002` on the apps that write into these exports keeps
newly-created files group-writable. Two of the three shares needed a
one-time permission fix before this would actually work - `media` and
`torrents` were `755` (owner-only write), while `usenet` already had the
right setgid + group-write pattern:

```sh
chmod -R g+w /srv/mergerfs/Pool/Data/media /srv/mergerfs/Pool/Data/torrents
chmod g+s /srv/mergerfs/Pool/Data/media /srv/mergerfs/Pool/Data/torrents
```

### qBittorrent's VPN sidecar

`qbittorrent-values.yaml` runs two containers in one pod: `gluetun` (brings
up a PIA VPN tunnel) and `qbittorrent`. Containers in the same Kubernetes
pod already share a network namespace, so qBittorrent's traffic rides
through gluetun's tunnel automatically - no special sidecar wiring needed
beyond that. `gluetun` needs the `qbittorrent-vpn-credentials` SopsSecret
(`dev/manifests/secrets/qbittorrent-vpn.yaml`), which holds PIA account
credentials. Edit it with:

```sh
sops argocd/dev/manifests/secrets/qbittorrent-vpn.yaml
```

Sonarr, Radarr, and Bazarr don't need a VPN - only qBittorrent's torrent
swarm traffic exposes an IP address to peers; SABnzbd's Usenet traffic
doesn't. See
[media-stack.md's Components table](../docs/architecture/media-stack.md#components).

### First-time setup: automated for everything except Jellyseerr

None of these apps have a declarative bootstrap mechanism the way
authentik's blueprint ConfigMap does, so `media-bootstrap` (raw manifests
in `dev/manifests/media-bootstrap/`) wires them together via their own
REST APIs instead of clicking through each web UI by hand:

- **Sonarr** - root folder set to `/media/tv`; native login disabled (see
  below).
- **Radarr** - root folder set to `/media/movies`; native login disabled.
- **Prowlarr** - Sonarr and Radarr added as Applications; qBittorrent and
  SABnzbd added as download clients.
- **Bazarr** - connected to both Sonarr and Radarr.

Sonarr and Radarr each also have their own native login (a mandatory
"create an account" prompt on first UI access) that's entirely separate
from - and unaware of - authentik's forward-auth already in front of
them. The bootstrap Job sets both apps' `authenticationRequired` to
`disabledForLocalAddresses` via `PUT /api/v3/config/host/1`, which
bypasses their own auth for any private-range source IP - covering all
in-cluster traffic, including from Traefik, since this cluster's
pod/service CIDRs are themselves private ranges. authentik stays the one
real gatekeeper.

This Application is **not** automated-sync - Jobs are immutable after
creation, so ArgoCD's usual prune/selfHeal would fight with a Job that
already ran. Sync it by hand once (ArgoCD UI "Sync" button, or
`argocd app sync media-bootstrap`) after the apps above are healthy; every
step checks for the thing it's about to create first, so re-syncing later
is safe. It reads each app's API key/password from the
`media-bootstrap-api-keys` SopsSecret - these are the apps' own
auto-generated credentials (LinuxServer.io *arr images and Bazarr
generate an API key on first boot; qBittorrent has no API key, only a
WebUI password, so its temporary auto-generated one was reset to a real
value via qBittorrent's own API rather than kept as the plaintext value
it logs on first boot), read from the already-running pods once, not set
by this repo. If an app's PVC is ever wiped and it generates new
credentials, re-derive and update that Secret before re-syncing this Job.

**Jellyseerr is deliberately not wired up here.** Its first-run flow
needs interactive admin-account creation (Plex OAuth or a local user),
which doesn't fit a scripted, API-key-based bootstrap. Connect it by
hand, once: **Jellyseerr** - connect to Sonarr and Radarr, and to
Jellyfin on the Mac Mini (point it at the SMB library share).

Two non-obvious bugs surfaced while building the Prowlarr/Bazarr calls -
see the comments in `dev/manifests/media-bootstrap/media-bootstrap.yaml`
for the details, and [[nikflix_media_stack_nas]] memory for the full
debugging trail:
- Prowlarr 2.5.2's download-client validation throws an unhandled
  `NullReferenceException` (surfaced as an opaque "Test was aborted due
  to an error") if the top-level `categories` field is omitted, even as
  an empty array - found by reading Prowlarr's own container logs for the
  real .NET stack trace, not from the API's own error response.
- Bazarr's settings API never casts string form values to `bool` before
  its dynaconf validator checks them - use dynaconf's `@bool` cast-prefix
  syntax (`@bool true`/`@bool false`) on those specific fields instead of
  a plain `true`/`false` string.

### SSO: authentik forward-auth (domain level)

`sonarr`, `radarr`, `prowlarr`, `bazarr`, `qbittorrent`, and `sabnzbd` sit
behind authentik SSO - `jellyseerr` deliberately doesn't, since it's the
app household members use directly. None of these apps support OIDC/SAML
natively, so this uses authentik's **forward-auth (domain level)** proxy
mode instead of the OAuth2 pattern [SSO / authentik](#sso--authentik)
describes for Grafana/ArgoCD/Headlamp: one login, via cookie_domain
`lab.pcenicni.dev`, covers every protected host - no separate login per
app.

The pieces, across three Applications:

- **`authentik`** (the blueprint) creates one `ProxyProvider` (mode
  `forward_domain`), one `Application`, and one `Outpost` DB object -
  see the "Media stack forward auth" entries in `dev/values/authentik-values.yaml`.
- **`authentik-outpost`** deploys the actual outpost pod (raw manifests in
  `dev/manifests/authentik-outpost/`) - `ghcr.io/goauthentik/proxy`,
  version-pinned to match the authentik server/worker exactly. This isn't
  authentik-managed (no Docker/Kubernetes service-connection configured),
  so it's a plain Deployment/Service tracked like any other app here.
- **`media-forward-auth`** is a Traefik `Middleware` CRD
  (`dev/manifests/media-forward-auth/`) pointing at the outpost's
  `/outpost.goauthentik.io/auth/traefik` endpoint. Each protected app's
  Ingress references it via the
  `traefik.ingress.kubernetes.io/router.middlewares: media-authentik-forward-auth@kubernetescrd`
  annotation in its own values file.

**Bootstrapping the outpost token**: authentik auto-creates a service
account and API token for every Outpost, but that token can't be set
declaratively via blueprint - it's generated after the Outpost object
first exists. `dev/manifests/secrets/authentik-outpost-media-token.yaml`
starts as a placeholder SopsSecret; fill in the real token once, the same
bootstrap pattern as `sops-age-key`/`cloudflare-api-token`:

```sh
# From an authentik shell (e.g. kubectl exec into the worker pod, `ak shell`):
#   from authentik.outposts.models import Outpost
#   from authentik.core.models import Token
#   o = Outpost.objects.get(name="Media stack outpost")
#   Token.objects.get(user=o.user, intent="api").key
# then:
sops argocd/dev/manifests/secrets/authentik-outpost-media-token.yaml
```

CAUTION: `!KeyOf` inside a list item (e.g. `providers: [!KeyOf some-id]`)
hits a real bug in authentik 2026.5.6's blueprint importer - it crashes
trying to *log* the resulting `EntryInvalidError` instead of reporting it
cleanly, which makes the failure look like nothing in both the admin UI
and the worker's logs. Use `!Find` (a live DB lookup by field match)
instead for this specific case - see the comment on the Outpost entry in
`dev/values/authentik-values.yaml`. The Outpost serializer also requires
an explicit `config.authentik_host` despite the model having a default -
omitting it fails with a plain "This field is required."

## Configuring the authentik admin account

### First login

Go to `https://auth.lab.pcenicni.dev/` and sign in as `akadmin` - the
`AUTHENTIK_BOOTSTRAP_PASSWORD` env var (see
`dev/values/authentik-values.yaml`) already created this account on first
boot, so there's no setup wizard to click through. Get the password by
decrypting `dev/manifests/secrets/authentik-config.yaml`:

```sh
sops -d dev/manifests/secrets/authentik-config.yaml | grep AUTHENTIK_BOOTSTRAP_PASSWORD
```

(see [Secrets management](#secrets-management) below for `SOPS_AGE_KEY_FILE`
setup). This value only creates `akadmin` the *first* time authentik starts
against an empty database - changing it in git afterward does nothing to the
already-created account. Rotate the account's actual password from inside
authentik instead (next section), not by editing this file.

### Secure the account after first login

Do these two things immediately after the first login, before creating or
inviting any other users:

1. **Change the `akadmin` password.** User menu (top right) → **Settings** →
   set a new password. This replaces the bootstrap password from git with
   one that exists only in authentik's database.
2. **Enable MFA (TOTP) on `akadmin`.** Same **Settings** page → **Add TOTP
   Authenticator**. `akadmin` is a superuser with unrestricted access to
   every app this cluster's SSO covers (see [SSO /
   authentik](#sso--authentik)) and to authentik's own admin interface, so
   treat it like a root account, not a day-to-day login.

### Day-to-day admin access

Prefer creating a personal admin user over sharing `akadmin` for regular
use. In authentik's admin interface: **Directory → Users → Create**, then
**Directory → Groups → authentik Admins → members** to add that user - this
is the same built-in superuser group `akadmin` belongs to, created
automatically by authentik itself (not by this repo's blueprint).

### Granting app access to other users

The `Grafana Admins`/`Editors`/`Viewers`, `ArgoCD Admins`/`Viewers`, and
`Headlamp Admins` groups the `authentik-blueprints` ConfigMap creates (see
[SSO / authentik](#sso--authentik)) start with no members except `akadmin`.
To give someone access to Grafana or ArgoCD: **Directory → Users → Create**
for them, then **Directory → Groups → <group name> → members** to add them
to the group matching the access level they need. Membership takes effect
on their next login - no sync or cluster change required, since this is
authentik-internal state, not something GitOps tracks.

## Secrets management

Every secret this repo needs (authentik's `secret_key`, its Postgres
credentials, its `akadmin` bootstrap password, and the OAuth2 client
id/secret pairs for the Grafana/ArgoCD/Headlamp integrations above) is
[SOPS](https://github.com/getsops/sops)-encrypted with
[age](https://github.com/FiloSottile/age) and committed as ciphertext under
`dev/manifests/secrets/` - never plaintext in git. `sops-secrets-operator`
(see the Applications table above) watches those `SopsSecret` custom
resources in-cluster and decrypts them into real `Secret` objects; the apps
that need them (authentik, Grafana, argocd-cm) reference those Secrets by
name, mostly via each chart's `existingSecret`/`envFromSecret` support or a
plain `secretKeyRef`.

`.sops.yaml` at the repo root scopes encryption to
`argocd/*/manifests/secrets/*.yaml` and to only the `data`/`stringData`
fields within them - everything else in those files (names, namespaces,
labels, comments) stays plaintext so diffs and reviews stay readable.

### Bootstrapping (once per cluster)

Like `cluster-issuers`' `cloudflare-api-token` Secret, the age decryption key
is a chicken-and-egg dependency: it has to exist in the cluster *before*
`sops-secrets-operator` can decrypt anything, so it can't itself be a
`SopsSecret`. Generate and install it by hand, once per cluster:

```sh
age-keygen -o age-key.txt
kubectl create namespace sops
kubectl -n sops create secret generic sops-age-key --from-file=keys.txt=age-key.txt
```

Save `age-key.txt` somewhere durable outside git (a password manager) - it's
the only way to decrypt or re-encrypt anything under `dev/manifests/secrets/`
in the future. Put the `# public key:` line `age-keygen` printed into
`.sops.yaml`'s `age:` field so `sops -e` encrypts against it.

### Editing an encrypted secret

```sh
export SOPS_AGE_KEY_FILE=/path/to/age-key.txt   # or ~/.config/sops/age/keys.txt
sops argocd/dev/manifests/secrets/authentik-config.yaml
```

`sops` decrypts to a scratch file, opens your `$EDITOR`, and re-encrypts on
save - the ciphertext in git never needs manual handling. To add a brand new
`SopsSecret`, write it as plaintext YAML first, then run
`sops --encrypt --in-place <file>` once.

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

NOTE: `authentik`, `secrets`, and `argocd-config` need the
`sops-secrets-operator` Application synced first, and that operator needs
the `sops-age-key` Secret bootstrapped by hand - see [Secrets
management](#secrets-management)'s "Bootstrapping" steps. Until that Secret
exists, `sops-secrets-operator`'s pod runs fine but every `SopsSecret`
fails to decrypt, and authentik's pods sit in `ContainerCreating` waiting on
Secrets that never appear.

NOTE: The `cluster-issuers` Application needs the `cert-manager` Application
synced first (for the CRDs and controller), and a secret named
`cloudflare-api-token` already in the cluster (see [Secrets
management](#secrets-management)).

NOTE: The `metallb-pool` Application needs the `metallb` Application synced
first, for MetalLB's CRDs and controller.

NOTE: `dev/values/external-dns-values.yaml` hardcodes pi-hole's current IP
(`192.168.1.127`) as `pihole-server`, and needs "Permit destructive actions
via API" reachable/working on that pi-hole for record writes to succeed
(see [DNS / external-dns](#dns--external-dns)). If the pi-hole this points
at is ever replaced or re-IP'd, update `pihole-server` to match.

## Applications brought under GitOps

ArgoCD, cert-manager, MetalLB, Traefik, and Headlamp were all originally
installed by hand, before this repo tracked them as Applications. Each is
now onboarded (`argocd`, `cert-manager`, `metallb`, `traefik`, `headlamp` in
the table above), pinned to the exact chart/manifest version already
running, so onboarding was a no-op sync against the live cluster rather
than a redeploy.

cert-manager, MetalLB, and Traefik are plain Helm-chart Applications, the
same pattern as `alloy` or `kube-prometheus-stack` - see [Helm-chart
Applications](#applications-dev) above. Their values files reproduce
exactly what `helm get values <release> -n <namespace>` showed for the
by-hand install, so the first sync changes nothing.

ArgoCD itself is the interesting case, since it means ArgoCD manages its
own install. `dev/manifests/argocd/install.yaml` is a vendored copy of the
official install manifest for the exact version already running, with five
resources deliberately removed - `argocd-cm`, `argocd-rbac-cm`, and
`argocd-cmd-params-cm` (already fully owned by `argocd-config`, which
patches in real OIDC/RBAC/insecure-mode config), and `argocd-secret` /
`argocd-notifications-secret` (hold live runtime state - the admin
password hash, JWT signing key, and notification credentials - that
ArgoCD generates itself; re-applying upstream's empty placeholder version
of either would wipe that out and break login). See the comment at the
top of that file for how to carry this forward on a future ArgoCD upgrade.
