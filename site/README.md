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

Toutes publiques (préfixe `PUBLIC_` = injectées dans le HTML), lues dans `src/config.ts`. Modèle : `.env.example`.

| Variable | Défaut | Rôle |
|---|---|---|
| `SITE_URL` | `https://clearance.cardormedia.com` | canonical, sitemap, Open Graph |
| `PUBLIC_DOWNLOAD_URL` | `https://github.com/fs0ciety7000/clearance/releases/latest` | cible des boutons « Télécharger » ; « Toutes les versions » = la même URL sans `/latest` |
| `PUBLIC_VERSION` | `0.15.0` | version affichée (Téléchargements, pied de page, JSON-LD) |
| `PUBLIC_RELEASED` | `0` | `1` quand cette version est réellement publiée : badge « Disponible » au lieu de « À venir » |
| `PUBLIC_WEB_DEMO` | `0` | `1` affiche « Jouer dans le navigateur » (section Démo) et la réponse FAQ correspondante — seulement si le lot W valide l'export Web |
| `PUBLIC_WEB_DEMO_URL` | `/play/` | adresse de la version Web (export Godot) |
| `WEB_DEMO_ZIP_URL` | *(vide)* | **argument Docker** facultatif : archive `.zip` de l'export Web (avec `index.html` à la racine), dépliée dans `public/play/` avant le build |

Version Web : l'export Godot est servi sous `/play/` (fichiers dans `public/play/`, **non versionnés** — `.gitignore`). `nginx.conf` y applique une CSP avec `'wasm-unsafe-eval'`, COOP/COEP (threads possibles) et `Cache-Control: no-cache`.

## Contenu

- Textes : `src/i18n/fr.ts` (source) et `src/i18n/en.ts` (même forme, typée). Pages : `/` (FR) et `/en/` (EN), sélecteur FR / EN dans la navigation, `hreflang` réciproques.
- Sections (ordre) : Hero · Ticker · Le jeu · Une journée · **Campagne** (3 actes, 30 jours, 10 fins, J31, Récit/Dur, Garde de nuit) · Inspection · **Au guichet** (interrogatoire, fouille, Économat, événements ; cinématiques, hall, Dossier, musique ; confort & accessibilité) · Passagers · Dilemmes · Galerie (12) · **Démo** (J1–J5, version Web conditionnelle) · **Téléchargements** (plateformes, statut de version, journal des versions) · Presse · Crédits & FAQ.
- **Aucun spoiler** : ni nom de fin, ni issue narrative ; la planche de cinématique montrée (`m14_plate_f9_1`) est légendée sans référence à sa fin.
- Captures : `src/assets/shots/` — copies de `docs/mockups/`, optimisées au build en AVIF/WebP responsives (`astro:assets`). Les captures M11+ y sont stockées directement en **WebP ≤ 1920 px** (q84, ≈ 40–190 Ko). Recadrages dérivés : `hero_band`, `portrait_demo`, `m6_visor_*_crop`.
- Exclues volontairement (spoilers) : `m7_end_f5`, `m7_evening_j9`, `m7_rulebook_wanted`, `m11_end_f8/f9`, `m12_end_f10`, `m12_booth_j30_final_figure`, `m12_epilogue_*`, `m14_f*`, `m14_ui_cin_*`, `m14_ui_revoir_*`, `m12_dossier_endings`.
- Images Open Graph : `public/og-fr.jpg`, `public/og-en.jpg` (1200 × 630).
- Captures du site : `docs/mockups/m15_site_*.png`.

## Déploiement

`Dockerfile` (build Astro → nginx, port 8080, `/healthz`) + `nginx.conf` (gzip, cache immuable de `/_astro/`, en-têtes de sécurité, 404).
Coolify : application *Dockerfile*, dépôt `fs0ciety7000/clearance`, *Base Directory* `/site`, port exposé `8080`, health check `/healthz`. Les variables ci-dessus se règlent en **Build Variables** (arguments Docker).
DNS : enregistrement `A clearance.cardormedia.com → IP du serveur Coolify`, proxifié Cloudflare, SSL/TLS **Full (strict)**.
