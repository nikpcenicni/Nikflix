# Shared apps

Applications whose config is identical across every cluster (dev, prod,
and any future one) live here, mirroring `dev/`'s layout:

```
shared/
├── apps/         # child Applications, discovered by bootstrap/root-app-shared.yaml
├── values/       # Helm values, one file per chart-backed app
└── manifests/    # raw manifests, one directory per non-Helm app
```

Empty for now — every app onboarded so far (see `../dev/`) has cluster-specific
values (dev-sized resource requests, dev cluster hostnames/IP ranges) and
so isn't actually shared yet. Move an app here from `dev/` (or `prod/`)
once its config stops differing between clusters, and apply
`bootstrap/root-app-shared.yaml` in every cluster's ArgoCD, not just one.
