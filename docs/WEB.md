# WEB.md — Version Web (HTML5) de la démo

> Propriétaire : **Godot Architect (export)** · M15 lot W · décision **D-216** (contrat `docs/M15.md` §3).
> Godot 4.7.2-stable, modèles `web_release.zip` (threads) / `web_nothreads_release.zip`, Chromium 153 (Playwright). Mesures du 31.10.2026 sur la version 0.14.0 + travaux M15 en cours (lot A : démo, langue).

## 1. Verdict

**Viable**, sous trois conditions (§7) : build **à threads** servi avec les en-têtes **COOP/COEP**, audio en mode **Stream** sur le Web (une ligne `.web` de `project.godot`), et hébergement sur notre nginx (D-090).

| Cible D-216 | Mesure | État |
|---|---|---|
| Taille ≤ 60 Mo | **≈ 42 Mo téléchargés** (gzip) ; 76 Mo décompressés (moteur 37 + paquet 39) | ✅ au transfert, ❌ brut (le moteur seul pèse 37 Mo) |
| Démarrage ≤ 20 s en local | **≈ 8 s** jusqu'à l'écran titre (serveur local) ; 16 s à 50 Mbit/s ; 26 s à 20 Mbit/s | ✅ |
| Rendu 3D | Guichet du J1 complet en Compatibility / WebGL 2 (néons, pluie, passager, carte, portrait) ; **coût par image identique au natif Compatibility sur le même GPU** | ✅ (GPU réel non mesurable ici, §3.2) |
| Audio (D-083, D-176) | Musique, ambiance, SFX au guichet ; **0 % de sous-alimentation** avec threads, même à 2 images/s | ✅ avec threads (❌ sans threads, §3.3) |
| Sauvegarde | `user://` → IndexedDB (`/userfs`) ; la partie survit au rechargement, CONTINUER — J1 au titre | ✅ |
| Entrées | Manette (standard, bouton A), clavier, souris : tout le parcours titre → J1 | ✅ |
| Jeu natif non dégradé | Aucun changement natif ; une seule garde `OS.has_feature("web")` dans `scripts/ui/input_prompts.gd` | ✅ |

## 2. Fichiers

| Fichier | Rôle |
|---|---|
| `export_presets.cfg` — préréglage **`Web`** (`[preset.4]`) | Démo (`custom_features="demo"`, lot A) ; plateforme Web (feature tag `web` automatique) ; **`variant/thread_support=true`** ; textures desktop (S3TC/BPTC) seulement ; mêmes exclusions que le natif **plus les planches des cinématiques** (`assets/cinematics/bg|mid|lit/*`, −12 Mo : jamais jouées dans la démo, chargées à la demande par chemin, D-183/D-215) ; sortie `build/web/index.html` |
| `tools/export_web.sh` | Contrôle Godot 4.7.2 + modèle Web, `--import`, export, échec sur `ERROR`, `CREDITS.txt` + `licenses/` (comme les archives natives), `.gz` précompressés (gzip -9 -n), archive `build/dist/CLEARANCE-<version>-web.zip` (+ `SHA256SUMS-web`). **Déterministe** (deux exports d'une même source : mêmes empreintes, fichier par fichier) |
| `tools/smoke_web.js` | Test de bout en bout dans Chromium (Playwright) : §4 |
| `web/nginx-clearance-web.conf` | Bloc nginx prêt à inclure (en-têtes, types MIME, `gzip_static`, cache) : §5 |
| `scripts/ui/input_prompts.gd` (hors ligne W, signalé) | `keyboard_get_keycode_from_physical()` n'est pas pris en charge par le serveur d'affichage Web : chaque appel écrivait « ERROR: Not supported by this display server » (des dizaines par image au briefing). Garde `and not OS.has_feature("web")` à côté de celle du headless ; l'invite affiche alors la touche physique (QWERTY) |

Aucun shell HTML personnalisé : celui de Godot (`index.html`, barre de progression, contrôle des fonctionnalités du navigateur) suffit.

## 3. Mesures

Machine : conteneur Linux 4 cœurs partagés avec les autres lots (charge 5–6), **sans GPU**. Chromium headless rend WebGL avec **SwiftShader** (rastériseur logiciel) ; avec `--gl=angle-gl` sous xvfb, avec **Mesa llvmpipe** — le même rastériseur que les mesures natives de `docs/QA.md` §5.

### 3.1 Taille (préréglage Web, démo)

| Fichier | Brut | gzip -9 |
|---|---|---|
| `index.wasm` (moteur Godot, modèle officiel) | 37,0 Mio | 9,7 Mio |
| `index.pck` (jeu) | 38,8 Mio | 32,2 Mio (OGG/WebP déjà compressés) |
| `index.js`, `index.html`, worklets audio, icônes | 0,3 Mio | 0,1 Mio |
| **Total téléchargé** | **≈ 76 Mio** | **≈ 42 Mio** |

Sans l'exclusion des planches : paquet 49,6 Mio (gzip 40,8). Le paquet de la démo garde tout le contenu J6–J30 (verrouillé, choix du lot A, D-215) : musique des actes II–III et thèmes de fin (≈ 17 Mo) sont référencés en dur par `music_library.tres` et ne peuvent pas être exclus par filtre sans casser le chargement de la bibliothèque.

### 3.2 Démarrage, images par seconde, mémoire

| Mesure | Valeur |
|---|---|
| Écran titre, serveur local | **8–10 s** (résolution de la détection : 1 s) ; moteur prêt à 1,4 s, `main: démo J1–J5` à 5,7 s |
| Écran titre, 50 Mbit/s simulés (`--throttle=50`) | 16 s |
| Écran titre, 20 Mbit/s simulés | 26 s |
| Titre, images/s | SwiftShader 12–15 ; llvmpipe 29–36 |
| **Guichet J1** (1280×720, qualité Auto = Élevé), images/s | SwiftShader 0,6–1,2 ; **llvmpipe 2,3–2,8** |
| Même scène, **natif** Compatibility (`--rendering-driver opengl3`, llvmpipe, 1280×720, `tools/qa_perf.gd`) | 2,2–2,3 images/s (430–447 ms) |
| Profil CPU du thread principal au guichet (CDP, 10 s) | **96 % dans `getParameter`** = attente du GPU (une fois par image) ; code wasm du jeu ≈ 45 ms sur 10 s (≈ 5 ms par image) |
| Mémoire | tas wasm 138 Mio au titre → **166 Mio au guichet** ; tas JS 11–14 Mio ; mémoire vidéo (natif Compatibility) 57–67 Mio en Élevé, 28–38 Mio en Bas |

Lecture : sans GPU, le chiffre absolu d'images/s n'a pas de sens (rastérisation logicielle, comme au §5 de `QA.md`). Ce qui se mesure : (1) **sur le même GPU, la version Web coûte autant que le natif Compatibility** (2,7 contre 2,3 images/s sur llvmpipe ; le natif mesuré est même un binaire de debug) ; (2) la logique du jeu en wasm est négligeable (≈ 5 ms par image) ; (3) le guichet ne dépend pas de la taille de la fenêtre (la vue 3D est un `SubViewport` de 1920×376 logiques, `stretch`) : en 320×180, le titre monte à 60 images/s mais le guichet reste à 1 image/s. La version Web tient donc dès que le GPU du joueur tient le **rendu Compatibility** du guichet — à vérifier sur un vrai GPU (§8).

**Qualité graphique (D-074)** sur le rendu Compatibility (natif, llvmpipe, J1, 1280×720) : Bas 132–186 ms, Moyen 293 ms, Élevé 247–447 ms par image (machine chargée par les autres lots : bruit important ; mesures appariées Bas/Élevé : 132/247 et 186/447 ms) ; **Bas ≈ 2× moins cher qu'Élevé**, mémoire vidéo divisée par 2 (28–38 contre 57–67 Mio). Recommandation §7 : Auto = Moyen sur le Web (comme le Steam Deck).

### 3.3 Audio (AudioWorklet, D-083, D-176)

Mesuré par le smoke : niveau RMS de la sortie (prise sur `AudioDestinationNode`) et **sous-alimentation** du worklet de Godot (blocs de 128 échantillons qu'il n'a pas pu remplir = craquement), sur 10 s.

| Variante | Titre (29–36 i/s) | Guichet (2–3 i/s) |
|---|---|---|
| Sans threads, latence 50 ms (défaut Godot) | **13 %** de blocs vides | **93 %** |
| Sans threads, `audio/driver/output_latency.web=150` | 0 % | 70 % |
| **Avec threads** (préréglage retenu) | **0 %** | **0 %** (0,1 % en mode Stream) |

Sans threads, le mixage de Godot se fait **sur le thread principal**, une fois par image : chaque image plus longue que la latence affame le worklet (musique hachée). Avec threads, le mixage tourne sur son propre thread et ne dépend plus des images/s. La musique (`AudioStreamInteractive` + `AudioStreamSynchronized`, D-176) est toujours mixée par Godot, donc concernée au premier chef.

**Mode d'échantillons du Web.** Godot 4.7 joue par défaut sur le Web les flux « échantillonnables » (OGG, WAV) **en dehors de son mixeur**, directement en Web Audio (`audio/general/default_playback_type.web = Sample`). Conséquence : les **effets de bus ne s'appliquent pas** à ces sons — seuls volume, sourdine et solo des bus sont émulés. Pour CLEARANCE cela retire : le **limiteur** du Master, l'option d'accessibilité **son mono** (`Mono`, Master), le **ducking** de l'ambiance et des voix (`Duck`), l'effet **hygiaphone** de la vitre (`Hygiaphone`, Voice), la chaîne radio des annonces (filtres, EQ, distorsion, réverbération), l'étouffement de pause (`Muffle`), les réverbérations d'ambiance et du monde. La musique, non échantillonnable, garde ses effets (`Fade` de D-176). Mesuré en mode **Stream** (`default_playback_type.web=0`, build à threads) : tout passe par le mixeur de Godot, 0,1 % de sous-alimentation au guichet à 2 images/s, niveau de sortie plus élevé (ducking et chaînes actifs). → proposition D-B (§7).

**D-083** (course `bus_details` du thread de mixage) : le build à threads a un thread de mixage comme le natif ; `AudioMixBarrier` prend le verrou du pilote une fois par image comme ailleurs. Environ 25 min de jeu Web cumulées (titre, briefing, guichet, rechargements) sans plantage ; **le stress `qa_audio_stress` n'a pas été rejoué sur le Web** (pas d'arguments de debug dans un export release).

### 3.4 Sauvegarde, entrées, langue

- `user://` = `/home/web_user/.local/share/godot/app_userdata/CLEARANCE` monté sur **IndexedDB** (base `/userfs`, magasin `FILE_DATA`), synchronisé par Godot à la fermeture de chaque fichier. Après le J1 : `user://demo/saves/profile.json`, `slot_1/{current,day_01,meta}.json` ; après rechargement, le titre propose **CONTINUER — J1** avec le focus. Limites : stockage par origine (changer de domaine = perdre la partie), effacé avec les données du site ; navigation privée = session seulement.
- **Manette** : manette standard simulée (`navigator.getGamepads`, mapping `standard`) ; le bouton A ouvre NOUVELLE PARTIE. **Clavier** : Entrée sur l'emplacement puis « Jouer en Dur », N (intercom). **Souris** : clic sur PRENDRE SON POSTE. Le canevas prend le focus au démarrage (`html/focus_canvas_on_start`).
- **Langue** (lot A) : le jeu suit la langue du navigateur (`en-*` → anglais). Le smoke force `fr-FR` (option `--locale`).
- Le cache de shaders de Godot (`user://shader_cache`) est lui aussi écrit dans IndexedDB (effet sur le second démarrage non mesuré).

## 4. Smoke test : `tools/smoke_web.js`

```bash
bash tools/export_web.sh
node tools/smoke_web.js                       # headless, SwiftShader (≈ 5 min)
xvfb-run -a node tools/smoke_web.js --gl=angle-gl   # Chromium fenêtré sur llvmpipe (plus rapide)
node tools/smoke_web.js --startup-only --throttle=50 --no-shots   # temps de démarrage à 50 Mbit/s
```

Sert `build/web/` avec les en-têtes de production (COOP, COEP, CORP, `.gz` précompressés), joue titre → manette → clavier → briefing → souris → guichet J1 → intercom, mesure (images/s, thread principal, audio, mémoire), recharge la page et vérifie la sauvegarde. **Échoue** sur : étape non atteinte, exception JS, ligne `ERROR`/`SCRIPT ERROR` de Godot, page non isolée (threads), `AudioContext` arrêté, audio muet, sous-alimentation > 20 %, sauvegarde absente d'IndexedDB ou CONTINUER sans le focus après rechargement. Les étapes sont reconnues à l'image (accent jaune du DS, cyan du titre, contraste de la vue 3D) : robuste au contenu, à revoir si la mise en page du titre, du briefing ou de la barre d'outils change. L'instrumentation (compteur du worklet audio, prise sur la sortie, manette simulée) n'existe que dans le serveur de test, jamais dans `build/web/`.

Sorties : `build/web_smoke/metrics.json`, `console.log`, une capture par étape ; captures de référence `docs/mockups/m15_web_title.png`, `m15_web_briefing.png`, `m15_web_j1.png`, `m15_web_j1_passenger.png` (`_en` avec `--locale=en-US`).

Dernier passage : ✅ (titre 10 s, briefing 87 s, guichet 137 s sous SwiftShader ; aucune erreur console).

## 5. Hébergement

- **En-têtes obligatoires** (threads → `SharedArrayBuffer`) sur la page **et** ses ressources : `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` (+ `Cross-Origin-Resource-Policy: same-origin` conseillé). Sans eux, Godot affiche « Cross-Origin Isolation - Check web server configuration » et ne démarre pas. Tout est servi depuis la même origine : rien d'autre à autoriser.
- **Types MIME** : `application/wasm` pour `.wasm` (compilation en flux), `application/octet-stream` pour `.pck`.
- **Compression** : `gzip_static on` (les `.gz` sont produits par `export_web.sh`) ; le `.pck` gagne peu (OGG/WebP), le `.wasm` passe de 37 à 9,7 Mio. Cloudflare (D-090) recompresse en Brotli si activé ; ne pas cacher les en-têtes COOP/COEP derrière une règle de cache qui les supprime.
- **Cache** : `index.html` en `no-cache` ; le reste `max-age=3600, must-revalidate` (les noms ne sont pas hachés : un nouveau build garde les mêmes URL).
- Bloc prêt : `web/nginx-clearance-web.conf` (`location /play/`).
- **Itch.io / hébergeurs sans en-têtes** : itch.io a une case « SharedArrayBuffer support » ; ailleurs, repli possible par le service worker de Godot (`progressive_web_app/enabled=true` + `ensure_cross_origin_isolation_headers=true`) ou par le build sans threads (audio dégradé, §3.3).
- **Navigateurs** : WebGL 2 + `SharedArrayBuffer` isolé = Chrome/Edge, Firefox et Safari récents (ordre de grandeur : Chrome 92+, Firefox 79+, Safari 15.2+ ; seul Chromium 153 testé). Mobile **non visé** (interface 1080p, clavier/souris/manette).

## 6. Intégration au site Astro (lot S)

- **URL relative** proposée : **`/play/`** (une seule version : le jeu choisit FR/EN selon le navigateur ; la page anglaise du site pointe aussi vers `/play/`). `index.html` à la racine de ce dossier.
- **Lien plein écran plutôt qu'`<iframe>`** : une iframe exigerait que la **page parente** soit elle-même isolée (COOP/COEP sur tout le site, ce qui bloque vidéos/embeds tiers) et `allow="cross-origin-isolated; autoplay; fullscreen; gamepad"`. Le bouton « Jouer à la démo dans le navigateur » ouvre `/play/` dans l'onglet.
- **Taille à annoncer** : « ≈ 42 Mo à télécharger » (76 Mo une fois décompressés) ; « ordinateur avec carte graphique récente, Chrome, Edge, Firefox ou Safari récent ; pas de mobile ».
- **Livraison** : `build/` n'est pas versionné. L'archive `build/dist/CLEARANCE-<version>-web.zip` (≈ 42 Mo, sans les `.gz`) se publie avec les autres archives (Release GitHub) ; l'image Docker du site la télécharge et la décompresse dans `<racine nginx>/play/`, puis `gzip -k -9` sur `*.wasm *.pck *.js *.html` (ou `gzip on` à la volée), et inclut `web/nginx-clearance-web.conf`. Ne pas copier le build dans `site/public/` (76 Mo dans git).

## 7. Propositions de décisions

| # | Proposition | Raison (chiffres §3) | Écartée |
|---|---|---|---|
| D-A | Build Web **à threads** (révise « sans threads si possible » de D-216) ; hébergement sur notre nginx avec COOP/COEP | 0 % de sous-alimentation audio contre 13 % (titre) à 93 % (guichet) sans threads ; le site est déjà auto-hébergé (D-090) | sans threads + latence 150 ms (0 % à 30 i/s mais 70 % à 3 i/s, et +150 ms sur chaque son) |
| D-B | `project.godot` : `[audio] general/default_playback_type.web=0` (**Stream**, ne vaut que pour le Web) — **à appliquer par le propriétaire** (Orchestrateur ou lot A) | Le mode Sample retire limiteur, **son mono (accessibilité)**, ducking, hygiaphone, chaîne radio des annonces, `Muffle` de pause ; mesuré en Stream + threads : 0,1 % de sous-alimentation | garder Sample (rendu sonore différent du natif, option mono inopérante) |
| D-C | Qualité **Auto = Moyen sur le Web** (`Settings.graphics_quality_level()` : `is_steam_deck() or OS.has_feature("web")`) — `scripts/autoload/settings.gd`, lot A | Le Web n'a que le rendu Compatibility ; Bas ≈ 2× moins cher qu'Élevé ; GPU des joueurs inconnu | Auto = Bas (perte visuelle sans mesure GPU) ; Élevé |
| D-D | Masquer **QUITTER** au titre (et « Quitter le jeu » s'il existe ailleurs) quand `OS.has_feature("web")` — `scenes/main/main.gd`, lot A | `get_tree().quit()` dans un navigateur arrête le moteur et laisse un canevas noir | — |
| D-E | Version Web = **démo seulement** à la 1.0 ; planches des cinématiques exclues du paquet Web | 42 Mo ; le jeu complet ajouterait 12 Mo de planches (et demanderait le stress D-083 sur le Web) | jeu complet en ligne |

## 8. Limites et suites

- **Aucun GPU réel mesuré** : à faire sur une machine de bureau (Chrome + GPU intégré récent) et un portable d'entrée de gamme, en Auto et en Bas, J1 et J5 (`node tools/smoke_web.js --gl=…` hors conteneur, ou à la main avec l'overlay de Chrome) ; critère : ≥ 30 images/s au guichet.
- Chromium seul (Firefox / Safari non installés dans le conteneur).
- Le moteur pèse 37 Mo à lui seul : un modèle d'export personnalisé (modules inutilisés retirés, `wasm-opt`) gagnerait 25–35 % mais demande de compiler Godot avec Emscripten : hors périmètre M15.
- Étiquettes de touches : sur le Web, la disposition réelle (AZERTY) n'est pas connue ; les invites montrent la touche physique QWERTY (Q d'interroger s'affiche « Q » même sur AZERTY, où la touche porte « A »).
- Vu pendant les tests en anglais (lot A/B) : au titre de la démo, « Dans le jeu complet. » n'est pas traduit ; invites « ESPACE » en anglais (table `NAME_KEYS` en cours).
- Plein écran, redimensionnement à chaud et onglet en arrière-plan non testés.
- Chemin retenu : `/play/` (D-218, D-220), aligné sur le site (`site/nginx.conf`, variable `PUBLIC_WEB_DEMO_URL`).
