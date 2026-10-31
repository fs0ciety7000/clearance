# CLEARANCE · site de présentation — spec de build

## 0. Brief
Site vitrine bilingue (FR par défaut, EN) du jeu **CLEARANCE** (Studio CLEARANCE, Godot 4.7.2). Mise à jour M15 (lot S) : campagne complète 3 actes / 30 jours / 10 fins + épilogue J31, nouveautés M11–M14, démo J1–J5, version 0.15.0, version Web conditionnelle. Visiteur cible : joueur PC / Steam Deck amateur de *Papers, Please*, presse et créateurs de contenu.
Humeur : **nocturne, bureaucratique, humide**.
Signature : **le Mode Inspection jouable** — le visiteur relie deux champs d'un dossier holographique fictif, révèle CONCORDANT / DISCORDANCE, puis tamponne. Le jeu se comprend en 20 secondes, sans vidéo.
Support : hero « poste de contrôle » sur la vraie capture du guichet (`m9_booth_j1`), pluie en canvas, titre révélé par une ligne de balayage holographique, horloge de shift vivante.
Fidélité : le `DESIGN_SYSTEM.md` du jeu prime sur les conventions génériques (angles **chanfreinés**, pas de pilules ; couleurs à rôle unique).

## 1. Stack
Astro 7.4.2 (statique), TypeScript strict, CSS natif (pas de Tailwind), aucun framework client : scripts vanilla par composant (bundlés par Vite). `astro:assets` (`<Picture>` AVIF + WebP, largeurs 480/800/1200/1600/1920). `@astrojs/sitemap`. Polices auto-hébergées (Fontsource, woff2 latin) : aucun appel tiers.

## 2. Polices
| Rôle | Famille | Graisses | Usage |
|---|---|---|---|
| Display | Chakra Petch | 600, 700 | H1, H2, tampons, chiffres clés |
| UI / texte | Inter (variable) | 400–600 | corps, boutons, nav |
| Données | JetBrains Mono (variable) | 400–700 | micro-labels, valeurs de documents, horloge |
Préchargement : Chakra Petch 700 + Inter. `font-display: swap`.

## 3. Tokens (DS §2, valeurs figées)
```
--void #07080C · --panel #0E1118 · --elev #161B26 · --line #232A38
--tx #E8F1F5 · --tx2 #8A97A8 · --tx3 #4E5868 (décor uniquement)
--cyan #00E5FF (holo, info, focus) · --yellow #FFE600 (Consortium, CTA unique)
--magenta #FF2E88 (discordance, Lucioles — rare) · --amber #FFA31A (nouveau / attention)
--red #FF3B3B (REFUSÉ) · --green #2EFF9A (APPROUVÉ)
```
`html,body{background:#07080C}` en première règle. Sélection : cyan 30 %. Texte sur accent plein : `#07080C`.
Hiérarchie : tx 100 % titres → tx2 corps → mono 11–12 px +0,18em labels.

## 4. Matériaux et utilitaires
- `.chamfer` : `clip-path: polygon(var(--c) 0,100% 0,100% calc(100% - var(--c)),calc(100% - var(--c)) 100%,0 100%,0 var(--c))` — coins haut-gauche/bas-droit (signature « ticket » du DS), `--c` 8 px (bouton), 16 px (panneau).
- `.holo` : fond `#0E1118` + voile cyan 8 %, bordure 1 px cyan 40 %, scanlines `repeating-linear-gradient` alpha 0,05 / 3 px **sur le cadre seulement** (jamais sur le texte de données).
- Grain SVG fractal-noise opacité 0,06, `pointer-events:none`, z 100.
- Grille de fond 64 px `--line` 35 % sur les sections « plan de travail ».
- Entrées : système fail-safe (`.appear`, état final visible sans JS), révélations au scroll via IntersectionObserver (`.js [data-reveal]`, y 30 px, 0,7 s, `cubic-bezier(.16,1,.3,1)`).
- `prefers-reduced-motion` : pas de pluie, pas de balayage, pas de scramble, transitions ≤ 160 ms en fondu.

## 5. Médias (captures réelles uniquement)
| Slot | Fichier | Cadrage |
|---|---|---|
| hero | `m9_booth_j1.png` | cover, `object-position: 62% 18%`, settle scale 1,08 → 1 en 1,8 s ; scrims : bas `#07080C` 0→92 %, gauche 85 % → 0 à 60 % |
| journée 1–4 | `m5_briefing`, `m6_day3_autoplay`, `m9_booth_j7_detain`, `m5_summary` | cadre holo 16:9 |
| passagers | `m6_visor_down` / `m6_visor_up` (comparateur), `m6_portraits`, `m6_lineup` | |
| dilemmes | `m7_envelope`, `m8_symbol_report`, `m5_evening` | |
| campagne | — (frise de 30 + 1 segments, couleurs d'acte cyan / jaune / ambre, épilogue vert pointillé) | |
| au guichet | `m13_journal`, `m13_search`, `m13_shop`, `m12_station_event` (recadrages zoomés `--fx/--fy/--z`) ; `m14_plate_f9_1` (21:9), `m14_hall_act1_strip`, `m14_ui_dossier_people` ; `m11_a11y_options` | |
| démo (Web) | `m9_booth_j1` + bouton lecture jaune | si `PUBLIC_WEB_DEMO=1` |
| galerie | 12 captures (7/5 · 4/4/4 · 5/7 · 6/6 · 4/4/4) | lightbox `<dialog>` |
| Deck | `m9_booth_j1_deck` | |
Exclues (spoilers) : fin `m7_end_f5`, soirée J9 `m7_evening_j9`, avis de recherche J10 `m7_rulebook_wanted`.

## 6. Sections (ordre)
1. **Nav** fixe 64 px, fond `#07080C` 0 → 85 % + flou 12 px après 40 px de scroll. Marque (losange cyan de l'icône + CLEARANCE Chakra 700 18 px +0,08em) · liens mono 12 px (Le jeu, Inspection, Passagers, Galerie, Presse) · bascule FR/EN · CTA jaune chanfreiné « Démo ». Mobile < 900 px : bouton menu → panneau plein écran, verrouillage du scroll, Échap.
2. **Hero** 100 svh (min 640). Quatre coins éditoriaux mono 11 px : HG `HALCYON GATE · ANNEAU A · GUICHET 04`, HD `SHIFT 10:00 ▮▮▮▯ FIN 18:00` (horloge vivante, 1 min de jeu = 1,125 s), BG titre, BD bloc CTA. Eyebrow mono jaune `CONSORTIUM · CONTRÔLE D'ENTRÉE · 2187`. H1 `CLEARANCE` Chakra 700 `clamp(64px, 15.5vw, 236px)`, interligne 0,82, tracking −0,02em, révélé par masque `clip-path` balayé de haut en bas (0,9 s, délai 0,35 s) avec une ligne cyan 1 px qui descend. Sous-titre Inter 18–20 px tx2 max 34rem : la tagline. CTA : primaire jaune « Télécharger la démo », secondaire contour « Essayer le Mode Inspection ». Bandeau bas mono : `v0.8.1 · DÉMO J1–J10 · WINDOWS · MACOS · LINUX · STEAM DECK`. Pluie canvas (≤ 140 gouttes, DPR ≤ 1,5, alpha 0,10–0,28, inclinaison 8°), en pause hors écran.
3. **Ticker** — slogans du Consortium alternés avec le Tessar, mono 13 px, 40 s/boucle, losanges jaunes.
4. **Manifeste** — paragraphe Chakra 600 `clamp(28px, 4.4vw, 60px)` révélé mot à mot au scroll (0,15 → 1), mots-clés en blanc, reste tx2. Puis 4 piliers (01–04) en grille 4 colonnes séparées par des filets.
5. **Une journée au guichet** — scène collante : colonne gauche 4 étapes (horodatage mono jaune, titre Chakra 32 px, texte), colonne droite cadre holo `position: sticky; top: 14vh` qui fond d'une capture à l'autre (600 ms). Mobile : capture sous chaque étape.
6. **Mode Inspection (signature)** — plan de travail quadrillé : Carte d'identité + Permis d'entrée + Rulebook (date du jour). Sélection A → B, tracé orthogonal SVG (240 ms, `ease.snap`), résultat chip : DISCORDANCE (magenta, ≠, trait plein + glow), CONCORDANT (gris, =, se dissout 1,5 s), INCOMPARABLE (ambre). Compteur 0/2. Tampons APPROUVÉ / REFUSÉ (impact `scale 1.08 → 1`, rotation −4°) et verdict pédagogique (refus documenté / refus sans preuve / entrée irrégulière). Région `aria-live`.
7. **Passagers** — comparateur visière (curseur glissant, clavier ←/→), portraits « sosies », lexique Tessar (phrase + sous-titre), catalogue d'implants (OPT-, NX-, MIL-, KIN-, DER-).
8. **Dilemmes** — 3 cartes : L'enveloppe (jaune), Les Lucioles (magenta), Le foyer (Ilan, Noa, Dora). Aucun spoiler : on pose la question, pas la réponse. « 7 fins. La station retient tout. »
9. **Galerie** — grille 12 colonnes (spans 7/5, 4/4/4, 5/7) + lightbox.
10. **Plateformes** — 4 tuiles + configuration indicative + notes macOS/Windows (non signés).
11. **Presse** — fiche technique, textes courts/longs, téléchargements (logo SVG/PNG, captures PNG).
12. **Crédits & licences**, **FAQ** (`<details>`), **Appel final** (tampon APPROUVÉ animé à l'entrée), **Pied de page**.

### 6 bis. Sections ajoutées en M15 (lot S)
- **03 Campagne** (`#campagne`) : 4 chiffres clés (3 / 30 / 10 / J31) en Chakra 700, frise des jours animée au scroll (statique si `prefers-reduced-motion`), 3 cartes d'acte + carte Épilogue (pointillés verts), puis « Récit ou Dur » et « Garde de nuit ». Aucun nom de fin.
- **05 Au guichet** (`#systemes`) : 4 cartes à capture recadrée (interrogatoire, fouille, Économat, événements) ; « Une station qui respire » : planche de cinématique 21:9 avec légende en surimpression, hall vivant, Dossier, carte Musique dynamique (5 couches L0–L4 animées, figées en mouvement réduit) ; « Confort & accessibilité » : capture des options + 6 entrées.
- **09 Démo** (`#demo`) : J01–J05 (horodatage mono jaune), carte holo chanfreinée (faits + CTA jaune), carte « Jouer dans le navigateur » (`#jouer`, lien vers `PUBLIC_WEB_DEMO_URL`) **uniquement** si `PUBLIC_WEB_DEMO=1`.
- **10 Téléchargements** (`#telecharger`, ex-Plateformes) : 4 tuiles, bandeau de version (badge ambre « À venir » ou vert « Disponible » selon `PUBLIC_RELEASED`), CTA vers `PUBLIC_DOWNLOAD_URL`, configuration, journal des versions 0.9 → 0.15 sans spoiler.
- Navigation : Le jeu · Campagne · Inspection · Galerie · Démo · Presse ; CTA « Télécharger » → `#telecharger`. Hero : bandeau `3 ACTES · 30 JOURS · 10 FINS · DÉMO J1–J5 · FR · EN · plateformes`.
- FAQ : + mode Récit, + « jouer dans le navigateur » (réponse selon `PUBLIC_WEB_DEMO`), anglais disponible en 0.15.0.

## 7. Contraintes
Lighthouse ≥ 95 ×4 mobile/desktop. Aucun secret. URL de téléchargement : `PUBLIC_DOWNLOAD_URL` (défaut : `…/releases/latest`). Version Web : `/play/` (CSP `wasm-unsafe-eval`, COOP/COEP dans `nginx.conf`). Pas de bande-annonce tant qu'aucune vidéo n'est fournie. Cibles tactiles ≥ 44 px, focus cyan 2 px visible partout, contrastes AA (tx3 jamais pour une info).
