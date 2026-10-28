# QA.md — Passe QA globale (campagne J1–J10)

> Propriétaire : **QA / Playtester** · Version du jeu : `0.7.0-m7` (sauvegarde v3) · Godot 4.7.2 · GUT 9.7.1
> Passe du 27.10.2026, sur `main` après les commits « Narration : écarts M7 corrigés » et « ARCHITECTURE rév. 3 ».
> **Passe Acte II du 28.10.2026** (`0.8.1` + M8 A/B, sauvegarde v4, 515 tests) : voir [§12](#12-passe-qa-acte-ii-j10j20) — bugs QA-019 à QA-031.
> Ce document liste les bugs trouvés ; **QA ne corrige pas le code de jeu** : chaque bug nomme le fichier suspecté et l'agent propriétaire (AGENTS.md).

## Sommaire

1. [Méthode](#1-méthode)
2. [Campagnes automatiques](#2-campagnes-automatiques)
3. [Passe visuelle](#3-passe-visuelle)
4. [Robustesse](#4-robustesse)
5. [Perf indicative](#5-perf-indicative)
6. [i18n](#6-i18n)
7. [Matrice de couverture](#7-matrice-de-couverture)
8. [Liste des bugs](#8-liste-des-bugs)
9. [Lisibilité, UX, design](#9-lisibilité-ux-design)
10. [Recommandations priorisées](#10-recommandations-priorisées)
11. [Rejouer la passe](#11-rejouer-la-passe)
12. [Passe QA Acte II (J10–J20)](#12-passe-qa-acte-ii-j10j20)

---

## 1. Méthode

| Volet | Outil | Ce qui est vérifié |
|---|---|---|
| Suite existante | `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit` | 414/414 avant la passe ; sortie moteur (warnings, fuites) |
| Campagne **réelle** | `tools/qa_campaign.gd` (lancé par `tools/qa_boot.gd`) | Vraie `day.tscn` (booth 3D, `ComparisonUI`, écrans, `reload_current_scene`) jouée J1→fin par le bot `--autoplay`, ×10 (`Engine.time_scale`) ; à chaque soir : sauvegarde automatique relue = `GameState` ; solde dans des bornes ; épilogue sans clé brute ; blocage de phase (garde-fou 7 min/jour) |
| Campagne **simulée** | `tools/balance_sim.gd` (existant) | 7 préréglages × 4 précisions × 50 graines : fins F1–F7 atteignables |
| Visuel | `xvfb-run … --rendering-driver opengl3 --write-movie` | 41 captures réelles de chaque écran en 1920×1080 et 1280×800 (`override.cfg` temporaire), options extrêmes |
| Mise en page | `tests/integration/test_qa_layout.gd` | Bouton principal de chaque écran dans l'écran, J1–J10, 1080p et Deck (canevas 1920×1200, plancher de texte) |
| i18n | script d'audit (clés `UiText.t/tf/plural`, `tr`, `*_key` des `.tres` et `.tscn`) | Clés manquantes, orphelines, sous-titres > 90 car., typographie, gabarits `%s` |
| Robustesse | `tests/integration/test_qa_robustness.gd`, `test_qa_saves.gd`, `test_qa_screens.gd` | Spam Suivant / tampons / Échap, tampon maintenu pendant la pause, sauvegarde à chaque soir J1–J9, sauvegardes corrompues, reprise |
| Générateur | `tests/unit/test_qa_generation.gd` | Homonymes des personnages scénarisés |
| Perf | `tools/qa_perf.gd` | Temps moyen / p95 par image au guichet, rendu logiciel |

**Convention des tests de non-régression** : un bug reproductible a un test qui appelle `pending("QA-xxx : …")` tant qu'il est présent (la suite reste verte, GUT liste les `pending` dans son résumé) et qui **passe** une fois corrigé. Après correction, l'auteur du correctif retire la branche `pending` (le test devient une assertion stricte) et passe le bug à ✅ ci-dessous.

**Sévérités** : **Bloquant** (empêche de jouer / de finir sans contournement connu du joueur) · **Majeur** (fausse une décision, perd des données, rend un écran inutilisable sur une cible D-023) · **Mineur** (gêne, incohérence, contournable) · **Cosmétique**.

---

## 2. Campagnes automatiques

### 2.1 Campagnes réelles (`day.tscn`, bot `--autoplay`, booth 3D)

Le bot de démonstration ne voit que l'écran : visière, visage ↔ photo, expirations, données croisées, puis REFUSÉ s'il a trouvé une discordance, sinon APPROUVÉ (il ne compare jamais les avis de recherche, n'utilise pas DÉTENTION, laisse les objets glissés au refus automatique). Les choix du soir viennent du `SimProfile` indiqué (sinon choix par défaut, D-058).

| Graine | Profil (soirées) | Fin | Jour | Solde final | Conformité | Problèmes détectés |
|---|---|---|---|---|---|---|
| 7 | default | **F5** Rendre l'air (Veilleurs) | J10 | −60 ₵ | 68 % | — |
| 11 | loyal | **F7** Le guichet rouvre | J10 | −45 ₵ | 66 % | `d07_school:pay` impossible (fonds) |
| 23 | luciole | **F2** Réaffectation | soir J9 | −4 ₵ | 71 % | `d08_neighbor:help` impossible (fonds) |
| 31 | mercenary | **F5** | J10 | −30 ₵ | 67 % | (le bot rend les enveloppes : profil réduit aux soirées) |
| 42 | drift | **F5** | J10 | −25 ₵ | 67 % | `d09_drift:buy` impossible (fonds) |
| 5 | `--approve-all` | **F2** | soir J4 | −131 ₵ | 34 % | — |
| 99 | default | **F2** | soir J9 | −4 ₵ | 68 % | — |

- **7 campagnes, 64 jours joués dans la vraie scène : aucune `SCRIPT ERROR`, aucun `push_error`, aucun timeout de phase (`DayController: timeout …`), aucun blocage, aucune clé brute dans les épilogues.** Les seules sorties moteur sont les fuites de sortie (QA-016).
- **Sauvegarde relue à chaque soir = état du jeu** : 55 soirs contrôlés (`_check_save_roundtrip`), 0 écart ; sauvegarde bien effacée à la fin (D-041).
- **Déterminisme** : graine 7 rejouée deux fois → mêmes lignes `QA_DAY` à l'identique.
- Profil de jeu du bot : 6/8 au J1 (deux refus d'un document manquant non détectés), 90–100 % aux J2–J3, puis 40–70 % dès le J5 (bio-scan, motifs, implants hors de sa portée) → amendes escaladées, solde négatif dès le J6 dans 5 campagnes sur 7. Voir §9 (F5 « par accident »).

### 2.2 Campagnes simulées (`tools/balance_sim.gd`, 50 graines, graine 1)

`godot --headless --script res://tools/balance_sim.gd -- --seeds=50 --seed=1 --profiles=0.6,0.8,0.95,1.0 --presets=default,loyal,luciole,mercenary,drift,negligent,evicted`

| Préréglage | 60 % | 80 % | 95 % | 100 % |
|---|---|---|---|---|
| `default` | F2 46 · F3 38 · F7 12 · F1 4 | F7 90 · F4 8 · F2 2 | F4 94 · F7 6 | F4 100 |
| `loyal` | F2 44 · F3 40 · F7 16 | F7 92 · F4 8 | F4 96 · F7 4 | F4 100 |
| `luciole` | F2 58 · F3 40 · F5 2 | F5 86 · F1 6 · F2 4 · F3 4 | F5 88 · F1 12 | F5 86 · F1 14 |
| `mercenary` | F1 50 · F2 26 · F3 24 | F1 100 (audit J9) | F1 100 | F1 100 |
| `drift` | F2 46 · F3 38 · F7 14 · F1 2 | F6 50 · F7 48 · F2 2 | F6 100 | F6 100 |
| `negligent` | F3 66 · F2 34 | F3 100 (J6) | F3 100 | F3 100 |
| `evicted` | F2 100 (J3) | F2 100 | F2 100 | F2 100 |

**Les sept fins sont atteignables** par une politique de jeu explicite (F1 `mercenary`, F2 `evicted`, F3 `negligent`, F4 `default` ≥ 95 %, F5 `luciole`, F6 `drift` ≥ 95 %, F7 `default` 80 %), conformément à `test_m7_campaign.gd::test_simulated_profiles_reach_every_ending`. Dans la vraie scène, F2, F5 et F7 ont été atteintes par le bot ; F1/F3/F4/F6 ne sont pas accessibles au bot (il ne garde pas d'enveloppe, ne sait pas DÉTENIR ; foyer jamais entièrement perdu en 10 jours avec les soirées par défaut).

---

## 3. Passe visuelle

Captures réelles (OpenGL 3 / llvmpipe sous xvfb, `--write-movie`, dernière image conservée), graine 3, en **1920×1080** et **1280×800** (Steam Deck : canevas logique 1920×1200 à l'échelle 2/3, plancher de texte 18 px logiques). Seules les captures montrant un bug sont versionnées dans `docs/qa/`.

| Écran | 1080p | Deck | Constat |
|---|---|---|---|
| Titre | ✅ | ⚠️ | Texte minuscule au Deck (QA-004) ; mention de version périmée (QA-013) |
| Briefing J1 | ✅ | ❌ | Deck : colonne de droite et bouton coupés à droite (QA-001) |
| Briefing J4 / J7 / J10 | ❌ | ❌ | « PRENDRE SON POSTE » sous l'écran dès le J4 (QA-001) ; « Noa · 8 ans » après ses 9 ans (QA-014) |
| Guichet J1 (carte d'identité) | ⚠️ | ✅ | Bas de la carte (bande MRZ) masqué par la barre d'outils (QA-015) |
| Guichet J4 + enveloppe | ✅ | ⚠️ | La carte « Glissé avec les papiers » recouvre le champ Émetteur de la carte d'identité (QA-015) |
| Citation (ticket) | ✅ | ⚠️ | Ticket coupé à droite au Deck (QA-009) |
| Détention + escorte J7 | ✅ | ❌ | Barre d'outils coupée sous l'écran au Deck (QA-011) ; ticket coupé (QA-009) |
| Rulebook : Avis de recherche J10 (Mode Inspection) | ✅ | ✅ | Dense mais lisible ; fil magenta correct |
| Rulebook : Origines / Implants / Symboles / Sceaux | voir §3.1 | | |
| Bilan J3 / J7 | ✅ | ✅ | Registre défilant ; ticket d'avertissement lisible |
| Soirée J1 / J4 (foyer malade) / J8 / J9 (audit, Ilan, Okonkwo) | ✅ | ✅ | Étapes « 1 / 3 » lisibles ; bouton VALIDER grisé tant qu'une décision manque (voulu, D-061) |
| Pause / Options | ✅ | ✅ | Options : « Réduire les animations » trouvé ACTIVÉ sans action du joueur (QA-006) |
| Fins F1–F7 | voir §3.1 | | |

### 3.1 Captures complémentaires

| Écran | Constat |
|---|---|
| Rulebook Origines (J6, 1080p) | ✅ lisible ; onglets « Bulletins » sur deux lignes |
| Rulebook Implants (J6, Deck, 4 documents) | ⚠️ le panneau Rulebook déborde à droite (« Tab », « Procédures ·1 », « ] » coupés) depuis l'ajout des onglets M7 (QA-009) ; documents empilés lisibles |
| Rulebook Symboles (J7, 1080p) | ✅ |
| Fins F4 (Deck) et F5 Veilleurs (1080p), `--reduce-motion` | ✅ épilogue, traces, tableau et « RETOUR AU TITRE » visibles ; date fixe « JEUDI 22.03.2187 » (QA-010) |

Non capturés après le redémarrage du conteneur (lots perdus) : fins F1–F3/F6/F7 en image, `text_scale` 1,5 et `fx_intensity` 0 en image. Couverture de substitution : `test_qa_layout` construit **les sept fins** et **les dix briefings** en 1080p et au Deck et vérifie le bouton principal ; `text_scale` 1,5 reste à capturer (§10).

## 4. Robustesse

| Scénario | Résultat | Test |
|---|---|---|
| Sauvegarde automatique relue à chaque soir J1–J9 (soirées par défaut, politique ~75 %) | ✅ identique (`to_save_dict` JSON) | `test_qa_saves::test_every_evening_save_roundtrips` |
| Idem dans la vraie scène, 55 soirs sur 7 campagnes | ✅ | `tools/qa_campaign.gd` |
| Fichiers corrompus : vide, `{`, `null`, `[]`, binaire, version texte, clés manquantes | ✅ refusés sans plantage (warning) | `test_qa_saves::test_garbage_files_are_refused_without_crash` |
| Types internes faux (foyer, historique, jauges texte, mémoire) | ✅ chargé, valeurs par défaut, briefing construit | `test_qa_saves::test_wrong_inner_types_load_safely` |
| Sauvegarde au J11 / J99 | ❌ acceptée → titre « CONTINUER — JOUR 99 », scène vide | QA-003 |
| Reprise de la scène au J6 depuis une sauvegarde | ✅ | `test_qa_saves::test_scene_resumes_from_a_loaded_save` |
| Spam « Suivant » (UI, EventBus, action ×12) | ✅ un seul passager appelé | `test_qa_robustness` |
| Spam de tampons sur un cas (5 verdicts) et tampon tardif | ✅ un seul verdict (le premier) | `test_qa_robustness` |
| Appuis brefs répétés sur V / X (sans maintien) | ✅ aucun tampon | `test_qa_robustness` |
| Échap ×7 puis ×1 | ✅ état pause ⇔ arbre en pause cohérent | `test_qa_robustness` |
| Tampon maintenu, Échap, relâché pendant la pause | ❌ verdict posé à la reprise | QA-005 |
| Réglage temporaire (`--reduce-motion`, tests) puis pause | ❌ écrit dans `settings.cfg` | QA-006 |
| `text_scale` 1,5 ; `fx_intensity` 0 ; `reduce_motion` | voir §3.1 | captures `ts15_*`, `fx0_*` |
| `--no-booth` (debug) | ❌ `SCRIPT ERROR` à chaque image | QA-012 |

---

## 5. Perf indicative

`xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_perf.gd --screen=shift --day=7 --seed=3` (guichet du J7, premier passager, 12 s de chauffe, 10 s de mesure, 1920×1080, fenêtre xvfb) :

| Mesure | Valeur |
|---|---|
| Rendu | **llvmpipe** (LLVM 20, rendu 100 % CPU, 4 cœurs) — **non représentatif d'un GPU** |
| Image moyenne / p95 | **252 ms / 269 ms** (≈ 4 i/s) |
| Temps `process` (Godot, inclut l'attente du rendu) | 261 ms ; physique 0,5 ms |
| Appels de dessin / primitives par image | **382** / 39 300 |
| Mémoire vidéo | 73 Mo |

Lecture : le coût CPU de la logique est négligeable (physique < 1 ms, campagnes headless à ×10 sans retard) ; tout le temps part dans la rastérisation logicielle. Le seul chiffre transposable est le **nombre d'appels de dessin (≈ 380)**, élevé pour la cible Steam Deck / PC d'entrée de gamme : à mesurer sur matériel réel (budget à fixer par le Godot Architect et le 3D Designer ; pistes : `MultiMesh` des imposteurs déjà en place, fusion des panneaux du décor, atlas d'UI).

---

## 6. i18n

Audit par script (clés littérales de `UiText.t/tf/has/plural`, `tr()`, champs `*_key` et listes de clés des `.tres`/`.tscn`), revérifié après le commit du Scénariste `0a180d6` :

| Contrôle | Résultat |
|---|---|
| Clés de `fr.csv` | 1 146, **aucun doublon, aucune valeur vide** |
| Clés littérales utilisées par le code et les données | 513 — **0 manquante** (les 15 « manquantes » brutes sont des gabarits dynamiques : `end_text_%s`, `hh_role_%s`, `rb_implant_%s_*`, `react_`, `trait_`, `val_`…) |
| Familles dynamiques vérifiées à la main | `end_trace_<drapeau>` (43/43), `react_*` (4), `trait_*` (6), `hh_name/role/note_*`, `opt_*` (Settings), `rb_implant_*` (5 familles) : complètes. `end_text_<fin>` n'existe que pour `demo_complete`, F2, F3 : sans effet (les fins M7 passent par `EndingService.epilogue`) |
| Clés jamais lues en jeu (candidates orphelines, à confirmer par le Scénariste) | `issuer_bureau_continuite`, `issuer_autorite_transit`, `issuer_clinique_meridian`, `briefing_eyebrow`, `briefing_title`, `briefing_hint` (briefing M4), `spk_dora`, `rb_origins_drv_birth` (dates « 00.00 » des Dérivants non implémentées, GDD §13) — ✅ revu : `briefing_eyebrow/title/hint` supprimées ; `issuer_*` gardées (lues par `UiText.issuer_name`, `issuer_%s`) ; `spk_dora` et `rb_origins_drv_birth` gardées (prévues NARRATIVE §4.10 / §8) |
| Gabarits `%s`/`%d` : nombre d'arguments code ↔ CSV | ✅ cohérent |
| Typographie FR (guillemets « » appariés, espaces, doublons de mots, `...`) | ✅ rien à signaler |
| Sous-titres > 90 caractères | 4 répliques d'Okonkwo au J1 (`okonkwo_j1_discordance` 107, `okonkwo_j1_open` 104, `okonkwo_j1_citation` 99, `okonkwo_j1_inspect` 96) ; `sc19_wren_note` (130) est un mot glissé, pas un sous-titre. En 1080p elles tiennent sur une ligne, au Deck elles débordent de la bande 3D : à couper en deux répliques (Scénariste) — ✅ resserrées à ≤ 90 caractères ; *lumika* ajouté par `arrival_text` désormais entre chevrons ‹Lumika.› (D-062) |
| Clés brutes à l'écran (`end_text_…`, `line_…`) | **aucune** sur les 41 captures ni dans les 7 épilogues des campagnes réelles |
| Textes périmés | `title_version` « Vertical slice M5 — Jours 1 à 3 » (QA-013) ; `hh_role_noa` « 8 ans » après l'anniversaire du J4 (QA-014) ; `end_date` fixe (QA-010) |

Note : `fr.fr.translation` n'est pas versionné (D-040) ; après une modification de `fr.csv` il faut `godot --headless --import`, sinon le jeu affiche l'ancien texte (constaté pendant la passe : réplique de Ravel encore en « … » anglais avant réimport).

---

## 7. Matrice de couverture

| Domaine | Auto (GUT) | Campagne réelle | Capture 1080p | Capture Deck | Manuel restant |
|---|---|---|---|---|---|
| Titre / options / continuer | ◐ (QA-004) | — | ✅ | ✅ | manette |
| Briefing J1–J10 | ✅ mise en page 20 cas | ✅ 64 | ✅ J1/4/7/10 | ✅ J1/4/7/10 | — |
| Guichet : arrivée, inspection, interrogatoire, tampons | ✅ (existant + spam) | ✅ 64 jours | ✅ | ✅ | ressenti, manette |
| Objets glissés, DÉTENTION, escorte | ✅ (existant) | ◐ refus auto seulement | ✅ | ✅ | garder / signaler à la main |
| Rulebook : règles, documents, origines, implants, symboles, sceaux, avis | ✅ (existant) | ✅ | ✅ (sauf sceaux) | ✅ implants, avis | onglet Sceaux en image |
| Bilan, citations | ✅ | ✅ | ✅ | ✅ | — |
| Soirées J1–J9, choix, mot des Lucioles | ✅ (+ QA-008) | ✅ 55 soirs, 5 profils | ✅ J1/4/8/9 | ✅ J1/4/9 | — |
| Fins F1–F7 | ✅ simulées + mise en page | ✅ F2, F5, F7 | ✅ F5 | ✅ F4 | F1/F3/F6 jouées à la main |
| Sauvegarde / reprise / corruption | ✅ | ✅ 55 relectures | — | — | — |
| Pause, Échap, spam | ✅ | — | ✅ | ✅ | — |
| Accessibilité : `text_scale` 1,5, FX 0, effets réduits | ◐ (`reduce_motion` seulement) | — | ✗ | ✗ | **à faire** |
| Audio | ✅ (existant) | sans erreur | — | — | écoute réelle |
| Perf | — | ×10 headless sans retard | llvmpipe | — | **GPU réel / Steam Deck** |

---

## 8. Liste des bugs

Statut : 🔴 ouvert (aucun corrigé pendant la passe). « Test » = test de non-régression `pending` tant que le bug existe.

| ID | Sév. | Titre | Agent propriétaire | Test |
|---|---|---|---|---|
| QA-001 | **Bloquant** | ✅ Corrigé (commit à venir) — Briefing sans défilement : « PRENDRE SON POSTE » hors écran dès le J4 (1080p) et dès le J1 au Deck : contenu en `ScrollContainer` (barre réservée), barre d'action fixe sous un filet, défilement ↑ ↓ / pages au clavier-manette, indication « Suite du bulletin » tant que du contenu reste sous le pli ; libellés repliés (tuiles, commandes, rôles, pied) pour tenir au Deck | UI/UX Expert (+ Design System) | `test_qa_layout` |
| QA-002 | **Majeur** | ✅ Corrigé — Passagers générés homonymes des personnages scénarisés (seconde « Mira Vasquez-Orlov », « Corentin Ravel » au guichet…) : `NamePool.reserved_full_names` + noms de famille distinctifs réservés, calculés par `build_data.gd` ; prénom remplacé sans tirage | Gameplay Systems | `test_qa_generation` |
| QA-004 | **Majeur** | ✅ Corrigé (commit à venir) — Écran titre sans plancher de texte Steam Deck (légendes ≈ 8 px physiques) : `main.gd` applique `ThemeBuilder.min_px_for` comme `ScreenBase` (reconstruit au redimensionnement) | UI/UX Expert | `test_qa_layout` |
| QA-005 | **Majeur** | ✅ Corrigé (commit à venir) — Tampon maintenu relâché pendant la pause → verdict posé à la reprise : `StampButton` annule tout maintien à `NOTIFICATION_PAUSED`, à la perte de focus de l'application et quand il est masqué | UI/UX Expert | `test_qa_robustness` |
| QA-011 | **Majeur** | ✅ Corrigé (commit à venir) — Deck, dès le J7 : barre d'outils coupée sous l'écran quand « SUIVANT » est affiché : compaction par paliers selon la largeur (légende du tiroir, ligne d'aide des tampons — gardée en infobulle —, touches d'Inspection / Interroger, puis ligne d'état) | UI/UX Expert | `test_qa_layout` |
| QA-003 | Mineur | ✅ Corrigé — Sauvegarde au-delà du dernier jour acceptée → scène de jour vide : `validate` borne le jour à `SaveService.last_day()` (refusée, titre sans « Continuer ») | Godot Architect | `test_qa_saves` |
| QA-006 | Mineur | ✅ Corrigé — Réglage temporaire (`--reduce-motion`, tests GUT) persisté par la fermeture de la pause : `Settings.set_session_value()` jamais écrit ; suite GUT sur `user://test_settings/` (`gut_pre_run.gd`) | Godot Architect | `test_qa_robustness`, `test_settings` |
| QA-008 | Mineur | ✅ Corrigé (commit à venir) — Soirée : prime de signalement (+10 ₵) absente du solde affiché et des postes payables : `EveningScreen.report_bonus` (ligne « Prime de signalement », « Disponible ce soir », postes et solde après la soirée), sans changement de logique (la prime reste créditée par `Campaign.decide_luciole_note`) | UI/UX Expert (+ Gameplay Systems) | `test_qa_screens` |
| QA-009 | Mineur | ✅ Corrigé (commit à venir) — Deck : ticket d'infraction et panneau Rulebook coupés au bord droit : libellés du ticket repliés ; « Tab » du Rulebook déplacé en pied à côté de « [ » « ] » ; Rulebook, file et toasts ancrés à droite (`GROW_DIRECTION_BEGIN`) | UI/UX Expert | capture |
| QA-012 | Mineur | ✅ Corrigé — `--no-booth` : `SCRIPT ERROR` à chaque image (`AudioDirector.is_voice_active`) : `live_passenger_audio()` purge les émetteurs libérés sans affectation typée | Audio Designer | `test_audio_director` |
| QA-015 | Mineur | ✅ Corrigé (commit à venir) — Carte d'identité plus haute que le plan de travail en 1080p (bande MRZ sous la barre) ; carte « Glissé avec les papiers » sur le champ Émetteur : documents mis en place après une passe de mise en page à une échelle d'ajustement (`Workbench.fit_scale`, ≥ 0,72, zoom de lecture par-dessus) ; colonne libre à droite pour les objets glissés reçus avec les papiers, sinon place la moins couverte | UI/UX Expert (+ Design System) | capture |
| QA-016 | Mineur | ✅ Corrigé — Fuites à la sortie de chaque exécution : « 2 ObjectDB instances leaked », « 1 resources still in use » (cause : `FlagCondition.any_of: Array[FlagCondition]`, référence circulaire du script → `Array[Resource]`) ; `test_booth_actor` laisse 180 orphelins (attente d'une image). Reste : quitter en plein shift (`--quit-after`) peut encore laisser des flux audio en cours (intermittent ; lecteurs arrêtés à la sortie) | Godot Architect / 3D Designer | log |
| QA-017 | Mineur | ✅ Corrigé — `--seed` / `--day` réappliqués à chaque `reload_current_scene` : partie relancée au J1 à chaque soir (`DebugArgs` : arguments `ONE_SHOT` une fois par processus ; tous inactifs en *release*) | Godot Architect | `test_debug_args` |
| QA-018 | Mineur | ✅ Corrigé — `SaveService.save` supprime l'ancienne sauvegarde avant de renommer le `.tmp` : un arrêt entre les deux perd la sauvegarde (le `.tmp` n'est jamais relu) → renommage par-dessus (`.bak` si la plateforme refuse), `.tmp` / `.bak` relus en secours | Godot Architect | `test_qa_saves` |
| QA-010 | Cosmétique | ✅ Corrigé (commit à venir) — Écran de fin daté « JEUDI 22.03.2187 » même pour une fin anticipée : date du dernier jour de `history` (`end_date_day`, repli `end_date`) | UI/UX Expert + Scénariste (`end_date`) | `test_qa_screens` |
| QA-013 | Cosmétique | ✅ Corrigé (commit à venir) — Titre : « Vertical slice M5 — Jours 1 à 3 » → « Démo · v0.8.0 » (`application/config/version`, repli « Démo ») | Scénariste (`title_version`) | — |
| QA-014 | Cosmétique | ✅ Corrigé (commit à venir) — « Noa · 8 ans » dans le foyer après son anniversaire (J4) : variantes `hh_role_<id>_from_j<N>` (`hh_role_noa_from_j4` « 9 ans ») | Scénariste (`hh_role_noa`) | — |

Total : **1 bloquant, 4 majeurs, 9 mineurs, 3 cosmétiques**. (QA-007, « écran de fin hors écran au Deck », retiré : non reproduit sur le vrai canevas 1920×1200 ; le test reste comme garde.)

### Détail

**QA-001 — Briefing : bouton principal hors écran** · Bloquant · `scripts/ui/briefing_screen.gd` (`_build`, aucune `ScrollContainer`) · capture `docs/qa/QA-001.png` (J7, 1080p), `docs/qa/QA-001-deck.png` (J1, Deck)
1. Nouvelle partie, jouer jusqu'au J4 (ou `godot --path . res://scenes/main/day.tscn -- --day=7`).
2. Le briefing liste toutes les règles en vigueur (10 au J4, 22 au J10) en cartes de deux colonnes : la page mesure 1 109 px au J4 et 1 723 px au J10 pour 1 080 ; « PRENDRE SON POSTE » et le slogan sont sous l'écran. Au Deck, avec le plancher de 18 px, les libellés sur une ligne (tuiles, raccourcis) élargissent la colonne de gauche : la colonne Messages / Foyer et le bouton sortent à droite **dès le J1** (bord du bouton à x = 2 027 pour 1 920).
3. Contournement non évident : Entrée / A (le bouton a le focus). À la souris, le joueur est bloqué.
Piste : `ScrollContainer` pour les colonnes et pied de page fixe ; règles anciennes repliées (seules les nouvelles en cartes, les autres en liste compacte) ; libellés en `autowrap`.

**QA-002 — Homonymes des personnages scénarisés** · Majeur · `scripts/generation/` (tirage des noms, `CaseBuilder._post_generate` ne déduplique que contre les avis de recherche), réserves `data/names/` (générées par `tools/build_data.gd`)
Sur 40 campagnes × 10 jours, **78 passagers générés sur 4 080 (1,9 %, ≈ 2 par campagne)** portent le nom complet exact d'un personnage scénarisé : graine 3 J3 #9 « Mira Vasquez-Orlov » le jour même où la vraie Mira passe (#2) ; graine 6 « Lev Petrenko » aux J5 et J6 ; graine 3 J6 « Corentin Ravel » (l'inspecteur) ; graine 1 J8 « Mira Vasquez-Orlov ». 25 % des passagers générés partagent aussi le **nom de famille** d'un personnage (Ravel, Valcourt, Whitmore…). Casse la continuité narrative (D-057) et brouille la reconnaissance par le nom (R22).
Piste : exclure les noms complets des `ScriptedCaseDef` (et des avis) des tirages ; réserver les noms de famille des personnages majeurs.

**QA-004 — Titre sans plancher Steam Deck** · Majeur · `scenes/main/main.gd` (`ThemeBuilder.build(Settings.text_scale)` sans `min_px_for`) · `docs/qa/QA-004.png`
Lancer en 1280×800 : légende de version et sur-titre ≈ 7–8 px physiques, boutons 9 px (DS : 12 px minimum, D-026). Les écrans `ScreenBase`, la pause et `ComparisonUI` appliquent bien le plancher. Piste : même logique que `ScreenBase._apply_theme` (+ `size_changed`).

**QA-005 — Tampon maintenu à travers la pause** · Majeur · `scripts/ui/comparison_ui.gd` (`_handle_stamp_input`) / `stamp_button.gd`
1. Documents posés, maintenir X (REFUSÉ). 2. Avant 0,4 s, Échap (pause). 3. Relâcher X pendant la pause (l'UI en pause ne reçoit pas le relâchement). 4. Reprendre : le maintien continue et **le refus est posé sans que la touche soit tenue**. Même mécanisme si un écran plein cadre s'ouvre pendant un maintien.
Piste : `end_hold()` sur tous les tampons à l'ouverture de la pause / `NOTIFICATION_PAUSED` / perte de focus fenêtre.

**QA-011 — Deck : barre d'outils hors écran au J7+** · Majeur · `scripts/ui/tool_bar.gd` · `docs/qa/QA-011.png`
Deck, J7 (trois tampons), guichet en attente (« SUIVANT » affiché) : la barre passe sur deux étages, boutons Inspection / Interroger / Suivant coupés à y = 1 282 pour 1 200, texte d'aide en colonne étroite, tampons rognés. Piste : masquer le texte d'aide ou les sous-titres des tampons sous une largeur seuil ; « SUIVANT » à la place des tampons verrouillés.

**QA-003** · `scripts/core/save_service.gd` (`validate` sans borne haute). Fichier `slot_0.json` avec `current_day` 11 ou 99 → accepté ; le titre propose « CONTINUER — JOUR 99 » ; `DayController.start_day` échoue (`push_error`) et `DayScene._ready` s'arrête : écran vide, aucun moyen d'en sortir sauf Échap → titre. Piste : refuser `current_day > dernier jour` (ou rediriger vers la fin).

**QA-006** · `scripts/autoload/settings.gd` (`save_settings` écrit toutes les valeurs en mémoire), `pause_menu.gd` (`close()` sauvegarde) · `docs/qa/QA-006.png`
`--reduce-motion` (et `test_day_scene`/`test_qa_robustness`, qui posent `reduce_motion` sans persistance) puis une pause ouverte/fermée : `reduce_motion=true` est écrit dans `user://settings.cfg`. Constaté deux fois sur la machine de QA après une exécution de la suite GUT : le joueur/développeur se retrouve en « animations réduites » sans l'avoir choisi. Piste : mémoriser les valeurs persistées à part ; les tests devraient utiliser un `SETTINGS_PATH` de test.

**QA-008** · `scripts/ui/evening_screen.gd` (`_decide_luciole`), `Campaign.decide_luciole_note`
Soir du J3, mot des Lucioles, « SIGNALER AU CONSORTIUM +10 ₵ » : `GameState.credits` passe de 9 à 19 ₵, mais l'écran garde « Disponible 9 ₵ » ; les postes restent « Fonds insuffisants » alors que l'argent est là, et le « Solde après la soirée » affiché est inférieur de 10 ₵ au solde du rapport de nuit. Piste : passer la prime par l'écran (`balance += report_bonus`, `_refresh()`), ou ne la créditer qu'à la validation.

**QA-009** · `scripts/ui/comparison_ui.gd`, `citation_ticket.gd`, `rulebook_panel.gd` · `docs/qa/QA-009.png`
Deck : le ticket d'infraction déborde à droite (« G04-J02-0… », « retenue sur salai… ») ; depuis les onglets M7, le Rulebook aussi (« Tab », « Procédures ·1 », bouton « ] »). La capture M4 du Deck (`docs/mockups/m4_day_deck.png`) tenait.

**QA-012** · `scripts/audio/audio_director.gd:433` (`for pa: PassengerAudio in passenger_audio.values()` : l'affectation typée d'une instance libérée lève l'erreur avant `is_instance_valid`) ; même motif ligne 781. Avec `--no-booth` (le booth est libéré après `_attach_booth`), une `SCRIPT ERROR` par image. Risque en jeu si un acteur est libéré. Piste : itérer en `Variant` puis tester, ou purger le dictionnaire à `tree_exiting` de l'acteur.

**QA-015** · `scripts/ui/document_view.gd` / `workbench.gd` · `docs/qa/QA-015.png`
Depuis M7, la carte d'identité affiche Implants, Sceau et MRZ dès le J1 : en 1080p, sa bande de code-barres passe sous la barre d'outils (capture J1). Au Deck J4, la carte « Glissé avec les papiers » est posée sur le champ Émetteur de la carte (valeur cachée tant que l'enveloppe n'est pas tranchée). Piste : afficher les champs M7 seulement quand une règle les rend pertinents, ou ancrer la carte d'objet hors des documents.

**QA-016** · fin de toute exécution (titre seul compris) : `WARNING: 2 ObjectDB instances were leaked at exit`, `ERROR: 1 resources still in use at exit`. Sans effet joueur, mais l'`ERROR` pollue les journaux CI. `test_booth_actor::test_every_catalog_option_applies` laisse 180 nœuds orphelins (accessoires).

**QA-017** · `scripts/day/day_scene.gd` (`_ready` : `if GameState.current_day <= 0 or _args.has("seed")`). Lancé avec `--seed=N` (ou `--day=N`), chaque « JOUR SUIVANT » recharge la scène et relance une partie neuve au J1 (ou force le jour N) : campagne impossible en `--autoplay --seed`. Debug seulement ; `tools/qa_campaign.gd` contourne en posant la graine lui-même. Piste : appliquer ces arguments une seule fois (drapeau statique).

**QA-018** · `scripts/core/save_service.gd` (`save` : `remove_absolute(path)` puis `rename_absolute(tmp, path)`). Fenêtre où aucune sauvegarde valide n'existe ; `load_slot` n'essaie pas le `.tmp`. Piste : renommer par-dessus (atomique sous Linux/macOS) ou garder `slot_0.json.bak` et le relire en secours.

**QA-010 / QA-013 / QA-014** · voir §6. Pour QA-010 : `end_screen.gd` affiche la clé fixe `end_date` ; dater avec le dernier jour de `history` (F2 au soir du J4 → « VEN. 16.03.2187 »).

---

## 9. Lisibilité, UX, design

- **F5 « par accident »** (Game Designer). Le bot qui ne fait que comparer ce qu'il voit, sans jamais aider sciemment les Lucioles, finit **F5 dans 4 campagnes réelles sur 7** : chaque Luciole en infraction approuvé faute d'avoir vu la discordance vaut `lucioles_trust +1` (NARRATIVE §1), et le bot laisse passer Mira (il ne consulte pas l'avis). `balance_sim` sous-estime ce cas (ses erreurs sont tirées au hasard, pas « approuver ce qu'on n'a pas vu ») : F5 n'y apparaît qu'avec le préréglage `luciole`. À trancher : voulu (l'inattention fait le jeu des Lucioles) ou réserver la confiance aux gestes explicites (mot de passe, choix du soir).
- **Courbe J5–J6** : le bot passe de 90–100 % (J2–J3) à 40–60 % (J5–J6) ; amendes escaladées et solde négatif dès le J6 dans 5 campagnes sur 7, F2 au soir du J9 dans 2. Cohérent avec D-060 (« dure »), mais l'écart vient surtout de règles introduites par le texte (bio-scan, motifs, implants) que le Mode Inspection ne propose pas comme paires évidentes : à confirmer en playtest humain (métriques GDD §14).
- **Bloquant de fait pour la souris** (QA-001) : c'est le premier problème qu'un joueur rencontrera au J4.
- **Steam Deck** : 4 problèmes de mise en page (QA-001, 004, 009, 011) ; aucun n'apparaissait sur les captures M4/M5 — les écrans M7 (plus de règles, d'onglets, un troisième tampon) n'ont pas été revus au Deck. Recommandé : une capture Deck par écran dans la définition de « fini ».
- **Soirée** : le bouton « VALIDER ET DORMIR » grisé avec « 1 décision à prendre ce soir » en petit texte ambre : lisible en 1080p, discret au Deck ; un clic sur le bouton grisé pourrait amener à l'événement non tranché.
- **Écran de fin des captures `--screen=end`** : la fin est forcée sur un historique simulé (F4 avec 62 % et −215 ₵) — normal en debug, à ne pas utiliser comme référence visuelle.
- **Propriété des fichiers** : `scripts/ui/` et `scenes/main/` n'ont pas de propriétaire dans AGENTS.md ; les bugs d'écran sont attribués ici à l'UI/UX Expert (pipeline « UI/UX (implémentation) »). À clarifier par l'Orchestrateur.

---

## 10. Recommandations priorisées

1. **QA-001** briefing défilant (bloquant, premier contact du joueur avec les J4+).
2. **QA-005** (verdict non voulu) et **QA-002** (homonymes : cohérence narrative et avis de recherche).
3. **Passe Steam Deck** des écrans M7 : QA-011, QA-004, QA-009, puis QA-015.
4. **QA-006** avant toute session de playtest (les tests modifient les réglages de la machine) ; isoler `user://settings.cfg` dans les tests.
5. QA-008, QA-003, QA-018 (données et argent), puis QA-012, QA-016, QA-017 (journaux propres, outils de debug fiables).
6. Contenu (Scénariste) : QA-010, QA-013, QA-014, clés candidates orphelines, couper les 4 répliques d'Okonkwo > 90 caractères.
7. Game Designer : statuer sur « F5 par accident » ; Godot Architect : budget d'appels de dessin (≈ 380) à valider sur Steam Deck réel.
8. QA (suite) : captures `text_scale` 1,5 et FX 0, fins F1/F3/F6 jouées à la main, playtest humain avec les métriques GDD §14, perf sur GPU.

---

## 11. Rejouer la passe

```bash
godot --headless --import
# Suite complète (les bugs ouverts apparaissent en « pending » QA-xxx)
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit
# Campagne réelle J1–J10 (≈ 3–4 min à ×10 ; ne pas passer --seed, cf. QA-017 ; --no-booth déclenche QA-012)
godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_campaign.gd --autoplay \
    --qa-seed=7 --qa-profile=default --qa-speed=10
# Fins simulées
godot --headless --script res://tools/balance_sim.gd -- --seeds=50 --seed=1 --profiles=0.6,0.8,0.95,1.0 \
    --presets=default,loyal,luciole,mercenary,drift,negligent,evicted
# Perf indicative (rendu logiciel sous xvfb)
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/qa_boot.gd -- \
    --qa-node=res://tools/qa_perf.gd --screen=shift --day=7 --seed=3
# Capture (dernière image) ; Deck : override.cfg temporaire window_width/height_override=1280/800, à supprimer ensuite
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --write-movie /tmp/qa/f.png \
    --quit-after 300 res://scenes/main/day.tscn -- --seed=3 --day=7 --screen=detain --start-case=3 --reduce-motion
```

`tools/qa_campaign.gd` et `tools/qa_perf.gd` ont besoin des autoloads : un script `--script` est compilé avant leur enregistrement, d'où le lanceur `tools/qa_boot.gd` (à corriger dans ARCHITECTURE §15, qui indique un lancement direct et « pas de `--headless` strict » : la campagne tourne en `--headless` **avec** le booth). Les campagnes et captures écrivent dans le `user://` réel (sauvegarde effacée à la fin, `settings.cfg` lu) : ne pas lancer deux campagnes en parallèle.

---

## 12. Passe QA Acte II (J10–J20)

> Passe du 28.10.2026 sur `main` après « M8 partie B — interfaces de l'Acte II » (`bfad7e2`, 515/515 tests), sauvegarde **v4**. Même méthode qu'aux §1–§11 ; QA n'a corrigé aucun code de jeu. Après la passe : **524 tests** (515 + 9 de `tests/integration/test_qa_act2.gd`, dont 5 en `pending("QA-0xx")`), suite verte.

### 12.1 Outils (QA) ajoutés ou étendus

| Outil | Changement |
|---|---|
| `tools/qa_campaign.gd` | Ferme l'interstitiel « CHAPITRE II » comme un joueur ; une option qui termine la campagne (« Embarquer », J10) passe par la boîte « QUITTER HALCYON ? » puis CONFIRMER ; `QA_EVENING` (postes, rations, prélèvements, choix) ; `QA_DAY` + entrées imputées, refus quota, foyer, jauges `solidarite` / `registre` / `quota_overrun` ; **`--qa-reload`** : à chaque briefing d'un nouveau jour, « Quitter → Continuer » réel (`GameState.load_from_slot()` puis `reload_current_scene`) ; **`--qa-load=slot.json`** : reprend une sauvegarde réelle (migration v3 → v4 jouée dans la vraie scène). |
| `tools/qa_capture.gd` (nouveau) | Capture réelle **sans `override.cfg`** : taille de fenêtre fixée (`--qa-size=1280x800`), attente en temps réel, PNG écrit puis sortie ; `--qa-quota=5/5` (état « ATTEINT »). |
| `tests/fixtures/qa_save_v3_j9_*.json` (nouveau) | Trois **vraies** sauvegardes v3 produites par le code v0.8.1 (`3dd6ead`, soir du J9) : `loyal` (Ilan dénoncé·e : `lost` + `detained`), `drift` (laissez-passer achetés), `luciole` (Ilan soutenu·e). |
| `tests/integration/test_qa_act2.gd` (nouveau) | Non-régressions Acte II (§12.6). |

Toutes les exécutions ont tourné avec un `XDG_DATA_HOME` jetable (le `user://` réel n'est jamais touché, campagnes parallèles possibles) ; aucun fichier temporaire laissé dans le dépôt.

### 12.2 Campagnes automatiques

#### Vraie scène (`day.tscn`, booth 3D, bot `--autoplay`, 59–69 % de conformité)

| Graine | Profil (soirées) | Crédits QA | Départ | Nuit des vannes | Fin | Jour | Solde final | Conformité |
|---|---|---|---|---|---|---|---|---|
| 7 | archiviste | +1 500 | J1 | ouvertes | **F8** Le Registre | J20 | 245 ₵ | 63 % |
| 11 | solidaire | +1 500 | J1 | ouvertes | **F9** Les vitres éteintes (lumières coupées après le 10ᵉ cas) | J20 | 155 ₵ | 60 % |
| 42 | luciole | +1 500 | J1 | ouvertes | **F7** (confiance 5 < 7 : pas de F5) | J20 | 164 ₵ | 59 % |
| 3 | drift10 | +300 | J1 | ouvertes | **F6** au J10 (« Embarquer » + confirmation) | J10 | 25 ₵ | 66 % |
| 7 | default | +300 | J1 | ouvertes | **F2** | soir J14 | −41 ₵ | 64 % |
| 11 | luciole | +300 | J1 | ouvertes (Ilan dans la Soute) | **F2** | soir J14 | −91 ₵ | 61 % |
| 23 | drift (reste au J10) | +300 | J1 | ouvertes | **F3** | soir J15 | −11 ₵ | 63 % |
| 7 | loyal | — | **sauvegarde v3 réelle** (J10, Ilan dénoncé·e) | avortées | **F2** | soir J16 | −28 ₵ | 76 % |
| 5 | default | 0 | J1 | — | **F2** | soir J7 | −28 ₵ | 64 % |
| 42 | default | 0 | J1 | — | **F3** | soir J10 | −35 ₵ | 67 % |
| 7 | default | 0 | J1 | — | **F3** | soir J11 | −28 ₵ | 69 % |
| 11 | default | 0 | J1 | — | ⛔ **plantage** (signal 11) au rechargement après la soirée du J7 — rejouée à l'identique : **F3** au soir du J11, −58 ₵, 66 % (QA-030) | — | — | — |

- **13 campagnes, 166 jours joués dans la vraie scène (dont 51 de l'Acte II), 104 « Quitter → Continuer » réels (49 aux soirs J10–J19) : aucune `SCRIPT ERROR` du jeu, aucun `QA_ISSUE`** (sauvegarde relue = état, solde borné, aucun blocage de phase, aucune clé brute dans les épilogues, sauvegarde effacée à la fin). Seules sorties moteur : QA-025 ; **un plantage** non reproduit (QA-030).
- **Fins atteintes dans la vraie scène : F2, F3, F6 (J10), F7, F8, F9.** F1 (Revue du J17), F4 et F5 restent hors de portée du bot (il ne garde pas d'enveloppe, n'atteint jamais 85 % de conformité ni 7 de confiance) : couvertes par la simulation (ci-dessous) et `test_act2_campaign.gd`.
- **Migration v3 → v4** : la sauvegarde v3 « loyal » (Ilan `lost` + `detained`) reprend au J10, Ilan apparaît **MIS·E EN ATTENTE** (vivant·e, `present_count` 2), pas de ration pour Ilan, caution proposée au J12/J14/J16 ; 7 jours joués, 6 rechargements sans écart.
- **Prélèvements** : J11 et J17 = ⌊30 % × (solde − 40)⌋ à chaque fois (ex. 100 ₵ → 18 ₵ ; 190 → 45 ; 512 → 141) ; aucun ailleurs ; ligne « PRÉLEVÉE D'OFFICE » — mais note en clé brute (QA-024).
- **Rations** : votre ration toujours prélevée (+1 ₵ sans compteur), pas de ligne pour un proche absent (Soute) ou en attente ; ration non payée → ESSOUFFLÉ·E puis MALADE au 2ᵉ soir (vu sur 4 campagnes).
- **Nuit des vannes « ouverte par accident »** : 7 campagnes réelles sur 8 arrivées au soir du J10 ont ouvert les vannes (bot qui n'aide jamais sciemment les Lucioles : `lucioles_trust` 4–9 par approbations manquées, Mira non comparée à l'avis). `luciole_trust_on_breach = false` ne vaut qu'à partir du J11 : le « F5 par accident » du §9 est devenu « vannes ouvertes par accident » (Game Designer, §12.7).

#### Simulation (`tools/balance_sim.gd`, 40 graines, graine 1, 12 préréglages × 65 / 80 / 95 %)

| Préréglage | 65 % | 80 % | 95 % |
|---|---|---|---|
| `default` | F3 47,5 · F2 42,5 · F7 7,5 · F1 2,5 | F7 97,5 · F2 2,5 | F7 100 |
| `loyal` | F3 45 · F2 30 · F7 25 | F7 100 | **F4 90** · F7 10 |
| `luciole` | F2 60 · F3 37,5 · F5 2,5 | F5 80 · F1 15 · F2/F3 5 | **F5 95** · F1 5 |
| `mercenary` | F1 85 (audit J9) · F2 10 · F3 5 | F1 100 (J9) | F1 100 (J9) |
| `mercenary2` | F1 42,5 (Revue J17) · F3 37,5 · F2 20 | F1 60 · F7 37,5 | F1 47,5 · F7 52,5 |
| `drift` / `drift10` | F2/F3 92,5 · F7 7,5 | F6 55 (J20) / 57,5 (J10) | **F6 100** |
| `archiviste` | F2/F3 90 · F8 7,5 | **F8 97,5** | **F8 100** |
| `solidaire` | F2/F3 87,5 · F9 7,5 · F1 5 | **F9 97,5** | **F9 100** |
| `overrun` | F2/F3 90 · F7 5 · F1 5 | F7 92,5 · F1 5 | F7 97,5 · F1 2,5 |
| `negligent` / `evicted` | F3 (J6) / F2 (J3) | idem | idem |

**Les neuf fins F1–F9 sont atteignables** ; chiffres identiques à ACT2 §6.5 (D-080). `gen_stats` (40 campagnes × 20 jours) : invariants OK, 0 anomalie non placée, 0 re-tirage ; écarts de poids signalés en QA-026.

### 12.3 Passe visuelle (captures réelles 1920×1080 et 1280×800)

`tools/qa_capture.gd` sous xvfb (OpenGL 3 / llvmpipe), graine 3, `--reduce-motion` ; la Qualité Basse + FX 0 + texte 1,5 au Deck en §12.4. Seules les captures de bugs sont versionnées (`docs/qa/QA-0xx.png`).

| Écran | 1080p | Deck | Constat |
|---|---|---|---|
| Briefing J11 (vannes ouvertes) | ❌ | ❌ | **« msg_cons_day11_albedo » en clair** dans le bloc Bureau de Continuité (QA-019, `docs/qa/QA-019.png`) ; voix COMMISSION (bleu registre) et magenta distinctes, lisibles |
| Guichet J11, compteur « ATTEINT · 5 / 5 » | ✅ | ✅ | ambre lisible ; au Deck le sur-titre de la barre du haut tombe à « CONS… » (QA-029) |
| Guichet J12 / J13, 4 documents (+ scanner magenta) | ❌ | ❌ | **chevauchement** : expiration du permis et du bio-scan, N° ID / émetteur / sceau de la carte cachés ; au J13 la discordance N° ID carte ↔ bio-scan est sous le permis (QA-020, `QA-020.png`, `QA-020-deck.png`) |
| Guichet J14, scanner ACV-2 (SC-34, firmware) | ✅ | ⚠️ | lien ambre et pastille ✓ corrects (firmware 25.12.2186, périmé d'un jour) ; la pastille couvre le bas du bio-scan (QA-029) |
| Rulebook J12 « Codes employeurs », J13 « Registre des cargos », J17 « Révocations » + Inspection | ✅ | ✅ | lisibles, listes défilantes ; J17 : 1ᵉʳ passager « Soren Sato » le jour de la révocation de Sato (QA-022) |
| Guichet J15 (attestation d'asile) / J16 (ticket de file) | ✅ | — | ticket sans sceau, « PRÉSENTATION 10:00 » |
| Soirée J10 + « QUITTER HALCYON ? » | ✅ | ✅ | boîte lisible, focus sur RESTER ; non modale au clavier (QA-021) |
| Soirée J11, prélèvement + rations | ❌ | ❌ | **« ev_note_levy » en clair** sous le prélèvement (QA-024, `QA-024.png`) ; rations groupées lisibles, montant `%d` formaté (« 39 ₵ ») |
| CHAPITRE II | ✅ | ✅ | Ⅱ lisible (pas une icône pause), rappel « Le 22 mars… » cohérent avec le J10 |
| Fins F8 / F9 | ✅ | ✅ | titres, puce ACTE II, date « DIM. 01.04.2187 » ; compteur « 4 » rogné au bord (QA-029) |
| J20 lumières coupées | ✅ | ✅ | bandeau haut-parleur lisible au-dessus du voile, panneaux assombris |
| J20 figure finale Ilan / Mira (5 documents) | ⚠️ | ❌ | liseré gris (Ilan) / magenta (Mira) corrects ; **5 documents** : au Deck la carte et le permis sont presque entièrement couverts (QA-020, `QA-020-j20-deck.png`) ; « PASSAGER · I. LINDQVIST-REY » genré pour Ilan (QA-027) |
| Qualité Basse + FX 0 + texte 1,5 | ❌ | ❌ | **QUOTA et CRÉDITS sortent de la barre du haut** (1080p comme Deck) ; ligne d'aide de la barre d'outils coupée au Deck (QA-031, `QA-031.png`) ; lumières coupées et soirée corrects |

### 12.4 Robustesse

| Scénario | Résultat | Preuve |
|---|---|---|
| Sauvegarde relue à chaque soir J10–J19 (+ prélèvements J11/J17 exacts, aucun ailleurs) | ✅ | `test_qa_act2::test_every_act_two_evening_save_roundtrips_with_levies` ; 49 « Quitter → Continuer » réels aux soirs J10–J19 |
| Sauvegardes v3 réelles (v0.8.1) → v4, soirée pivot jouée, sauvegarde v4 relue | ✅ | `test_real_v3_saves_migrate_and_continue_into_act_two` ; campagne réelle `--qa-load` |
| Spam « Suivant » / tampons pendant les lumières coupées (grève J20) | ✅ un seul verdict, aucun passager de plus, un seul bilan | `test_strike_lights_out_ignores_spam` |
| Pause pendant un lien suggéré du scanner ; fin du temps pendant l'inspection puis confirmation et tampon | ✅ suggestion conservée, confirmation et tampon acceptés, bilan après le départ | `test_scanner_suggestion_survives_pause_and_time_out` |
| Comparaison **concordante** puis tampon rapide (départ avant 1,5 s) | ❌ erreur moteur à chaque fois | QA-023 |
| Boîte « QUITTER HALCYON ? » au clavier / manette | ❌ Tab sort de la boîte ; VALIDER accepté boîte ouverte | QA-021 |
| « Embarquer » sans UI / par défaut | ✅ jamais choisi (`confirm()` → « Rester ») | test + campagne `drift` |
| `reduce_motion` : CHAPITRE II, lumières coupées, documents | ✅ apparition immédiate, fondus courts (`DUR_FAST`) | captures |
| Qualité Basse + FX 0 + texte 1,5 (Deck) | ❌ compteur QUOTA et CRÉDITS hors écran (QA-031) ; lumières coupées, soirée : ✅ | captures `low_*` |
| Rechargements de scène rapprochés (CHAPITRE II puis Continuer) | ⚠️ `ERROR: Playback can only happen when a node is inside the scene tree` (pas de joueur bloqué) | QA-025 |

### 12.5 i18n

| Contrôle | Résultat |
|---|---|
| `fr.csv` | 1 925 clés (+769 depuis v0.8.1), aucun doublon, aucune valeur vide |
| Clés manquantes | **`msg_cons_day11_albedo`** (briefing J11, QA-019) ; **`ev_note_levy`**, **`ev_note_lease`**, **`ev_note_inc_ilan_job`** (notes de postes par défaut, QA-024) |
| Orphelines (jamais lues) | `tb_quota`, `tb_quota_full` (le compteur lit `tb_quota_caption/value/reached`), `wb_scanner_acv`, `wb_scanner_luciole` (lit `wb_scanner_src_*`), `field_holder`, `rb_emp_*` ×13 (l'onglet Employeurs affiche le nom brut de la règle) — QA-028 |
| Sous-titres > 90 car. (SC-23 → SC-50, annonces) | **aucun** ; mots glissés longs mais hors sous-titre (`sc44_lindgren_note` 200, `sc33_corvo_note` 145) |
| Briefings / soirées > 220 car. | directives `day11_intro`…`day15_intro` 226–256 (comme l'Acte I : `day08_intro` 314) — la directive n'a pas la limite des messages ; rien d'autre |
| Tessar entre ‹…› | ✅ chevrons équilibrés partout ; aucun mot tessar hors chevrons (« ‹Ravel ka ota› » est voulu, SC-45) |
| Noms | Beaumont, Sato, Lindgren, Oyelaran-Holm, Navarro, Kerr, Vasquez-Orlov cohérents entre `fr.csv`, ACT2 et LORE ; *Mistigri* (SC-27) absent du LORE (anecdotique) ; « Joaquín » (fils d'Elena) est aussi un nom du Puits 9 lu au J20 — écho voulu ? (Scénariste) |
| Locuteurs | `msg_ilan_day16` signé ILAN mais parle d'Ilan à la 3ᵉ personne (QA-027) |
| Pronoms | aucun pronom genré pour Ilan ; point médian respecté |
| Spoilers | aucun : le CHAPITRE II ne rappelle que la nuit vécue, l'avis « visages seuls » du J20 ne nomme personne, les traces de fin ne citent que les choix faits |
| Dates / jours | briefings, top bar, soirées et fins cohérents (ven. 23.03 → dim. 01.04.2187 ; « Le 22 mars » = J10) |

### 12.6 Tests ajoutés (`tests/integration/test_qa_act2.gd`)

| Test | État |
|---|---|
| `test_real_v3_saves_migrate_and_continue_into_act_two` | ✅ passe |
| `test_every_act_two_evening_save_roundtrips_with_levies` | ✅ passe |
| `test_scanner_suggestion_survives_pause_and_time_out` | ✅ passe |
| `test_strike_lights_out_ignores_spam` | ✅ passe |
| `test_act_two_briefings_have_no_raw_key` | `pending` QA-019 |
| `test_four_documents_keep_their_expiry_dates_visible` | `pending` QA-020 |
| `test_quit_halcyon_confirmation_is_modal` | `pending` QA-021 |
| `test_act_two_character_surnames_are_not_drawn_for_generated_passengers` | `pending` QA-022 |
| `test_evening_line_notes_are_translated` | `pending` QA-024 |

### 12.7 Liste des bugs (Acte II)

Statut : 🔴 ouvert. « Test » = test de non-régression `pending` tant que le bug existe.

| ID | Sév. | Titre | Agent propriétaire | Test |
|---|---|---|---|---|
| QA-019 | **Majeur** | ✅ Corrigé (commit à venir) — `msg_cons_day11_albedo` ajoutée (ton ACT2 §3.5) : le bulletin Albédo **reprend l'annonce du prélèvement** (« Ce soir, Prélèvement de Rééquilibrage : 30 % de l'épargne au-delà de 40 ₵ »), les deux bulletins du groupe `levy` passent en priorité 0 (jamais coupés par le plafond de 4 messages) ; le test vérifie aussi que le J11 annonce toujours le prélèvement. Constat d'origine : briefing du J11, vannes ouvertes : **clé brute `msg_cons_day11_albedo`** affichée (absente de `fr.csv`) — et, même groupe `levy`, elle remplace l'annonce du prélèvement : le joueur n'est pas prévenu des 30 % retenus le soir. C'est la branche la plus fréquente (7 campagnes réelles sur 8) | Scénariste (`fr.csv`) + Gameplay Systems (groupe dans `build_data_act2.gd`) | `test_act_two_briefings_have_no_raw_key` |
| QA-020 | **Majeur** | ✅ Corrigé (commit à venir) — mise en page par colonnes (`Workbench._plan_layout`) : critère = valeurs des champs ≥ 12 px **physiques** (échelle de la fenêtre et texte compris) ; à défaut, la disposition au texte le plus grand (à 3 % près, la plus large), jamais sous 0,72 : 1080p à 4 documents côte à côte (0,73, la carte borne la hauteur), Deck en **piles à onglets** (≈ 0,85 au lieu de 0,72) (la carte seule devant sa pile, les autres laissent dépasser émetteur + titre) ; clic sur un onglet ou **touches 1–n** (« TOUCHES 1–n » dans l'en-tête) : document devant ; un lien suggéré du scanner amène son document devant ; glisser / zoomer sort un document de sa pile ; plan recalé sur le Rulebook et la barre d'outils réels. Constat d'origine : plan de travail à **4 documents** (J12+ ; 5 possibles au J14+) : la mise en page par défaut les fait se chevaucher (~40 % de largeur) ; **dates d'expiration du permis et du bio-scan, N° ID / émetteur / sceau de la carte cachés** sous le document suivant, en 1080p comme au Deck. Au J13 (graine 3), la discordance N° ID carte ↔ bio-scan est entièrement sous le permis ; un lien du scanner peut pointer un champ invisible | UI/UX Expert (+ Design System) | `test_four_documents_keep_their_expiry_dates_visible` |
| QA-024 | **Majeur** | ✅ Corrigé (commit à venir) — `ev_note_levy`, `ev_note_lease`, `ev_note_inc_ilan_job` ajoutées ; `test_evening_line_notes_are_translated` couvre J1–J20 × foyers (malades, Soute, en attente) × drapeaux Acte II, et **`test_every_data_referenced_key_exists_in_fr_csv`** parcourt par réflexion toutes les ressources de `data/` (briefings, soirées et options, annonces, avis, révocations, cas scénarisés, objets glissés, documents, règles, factions : `*_key`, `key`, `*_keys`). Constat d'origine : soirée : **notes de postes en clé brute** — « ev_note_levy » sous le Prélèvement de Rééquilibrage (J11, J17, dès 41 ₵ d'épargne : quasi toutes les parties), « ev_note_lease » sous la location ACV-2 (J14–J19), « ev_note_inc_ilan_job » (salaire d'Ilan) : `ExpenseLine` pose `ev_note_<id>` par défaut | Scénariste (`fr.csv`) ou Gameplay Systems (`note_key` vide / dédié dans `evening_service.gd`) | `test_evening_line_notes_are_translated` |
| QA-030 | **Majeur** | ✅ Corrigé (commit à venir) — **cause racine : course de Godot 4.7.2 dans le thread audio**, pas la synthèse tessar. Reproduit (stress de rechargements de la vraie scène, §12.12 : `signal 11` après ≈ 500 rechargements) ; pile désassemblée : copie de `StringName` dans `AudioServer::_mix_step` sur le thread du pilote audio — l'erreur `/root … propagate_notification()` est la `NOTIFICATION_CRASH` du gestionnaire de plantage, émise hors du thread principal. Chaque changement de volume d'une lecture (`AudioStreamPlayer3D` des passagers à chaque mixage, fondus) remplace ses `bus_details` ; l'ancien bloc est libéré deux `AudioServer.update()` plus tard alors que le mixage peut encore le copier s'il est retardé d'une image (processeur chargé, images très courtes autour d'un rechargement). Correctif : autoload **`AudioMixBarrier`** (verrou du pilote pris et rendu à chaque image : le mixage en cours finit avant toute libération) ; en outre barks rendus par un `BarkJob` sans nœud (plus de lambda capturant le directeur), aucun bark ni son hors de l'arbre, attente des rendus à la sortie de l'arbre et à la libération. Après : 3 × 1 000 rechargements et 19 campagnes réelles (218 « Quitter → Continuer ») sans plantage (§12.12, ARCHITECTURE R31). Constat d'origine : **plantage intermittent** (1 campagne réelle sur 13, graine 11 sans crédits) au rechargement de la scène après la soirée du J7 : `ERROR: /root: The caller thread can't call the function propagate_notification() on this node` puis `handle_crash: signal 11` (Godot 4.7.2). Rejouée à l'identique : pas de plantage. Seul code multithread du projet : synthèse des voix tessar (`AudioDirector`, `WorkerThreadPool.add_task`, attente à `_exit_tree`) ; à instrumenter (`--verbose`, symboles) | Godot Architect + Audio Designer (`audio_director.gd:392`) | log `QA-030` (repro non déterministe) |
| QA-031 | **Majeur** | ✅ Corrigé (commit à venir) — barre du haut adaptative (`TopBar.update_compaction`, paliers comme QA-011 : sur-titre, « FIN 18:00 », jauge, lieu, marque, date ; compteurs sur une ligne « TRAITÉS 00 · QUOTA 0/5 · CRÉDITS ₵ 20 » quand légende + valeur dépassent la hauteur) ; ligne d'aide de la barre d'outils dimensionnée à la taille du texte, barre qui grandit vers le haut et plan de travail qui la suit ; échelle minimale des documents divisée par l'échelle du texte. Constat d'origine : **Texte 1,5 (accessibilité)** : à l'Acte II, le compteur QUOTA ajouté à la barre du haut pousse **QUOTA et CRÉDITS hors de l'écran**, en 1920×1080 comme au Deck (au J10, sans quota, « CRÉDITS » est déjà rogné au Deck) ; au Deck la ligne d'aide de la barre d'outils passe sur 3 lignes et sort par le bas. Le joueur qui a besoin du grand texte ne voit plus ni son quota ni son solde | UI/UX Expert (`top_bar.gd`, `quota_counter_view.gd`, `tool_bar.gd`) | capture `QA-031.png` |
| QA-021 | Mineur | ✅ Corrigé (commit à venir) — focus piégé entre RESTER / CONFIRMER (Tab, Maj+Tab, directions), Échap / B = « Rester » (le focus revient à l'option), `confirm()` ignoré boîte ouverte. Constat d'origine : boîte « QUITTER HALCYON ? » (J10, Embarquer) **non modale au clavier / manette** : Tab depuis CONFIRMER LE DÉPART passe aux postes de dépense derrière le voile puis à VALIDER ET DORMIR ; `confirm()` accepté boîte ouverte (la nuit passe avec « Rester », la boîte reste sous le rapport de nuit). Aucun départ involontaire possible | UI/UX Expert (`evening_screen.gd`) | `test_quit_halcyon_confirmation_is_modal` |
| QA-022 | Mineur | ✅ Corrigé (commit à venir) — D-067 étendu : `build_data.gd` réserve le **nom de famille de chaque personnage scénarisé des deux actes** (identité présentée et vraie) et des avis nommés, plus les noms distinctifs ; pour garder ≥ 12–15 noms tirables, réserves TYC / HAL (+10) et TER (+7) complétées de figurants (`EXTRA_FAMILY_NAMES`, à reporter au LORE §5 par le Lore Master) ; test étendu à J1–J20 × 6 graines. Constat d'origine : générateur : **noms de famille des personnages de l'Acte II tirés pour des passagers générés** les jours mêmes — « Navarro » ≈ 0,5/jour (graine 3 : « Tomás Navarro » 1ᵉʳ passager du J11 **et** du J12, le jour d'Elena Navarro), « Kerr » au J13 (les trois Ren Kerr), « Sato » au J17 (« Soren Sato » 1ᵉʳ passager du jour où Sato est révoqué). Par ailleurs 28 % des paires de jours consécutifs partagent un nom complet exact (19 % à l'Acte I) | Gameplay Systems (`reserved_names`, D-067 / QA-002) | `test_act_two_character_surnames_are_not_drawn_for_generated_passengers` |
| QA-023 | Mineur | ✅ Corrigé (commit à venir) — minuteur du surlignage concordant porté par le champ (`Tween` du champ, libéré avec lui) ; `test_concordant_mark_survives_documents_leaving_early`. Constat d'origine : `ERROR: Error calling from signal 'timeout' … _unmark_concordant: Cannot convert argument 1 from Object to Object` : une paire **concordante** comparée puis tamponnée avant 1,5 s → le minuteur rappelle `_unmark_concordant(item: InspectableItem)` sur un champ libéré (même motif que QA-012 : paramètre typé avant `is_instance_valid`). Aucun effet joueur, journal pollué (et GUT échoue si un test le déclenche) | UI/UX Expert (`comparison_ui.gd:851`, `:1556`) | log (repro : `test_scanner_suggestion…` avec un lien concordant) |
| QA-025 | Mineur | ✅ Corrigé (commit à venir) — `PassengerAudio._play_on` / `say` ignorent un émetteur hors de l'arbre ; `AudioDirector` n'accepte plus aucun son ni bark une fois sorti de l'arbre (`_is_active()`) : un signal tardif ne relance plus de lecture **ni ne remplit à nouveau le cache d'`AudioCueBank` après `clear_cache()`** (première source des fuites) ; seconde source (`--verbose`) : quitter juste après l'écran de fin laisse des lectures (`AudioStreamRandomizer`, WAV, musique du bilan) dans la liste de l'`AudioServer`, qui ne les retire qu'à ses `update()` suivants — `AudioMixBarrier.quit_after_silence()` arrête tous les lecteurs, laisse 8 images + 250 ms (processeur chargé) puis quitte (`qa_campaign`, `qa_capture`, `qa_perf`). Stress de 60 rechargements : avant 2 erreurs « Playback… » + `49 ObjectDB instances leaked` / `25 resources still in use` ; après : 0 ; campagne graine 5 `--verbose` : 0 fuite. Reste (hors périmètre, cosmétique) : fermer la fenêtre en plein shift peut encore laisser ces fuites à la sortie. Constat d'origine : sorties moteur : `ERROR: Playback can only happen when a node is inside the scene tree` (`passenger_audio.gd:123`, `_play_on` sur un acteur sorti de l'arbre, rechargement de scène pendant une marche) ; fuites à la sortie après une fin F3 / F6 ou une capture (`8–37 ObjectDB instances leaked`, `3–17 resources still in use`) — QA-016 réapparaît sur ces chemins | Audio Designer / Godot Architect | log |
| QA-026 | Mineur | ✅ Corrigé (commit à venir) — R28 : `DayDef.asylum_class_rate` (J15 : 1,0, ensuite 0,30) et `DayDef.focus_documents = [asylum]` (J15+ : `MISSING_DOCUMENT` / `EXPIRED_DOCUMENT` visent l'attestation quand le passager en porte une), file F_TER et poids EXPIRED / MISSING relevés au J15 → R28 violée dans **2,6 %** des cas du J15 (0,1 % avant), 0,3–0,9 % ensuite ; `UNREGISTERED_VESSEL` : poids **conditionnel** (DRV porteurs seulement) relevé à 0,20 dès le J14 → 1,1–2,8 % des anomalies (0,2–1,2 %) ; `REVOKED_ID` : poids 0 (jamais tiré au hasard : entrées de `DayDef.revocations`, comme `WANTED_PERSON`). Invariants OK, 0 re-tirage ; fins de `balance_sim` dans ±5 points (§12.12). Constat d'origine : équilibrage du générateur (gen_stats, 40 campagnes) : **R28 (attestation d'asile, J15) violée dans 0,1 % des cas** (la règle du jour n'est presque jamais exercée hors SC-36) ; `UNREGISTERED_VESSEL` sous-représenté après le J13 (0,2–1,2 % observés pour 3,7–6,5 % de poids : réservé aux `DRV`, 10 % de la file) ; `REVOKED_ID` au J19 14 % pour 6,8 % de poids | Gameplay Systems (`build_data_act2.gd`, injecteurs) | gen_stats |
| QA-027 | Cosmétique | ✅ Corrigé (commit à venir, partie texte) — `msg_ilan_day16` réécrit à la 1ʳᵉ personne (« On m'a glissé un mot. Je ne l'ai pas encore ouvert… ») ; le libellé « PASSAGER·E » pour `X` reste côté UI/UX (`UiText`). Constat d'origine : `msg_ilan_day16` signé « ILAN · BLOC PÉTREL » : « Ilan a reçu un mot. Ilan ne l'a pas encore ouvert… » (Ilan parle de lui·elle à la 3ᵉ personne) → `spk_note` ou Dora (D-081). Même famille : le panneau du passager affiche « PASSAGER · I. LINDQVIST-REY » pour Ilan (sexe `X` → libellé masculin par défaut, `UiText.passenger_number`) alors que la convention interdit le genre pour Ilan → « PASSAGER·E » pour `X` | Scénariste / UI/UX | — |
| QA-028 | Cosmétique | ✅ Corrigé (commit à venir, partie données) — `ContractConsistentRule.label_key(code)` (`rb_emp_<code>`) et `test_employer_codes_have_label_keys` (13 codes, libellé « XX · Employeur ») ; aucune clé référencée par les données sans traduction (`test_every_data_referenced_key_exists_in_fr_csv`). ✅ Corrigé (commit à venir, partie UI) — onglet « Codes employeurs » lu via `rb_emp_<code>` (code déjà sur la pastille) ; `tb_quota` / `tb_quota_full` = compteur compact de la barre du haut ; `wb_scanner_acv` / `wb_scanner_luciole` = infobulle de la pastille ✓ ; `field_holder` = libellé « TITULAIRE » du nom sur un document d'un tiers. Constat d'origine : clés orphelines de l'Acte II (§12.5) : `tb_quota`, `tb_quota_full`, `wb_scanner_acv`, `wb_scanner_luciole`, `field_holder`, `rb_emp_*` ×13 ; l'onglet « Codes employeurs » affiche les noms bruts de `ContractConsistentRule.employer_codes` au lieu de `rb_emp_*` | Scénariste / UI/UX | — |
| QA-029 | Cosmétique | ✅ Corrigé (commit à venir) — libellés de champs repliés sur deux lignes au lieu d'être tronqués (« VALIDE / JUSQU'AU ») ; sur-titre « CONSORTIUM · … » de la barre du haut abandonné en entier ; pastille ✓ posée sur le lien hors de tout document ; compteur de l'écran de fin non reproduit (F8, 1080p et Deck : visible). Constat d'origine : libellés tronqués des documents (« FIRMWARE… », « STATUT SANITAI… », « VALIDE JUS… » au Deck ; « CONSORT… » dans la barre du haut au Deck) ; la pastille ✓ d'un lien du scanner se pose sur le texte du document qu'elle traverse (sceau / code-barres du bio-scan, J14) ; compteur « 4 » du bloc « CE QUE VOUS AVEZ CHOISI » rogné au bord droit de l'écran de fin | UI/UX Expert | captures |

Total Acte II : **0 bloquant, 5 majeurs, 5 mineurs, 3 cosmétiques** (13 bugs, QA-019 à QA-031). Aucun bug de l'Acte I réapparu hors QA-016 (QA-025) ; les correctifs QA-001 à QA-018 tiennent (suite verte, captures J1–J10 non refaites).

### 12.8 Difficulté observée (Game Designer)

- **Le bot de la vraie scène (59–69 % de conformité cumulée) ne passe pas l'Acte II sans aide** : sans crédits de QA, fin F2 au soir du J7 (graine 5), F3 aux soirs du J10 et du J11 (graines 42, 7 et 11) : **sans aide, le bot ne voit jamais le J12** ; avec **+300 ₵**, F2/F3 entre le soir du J14 et celui du J15 (3/3) ; il faut **+1 500 ₵** pour atteindre le J20. À l'Acte II, ce bot tombe à **38–50 % de conformité les J12, J14, J17–J19** (contrats R24/R25, firmware R27, révocations R30 : règles « hors de l'écran » pour lui) et perd 25–50 ₵ par shift ; la base quotidienne (≈ 50 ₵ + rations, oxygène, soins) n'est jamais couverte.
- **Simulation** (erreurs au hasard, plus clémente) : à 65 %, 50 % des campagnes atteignent le J11, 30 % le J15, **7,5 % le J20** ; à 80 %, 97,5 % finissent au J20 (fins conformes à la politique) ; à 95 %, épargne 300–450 ₵ malgré les deux prélèvements.
- **Lecture** : cohérent avec D-060 (« dur ») et ACT2 §6.3 pour un joueur à 60 % (cibles respectées : J20 ≤ 5–10 %). Mais **ce n'est pas bloquant pour « la plupart des joueurs » seulement si un joueur humain dépasse nettement le bot** : les métriques Acte I du bot (90–100 % aux J2–J3, 40–70 % ensuite) suggèrent qu'un joueur moyen qui ne maîtrise pas les onglets Employeurs / Révocations se trouvera dans la zone 60–70 % au J12 et s'effondrera vers le J14–J15, **après** le pivot et le CHAPITRE II, ce qui est plus frustrant qu'un échec à l'Acte I. À confirmer en playtest humain (GDD §14) avant tout réglage ; pistes si confirmé : un 3ᵉ avertissement gratuit les jours de nouvelle règle (J12, J14, J17), ou plancher du prélèvement J11 relevé pour un solde < 100 ₵.
- **« Vannes ouvertes par accident »** (suite de §9) : 7/8 campagnes réelles arrivées au J10 ont ouvert les vannes sans jamais aider sciemment les Lucioles. Recommandé : appliquer `luciole_trust_on_breach = false` dès le J8–J10 (ou compter `final_passed` seulement si Mira a été comparée à l'avis), sinon la branche « avortées » sera rare chez les joueurs inattentifs.

### 12.9 Perf indicative

`tools/qa_perf.gd` sous xvfb (llvmpipe, 4 cœurs **partagés avec les campagnes en cours** : les temps d'image ne sont pas comparables au §5, seuls les appels de dessin le sont).

| Scène | Appels de dessin | Primitives | Image moyenne / p95 (llvmpipe chargé) |
|---|---|---|---|
| J7, 1ᵉʳ passager (référence Acte I, même machine, même charge) | **325** | 50 000 | 535 / 679 ms |
| **J12**, 4 documents + scanner (boîte magenta, pointillés) | **406** (+25 %) | 51 400 | 555 / 760 ms |
| **J20**, figure finale (5 documents, ticket de file) | **408** (+26 %) | 52 400 | 528 / 668 ms |

Lecture : l'Acte II ajoute ≈ 80 appels de dessin, presque tous en **UI 2D** (un document ≈ 15–20 appels : cadre, champs, code-barres, sceau ; liens pointillés ; pastilles) ; la 3D ne bouge pas (primitives +4 %). Rien d'alarmant sur GPU, mais le budget Deck à fixer (§5, recommandation 7) doit inclure ~410 appels au pire cas ; piste : regrouper le rendu des champs d'un document (un seul `_draw`) si le Deck réel le demande.

### 12.10 Recommandations priorisées

1. **QA-030** (plantage intermittent au rechargement de scène) : instrumenter et relancer 20 campagnes avant toute démo publique.
2. **QA-019 et QA-024** (clés brutes au J11, la première journée de l'Acte II, dans presque toutes les parties) : ajouter les quatre clés manquantes ; ne pas laisser le message Albédo évincer l'annonce du prélèvement (groupe distinct).
3. **QA-020 et QA-031** : mise en page du guichet de l'Acte II — à 4–5 documents — ajuster aussi l'échelle à la largeur (≥ 0,72) ou cascader en gardant la colonne droite (dates, N° ID) de chaque document visible ; un lien suggéré du scanner devrait amener son document au premier plan ; barre du haut repliable (libellés courts / deux lignes) avec le texte 1,5.
4. **Difficulté (§12.8)** : playtest humain J10–J15 avant toute retouche ; trancher « vannes ouvertes par accident ».
5. QA-022 (réserver Navarro / Kerr / Sato ; élargir les réserves de noms), QA-021 (piéger le focus dans la boîte, ignorer VALIDER boîte ouverte), QA-026 (exercer R28).
6. Journaux propres : QA-023, QA-025.
7. Contenu : QA-027, QA-028, QA-029.
8. QA (suite) : captures J1–J10 de non-régression à refaire au prochain jalon, F1/F4/F5 jouées à la main dans la vraie scène, perf sur GPU / Steam Deck réel.

### 12.11 Rejouer la passe Acte II

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit           # 524 tests, 5 pending QA-019…024
# Campagne réelle J1–J20 avec « Quitter → Continuer » chaque soir (user:// jetable)
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-seed=11 --qa-profile=solidaire --qa-speed=10 --qa-credits=1500 --qa-reload
# Reprise d'une sauvegarde v3 réelle (migration v3 → v4 dans la vraie scène)
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-load=$PWD/tests/fixtures/qa_save_v3_j9_loyal.json --qa-profile=loyal --qa-speed=10 --qa-reload
# Fins F1–F9 simulées
godot --headless --script res://tools/balance_sim.gd -- --seeds=40 --seed=1 --profiles=0.65,0.8,0.95 \
    --presets=default,loyal,luciole,mercenary,drift,negligent,evicted,drift10,archiviste,solidaire,overrun,mercenary2
# Capture réelle (Deck) sans override.cfg
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1280x800 --qa-wait=25 \
    --qa-out=/tmp/j12.png --seed=3 --day=12 --screen=shift --flags=scanner_luciole,act2_started --reduce-motion
```

### 12.12 Correctifs techniques (Godot Architect) — mesures

Correctifs QA-019, QA-022, QA-024 à QA-028 (données), QA-030, R28 et R30 de la revue d'architecture (rév. 3.5). Exécutions avec `XDG_DATA_HOME` jetable ; rien laissé dans le dépôt.

| Mesure | Avant | Après |
|---|---|---|
| **Stress de rechargements** de la vraie scène (`day.tscn`, bot `--autoplay`, `reload_current_scene` toutes les 1–240 images, briefing comme plein shift) | 3 runs (≈ 2 100 rechargements) : **1 `signal 11`** (≈ 500ᵉ rechargement, pile : `AudioServer::_mix_step`, thread du pilote audio) ; 14–72 « Playback can only happen… » ; fuites à la sortie | 3 × 1 000 rechargements : **0 plantage**, 0 « Playback… » |
| **Campagnes réelles** `qa_campaign --qa-reload` (« Quitter → Continuer » à chaque briefing), 3–4 en parallèle | 13 campagnes (§12.2) : 1 plantage (QA-030), fuites à la sortie | **19 campagnes**, 236 jours, **218 rechargements** (graines 3, 5, 7, 11, 13, 19, 23, 42 ; profils default, archiviste, solidaire, luciole, drift, drift10, loyal sur sauvegarde v3 réelle ; fins F2, F3, F6, F7, F8, F9) : 0 plantage, 0 `SCRIPT ERROR`, 0 `QA_ISSUE`, 0 « Playback… » ; 0 fuite depuis `quit_after_silence` (4 dernières campagnes, 4 en parallèle) |
| `gen_stats` (40 campagnes) — R28 violée au J15 | 0,1 % | **2,6 %** (J16–J20 : 0,1–0,9 %) |
| `UNREGISTERED_VESSEL` J14–J20 (part des anomalies) | 0,2–1,2 % | 1,1–2,8 % |
| `REVOKED_ID` (poids) | 6,8–16,5 % (jamais tiré) | 0 (entrées de révocation seules, part observée inchangée : 6,2–19 %) |
| Invariants du générateur, re-tirages | OK, 0 | OK, 0 (anomalies non placées J1/J2/J8 : 5/1/1, inchangées) |
| `balance_sim` 40 graines × 12 préréglages × 65/80/95 % | §12.2 | 35 cases sur 36 à ±2,5 points ; `drift` 80 % : F6 55 → 47,5 (bruit : à **200 graines** 58,5 → 58,0 %) |
| `build_data.gd` | — | deux exécutions = fichiers identiques |
| Suite GUT | 524 (5 pending) | **531 / 531**, aucun `pending` |
| `export_all.sh linux` + `smoke_export.sh` | — | OK (titre, J1, J4, J7, J10, J15, J20) |

Outils de ces mesures (stress de rechargements, sonde d'asile) gardés hors dépôt ; le stress se rejoue avec une boucle `reload_current_scene.call_deferred()` à intervalles aléatoires depuis un nœud lancé par `tools/qa_boot.gd`.
