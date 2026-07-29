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
│   │   ├── sops-secrets-operator.yaml
│   │   ├── argocd-config.yaml
│   │   ├── cluster-issuers.yaml
│   │   ├── ingress-apps.yaml
│   │   ├── metallb-pool.yaml
│   │   └── secrets.yaml
│   ├── values/
│   │   ├── alloy-values.yaml
│   │   ├── authentik-values.yaml
│   │   ├── kube-prometheus-stack-values.yaml
│   │   ├── loki-values.yaml
│   │   └── sops-secrets-operator-values.yaml
│   └── manifests/
│       ├── argocd-config/
│       ├── cluster-issuers/
│       ├── ingress-apps/
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

- **Helm-chart Applications** (`alloy`, `authentik`, `kube-prometheus-stack`,
  `loki`, `sops-secrets-operator` in `dev/`) each use two sources: a Helm
  chart from an upstream chart repository, and this git repository for the
  matching values file in that cluster's `values/`. ArgoCD calls this a
  [multi-source Application](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/).
- **Raw-manifest Applications** (`argocd-config`, `cluster-issuers`,
  `ingress-apps`, `metallb-pool`, `secrets` in `dev/`) each use one source: a
  directory of plain Kubernetes manifests under that cluster's `manifests/`.

## Applications (dev)

| Application | Deploys | Namespace | Purpose |
|---|---|---|---|
| `alloy` | Helm chart `alloy` from the Grafana chart repository, values in `dev/values/alloy-values.yaml` | `monitoring` | Per-node log shipper. Alloy runs as a DaemonSet on every node and sends pod logs to Loki. |
| `authentik` | Helm chart `authentik` from the authentik chart repository, values in `dev/values/authentik-values.yaml` | `authentik` | Identity provider (SSO). Serves `auth.lab.pcenicni.dev`. Its values file embeds a declarative [blueprint](https://docs.goauthentik.io/customize/blueprints/) (`authentik-blueprints` ConfigMap) that creates the OAuth2/OIDC provider, application, and RBAC groups for Grafana, ArgoCD, and Headlamp - see [SSO / authentik](#sso--authentik). Depends on `sops-secrets-operator` and `secrets` having synced first. |
| `kube-prometheus-stack` | Helm chart `kube-prometheus-stack` from the Prometheus Community chart repository, values in `dev/values/kube-prometheus-stack-values.yaml` | `monitoring` | Metrics and dashboards. The chart installs Prometheus and Grafana. The dev cluster's values file disables Alertmanager and configures Grafana's `auth.generic_oauth` against authentik, mapping the `Grafana Admins`/`Grafana Editors`/`Grafana Viewers` authentik groups to Grafana's Admin/Editor/Viewer org roles. |
| `loki` | Helm chart `loki` from the Grafana chart repository, values in `dev/values/loki-values.yaml` | `monitoring` | Log storage. Loki stores the logs that Alloy sends to it. The dev cluster's values file sets single-binary mode with filesystem storage. |
| `sops-secrets-operator` | Helm chart `sops-secrets-operator` from the isindir chart repository, values in `dev/values/sops-secrets-operator-values.yaml` | `sops` | Watches `SopsSecret` custom resources cluster-wide and decrypts them into real Kubernetes Secrets - see [Secrets management](#secrets-management). |
| `argocd-config` | Raw manifests in `dev/manifests/argocd-config/` | `argocd` | Patches the `argocd-cm` and `argocd-rbac-cm` ConfigMaps that ArgoCD's own (by-hand) install created. Wires up OIDC login against authentik and maps the `ArgoCD Admins`/`ArgoCD Viewers` authentik groups to ArgoCD's built-in `admin`/`readonly` roles. |
| `cluster-issuers` | Raw manifests in `dev/manifests/cluster-issuers/` | `cert-manager` | cert-manager `ClusterIssuer` resources. The manifests define a Let's Encrypt staging issuer and a Let's Encrypt production issuer, both through a Cloudflare DNS-01 challenge for the `pcenicni.dev` zone. |
| `ingress-apps` | Raw manifests in `dev/manifests/ingress-apps/` | `default` (each resource sets its own namespace) | `Ingress` resources for ArgoCD, Headlamp, Grafana, and authentik. Each resource routes traffic through Traefik and requests a certificate from the `letsencrypt-prod` cluster issuer. |
| `metallb-pool` | Raw manifests in `dev/manifests/metallb-pool/` | `metallb-system` | MetalLB `IPAddressPool` and `L2Advertisement` resources. These resources give MetalLB the address range `192.168.10.240`–`192.168.10.245` to assign to `LoadBalancer` services. |
| `secrets` | Raw manifests (SOPS-encrypted) in `dev/manifests/secrets/` | `authentik` (each resource sets its own namespace) | `SopsSecret` resources for authentik, Grafana, and ArgoCD's OIDC/database credentials - see [Secrets management](#secrets-management). Depends on `sops-secrets-operator` having synced first. |

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
changes needed.

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

NOTE: `dev/values/kube-prometheus-stack-values.yaml` sets
`grafana.adminPassword` to the placeholder value
`dev-admin-changeme`. Replace this value with a real secret before
you use this configuration outside development.

NOTE: `authentik`, `secrets`, and `argocd-config` need the
`sops-secrets-operator` Application synced first, and that operator needs
the `sops-age-key` Secret bootstrapped by hand - see [Secrets
management](#secrets-management)'s "Bootstrapping" steps. Until that Secret
exists, `sops-secrets-operator`'s pod runs fine but every `SopsSecret`
fails to decrypt, and authentik's pods sit in `ContainerCreating` waiting on
Secrets that never appear.

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
was installed by hand and is not yet tracked as an Application itself
— except ArgoCD's `argocd-cm`/`argocd-rbac-cm` ConfigMaps, which
`argocd-config` now patches (see [SSO / authentik](#sso--authentik));
the rest of the ArgoCD install is still untracked. Bring each one
under GitOps the same way as the Applications above, with a chart and
a values file, or with raw manifests, once you know its currently
installed chart version.
