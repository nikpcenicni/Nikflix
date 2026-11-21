# Upgrade Talos

<p class="lead">Upgrade Talos, then Kubernetes, one node at a time, with no
downtime for the cluster.</p>

**You need:** `talosctl` at the **new** version, `development/talos/talosconfig`,
and a recent etcd backup.

!!! warning "Read the release notes first"
    Check the [Talos releases](https://github.com/siderolabs/talos/releases)
    for upgrade-path limits. Do not skip minor versions.

## 1. Take an etcd snapshot

```sh
cd development/talos
talosctl --talosconfig talosconfig -n 192.168.10.121 etcd snapshot ./etcd-$(date +%F).db
```

Store the snapshot outside the lab.

## 2. Upgrade each node

Do the control plane first, one at a time, then the workers. Wait for
each node to come back `Ready` before you start the next one.

```sh
NEW=v1.13.8   # example
for ip in 192.168.10.121 192.168.10.123 192.168.10.125 \
          192.168.10.122 192.168.10.124 192.168.10.126; do
  talosctl --talosconfig talosconfig -n "$ip" upgrade \
    --image ghcr.io/siderolabs/installer:$NEW --wait
  kubectl wait --for=condition=Ready node --all --timeout=10m
done
```

| VM | IP |
|---|---|
| cp-helium, cp-neon, cp-argon | `.121`, `.123`, `.125` |
| worker-helium, worker-neon, worker-argon | `.122`, `.124`, `.126` |

## 3. Update git

Set the new installer image in every patch, so a rebuilt node installs
the same version:

```sh
sed -i '' "s#installer:v[0-9.]*#installer:$NEW#" development/talos/patches/*.yaml
```

Also set `talos_version` in `development/terraform/variables.tf` (used for
the boot ISO). Commit both changes.

## 4. Upgrade Kubernetes (optional)

```sh
talosctl --talosconfig talosconfig -n 192.168.10.121 upgrade-k8s --to <k8s-version>
```

This updates the control-plane components and kubelets on every node.

## Check

```sh
talosctl --talosconfig talosconfig -n 192.168.10.121 version
kubectl get nodes -o wide
kubectl -n argocd get applications
```

Every node shows the new version and all Applications are healthy.
