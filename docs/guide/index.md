# Build the lab

This guide builds the development cluster from bare hardware. Do the
steps in order. Each step needs the previous step to be complete.

| Step | Result | Approx. time |
|---|---|---|
| [0. Prerequisites](prerequisites.md) | Hardware, accounts, and tools ready | - |
| [1. Network](network.md) | VLANs 10, 80, and 100 live on the correct switch ports | 30 min |
| [2. Proxmox nodes](proxmox.md) | Hardened, quorate `noble` Proxmox cluster | 1 h |
| [3. Talos VMs](vms.md) | Six empty Talos VMs booted from ISO | 15 min |
| [4. Talos and Kubernetes](talos.md) | Running Kubernetes cluster and a `kubeconfig` | 30 min |
| [5. GitOps and secrets](gitops.md) | ArgoCD syncs every Application from git | 30 min + sync |
| [6. Applications](apps.md) | SSO, ingress, and apps configured | 1 h+ |

!!! tip "Recovering, not building?"
    Read [Disaster recovery](../disaster-recovery.md) first. It tells you
    which steps you can skip and which saved files to restore at each step.
