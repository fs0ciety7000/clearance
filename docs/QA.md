# QA.md — Passe QA globale (campagne J1–J10)

> Propriétaire : **QA / Playtester** · Version du jeu : `0.7.0-m7` (sauvegarde v3) · Godot 4.7.2 · GUT 9.7.1
> Passe du 27.10.2026, sur `main` après les commits « Narration : écarts M7 corrigés » et « ARCHITECTURE rév. 3 ».
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
