# Future stack

<p class="lead">Where the lab is going, and the order the work happens in.
The full production design is in
<a href="production/">Production cluster</a>.</p>

## Today vs. target

| Area | Today | Target |
|---|---|---|
| Proxmox nodes | 3 (helium, neon, argon) | 6 (+ krypton, xenon, radon) and a QDevice tie-breaker |
| Kubernetes | `dev-noble`: 6 small VMs, 2 per node | Production: 3 control plane on old nodes, 3 workers on new nodes |
| Persistent storage | `local-path` (node-local, not replicated) | Longhorn on a dedicated SSD per node, replicated over VLAN 80 |
| Backups | App exports by hand | Longhorn snapshots to S3 (Garage or SeaweedFS) on the NAS |
| CNI | Flannel + kube-proxy | Cilium with kube-proxy replacement, NetworkPolicy enforced |
| NAS | Interim OMV on VLAN 50 | Target NAS on VLAN 80 (NFS for Talos, SMB for the Mac Mini) |
| DNS automation | Pi-hole wildcard by hand | external-dns, scoped to externally exposed apps |
| External access | WireGuard only | authentik at `auth.pcenicni.dev` and `auth.nikflix.ca` |
| Kyverno | 1 policy enforced, 2 audit | All policies enforced |

## Roadmap

<div class="nf-timeline" markdown>

<div class="step ok" markdown>
### Proxmox cluster `noble` <span class="pill ok">Done</span> { data-toc-label="Proxmox cluster noble" }
Three nodes, hardened, dual-link corosync, all through Ansible.
</div>

<div class="step ok" markdown>
### Development Kubernetes cluster <span class="pill ok">Done</span> { data-toc-label="Development Kubernetes cluster" }
Six Talos VMs, ArgoCD app-of-apps, SSO, TLS, monitoring, media stack.
</div>

<div class="step wip" markdown>
### Cilium migration <span class="pill wip">Staged</span> { data-toc-label="Cilium migration" }
Values and NetworkPolicies are committed. Remaining work: set CNI to
`none`, disable kube-proxy in the Talos configs, then sync `cilium` by
hand. After that the NetworkPolicies are enforced.
</div>

<div class="step wip" markdown>
### Enforce Kyverno policies <span class="pill wip">In progress</span> { data-toc-label="Enforce Kyverno policies" }
Clear the audit findings, then switch `require-approved-registries` and
`require-resource-limits` to `Enforce`. Then make the Trivy CI scan fail
the build.
</div>

<div class="step" markdown>
### Phase 1 - Longhorn on today's nodes <span class="pill plan">Planned</span> { data-toc-label="Phase 1 - Longhorn on today's nodes" }
Fix the SSDs on neon and argon. Add a `vmbr2` bridge on `nic2`. Run
Longhorn on the three control-plane VMs to prove the storage path.
</div>

<div class="step" markdown>
### Phase 2 - Add krypton, xenon, radon <span class="pill plan">Planned</span> { data-toc-label="Phase 2 - Add krypton, xenon, radon" }
Rack, cable, and join them with the
[add-a-node tutorial](../tutorials/add-a-node.md). Add a QDevice so a
3-3 split cannot drop quorum.
</div>

<div class="step" markdown>
### Phase 3 - Worker VMs and full Longhorn <span class="pill plan">Planned</span> { data-toc-label="Phase 3 - Worker VMs and full Longhorn" }
Install the 2 TB SSDs first. Join three worker VMs, taint the control
plane, and spread Longhorn across all six SSDs.
</div>

<div class="step" markdown>
### Phase 4 - Backups to the NAS <span class="pill plan">Planned</span> { data-toc-label="Phase 4 - Backups to the NAS" }
Run Garage or SeaweedFS on the NAS and point Longhorn's backup target at
it.
</div>

<div class="step" markdown>
### Phase 5 - Production cutover <span class="pill plan">Planned</span> { data-toc-label="Phase 5 - Production cutover" }
Bootstrap ArgoCD on the production cluster with `root-app-prod.yaml`,
move Applications into `argocd/prod/` or `argocd/shared/`, and migrate
app data.
</div>

<div class="step" markdown>
### External access <span class="pill plan">Planned</span> { data-toc-label="External access" }
Expose authentik publicly, then bring back external-dns scoped to the
public apps only.
</div>

</div>

See [Questions](../faq.md#open-design-decisions) for the decisions that
must be made before some of these steps.
