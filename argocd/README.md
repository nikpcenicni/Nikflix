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
│   │   ├── eclipse-che.yaml
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
│   │   ├── che-cluster.yaml
│   │   ├── cluster-issuers.yaml
│   │   ├── coredns.yaml
│   │   ├── ingress-apps.yaml
│   │   ├── media-bootstrap.yaml
│   │   ├── media-forward-auth.yaml
│   │   ├── metallb-pool.yaml
│   │   ├── oidc-rbac.yaml
│   │   └── secrets.yaml
│   ├── values/
│   │   ├── alloy-values.yaml
│   │   ├── authentik-values.yaml
│   │   ├── bazarr-values.yaml
│   │   ├── cert-manager-values.yaml
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
│       ├── che-cluster/
│       ├── cluster-issuers/
│       ├── coredns/
│       ├── ingress-apps/
│       ├── media-bootstrap/
│       ├── media-forward-auth/
│       ├── metallb-pool/
│       ├── oidc-rbac/
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

- **Helm-chart Applications** (`alloy`, `authentik`,
  `kube-prometheus-stack`, `loki`, `sops-secrets-operator` in `dev/`) each
  use two sources: a Helm chart from an upstream chart repository, and this
  git repository for the matching values file in that cluster's `values/`.
  ArgoCD calls this a
  [multi-source Application](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/).
- **Raw-manifest Applications** (`argocd`, `argocd-config`,
  `authentik-outpost`, `che-cluster`, `cluster-issuers`, `coredns`,
  `ingress-apps`, `media-bootstrap`, `media-forward-auth`, `metallb-pool`,
  `oidc-rbac`, `secrets` in `dev/`) each use one source: a directory of
  plain Kubernetes manifests under that cluster's `manifests/`.

## Applications (dev)

| Application | Deploys | Namespace | Purpose |
|---|---|---|---|
| `alloy` | Helm chart `alloy` from the Grafana chart repository, values in `dev/values/alloy-values.yaml` | `monitoring` | Per-node log shipper. Alloy runs as a DaemonSet on every node and sends pod logs to Loki. |
| `authentik` | Helm chart `authentik` from the authentik chart repository, values in `dev/values/authentik-values.yaml` | `authentik` | Identity provider (SSO). Serves `auth.lab.pcenicni.dev`. Its values file embeds a declarative [blueprint](https://docs.goauthentik.io/customize/blueprints/) (`authentik-blueprints` ConfigMap) that creates the OAuth2/OIDC provider, application, and RBAC groups for Grafana, ArgoCD, and Headlamp - see [SSO / authentik](#sso--authentik). Depends on `sops-secrets-operator` and `secrets` having synced first. |
| `bazarr` | Helm chart `app-template` from the bjw-s chart repository, values in `dev/values/bazarr-values.yaml` | `media` | Subtitle automation - watches the Sonarr/Radarr libraries and fetches matching subtitles. See [Media stack](#media-stack). |
| `cert-manager` | Helm chart `cert-manager` from the jetstack chart repository, values in `dev/values/cert-manager-values.yaml` | `cert-manager` | Issues and renews TLS certificates. Brought under GitOps at the chart version already running (`cert-manager-v1.21.0`) - see [Applications brought under GitOps](#applications-brought-under-gitops). `cluster-issuers` depends on this. Syncs with `ServerSideApply=true`, same annotation-size reasoning as `kube-prometheus-stack`. |
| `eclipse-che` | Helm chart `eclipse-che` from the Eclipse Che chart repository (che-operator and the CheCluster Custom Resource Definitions (CRDs)) | `eclipse-che` | Installs the Che operator only. The `che-cluster` Application's `CheCluster` custom resource configures the actual instance. Single-source, not the usual two-source shape: this chart's `values.yaml` is empty, and nothing in it is templated, so there is no matching `dev/values/eclipse-che-values.yaml`. Depends on `cert-manager` having synced first, for the chart's own Issuer/Certificate pair for its admission webhook's serving certificate. Syncs with `ServerSideApply=true` - same annotation-size reasoning as `kube-prometheus-stack`. Its CRD is about 22,700 lines. |
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
| `che-cluster` | Raw manifests in `dev/manifests/che-cluster/` | `eclipse-che` | The `CheCluster` v2 custom resource that configures the actual Eclipse Che instance (dashboard at `che.lab.pcenicni.dev`) - see [Eclipse Che](#eclipse-che). Depends on `eclipse-che` (the operator/CRD), `devworkspace-operator` (che-operator's own reconcile hard-fails without it), `authentik`'s blueprint (the "Eclipse Che" OAuth2 provider/application), and `secrets`' `che-oauth-client-secret` SopsSecret having synced first. |
| `cluster-issuers` | Raw manifests in `dev/manifests/cluster-issuers/` | `cert-manager` | cert-manager `ClusterIssuer` resources. The manifests define a Let's Encrypt staging issuer and a Let's Encrypt production issuer, both through a Cloudflare DNS-01 challenge for the `pcenicni.dev` zone. |
| `coredns` | Raw manifests in `dev/manifests/coredns/` | `kube-system` | Patches the `coredns` ConfigMap Talos's own bootstrap installed, so pods resolve five `*.lab.pcenicni.dev` hostnames to Traefik's in-cluster IP directly instead of falling through to public DNS - see [SSO / authentik](#sso--authentik). |
| `devworkspace-operator` | Raw manifest (vendored upstream `combined.yaml`, v0.41.0) in `dev/manifests/devworkspace-operator/` | `devworkspace-controller` | CRDs and controller that che-operator hard-requires at runtime - discovered live during the Eclipse Che rollout when che-operator's manager and its `CheCluster` reconcile both failed with "no matches for kind DevWorkspaceOperatorConfig/DevWorkspaceRouting" without it. The `eclipse-che` Helm chart does not install this itself. Depends on `cert-manager` having synced first (its webhook's Certificate/Issuer). `eclipse-che` and `che-cluster` depend on this having synced first - no sync-wave is set, so che-operator crash-loops/reconcile-fails for a few minutes until this lands, then recovers on its own (same selfHeal-driven convergence as `cluster-issuers`/`authentik-outpost` elsewhere in this table). |
| `ingress-apps` | Raw manifests in `dev/manifests/ingress-apps/` | `default` (each resource sets its own namespace) | `Ingress` resources for ArgoCD, Headlamp, Grafana, and authentik. Each resource routes traffic through Traefik and requests a certificate from the `letsencrypt-prod` cluster issuer. |
| `media-bootstrap` | Raw manifests in `dev/manifests/media-bootstrap/` | `media` | One-shot Job wiring Prowlarr/Sonarr/Radarr/Bazarr together via their REST APIs - see [Media stack](#media-stack)'s "First-time setup" section. Not automated-sync - sync it by hand when needed. |
| `media-forward-auth` | Raw manifests in `dev/manifests/media-forward-auth/` | `media` | Traefik `Middleware` for the media stack's authentik SSO - see [SSO: authentik forward-auth](#sso-authentik-forward-auth-domain-level). Depends on `authentik-outpost` having synced first. |
| `metallb-pool` | Raw manifests in `dev/manifests/metallb-pool/` | `metallb-system` | MetalLB `IPAddressPool` and `L2Advertisement` resources. These resources give MetalLB the address range `192.168.10.240`–`192.168.10.245` to assign to `LoadBalancer` services. |
| `oidc-rbac` | Raw manifests in `dev/manifests/oidc-rbac/` | `default` (all resources are cluster-scoped) | `ClusterRoleBinding` granting Kubernetes RBAC to the cluster-wide `k8s-human-access` OIDC identity space from the Talos `AuthenticationConfiguration` (live on all three control-plane nodes) - see [Cluster-wide OIDC / RBAC](#cluster-wide-oidc--rbac). |
| `secrets` | Raw manifests (SOPS-encrypted) in `dev/manifests/secrets/` | `authentik` (each resource sets its own namespace) | `SopsSecret` resources for authentik, Grafana, ArgoCD's OIDC/database credentials, pi-hole's API password, and Eclipse Che's OAuth2 client secret (`che-oauth-client-secret`, see [Eclipse Che](#eclipse-che)) - see [Secrets management](#secrets-management). Depends on `sops-secrets-operator` having synced first. |

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

## Cluster-wide OIDC / RBAC

`development/talos/patches/cp-{helium,argon,neon}.yaml` defines a Talos
`AuthenticationConfiguration` for this cluster. This configuration is not
live on the cluster yet. It has one JSON Web Token (JWT) authenticator
entry that trusts this cluster's own authentik as the issuer - see the
comments in those patch files, and the "Kubernetes human access" blueprint
entry in `dev/values/authentik-values.yaml`, for the authentik-side
OAuth2Provider/Application config. `oidc-rbac` (raw manifests in
`dev/manifests/oidc-rbac/`) is the RBAC half. Without `oidc-rbac`, a valid
token from that issuer authenticates but grants zero permissions.

- **`k8s-human-access`** - direct human and CLI `kubectl` access (public
  client with Proof Key for Code Exchange (PKCE), kubelogin-style). The
  `sub`/`groups` claims carry no prefix, so the authentik group
  `Kubernetes Admins` becomes the literal Kubernetes group
  `Kubernetes Admins`. This entry binds to `cluster-admin`. This binding
  gives the repo owner no new access. The repo owner already has
  `cluster-admin`-equivalent access today, through the X.509 admin
  kubeconfig (`development/talos/kubeconfig`). This binding is only a
  second front door onto that same access level. Revisit this binding if
  `Kubernetes Admins` ever gains a member who is not the repo owner.

A second entry, `che` (Eclipse Che's dashboard OIDC login), also exists
here. This repository briefly removed it, on the mistaken conclusion
(from reading only `pkg/deploy/gateway/gateway.go`) that che-operator
never forwards a user's own OIDC token to the Kubernetes API server on
plain Kubernetes. That conclusion was wrong, discovered live the first
time a real login actually reached this code path: che-dashboard's own
backend (`packages/dashboard-backend/src/routes/api/helpers/getToken.ts`,
used by every route via
`kubeConfigProvider.getKubeConfig(getToken(request))`) builds its
Kubernetes API client straight from the browser's forwarded Authorization
bearer header, on every platform - the `gateway.go` finding was about a
narrower, unrelated OpenShift-specific check inside the gateway itself,
not about the dashboard's own token handling. Removing the `che` entry
left `che-dashboard` presenting a token the apiserver had no way to
trust, producing a real `401 Unauthorized` ("Unable to list
devworkspaces"). The entry's `claimMappings` intentionally differ from
`k8s-human-access`: `username` maps the `name` claim (not `sub`), with no
prefix, because che-operator itself provisions per-user RBAC for a
Kubernetes `User` matching that exact claim unprefixed - confirmed live
by inspecting the `RoleBinding` che-operator had already created, bound
to `User "authentik Default Admin"` (Authentik's `name` field for the
`akadmin` account, not `sub`/`preferred_username`/email). The two
identity spaces still stay separated - not by username shape, but by
OIDC audience: a `che`-issued token's audience never matches
`k8s-human-access`'s expected audience, so it can never be used for that
tighter path regardless of claim mapping. No `oidc-rbac` ClusterRole/
ClusterRoleBinding exists for `che` identities - che-operator provisions
namespace-scoped RoleBindings itself per user, through `CheCluster`'s
`devEnvironments.user.clusterRoles` - see [Eclipse Che](#eclipse-che).

Both `jwt[]` entries' OIDC discovery depends on `kube-apiserver` being
able to reach `auth.lab.pcenicni.dev` with a certificate it actually
trusts - not automatic on this cluster, and worth understanding since it
failed live twice for two different reasons before working:

- `kube-apiserver`'s static pod runs `hostNetwork: true`, so it uses this
  Talos node's own DNS resolver, not the cluster's pi-hole split-horizon
  DNS that pod-network components get through the `coredns` Application.
  That resolver answers `auth.lab.pcenicni.dev` with a public IP, not
  Traefik's in-cluster LoadBalancer IP (`192.168.10.240`). Each
  control-plane patch carries a `StaticHostConfig` document mapping that
  hostname straight to the LoadBalancer IP, bypassing the resolver
  entirely for just this one name.
- That alone was not enough: `StaticHostConfig` only edits the Talos
  **host's** own `/etc/hosts`, and `hostNetwork: true` only shares the
  network namespace, not the filesystem - `kube-apiserver`'s own
  container still has its own separate, kubelet/containerd-generated
  `/etc/hosts` that never inherits the host's. Each patch also bind-mounts
  the host's real `/etc/hosts` straight over the container's own, through
  `cluster.apiServer.extraVolumes` (the same mechanism the
  `AuthenticationConfiguration` file itself uses) - confirmed there is no
  `hostAliases` field or equivalent in Talos's own generated static pod
  manifest to hook into instead.

Group *membership* for `Kubernetes Admins` works the same way as every
other authentik group in this document - see [Granting app access to
other users](#granting-app-access-to-other-users).

## Eclipse Che

Two Applications, split the same way as cert-manager and
cluster-issuers - one Application for the operator, one for the custom
resource:

- **`eclipse-che`** - the che-operator chart (Custom Resource Definitions
  (CRDs) and the controller only). Single-source, not the usual
  two-source Helm-chart shape: this chart's `values.yaml` is empty, and
  nothing in it is templated - see that Application's own comment for
  details. Depends on `cert-manager` having synced first. The chart's own
  `che-operator-selfsigned-issuer`/`che-operator-serving-cert` pair (an
  `Issuer` and a `Certificate` for the operator's own admission and
  conversion webhook) needs cert-manager's CRDs and controller to already
  exist.
- **`che-cluster`** - the `CheCluster` v2 custom resource
  (`dev/manifests/che-cluster/checluster.yaml`) that configures the Che
  instance, at `che.lab.pcenicni.dev`. Depends on `eclipse-che` having
  synced first, for the `CheCluster` CRD itself. It also depends on
  `authentik`'s blueprint (the "Eclipse Che" OAuth2 provider/application -
  see [SSO / authentik](#sso--authentik)) and on `secrets`'
  `che-oauth-client-secret` SopsSecret having synced first, for the OIDC
  config below to work.

Sized for this cluster's 6GiB-per-node capacity, rather than upstream's
stock example values:

- `components.cheServer`/`components.dashboard` pin explicit, conservative
  resource requests and limits, instead of the operator's own defaults
  (see `checluster.yaml`'s comments for the exact numbers and where they
  came from). `components.pluginRegistry.openVSXURL` and
  `components.devfileRegistry.disableInternalRegistry` point at the public
  upstream registries. This setup replaces an embedded OpenVSX registry, a
  Postgres database, and an internal devfile-registry pod - upstream's own
  recommended lightweight config, and a meaningful resource saving here.
- `devEnvironments.defaultContainerResources` and `.containerResourceCaps`
  bind every *workspace* container (not the platform components above) to
  a 512Mi/200m request and a 2Gi/1cpu limit. This is much lower than the
  512Mi-request/6Gi-limit range some upstream examples use. Adjust these
  values once a real workspace has run and its true resource footprint is
  known.
- `devEnvironments.storage.perUserStrategyPvcConfig.storageClass` sets
  `local-path` explicitly. `local-path` is this cluster's only
  StorageClass.
- `devEnvironments.user.clusterRoles` grants `che-user-workspace-edit` to
  each Che-provisioned user's own per-user-namespace `ServiceAccount`.
  `che-user-workspace-edit` is a `ClusterRole` defined as a second
  document in `checluster.yaml`. It aggregates the built-in `edit`
  ClusterRole's rule set, through the standard
  `rbac.authorization.k8s.io/aggregate-to-edit: "true"` selector.
  che-operator creates the binding automatically, as a namespace-scoped
  `RoleBinding` - not `cluster-admin` or `admin`. A workspace terminal
  that runs arbitrary devfile-supplied tooling does not need
  cluster-scoped or RBAC-escalation permissions to manage ordinary
  objects in its own namespace. See [Cluster-wide OIDC /
  RBAC](#cluster-wide-oidc--rbac) above, and the "Per-user delegation
  model" note below, for why this replaced the apiserver-OIDC approach
  staged there originally.

**Networking**: che-operator creates its **own** `Ingress` objects,
derived from `spec.networking.domain`, `hostname`, `annotations`, and
`ingressClassName`. This differs from every other app in this repository,
which gets a hand-written `Ingress` in `ingress-apps.yaml`. che-operator's
own `pkg/deploy/ingress.go` confirms this behavior directly; the CRD field
names alone do not confirm it. So `ingress-apps.yaml` has no
`che-cluster` entry. Instead, `checluster.yaml` sets
`ingressClassName: traefik` and
`cert-manager.io/cluster-issuer: letsencrypt-prod` directly. This gives
the same result the hand-written Ingresses in `ingress-apps.yaml` get.
A pi-hole wildcard DNS entry covers whatever hostname che-operator's
Ingress ends up using, including per-workspace subdomains, with no
per-host config at all - see [DNS / external-dns](#dns--external-dns)
below. `coredns` now has a fifth `che.lab.pcenicni.dev` entry, for the
same in-cluster-callback reason as the other four - see that
Application's manifest.

Per-workspace endpoints get their own subdomain under
`spec.networking.domain` (for example,
`<user>-<workspace>-<endpoint>.che.lab.pcenicni.dev`). This cluster has no
wildcard certificate for that subdomain pattern. `checluster.yaml` enables
`devEnvironments.networking.externalTLSConfig`, with the same
`cert-manager.io/cluster-issuer` annotation. So cert-manager issues a real
per-workspace certificate through the DNS-01 challenge instead. Expect a
delay of roughly one to five minutes before a new workspace's endpoints
are reachable over TLS for the first time. Watch Let's Encrypt's rate
limits if users create many workspaces in a short time window. A wildcard
certificate for `*.che.lab.pcenicni.dev` removes this kind of delay. This
repository does not add one now, to avoid introducing that machinery
speculatively. Revisit this decision if the delay becomes a problem in
practice.

**Still needs a real value from a human before login works**:
`spec.networking.auth.oAuthClientName` in `checluster.yaml` is an empty
placeholder. The CheCluster v2 CRD has no secret-reference mechanism for
this field (unlike `oAuthSecret`, which has one). So this field must hold
the literal OIDC client_id string, the same way `argocd-config.yaml`'s
`clientID` and `kube-prometheus-stack-values.yaml`'s `client_id` are
literal. Enter the same value here as `CHE_OAUTH_CLIENT_ID` in
`dev/manifests/secrets/authentik-oauth-clients.yaml`. Separately, enter
the matching `CHE_OAUTH_CLIENT_SECRET` value in
`dev/manifests/secrets/che-oauth-client-secret.yaml`, and run
`sops --encrypt --in-place` on that file. See that file's own header for
the exact steps.

**Per-user delegation model** (this note resolves the open cross-reference
flagged earlier in this section): che-dashboard's backend genuinely does
forward a logged-in user's own OIDC token straight to the Kubernetes API
server for per-request calls (confirmed from its actual source, not
assumed - see [Cluster-wide OIDC / RBAC](#cluster-wide-oidc--rbac) above
for the full story, including the wrong conclusion this repository
briefly drew from a narrower, unrelated check in
`pkg/deploy/gateway/gateway.go`). The `che` `AuthenticationConfiguration`
`jwt[]` entry on all three control-plane nodes exists specifically so the
apiserver trusts those forwarded tokens.

That per-request token use is layered on top of a separate delegation
chain che-operator also runs, per its own ["Configuring cluster roles for
users"](https://eclipse.dev/che/docs/stable/secure/configuring-cluster-roles-for-users/)
documentation, for provisioning: che-operator and che-server run as one
shared privileged service account. `components.cheServer.clusterRoles`
grants this service account the built-in `edit` ClusterRole directly - not
left unset, despite an earlier comment here claiming che-operator's own
defaults were sufficient. That assumption was wrong too, discovered on
the very first real per-user namespace provisioning attempt: Kubernetes'
own RBAC escalation-prevention rule blocked `che` from creating the
`che-user-workspace-edit` RoleBinding below it without holding `edit`
directly, and then blocked `che-operator` itself from granting `che`
that role, for the same reason one level up - fixed with a narrowly
scoped `bind` verb ClusterRole/ClusterRoleBinding for `che-operator` on
just the `edit` ClusterRole (RBAC's own documented mechanism for an
operator granting a role broader than what it holds - see
`checluster.yaml`'s comments for both fixes). This service account
provisions a per-user
namespace and a per-user `ServiceAccount`, with RBAC bound through
`devEnvironments.user.clusterRoles` (see the sizing list above). This
model does not rely on apiserver-level OIDC trust of the user's own
token. authentik's "Eclipse Che" OAuth2Provider is unaffected by any of
this. It only ever authenticates the Che *dashboard* login, a normal
`authorization_code` browser flow to `/api/oauth/callback`, which
che-server itself validates. This provider is never a source of
apiserver-trusted tokens, and nothing in its blueprint config
(`dev/values/authentik-values.yaml`) assumes otherwise.

## DNS / external-dns

`coredns` (above) makes hostnames resolve correctly *from inside* the
cluster. LAN clients (a browser, `curl`, another machine) get the other
direction - a working record for `*.lab.pcenicni.dev` - from a wildcard
DNS entry on pi-hole (`192.168.1.127`), not from this repo:
`misc.dnsmasq_lines` on that pi-hole carries
`address=/.lab.pcenicni.dev/192.168.10.240` (Traefik's in-cluster
LoadBalancer IP), added directly through pi-hole's own v6 REST API. This
matches at any subdomain depth (dnsmasq's `address=/domain/ip` is a
suffix match, not the single-label match a standard DNS `*.domain`
wildcard would give), which is what lets Eclipse Che's dynamic
per-workspace hostnames (`<workspace>.che.lab.pcenicni.dev`, and
deeper) resolve with no extra automation at all - see [Eclipse
Che](#eclipse-che).

Every other `lab.pcenicni.dev` name already in pi-hole's plain "Local DNS
Records" list (the rest of the home lab - NAS, other VMs, the separate
`noble` cluster, non-Kubernetes services) still resolves to its own
explicit IP, unaffected: dnsmasq always prefers an exact record over a
wildcard match, confirmed live before relying on it. The real tradeoff,
accepted deliberately: a typo'd or not-yet-registered
`*.lab.pcenicni.dev` host now silently resolves to this dev cluster's
Traefik instead of failing with a clean NXDOMAIN.

**`external-dns` (the Helm-chart Application that used to automate the
per-Ingress-host side of this) has been removed, temporarily.** It
watched every Ingress cluster-wide and wrote a matching individual
record to pi-hole's `hosts` list for each one - fully superseded now by
the wildcard above for anything reachable only on the LAN. The plan
going forward is a split between internal-only apps (covered by the
wildcard, same as today) and a small set of externally-exposed apps
(starting with authentik, meant to be reachable from outside the LAN
under `auth.pcenicni.dev` and, with dual tenancy, `auth.nikflix.ca`) -
`external-dns` (or an equivalent) is expected to come back scoped to
just that second, smaller set once that work is actually planned out.
Until then, nothing in this repo manages individual pi-hole records -
the wildcard is the whole story. The removed Application's old
`policy: upsert-only`/`registry: noop` reasoning (this pi-hole has many
hand-managed entries with no per-record ownership tracking to safely
diff against) still applies whenever it comes back.

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
