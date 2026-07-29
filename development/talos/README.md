# Talos machine configs - development cluster

This directory holds the Talos machine config for the six VMs that
[../terraform](../terraform) provisions on the `helium`, `neon`, and
`argon` Proxmox nodes. It also holds the cluster secrets that `talosctl`
and `kubectl` need to reach the cluster. Terraform creates the VM shells
only. You must apply the machine config in this directory afterward, by
hand, with `talosctl`.

## Files in this directory

| File | Purpose | Committed to git? |
|---|---|---|
| `controlplane.yaml` | Base machine config for control plane VMs. Contains the cluster Certificate Authority (CA) certificate and key, and the join token. | No (secret) |
| `worker.yaml` | Base machine config for worker VMs. Contains the same cluster CA and join token as `controlplane.yaml`. | No (secret) |
| `patches/*.yaml` | Small per-VM overlays applied on top of a base config. No secrets. | Yes |
| `talosconfig` | Client config for `talosctl`. Contains the cluster endpoint and client certificate for the Talos Application Programming Interface (API). | No (secret) |
| `kubeconfig` | Client config for `kubectl`. You generate this file after the cluster is up. | No (secret) |

## Base config and per-node patches

`controlplane.yaml` and `worker.yaml` are full Talos machine configs, one
per role. You generate both files with `talosctl gen config`. Both share
the same cluster CA, join token, control plane endpoint
(`https://192.168.10.160:6443`), and cluster name (`dev-noble`). Neither
file is specific to one VM.

Each file in `patches/` is a small YAML overlay for one VM. You apply a
patch together with the matching base config at `talosctl apply-config`
time. A patch does not change the base file on disk. Every patch in this
directory overrides two fields:

- `machine.install.image` - pins the Talos installer image to a specific
  version, for example `ghcr.io/siderolabs/installer:v1.13.7`. The base
  config's own default install image is an older version. Every VM needs
  this override to install the intended Talos version.
- `hostname` (under a `HostnameConfig` document, with `auto: "off"`) -
  sets a static hostname for the VM, for example `talos-dev-cp-helium`.

NOTE: The patches in this directory do not set a static IP address or a
disk selector. The base config's default install disk (`/dev/sda`) applies
to every VM unchanged. The management IP addresses in
`terraform output talos_vms` (the `192.168.10.121`-`192.168.10.126` range)
show the intended address for each VM only. Check the actual network
config before you rely on a specific IP address for a node.

## Patch file names

Each patch file name follows `cp-<node>.yaml` for a control plane VM or
`worker-<node>.yaml` for a worker VM, where `<node>` is the Proxmox node
that hosts the VM: `helium`, `neon`, or `argon`. This matches the VM names
in [../terraform/locals.tf](../terraform/locals.tf).

| Patch file | Base config to pair with it | Proxmox node | Role |
|---|---|---|---|
| `patches/cp-helium.yaml` | `controlplane.yaml` | helium | controlplane |
| `patches/worker-helium.yaml` | `worker.yaml` | helium | worker |
| `patches/cp-neon.yaml` | `controlplane.yaml` | neon | controlplane |
| `patches/worker-neon.yaml` | `worker.yaml` | neon | worker |
| `patches/cp-argon.yaml` | `controlplane.yaml` | argon | controlplane |
| `patches/worker-argon.yaml` | `worker.yaml` | argon | worker |

## Secrets: never commit the base configs or client configs

`controlplane.yaml`, `worker.yaml`, `talosconfig`, and `kubeconfig` all
contain credentials that grant control over the cluster. The repository's
[development/.gitignore](../.gitignore) already excludes all four files
(as `talos/controlplane.yaml`, `talos/worker.yaml`, `talos/talosconfig`,
and `talos/kubeconfig`). The `.gitignore` file does not list the
`patches/` directory, because it holds no secrets.

CAUTION: Do not remove these entries from `.gitignore`. Do not commit
`controlplane.yaml`, `worker.yaml`, `talosconfig`, or `kubeconfig` under a
different file name, either.

## Procedure: generate and apply a machine config

NOTE: This procedure follows the general `talosctl` command pattern to
generate and apply a machine config. Check the exact flags against the
`talosctl` version installed on your machine before you run these
commands.

1. In `../terraform`, run `terraform output talos_vms` to list each VM's
   node, VM ID, role, and planned management IP address.
2. If `controlplane.yaml`, `worker.yaml`, and `talosconfig` do not already
   exist in this directory, generate them:
   `talosctl gen config dev-noble https://192.168.10.160:6443 --output-dir .`
3. For each control plane VM, apply the base config with its matching
   patch: `talosctl apply-config --insecure -n <management-ip> -f controlplane.yaml --config-patch @patches/cp-<node>.yaml`.
4. For each worker VM, apply the base config with its matching patch:
   `talosctl apply-config --insecure -n <management-ip> -f worker.yaml --config-patch @patches/worker-<node>.yaml`.
5. Bootstrap the cluster on one control plane VM only:
   `talosctl bootstrap -n <one-controlplane-management-ip> -e <control-plane-endpoint> --talosconfig talosconfig`.
6. Retrieve the admin kubeconfig:
   `talosctl kubeconfig -n <any-controlplane-management-ip> -e <control-plane-endpoint> --talosconfig talosconfig ./kubeconfig`.

CAUTION: Step 3 and step 4 use `--insecure` because a freshly booted Talos
VM has no client certificate yet. Do not use `--insecure` against a node
that already runs a full machine config, unless you accept the security
risk.

NOTE: Run step 5 exactly once, against a single control plane VM. If you
run `talosctl bootstrap` against more than one node, you can corrupt the
cluster's `etcd` store.

Once `kubeconfig` exists in this directory, use it with `kubectl` or point
ArgoCD's bootstrap step at it — see
[../../argocd/README.md](../../argocd/README.md) for the next stage.
