---
hide:
  - navigation
  - toc
---

<div class="nf-hero" markdown>

# Nikflix

A home lab defined as code. Proxmox hosts Talos Linux VMs, the VMs run
Kubernetes, and ArgoCD deploys everything on the cluster from git. These
docs explain how it works, how to build your own, and how to bring it
back after a failure.

[Explore the stack :material-arrow-right:](current/index.md){ .md-button .md-button--primary }
[Build your own](tutorials/build/index.md){ .md-button }
[Disaster recovery](operations/disaster-recovery.md){ .md-button }

</div>

<div class="nf-stats" markdown>
<div class="nf-stat"><b>3</b><span>Proxmox nodes</span></div>
<div class="nf-stat"><b>6</b><span>Talos VMs</span></div>
<div class="nf-stat"><b>40</b><span>ArgoCD Applications</span></div>
<div class="nf-stat"><b>3</b><span>Isolated VLANs</span></div>
<div class="nf-stat"><b>0</b><span>Plaintext secrets in git</span></div>
</div>

## Where to go

<div class="grid cards" markdown>

-   :material-layers-triple:{ .lg .middle } **Current stack**

    ---

    What runs today: hardware, network, Kubernetes platform, security
    controls, and every app.

    [:octicons-arrow-right-24: Current stack](current/index.md)

-   :material-rocket-launch-outline:{ .lg .middle } **Future stack**

    ---

    The roadmap: a six-node production cluster, Longhorn storage,
    Cilium, and external access.

    [:octicons-arrow-right-24: Roadmap](future/index.md)

-   :material-school-outline:{ .lg .middle } **Tutorials**

    ---

    Build the lab from bare metal, then everyday tasks: add an app,
    manage secrets, add a node, upgrade Talos.

    [:octicons-arrow-right-24: Tutorials](tutorials/index.md)

-   :material-lifebuoy:{ .lg .middle } **Operations**

    ---

    Disaster recovery runbooks, what to back up, and routine
    maintenance.

    [:octicons-arrow-right-24: Operations](operations/index.md)

-   :material-lan:{ .lg .middle } **Reference**

    ---

    IP plan, port map, DNS, repository layout, and the full
    architecture write-ups.

    [:octicons-arrow-right-24: Reference](reference/index.md)

-   :material-frequently-asked-questions:{ .lg .middle } **Questions**

    ---

    FAQ, and the design decisions that are still open.

    [:octicons-arrow-right-24: Questions](faq.md)

</div>

## The stack at a glance

```mermaid
flowchart LR
    subgraph net["Network · UniFi"]
        V["VLAN 10 mgmt<br/>VLAN 80 storage<br/>VLAN 100 corosync"]
    end
    subgraph pve["Proxmox 'noble'"]
        H["helium · neon · argon"]
    end
    subgraph k8s["Kubernetes 'dev-noble'"]
        T["3 control plane<br/>3 worker"]
    end
    subgraph git["GitOps"]
        A["ArgoCD<br/>40 Applications"]
    end
    net -->|Ansible| pve -->|Terraform + talosctl| k8s
    git -->|syncs| k8s
```

| Layer | Tool | Status |
|---|---|---|
| Network | UniFi, configured by hand | <span class="pill ok">Running</span> |
| Proxmox cluster `noble` | Ansible | <span class="pill ok">Running</span> |
| Development cluster `dev-noble` | Terraform + Talos | <span class="pill ok">Running</span> |
| Platform and apps | ArgoCD + SOPS | <span class="pill ok">Running</span> |
| Production cluster | Terraform + Talos | <span class="pill plan">Planned</span> |
| Longhorn storage | ArgoCD | <span class="pill plan">Planned</span> |
