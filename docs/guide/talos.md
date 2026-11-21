# 4. Talos and Kubernetes

This step turns the six VMs into the `dev-noble` Kubernetes cluster. The
full reference is
[`development/talos/README.md`](https://github.com/nikpcenicni/Nikflix/blob/main/development/talos/README.md).

| Setting | Value |
|---|---|
| Cluster name | `dev-noble` |
| API endpoint | `https://192.168.10.160:6443` |
| Talos version | `v1.13.7` (installer image pinned in every patch) |
| CNI | Flannel (Talos default) today. A Cilium Application exists but is a manual-sync migration, not done yet |

!!! warning "The `192.168.10.160` endpoint"
    The patches in git do not define `192.168.10.160`. It must reach a
    control-plane node before `kubectl` works. The usual Talos method is
    a shared VIP in the control-plane config, for example a patch with
    `machine.network.interfaces[].vip.ip: 192.168.10.160`. Check how your
    saved `controlplane.yaml` sets it, and keep that file with your
    secrets.

## Procedure

All commands run from `development/talos/`.

1. **Generate secrets and base configs** (skip this in a recovery - restore
   your saved files instead):

    ```sh
    talosctl gen config dev-noble https://192.168.10.160:6443 --output-dir .
    ```

    This writes `controlplane.yaml`, `worker.yaml`, and `talosconfig`.
    They are git-ignored. **Save all three in your password manager now.**

2. **Find each VM's current IP** from its Proxmox console (maintenance
   mode shows it).

3. **Apply configs.** For each control-plane VM:

    ```sh
    talosctl apply-config --insecure -n <vm-ip> \
      -f controlplane.yaml --config-patch @patches/cp-<node>.yaml
    ```

    For each worker VM:

    ```sh
    talosctl apply-config --insecure -n <vm-ip> \
      -f worker.yaml --config-patch @patches/worker-<node>.yaml
    ```

4. **Bootstrap etcd, once, on one control-plane node only:**

    ```sh
    talosctl --talosconfig talosconfig bootstrap -n 192.168.10.121 -e 192.168.10.121
    ```

5. **Get the kubeconfig:**

    ```sh
    talosctl --talosconfig talosconfig kubeconfig ./kubeconfig -n 192.168.10.121 -e 192.168.10.121
    export KUBECONFIG=$PWD/kubeconfig
    ```

!!! danger
    Run `talosctl bootstrap` against exactly one node, exactly once.
    Running it again or on a second node can corrupt etcd.

## Check

```sh
kubectl get nodes -o wide
```

All six nodes are listed and `Ready` (Flannel starts with the cluster).

!!! note "Change for your lab"
    The control-plane patches (`patches/cp-*.yaml`) contain the OIDC
    issuer URLs (`auth.lab.pcenicni.dev`), client IDs, and a static host
    entry pointing at `192.168.10.240`. Update all three patches for your
    domain and authentik client IDs, or remove the
    `AuthenticationConfiguration` until authentik is running.
