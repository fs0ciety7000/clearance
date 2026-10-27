# CLEARANCE

> *Halcyon Gate, 2187. Station orbitale du Consortium. Vous êtes l'agent de contrôle au guichet d'entrée. Chaque visage, chaque hologramme, chaque règle compte.*

Jeu 3D stylisé cyberpunk inspiré de *Papers, Please*, développé avec **Godot 4**. Le joueur vérifie l'identité des passagers grâce à des documents holographiques, applique des règles qui changent chaque jour, et affronte des dilemmes moraux sous la pression du temps.

## État du projet

**Phase : production — campagne complète jouable (jours 1 à 10, 7 fins).** Jalons livrés : M1 Fondations · M2 Documents & règles · M3 Générateur & apparences · M4 Interface de comparaison + guichet 3D · M5 Boucle de jour (scoring, soirée, sauvegarde) · M6 Passager final (Kenney + Quaternius) et audio · M7 Jours 4–10 (détention, objets glissés, avis de recherche, Lucioles, soirées à choix, fins).

Captures : [guichet J3](docs/mockups/m6_day3_autoplay.png) · [enveloppe J4](docs/mockups/m7_envelope.png) · [fin « Rendre l'air »](docs/mockups/m7_end_f5.png) · [interface](docs/mockups/m4_day.png) · [Steam Deck](docs/mockups/m4_day_deck.png) · [briefing](docs/mockups/m5_briefing.png) · [soirée](docs/mockups/m5_evening.png)

## Documentation

| Fichier | Contenu |
|---|---|
| [`GDD.md`](GDD.md) | Game design : boucle, économie, anomalies, progression J1–J10, fins |
| [`LORE.md`](LORE.md) | Univers : Halcyon Gate, Consortium, origines, Lucioles, implants, langue Tessar |
| [`AGENTS.md`](AGENTS.md) | Rôles du studio, propriété des fichiers, règles de collaboration |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Couleurs, typographie, composants, effets holographiques |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Structure Godot, modèle de données, moteur de règles, générateur |
| [`docs/UI_FLOW.md`](docs/UI_FLOW.md) | Boucle de jeu, layout, flux de comparaison des documents |
| [`docs/mockups/comparison.html`](docs/mockups/comparison.html) | Maquette interactive de l’écran de comparaison (ouvrir dans un navigateur, touches 0–4) · captures : [arrivée](docs/mockups/arrival.png), [discordance](docs/mockups/comparison.png) |
| [`docs/BOOTH_SCENE.md`](docs/BOOTH_SCENE.md) | Mise en scène du guichet : vitre, caméra, chorégraphie du passager, apparences |
| [`docs/ASSETS.md`](docs/ASSETS.md) | Sources d'assets libres, pipeline personnages/animations, registre des licences |
| [`docs/AUDIO.md`](docs/AUDIO.md) | Bus audio, liste des sons, voix courtes sous-titrées |
| [`docs/NARRATIVE.md`](docs/NARRATIVE.md) | Arcs, flags, passagers scénarisés J4–J10, soirées, 7 fins |
| [`DECISIONS.md`](DECISIONS.md) | Journal des décisions |

À venir : `docs/QA.md` (QA).

## Démarrage

1. Installer [Godot 4.7.2](https://godotengine.org/download) (version standard, GDScript — pas la version .NET).
2. Ouvrir `project.godot` depuis le gestionnaire de projets (le premier import génère `.godot/`, ignoré par git).
3. Lancer (F5) : écran titre → « Nouvelle partie » → briefing → shift au guichet → bilan → soirée.
4. Assets sources (facultatif, pour retravailler personnages/sons) : `bash tools/fetch_assets.sh` (packs CC0 dans `art_src/downloads/`, non versionnés).

En ligne de commande :

```bash
godot --headless --import          # import + détection des erreurs de parse
godot --path .                     # lance le jeu
```

Autoloads (dans cet ordre) : `EventBus` (catalogue de signaux), `Settings` (`user://settings.cfg`), `GameState` (état de campagne). Polices : Chakra Petch, Inter, JetBrains Mono (OFL) dans `assets/fonts/`.

## Tests

Framework : [GUT](https://github.com/bitwes/Gut) **9.7.1** (branche `godot_4_7`), **versionné** dans `addons/gut/` (D-008) — rien à installer. Le plugin est activé dans `project.godot` (panneau GUT dans l'éditeur).

Mettre à jour GUT : remplacer le dossier `addons/gut/` par celui d'une release compatible Godot 4.7 (AssetLib « Gut - Godot Unit Testing (Godot 4) » ou `git clone -b godot_4_7 https://github.com/bitwes/Gut` puis copier `addons/gut`), et consigner la version ici.

Lancer toute la suite en headless (config dans `.gutconfig.json` : `tests/unit/` et `tests/integration/`, préfixe `test_`) :

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit
```

Code de sortie 0 si tout est vert. Un seul fichier : ajouter `-gtest=res://tests/unit/test_game_date.gd`.

Notes :
- Les avertissements GDScript des `addons/` sont exclus par défaut (GUT n'est pas typé statiquement) ; le code du projet, lui, traite `untyped_declaration` comme une erreur.
- `push_error()` fait échouer un test GUT sauf s'il est attendu (`assert_push_error_count`).

## Feuille de route MVP

1. Structure de projet Godot 4
2. Design System documenté
3. Système de documents + règles dynamiques
4. Interface de comparaison premium
5. Générateur de passagers procédural
6. Documentation (README, AGENTS, DESIGN_SYSTEM)

## Assets

Uniquement des ressources libres : [Kenney](https://kenney.nl), [Poly Haven](https://polyhaven.com), [AmbientCG](https://ambientcg.com), [BlendKit](https://www.blenderkit.com) (licence libre), [Google Fonts](https://fonts.google.com) (OFL).
