# Maintenance

<p class="lead">Routine work that keeps the lab patched and recoverable.</p>

## Schedule

| Task | How often | How |
|---|---|---|
| Proxmox security updates | Automatic, daily | `unattended-upgrades` (installed by Ansible) |
| Proxmox full upgrade | Monthly | [Patch Proxmox](#patch-proxmox) |
| Charts, images, Terraform providers, Actions | As PRs arrive | Renovate opens a PR. CI passes, then it auto-merges |
| Talos and Kubernetes | Each Talos minor release | [Upgrade Talos](../tutorials/upgrade-talos.md) |
| Check ArgoCD and certificates | Weekly | [Quick health check](index.md#quick-health-check) |
| App data backup to the NAS | Weekly | Each app's own backup/export |
| Recovery drill | Twice a year | [Drill checklist](disaster-recovery.md#recovery-drill-checklist) |

## Patch Proxmox

```sh
cd ansible
ansible-playbook playbooks/update.yml                         # reports if a reboot is needed
ansible-playbook playbooks/update.yml -e reboot_if_required=true
```

The playbook runs one node at a time. Before a reboot, check
`pvecm status` is quorate. The Talos VMs on the node restart with it, so
the cluster runs on the other two nodes for a short time.

## Renovate and auto-merge

- Renovate opens a PR for each update (`renovate.json`).
- `.github/workflows/auto-merge.yml` squash-merges every PR as soon as
  the workflow runs.
- ArgoCD then syncs the change.

!!! warning "Auto-merge does not wait for checks"
    The merge job does not depend on the security scan or docs build. A
    bad chart bump reaches the cluster within minutes. If an app breaks
    after a Renovate merge, revert the commit on `main`. ArgoCD rolls
    back on its own.

!!! note "Docs deploys after auto-merge"
    Merges done by the workflow's `GITHUB_TOKEN` do not trigger other
    workflows. After a docs PR is auto-merged, run
    `gh workflow run pages.yml` to publish the site.

## Re-run Ansible after a config change

| You changed | Run |
|---|---|
| Hardening variables | `ansible-playbook playbooks/harden.yml` |
| Corosync or storage IPs | `ansible-playbook playbooks/bootstrap.yml --tags network` |
| Packages or repos | `ansible-playbook playbooks/update.yml` |
