# Disaster recovery

This page tells you how to rebuild the lab after a failure. Git holds
everything that is declarative. **Git does not hold the secrets or the
application data.** A recovery is only as good as the items in the
first table below.

## What you must have before a disaster

Keep these in a password manager or other store **outside the lab**. Do
not keep the only copy on a Proxmox node, a VM, or the NAS that the lab
uses.

| Item | Where it lives normally | Without it |
|---|---|---|
| `age-key.txt` (SOPS private key) | `sops/sops-age-key` Secret, your workstation | **Every** file in `argocd/dev/manifests/secrets/` is unreadable. You must create every secret again from the source services |
| `development/talos/controlplane.yaml`, `worker.yaml`, `talosconfig` | Workstation (git-ignored) | You cannot manage the existing Talos nodes. A full cluster rebuild with new certificates is required |
| `development/talos/kubeconfig` | Workstation (git-ignored) | Re-create it with `talosctl kubeconfig` if you still have `talosconfig` |
| `~/.ssh/id_ed25519_proxmox` | Workstation | Password SSH is disabled. Use the Proxmox console to add a new key |
| Proxmox root passwords | Password manager | Console recovery needs single-user boot |
| Proxmox API token (`terraform@pve`) | Password manager | Create a new one (low impact) |
| `development/terraform/terraform.tfstate` | Workstation (git-ignored) | See [Terraform state is lost](#terraform-state-is-lost) |
| Cloudflare API token | Password manager | Create a new one in Cloudflare (low impact) |
| authentik `akadmin` password | Password manager | Reset with `ak create_recovery_key` in the authentik worker pod |
| NAS data (media library) | NAS | Not recoverable from this repository |

!!! danger "Application data is not backed up by this repository"
    Every app (authentik's PostgreSQL, the *arr databases, Vikunja,
    Spoolman, Grafana, and others) stores its data on `local-path`
    volumes **inside the Talos VM disk** on the node that runs the pod.
    If you lose a VM disk, you lose that data. Longhorn and its S3
    backups are planned but not built. Until then, back up the
    important apps' own exports (for example Sonarr/Radarr
    *System → Backup*, Spoolman's nightly backup file) to the NAS.

## Pick your scenario

| What failed | Go to |
|---|---|
| One Talos VM | [A. Replace one Talos VM](#a-replace-one-talos-vm) |
| One Proxmox node (hardware) | [B. Replace one Proxmox node](#b-replace-one-proxmox-node) |
| The Kubernetes cluster (etcd lost, all VMs gone) | [C. Rebuild the Kubernetes cluster](#c-rebuild-the-kubernetes-cluster) |
| Everything (site loss, new hardware) | [D. Full rebuild](#d-full-rebuild) |
| Network gear | [E. Network replacement](#e-network-replacement) |

## A. Replace one Talos VM

The cluster keeps running with two of three control-plane nodes.

1. Remove the dead node from Kubernetes and etcd:

    ```sh
    kubectl delete node <node-name>
    # control-plane only:
    talosctl --talosconfig development/talos/talosconfig -n <healthy-cp-ip> etcd remove-member <dead-node-hostname>
    ```

2. Re-create the VM: `terraform apply -replace='proxmox_virtual_environment_vm.talos["<vm-name>"]'`
   in `development/terraform/`. Check the exact resource address with
   `terraform state list`.
3. Apply the saved config with its patch, as in
   [step 4.3](../tutorials/build/talos.md#procedure). **Do not run `talosctl bootstrap`.**
   The node joins the existing etcd.
4. Pods that used `local-path` volumes on that node start with empty
   data. Restore their data from the app's own backup.

## B. Replace one Proxmox node

The Proxmox cluster keeps quorum with two of three nodes.

1. On a healthy node, remove the dead node: `pvecm delnode <name>`.
2. Install Proxmox VE on the new hardware, with the **same hostname and
   management IP**. Cable it as in the [port map](../reference/networking.md#per-node-cabling).
3. If the USB NIC has a new MAC address, update
   `pve_nic2_mac_override` (or add it) in
   `ansible/inventory/host_vars/<name>.yml`.
4. Remove the old host key: `ssh-keygen -R 192.168.10.<x>`.
5. Run Ansible against only the new node, then join it:

    ```sh
    cd ansible
    ansible-playbook playbooks/bootstrap.yml -l <name> --skip-tags cluster
    ansible-playbook playbooks/cluster.yml
    ```

6. Re-create the node's two Talos VMs with
   [scenario A](#a-replace-one-talos-vm).

## C. Rebuild the Kubernetes cluster

Use this when the Proxmox cluster is healthy but the Kubernetes cluster
is gone.

1. **If you still have** `controlplane.yaml`, `worker.yaml`, and
   `talosconfig`: re-create the VMs with Terraform (`terraform apply`, or
   destroy and apply), then do [step 4](../tutorials/build/talos.md) from 4.2. Skip
   `talosctl gen config`. Bootstrap once.
2. **If you lost them:** run [step 4](../tutorials/build/talos.md) in full. Then save
   the new files right away.
3. Do [step 5](../tutorials/build/gitops.md) with your **saved** `age-key.txt`. Do not
   generate a new key, because the encrypted files in git need the old one.
4. Wait for ArgoCD to sync every Application.
5. Do [step 6](../tutorials/build/apps.md). authentik's blueprint re-creates its
   providers, groups, and applications. You must set the `akadmin`
   password again, re-add your users, and generate a new outpost token
   (`sops` the new value into `authentik-outpost-media-token.yaml` and
   push it).
6. Restore application data from each app's own backup.

## D. Full rebuild

Do the whole [Build the lab](../tutorials/build/index.md) guide, in order, with these
changes:

- Step 1: use the [port map](../reference/networking.md#physical-port-map)
  and IP plan exactly, so no config in git needs to change.
- Step 4: restore your saved Talos files instead of `gen config`, if you
  have them. New VMs with the old configs make a cluster that your old
  `talosconfig` and `kubeconfig` can reach.
- Step 5: use your saved `age-key.txt`.
- Then restore application data, as in [scenario C](#c-rebuild-the-kubernetes-cluster).

## E. Network replacement

1. Re-create VLANs 10, 80, and 100 with the same subnets
   ([VLANs](../reference/networking.md#vlans)).
2. Set every node-facing port to the **native** VLAN in the
   [port map](../reference/networking.md#per-node-cabling). Tagged ports
   do not work.
3. Re-add the Pi-hole wildcard
   `address=/.lab.pcenicni.dev/192.168.10.240`.
4. Check corosync on a node: `pvecm status` shows `Quorate: Yes` and
   both links up (`corosync-cfgtool -s`).

## Terraform state is lost

The VMs still run. Terraform does not know they exist. Choose one:

- **Import** each VM (keeps the VMs):

    ```sh
    cd development/terraform
    terraform import 'proxmox_virtual_environment_vm.talos["talos-dev-cp-helium"]' helium/201
    # repeat for each VM; check addresses with: grep -n 'resource "' vms.tf
    ```

- **Re-create** the VMs: delete VMs 201-206 in Proxmox, then
  `terraform apply`, then [scenario C](#c-rebuild-the-kubernetes-cluster).

Back up the state file after each `apply` to prevent this.

## Recovery drill checklist

Do this drill twice a year. A recovery plan that nobody tested does not
work.

- [ ] Decrypt one secret with the saved key: `SOPS_AGE_KEY_FILE=<saved> sops -d argocd/dev/manifests/secrets/pihole.yaml`
- [ ] `talosctl --talosconfig <saved> -n 192.168.10.121 version` works
- [ ] `ssh -i <saved key> root@192.168.10.10 pvecm status` works
- [ ] `terraform plan` in `development/terraform/` shows no changes
- [ ] The NAS has an app backup newer than 7 days for each important app
- [ ] The per-switch port table on the [networking page](../reference/networking.md#per-switch-port-assignments) matches the UniFi console
