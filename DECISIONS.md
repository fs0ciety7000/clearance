# DECISIONS.md — Journal des décisions

Statuts : 🟡 proposé (en attente de validation client) · 🟢 validé · 🔴 rejeté

| # | Date | Décision | Statut | Raison | Alternatives écartées |
|---|---|---|---|---|---|
| D-001 | 2026-10-27 | Palette : fond noir profond, cyan = hologramme/info, jaune = Consortium/CTA, magenta = anomalie, ambre = alerte, rouge/vert = refus/approbation | 🟡 | Chaque couleur porte un sens unique ; lecture instantanée sous pression temporelle | Jaune comme couleur d'alerte (conflit avec la marque) |
| D-002 | 2026-10-27 | Typographies : Chakra Petch (titres), Inter (UI), JetBrains Mono (données) | 🟡 | Gratuites (OFL), très lisibles, cyberpunk sans tomber dans l'illisible | Orbitron (peu lisible en petit), Rajdhani |
| D-003 | 2026-10-27 | Godot 4.4+, GDScript typé, renderer Forward+ | 🟡 | Écosystème mature, pas de dépendance .NET | C# (complexifie l'export web/build) |
| D-004 | 2026-10-27 | Architecture data-driven (Resources `.tres`) + EventBus + logique découplée de l'UI | 🟡 | Règles et documents éditables sans code ; testable | Logique dans les scènes |
| D-005 | 2026-10-27 | Générateur « à vérité terrain » : passager valide puis injection d'anomalies typées, RNG seedée | 🟡 | Réponse correcte connue → scoring juste, tests déterministes. **Amendement (Godot Architect)** : le verdict attendu est recalculé par le moteur de règles sur le cas final (`CaseKey`), jamais déduit des anomalies injectées ; vérifié par tests sur 1 000 seeds | Génération aléatoire puis validation a posteriori |
| D-007 | 2026-10-27 | Documents et Rulebook en surcouche 2D au-dessus de la scène 3D ; la projection 3D est réservée aux écrans décoratifs | 🟡 | Lisibilité maximale du texte | Documents en 3D projetés sur le bureau |
| D-008 | 2026-10-27 | Sauvegarde en JSON versionné (jamais de `.tres` dans `user://`) ; GUT versionné dans `addons/gut` | 🟡 | Sécurité (un `.tres` peut exécuter du code) ; CI reproductible | — |
| D-006 | 2026-10-27 | Flux de comparaison : « Mode Inspection » champ A ↔ champ B (à la Papers, Please) | 🟡 | Interaction active, lisible, fait sentir le travail d'enquête | Voir `docs/UI_FLOW.md` pour les alternatives |
