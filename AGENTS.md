# AGENTS.md — Studio CLEARANCE

Ce fichier définit les agents (rôles spécialisés) du studio, leurs responsabilités, les fichiers dont ils sont propriétaires et les règles de collaboration. Tout agent (humain ou IA) qui intervient sur le dépôt doit le lire en premier.

## Orchestrateur

Planifie, découpe, délègue, revoit et intègre. Il n'écrit du code que pour l'intégration ou le glue code.

- Fixe le **contrat partagé** (tokens, conventions, interfaces) avant de lancer des agents en parallèle.
- Demande la validation du client sur les choix majeurs : DA, architecture, flux UI.
- Tient à jour `DECISIONS.md` (journal des décisions) et ce fichier.
- Revoit chaque livrable avant commit : cohérence avec le Design System, le Lore et l'architecture.

## Agents

| Agent | Mission | Propriétaire de | Consulte |
|---|---|---|---|
| **Lore Master** | Univers, factions, histoire de la station, chronologie, glossaire | `LORE.md`, `data/factions/` | GDD |
| **Scénariste** | Arcs narratifs, passagers scénarisés, dialogues, dilemmes moraux, fins | `docs/NARRATIVE.md`, dialogues | LORE, GDD |
| **Design System / Senior Designer** | Tokens, typographie, composants, effets holographiques, gouvernance | `DESIGN_SYSTEM.md`, `ui/theme/` | UI_FLOW |
| **UI/UX Expert** | Flux d'écrans, interactions, ergonomie, accessibilité, maquettes | `docs/UI_FLOW.md`, `docs/mockups/` | DESIGN_SYSTEM |
| **Godot Architect** | Structure du projet, modèle de données, autoloads, conventions, revue technique | `docs/ARCHITECTURE.md`, `project.godot`, `scripts/autoload/`, `scripts/core/` | tous |
| **Gameplay Systems** | Documents, moteur de règles, générateur de passagers, scoring, équilibrage | `scripts/documents/`, `scripts/rules/`, `scripts/generation/`, `data/` | ARCHITECTURE, GDD |
| **3D Designer / Asset Lead** | Guichet, station, passagers, éclairage, shaders, pipeline d'assets libres | `assets/`, `scenes/booth/`, `docs/ASSETS.md` | DESIGN_SYSTEM |
| **QA / Playtester** | Plans de test, tests GUT, sessions de playtest, rapports de bugs, lisibilité | `tests/`, `docs/QA.md` | tous |
| **Game Designer** *(ajouté)* | Boucle de jeu, progression des règles jour par jour, économie, difficulté | `GDD.md` | LORE, ARCHITECTURE |
| **Audio Designer** *(optionnel, post-MVP)* | Ambiance, sons d'UI, musique | `assets/audio/`, `docs/AUDIO.md` | DESIGN_SYSTEM |

## Règles de collaboration

1. **Planifier avant de coder.** Toute tâche non triviale commence par un plan court validé par l'Orchestrateur.
2. **Un propriétaire par fichier.** Modifier un fichier d'un autre agent = proposer le changement à son propriétaire (ou passer par l'Orchestrateur).
3. **Le Design System fait loi.** Aucune couleur, taille de police ou durée d'animation codée en dur : passer par `DS` (`ui/theme/tokens.gd`) ou le thème Godot.
4. **La logique ne dépend pas de l'UI.** `scripts/core|documents|rules|generation` n'importent jamais de scènes ; la communication passe par l'`EventBus`.
5. **Données plutôt que code.** Documents, règles, jours, factions sont des Resources `.tres` dans `data/`.
6. **Typage statique GDScript obligatoire.**
7. **Tout ce qui est testable est testé** (règles et générateur en priorité, GUT).
8. **Assets libres uniquement** (Kenney, Poly Haven, AmbientCG, BlendKit en licence libre, Google Fonts OFL). Licence et source consignées dans `docs/ASSETS.md`.
9. **Documenter les décisions** dans `DECISIONS.md` (date, décision, raison, alternatives écartées).

## Pipeline type d'une fonctionnalité

```
Game Designer (intention) → Godot Architect (interfaces) → Gameplay Systems / UI/UX (implémentation)
  → Design System (revue visuelle) → QA (tests + playtest) → Orchestrateur (revue + merge)
```
