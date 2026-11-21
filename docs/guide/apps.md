# 6. Applications

ArgoCD deploys the applications, but some settings exist only in each
application's own database. This step covers the by-hand settings.

## authentik (SSO)

1. Open `https://auth.lab.pcenicni.dev/if/flow/initial-setup/` and set the
   `akadmin` password. Save it.
2. The blueprint in `argocd/dev/values/authentik-values.yaml` creates the
   OIDC providers and groups for ArgoCD, Grafana, Headlamp, Vikunja, and
   the media forward-auth outpost. Add your user to the admin groups you
   need (for example `ArgoCD Admins`, `Grafana Admins`).
3. Fill the media outpost token into
   `argocd/dev/manifests/secrets/authentik-outpost-media-token.yaml`. See
   [Bootstrapping the outpost token](https://github.com/nikpcenicni/Nikflix/blob/main/argocd/README.md#sso-authentik-forward-auth-domain-level).

## Media stack

The media apps store their settings in `local-path` volumes on the node.
Set up each app through its web UI:

| App | URL | What to set |
|---|---|---|
| Prowlarr | `prowlarr.lab.pcenicni.dev` | Indexers; add Sonarr and Radarr as apps |
| qBittorrent | `qbittorrent.lab.pcenicni.dev` | Save path `/torrents` |
| SABnzbd | `sabnzbd.lab.pcenicni.dev` | Usenet server; completed folder under `/usenet` |
| Sonarr | `sonarr.lab.pcenicni.dev` | Root folder `/media/tv`; add both download clients |
| Radarr | `radarr.lab.pcenicni.dev` | Root folder `/media/movies`; add both download clients |
| Bazarr | `bazarr.lab.pcenicni.dev` | Connect to Sonarr and Radarr |
| Profilarr | `profilarr.lab.pcenicni.dev` | Connect to Sonarr and Radarr |
| Seerr | `seerr.lab.pcenicni.dev` | Connect to Jellyfin, Sonarr, and Radarr |

The NAS must export `/export/media`, `/export/torrents`, and
`/export/usenet` to `192.168.10.0/24`, owned by UID `1004` / GID `100`.
See the
[media stack storage notes](https://github.com/nikpcenicni/Nikflix/blob/main/argocd/README.md#storage-nas-backed-not-longhorn).

## Homepage

Homepage widgets need API keys from each app. Put them in
`argocd/dev/manifests/secrets/homepage-widget-tokens.yaml` with `sops`.

## Check

- `https://dash.lab.pcenicni.dev` loads after an authentik login and
  every tile is green.
- `https://argocd.lab.pcenicni.dev` accepts an authentik login.
- A test request in Seerr reaches Sonarr or Radarr and a download client.
