# LOCALIZATION.md — Localisation de CLEARANCE (FR → EN)

> Propriétaire : **Scénariste** (lot B de M15). Décisions D-213 (FR source + EN dans un fichier séparé, mêmes clés) et D-214 (documents en jeu traduits, dates `JJ.MM.AAAA`, pseudo-localisation `en-XA`). Contrat : `docs/M15.md`.

## 1. Fichiers

| Fichier | Rôle | Propriétaire |
|---|---|---|
| `data/i18n/fr.csv` | **Source**. En-tête `keys,fr`. Gelé pendant M15 (coquilles → Orchestrateur). | Scénariste / Orchestrateur |
| `data/i18n/en.csv` | Traduction anglaise. En-tête `keys,en`, **mêmes clés, même ordre** que `fr.csv`. | Scénariste (lot B) |
| `data/i18n/*.translation` | Ressources importées par Godot (`godot --headless --import`). Ne jamais éditer à la main. | — |
| `tests/unit/test_localization_en.gd` | Contrôles automatiques de `en.csv` (§7). | QA / Scénariste |

L'import Godot (`csv_translation`) utilise `unescape_translations=true` : un retour à la ligne s'écrit `\n` littéral dans le CSV, jamais un vrai saut de ligne. Le CSV est écrit en UTF-8, virgule séparatrice, guillemets doublés (`""`) dans un champ entre guillemets.

## 2. Glossaire FR → EN

Un terme du glossaire se traduit **toujours** de la même façon (UI, dialogues, Rulebook, fins).

### Le poste et l'inspection

| Français | Anglais | Note |
|---|---|---|
| guichet (Guichet 04) | booth (Booth 04) | « la vitre » des passagers = *the window* / *the glass* |
| Hall des Guichets | Booth Hall | « le Hall » = *the Hall* |
| vitre (personnel de vitre) | window, glass (glass staff) | |
| plan de travail | desk | |
| Mode Inspection | Inspection Mode | |
| discordance / concordant | discrepancy / match | « Discordance » est un mot de la novlangue, garder *discrepancy* partout |
| épingler une discordance | pin a discrepancy | |
| interroger | interrogate | |
| tampon APPROUVÉ / REFUSÉ / DÉTENTION | stamp APPROVED / DENIED / DETAINED | verbes : *approve / deny / detain* |
| mise en attente, mettre en attente | holding, place in holding | euphémisme du Consortium pour la détention |
| refus / refoulé | denial / turned away | |
| avis d'infraction, citation, avertissement, amende | notice of infraction, citation, warning, fine | « retenue sur salaire » = *docked from pay* |
| Rulebook | Rulebook | non traduit (déjà anglais) |
| onglet | tab | |
| directive (Directive n° 04) | directive (Directive No. 04) | « Délégation n° » = *Delegation No.* |
| bulletin quotidien | daily bulletin | « Brève » = *In brief* |
| Main courante | Logbook | |
| Répondant | Sponsor | « se porter répondant » = *stand sponsor / vouch for* |
| Convocation (de l'Enquête) | Summons | pluriel *summonses* |
| Déposition | Deposition | |
| Enquête / enquêteur / greffe | Inquiry / investigator / registry | |
| Arbitre, Arbitrage de Continuité | Arbiter, Continuity Arbitration | |
| Révocations, réintégration | Revocations, reinstatement | |
| Prorogation de Continuité | Continuity Extension | |
| portique (fouille) | scanner arch | « fouille sur motif » = *search on grounds* ; « motif » de fouille = *grounds* |
| Contrebande | Contraband | |
| Économat (du Hall) | (Hall) Commissary | |
| hygiaphone | speech grille | |
| borne (ACV-3) | kiosk | |
| Garde de nuit (mode) | Night Watch | « graine » = *seed*, « palier » = *tier*, « relève » = *relief* |
| Dossier de l'agent | Officer's File | « dossiers » (personnes) = *case files* |
| Mode Récit / Dur | Story / Hard | |
| soirée, foyer | evening, household | |

### Monde

| Français | Anglais |
|---|---|
| le Consortium, le Directoire | the Consortium, the Directorate |
| Bureau de Continuité | Continuity Bureau |
| Autorité de Transit | Transit Authority |
| Garde de Continuité | Continuity Guard |
| Commission de Rééquilibrage, Rééquilibrage | Rebalancing Commission, rebalancing |
| Conseil de l'air, Charte de l'air | Air Council, Air Charter |
| Clinique Orbitale Meridian | Meridian Orbital Clinic |
| Continuité | Continuity |
| ressortissant(s) | national(s) ; *non-residents* dans les règles (« Ressortissants (sauf Nés-Halcyon) ») |
| quota respiratoire | breathing quota |
| couvre-feu respiratoire | respiratory curfew |
| réaffectation, réaffecté·e | reassignment, reassigned |
| contributeur | contributor |
| souffle (argot pour ₵) | breath |
| Anneaux, Anneau B | the Rings, Ring B |
| la Soute | the Hold |
| quai 2 | dock 2 |
| Bloc Pétrel, Bloc Cormoran | Petrel Block, Cormorant Block |
| Lucioles (*lumika*) | Fireflies |
| Veilleurs / Brûlants | Watchers / Burners |
| Nés-Halcyon | Halcyon-Born |
| Gravitaires, « le Puits » (la Terre) | Downwellers (adj. *Downwell*), "the Well" |
| Puits 9, Puits 14 (mines de Tycho) | Shaft 9, Shaft 14 (distinct de *the Well*) |
| Ceinturiers, la Ceinture | Belters, the Belt |
| Tharsiens | Tharsians |
| Dérivants, en dérive | Drifters, adrift |
| Fièvre grise | Grey Fever |
| Guerre du Sel | Salt War |
| Incident Albédo | Albedo Incident |
| Laissez-passer de dérive | Drift Pass |
| Registre des cargos | Freighter Register |
| Attestation d'asile | Asylum Certificate |
| Dérogation d'implant militaire | Military Implant Waiver |
| Contrat de travail | Work Contract |
| Carte d'identité / Permis d'entrée / Certificat bio-scan | ID Card / Entry Permit / Bio-scan Certificate |
| SAIN / QUARANTAINE / EXAMEN REQUIS | FIT / QUARANTINE / REVIEW REQUIRED |
| « Gloire au Consortium. » | "Glory to the Consortium." |
| Phrase de passe « Il pleut, même ici. » / « La pluie ne tombe que vers le bas. » | "It rains, even here." / "Rain only falls downward." |
| le Pont (fin F10), la Vanne | the Bridge, the Valve |

## 3. Ce qui ne se traduit pas

- **Noms propres** : personnages (Okonkwo, Mira Vasquez-Orlov, Ren Kerr…), lieux (Halcyon Gate, Tycho, Tharsis), vaisseaux (Long-Ruban, Basse-Marée, Sillage), navette Transit-7. Exonymes anglais usuels admis : *Earth*, *Ceres* (sans accent).
- **Le Tessar** : tout segment entre chevrons `‹…›` est recopié à l'identique, ponctuation et espaces compris (`‹Kumo ri sava sa ?›`). La traduction anglaise suit hors chevrons, comme en français.
- **Codes** : N° ID (`HG-4471-K2Q9`), MRZ, numéros de documents, codes employeurs (`KA`, `CT-KA`), classes (`C-3`), implants (`MIL-9`), formulaires (`27-B/2`), convocations (`ENQ-0004`), numéros de série internes (`G04-J%02d-%02d`, tampon `CONSORTIUM · G04 · J%02d`), préfixe de graine `NUIT-`.
- **Sigles de règles** : `R01`, `R32`… restent tels quels.
- **Noms d'employeurs** (`rb_emp_*`, `issuer_dispensaire_tycho`, `val_issuer_dt`) : ce sont les **valeurs** écrites sur les documents (données, non traduites) ; le Rulebook doit les reproduire à l'identique pour que le joueur puisse les comparer (`Valcourt-Hsu Logistique`, `Bureau de Continuité`, `Dispensaire de Tycho`…). La mention « SANS EMPLOYEUR » n'est pas un nom : traduite à l'affichage (`val_no_employer`, *NO EMPLOYER*).
- **Secteurs d'origine** (lot U) : données en français, **traduits** des deux côtés — champ « Zone » de l'Attestation d'asile par `faction_<id>_sector_<n>`, onglet Origines par `faction_<id>_sectors`. La ligne du Rulebook doit être **exactement** les secteurs joints par « · », dans le même ordre (testé).
- **Dates et heures** : format neutre `JJ.MM.AAAA` et `HH:MM` (24 h). Dans la prose, « le 22 mars » devient *22 March* (style britannique, sans ordinal).

## 4. Guide de style

- **Anglais britannique** (*colour, neighbour, recognise, programme, cancelled*) ; guillemets droits doubles `"…"` à la place des « … » ; points de suspension `…` (un caractère).
- **Montants et pourcentages** (lot U) : en anglais, le symbole précède le nombre, sans espace — `₵25`, `+₵10`, `(₵0)`, `₵%d` — comme l'interface (`Localization.credits`) ; pourcentage collé : `62%`, `Compliance %d%%`. Le français garde `25 ₵` et `62 %`.
- **Guillemets de l'interface** (lot U) : jamais dans le code ; clés `ui_quoted` (`« %s »` / `"%s"`) et `ui_speaker_quoted` (`%s : « %s »` / `%s: "%s"`).
- **UI** : sobre, impératif court, MAJUSCULES quand le français en a. Viser une longueur ≤ au français (l'anglais est plus court : en profiter). Pluriels : clés `_one` séparées comme en FR.
- **Consortium** (bulletins, directives, Commission, Arbitre) : froid, administratif, passif et euphémismes (*placed in holding*, *rebalanced*, *reassigned*), jamais de contraction.
- **Lucioles** : phrases courtes, cryptiques, sans signature sauf initiale.
- **Okonkwo** : paternel, las, familier ; tic « …comme on dit » = *"… as they say."* ; il tutoie l'agent·e (en anglais : registre familier, *colleague*).
- **Passagers** : accents rendus par la syntaxe (phrases courtes, inversions, omissions), jamais par une orthographe caricaturale. Les C-1/C-2 sont condescendants (*would you*, *do check*), les Tycho laconiques, les Ceinturiers rapides et ironiques, les Tharsiens raides.
- **Genre** : l'agent·e n'a pas de genre → *you*, *officer*. **Ilan** = *they/them* (singulier). **Noa** = *she*. Les variantes `_f` / `_m` françaises (`tag_nervous_f`) sont identiques en anglais quand le genre ne se marque pas.
- **Sous-titres** : ≤ 90 caractères par réplique (`sc*`, `line_*`, `bark_*`, `react_*`, `ans_*`, `okonkwo_j*`, `sato_j*`, `pa_*`) ; légendes de cinématiques `cin_*` ≤ 70 caractères.
- **Jeux de mots** : adapter plutôt que traduire (Lindgren classe « à la lettre P… pont » → *under B, "bygone", or "bridge"* ; « à la lettre T » des Témoins → *under W*).

## 5. Placeholders

Recopier **à l'identique, en même nombre et dans le même ordre** :

| Forme | Exemple | Remarque |
|---|---|---|
| `%s`, `%d`, `%02d`, `%.1f`, `%%` | `DAY %02d`, `Compliance %d %%` | formatage `%` de GDScript ; l'ordre des arguments est fixé par le code |
| `{motif}`, `{duree}`, `{duree_barree}`, `{employeur}`, `{hote}`, `{origine}`, `{provenance}`, `{doc}` | `{motif}, for {duree}.` | emplacements nommés (déclarations, questions) |
| `\n` | — | retour à la ligne littéral |
| BBCode `[b]…[/b]` | — | aucun dans le corpus actuel |

Un pourcentage littéral s'écrit `30%` (sans espace) ; il n'est jamais suivi d'une lettre de format directement (`100% on` serait lu comme `% o` par certains contrôles).

## 6. Déclarations composées (M13)

Les réponses orales sont **composées** : un cadre (`line_stmt_frame_*`, `line_stmt_stay_*`, `line_stmt_origin_*`) reçoit des fragments (`stmt_*`). `Statement.apply_case` met le **premier mot d'un fragment** en majuscule en début de phrase et en **minuscule** ailleurs (« …, for two weeks. »). Conséquences pour l'anglais :

- **Aucun fragment ne commence par « I »** (il deviendrait « i » au milieu d'une phrase) : *Here to work*, *Going home*, *From Tycho*, *Came in on the Transit-7*, *Coming from %s*.
- Fragments de durée sans préposition (*Two weeks*, *A few days*) : la préposition est dans le cadre (*for {duree}*). Les durées vagues (*Who knows how long*, *Depends on the work*) ne vont jamais dans les cadres `vague_unfit_frames`.
- Employeur : `at %s` ; l'article français détaché par le générateur (« le Bureau ») devient *at the %s*.
- Personne visitée : *my sister, %s* ; ami·e garant·e : *with %s, who vouches for me*.

**Besoins de code connus** (lot A/U, non traités par le lot B) :
1. `StatementTablesDef.provenance_places` contient des **chaînes françaises brutes** (`"la Terre"`, `"l'Anneau B"`, `"Cérès"`) passées en argument de `stmt_prov_place` : en anglais on obtient *Coming from la Terre*. Il faut y mettre les clés `stmt_place_*` (déjà traduites : *Earth*, *Ring B*, *Ceres*, *dock 5*) et les traduire avant formatage (même chose pour `origin_places` dans `_provenance_is_origin`, comparé après normalisation).
2. `text_lengths` (sélection des cadres ≤ 90) est calculé sur le **français** ; le test anglais vérifie qu'une réplique qui tient en français tient aussi en anglais.
3. `employer_article_keys` (`"le "`, `"les "`) et les alias (`"le Bureau"`) sont des données françaises : l'anglais les absorbe via *at the %s* ; aucun changement nécessaire tant que ces alias restent en français.

## 7. Contrôles automatiques

`tests/unit/test_localization_en.gd` (GUT) vérifie : en-tête `keys,en` et deux colonnes ; mêmes clés, même ordre, aucune valeur vide ; aucun mot-outil français résiduel (hors noms propres et Tessar) ; placeholders identiques ; Tessar identique ; `cin_*` ≤ 70 ; répliques ≤ 90 ; ressource `en.en.translation` importée et égale au CSV ; déclarations composées (plusieurs milliers de combinaisons) sans minuscule en début de phrase ni « i » minuscule ni mot doublé, et ≤ 90 caractères quand le français tient.

## 8. Ajouter ou modifier une clé

1. Ajouter la clé dans `fr.csv` (source), à l'endroit logique.
2. Ajouter **la même clé au même rang** dans `en.csv`, traduite selon ce guide (un brouillon anglais vaut mieux qu'une clé manquante : le test échoue sinon).
3. Respecter placeholders, Tessar, longueurs ; ajouter un terme nouveau au glossaire (§2).
4. Réimporter : `godot --headless --import` (régénère `*.translation`).
5. Lancer les tests : `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_localization_en.gd -gexit` (et le test M15 du lot A).
6. Vérifier en jeu en anglais (Options › Langue) et en pseudo-localisation `en-XA` pour les débordements.
