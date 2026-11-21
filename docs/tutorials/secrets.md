# Manage secrets

<p class="lead">Every secret in git is a <code>SopsSecret</code>, encrypted
with age. sops-secrets-operator decrypts it into a normal Kubernetes
Secret in the cluster.</p>

**You need:** `sops`, and the age private key (`age-key.txt`) from your
password manager.

```sh
export SOPS_AGE_KEY_FILE=~/path/to/age-key.txt
```

## Edit an existing secret

```sh
sops argocd/dev/manifests/secrets/grafana-admin.yaml
```

`sops` opens the decrypted file in `$EDITOR` and encrypts it again when
you save. Commit and push. ArgoCD syncs the change, and the operator
updates the Secret.

!!! tip
    Pods do not restart when a Secret changes. Restart the app's
    Deployment after the sync:
    `kubectl -n <ns> rollout restart deploy/<name>`.

## Create a new secret

1. Write the file as plaintext in `argocd/dev/manifests/secrets/`:

    ```yaml title="argocd/dev/manifests/secrets/myapp.yaml"
    apiVersion: isindir.github.com/v1alpha3
    kind: SopsSecret
    metadata:
      name: myapp
      namespace: myapp
    spec:
      secretTemplates:
        - name: myapp-credentials
          stringData:
            API_KEY: change-me
    ```

    Copy the `apiVersion` from an existing file in that folder so it
    matches the installed operator.

2. Encrypt it in place:

    ```sh
    sops --encrypt --in-place argocd/dev/manifests/secrets/myapp.yaml
    ```

3. Check that only the values are encrypted (names stay readable), then
   commit.

!!! danger "Never commit plaintext"
    Run step 2 before `git add`. TruffleHog in CI catches only verified,
    live credentials, not every leak.

## Rotate the age key

Use this if the key leaks or a person with access leaves.

```sh
age-keygen -o new-age-key.txt
# put the new public key in .sops.yaml (age: field), then:
for f in argocd/*/manifests/secrets/*.yaml; do sops updatekeys -y "$f"; done
kubectl -n sops create secret generic sops-age-key \
  --from-file=keys.txt=new-age-key.txt --dry-run=client -o yaml | kubectl apply -f -
```

Commit, push, and store `new-age-key.txt` in the password manager. Also
rotate the secret values themselves. The old key can still decrypt old
commits in git history.

## Secrets that are not in git

| Secret | Namespace | Why not in git |
|---|---|---|
| `sops-age-key` | `sops` | Needed to decrypt everything else |
| `cloudflare-api-token` | `cert-manager` | Created at bootstrap |

See [GitOps and secrets](build/gitops.md#1-install-the-bootstrap-secrets).
