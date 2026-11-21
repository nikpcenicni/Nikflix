# Operations

<p class="lead">Keeping the lab healthy, and getting it back when something
breaks.</p>

<div class="grid cards" markdown>

-   :material-lifebuoy:{ .lg .middle } **[Disaster recovery](disaster-recovery.md)**

    ---

    What to keep outside the lab, and runbooks for losing a VM, a node,
    the cluster, the network, or everything.

-   :material-wrench-clock:{ .lg .middle } **[Maintenance](maintenance.md)**

    ---

    Patching Proxmox, dependency updates, health checks, and the
    recovery drill.

</div>

## Quick health check

```sh
ssh root@192.168.10.10 pvecm status | grep -E 'Quorate|Nodes'
kubectl get nodes
kubectl -n argocd get applications | grep -v 'Synced.*Healthy'
kubectl get certificates -A | grep -v True
```

All nodes are present and quorate. The last two commands print only the
header line when everything is fine (`cilium` stays `OutOfSync` on
purpose).
