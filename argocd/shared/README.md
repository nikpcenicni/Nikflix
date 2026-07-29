# Shared Applications

An Application belongs in this directory when its configuration is
identical across every cluster: development, production, and any future
cluster. This directory mirrors the layout of [../dev/](../dev):

```
shared/
├── apps/         # child Applications, read by bootstrap/root-app-shared.yaml
├── values/       # Helm values, one file per chart-backed Application
└── manifests/    # raw manifests, one directory per non-Helm Application
```

This directory is empty today. Every Application onboarded so far (see
[../dev/](../dev)) has cluster-specific values: development-sized resource
requests, and development cluster hostnames and IP ranges. No Application
is shared yet.

Move an Application here from `dev/` (or `prod/`) once its configuration
stops differing between clusters. After you move it, apply
`bootstrap/root-app-shared.yaml` in every cluster's ArgoCD instance, not
only one.
