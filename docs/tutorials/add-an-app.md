# Add an app

<p class="lead">Deploy a new web app the same way every existing app is
deployed. The example adds an app called <code>myapp</code> with the
bjw-s <code>app-template</code> chart. Spoolman is a good real-world
reference.</p>

**You need:** a cluster from [Build the lab](build/index.md), and a
container image for the app.

## 1. Create the Application

Create `argocd/dev/apps/myapp.yaml`. It has two sources: the chart, and
this repository for the values file.

```yaml title="argocd/dev/apps/myapp.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://bjw-s-labs.github.io/helm-charts
      chart: app-template
      targetRevision: 5.0.1
      helm:
        valueFiles:
          - $values/argocd/dev/values/myapp-values.yaml
    - repoURL: https://github.com/nikpcenicni/Nikflix.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 2. Write the values

Create `argocd/dev/values/myapp-values.yaml`:

```yaml title="argocd/dev/values/myapp-values.yaml"
defaultPodOptions:
  labels:
    ballast.tightlinesoftware.com/mode: resize   # (1)!
controllers:
  main:
    containers:
      main:
        image:
          repository: ghcr.io/example/myapp
          tag: 1.2.3                              # (2)!
        resources:
          requests: { cpu: 10m, memory: 128Mi }
          limits: { memory: 512Mi }               # (3)!
service:
  main:
    controller: main
    ports:
      http:
        port: 8080
ingress:
  main:
    className: traefik
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      traefik.ingress.kubernetes.io/router.middlewares: media-authentik-forward-auth@kubernetescrd  # (4)!
    hosts:
      - host: myapp.lab.pcenicni.dev
        paths:
          - path: /
            pathType: Prefix
            service: { identifier: main, port: http }
    tls:
      - hosts: [myapp.lab.pcenicni.dev]
        secretName: myapp-tls
persistence:
  data:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteOnce
    size: 1Gi
    storageClass: local-path
    globalMounts:
      - path: /data
```

1. Optional. Lets Ballast rightsize the pod.
2. Pin an exact tag. Renovate opens PRs for new versions.
3. Kyverno reports containers without a memory limit.
4. Puts authentik in front of the app. Leave this out if the app has its
   own OIDC login, and add an OIDC provider to the authentik blueprint
   instead.

No DNS work is needed. The Pi-hole wildcard already sends
`myapp.lab.pcenicni.dev` to Traefik.

## 3. Add NetworkPolicies

Copy `argocd/dev/manifests/network-policies/spoolman.yaml` to
`myapp.yaml`. Change the namespace, and add any egress the app needs.

## 4. Add a Homepage tile

Every app with a web UI gets a tile. In
`argocd/dev/values/homepage-values.yaml`, add an entry under the right
section in `services.yaml`:

```yaml
- MyApp:
    icon: myapp.png
    href: https://myapp.lab.pcenicni.dev
    siteMonitor: http://myapp.myapp.svc.cluster.local:8080
```

If Homepage has a widget for the app, use the widget instead. Put its API
key in `homepage-widget-tokens.yaml` with [sops](secrets.md), never in
the values file.

## 5. Ship it

```sh
git switch -c add-myapp
git add argocd/dev
git commit -m "argocd: add myapp"
git push -u origin add-myapp
gh pr create --fill
```

CI runs, then the PR auto-merges. ArgoCD syncs within about three
minutes.

## Check

```sh
kubectl -n argocd get application myapp
kubectl -n myapp get pods,ingress,certificate
```

The Application is `Synced`/`Healthy`, the certificate is `Ready`, and
`https://myapp.lab.pcenicni.dev` loads after an authentik login.

??? question "The certificate stays not ready"
    Run `kubectl -n myapp describe certificaterequest`. The usual cause
    is a missing or expired `cloudflare-api-token` Secret in
    `cert-manager`.

??? question "502 Bad Gateway"
    The Service port does not match the container port, or a
    NetworkPolicy blocks Traefik. Check `allow-traefik-ingress` in the
    app's namespace.
