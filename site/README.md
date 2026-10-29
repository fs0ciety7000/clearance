# Site CLEARANCE

Site de présentation du jeu (Astro 7, statique, FR + EN). Spec de design : [`SPEC.md`](SPEC.md).

```bash
cd site
npm ci
npm run dev        # http://localhost:4321
npm run build      # → dist/
```

Node ≥ 22.23.4 (exigence d'Astro 7.4) — l'image Docker utilise `node:24-alpine`.

## Configuration (variables d'environnement, au build)

| Variable | Défaut | Rôle |
|---|---|---|
| `SITE_URL` | `https://clearance.cardormedia.com` | canonical, sitemap, Open Graph |
| `PUBLIC_DOWNLOAD_URL` | `https://github.com/fs0ciety7000/clearance/releases` | cible des boutons « Télécharger la démo ». **Aucune release n'est encore publiée** : publier la v0.8.1 (tag `v0.8.1`, workflow *Build*) ou pointer vers une page itch.io / Steam avant d'annoncer le site. |

## Contenu

- Textes : `src/i18n/fr.ts` (source) et `src/i18n/en.ts` (même forme, typée).
- Captures : `src/assets/shots/` — copies de `docs/mockups/` (captures réelles), optimisées au build en AVIF/WebP. Recadrages dérivés : `hero_band`, `portrait_demo`, `m6_visor_*_crop`.
- Exclues volontairement (spoilers) : `m7_end_f5`, `m7_evening_j9`, `m7_rulebook_wanted`.
- Images Open Graph : `public/og-fr.jpg`, `public/og-en.jpg` (1200 × 630).

## Déploiement

`Dockerfile` (build Astro → nginx, port 8080, `/healthz`) + `nginx.conf` (gzip, cache immuable de `/_astro/`, en-têtes de sécurité, 404).
Coolify : application *Dockerfile*, dépôt `fs0ciety7000/clearance`, *Base Directory* `/site`, port exposé `8080`, health check `/healthz`.
DNS : enregistrement `A clearance.cardormedia.com → IP du serveur Coolify`, proxifié Cloudflare, SSL/TLS **Full (strict)**.
