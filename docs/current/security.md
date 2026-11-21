# Security

<p class="lead">The controls at each layer, from host hardening to cluster
policy.</p>

<div class="grid cards" markdown>

-   :material-server-security:{ .lg .middle } **Hosts**

    ---

    Ansible `harden.yml`: SSH key-only login, `fail2ban`, `auditd`, sysctl
    hardening, and unattended security upgrades on every Proxmox node.

-   :material-key-chain:{ .lg .middle } **Secrets**

    ---

    SOPS + age. Only the `data`/`stringData` fields are encrypted, so
    diffs stay readable. The age key is never in git.

-   :material-account-lock:{ .lg .middle } **Identity**

    ---

    authentik SSO for every UI. Group-based roles for ArgoCD, Grafana,
    and Kubernetes RBAC through OIDC.

-   :material-police-badge-outline:{ .lg .middle } **Policy**

    ---

    Kyverno admission policies and default-deny NetworkPolicies per
    namespace.

</div>

## Kyverno policies

| Policy | Mode | Effect |
|---|---|---|
| `disallow-privileged` | <span class="pill ok">Enforce</span> | Blocks privileged containers |
| `require-approved-registries` | <span class="pill wip">Audit</span> | Reports images from registries not on the allow list |
| `require-resource-limits` | <span class="pill wip">Audit</span> | Reports containers without a memory limit |

Policies are in `argocd/dev/manifests/kyverno-policies/`.

## Network policies

Each app namespace starts with `default-deny-all`. It then allows only:

- DNS to `kube-system`,
- ingress from Traefik (and from Prometheus, where the app has metrics),
- the egress the app actually needs (for example, the media namespace
  may reach the internet and the NAS for NFS).

Policies are in `argocd/dev/manifests/network-policies/`.

!!! warning "Not enforced yet"
    Flannel does not enforce NetworkPolicy. The policies are in place so
    they take effect when the [Cilium migration](../future/index.md) is
    done.

## Who can log in where

| Surface | How |
|---|---|
| Proxmox SSH | Key only (`~/.ssh/id_ed25519_proxmox`), fail2ban |
| Proxmox GUI/API | Proxmox users; Terraform and the exporter use scoped tokens |
| Talos API | mTLS with `talosconfig` |
| Kubernetes API | Admin `kubeconfig`, or authentik OIDC |
| Web apps | authentik (OIDC or forward-auth). OpenGym uses passkeys |

## CI checks on every PR

| Check | Tool |
|---|---|
| Verified secrets in git history | TruffleHog |
| Kubernetes misconfiguration | Trivy (report only) |
| Docs site builds with no broken links | MkDocs `--strict` |
