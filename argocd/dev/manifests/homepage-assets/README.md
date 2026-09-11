# Homepage background photos

Six nature/landscape photos used by the Homepage dashboard's random
background (`argocd/dev/values/homepage-values.yaml`'s `custom.js` and
`configMaps.homepage-config.binaryData`). Downloaded once, locally, via
the Unsplash API (free tier) at reduced size/quality (1024px wide, JPEG
quality ~35) to fit Kubernetes' ~1MiB ConfigMap size limit alongside the
rest of Homepage's config - the heavy blur/darken treatment in
`custom.css` hides the compression well.

Per [Unsplash's API guidelines](https://help.unsplash.com/en/articles/2511315-guideline-attributing-photographers),
photographer attribution:

| File | Photographer | Source |
|------|--------------|--------|
| `nature-1.jpg` | Zizi zi | https://unsplash.com/photos/8mtCzzAXdw4 |
| `nature-2.jpg` | Mushegh Hakobyan | https://unsplash.com/photos/DOOSi8EQuwQ |
| `nature-3.jpg` | Navi | https://unsplash.com/photos/hI3xNg_V6DM |
| `nature-4.jpg` | stefano d'andrea | https://unsplash.com/photos/UXIsw4vK1gM |
| `nature-5.jpg` | Chris Stenger | https://unsplash.com/photos/fvJwchRL6xw |
| `nature-6.jpg` | Fenna van Casand | https://unsplash.com/photos/rzbR-6n4IIc |

To refresh this set: put a real `UNSPLASH_ACCESS_KEY` in the repo root's
`.env` (gitignored, never commit it), then fetch and downsize new random
photos, replace the files here, and re-run the base64 embed into
`homepage-values.yaml`'s `configMaps.homepage-config.binaryData`.
