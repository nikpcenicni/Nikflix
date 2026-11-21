# Tutorials

<p class="lead">Step-by-step guides. Start with <b>Build the lab</b> if you
are setting up from nothing. Use <b>Everyday tasks</b> once the cluster
runs.</p>

## Build the lab

A seven-part series that takes you from bare hardware to a running
cluster with every app. Do the parts in order.

<div class="grid cards" markdown>

-   :material-clipboard-check-outline: **[0. Prerequisites](build/prerequisites.md)**

    Hardware, accounts, tools, and the secrets you will create.

-   :material-lan-connect: **[1. Network](build/network.md)**

    VLANs, native ports, and the DNS wildcard.

-   :material-server-network: **[2. Proxmox nodes](build/proxmox.md)**

    Install Proxmox and run the Ansible bootstrap.

-   :material-terraform: **[3. Talos VMs](build/vms.md)**

    API token and `terraform apply`.

-   :material-kubernetes: **[4. Talos and Kubernetes](build/talos.md)**

    Machine configs, bootstrap, kubeconfig.

-   :material-source-branch-sync: **[5. GitOps and secrets](build/gitops.md)**

    Bootstrap secrets, ArgoCD, root Applications.

-   :material-apps: **[6. Applications](build/apps.md)**

    authentik, the media stack, and Homepage.

</div>

## Everyday tasks

| Tutorial | You will learn to | Time |
|---|---|---|
| [Add an app](add-an-app.md) | Deploy a new web app with ingress, TLS, SSO, NetworkPolicy, and a Homepage tile | 30 min |
| [Manage secrets](secrets.md) | Create, edit, and rotate SOPS-encrypted secrets | 10 min |
| [Add a Proxmox node](add-a-node.md) | Cable, bootstrap, and join a new node to `noble` | 1 h |
| [Upgrade Talos](upgrade-talos.md) | Upgrade Talos and Kubernetes one node at a time | 30 min |
