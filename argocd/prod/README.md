# Prod apps

Same layout as `../dev/`, for the production cluster once it exists:

```
prod/
├── apps/         # child Applications, discovered by bootstrap/root-app-prod.yaml
├── values/       # Helm values, one file per chart-backed app
└── manifests/    # raw manifests, one directory per non-Helm app
```

Empty scaffold — the production Talos cluster this would run on hasn't
been provisioned yet (see `../../terraform/README.md`). Populate this
once that cluster is up, following the pattern in `../dev/` (and
`../README.md`'s note on chart-backed vs raw-manifest apps).
