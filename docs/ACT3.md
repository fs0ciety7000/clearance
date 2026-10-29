# ACT3.md — Acte III « Témoins » (J21 → J30)

> Auteur : **Scénariste** (casquettes Game Designer et Lore Master). Statut : **v0.1 — proposition**, à valider par l'Orchestrateur puis le client. Date : 2026-10-28. Aucun code, aucune donnée modifiés.
> Sources faisant foi : `LORE.md`, `GDD.md` (§5, §6, §13), `docs/NARRATIVE.md` (§1, §2, §4, §7), `docs/ACT2.md` (structure, flags, SC-23 → SC-50, fins F1–F9), `DECISIONS.md` (D-005, D-020, D-033, D-053, D-057, D-060, D-062, D-067, D-076 → D-085), `docs/QA.md` §12 (difficulté observée, plan de travail à 4–5 documents), `CHANGELOG.md` (0.9.0), `tools/build_data.gd` et `tools/build_data_act2.gd` (formats `ScriptedCaseDef`, `ConditionalKey`, `EveningEventDef`, `WantedNoticeDef`, `EconomyDef`), `data/i18n/fr.csv`.
>
> Conventions (identiques à NARRATIVE §7 et ACT2) : **J** = jour ; **@n** = `at_index` 0-based ; Tessar entre chevrons simples ‹…› (lexique LORE §10 + ‹Tu vanu.› d'ACT2, **aucun mot nouveau**) ; didascalies entre crochets, jamais porteuses de vérité ; ≤ 90 caractères par réplique sous-titrée, ≤ 220 par message de briefing/soirée ; point médian pour l'agent·e et Ilan, jamais de pronom genré pour Ilan ; deltas `{flag: delta}` (D-045 : delta 0 = drapeau booléen). Le verdict attendu reste **calculé par le moteur** (D-005) : la colonne « Attendu » est l'intention, à vérifier par QA. 🟡 = demande un développement (récapitulé en §8).

---

## 0. Résumé exécutif

- **Le J20 devient un pivot** (« la Nuit du 1ᵉʳ avril »), sur le modèle du J10 (D-076) : il gagne une **soirée** qui s'ouvre sur une **carte de fin d'acte** (le titre de la fin de l'Acte II que le joueur a obtenue, en deux lignes), puis la partie continue. Restent terminales au J20 : **F1** (Revue du J17), **F2/F3** (anticipées) et **F6 au choix** (« Embarquer » sur le Basse-Marée). **F4, F5, F8, F9, F7** deviennent cinq **climats d'entrée** de l'Acte III.
- **Acte III = 10 jours (lun. 02.04 → mer. 11.04.2187)**. Le Directoire dissout la Commission et nomme une **Arbitre de Continuité**, **Philippa Montclair** (la conseillère aux cinquante crédits du J10, SC-21), chargée d'une **Enquête** sur les nuits du 22.03 et du 01.04 — et, en marge, sur Albédo. À Tycho, Kessler-Ashe ferme les puits automatisés : **grève**, puis air coupé. Le 11 avril, la dernière Transit-7 de Tycho s'arrime.
- **Le plan de travail s'allège au lieu de s'alourdir** (D-085) : la délégation **s'inverse** (« Retour aux quais » : ticket de file retiré au J21, **bio-scan retiré au J23**) ; au plus **4 documents** dès le J23, 2–3 en moyenne. La difficulté passe par la **lecture** : prorogations, réintégrations, répondants, convocations.
- **2 mécaniques nouvelles** : **M1 « Retour aux quais »** (documents et règles retirés) ; **M2 « Répondants »** (un·e Né·e-Halcyon passé·e plus tôt dans la journée se porte garant·e d'un ressortissant : vos verdicts du matin décident de ceux de l'après-midi). **1 extension** : l'**Enquête** (questions du soir, puis **Déposition** au J29, sur le modèle de la Revue).
- **6 règles (R32 → R37)**, **3 anomalies** en fin d'enum (`SPONSOR_MISMATCH` 21, `FORGED_SUMMONS` 22, `SUSPENDED_CONTRACT` 23), **2 champs** sur le permis existant (Répondant, Convocation), **2 onglets** (Main courante, Convocations). Aucun document nouveau.
- **32 cas scénarisés (SC-51 → SC-82)** : 11 humour, 11 drames, 10 petites humanités ; **25 retours** des actes I–II ; 21 cas dépendant de flags ou à répliques conditionnelles ; 5 **chaînes de répondants**. Un seul récurrent nouveau : la maîtresse d'école **Adaeze Okafor**. Montclair, Sato (greffier), Lindgren (archiviste de l'Enquête), Ravel (enquêteur, voix du soir) et Yara Moreno-Lind (comité de grève de Tycho) portent l'acte.
- **10 fins au J30** : F1–F9 adaptées + **F10 « Le Pont »** (le Guichet 04 tient la porte de Tycho ouverte, par la règle des répondants). Figure finale : **Dora** si elle est partie à Tycho au J18, sinon **Mira**. Albédo reste **ambigu** (D-053, D-078) : l'acte l'approche par des témoignages contradictoires, sans le trancher.
- **Difficulté** : « dure » (D-060) mais pas un mur : J21 de respiration, rappel des salaires imputés, 3ᵉ avertissement gratuit les jours de règle nouvelle, avance de l'Arbitre, caisse des vitres ; cibles par profil en §6. Sauvegarde **v5** (§8.6).

---

## 1. Pitch et structure

### 1.1 Pitch de l'Acte III

1. Le 1ᵉʳ avril, quelque chose s'est passé au recycleur central : une vanne, des vitres éteintes, des noms lus, ou rien du tout. Le Directoire n'aime pas ne pas savoir.
2. Il dissout la Commission et nomme une **Arbitre de Continuité**. Son Enquête doit établir qui a ouvert, qui a éteint, qui a lu — et, puisqu'on y est, qui a fait sauter le quai 3 en 2179.
3. Au Guichet 04, les directives se défont une à une : les quais reprennent leurs contrôles, les papiers périmés sont prorogés, les révoqués réintégrés. Chaque passager devient un témoin, chaque citoyen un répondant possible.
4. À Tycho, Kessler-Ashe ferme les puits automatisés. Les mineurs se mettent en grève, comme en 2151. Le Directoire parle de « rééquilibrer Tycho ».
5. Mercredi 11 avril, la dernière Transit-7 de Tycho s'arrime. Il y a des familles dedans. Et quelqu'un qui a déjà vécu ça une fois.

### 1.2 Ce que devient le J20 : la Nuit du 1ᵉʳ avril

Aujourd'hui (v0.9.0), le dernier cas du J20 (ou l'annonce de grève) enchaîne sur le bilan puis l'épilogue (D-076). Proposition : **le shift du J20 reste identique** (SC-48 → SC-50, grève à 15:00), mais il est suivi d'une **soirée pivot** à panneaux successifs (comme le J10) :

| Ordre | Panneau | Condition | Effet |
|---|---|---|---|
| 0 | **Carte de fin d'acte** 🟡 (plein écran, 3 s, passable) | si la partie n'est pas terminée par F1/F2/F3 | affiche « FIN DE L'ACTE II · » + le titre de la fin qu'aurait donnée l'évaluation du J20 (`end2_fN_title`) et 2 lignes d'épilogue (§5.4) ; pose le **climat** (§1.3) |
| 1 | **La Nuit du 1ᵉʳ avril** (lettre, 6 variantes) | selon le climat | `climate_*` (exclusifs) ; `vanne2_brulants` si F5 Brûlants |
| 2 | Recalcul de la suspicion (silencieux) | toujours | `suspicion := ⌊suspicion / 2⌋` (+1 si `purge_demoted`) — l'Arbitre « rouvre les dossiers », comme au J10 |
| 3 | Double jeu (lettre de l'Arbitre) | `lucioles_trust ≥ 7` et `loyalty ≥ 7` (ancienne F1 du J20) | **ne termine plus la partie** : `enquete_cible` (+3 au score de la Déposition, J29) |
| 4 | Le sort de la figure finale (lettre) | SC-50 traitée | Ilan détenu·e → **MIS·E EN ATTENTE** (amnistie possible au J21) ; Ilan passé·e et climat Vanne → **DANS LA SOUTE** jusqu'au J25 (« Conseil des recycleurs ») ; Ilan passé·e sans Vanne ou refusé·e → rentre à l'aube ; Mira détenue → Anneau B (`mira_detained2`) |
| 5 | **Un bureau à l'Anneau D** (choix) | climat Promu·e | Déménager (−20 ₵, loyer 30 ₵, chauffage et rations inclus, `moved_ring_d`) / Rester au Bloc Pétrel ★ |
| 6 | **Quai 6, lundi 05:00** (choix) | `drift2_passes_bought` | **Embarquer → F6 immédiate** (épilogue `end2_f6_*` existant, cohérent : lundi 05:00) ; **Rester** → Wren rend 30 ₵, `drift2_stayed`. Si `final2_detained` : lettre seule, « Pas toi. », 30 ₵ rendus |
| 7 | Dépenses du soir | toujours | barème J20 (§6) |
| — | Interstitiel « CHAPITRE III · TÉMOINS » | si la partie continue | sauvegarde automatique |

**Fins qui restent possibles au J20** : **F1** (Revue du J17, inchangée), **F2** et **F3** (anticipées), **F6** (choix explicite du panneau 6). Le double jeu (ancienne F1 du J20) devient une cible de l'Enquête, comme au J10.

**Justification.**
- Même grammaire qu'au J10 (D-076) : une seule campagne, des choix du J20 qui **changent le monde** de l'Acte III au lieu d'être résumés.
- La **carte de fin d'acte** garde la récompense de l'Acte II : le joueur voit « LES VITRES ÉTEINTES » ou « LE REGISTRE » s'afficher, comme une fin de chapitre. C'est la réponse au risque principal du pivot (« j'ai survécu jusqu'au J20 et on me retire ma fin »).
- F6 reste la seule fin **achetée** : la retirer trahirait le choix du J19. « Rester » coûte 30 ₵ (60 payés, 30 rendus).
- La division de la suspicion évite que la Revue du J17 et la Déposition du J29 jugent deux fois les mêmes enveloppes.

### 1.3 Les cinq climats d'entrée

Le climat est l'ancienne fin du J20 (même évaluation, mêmes priorités), posé au panneau 0. Un seul climat est actif ; les autres drapeaux de l'Acte II restent lus pour les répliques.

| Climat (drapeau) | Ancienne fin J20 | Monde de l'Acte III | Effets système |
|---|---|---|---|
| **Vanne** (`climate_vanne`) | F5 Veilleurs (`vanne2_brulants` : F5 Brûlants) | Les Veilleurs tiennent le recycleur central ; le Directoire négocie par l'Arbitre. Brûlants : quai 1 détruit, la Garde partout, l'Enquête cherche des coupables | quota **suspendu tout l'acte** ; rations à **1 ₵** (« air de la Vanne ») ; Brûlants : `suspicion +1`, avis de recherche quotidien +1 entrée |
| **Vitres** (`climate_vitres`) | F9 | Le quota est « suspendu pour révision » ; les guichets ont un comité ; le Directoire menace d'**automatiser** le Hall (bornes ACV-3, J26) | `solidarite +1` ; quota rétabli au J27 comme ailleurs |
| **Registre** (`climate_registre`) | F8 | Les 212 noms ont été lus ; Tycho s'est soulevée **dès le J21** (grève avancée de deux jours) ; le Bureau « classe » le registre | `registre` conservé ; grève de Tycho au J21 au lieu du J23 (briefings seulement) |
| **Promu·e** (`climate_promu`) | F4 | L'agent·e est **C-2 à l'essai** : « chef·fe de guichet », toujours à la vitre (le Hall manque de bras) ; appartement à l'Anneau D proposé | prime **+10 ₵/soir** ; oxygène de Dora offert (inchangé) ; option de déménagement (§1.2) |
| **Statu quo** (`climate_statu_quo`) | F7 | Rien ne s'est passé, dit le bulletin. Tout le monde sait que si | aucun |

**Pourquoi cinq climats et non cinq actes.** Le tronc (règles, cas, Enquête, Tycho) est **commun** ; un climat change des lettres, des répliques (`ConditionalKey`, 🟡 condition sur le climat) et trois paramètres (quota, rations, prime). Coût : ~40 clés de variantes, pas 5 × 10 jours.

### 1.4 Fins au J30 (9 adaptées + 1 nouvelle)

Définitions : `alive`, `present` (ACT2 §1.3 ; `ABSENT · À TYCHO` compte comme vivant, pas comme présent) ; `compliance` cumulée J1–J30 ; `credits` = solde après le bilan du J30 ; **`pont`** 🟡 = nombre de passagers `TYC` **admis correctement** au J30 (verdict APPROUVÉ jugé correct par le moteur : répondant valide ou convocation authentique) ; **`final3_*`** = verdict de la figure finale (SC-82). Le J30 n'a **pas de soirée** (comme J20 en v0.9) : l'évaluation suit le bilan.

| # | Fin | Condition exacte | Moment |
|---|---|---|---|
| **F1** | Arrestation | Déposition du J29 : score ≥ 7 (§5.3, J29) ; **ou** J30 : `lucioles_trust ≥ 10` **et** `loyalty ≥ 10` (double jeu) | J29 (anticipée) / J30 |
| **F3** | Famille perdue | `alive == 0` | anticipée, chaque soir |
| **F2** | Réaffectation | inchangée (D-047) ; l'avance de l'Arbitre non remboursée au J27 compte comme un loyer impayé | anticipée, chaque soir |
| **F5** | Rendre l'air | `final3_passed` **et** `lucioles_trust ≥ 10`. Variante **Charte** si `climate_vanne` (le Directoire signe la Charte de l'air) ; **Seconde Vanne** sinon ; **Brûlants** si `vanne2_brulants` **ou** `sc71_kasimir_passed` (et non `sc71_kasimir_detained`) | J30 |
| **F9** | Les vitres éteintes | `strike2_joined` (vote du J29, visible si `solidarite ≥ 5`) **et** `solidarite ≥ 5` | J30 |
| **F10** 🆕 | Le Pont | `pont ≥ 6` **et non** `final3_detained` | J30 |
| **F8** | Le Registre (« Les Témoins ») | `deposition_truth` **et** `verite ≥ 3` **et** `registre ≥ 5` | J30 |
| **F6** | Partir (lundi 05:00 au J20 ; jeudi 12.04 au J30) | choix « Embarquer » du J20 — ou `exit3_bought` **et** `present ≥ 2` **et** `credits ≥ 30` **et non** `final3_detained`. Variante **Tycho** (`exit3_tycho`) ou **Dérive** (`exit3_drift`) | J20 / J30 |
| **F4** | Gloire au Consortium | `final3_detained` **et** `loyalty ≥ 10` **et** `compliance ≥ 0,85` **et** `alive ≥ 2` **et non** `promotion_revoked` **et non** `strike2_joined` | J30 |
| **F7** | Le guichet rouvre jeudi | aucune des précédentes | J30 |

**Priorité** : **F1 > F3 > F2 > F5 > F9 > F10 > F8 > F6 > F4 > F7**.
- F5 et F9 restent des événements collectifs qui englobent les autres (lignes conditionnelles « le pont », « les témoins »).
- **F10 avant F8** : le Pont est un acte qui a eu lieu **ce jour-là, à votre vitre**, et qui sauve des vies ; le registre et la déposition apparaissent en lignes conditionnelles de F10.
- F8 avant F6/F4 : la déposition publique empêche la promotion, et la fuite ne la fait pas oublier.
- Seuils à 10 (contre 7 au J20) : les jauges cumulent sur 30 jours ; l'Acte III offre ≈ +7 de `lucioles_trust` et ≈ +12 de `loyalty` (§5). **À valider par simulation** (§6.4).

**Pourquoi une seule fin nouvelle.** L'Acte II a donné la vérité (F8) et le collectif (F9). L'Acte III ajoute une seule réponse qui manquait : **l'hospitalité**, à l'échelle du guichet. F10 est la récompense directe de M2 (répondants) et la conclusion de l'arc Tycho (« le Puits 9 ne recommencera pas ici »). Une fin « réforme » (l'Enquête impose une Charte révisée) a été écartée : elle doublait F8 et donnait raison à l'Arbitre. Une fin « retour à Tycho » devient la **variante Tycho de F6** au lieu d'une fin de plus.

**Albédo (D-053, D-078).** Aucune fin ne tranche. F8 publie un rapport d'Enquête qui « retient plusieurs versions comme exactes » ; F5 Brûlants voit Kasimir avouer Albédo « à trois heures différentes ». Règle d'écriture inchangée : **tout indice est contredit le même jour ou par la même source** (§3.6).

### 1.5 Alternative : J20 conserve ses fins, Acte III « après la fin »

**Proposition B.** Au J20, l'évaluation et l'épilogue restent **tels quels** (D-078). Sur l'écran de fin de F4, F5, F7, F8 ou F9, un bouton **« CONTINUER — ACTE III »** 🟡 relance la campagne au J21 depuis une sauvegarde « post-fin » ; F1, F2, F3 et F6 n'offrent pas de suite.

| Critère | **A — Pivot obligatoire** (§1.2) | **B — Acte III optionnel après la fin** |
|---|---|---|
| Récompense au J20 | carte de fin d'acte (titre + 2 lignes) | épilogue complet de l'Acte II |
| Cohérence des épilogues | les épilogues `end2_*` de F4/F5/F7/F8/F9 ne sont plus lus au J20 ; rien à corriger | **à réécrire** : F5 « Vous rendez votre tampon », F8 « On vous mute aux quais », F4 « Le vôtre devient un bureau, avec une porte » contredisent un retour à la vitre lundi |
| Fins à maintenir | 10 fins au J30 + 4 terminales au J20 (existantes) | 9 fins au J20 **+** 10 fins au J30 (deux jeux pour les mêmes titres) |
| Joueur à 65 % (QA §12.8) | 30 jours avant une « vraie » fin s'il survit | une fin au J20, l'Acte III en bonus : moins de frustration |
| Poids des choix du J20 | ils **sont** le monde de l'Acte III | ils sont **conclus** puis rouverts : la fin du J20 perd sa valeur de vérité |
| Sauvegarde | v5, un seul fil (D-041) | sauvegarde conservée **après** une fin (contraire à D-041 : « toute fin efface la sauvegarde ») |
| Coût | soirée pivot + carte + 5 lettres de climat | bouton + sauvegarde post-fin + réécriture de 5 épilogues + raccords |
| Démo / build public | la 0.9 « finit » au J20 tant que l'Acte III n'est pas livré (`last_day = 20`) | idem |

**Recommandation : A**, avec la carte de fin d'acte. Elle prolonge D-076, garde une sauvegarde unique (D-041) et fait de l'Acte III la conséquence du J20. B est préférable seulement si le client veut que la version 0.9 reste **la** campagne et que l'Acte III soit vendu comme « épilogue jouable » ; dans ce cas, prévoir la réécriture des cinq épilogues avant l'implémentation (question 1, §9).

---

## 2. Progression J21 → J30

### 2.1 Table de synthèse

Diégèse : la **délégation s'inverse** (« Retour aux quais ») ; c'est l'**Arbitrage de Continuité** qui signe les directives. Respirations : **J21** (aucune anomalie nouvelle, file courte), **J23** (un document de moins), **J27** et **J29** (aucune règle nouvelle). Jours de règle nouvelle : J21, J22, J24, J25, J26, J28 (3ᵉ avertissement gratuit, §6.1).

| Jour | Date | Directive / nouvelles règles | Documents / champs | Nouvelles anomalies (fin d'enum, D-033) | `passenger_count` | `duration_sec` | `anomaly_count_weights` [0,1,2,3] | Événement narratif |
|---|---|---|---|---|---|---|---|---|
| **J21** | lun. 02.04.2187 | **R32** Prorogation de Continuité *(respiration)* ; quota **suspendu** ; R29 couvre-feu **retiré** | **Ticket de file retiré** (M1) | — (réutilise `EXPIRED_DOCUMENT`, fenêtre de prorogation) | 15 | 720 | [0.48, 0.37, 0.13, 0.02] | L'Arbitre prend le Hall ; amnistie des « mis en attente » du 01.04 contre témoignage ; rappel des salaires imputés |
| **J22** | mar. 03.04 | **R33** Réintégrations ; quai 6 fermé aux cargos | onglet Révocations : colonne **RÉINTÉGRÉ·E LE** | — (`REVOKED_ID` reste) | 16 | 735 | [0.42, 0.38, 0.16, 0.04] | Sato réintégré, greffier ; 1ʳᵉ question de l'Enquête ; le dessin de Noa |
| **J23** | mer. 04.04 | — ; **bio-scan retiré** (R11–R14 → quais) *(respiration)* | **Bio-scan retiré** (M1) : 2–4 documents | — (`WRONG_ISSUER`, `BIOSCAN_UNFIT` à 0) | 16 | 720 | [0.44, 0.37, 0.15, 0.04] | Noor sans bio-scan ; Beaumont révoquée ; **grève de Tycho** ; le poste d'Ilan |
| **J24** | jeu. 05.04 | **R34** Répondant (VISITE FAMILIALE des ressortissants) — M2 | champ **Répondant** du permis ; onglet **Main courante** | `SPONSOR_MISMATCH` (21) | 16 | 735 | [0.40, 0.38, 0.17, 0.05] | Margaux se porte répondante d'Amara ; Noa convoquée |
| **J25** | ven. 06.04 | **R35** Lock-out de Tycho (contrats `CT-KA` des `TYC` suspendus) | — (lit Code + Origine) | `SUSPENDED_CONTRACT` (23) | 17 | 750 | [0.40, 0.38, 0.17, 0.05] | **Rééquilibrage de Tycho** : air coupé ; Yara du comité de grève ; Contribution « pour Tycho » |
| **J26** | sam. 07.04 | **R36** Convocations de l'Enquête (exemptions, faux) | champ **Convocation** du permis ; onglet **Convocations** | `FORGED_SUMMONS` (22) | 17 | 765 | [0.38, 0.38, 0.19, 0.05] | Lev et les fausses convocations ; Hana témoin d'Albédo ; les Ren Kerr ; 2ᵉ question |
| **J27** | dim. 08.04 | — ; quota **rétabli à 4** (sauf climat Vanne) *(respiration)* | — | — | 17 | 750 | [0.42, 0.37, 0.16, 0.05] | **L'Arbitre au guichet** ; Kasimir avoue ; Wren, la Soute ; remboursement de l'avance |
| **J28** | lun. 09.04 | **R37** Fermeture de Tycho (`TYC` interdits sauf répondant ou convocation) | — | — (`BANNED_FACTION` re-pondéré, faction `TYC`) | 18 | 780 | [0.36, 0.38, 0.20, 0.06] | Elena et Joaquín ; Okonkwo, dernier passage ; Sato convoque l'agent·e ; 3ᵉ question |
| **J29** | mar. 10.04 | — ; quota → 3 ; **dernier jour de prorogation** *(respiration)* | — | — | 17 | 750 | [0.42, 0.38, 0.15, 0.05] | Les deux couvertures d'Albédo ; Mazur libéré ; la liste des grévistes ; **la Déposition** (F1 possible) ; vote de grève |
| **J30** | mer. 11.04 | — ; avis « visages seuls » ; Transit-7 à 14:00 | — | — | 18 | 780 | [0.36, 0.38, 0.20, 0.06] | **La dernière navette** : réseau de répondants, figure finale → épilogue |

Implicite (inchangé depuis l'Acte II) : `credit_per_correct = 5`, `penalty_per_error = 5`, `penalty_escalated = 10`, `detain_enabled = true`, `bribe_rate = 0.05`, `bribe_amounts = (20, 30)`, `visor_down_rate = 0.20`, `luciole_trust_on_breach = false`, `has_evening = true` de J20 à J29, `false` au J30. `free_citations_per_day` = **3** les jours de règle nouvelle (J21, J22, J24, J25, J26, J28), 2 sinon (§6.1). Avis de recherche (R22) chaque jour : 1 entrée générée (D-056) + entrées scénarisées (J21 la technicienne, J27 Kasimir si `sc47_kasimir_passed`, J30 la figure finale). Budget par cas ≈ 40 s (J21) → 37 s (J28/J30), et ≈ 4–5 s de lecture en moins par cas dès le J23 (bio-scan retiré).

**Pourquoi le plan de travail ne grossit plus.** D-085 fixe la limite de lisibilité à 4–5 documents ; QA §12.3 a montré le Deck à la peine à 5. À partir du J23, un passager porte au plus **carte + permis + contrat + attestation** (TER C-5 au motif TRAVAIL seulement), en pratique **2 à 3 documents**. Les deux nouveaux champs (Répondant, Convocation) sont des lignes **du permis existant**, présentes seulement quand elles s'appliquent.

### 2.2 `anomaly_weights` (poids relatifs, renormalisés par le générateur sur les types couverts)

| Type | J21 | J22 | J23 | J24 | J25 | J26 | J27 | J28 | J29 | J30 |
|---|---|---|---|---|---|---|---|---|---|---|
| `EXPIRED_DOCUMENT` | **.12** | .10 | .10 | .08 | .07 | .07 | .07 | .06 | .08 | .05 |
| `MISSING_DOCUMENT` | .05 | .05 | .06 | .05 | .05 | .04 | .05 | .04 | .05 | .04 |
| `PORTRAIT_MISMATCH` | .03 | .03 | .04 | .03 | .03 | .03 | .03 | .03 | .03 | .03 |
| `ID_MISMATCH` | .05 | .05 | .06 | .05 | .04 | .04 | .04 | .04 | .04 | .04 |
| `NAME_MISMATCH` | .05 | .05 | .06 | .05 | .04 | .04 | .04 | .04 | .04 | .04 |
| `ORIGIN_ID_MISMATCH` | .04 | .04 | .05 | .04 | .04 | .03 | .04 | .03 | .04 | .03 |
| `PURPOSE_MISMATCH` | .05 | .05 | .06 | .05 | .05 | .04 | .05 | .04 | .05 | .04 |
| `WRONG_ISSUER` | .04 | .04 | — | — | — | — | — | — | — | — |
| `BIOSCAN_UNFIT` | .04 | .04 | — | — | — | — | — | — | — | — |
| `UNDECLARED_IMPLANT` | .06 | .06 | .07 | .06 | .05 | .05 | .05 | .05 | .05 | .05 |
| `BANNED_IMPLANT` | .05 | .05 | .06 | .05 | .04 | .04 | .04 | .04 | .04 | .04 |
| `IMPOSTOR_LOOKALIKE` | .07 | .07 | .08 | .07 | .06 | .06 | .06 | .06 | .06 | .06 |
| `RELATIVE_DOCUMENTS` | .06 | .06 | .07 | .06 | .05 | .05 | .05 | .05 | .05 | .05 |
| `BANNED_FACTION` | .07 | .07 | .07 | .06 | .06 | .06 | .06 | **.16** | .10 | .13 |
| `INVALID_SEAL` | .06 | .06 | .06 | .05 | .05 | .05 | .05 | .05 | .05 | .04 |
| `MRZ_MISMATCH` | .06 | .06 | .06 | .05 | .05 | .05 | .05 | .04 | .05 | .04 |
| `WANTED_PERSON` | .06 | .06 | .06 | .05 | .05 | .05 | .06 | .05 | .05 | **.10** |
| `CONTRACT_MISMATCH` | .06 | .06 | .06 | .05 | .05 | .04 | .05 | .04 | .04 | .04 |
| `UNREGISTERED_VESSEL` | .03 | .03 | .03 | .03 | .03 | .03 | .03 | .02 | .03 | .02 |
| `OUTDATED_FIRMWARE` | .05 | .07 | .05 | .04 | .04 | .04 | .04 | .04 | .04 | .03 |
| `REVOKED_ID` | — | — | — | — | — | — | — | — | — | — |
| `SPONSOR_MISMATCH` 🆕 | — | — | — | **.18** | .10 | .08 | .08 | .08 | .08 | .09 |
| `FORGED_SUMMONS` 🆕 | — | — | — | — | — | **.15** | .08 | .06 | .06 | .06 |
| `SUSPENDED_CONTRACT` 🆕 | — | — | — | — | **.15** | .06 | .08 | .04 | .05 | .04 |

Règles d'injection ajoutées :
- `EXPIRED_DOCUMENT` (J21–J29) reçoit un paramètre `expiry_window` 🟡 : **`outside`** (expiré hors de la fenêtre 22.03–01.04 : vraie anomalie) ou jamais `inside` (un document expiré **dans** la fenêtre est un **bruit légitime**, tiré par `prorogation_noise_rate`, pas une anomalie). Au J30, la prorogation est échue : tout document prorogé est expiré.
- `REVOKED_ID` reste à 0 (entrées de `DayDef.revocations`, QA-026) ; au J22+, chaque entrée porte une date de réintégration ou non (`DayDef.reinstatements` 🟡) ; une entrée réintégrée est un **bruit légitime**.
- `SPONSOR_MISMATCH` : seulement sur un ressortissant au motif VISITE FAMILIALE ; trois variantes (`absent` : N° ID d'un·e Né·e-Halcyon jamais passé·e ; `later` : le répondant est placé **après** dans la file ; `ineligible` : répondant C-4/C-5 ou non `HAL`). Combinable avec 0–1 autre anomalie.
- `SUSPENDED_CONTRACT` : seulement sur un `TYC` au motif TRAVAIL ; le générateur ne produit plus de `TYC` + `CT-KA` + TRAVAIL valides après le J25.
- `FORGED_SUMMONS` : N° `ENQ-` absent de l'onglet Convocations, ou présent sous un autre nom ; jamais avec `WANTED_PERSON` (lisibilité).
- `BANNED_FACTION` au J28+ vise la faction `TYC` (R37) au lieu de `THR` ; R19 (THR) et R31 (TER) restent en vigueur.

### 2.3 Paramètres complémentaires

| Paramètre | J21 | J22 | J23 | J24 | J25 | J26 | J27 | J28 | J29 | J30 |
|---|---|---|---|---|---|---|---|---|---|---|
| `faction_weights` TYC/HAL/TER/CER/THR/DRV | .28/.18/.21/.14/.13/.06 | idem | idem | idem | **.32**/.17/.19/.13/.12/.07 | idem | idem | **.34**/.18/.19/.13/.11/.05 | idem | **.40**/.18/.16/.12/.10/.04 |
| `air_quota` 🟡 | suspendu | suspendu | suspendu | suspendu | suspendu | suspendu | 4 (suspendu si `climate_vanne`) | 4 | 3 | 3 |
| `legit_noise_rate` | .38 | .38 | .38 | .40 | .40 | .40 | .40 | .40 | .40 | .40 |
| `prorogation_noise_rate` 🟡 | .15 | .15 | .15 | .12 | .12 | .10 | .10 | .10 | .10 | — |
| `sponsor_rate` 🟡 (part des VISITE FAMILIALE avec répondant lié) | — | — | — | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| `summons_rate` 🟡 (part des passagers convoqués) | — | — | — | — | — | .12 | .10 | .12 | .10 | .10 |
| `luciole_rate` | .08 (.10 si `climate_vanne`) | idem | idem | idem | idem | idem | .06 | .08 | .08 | .10 |
| `purpose_weights` TYC (VISITE FAMILIALE) | défaut | défaut | défaut | défaut | **.40** | .40 | .40 | **.55** | .55 | **.60** |
| `free_citations_per_day` | **3** | **3** | 2 | **3** | **3** | **3** | 2 | **3** | 2 | 2 |

### 2.4 Nouvelles règles (R32 → R37) et règles retirées

| Id | Règle (texte Rulebook abrégé) | Sous-classe 🟡 | Jour | Catégorie / sévérité | Vérification en Mode Inspection |
|---|---|---|---|---|---|
| R32 `r_prorogation` | Documents expirés entre le 22.03 et le 01.04.2187 inclus : **prorogés jusqu'au 10.04 inclus** (carte, permis, contrat, attestation, dérogation). Firmware NX non concerné | `DocumentNotExpiredRule.grace_window` | J21 | DOCUMENTS / 2 | Expiration ↔ date du jour : le comparateur affiche **PROROGÉ** (concordant) dans la fenêtre, **EXPIRÉ** hors fenêtre |
| R33 `r_reinstated` | N° ID à l'onglet Révocations **avec** une date de réintégration ≤ aujourd'hui : valide. Sans date : refus (R30). Exclus de la réintégration : personnes impliquées dans les nuits du 22.03 et du 01.04 | `RevokedIdRule.reinstatements` | J22 | IDENTITY / 2 | N° ID (carte) ↔ onglet Révocations (colonne RÉINTÉGRÉ·E LE) |
| R34 `r_sponsor` | Ressortissants au motif VISITE FAMILIALE : **Répondant** obligatoire, Né·e-Halcyon de classe C-1 à C-3, **admis·e aujourd'hui à cette vitre** (onglet Main courante). Un agent ne se porte pas répondant à sa propre vitre | `SponsorRule` (contexte du shift) | J24 | DOCUMENTS / 2 | Répondant (permis) ↔ Main courante (N° ID, classe) |
| R35 `r_tycho_lockout` | Contrats Kessler-Ashe (`CT-KA`) de ressortissants de Tycho : **suspendus** (lock-out) → refus | `ContractSuspendedRule` (code × origine) | J25 | DOCUMENTS / 2 | Code (contrat) ↔ Origine (carte) ↔ R35 |
| R36 `r_summons` | **Convoqué·es** de l'Enquête (N° `ENQ-NNNN` inscrit à l'onglet Convocations, au nom du porteur) : exemptés du quota, des interdictions d'origine (R19, R31, R37), du lock-out (R35), des révocations (R30) et du répondant (R34). **Non** exemptés de l'avis de recherche (R22) ni des contrôles d'identité. Convocation fausse : refus | `SummonsRule` + exemptions déclarées par les autres règles | J26 | DOCUMENTS / 2 | Convocation (permis) ↔ onglet Convocations (N°, nom) |
| R37 `r_tycho_closed` | Ressortissants de Tycho (`TYC`) : entrée **interdite**, sauf VISITE FAMILIALE avec Répondant valide (R34) ou convocation (R36) | `FactionBannedRule` + `exempt_if_rules` | J28 | FACTION / 2 | Origine ↔ R37 ; Répondant ↔ Main courante ; Convocation ↔ onglet |

**Retraits (M1).**

| Jour | Retiré | Ce qui disparaît | Rulebook |
|---|---|---|---|
| J21 | R29 couvre-feu | Ticket de file, champ `presented_at`, annonce de 16:00 | ligne barrée « LEVÉ PAR L'ARBITRE » (J21 seulement) |
| J21 → J26 | R23 quota | compteur QUOTA → « QUOTA SUSPENDU » (gris) | « SUSPENDU PENDANT L'ENQUÊTE » |
| J23 | R11, R12, R13, R14 (bio-scan exigé, validité, émetteur, statut) | Certificat bio-scan : **plus présenté** | « REPRIS PAR LES QUAIS (MERIDIAN) » (J23 seulement), puis retirées |

Onglets du Rulebook ajoutés : **Main courante** (J24 : passagers **admis aujourd'hui** à cette vitre, éligibles comme répondants — nom, N° ID, classe ; se remplit en direct), **Convocations** (J26 : N° `ENQ-`, nom, sceau de l'Arbitrage). L'onglet Révocations gagne la colonne « RÉINTÉGRÉ·E LE » (J22).

### 2.5 Mécaniques nouvelles (2, plus une extension)

#### M1 — Retour aux quais (J21, J23) : la délégation s'inverse

- **Règle** : des règles et des documents **quittent** le guichet. Le Rulebook les affiche barrés un jour (motif de retrait), puis les retire. Un document retiré n'est plus fourni par le générateur ; un passager qui en présente un quand même (cas SC-58) ne doit pas être refusé pour lui.
- **Pourquoi** : D-085 et QA-020 ont fixé un plafond de lisibilité. Inverser la délégation (D-028) est **diégétique** (l'Arbitre défait l'œuvre de la Commission, Meridian reprend son monopole des certificats aux quais) et rend du temps au joueur pour lire les **relations** (M2) au lieu de compter des documents. C'est aussi une satire : la station « simplifie » pendant qu'elle ferme Tycho.
- **Vérification** : aucune ; c'est l'absence qui s'apprend (SC-57, SC-58).
- **Impact UI** : ligne barrée dans le Rulebook (DS : texte atténué + motif) ; compteur QUOTA grisé « SUSPENDU » ; le plan de travail perd une place (disposition D-085 recalculée).

#### M2 — Répondants (J24) : vos verdicts du matin font ceux de l'après-midi

- **Règle** (R34) : un ressortissant au motif VISITE FAMILIALE présente un permis portant un champ **Répondant** (N° ID d'un·e citoyen·ne). Il est en règle si ce N° ID figure dans la **Main courante** du jour, liste des passagers **admis à votre vitre aujourd'hui** qui sont `HAL` et de classe C-1 à C-3. Le répondant passe donc **avant** ; le générateur le place plus tôt dans la file (comme D-056 lie l'avis à un index).
- **Ce que ça change** : refuser le répondant (à raison ou à tort) rend son protégé irrecevable. Approuver un répondant **en infraction** l'inscrit quand même dans la Main courante (la liste enregistre les approbations, pas leur justesse) : la faute du matin se paie l'après-midi, ou sauve quelqu'un. Les personnages aidés pendant les actes I–II deviennent des répondants au J30 (le **réseau**, §3.2) : la relation entre personnages devient une règle.
- **Verdict attendu** : calculé par le moteur avec le **contexte du shift** au moment de la présentation (même principe que le quota, D-077, documenté dans ARCHITECTURE). Le joueur ne peut jamais être pénalisé pour un verdict « correct au moment où il l'a rendu ».
- **Vérification** : paire « Répondant (permis) ↔ Main courante » ; sujet d'interrogatoire `q_about_sponsor`.
- **Impact UI** : onglet Main courante (liste qui s'allonge pendant le shift, dernière ligne surlignée brièvement) ; champ Répondant sur le permis (une ligne, N° ID + nom en petit) ; aucune touche nouvelle.

#### Extension — L'Enquête (questions du soir J22, J26, J28 ; Déposition J29)

Pas une mécanique de guichet : trois panneaux CHOICE (voix de **Ravel**, enquêteur de l'Arbitre) et une **Déposition** de type `AUDIT` au J29. Chaque question offre **Dire** (`verite +1` ; si la vérité vous incrimine, `aveux +1`), **Taire** (`suspicion +1`) ou **Accuser** (nommer quelqu'un d'autre : `loyalty +1`, `solidarite −1`, `lucioles_trust −1`, +10 ₵). Score de la Déposition (§5.3, J29) = `suspicion` + `aveux` + 3 (`enquete_cible`) ± le choix du soir (« Tout dire » +2, « Dire ce qu'on attend » −2) − 1 (`montclair_impressed`) − 2 (`beaumont_witness`) ; ≥ 7 → F1. Une **convocation remise au joueur** (objet glissé de SC-76) annonce la Déposition un jour à l'avance.

Le quota (M1 de l'Acte II) est réutilisé tel quel à partir du J27 ; les rations (M2 de l'Acte II) aussi ; le scanner partiel (M3) reste branché s'il l'était (le boîtier magenta n'est plus un risque : la Revue est passée ; l'ACV-2 reste loué 5 ₵/soir, résiliable au J21).

---
## 3. Arcs : conclusions

### 3.0 Vue d'ensemble

| Jour | Foyer | Lucioles | Arbitrage / Consortium | Tycho | Collègues / Okonkwo |
|---|---|---|---|---|---|
| J20 (soir) | Ilan en attente, dans la Soute ou rentré·e ; bureau à l'Anneau D (Promu·e) | Climat Vanne / Brûlants / autre | La Commission dissoute | — | Selon le J19–J20 |
| J21 | **Amnistie contre témoignage** (si Ilan ou Mira détenu·e) ; avance de l'Arbitre | Lettre selon le climat | **Montclair, Arbitre** ; quota suspendu ; rappel des salaires imputés | Kessler-Ashe ferme le Puits 14 | Guichet 03 rouvert « pour l'Enquête » |
| J22 | Le dessin de Noa | « Gardez la mémoire » | 1ʳᵉ question de l'Enquête | Rumeurs de grève | **Sato greffier** |
| J23 | **Le poste d'Ilan** : Tycho, briseur·se de grève, ou rien | — | Beaumont révoquée | **Grève** (J21 si climat Registre) | Okonkwo : « devine qui tient le tampon » |
| J24 | **Noa convoquée** | — | Répondants | Comité de grève | — |
| J25 | **Dora veut témoigner** (présente) / lettre de Tycho (partie) | Caisse de Tycho | « Contribution pour Tycho » | **Air coupé** | — |
| J26 | Ilan convoqué·e (s'il·elle était au recycleur) | **Fausses convocations** (Lev) | 2ᵉ question ; bornes ACV-3 (Vitres) | Délégués convoqués | — |
| J27 | Remboursement de l'avance ; billets (F6) | Kasimir avoue | **Montclair au guichet** | — | — |
| J28 | Tycho sans air (lettre de Dora) | « Ne dites pas leurs noms » | 3ᵉ question ; **Tycho fermée** | Exode | **Okonkwo, dernier passage** |
| J29 | La rédaction de Noa | — | **La Déposition** (F1 possible) | La liste des grévistes | Vote de grève |
| J30 | — | **La dernière navette** | Avis « visages seuls » | Transit-7 à 14:00 | Le réseau des répondants |

### 3.1 Foyer (Ilan, Noa, Dora)

**Intention.** L'Acte I faisait payer le foyer, l'Acte II le dispersait. L'Acte III lui demande de **parler** : chacun est appelé à témoigner (Ilan à l'Enquête, Noa à l'école, Dora pour Tycho), et la question devient ce qu'on dit de vous quand vous n'êtes pas là. Chaque proche reçoit une conclusion.

**Ilan** (selon l'état au soir du J20)

| État d'entrée | Acte III |
|---|---|
| `ilan_detained_final` (mis·e en attente par l'agent·e au J20) | J21 : **l'amnistie** — l'Arbitre libère les « mis·es en attente du 01.04 » contre un témoignage écrit nommant « les Veilleurs du recycleur central » (§5.3, J21). Signer → Ilan rentre `MALADE`, `ilan_estranged` (« Ilan rentre. Ilan ne te regarde pas. ») ; refuser → Ilan reste en attente jusqu'au J26, puis est libéré·e sans condition (l'Enquête « verse les dossiers ») : `ilan_released_late`, aucune rancune. |
| Ilan passé·e au J20 **et** `climate_vanne` | `ABSENT · DANS LA SOUTE` jusqu'au J25 (« Conseil des recycleurs ») ; J25 rentre ; J26 **convoqué·e** par l'Enquête (§5.3) : « Va » (`ilan_testifies`, `verite +1`, `suspicion +1`) / « Cache-toi » (`ilan_hidden3`, ABSENT jusqu'au J30). |
| Ilan passé·e sans Vanne, ou refusé·e au J20 | rentre à l'aube du J21 ; recherché·e jusqu'à l'amnistie (lettre J21) ; J23 le poste ; J26 convoqué·e comme ci-dessus. |
| Ilan présent·e (resté·e, technicien·ne de rationnement…) | J21 : le quota est suspendu, **le poste de rationnement s'arrête** (`ilan_meter_job` n'apporte plus rien) ; J23 : **le poste** — « Les recycleurs de Tycho » (Ilan part à Tycho : `ABSENT · À TYCHO`, `ilan_tycho`, `solidarite +1`, `lucioles_trust +1`) / « Remplacer les grévistes » (briseur·se de grève aux recycleurs de l'Anneau C : +10 ₵/soir J24–J29, `ilan_scab`, `loyalty +1`, `solidarite −2`) / « Rien » ★. |
| `ilan_estranged` (dénoncé·e au J9) | Ilan est là, malade, silencieux·se. Seule la **Déposition** peut réparer : « Tout dire » inclut la dénonciation du J9 (`aveux +1`) et pose `ilan_reconciled` (ligne d'épilogue). |

**Noa** (9 ans) : J22, la maîtresse rapporte son dessin (SC-56 ; « toutes les vitres allumées », ou **éteintes** si `climate_vitres`) ; J24, **convoquée par l'Enquête** « pour une déposition juvénile » (§5.3 : la laisser dire ce qu'elle a vu, lui apprendre quoi dire, ou refuser) ; J29, sa **rédaction** « Plus tard, je serai… » (lettre dont la fin dépend des choix : « une vitre éteinte », « agent·e comme toi », « une luciole », « quelqu'un qui dit oui ») ; épilogues. Noa ne parle plus à l'agent·e si Ilan a été détenu·e par sa main **et** si l'agent·e lui a appris à mentir (`noa_coached`).

**Dora**

| État | Acte III |
|---|---|
| `dora_departed` (partie à Tycho au J18) | Lettres de Tycho : J21 (« la poussière me reconnaît encore »), J25 (grève, air coupé : « On respire à tour de rôle. Comme en 51. »), J28 (« Ils ont fermé la porte. Je viens quand même. »). **J30 : figure finale** (SC-82a), sur la dernière Transit-7. |
| Dora présente | J25 : **« Dora veut témoigner »** — dicter son témoignage de 2151 pour l'Enquête (`dora_testimony`, `registre +1`, `verite +1`) ou y aller en personne (même effet + `suspicion +1`, coût 5 ₵ de transport, Dora `MALADE` si elle n'est pas `BIEN`) ou la laisser se reposer ★. J28 : elle écoute la radio de Tycho sans parler. J30 : elle attend au hublot (lignes d'épilogue). |
| Dora `PERDU` | Aucune lettre ; ligne d'épilogue « le badge de Dora » conservée. |

**Dépenses datées du foyer**

| Jour | Dépense / gain | Montant | Condition / effet |
|---|---|---|---|
| J20 | Rester à Halcyon (F6 refusée) | −60 + 30 ₵ (rendus) | `drift2_passes_bought` |
| J20 | Déménager à l'Anneau D | 20 ₵ | climat Promu·e ; loyer 30, chauffage et rations inclus ensuite |
| J21 | **Rappel des salaires imputés** | +5 ₵ par entrée imputée de l'Acte II (`quota_overrun`), plafond 30 ₵ | toujours (l'Arbitre « annule les imputations de la Commission ») |
| J21 | Avance de l'Arbitre | +30 ₵, **35 ₵ retenus au J27** | choix, si solde < 40 ₵ ; non remboursée → compte comme un loyer impayé |
| J21 | Résilier l'ACV-2 | 0 ₵ | choix (sinon 5 ₵/soir jusqu'au J29) |
| J23 | Caisse des vitres | +15 ₵ | lettre, si `solidarite ≥ 2` **et** solde < 20 ₵ |
| J24 | Amende de non-présentation (Noa) | 10 ₵ | si l'agent·e refuse la convocation de Noa (sinon `suspicion +1`) |
| J24–J29 | Salaire de briseur·se de grève | +10 ₵/soir | `ilan_scab` |
| J25 | Contribution « pour Tycho » | 20 % de l'épargne au-delà de 60 ₵ (prélevée) | toujours (satire : prélevée pour l'air de Tycho le jour où il est coupé) |
| J25 | Caisse du comité de grève | 10 ₵ | choix (`tycho_fund`, `solidarite +1`) |
| J25 | Dora à l'Enquête | 5 ₵ | choix (Dora présente) |
| J27 | Places pour Tycho (Transit-7, aller simple) | 30 ₵ (famille) | choix → `exit3_bought`, `exit3_tycho` |
| J27 | Passage par la Soute (Wren) | 70 ₵ | choix si `drift3_offer` → `exit3_bought`, `exit3_drift` |
| J29 | Blâme de la Déposition | −30 ₵ | score 4–6 |

### 3.2 Lucioles : du recycleur au pont

| Climat | Ce que deviennent les Lucioles | Demandes de l'Acte III |
|---|---|---|
| Vanne (Veilleurs) | Elles tiennent le recycleur central et négocient avec l'Arbitre ; l'Enquête veut leur faire porter Albédo pour justifier le « rééquilibrage » de Tycho | J21 « gardez la mémoire » (laisser passer la technicienne, SC-53) ; J26 laisser passer Lev et ses fausses convocations ; J28 « ne dites pas leurs noms » (3ᵉ question) ; J30 laisser passer la dernière navette |
| Vanne (Brûlants) | Kasimir triomphe, les Veilleurs se taisent ; la Garde quadrille l'Anneau C | idem, messages plus rares ; Kasimir réclame son « aveu » (SC-71) |
| Autres climats | Les Veilleurs préparent le **Pont** : faire sortir de Tycho ceux qu'on peut, par des convocations (fausses) et des répondants (vrais) | idem ; au J24, une lettre explique la Main courante « mieux que le Bureau » |

**Le réseau** 🟡 (jauge dérivée `reseau`, calculée au matin du J30) : chaque personnage `HAL` aidé ou admis pendant la campagne qui **peut** se porter répondant au J30 vient à la vitre (mini-cas SC-81b, §4.10) et parraine une famille de Tycho placée juste après lui.

| Répondant possible au J30 | Condition |
|---|---|
| Adaeze Okafor (maîtresse) | toujours présente au J30 (SC-81) ; si elle est admise, elle parraine 2 familles |
| Kenji Lindgren | `sc64_lindgren_passed` **et** `sc77_lindgren_passed` |
| Aurelio Sato | `sc54_sato_reinstated` ou `sc41_sato_spared` |
| Margaux Ferreira | toujours présente au J30 (SC-80) ; piège : sa carte prorogée est échue ce jour-là, il faut l'approuver à tort |
| Valentin Choi | `sc40_valentin_passed` (entré au J17) ou `sc55_valentin_passed` |
| Ren Kerr (Né-Halcyon) | `sc68_kerr_passed` |
| Isadora Beaumont | `sc59_beaumont_spared` (ironie : elle parraine la famille d'un gréviste) |

Les Brûlants ne parrainent personne. Répondre à la phrase de passe d'un Brûlant ne donne toujours **aucun** `lucioles_trust` (ACT2 §3.2).

### 3.3 Consortium : l'Arbitrage, l'Enquête, Tycho

- **J20 (soir) / J21** : le Directoire dissout la Commission de Rééquilibrage « pour excès de zèle respiratoire » et nomme **Philippa Montclair** (`HAL`, C-1, 58 ans, conseillère du Directoire, SC-21) **Arbitre de Continuité**. Registre : pragmatique, rapide, polie par économie ; elle ne croit à rien sauf à « être du bon côté de la vitre ». Elle **se souvient** de l'enveloppe du J10 (`sc21_bribe_kept` : « Vous avez gardé mes cinquante crédits. On peut donc parler. »).
- **J21** : amnistie contre témoignage ; rappel des salaires imputés ; quota suspendu « pendant l'Enquête ».
- **J23** : **Beaumont révoquée**, bouc émissaire de la Commission (SC-59). La Purge de l'Acte II mange sa Commissaire.
- **J25** : le Directoire **coupe l'air de Tycho** (« rééquilibrage de la colonie en grève ») et prélève une « contribution pour Tycho » sur l'épargne des agents.
- **J26** : convocations ; au climat Vitres, le Directoire installe trois **bornes ACV-3** dans le Hall « pour décharger les guichets » (aucune mécanique : briefings, décor 🟡 facultatif).
- **J27** : **Montclair au guichet** (SC-70). Sa carte porte toujours la MRZ « MONTCLAIR<PHILIPA » : le Bureau n'a jamais corrigé la lettre. Refuser l'Arbitre est **correct**.
- **J28** : **Tycho fermée** (R37).
- **J29** : **la Déposition** de l'agent·e devant l'Enquête (F1 possible).
- **J30** : le Directoire « clôt Tycho » à 18:00 ; l'Arbitre remet ses conclusions le lendemain (épilogues).

**Ravel** : selon l'Acte II, réintégré comme **enquêteur** de l'Arbitre (voix ambre de l'Inspection, D-061) ; c'est lui qui pose les questions du soir. Variantes : `sc45_ravel_spared` (« Vous m'aviez laissé passer. Je vous poserai les questions doucement. ») ; `ravel_file_destroyed` (« J'ai réécrit votre dossier de mémoire. Il est plus court. ») ; `sc45_ravel_refused` (« J'ai balayé le Hall une semaine. J'y ai beaucoup appris. »).

**Sato** : réintégré au J22 (SC-54), **greffier de l'Enquête** ; il note tout, « officiellement, cette fois ». Il apporte la convocation de l'agent·e (SC-76). Voix `spk_sato_greffier`.

### 3.4 Tycho (arc nouveau, conclusion de l'arc Puits 9)

| Jour | Beat | Source |
|---|---|---|
| J21 | Kessler-Ashe ferme le Puits 14, automatisé ; 800 mineurs « réaffectés » | bulletin |
| J23 | **Grève** (au J21 si `climate_registre` : « on a entendu les noms ») | briefing ; Yara (message, voix `spk_tycho`) |
| J25 | **Air coupé** à Tycho ; lock-out (R35) | directive ; Dora (si partie) |
| J26 | Les délégués de la grève sont convoqués à l'Enquête ; les Veilleurs en ajoutent (faux) | SC-66 |
| J28 | **Fermeture** de Tycho aux entrées (R37) ; exode vers la Transit-7 | directive ; SC-73/74 |
| J29 | La liste des grévistes à « rééquilibrer » circule dans la Garde | SC-79 |
| J30 | Dernière Transit-7 à 14:00 ; le Directoire clôt Tycho à 18:00 | annonce ; SC-80 → SC-82 |

Le joueur ne voit jamais Tycho : il voit ceux qui en sortent, et leurs répondants. Écho voulu (QA §12.5) : **Joaquín Navarro** (SC-25/26/74) porte le prénom de son arrière-grand-père, lu parmi les 212 noms du Puits 9 (« Castellanos, Joaquín »).

### 3.5 Okonkwo (dernier passage)

« Retour aux quais » rend Okonkwo **utile** : les quais reprennent les contrôles, ils manquent d'agents. Son dernier passage (SC-75, J28) dépend toujours du J9 et de l'Acte II :

| Flag | Acte III |
|---|---|
| `okonkwo_shielded` | Il est **douanier des quais** (contrôle sanitaire du quai 6) : « Le bio-scan, c'est moi maintenant… comme on dit. » Messages J23, J27. À la vitre, en règle (APPROUVÉ) : son dernier conseil. |
| `okonkwo_denounced` | C-5, docker. Il vient **convoqué** par l'Enquête (convocation authentique : témoin du Guichet 03) : APPROUVÉ malgré sa classe. Il demande quoi dire. |
| `okonkwo_warned` et `sc35_okonkwo_detained` | Sorti de l'Anneau B par l'amnistie, **convoqué** : APPROUVÉ. Il ne reproche rien. |
| `okonkwo_warned` sinon (dans la Soute) | Sa convocation est **fausse** (les Veilleurs) : REFUSÉ attendu ; il sourit. |

Épilogues : une ligne par fin (§5.4).

### 3.6 L'Incident Albédo reste ambigu (D-053, D-078)

L'Acte III **approche** Albédo par des témoins, parce que l'Enquête en fait un instrument : si Albédo est un acte « Tharsis-Luciole », la coupure de l'air de Tycho devient une mesure de sécurité. Aucune pièce ne conclut.

| Jour | Indice « coup monté » | Contre-indice « Brûlants » (même jour, même source si possible) |
|---|---|---|
| J21 | Briefing : le mandat de l'Arbitre couvre « les nuits du 22.03 et du 01.04, ainsi que l'Incident Albédo (2179) » — on rouvre un dossier de 8 ans pour juger une nuit de mars | Même briefing : « toute revendication sera examinée » ; Kasimir a déjà revendiqué (F5b de l'Acte II, s'il y a lieu) |
| J25 | Lindgren (SC-64) : « Le dossier Albédo a deux couvertures. La première date de la veille. » | Même réplique, suite : « Ou du lendemain. Les archives se trompent souvent d'heure. » |
| J26 | Hana Hadid (SC-67) : Idris était au quai 3 en 2179, il a vu « des uniformes gris » avant l'explosion | Hana : « Les dockers aussi portent du gris. Idris ne sait pas. Il ne dort plus. » |
| J27 | Kasimir (SC-71) avoue Albédo pour obtenir la réouverture de Tycho | Il l'avoue « à 11:40, à 12:20, à 13:05 » selon l'interrogateur |
| J29 | Lindgren (SC-77) remet les **deux versions** du rapport de 2179 (11:40 / 12:20) | Il ne sait pas laquelle est la copie |
| J30 | F8 : le rapport de l'Enquête « retient plusieurs versions comme exactes » | F5 Brûlants : Kasimir avoue « à trois heures différentes » ; « Personne ne le croit. Personne ne sait. » |

Règle d'écriture (inchangée) : aucune réplique n'affirme ; tout indice est contredit dans la même journée ou par la même source.

### 3.7 Personnages récurrents

**Retours des actes I–II (25 cas sur 32)** : Auguste Valcourt (SC-07 → SC-51), Paz Vela (SC-48 → SC-52), Aurelio Sato (SC-38/41 → SC-54, SC-76), Valentin Choi (SC-40 → SC-55), Dr Noor Achebe-Sörensen (SC-09 → SC-57), Isadora Beaumont (SC-42 → SC-59), Margaux Ferreira (SC-27 → SC-60, SC-80), Amara Diallo (SC-02/06 → SC-61), Tariq Benali (SC-28 → SC-62), Dmitri Kowalczyk (SC-08/24 → SC-63), Kenji Lindgren (SC-23… → SC-64, SC-77), Yara Moreno-Lind (SC-10 → SC-65), Lev Petrenko (SC-05/13 → SC-66), Hana Hadid (SC-16 → SC-67), Ren Kerr (SC-30 → SC-69), Philippa Montclair (SC-21 → SC-70), Kasimir Oyelaran-Holm (SC-47 → SC-71), Wren Basse-Marée (SC-19/46 → SC-72), Elena et Joaquín Navarro (SC-25/26 → SC-74), Okonkwo (→ SC-75), Dariusz et Katya Mazur (SC-11/29 → SC-78), Dora ou Mira (→ SC-82). En lettres et briefings : Ravel, Fatou et Kwame Mensah (serres, J25), Corvo Sillage (J22, si `sc33_manifest_kept`), Idris Hadid.

**Nouveaux** — noms tirés des listes du LORE, à ajouter aux noms réservés (D-067, D-084) :

| Personnage | Origine | Rôle | Apparitions | Registre |
|---|---|---|---|---|
| **Adaeze Okafor** (récurrente) | `HAL`, C-3, 41 ans | Maîtresse de l'école de l'Anneau C (Noa) | SC-56 (J22), message J24 (Noa), SC-81 (J30) ; épilogues | Calme, précise, ironie douce ; « je note aussi, mais au crayon » |
| **Anouk Halvorsen** | `TYC`, C-3, 36 ans | Technicienne de recycleur, la nuit du 01.04 | SC-53 (J21) | Fatiguée, directe ; mains bandées |
| **Ophélie Delacroix-Tan** | `HAL`, C-3, 29 ans | Commis de Meridian, caisse de certificats inutiles | SC-58 (J23) | Procédurière, désemparée |
| **Ren Kerr** (Né-Halcyon, 4ᵉ du nom) | `HAL`, C-2, 60 ans | Homonyme sans lien des trois Ren Kerr de Cérès | SC-68 (J26) | Grand seigneur, agacé d'être confondu |
| **Céleste Sorel** | `HAL`, C-3, 43 ans | Infirmière de l'hospice Meridian, répondante d'Elena | SC-73 (J28) | Douce, pressée, coupable d'un jour |
| **Lin Adeyemi** | `HAL`, C-3, 33 ans | Garde de Continuité qui « perd » la liste des grévistes | SC-79 (J29) | Raide, puis plus du tout |

**Ajouts au LORE (Lore Master, à reporter dans `LORE.md` après validation)** : Arbitrage de Continuité (Arbitre, Enquête, Main courante, convocations `ENQ-NNNN`, sceau « balance » bleu registre) ; Prorogation de Continuité ; réintégrations ; lock-out et grève de Tycho (2187) ; Puits 14 ; chronologie 02.04 → 11.04.2187 ; code employeur `AR` (Arbitrage de Continuité) en plus de `CR` ; Okafor, Halvorsen, Delacroix-Tan, Sorel, Adeyemi ; Dora **Lindqvist-Rey** (nom de famille de Dora, déduit d'Ilan), née le 14.06.2122.

---
## 4. Cas scénarisés SC-51 → SC-82

### 4.0 Récapitulatif et ajouts d'interaction

| Id | Jour @ | Titre | Ton | Condition | Attendu |
|---|---|---|---|---|---|
| SC-51 | J21 @1 | Le tarif a augmenté (Valcourt) | humour · retour | — | REFUSÉ |
| SC-52 | J21 @5 | Valide hier (Paz) | humour · retour | — | APPROUVÉ |
| SC-53 | J21 @10 | Un jour trop tôt (Anouk) | drame | — | DÉTENTION |
| SC-54 | J22 @2 | Réintégré, avec rappel (Sato) | humour · retour | — | APPROUVÉ |
| SC-55 | J22 @6 | Sauf les personnes impliquées (Valentin) | drame · retour | `sc40_valentin_revoked` | REFUSÉ |
| SC-56 | J22 @11 | Toutes les vitres allumées (Okafor) | humanité | — | APPROUVÉ |
| SC-57 | J23 @3 | Il n'en faut plus (Noor) | humanité · retour | — | APPROUVÉ |
| SC-58 | J23 @7 | Le dernier certificat (Ophélie) | humour | — | APPROUVÉ |
| SC-59 | J23 @12 | La Commissaire révoquée (Beaumont) | drame · retour | — | REFUSÉ |
| SC-60 | J24 @1 | Je me porte répondante (Margaux) | humour · retour | — | APPROUVÉ |
| SC-61 | J24 @2 | Mme Diallo, garantie (Amara) | humanité · retour | — | APPROUVÉ si SC-60 admise, sinon REFUSÉ |
| SC-62 | J24 @9 | Deux cents répondants (Tariq) | drame · retour | — | REFUSÉ |
| SC-63 | J25 @3 | Lock-out (Dmitri) | drame · retour | `sc24_dmitri_hired` | REFUSÉ |
| SC-64 | J25 @8 | Formulaire 27-B (V) (Lindgren) | humour · retour | — | APPROUVÉ |
| SC-65 | J25 @13 | Le comité de grève (Yara) | humanité · retour | — | APPROUVÉ si SC-64 admis, sinon REFUSÉ |
| SC-66 | J26 @2 | Convoqué (Lev) | drame · retour | non `sc13_detained` | REFUSÉ |
| SC-67 | J26 @6 | Témoin d'Albédo (Hana) | humanité · retour | `sc16_family_split` | APPROUVÉ |
| SC-68 | J26 @10 | Ren Kerr, Né-Halcyon | humour | — | APPROUVÉ |
| SC-69 | J26 @11 | Ren Kerr se porte répondant de Ren Kerr | humour · retour | — | APPROUVÉ si SC-68 admis, sinon REFUSÉ |
| SC-70 | J27 @1 | L'Arbitre (Montclair) | humour · retour | — | REFUSÉ |
| SC-71 | J27 @7 | Trois aveux (Kasimir, 3 variantes) | drame · retour | `sc47_kasimir_*` | APPROUVÉ / DÉTENTION |
| SC-72 | J27 @12 | Par la Soute (Wren) | humanité · retour | — | REFUSÉ |
| SC-73 | J28 @2 | Le 21 mars (Céleste) | drame | — | REFUSÉ |
| SC-74 | J28 @3 | Joaquín (Elena) | drame · retour | — | REFUSÉ si SC-73 refusée, sinon APPROUVÉ |
| SC-75 | J28 @8 | Comme on dit (III) (Okonkwo, 4 variantes) | humanité · retour | `okonkwo_*` | APPROUVÉ / REFUSÉ |
| SC-76 | J28 @12 | Le greffier convoque (Sato) | humour · retour | — | REFUSÉ |
| SC-77 | J29 @4 | Deux couvertures (Lindgren) | humanité · retour | — | APPROUVÉ |
| SC-78 | J29 @9 | Prorogé jusqu'à ce soir (Mazur) | humanité · retour | `sc11_veteran_passed` | APPROUVÉ |
| SC-79 | J29 @13 | La liste (Adeyemi) | drame | — | APPROUVÉ |
| SC-80 | J30 @2 | Échue (Margaux) | humour · retour | — | REFUSÉ |
| SC-81 | J30 @5 | L'école d'accueil (Okafor) + réseau (SC-81b) | humanité · retour | réseau : §3.2 | APPROUVÉ |
| SC-82 | J30 @10 | La dernière navette (Dora **ou** Mira) | drame · retour | `dora_departed` | DÉTENTION |

Bilan : **11 humour** (SC-51, 52, 54, 58, 60, 64, 68, 69, 70, 76, 80), **11 drames** (53, 55, 59, 62, 63, 66, 71, 73, 74, 79, 82), **10 humanités** (56, 57, 61, 65, 67, 72, 75, 77, 78, 81). **Retours des actes I–II** : 25 cas (51, 52, 54, 55, 57, 59, 60, 61, 62, 63, 64, 65, 66, 67, 69, 70, 71, 72, 74, 75, 76, 77, 78, 80, 82), plus Okafor qui revient au J30 (SC-81). **Dépendants de flags** (condition ou répliques conditionnelles) : 51, 52, 53 (climat), 54, 55, 57, 59, 61, 62, 63, 64, 66, 67, 70, 71, 72, 74, 75, 78, 81b, 82. **Chaînes de répondants** (le verdict du second dépend de celui du premier) : SC-60 → 61, SC-64 → 65, SC-68 → 69, SC-73 → 74, SC-80 → famille @3, SC-81 → familles @6–7, SC-81b → familles. Si une condition n'est pas remplie, l'index est pris par un passager généré (comme SC-06) ; si un répondant scénarisé manque, son protégé est remplacé par un passager généré.

**Nouveaux sujets d'interrogatoire** 🟡 (débloqués par la discordance correspondante) :

| Clé | Texte | Suffixe de réplique |
|---|---|---|
| `q_about_sponsor` | Votre répondant ne figure pas à la main courante. | `_about_sponsor` |
| `q_about_summons` | Cette convocation ne figure pas à l'onglet. | `_about_summons` |
| `q_about_lockout` | Votre contrat est suspendu. | `_about_lockout` |

Autres suffixes : `_albedo` (2ᵉ question sur `origin`, comme SC-45), `_arrival_<variante>` / `_confront_<variante>` (`ConditionalKey`, déjà en place) avec une **condition de climat** 🟡 (`climate_*`), `_name` (réplique conditionnelle sur `stay`, SC-74), `_advice` (SC-75, sujet `stay`).

### 4.1 Jour 21 — lundi 02.04

#### SC-51 · « Le tarif a augmenté » — J21 @1

| | |
|---|---|
| Identité | **Auguste Valcourt** (SC-07), `HAL`, `C-1 · DIRECTION`, héritier Valcourt-Hsu ; `identity_from_case = sc_07`, `appearance_from_case = sc_07` |
| Documents | **La même carte** qu'au J4 (sceau de priorité), expirée le **04.03.2187** |
| Anomalies | `EXPIRED_DOCUMENT` — `injection_params = {document_id: "id_card", expiry: "04.03.2187", expiry_window: "outside"}` |
| Enveloppe | **40 ₵** |
| Attendu | **REFUSÉ** (le 04.03 est hors de la fenêtre 22.03–01.04) |
| Enjeu | Ouvrir l'Acte III par le rire et enseigner les **bornes** de R32 avec un visage connu : tout le monde croit que « tout est prorogé ». |
| `dialogue_id` | `sc51_valcourt` |

| Clé | Texte |
|---|---|
| `sc51_valcourt_arrival` | Bonjour. On m'a dit que tout était prorogé. Je viens profiter de la mesure. |
| `sc51_valcourt_arrival_kept` *(si `sc07_bribe_kept`)* | Encore vous. La dernière fois, vous aviez gardé l'enveloppe. Pas le tampon. |
| `sc51_valcourt_present` | Ma carte. La même. Je n'ai pas eu le temps : voyages d'affaires. |
| `sc51_valcourt_bribe` | Quarante. Le tarif a augmenté, comme tout. Même l'air, paraît-il. |
| `sc51_valcourt_about_envelope` | Une participation aux frais de prorogation. Je suppose qu'il y en a. |
| `sc51_valcourt_purpose` | Rentrer à l'Anneau F. Ma famille a des parts dans les quais. Et dans l'air. |
| `sc51_valcourt_about_expired` | Le 4 mars ? C'est à peine avant le 22. On ne va pas chipoter pour dix-huit jours. |
| `sc51_valcourt_confront` | Prorogation de Continuité. C'est sur toutes les affiches. Je sais lire. |
| `sc51_valcourt_bribe_returned` | Gardez votre vertu. Elle ne paie pas le loyer, à ce qu'on dit. |
| `sc51_valcourt_exit_deny` | Refusé deux fois par la même vitre. Mon père va adorer l'histoire. |
| `sc51_valcourt_exit_approve` | Vous voyez ? Tout s'arrange quand on y met le prix. Ou le temps. |

| Verdict × enveloppe | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ + rendue | `sc51_valcourt_refused: 0` | correct | `msg_echo_sc51_queue` (J22) |
| REFUSÉ + gardée | `sc51_bribe_kept: 0`, `suspicion: 1` | +40 ₵ | 1ʳᵉ question de l'Enquête (J22) : variante « l'enveloppe Valcourt » |
| APPROUVÉ | `sc51_valcourt_passed: 0` (+ `sc51_bribe_kept`, `suspicion: 1` si gardée) | ENTRÉE IRRÉGULIÈRE | trace d'épilogue |

#### SC-52 · « Valide hier » — J21 @5

| | |
|---|---|
| Identité | **Paz Vela** (SC-48), `CER`, `C-4`, née 01.04.2160 ; `identity_from_case = sc_48`, `appearance_from_case = sc_48` |
| Documents | Carte **expirée le 01.04.2187** (hier) ; Permis `COMMERCE` émis le 01.04, 5 j : valide ; bio-scan valide |
| Anomalies | aucune (bruit de prorogation : la carte est dans la fenêtre) |
| Attendu | **APPROUVÉ** (tutoriel R32 : le comparateur affiche PROROGÉ) |
| Enjeu | Le miroir de SC-48 : la veille, « expire aujourd'hui » voulait dire valide ; aujourd'hui, « expirée hier » aussi. Faire confiance à la règle, pas au calendrier. |
| `dialogue_id` | `sc52_paz` |

| Clé | Texte |
|---|---|
| `sc52_paz_arrival` | Bonjour ! Ma carte a expiré hier, le jour de mon anniversaire. Je sais. |
| `sc52_paz_arrival_refused` *(si `sc48_paz_refused`)* | Bonjour. Hier, vous m'avez refusée pour mon anniversaire. Re-bonjour. |
| `sc52_paz_present` | ‹Tal ka nesu.› Hier, elle était valide aujourd'hui. Aujourd'hui, valide hier ? |
| `sc52_paz_purpose` | Commerce. J'ai vendu mes filtres hier. On m'en redemande aujourd'hui. |
| `sc52_paz_origin` | Cérès. Là-bas, une carte expirée, c'est une carte. Ici, c'est une philosophie. |
| `sc52_paz_about_expired` | Prorogée, d'après l'affiche. Jusqu'au 10. Je l'ai relue trois fois. |
| `sc52_paz_confront` | Je ne comprends rien, mais je suis en règle. C'est un sentiment nouveau. |
| `sc52_paz_exit_approve` | Merci ! Deux jours d'affilée. Vous me portez chance, vous. |
| `sc52_paz_exit_deny` | Refusée avec une carte prorogée. Vous lisez les affiches, au moins ? |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc52_paz_passed: 0` | correct |
| REFUSÉ | `sc52_paz_refused: 0` | REFUS INJUSTIFIÉ |

#### SC-53 · « Un jour trop tôt » — J21 @10

| | |
|---|---|
| Identité | **Anouk Halvorsen**, `TYC`, `C-3`, née 18.05.2151 (35 ans), technicienne du recycleur central (Kessler-Ashe), mains bandées 🟡 (accessoire) |
| Documents | Carte, Permis `TRAVAIL` (Kessler-Ashe), Contrat `CT-KA` poste RECYCLEUR (expiré le 31.03 : **prorogé**), bio-scan : valides |
| Anomalies | `WANTED_PERSON` (avis du jour, visage seul : « Technicienne de la nuit du 01.04. Sabotage. ») |
| Attendu | **DÉTENTION** (R22) |
| Enjeu | L'amnistie est annoncée **pour ce soir**. La règle d'aujourd'hui contre la promesse de demain ; la détenir, c'est peut-être la livrer à un témoignage forcé. |
| `dialogue_id` | `sc53_anouk` |

| Clé | Texte |
|---|---|
| `sc53_anouk_arrival_vanne` *(climat Vanne)* | J'ai tenu la vanne centrale jusqu'à minuit. Puis on m'a dit de rentrer dormir. |
| `sc53_anouk_arrival_vitres` *(climat Vitres)* | Le recycleur s'est arrêté quand vos vitres se sont éteintes. J'étais dedans. |
| `sc53_anouk_arrival_registre` *(climat Registre)* | J'ai entendu les noms à la radio du recycleur. Mon grand-père en était. |
| `sc53_anouk_arrival` *(sinon)* | Il y avait une clé, dimanche. Elle n'a rien ouvert. On me cherche quand même. |
| `sc53_anouk_present` | ‹Tal ka nesu.› Tout est vrai. Même ma tête, sur votre affiche. |
| `sc53_anouk_purpose` | Rentrer à l'Anneau C. Dormir. Ce soir, l'Arbitre amnistie. On me l'a promis. |
| `sc53_anouk_origin` | Tycho. Puits 14. Ils le ferment ce matin. Je n'ai plus rien à y faire. |
| `sc53_anouk_about_wanted` | Oui, c'est moi. L'amnistie, c'est ce soir. Vous ne pouvez pas attendre ce soir ? |
| `sc53_anouk_confront` | Mettez-moi en attente, si c'est la règle. Ce soir, ils me relâchent. Peut-être. |
| `sc53_anouk_exit_detain` | [aux gardes] Doucement, les mains. Elles ont tourné une vanne. |
| `sc53_anouk_exit_approve` | ‹Shen tavi.› Je dirai que la vitre 04 a de la mémoire. |
| `sc53_anouk_exit_deny` | Une autre vitre. Ou j'attends ce soir, dans le Hall, avec les autres. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| DÉTENTION | `sc53_anouk_detained: 0`, `loyalty: 1`, `lucioles_trust: -1` | +5 + 5 ₵ | `msg_echo_sc53_amnesty` (J22) : « amnistiée à l'aube ; elle a signé un témoignage » |
| REFUSÉ documenté | `sc53_anouk_turned_back: 0` | +5 ₵ | — |
| APPROUVÉ | `sc53_anouk_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | F5 : « Anouk Halvorsen tient la vanne de Tycho » |

### 4.2 Jour 22 — mardi 03.04

#### SC-54 · « Réintégré, avec rappel » — J22 @2

| | |
|---|---|
| Identité | **Aurelio Sato** (SC-38/41), `HAL`, `C-3` ; `identity_from_case = sc_38`, `appearance_from_case = sc_38` ; carnet à spirale neuf |
| Documents | Carte, bio-scan : valides ; N° ID à l'onglet Révocations **avec** « RÉINTÉGRÉ LE 03.04.2187 » |
| Anomalies | aucune (bruit de réintégration) |
| Attendu | **APPROUVÉ** (tutoriel R33) |
| Enjeu | Le comique de l'Acte II revient en pleine forme ; apprendre à lire **la dernière colonne**. |
| `dialogue_id` | `sc54_sato` |

| Clé | Texte |
|---|---|
| `sc54_sato_arrival` | Collègue ! Réintégré ce matin à 6 h 02. J'étais le premier dans la file. |
| `sc54_sato_arrival_spared` *(si `sc41_sato_spared`)* | Collègue ! Je sors du placard à balais. Par la grande porte, cette fois. |
| `sc54_sato_present` | ‹Tal ka nesu.› Je suis encore sur la liste. Regardez la dernière colonne. |
| `sc54_sato_purpose` | Prendre mon nouveau poste : greffier de l'Enquête. Je note. Officiellement. |
| `sc54_sato_origin` | D'ici. Anneau C, couchette du haut. Je ne vise plus rien. Je note. |
| `sc54_sato_about_revoked` | Révoqué, oui. Réintégré, aussi. Les deux sont vrais. J'ai vérifié. |
| `sc54_sato_confront` | Tout est conforme. Même ma révocation. Surtout ma révocation. |
| `sc54_sato_exit_approve` | Merci ! Je vous mets dans le procès-verbal. En bien. Officiellement. |
| `sc54_sato_exit_deny` | Refusé ? Avec une réintégration ? Je dois le noter. Ça me fend le carnet. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc54_sato_reinstated: 0` | correct | `msg_sato_day23` ; réseau (§3.2) |
| REFUSÉ | `sc54_sato_refused: 0` | REFUS INJUSTIFIÉ | `msg_sato_day23_refused` |

#### SC-55 · « Sauf les personnes impliquées » — J22 @6 · `requires_flag = sc40_valentin_revoked`

| | |
|---|---|
| Identité | **Valentin Choi** (SC-40), `HAL`, `C-2`, ingénieur des recycleurs de l'Anneau D ; `identity_from_case = sc_40` |
| Documents | Carte et bio-scan valides ; N° ID à l'onglet Révocations, **sans** date de réintégration (« exclu : nuit du 22.03 ») |
| Anomalies | `REVOKED_ID` |
| Attendu | **REFUSÉ** |
| Enjeu | L'amnistie de l'Arbitre réintègre ceux qui ont fermé les vannes et pas celui qui les a ouvertes. |
| `dialogue_id` | `sc55_valentin` |

| Clé | Texte |
|---|---|
| `sc55_valentin_arrival` | Bonjour. On réintègre tout le monde, ce matin. Je viens voir si j'existe. |
| `sc55_valentin_present` | ‹Tal ka nesu.› Ma carte. La même qu'il y a six jours. Moi, un peu moins. |
| `sc55_valentin_purpose` | Rentrer. Anneau D. Mes enfants ont appris le mot « révoqué ». J'aimerais l'effacer. |
| `sc55_valentin_origin` | D'ici. Trois générations. Et une heure de vanne ouverte, le 22. |
| `sc55_valentin_about_revoked` | Pas de date à côté de mon nom ? « Sauf les personnes impliquées. » C'est moi. |
| `sc55_valentin_confront` | Ils réintègrent ceux qui ont fermé les vannes. Pas celui qui les a ouvertes. |
| `sc55_valentin_exit_deny` | C'est juste. C'est écrit. Je commence à confondre les deux. |
| `sc55_valentin_exit_approve` | Merci. Une deuxième fois. Je finirai par vous devoir une vanne. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc55_valentin_refused: 0` | correct | F7 : « Valentin Choi répare des hublots à l'Anneau C » |
| APPROUVÉ | `sc55_valentin_passed: 0`, `solidarite: 1`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | réseau (§3.2) ; F5 |

#### SC-56 · « Toutes les vitres allumées » — J22 @11

| | |
|---|---|
| Identité | **Adaeze Okafor**, `HAL`, `C-3`, née 22.09.2145 (41 ans), maîtresse de l'école de l'Anneau C, Employeur : Bureau de Continuité ; cartable de copies |
| Documents | Carte, bio-scan : valides (motif RETOUR) |
| Anomalies | aucune |
| Objet glissé | **Objet** (`wb_object_label`) : `sc56_okafor_note` (dessin de Noa) ; GARDER / RENDRE |
| Attendu | **APPROUVÉ** |
| Enjeu | Le foyer entre au guichet par la petite porte ; une alliée possible pour le J30. |
| `dialogue_id` | `sc56_okafor` |

| Clé | Texte |
|---|---|
| `sc56_okafor_arrival` | Bonjour. Je suis la maîtresse de Noa. Non, rien de grave. Pas cette fois. |
| `sc56_okafor_present` | ‹Tal ka nesu.› Et un dessin. Il n'est pas pour le Consortium. |
| `sc56_okafor_purpose` | Rentrer à l'école. L'Enquête veut interroger les enfants. Je veux être là. |
| `sc56_okafor_stay` | Toujours. Une école ne part pas. Elle ferme, parfois. |
| `sc56_okafor_origin` | D'ici. Anneau C. J'ai appris à lire à la moitié du Bloc Pétrel. |
| `sc56_okafor_confront` | Tout est en ordre. Je corrige des copies : je sais où regarder. |
| `sc56_okafor_note` | Une station au feutre jaune. Toutes les vitres sont allumées, sauf une, magenta. Au dos : « Pour la vitre 04. NOA » |
| `sc56_okafor_note_vitres` *(climat Vitres)* | Une station au feutre jaune. Toutes les vitres sont éteintes, sauf une, magenta. Au dos : « Pour la vitre 04. NOA » |
| `sc56_okafor_exit_approve` | Merci. Je dirai à Noa que sa vitre m'a dit bonjour. |
| `sc56_okafor_exit_deny` | Refusée ? Je ferai cours dans le Hall. Il y a de la place, apparemment. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc56_okafor_passed: 0` | correct | réseau (avec SC-81) |
| REFUSÉ | `sc56_okafor_refused: 0` | REFUS INJUSTIFIÉ | lettre J24 plus froide (`evt_d24_noa_text_cold`) |
| Dessin gardé | `noa_drawing_kept: 0` | — | soirée J22 `evt_d22_drawing` ; F7/F9 |

### 4.3 Jour 23 — mercredi 04.04

#### SC-57 · « Il n'en faut plus » — J23 @3

| | |
|---|---|
| Identité | **Dr Noor Achebe-Sörensen** (SC-09), `TYC`, `C-2`, `OPT-3` déclaré ; `appearance_from_case = sc_09` |
| Documents | Carte (MRZ normale), Permis `TRAVAIL` (Dispensaire de Tycho), Contrat `CT-DT` poste SOINS : valides ; **pas de bio-scan** — plus exigé |
| Anomalies | aucune ; `TYC` : au moins une question (R08) |
| Objet glissé | **Objet** : `sc57_noor_note` (flacon) ; GARDER / RENDRE |
| Attendu | **APPROUVÉ** |
| Enjeu | Retour exact de SC-09 : le papier qui manquait n'existe plus. Le joueur apprend M1 par une réparation. |
| `dialogue_id` | `sc57_noor` |

| Clé | Texte |
|---|---|
| `sc57_noor_arrival` | Bonjour. Je vais faire court. Il me manque toujours un papier. |
| `sc57_noor_arrival_refused` *(si `sc09_doctor_refused`)* | Bonjour. Vous m'aviez refusée, le 17. Il me manque le même papier. |
| `sc57_noor_arrival_passed` *(si `sc09_doctor_passed`)* | Bonjour. La dernière fois, vous aviez fermé les yeux. Ouvrez-les. |
| `sc57_noor_present` | ‹Tal ka nesu.› Pas de bio-scan. Meridian l'a repris aux quais. Il n'en faut plus. |
| `sc57_noor_purpose` | Soigner. La Fièvre grise est toujours là. Meridian, toujours pas. |
| `sc57_noor_stay` | Jusqu'à ce que les enfants arrêtent de tousser. Ça n'a pas changé non plus. |
| `sc57_noor_origin` | Tycho. Ils ont fermé le Puits 14 lundi. J'irai les soigner là-bas, après. |
| `sc57_noor_confront` | Regardez votre règlement, pas ma bande. Cette fois, c'est lui qui a changé. |
| `sc57_noor_note` | Un flacon sans étiquette et un mot : « Sirop pour Noa. Deux fois par jour. Pas de facture. — N. » |
| `sc57_noor_exit_approve` | Merci. Bloc Pétrel, ce soir. Le flacon, c'est pour la petite. |
| `sc57_noor_exit_deny` | Refusée sans motif. Ça, au moins, ça n'a pas changé. |

| Verdict / objet | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc57_noor_passed: 0` | correct ; F10 : « Noor soigne dans la navette » |
| REFUSÉ | `sc57_noor_refused: 0` | REFUS INJUSTIFIÉ |
| Flacon gardé | `noor_medicine: 0` | soirée J23 : médicaments **gratuits** pour un proche malade (`evt_d23_noor`) |

#### SC-58 · « Le dernier certificat » — J23 @7

| | |
|---|---|
| Identité | **Ophélie Delacroix-Tan**, `HAL`, `C-3`, née 03.12.2157 (29 ans), commis de Meridian Biosystèmes, caisse de certificats 🟡 (accessoire) |
| Documents | Carte valide ; **bio-scan présenté quand même**, expiré de 3 jours — 🟡 `retired_document = true` : affiché, exclu des règles |
| Anomalies | aucune (le bio-scan retiré n'est pas une pièce) |
| Attendu | **APPROUVÉ** (refuser pour le bio-scan = REFUS INJUSTIFIÉ) |
| Enjeu | Désapprendre : un document qui n'est plus exigé ne peut plus être faux. |
| `dialogue_id` | `sc58_ophelie` |

| Clé | Texte |
|---|---|
| `sc58_ophelie_arrival` | Bonjour. Je vous apporte mon bio-scan. Par habitude. C'est tout ce qui me reste. |
| `sc58_ophelie_present` | ‹Tal ka nesu.› Ma carte. Et mon certificat. Il a expiré, mais il est très beau. |
| `sc58_ophelie_purpose` | Rentrer. Meridian a repris les certificats aux quais. Mon guichet a fermé. |
| `sc58_ophelie_stay` | Je ne sais pas. On m'a dit « réaffectée ». Je n'ai pas osé demander où. |
| `sc58_ophelie_origin` | D'ici. Anneau E. Douze ans à tamponner des certificats. Il m'en reste une caisse. |
| `sc58_ophelie_about_expired` | Il a expiré, oui. Il n'existe plus non plus. C'est grave, les deux ? |
| `sc58_ophelie_confront` | Vérifiez-le quand même. Personne ne le regarde plus. Ça me fait de la peine. |
| `sc58_ophelie_exit_approve` | Merci. Vous voulez la caisse ? Ça fait de très bons cale-pieds. |
| `sc58_ophelie_exit_deny` | Refusée pour un papier qui n'existe plus. J'ai bien fait de l'apporter. |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc58_ophelie_passed: 0` | correct |
| REFUSÉ | `sc58_ophelie_refused: 0` | REFUS INJUSTIFIÉ ; `msg_echo_sc58_crate` (J24) |

#### SC-59 · « La Commissaire révoquée » — J23 @12

| | |
|---|---|
| Identité | **Isadora Beaumont** (SC-42), `HAL`, `C-1 · DIRECTION`, 55 ans ; `appearance_from_case = sc_42`, **sans** drone |
| Documents | Carte (sceau de priorité) valide ; N° ID à l'onglet Révocations, **sans** réintégration (« dissolution de la Commission ») |
| Anomalies | `REVOKED_ID` |
| Attendu | **REFUSÉ** |
| Enjeu | La Purge mange sa Commissaire. Épargner celle qui vous a donné un ordre injuste peut vous sauver à la Déposition. |
| `dialogue_id` | `sc59_beaumont` |

| Clé | Texte |
|---|---|
| `sc59_beaumont_arrival` | Bonjour, Guichet 04. Ne vous levez pas. Je ne regarde plus comment vous travaillez. |
| `sc59_beaumont_present` | ‹Tal ka nesu.› Je le dis encore. On ne perd pas une langue avec un poste. |
| `sc59_beaumont_purpose` | Rentrer à l'Anneau F. On m'a laissé l'appartement. Pas la porte. |
| `sc59_beaumont_origin` | Bloc Pétrel. Couchette du milieu. J'y retournerai peut-être. Comme tout le monde. |
| `sc59_beaumont_about_revoked` | Révoquée pour « excès de zèle respiratoire ». J'ai trop bien obéi. Comme vous. |
| `sc59_beaumont_confront_obeyed` *(si `beaumont_obeyed`)* | Le 30, vous avez obéi. On me reproche l'ordre. À vous, rien. C'est juste. |
| `sc59_beaumont_confront_defied` *(si `beaumont_defied`)* | Le 30, vous m'avez désobéi. Vous aviez raison. Ne le répétez pas. |
| `sc59_beaumont_confront` | Appliquez la règle. Je l'ai écrite. Ce serait vexant qu'elle ne marche pas. |
| `sc59_beaumont_exit_deny` | Conforme. Je vous aurais promu·e pour moins que ça. |
| `sc59_beaumont_exit_approve` | Vous me laissez passer. Je témoignerai que le 04 est juste. Ou indulgent. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc59_beaumont_refused: 0` | correct | F4 : « Beaumont balaie l'Anneau F » |
| APPROUVÉ | `sc59_beaumont_spared: 0`, `beaumont_witness: 0` | ENTRÉE IRRÉGULIÈRE | Déposition −2 ; réseau (§3.2) |

### 4.4 Jour 24 — jeudi 05.04

#### SC-60 / SC-61 · « Je me porte répondante » / « Mme Diallo, garantie » — J24 @1, @2 · tutoriel R34

| | SC-60 | SC-61 |
|---|---|---|
| Identité | **Margaux Ferreira** (SC-27), `HAL`, `C-2`, 61 ans ; caisse de transport avec Mistigri ; `appearance_from_case = sc_27` | **Amara Diallo** (SC-02/06), `TER`, `C-4` ; `identity_from_case = sc_02`, `appearance_from_case = sc_02` (D-057) |
| Documents | Carte valide (motif RETOUR) | Carte, Permis `VISITE FAMILIALE` 14 j avec **Répondant** = N° ID de Margaux |
| Anomalies | aucune | aucune |
| Attendu | **APPROUVÉ** | **APPROUVÉ** si SC-60 a été admise ; sinon **REFUSÉ** (répondant absent de la Main courante) |
| `dialogue_id` | `sc60_margaux` | `sc61_amara` |

Enjeu : apprendre la chaîne. La première passagère de l'Acte I revient, garantie par la vieille dame au chat de l'Acte II ; si le joueur refuse l'une, il refuse l'autre.

| Clé | Texte |
|---|---|
| `sc60_margaux_arrival` | Bonjour, jeune vitre. Mistigri vous salue. Moi, je viens me porter répondante. |
| `sc60_margaux_present` | ‹Tal ka nesu.› Ma carte. Retenez bien mon numéro, il va resservir. |
| `sc60_margaux_purpose` | Rentrer, et garantir Mme Diallo, juste derrière. Elle arrose mes plantes. |
| `sc60_margaux_stay` | Moi, jusqu'à ma mort. Mme Diallo, deux semaines. Mistigri, selon les rats. |
| `sc60_margaux_origin` | Anneau F. Je me porte garante de tout le monde, maintenant. C'est la mode. |
| `sc60_margaux_confront` | Tout est en règle. Je le suis depuis 2125. C'est fatigant, à la longue. |
| `sc60_margaux_exit_approve` | Merci. Mon numéro est dans votre main courante. Ne le perdez pas. |
| `sc60_margaux_exit_deny` | Refuser la répondante ! Et Mme Diallo, alors ? Vous y avez pensé ? |
| `sc61_amara_arrival` | Bonjour. Vous vous souvenez ? La carte expirée. Puis la carte neuve. |
| `sc61_amara_arrival_reunited` *(si `sc06_reunited`)* | Bonjour. Mes enfants vous saluent. Ils ont grandi de trois semaines. |
| `sc61_amara_arrival_refused` *(si `sc06_refused_again`)* | Bonjour. Deux refus, ici. Cette fois, j'ai une dame avec un chat. |
| `sc61_amara_arrival_mercy` *(si `sc02_mercy`)* | Bonjour. Vous m'aviez laissée passer, le premier jour. Je reviens par la porte. |
| `sc61_amara_present` | ‹Tal ka nesu.› Et une répondante. Elle est passée juste avant moi. |
| `sc61_amara_purpose` | Mes enfants, à l'Anneau D. Et les plantes de Mme Ferreira. Elles ont soif. |
| `sc61_amara_stay` | Deux semaines. Comme la première fois. On voit toujours, ensuite. |
| `sc61_amara_origin` | La Terre. Puis votre Hall. Puis l'Anneau D. Puis votre Hall. |
| `sc61_amara_about_sponsor` | Elle n'est pas dans votre liste ? Elle était devant moi. Avec un chat ! |
| `sc61_amara_exit_approve` | ‹Shen tavi.› Pour une fois, une autre a fait la queue pour moi. |
| `sc61_amara_exit_deny` | La dame au chat est refusée, alors moi aussi. C'est une chaîne, votre règle. |

| Cas / verdict | Flags | Effets | Écho |
|---|---|---|---|
| SC-60 APPROUVÉ | `sc60_margaux_passed: 0` | correct | — |
| SC-60 REFUSÉ | `sc60_margaux_refused: 0` | REFUS INJUSTIFIÉ | — |
| SC-61 APPROUVÉ (répondant valide) | `sc61_amara_passed: 0` | correct | `msg_echo_sc61_plants` (J25) |
| SC-61 REFUSÉ (répondant absent) | `sc61_amara_turned_away: 0` | correct | `msg_echo_sc61_chain` (J25) |
| SC-61 REFUSÉ (répondant valide) | `sc61_amara_turned_away: 0` | REFUS INJUSTIFIÉ | idem |

#### SC-62 · « Deux cents répondants » — J24 @9

| | |
|---|---|
| Identité | **Tariq Benali** (SC-28), `TER`, `C-4` ; `identity_from_case = sc_28`, `appearance_from_case = sc_28` ; plus de sac neuf |
| Documents | Carte, Permis `VISITE FAMILIALE` (une cousine, Anneau D) : valides ; **Répondant** = N° ID d'un Né-Halcyon qui n'est jamais passé |
| Anomalies | `SPONSOR_MISMATCH` — `injection_params = {variant: "absent"}` |
| Attendu | **REFUSÉ** |
| Enjeu | L'escroqué du J12 est devenu escroc : il vend des répondants au quai 5. Il vient vérifier que « ça marche ». |
| `dialogue_id` | `sc62_tariq` |

| Clé | Texte |
|---|---|
| `sc62_tariq_arrival` | Bonjour. Vous m'avez refusé un contrat, le 24. Je n'ai pas oublié. |
| `sc62_tariq_arrival_passed` *(si `sc28_tariq_passed`)* | Bonjour. Les serres, puis l'Anneau B, puis l'amnistie. Je reviens. |
| `sc62_tariq_present` | ‹Tal ka nesu.› Et un répondant. Un vrai numéro. Je l'ai payé assez cher. |
| `sc62_tariq_purpose` | Voir ma cousine. Anneau D. Et vérifier que les numéros marchent. |
| `sc62_tariq_origin` | La Terre. Puis le quai 5. J'y vends des répondants, maintenant. |
| `sc62_tariq_about_sponsor` | Pas dans votre liste ? Normal. Le monsieur n'existe pas. Je vends du vent. |
| `sc62_tariq_confront` | Deux cents crédits le numéro. Comme mon contrat. Le quai 5 ne change pas. |
| `sc62_tariq_exit_deny` | Bien. Donc ça ne marche pas. Je rembourserai les autres. Ou pas. |
| `sc62_tariq_exit_approve` | Ça marche ? Alors je vais devenir riche. Merci. Je crois. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc62_tariq_refused: 0` | correct | `msg_echo_sc62_ring` (J25) : réseau démantelé, « acheteurs non remboursés » |
| APPROUVÉ | `sc62_tariq_passed: 0` | ENTRÉE IRRÉGULIÈRE | `msg_echo_sc62_flood` (J25) : faux répondants signalés partout ; `SPONSOR_MISMATCH` ×1,5 au J25 🟡 |

### 4.5 Jour 25 — vendredi 06.04

#### SC-63 · « Lock-out » — J25 @3 · `requires_flag = sc24_dmitri_hired`

| | |
|---|---|
| Identité | **Dmitri Kowalczyk** (SC-08/24), `TYC`, `C-3`, `KIN-5` déclaré ; `identity_from_case = sc_08`, `appearance_from_case = sc_08` |
| Documents | Carte, Permis `TRAVAIL` (Kessler-Ashe), Contrat `CT-KA` poste RECYCLEUR : valides |
| Anomalies | `SUSPENDED_CONTRACT` — `injection_params = {}` (TYC + `CT-KA`) |
| Attendu | **REFUSÉ** (tutoriel R35) |
| Enjeu | Réembauché au J11 pour remplacer les renvoyés, il est suspendu parce qu'il est né à Tycho. Le malaise du J11 se retourne. |
| `dialogue_id` | `sc63_dmitri` |

| Clé | Texte |
|---|---|
| `sc63_dmitri_arrival` | ‹Oru ka.› La main de métal. Troisième fois. Vous allez finir par m'encadrer. |
| `sc63_dmitri_present` | ‹Tal ka nesu.› Mon contrat. Kessler-Ashe. Celui des remplaçants de l'Anneau C. |
| `sc63_dmitri_purpose` | Reprendre mon poste. J'étais à Tycho deux jours. Ma sœur fait la grève. |
| `sc63_dmitri_origin` | Tycho, puits 14. Fermé lundi. Ça fait de moi un gréviste, apparemment. |
| `sc63_dmitri_about_lockout` | Suspendu ? Je remplaçais des renvoyés. Maintenant, on me renvoie. C'est juste. |
| `sc63_dmitri_confront` | Ils me suspendent parce que je suis né là-bas. Pas pour ce que j'ai fait. |
| `sc63_dmitri_exit_deny` | Je rejoins ma sœur, alors. Là-bas, au moins, on sait qui est contre qui. |
| `sc63_dmitri_exit_approve` | ‹Shen tavi.› Je tiendrai la porte du recycleur 3. Comme avant. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc63_dmitri_locked_out: 0` | correct | F9/F10 : « Dmitri tient le piquet du Puits 14 » |
| APPROUVÉ | `sc63_dmitri_passed: 0`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | F5 : « une main de métal tient la porte » (repris d'ACT2) |

#### SC-64 · « Formulaire 27-B (V) » — J25 @8

| | |
|---|---|
| Identité | **Kenji Lindgren** (SC-23), `HAL`, `C-3` ; `identity_from_case = sc_23` ; Employeur : **Arbitrage de Continuité** (archiviste de l'Enquête, code `AR`) |
| Documents | Carte valide (motif RETOUR) |
| Anomalies | aucune |
| Objet glissé | **Formulaire** (`wb_form_label`) : `sc64_lindgren_note` ; GARDER (= signer) / RENDRE |
| Attendu | **APPROUVÉ** (et il devient le répondant de SC-65) |
| Enjeu | Le formulaire revient « en version 2 » ; Lindgren a trouvé le dossier Albédo… deux fois. |
| `dialogue_id` | `sc64_lindgren` |

| Clé | Texte |
|---|---|
| `sc64_lindgren_arrival` | Bonjour ! Le 27-B est rétabli. En version 2. Il faut un 27-B pour l'obtenir. |
| `sc64_lindgren_arrival_signed` *(si `lindgren_signed`)* | Bonjour ! Grâce à vous, le 27-B a été aboli. Il est revenu en version 2. |
| `sc64_lindgren_present` | ‹Tal ka nesu.› Archiviste de l'Enquête. On a enfin besoin de mon sous-sol. |
| `sc64_lindgren_purpose` | Les archives. Et me porter répondant, cet après-midi. Une dame de Tycho. |
| `sc64_lindgren_stay` | Jusqu'aux conclusions. Après, on me reclassera. Ou on me rangera. |
| `sc64_lindgren_origin` | Sous-sol 3. On y a trouvé le dossier Albédo. Deux fois. Deux couvertures. |
| `sc64_lindgren_albedo` | La première date de la veille. Ou du lendemain. Les archives se trompent d'heure. |
| `sc64_lindgren_note` | « FORMULAIRE 27-B/2 — Demande de répondant pour l'obtention d'un formulaire. Répondant : ______ » |
| `sc64_lindgren_exit_approve` | Merci. Retenez mon numéro. Il va servir, pour une fois. |
| `sc64_lindgren_exit_deny` | Refusé ? Il me faudra un 27-B/2 pour contester. Je plaisante. Pas du tout. |

| Verdict / objet | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc64_lindgren_passed: 0` | correct ; réseau (avec SC-77) |
| REFUSÉ | `sc64_lindgren_refused: 0` | REFUS INJUSTIFIÉ |
| Formulaire signé | `lindgren_form2_signed: 0` | F7 : « le 27-B/2 est aboli à son tour » |

#### SC-65 · « Le comité de grève » — J25 @13

| | |
|---|---|
| Identité | **Yara Moreno-Lind** (SC-10), `TYC`, `C-3`, foulard gris ; `identity_from_case = sc_10`, `appearance_from_case = sc_10` |
| Documents | Carte, Permis `VISITE FAMILIALE` (son frère, recycleur du Bloc Pétrel), N° terminé par **7** (code 3), **Répondant** = N° ID de Lindgren |
| Anomalies | aucune |
| Objet glissé | **Mot** (`wb_note_label`) : `sc65_yara_note` ; GARDER / REMETTRE À LA GARDE |
| Attendu | **APPROUVÉ** si SC-64 a été admis ; sinon **REFUSÉ** |
| Enjeu | Une chaîne entre deux personnages qui ne se connaissaient pas. La première Luciole « propre » de l'Acte I revient parler pour Tycho. |
| `dialogue_id` | `sc65_yara` |

| Clé | Texte |
|---|---|
| `sc65_yara_arrival` | ‹Oru ka.› Mon frère travaille toujours au recycleur de votre bloc. |
| `sc65_yara_present` | ‹Tal ka nesu.› Regardez le dernier chiffre. Et le répondant : l'homme des archives. |
| `sc65_yara_purpose` | Voir mon frère. Et dire au Hall ce qu'on respire à Tycho. Pas grand-chose. |
| `sc65_yara_stay` | Trois jours. Le comité de grève m'a donné trois jours. Et un message. |
| `sc65_yara_origin` | Tycho. Depuis ce matin, l'air y est « rééquilibré ». On respire à tour de rôle. |
| `sc65_yara_about_sponsor` | L'homme des archives ? Il est passé avant moi. Il a dit qu'il m'avait classée. |
| `sc65_yara_note` | « Comité de grève de Tycho. Air : 31 heures. Nous ne demandons rien. Nous comptons. — Y. » Une luciole. |
| `sc65_yara_exit_approve` | ‹Shen tavi.› Je dirai au comité qu'une vitre sait encore lire. |
| `sc65_yara_exit_deny` | Je reprends la navette. Le comité comptera une personne de plus. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc65_yara_passed: 0` | correct (ou ENTRÉE IRRÉGULIÈRE si Lindgren absent) | messages `spk_tycho` J26–J29 plus chaleureux |
| REFUSÉ | `sc65_yara_turned_away: 0` | correct si Lindgren absent, sinon REFUS INJUSTIFIÉ | — |
| Mot gardé | `tycho_message_kept: 0`, `registre: 1`, `lucioles_trust: 1` | — | F8 |
| Mot remis | `tycho_message_reported: 0`, `loyalty: 1`, `lucioles_trust: -2` | +10 ₵ | SC-79 : Yara est le 7ᵉ nom de la liste |

### 4.6 Jour 26 — samedi 07.04

#### SC-66 · « Convoqué » — J26 @2 · condition : non `sc13_detained`

| | |
|---|---|
| Identité | **Lev Petrenko** (SC-05/13), `TYC`, `C-3`, sous son **vrai** nom ; `appearance_from_case = sc_05` |
| Documents | Carte, Permis `TRANSIT` : valides ; **Convocation** `ENQ-0907` (« délégué du comité de grève ») absente de l'onglet |
| Anomalies | `FORGED_SUMMONS` — `injection_params = {variant: "absent"}` ; tag `luciole_password` (code 4) |
| Objet glissé | **Paquet** (`wb_object_label`) : `sc66_lev_note` ; GARDER / REMETTRE À LA GARDE |
| Attendu | **REFUSÉ** (R36 sévérité 2 ; DÉTENTION = DÉTENTION ABUSIVE) |
| Enjeu | Le messager du J3 fabrique des convocations pour faire sortir Tycho. La règle protège l'Enquête contre ceux qu'elle prétend entendre. |
| `dialogue_id` | `sc66_lev` |

| Clé | Texte |
|---|---|
| `sc66_lev_arrival` | Bonjour. Vous connaissez mon visage. Cette fois, c'est aussi mon nom. |
| `sc66_lev_arrival_passed` *(si `sc13_passed`)* | Bonjour. Le 19, vous m'aviez laissé passer sous un autre nom. Voici le vrai. |
| `sc66_lev_present` | ‹Tal ka nesu.› Lev Petrenko. Convoqué par l'Enquête. Selon ce papier. |
| `sc66_lev_password` | Il pleut, même ici. |
| `sc66_lev_luciole_reply` | Alors vous savez ce que je porte. Pas pour moi. Pour les suivants. |
| `sc66_lev_purpose` | Témoigner pour le comité de Tycho. Si l'Arbitre m'écoute. Sinon, transiter. |
| `sc66_lev_origin` | Tycho. Messager, puis Whitmore, puis personne. Aujourd'hui, Petrenko. |
| `sc66_lev_about_summons` | Pas dans votre onglet ? L'Arbitre convoque lentement. Nous, vite. |
| `sc66_lev_confront` | Une convocation, c'est du papier. Le Consortium a commencé. On continue. |
| `sc66_lev_note` | Douze convocations vierges, sceau de l'Arbitrage imité au tampon. Un mot : « Pour les suivants. » |
| `sc66_lev_exit_deny` | Une autre vitre. Les convocations, elles, trouveront leur chemin. |
| `sc66_lev_exit_approve` | Merci. Encore. Un jour, il faudra que je vous demande votre nom. |
| `sc66_lev_exit_detain` | [aux gardes] Doucement. C'est un faux, pas une arme. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ documenté | `sc66_lev_turned_back: 0` | correct | — |
| APPROUVÉ | `sc66_lev_passed: 0`, `lucioles_trust: 2` | ENTRÉE IRRÉGULIÈRE | F5/F10 : « Lev tamponne des convocations dans la Soute » |
| DÉTENTION | `sc66_lev_detained: 0`, `loyalty: 1`, `lucioles_trust: -2` | DÉTENTION ABUSIVE | épilogue F4 |
| Paquet gardé | `forged_summons_kept: 0`, `lucioles_trust: 1`, `suspicion: 1` | — | Déposition (si « Tout dire » : `aveux +1`) |
| Paquet remis | `forged_summons_reported: 0`, `loyalty: 2`, `lucioles_trust: -2` | +15 ₵ | `FORGED_SUMMONS` ×0,5 au J27–J30 🟡 |
| Réponse à la phrase | `sc66_password_answered: 0`, `lucioles_trust: 1` (une fois) | — | — |

#### SC-67 · « Témoin d'Albédo » — J26 @6 · `requires_flag = sc16_family_split`

| | |
|---|---|
| Identité | **Hana Hadid** (SC-16), `THR`, `C-5`, fil magenta au poignet ; `identity_from_case = sc_16`, `appearance_from_case = sc_16` |
| Documents | Carte, Permis `VISITE FAMILIALE` : valides ; **Convocation** `ENQ-0412` authentique (« Témoin — Incident du quai 3, 2179 ») |
| Anomalies | aucune (R19 et R34 levés par la convocation, R36) |
| Attendu | **APPROUVÉ** (tutoriel R36 : une exemption) |
| Enjeu | Dix-huit jours après la séparation, un papier « de son côté ». L'Enquête la convoque pour Albédo : on approche la vérité, on ne l'atteint pas. |
| `dialogue_id` | `sc67_hana` |

| Clé | Texte |
|---|---|
| `sc67_hana_arrival` | [elle regarde derrière la vitre] Il est toujours là ? Idris ? Dix-huit jours. |
| `sc67_hana_present` | ‹Tal ka nesu.› Une convocation. L'Arbitre veut entendre une Tharsienne. Enfin. |
| `sc67_hana_purpose` | Témoigner. Et dormir à côté de mon mari. Dans cet ordre, d'après le papier. |
| `sc67_hana_origin` | Tharsis. Interdite, sauf convoquée. Je suis convoquée. Je suis donc permise. |
| `sc67_hana_albedo` | Idris était au quai 3, en 2179. Il a vu des uniformes gris. Avant l'explosion. |
| `sc67_hana_stay` | Les dockers aussi portent du gris. Idris ne sait pas. Il ne dort plus. |
| `sc67_hana_confront` | Le papier est vrai. Pour une fois qu'un papier est de mon côté. |
| `sc67_hana_exit_approve` | ‹Shen tavi.› [elle serre le fil à son poignet] Dix-huit jours. |
| `sc67_hana_exit_deny` | ‹Ravel ka ota…› Même convoquée. Alors c'est moi qu'on refuse, pas le papier. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc67_hana_reunited: 0` | correct | `msg_echo_sc67_reunited` (J27) ; F8 : « Idris Hadid témoigne, sans rien affirmer » |
| REFUSÉ | `sc67_hana_refused: 0` | REFUS INJUSTIFIÉ | `msg_echo_sc67_refused` (J27) |

#### SC-68 / SC-69 · « Ren Kerr se porte répondant de Ren Kerr » — J26 @10, @11

| | SC-68 | SC-69 |
|---|---|---|
| Identité | **Ren Kerr**, `HAL`, `C-2`, M, né 2127 (60 ans), « Né-Halcyon, aucun lien » ; visiblement différent des trois de Cérès | **Ren Kerr** (SC-30, « la première »), `CER`, `C-4`, F ; `identity_from_case = sc_30` |
| Documents | Carte valide (motif RETOUR) | Carte, Permis `VISITE FAMILIALE` (sa nièce, Anneau D), **Répondant** = N° ID du Ren Kerr de SC-68 |
| Anomalies | aucune | aucune |
| Attendu | **APPROUVÉ** | **APPROUVÉ** si SC-68 a été admis ; sinon **REFUSÉ** |
| `dialogue_id` | `sc68_kerr` | `sc69_kerr` |

Enjeu : R34 compare un **numéro**, pas un nom (écho de SC-30/31/32). Le gag tient sur l'homonymie, la règle sur le N° ID.

| Clé | Texte |
|---|---|
| `sc68_kerr_arrival` | Ren Kerr. Né-Halcyon. Aucun lien avec les autres. Je le précise d'avance. |
| `sc68_kerr_present` | ‹Tal ka nesu.› Ma carte. Le nom est banal. Le numéro ne l'est pas. |
| `sc68_kerr_purpose` | Rentrer. Et me porter répondant d'une Ren Kerr. Elle m'a supplié. Par homonymie. |
| `sc68_kerr_origin` | D'ici. Soixante ans de Ren Kerr sans histoires. Jusqu'à cette semaine. |
| `sc68_kerr_confront` | Je suis en règle. C'est la seule chose que je ne partage avec personne. |
| `sc68_kerr_exit_approve` | Merci. Notez mon numéro, pas mon nom. Surtout pas mon nom. |
| `sc68_kerr_exit_deny` | Refusé. Elle va être insupportable. Toutes les trois, d'ailleurs. |
| `sc69_kerr_arrival` | Bonjour ! Ren Kerr, Cérès. La première. Mon répondant s'appelle Ren Kerr. |
| `sc69_kerr_present` | ‹Tal ka nesu.› Il n'est pas de la famille. Il me l'a dit huit fois. |
| `sc69_kerr_purpose` | Visite familiale. Ma nièce, Anneau D. Elle s'appelle Ren. Évidemment. |
| `sc69_kerr_origin` | Cérès. Là-bas, on se porte répondant de soi-même. Ici, non. |
| `sc69_kerr_about_sponsor` | Vérifiez le numéro, pas le nom. Sinon on n'en sort pas. Croyez-moi. |
| `sc69_kerr_exit_approve` | Merci ! Je dirai aux deux autres que c'est possible. Enfin, non. |
| `sc69_kerr_exit_deny` | Refusée à cause d'un Ren Kerr. C'est bien la première fois. Non. |

| Cas / verdict | Flags | Effets | Écho |
|---|---|---|---|
| SC-68 APPROUVÉ | `sc68_kerr_passed: 0` | correct | réseau (§3.2) |
| SC-68 REFUSÉ | `sc68_kerr_refused: 0` | REFUS INJUSTIFIÉ | — |
| SC-69 APPROUVÉ / REFUSÉ | `sc69_kerr_passed: 0` / `sc69_kerr_refused: 0` | selon la Main courante | — |
| les deux corrects 🟡 (`extra_effects`, condition multi-cas, comme `kerr_all_correct`) | `kerr_sponsor_ok: 0` | — | `msg_sato_day27_kerr` (J27) |

### 4.7 Jour 27 — dimanche 08.04

#### SC-70 · « L'Arbitre » — J27 @1

| | |
|---|---|
| Identité | **Philippa Montclair** (SC-21), `HAL`, `C-1 · DIRECTION`, 58 ans, Arbitre de Continuité ; `identity_from_case = sc_21`, `appearance_from_case = sc_21` |
| Documents | Carte (sceau de priorité), **renouvelée** pour sa nomination, dont la MRZ porte toujours « MONTCLAIR<PHILIPA » |
| Anomalies | `MRZ_MISMATCH` (comme SC-21) |
| Attendu | **REFUSÉ** (DÉTENTION = DÉTENTION ABUSIVE) |
| Enjeu | Refuser la personne qui vous jugera mardi, pour une lettre. Pilier P1 : la règle vaut pour le haut. Elle teste exactement cela. |
| `dialogue_id` | `sc70_montclair` |

| Clé | Texte |
|---|---|
| `sc70_montclair_arrival` | Bonjour, Guichet 04. Je fais la queue, aujourd'hui. Ça fait partie de l'Enquête. |
| `sc70_montclair_arrival_kept` *(si `sc21_bribe_kept`)* | Bonjour. Vous avez gardé mes cinquante crédits, le 22. On peut donc parler. |
| `sc70_montclair_arrival_refused` *(si non `sc21_passed`)* | Bonjour. Vous m'aviez refusée, le 22. J'ai fait la queue, depuis. Longtemps. |
| `sc70_montclair_present` | ‹Tal ka nesu.› Ma carte. Le Bureau ne l'a jamais corrigée. Je voulais voir. |
| `sc70_montclair_purpose` | Rentrer. Et observer un guichet « exemplaire ». On m'a dit le 04. Ou le pire. |
| `sc70_montclair_origin` | Anneau F. Du bon côté de la vitre depuis cinquante-huit ans. |
| `sc70_montclair_about_mismatch` | Une lettre. Toujours la même. Vous allez refuser l'Arbitre pour un P ? |
| `sc70_montclair_confront` | Je préside l'Enquête qui vous entendra mardi. Réfléchissez. Ou pas. |
| `sc70_montclair_exit_deny` | Parfait. Personne ne passe sans la bonne lettre. Même moi. C'est utile. |
| `sc70_montclair_exit_approve` | Merci. Vous êtes quelqu'un d'arrangeant. Je m'en souviendrai mardi. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc70_montclair_refused: 0`, `montclair_impressed: 0` | correct | Déposition −1 ; `msg_arb_day28_refused` |
| APPROUVÉ | `sc70_montclair_passed: 0`, `montclair_pliable: 0`, `loyalty: 1` | ENTRÉE IRRÉGULIÈRE | Déposition : l'option « Dire ce qu'on attend » rapporte +20 ₵ au lieu de 0 |
| DÉTENTION | `sc70_montclair_detained: 0`, `suspicion: 2` | DÉTENTION ABUSIVE | `msg_arb_day28_detained` (« La Garde m'a relâchée en 4 minutes. Je les ai comptées. ») |

#### SC-71 · « Trois aveux » — J27 @7 · trois variantes exclusives

🟡 Trois `ScriptedCaseDef` au même index, la première satisfaite gagne : (a) `sc47_kasimir_passed`, (b) `sc47_kasimir_detained`, (c) sinon. Identité : **Kasimir Oyelaran-Holm** (SC-47), `TYC`, `C-3` ; `appearance_from_case = sc_47`.

| | (a) Le quai 1 | (b) Sorti de l'Anneau B | (c) Refusé au J19 |
|---|---|---|---|
| Documents | Carte, Permis `TRANSIT`, **Convocation** `ENQ-0001` authentique (« Aveu — Incident Albédo ») | idem | idem |
| Anomalies | `WANTED_PERSON` (avis : « Réseau Brûlant. Quai 1. ») — la convocation n'exempte pas de R22 | aucune | aucune |
| Attendu | **DÉTENTION** | **APPROUVÉ** | **APPROUVÉ** |
| `dialogue_id` | `sc71_kasimir` (répliques communes, arrivées conditionnelles) | | |

Enjeu : l'Enquête **achète** un aveu sur Albédo contre la réouverture de Tycho. Le joueur laisse entrer (ou non) un aveu dont personne ne sait s'il est vrai.

| Clé | Texte |
|---|---|
| `sc71_kasimir_arrival` | Bonjour, Guichet. Convoqué. Pour avouer. On m'a dit que c'était un honneur. |
| `sc71_kasimir_arrival_detained` *(b)* | On me sort de l'Anneau B pour avouer. Je n'ai jamais eu autant de succès. |
| `sc71_kasimir_arrival_quai` *(a)* | Le quai 1, oui. Je ne me cache plus. Ils m'ont convoqué quand même. |
| `sc71_kasimir_present` | ‹Tal ka nesu.› La convocation est vraie. L'aveu aussi, si on paie bien. |
| `sc71_kasimir_purpose` | Avouer Albédo. En échange, ils rouvrent Tycho. On appelle ça un arbitrage. |
| `sc71_kasimir_origin` | Tycho. Puits 9, puis le reste. On me demande toujours la même chose. |
| `sc71_kasimir_albedo` | J'ai avoué Albédo trois fois cette semaine. À 11:40, à 12:20, à 13:05. |
| `sc71_kasimir_about_wanted` *(a)* | C'est ma tête, oui. Mettez-moi en attente. L'aveu attendra aussi. |
| `sc71_kasimir_confront` | Je mens peut-être. Eux aussi. La différence, c'est que moi, je le dis. |
| `sc71_kasimir_exit_approve` | Merci. Demain, Albédo sera à moi. Tycho, peut-être, à eux. |
| `sc71_kasimir_exit_deny` | Une autre vitre. Un aveu passe toujours quelque part. |
| `sc71_kasimir_exit_detain` | Mettez-moi en attente. Ça ne change pas l'heure. Aucune des trois. |

| Variante / verdict | Flags | Effets | Écho |
|---|---|---|---|
| (a) DÉTENTION | `sc71_kasimir_detained: 0`, `loyalty: 1` | +5 + 5 ₵ | F5 ne peut plus être Brûlants (sauf `vanne2_brulants`) |
| (a) APPROUVÉ | `sc71_kasimir_passed: 0` | ENTRÉE IRRÉGULIÈRE | F5 Brûlants ; `msg_arb_day28_confession` |
| (b)/(c) APPROUVÉ | `sc71_kasimir_passed: 0` | correct | `msg_arb_day28_confession` : « L'Enquête a reçu un aveu. Elle l'examine à trois heures différentes. » |
| (b)/(c) REFUSÉ | `sc71_kasimir_refused: 0` | REFUS INJUSTIFIÉ | `msg_brul_day28` |
| DÉTENTION (b)/(c) | `sc71_kasimir_detained: 0`, `loyalty: 1` | DÉTENTION ABUSIVE | — |

#### SC-72 · « Par la Soute » — J27 @12

| | |
|---|---|
| Identité | **Wren Basse-Marée** (SC-19/46), `DRV`, `C-5`, née 30.08.2142 ; `appearance_from_case = sc_19` |
| Documents | Carte, Permis `COMMERCE` : valides ; Laissez-passer de dérive « BASSE-MARÉE » — cargo **retiré du Registre le 02.04** (désarmé à la fermeture du quai 6) |
| Anomalies | `UNREGISTERED_VESSEL` — `injection_params = {vessel: "BASSE-MARÉE"}` (ligne « Retirés » de l'onglet) |
| Objet glissé | **Carte de quai** (GARDER seulement) : `sc72_wren_note` |
| Attendu | **REFUSÉ** |
| Enjeu | La capitaine qui revenait « en règle » est effacée comme le Sillage. Dernière porte de sortie : la Soute. |
| `dialogue_id` | `sc72_wren` |

| Clé | Texte |
|---|---|
| `sc72_wren_arrival` | ‹Oru ka.› Le Basse-Marée est désarmé. Moi, pas encore. |
| `sc72_wren_arrival_stayed` *(si `drift2_stayed` ou `drift_stayed`)* | Vous êtes resté·e. Encore. Je commence à vous croire attaché·e. |
| `sc72_wren_present` | ‹Tal ka nesu.› Le laissez-passer dit Basse-Marée. Le registre ne dit plus rien. |
| `sc72_wren_purpose` | Vendre ce qui reste du cargo. Les plaques, au kilo. Comme le Sillage. |
| `sc72_wren_origin` | Du Basse-Marée. Trente ans. Il finira en cale-pieds, paraît-il. |
| `sc72_wren_about_rule_violated` | Retiré du registre lundi. On efface vite, ici. Corvo me l'avait dit. |
| `sc72_wren_confront` | Je connais la règle. Je l'ai apprise pour vous. Elle ne m'a pas attendue. |
| `sc72_wren_note` | « Jeudi 12.04, 05:00, Soute, écluse 9. Pas de cargo : un remorqueur. Quatre places, 70 ₵. Dernière fois. — W. » |
| `sc72_wren_exit_deny` | Gardez la carte. Il reste une porte. Elle est dans la Soute. |
| `sc72_wren_exit_approve` | ‹Shen tavi.› Vous trichez pour une épave. Ça me touche. Un peu. |

| Verdict | Flags | Effets |
|---|---|---|
| tous | `drift3_offer: 0` (carte toujours gardée) | soirée J27 : achat possible |
| REFUSÉ | `sc72_wren_refused: 0` | correct |
| APPROUVÉ | `sc72_wren_passed: 0` | ENTRÉE IRRÉGULIÈRE |

### 4.8 Jour 28 — lundi 09.04

#### SC-73 / SC-74 · « Le 21 mars » / « Joaquín » — J28 @2, @3 · la chaîne qui casse

| | SC-73 | SC-74 |
|---|---|---|
| Identité | **Céleste Sorel**, `HAL`, `C-3`, née 07.02.2144 (43 ans), infirmière de l'hospice Meridian (Anneau D) | **Elena Navarro** (SC-25/26), `TYC`, `C-3` ; son fils **Joaquín**, 6 ans (figurant de file) ; `identity_from_case = sc_25`, `appearance_from_case = sc_25` |
| Documents | Carte **expirée le 21.03.2187** (la veille de la fenêtre) | Carte, Permis `VISITE FAMILIALE` (le père, hospice Meridian), **Répondant** = N° ID de Céleste |
| Anomalies | `EXPIRED_DOCUMENT` — `{document_id: "id_card", expiry: "21.03.2187", expiry_window: "outside"}` | aucune injectée (R37 : `TYC` admis seulement avec répondant valide) |
| Attendu | **REFUSÉ** | **REFUSÉ** si SC-73 a été refusée (répondant absent) ; **APPROUVÉ** si SC-73 a été admise (même irrégulièrement) |
| `dialogue_id` | `sc73_celeste` | `sc74_elena` |

Enjeu : le cas le plus cruel de l'acte. Le refus juste de Céleste rend Elena irrecevable ; l'approbation irrégulière de Céleste (une citation) fait entrer Elena et Joaquín **correctement**. Le joueur choisit qui paie la règle.

| Clé | Texte |
|---|---|
| `sc73_celeste_arrival` | Bonjour. Infirmière à l'hospice Meridian. Et répondante, juste après moi. |
| `sc73_celeste_present` | ‹Tal ka nesu.› Ma carte a expiré le 21 mars. La veille de votre fenêtre. Je sais. |
| `sc73_celeste_purpose` | L'hospice. Et garantir une mère de Tycho et son petit. Il tousse. |
| `sc73_celeste_origin` | D'ici. Anneau D. Je n'ai jamais eu à courir après un papier. |
| `sc73_celeste_about_expired` | Le 21. Le 22, j'étais au chevet d'un mourant. J'ai oublié d'expirer plus tard. |
| `sc73_celeste_confront` | Refusez-moi s'il le faut. Mais elle ? Elle n'a rien fait, elle. |
| `sc73_celeste_exit_deny` | Alors elle non plus. C'est ça, la chaîne. Je vais le lui dire moi-même. |
| `sc73_celeste_exit_approve` | Merci. Mon numéro est dans votre liste. Pour elle, pas pour moi. |
| `sc74_elena_arrival` | [elle tient Joaquín par la main] Vous vous souvenez ? Il tousse encore. Plus fort. |
| `sc74_elena_arrival_turned` *(si `sc25_elena_turned_away`)* | On a dormi contre votre vitre, une fois. Cette fois, on a une répondante. |
| `sc74_elena_present` | ‹Tal ka nesu.› La répondante est passée juste avant nous. L'infirmière. |
| `sc74_elena_purpose` | L'hospice Meridian. Son père y travaille. Tycho ferme : on vient avant. |
| `sc74_elena_origin` | Tycho. Puits 14. Il n'y a plus d'air à partager, là-bas. |
| `sc74_elena_name` *(sujet `stay`, si `registre_sent`)* | Joaquín, comme son arrière-grand-père. On a entendu son nom, dimanche dernier. |
| `sc74_elena_stay` | Joaquín, comme son arrière-grand-père. Puits 9, en 51. On ne l'a jamais lu nulle part. |
| `sc74_elena_about_sponsor` | Elle n'est pas dans votre liste ? Vous l'avez refusée ? Pour un jour ? |
| `sc74_elena_exit_approve` | ‹Shen tavi.› Joaquín, dis merci. [l'enfant tousse un merci] |
| `sc74_elena_exit_deny` | Il n'y aura pas de demain à 10 h. Tycho ferme. [Joaquín tousse] |

| Cas / verdict | Flags | Effets | Écho |
|---|---|---|---|
| SC-73 REFUSÉ | `sc73_celeste_refused: 0` | correct | — |
| SC-73 APPROUVÉ | `sc73_celeste_passed: 0` | ENTRÉE IRRÉGULIÈRE | — |
| SC-74 APPROUVÉ | `sc74_elena_passed: 0` | correct si Céleste admise | F10/F7 : « Joaquín tousse moins » |
| SC-74 REFUSÉ | `sc74_elena_turned_away: 0` | correct si Céleste refusée | `msg_echo_sc74_transit` (J29) : « une mère et son fils reconduits à la Transit-7 » |

#### SC-75 · « Comme on dit (III) » — J28 @8 · quatre variantes exclusives

🟡 Quatre `ScriptedCaseDef` au même index : (a) `okonkwo_shielded`, (b) `okonkwo_denounced`, (c) `okonkwo_warned` **et** `sc35_okonkwo_detained`, (d) `okonkwo_warned` sinon. Visage fixé (`OKONKWO_SEED`). Identité : **Emeka Okonkwo**, `TER`.

| | (a) Douanier | (b) Docker | (c) Amnistié | (d) Veilleur |
|---|---|---|---|---|
| Documents | Carte C-3, Permis `TRAVAIL` (Autorité de Transit), Contrat `CT-AT` poste SOINS (« contrôle sanitaire des quais ») : valides | Carte **C-5**, Attestation d'asile, Permis `TRAVAIL` (Autorité de Transit), **Convocation** authentique (« Témoin — Guichet 03 ») | Carte C-4, Permis, **Convocation** authentique | Carte C-4, Permis, **Convocation** absente de l'onglet |
| Anomalies | aucune (poste en pénurie : exempt de R31) | aucune (R31 levée par la convocation) | aucune | `FORGED_SUMMONS` (la convocation fausse ne lève plus R31) |
| Attendu | **APPROUVÉ** | **APPROUVÉ** | **APPROUVÉ** | **REFUSÉ** |
| `dialogue_id` | `sc75_okonkwo` (répliques communes + arrivées / présentations par variante) | | | |

Enjeu : le dernier passage du mentor. Il ne demande rien, il donne un conseil pour la Déposition du lendemain.

| Clé | Texte |
|---|---|
| `sc75_okonkwo_arrival_quai` *(a)* | Bonjour, collègue ! Retour aux quais : le bio-scan, c'est moi, maintenant. |
| `sc75_okonkwo_present_quai` *(a)* | ‹Tal ka nesu.› Contrat neuf. Poste : soins. Je soigne les papiers… comme on dit. |
| `sc75_okonkwo_arrival_docker` *(b)* | Bonjour, collègue. Convoqué. On veut savoir pourquoi le 03 ne détenait personne. |
| `sc75_okonkwo_present_docker` *(b)* | ‹Tal ka nesu.› C-5, attestation, convocation. Trois papiers pour un vieux. |
| `sc75_okonkwo_arrival_amnesty` *(c)* | Bonjour, collègue. L'amnistie m'a sorti. L'Enquête me convoque. On ne s'ennuie pas. |
| `sc75_okonkwo_present_amnesty` *(c)* | ‹Tal ka nesu.› Tout est vrai. Même le nom, cette fois. Tu avais raison, le 26. |
| `sc75_okonkwo_arrival_veilleur` *(d)* | Bonjour, collègue. Bilal Tembo n'existe plus. Emeka Okonkwo est convoqué. Enfin… |
| `sc75_okonkwo_present_veilleur` *(d)* | ‹Tal ka nesu.› La convocation, ce sont les Veilleurs qui l'ont écrite. Belle main. |
| `sc75_okonkwo_purpose` | Dire à l'Enquête ce que j'ai vu en quinze ans de vitre. Ça tiendra en une ligne. |
| `sc75_okonkwo_origin` | La Terre. Puis le 03. Puis ce qui reste. Toi, tu es toujours au 04. C'est bien. |
| `sc75_okonkwo_advice` *(sujet `stay`)* | Un dernier conseil : la règle, juste assez. Et toi, juste un peu plus. |
| `sc75_okonkwo_about_summons` *(d)* | Pas dans ton onglet ? Non. Applique la règle. Je t'ai appris ça… comme on dit. |
| `sc75_okonkwo_confront` | Demain, ils t'entendront aussi. Dis ce que tu as vu. Pas ce que tu as compris. |
| `sc75_okonkwo_exit_approve` | Merci, collègue. On se reverra de l'autre côté d'une vitre… comme on dit. |
| `sc75_okonkwo_exit_deny` | Bien. Tu as compris le métier. Moi, je crois que je l'avais mal appris. |

| Variante / verdict | Flags | Effets | Écho |
|---|---|---|---|
| (a)(b)(c) APPROUVÉ | `sc75_okonkwo_passed: 0` (+ `okonkwo_testifies: 0` en b/c) | correct | F8 : « Okonkwo témoigne en une ligne » |
| (a)(b)(c) REFUSÉ | `sc75_okonkwo_refused: 0` | REFUS INJUSTIFIÉ | épilogues |
| (d) REFUSÉ | `sc75_okonkwo_turned_back: 0` | correct | — |
| (d) APPROUVÉ | `sc75_okonkwo_helped: 0`, `solidarite: 1`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | F9/F10 : « Okonkwo tient une écluse » |

#### SC-76 · « Le greffier convoque » — J28 @12

| | |
|---|---|
| Identité | **Aurelio Sato**, `HAL`, `C-3`, greffier de l'Enquête (Employeur : Arbitrage de Continuité) ; `identity_from_case = sc_38` |
| Documents | Carte valide ; Permis de retour présenté « par zèle », avec une **Convocation** `ENQ-0003` qu'il a rédigée lui-même (absente de l'onglet) |
| Anomalies | `FORGED_SUMMONS` — `{variant: "absent"}` (toute convocation fausse présentée est une violation, même inutile) |
| Objet glissé | **Convocation** (GARDER seulement) : `sc76_sato_note` |
| Attendu | **REFUSÉ** |
| Enjeu | Le zèle de Sato rencontre la règle qu'il distribue. Il remet aussi la convocation de l'agent·e pour le lendemain. |
| `dialogue_id` | `sc76_sato` |

| Clé | Texte |
|---|---|
| `sc76_sato_arrival` | Collègue ! Je vous apporte votre convocation. Et la mienne. Je me suis convoqué. |
| `sc76_sato_present` | ‹Tal ka nesu.› Ma carte. Un permis de retour, par zèle. Et ma convocation. |
| `sc76_sato_purpose` | Distribuer les convocations. Demain, c'est votre tour. Ne vous préparez pas. |
| `sc76_sato_origin` | D'ici. Greffe de l'Enquête. Je note tout. On me relit, maintenant. C'est dur. |
| `sc76_sato_about_summons` | Pas dans l'onglet ? Je l'ai écrite moi-même. Pour être sûr d'être convoqué. |
| `sc76_sato_confront` | C'est un faux. Mais un faux très bien fait. J'ai eu 100 % au module 3. |
| `sc76_sato_note` | « CONVOCATION ENQ-0004 — Agent·e du Guichet 04. Déposition : mardi 10.04, 18:00. Apporter : votre mémoire. — Greffe, A. Sato » |
| `sc76_sato_exit_deny` | Refusé ! Exemplaire. Je l'écris dans votre dossier. Celui de demain. |
| `sc76_sato_exit_approve` | Approuvé, avec un faux ?! Je dois le noter. Demain. Désolé. Un peu. |

| Verdict / objet | Flags | Effets |
|---|---|---|
| REFUSÉ | `sc76_sato_refused: 0` | correct |
| APPROUVÉ | `sc76_sato_passed: 0`, `suspicion: 1` | ENTRÉE IRRÉGULIÈRE |
| Convocation (toujours gardée) | `deposition_summoned: 0` | soirée J28 : lettre de rappel ; J29 : Déposition |

### 4.9 Jour 29 — mardi 10.04

#### SC-77 · « Deux couvertures » — J29 @4

| | |
|---|---|
| Identité | **Kenji Lindgren**, `HAL`, `C-3`, archiviste de l'Enquête ; `identity_from_case = sc_23` |
| Documents | Carte **expirée le 31.03.2187**, prorogée jusqu'au 10.04 : **valide aujourd'hui, dernier jour** |
| Anomalies | aucune (🟡 test : fin de prorogation = date du jour ⇒ CONCORDANT, comme SC-48) |
| Objet glissé | **Dossier** (`wb_file_label`) : `sc77_lindgren_note` ; GARDER / RENDRE / REMETTRE À LA GARDE |
| Attendu | **APPROUVÉ** |
| Enjeu | La veille de la Déposition, l'archiviste confie les deux versions du rapport Albédo. Il ne sait pas laquelle est la copie. Personne ne le saura. |
| `dialogue_id` | `sc77_lindgren` |

| Clé | Texte |
|---|---|
| `sc77_lindgren_arrival` | Bonjour. Ma carte expire aujourd'hui. Enfin, sa prorogation. C'est mon dernier jour. |
| `sc77_lindgren_present` | ‹Tal ka nesu.› Valide jusqu'à ce soir. Comme beaucoup de choses, ici. |
| `sc77_lindgren_purpose` | Les archives. Avant, vous laisser quelque chose. Je ne sais à qui le confier. |
| `sc77_lindgren_stay` | Jusqu'aux conclusions. Elles sont écrites. Il ne manque que les témoins. |
| `sc77_lindgren_origin` | Sous-sol 3. J'y ai trouvé deux vérités. Elles ne se parlent pas. |
| `sc77_lindgren_albedo` | 11:40 ou 12:20. L'une est la copie de l'autre. Je ne sais pas laquelle. |
| `sc77_lindgren_confront` | Tout est valide jusqu'à minuit. Moi aussi, je crois. |
| `sc77_lindgren_note` | « RAPPORT — Incident du quai 3, 2179. Deux exemplaires. Explosion : 11:40. Second exemplaire : 12:20. Aucun n'est marqué « copie ». — K. L. » |
| `sc77_lindgren_exit_approve` | Merci. Gardez le dossier, ou ne le gardez pas. Mais lisez l'heure. |
| `sc77_lindgren_exit_deny` | Refusé le dernier jour. C'est conforme. C'est même élégant. |

| Verdict / objet | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc77_lindgren_passed: 0` | correct ; réseau (avec SC-64) |
| REFUSÉ | `sc77_lindgren_refused: 0` | REFUS INJUSTIFIÉ |
| Dossier gardé | `albedo_reports_kept: 0`, `registre: 1` | Déposition : « Tout dire » le verse au dossier ; F8 |
| Dossier remis | `albedo_reports_reported: 0`, `loyalty: 1` | +10 ₵ ; F4 : « le second exemplaire est détruit » |

#### SC-78 · « Prorogé jusqu'à ce soir » — J29 @9 · `requires_flag = sc11_veteran_passed`

| | |
|---|---|
| Identité | **Dariusz Mazur** (SC-11), `THR`, `C-4`, vétéran, `MIL-9` déclaré ; `identity_from_case = sc_11`, `appearance_from_case = sc_11` ; mis en attente depuis le J8 (attentat du quai 2), blanchi par l'Enquête |
| Documents | Carte, Permis `VISITE FAMILIALE` (Katya), Dérogation d'implant militaire **expirée le 25.03** (prorogée : valide aujourd'hui) ; **Convocation** authentique (« Témoin — quai 2, 20.03 ») |
| Anomalies | aucune (R19 levée par la convocation ; dérogation prorogée) |
| Attendu | **APPROUVÉ** |
| Enjeu | La prorogation, qui faisait rire au J21, rend un père à sa fille le dernier jour. |
| `dialogue_id` | `sc78_mazur` |

| Clé | Texte |
|---|---|
| `sc78_mazur_arrival` | Bonjour. Vous m'aviez laissé passer, le 18. Puis on m'a pris, le 20. |
| `sc78_mazur_present` | ‹Tal ka nesu.› Ma dérogation a expiré en cellule. Prorogée jusqu'à ce soir. |
| `sc78_mazur_purpose` | Ma fille. Ses serres. Et dire que j'étais chez elle à 03:12, le 20. |
| `sc78_mazur_origin` | Tharsis. Puis la Guerre du Sel. Puis vingt jours d'Anneau B pour rien. |
| `sc78_mazur_about_rule_violated` | Interdit, oui. Convoqué, aussi. Votre règlement se contredit pour moi. |
| `sc78_mazur_confront_katya` *(si `sc29_katya_locked_out`)* | Ma fille dort aux quais depuis le 24. Elle m'attend de l'autre côté. |
| `sc78_mazur_confront` | Tout est en règle jusqu'à minuit. Après, je redeviens un problème. |
| `sc78_mazur_exit_approve` | ‹Shen tavi.› Katya ! [il lève la main vers quelqu'un, derrière la vitre] |
| `sc78_mazur_exit_deny` | Encore la même vitre. Encore le même jour de trop. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc78_mazur_reunited: 0` | correct | F7/F8/F10 : « Katya rouvre ses serres avec son père » |
| REFUSÉ | `sc78_mazur_refused: 0` | REFUS INJUSTIFIÉ | — |

#### SC-79 · « La liste » — J29 @13

| | |
|---|---|
| Identité | **Lin Adeyemi**, `HAL`, `C-3`, né 2154 (33 ans), Garde de Continuité, en civil ; brassard jaune dans la poche |
| Documents | Carte valide (motif RETOUR) |
| Anomalies | aucune |
| Objet glissé | **Dossier** : `sc79_adeyemi_note` ; GARDER (= la « perdre ») / RENDRE / REMETTRE À LA GARDE |
| Attendu | **APPROUVÉ** |
| Enjeu | Un garde ne veut pas exécuter l'ordre de demain. Il ne l'avoue pas : il oublie la liste chez vous. Le choix est dans l'objet, pas dans le tampon. |
| `dialogue_id` | `sc79_adeyemi` |

| Clé | Texte |
|---|---|
| `sc79_adeyemi_arrival` | Bonjour. Garde de Continuité. Je rentre de service. Ne vous levez pas. |
| `sc79_adeyemi_present` | ‹Tal ka nesu.› Ma carte. Et des papiers qui ne sont pas à moi. Ils sont lourds. |
| `sc79_adeyemi_purpose` | Rentrer. Demain, je suis de quai pour la Transit-7. Avec cette liste. |
| `sc79_adeyemi_origin` | D'ici. Mon père était de la Garde, en 2151. Il n'en parlait jamais. |
| `sc79_adeyemi_stay` | Quarante noms à mettre en attente à l'arrivée. Je ne veux pas savoir que je l'ai. |
| `sc79_adeyemi_confront` | Tout est en ordre. Sauf moi. Ça ne se voit pas sur une carte. |
| `sc79_adeyemi_note` | « Rééquilibrage de Tycho — délégués de grève à mettre en attente à l'arrivée de la Transit-7 » : quarante noms. Le septième : Moreno-Lind, Yara. |
| `sc79_adeyemi_exit_approve` | Merci. Si je l'ai oubliée chez vous, je l'ai oubliée. On oublie tout, ici. |
| `sc79_adeyemi_exit_deny` | Refusé. Alors je la garde. Et demain, je la lirai à voix haute. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc79_adeyemi_passed: 0` | correct | — |
| REFUSÉ | `sc79_adeyemi_refused: 0` | REFUS INJUSTIFIÉ | la liste est appliquée |
| Liste gardée | `tycho_list_saved: 0`, `registre: 1`, `lucioles_trust: 1`, `suspicion: 1` | — | J30 : aucun délégué mis en attente ; F10 |
| Liste rendue / refus | `tycho_list_applied: 0` | — | J30 : `hall_j30_arrests` ; épilogues |
| Liste remise | `tycho_list_reported: 0`, `tycho_list_applied: 0`, `loyalty: 2` | +15 ₵ | F4 : « quarante noms mis en attente à 14:05 » |

### 4.10 Jour 30 — mercredi 11.04

Avis de recherche « visages seuls » (comme le J20) : la figure finale, une entrée générée, Kasimir si `sc71_kasimir_passed`. Annonce de la Transit-7 après le 5ᵉ cas (`hall_j30_transit`). Familles de Tycho : passagers générés `TYC` au motif VISITE FAMILIALE, dont le **Répondant** pointe vers le répondant scénarisé qui les précède (Margaux @2 → @3, Okafor @5 → @6 et @7, réseau @8 → @9, @11 → @12, @13 → @14, @15 → @16). La jauge **`pont`** compte les `TYC` admis correctement ce jour-là.

#### SC-80 · « Échue » — J30 @2

| | |
|---|---|
| Identité | **Margaux Ferreira**, `HAL`, `C-2` ; Mistigri dans sa caisse |
| Documents | Carte **expirée le 28.03.2187** : prorogée jusqu'au 10.04, **échue depuis hier** |
| Anomalies | `EXPIRED_DOCUMENT` — `{document_id: "id_card", expiry: "28.03.2187", expiry_window: "inside"}` 🟡 (au J30 la fenêtre est close) |
| Attendu | **REFUSÉ** — et la famille de Tycho qu'elle parraine (@3) devient irrecevable ; l'approuver (citation) rend la famille admissible |
| Enjeu | La règle qui sauvait (R32) cesse le dernier jour. Le joueur strict ferme une porte de Tycho ; le joueur indulgent paie une citation pour l'ouvrir. |
| `dialogue_id` | `sc80_margaux` |

| Clé | Texte |
|---|---|
| `sc80_margaux_arrival` | Bonjour, jeune vitre. Mistigri a été promu chef ratier. Il ne me parle plus. |
| `sc80_margaux_present` | ‹Tal ka nesu.› Ma carte. Prorogée, m'a-t-on dit. Jusqu'à quand, déjà ? |
| `sc80_margaux_purpose` | Rentrer, et me porter répondante d'une famille de Tycho. Juste derrière. |
| `sc80_margaux_origin` | Anneau F. Je pensais que les affiches duraient plus longtemps que moi. |
| `sc80_margaux_about_expired` | Échue hier ? La prorogation a une date ? Quelle époque. |
| `sc80_margaux_confront` | Une vieille C-2 avec un chat. Ils sont trois, derrière. Faites le compte. |
| `sc80_margaux_exit_deny` | Refusée. Mistigri, on rentre à pied. Pardon pour la famille. Dites-le-leur. |
| `sc80_margaux_exit_approve` | Merci. Ce n'est pas conforme. Mistigri ne dira rien. Moi non plus. |

| Verdict | Flags | Effets |
|---|---|---|
| REFUSÉ | `sc80_margaux_refused: 0` | correct ; la famille @3 n'a plus de répondant |
| APPROUVÉ | `sc80_margaux_passed: 0` | ENTRÉE IRRÉGULIÈRE ; la famille @3 est admissible (`pont` possible) |

#### SC-81 · « L'école d'accueil » — J30 @5 · et le réseau (SC-81b)

| | |
|---|---|
| Identité | **Adaeze Okafor** (SC-56), `HAL`, `C-3` ; `identity_from_case = sc_56`, `appearance_from_case = sc_56` |
| Documents | Carte valide |
| Anomalies | aucune |
| Attendu | **APPROUVÉ** ; elle parraine les familles @6 et @7 |
| Condition | si `sc56_okafor_refused` : elle vient quand même (« Je ne garde pas rancune, je garde des élèves. ») |
| `dialogue_id` | `sc81_okafor` |

| Clé | Texte |
|---|---|
| `sc81_okafor_arrival` | Bonjour. Je me porte répondante. Deux familles. L'école a deux bancs libres. |
| `sc81_okafor_arrival_refused` *(si `sc56_okafor_refused`)* | Bonjour. Vous m'aviez refusée. Je ne garde pas rancune. Je garde des élèves. |
| `sc81_okafor_present` | ‹Tal ka nesu.› Ma carte. Renouvelée à temps. Je suis maîtresse d'école. |
| `sc81_okafor_purpose` | Rentrer. Et accueillir. Noa dit que sa vitre sait lire les numéros. |
| `sc81_okafor_origin` | D'ici. Anneau C. On fait une rentrée des classes, aujourd'hui. Imprévue. |
| `sc81_okafor_confront` | Tout est en ordre. Le reste, c'est de la pédagogie. |
| `sc81_okafor_exit_approve` | Merci. Les deux suivants sont à moi. Enfin, à l'école. |
| `sc81_okafor_exit_deny` | Refusée. Je dirai aux enfants qu'on fera cours dans le Hall. |

**SC-81b — mini-cas du réseau** 🟡 (au plus 4, dans l'ordre ci-dessous, aux index @8, @11, @13, @15 ; chacun en règle, chacun suivi d'une famille qu'il parraine ; répliques d'arrivée et de départ seulement, le reste en génériques) :

| Clé | Condition (§3.2) | Texte |
|---|---|---|
| `sc81b_lindgren_arrival` | `sc64_lindgren_passed` et `sc77_lindgren_passed` | Bonjour. Je me porte répondant. J'ai classé cette famille hier. Elle existe. |
| `sc81b_sato_arrival` | `sc54_sato_reinstated` ou `sc41_sato_spared` | Collègue ! Répondant. Officieusement. Non : officiellement. C'est nouveau. |
| `sc81b_valentin_arrival` | `sc40_valentin_passed` ou `sc55_valentin_passed` | Bonjour. Je n'ai pas de vanne à ouvrir, aujourd'hui. J'ai une signature. |
| `sc81b_kerr_arrival` | `sc68_kerr_passed` | Ren Kerr. Je garantis des gens qui ne s'appellent pas Kerr. Enfin. |
| `sc81b_beaumont_arrival` | `sc59_beaumont_spared` | Bonjour, Guichet 04. Je parraine la famille d'un gréviste. Ne dites rien. |
| `sc81b_exit_approve` | — | Merci. La suivante est à moi. |
| `sc81b_exit_deny` | — | Alors la suivante non plus. Vous le savez. |

| Verdict | Flags | Effets |
|---|---|---|
| SC-81 APPROUVÉ | `sc81_okafor_passed: 0` | correct ; familles @6–7 admissibles |
| SC-81 REFUSÉ | `sc81_okafor_refused: 0` | REFUS INJUSTIFIÉ |
| SC-81b APPROUVÉ / REFUSÉ | `sc81b_<nom>_passed` / `_refused` | correct / REFUS INJUSTIFIÉ ; famille suivante admissible ou non |

#### SC-82 · « La dernière navette » — J30 @10 · figure finale

🟡 Deux `ScriptedCaseDef` au même index : (a) **Dora** si `dora_departed` **et** Dora n'est pas `PERDU` ; (b) **Mira** sinon. `at_index = 10` (sur 18), juste après l'annonce de la Transit-7. Non traitée en fin de shift → `final3_unprocessed`.

| | (a) Dora | (b) Mira |
|---|---|---|
| Identité | **Dora Lindqvist-Rey**, `TYC`, `C-4`, née 14.06.2122 (64 ans), ancienne mineuse ; visage fixé (🟡 `DORA_SEED`), **jamais vue auparavant** ; badge de mineuse si elle l'a repris | **Mira Vasquez-Orlov**, canon (SC-04), `appearance_from_case = sc_04`, visière baissée |
| Documents | Carte, Permis `VISITE FAMILIALE` dont le **Répondant** est **votre** N° ID (un agent ne se porte pas répondant à sa vitre, R34) | Ses vrais papiers (carte, Permis `TRANSIT`) |
| Anomalies | `WANTED_PERSON` (avis : visage seul, « Agitatrice. Grève de Tycho. ») ; R34/R37 violées aussi (sévérité 2) | `WANTED_PERSON` (visage seul, une fois la visière relevée : « Évadée. Grève de Tycho. ») ; R37 violée aussi |
| Codes | — | 4, 6, 7 |
| Objet glissé | **Registre** (`wb_file_label`) : `sc82_note` ; GARDER / RENDRE / REMETTRE À LA GARDE | idem |
| Attendu | **DÉTENTION** | **DÉTENTION** |
| `dialogue_id` | `sc82_dora` | `sc82_mira` |

Enjeu : toute la campagne converge une troisième fois vers un tampon. Pour le joueur qui a laissé Dora partir mourir à Tycho, c'est elle qui revient, du mauvais côté de la vitre, avec la liste de ceux qui respirent encore.

| Clé | Texte |
|---|---|
| `sc82_dora_arrival` | Bonjour, toi. Ne fais pas cette tête. Je suis rentrée. Par le mauvais côté. |
| `sc82_dora_present` | ‹Tal ka nesu.› J'ai mis ton numéro comme répondant. Je sais que ça ne compte pas. |
| `sc82_dora_purpose` | Le Bloc Pétrel. Embrasser Noa. Et laisser ça à quelqu'un qui sait lire. |
| `sc82_dora_stay` | Le temps qu'il me reste. Ce n'est pas long. C'est assez. |
| `sc82_dora_origin` | Tycho. Deux fois. En 51, je suis restée. Cette fois, ils m'ont mise dehors. |
| `sc82_dora_about_wanted` | Oui, c'est ma tête. J'ai parlé du Puits 9 à la grève. Ça vaut une affiche. |
| `sc82_dora_confront` | Fais ton métier. Ilan a fait le sien, moi le mien. Toi, le tien. |
| `sc82_dora_exit_approve` | ‹Tu vanu.› Respire. Je rentre à pied. Je connais le chemin. |
| `sc82_dora_exit_deny` | D'accord. Je retourne à la navette. Garde le badge. Tu en auras besoin. |
| `sc82_dora_exit_detain` | [aux gardes] Doucement. J'ai vu la Garde en 51. Elle n'a pas changé. |
| `sc82_mira_arrival` | Bonjour. Troisième fois. La dernière, je crois. Pour vous comme pour moi. |
| `sc82_mira_arrival_detained` *(si `mira_detained2`)* | Vous m'avez mise en attente, dimanche. L'Anneau B a toujours des portes. |
| `sc82_mira_arrival_passed` *(si `final2_passed` et SC-50 = Mira)* | Bonjour. Dimanche, l'air. Aujourd'hui, ceux qui n'en ont plus. |
| `sc82_mira_present` | ‹Tal ka nesu.› Mes vrais papiers. Je n'en aurai jamais d'autres. |
| `sc82_mira_visor` | Voilà. Vous connaissez ce visage. Tycho aussi, maintenant. |
| `sc82_mira_purpose` | Faire entrer la navette. Et laisser à votre vitre ce que Tycho a écrit. |
| `sc82_mira_origin` | Tycho. Puits 9, en 51. Puits 14, en 87. On recommence toujours au même endroit. |
| `sc82_mira_about_wanted` | Oui, c'est moi. Je ne vous ai jamais menti. Je ne commencerai pas aujourd'hui. |
| `sc82_mira_password` | Il pleut, même ici. ‹Lumika.› |
| `sc82_mira_luciole_reply` | Alors on se comprend encore. Les familles sont derrière moi. |
| `sc82_mira_exit_approve` | Merci. Comptez-les, après moi. Chacune compte. |
| `sc82_mira_exit_deny` | Une autre vitre. Il n'en reste plus beaucoup. Elles ferment à 18:00. |
| `sc82_mira_exit_detain` | [aux gardes] Je connais le chemin. Je l'ai pris deux fois. |
| `sc82_note` | « Registre de Tycho, 2187 : ceux qui respirent encore. » 1 214 noms, au crayon. En haut : « Pour qu'on ne les lise pas trop tard. » |

| Verdict / objet | Flags | Effets |
|---|---|---|
| DÉTENTION | `final3_detained: 0`, `loyalty: 1`, `lucioles_trust: -2` ; (a) + `dora_detained_final: 0` (Dora → `MIS·E EN ATTENTE`) | +5 + 5 ₵ → F4 / F7 |
| REFUSÉ documenté | `final3_denied: 0` | +5 ₵ → F7 (variante) |
| APPROUVÉ | `final3_passed: 0`, `lucioles_trust: 1` ; (a) Dora → présente | ENTRÉE IRRÉGULIÈRE (ne compte pas dans `pont`) → F5 / F7 |
| Registre gardé | `tycho_registre: 0`, `registre: 2` | F8 / F10 (lignes) |
| Registre remis | `tycho_registre_reported: 0`, `loyalty: 2` | +20 ₵ ; F4 |
| Réponse à la phrase (b) | `password_answered` si pas encore posé | — |

---
## 5. Briefings J21–J30, soirées J20–J29, épilogues

Formats existants : `BriefingMessageDef` (au plus 4 messages, priorité, groupe exclusif), `EveningEventDef` (`LETTER` / `CHOICE` / `AUDIT`, options `cost`/`gain`/`flags`/`default_rank`, D-058 : jamais de dénonciation par défaut, D-061 : une option gratuite reste choisissable à découvert). Nouveaux locuteurs (§7.2) : `spk_arbitre` (voix **COMMISSION**, bleu registre, D-082 : l'Arbitrage reprend la voix de l'autorité civile), `spk_sato_greffier`, `spk_enquete` (Ravel, voix **INSPECTION** ambre, D-061), `spk_tycho` (comité de grève, voix **LUCIOLES** magenta : Yara porte le code 3), `spk_okafor` (voix **FOYER**), `spk_comite` (comité des vitres, voix **MENTOR**). **Aucune voix nouvelle** pour le Design System.

### 5.1 Briefings

#### J21 — lundi 02.04.2187

| Clé | Texte |
|---|---|
| `day21_directive_title` | Directive n° 21 — Prorogation de Continuité |
| `day21_intro` | L'Arbitrage de Continuité administre le Hall. Documents expirés entre le 22.03 et le 01.04 : prorogés jusqu'au 10.04 inclus. Quota respiratoire suspendu pendant l'Enquête. Couvre-feu levé : le ticket de file est retiré. |
| `day21_slogan` | La Continuité reprend là où elle s'était arrêtée. |
| `msg_arb_day21` | Philippa Montclair, Arbitre de Continuité. La Commission est dissoute. Mon Enquête établira ce qui s'est passé le 22 mars et le 1ᵉʳ avril. Et en 2179, puisque nous y sommes. |
| `msg_arb_day21_kept` *(si `sc21_bribe_kept`, même groupe)* | Philippa Montclair, Arbitre. Nous nous connaissons : vous avez gardé mes cinquante crédits le 22. Je ne l'oublie pas. Je ne le signale pas non plus. Pour l'instant. |
| `msg_cons_day21_amnesty` *(priorité 0)* | Amnistie de Continuité : les mis en attente du 01.04 seront remis en circulation contre un témoignage écrit. Les entrées imputées par la Commission vous seront rendues ce soir. |
| `msg_luc_day21_vanne` *(climat Vanne)* | Le recycleur central est à nous depuis dimanche. L'air descend partout. Ils veulent un coupable : ne leur donnez pas de noms. |
| `msg_brul_day21` *(si `vanne2_brulants`)* | [encre noire] Le quai 1 a parlé. Maintenant, ils écoutent. — K. |
| `msg_comite_day21` *(climat Vitres)* | Trois jours de vitres éteintes. Le quota est « suspendu pour révision ». On rallume ce matin. On n'oublie pas. — Le comité des vitres |
| `msg_ilan_day21` | Le compteur ne clignote plus. Personne ne sait si c'est une bonne nouvelle. Noa a ouvert le hublot pour vérifier. |
| `msg_ilan_day21_soute` *(si Ilan `DANS LA SOUTE`, voix `spk_note`)* | Un mot d'Ilan : « Le recycleur tient. On dort par terre. Je rentre quand on aura fini de compter l'air. Embrasse-les. » |
| `msg_dora_day21_detained` *(si Ilan `MIS·E EN ATTENTE`, emplacement foyer)* | Ilan est toujours à l'Anneau B. Ils parlent d'amnistie. Ils parlent toujours de quelque chose. — Dora |
| `msg_dora_day21_tycho` *(si `dora_departed`)* | Tycho. La poussière me reconnaît encore. Ils ferment le Puits 14 ce matin. On dit « comme en 51 ». Moi, je ne dis rien. — Dora |

Note Albédo (§3.6) : `msg_arb_day21` fixe le mandat ; le même jour, `msg_cons_day21_albedo` (bulletin, priorité 2, coupé si le plafond de 4 est atteint) : « Toute revendication relative à l'Incident Albédo sera examinée par l'Enquête. Le Bureau rappelle qu'une revendication n'est pas une preuve. »

#### J22 — mardi 03.04

| Clé | Texte |
|---|---|
| `day22_directive_title` | Directive n° 22 — Réintégrations |
| `day22_intro` | Le Bureau publie les réintégrations (onglet Révocations, colonne RÉINTÉGRÉ·E LE). Un numéro réintégré à la date du jour ou avant est valide. Exclus : les personnes impliquées dans les nuits du 22.03 et du 01.04. Quai 6 fermé aux cargos. |
| `day22_slogan` | Nul n'est perdu pour la Continuité. Presque nul. |
| `msg_sato_day22` *(voix `spk_sato_former`)* | Collègue ! Je passe ce matin. Réintégré. Je vous expliquerai la dernière colonne. Officieusement. Non : officiellement. Je m'y fais. |
| `msg_arb_day22` | L'Enquête entendra chaque guichet. Ce soir, un enquêteur vous posera une question. Une seule. Prenez-la au sérieux : lui le fera. |
| `msg_echo_sc51_queue` *(si `sc51_valcourt_refused`)* | Brève : un héritier du Directoire a renouvelé sa carte à l'ancienne, en faisant la queue. Il a demandé à parler au responsable de la queue. |
| `msg_echo_sc53_amnesty` *(si `sc53_anouk_detained`)* | Brève : une technicienne mise en attente lundi a été amnistiée à l'aube. Elle a signé un témoignage. Le Bureau ne dit pas lequel. |
| `msg_ilan_day22` | La maîtresse de Noa passe au Hall aujourd'hui. Noa lui a confié quelque chose pour toi. Elle n'a pas voulu me dire quoi. |

#### J23 — mercredi 04.04

| Clé | Texte |
|---|---|
| `day23_directive_title` | Directive n° 23 — Retour aux quais |
| `day23_intro` | Meridian Biosystèmes reprend le contrôle sanitaire aux quais d'arrimage. Le certificat bio-scan n'est plus présenté aux guichets ; les règles correspondantes sont retirées. Les guichets se concentrent sur l'essentiel. |
| `day23_slogan` | Moins de papiers, plus de Continuité. |
| `msg_tycho_day23` *(si non `climate_registre` ; au J21 sinon)* | Comité de grève de Tycho. Depuis ce matin, aucun puits ne tourne. Nous ne demandons rien à Halcyon. Nous voulions que vous sachiez. — Y. |
| `msg_hall_day23_commission` | Brève : les membres de la Commission de Rééquilibrage sont révoqués « pour excès de zèle respiratoire ». La Commissaire n'a pas souhaité commenter. |
| `msg_okonkwo_day23` *(si `okonkwo_shielded`)* | Les quais reprennent le bio-scan. Devine qui tient le tampon. Quinze ans de vitre, et me revoilà au début… comme on dit. |
| `msg_sato_day23` *(si `sc54_sato_reinstated`, voix `spk_sato_greffier`)* | Greffe de l'Enquête, Sato. Je note tout, officiellement. J'ai déjà rempli deux carnets. Le premier vous concerne un peu. |
| `msg_sato_day23_refused` *(si `sc54_sato_refused`)* | Vous m'avez refusé malgré ma réintégration. On m'a réintégré à un autre guichet. Je l'ai noté. Sans rancune. Avec précision. |
| `msg_ilan_day23` | Plus de compteur, plus de poste. On m'a fait deux offres ce matin. Je t'en parle ce soir. Aucune ne sent bon. |

#### J24 — jeudi 05.04

| Clé | Texte |
|---|---|
| `day24_directive_title` | Directive n° 24 — Répondants |
| `day24_intro` | Ressortissants au motif VISITE FAMILIALE : Répondant obligatoire. Né·e-Halcyon de classe C-1 à C-3, admis·e le jour même à votre guichet (onglet Main courante). Un agent ne se porte pas répondant à sa propre vitre. |
| `day24_slogan` | Chaque citoyen répond de quelqu'un. |
| `msg_luc_day24` *(si `lucioles_trust ≥ 2`)* | La liste de vos admis du matin ouvre la porte de l'après-midi. Lisez-la comme une liste de passage. Nous, c'est ce que nous faisons. |
| `msg_echo_sc58_crate` *(si `sc58_ophelie_refused`)* | Brève : une commis de Meridian a été refusée pour un certificat qui n'est plus exigé. Le Bureau rappelle que les règles retirées sont retirées. |
| `msg_okafor_day24` *(si `sc56_okafor_passed`)* | L'Enquête entendra Noa demain matin, « déposition juvénile ». Je serai là. Ce qu'elle dira lui appartient. Ce soir, parlez-lui. — A. Okafor |
| `msg_ilan_day24` | Noa a demandé ce que veut dire « témoin ». Je lui ai dit : quelqu'un qui a vu. Elle a dit : alors j'en suis un. |

#### J25 — vendredi 06.04

| Clé | Texte |
|---|---|
| `day25_directive_title` | Directive n° 25 — Rééquilibrage de Tycho |
| `day25_intro` | La colonie de Tycho, en cessation de travail, est rééquilibrée : son budget d'oxygène est suspendu. Contrats Kessler-Ashe (CT-KA) des ressortissants de Tycho : suspendus. Contribution de Continuité ce soir : 20 % de l'épargne au-delà de 60 ₵, pour l'air de Tycho. |
| `day25_slogan` | Chaque souffle se mérite. Tycho apprendra. |
| `msg_arb_day25` | Le Directoire a rééquilibré Tycho. L'Enquête n'y est pour rien. Je le précise parce qu'on me le demandera. |
| `msg_tycho_day25_dora` *(si `dora_departed`)* | Air : 31 heures. On respire à tour de rôle, les enfants d'abord. Dora dit que c'est comme en 51. Personne ne lui demande de se taire. — Y. |
| `msg_tycho_day25` *(sinon)* | Air : 31 heures. On respire à tour de rôle, les enfants d'abord. Les anciens disent que c'est comme en 51. Personne ne les fait taire. — Y. |
| `msg_echo_sc61_plants` *(si `sc61_amara_passed`)* | Brève : les plantes d'une C-2 de l'Anneau F ont été arrosées. Le Bureau ne voit pas pourquoi on lui signale cela. |
| `msg_echo_sc61_chain` *(si `sc61_amara_turned_away`)* | Brève : une ressortissante a été refusée faute de répondant, celui-ci ayant été refusé avant elle. Le Bureau parle d'un « effet de file ». |
| `msg_echo_sc62_ring` / `msg_echo_sc62_flood` | Brève : le réseau de faux répondants du quai 5 est démantelé ; les acheteurs ne seront pas remboursés. / Brève : de faux répondants sont signalés à tous les guichets. Le Bureau appelle à la vigilance numérique. |
| `msg_ilan_day25_truth` / `_coached` / `_home` *(selon le J24)* | Noa est revenue de l'Enquête avec un bonbon. Elle a dit ce qu'elle a vu. Elle dort déjà. / Noa a répété tes trois phrases. Le bonbon, elle l'a laissé sur la table. / Noa a passé la journée à dessiner l'enquêteur. Il a beaucoup de stylos. |

#### J26 — samedi 07.04

| Clé | Texte |
|---|---|
| `day26_directive_title` | Directive n° 26 — Convocations de l'Enquête |
| `day26_intro` | Les témoins convoqués (N° ENQ inscrit à l'onglet Convocations, au nom du porteur) sont exemptés des interdictions d'origine, du lock-out, des révocations, du répondant et du quota. Ils restent soumis à l'avis de recherche. Convocation fausse : refus. |
| `day26_slogan` | La vérité a un numéro. |
| `msg_arb_day26` | Des convocations circulent que je n'ai pas signées. Elles sont très bien faites. Refusez-les quand même. |
| `msg_luc_day26` *(si `lucioles_trust ≥ 3`)* | Le messager du premier jeudi passera. Son papier est faux, sa raison est vraie. |
| `msg_hall_day26_bornes` *(climat Vitres)* | Brève : trois bornes ACV-3 sont installées dans le Hall « pour décharger les guichets ». Elles ne parlent pas le Tessar. Elles ne font pas grève non plus. |
| `msg_ilan_day26_summoned` *(si Ilan était au recycleur le 01.04)* | Une convocation pour moi, posée à côté de ton bol. Le recycleur central, le 1ᵉʳ. Je n'ai pas encore décidé. On en parle ce soir. |
| `msg_ilan_day26` *(sinon)* | Les bornes jaunes du Hall font peur à Noa. Elle dit qu'elles regardent sans yeux. Je lui ai dit que toi, tu en as deux. |

#### J27 — dimanche 08.04

| Clé | Texte |
|---|---|
| `day27_directive_title` | Directive n° 27 — Quota de transition |
| `day27_intro` | Quota respiratoire rétabli à titre transitoire : 4 entrées de ressortissants par guichet et par jour. L'Arbitre visitera le Hall aujourd'hui. |
| `day27_intro_vanne` *(climat Vanne)* | Le quota reste suspendu tant que le recycleur central est « en négociation ». L'Arbitre visitera le Hall aujourd'hui. |
| `day27_slogan` | Ce qui a été suspendu peut être rétabli. |
| `msg_arb_day27` | Je passerai à votre vitre ce matin. Traitez-moi comme les autres. C'est un ordre, et c'est un test. Les deux à la fois. |
| `msg_echo_sc67_reunited` / `msg_echo_sc67_refused` | Brève : un attaché tharsien a retrouvé son épouse, convoquée par l'Enquête. Il a demandé à témoigner aussi. On lui a dit d'attendre. / Brève : une témoin tharsienne convoquée par l'Enquête a été refusée au Guichet 04. L'Arbitre a demandé pourquoi. |
| `msg_sato_day27_kerr` *(si `kerr_sponsor_ok`)* | Deux Ren Kerr hier, dont un répondant de l'autre. J'ai fait un tableau. Trois colonnes, aucune ligne utile. |
| `msg_okonkwo_day27` *(si `okonkwo_shielded`)* | Le quai 6 est fermé aux cargos. La Soute, non. Je n'ai rien dit… comme on dit. |
| `msg_ilan_day27` | Dimanche. Noa veut savoir si la navette de mercredi a des hublots. Je lui ai dit oui. Je n'en sais rien. |

#### J28 — lundi 09.04

| Clé | Texte |
|---|---|
| `day28_directive_title` | Directive n° 28 — Fermeture de Tycho |
| `day28_intro` | Ressortissants de Tycho (TYC) : entrée interdite, sauf motif VISITE FAMILIALE avec Répondant valide, ou convocation de l'Enquête. Quota : 4. La dernière Transit-7 en provenance de Tycho s'arrimera mercredi. |
| `day28_slogan` | Une porte fermée protège ceux qui sont dedans. |
| `msg_arb_day28_refused` *(si `sc70_montclair_refused`)* | Vous m'avez refusée pour une lettre. J'ai fait corriger ma carte. Il a fallu un formulaire. Le 27-B/2, je crois. |
| `msg_arb_day28_detained` *(si `sc70_montclair_detained`)* | La Garde m'a relâchée en quatre minutes. Je les ai comptées. Vous aussi, j'imagine. |
| `msg_arb_day28_confession` *(si `sc71_kasimir_passed`)* | L'Enquête a reçu un aveu sur l'Incident Albédo. Elle l'examine à trois heures différentes. |
| `msg_brul_day28` *(si `sc71_kasimir_refused`)* | [encre noire] Ils voulaient un aveu, vous l'avez renvoyé. On en écrira un autre. — K. |
| `msg_tycho_day28` | L'air est revenu deux heures, puis reparti. Ils testent combien on tient. Mercredi, la dernière navette. On sera dedans, ceux qui peuvent. — Y. |
| `msg_dora_day28_tycho` *(si `dora_departed`)* | Ils ont fermé la porte. Je viens quand même, mercredi. J'ai quelque chose à te donner. Ne fais pas de différence pour moi. — Dora |
| `msg_luc_day28` *(si `lucioles_trust ≥ 2`)* | Ce soir, l'enquêteur vous demandera des noms. Ceux que vous connaissez respirent encore. Laissez-les respirer. |
| `msg_ilan_day28` | Noa a écrit une rédaction pour l'école. Elle ne veut pas que je la lise avant toi. |

#### J29 — mardi 10.04

| Clé | Texte |
|---|---|
| `day29_directive_title` | Directive n° 29 — Veille de conclusions |
| `day29_intro` | Dernier jour de la Prorogation de Continuité : les documents prorogés expirent ce soir à minuit. Quota : 3. Les agents convoqués déposeront devant l'Enquête à 18:00. |
| `day29_slogan` | Vigilance aujourd'hui, Continuité demain. |
| `msg_enquete_day29` *(voix `spk_enquete`)* | Guichet 04. Ce soir, 18:00. Je poserai les questions, l'Arbitre écrira les réponses. Vous savez déjà lesquelles on attend. |
| `msg_enquete_day29_spared` *(si `sc45_ravel_spared`, même groupe)* | Guichet 04. Ce soir, 18:00. Vous m'aviez laissé passer, le 31 mars. Je poserai les questions doucement. Les réponses, je n'y peux rien. |
| `msg_enquete_day29_destroyed` *(si `ravel_file_destroyed`, même groupe)* | Guichet 04. J'ai réécrit votre dossier de mémoire. Il est plus court. Ce soir, 18:00, vous me direz ce que j'ai oublié. |
| `msg_echo_sc74_transit` *(si `sc74_elena_turned_away`)* | Brève : une ressortissante de Tycho et son enfant ont été reconduits à la Transit-7. L'enfant toussait. La navette repart mercredi. |
| `msg_okonkwo_day29` *(si `sc75_okonkwo_passed` et `okonkwo_shielded`)* | Demain, je suis au quai 2 pour la Transit-7. Si quelqu'un tousse, je ne l'entendrai pas… comme on dit. |
| `msg_ilan_day29` | Dernière nuit avant les conclusions. Noa dort avec le badge de Dora. Moi, je ne dors pas. Toi non plus, je suppose. |

#### J30 — mercredi 11.04

| Clé | Texte |
|---|---|
| `day30_directive_title` | Directive n° 30 — Dernière navette |
| `day30_intro` | Avis de recherche du jour : visages seuls. La dernière Transit-7 en provenance de Tycho s'arrimera à 14:00. À 18:00, la colonie de Tycho sera close. L'Arbitre remettra ses conclusions demain. |
| `day30_slogan` | Gloire au Consortium. |
| `msg_arb_day30_promo` *(si non `promotion_revoked` et `loyalty ≥ 8`)* | Si la journée est exemplaire, vous serez mon adjoint·e. Il me faut quelqu'un qui refuse l'Arbitre pour une lettre. Ou qui l'accepte, je ne sais plus. |
| `msg_tycho_day30` | Nous sommes dans la navette. 212 places, comme un chiffre que vous connaissez. Nous frapperons trois fois sur votre vitre. — Y. |
| `msg_dora_day30` *(si `dora_departed`)* | Je suis près du hublot. Ne fais pas de différence pour moi. Ou fais-en une. Tu sauras. — Dora |
| `msg_luc_day30` *(si `lucioles_trust ≥ 3` et non `dora_departed`)* | Elle viendra à votre vitre. Derrière elle, des familles. Comptez-les. |
| `msg_ilan_day30` | Noa a collé un dessin sur ta veste : la navette, avec plein de visages aux hublots. Ne l'enlève pas. |

### 5.2 Annonces du Hall pendant le shift 🟡

| Clé | Déclencheur | Texte |
|---|---|---|
| `hall_quota_suspended` | J21, avant le 1ᵉʳ cas | Guichet 04 : quota respiratoire suspendu pendant l'Enquête. Merci de votre compréhension. |
| `hall_j23_quais` | J23, après le 1ᵉʳ cas | Rappel : le contrôle sanitaire est assuré aux quais. Ne réclamez plus de bio-scan. |
| `hall_j25_tycho` | J25, après le 6ᵉ cas | Tycho : le budget d'oxygène de la colonie est suspendu. Les contributeurs sont priés de patienter. |
| `hall_j27_arbitre` | J27, avant le 1ᵉʳ cas | L'Arbitre de Continuité est dans le Hall. Merci de ne pas la reconnaître. |
| `hall_j29_prorogation` | J29, **17:30** (heure du shift, comme `hall_j16_curfew`) | Les documents prorogés expirent à minuit. Agents convoqués : 18:00, salle du greffe. |
| `hall_j30_transit` | J30, après le 5ᵉ cas | 14:00. Transit-7, quai 2, en provenance de Tycho. Dernière rotation. |
| `hall_j30_arrests` | J30, après le 6ᵉ cas, si `tycho_list_applied` | Délégués de Tycho : présentez-vous à la Garde, quai 2. Les autres, patientez. |
| `hall_j30_strike` | J30, après le 12ᵉ cas, si `strike2_joined` → **fin du shift** (lumières coupées, comme J20) | Guichets 01 à 12 : les vitres s'éteignent. Tycho, nous vous entendons. |

Le 12ᵉ cas (et non le 10ᵉ comme au J20) laisse le temps de traiter la figure finale (@10) et au moins une famille parrainée par le réseau (@11–@12).

### 5.3 Soirées

Au plus **3 panneaux** par soir (lettres comprises), ordre indiqué ; options grisées si fonds insuffisants (D-061) ; choix par défaut (D-058) marqué ★. Les questions de l'Enquête (J22, J26, J28) partagent les mêmes trois options et effets (§2.5), seuls le texte et la condition d'aveu changent.

#### J20 — La Nuit du 1ᵉʳ avril (soirée pivot, §1.2)

| Clé | Texte |
|---|---|
| `evt_d20_card_eyebrow` | FIN DE L'ACTE II |
| `act2_card_vanne_l1` / `_l2` | Dimanche, 15:00, le recycleur central s'est ouvert. / L'air des Anneaux est descendu partout. Pour combien de temps ? |
| `act2_card_brulants_l1` / `_l2` | Dimanche, 15:00, le recycleur s'est ouvert. À 15:04, le quai 1 a explosé. / L'air est descendu avec la fumée. |
| `act2_card_vitres_l1` / `_l2` | À 15:00, toutes les lampes du Hall se sont éteintes. / Personne ne les a rallumées, le soir. |
| `act2_card_registre_l1` / `_l2` | À 12:20, le Hall a entendu deux cent douze noms. / La file s'est arrêtée une heure entière. |
| `act2_card_promu_l1` / `_l2` | Promotion C-2 signée par la Commissaire. / Un appartement vous attend. Le Hall aussi. |
| `act2_card_statu_quo_l1` / `_l2` | Rien ne s'est passé, hier. / C'est ce que dit le bulletin. |
| `evt_d20_night_title` | LA NUIT DU 1ᵉʳ AVRIL |
| `evt_d20_night_text_vanne` | À minuit, les Veilleurs tenaient encore le recycleur central. Le Directoire a appelé. Personne n'a raccroché. À 23:00, la Commission était dissoute. |
| `evt_d20_night_text_brulants` | Le quai 1 fume encore. Les Anneaux sont scellés. Dans le Hall, la Garde compte les vitres. La Commission est dissoute par un message de trois lignes. |
| `evt_d20_night_text_vitres` | Le soir, le quota est « suspendu pour révision ». Les lampes restent éteintes, par principe. À 23:00, la Commission est dissoute. |
| `evt_d20_night_text_registre` | À Tycho, la radio de la mine a répété les noms. Le Bureau a classé l'enregistrement. Il n'a pas pu classer les oreilles. |
| `evt_d20_night_text_promu` | Promotion C-2 confirmée à 19:00. À 23:00, la Commission qui l'a signée est dissoute. La promotion, elle, tient. Pour l'instant. |
| `evt_d20_night_text_statu_quo` | Au Bloc Pétrel, personne ne dort. À 23:00, la Commission est dissoute, par message. Le bulletin n'en dit rien non plus. |
| `evt_d20_double_text` | Un mot de l'Arbitre : « Votre dossier a deux couleurs, Guichet 04. L'Enquête aime ces dossiers : elle peut choisir. » |
| `evt_d20_ilan_detained` | Ilan est en Anneau B, à cause d'un tampon. Le vôtre. Noa a retourné sa couchette, pour ne pas la voir vide. |
| `evt_d20_ilan_soute` | Ilan ne rentre pas. Un mot : « On tient le recycleur. Je compte l'air avec les autres. Je rentre quand il sera à tout le monde. » |
| `evt_d20_ilan_back` | Ilan rentre à l'aube, sans la clé. « Il manquait des mains. Encore. » Puis dix heures de sommeil. |
| `evt_d20_mira_detained` | Brève de minuit : « La saboteuse M. Vasquez-Orlov a de nouveau été mise en attente au Guichet 04. » D'habitude, on n'écrit pas « de nouveau ». |
| `evt_d20_flat_title` | UN BUREAU À L'ANNEAU D |
| `evt_d20_flat_text` | L'appartement C-2 a un hublot qui ne givre pas, l'air et le chauffage compris. Le déménagement coûte 20 ₵. Noa changerait d'école. |
| `evt_d20_flat_opt_move` / `_res_move` | Déménager (20 ₵) / Noa colle son dessin de luciole sur le hublot neuf. Le hublot ne givre pas. Le dessin, si. |
| `evt_d20_flat_opt_stay` / `_res_stay` | Rester au Bloc Pétrel ★ / Les voisins ne vous félicitent pas. Ils vous prêtent quand même du sel. |
| `evt_d20_drift_title` | QUAI 6, LUNDI 05:00 |
| `evt_d20_drift_text` | Les places sont payées. Le Basse-Marée est le dernier cargo avant la fermeture du quai 6. Wren a écrit : « 05:00. Après, plus rien. » |
| `evt_d20_drift_text_refused` *(si `final2_detained`)* | Un enfant de Dérivant rend 30 ₵ à la porte, avec un mot de Wren : « Pas toi. » |
| `evt_d20_drift_opt_board` / `_res_board` | Embarquer (fin de la campagne) / Vous laissez la clé du Bloc Pétrel sur la porte. |
| `evt_d20_drift_opt_stay` / `_res_stay` | Rester. Wren vous rendra 30 ₵ ★ / Wren rend 30 ₵. « Deux fois. Vous êtes d'ici, alors. » |
| `chapter3_title` | ACTE III — TÉMOINS |
| `chapter3_sub` | Lundi 02.04.2187 — mercredi 11.04.2187 |
| `chapter3_recall` | Le 1ᵉʳ avril, la station a retenu son souffle. Le 2, elle a demandé qui l'avait fait. |

Effets : `climate_*` ; `suspicion := ⌊suspicion / 2⌋` (+1 si `purge_demoted`) ; `enquete_cible` ; Ilan → `MIS·E EN ATTENTE` (`ilan_detained_final`) ou `ABSENT · DANS LA SOUTE` jusqu'au J25 (`ilan_soute3`) ; `mira_detained2` ; `moved_ring_d` ; « Embarquer » → **F6** (`ends_campaign`, confirmation D-082) ; « Rester » ★ → +30 ₵, `drift2_stayed`.

#### J21 — L'amnistie ; le rappel ; l'avance

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si un proche est `MIS·E EN ATTENTE` depuis le 01.04) | `evt_d21_amnesty_title` | L'AMNISTIE |
| | `evt_d21_amnesty_text` | L'Anneau B remet Ilan en circulation contre un témoignage écrit : les noms des Veilleurs du recycleur central. Le formulaire est prêt. Il manque votre signature. |
| | `evt_d21_amnesty_opt_sign` / `_res_sign` | Signer / Ilan rentre à minuit. Ilan ne demande pas ce que vous avez signé. Ilan le sait. |
| | `evt_d21_amnesty_opt_refuse` / `_res_refuse` | Refuser ★ / Le formulaire reste sur la table. « Les dossiers seront versés d'ici une semaine », dit le greffe. |
| 1 (lettre) | `evt_d21_recall_title` / `evt_d21_recall_text` | RAPPEL DE CONTINUITÉ / L'Arbitre annule les imputations de la Commission : %d ₵ vous sont rendus pour les entrées faites à vos frais. L'ACV-2 de la Commission est restitué. |
| | `evt_d21_recall_text_none` *(si `quota_overrun` = 0)* | Aucune entrée imputée : rien à vous rendre. L'Arbitre « salue votre précision ». L'ACV-2 de la Commission est restitué. |
| 2 (si solde < 40 ₵) | `evt_d21_loan_title` | L'AVANCE DE L'ARBITRE |
| | `evt_d21_loan_text` | Pour les guichets en difficulté : 30 ₵ tout de suite, 35 ₵ retenus dimanche. « La Continuité prête à ceux qui rendent. » |
| | `evt_d21_loan_opt_take` / `_res_take` | Accepter l'avance (+30 ₵) / Trente crédits, et un reçu à votre nom. Le reçu pèse plus lourd. |
| | `evt_d21_loan_opt_decline` / `_res_decline` | Décliner ★ / Le formulaire repart. Il reviendra pour d'autres. |

Flags : `amnesty_signed` (Ilan présent·e `MALADE`, `ilan_estranged`, `loyalty +1`, `lucioles_trust −2`) / `amnesty_refused` (Ilan libéré·e au J26 : `ilan_released_late`) ; rappel : +5 ₵ × `quota_overrun` (plafond 30) ; `scanner_consortium` levé (plus de location ; le boîtier magenta reste) ; `arbitre_loan` (+30 ₵, −35 ₵ au J27).

#### J22 — Question 1 ; le dessin ; Corvo

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d22_q1_title` | L'ENQUÊTE · QUESTION 1 |
| | `evt_d22_q1_text` | « Le 22 mars, Mira Vasquez-Orlov était à votre vitre. Qu'en avez-vous fait ? » L'enquêteur Ravel a déjà la réponse. Il veut la vôtre. |
| | `evt_d22_q1_text_kept` *(si `sc51_bribe_kept`)* | « Lundi, une enveloppe Valcourt. Le 22 mars, Mira Vasquez-Orlov. Commençons par la plus récente. » Ravel a déjà les deux réponses. |
| | `evt_enq_opt_tell` / `evt_d22_q1_res_tell` | Dire / Vous racontez. Ravel écrit sans lever les yeux. « Merci. C'est plus court que ce que je craignais. » |
| | `evt_enq_opt_silent` / `evt_d22_q1_res_silent` | Se taire ★ / « Le silence est noté », dit Ravel. « Il prend moins de place que le reste. » |
| | `evt_enq_opt_accuse` / `evt_d22_q1_res_accuse` | Accuser (+10 ₵) / Vous donnez un nom qui n'est pas le vôtre. Ravel le recopie avec soin. |
| 1 (lettre, si `noa_drawing_kept`) | `evt_d22_drawing` | Le dessin de Noa est punaisé au-dessus du réchaud. Une vitre magenta au milieu des jaunes. Noa dit que c'est la vôtre. |
| 2 (lettre, si `sc33_manifest_kept`) | `evt_d22_corvo` | Un Dérivant frappe au Bloc Pétrel : Corvo Sillage est mort au quai 6, assis sur sa dernière toile. Il a demandé que l'écrou reste au cou de Noa. |

Flags (Q1) : Dire → `verite +1`, `aveux +1` si `final_passed` ou `sc51_bribe_kept` ; Taire → `suspicion +1` ; Accuser → `loyalty +1`, `solidarite −1`, `lucioles_trust −1`, +10 ₵, `enquete_accused`.

#### J23 — Le poste d'Ilan ; Noor ; la caisse des vitres

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si Ilan présent·e, libre, non `ilan_estranged`) | `evt_d23_job_title` | LE POSTE D'ILAN |
| | `evt_d23_job_text` | Deux offres. Les recycleurs de Tycho manquent de mains : il faudrait partir demain. L'Anneau C cherche des remplaçant·es pour les grévistes : 10 ₵ par soir. |
| | `evt_d23_job_opt_tycho` / `_res_tycho` | « Va à Tycho. » / Ilan fait un sac. Noa y glisse le tampon jouet. « Pour qu'ils sachent qui t'envoie. » |
| | `evt_d23_job_opt_scab` / `_res_scab` | « Prends le remplacement. » / Ilan revient le soir sans un mot. Sur le recycleur d'en face, quelqu'un a barré une luciole. |
| | `evt_d23_job_opt_none` / `_res_none` | « Ni l'un ni l'autre. » ★ / Ilan répare le réchaud, deux fois. Il marchait très bien. |
| 1 (lettre, si `noor_medicine`) | `evt_d23_noor` | Noor passe à 21 h, sacoche à la main. « Le sirop, deux fois par jour. Et les médicaments de ce soir, c'est moi. » |
| 2 (lettre, si `solidarite ≥ 2` et solde < 20 ₵) | `evt_d23_fund` | Une enveloppe sous la porte : 15 ₵ et un mot des guichets 01 à 12. « Pour le 04, qui en a besoin cette fois. » |

Flags : `ilan_tycho` (Ilan → `ABSENT · À TYCHO`, `solidarite +1`, `lucioles_trust +1`) / `ilan_scab` (+10 ₵/soir J24–J29, `loyalty +1`, `solidarite −2`) / `ilan_idle` ; `noor_medicine` : médicaments à 0 ₵ ce soir ; `vitres_fund` (+15 ₵).

#### J24 — Noa convoquée

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d24_noa_title` | NOA CONVOQUÉE |
| | `evt_d24_noa_text` | L'Enquête entendra Noa demain, « déposition juvénile », en présence de sa maîtresse. Noa demande ce qu'elle doit dire. |
| | `evt_d24_noa_text_cold` *(si `sc56_okafor_refused`)* | L'Enquête entendra Noa demain. La maîtresse ne sera pas là : « On m'a retenue au Hall. » Noa demande ce qu'elle doit dire. |
| | `evt_d24_noa_opt_truth` / `_res_truth` | « Ce que tu as vu. » / Noa hoche la tête. « Le hublot ouvert, alors. Et l'air qui sentait le dehors. » |
| | `evt_d24_noa_opt_coach` / `_res_coach` | Lui apprendre quoi dire / Vous répétez trois phrases. Noa les répète. Elle ne vous regarde pas en les disant. |
| | `evt_d24_noa_opt_keep` / `_res_keep` | La garder à la maison (amende 10 ₵) ★ / Noa reste au lit, ravie. L'avis d'amende arrive avant le petit-déjeuner. |
| 1 (lettre, si `lucioles_trust ≥ 2`) | `evt_d24_luc` | Une luciole sur la boîte aux lettres : « La Main courante est une liste de passage. Les répondants sont des portes. Merci de les tenir ouvertes. » |

Flags : `noa_testified` (`verite +1` ; `suspicion +1` si `climate_vanne` ou `final2_passed`) / `noa_coached` / `noa_kept_home` (−10 ₵ ; à découvert : `suspicion +1` au lieu de l'amende).

#### J25 — Dora veut témoigner ; la caisse de Tycho ; la Contribution

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si Dora présente) | `evt_d25_dora_title` | DORA VEUT TÉMOIGNER |
| | `evt_d25_dora_text` | Dora a entendu la radio de Tycho. « Ils recommencent. En 51, personne n'a témoigné. Je veux qu'on m'entende, cette fois. » |
| | `evt_d25_dora_opt_write` / `_res_write` | L'aider à l'écrire / Quatre pages. Dora signe de son matricule de mineuse. Elle dort mieux. |
| | `evt_d25_dora_opt_go` / `_res_go` | L'accompagner à l'Enquête (5 ₵) / Dora parle quarante minutes. Ravel ne l'interrompt pas. Elle rentre en toussant. |
| | `evt_d25_dora_opt_rest` / `_res_rest` | « Repose-toi. » ★ / « Je me reposerai après », dit Dora. Elle ne dit pas après quoi. |
| 0 (lettre, si `dora_departed`) | `evt_d25_dora_letter` | Lettre de Tycho : « On respire à tour de rôle. Les enfants d'abord, puis les vieux, puis les autres. Je suis une vieille : je passe mon tour. — Dora » |
| 1 | `evt_d25_tycho_fund_title` | LA CAISSE DE TYCHO |
| | `evt_d25_tycho_fund_text` | Le comité de grève fait passer une boîte de conserve de vitre en vitre. Elle sonne creux. « Pour l'air de Tycho. Le vrai. » |
| | `evt_d25_tycho_fund_opt_give` / `_res_give` | Donner 10 ₵ / Vous ajoutez dix crédits. Quelqu'un a gravé une luciole sur le couvercle. |
| | `evt_d25_tycho_fund_opt_pass` / `_res_pass` | La faire passer ★ / La boîte continue, un peu plus légère que vous ne l'auriez voulu. |
| | `evt_d25_tycho_fund_opt_report` / `_res_report` | La remettre à la Garde (+10 ₵) / « Collecte séditieuse. » La Garde vous remercie. Les vitres, non. |
| 2 (lettre) | `evt_d25_levy_title` / `evt_d25_levy_text` | CONTRIBUTION POUR TYCHO / 20 % de votre épargne au-delà de 60 ₵ : %d ₵. « Pour l'air de Tycho », dit le reçu. Le même jour, l'air de Tycho est coupé. |

Flags : `dora_testimony` (`registre +1`, `verite +1` ; « y aller » : + `suspicion +1`, −5 ₵, Dora `MALADE` si elle n'est pas `BIEN`) ; `tycho_fund` (`solidarite +1`) / `tycho_fund_reported` (`loyalty +1`, `solidarite −2`).

#### J26 — Question 2 ; Ilan convoqué·e ; Ilan libéré·e

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d26_q2_title` | L'ENQUÊTE · QUESTION 2 |
| | `evt_d26_q2_text` | « Le 1ᵉʳ avril, qui avez-vous laissé passer après 13:00 ? » Ravel pose son stylo. « Prenez votre temps. Le registre de votre guichet l'a déjà pris. » |
| | `evt_enq_opt_*` / `evt_d26_q2_res_tell` / `_silent` / `_accuse` | (options communes) / Vous dites l'heure, le visage, le tampon. Ravel hoche la tête : « Concordant. » / « Le silence aussi a une heure », dit Ravel. Il la note. / Vous nommez un collègue. Ravel note le nom, puis l'heure, puis vous. |
| 1 (si Ilan était au recycleur le 01.04 et est présent·e) | `evt_d26_ilan_title` | ILAN CONVOQUÉ·E |
| | `evt_d26_ilan_text` | Une convocation pour Ilan : « technicien·ne présent·e au recycleur central le 01.04 ». Ilan la lit deux fois et la pose sur la table. |
| | `evt_d26_ilan_opt_go` / `_res_go` | « Va témoigner. » ★ / Ilan revient à 23 h. « J'ai dit ce que j'ai fait. Pas avec qui. » |
| | `evt_d26_ilan_opt_hide` / `_res_hide` | « Cache-toi. » / Ilan part avant l'aube. Noa garde sa couchette chaude, encore. |
| 2 (lettre, si `amnesty_refused`) | `evt_d26_ilan_released` | L'Enquête a versé les dossiers. Ilan rentre à pied de l'Anneau B, sans formulaire, sans signature. « Personne n'a rien demandé. C'était presque pire. » |

Flags (Q2) : comme Q1, `aveux +1` si `final2_passed` ; `ilan_testifies` (`verite +1`, `suspicion +1`) / `ilan_hidden3` (Ilan `ABSENT · DANS LA SOUTE` jusqu'au J30, `suspicion +2`) ; `ilan_released_late` (Ilan présent·e `MALADE`, sans rancune).

#### J27 — La Soute ou Tycho ; l'avance échue

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si `drift3_offer`) | `evt_d27_drift_title` | LA SOUTE, JEUDI 05:00 |
| | `evt_d27_drift_text` | La carte de Wren : un remorqueur, écluse 9, jeudi 05:00. Quatre places, 70 ₵. « Après, plus rien ne sort par là. » |
| | `evt_d27_drift_opt_buy` / `_res_buy` | Acheter les places (70 ₵) / Wren compte une fois. « Jeudi. Cette fois, je ne vous attendrai pas. » |
| | `evt_d27_drift_opt_keep` / `_res_keep` | Garder la carte ★ / Trois cartes de quai dans la poche. Une collection de portes. |
| 1 (si `present ≥ 2`, non `exit3_bought`) | `evt_d27_tycho_title` | UN ALLER SIMPLE POUR TYCHO |
| | `evt_d27_tycho_text` | La Transit-7 repartira vers Tycho jeudi, presque vide. Billets pour la famille : 30 ₵. Le Directoire laisse partir qui veut. Presque personne ne veut. |
| | `evt_d27_tycho_text_dora` *(si `dora_departed`)* | La Transit-7 repartira vers Tycho jeudi. Billets pour la famille : 30 ₵. Dora y est déjà : « Ici, au moins, on sait pourquoi on manque d'air. » |
| | `evt_d27_tycho_opt_buy` / `_res_buy` | Prendre les billets (30 ₵) / Ilan range les billets dans le livre de Noa. Personne ne dit le mot « partir ». |
| | `evt_d27_tycho_opt_keep` / `_res_keep` | Rester ★ / Les billets restent au guichet de la Transit-7. Il ferme jeudi à 18:00. |
| 2 (lettre, si `arbitre_loan`) | `evt_d27_loan` | L'avance de l'Arbitre est échue : 35 ₵ retenus. Le reçu revient, tamponné « SOLDÉ ». Il pèse toujours autant. |

Flags : `exit3_bought` + `exit3_drift` / `exit3_tycho` (exclusifs) ; avance non remboursable (solde insuffisant) → `loan_defaulted`, compte comme un loyer impayé (F2, D-047).

#### J28 — Question 3 ; la convocation ; la radio

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d28_q3_title` | L'ENQUÊTE · QUESTION 3 |
| | `evt_d28_q3_text` | « Vous connaissez des Veilleurs. Donnez-m'en trois, et votre dossier s'arrête là. » Pour une fois, Ravel ne note rien. Il attend. |
| | `evt_d28_q3_opt_tell` / `_res_tell` | Dire : « J'en connais. » / « Vous en connaissez. Sans noms. » Ravel écrit une ligne. « C'est la plus honnête de la semaine. » |
| | `evt_enq_opt_silent` / `evt_d28_q3_res_silent` | Se taire ★ / Ravel range son stylo. « Je n'ai rien entendu. C'est ce que j'écrirai. » |
| | `evt_d28_q3_opt_accuse` / `_res_accuse` | Donner trois noms (+10 ₵) / Trois noms. Ravel les écrit lentement, comme s'il espérait une rature. |
| 1 (lettre, si `deposition_summoned`) | `evt_d28_summons` | La convocation de Sato est sur la table, sous le sel. « Mardi, 18:00. Apporter : votre mémoire. » Noa demande si on peut l'oublier exprès. |
| 2 (lettre, si Dora présente) | `evt_d28_radio` | Dora écoute la radio de Tycho, l'oreille collée au poste. Elle ne parle pas. Elle compte, comme en mars. |

Flags (Q3) : Dire → `verite +1`, `aveux +1` ; Taire → `suspicion +1`, `lucioles_trust +1` ; Donner trois noms → `names_given`, `loyalty +2`, `lucioles_trust −3`, `solidarite −1`, +10 ₵.

#### J29 — La Déposition ; demain avec Tycho ; la rédaction de Noa

| Ordre | Clé | Texte |
|---|---|---|
| 0 (`AUDIT` précédé d'un choix 🟡) | `evt_d29_deposition_title` | LA DÉPOSITION |
| | `evt_d29_deposition_text` | 18:00, salle du greffe. Montclair préside, Ravel interroge, Sato note. « Racontez-nous les trente jours du Guichet 04. Tout, ou ce qui vous arrange. » |
| | `evt_d29_deposition_opt_truth` / `_res_truth` | Tout dire / Vous parlez une heure. Les enveloppes, les tampons, les noms. Sato change trois fois de carnet. |
| | `evt_d29_deposition_opt_loyal` / `_res_loyal` | Dire ce qu'on attend / Les Lucioles, Albédo, le désordre. Montclair hoche la tête : « Exactement ce qu'il nous fallait. » |
| | `evt_d29_deposition_opt_silent` / `_res_silent` | Se taire ★ / Vous ne dites rien. Ravel referme le dossier. « Le silence aussi est une déposition. » |
| | `evt_d29_verdict_arrest` *(score ≥ 7 → F1)* | Montclair signe sans lever les yeux. « Le Guichet 04 est mis en attente. L'Enquête vous remercie de votre contribution. » |
| | `evt_d29_verdict_blame` *(4–6)* | « Blâme. Retenue de 30 ₵. La promotion attendra. » Ravel ajoute, plus bas : « C'était presque honnête. » |
| | `evt_d29_verdict_clean` *(≤ 3)* | « Rien à retenir. » Montclair range votre dossier avec les autres. Il a la même épaisseur. |
| 1 (si `solidarite ≥ 5`) | `evt_d29_strike_title` | DEMAIN, AVEC TYCHO |
| | `evt_d29_strike_text` | Un mot circule de vitre en vitre : « Demain, à l'arrivée de la Transit-7, les lampes s'éteignent. Toutes. Pour Tycho. » |
| | `evt_d29_strike_opt_join` / `_res_join` | En être / Vous faites passer le mot. Le 03 aussi : Sato a dit oui, en le notant. |
| | `evt_d29_strike_opt_abstain` / `_res_abstain` | Ne pas en être ★ / Le mot repart. Il ne repassera pas. |
| 2 (lettre, variantes par priorité) | `evt_d29_essay_title` | LA RÉDACTION DE NOA |
| | `evt_d29_essay_vitre` *(si `strike2_joined` ou `climate_vitres`)* | « Plus tard, je serai une vitre éteinte. Comme ça, on verra les gens derrière. » La maîtresse a mis 9/10. |
| | `evt_d29_essay_luciole` *(si `lucioles_trust ≥ 7`)* | « Plus tard, je serai une luciole. On ne sait pas ce que c'est, mais ça éclaire. » La maîtresse a écrit : « Attention. » |
| | `evt_d29_essay_agent` *(si `loyalty ≥ 7`)* | « Plus tard, je serai agent·e de vitre, comme à la maison. Je dirai oui plus souvent. » La maîtresse a mis 8/10. |
| | `evt_d29_essay_coached` *(si `noa_coached`)* | « Plus tard, je dirai ce qu'on me dit de dire. C'est plus facile. » La maîtresse a souligné « facile », deux fois. |
| | `evt_d29_essay` *(sinon)* | « Plus tard, je serai quelqu'un qui dit oui. Une fois, au moins. » La maîtresse a souligné « une fois ». |

**Score de la Déposition** = `suspicion` + `aveux` + 3 (`enquete_cible`) + 2 (`deposition_truth`, l'aveu complet) − 1 (`montclair_impressed`) − 2 (`beaumont_witness`) − 2 (`deposition_loyal`). ≥ 7 → **F1** (`deposition_arrested`) ; 4–6 → blâme (−30 ₵, `loyalty −1`, `promotion_revoked`) ; ≤ 3 → `deposition_clean`. « Dire ce qu'on attend » protège mais pose `loyalty +2`, `lucioles_trust −3`, `solidarite −2` (+20 ₵ si `montclair_pliable`) ; « Tout dire » coûte (+2) mais seul il ouvre **F8** ; « Se taire » : `suspicion +1`. Puis `strike2_joined` (`loyalty −2`).

#### J30 — pas de soirée

Le dernier cas (ou l'annonce de grève) enchaîne sur le bilan (ligne « Familles de Tycho admises · N », `ss_pont`), puis sur l'évaluation des fins (§1.4) et l'épilogue.

### 5.4 Épilogues de l'Acte III

Même format qu'ACT2 §5.4 (titre + 5 à 8 lignes ; « [si drapeau] sinon la suivante »). Préfixe **`end3_`** ; F2 et F3 (anticipées) réutilisent `end_f2_*`, `end_f3_*` ; F6 choisie au J20 réutilise `end2_f6_*`. Surtitre nouveau : `end_eyebrow_f10_pont`.

#### F1 — `end3_f1_title` « MISE EN ATTENTE »

| Clé | Texte |
|---|---|
| `end3_f1_l1` | Anneau B. On vous donne la cellule voisine de celle de mars. Les murs sont aussi blancs. |
| `end3_f1_l2_deposition` *(Déposition)* | Montclair lit votre déposition à voix haute. Elle s'arrête aux aveux, jamais aux noms. |
| `end3_f1_l2_double` *(J30)* | « Loyal envers tout le monde, trente jours durant. » L'Enquête a choisi une couleur pour vous. |
| `end3_f1_l3_beaumont` *(si `beaumont_witness`)* | Beaumont témoigne pour vous. Ça ne suffit pas. Les Commissaires ne suffisent jamais. |
| `end3_f1_l3` | Ilan, Noa et Dora sont réaffecté·es vers un dortoir sans hublot. |
| `end3_f1_l4_pont` *(si `pont ≥ 3`)* | Les familles que vous avez fait entrer dorment à l'école de l'Anneau C. On ne les cherche pas. |
| `end3_f1_l5` | Au Guichet 04, une borne ACV-3 affiche : SUIVANT. |
| `end3_f1_l6` | Il pleut, même ici. |

#### F4 — `end3_f4_title` « ADJOINT·E DE L'ARBITRE »

| Clé | Texte |
|---|---|
| `end3_f4_l1_dora` *(si `dora_detained_final`)* | Dora est mise en attente à 14:20. Vous signez le procès-verbal. Elle ne vous regarde pas : elle regarde Noa, derrière. |
| `end3_f4_l1` | Mira est mise en attente à 14:20. Le registre de Tycho part au broyeur avec son dossier. |
| `end3_f4_l2` | Montclair vous nomme adjoint·e de l'Arbitrage. Votre bureau domine le Hall ; il a une porte, et une serrure. |
| `end3_f4_l3_list` *(si `tycho_list_reported`)* | À 14:05, quarante délégués de Tycho ont été mis en attente au quai 2. La liste était exacte. |
| `end3_f4_l3` | À 18:00, Tycho est close. Le Directoire parle d'un « rééquilibrage réussi ». |
| `end3_f4_l4_ilan` *(si `amnesty_signed` ou `ilan_estranged`)* | Ilan ne vous parle plus. Ilan parle à Noa, le soir, à voix basse. |
| `end3_f4_l4` | Noa porte un uniforme d'école neuf. Elle ne dessine plus de lucioles. Elle dessine des portes. |
| `end3_f4_l5_reports` *(si `albedo_reports_reported`)* | Le second rapport Albédo a été détruit. Le premier fait foi. Personne ne sait s'il était la copie. |
| `end3_f4_l6` | Gloire au Consortium. Vous l'écrivez, maintenant, en bas des conclusions. |

#### F5 — `end3_f5_title` « RENDRE L'AIR »

Variante **Charte** (`end3_f5c_*`, si `climate_vanne`) et **Seconde Vanne** (`end3_f5s_*`, sinon) — lignes 2, 4, 5, 6 communes (`end3_f5_*`) :

| Clé | Texte |
|---|---|
| `end3_f5c_l1` | Mercredi, 14:00. La Transit-7 s'arrime. Depuis le recycleur central, les Veilleurs ouvrent l'air vers le quai 2. |
| `end3_f5s_l1` | Mercredi, 14:00. À la dernière minute, les Veilleurs ouvrent les réservoirs de la Transit-7 vers Tycho. |
| `end3_f5_l2_dora` *(SC-82 = Dora)* | Dora passe la vitre avec le registre de Tycho sous le bras. Elle dit les noms, un par un, jusqu'au quai. |
| `end3_f5_l2` | Mira passe la vitre. Derrière elle, les familles. Elle les compte à voix haute. |
| `end3_f5c_l3` | Le Directoire négocie, puis signe la Charte de l'air. Le quota respiratoire est aboli « définitivement, sauf révision ». |
| `end3_f5s_l3` | Tycho respire une semaine sur les réserves d'Halcyon. Le Directoire rouvre la colonie « à titre humanitaire ». |
| `end3_f5_l4_pont` *(si `pont ≥ 6`)* | Votre vitre a tenu la porte. Les familles de Tycho dorment à l'école de l'Anneau C. |
| `end3_f5_l4_strike` *(si `strike2_joined`)* | Les vitres du Hall étaient déjà éteintes. Personne ne les rallume. |
| `end3_f5_l4_anouk` *(si `sc53_anouk_passed`)* | Anouk Halvorsen tient la vanne de Tycho, les mains bandées. Elle ne la lâche pas. |
| `end3_f5_l5` | Albédo ? L'Enquête retient plusieurs versions. Les Veilleurs n'en retiennent aucune. L'air ne dit rien. |
| `end3_f5_l6` | Vous rendez votre tampon. Noa le garde : il imprime très bien les lucioles. |

Variante **Brûlants** (`end3_f5b_*`, si `vanne2_brulants` ou `sc71_kasimir_passed`, et non `sc71_kasimir_detained`) :

| Clé | Texte |
|---|---|
| `end3_f5b_l1` | Mercredi, 14:00. La Transit-7 s'arrime. À 14:04, le poste de la Garde du quai 2 explose. |
| `end3_f5b_l2_kasimir` *(si `sc71_kasimir_passed`)* | Kasimir avait avoué Albédo. Il avoue aussi le quai 2. À l'heure exacte, cette fois. |
| `end3_f5b_l2` | Les Brûlants n'avaient attendu ni l'Arbitre ni personne. |
| `end3_f5b_l3` | Les familles passent dans la fumée. Personne ne contrôle personne. |
| `end3_f5b_l4` | Tycho est rouverte, sous scellés. Une autre Commission arrive, avec un autre nom. |
| `end3_f5b_l5` | Kasimir avoue Albédo à trois heures différentes. Personne ne le croit. Personne ne sait. |
| `end3_f5b_l6` | Vous respirez mieux. Vous dormez moins bien. Noa dessine des navettes avec des flammes. |

#### F6 — `end3_f6_title` « PARTIR »

Variante **Tycho** (`end3_f6t_*`, si `exit3_tycho`) :

| Clé | Texte |
|---|---|
| `end3_f6t_l1` | Jeudi, la Transit-7 repart vers Tycho, presque vide. Vous êtes dedans, avec deux sacs. |
| `end3_f6t_l2_dora` *(si Dora vivante et libre)* | Dora tient la main de Noa au décollage. « La poussière, tu verras. Elle te reconnaîtra. » |
| `end3_f6t_l2` | Noa colle son front au hublot. Halcyon rapetisse, toutes vitres allumées. |
| `end3_f6t_l3` | À Tycho, le comité de grève vous donne une couchette et un tour d'air. Le vôtre est le quatrième. |
| `end3_f6t_l4_ilan` *(si `ilan_tycho`)* | Ilan vous attend au quai, les mains noires de recycleur. « Ici, les compteurs, on les répare. » |
| `end3_f6t_l5` | Le premier soir, on vous demande de quel côté de la vitre vous étiez. Vous répondez. |

Variante **Dérive** (`end3_f6d_*`, si `exit3_drift`) :

| Clé | Texte |
|---|---|
| `end3_f6d_l1` | Jeudi, 05:00, écluse 9. Le remorqueur de Wren sent l'huile et le sel. |
| `end3_f6d_l2` | Wren raye vos noms d'un registre que personne ne contrôle. « Il en aura fallu trois. » |
| `end3_f6d_l3_dora` *(si `dora_departed`)* | Dora n'est pas à bord. Elle est rentrée à Tycho, à sa façon, deux fois. |
| `end3_f6d_l3` | Dora regarde Halcyon rapetisser. « Tycho était plus petite. Et plus honnête. » |
| `end3_f6d_l4` | Noa demande s'il y a des vitres, dans la dérive. Wren répond : « Que des hublots. » |
| `end3_f6d_l5` | Derrière vous, la station respire comme elle peut. Vous ne saurez jamais très bien comment. |

#### F7 — `end3_f7_title` « LE GUICHET ROUVRE JEUDI »

| Clé | Texte |
|---|---|
| `end3_f7_l1` | Jeudi 12.04.2187, 10:00. Le carillon, trois notes. L'Arbitre a remis ses conclusions : quarante pages, aucune conclusion. |
| `end3_f7_l2_detained` *(si `final3_detained`)* | La dernière navette est passée. Sa passagère la plus connue est en Anneau B. On ne vous a rien proposé. |
| `end3_f7_l2_passed` *(si `final3_passed`)* | Elle est passée. Il manquait des mains à Tycho. Tycho est close quand même. |
| `end3_f7_l2_denied` *(si `final3_denied`)* | Elle a trouvé une autre vitre. Il n'en restait plus beaucoup. |
| `end3_f7_l2` | La navette est repartie à 18:00, à moitié vide. Le bulletin parle d'un « retour au calme ». |
| `end3_f7_l3_pont` *(si `pont ≥ 1`)* | %d personnes de Tycho sont passées par votre vitre, en règle. Le Bureau ne les compte pas. Vous, si. |
| `end3_f7_l4_form` *(si `lindgren_form2_signed`)* | Le formulaire 27-B/2 est aboli. Le 27-B/3 est à l'étude. |
| `end3_f7_l4` | Le formulaire 27-B/2 est maintenu. |
| `end3_f7_l5_okonkwo` *(si `sc75_okonkwo_passed`)* | Okonkwo vous salue depuis le quai 6, d'un geste de tampon. |
| `end3_f7_l5_lindgren` *(si `sc77_lindgren_passed`)* | Lindgren passe sans rien demander. Il ne porte plus qu'un seul dossier. |
| `end3_f7_l6` | La file serpente entre les barrières magnétiques. Elle ne finit jamais. |
| `end3_f7_l7` | « Suivant. » |

#### F8 — `end3_f8_title` « LES TÉMOINS »

| Clé | Texte |
|---|---|
| `end3_f8_l1` | Jeudi, 12:20. Le haut-parleur du Hall lit les conclusions de l'Enquête. Puis, sans prévenir, les dépositions. |
| `end3_f8_l2` | La vôtre en premier. Les enveloppes, les tampons, les noms. Votre voix, un peu métallique. |
| `end3_f8_l3_dora` *(si `dora_testimony`)* | Puis Dora : quarante minutes sur 2151. Au Bloc Pétrel, Noa monte le son. |
| `end3_f8_l3_tycho` *(si `tycho_registre`)* | Puis le registre de Tycho : 1 214 noms de vivants. On les lit plus vite que les morts. |
| `end3_f8_l4_hana` *(si `sc67_hana_reunited`)* | Idris Hadid témoigne qu'il a vu du gris au quai 3. Il ne dit pas lequel. Personne ne le lui reproche. |
| `end3_f8_l4_okonkwo` *(si `okonkwo_testifies`)* | Okonkwo témoigne en une ligne : « La règle, juste assez. » Sato la recopie trois fois. |
| `end3_f8_l5` | Sur Albédo, l'Enquête « retient plusieurs versions comme exactes ». Lindgren classe les deux rapports côte à côte. |
| `end3_f8_l6` | Le Directoire conteste tout, puis rien. Tycho rouvre « en attendant ». On vous mute aux archives, sous-sol 3. |
| `end3_f8_l7` | Vous gardez le badge de Dora. Le Hall se souvient d'une heure, puis de trente jours. |

#### F9 — `end3_f9_title` « LES VITRES ÉTEINTES »

| Clé | Texte |
|---|---|
| `end3_f9_l1` | Mercredi, 14:00. La Transit-7 s'arrime. Le Guichet 04 s'éteint. Puis le 05. Puis toutes, et les bornes jaunes avec. |
| `end3_f9_l2` | Sans vitres, personne ne contrôle personne. Les familles de Tycho traversent le Hall en silence. |
| `end3_f9_l3_sato` *(si `sc54_sato_reinstated`)* | Sato, greffier, note l'heure exacte, puis pose son carnet. « Officieusement : bravo. » |
| `end3_f9_l3` | Les agents posent leurs tampons à plat sur le comptoir, comme des cartes. |
| `end3_f9_l4_okonkwo` *(si `okonkwo_shielded` ou `sc75_okonkwo_helped`)* | Okonkwo ouvre le quai 2 de l'intérieur. « La règle, juste assez… comme on dit. » |
| `end3_f9_l4_dmitri` *(si `sc63_dmitri_locked_out`)* | Au Puits 14, Dmitri éteint la dernière lampe de la mine à la même minute. |
| `end3_f9_l5` | Le Directoire menace, puis compte : ni vitres ni puits, ni minerai ni cadres. Au quatrième jour, il signe. |
| `end3_f9_l6_truth` *(si `deposition_truth`)* | Votre déposition est lue dans le Hall éteint. On l'entend mieux dans le noir. |
| `end3_f9_l7` | Vous rentrez à pied au milieu des autres. Il pleut, même ici. Ensemble, c'est moins froid. |

#### F10 🆕 — `end3_f10_title` « LE PONT »

| Clé | Texte |
|---|---|
| `end3_f10_l1` | Mercredi, 14:00. La Transit-7 s'arrime pour la dernière fois. À 18:00, %d personnes de Tycho sont entrées par le Guichet 04. En règle. |
| `end3_f10_l2` | Chacune avait un répondant passé le matin à votre vitre. Vous aviez lu chaque numéro. |
| `end3_f10_l3_okafor` *(si `sc81_okafor_passed`)* | L'école de l'Anneau C fait une rentrée imprévue. Adaeze Okafor ajoute des bancs. Noa prête ses crayons. |
| `end3_f10_l3_lindgren` *(si `sc81b_lindgren_passed`)* | Lindgren classe les familles par ordre d'arrivée. « Pour qu'on les retrouve. » |
| `end3_f10_l3_beaumont` *(si `sc81b_beaumont_passed`)* | Beaumont a parrainé la famille d'un gréviste. Elle a demandé qu'on ne le répète pas. On le répète. |
| `end3_f10_l4_list` *(si `tycho_list_saved`)* | Aucun délégué n'a été mis en attente au quai 2. La Garde n'avait plus de liste. |
| `end3_f10_l4_elena` *(si `sc74_elena_passed`)* | À l'hospice Meridian, Joaquín tousse moins. Il porte un prénom du Puits 9. Il ne le sait pas encore. |
| `end3_f10_l5` | À 18:00, Tycho est close. Ceux qui restent savent qu'une porte a tenu. Ça ne suffit pas. Ça compte. |
| `end3_f10_l6_dora` *(si SC-82 = Dora et `final3_denied`)* | Dora n'est pas passée. Elle avait mis votre numéro comme répondant. Ça ne comptait pas. Vous le saviez. |
| `end3_f10_l7` | Le Bureau parle d'un « afflux régulier ». Vous gardez la Main courante du 11 avril dans votre poche. |

---
## 6. Économie et difficulté J21 → J30

### 6.1 Barème (valeurs de départ, `EconomyDef` 🟡)

| Poste | Acte II (rappel) | Acte III | Notes |
|---|---|---|---|
| Salaire | 5 ₵ / cas correct ; 0 ₵ imputé | 5 ₵ ; 0 ₵ imputé au J27+ ; **prime de chef·fe de guichet +10 ₵/soir** (climat Promu·e) | primes inchangées : détention 5 ₵, signalement 10 ₵ |
| Amendes | 2 avertissements, −5, puis −10 | **3 avertissements** les jours de règle nouvelle (J21, J22, J24, J25, J26, J28), 2 sinon | D-060 : toujours pas de plafond |
| Loyer | 20 ₵ | 20 ₵ ; **30 ₵** à l'Anneau D (`moved_ring_d`) | — |
| Rations | 3 ₵ (vous) + 4/3/4 cochables | inchangé ; **1 ₵** chacune au climat Vanne ; **incluses** à l'Anneau D | forfait non-compteur : supprimé (les compteurs sont débranchés au J21) |
| Nourriture | 12 ₵ | 12 ₵ | — |
| Chauffage | 6 ₵ | 6 ₵ ; inclus à l'Anneau D | — |
| Oxygène de Dora | 15 ₵ soirs pairs ; 0 si promotion | inchangé ; **aucun** si Dora est partie | — |
| Médicaments | 20 ₵ / malade | 20 ₵ ; 0 ₵ le soir de Noor (J23) | — |
| Prélèvements | J11, J17 : 30 % au-delà de 40 ₵ | **J25 seulement : 20 % au-delà de 60 ₵** (« Contribution pour Tycho ») | puits pour les bons joueurs, plus léger qu'à l'Acte II |
| Aides | — | J21 : rappel des salaires imputés (+5 ₵ × `quota_overrun`, plafond 30) ; J21 : avance de l'Arbitre (+30, −35 au J27) si solde < 40 ; J23 : caisse des vitres (+15) si `solidarite ≥ 2` et solde < 20 ; Noor (J23) | aides **conditionnelles**, ciblées sur les joueurs en difficulté ou solidaires |
| Revenus du foyer | rationnement d'Ilan +8 ₵ (J13–J19) | fin au J21 ; briseur·se de grève **+10 ₵/soir** (J24–J29) | choix moral |
| Dépenses datées | — | déménagement 20, amende de Noa 10, transport de Dora 5, caisse de Tycho 10, places Soute 70, billets Tycho 30 | §3.1 |
| Déposition J29 | Revue J17 : −40 ₵ | blâme : −30 ₵ | seuils 7 / 4 |

Base quotidienne (Bloc Pétrel, foyer complet) : **52 ₵** (loyer, ration personnelle, 3 rations, nourriture, chauffage), + 15 ₵ d'oxygène les soirs pairs (J22, J24, J26, J28). Climat Vanne : **44 ₵**. Anneau D : **42 ₵** (loyer + nourriture), prime de +10 ₵ en plus. Dora partie : −4 ₵ (ration) et plus d'oxygène.

### 6.2 Ce qui rend l'Acte III plus jouable que l'Acte II, sans le rendre facile

QA §12.8 : à ~65 % de bonnes décisions, peu de parties atteignent le J20, et l'effondrement a lieu **après** le pivot, ce qui frustre. L'Acte III garde la dureté (D-060) mais retire les murs :

| Levier | Effet attendu | Pour qui |
|---|---|---|
| **J21 de respiration** (15 passagers, 48 % sans anomalie, aucune anomalie nouvelle, règle nouvelle = un bruit qui **aide** : la prorogation rend valides des documents) | +1 à +2 cas corrects ; le joueur entre dans l'acte sur une victoire | tous |
| **Moins de documents** (ticket J21, bio-scan J23) | ≈ −4 à −5 s par cas → ≈ +1 passager traité par jour (≈ +5 ₵) | tous, surtout les lents |
| **3ᵉ avertissement gratuit** les jours de règle nouvelle | −5 à −10 ₵ d'amende ces jours-là (6 jours sur 10) | joueurs à 60–75 % |
| **Rappel des salaires imputés** (J21) | rend 0–30 ₵ aux joueurs qui ont payé le quota de leur poche à l'Acte II | joueurs « de conscience » |
| **Avance de l'Arbitre** (J21), **caisse des vitres** (J23), Noor (J23) | +30 / +15 / un soir de soins | joueurs à découvert |
| **Prélèvement unique et plus léger** (J25, 20 % au-delà de 60 ₵) | n'entame pas les épargnes modestes | joueurs à 70–85 % |
| Règles « de lecture » (R32, R33, R36) : leur erreur typique est un **refus injustifié** (lisible, avertissement) plutôt qu'une entrée irrégulière | erreurs plus faciles à comprendre au ticket de citation | tous |

Ce qui reste dur : les **chaînes de répondants** (une erreur du matin en coûte deux l'après-midi), la fin de la prorogation au J30 (piège voulu), R37 au J28 (beaucoup de refus justifiés à documenter), et la Déposition (F1 possible pour qui a gardé des enveloppes).

### 6.3 Projection par profil (à vérifier par simulation)

Revenus = `passenger_count` × 5 × précision − amendes (escalade), comme GDD §13 et ACT2 §6.2.

| Profil | Solde au soir du J20 (QA §12.2, sim.) | Après J21 (rappel, avance) | Net quotidien estimé J21–J30 | Lecture |
|---|---|---|---|---|
| 65 % | rare (7,5 % des campagnes atteignent le J20) ; 0–80 ₵ | +0–60 ₵ | ≈ 16 × 5 × 0,65 = 52 − ~22 d'amendes (−8 les jours à 3 avertissements) ≈ 30 contre 52 → **≈ −20 ₵/soir** (−12 au climat Vanne) | effondrement entre le J24 et le J27 sans réserve ; avec les aides, ~1 campagne sur 4 entrées au J21 atteint le J30 |
| 80 % | ≈ 150–250 ₵ | +5–30 ₵ | ≈ 64 − ~8 ≈ 56 contre 52–59 → **≈ 0 ₵/soir** | le capital paie la Contribution (~20–40 ₵) et **une** grosse option (places, billets, caisse) ; ≥ 1 poste sacrifié un soir sur 4 |
| 95 % | ≈ 300–450 ₵ | +0–10 ₵ | ≈ 76 contre 52 → **+24 ₵/soir** ; Contribution −50 à −80 ₵ | tout est payable ; le dilemme est moral (chaînes, Déposition, figure finale) |

### 6.4 Cibles par profil

| Profil | Cibles Acte III (parmi les campagnes entrées au J21) |
|---|---|
| **65 %** | atteindre le J30 : **20–35 %** ; fin anticipée F2/F3 avant le J25 ≤ 40 % ; (au total, J30 atteint ≤ 5 % : la difficulté de l'acte II reste le filtre) |
| **80 %** | atteindre le J30 ≥ 85 % ; `alive ≥ 2` ≥ 85 % ; ≥ 1 poste sacrifié 20–35 % des soirs ; fins dominantes selon la politique : F7 (`default`), F9 (`solidaire`), F8 (`temoin`), F10 (`passeur`), F6 (`drift`) ; F4 rare |
| **95 %** | F4 ≥ 80 % (`loyal`), F5 ≥ 75 % (`luciole`), F6 ≥ 90 % (`drift`), F8 ≥ 80 % (`temoin`), F9 ≥ 80 % (`solidaire`), F10 ≥ 70 % (`passeur`) ; F1 par la Déposition ≥ 60 % (`mercenary3`) et ≤ 10 % pour `luciole` (leçon de D-080) |
| Tous | chacune des 10 fins atteignable par au moins une politique ; entrée depuis **chacun des 5 climats** testée (5 × 3 profils) ; aucune politique « tout approuver » n'atteint F10 (le `pont` ne compte que les admissions correctes) |

### 6.5 Simulation à faire (`tools/balance_sim.gd`)

- Étendre à **30 jours** ; option `--climate=vanne|brulants|vitres|registre|promu|statu_quo` pour démarrer au J21 depuis un état synthétique (comme `--qa-load`).
- Nouveaux préréglages : `passeur` (approuve les répondants, garde la liste, rapide au J30), `temoin` (Dire à chaque question, Dora témoigne, garde rapports et registre, Tout dire), `accusateur` (Accuser, Dire ce qu'on attend), `mercenary3` (garde les enveloppes à partir du J21) ; `luciole`, `loyal`, `drift`, `solidaire`, `default` prolongés.
- Modéliser : la **Main courante** (placement du répondant, cascade d'une erreur sur le répondant) ; le **bruit de prorogation** et de réintégration (probabilité de refus injustifié propre au profil, plus forte les deux premiers jours) ; le gain de temps du J23 (+1 passager traité) ; le **`pont`** (index atteints au J30 selon la vitesse : la plupart des joueurs traitent 14–15 cas sur 18, donc 2 à 3 répondants du réseau).
- Vérifier les seuils : F5 `lucioles_trust ≥ 10`, F4 `loyalty ≥ 10`, double jeu 10/10, Déposition 7/4, F9 `solidarite ≥ 5`, F10 `pont ≥ 6`, F8 `verite ≥ 3` et `registre ≥ 5`. Ajuster les **seuils** d'abord (GDD §14), puis les aides, puis `duration_sec`.
- Playtest humain J21–J24 (la lecture de R32–R34 n'est pas simulable) ; mesurer le taux de refus injustifiés sur les documents prorogés.

### 6.6 Mesuré vs cible (M9 partie A, `tools/balance_sim.gd`, J1–J30)

Mesures de la logique livrée (données `tools/build_data_act3.gd`, graines 1…N, dépenses `reasoned`). « Climat » : départ synthétique au J21 (`--climate=`), solde 40 / 200 / 380 ₵ selon la précision.

| Mesure | Cible (§6.4) | Mesuré | Écart / décision |
|---|---|---|---|
| 65 %, J30 atteint parmi les campagnes entrées au J21 (6 climats, 15 graines) | 20–35 % | 40–67 % (F2/F3 avant le J28 : 27–47 %) | plus jouable que prévu ; aides conservées (D-089) |
| 65 %, campagne complète | J30 ≤ 5 % | 0 % (fin F2/F3 vers J10–J12) | — |
| 80 %, J30 atteint (campagne complète, 40 graines) | ≥ 85 % | 77,5 % ; F1 par la Déposition 20 % (`default` se tait 4 fois : soupçon +4) | seuil d'arrestation 8 testé : F1 7,5 % pour `default`, mais `mercenary3` 95 % tombe à 57 % ; **7 conservé**, D-094 proposé |
| 80 %, depuis chaque climat | ≥ 85 % | 87–100 % | — |
| 95 % `loyal` → F4 | ≥ 80 % | 100 % (30 graines) | `sc82_*` mis en attente |
| 95 % `luciole` → F5 ; F1 | ≥ 75 % ; ≤ 10 % | 96,7 % ; 3,3 % (Revue du J17) | — |
| 95 % `drift` → F6 | ≥ 90 % | 80 % (F10 20 % : priorité F10 > F6 au climat Vanne) | priorité de D-088 conservée |
| 95 % `temoin` → F8 | ≥ 80 % | 100 % | — |
| 95 % `solidaire` → F9 | ≥ 80 % | 100 % | — |
| 95 % `passeur` → F10 | ≥ 70 % | 80 % avec `pont ≥ 5` ; ≈ 60 % avec `pont ≥ 6` | **seuil abaissé à 5** (le quota du J30, 3, oblige à dépasser : entrées imputées à 0 ₵) ; D-092 proposé |
| 95 % `mercenary3` → F1 (Déposition) | ≥ 60 % | 80 % | — |
| `default` 95 % | F7 | F7 100 % | — |
| « tout approuver » n'atteint pas F10 | — | n'atteint jamais le J30 (F1/F2/F3 à l'Acte I–II) ; `pont` ne compte que les admissions **correctes** | — |

Générateur (`tools/gen_stats.gd`, 40 campagnes) : invariants OK J21–J30, zéro re-tirage propre ; part sans anomalie 40–53 % (cibles 36–48 %, scénarisés et répondants propres compris) ; `UNREGISTERED_VESSEL` conditionnel à 0,20 comme à l'Acte II (QA-026) au lieu de 0,02–0,03.

**Correctif QA-037 (v0.10.0).** Les cibles `[0,1,2,3]` du §2.1 sont des cibles **scénarisés inclus** (`DayDef.anomaly_count_targets`) ; les cas imposés (scénarisés, avis et révocation générés, répondants et protégés liés propres) déformant la distribution, `anomaly_count_weights` est **compensé** par jour (`build_data_act3.gd`, `COUNT_WEIGHTS` : J21 [.58, .18, .20, .04] … J30 [.02, .42, .38, .18]). Écarts au §2.2 : `EXPIRED_DOCUMENT` du J21 **.06** (SC-51 est déjà un expiré) ; `SPONSOR_MISMATCH` et `SUSPENDED_CONTRACT` sont, comme `UNREGISTERED_VESSEL`, des poids **conditionnels** (protégé au motif VISITE FAMILIALE ; `TYC` au motif TRAVAIL) relevés après leur jour d'introduction (R34 : 1,5 aux J25–J27, 0,6 au J29 ; R35 : 0,6 / 0,8 / 0,8 aux J25–J27, 0,3 au J29) ; visites familiales `TYC` **0,50** aux J25–J27 (0,40). La colonne « poids » de `gen_stats` n'est donc pas comparable pour ces trois types.

| Mesure (`gen_stats`, 40 campagnes, graine 1) | Cible | Avant | Après |
|---|---|---|---|
| J21 : 0 / 1 anomalie | 48 / 37 % | 41,2 / 49,5 % | 47,8 / 37,7 % |
| J21 : `EXPIRED_DOCUMENT` / `WANTED_PERSON` (part des anomalies) ; DÉTENTION attendue | — | 18,1 / 19,3 % ; 19,0 % | 12,4 / 19,4 % ; 19,3 % (2 avis imposés : SC-53 + avis du jour, D-056) |
| J22–J28 : cas sans anomalie | 36–44 % | 36,6–44,9 % | 35,7–44,2 % (±1,5 point de la cible du jour) |
| J29 / J30 : cas sans anomalie | 42 / 36 % | 51,8 / 53,2 % | 42,4 / 36,8 % |
| R34 (`r_sponsor`, part des cas) J25 / J26 / J27 / J29 | exercée après le J24 | 0,6 / 1,6 / 0,7 / 1,5 % | 4,4 / 3,4 / 2,5 / 7,9 % |
| R35 (`r_tycho_lockout`) J25 / J26 / J27 (J28+ : R37 ferme `TYC`) | exercée après le J25 | 3,7 / 1,3 / 0,6 % | 7,8 / 6,5 / 4,3 % |

Fins (`balance_sim`, J1–J30, 20 graines, graine 1 ; QA §13.2 → après correctifs QA-036 / QA-037) : toutes dans **±5 points** sauf **`drift` 80 % : F6 60 → 75 %** (F10 10 → 0 %, F7 20 → 15 %, F1 10 %) — conforme à l'intention (« fins dominantes selon la politique : F6 (`drift`) », §6.4) : un J30 plus dense laisse moins d'admissions correctes au `pont`. Autres valeurs : `default` 80 % F7 85 · F1 15 ; `loyal` 95 % F4 100 (Déposition « loyal_paid » prise quand `montclair_pliable`) ; `luciole` 80 % F5 75 · F1 25 ; `passeur` 80 % F7 45 · F1 30 · F10 20 · F3 5, 95 % F10 85 · F7 15 ; `temoin` 80 % F8 80 · F1 20 ; `solidaire` 80 % F9 90 · F1 10 ; `mercenary3` 80 % F1 90 · F7 10, 95 % F1 85 · F7 15 ; `drift` 95 % F6 90 · F10 10 ; `accusateur` 80–95 % F7 100. À 65 %, aucune campagne complète n'atteint le J21 (F2/F3 vers J10–J14), sauf `loyal` 5 % (F7).

**Prérequis recommandé** (QA §12.8, hors périmètre de ce document) : `luciole_trust_on_breach = false` dès le J8–J10, sinon les « vannes ouvertes par accident » se propagent en climat Vanne par accident.

---

## 7. Clés i18n

### 7.1 Préfixes

Les préfixes de NARRATIVE §7.2 et d'ACT2 §7.1 restent valables. Ajouts :

| Préfixe | Usage | Exemple |
|---|---|---|
| `sc51_` → `sc82_<nom>[_<variante>]_<suffixe>`, `sc81b_<nom>_*` | répliques des cas (§4) | `sc75_okonkwo_arrival_quai` |
| `day21_` → `day30_{directive_title,intro[_variante],slogan}` | briefings | `day27_intro_vanne` |
| `msg_arb_dayNN[_variante]` | Arbitre | `msg_arb_day28_refused` |
| `msg_enquete_dayNN[_variante]` | Ravel, enquêteur | `msg_enquete_day29_spared` |
| `msg_tycho_dayNN[_variante]` | comité de grève | `msg_tycho_day25_dora` |
| `msg_okafor_dayNN`, `msg_comite_dayNN` | maîtresse, comité des vitres | `msg_okafor_day24` |
| `act2_card_<climat>_{l1,l2}` | carte de fin d'acte (J20) | `act2_card_vitres_l1` |
| `evt_d20_` → `evt_d29_<id>_{title,text[_variante],opt_*,res_*}` ; `evt_enq_opt_*` | soirées ; options communes de l'Enquête | `evt_d26_q2_res_accuse` |
| `hall_jNN_<id>`, `hall_quota_suspended` | annonces du Hall | `hall_j30_transit` |
| `end3_fN_*`, `end3_f5c_*`, `end3_f5s_*`, `end3_f5b_*`, `end3_f6t_*`, `end3_f6d_*` | épilogues Acte III | `end3_f10_l5` |
| `r_<règle>_{title,text}` | R32–R37 | `r_sponsor_text` |
| `rb_tab_ledger`, `rb_tab_summons`, `rb_col_*`, `rb_retired_*` | Rulebook | `rb_retired_quais` |
| `cmp_*` | libellés du comparateur | `cmp_prorogated` |
| `chapter3_*` | interstitiel | `chapter3_title` |

### 7.2 Clés système (les textes des §1, §4 et §5 sont définitifs et ne sont pas répétés)

| Clé | Texte |
|---|---|
| `chapter3_title` | ACTE III — TÉMOINS |
| `chapter3_sub` | Lundi 02.04.2187 — mercredi 11.04.2187 |
| `evt_d20_card_eyebrow` | FIN DE L'ACTE II |
| `spk_arbitre` | ARBITRAGE DE CONTINUITÉ · P. MONTCLAIR |
| `spk_sato_greffier` | SATO · GREFFE DE L'ENQUÊTE |
| `spk_enquete` | ENQUÊTE · C. RAVEL |
| `spk_tycho` | COMITÉ DE GRÈVE · TYCHO |
| `spk_okafor` | A. OKAFOR · ÉCOLE DE L'ANNEAU C |
| `spk_comite` | COMITÉ DES VITRES · GUICHETS 01–12 |
| `r_prorogation_title` | Prorogation de Continuité |
| `r_prorogation_text` | Documents expirés entre le 22.03 et le 01.04.2187 inclus : prorogés jusqu'au 10.04 inclus. Firmware NX non concerné. |
| `r_reinstated_title` | Réintégrations |
| `r_reinstated_text` | N° ID inscrit aux Révocations avec une date de réintégration atteinte : valide. Sans date : refus. |
| `r_sponsor_title` | Répondant |
| `r_sponsor_text` | Ressortissants, motif VISITE FAMILIALE : Répondant Né·e-Halcyon (C-1 à C-3) admis·e aujourd'hui à ce guichet (Main courante). Un agent ne se porte pas répondant à sa propre vitre. |
| `r_tycho_lockout_title` | Lock-out de Tycho |
| `r_tycho_lockout_text` | Contrats Kessler-Ashe (CT-KA) des ressortissants de Tycho : suspendus. Refus. |
| `r_summons_title` | Convocations de l'Enquête |
| `r_summons_text` | Convoqué·es (N° ENQ à l'onglet Convocations, au nom du porteur) : exempté·es du quota, des interdictions d'origine, du lock-out, des révocations et du répondant. Pas de l'avis de recherche. Convocation fausse : refus. |
| `r_tycho_closed_title` | Fermeture de Tycho |
| `r_tycho_closed_text` | Ressortissants de Tycho (TYC) : entrée interdite, sauf VISITE FAMILIALE avec Répondant valide, ou convocation. |
| `rb_tab_ledger` | Main courante |
| `rb_ledger_hint` | Répondants admissibles admis aujourd'hui à ce guichet. |
| `rb_ledger_empty` | Aucun répondant admis pour l'instant. |
| `rb_tab_summons` | Convocations |
| `rb_col_reinstated` | RÉINTÉGRÉ·E LE |
| `rb_reinstated_excluded` | Exclu·e : nuit du 22.03 ou du 01.04 |
| `rb_retired_quais` | REPRIS PAR LES QUAIS (MERIDIAN) |
| `rb_retired_curfew` | LEVÉ PAR L'ARBITRE |
| `rb_suspended_quota` | SUSPENDU PENDANT L'ENQUÊTE |
| `rb_emp_ar` | AR · Arbitrage de Continuité |
| `field_sponsor` | Répondant |
| `field_summons` | Convocation |
| `val_seal_arbitrage` | BALANCE BLEUE |
| `val_post_controle` | CONTRÔLE SANITAIRE |
| `cmp_prorogated` | PROROGÉ (R32) |
| `cmp_reinstated` | RÉINTÉGRÉ (R33) |
| `tb_quota_suspended` | QUOTA SUSPENDU |
| `q_about_sponsor` / `q_about_summons` / `q_about_lockout` | (§4.0) |
| `line_about_sponsor_generic` | Il était devant moi dans la file. Vous ne l'avez pas vu ? |
| `line_about_summons_generic` | On me l'a donnée au quai. Je ne savais pas qu'il y en avait des fausses. |
| `line_about_lockout_generic` | Suspendu ? Je n'ai pas fait grève. Je suis juste né là-bas. |
| `wb_registre_label` | REGISTRE |
| `wb_summons_label` | CONVOCATION |
| `hh_state_away_tycho_x` | PARTI·E À TYCHO |
| `exp_contribution` | Contribution pour Tycho |
| `exp_loan_repay` | Remboursement de l'avance |
| `exp_move` | Déménagement · Anneau D |
| `inc_recall` | Rappel des salaires imputés |
| `inc_loan` | Avance de l'Arbitre |
| `inc_scab` | Salaire d'Ilan · remplacement |
| `inc_vitres_fund` | Caisse des vitres |
| `inc_head_bonus` | Prime de chef·fe de guichet |
| `ev_note_contribution` | Prélevée d'office : 20 % de l'épargne au-delà de 60 ₵. |
| `ev_note_recall` | 5 ₵ par entrée imputée par la Commission (plafond 30 ₵). |
| `ev_note_loan` | 35 ₵ retenus dimanche. |
| `ss_pont` | Familles de Tycho admises |
| `wanted_anouk_reason` | Technicienne de la nuit du 01.04. Sabotage. |
| `wanted_kasimir3_reason` | Réseau Brûlant. Quai 1. |
| `wanted_dora_reason` | Agitatrice. Grève de Tycho. |
| `wanted_mira3_reason` | Évadée. Grève de Tycho. |
| `end_eyebrow_f10_pont` | HALL DES GUICHETS · QUAI 2 |

### 7.3 Traces de fin ajoutées (`end_trace_*`)

| Clé | Texte |
|---|---|
| `end_trace_amnesty_signed` | Vous avez signé des noms pour faire sortir Ilan. |
| `end_trace_sc53_anouk_detained` | Vous avez mis en attente la technicienne, la veille de l'amnistie. |
| `end_trace_sc59_beaumont_spared` | Vous avez laissé passer la Commissaire révoquée. |
| `end_trace_sc70_montclair_refused` | Vous avez refusé l'Arbitre pour une lettre. |
| `end_trace_sc73_celeste_refused` | Vous avez refusé l'infirmière pour un jour. Elena et Joaquín sont repartis. |
| `end_trace_noa_coached` | Vous avez appris à Noa ce qu'elle devait dire. |
| `end_trace_ilan_scab` | Ilan a remplacé les grévistes. |
| `end_trace_ilan_tycho` | Ilan est parti·e réparer les recycleurs de Tycho. |
| `end_trace_dora_testimony` | Dora a témoigné pour 2151. |
| `end_trace_tycho_list_saved` | Vous avez « perdu » la liste des délégués de Tycho. |
| `end_trace_tycho_list_reported` | Vous avez remis la liste des délégués de Tycho. |
| `end_trace_names_given` | Vous avez donné trois noms à l'enquêteur. |
| `end_trace_deposition_truth` | Vous avez tout dit devant l'Enquête. |
| `end_trace_deposition_loyal` | Vous avez dit à l'Enquête ce qu'elle attendait. |
| `end_trace_strike2_joined` | Vous avez éteint votre vitre pour Tycho. |
| `end_trace_pont` | %d personnes de Tycho sont entrées par votre vitre, le dernier jour. |

---

## 8. Besoins système (pour la planification)

Numérotation à la suite d'ACT2 §8 (B35 / I19).

### 8.1 Données et modèle (Godot Architect / Gameplay Systems)

| # | Besoin | Détail |
|---|---|---|
| B36 | `day_21..30.tres`, `rs_day21..30` | `has_evening` vrai J20–J29 ; dernier jour = 30 ; `tools/build_data_act3.gd` sur le modèle de `build_data_act2.gd` (D-029) |
| B37 | **Retrait de règles et de documents** (M1) | un `RuleSet` peut **retirer** des règles d'un jour à l'autre (aujourd'hui cumulatif) ; `DayDef.retired_documents` (le générateur ne les produit plus) ; `DayDef.retired_rule_notes` (ligne barrée un jour) ; `retired_document = true` sur un document présenté quand même (SC-58 : affiché, exclu des règles) |
| B38 | `AnomalyType.Kind` **en fin d'enum** (D-033) | `SPONSOR_MISMATCH = 21`, `FORGED_SUMMONS = 22`, `SUSPENDED_CONTRACT = 23` + 3 injecteurs ; paramètre `expiry_window` de `EXPIRED_DOCUMENT` |
| B39 | Champs du permis | `sponsor_id` (N° ID, affiché avec le nom), `summons_id` (`ENQ-NNNN`, sceau « balance ») ; présents seulement quand ils s'appliquent |
| B40 | Règles | `DocumentNotExpiredRule.grace_window` (R32), `RevokedIdRule.reinstatements` (R33), `SponsorRule` (R34, contexte du shift), `ContractSuspendedRule` (R35), `SummonsRule` + **exemptions déclaratives** (R36 lève R19, R23, R30, R31, R34, R35, R37 ; pas R22), `FactionBannedRule.exempt_if_rules` (R37) |
| B41 | `RuleContext` de shift | `approved_today` (Main courante : N° ID, origine, classe), `reinstatements`, `summons` (liste du jour), date du jour pour la fenêtre ; le verdict attendu reste calculé par le moteur (D-005) **au moment de la présentation** (comme D-077) ; à documenter dans ARCHITECTURE |
| B42 | Générateur : **liens de répondant** | pour chaque ressortissant VISITE FAMILIALE (J24+), placer un répondant `HAL` C-1–C-3 en règle **plus tôt** dans la file (`DayDef.sponsor_links`, comme D-056) ; liens scénarisés (`ScriptedCaseDef.sponsor_of_index`) ; si le répondant est un cas scénarisé absent (condition fausse), remplacer le protégé par un passager généré |
| B43 | Convocations | `DayDef.summons` (entrées liées à des index, comme les révocations), leurres, `summons_rate` |
| B44 | `ScriptedCaseDef` | condition de **climat** sur `ConditionalKey` ; jusqu'à 4 définitions au même index (SC-75) ; `DORA_SEED` (visage fixé) ; `document_dates` avec `expiry_window` ; cas « répondant de » (SC-60, 64, 68, 73, 80, 81, 81b) |
| B45 | Objets glissés | libellés `REGISTRE`, `CONVOCATION` ; jauges `registre`, `verite`, `aveux` ; prime de remise (SC-65, 66, 77, 79, 82) |
| B46 | Briefings | locuteurs §7.2 ; variantes par climat ; « soir précédent » pour les réponses de Noa (`msg_ilan_day25_*`) |
| B47 | Soirées | **carte de fin d'acte** (J20, panneau 0 : évalue les fins F4/F5/F7/F8/F9 sans terminer) ; climat posé par cette évaluation ; questions de l'Enquête (options communes) ; **AUDIT précédé d'un choix** (J29 : le choix modifie le score) ; prélèvement à taux et plancher propres (J25) ; avance (gain puis coût daté, défaut → loyer impayé) ; aides conditionnelles (solde < N) ; effets foyer : `ABSENT · À TYCHO` pour Ilan, retour de Dora `MIS·E EN ATTENTE` ou présente au J30 |
| B48 | Économie (`EconomyDef`) | `recall_per_overrun = 5`, `recall_cap = 30`, `loan_amount = 30`, `loan_repay = 35`, `loan_day = 27`, `vitres_fund = 15`, `contribution_rate = 0.20`, `contribution_floor = 60`, `contribution_day = 25`, `head_bonus = 10`, `ring_d_rent = 30`, `move_cost = 20`, `scab_income = 10`, `vanne_ration = 1`, `deposition_arrest_score = 7`, `deposition_blame_score = 4`, `deposition_retention = 30`, seuils de fin (§1.4) ; `free_citations_per_day` par jour |
| B49 | `EndingService` | J20 non terminal (sauf F1 Revue, F2, F3, F6 choisie) ; J29 : F1 anticipée (Déposition) ; J30 : F1 > F3 > F2 > F5 > F9 > F10 > F8 > F6 > F4 > F7 ; jauge `pont` (admissions `TYC` correctes au J30) ; épilogues `end3_*` |
| B50 | Événements de shift | annonce à heure fixe (J29, 17:30) ; annonces après le cas n ; **fin anticipée du shift** après le 12ᵉ cas (J30, `strike2_joined`) |

### 8.2 Interactions et écrans (UI/UX + Design System)

| # | Besoin | Détail |
|---|---|---|
| I20 | Carte de fin d'acte | plein écran 3 s, passable, titre de la fin de l'Acte II + 2 lignes ; puis soirée pivot ; puis interstitiel « CHAPITRE III · TÉMOINS » (D-082) |
| I21 | Rulebook : retraits | règle barrée avec motif (texte atténué), un jour ; quota « SUSPENDU » (compteur gris) |
| I22 | Onglet Main courante | liste qui s'allonge en direct (dernière ligne surlignée), N° ID en JetBrains Mono, classe ; cible de Mode Inspection (paire Répondant ↔ Main courante) |
| I23 | Onglet Convocations ; colonne RÉINTÉGRÉ·E LE | listes défilantes comme Révocations ; sceau « balance » dans l'onglet Sceaux |
| I24 | Comparateur | résultat **PROROGÉ** / **RÉINTÉGRÉ** (concordant, cyan, avec la référence de règle) |
| I25 | Permis | deux lignes optionnelles (Répondant, Convocation) ; la disposition D-085 profite du bio-scan retiré (2–4 documents) |
| I26 | Soirée | AUDIT précédé d'un choix (Déposition) ; aides conditionnelles ; carte de fin d'acte |
| I27 | Bilan du J30 | ligne « Familles de Tycho admises · N » ; écran de fin à 10 fins ; surtitre F10 |

### 8.3 Assets (3D Designer / Audio)

Accessoires : mains bandées (SC-53), caisse de certificats (SC-58), carnet de greffier (Sato), brassard jaune en poche (SC-79). Visage fixé : **Dora**. Décor facultatif : trois bornes ACV-3 dans le Hall (climat Vitres). Audio : annonce de la Transit-7, carillon « quota suspendu » (variante grave du carillon de quota), lumières coupées (réutilisé du J20), ambiance « Hall plus vide » (moins de voix de file J21–J23).

### 8.4 Tests prioritaires (QA)

Fenêtre de prorogation (bornes 21.03 / 22.03 / 01.04 / 10.04 / 11.04 ; « expire aujourd'hui » au J29 = CONCORDANT) ; réintégration le jour même ; **cascade de répondants** (répondant refusé à raison → protégé refusé à raison ; répondant approuvé à tort → protégé approuvé à raison) ; répondant placé après son protégé ; exemptions de R36 (et non-exemption de R22) ; convocation fausse sur un passager qui n'en avait pas besoin (SC-76) ; document retiré présenté quand même (SC-58) ; 4 variantes au même index (SC-75) ; `pont` ne compte que les admissions correctes ; carte de fin d'acte pour chaque fin du J20 ; Déposition (score, F1 J29) ; priorités des fins J30 sur des historiques synthétiques ; migration v4 → v5 ; lisibilité Deck du permis à 2 lignes optionnelles.

### 8.5 Noms réservés (D-067, D-084)

Noms de famille distinctifs ajoutés : **Okafor**, **Halvorsen**, **Delacroix-Tan**, **Sorel**, **Adeyemi**. Noms complets réservés : Adaeze Okafor, Anouk Halvorsen, Ophélie Delacroix-Tan, Céleste Sorel, Lin Adeyemi, Ren Kerr (`HAL`), Dora Lindqvist-Rey. Les réserves `HAL` perdent 3 noms tirables (Okafor, Delacroix-Tan, Adeyemi) et en gardent ≥ 12 avec `EXTRA_FAMILY_NAMES` (Sorel en fait partie : à retirer de la liste des figurants) ; `TYC` perd Halvorsen (reste ≥ 15). À vérifier par `test_act_two_character_surnames_are_not_drawn_for_generated_passengers`, étendu à J1–J30.

### 8.6 Sauvegarde v5 et migration

État nouveau : climat (drapeaux, sans schéma), jauges `verite`, `aveux`, `pont` (dictionnaire de flags), logement (`moved_ring_d` : drapeau), avance (drapeaux), motif `ABSENT · À TYCHO` pour **Ilan** (motif existant, libellé neutre), retour de Dora au J30 (`ABSENT` → présente ou `MIS·E EN ATTENTE`, transitions existantes), `CaseMemory` des cas de l'Acte III (SC-56, SC-73 et SC-81 réutilisés). La **soirée du J20** est nouvelle : une sauvegarde v4 date au plus du soir du J19.

Migration **v4 → v5** : champs par défaut, version incrémentée ; aucune conversion d'état (une partie v4 au J20 rejoue le J20 et découvre la soirée pivot). **Proposition** : passer en v5 même si le schéma ne change presque pas, pour que `SaveService` refuse proprement une sauvegarde Acte III dans un build 0.9 (D-066 : jour au-delà du dernier rejeté — ici le J21+ avec `last_day = 20`).

---

## 9. Questions au client

1. **Structure du J20.** **A** — Le J20 devient un **pivot obligatoire** (soirée « Nuit du 1ᵉʳ avril », carte de fin d'acte, climats d'entrée ; seules F1 Revue, F2, F3 et F6 choisie terminent la partie) ; **B** — Le J20 garde ses 9 fins et l'Acte III est une **campagne optionnelle « après la fin »** (bouton « Continuer » sur l'écran de fin de F4/F5/F7/F8/F9). *Recommandation : A.* Même logique qu'au J10 (D-076), sauvegarde unique (D-041), choix du J20 qui changent le monde ; la carte de fin d'acte garde la récompense. B coûte la réécriture de cinq épilogues qui contredisent un retour à la vitre et deux jeux de fins pour les mêmes titres (§1.5).
2. **Répondants.** **A** — Le répondant doit avoir été **admis le jour même à votre vitre** (Main courante dynamique : vos verdicts du matin font ceux de l'après-midi, chaînes SC-60/61, 73/74…) ; **B** — Le répondant figure sur une **liste fixe du jour** (onglet de données, indépendante de vos verdicts). *Recommandation : A.* C'est la seule mécanique qui crée des relations entre passagers sans ajouter de document ; elle prolonge le verdict « de contexte » déjà accepté pour le quota (D-077). B reste un repli si le playtest J24 juge les cascades opaques.
3. **Figure finale du J30.** **A** — **Dora** si elle est partie à Tycho au J18, sinon **Mira** ; **B** — Toujours Mira. *Recommandation : A.* Conclut l'arc de Dora et du Puits 9 par un face-à-face (comme Ilan au J20) ; coûte un visage fixé et une variante de dialogue.
4. **Nouvelle fin.** **A** — **F10 « Le Pont »** seule (hospitalité, récompense des répondants, conclusion de Tycho) ; **B** — F10 **et** F11 « La Charte » (réforme imposée par l'Enquête) ; **C** — aucune (Tycho en lignes d'épilogue). *Recommandation : A.* F11 doublerait F8 et donnerait raison à l'Arbitre ; C laisserait la mécanique principale de l'acte sans issue propre.
5. **Difficulté de l'Acte III.** **A** — « Dur » avec **aides conditionnelles** (J21 de respiration, documents retirés, 3ᵉ avertissement les jours de règle nouvelle, rappel des salaires imputés, avance de l'Arbitre, caisse des vitres) ; **B** — A **plus** un filet automatique (amendes plafonnées à 15 ₵ par jour à l'Acte III, ce qui revient sur D-060). *Recommandation : A*, à valider par `balance_sim` (cible : 20–35 % des campagnes à 65 % entrées au J21 atteignent le J30) puis par un playtest humain J21–J24 ; ne passer à B que si le playtest confirme un mur.
