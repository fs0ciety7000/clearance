# QA.md — Passe QA globale (campagne J1–J10)

> Propriétaire : **QA / Playtester** · Version du jeu : `0.7.0-m7` (sauvegarde v3) · Godot 4.7.2 · GUT 9.7.1
> Passe du 27.10.2026, sur `main` après les commits « Narration : écarts M7 corrigés » et « ARCHITECTURE rév. 3 ».
> **Passe Acte II du 28.10.2026** (`0.8.1` + M8 A/B, sauvegarde v4, 515 tests) : voir [§12](#12-passe-qa-acte-ii-j10j20) — bugs QA-019 à QA-031.
> **Passe Acte III du 29.10.2026** (M9 A/B `26eb154`, sauvegarde v5, 573 tests) : voir [§13](#13-passe-qa-acte-iii-j20j30) — bugs QA-032 à QA-040.
> **Passe M11 « Confort » du 29.10.2026** (`4bbda95`, sauvegarde v6, 638 tests) : voir [§14](#14-passe-qa-m11-confort) — bugs QA-041 à QA-049, 655 tests (8 `pending`).
> **Passe M12 « Rejouabilité » du 29.10.2026** (`c729f93`, profil v2, 770 tests) : voir [§15](#15-passe-qa-m12-rejouabilité) — bugs QA-050 à QA-062, 783 tests (10 `pending`).
> **Passe M13 « Gameplay » du 30.10.2026** (`a9ddc0c`, sauvegarde v6, 882 tests) : voir [§16](#16-passe-qa-m13-gameplay) — bugs QA-063 à QA-071, 893 tests (8 `pending`).
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
13. [Passe QA Acte III (J20–J30)](#13-passe-qa-acte-iii-j20j30)
14. [Passe QA M11 « Confort »](#14-passe-qa-m11-confort)
15. [Passe QA M12 « Rejouabilité »](#15-passe-qa-m12-rejouabilité)
16. [Passe QA M13 « Gameplay »](#16-passe-qa-m13-gameplay)

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
| ✅ Corrigé — **rechargement en plein shift** : `BoothDirector` émettait encore hors de l'arbre (minuteur de présentation, repère d'animation) → `ComparisonUI` sortie de l'arbre → `workbench.gd:137` (`process_frame` sur null) | reproduit (`test_booth_emits_nothing_once_the_scene_left_the_tree`, scène retirée de l'arbre au guichet) : `documents_presented` émis, 6 erreurs moteur | `_emit_once` / `_knock` / arrivée gardés par `is_inside_tree()`, minuteurs (`_after`) déconnectés à `_exit_tree` ; `Workbench` ne touche plus à `get_tree()` hors de l'arbre (mise en page reportée à `NOTIFICATION_ENTER_TREE`) : 0 émission, 0 erreur |
| ✅ Corrigé — `build_data.gd` affichait « OK » malgré un `build_data_act2.gd` non analysable (`_build()` interrompu, code 0) | erreur d'analyse simulée (copie hors dépôt) : « OK », code 0, données partielles | scripts de données vérifiés avant toute écriture, `Logger` comptant les erreurs moteur / de script, génération menée à terme : « build_data : ÉCHEC — … », code 1, rien d'écrit ; échec d'enregistrement simulé : code 1 |
| Suite GUT | 524 (5 pending) | **532 / 532**, aucun `pending` |
| `export_all.sh linux` + `smoke_export.sh` | — | OK (titre, J1, J4, J7, J10, J15, J20) |

Outils de ces mesures (stress de rechargements, sonde d'asile) gardés hors dépôt ; le stress se rejoue avec une boucle `reload_current_scene.call_deferred()` à intervalles aléatoires depuis un nœud lancé par `tools/qa_boot.gd`.

## 13. Passe QA Acte III (J20–J30)

> Passe du 29.10.2026 sur `main` après « M9 partie B — interfaces de l'Acte III » (`26eb154`, 573/573 tests), sauvegarde **v5**. Même méthode qu'aux §1–§12 ; QA n'a corrigé aucun code de jeu ni aucune donnée. Après la passe : **581 tests** (573 + 8 de `tests/integration/test_qa_act3.gd`, dont 4 en `pending("QA-0xx")`), suite verte. Le conteneur a redémarré pendant la passe : les campagnes ont été rejouées en **tronçons ≤ 9 min** (« Quitter » par arrêt du processus, puis reprise de la vraie sauvegarde automatique par `--qa-load`), ce qui ajoute un « Quitter → Continuer » réel à chaque tronçon.

### 13.1 Outils

Aucun outil QA modifié : `tools/qa_campaign.gd` (J1–J30, `--qa-reload`, `--qa-load`, `--qa-credits`), `tools/qa_capture.gd` (`--qa-after-check`), `tools/qa_perf.gd`, `tools/balance_sim.gd`, `tools/gen_stats.gd` suffisent. Toutes les exécutions avec `XDG_DATA_HOME` jetable (Qualité Basse + FX 0 + texte 1,5 : `settings.cfg` posé dans ce `user://` jetable), rien laissé dans le dépôt.

### 13.2 Campagnes automatiques

#### Vraie scène (`day.tscn`, booth 3D, bot `--autoplay`, `--qa-reload`)

| Graine | Profil (soirées) | Départ | Climat (carte du J20) | Fin | Jour | Solde final | Conformité |
|---|---|---|---|---|---|---|---|
| 3 | loyal | **sauvegarde v4 réelle** `qa_save_v4_j20_loyal` | statu quo | **F7** | J30 | 121 ₵ | 80 % |
| 5 | luciole | sauvegarde v4 `…_luciole` (Ilan dans la Soute) | statu quo | **F7** | J30 | 90 ₵ | 81 % |
| 11 | solidaire | sauvegarde v4 `…_solidaire` (grève) | vitres | **F2** | soir J29 | −34 ₵ | 79 % |
| 23 | solidaire | J1, +3 000 ₵ | vitres | **F9** (grève du J30, lumières coupées) | J30 | 306 ₵ | 60 % |
| 13 | passeur | J1, +3 000 ₵ | statu quo | **F7** | J30 | 407 ₵ | 62 % |
| 19 | temoin | J1, +3 000 ₵ | statu quo | **F7** | J30 | 389 ₵ | 60 % |
| 7 | passeur | J1, +1 500 ₵ | statu quo | **F2** | soir J28 | 0 ₵ | 62 % |
| 42 | luciole | J1, +1 500 ₵ | statu quo | **F2** | soir J28 | −41 ₵ | 60 % |
| 3 | drift | J1, +1 500 ₵ | statu quo (« Rester » au J20) | **F3** (Dora puis Ilan et Noa) | soir J27 | −43 ₵ | 58 % |
| 11 | temoin | J1, +1 500 ₵ | registre | **F2** | soir J24 | −63 ₵ | 56 % |

- **10 campagnes, 229 jours joués dans la vraie scène dont 86 de l'Acte III, ≈ 220 « Quitter → Continuer » réels (≈ 85 aux soirs J20–J29) : aucune `SCRIPT ERROR`, aucun plantage, aucun blocage de phase, aucun écart sauvegarde relue ↔ état** (seuls `QA_ISSUE` : « solde aberrant » > 2 000 ₵, attendus avec +3 000 ₵ de crédits QA). Seules sorties moteur : fuites à la sortie (QA-039).
- **Migration v4 → v5** : les trois vraies sauvegardes v4 du J20 reprennent au J20, jouent la carte « FIN DE L'ACTE II », la soirée pivot, le CHAPITRE III et l'Acte III jusqu'au J29/J30 ; aussi `test_qa_act3::test_real_v4_j20_saves_roundtrip_every_act_three_evening` (chaque soir J20–J29 relu à l'identique).
- **Fins atteintes dans la vraie scène : F2, F3, F7, F9.** F1 (Déposition), F4, F5, F6, F8, F10 restent hors de portée du bot (il n'aide jamais sciemment, ne lit ni répondants ni convocations, ne garde rien) : couvertes par la simulation (ci-dessous). Toutes les cartes de fin d'acte vues : `statu_quo`, `vitres`, `registre` (+ `vanne`, `promu` en capture / test).
- **Répondants / Main courante** : signaux `ledger_changed` et onglet cohérents (captures J24) ; le bot n'utilise pas la Main courante. **Retour aux quais** : ticket de file absent dès le J21, bio-scan dès le J23 (plans de travail à 2 documents, côte à côte). **Enquête** : Q1/Q2/Q3 présentes les soirs J22/J26/J28 dans les 10 campagnes ; **Déposition** + verdict au J29 (6 campagnes arrivées au J29) ; `d29_strike` seulement si solidarité suffisante.
- **Aides** : rappel des salaires imputés (`d21_recall`, +30 ₵ pour `quota_overrun` 7) ; caisse des vitres (`d23_fund`) vue à bas solde ; **avance de l'Arbitre (`d21_loan`, solde < 40 ₵ au J21) jamais déclenchée** dans ces campagnes (non couverte en vraie scène). **Prélèvements** : J25 « Contribution » = ⌊20 % × (solde − 60)⌋ (342 → 56 ; 322 → 52 ; 161 → 20 ; aucun sous 60 ₵), J11/J17 inchangés ; aucun ailleurs.
- **Foyer** : Ilan quitte la Soute au J20 (`d20_ilan_back`) puis part à Tycho au J24 (`d23_job` = tycho) : ration retirée, aucune ligne pour un absent ; ration non payée → ESSOUFFLÉ·E puis MALADE, puis GRAVEMENT MALADE et perdu·e (F3 vue au soir du J27).
- **Profil `loyal` au J29** : « choix d29_deposition:loyal refusé par l'écran » → Déposition « Se taire » par défaut (QA-036).

#### Simulation (`tools/balance_sim.gd`, 20 graines, graine 1, J1–J30)

| Préréglage | 65 % | 80 % | 95 % |
|---|---|---|---|
| `default` | F2 50 · F3 45 · F1 5 | F7 85 · F1 15 (Déposition) | F7 100 |
| `loyal` | F2/F3 100 | F7 100 | **F4 100** |
| `luciole` | F2/F3 100 | F5 80 · F1 20 | **F5 100** |
| `passeur` | F2/F3 95 · F1 5 | F7 45 · F10 25 · F1 25 · F3 5 | **F10 85** · F7 15 |
| `temoin` | F2/F3 95 · F1 5 | F8 75 · F1 25 | **F8 100** |
| `solidaire` | F2/F3 85 · F1 10 · F9 5 | F9 90 · F1 10 | **F9 100** |
| `mercenary3` | F2/F3 90 · F1 10 | F1 95 | F1 80 · F7 20 |
| `drift` | F2/F3 95 · F1 5 | F6 60 · F7 20 · F10 10 · F1 10 | **F6 85** · F10 15 |

**Les dix fins F1–F10 sont atteignables** ; ordres de grandeur conformes à ACT3 §6.6 (20 graines au lieu de 40 : ±10 points). `gen_stats` (40 campagnes × 30 jours) : invariants OK, 0 re-tirage, anomalies non placées J21–J30 : 0–4 par jour ; écarts de poids en QA-037.

### 13.3 Passe visuelle (captures réelles 1920×1080 et 1280×800)

`tools/qa_capture.gd` sous xvfb (OpenGL 3 / llvmpipe), graine 3, `--reduce-motion`. Seules les captures de bugs sont versionnées (`docs/qa/QA-0xx.png`).

| Écran | 1080p | Deck | Constat |
|---|---|---|---|
| Carte « FIN DE L'ACTE II » (J20, vitres, `--hold-card`) | ✅ | ✅ | titre deux lignes dans la couleur de fin, bouton « LA NUIT DU 1ᵉʳ AVRIL ▶ » |
| CHAPITRE III | ✅ | ✅ | Ⅲ dessiné, « TÉMOINS » ambre, dates lun. 02.04 → mer. 11.04, rappel du climat ; pas de spoiler |
| Guichet J24, Main courante + comparaison Répondant ↔ entrée (`--qa-after-check`) | ❌ | ❌ | **bandeau CONCORDANT sur la MRZ et le code-barres de la carte** (QA-033, `QA-033.png`) ; au Deck la carte de la Main courante est coupée par le pied du Rulebook (QA-032) |
| Guichet J26 / J28, Convocations (SC-66 Lev, SC-76 Sato) | ⚠️ | ⚠️ | liste à 5–6 convocations : **une seule carte visible** (QA-032) ; objets glissés OBJET / CONVOCATION / REGISTRE dessinés comme une carte de quai « Q6 » (QA-035, `QA-035.png`) |
| Rulebook J26 / J30, onglet Règles (16 onglets) | ❌ | ❌ | **2 règles visibles**, la rangée de 16 onglets prend ≈ 240 px (QA-032, `QA-032.png`) ; même capture : carte d'identité seule, libellé « FIRMWARE NX » écrit lettre par lettre en colonne (QA-038) |
| Soirée J22, Enquête Q1 | ⚠️ | ✅ | panneau ambre « ⚖ ENQUÊTE · C. RAVEL », options Dire / Se taire / Accuser ; **rations : Noa et Dora sous le bord** (QA-034) |
| Soirée J29, Déposition (« Se taire » → RIEN À RETENIR) | ❌ | ✅ | verdict révélé après le choix ✅ ; **« Ration d'air · Dora » coupée en bas** (QA-034, `QA-034.png`) |
| Fin F10 « LE PONT » | ✅ | ✅ | vert, surtitre « HALL DES GUICHETS · QUAI 2 », puce ACTE III, trace « 6 personnes de Tycho… » |
| J30 figure finale Dora / Mira (SC-82) | ✅ | ⚠️ | Dora (répondant HG-1404-AGNT, registre glissé) et Mira (visière, ‹[mot inconnu]› sans *lumika*) ; au Deck « PASSAGÈRE · D. LINDQVIST- » tronqué contre « INTERCOM » (QA-040, `QA-040-deck.png`) |
| Qualité Basse + FX 0 + texte 1,5 (Deck) : J24, J29 | ❌ | ❌ | barre du haut ✅ (QA-031 tient : QUOTA SUSPENDU et CRÉDITS visibles) ; **Main courante illisible** (entrée réduite à une bande sous la date, `QA-032-deck.png`) ; soirée : 3 rations sur 4, sous-titres des postes qui débordent de leur ligne |

### 13.4 Robustesse

| Scénario | Résultat | Preuve |
|---|---|---|
| Sauvegarde relue à chaque soir J20–J29 (3 sauvegardes v4 réelles → v5) | ✅ | `test_real_v4_j20_saves_roundtrip_every_act_three_evening` ; ≈ 85 « Quitter → Continuer » réels aux soirs J20–J29 |
| Processus tué en plein shift (redémarrage du conteneur, arrêts de tronçon) puis reprise de la sauvegarde | ✅ reprise au briefing du jour non validé, aucune perte au-delà | 13 tronçons |
| Déposition : choix changé 4 fois puis VALIDER ET DORMIR ×4 | ✅ une validation, dernier choix retenu | `test_deposition_spam_validates_once_with_last_choice` |
| Carte de fin d'acte : passe seule ≈ 3 s, ou clic / Entrée ; `--hold-card` | ✅ | captures |
| `reduce_motion` : carte, CHAPITRE III, verdict de la Déposition | ✅ apparition immédiate | captures |
| Qualité Basse + FX 0 + texte 1,5 | ❌ Main courante, rations (QA-032, QA-034) | captures `low_*` |
| Pause / « Quitter » au milieu d'une soirée d'Enquête | ✅ (au correctif) vraie scène, Q1 du J22 répondue, pause, QUITTER confirmé : nuit non validée, aucune sauvegarde écrite ; « Continuer » relit le matin du J22, le jour est rejoué et Q1 reposée | `test_pause_quit_during_the_inquiry_replays_the_day` |
| Avance de l'Arbitre (`d21_loan`, solde < 40 ₵ au J21) | ✅ (au correctif) vraie scène : offre présentée, « Accepter » → `arbitre_loan`, nuit validée ; remboursement obligatoire de 35 ₵ au soir du J27 | `test_arbitre_loan_is_offered_and_repaid_in_the_real_scene` |
| Sortie après un écran de fin | ⚠️ fuites (QA-039) | logs |

### 13.5 i18n

| Contrôle | Résultat |
|---|---|
| `fr.csv` | 2 760 clés (+835 depuis l'Acte II), aucun doublon, aucune valeur vide |
| Clés manquantes | **aucune** : briefings, soirées (titres, textes, options, résultats) J20–J30 × 5 climats × 3 foyers, épilogues F1–F10 × 5 climats (`test_act_three_texts_have_no_raw_key`) ; aucune clé brute dans les 10 épilogues des campagnes réelles |
| Orphelines | non mesurables statiquement (clés composées : `evt_<événement>_opt_<option>`, `end3_<fin>_l<n>`…) ; rien d'anormal vu à l'écran |
| Sous-titres > 90 car. (SC-51 → SC-82) | **aucun** ; aucun message de soirée / briefing > 220 |
| Tessar entre ‹…› | ✅ chevrons équilibrés dans les 656 clés de l'Acte III ; aucun mot tessar (*tal ka*, *nesu*, *vanu*, *vesh*, *lumika*) hors chevrons |
| Spoilers | aucun : CHAPITRE III ne rappelle que le 1ᵉʳ avril et le climat ; « la dernière navette » n'est annoncée (J28) que comme un fait public ; la figure finale n'est nommée nulle part avant le J30 |
| Libellés de gain | « Accuser (+10 ₵) » affiche aussi « +10 ₵ » à droite : convention héritée de l'Acte I (`evt_d08_neighbor_opt_denounce`…), signalée sans numéro |

### 13.6 Tests ajoutés (`tests/integration/test_qa_act3.gd`)

| Test | État |
|---|---|
| `test_real_v4_j20_saves_roundtrip_every_act_three_evening` | ✅ passe |
| `test_act_three_texts_have_no_raw_key` | ✅ passe |
| `test_act_three_subtitles_fit_and_tessar_is_bracketed` | ✅ passe |
| `test_deposition_spam_validates_once_with_last_choice` | ✅ passe |
| `test_rulebook_shows_enough_rules_with_sixteen_tabs` | ✅ passe (QA-032 corrigé) |
| `test_result_banner_does_not_cover_documents` | ✅ passe (QA-033 corrigé) |
| `test_evening_rations_are_all_visible_at_1080p` | ✅ passe (QA-034 corrigé) |
| `test_sim_profiles_choose_an_available_deposition_option` | ✅ passe (QA-036 corrigé) |
| `test_pause_quit_during_the_inquiry_replays_the_day` (ajouté au correctif) | ✅ passe |
| `test_arbitre_loan_is_offered_and_repaid_in_the_real_scene` (ajouté au correctif) | ✅ passe |

Les tests `pending` mesurent le défaut et redeviennent des assertions dès qu'il disparaît.

### 13.7 Liste des bugs (Acte III)

Statut : 🔴 ouvert.

| ID | Sév. | Titre | Agent propriétaire | Preuve |
|---|---|---|---|---|
| QA-032 | **Majeur** | ✅ Corrigé (commit à venir) — **Rulebook à 15–16 onglets (J24+) : liste rognée.** La rangée d'onglets (Règles … Main courante, Convocations) et le bloc DATE DU JOUR laissent ≈ 110 px à la liste en 1920×1080 : **2 règles visibles** sur ~30 (J26, J30), **une seule** entrée de Main courante ou de Convocations (5–6 au J26/J28), à faire défiler une à une ; au Deck l'unique entrée est coupée par « ONGLET n / 16 » ; avec le texte 1,5 la Main courante devient une bande illisible. Les règles nouvelles de l'Acte III se lisent dans ces listes. Repro : `--day=26 --screen=shift --rulebook-tab=rules` (ou `summons`, `ledger`). Pistes : onglets repliés en liste déroulante / deux niveaux (Règles · Bulletins), date du jour dans l'en-tête | UI/UX Expert (+ Design System) (`rulebook_panel.gd`) | `QA-032.png`, `QA-032-deck.png`, `test_rulebook_shows_enough_rules_with_sixteen_tabs` |
| QA-033 | **Majeur** | ✅ Corrigé (commit à venir) — **Bandeau de résultat posé sur les documents.** Depuis que l'Acte III repasse à 2 documents à grande échelle (D-085), le bas des documents atteint le bandeau : MRZ et code-barres de la carte, et à l'échelle la ligne Répondant / Convocation du permis ; le bandeau CONCORDANT reste 1,2 s, **DISCORDANCE reste jusqu'à la comparaison suivante** et cache donc durablement la MRZ. Repro : `--day=24 --start-case=2 --rulebook-tab=ledger --inspect --qa-after-check=0.8` | UI/UX Expert (`workbench.gd` `show_banner`, `_plan_layout`) | `QA-033.png`, `test_result_banner_does_not_cover_documents` |
| QA-034 | Mineur | ✅ Corrigé (commit à venir) — **Rations coupées en bas de la soirée** : foyer complet (vous + Ilan, Noa, Dora) + loyer, nourriture, chauffage, oxygène : la liste des dépenses défile dans un cadre trop court, « Ration d'air · Dora » est coupée au bord sans indice de défilement (barre de 2 px), 1080p (J22, J29 — tous les soirs à 4 rations) ; Deck texte 1,5 : 3 rations sur 4 et sous-titres de postes qui débordent. Un joueur peut ne pas voir qu'il ne paie pas l'air de Dora | UI/UX Expert (`evening_screen.gd` `_budget` / `_rations_group`) | `QA-034.png`, `test_evening_rations_are_all_visible_at_1080p` |
| QA-036 | Mineur | ✅ Corrigé (commit à venir) — choix des profils **par intention** : `EveningEvent.option_for_intent()` (l'option demandée, sinon la variante offerte au même libellé : `loyal` → `loyal_paid`, `pay` → `pay_denounced`, `keep` → `keep_broke`), `SimProfile.choices_for()` / `option_for()` utilisés par `BalanceSimulator` (coûts de postes compris), `qa_campaign` et `test_act3_campaign` ; `test_sim_profiles_choose_an_available_deposition_option` sans `pending` (`loyal`, `accusateur`, avec et sans `montclair_pliable`) ; vraie scène graine 3 `loyal` depuis la sauvegarde v4 : `d29_deposition: loyal_paid`, plus aucun « choix refusé ». Constat d'origine : **Profil `loyal` : option de Déposition absente** quand `montclair_pliable` (SC-70 approuvée) : l'option `loyal` est remplacée par `loyal_paid` (même libellé, +20 ₵), le profil demande `loyal`, le choix est refusé et la Déposition retombe sur « Se taire » (soupçon +1) — dans `balance_sim` comme dans `qa_campaign` (graine 3). Fausse les mesures F4 / F1 du profil loyal quand Montclair est passée | Gameplay Systems (`sim_profile.gd`, ou repli `loyal` → `loyal_paid` dans `balance_simulator.gd`) | `test_sim_profiles_choose_an_available_deposition_option`, log graine 3 |
| QA-037 | Mineur | ✅ Corrigé (commit à venir) — `DayDef.anomaly_count_targets` (cible §2.1, scénarisés inclus, lue par `gen_stats`) et `anomaly_count_weights` **compensés** par jour (`build_data_act3.gd` `COUNT_WEIGHTS`) : J21 0/1 anomalie 47,8 / 37,7 % (cibles 48 / 37), J29 42,4 % et J30 36,8 % de cas propres (42 / 36), tous les jours J21–J30 à ±2 points (graine 7 : ±3) ; `EXPIRED_DOCUMENT` du J21 0,12 → 0,06 (18,1 → 12,4 % des anomalies ; `WANTED_PERSON` reste à 2 entrées imposées, avis du jour + SC-53) ; `SPONSOR_MISMATCH` / `SUSPENDED_CONTRACT` **conditionnels** relevés (0,6–1,5 / 0,3–0,8, J25–J27, J29) et visites familiales `TYC` 0,50 aux J25–J27 : R34 4,4 / 3,4 / 2,5 / 7,9 % des cas (J25/J26/J27/J29 ; 0,6 / 1,6 / 0,7 / 1,5 avant), R35 7,8 / 6,5 / 4,3 % (J25–J27 ; 3,7 / 1,3 / 0,6) ; au passage, `ForgedSummonsInjector` refuse un cas sans carte d'identité (invariant violé MISSING_DOCUMENT + FORGED_SUMMONS révélé par les nouveaux poids). `gen_stats` J1–J30 : invariants OK, 0 re-tirage ; `balance_sim` J1–J30 (8 préréglages + `accusateur`, 20 graines) dans ±5 points sauf `drift` 80 % (F6 60 → 75 %, voulu : ACT3 §6.6). Constat d'origine : **Générateur Acte III, écarts aux cibles** (`gen_stats`, 40 campagnes) : **J21 « respiration » plus dense que prévu** — 0 anomalie 41 % (cible 48 %), 1 anomalie 49,5 % (37 %), `WANTED_PERSON` 19 % et `EXPIRED_DOCUMENT` 18 % des anomalies (poids 4,7 / 9,4 %), DÉTENTION attendue 19 % des cas : c'est le 2ᵉ jour le plus raté du bot (51 %) ; **mécaniques nouvelles peu exercées après leur jour d'introduction** : R34 répondant 6,6 % des cas au J24 puis 0,6 % (J25) et 1,6 % (J26) pour 6–8 % de poids ; R35 lock-out 3,7 % au J25 (poids 11,8 %), ≈ 0 ensuite ; `UNREGISTERED_VESSEL` 0,2–1,5 % pour 15,7 % de poids (sauf J27 : 7,7 %). J29/J30 : 52–53 % de cas propres (cibles 42/36 %) | Gameplay Systems (`build_data_act3.gd`, injecteurs) + Game Designer | `gen_stats` |
| QA-039 | Mineur | ✅ Corrigé (commit à venir) — cause : `AudioMixBarrier.quit_after_silence()` arrêtait les lecteurs mais laissait la scène vivante pendant l'attente (8 images + 250 ms) : la scène pouvait **relancer** un son (musique posée juste après l'apparition de l'écran de fin quand le bot le lit dans la même image, pas / annonces / barks du shift) → lecture active à la sortie. Désormais la scène courante est d'abord **déchargée** (`AudioDirector._exit_tree` : plus aucun son, lecteurs vidés, caches libérés), puis arrêt des lecteurs restants avant et juste avant `quit()` (appel unique). Vérifié : 3 campagnes réelles J20 → J30 depuis les sauvegardes v4 (`loyal` F7, `solidaire` F9, `luciole` F7 ; avant le correctif, `loyal` : `18 ObjectDB … / 10 resources …`), captures de l'écran de fin F7 / F2 / F9 et du J30 (figure finale) : 0 fuite. Constat d'origine : **Fuites à la sortie revenues** (QA-025) : `11 ObjectDB instances were leaked` + `8 resources still in use at exit` après l'écran de fin (F7 graine 3, F2 graines 7 et 42 : 3 campagnes sur 10) ; `7 … / 4 …` après une capture du J30 (figure finale). Aucun effet joueur, journal pollué | Audio Designer / Godot Architect (`AudioMixBarrier.quit_after_silence`, ressources de l'écran de fin / SC-82) | logs |
| QA-035 | Cosmétique | ✅ Corrigé (commit à venir) — **Objets glissés de l'Acte III dessinés comme une carte de quai « Q6 »** : le dessin par défaut de `SlippedItemView` (branche `_`) sert pour OBJET (« Douze convocations vierges », SC-66), CONVOCATION (ENQ-0004, SC-76), REGISTRE (SC-82) | UI/UX Expert (`slipped_item_view.gd:265-273`) | `QA-035.png` |
| QA-038 | Cosmétique | ✅ Corrigé (commit à venir) — **Carte d'identité seule sur le plan de travail** (J26, permis manquant) : le libellé « FIRMWARE NX » est replié **lettre par lettre** en colonne (repli de QA-029 dans une colonne trop étroite), la valeur glisse à côté du sceau | UI/UX Expert (`doc_field_view.gd`, `document_view.gd`) | `QA-032.png` (carte au centre) |
| QA-040 | Cosmétique | ✅ Corrigé (commit à venir) — Deck : en-tête du panneau passager tronqué pour les noms composés (« PASSAGÈRE · D. LINDQVIST- » contre « INTERCOM ») | UI/UX Expert (`passenger_panel.gd`) | `QA-040-deck.png` |

Total Acte III : **0 bloquant, 2 majeurs, 4 mineurs, 3 cosmétiques** (9 bugs, QA-032 à QA-040). Aucun bug de l'Acte II réapparu hors QA-025 (QA-039) ; QA-020 (plan de travail à 2–3 documents côte à côte), QA-031 (barre du haut en texte 1,5), QA-021/QA-023 tiennent ; suite verte.

### 13.8 Difficulté observée (Game Designer)

- **Le bot de la vraie scène (56–62 % de conformité cumulée depuis le J1) n'atteint le J30 qu'avec +3 000 ₵** (3/3 : F9, F7, F7, solde final 306–407 ₵) ; avec +1 500 ₵ (qui suffisaient au J20 à l'Acte II), **0/4** : F2 au soir du J24 (registre) et du J28 (×2), F3 au soir du J27. Les prélèvements emportent ≈ 30 % des crédits QA (J11 : 369 ₵ sur 1 270 ; J17 : 126 ; J25 : 20–56) et l'Acte III coûte au bot ≈ 25–40 ₵ par jour (charges ≈ 52 ₵ + oxygène 15 ₵ les jours pairs, net de shift moyen ≈ +5 à +15 ₵).
- **Depuis une vraie sauvegarde du J20 (80 % de conformité)** : 2/3 atteignent le J30 (F7, 90–121 ₵) ; la 3ᵉ (grève, 592 ₵ au J20) finit F2 au soir du J29 après un J22 à 3/16.
- **Précision du bot par jour (10 campagnes)** : J20 60 %, **J21 51 %**, J22 53 %, J23 56 %, J24 55 %, J25 64 %, J26 61 %, **J27 48 %** (net −22 ₵ en moyenne), J28 58 %, J29 71 %, J30 77 %. Le J21 de « respiration » est l'un des plus durs (QA-037) ; le J27 (« respiration », quota rétabli à 4) est le plus coûteux.
- **Simulation** (erreurs au hasard) : à 65 %, **aucune** campagne complète n'atteint le J21 (F2/F3 vers J10–J14) ; à 80 %, 75–100 % atteignent le J30 mais **la Déposition arrête 10–25 % des profils** (F1 au J29 : `default` 15 %, `luciole` 20 %, `temoin` 25 %, `passeur` 25 %) ; à 95 %, chaque profil obtient sa fin (F4, F5, F8, F9, F10 85 %, F6 85 %).
- **Lecture** : l'Acte III tient la cible « dur mais pas un mur » pour un joueur ≥ 80 % (D-089), mais il **ajoute peu de respiration réelle** : J21 et J27 sont plus durs que les jours à règle nouvelle pour un joueur qui ne lit pas les onglets. Recommandé (Game Designer) : ramener le J21 à sa cible (moins d'avis de recherche / d'expirés, QA-037) ; vérifier en playtest humain que la Déposition à 7 (D-094) n'arrête pas un quart des joueurs prudents qui « se taisent » ; avec QA-032 corrigé avant tout playtest J24–J28 (Main courante et Convocations lisibles).

### 13.9 Perf indicative

`tools/qa_perf.gd` sous xvfb (llvmpipe, machine non chargée), graine 3, 1920×1080.

| Scène | Appels de dessin | Primitives | Image moyenne / p95 (llvmpipe) |
|---|---|---|---|
| J7, 1ᵉʳ passager (référence Acte I) | **325** | 50 000 | 253 / 285 ms |
| **J24**, 3ᵉ passager (répondant, 2 documents) | **302** | 51 200 | 254 / 282 ms |
| **J30**, figure finale (Dora, registre glissé) | **323** | 48 600 | 253 / 270 ms |

Lecture : le Retour aux quais (D-085) **ramène l'Acte III sous l'Acte I** (−100 appels par rapport au J20 de l'Acte II, 408) ; la figure finale et les accessoires de SC-81/82 ne coûtent rien (pièces fusionnées).

### 13.10 Recommandations priorisées

1. **QA-032** (Rulebook à 16 onglets) avant tout playtest J24–J30 : les mécaniques propres à l'acte (Main courante, Convocations, règles R32–R37) se lisent dans une liste de 1–2 lignes.
2. **QA-033** : bandeau de résultat hors des documents (réserver sa hauteur dans `_plan_layout`, ou le poser en haut du plan de travail).
3. **QA-034** : soirée — cadre des dépenses à hauteur du contenu (ou rations repliées), indice de défilement visible.
4. **Difficulté (§13.8)** : J21 à sa cible (QA-037), décider si l'Acte III doit être atteignable pour un joueur ~60 % sans crédits ; playtest humain J21–J24 et Déposition (D-094).
5. QA-036 (profil `loyal` → `loyal_paid`) puis relancer `balance_sim` ; QA-037 (R34/R35 exercées après leur jour d'introduction).
6. Journaux propres : QA-039.
7. Cosmétique : QA-035, QA-038, QA-040.
8. QA (suite) : pause / « Quitter » en pleine Enquête dans la vraie scène, avance de l'Arbitre (`d21_loan`) en vraie scène, F1 (Déposition), F10 et F6 du J27 jouées à la main, perf sur GPU / Steam Deck réel.

### 13.11 Rejouer la passe Acte III

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit     # 581 tests, 4 pending QA-032…036
# Reprise d'une sauvegarde v4 réelle du J20 (migration v4 → v5, carte de fin d'acte, J20 → J30)
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-load=$PWD/tests/fixtures/qa_save_v4_j20_solidaire.json --qa-profile=solidaire --qa-speed=10 --qa-reload
# Campagne J1–J30 (≈ 20 min ; en tronçons : `timeout 540`, puis --qa-load=<copie de user://saves/slot_0.json>)
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-seed=23 --qa-profile=solidaire --qa-speed=10 --qa-credits=3000 --qa-reload
# Fins F1–F10 simulées
godot --headless --script res://tools/balance_sim.gd -- --seeds=20 --seed=1 --profiles=0.65,0.8,0.95 \
    --presets=default,loyal,luciole,passeur,temoin,solidaire,mercenary3,drift
# Captures (QA-033 : bandeau juste après la comparaison ; QA-032 : onglet Règles du J26)
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1920x1080 --qa-wait=30 \
    --qa-after-check=0.8 --qa-out=/tmp/j24.png --seed=3 --day=24 --screen=shift --rulebook-tab=ledger --inspect \
    --start-case=2 --flags=act2_started,act3_started --reduce-motion
```

---

## 14. Passe QA M11 « Confort »

> Passe du 29.10.2026 sur `claude/laughing-bell-8ayudz` après `4bbda95` (lots A/B/C : sauvegarde v6 à 3 emplacements + instantanés + fins archivées + profil, mode Récit, vision des couleurs `Palette`, manette complète, carte d'identité redessinée, écrans Nouvelle partie / Charger / reprise d'un jour, tutoriel du J1). Godot 4.7.2, GUT 9.7.1. **QA ne corrige pas le code de jeu** : bugs QA-041 à QA-049 ci-dessous, chacun avec son propriétaire suggéré.

### 14.1 Méthode et couverture

| Volet | Outil | Résultat |
|---|---|---|
| Suite existante | GUT complet | **638 / 638** avant la passe ; **655 tests (647 verts + 8 `pending` QA-041…047)** après ajout de `tests/integration/test_qa_m11.gd` |
| Campagnes réelles | `tools/qa_campaign.gd` (vraie `day.tscn`, `--autoplay`, ×10, `--qa-reload` = « Quitter → Continuer » réel chaque jour), tronçons ≤ 9 min repris par `--qa-load=<slot_1/current.json>` | 5 campagnes (§14.2), dont 2 en Récit et une reprise d'une vraie sauvegarde 0.10.0 : **0 `QA_ISSUE`**, 0 `SCRIPT ERROR`, 0 fuite |
| Campagnes simulées | `balance_sim --story` (8 préréglages × 65 / 80 / 95 %, 20 graines ; 10 pour les 3 derniers) | §14.2.2 |
| Manette seule | `test_qa_m11.gd` : **vrais** `InputEventJoypadButton` / `InputEventJoypadMotion` via `Input.parse_input_event` (pas d'`InputEventAction`), parcours en largeur du graphe de focus à la croix | §14.3 |
| Sauvegardes | dossiers `user://` isolés (`XDG_DATA_HOME` temporaire pour les outils, `SaveService.use_root` pour GUT) ; vraie sauvegarde 0.10.0 `tests/fixtures/qa_save_v5_j25_*` posée en `slot_0.json` | §14.4 |
| Accessibilité | captures réelles OpenGL 3 sous xvfb (`qa_capture` : `--qa-set=color_vision:N`, `--qa-set=text_scale:1.5`, `--qa-discord`, `--qa-pad`, `--demo-saves`, `--title=…`, `--tutorial-step`, `--story --close-booth`) ; lecture des shaders ; ΔE2000 simulé (Machado 2009) de la lumière de porte | §14.5 |
| Données / exports | `build_data` (md5 de `data/*/*.tres` avant / après), `bash tools/export_all.sh linux`, `bash tools/smoke_export.sh` | §14.6 |

**Vrai `user://saves` jamais touché** : vide avant et après la passe (vérifié), `settings.cfg` du joueur inchangé (md5) ; aucun `override.cfg` créé dans le projet.

### 14.2 Campagnes automatiques

#### 14.2.1 Vraie scène (`day.tscn`, bot `--autoplay`, ×10, `--qa-reload`)

| Graine | Profil | Mode | Départ | Crédits QA | Fin | Jour | Solde final | Conformité | Problèmes |
|---|---|---|---|---|---|---|---|---|---|
| 23 | solidaire | **Récit** | J1 | — | **F3** famille perdue | soir J22 | 7 ₵ | 61 % | aucun `QA_ISSUE` (Dora perdue au J15, Noa au J16 : soins non cochés par le bot, choix par défaut) |
| 7 | loyal | **Récit** | J1 | +3 000 | **F7** Le guichet rouvre | J30 | 1 169 ₵ | 63 % | aucun |
| 23 | solidaire | Dur | J1 | +3 000 | **F9** grève | J30 | 315 ₵ | 60 % | aucun |
| 3 | loyal | Dur | J1 | +3 000 | **F7** | J30 | 436 ₵ | 60 % | aucun |
| 11 | solidaire | Dur | **sauvegarde 0.10.0** `qa_save_v5_j25_solidaire` (vraie `migrate_legacy`) | — | **F9** | J30 | 186 ₵ | 85 % | aucun |

- **Récit** : chaque jour, **toute la file prévue est traitée** (pas de fin à l'heure ; seul le J20 s'arrête à 10/18 sur l'annonce de grève `ends_shift`, comme prévu) ; **0 ₵ d'amende** : net du shift = 5 ₵ × conformes chaque jour (ex. J1 6/8 conformes, 2 citations → +30 ₵ ; en Dur, même graine : +20 ₵) ; citations comptées (Revue, Déposition). Profil après F7 : `endings_seen = [{f7_reopens, J30, date}]`, `story_mode_used = true`, 85 personnages croisés.
- **À chaque soir** (`qa_campaign`) : sauvegarde relue = état en mémoire + instantané du matin présent ; « Continuer » reprend bien l'emplacement 1 (≈ 115 rechargements réels) ; **à la fin, partie archivée** (`meta.status = ended`, bonne `ending_id`) et fin inscrite au profil — 5 / 5.
- Remarque outil : `QA_ISSUE solde aberrant` sur les campagnes à +3 000 ₵ (borne du contrôle, attendu) ; `QA_END day=31` après le J30 = jour suivant non joué (attendu).

#### 14.2.2 Simulation en mode Récit (`balance_sim --story`, dépenses `reasoned`)

| Préréglage (Récit) | 65 % | 80 % | 95 % |
|---|---|---|---|
| `default` | F1 60 · F7 30 · F3 10 (J6) | F7 95 · F1 5 | F7 100 |
| `loyal` | F7 95 · F3 5 (J6) | F7 100 | F4 100 |
| `luciole` | F1 60 · F5 25 · F3 15 (J6) | F5 80 · F1 20 | F5 100 |
| `passeur` | F1 75 · F3 15 · F7 10 | F7 55 · F1 25 · F10 20 | F10 85 · F7 15 |
| `temoin` | F1 80 · F3 15 · F8 5 | F8 80 · F1 20 | F8 100 |
| `solidaire` | F1 50 · F9 40 · F3 10 | F9 100 | F9 100 |
| `mercenary3` | F1 90 · F3 10 | F1 90 · F7 10 | F1 90 · F7 10 |
| `drift` | F1 50 · F6 40 · F3 10 | F6 90 · F1 10 | F6 90 · F10 10 |

Fins vues en Récit : F1, F3, F4, F5, F6, F7, F8, F9, F10 (F2 seulement avec `story_evicted`, couvert par `test_every_ending_is_reachable_in_story_mode`). **Lecture (Game Designer)** : sans amendes, un joueur à 65 % reste à 4–10 ₵ du J2 au J6, perd un proche dans 10–15 % des parties dès le J6 (F3) et finit arrêté à la Déposition (F1, J26–J29) dans 50–90 % des cas : le mode « Pour l'histoire, sans pression » ne protège ni le foyer ni la Déposition — voir QA-049.

### 14.3 Manette seule (sans souris ni clavier)

Parcours joués dans la vraie scène avec de vrais événements de manette (Xbox) :

| Étape | Commandes | Résultat | Test |
|---|---|---|---|
| Titre → Nouvelle partie → emplacement → RÉCIT | Ⓐ, Ⓐ, croix →, Ⓐ | ✅ partie en Récit, emplacement occupé (matin du J1), tutoriel demandé | `test_pad_title_new_game_story_to_day_one` |
| Briefing | Ⓐ | ✅ focus PRENDRE SON POSTE | (tous) |
| Tutoriel complet (6 étapes) + 1ᵉʳ passager | Ⓐ COMMENCER (appelle aussi le passager, cf. QA-041), LT, RB, Ⓐ champ A, croix → jusqu'à une règle, Ⓐ, Y, Ⓐ question, RT maintenu | ✅ 6 étapes validées par les vraies actions, « TUTORIEL TERMINÉ » | `test_pad_only_tutorial_and_first_passenger` |
| Lien entre deux documents | Ⓐ champ A, stick droit → (document suivant, le focus suit), Ⓐ | ✅ (un champ du **même** document remplace A : prévu, `REPLACED_A`) | — |
| J1 complet, bilan, soirée | Ⓐ / RT par passager, Ⓐ CONTINUER, Ⓐ VALIDER ET DORMIR | ✅ 8 / 8 tamponnés, nuit validée, sauvegarde du soir | `test_pad_only_day_one_summary_and_evening` |
| Détention | L3 maintenu 0,8 s (J7) | ✅ verdict DETAIN | `test_pad_detention_with_left_stick_click` |
| Pause, Options, Récit → Dur | Menu, croix ↓, Ⓐ OPTIONS, croix ↓ ×17, Ⓐ PASSER EN MODE DUR, croix →, Ⓐ, Ⓑ, Ⓑ | ✅ (voir §14.4) | `test_pad_pause_story_to_hard_after_closing_time_ends_the_shift` |
| Écran de fin | Ⓐ | ✅ retour au titre | `test_pad_end_screen_and_load_screen_past_day` |
| Charger → jour passé | croix ↓↓, Ⓐ CHARGER, croix ←↓, Ⓐ, croix ←←, Ⓐ, croix →, Ⓐ (boîte : focus ANNULER) | ✅ matin du J4 repris | idem |
| Quitter en plein shift | Menu, croix ↓↓, Ⓐ, Ⓐ (deux temps) | ✅ | `test_quit_mid_shift_writes_nothing_and_continue_replays_the_day` |
| **FERMER LE GUICHET** (Récit, quota atteint) | croix ↑ depuis SUIVANT, Ⓐ | ❌ **entre deux passagers, Ⓐ appelle le passager suivant** (QA-041) ; ✅ pendant un passager (bouton joignable à la croix, Ⓐ ferme) | `test_pad_a_on_close_booth_…` (pending) |
| **PASSER LE TUTORIEL** (accueil) | croix depuis COMMENCER, Ⓐ | ❌ **injoignable** (toute direction → SUIVANT, QA-042) et, focus forcé, **Ⓐ appelle un passager et commence le tutoriel** (QA-041) | `test_pad_a_on_tutorial_skip_…`, `test_pad_dpad_reaches_the_tutorial_buttons` (pending) |
| PASSER L'ÉTAPE / QUITTER pendant le tutoriel | croix | ⚠️ point connu **confirmé et aggravé** : entre deux passagers, PASSER L'ÉTAPE n'est jamais joignable (6 contrôles atteints depuis SUIVANT, QUITTER seul — et Ⓐ dessus appelle un passager) ; en inspection, les deux sont joignables par navigation géométrique depuis certains champs (22 contrôles), et depuis QUITTER la croix → part sur un bouton du guichet, pas sur PASSER L'ÉTAPE (QA-042) | idem |

**Bilan** : une campagne reste jouable à la manette seule (critère M11 §6 tenu), mais **deux gestes M11 font autre chose que le bouton qui a le focus** (QA-041) et le tutoriel ne se passe pas à la manette depuis son accueil (contournement : COMMENCER puis QUITTER en inspection, ou Options › Partie › Tutoriel du jour 1).

### 14.4 Sauvegardes v6 et mode Récit

| Scénario | Résultat | Preuve |
|---|---|---|
| Vraie sauvegarde 0.10.0 (`qa_save_v5_j25_luciole`) posée en `user://saves/slot_0.json` d'un profil vierge, lancement du titre | ✅ emplacement 1 : `current.json`, `meta.json`, `day_25.json` (seul le jour courant) ; `slot_0.v5.bak` gardé ; titre « CONTINUER — JOUR 25 » ; carte JOUR 25 · ACTE III · ₵ 667 · « 3 vivants · 1 absent·e » · date d'origine · « < 1 min » ; état relu = fixture (graine, jour, crédits, score, citations, drapeaux, mémoire, historique) ; `difficulty = hard` | `m11_qa_migration_load.png`, `test_real_v5_save_appears_on_title_and_load_screen` ; `qa_save_v5_j25_solidaire` jouée J25 → F9 (§14.2) |
| 3 emplacements, « Continuer » = partie active la plus récente, terminées exclues | ✅ | tests existants + `--demo-saves` |
| Reprendre le J1 d'une partie **terminée** (F3) puis jouer le jour à la manette | ✅ instantanés J3–J5 supprimés à la soirée (`[1, 2]`), partie `active`, Continuer → emplacement 1, F3 reste au profil | `test_resume_first_day_of_ended_game_truncates_and_reactivates` |
| Fin → partie archivée + fin au profil | ✅ 5 / 5 campagnes réelles (`qa_campaign` contrôle `meta.status`, `ending_id`, profil) | §14.2 |
| Quitter en plein shift puis Continuer | ✅ `current.json`, `meta.json`, instantanés **identiques à l'octet** ; Continuer reprend le matin du jour abandonné | `test_quit_mid_shift_…` |
| `meta.json` absent (partie active) | ✅ reconstruite depuis `current.json` | test existant |
| `meta.json` absent (partie **terminée**) | ❌ reconstruite « active » : la partie terminée revient sous CONTINUER (QA-044) | `test_ended_game_stays_ended_when_meta_is_lost` |
| `current.json` corrompu, méta et instantanés intacts | ❌ CONTINUER — JOUR 4 et REPRENDRE restent actifs et **ne font rien** (aucun message), alors que `day_04.json` (même contenu) est lisible ; contournement : REPRENDRE UN JOUR PASSÉ (QA-043) | `test_corrupt_current_…` |
| `.tmp` orphelin tronqué d'un nouvel instantané (`day_06.json.tmp`) | ❌ listé : « JOUR 06 · DERNIER » reçoit le focus, le choisir ne fait rien (QA-045) | `test_orphan_truncated_tmp_snapshot_…` |
| `current.json.tmp` plus récent que `current.json` (coupure entre écriture et renommage) | ⚠️ l'ancien `current.json` est lu (le `.tmp` n'est qu'un secours) : la dernière soirée est perdue pour Continuer mais son instantané `day_NN` est présent et proposé comme dernier jour ; pas de perte, comportement QA-018 attendu | sonde |
| Récit : pas de fin à l'heure, 0 ₵ d'amende, fins atteignables | ✅ (§14.2) | campagnes, `balance_sim --story` |
| Récit → Dur en plein shift, horloge **déjà passée 18:00** (bloquée à 18:00 sans fin en Récit) | ✅ l'horloge expire dès la confirmation ; le shift s'arrête après le passager en cours (bilan) ; RÉCIT et FERMER LE GUICHET disparaissent | `test_pad_pause_story_to_hard_…` |
| Dur → Récit | ✅ refusé (`set_difficulty(&"story") == false`, aucune commande) | idem |
| Récit → Dur **puis quitter avant la soirée** | ❌ « Continuer » (et « jour passé ») revient en **Récit** : le choix « irréversible » n'est écrit qu'à la soirée (QA-046) | `test_hard_mode_switch_is_not_undone_…` |
| Fermer le guichet (Récit, jour à quota) | ✅ pendant un passager ; ❌ entre deux passagers à la manette (QA-041) ; logique : test existant `test_close_booth_once_the_quota_is_full` | — |

### 14.5 Accessibilité

| Contrôle | Résultat | Preuve |
|---|---|---|
| Vision des couleurs, 4 modes, sur une vraie DISCORDANCE (J2, carte expirée ↔ date du jour) : bandeau, lien, losange, puce « 1 DOCUMENTÉE », tampons | ✅ Aucune : magenta ; Protan·Deutan : lien rose pâle, APPROUVÉ bleu ; Tritan : lien violet, APPROUVÉ vert-jaune ; Contraste élevé : états plus clairs. Losange au milieu du lien et icônes des tampons dans tous les modes | `m11_qa_colorvision_4modes.png` (Aucune · Protan·Deutan / Tritan · Contraste élevé) |
| Lumière de porte 3D (`BoothDirector._pulse_light` : `Palette.STATE_GREEN` / `Palette.STATE_RED`, détention `DS.ACCENT_YELLOW`) | ✅ relue à chaque impulsion ; ΔE2000 simulés (Machado, sévérité 1) — Protan·Deutan vu deutan : vert/rouge 59, vert/détention 68, rouge/détention **21** ; Tritan vu tritan : 59 / 32 / 35 ; sans filtre vu deutan : 20 / 16 / 22. Distinguable dans chaque mode ; la détention garde le jaune du contrat (signalé, pas un bug) | calcul §14.5 |
| Liens du scanner Luciole (J12, `scanner_luciole`) | ⚠️ en-tête « BOÎTIER MAGENTA · SCAN · DATES CONFORMES » vu en Protan·Deutan ; pas de lien de suggestion dans les cas capturés (dates conformes) — glyphes de source non revus à l'écran | capture de travail |
| `holo_flicker` coupé | ✅ documents (scanlines / bord), hologrammes du guichet (`booth_holo.gdshader`, `flicker = 0`) ; ❌ **néons « instables » (chute de 60 % ≤ 2 Hz) et écrans holo (scanlines, balayage) de `booth_emissive.gdshader` continuent** : ils ne suivent que `fx_intensity` (QA-047) | `test_holo_flicker_off_also_freezes_booth_neons_and_screens` |
| `text_scale` 1,5 — titre, Nouvelle partie (emplacements, écrasement, difficulté), Charger, jours passés, tutoriel, barre Récit + FERMER LE GUICHET, Options en jeu, 1080p et Deck | ✅ aucun débordement ni texte coupé ; au Deck la barre du haut replie titre, SHIFT et « SANS CHRONO » (QUOTA ATTEINT et FERMER LE GUICHET visibles) ; libellés « maintenir … » des tampons masqués (comme QA-031) ; légendes et puces identiques à 1,0 au Deck (le plancher de 18 px = 12 × 1,5 — attendu) | `m11_qa_game_screens_1080_text150.png`, `m11_qa_game_screens_deck_text150.png`, `m11_qa_tutorial_deck_text150.png`, `m11_qa_story_bar_deck_text150.png`, `m11_qa_options_deck_text150.png` |
| Deck 1280×800 | ✅ mêmes écrans (ci-dessus) ; carte d'identité et glyphes manette : captures du lot B | — |

### 14.6 Régression

| Contrôle | Résultat |
|---|---|
| GUT complet | ✅ **638 / 638** à l'arrivée (306 s) ; après la passe : **655 tests, 647 verts + 8 `pending`**, 0 échec (365 s) |
| `build_data` | ✅ « build_data : OK », **119 `.tres` identiques** (md5 avant / après) |
| `bash tools/export_all.sh linux` | ✅ `build/dist/CLEARANCE-0.10.0-linux.tar.gz` (37 Mo) — nom de version : QA-048 |
| `bash tools/smoke_export.sh` | ✅ release_title + debug J1, J4, J7, J10, J15, J20, J25, J30 : OK |
| Campagnes J1 → J30 en Dur, 2 profils | ✅ F9 (`solidaire`, graine 23) et F7 (`loyal`, graine 3), 0 `QA_ISSUE` (§14.2) |
| Journaux | ✅ aucune `SCRIPT ERROR`, aucune fuite à la sortie (QA-039 tient) dans les 10 tronçons de campagne |

### 14.7 Liste des bugs (M11)

Statut : 🔴 ouvert.

| ID | Sév. | Titre | Reproduction | Propriétaire suggéré | Preuve |
|---|---|---|---|---|---|
| QA-041 | **Majeur** | ✅ Corrigé (0.11.0) — **Ⓐ entre deux passagers appelle le passager suivant au lieu d'activer le bouton qui a le focus.** `next_case` est lié à Ⓐ (bouton 0, comme `ui_accept`) et traité dans `ComparisonUI._input` (avant l'interface, `set_input_as_handled`) dès que la phase est `WAITING_CASE`. Conséquences manette : **FERMER LE GUICHET** (Récit), atteint comme documenté par croix ↑ depuis SUIVANT, appelle un passager ; **PASSER LE TUTORIEL** appelle un passager et **commence** le tutoriel (impossible de le passer à la manette depuis l'accueil) ; même chose pour QUITTER (tutoriel), une carte de règle du Rulebook, etc. | Récit, quota atteint, entre deux passagers : croix ↑ depuis SUIVANT, Ⓐ. Ou J1 avec tutoriel : focus sur PASSER LE TUTORIEL, Ⓐ | UI/UX Expert (`comparison_ui.gd` `_input` : n'appeler `request_next_case` que si le focus est sur SUIVANT ou hors de tout bouton ; ou `next_case` en `_unhandled_input`) | `test_pad_a_on_close_booth_closes_instead_of_calling_a_passenger`, `test_pad_a_on_tutorial_skip_skips_instead_of_calling_a_passenger` |
| QA-042 | Mineur | ✅ Corrigé (0.11.0) — **Boutons du tutoriel hors de portée de la croix.** La carte (`TutorialOverlay`) n'est pas dans la racine du guichet : à l'accueil, **toute** direction depuis COMMENCER est reprise par le `FocusGuard` du guichet et renvoie à SUIVANT (PASSER LE TUTORIEL jamais atteint) ; entre deux passagers, PASSER L'ÉTAPE n'est jamais atteint (6 contrôles joignables depuis SUIVANT) ; en inspection, PASSER L'ÉTAPE / QUITTER ne sont joignables que par navigation géométrique depuis certains champs, et la croix → depuis QUITTER ne mène pas à PASSER L'ÉTAPE. Confirme et précise le point connu | J1, tutoriel : croix ← depuis COMMENCER ; puis COMMENCER et explorer à la croix depuis SUIVANT | UI/UX Expert (`tutorial_overlay.gd` : `FocusGuard.attach` sur la carte, voisins explicites COMMENCER ↔ PASSER, et un raccourci manette, ex. Vue maintenue = passer l'étape) | `test_pad_dpad_reaches_the_tutorial_buttons` |
| QA-043 | Mineur | ✅ Corrigé (0.11.0) — **`current.json` illisible : CONTINUER et REPRENDRE morts, sans message**, alors que `day_NN.json` du même matin (même contenu à l'écriture) est intact. Le joueur croit sa partie perdue ; contournement : REPRENDRE UN JOUR PASSÉ… → dernier jour | corrompre `slot_1/current.json` (méta et instantanés intacts), lancer le titre, CONTINUER | Godot Architect (`SaveService.load_current` : secours sur `day_<current_day>.json` ; sinon désactiver avec « Sauvegarde illisible ») | `test_corrupt_current_does_not_leave_a_dead_continue_button` |
| QA-044 | Mineur | ✅ Corrigé (0.11.0) — **Partie terminée « ressuscitée » si `meta.json` est perdu** : la méta est reconstruite depuis `current.json` avec `status = active` ; la partie F1–F10 revient sous CONTINUER (rejoue son dernier matin) et la carte n'affiche plus « PARTIE TERMINÉE » | partie terminée, supprimer `slot_N/meta.json`, ouvrir le titre | Godot Architect (`SaveService.mark_ended` : écrire aussi `status` / `ending_id` dans `current.json`, ou garder un `meta.json.bak`) | `test_ended_game_stays_ended_when_meta_is_lost` |
| QA-045 | Mineur | ✅ Corrigé (0.11.0) — **`.tmp` orphelin tronqué listé comme dernier matin** : `list_snapshots` compte `day_06.json.tmp` (coupure pendant l'écriture d'une soirée) ; la grille affiche « JOUR 06 · DERNIER » avec le focus, le choisir ne fait rien (aucun message) | `slot_3` J1–J5 + `day_06.json.tmp` tronqué ; Charger › REPRENDRE UN JOUR PASSÉ… | Godot Architect (`list_snapshots` : ne garder que les jours lisibles, ou ignorer un `.tmp` sans principal) + UI/UX (`LoadScreen.choose_day` : message si l'instantané est illisible) | `test_orphan_truncated_tmp_snapshot_is_not_offered` |
| QA-046 | Mineur | ✅ Corrigé (0.11.0) — **Récit → Dur annulé en quittant avant la soirée** : la boîte annonce « Impossible de revenir en mode Récit » mais le choix n'est écrit qu'à la sauvegarde du soir ; « Quitter → Continuer » (ou un plantage) recharge la partie en Récit (D-102 : jamais l'inverse) — contournement exploitable pour éviter un shift en Dur | partie Récit, Pause › Options › PASSER EN MODE DUR, confirmer, QUITTER VERS LE TITRE, CONTINUER | Godot Architect (`GameState.set_difficulty` : mettre à jour `meta.json` / `current.json` de l'emplacement actif, difficulté seule) | `test_hard_mode_switch_is_not_undone_by_quitting_before_the_evening` |
| QA-047 | Mineur | ✅ Corrigé (0.11.0) — **« Scintillement holographique » coupé : le guichet scintille encore.** `booth_emissive.gdshader` (néons « instables » : chute de 60 % ≤ 2 Hz ; écrans holo : scanlines + balayage) ne lit que `fx_intensity` ; `BoothQuality` ne transmet `holo_flicker` qu'à `booth_holo`. D-109 promet « scintillement, scanlines, glitchs » coupés sans perdre les lueurs. Au passage, l'aide d'Options « Effets visuels » dit encore « Scanlines, scintillement, lueurs des hologrammes » (`opt_fx_hint`) | Options › Scintillement holographique : DÉSACTIVÉ, Effets : COMPLETS ; observer les néons du guichet | 3D Designer / Asset Lead (`booth_emissive.gdshader` : uniforme `flicker` sur les modes 1 et 2) + Design System (`booth_quality.gd`, `opt_fx_hint`) | `test_holo_flicker_off_also_freezes_booth_neons_and_screens` |
| QA-048 | Cosmétique | ✅ Corrigé (0.11.0) — **Version non montée** : `application/config/version = "0.10.0"` ; les sauvegardes v6 portent `game_version: "0.10.0"` (indistinguables d'une 0.10.0 dans les journaux et la méta), l'export s'appelle `CLEARANCE-0.10.0-linux.tar.gz` et le titre affiche v0.10.0 alors que M11 = 0.11.0 (`docs/M11.md`) | `export_all.sh linux` ; `meta.json` d'une partie neuve | Orchestrateur (`project.godot`, `CHANGELOG.md` au moment de la livraison) | `build/dist`, `meta.json` |
| QA-049 | Mineur (design) | ✅ Corrigé (0.11.0) — **Mode Récit peu protecteur pour un joueur débutant** : « Pour l'histoire, sans pression » ; à 65 % de précision, `balance_sim --story` : solde 4–10 ₵ du J2 au J6, F3 (famille perdue) 10–15 % dès le J6, F1 (Déposition) 50–90 % aux J26–J29 ; dans la vraie scène, bot ~60 % sans crédits QA : Dora puis Noa perdues aux J15–J16, F3 au soir du J22 | `balance_sim --story --profiles=0.65` ; `qa_campaign --qa-story --qa-seed=23 --qa-profile=solidaire` | Game Designer (`GDD.md` : salaire plancher, Déposition ou soins adoucis en Récit — décision à consigner) | §14.2 |

Total M11 : **0 bloquant, 1 majeur, 6 mineurs (dont 1 de design), 1 cosmétique** (QA-041 à QA-049, 9 bugs). Aucun bug des passes précédentes réapparu (QA-031, QA-032, QA-039 tiennent).

### 14.8 Tests ajoutés (`tests/integration/test_qa_m11.gd`, 17 tests)

| Test | État |
|---|---|
| `test_pad_title_new_game_story_to_day_one` | ✅ passe |
| `test_pad_only_tutorial_and_first_passenger` | ✅ passe |
| `test_pad_only_day_one_summary_and_evening` | ✅ passe |
| `test_pad_detention_with_left_stick_click` | ✅ passe |
| `test_pad_pause_story_to_hard_after_closing_time_ends_the_shift` | ✅ passe |
| `test_pad_end_screen_and_load_screen_past_day` | ✅ passe |
| `test_real_v5_save_appears_on_title_and_load_screen` | ✅ passe |
| `test_quit_mid_shift_writes_nothing_and_continue_replays_the_day` | ✅ passe |
| `test_resume_first_day_of_ended_game_truncates_and_reactivates` | ✅ passe |
| `test_pad_a_on_close_booth_closes_instead_of_calling_a_passenger` | ⏸ `pending` QA-041 |
| `test_pad_a_on_tutorial_skip_skips_instead_of_calling_a_passenger` | ⏸ `pending` QA-041 |
| `test_pad_dpad_reaches_the_tutorial_buttons` | ⏸ `pending` QA-042 |
| `test_corrupt_current_does_not_leave_a_dead_continue_button` | ⏸ `pending` QA-043 |
| `test_ended_game_stays_ended_when_meta_is_lost` | ⏸ `pending` QA-044 |
| `test_orphan_truncated_tmp_snapshot_is_not_offered` | ⏸ `pending` QA-045 |
| `test_hard_mode_switch_is_not_undone_by_quitting_before_the_evening` | ⏸ `pending` QA-046 |
| `test_holo_flicker_off_also_freezes_booth_neons_and_screens` | ⏸ `pending` QA-047 (suppose un uniforme `flicker` dans `booth_emissive`, comme `booth_holo` ; à adapter si le correctif choisit un autre nom) |

Durée du fichier : ≈ 36 s (parcours réels à ×4). Suite complète : **655 tests, 647 verts, 8 `pending`** (QA-041 ×2, QA-042…QA-047), 0 échec, 0 `SCRIPT ERROR`, 365 s.

### 14.9 Recommandations priorisées

1. **QA-041** avant toute campagne de playtest à la manette (Steam Deck) : Ⓐ ne doit jamais faire autre chose que le bouton qui a le focus.
2. **QA-042** avec QA-041 : le tutoriel doit se passer à la manette depuis son accueil (critère « campagne complète jouable à la manette seule »).
3. **QA-047** (photosensibilité, D-109).
4. Robustesse des sauvegardes : QA-043, QA-046, puis QA-044, QA-045.
5. **QA-049** : décision du Game Designer sur ce que « Récit » protège (foyer, Déposition), à consigner dans `DECISIONS.md`.
6. QA-048 au moment de la livraison 0.11.0.
7. QA (suite) : playtest humain à la manette sur Steam Deck réel ; captures des liens du scanner Luciole en Protan·Deutan / Tritan sur un cas discordant ; Fermer le guichet en vraie scène sur un jour à quota.

### 14.10 Rejouer la passe M11

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit     # 655 tests, 8 pending QA-041…047
# Fichier seul (≈ 36 s)
godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_qa_m11.gd \
    -gpre_run_script=res://tests/helpers/gut_pre_run.gd -gexit
# Campagne en Récit (tronçons de 9 min ; reprise : --qa-load=<copie de $X/godot/app_userdata/CLEARANCE/saves/slot_1/current.json>)
X=$(mktemp -d); XDG_DATA_HOME=$X timeout 540 godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-seed=7 --qa-profile=loyal --qa-speed=10 --qa-story --qa-credits=3000 --qa-reload
# Vraie sauvegarde 0.10.0 → v6 (migrate_legacy) puis J25 → J30
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-load=$PWD/tests/fixtures/qa_save_v5_j25_solidaire.json --qa-profile=solidaire --qa-speed=10 --qa-reload
# Simulation Récit
godot --headless --script res://tools/balance_sim.gd -- --seeds=20 --seed=1 --profiles=0.65,0.8,0.95 \
    --presets=default,loyal,luciole,passeur,temoin --story
# Captures : vision des couleurs sur une vraie discordance (J2, 3ᵉ passager), N = 0..3
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1920x1080 --qa-wait=30 \
    --qa-after-check=0.8 --qa-discord --qa-set=color_vision:N --qa-out=/tmp/cvN.png --seed=3 --day=2 --start-case=2 \
    --screen=shift --reduce-motion
# Écrans de partie en texte 1,5 (Deck) : --title=new|difficulty|overwrite|load|days
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-scene=res://scenes/main/main.tscn \
    --qa-size=1280x800 --qa-wait=5 --qa-set=text_scale:1.5 --qa-out=/tmp/load.png --demo-saves --title=load
# Données, exports
godot --headless --script res://tools/build_data.gd && md5sum data/*/*.tres
bash tools/export_all.sh linux && bash tools/smoke_export.sh
```

---

## 15. Passe QA M12 « Rejouabilité »

> Passe du 29.10.2026 sur `claude/laughing-bell-8ayudz` après `c729f93` (M12 lots A, B, C, A2 : épilogue J31, Garde de nuit, événements EV-01 → EV-08, échos SC-83 → SC-90, Dossier, profil v2, règles mutables). Godot 4.7.2, GUT 9.7.1. **QA ne corrige pas le code de jeu** : bugs QA-050 à QA-062 ci-dessous, chacun avec son propriétaire suggéré.

### 15.1 Méthode et couverture

| Volet | Outil | Résultat |
|---|---|---|
| Suite existante | GUT complet | **770 / 770** à l'arrivée (504 s) ; après la passe **783 tests : 773 verts + 10 `pending`**, 0 échec, 0 `SCRIPT ERROR` (§15.8) |
| Campagnes réelles (`day.tscn`, booth 3D, bot `--autoplay`, ×10, `--qa-reload`) | `tools/qa_campaign.gd` sous-classé par `tests/qa_drivers/qa_m12_campaign.gd` (journal des événements, puis épilogue joué par les **trois portes**) | 3 campagnes **J1 → J30** (2 en Dur, 1 en Récit) + 3 reprises de vraies sauvegardes du J25 (§15.2) : **0 `QA_ISSUE`** hors « solde aberrant » attendu (+3 000 ₵), 0 `SCRIPT ERROR`, 0 fuite |
| Épilogue J31 | même pilote ; `--epilogue=f10_pont` / `f8_registre` (monde C) | mondes **A, B, D depuis de vraies fins**, C depuis une graine synthétique (§15.2) |
| Garde de nuit (vraie scène) | `tests/qa_drivers/qa_m12_garde.gd` : titre → accueil → guichet → fin de garde, bot « oracle » à erreurs programmées | 2 sessions (4 + 1 gardes), dont une de **130 passagers** jusqu'au palier 4 (§15.3) |
| Événements (vraie scène) | `tests/qa_drivers/qa_m12_events.gd` : un jour réel par événement (`--seed --day --autoplay`) | **EV-01 → EV-08** observés (§15.4) ; 10 événements de plus dans les campagnes |
| Simulation | `balance_sim --garde` (300 codes, 80/90 %, dégressif, 60 graines du jour) ; `--events=compare` (150 graines, 80 %) ; reproduction du bug d'invariant | D-136 et D-060 tenus ; QA-050 expliqué (§15.4) |
| Échos | scripts de simulation (`CaseBuilder` J2 → J4 / J18, vraies données) | SC-84a/b selon le verdict du J2 ; SC-90 vu dans les 15 J31 joués (§15.5) |
| Profil v2 | **3 vrais profils produits par la 0.11.0** (export `git archive ba17e14`, parties jouées par son `qa_campaign`), ouverts par M12 : `tests/qa_drivers/qa_m12_migrate.gd` | §15.6 ; profils versés en fixtures `tests/fixtures/qa_profile_v1_m11_*` |
| Manette, accessibilité | GUT (vrais `InputEventJoypadButton`), ≈ 30 captures réelles OpenGL 3 sous xvfb (14 versées en `docs/mockups/m12_qa_*.png`) (1080p, Deck 1280×800, texte 1,5, `--qa-pad`, 4 modes de vision) | §15.7 |
| Régression | `build_data` (md5), `export_all.sh linux`, `smoke_export.sh` | §15.8 |

**Vrai `user://saves` jamais touché** : vide avant et après la passe, pas de `profile.json` réel créé, `settings.cfg` du joueur inchangé (md5 `9d0188…`) ; tous les outils sous `XDG_DATA_HOME` temporaire (scratchpad, supprimé) ; aucun `override.cfg` dans le projet.

### 15.2 Épilogue J31

#### 15.2.1 Campagnes réelles et fins

| Graine | Profil | Mode | Départ | Fin (variante) | Monde | Solde | Conformité | Événements vus | Problèmes |
|---|---|---|---|---|---|---|---|---|---|
| 3 | loyal | Dur | J1 (+3 000 ₵) | **F7** | A | 451 ₵ | 61 % | EV-08 J5, EV-05 J16, EV-04 J28 | aucun |
| 5 | passeur | Dur | J1 (+3 000 ₵) | **F7** (le bot n'atteint pas F10) | A | 335 ₵ | 60 % | EV-05 J4, EV-01 J13, EV-02 J19, EV-04 J26 | aucun |
| 7 | drift | **Récit** | J1 (+3 000 ₵) | **F6 · d** | **D** | 967 ₵ | 63 % | EV-03 J8, EV-02 J14, EV-02 J28 | aucun |
| 11 | solidaire | Dur | sauvegarde réelle `qa_save_v5_j25_solidaire` | **F9** | **B** | 201 ₵ | 86 % | — | aucun |
| 11 | temoin | Dur | idem | F7 (le bot n'atteint pas F8) | A | 226 ₵ | 86 % | — | aucun |
| 5 | passeur | Dur | `qa_save_v5_j25_luciole` | **F5 · b** | A | 390 ₵ | 86 % | — | aucun |

- **Monde C** : le bot de démonstration ne fait pas les choix du soir qui mènent à F8 / F10 (il ne voit que l'écran). C est joué en vraie scène depuis une graine synthétique (`--epilogue=f10_pont`, `--epilogue=f8_registre` : J31 complet, 7 passagers jugés par `--skip-cases=7`, puis conclusion) et par le test existant `test_every_world_plays_from_a_seed_to_its_conclusion` ; conclusion F10 avec `%d` de `pont31` résolu (« 2 personnes de Tycho »), F8 avec réplique Tessar « ‹Shen tavi.› » ([`m12_qa_epilogue_conclusion_f8.png`](mockups/m12_qa_epilogue_conclusion_f8.png)).
- **Fins des actes I–II** : F3 (J15, Acte II) d'un vrai profil M11 et `test_end_screen_offers_the_epilogue_only_after_act_three` : pas d'épilogue, ligne `epi_locked_hint`.

#### 15.2.2 Les trois portes (6 parties × 3 = 18 J31 réels)

| Contrôle | Résultat |
|---|---|
| Écran de fin → **UN AN PLUS TARD** (3 s après le récit, focus sur le bouton) | ✅ 6 / 6 |
| Titre → **Charger** → JOUER « UN AN PLUS TARD » (sans confirmation) | ✅ 6 / 6 |
| Emplacement **supprimé** → Titre → **Dossier › Épilogues** → REJOUER (graine du profil, `slot = -1`) | ✅ 6 / 6 |
| Partie terminée non modifiée : md5 de `current.json` et des `day_NN.json` identiques avant / après, aucun fichier créé ; seule la méta reçoit `epilogue_done` ; `status = ended`, `ending_id` intact | ✅ 18 / 18 |
| Aucune économie : solde 0, net 0 ₵ malgré 2–3 citations « AVERTISSEMENT » ; fin à la file vide (7 / 7) dans les deux modes | ✅ |
| Drapeaux du matin : exactement un `epi_ending_<clé>` vrai (`epi_ending_f7`, `f9`, `f6d`, `f5b`), `hh_*` = foyer de la graine (ex. F9 : `hh_ilan_away`, `hh_ilan_present = false`, `hh_present = 2`) | ✅ 18 / 18 |
| Profil : `epilogues["<fin>:<variante>"].count` = 1, 2, 3 au fil des portes ; `epilogue_unlocked` | ✅ |
| Conclusions : ≤ 8 lignes, ouverture → SC-90 → monde → foyer → clôture, aucune clé brute ni `%d` / `%s` | ✅ (7 lignes chacune) |
| Retrouvailles cohérentes avec la partie | ⚠️ en jeu réel : oui (Ilan parti à Tycho ⇒ aucune ligne d'Ilan au monde B). **Synthèse 13 variantes × 3 proches × 3 états** : 33 lignes nomment un proche absent, dont **Noa morte** dans les ouvertures / clôtures F5c, F6t, F6d → **QA-056** |

### 15.3 Garde de nuit

| Contrôle | Résultat | Preuve |
|---|---|---|
| Profil vierge : GARDE DE NUIT grisée, non focalisable, « Terminez votre premier jour au Guichet 04. » ; après `max_day_reached = 2` : active | ✅ | pilote, `test_title_locks_garde_and_dossier_on_a_blank_profile` |
| Accueil : focus JOUER LA GRAINE DU JOUR ; graine du jour `NUIT-2026-10-29` = `GardeService.today_code()` (UTC) | ✅ | [`m12_qa_garde_home_deck_text150_pad.png`](mockups/m12_qa_garde_home_deck_text150_pad.png) |
| Codes libres : `k2q9tx`, ` k2q-9tx `, `K2Q-9TX` → `K2Q-9TX` ; O, I, 0, 1 refusés (« Les codes n'utilisent ni O, ni I, ni 0, ni 1. ») ; 5 ou 7 caractères refusés ; JOUER CE CODE inactif tant que le code est invalide ; TIRER AU HASARD remplit et donne le focus à JOUER CE CODE | ✅ | pilote |
| `NUIT-2026-13-40`, `é2Q-9TX` : refusés mais annoncés « Il faut 6 caractères » | ❌ **QA-055** | test |
| Directive tous les 5 passagers, carte DIRECTIVE N° n (focus COMPRIS, Ⓐ la ferme sans appeler de passager), règle au Rulebook au passager suivant (`[NEW]`, un seul badge à la fois) ; palier 1 / 2 / 3 / 4 aux passagers 20 / 40 / 60 / 100 ; **rotation** au palier 4 : directive 21 `u03 retire` (ligne barrée) → `forget` au passager suivant → directive 22 `restore` (RÉTABLIE) ; idem `u05` | ✅ | pilote (130 passagers) |
| Rulebook long (≥ 9 directives) : la règle NOUVEAU n'est **pas** amenée à l'écran (`ensure_control_visible` : « Must be an ancestor ») | ❌ **QA-061** | [`m12_qa_garde_directive10_ev08.png`](mockups/m12_qa_garde_directive10_ev08.png) |
| 3ᵉ erreur → FIN DE GARDE (« Trois erreurs. La relève arrive. »), erreurs listées (passager, verdict rendu → attendu, citation, règle) | ✅ ; ❌ erreur de procédure affichée « APPROUVÉ → APPROUVÉ » (**QA-054**) | [`m12_qa_garde_end_deck_text150.png`](mockups/m12_qa_garde_end_deck_text150.png) |
| TERMINER LA GARDE (barre) : boîte focus ANNULER, score enregistré ; à la manette, la croix sort de la boîte (**QA-057**) | ⚠️ | test |
| Records : top 10 trié, `new_record` à la 1ʳᵉ garde, `rank` 0-indexé, **premier essai du jour** conservé (`first_try` = 0 puis `attempts` = 2, `best` = 4), graines libres (`best` 75), `garde_stats` (`runs` 4, `longest_run` 70) ; REJOUER = même code ; NOUVELLE GRAINE rouvre l'accueil ; RETOUR → titre | ✅ | pilote |
| **Déterminisme** en vraie scène : même code, verdicts différents (garde 1 juste, garde 2 fausse aux passagers 3, 8, 12) → **13 / 13** passagers identiques (nom, N° ID) | ✅ | pilote ; `test_garde_is_deterministic_whatever_the_verdicts` (1 000 graines) |
| Garde longue : **130 passagers**, 26 directives, palier 4, score 145 (EV-04 double), aucun plantage ni `SCRIPT ERROR` ; nœuds stables (≈ 850) mais **mémoire +0,4 Mo et +17 objets par passager**, portraits en cache = passagers vus | ⚠️ **QA-053** | pilote (`QA_G_MEM`) |
| Événements en Garde : EV-04 (points doubles), EV-07, EV-08, EV-01 (R `mrz` retirée puis rétablie), jamais dans les 2 passagers qui suivent une directive | ✅ ; ❌ EV-08 annoncé « 13:00–14:00 » à 03:00 (**QA-062**) | idem |
| Journal : `CallbackTweener … _reset_pivot : Cannot convert argument 1 from Object to Object` (61 à 137 par session de Garde du bot) quand le verdict tombe avant la fin de l'arrivée des documents | ⚠️ **QA-061** (journal) | pilote |

**`balance_sim --garde` (D-136)** — 300 codes libres, graine 1 ; 60 graines du jour à partir du 29.10.2026 :

| Bot | Médiane | Moyenne | p10 | p90 | Directives ≥ 1 / ≥ 4 | Cible | |
|---|---|---|---|---|---|---|---|
| 80 % | **11** | 13,0 | 4 | 24 | 96,3 % / 24,3 % | 11 ± 1, p10 ≥ 3, p90 ≤ 26 | ✅ |
| 90 % | **25** | 28,4 | 10 | 52 | 99,0 % / 72,7 % | 25 ± 2 | ✅ |
| dégressif | **37** | 37,5 | 19 | 57 | 100 % / 92,7 % | 30 à 40 (D-136) | ✅ |
| 80 %, graines du jour | 10 | 11,7 | 4 | 22 | 98,3 % / 20,0 % | pas de « graine maudite » | ✅ |

Cas sans preuve citable : **0** sur 26 393 passagers ; directives exercées : 3 934 / 3 934.

### 15.4 Événements de station

#### 15.4.1 Chaque événement en vraie scène (`qa_m12_events.gd`)

| Événement | Graine · jour | Annonce (avant effet) | Bandeau | Effet observé | Fin | Classe B : +1 avert. | Cas scénarisés |
|---|---|---|---|---|---|---|---|
| EV-01 lecteur MRZ | 1 · J25 | après 9 passagers, 11:47 | « LECTEUR DE BANDE HS · 4 PASSAGERS » | `r_mrz_valid` retirée [9, 13) | rétablie au 13 (annonce de fin) | — (A) | 13 scénarisé : fenêtre close avant ✅ |
| EV-02 comparateur | 2 · J8 | après 9 | « COMPARATEUR HS · 3 PASSAGERS » | `comparator_down`, `max_anomalies`, `no_subtle` | au 12, « Comparateur rétabli. » | ✅ (3 au lieu de 2) | — |
| EV-03 quarantaine | 7 · J8 | après 12 | « ALERTE MERIDIAN · JUSQU'À LA FIN DU SHIFT » | surcharge `r_bioscan_valid` (TYC) | fin du jour | ✅ | — |
| EV-04 inspection | 1 · J18 | après 3, voix INSPECTION | « INSPECTION EN COURS · 5 PASSAGERS » | 1ʳᵉ citation **amendée** (5 ₵, aucun avertissement), +2 ₵ par verdict juste (7 ₵) | au 8 | — (A) | — |
| EV-05 coupure | 1 · J15 | après 13 | « COUPURE · ÉCLAIRAGE DE SECOURS · EN COURS » | horloge gelée à 12:37 pendant 60 s, `r_seals_valid` retirée | rétablie au passager suivant la fin | — (A) | après le dernier scénarisé ✅ |
| EV-06 file dense | 1 · J7 | après 11 | « FILE DENSE · JUSQU'À LA FIN DU SHIFT » | **20 / 20** passagers (17 + 3) | fin du jour | — (A) | — |
| EV-07 cartes volées | 13 · J18 | après 15 | « CARTES VOLÉES · JUSQU'À LA FIN DU SHIFT » | liste `stolen` de 3 N° (onglet), porteur au passager 16 | liste vidée en fin de jour | ✅ | — |
| EV-08 exemption | 1 · J5 | 12:35 (≥ 12:30) | « EXEMPTION 13:00–14:00 · JUSQU'À 14:00 » | surcharge `r_bioscan_required` TRANSIT 13:00–14:00 | fin du jour à 12:54 | — (A) | — |

- **Jamais pendant un cas scénarisé** : aucun cas scénarisé présenté sous un événement structurel (journal `QA_EV_CASE` des 8 jours + 10 événements de campagne). **EV-02** : le comparateur ne donne ni CONCORDANT ni DISCORDANCE à l'écran (`test_comparator_down_shows_an_agent_finding_instead_of_a_result`) ; le bot, qui lit le signal logique, trouve encore les discordances (attendu).
- Remarque (Game Designer) : **EV-08 un jour court** (J5, 12 passagers) — à l'allure du bot, la file est vidée à 12:54 : l'événement est annoncé, affiché, puis se termine sans s'être appliqué. Pas un bug (annonce juste), mais un événement « fantôme » ; à surveiller au playtest humain (30–50 s par passager).
- **`balance_sim --events=compare`** (150 graines, 80 %) : fins F1 22,7 → 24,0, F7 76,0 → 74,7, **écart maximal 1,3 point** (D-060 : ≤ 3) ✅ ; **4,51 événements par campagne, 100 % entre 3 et 6** ✅ ; tous les types tirés ; revenu un jour d'événement : +2,92 ₵ en moyenne (≤ 5 ₵) ✅.

#### 15.4.2 Bug d'invariant « N° ID révoqué non détecté » (n = 156, 80 %, J19, EV-08) — QA-050

**Reproduction** : `balance_sim --seeds=400 --seed=1 --profiles=0.8 --events=on` → `CaseBuilder: invariants violés (jour 19, cas 6, seed 3477444520065303047) : Anomaly(REVOKED_ID, id_card.citizen_id) non détectée`. Graine de campagne `SeededRng.mix(1, 156)` = `2500715359172382266` ; calendrier : EV-05 J5, EV-08 J12, **EV-08 J19** (fenêtre 13:00 → 14:00), EV-07 J23. Reproduit hors simulateur avec un seul `CaseBuilder` (J19, EV-08 appliqué, `presentation_minute = 782`) : 1 occurrence sur ≈ 750 campagnes simulées avec événements (400 graines à 60 %, ≈ 200 à 80 %, 150 en `compare`).

**Cause (générateur)** : `CaseBuilder._clean_ctx` (contexte du contrôle « cas propre », `trust_documents`) est une copie de `ctx` faite **une fois** dans `_init` : son `now_minute` reste à −1. À la production des documents, `_required_document_ids` lit l'heure de présentation (`ctx.now_minute`, 13:02) et **retire** le bio-scan d'un passager TRANSIT (surcharge `exempt` d'EV-08) ; puis `_clean_violation_ids` valide le cas avec `_clean_ctx` (heure −1, hors 13:00–14:00) : R11 « bio-scan obligatoire » est violée, le cas n'est pas « propre », **l'essai est rejeté et le passager re-tiré** (2ᵉ essai : un autre passager, TRADE). Or la liste des révocations du jour a été calculée au matin (`_build_revocations` → `build_clean(6)` à l'heure −1 : « Ashe Mainsoleil », HG-9455-9W62, TRANSIT). Le passager 6 présenté à 13:02 est « Halo Tessaride » (HG-9884-DFVN) : `RevokedIdInjector` trouve l'entrée par **index**, pose l'anomalie, mais aucune violation ne la prouve.
- Pas un défaut du simulateur (`DaySimulator.play_day` reproduit fidèlement le `DayController`, qui pose aussi `ctx.now_minute` et jamais `_clean_ctx.now_minute`) ni de la règle R30 : **le même défaut existe en jeu réel**.
- Portée : tout passager TRANSIT présenté pendant la fenêtre d'EV-08 est re-tiré (2 sur 17 au J19 de cette graine) ; conséquence visible seulement pour un passager **pré-calculé** (révocation R30, avis de recherche, porteur de liste nommée, répondant, exercice de Garde) : la liste affiche quelqu'un qui ne viendra pas, le passager attendu est remplacé par un passager en règle (verdict attendu APPROUVÉ, cohérent), `push_error` au journal. En Garde, la surcharge d'EV-08 n'a pas de plage horaire : même mécanisme si `now_minute` du contrôle diffère.
- **Correctif proposé (Gameplay Systems, `scripts/generation/case_builder.gd`)** : synchroniser l'heure du contrôle avant chaque validation — dans `_clean_violation_ids` (ou au début de `_build`) : `_clean_ctx.now_minute = ctx.now_minute if ctx.now_minute >= 0 else presentation_minute` (et, par sûreté, `_clean_ctx.rule_set = day.rule_set`). Option défensive : pour un index lié à une liste (révocation, avis, liste nommée), imposer l'identité de l'entrée (`citizen_id`, nom) en surcharge plutôt que de compter sur la stabilité du tirage. Tests : `test_qa050_*` (2, `pending`).

### 15.5 Échos

| Écho | Vérification | Résultat |
|---|---|---|
| SC-84a (J4 @10) | SC-03 **refusé** au J2 (graines 7, 23, 99) → présent, visage = **vrai visage du mineur** du J2, ses propres papiers, attendu APPROUVÉ | ✅ |
| SC-84b (J18 @11, D-135) | SC-03 **approuvé** (`sc03_passed`) → présent, identité de la carte du J2, **visage = photo du J2** (traits d'identité ; tranche d'âge recalculée), N° à l'onglet Révocations, attendu REFUSÉ | ✅ (graines 1–10, 23) ; ❌ graine 7 : attendu DÉTENTION (avis homonyme, **QA-051**) ; ❌ mémoire 0.11 sans `photo_appearance` : visage du roster et « aucun cas propre » (**QA-060**) |
| SC-90 (J31 @0) | 18 J31 réels + 2 synthétiques | ✅ présent, APPROUVÉ, ligne « La troisième personne du 13 mars… » |
| Autres échos (SC-83 → SC-89) | `test_echoes_appear_on_their_trigger_with_expected_verdicts`, `test_echo_indices_are_free` (existants) | ✅ |

### 15.6 Dossier et profil v2

| Contrôle | Résultat | Preuve |
|---|---|---|
| Profil « early » (avant `epilogue_unlocked`) : « 0 fin vue · 0 garde », **aucun total**, pas d'onglet ÉPILOGUES, fins en silhouette + indice de niveau 1 seulement, personnes croisées seules, **« Bastien Duval » entre guillemets** | ✅ | [`m12_qa_dossier_early_endings.png`](mockups/m12_qa_dossier_early_endings.png), [`m12_qa_dossier_early_people.png`](mockups/m12_qa_dossier_early_people.png) |
| Après une fin de l'Acte III : « 3 / 10 fins », « 18 / 44 personnes », onglet ÉPILOGUES, vrai nom appris | ✅ | [`m12_qa_dossier_people_deck_text150.png`](mockups/m12_qa_dossier_people_deck_text150.png) |
| **Vrai profil 0.11.0 + sa partie terminée** (F9, J30) : `profile.v1.bak`, v2, `max_day_reached = 30`, `epilogue_unlocked`, graine `f9_strike:` au profil, `day_31.json` + méta `epilogue_available` écrits, `last_campaign` (monde B) ; Charger → J31 joué ; partie inchangée (`game_version` 0.11.0 conservée) | ✅ | `test_real_m11_profile_with_its_finished_game_migrates_and_offers_the_epilogue` |
| Vrais profils 0.11.0 **sans emplacement** (F5 au J30 ; F3 au J15) : `max_day_reached = 0` → **Garde verrouillée** ; F5 de l'Acte III sans `epilogue_unlocked` ; `known_names` jamais reconstruits | ❌ **QA-052** | `test_qa052_*` |

### 15.7 Manette seule et accessibilité

| Écran | Manette | Texte 1,5 · Deck 1280×800 | Vision des couleurs |
|---|---|---|---|
| Accueil de la Garde | ✅ focus JOUER LA GRAINE DU JOUR, Ⓑ retour (glyphe) | ✅ | — |
| Carte de directive | ✅ focus COMPRIS, Ⓐ ferme la carte **sans** appeler de passager (QA-041 tient) | ✅ | ✅ 4 modes : badge NOUVEAU ⚠ + texte, bord ambre → crème en Protan·Deutan / Tritan, jamais la couleur seule ([`m12_qa_directive_colorvision.png`](mockups/m12_qa_directive_colorvision.png)) |
| Barre de Garde (ERREURS ◇◇◇ 0/3, ⊗ pleins) | ✅ TERMINER LA GARDE joignable à la croix ↑ ; ❌ boîte : la croix sort vers SUIVANT (**QA-057**) | ✅ | ✅ octogones / losanges + « 1/3 » |
| Fin de garde | ✅ focus REJOUER, Ⓐ = rejouer, Ⓑ = titre | ✅ | — |
| Carte « UN AN PLUS TARD » | ✅ focus CONTINUER, Ⓑ = titre | ✅ | ✅ (Tritan, monde D) |
| Conclusion | ✅ Ⓑ révèle tout puis titre, focus RETOUR AU TITRE | ❌ colonne tronquée (**QA-058**) | — |
| Dossier | ✅ RB / LB entre les onglets, Ⓑ retour | ✅ | — |
| Bandeau ÉVÉNEMENT + ligne du Rulebook | — (non focalisable) | ✅ | ✅ 4 modes : icône « = » + texte ambre lisible ([`m12_qa_banner_colorvision.png`](mockups/m12_qa_banner_colorvision.png)) |

Remarques (cosmétique, non numérotées) : au Deck en texte 1,5 l'onglet « Documents » du Rulebook passe sous la puce RB (déjà vu en campagne) ; avec `--qa-pad`, la consigne du bas reste « intercom (N) » quand l'encart du haut dit « (A) ».

### 15.8 Régression

| Contrôle | Résultat |
|---|---|
| GUT complet | ✅ **770 / 770** à l'arrivée ; après la passe **783 tests, 773 verts + 10 `pending`** (QA-050 ×2, QA-051 → QA-057, QA-060), 0 échec, 0 `SCRIPT ERROR` (≈ 500 s) |
| `build_data` | ✅ « build_data : OK », 172 fichiers réécrits, **167 fichiers de `data/` identiques** (md5 avant / après), M12 compris |
| `bash tools/export_all.sh linux` | ✅ `build/dist/CLEARANCE-0.11.0-linux.tar.gz` (38,6 Mo, 44 s) — nom de version : **QA-059** |
| `bash tools/smoke_export.sh` | ✅ release_title + debug J1, J4, J7, J10, J15, J20, J25, J30 : OK (le smoke ne couvre ni la Garde ni le J31) |
| Campagnes J1 → J30 | ✅ 2 en Dur (F7 ×2), 1 en Récit (F6 · d), 0 `QA_ISSUE`, sauvegarde relue = état chaque soir, « Quitter → Continuer » réel à chaque nouveau jour |

### 15.9 Liste des bugs (M12)

Statut : 🔴 ouvert.

| ID | Sév. | Titre | Reproduction | Propriétaire suggéré | Preuve |
|---|---|---|---|---|---|
| QA-050 | Mineur | ✅ Corrigé (0.12.0) — **Contrôle « cas propre » sans l'heure de présentation (EV-08)** : `CaseBuilder._clean_ctx.now_minute` reste à −1 ; dans la fenêtre 13:00–14:00, un TRANSIT dispensé de bio-scan est re-tiré ; un porteur pré-calculé (révocation, avis, liste) est remplacé — invariant « N° ID révoqué non détecté », liste fausse, `push_error` | `balance_sim --seeds=400 --seed=1 --profiles=0.8 --events=on` (n = 156, J19, cas 6) ; §15.4.2 | Gameplay Systems (`case_builder.gd` : synchroniser `_clean_ctx.now_minute`) | `test_qa050_*` (2) |
| QA-051 | Mineur | ✅ Corrigé (0.12.0) — **SC-84b attendu DÉTENTION** quand le passager généré visé par l'avis du jour porte exactement son nom (graine 7, 1 graine sur 150) : l'avis vise aussi le vrai titulaire | `CaseBuilder` J2 (SC-03 approuvé) puis J18, graine 7 | Gameplay Systems (exclure des avis et des passagers générés les identités des cas scénarisés du jour, `identity_from_case` compris) | `test_qa051_*` |
| QA-052 | Mineur | ✅ Corrigé (0.12.0) — **Migration v1 → v2 sans emplacement** : `max_day_reached` ne lit que les emplacements (0 pour un joueur 0.11 qui a fini la campagne puis supprimé sa partie → **Garde verrouillée**), fin de l'Acte III sans `epilogue_unlocked`, `known_names` jamais reconstruits | vrais profils `qa_profile_v1_m11_f5_j30_noslot.json`, `…_f3_j15_noslot.json` | Godot Architect (`ProfileService.migrate_v1` : `max_day_reached` ≥ jour des `endings_seen`, `epilogue_unlocked` si une fin d'acte 3 est vue, noms connus depuis les parties terminées) ; M12 §7.5 à amender | `test_qa052_*` |
| QA-053 | Mineur (perf) | ✅ Corrigé (0.12.0) — **Garde : cache des portraits sans plafond** — la scène n'est jamais rechargée ; un portrait par passager (+0,4 Mo, +17 objets par passager : +89 Mo à 130 passagers) | `qa_m12_garde.gd --qa-garde-long=130` (`QA_G_MEM`) | 3D Designer / Asset Lead (`portrait_service.gd` : LRU) ou Godot Architect (`DayScene` : vider le cache au départ du passager en Garde) | `test_qa053_*` |
| QA-054 | Cosmétique | ✅ Corrigé (0.12.0) — **Fin de garde : erreur de procédure « APPROUVÉ → APPROUVÉ »** (visière non retirée) : la ligne verdict rendu → attendu ne dit rien de la faute | 3 erreurs dont une de visage non contrôlé | UI/UX Expert (`garde_end_screen.gd` `error_row` : libellé de procédure quand verdict = attendu) | `test_qa054_*`, [`m12_qa_garde_end_deck_text150.png`](mockups/m12_qa_garde_end_deck_text150.png) |
| QA-055 | Cosmétique | ✅ Corrigé (0.12.0) — **Code de garde : date impossible annoncée « Il faut 6 caractères »** (`NUIT-2026-13-40`, et caractère accentué) | accueil › graine libre | Godot Architect (`GardeService.normalize_code` : clé d'erreur propre) + UI/UX (texte) | `test_qa055_*` |
| QA-056 | Mineur (narratif) | ✅ Corrigé (0.12.0) — **Conclusions : Noa nommée alors qu'elle est morte** — `epi_f5c_close`, `epi_f6t_open`, `epi_f6d_close` sans condition ; `epi_home_noa` conditionnée à `hh_noa_alive` seulement (Noa partie ou retenue : 24 cas) | `EpilogueService.conclusion` sur 13 variantes × proche mort / parti / retenu | Scénariste (variantes sans Noa) + Gameplay Systems (`build_data_m12.gd` : conditions `hh_noa_alive` / `hh_noa_present`) | `test_conclusions_never_name_a_lost_away_or_held_relative` (QA-056) |
| QA-057 | **Majeur** | ✅ Corrigé (0.12.0) — **Manette : la boîte « Terminer la garde » (barre) laisse fuir le focus** — toute direction de la croix depuis ANNULER part sur SUIVANT, derrière la boîte ; Ⓐ y appelle un passager, la garde ne se termine pas (contournement : Pause › TERMINER LA GARDE) | Garde, croix ↑ depuis SUIVANT, Ⓐ, croix → | UI/UX Expert (`DayScene.request_end_garde` / `ConfirmDialog` : piéger le focus, `FocusGuard` de la boîte, comme la pause) | `test_pad_only_garde_directive_card_and_end_from_the_bar` |
| QA-058 | Mineur (a11y) | ✅ Corrigé (0.12.0) — **Conclusion au Deck en texte 1,5 : colonne tronquée** à 3,5 lignes (ligne coupée), 150 px vides au-dessus du pied, aucun indice de défilement | `--epilogue=f10_pont --skip-cases=7 --qa-set=text_scale:1.5`, 1280×800 | UI/UX Expert (`epilogue_screen.gd` : défilement sur la hauteur disponible + repère « suite ») | [`m12_qa_epilogue_conclusion_c_deck_text150.png`](mockups/m12_qa_epilogue_conclusion_c_deck_text150.png) |
| QA-059 | Cosmétique | ✅ Corrigé (0.12.0) — **Version non montée** : `config/version = "0.11.0"` (export `CLEARANCE-0.11.0-linux.tar.gz`, `game_version` des sauvegardes) alors que M12 = 0.12.0 | `export_all.sh linux` | Orchestrateur (à la livraison) | `build/dist` |
| QA-060 | Mineur | ✅ Corrigé (0.12.0) — **Sauvegarde 0.11 : SC-84b sans le visage de la photo du J2** — l'entrée `sc_03` d'une mémoire 0.11 n'a pas `photo_appearance` (ajouté en M12) : visage du roster, et « aucun cas propre après 8 essais (r_apparent_age) » au matin du J18 | mémoire SC-03 approuvée sans `photo_appearance`, `CaseMemory.resolve`, J18 | Godot Architect (`CaseMemory.resolve` : recalcul déterministe de `photo_appearance` manquante, D-057) | `test_qa060_*` |
| QA-061 | Mineur | ✅ Corrigé (0.12.0) — **Garde : le Rulebook ne montre pas la règle NOUVEAU quand la liste est longue** (`ensure_control_visible` différé sur une carte reconstruite : « Must be an ancestor of the control », 5–14 par garde) ; au journal aussi `CallbackTweener … _reset_pivot` (61–137 par session du bot, `DocumentView` libéré avant la fin de son arrivée) | garde ≥ 45 passagers ; verdict < 0,6 s après les documents | UI/UX Expert (`rulebook_panel.gd` `focus_rule` : défiler après reconstruction ; `workbench.gd` : `_reset_pivot(view: Object)` ou tuer `_arrivals`) | [`m12_qa_garde_directive10_ev08.png`](mockups/m12_qa_garde_directive10_ev08.png) |
| QA-062 | **Majeur** | ✅ Corrigé (0.12.0) — **EV-08 en Garde : textes de campagne** — annonce « de 13:00 à 14:00, motif TRANSIT dispensé de bio-scan », bandeau « EXEMPTION 13:00–14:00 · JUSQU'À LA FIN DU SHIFT », Rulebook « JUSQU'À 14:00 » à 02:42 / 03:00, alors que l'exemption s'applique **aux 5 passagers suivants** (`garde_changes` sans plage). Le joueur qui refuse un TRANSIT sans bio-scan est cité : une erreur sur 3 | garde K2Q-9TX, passager 47 | Gameplay Systems (`build_data_m12.gd` : `garde_announce_key`, titres de Garde) + Scénariste (textes) + UI/UX (reste « n PASSAGERS » en Garde) | [`m12_qa_garde_directive10_ev08.png`](mockups/m12_qa_garde_directive10_ev08.png) |

Total M12 : **0 bloquant, 2 majeurs, 8 mineurs (dont 1 perf, 1 narratif, 1 accessibilité), 3 cosmétiques** (QA-050 à QA-062, 13 bugs). Aucun bug des passes précédentes réapparu (QA-041 tient sur la carte de directive ; QA-047 non revu).

### 15.10 Tests ajoutés (`tests/integration/test_qa_m12.gd`, 13 tests) et outils

| Test | État |
|---|---|
| `test_qa050_ev08_revoked_carrier_keeps_its_listed_identity` | ⏸ `pending` QA-050 |
| `test_qa050_clean_build_does_not_depend_on_the_exemption_window` | ⏸ `pending` QA-050 |
| `test_qa051_sc84b_is_denied_even_when_a_generated_wanted_passenger_shares_his_name` | ⏸ `pending` QA-051 |
| `test_sc84_echoes_wear_the_right_face_of_day_two` | ✅ passe |
| `test_qa060_sc84b_keeps_the_photo_face_with_a_0_11_memory_entry` | ⏸ `pending` QA-060 (marque comme traitée l'erreur « aucun cas propre » attendue tant que le défaut existe) |
| `test_qa052_real_m11_profiles_without_slot_keep_their_progress` | ⏸ `pending` QA-052 |
| `test_real_m11_profile_with_its_finished_game_migrates_and_offers_the_epilogue` | ✅ passe |
| `test_qa053_garde_portrait_cache_does_not_grow_with_the_run` | ⏸ `pending` QA-053 |
| `test_qa054_procedure_error_does_not_read_the_same_verdict_twice` | ⏸ `pending` QA-054 |
| `test_qa055_invalid_daily_code_is_not_reported_as_a_length_error` | ⏸ `pending` QA-055 |
| `test_conclusions_never_name_a_lost_away_or_held_relative` | ⏸ `pending` QA-056 |
| `test_pad_only_m12_screens` | ✅ passe (fin de garde, carte du J31, conclusion, Dossier : vrais boutons de manette) |
| `test_pad_only_garde_directive_card_and_end_from_the_bar` | ⏸ `pending` QA-057 (COMPRIS au Ⓐ vérifié) |

Durée du fichier : ≈ 6 s. Fixtures : `tests/fixtures/qa_profile_v1_m11_f9_j30.json` (+ `_slot_current.json`, `_slot_meta.json`), `qa_profile_v1_m11_f5_j30_noslot.json`, `qa_profile_v1_m11_f3_j15_noslot.json` — **profils réels écrits par la 0.11.0** (`git archive ba17e14`, parties jouées par son `qa_campaign`). Pilotes de vraie scène (hors GUT) : `tests/qa_drivers/qa_m12_campaign.gd`, `qa_m12_garde.gd`, `qa_m12_events.gd`, `qa_m12_migrate.gd`.

### 15.11 Recommandations priorisées

1. **QA-062** et **QA-057** avant tout playtest de la Garde (une erreur coûte un tiers de la partie ; la manette est la cible Deck).
2. **QA-050** (une ligne dans `case_builder.gd`) puis **QA-051** : intégrité des listes du jour.
3. **QA-056**, **QA-060** : cohérence narrative des retrouvailles et des échos sur les sauvegardes 0.11 (les joueurs 0.11 arriveront en M12 avec ces mémoires).
4. **QA-052** (et M12 §7.5) : ne pas reverrouiller la Garde ni cacher les totaux à un joueur qui a fini la campagne en 0.11.
5. **QA-053**, **QA-061** (Garde longue), **QA-058** (texte 1,5).
6. QA-054, QA-055, QA-059 à la livraison 0.12.0.
7. QA (suite) : étendre `smoke_export.sh` à `--garde` et `--epilogue` ; playtest humain de la Garde (cibles M12 §6.1 : médiane 20–30, 30–50 s par passager) et de l'EV-08 un jour court ; une vraie fin F8 / F10 jouée à la main pour le monde C.

### 15.12 Rejouer la passe M12

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit        # 783 tests, 10 pending
godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_qa_m12.gd \
    -gpre_run_script=res://tests/helpers/gut_pre_run.gd -gexit                       # ≈ 6 s
# Campagne réelle + épilogue par les trois portes (tronçons de 9 min ; reprise : --qa-load=<copie de slot_1/current.json>)
X=$(mktemp -d); XDG_DATA_HOME=$X timeout 540 godot --headless --script res://tools/qa_boot.gd -- \
    --qa-node=res://tests/qa_drivers/qa_m12_campaign.gd --autoplay --qa-seed=3 --qa-profile=loyal --qa-speed=10 \
    --qa-reload --qa-credits=3000
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
    --qa-node=res://tests/qa_drivers/qa_m12_campaign.gd --autoplay --qa-load=$PWD/tests/fixtures/qa_save_v5_j25_solidaire.json \
    --qa-profile=solidaire --qa-speed=10 --qa-reload                                  # F9, monde B
# Garde réelle (codes, directives, records, déterminisme) ; garde longue
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m12_garde.gd --qa-garde-long=70
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m12_garde.gd --qa-garde-long=130 --qa-only-long
# Un jour réel par événement : ev_01 1/25, ev_02 2/8, ev_03 7/8, ev_04 1/18, ev_05 1/15, ev_06 1/7, ev_07 13/18, ev_08 1/5
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m12_events.gd --seed=1 --day=18 --autoplay
# Simulation
godot --headless --script res://tools/balance_sim.gd -- --garde --seeds=300 --seed=1 --profiles=0.8,0.9
godot --headless --script res://tools/balance_sim.gd -- --garde --decay --seeds=300 --seed=1
godot --headless --script res://tools/balance_sim.gd -- --events=compare --seeds=150 --seed=1 --profiles=0.8
godot --headless --script res://tools/balance_sim.gd -- --seeds=400 --seed=1 --profiles=0.8 --events=on 2>&1 | grep "invariants violés"   # QA-050
# Captures (xvfb, OpenGL 3) : directive en 4 modes, bandeau, J31, Dossier
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1920x1080 --qa-wait=30 \
    --qa-out=/tmp/dir.png --garde=K2Q-9TX --skip-cases=5 --hold-card --qa-set=color_vision:N --reduce-motion
#   bandeau : --seed=2 --day=8 --skip-cases=1 --station-event=ev_02 ; J31 : --epilogue=f10_pont [--skip-cases=7]
#   Dossier : --qa-scene=res://scenes/main/main.tscn --demo-profile[=early] --title=dossier|dossier-people
# Données, exports
godot --headless --script res://tools/build_data.gd && md5sum data/*/*.tres
bash tools/export_all.sh linux && bash tools/smoke_export.sh
```

---

## 16. Passe QA M13 « Gameplay »

> Passe du 30.10.2026 sur `claude/laughing-bell-8ayudz` après `a9ddc0c` (M13 intégré : déclarations et R43, journal à puces, fouille holographique R44–R47, contrebande et implants cachés, AG-01 → AG-06, prime de relevé, SC-104 → SC-111, Garde v2, EV-09, cartes d'aide). Godot 4.7.2, GUT 9.7.1. **QA ne corrige pas le code de jeu** : bugs QA-063 à QA-071 ci-dessous, chacun avec son propriétaire suggéré.

### 16.1 Méthode et couverture

| Volet | Outil | Résultat |
|---|---|---|
| Suite existante | GUT, unit et integration lancés séparément (> 10 min ensemble) | **882 / 882** à l'arrivée (unit 576 en 225 s, integration 306 en 546 s) ; après la passe **893 tests : 885 verts + 8 `pending`**, 0 échec (§16.8) |
| Interrogatoire en vraie scène | **`tests/qa_drivers/qa_m13_booth.gd`** (nouveau) : `day.tscn` (booth 3D, vraie `ComparisonUI`, vraie `InspectionSession`), agent « oracle » qui pose la question de motif par l'action `interrogate` + Ⓐ (origine en plus au palier s3+), puis compare **chaque puce du journal à chaque champ comparable par de vrais clics souris** (`Viewport.push_input`), fouille par le menu (motif lu, TOUT SCANNER, objets épinglés à l'onglet Contrebande ou à la carte), épingle les autres violations par paires puis tamponne (maintien) | 20 journées réelles jouées (§16.2) : J4, J8, J9, J12, J13, J16, J19, J22, J24 (graine 3), J19 (graines 30, 43), J23 (6), J25 (12), J8 (7 : EV-05 ; 14 et 24 : EV-09) ; variantes « menteurs non interrogés », « fouille sans motif », « aucune fouille », AG-01 + AG-03 ; **0 faux positif** sur ≈ 650 comparaisons puce ↔ champ (hors QA-064) |
| Manette seule (vraie scène) | même pilote, `--qa-pad-chip` : graphe de focus **mesuré par de vrais appuis** (`InputEventJoypadButton` croix, `InputEventJoypadMotion` LT / stick droit) puis chemin rejoué, Ⓐ | puce atteinte en 3 appuis (↑ ↑ ←), champ du permis en 5–6 (↓ ↓ → ↑ →), comparaison faite ; portique et boîte : tests GUT existants + captures |
| Faux positifs (hors scène) | **`tests/qa_drivers/qa_m13_scan.gd`** (nouveau) : 50 historiques de drapeaux synthétiques × J1 → J30 ; chaque puce de **chaque** cas (générés et scénarisés) comparée à **chaque** champ de document ; verdicts scénarisés 0.12 (`M13Sim.strip`) ↔ 0.13 | 4 743 cas scénarisés, 55 164 puces : 0 discordance chez un honnête sans autre anomalie, 0 sur un cas scénarisé ; 248 « déclarations » discordantes chez des passagers en infraction pour une autre anomalie (QA-064) ; aucun verdict scénarisé SC-01 → SC-103 changé (seul SC-89b diffère, avec des drapeaux contradictoires `sc18_note_kept` + `sc18_note_reported` : artefact du balayage, pas du jeu) |
| Répliques | `tools/qa_statements_audit.gd` ; **`tests/qa_drivers/qa_m13_lines.gd`** (nouveau : 3 293 réponses composées réellement générées, relues) | 241 répliques scénarisées, 0 contradiction ; ≤ 90 caractères partout ; casse correcte ; tournures fautives (QA-068) |
| Événements | **`tests/qa_drivers/qa_m13_events_find.gd`** (calendrier EV-05 / EV-09 sur 59 campagnes) puis vraie scène | EV-05 au J8 (graine 7) et au J25 (graine 12) : portique retiré, aucun indice ni anomalie de fouille après la coupure ; EV-09 au J8 (graine 14) : **aucun passager du profil** dans la fenêtre (QA-066) ; EV-05 × R47 (QA-063) |
| Améliorations | vraie scène (`--flags=upg_ag0N`), captures de l'Économat (`--screen=evening --shop=ag0N`), lecture des données et du code | effets AG-01 / AG-02 / AG-03 / AG-05 / AG-06 visibles et mesurés ; refus expliqués ; messages d'offre jamais affichés (QA-069) ; prime de relevé (QA-067) |
| Garde v2 | `tests/qa_drivers/qa_m12_garde.gd` (garde longue K2Q-9TX, 110 passagers) | U21 (75ᵉ), U22 (80ᵉ), U23 (90ᵉ, après U22 et U11) tirées ; 0 erreur de l'oracle, 0 `ERROR` ; records `garde_version` 2 |
| Sauvegardes 0.12 → 0.13 | **vraies sauvegardes 0.12.0** (`git archive f6d5f35`, importé, campagne réelle graine 5) versées en `tests/fixtures/qa_save_v6_012_j03.json`, `_j07.json`, `_j09.json` ; reprises par `qa_campaign --qa-load` | J3 → J18, J7 → J21, J9 → J23 joués en 0.13 sans erreur (§16.6) |
| Campagnes complètes | `tools/qa_campaign.gd` (tronçons de 9 min repris sur la sauvegarde réelle) | voir §16.7 |
| Équilibrage | `balance_sim --m13=compare` (100 graines, `default` et `passeur`, 80 %) ; `gen_stats` (40 campagnes) | §16.8 |
| Visuel, accessibilité | ≈ 20 captures réelles OpenGL 3 sous xvfb (1080p, Deck 1280×800, texte 1,5, `--qa-pad`, vision des couleurs 1–3, `--reduce-motion`) ; versées en `docs/mockups/m13_qa_*.png` | §16.5 |

**Vrai `user://saves` jamais touché** : vide avant et après la passe, `settings.cfg` du joueur inchangé (md5 `9d0188…`) ; tous les outils sous `XDG_DATA_HOME` temporaire (scratchpad) ; aucun `override.cfg`.

### 16.2 Interrogatoire (R43, journal, puces)

Pilote `qa_m13_booth.gd`, graine 3 sauf mention ; « puces » = comparaisons puce ↔ champ faites **à la souris** (puce puis champ) ; CONC / INCOMP / DISC = CONCORDANT / INCOMPARABLE / DISCORDANCE.

| Jour (palier) | Puces comparées | Discordances | Constat |
|---|---|---|---|
| J4 (s1 : motif, durée) | motif 7 CONC ; durée 3 CONC, 3 INCOMP (« Ça dépend du travail », « Aussi longtemps qu'on voudra de moi », « Le temps du contrat » : `disc_statement_vague`) | 1 : SC-104 Strand, « Trois semaines » ↔ 5 jours | refus documenté, **7 ₵** (5 + prime 2) ; carte d'aide « déclarations » à la fermeture du briefing |
| J4, menteurs **non interrogés** (`--qa-liars=skip`) | — | — | SC-104 approuvé → **ENTRÉE IRRÉGULIÈRE** ✅ (D-005) |
| J12 (s2 : + employeur) | employeur 21 CONC (alias « chez Ondine », « chez Valcourt-Hsu » → nom canonique) | 1 : SC-107 Priya Nair (courtier) | refus juste ; aucune puce employeur hors TRAVAIL |
| J13 (s3 : + origine) | origine 12 CONC (« Je suis de… » ; provenance jamais comparée) | 1 : durée (menteur généré) | refus documenté **7 ₵** ; question d'origine posée en plus (2 × 3 s) |
| J19, J23 (s3) | origine 11 + 10 CONC | 1 + 1 : origine (AV-4) | refus documentés 7 ₵ |
| J19, graine 43 | employeur ↔ **Code du contrat** : 2 DISC chez des passagers **honnêtes** dont le contrat est faux (R25) | 2 | **QA-064** : affiché « DÉCLARATION », compté « déclaration contradictoire » au bilan, `about_statement` débloquée |
| J24 (s4 : + personne visitée) | personne visitée 1 DISC (SC-110 Sabine Moreno-Lind, « mon fils, Tomás Moreno-Lind » ≠ répondant) ; employeur 1 DISC (généré) | 2 | refus justes ; J25 (graine 12) : personne visitée 1 CONC |

- **Zéro faux positif** sur un honnête, en scène (≈ 650 comparaisons sur 20 journées), et hors scène sur 55 164 puces (balayage) : réponses vagues, provenance, auto-corrections (la valeur barrée n'est pas une puce), hésitations, alias d'employeur, durées arrondies (« Trois semaines » ↔ 20 j). Les seules discordances d'honnêtes viennent d'un **autre document faux** (QA-064 : contrat ; le refus reste juste et documenté, mais l'étiquette accuse la parole du passager).
- **Cas scénarisés** : aucune puce discordante hors du mensonge déclaré (`test_scripted_chips_are_never_discordant_outside_their_lie`) ; SC-01 → SC-103 en prose : 0 contradiction (`qa_statements_audit`) ; verdicts SC-01 → SC-103 identiques 0.12 / 0.13 sur 50 historiques.
- **Coûts** (`inspection_busy`) : question 3 s ; +1 s avec auto-correction (4 s) ; AG-01 : 2 s. Pendant l'attente, menu Interroger et portique grisés, tampons et inspection libres (D-158).
- **Casse** : aucune phrase ne commence par une minuscule (3 293 réponses composées) ; `‹Ha.› 8 jours.` commence par un chiffre (format `%d jours` assumé par M13 §1.6). Tournures fautives : **QA-068**.
- **Audio** des réponses composées : couvert par `test_statement_frame_is_spoken_composed` (vert) ; pas d'écoute humaine dans cette passe (conteneur sans sortie audio).

### 16.3 Fouille (R44 → R47)

| Vérification | Résultat |
|---|---|
| Déblocage | portique et onglet Contrebande au J8 (cartes d'aide « déclarations » puis « portique » au premier jour joué) ; menu « Placez-vous dans le portique… » seulement si R44 est en vigueur |
| Motif affiché, figé | MF-1 « Discordance n » (J13 #14 : durée épinglée avant), MF-2 « INDICE : BOSSE SOUS LA VESTE » (capture), MF-5 « FOUILLE OBLIGATOIRE (R47) » (Kerr J19, J22 #8, J23 #2 et #9, J24 #12) ; MF-4 : voir EV-09 ci-dessous |
| Boîte « AUCUN MOTIF ÉTABLI » | J8 #2 (Brandt, en règle) : focus **ANNULER** (capture Deck manette texte 1,5), FOUILLER QUAND MÊME → **FOUILLE SANS MOTIF** (`cit_unwarranted_search`, 0 ₵), bilan « sans motif · 1 » ; ANNULER : rien n'est compté (GUT) |
| Durées | activation 2 s + 5 × 2 s = **12 s** (TOUT SCANNER) ; AG-03 : 1 s + 5 × 1 s = 6 s. *Écart documentaire connu* : M13 §3.2 annonce « TOUT SCANNER 10 s → 4 s », les données (`search_all_sec` 5) font foi (ARCHITECTURE §12.4) — à aligner dans M13 (Game Designer) |
| TOUT SCANNER pendant l'activation | bouton grisé pendant les 2 s d'activation (D-158) : il faut attendre la fin de l'activation, alors que la session accepte la mise en file (ARCHITECTURE §12.5). Conforme à D-158, noté pour l'UX |
| Objets épinglables | objet ↔ entrée de l'onglet Contrebande : CB-01, CB-02, CB-03, CB-05, CB-06, CB-07 DISCORDANCE ; implant trouvé ↔ « Implants déclarés » : MIL-2 et DER-13 non déclarés DISCORDANCE, KIN-11 / KIN-17 déclarés CONCORDANT (SC-105 Mbeki, J13, J22) |
| Armes, implants militaires | CB-06 (J13), CB-07 (SC-111 Whitmore, J22), MIL-2 (J8) → **DÉTENTION** documentée, **12 ₵** (5 + 5 + prime 2) |
| R47 au J19 | Kerr (SC-109) : motif « obligatoire », fouille complète, APPROUVÉ juste ; sans fouille (`--qa-no-search`) : **FOUILLE OMISE** (`cit_search_skipped`) ✅ |
| EV-05 | graine 7 J8 (coupure dès #11), graine 12 J25 (dès #5) : entrée « portique » retirée, aucun indice ni anomalie de fouille après la coupure (vraie scène + `test_blackout_window_has_no_search_anomaly_nor_cue`) ; **R47 reste en vigueur** : QA-063 |
| EV-09 | graine 14 J8, profil Cérès, fenêtre #10–#14 : Tycho, Tharsis, Tycho, Tharsis, Tycho — **aucun porteur ni passager du profil** (QA-066) ; graine 24 J8 (profil COMMERCE) : 2 porteurs du profil dans la fenêtre (#13 Dérivant, #14 Terrien), tous deux avec un indice — le bandeau dit « INDICE » (MF-2 passe avant MF-4) ; MF-4 « DIRECTIVE DU JOUR » ne s'affiche que pour un passager du profil **sans** indice (GUT `test_search_motive_order_mf1_to_mf5`) |
| Lucioles, objets glissés | SC-108 Ilse (J16) : CB-03 trouvé, refus → `sc108_searched`, `lucioles_trust −1` (effet de SC-108 restauré par les finitions) ✅ ; objets glissés : inchangés (campagnes) |
| Détention, `inspection_busy` | le tampon referme la fouille ; pendant une zone, seules les entrées Interroger / portique sont suspendues (D-158) ; lecture, Mode Inspection, onglet FOUILLE du journal et tampons restent utilisables |

### 16.4 Améliorations (AG-01 → AG-06) et prime de relevé

| Amélioration | Vu en jeu | Efficace |
|---|---|---|
| AG-01 Hygiaphone | pastille « AG-01 » au panneau File | questions 3 → **2 s** (`inspection_busy`, J19) |
| AG-02 Lampe de Wood | « UV · MODÈLE 2187 », « UV · HEXAGONE SOLAIRE »… sous le sceau de chaque document (capture J12) | lecture du modèle sans zoom ; aucune conformité affichée |
| AG-03 PH-2 | pastille | activation 2 → 1 s, zone 2 → 1 s ; relevé (`suspicion +1` après approbation d'un porteur révélé) : GUT seulement (`test_day_controller_search_consequences`) |
| AG-04 Tiroir | proposé hors catalogue **dès le soir du J5** quand une enveloppe a été vue (partie 0.12 reprise : offert J5, J6, J7, J8, J10) | audits J9 / J17 / J29 : GUT (`test_double_drawer_envelopes_and_audits`) ; message de confiscation jamais affiché (QA-069) |
| AG-05 Recueil | soirs J6 → J8 seulement, « NOUVEAU » (capture J6) ; Rulebook ouvert à la bonne règle avec la marge d'Okonkwo (GUT) | message d'Okonkwo jamais affiché (QA-069) |
| AG-06 Moniteur | « MANIFESTE · TYC · TRAVAIL · 4 DOC. » au panneau File (capture J12) ; offert à partir du soir du J11, « NOUVEAU » | `loyalty +1` à l'achat : GUT |

- **Un achat par soir**, jamais présélectionné, « Un achat par soir : décochez l'autre d'abord », « Fonds insuffisants » (captures J6, J11) ; « Solde après achat » recalculé. L'achat concurrence le foyer : au soir du J6, cocher le Recueil (10 ₵) rend le bio-scan de Noa (25 ₵) « Fonds insuffisants » — voulu (M13 §3.1), mais rien ne le signale au moment de cocher (le soin est dans « CE SOIR », l'Économat dans les dépenses).
- **Prime de relevé** (2 ₵) observée sur : refus R43 (SC-104, J13, J19, J23), refus R45 (J8, J9, J16, J19, J22), détentions R46 / MIL (12 ₵) ; **jamais** sur un refus R25 documenté par la puce employeur (J19, graine 43 : 5 ₵), ni sur une approbation. Versée aussi **sans** trouvaille de M13 quand le menteur porte une autre anomalie : **QA-067**.

### 16.5 Manette seule et accessibilité

| Élément | Manette | Deck 1280×800, texte 1,5 | Vision des couleurs | Réduire les animations |
|---|---|---|---|---|
| Journal à puces | vraie scène : puce en 3 appuis de croix, champ du permis en 5–6, Ⓐ / Ⓐ (§16.1) | lisible ; **ponctuation seule en tête de ligne**, numéro de discordance posé sur le texte de la puce, étiquette « FIGÉE » coupée en haut (QA-070) — [`m13_qa_journal_deck_text150.png`](mockups/m13_qa_journal_deck_text150.png) | puces : glyphe « » » + pointillé ; discordance hachurée et numérotée en protan et tritan — [`m13_qa_journal_protan.png`](mockups/m13_qa_journal_protan.png), [`_tritan`](mockups/m13_qa_journal_tritan.png) | — |
| Portique | focus sur la première zone libre, croix entre zones / TOUT SCANNER / FERMER, Ⓑ referme (GUT `test_gate_is_driven_by_pad_and_closed_by_back`) ; invite « choisissez une zone (A) ou TOUT SCANNER · B : refermer » — [`m13_qa_search_deck_pad.png`](mockups/m13_qa_search_deck_pad.png) | zones et objets étiquetés en texte ; liste d'objets défilante | objets épinglés : hachures + numéro (deutan) — [`m13_qa_contraband_deutan.png`](mockups/m13_qa_contraband_deutan.png) | balayage coupé, barre d'attente par quarts — [`m13_qa_search_reduce_motion.png`](mockups/m13_qa_search_reduce_motion.png) |
| Boîte « AUCUN MOTIF ÉTABLI » | focus **ANNULER**, Ⓑ annule, guichet muet derrière — [`m13_qa_unwarranted_deck_pad_text150.png`](mockups/m13_qa_unwarranted_deck_pad_text150.png) | tient en texte 1,5 | bouton FOUILLER rouge + libellé | — |
| Onglet Contrebande | LB / RB jusqu'à l'onglet ; entrées focalisables | **libellé « Contrebande · NOUV. » coupé sous l'invite [** (QA-071) — [`m13_qa_contraband_deck_text150.png`](mockups/m13_qa_contraband_deck_text150.png) | REFUS · R45 en texte | — |
| Économat | rangées focalisables, Ⓑ n'achète pas (GUT) | refus écrits (« Fonds insuffisants », « Un achat par soir… »), prix narratifs — [`m13_qa_shop_j11_deck_text150.png`](mockups/m13_qa_shop_j11_deck_text150.png), [`m13_qa_shop_j6_ag05.png`](mockups/m13_qa_shop_j6_ag05.png) | ⚠ + texte | — |
| Cartes d'aide | focus SUIVANT / COMPRIS, invites Ⓐ / LT / Y / croix — [`m13_qa_help_deck_pad_text150.png`](mockups/m13_qa_help_deck_pad_text150.png) | « 1 / 2 », tient en texte 1,5 | — | — |
| Améliorations au guichet | pastilles AG-0n, manifeste, « UV · modèle » — [`m13_qa_booth_upgrades_j12.png`](mockups/m13_qa_booth_upgrades_j12.png) | — | texte | — |

### 16.6 Garde v2, Récit, sauvegardes 0.12 → 0.13, J31

- **Garde v2** (vraie scène, garde longue K2Q-9TX, 110 passagers, oracle) : U21 (R43 s1) tirée au 75ᵉ passager, U22 (R44 + R45) au 80ᵉ, U23 (R46) au 90ᵉ, après U22 et U11 ; 0 erreur, 0 `ERROR`, records et graines `garde_version` 2 dans `profile.json`. U24 (R43 s2 + s3, « remplacé en place ») non tirée en 110 passagers : couverte par `test_garde_tier_replaces_r43_in_place` (vert).
- **Récit** : campagne réelle complète (§16.7) ; FOUILLE SANS MOTIF / FOUILLE OMISE à 0 ₵ : GUT existants.
- **Sauvegardes 0.12.0 réelles** (v6, écrites par la 0.12.0 compilée depuis `f6d5f35`) : avant J4 (`qa_save_v6_012_j03.json`), avant J8 (`_j07`), après J8 (`_j09` : J8 joué sans portique en 0.12). Reprises par `qa_campaign --qa-load` : J3 → J18, J7 → J21, J9 → J23 en 0.13, **0 `SCRIPT ERROR`, 0 `QA_ISSUE`** hors « solde aberrant » attendu (+3 000 ₵), sauvegarde relue = `GameState` chaque soir ; Économat ouvert au soir du J5 (AG-01, AG-04 hors catalogue puisqu'une enveloppe a été vue au J4 en 0.13) ; R43 au J4, portique au J8 ou au J9 pour la partie reprise après le J8. Aucune migration nécessaire (v6 inchangée, M13 §6.5) — confirmé.
- **J31** : règles R43 → R47 absentes des quatre mondes (`test_r43_tiers_follow_the_calendar`, vert) ; `data/epilogue/day_31_*.tres` régénérés par M13 avec le même contenu (seuls les identifiants de sous-ressources changent) ; épilogue non rejoué en scène dans cette passe.

### 16.7 Campagnes réelles J1 → J30 (`qa_campaign`, `day.tscn`, bot `--autoplay`, ×10, `--qa-reload`)

Deux tronçons de 9 min par campagne (le second reprend la vraie sauvegarde `current.json` du premier). Le bot ne pose que la question de motif et ne fouille jamais : il mesure la stabilité, pas l'usage de M13.

| Graine | Profil (soirées) | Mode | Départ | Jours | Fin | Solde | Conformité | Problèmes |
|---|---|---|---|---|---|---|---|---|
| 3 | loyal | Dur | J1 (+3 000 ₵) | J1 → J30 (17 + 13) | **F7** Le guichet rouvre | 380 ₵ | 58 % | aucun |
| 11 | passeur | Dur | J1 (+3 000 ₵) | J1 → J30 (18 + 12) | **F7** | 111 ₵ | 55 % | aucun |
| 7 | drift | **Récit** | J1 (+3 000 ₵) | J1 → J30 (17 + 13) | **F6** Dérive | 946 ₵ | 60 % | aucun |

0 `QA_ISSUE` hors « solde aberrant » attendu, 0 `SCRIPT ERROR`, 0 `WARNING` ; sauvegarde relue = `GameState` chaque soir ; Économat proposé chaque soir à partir du J5 (AG-01 : 25 soirs, AG-02 / AG-03 : 21 soirs, J9 → J29), **jamais coché par défaut** (aucun achat du bot). Plus les trois reprises de sauvegardes 0.12 (§16.6) : 54 jours de plus, mêmes résultats.

### 16.8 Régression et équilibrage

**Régression** :
- **GUT après la passe** : unit **576 / 576** (203 s) ; integration **317 tests : 309 verts + 8 `pending`** (QA-063 → QA-070), 0 échec, 0 `SCRIPT ERROR` (549 s — près de la limite de 10 min : à scinder si la suite grossit) ; total **893 tests, 885 verts, 8 `pending`**.
- **`build_data`** : relancé, **0 fichier** de `data/` modifié (md5 identiques, 193 ressources écrites) : déterministe.
- **`export_all.sh linux`** : 47 s, `build/dist/CLEARANCE-0.12.0-linux.tar.gz` (38,8 Mo ; nom de version : QA-065) ; **`smoke_export.sh`** : titre, J1 / J4 / J7 / J10 / J15 / J20 / J25 / J30, Garde, deux J31 : **OK** (3 min). Le smoke ne passe ni par le J8 (portique), ni par le J19 (R47), ni par le J24 (palier s4) : à ajouter.
- Campagnes réelles, reprises 0.12, Garde : §16.6, §16.7.

**Équilibrage.** **`balance_sim --m13=compare --upgrades=smart --profiles=0.8 --seed=1 --seeds=100`** (100 graines : écart-type d'une différence de parts ≈ 4 à 7 points, M13 §4.7) :

| Préréglage | Écart max (100 graines) | §4.7 (1 000 graines) | Détail | Lecture |
|---|---|---|---|---|
| `default` | 7,0 | 2,4 | F1 Déposition 17 → 10, F3 4 → 8, F7 77 → 81 ; soldes J10 / J20 / J29 −9 / −20 / −15 ₵ ; achats AG-01 73 %, AG-02 29 %, AG-03 43 %, AG-05 35 %, AG-06 37 % ; questions 11,8 / jour, fouilles 1,5 / jour (0 sans motif), fausses déclarations 0,62 / jour relevées à 64 % | dans le bruit à 100 graines ; achats et soldes cohérents avec §4.7 (75 / 29 / 45 / 42 / 44 % ; −8 / −19 / −6 ₵) |
| `passeur` | 5,0 | 9,0 | F10 11 → 16, F7 56 → 53, F1 Déposition 17 → 19 | même sens que §4.7 (F7 → F1 / F10), D-170 |

La prime de relevé mesurée par la simulation inclut les cas de QA-067 (prime sans trouvaille) : la correction de QA-067 retirera un peu d'argent aux profils qui refusent sur une autre anomalie (à re-mesurer, Game Designer).

**`gen_stats --campaigns=40 --seed=1`** (J1 → J30) : **invariants OK** ; M13 sur l'ensemble : fausses déclarations 4,2 %, anomalies de fouille 5,8 %, armes 0,03 / jour, indices des innocents 10,6 %, P(porteur | indice) 36,8 %, évasives des innocents 3,5 % — dans les cibles de §4.1. Par jour (n = 480 à 680 passagers, ± 1 à 2 points) : J4 9,7 % de fausses déclarations (cible 8–11 ✅), J12 7,3 % et J13 8,3 % (7–9 ✅), J24 8,3 % (7–9 ✅) ; J8 fouille 9,0 % (7–10 ✅) mais **P(porteur | indice) 51 %** (cible 30–45) ; **J19 fouille 6,2 %** (cible 8–10) et indices des innocents 13,3 % (10–12) ; J24 P(porteur | indice) 27 % (30–45). Écarts à confirmer sur 200 campagnes avant d'en faire des bugs (Game Designer, `search_cue_noise_rate` du J8 et poids du J19).

### 16.9 Liste des bugs (M13)

Statut : 🔴 ouvert. QA-063 à QA-070 ont chacun un test `pending` dans `tests/integration/test_qa_m13.gd` (§16.10) ; QA-071 est documenté par une capture.

| ID | Sév. | Titre | Reproduction | Propriétaire suggéré | Preuve |
|---|---|---|---|---|---|
| QA-063 | **Majeur** | **Coupure EV-05 : R47 reste en vigueur sans portique** — EV-05 retire R44 (`RuleChangeDef.retire(R44)` seul, `build_data_m13.gd`) : plus d'entrée « portique », mais `r_belt_search` reste dans le RuleSet. Au J19+, un Ceinturier au séjour > 7 jours **en règle** qui se présente après la coupure ne peut être que **cité FOUILLE OMISE** (APPROUVÉ, `ScoringService._procedure_citation` ne regarde pas si la fouille était possible) ou **refusé à tort** (REFUS INJUSTIFIÉ, gravité 3). EV-05 tombe aux J19–J28 dans ≈ 1 campagne sur 5 (12 graines sur 59 : 30, 43 au J19 ; 6, 21, 24, 31, 41 aux J22–J23 ; 10, 12 au J25 ; 26, 7, 40 aux J26–J28) | J19 réel, EV-05 appliqué (`ev_05.changes`), Ceinturier 14 j en règle, APPROUVÉ sans fouille → `cit_search_skipped` ; vraie scène graine 12 J25 : « R47 visé, portique HORS SERVICE » (#6) | Gameplay Systems (EV-05 : suspendre aussi R47, `sev_blackout_rb_search` pour les deux) ou Godot Architect (`ScoringService` : `belt_search` seulement si `search_cause` est active) ; Game Designer (choix) | `test_qa063_*` |
| QA-064 | Mineur | **« DÉCLARATION » discordante chez un passager qui n'a pas menti** — puce employeur ↔ **Code du contrat** quand le contrat est faux (R25) : `disc_statement_mismatch`, bandeau « DÉCLARATION · Dit : … ≠ … », confrontation « Ce que vous dites ne correspond pas à votre contrat » débloquée, bilan « Déclarations contradictoires relevées · n » (`DaySummary.get_statement_mismatch_count`) ; le refus reste juste et documenté (la paire partage le Code), sans prime. Contredit M13 §1.6 (« un honnête ne produit jamais de puce discordante »). 248 cas sur 55 164 puces (balayage) ; vraie scène : 2 au J19 (graine 43) | J19 graine 43 #3 (Valcourt-Hsu, contrat « CT-… » d'un autre code) et #12 ; `qa_m13_scan.gd` | Gameplay Systems (`DiscrepancyChecker._check_statement` : hors champ de référence, raison documentaire et non `statement_mismatch`, ou comparer au Code seulement si permis et contrat concordent) + UI/UX (bilan) | `test_qa064_*` |
| QA-065 | Cosmétique | **Version non montée** : `config/version = "0.12.0"` (export `CLEARANCE-0.12.0-linux`, `game_version` des sauvegardes) alors que M13 = 0.13.0 | `export_all.sh linux` | Orchestrateur (à la livraison) | `test_qa065_*` |
| QA-066 | Mineur | **EV-09 « Alerte des quais » sans aucun porteur du profil** — pour un profil d'origine (Tycho, Cérès), `CaseBuilder._plan_search_alert` choisit les porteurs parmi les passagers **déjà** de cette origine dans la fenêtre ; s'il n'y en a pas, l'alerte (« fouille autorisée des ressortissants de Cérès pour les cinq prochains passagers ») est annoncée et ne vise personne : **14 alertes sur 77** (300 campagnes). M13 §2.10 promet « 1 ou 2 porteurs du profil dans la fenêtre » | vraie scène graine 14 J8, fenêtre #10–#14 : Tycho, Tharsis, Tycho, Tharsis, Tycho | Gameplay Systems (profil tiré parmi ceux présents dans la fenêtre, ou origine imposée à 1–2 passagers générés comme pour les profils par motif) | `test_qa066_*` |
| QA-067 | Mineur (économie) | **Prime de relevé versée sans trouvaille de M13** — `ScoringService.is_m13_finding` ne lit que les violations **attendues** : un menteur (AV) ou un porteur qui a aussi une autre anomalie, refusé sur cette autre anomalie **sans question ni fouille**, rapporte les 2 ₵. D-169 et M13 §4.4 : prime pour « une déclaration **épinglée** ou un objet/implant **révélé** ». Fausse aussi la mesure de D-168 (la simulation paie la même prime) | cas réel J4–J14, `r_identity_fields_match` + `r_statements`, refus documenté par l'identité seule : salaire 7 ₵ au lieu de 5 | Godot Architect (`ScoringService` : exiger une discordance confirmée sur `FieldRef.statement` / `scan` parmi `verdict.flagged`) + Game Designer (re-mesure `passeur`, `drift`) | `test_qa067_*` |
| QA-068 | Cosmétique (texte) | **Réponses composées mal tournées** (36 sur 2 119 phrases uniques) : « Vendre ce que j'apporte, pour **je ne sais pas encore**. C'est écrit sur le permis. », « Affaires d'État, pour **ça dépend du travail**. » ; réponse vague suivie d'une affirmation précise (« Quelques jours. **Pas un jour de plus.** », « Ça dépend du travail. **C'est ce qu'on m'a accordé.** ») ; « J'arrive de Tycho. **Mais** je suis de Tycho, oui. » ; « Le temps du contrat, le temps du chantier. » ; « Je viens travailler **chez le Bureau** ». Aussi « Voir ma famille. Ça dépend du travail. » | `qa_m13_lines.gd` (3 293 réponses) | Scénariste (cadres compatibles avec les durées vagues ; formule « au Bureau ») + Gameplay Systems (`StatementGenerator` : pas de `gen_2` / `stay_1` / `stay_2` / `work_2` avec une durée vague ; `origin_3` seulement si provenance ≠ origine) | `test_qa068_*` |
| QA-069 | Mineur (narratif) | **Messages d'offre et de confiscation jamais affichés** — `UpgradeDef.offer_message_key` (`msg_soute_drawer`, `msg_okonkwo_book`, `msg_vh_monitor`) n'est lu par aucun script ; `msg_okonkwo_drawer_found` n'est posé nulle part. Le Recueil d'Okonkwo (« de la main à la main », « pour ma tasse ») et le tiroir de la Soute apparaissent comme de simples lignes de l'Économat ; la confiscation du tiroir n'a aucun retour d'Okonkwo (M13 §3.3, §3.5) | soirée J6 (capture) ; relecture des sources | UI/UX (`EveningScreen` : message dans « CE SOIR » au premier soir de l'offre) + Gameplay Systems (message après `upg_ag04_found`) + Scénariste | `test_qa069_*`, [`m13_qa_shop_j6_ag05.png`](mockups/m13_qa_shop_j6_ag05.png) |
| QA-070 | Cosmétique (lisibilité Deck) | **Journal : ponctuation détachée des puces** — `DialogueJournal._add_words` fait de « , » / « . » qui suivent une puce des `Label` séparés : au Deck en texte 1,5, « , normalement. » ouvre la ligne suivante ; en 1080p, espace visible avant le point (« passer . ») ; le numéro de discordance ① est posé sur la fin du texte de la puce (« Deux jou① ») ; l'étiquette « FIGÉE · DISCORDANCE » est coupée par le haut du journal (défilement) | `--day=13 --seed=3 --screen=shift --m13=journal --qa-size=1280x800 --qa-set=text_scale:1.5` | UI/UX Expert (`dialogue_journal.gd`, `statement_chip_view.gd`) | `test_qa070_*`, [`m13_qa_journal_deck_text150.png`](mockups/m13_qa_journal_deck_text150.png), [`m13_qa_journal_protan.png`](mockups/m13_qa_journal_protan.png) |
| QA-071 | Cosmétique | **Rulebook au Deck, texte 1,5 : onglet « Contrebande · NOUV. » coupé** à gauche sous l'invite « [ » (le « C » disparaît) | `--day=8 --seed=3 --screen=shift --m13=contraband --qa-size=1280x800 --qa-set=text_scale:1.5` | UI/UX Expert (`rulebook_panel.gd` : largeur de l'onglet / ellipse) | [`m13_qa_contraband_deck_text150.png`](mockups/m13_qa_contraband_deck_text150.png) |

Total M13 : **0 bloquant, 1 majeur, 4 mineurs (dont 1 économie, 1 narratif), 4 cosmétiques** (QA-063 à QA-071, 9 bugs). Aucun bug des passes précédentes réapparu (QA-057 : la boîte « AUCUN MOTIF » est une `ConfirmDialog` modale, focus ANNULER, guichet muet derrière).

### 16.10 Tests ajoutés (`tests/integration/test_qa_m13.gd`, 11 tests) et outils

| Test | État |
|---|---|
| `test_qa063_blackout_does_not_cite_a_belt_search_that_cannot_be_done` | ⏸ `pending` QA-063 |
| `test_qa064_honest_chip_is_never_a_statement_mismatch` | ⏸ `pending` QA-064 |
| `test_qa065_version_is_0_13` | ⏸ `pending` QA-065 |
| `test_scripted_chips_are_never_discordant_outside_their_lie` | ✅ passe (SC-104 → SC-111, 3 campagnes, chaque puce ↔ chaque champ) |
| `test_blackout_window_has_no_search_anomaly_nor_cue` | ✅ passe (EV-05 appliqué en cours de jour, 30 jours) |
| `test_qa066_every_contraband_alert_has_a_carrier_of_its_profile` | ⏸ `pending` QA-066 (14 / 77 alertes sur 300 campagnes) |
| `test_qa067_finding_bonus_needs_the_m13_finding_itself` | ⏸ `pending` QA-067 |
| `test_qa068_composed_answers_read_well` | ⏸ `pending` QA-068 |
| `test_qa069_offer_and_drawer_messages_are_wired` | ⏸ `pending` QA-069 |
| `test_qa070_punctuation_never_starts_a_journal_line` | ⏸ `pending` QA-070 (contrôle structurel : ponctuation séparable d'une puce) |
| `test_real_0_12_saves_resume_with_m13` | ✅ passe (3 vraies sauvegardes 0.12.0, valides, sans amélioration, jour suivant construit avec déclarations / fouille) |

Fixtures : `tests/fixtures/qa_save_v6_012_j03.json`, `_j07.json`, `_j09.json` — **sauvegardes réelles écrites par la 0.12.0** (`git archive f6d5f35`, campagne réelle graine 5, profil `default`).

Pilotes et outils (hors GUT, `tests/qa_drivers/`) :
- `qa_m13_booth.gd` — jour réel joué par l'oracle à la souris (et `--qa-pad-chip` : manette, graphe de focus mesuré) ; options `--qa-liars=skip`, `--qa-unwarranted=N`, `--qa-cancel-unwarranted`, `--qa-no-search`, `--flags=upg_ag0N` ; sorties `QA_CHIP`, `QA_FP`, `QA_SEARCH`, `QA_MOTIVE`, `QA_R47`, `QA_SCRIPTED`, `QA_RESOLVED`, `QA_ISSUE`.
- `qa_m13_scan.gd` — faux positifs et verdicts scénarisés 0.12 / 0.13 sur N historiques de drapeaux (`--histories=50 --seeds=1 [--only-day=N]`).
- `qa_m13_lines.gd` — réponses composées réellement générées (relecture typographique).
- `qa_m13_events_find.gd` — calendrier EV-05 / EV-09 par graine.

### 16.11 Recommandations priorisées

1. **QA-063** avant tout playtest de l'Acte III (une citation inévitable ou un refus injuste, ≈ 1 campagne sur 5).
2. **QA-067** puis re-mesure de D-168 (la prime finance une partie de l'équilibrage économique).
3. **QA-064** (étiquette, bilan et confrontation qui accusent un honnête) et **QA-066** (alerte sans objet).
4. **QA-069** (trois offres d'amélioration sans leur message, confiscation muette), **QA-068** (Scénariste).
5. **QA-070**, **QA-071** (lisibilité Deck en texte 1,5), **QA-065** à la livraison 0.13.0.
6. QA (suite) : ajouter J8, J19 et J24 à `smoke_export.sh` (portique, R47, palier s4 absents du smoke) ; playtest humain des cibles M13 §4.2 (questions posées, mensonges trouvés, fouilles avec motif) ; garde longue jusqu'à U24 ; `gen_stats` sur 200 campagnes pour J8 / J19 (§16.8) ; aligner M13 §3.2 (TOUT SCANNER AG-03 : 4 s annoncés, 6 s en données).

### 16.12 Rejouer la passe M13

```bash
# GUT (unit puis integration : > 10 min ensemble)
godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gdir=res://tests/unit/ -gprefix=test_ -gsuffix=.gd \
    -gpre_run_script=res://tests/helpers/gut_pre_run.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gdir=res://tests/integration/ -gprefix=test_ -gsuffix=.gd \
    -gpre_run_script=res://tests/helpers/gut_pre_run.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_qa_m13.gd \
    -gpre_run_script=res://tests/helpers/gut_pre_run.gd -gexit
# Jour réel joué par l'oracle (souris) ; variantes
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
    --qa-node=res://tests/qa_drivers/qa_m13_booth.gd --seed=3 --day=4 [--qa-liars=skip] [--qa-pad-chip]
#   --day=8 --qa-unwarranted=2 [--qa-cancel-unwarranted] ; --day=19 --qa-no-search (FOUILLE OMISE) ;
#   --day=19 --flags=upg_ag01,upg_ag03 ; --seed=43 --day=19 (QA-064) ; --seed=14 --day=8 (QA-066) ; --seed=12 --day=25 (QA-063)
# Balayages hors scène
godot --headless --script res://tests/qa_drivers/qa_m13_scan.gd -- --histories=50 --seeds=1      # ≈ 7 min
godot --headless --script res://tests/qa_drivers/qa_m13_lines.gd -- --groups=400
godot --headless --script res://tools/qa_statements_audit.gd
godot --headless --script res://tests/qa_drivers/qa_m13_events_find.gd
# Sauvegardes 0.12 reprises, campagnes complètes (tronçons de 9 min repris sur slot_1/current.json)
XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-load=$PWD/tests/fixtures/qa_save_v6_012_j07.json --qa-profile=default --qa-speed=10 --qa-reload
X=$(mktemp -d); XDG_DATA_HOME=$X timeout 560 godot --headless --script res://tools/qa_boot.gd -- --autoplay \
    --qa-seed=7 --qa-profile=drift --qa-credits=3000 --qa-story --qa-speed=10 --qa-reload
# Captures (xvfb, OpenGL 3)
XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1280x800 --qa-wait=22 \
    --qa-out=/tmp/j.png --day=13 --seed=3 --screen=shift --m13=journal --qa-set=text_scale:1.5
#   --m13=search|unwarranted|contraband (--day=8 --seed=3), --qa-pad, --qa-set=color_vision:N, --reduce-motion ;
#   --day=8 --m13-help --qa-close-briefing ; --screen=evening --shop=ag0N (--day=6|11)
# Équilibrage, données, exports
godot --headless --script res://tools/balance_sim.gd -- --m13=compare --upgrades=smart --profiles=0.8 --presets=default --seeds=100 --seed=1
godot --headless --script res://tools/gen_stats.gd -- --campaigns=40 --seed=1
godot --headless --script res://tools/build_data.gd && git status --short data/      # aucun fichier modifié
bash tools/export_all.sh linux && bash tools/smoke_export.sh
```
