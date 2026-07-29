# Production Applications

This directory holds the Applications specific to the production
cluster, once that cluster exists. This directory mirrors the layout of
[../dev/](../dev):

```
prod/
├── apps/         # child Applications, read by bootstrap/root-app-prod.yaml
├── values/       # Helm values, one file per chart-backed Application
└── manifests/    # raw manifests, one directory per non-Helm Application
```

This directory is an empty scaffold. The production Talos cluster that
would run these Applications does not exist yet — see
[../../terraform/README.md](../../terraform/README.md). Populate this
directory after that cluster is up. Follow the pattern in
[../dev/](../dev), and see [../README.md](../README.md) for the
difference between a chart-backed Application and a raw-manifest
Application.
