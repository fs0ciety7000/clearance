# CLEARANCE

> *Halcyon Gate, 2187. Station orbitale du Consortium. Vous êtes l'agent de contrôle au guichet d'entrée. Chaque visage, chaque hologramme, chaque règle compte.*

Jeu 3D stylisé cyberpunk inspiré de *Papers, Please*, développé avec **Godot 4**. Le joueur vérifie l'identité des passagers grâce à des documents holographiques, applique des règles qui changent chaque jour, et affronte des dilemmes moraux sous la pression du temps.

## État du projet

**Phase : pré-production.** Design System, architecture et flux UI en cours de validation. Aucun code gameplay pour l'instant.

## Documentation

| Fichier | Contenu |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Rôles du studio, propriété des fichiers, règles de collaboration |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Couleurs, typographie, composants, effets holographiques |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Structure Godot, modèle de données, moteur de règles, générateur |
| [`docs/UI_FLOW.md`](docs/UI_FLOW.md) | Boucle de jeu, layout, flux de comparaison des documents |
| [`docs/mockups/comparison.html`](docs/mockups/comparison.html) | Maquette interactive de l’écran de comparaison (ouvrir dans un navigateur, touches 0–4) · captures : [arrivée](docs/mockups/arrival.png), [discordance](docs/mockups/comparison.png) |
| [`docs/BOOTH_SCENE.md`](docs/BOOTH_SCENE.md) | Mise en scène du guichet : vitre, caméra, chorégraphie du passager, apparences |
| [`docs/ASSETS.md`](docs/ASSETS.md) | Sources d'assets libres, pipeline personnages/animations, registre des licences |
| [`docs/AUDIO.md`](docs/AUDIO.md) | Bus audio, liste des sons, voix courtes sous-titrées |
| [`DECISIONS.md`](DECISIONS.md) | Journal des décisions |

À venir : `GDD.md` (Game Designer), `LORE.md` (Lore Master), `docs/NARRATIVE.md` (Scénariste), `docs/QA.md` (QA).

## Démarrage

1. Installer [Godot 4.4+](https://godotengine.org/download) (version standard, GDScript).
2. Ouvrir `project.godot` depuis le gestionnaire de projets.

## Feuille de route MVP

1. Structure de projet Godot 4
2. Design System documenté
3. Système de documents + règles dynamiques
4. Interface de comparaison premium
5. Générateur de passagers procédural
6. Documentation (README, AGENTS, DESIGN_SYSTEM)

## Assets

Uniquement des ressources libres : [Kenney](https://kenney.nl), [Poly Haven](https://polyhaven.com), [AmbientCG](https://ambientcg.com), [BlendKit](https://www.blenderkit.com) (licence libre), [Google Fonts](https://fonts.google.com) (OFL).
