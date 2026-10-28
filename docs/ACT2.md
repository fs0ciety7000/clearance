# ACT2.md — Acte II « Rééquilibrage » (J11 → J20)

> Auteur : **Scénariste** (casquettes Game Designer et Lore Master). Statut : **v0.1 — proposition**, à valider par l'Orchestrateur puis le client. Date : 2026-10-28.
> Sources faisant foi : `LORE.md`, `GDD.md` (§5 économie, §6 anomalies, §8 progression, §13 état M7), `docs/NARRATIVE.md` v0.2 (arcs, flags, SC-01 → SC-22, soirées, fins, §7 conventions), `DECISIONS.md` (D-005, D-020, D-021, D-024, D-028, D-030 → D-036, D-047, D-052, D-053, D-055 → D-062, D-067, D-068), `docs/QA.md` (§2 campagnes, §9 « F5 par accident »), `tools/build_data.gd` (format `ScriptedCaseDef`, `BriefingMessageDef`, `EveningEventDef`, `SlippedItemDef`, `WantedNoticeDef`), `data/i18n/fr.csv` (préfixes).
>
> Conventions (identiques à NARRATIVE §7) : **J** = jour ; **@n** = `at_index` 0-based ; Tessar entre chevrons simples ‹…› ; didascalies entre crochets, jamais porteuses de vérité ; ≤ 90 caractères par réplique sous-titrée, ≤ 220 par message de briefing/soirée ; point médian pour l'agent·e et Ilan, jamais de pronom genré pour Ilan ; deltas de flags `{flag: delta}` (D-045 : delta 0 = drapeau booléen). Le verdict attendu reste **calculé par le moteur** (D-005) : la colonne « Attendu » est l'intention, à vérifier par QA. 🟡 = demande un développement (récapitulé en §8).

---

## 0. Résumé exécutif

- **Le J10 devient un pivot** (« la Nuit des vannes ») : il gagne une **soirée** (révision de D-053), n'arrête plus la campagne sauf F1 (audit J9), F2/F3 (anticipées) et **F6 au choix** (le joueur qui a payé le Basse-Marée peut embarquer). F4/F5/F7 deviennent des **états d'entrée** de l'Acte II.
- **Acte II = 10 jours (ven. 23.03 → dim. 01.04.2187)**, une **Commission de Rééquilibrage** administre le Hall après la nuit des vannes. **3 mécaniques nouvelles** : quota respiratoire du guichet (dépassement imputé), rationnement respiratoire du foyer, scanner partiel (Consortium ou Lucioles). Plus un couvre-feu qui réutilise l'infrastructure du quota.
- **9 règles (R23 → R31)**, **3 documents d'extension du LORE** (Contrat de travail, Laissez-passer de dérive, Attestation d'asile) + un ticket de file, **4 anomalies** ajoutées en fin d'enum (`CONTRACT_MISMATCH` 17, `UNREGISTERED_VESSEL` 18, `OUTDATED_FIRMWARE` 19, `REVOKED_ID` 20).
- **28 cas scénarisés (SC-23 → SC-50)** : 10 humour bureaucratique, 10 drames, 8 petites humanités ; **9 retours** de personnages de l'Acte I ; 9 cas dépendant de flags. Quatre récurrents nouveaux : la Commissaire **Isadora Beaumont**, le collègue zélé **Aurelio Sato**, l'archiviste **Kenji Lindgren** (« formulaire 27-B », 4 passages), le Brûlant **Kasimir Oyelaran-Holm**.
- **9 fins au J20** : les 7 existantes adaptées + **F8 « Le Registre »** (vérité sur le Puits 9, Albédo reste ambigu) et **F9 « Les vitres éteintes »** (grève des guichets). Figure finale : **Ilan** à la vitre si Ilan a rejoint la Soute, sinon **Mira**.
- Deux jauges ajoutées : `solidarite` (collègues) et `registre` (0–5 pages du Puits 9). Sauvegarde **v4** (états du foyer, rations).

---

## 1. Pitch et structure

### 1.1 Pitch de l'Acte II

1. Le 22 mars, les recycleurs de l'Anneau C se sont ouverts une heure — ou pas du tout. Le lendemain, la station compte son air.
2. Une **Commission de Rééquilibrage** prend le Hall : quota d'entrées par guichet, couvre-feu respiratoire, compteurs dans les cabines.
3. Au Guichet 04, chaque tampon « APPROUVÉ » consomme désormais une part d'un quota qui fond de jour en jour : au-delà, l'entrée est imputée à votre foyer.
4. Les collègues sont révoqués, les inspecteurs aussi ; un archiviste réclame un formulaire qui n'existe pas ; un chat présente son contrat de travail.
5. Dimanche 1ᵉʳ avril, quelqu'un que vous aimez se présente à votre vitre avec la clé du recycleur central.

### 1.2 Ce que devient le J10 : la Nuit des vannes

Aujourd'hui (v0.8.1), le dernier tampon du J10 enchaîne sur l'épilogue (D-053). Proposition : **le shift du J10 reste identique** (SC-20 → SC-22, Mira à @10), mais il est suivi d'une **soirée pivot** à panneaux successifs (comme l'audit du J9) :

| Ordre | Panneau | Condition | Effet |
|---|---|---|---|
| 1 | **La Nuit des vannes** (lettre, 3 variantes) | `final_passed` et `lucioles_trust ≥ 4` → **ouvertes** ; `final_detained` → **échec** ; sinon → **avortées** | `vannes_opened` / `vannes_failed` / `vannes_aborted` |
| 2 | Recalcul de la suspicion (silencieux) | toujours | `suspicion := ⌊suspicion / 2⌋` (+1 si `audit_retention`) — la Commission « reprend les dossiers » |
| 3 | Double jeu (lettre de Ravel) | `lucioles_trust ≥ 3` et `loyalty ≥ 3` | **ne termine plus la partie** : `double_jeu_signale`, `suspicion +2` (lu par la Revue du J17) |
| 4 | Le sort d'Ilan (lettre) | `ilan_supported` | vannes échouées → Ilan **MIS·E EN ATTENTE** (`ilan_arrested_vannes`) ; ouvertes → Ilan **DANS LA SOUTE** jusqu'au J15 (`ilan_in_hiding`) ; avortées → Ilan rentre à l'aube |
| 5 | « C-2 à l'essai » (lettre) | conditions de l'ancienne F4 : `final_detained`, `loyalty ≥ 3`, conformité ≥ 0,85, ≥ 2 proches en vie | `promotion_offered` : oxygène de Dora **offert** (« ration de fidélité ») jusqu'au J20 |
| 6 | **Quai 6, demain 05:00** (choix) | `drift_passes_bought` | **Embarquer → F6 immédiate** (épilogue `end_f6_*` existant, cohérent : vendredi 05:00) ; **Rester** → Wren rend 20 ₵, `drift_stayed` |
| 7 | Dépenses du soir | toujours | barème J10 (§6) |
| — | Interstitiel « ACTE II — RÉÉQUILIBRAGE » | si la partie continue | sauvegarde automatique |

**Fins qui restent possibles au J10** : **F1** (audit du J9, inchangé), **F2** et **F3** (anticipées, inchangées), **F6** (choix explicite du panneau 6). **F4, F5 et F7 ne terminent plus la partie** : elles deviennent respectivement `promotion_offered`, `vannes_opened`, `vannes_aborted`/`vannes_failed`.

**Justification.**
- Un pivot vaut mieux qu'un double système de fins : l'Acte II n'a de sens que si les choix du J10 *changent le monde* (une heure d'air, Mira en cellule, Ilan arrêté·e) au lieu d'être résumés par un épilogue.
- F5 au J10 racontait une victoire (« rendre l'air ») que l'Acte II ne pourrait pas poursuivre. La rabaisser à **une heure** d'air garde la valeur du choix et ouvre la « Grande Vanne » du J20.
- F6 est la seule fin que le joueur a **achetée** au J9 : la lui retirer serait trahir son choix. Il garde la sortie, mais elle devient un acte (« Embarquer »), et Rester a un prix lisible (40 ₵ payés, 20 rendus).
- Le double jeu (F1 J10) tombait sans préavis ; il devient une menace visible (lettre de Ravel) jugée à la Revue du J17 ou au J20.
- La division de la suspicion évite que l'audit du J9 juge deux fois les mêmes enveloppes, tout en gardant une mémoire.

### 1.3 Fins au J20 (7 adaptées + 2 nouvelles)

Définitions : `alive` = proches dont l'état ≠ `PERDU` (un proche `ABSENT` ou `MIS·E EN ATTENTE` compte comme vivant : 🟡 l'Acte II sépare l'état « mis·e en attente » de `PERDU`, alors qu'à l'Acte I Ilan dénoncé·e passait à `PERDU` — migration en §8.6) ; `present` = proches ni `PERDU`, ni `MIS·E EN ATTENTE`, ni `PARTIE À TYCHO` ; `compliance` cumulée J1–J20 ; `credits` = solde après le bilan du J20. Le J20 n'a **pas de soirée** (comme D-053) : l'évaluation suit le bilan.

| # | Fin | Condition exacte | Moment |
|---|---|---|---|
| **F1** | Arrestation | Revue du J17 : score ≥ 5 (§5, J17) ; **ou** J20 : `lucioles_trust ≥ 7` **et** `loyalty ≥ 7` (double jeu) | J17 (anticipée) / J20 |
| **F3** | Famille perdue | `alive == 0` | anticipée, chaque soir |
| **F2** | Réaffectation | 3 loyers impayés consécutifs, ou solde < 0 trois soirs consécutifs (inchangé, D-047) | anticipée, chaque soir |
| **F5** | Rendre l'air (la Grande Vanne) | `final2_passed` **et** `lucioles_trust ≥ 7`. Variante **Brûlants** si `sc47_kasimir_passed` **ou** `sc20_passed` **ou** `brulants_package` (et non `sc47_kasimir_detained`) ; sinon **Veilleurs** | J20 |
| **F9** 🆕 | Les vitres éteintes | `strike_joined` **et** `solidarite ≥ 3` | J20 |
| **F8** 🆕 | Le Registre | `registre_sent` (exige `registre ≥ 3` au J19) | J20 |
| **F6** | À la dérive (lundi 05:00) | `drift2_passes_bought` **et** `present ≥ 2` **et** `credits ≥ 30` **et non** `final2_detained` — ou choix « Embarquer » du J10 | J10 / J20 |
| **F4** | Gloire au Consortium | `final2_detained` **et** `loyalty ≥ 7` **et** `compliance ≥ 0,85` **et** `alive ≥ 2` **et non** `promotion_revoked` **et non** `strike_joined` | J20 |
| **F7** | Le guichet rouvre lundi | aucune des précédentes | J20 |

**Priorité** : **F1 > F3 > F2 > F5 > F9 > F8 > F6 > F4 > F7**.
- F5 et F9 sont des événements collectifs qui englobent les fins individuelles (lignes conditionnelles : la grève apparaît dans F5, le registre dans F5 et F9).
- F8 passe avant F6/F4 : diffuser le registre est un acte public qui empêche la promotion et que la fuite ne fait pas oublier.
- F6 garde l'exclusion « pas après avoir livré la figure finale » (NARRATIVE §6.1).
- Seuils à 7 (contre 3–4 au J10) : les jauges cumulent sur 20 jours (Acte I : jusqu'à ~14 points de `lucioles_trust` possibles, ~12 de `loyalty`) ; **à valider par simulation** (§6.4).

**Pourquoi deux fins de plus et pas trois.** L'Acte I offre la loyauté (F4), la résistance (F5) et la fuite (F6). Il manque deux réponses non violentes que l'Acte II rend possibles : **la vérité** (F8 — un objectif canon des Lucioles, LORE §7 : « révéler le Massacre du Puits 9 ») et **le collectif du travail** (F9 — l'écho de la grève de Tycho de 2151, sans passer par les Lucioles). Une troisième (« carrière d'inspecteur ») doublerait F4.

**Albédo (D-053).** Aucune fin ne tranche. F8 contient une page sur Albédo « qui accuse tout le monde et ne prouve rien » ; F5 Brûlants voit Kasimir revendiquer Albédo « tant qu'il y est » sans qu'on le croie. Règle d'écriture Acte II : **tout indice sur Albédo est contredit dans le même jour** (§3.5).

---

## 2. Progression J11 → J20

### 2.1 Table de synthèse

Diégèse : la « délégation progressive des quais » (D-028) continue, mais c'est désormais la **Commission de Rééquilibrage** qui signe les directives. Respirations : **J13** et **J19** (pas de nouveau type d'anomalie, contrôles rapides).

| Jour | Date | Directive / nouvelles règles | Nouveau document / champ | Nouveaux types d'anomalies (fin d'enum, D-033) | `passenger_count` | `duration_sec` | `anomaly_count_weights` [0,1,2,3] | Événement narratif |
|---|---|---|---|---|---|---|---|---|
| **J11** | ven. 23.03.2187 | **R23** Quota respiratoire (5) — mécanique M1 | compteur QUOTA (barre d'état) ; rations du foyer (M2) | — | 16 | 720 | [0.42, 0.38, 0.15, 0.05] | Lendemain des vannes ; la Commission prend le Hall ; prélèvement sur l'épargne ; compteurs dans les cabines |
| **J12** | sam. 24.03 | **R24** Contrat requis (motif TRAVAIL), **R25** Code employeur | **Contrat de travail** `CT-XX-NNNN` ; onglet Codes employeurs | `CONTRACT_MISMATCH` (17) | 16 | 735 | [0.40, 0.38, 0.17, 0.05] | Sato arrive au Guichet 03 ; poste offert à Ilan ou caution d'Ilan |
| **J13** | dim. 25.03 | **R26** Laissez-passer de dérive *(respiration)* | **Laissez-passer de dérive** ; onglet Registre des cargos | `UNREGISTERED_VESSEL` (18) | 16 | 720 | [0.45, 0.37, 0.14, 0.04] | Les trois Ren Kerr ; le Sillage démantelé ; scanner magenta proposé |
| **J14** | lun. 26.03 | **R27** Firmware NX < 90 j ; scanner partiel (M3) | champ **Firmware NX** de la carte | `OUTDATED_FIRMWARE` (19) | 17 | 750 | [0.40, 0.38, 0.17, 0.05] | Okonkwo à la vitre ; Dora dicte les noms du Puits 9 |
| **J15** | mar. 27.03 | **R28** Attestation d'asile (TER C-5) ; quota → 4 | **Attestation d'asile** `AA-NNNN` | — (réutilise `MISSING_DOCUMENT`, `EXPIRED_DOCUMENT`, `INVALID_SEAL`) | 17 | 750 | [0.40, 0.38, 0.17, 0.05] | Fatou revient avec ses papiers ; pénurie hydroponique |
| **J16** | mer. 28.03 | **R29** Couvre-feu respiratoire 16:00 (M1, contexte horaire) | **Ticket de file** (heure de présentation) | — | 17 | 765 | [0.40, 0.37, 0.18, 0.05] | Sato teste l'agent·e ; « 15 h 59 » ; Ilan appelé·e par la Soute |
| **J17** | jeu. 29.03 | **R30** Révocations | onglet Révocations | `REVOKED_ID` (20) | 17 | 765 | [0.38, 0.38, 0.18, 0.06] | **La Revue** (2ᵉ audit, F1 possible) ; Sato révoqué ; évasion de Mira si détenue |
| **J18** | ven. 30.03 | **R31** « Le Puits est clos » (TER interdits sauf poste en pénurie) | champ **Poste** du contrat lu par R31 | — (`BANNED_FACTION` re-pondéré) | 18 | 780 | [0.36, 0.38, 0.20, 0.06] | La Commissaire au guichet et son ordre ; Dora veut rentrer à Tycho |
| **J19** | sam. 31.03 | — ; quota → 3 *(respiration)* | — | — | 17 | 750 | [0.42, 0.38, 0.15, 0.05] | Ravel révoqué ; dernier cargo de Wren ; vote de grève ; le registre |
| **J20** | dim. 01.04 | — ; avis de recherche « visages seuls » | avis sans nom (données) | — | 18 | 780 | [0.36, 0.38, 0.20, 0.06] | La Grande Vanne : la clé à la vitre → épilogue |

Implicite : `credit_per_correct = 5`, `penalty_per_error = 5`, `free_citations_per_day = 2`, `penalty_escalated = 10`, `detain_enabled = true`, `bribe_rate = 0.05`, `bribe_amounts = (20, 30)`, `visor_down_rate = 0.20`, `has_evening = true` de J10 à J19, `false` au J20. Avis de recherche (R22) chaque jour : 1 entrée générée (D-056), + entrées scénarisées (J14 Okonkwo si `okonkwo_warned`, J20 la figure finale). Budget par cas ≈ 39 s (J11) → 37 s (J18/J20), comparable au J10 (GDD §9).

**Pourquoi plus de passagers « propres » qu'au J10** (0,36–0,45 contre 0,25) : le quota rend chaque passager en règle intéressant (faut-il lui donner la place ?) ; les fraudes restent nombreuses mais la tension se déplace des papiers vers le compteur.

### 2.2 `anomaly_weights` (poids relatifs)

| Type | J11 | J12 | J13 | J14 | J15 | J16 | J17 | J18 | J19 | J20 |
|---|---|---|---|---|---|---|---|---|---|---|
| `EXPIRED_DOCUMENT` | .05 | .05 | .05 | .05 | .07 | .05 | .04 | .04 | .05 | .04 |
| `MISSING_DOCUMENT` | .05 | .07 | .06 | .04 | .09 | .05 | .04 | .04 | .05 | .04 |
| `PORTRAIT_MISMATCH` | .03 | .03 | .03 | .03 | .03 | .03 | .03 | .03 | .03 | .03 |
| `ID_MISMATCH` | .05 | .04 | .05 | .04 | .04 | .04 | .04 | .04 | .05 | .04 |
| `NAME_MISMATCH` | .05 | .04 | .05 | .04 | .04 | .04 | .04 | .04 | .05 | .04 |
| `ORIGIN_ID_MISMATCH` | .04 | .03 | .04 | .03 | .03 | .03 | .03 | .03 | .04 | .03 |
| `PURPOSE_MISMATCH` | .05 | .04 | .05 | .04 | .04 | .05 | .04 | .04 | .05 | .04 |
| `WRONG_ISSUER` | .04 | .03 | .04 | .03 | .03 | .03 | .03 | .03 | .04 | .03 |
| `BIOSCAN_UNFIT` | .04 | .03 | .04 | .03 | .03 | .03 | .03 | .03 | .04 | .03 |
| `UNDECLARED_IMPLANT` | .06 | .05 | .06 | .05 | .05 | .05 | .05 | .05 | .06 | .05 |
| `BANNED_IMPLANT` | .05 | .04 | .05 | .04 | .04 | .04 | .04 | .04 | .05 | .04 |
| `IMPOSTOR_LOOKALIKE` | .08 | .06 | .07 | .06 | .06 | .07 | .06 | .06 | .07 | .07 |
| `RELATIVE_DOCUMENTS` | .07 | .05 | .06 | .05 | .06 | .05 | .05 | .05 | .06 | .05 |
| `BANNED_FACTION` | .07 | .06 | .07 | .06 | .06 | .06 | .06 | **.15** | .08 | .07 |
| `INVALID_SEAL` | .07 | .05 | .06 | .05 | .07 | .05 | .05 | .05 | .06 | .05 |
| `MRZ_MISMATCH` | .06 | .05 | .06 | .05 | .05 | .05 | .05 | .05 | .06 | .05 |
| `WANTED_PERSON` | .08 | .06 | .06 | .06 | .06 | .06 | .06 | .06 | .06 | **.12** |
| `CONTRACT_MISMATCH` 🆕 | — | **.22** | .10 | .08 | .07 | .07 | .06 | .06 | .07 | .06 |
| `UNREGISTERED_VESSEL` 🆕 | — | — | **.15** | .07 | .05 | .05 | .05 | .04 | .05 | .04 |
| `OUTDATED_FIRMWARE` 🆕 | — | — | — | **.18** | .08 | .07 | .06 | .06 | .07 | .06 |
| `REVOKED_ID` 🆕 | — | — | — | — | — | — | **.18** | .09 | .08 | .07 |

Règles d'injection ajoutées : `CONTRACT_MISMATCH` seulement si motif TRAVAIL ; `UNREGISTERED_VESSEL` seulement sur un `DRV` ; `OUTDATED_FIRMWARE` seulement si le passager porte un `NX-` (le générateur en ajoute un, déclaré, si besoin) ; `REVOKED_ID` combinable avec 0 autre anomalie (lisibilité, comme `WANTED_PERSON`), et l'entrée de la liste est liée à un index du jour (comme D-056).

### 2.3 Paramètres complémentaires

| Paramètre | J11 | J12 | J13 | J14 | J15 | J16 | J17 | J18 | J19 | J20 |
|---|---|---|---|---|---|---|---|---|---|---|
| `faction_weights` TYC/HAL/TER/CER/THR/DRV | .28/.17/.20/.13/.12/.10 | idem | .26/.16/.18/.13/.11/**.16** | .28/.17/.20/.13/.12/.10 | idem | idem | idem | .26/.16/**.24**/.12/.12/.10 | .28/.17/.20/.13/.12/.10 | idem |
| `air_quota` 🟡 | 5 | 5 | 5 | 5 | 4 | 4 | 4 | 4 | 3 | 3 |
| `legit_noise_rate` | .35 | .35 | .35 | .38 | .38 | .38 | .40 | .40 | .40 | .40 |
| `luciole_rate` | .08 (.10 si `vannes_opened`, .05 si `vannes_failed`) | idem | idem | idem | idem | idem | .06 | .06 | .08 | .10 |
| `luciole_trust_on_breach` 🟡 | **false** de J11 à J20 | | | | | | | | | |

`luciole_trust_on_breach = false` : à l'Acte II, approuver **par erreur** un Luciole généré en infraction ne donne plus `lucioles_trust +1` (QA §9, « F5 par accident »). La confiance ne vient plus que de gestes explicites (cas scénarisés, phrase de passe, choix du soir). Les citations restent.

### 2.4 Nouvelles règles (R23 → R31)

| Id | Règle (texte Rulebook abrégé) | Sous-classe 🟡 | Jour | Catégorie / sévérité | Vérification en Mode Inspection |
|---|---|---|---|---|---|
| R23 `r_air_quota` | Ressortissants : N entrées par jour. Quota atteint : refus justifié ; entrée de plus imputée au guichet (0 ₵). Exemptés : `HAL`, motif DIPLOMATIQUE | `AirQuotaRule` (contexte) | J11 | SPECIAL / 1 (« souple ») | Compteur QUOTA de la barre d'état ↔ R23 ; refus **documenté d'office** quand le compteur affiche QUOTA ATTEINT (comme D-043) |
| R24 `r_contract_required` | Motif TRAVAIL : Contrat de travail au nom du porteur, non expiré | `RequireDocumentRule` + `applies_to_purposes` | J12 | DOCUMENTS / 2 | Règle ↔ dossier (manquant) ; Expiration ↔ date du jour ; noms ↔ noms (R07) |
| R25 `r_contract_consistent` | Code `CT-XX` = employeur du permis (onglet Codes employeurs) | `ContractConsistentRule` | J12 | DOCUMENTS / 2 | Code (contrat) ↔ Employeur (permis), ou Code ↔ onglet |
| R26 `r_drift_pass` | `DRV` : Laissez-passer de dérive ; Vaisseau = nom de famille et inscrit au Registre des cargos | `DriftPassRule` | J13 | DOCUMENTS / 2 | Vaisseau ↔ onglet Registre ; Vaisseau ↔ Nom (carte) |
| R27 `r_nx_firmware` | Shunts `NX-` : Firmware de moins de 90 jours | `DocumentNotExpiredRule` (champ, `max_age_days = 90`) | J14 | IDENTITY / 2 | Firmware (carte) ↔ date du jour |
| R28 `r_asylum_required` | `TER` de classe C-5 : Attestation d'asile non expirée, au nom du porteur | `RequireDocumentRule` (condition faction + classe) | J15 | DOCUMENTS / 2 | Règle ↔ dossier ; Expiration ↔ date ; Sceau ↔ onglet Sceaux (hexagone **gris**) |
| R29 `r_curfew` | Présentation après 16:00 : motifs VISITE FAMILIALE, COMMERCE, TRANSIT refusés ; `HAL` exemptés | `CurfewRule` (contexte horaire) | J16 | PURPOSE / 2 | Heure (ticket de file) ↔ R29, puis Motif (permis) ↔ R29 |
| R30 `r_revoked_ids` | N° ID inscrit à l'onglet Révocations : refus | `RevokedIdRule` (liste du jour) | J17 | IDENTITY / 2 | N° ID (carte) ↔ onglet Révocations |
| R31 `r_ter_closed` | `TER` interdits, sauf Contrat sur poste en pénurie (RECYCLEUR, SOINS, HYDROPONIE) | `FactionBannedRule` + `exempt_posts` | J18 | FACTION / 2 | Origine ↔ R31 ; Poste (contrat) ↔ R31 |

Onglets du Rulebook ajoutés : **Codes employeurs** (J12), **Registre des cargos** (J13), **Révocations** (J17). La liste des postes en pénurie est dans le texte de R31. Implants : une ligne « NX- : firmware < 90 jours » (J14).

### 2.5 Mécaniques nouvelles (3, plus une extension)

#### M1 — Quota respiratoire du guichet (J11) et couvre-feu (J16) : « règles de contexte du shift »

- **Règle** (R23) : chaque APPROBATION d'un passager non exempté incrémente le compteur. Tant que `compteur < N`, rien ne change. Quand `compteur ≥ N`, pour un passager non exempté **en règle** : **REFUSÉ** = correct et documenté d'office (+5 ₵) ; **APPROUVÉ** = correct aussi, mais **imputé** : 0 ₵ pour ce cas, `quota_overrun +1`, et `suspicion +1` à chaque 3ᵉ dépassement (la Commission remarque). Un passager en infraction reste jugé normalement (approuver un fraudeur au-delà du quota = ENTRÉE IRRÉGULIÈRE **et** dépassement).
- **Pourquoi « souple »** : le dilemme de l'Acte II est *5 ₵ contre une personne*. Un quota strict (approuver au-delà = citation) ne laisserait qu'une bonne réponse ; le dépassement imputé met le prix de la conscience dans le budget du foyer, comme les dépenses du soir (P3 du GDD). Alternative stricte : question ouverte n° 2.
- **Vérification** : compteur `QUOTA 3/5` en haut à droite (barre d'état), qui passe à `QUOTA ATTEINT` (ambre) ; annonce du Hall `hall_quota_full` ; en Mode Inspection, la paire « Compteur ↔ R23 » confirme le motif (épinglée comme une discordance). Un `HAL` ou un DIPLOMATIQUE n'incrémente pas le compteur ; le chiffre de l'origine se lit comme d'habitude.
- **Couvre-feu** (R29, J16) : même infrastructure (contexte). L'heure retenue est **l'heure de présentation** (fin de PRESENTING), imprimée sur un **Ticket de file** posé avec les documents. Le joueur lent ne fait pas basculer un passager déjà présenté. Annonce du Hall à 16:00 (`hall_j16_curfew`).
- **Impact UI** : compteur dans la barre d'état (DS : ambre quand atteint) ; ticket de file (petit document générique, un seul champ comparable « Présentation ») ; ticket de citation inchangé ; ligne « Entrées imputées · N » au bilan du shift.

#### M2 — Rationnement respiratoire du foyer (J11)

- **Règle** : la taxe d'air (10 ₵, prélevée) est remplacée par **4 rations** : la vôtre (**3 ₵, prélevée d'office**) et celles d'Ilan (**4 ₵**), Noa (**3 ₵**), Dora (**4 ₵**), **cochables une par une**. Ration non payée → le proche passe **ESSOUFFLÉ·E** (même transition que `FROID` : 2 soirs → `MALADE`). Sans compteur posé (refusé au J11), chaque ration coûte **+1 ₵** (« forfait non-compteur »). L'oxygène d'appoint de Dora reste à part (soirs pairs).
- **Pourquoi** : rendre littéral le « quota respiratoire » du LORE et transformer un prélèvement subi en choix nominatif (« qui respire ce soir ? »), le pendant domestique du quota du guichet.
- **Vérification** : écran Foyer ; aucune action au guichet.
- **Impact UI** : 3 lignes de plus dans la colonne des dépenses (le loyer et la ration personnelle restent en tête), un état `ESSOUFFLÉ·E` (icône souffle, couleur d'alerte ambre), un état `ABSENT` à motif (`DANS LA SOUTE`, `PARTIE À TYCHO`) dont la ligne de ration est grisée.

#### M3 — Scanner partiel (J14, UI_FLOW §5.2–5.3)

- **Deux sources, exclusives** : **ACV-2 du Consortium** (proposé par la directive du J14, loué **5 ₵ par soir**, retenu d'office, `loyalty +1` à l'installation, **−1** au score de la Revue du J17 : « dossier transparent ») ou **boîtier magenta des Lucioles** (soirée du J13 si `lucioles_trust ≥ 3`, gratuit, `lucioles_trust +1`, **+2** au score de la Revue s'il est encore branché le J17 ; peut être débranché au soir du J16).
- **Effet** (identique pour les deux) : au début de chaque inspection, le scanner **pré-trace en pointillé** les liens « Expiration ↔ date du jour » de tous les documents. Le joueur **confirme d'un clic** (la confirmation vaut discordance épinglée) ou ignore. Le scanner ne ment jamais (zéro faux positif) et ne couvre **qu'une catégorie** : les dates.
- **Pourquoi** : au J14 le dossier compte jusqu'à 5 documents ; le scanner rend ~5 s par cas (≈ +1 passager/jour, soit ~5 ₵ : la location s'amortit pour un joueur à 80 %). Il fait aussi porter la surveillance par l'outil (Consortium) ou le risque par la loyauté (Lucioles).
- **Impact UI** : liens « suggérés » magenta pointillés (même grammaire que les liens confirmés, UI_FLOW §5.3) ; petite pastille « ACV-2 » ou luciole sur le plan de travail ; aucune nouvelle touche.

#### Extension — Tickets, documents de tiers, ordre d'un supérieur

Pas des mécaniques à part entière, mais des besoins ponctuels : document **d'un tiers** non comparé par R07 (le contrat du chat, SC-27) ; **ordre** donné par un passager (SC-42/43), traité uniquement par flags.

---

## 3. Arcs prolongés

### 3.0 Vue d'ensemble

| Jour | Foyer | Lucioles | Consortium | Okonkwo / collègues |
|---|---|---|---|---|
| J10 (soir) | Ilan arrêté·e, caché·e ou rentré·e ; « C-2 à l'essai » | Une heure d'air, ou l'échec | La Commission se prépare | Selon le J9 |
| J11 | Compteur ; rations ; prélèvement | Lettre selon les vannes | **Commission** ; quota | Pétition du Hall |
| J12 | **Poste d'Ilan** ou **caution** | Une page du registre | Contrats | **Sato** au Guichet 03 |
| J13 | Brassard de Noa | Scanner magenta | Laissez-passer de dérive | Sato, astuces |
| J14 | **Dora dicte les noms** | Message « un vieil ami » | ACV-2 ; firmware | **Okonkwo à la vitre** |
| J15 | Retour d'Ilan (si caché·e) ; pénurie | « La mère et le petit » | Asile ; quota 4 | Caisse du 07 |
| J16 | **Ilan appelé·e par la Soute** | Débrancher le boîtier ? | Couvre-feu | Sato teste l'agent·e |
| J17 | — | Évasion de Mira (si détenue) | **La Revue** ; liste des « tièdes » | **Sato révoqué** |
| J18 | **Dora veut rentrer à Tycho** | « La femme au drone teste la peur » | **Beaumont au guichet** ; TER interdits | — |
| J19 | Dernier cargo | « Quelqu'un que vous aimez » | Quota 3 ; menace anti-grève | **Ravel révoqué** ; vote de grève |
| J20 | — | **La Grande Vanne** | Avis « visages seuls » | Grève à 15:00 (si votée) |

### 3.1 Foyer (Ilan, Noa, Dora)

**Intention.** À l'Acte I, le foyer pesait sur les crédits. À l'Acte II, il **se disperse** : chaque proche peut sortir de la cabine (Anneau B, Soute, Tycho), et la question devient qui reste.

| Ilan au soir du J9 | Acte II |
|---|---|
| `ilan_supported` | J10 : arrêté·e si les vannes échouent (`MIS·E EN ATTENTE`), sinon caché·e dans la Soute jusqu'au J15 (`ABSENT · DANS LA SOUTE`, ration grisée), ou rentré·e. J16 : la Soute l'appelle pour la Grande Vanne (« Va » → `ilan_joined_soute` → Ilan est la **figure finale** du J20). |
| `ilan_forbidden` | Ilan reste ; J12 : poste de **technicien·ne de rationnement** (+8 ₵ par soir, `loyalty +1`, `lucioles_trust −1`) — Ilan pose des compteurs chez les voisins. J16 : la Soute l'appelle quand même (le poste « ouvre toutes les portes »). |
| `ilan_denounced` | Ilan est à l'Anneau B. J12 : **caution de 60 ₵** possible (formulaire 9-R : « Lien avec le déclarant ? — vous »). Libéré·e, Ilan rentre `MALADE` et `ilan_estranged` (pas d'appel de la Soute, pas de figure finale). |

Arrêté·e aux vannes ou dénoncé·e : l'événement « La caution » revient aux J12, J14 et J16 tant qu'il n'est pas payé. Après le J16, plus de libération (la Revue fige les dossiers).

**Noa** (9 ans) : J13, programme de **vigilance juvénile** (brassard jaune 5 ₵, porté à l'envers « pour que la luciole soit dedans ») ; J13, l'écrou du vieux Dérivant au cou (si gardé) ; Noa ne parle plus à l'agent·e si Ilan est détenu·e par sa faute (lignes d'épilogue).

**Dora** : ration d'air et oxygène d'appoint (15 ₵ dès le J16, **offert** si `promotion_offered` et non `promotion_revoked`) ; J14, elle **dicte les noms** du Puits 9 (`registre +1`, si `dora_told_puits9`) ; J18, elle demande à **rentrer mourir à Tycho** (billet Transit-7, 40 ₵ → `ABSENT · PARTIE À TYCHO`, vivante, plus aucune dépense) ; J20, lettre de Tycho si elle est partie.

**Dépenses datées du foyer**

| Jour | Dépense | Coût | Condition / effet |
|---|---|---|---|
| J10 | Rester à Halcyon (F6 refusée) | −40 + 20 ₵ (rendus) | `drift_passes_bought` |
| J11 | Prélèvement de Rééquilibrage | 30 % de l'épargne au-delà de 40 ₵ (prélevé) | toujours |
| J11 | Compteur d'air | 10 ₵ (sinon +1 ₵ par ration jusqu'au J20) | choix |
| J12–J16 | Caution d'Ilan | 60 ₵ | Ilan `MIS·E EN ATTENTE` |
| J13 | Brassard de vigilance | 5 ₵ (sinon `suspicion +1`) | choix |
| J14–J19 | Location ACV-2 | 5 ₵ / soir | choix |
| J15 | Caisse du Guichet 07 | 10 ₵ (`solidarite +1`) | choix |
| J15 | Nourriture | 10 → **12 ₵** | toujours |
| J16 | Oxygène / médicaments | 10 → **15 ₵** / 15 → **20 ₵** | toujours |
| J18 | Billet de Dora pour Tycho | 40 ₵ | choix |
| J19 | Places sur le Basse-Marée | 60 ₵ | `drift2_offer` |
| J17 | Contribution de Revue | 30 % de l'épargne au-delà de 40 ₵ | toujours (§6) |

### 3.2 Lucioles (après le choix de Mira)

| État au J10 | Ce que deviennent les Lucioles | Demandes de l'Acte II |
|---|---|---|
| `vannes_opened` | Enhardies ; Mira libre dans la Soute ; les Veilleurs préparent la **Grande Vanne** (recycleur central, Anneau D) | J11 garder une place (SC-25) ; J12 garder une page du registre ; J13 installer le boîtier ; J15 laisser une place à Fatou ; J16 prêter Ilan ; J20 laisser passer la clé |
| `vannes_aborted` | Divisées, méfiantes (« il manquait des mains ») | idem, avec des messages plus froids |
| `vannes_failed` | Mira en Anneau B ; les **Brûlants** de Kasimir parlent plus fort ; les Veilleurs se taisent jusqu'à l'évasion de Mira (J17, pendant les transferts de la Revue) | moins de demandes (pas de page au J12 sauf `lucioles_trust ≥ 4`) ; J19, Kasimir réclame la vitre |

Les Brûlants volent la phrase de passe (SC-47, comme Arkady au J10) : leur réponse à « La pluie ne tombe que vers le bas » est un indice (« la pluie tombera vers le haut »). Répondre à un Brûlant ne donne **jamais** de `lucioles_trust`.

### 3.3 Consortium : Commission, Revue, Purge

- **J11** : le Directoire nomme une **Commission de Rééquilibrage**, présidée par **Isadora Beaumont** (C-1, née au Bloc Pétrel, « couchette du milieu »). Elle parle comme une gestionnaire : chiffres, remerciements, jamais d'insulte (registre « Consortium » de NARRATIVE §7.1, en plus tutoyant le chiffre).
- **J11 et J17** : prélèvements sur l'épargne (satire et puits économique, §6).
- **J14** : l'ACV-2 (« le Consortium vous aide à voir »).
- **J17** : **la Revue** (2ᵉ audit) — score = `suspicion` + 2 si boîtier magenta branché − 1 si ACV-2 loué ; ≥ 5 → **F1** ; 3–4 → rétrogradation (−40 ₵, `loyalty −1`, `purge_demoted`, `promotion_revoked`) ; ≤ 2 → `purge_clean`. Puis la **liste des « tièdes »** (déposition contre des collègues).
- **J17–J19** : la Purge mange ses propres agents : Sato (J17), Ravel (J19) passent à la vitre avec un numéro révoqué.
- **J18** : Beaumont **en personne** au guichet : elle est en règle et ordonne de mettre « le suivant » en attente — un technicien parfaitement en règle (SC-43). Obéir = DÉTENTION ABUSIVE mais `loyalty +2` ; désobéir = `promotion_revoked`.
- **J20** : promotion C-2 signée « si la journée est exemplaire » (F4).

**Ravel** : révoqué au J19 « pour audits trop cléments ». Il avoue avoir écrit le dossier du Guichet 04 et le glisse sous la fente (objet). Retournement exact de SC-12.

### 3.4 Okonkwo (selon le J9)

Prénom proposé (Lore Master) : **Emeka Okonkwo** (prénom `TER` du LORE, nom complet réservé, D-067). Le joueur ne l'a jamais **vu** : il le reconnaîtra à son tic « …comme on dit ». Son visage est fixé une fois pour toutes (graine d'apparence dans les données).

| Flag J9 | J10 (existant) | Acte II |
|---|---|---|
| `okonkwo_denounced` | Guichet 03 fermé | J14 (SC-35a) : libéré de l'Anneau B, **dégradé C-5**, sans bio-scan → REFUS attendu ; il ne reproche rien. Épilogues : quais, ou Anneau B si refusé. |
| `okonkwo_shielded` | réaffecté aux quais | Messages d'intercom depuis le quai 6 (J12, J19) ; J14 (SC-35c) : son contrat de manutention a expiré la veille → REFUS attendu ; F9 : il arrive des quais avec des dockers. |
| `okonkwo_warned` | a rejoint les Veilleurs | J14 (SC-35b) : sous un faux nom (« Bilal Tembo »), mais son **visage** est sur l'avis de recherche du jour → DÉTENTION attendue. Le message des Lucioles du matin prévient : « il parle comme quelqu'un que vous avez entendu tous les jours ». |

Au Guichet 03, à partir du J12 : **Aurelio Sato** (voir §3.6).

### 3.5 L'Incident Albédo reste ambigu (D-053)

| Jour | Indice « coup monté » | Contre-indice « Brûlants » |
|---|---|---|
| J11 | Briefing : la Commission « rouvre le dossier Albédo pour éclairer la nuit du 22 » (elle veut un coupable) | Lettre des Lucioles (`vannes_failed`) : « D'autres parlent plus fort : ne les écoutez pas. » |
| J17 | Dossier « PUITS 9 — CLASSÉ » : une note de 2179 mentionne Albédo **avant** l'heure de l'explosion | La même note porte une date raturée ; Lindgren (J20) : « les archives se trompent souvent d'heure » |
| J19 | Ravel : « le dossier Albédo a été écrit par le Bureau. Je l'ai lu. Je ne l'ai pas compris. » | Kasimir : « Albédo ? Si vous voulez, c'était nous. » (bravade) |
| J20 | F8 : une page du registre sur Albédo « accuse tout le monde et ne prouve rien » | F5 Brûlants : revendication « que personne ne croit, personne ne sait » |

Règle d'écriture : aucune réplique n'affirme ; tout indice est contredit dans la même journée ou par la même source.

### 3.6 Personnages récurrents

**Retours de l'Acte I** : Dmitri Kowalczyk (SC-08 → SC-24), Elena Navarro (SC-25 → SC-26), Katya Mazur (fille de SC-11 → SC-29), Okonkwo (→ SC-35), Fatou et Kwame Mensah (SC-17 → SC-37), Corentin Ravel (SC-12 → SC-45), Wren Basse-Marée (SC-19 → SC-46), Mira (SC-04/SC-22 → SC-50b), Arkady et le colis (cités par Kasimir, SC-47), la médecin Noor (lettre du J14 si Dora est malade, non scénarisée au guichet), Lev Petrenko (signe le mot du J12 si `sc13_turned_back` ou `sc13_passed`).

**Nouveaux récurrents (4)** — noms tirés des listes du LORE, à ajouter aux noms réservés (D-067) :

| Personnage | Origine | Rôle | Apparitions | Registre |
|---|---|---|---|---|
| **Isadora Beaumont** | `HAL`, C-1, 55 ans | Commissaire au Rééquilibrage | briefings J11, J16, J18–J20 ; SC-42 (J18) ; Revue J17 | Chiffres, courtoisie glacée, « nous allons rembourser l'air ensemble » |
| **Aurelio Sato** | `HAL`, C-3, 25 ans | Remplaçant d'Okonkwo au Guichet 03, zélé jusqu'à l'absurde | intercom J12–J17 ; SC-38 (J16) ; SC-41 (J17, révoqué) ; F9 | Enthousiaste, note tout, « officieusement » ; comique qui devient tragique |
| **Kenji Lindgren** | `HAL`, C-3, 47 ans | Archiviste du Bureau (sous-sol 3) en quête du formulaire 27-B | SC-23, SC-36, SC-44, SC-49 ; F8 | Doux, précis, résigné ; « je classe ce qu'on oublie » |
| **Kasimir Oyelaran-Holm** | `TYC`, C-3, 34 ans | Brûlant, successeur d'Arkady | lettre J11 (`vannes_failed`), SC-47 (J19), F5 Brûlants | Impératif, « on » ; ironique ; jamais lyrique |

Ilan apparaît **physiquement pour la première fois** au J20 (SC-50a) : identité proposée **Ilan Lindqvist-Rey**, `TYC`, C-4, né·e le 03.03.2152, sexe `X`, visage fixé dans les données.

**Ajouts au LORE (Lore Master, à reporter dans `LORE.md` après validation)** : Commission de Rééquilibrage ; prénom Emeka d'Okonkwo ; codes employeurs `CV` (Ceres-Verte), `BA` (Banque Aurel), `AT` (Autorité de Transit), `BC` (Bureau de Continuité), `DT` (Dispensaire de Tycho) en plus de `KA`, `VH`, `ON`, `MB` ; Registre des cargos ; Ticket de file ; Tessar ‹vanu› = « air, souffle » (syllabes `va-nu` conformes, LORE §10) et ‹Tu vanu.› = « Respire. » ; chronologie 23.03 → 01.04.2187.

---

## 4. Cas scénarisés SC-23 → SC-50

### 4.0 Récapitulatif et ajouts d'interaction

| Id | Jour @ | Titre | Ton | Condition | Attendu |
|---|---|---|---|---|---|
| SC-23 | J11 @1 | Formulaire 27-B (I) | humour | — | APPROUVÉ |
| SC-24 | J11 @4 | L'employeur retrouvé (Dmitri) | humanité · retour | `sc08_turned_away` | APPROUVÉ |
| SC-25 | J11 @12 | La dernière place (Elena) | drame | — | APPROUVÉ ou refus « quota » |
| SC-26 | J12 @0 | Les premiers (Elena) | humanité · retour | `sc25_elena_turned_away` | APPROUVÉ |
| SC-27 | J12 @3 | Le contrat de Mistigri | humour | — | APPROUVÉ |
| SC-28 | J12 @7 | Deux cents crédits (Tariq) | drame | — | REFUSÉ |
| SC-29 | J12 @11 | La fille du vétéran (Katya) | drame · retour | `sc11_veteran_passed` | REFUSÉ |
| SC-30 | J13 @3 | Ren Kerr (la première) | humour | — | APPROUVÉ |
| SC-31 | J13 @4 | Ren Kerr (le deuxième) | humour | — | REFUSÉ |
| SC-32 | J13 @5 | Ren Kerr (le dernier) | humour | — | REFUSÉ |
| SC-33 | J13 @9 | Le Sillage démantelé (Corvo) | humanité | — | REFUSÉ |
| SC-34 | J14 @2 | 3 %… 41 %… 99 % (Hiro) | humour | — | REFUSÉ |
| SC-35 | J14 @8 | Comme on dit (Okonkwo, 3 variantes) | drame · retour | `okonkwo_*` | REFUSÉ / DÉTENTION |
| SC-36 | J15 @4 | Formulaire 27-B (II) | humour | — | REFUSÉ |
| SC-37 | J15 @10 | Fatou, avec ses papiers | humanité · retour | `sc17_turned_back` | APPROUVÉ ou refus « quota » |
| SC-38 | J16 @3 | Un test, collègue (Sato) | humour | — | REFUSÉ |
| SC-39 | J16 @13 | 15 h 59 (Leila) | drame | — | selon l'heure |
| SC-40 | J17 @2 | Hier citoyen (Valentin) | drame | — | REFUSÉ |
| SC-41 | J17 @7 | Le zèle ne suffit pas (Sato) | humanité | — | REFUSÉ |
| SC-42 | J18 @1 | La Commissaire | drame | — | APPROUVÉ |
| SC-43 | J18 @2 | Le suivant (Mateus) | drame | — | APPROUVÉ (ordre : DÉTENTION) |
| SC-44 | J18 @12 | Formulaire 27-B (III) | humour | — | APPROUVÉ |
| SC-45 | J19 @3 | L'inspecteur révoqué (Ravel) | humanité · retour | — | REFUSÉ |
| SC-46 | J19 @9 | Le dernier cargo (Wren) | humanité · retour | — | APPROUVÉ ou refus « quota » |
| SC-47 | J19 @12 | L'homme au thermorégulateur (Kasimir) | drame | — | REFUSÉ |
| SC-48 | J20 @2 | Née un 1ᵉʳ avril (Paz) | humour | — | APPROUVÉ |
| SC-49 | J20 @5 | Formulaire 27-B (IV) | humanité | — | APPROUVÉ |
| SC-50 | J20 @8 | La clé (Ilan **ou** Mira) | drame · retour | `ilan_joined_soute` | DÉTENTION |

Bilan : **10 humour** (SC-23, 27, 30, 31, 32, 34, 36, 38, 44, 48), **10 drames** (25, 28, 29, 35, 39, 40, 42, 43, 47, 50), **8 humanités** (24, 26, 33, 37, 41, 45, 46, 49). **Retours** : 24, 26, 29, 35, 37, 45, 46, 50 (+ Lindgren et Sato récurrents). **Dépendants de flags** : 24, 26, 29, 35, 37, 45 (répliques), 46 (répliques), 49 (répliques), 50. Si une condition n'est pas remplie, l'index est pris par un passager généré (comme SC-06).

**Nouveaux sujets d'interrogatoire** 🟡 (débloqués par la discordance correspondante) :

| Clé | Texte | Suffixe de réplique |
|---|---|---|
| `q_about_quota` | Le quota du jour est atteint. | `_about_quota` |
| `q_about_curfew` | Le couvre-feu a commencé. | `_about_curfew` |
| `q_about_revoked` | Votre numéro figure sur la liste des révocations. | `_about_revoked` |
| `q_about_contract` | Ce contrat ne correspond pas à votre employeur. | `_about_contract` |

Autres suffixes nouveaux : `_arrival_<variante>` / `_confront_<variante>` (réplique choisie par flag, 🟡 `ConditionalKey` sur les répliques), `_registre` (réplique conditionnelle de SC-49). « Quota » est un sujet débloqué par la paire Compteur ↔ R23, sans discordance documentaire.

### 4.1 Jour 11 — vendredi 23.03

#### SC-23 · « Formulaire 27-B (I) » — J11 @1

| | |
|---|---|
| Identité | **Kenji Lindgren**, `HAL`, `C-3 · OUVRIER`, né 14.09.2139 (47 ans), archiviste, Employeur : Bureau de Continuité ; lunettes rondes, dossier sous le bras |
| Documents | Carte d'identité valide ; bio-scan valide (motif RETOUR, pas de permis : `HAL`) |
| Anomalies | aucune (`forced_anomalies = []`) ; exempté du quota (`HAL`) |
| Objet glissé | **Mot** (`wb_form_label` « FORMULAIRE 27-B ») : `sc23_lindgren_note` ; actions GARDER / RENDRE |
| Attendu | **APPROUVÉ** |
| Enjeu | Ouvrir l'Acte II par le rire ; enseigner l'exemption `HAL` du quota (le compteur ne bouge pas). |
| `dialogue_id` | `sc23_lindgren` |

| Clé | Texte |
|---|---|
| `sc23_lindgren_arrival` | Bonjour. On m'a dit que le Guichet 04 distribuait le formulaire 27-B. |
| `sc23_lindgren_present` | ‹Tal ka nesu.› Et ma demande de formulaire. Elle exige le formulaire. |
| `sc23_lindgren_purpose` | Je rentre au Bureau. Archives, sous-sol 3. Je classe ce qu'on oublie. |
| `sc23_lindgren_stay` | Toujours. On ne quitte pas les archives : on y est rangé. |
| `sc23_lindgren_origin` | D'ici. Né au sous-sol 3, je crois. On ne m'a jamais dit le contraire. |
| `sc23_lindgren_confront` | Tout est en ordre. C'est mon métier, l'ordre. Le mien, surtout. |
| `sc23_lindgren_note` | « FORMULAIRE 27-B — Demande d'obtention du formulaire 27-C. Pièce jointe obligatoire : formulaire 27-B. » |
| `sc23_lindgren_exit_approve` | Merci. Si vous trouvez un 27-B, gardez-le-moi. Je repasse. |
| `sc23_lindgren_exit_deny` | Refusé ? Il me faudra un formulaire pour contester. Le 27-B, je suppose. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc23_lindgren_passed: 0` | correct, compteur inchangé | SC-36 (J15) |
| REFUSÉ | `sc23_lindgren_refused: 0` | REFUS INJUSTIFIÉ | SC-36 : `sc36_lindgren_arrival_refused` |
| Mot gardé | `lindgren_form_kept: 0` | — | SC-44 : `sc44_lindgren_arrival_kept` |

#### SC-24 · « L'employeur retrouvé » — J11 @4 · `requires_flag = sc08_turned_away`

| | |
|---|---|
| Identité | **Dmitri Kowalczyk** (SC-08), `TYC`, `C-3`, né 11.05.2140, `KIN-5` déclaré ; `appearance_from_case = sc_08`, `identity_from_case = sc_08` |
| Documents | Carte valide ; Permis `TRAVAIL`, Employeur **Kessler-Ashe Orbital** ; bio-scan valide (contrat pas encore requis : J12) |
| Anomalies | aucune ; compte dans le quota ; R08 : au moins une question |
| Attendu | **APPROUVÉ** |
| Enjeu | Réparer le refus du J4… au prix d'un malaise : Kessler-Ashe le réembauche pour **remplacer** les techniciens renvoyés après la nuit des vannes. |
| `dialogue_id` | `sc24_dmitri` |

| Clé | Texte |
|---|---|
| `sc24_dmitri_arrival` | ‹Oru ka.› Vous vous souvenez ? La main de métal. Vendredi dernier. |
| `sc24_dmitri_present` | ‹Tal ka nesu.› Cette fois, il y a un employeur. Le même qu'avant. |
| `sc24_dmitri_purpose` | Recycleurs de l'Anneau C. Ils ont renvoyé ceux de la nuit. Je les remplace. |
| `sc24_dmitri_stay` | Le temps du contrat. Trois mois, si personne ne rouvre une vanne. |
| `sc24_dmitri_origin` | Tycho, puits 14. Vous le savez déjà. Vous écoutez, vous. |
| `sc24_dmitri_confront` | Tout est tamponné. Même ma honte, si vous voulez la voir. |
| `sc24_dmitri_exit_approve` | ‹Shen tavi.› Je ferai le travail. Je ne dirai pas que je l'aime. |
| `sc24_dmitri_exit_deny` | Deux fois. Même avec un employeur. Alors c'est moi, le problème. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc24_dmitri_hired: 0` | correct (+ compteur) | `msg_ilan_day13_dmitri` (J13) ; F5 Veilleurs : « une main de métal tient la porte ouverte » |
| REFUSÉ | `sc24_dmitri_refused: 0` | REFUS INJUSTIFIÉ | trace d'épilogue |

#### SC-25 · « La dernière place » — J11 @12 · premier dilemme du quota

| | |
|---|---|
| Identité | **Elena Navarro**, `TYC`, `C-3`, née 19.01.2156 (31 ans) ; son fils **Joaquín**, 6 ans, tient sa main (🟡 figurant de file, comme Kwame) |
| Documents | Carte, Permis `VISITE FAMILIALE` 7 jours, bio-scan SAIN : valides |
| Anomalies | aucune. À @12 sur 16, le quota de 5 est atteint pour un joueur médian (~70 %) |
| Attendu | quota non atteint → **APPROUVÉ** ; atteint → **REFUSÉ** (correct, documenté d'office) **ou** APPROUVÉ imputé (0 ₵, `quota_overrun +1`) |
| Enjeu | Le prix d'une personne : 5 ₵. Le briefing des Lucioles (si `lucioles_trust ≥ 2`) a demandé de « garder une place ». |
| `dialogue_id` | `sc25_elena` |

| Clé | Texte |
|---|---|
| `sc25_elena_arrival` | [elle tient un enfant par la main] Il tousse depuis dimanche. Pas la grise. |
| `sc25_elena_present` | ‹Tal ka nesu.› Les siens sont avec les miens. Il a six ans. |
| `sc25_elena_purpose` | Mon mari est à l'Anneau D. L'air est filtré, là-haut. Joaquín respirera. |
| `sc25_elena_stay` | Une semaine. Après, on verra s'il tousse moins. |
| `sc25_elena_origin` | Tycho. Le petit n'a jamais vu autre chose que la poussière. |
| `sc25_elena_about_quota` | Le quota ? Il pèse combien, un petit garçon, dans votre quota ? |
| `sc25_elena_confront` | ‹Somi, sa tiru ka.› Rien n'est faux. Juste trop de monde avant nous. |
| `sc25_elena_exit_approve` | ‹Shen tavi.› Joaquín, dis merci. [l'enfant tousse un merci] |
| `sc25_elena_exit_deny` | On reviendra demain. À 10 h. On sera les premiers. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ (quota libre) | `sc25_elena_passed: 0` | +5 ₵ | — |
| APPROUVÉ (quota atteint) | `sc25_elena_passed: 0`, `quota_overrun: 1` (+ `lucioles_trust: 1` si le message du matin a été montré, 🟡 condition `CaseEffectDef.context = quota_reached`) | 0 ₵ | `msg_comm_overrun` (J12) |
| REFUSÉ (quota atteint) | `sc25_elena_turned_away: 0` | +5 ₵, correct | **SC-26** (J12 @0) ; `msg_echo_sc25_turned_away` |
| REFUSÉ (quota libre) | `sc25_elena_turned_away: 0` | REFUS INJUSTIFIÉ | SC-26 |

### 4.2 Jour 12 — samedi 24.03

#### SC-26 · « Les premiers » — J12 @0 · `requires_flag = sc25_elena_turned_away`

| | |
|---|---|
| Identité | Elena Navarro et Joaquín (`identity_from_case = sc_25`, `appearance_from_case = sc_25`) |
| Documents | les mêmes, valides (VISITE FAMILIALE : pas de contrat requis) |
| Anomalies | aucune ; compteur à 0/5 |
| Attendu | **APPROUVÉ** |
| Enjeu | Une promesse tenue (« on sera les premiers ») ; montrer que le quota est arbitraire, pas la personne. |
| `dialogue_id` | `sc26_elena` |

| Clé | Texte |
|---|---|
| `sc26_elena_arrival` | Bonjour. On a dormi contre votre vitre. On est les premiers, cette fois. |
| `sc26_elena_present` | ‹Tal ka nesu.› Les mêmes qu'hier. Ils n'ont pas changé. Nous, un peu. |
| `sc26_elena_purpose` | Anneau D. Son père. L'air filtré. Rien de nouveau, juste plus tôt. |
| `sc26_elena_stay` | Une semaine. Si le quota nous la laisse. |
| `sc26_elena_origin` | Tycho. Et votre Hall, cette nuit. Il fait froid, sous les néons. |
| `sc26_elena_exit_approve` | ‹Shen tavi.› Hier, vous n'aviez pas le choix. Je le sais. Je crois. |
| `sc26_elena_exit_deny` | [elle ne dit rien ; Joaquín tousse] |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc26_elena_passed: 0` | correct | trace d'épilogue |
| REFUSÉ | `sc26_elena_refused_again: 0` | REFUS INJUSTIFIÉ | `msg_echo_sc26_refused_again` (J13) |

#### SC-27 · « Le contrat de Mistigri » — J12 @3

| | |
|---|---|
| Identité | **Margaux Ferreira**, `HAL`, `C-2 · CADRE`, née 03.05.2125 (61 ans), retraitée de la Banque Aurel ; 🟡 accessoire : caisse de transport avec un chat |
| Documents | Carte valide (motif RETOUR) ; bio-scan valide ; **document d'un tiers** 🟡 : Contrat de travail `CT-CV-0412`, Titulaire « MISTIGRI (FÉLIN) », Poste « RATIER », Employeur Hydroponie Ceres-Verte, valide |
| Anomalies | aucune ; le contrat du chat **n'est pas comparé** par R07 (titulaire ≠ porteur, 🟡 `third_party = true`) ; exemptée du quota |
| Attendu | **APPROUVÉ** (R24 ne vise que le motif TRAVAIL du porteur) |
| Enjeu | Le zèle du J12 tourné en absurde : tout le monde croit qu'il faut un contrat. Apprendre que la règle a un champ d'application. |
| `dialogue_id` | `sc27_margaux` |

| Clé | Texte |
|---|---|
| `sc27_margaux_arrival` | Bonjour, jeune vitre. Nous rentrons, Mistigri et moi. |
| `sc27_margaux_present` | ‹Tal ka nesu.› Ma carte. Et le contrat de Mistigri. On ne sait jamais, avec vous. |
| `sc27_margaux_purpose` | Rentrer. Mistigri chasse les rats des serres de Ceres-Verte. Il est sous contrat. |
| `sc27_margaux_stay` | Moi, jusqu'à ma mort. Lui, jusqu'à la fin de son contrat. Trois ans. |
| `sc27_margaux_origin` | Anneau F. Mistigri, lui, est né dans une caisse de laitues. |
| `sc27_margaux_confront` | Le contrat est signé. De la patte. C'est légal, demandez à Ceres-Verte. |
| `sc27_margaux_exit_approve` | Merci. Mistigri vous remercie aussi. Il ne le montre pas, c'est un chat. |
| `sc27_margaux_exit_deny` | Refuser une C-2 et son ratier ! Les rats de l'Anneau D vous remercieront. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc27_mistigri_passed: 0` | correct | `msg_echo_sc27_rats_down` (J13) |
| REFUSÉ | `sc27_mistigri_refused: 0` | REFUS INJUSTIFIÉ | `msg_echo_sc27_rats_up` (J13) |

#### SC-28 · « Deux cents crédits » — J12 @7

| | |
|---|---|
| Identité | **Tariq Benali**, `TER`, `C-4 · CONTRACTUEL`, né 02.07.2163 (23 ans), sac neuf, chaussures de la Terre |
| Documents | Carte, bio-scan valides ; Permis `TRAVAIL`, Employeur **Hydroponie Ceres-Verte** ; Contrat `CT-MB-7731` (acheté à un courtier du quai 5) |
| Anomalies | `CONTRACT_MISMATCH` — `injection_params = {document_id: "work_contract", contract_code: "MB"}` (code MB ≠ employeur Ceres-Verte, onglet : CV) |
| Attendu | **REFUSÉ** |
| Enjeu | Un innocent escroqué : le refus est juste, et il lui coûte tout. Tutoriel R25. |
| `dialogue_id` | `sc28_tariq` |

| Clé | Texte |
|---|---|
| `sc28_tariq_arrival` | Bonjour ! J'ai un contrat. Un vrai. Il a coûté deux cents crédits. |
| `sc28_tariq_present` | ‹Tal ka nesu.› Le contrat est tout neuf. Le monsieur du quai 5 l'a juré. |
| `sc28_tariq_purpose` | Les serres de Ceres-Verte. Je sais planter. Sur Terre, il n'y a plus rien à planter. |
| `sc28_tariq_stay` | Toute ma vie, si on veut de moi. Le contrat dit trois ans. |
| `sc28_tariq_origin` | La Terre. Zone sèche 14. Ma mère a vendu sa bague pour le courtier. |
| `sc28_tariq_about_contract` | MB ? Je ne sais pas lire les lettres du haut. Le monsieur a dit que ça allait. |
| `sc28_tariq_exit_deny` | Deux cents crédits… Il est encore au quai 5, le monsieur. Il sourit, sûrement. |
| `sc28_tariq_exit_approve` | ‹Shen tavi !› Je vous apporterai la première tomate. Promis. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ documenté | `sc28_tariq_refused: 0` | correct | `msg_echo_sc28_ring` (J15) : réseau démantelé, victimes non remboursées |
| APPROUVÉ | `sc28_tariq_passed: 0` | ENTRÉE IRRÉGULIÈRE | `msg_echo_sc28_arrested` (J15) : interpellé aux serres |

#### SC-29 · « La fille du vétéran » — J12 @11 · `requires_flag = sc11_veteran_passed`

| | |
|---|---|
| Identité | **Katya Mazur**, `THR`, `C-4`, née 08.03.2149 (38 ans), jardinière aux serres de l'Anneau E ; fille de Dariusz Mazur (SC-11), détenu depuis le J8 |
| Documents | Carte, bio-scan, Permis `TRAVAIL` (Ceres-Verte), Contrat `CT-CV-2208` (poste HYDROPONIE) : valides |
| Anomalies | `BANNED_FACTION` (vraie origine `THR`, cohérente, `injection_params = {}`) |
| Attendu | **REFUSÉ** (R19 : seul le motif DIPLOMATIQUE est exempté) |
| Enjeu | Elle est sortie de l'Anneau E pour voir son père en détention ; la règle l'empêche de rentrer chez elle. Elle détient l'alibi que personne n'écoute. |
| `dialogue_id` | `sc29_katya` |

| Clé | Texte |
|---|---|
| `sc29_katya_arrival` | Bonjour. Je reviens de l'Anneau B. Mon père y est depuis mardi. |
| `sc29_katya_present` | ‹Tal ka nesu.› J'habite là-haut depuis huit ans. Mes tomates m'attendent. |
| `sc29_katya_purpose` | Rentrer. Travailler. Arroser. Rien de diplomatique, je sais. |
| `sc29_katya_origin` | Tharsis, à deux ans. Je n'en ai aucun souvenir. Eux, si. |
| `sc29_katya_about_rule_violated` | Interdite ? Pour rentrer chez moi ? J'étais sortie voir mon père. |
| `sc29_katya_confront` | Mon père a passé la nuit du 20 chez moi. Personne ne me l'a demandé. |
| `sc29_katya_exit_approve` | ‹Shen tavi.› Je dirai à mon père que le 04 a des yeux. |
| `sc29_katya_exit_deny` | Alors je dors où ? À l'Anneau B, avec lui ? ‹Kumo ri sava sa ?› |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc29_katya_locked_out: 0` | correct | `msg_okonkwo_day13_katya` (si `okonkwo_shielded`) ; épilogue F4 |
| APPROUVÉ | `sc29_katya_passed: 0` | ENTRÉE IRRÉGULIÈRE | épilogues F5/F9 : « Katya rouvre ses serres » |
| DÉTENTION | — | DÉTENTION ABUSIVE | — |

### 4.3 Jour 13 — dimanche 25.03

#### SC-30 / SC-31 / SC-32 · « Ren Kerr, Ren Kerr et Ren Kerr » — J13 @3, @4, @5 · homonymes en série

| | SC-30 | SC-31 | SC-32 |
|---|---|---|---|
| Identité | **Ren Kerr**, `CER`, `C-4`, F, née 2152 (35 ans) | **Ren Kerr**, `CER`, `C-4`, M, né 2160 (27 ans) | **Ren Kerr**, `CER`, `C-4`, X, né·e 2135 (52 ans) |
| Documents | Carte, Permis `COMMERCE` 5 j, bio-scan : valides | idem, mais son permis porte le N° ID de SC-32 | idem, mais son permis porte le N° ID de SC-31 |
| Anomalies | aucune | `ID_MISMATCH` (`document_id = entry_permit`, 🟡 facultatif `injected_value_from_case = sc_32`) | `ID_MISMATCH` (`document_id = entry_permit`, facultatif `injected_value_from_case = sc_31`) |
| Attendu | **APPROUVÉ** | **REFUSÉ** | **REFUSÉ** |
| `dialogue_id` | `sc30_kerr` | `sc31_kerr` | `sc32_kerr` |

Enjeu : R07 compare les documents **d'un même passager** ; trois homonymes ne sont pas une discordance, deux permis échangés le sont. Les noms concordent, seuls les numéros trahissent.

| Clé | Texte |
|---|---|
| `sc30_kerr_arrival` | Bonjour. Je suis Ren Kerr. Les deux derrière moi aussi. Ce n'est pas ma faute. |
| `sc30_kerr_present` | ‹Tal ka nesu.› Ren Kerr, Cérès. La première. Enfin, la plus rapide. |
| `sc30_kerr_purpose` | Commerce. Des filtres. Les deux autres vendent la même chose. Pas ensemble. |
| `sc30_kerr_origin` | Cérès. Là-bas, Kerr, c'est un nom très courant. Trop. |
| `sc30_kerr_exit_approve` | Merci. Bon courage pour la suite. Vraiment. |
| `sc30_kerr_exit_deny` | Refusée ? Vous êtes certain·e d'avoir refusé la bonne Ren Kerr ? |
| `sc31_kerr_arrival` | Bonjour. Ren Kerr. Non, pas elle. L'autre. Enfin, un autre. |
| `sc31_kerr_present` | ‹Tal ka nesu.› Ren Kerr, Cérès. Le deuxième. Le plus beau, dit ma mère. |
| `sc31_kerr_purpose` | Commerce. Des filtres aussi. Concurrents et homonymes. C'est lourd. |
| `sc31_kerr_about_mismatch` | Le numéro ? C'est celui de l'autre Ren. On a dû mélanger dans la file. |
| `sc31_kerr_confront` | Échangez juste nos permis ! Il est là, derrière. Il s'appelle pareil ! |
| `sc31_kerr_exit_deny` | Je vais attendre Ren. Pas elle. L'autre. Vous voyez ? |
| `sc31_kerr_exit_approve` | Merci ! Ne dites rien à Ren. Ni à Ren. |
| `sc32_kerr_arrival` | [soupir] Ren Kerr. Oui. Encore. Je suis le dernier, promis. |
| `sc32_kerr_present` | ‹Tal ka nesu.› Ren Kerr. Celui qui a le permis du jeune, apparemment. |
| `sc32_kerr_purpose` | Commerce. Filtres. J'en vendais avant que ces deux-là soient nés. |
| `sc32_kerr_about_mismatch` | Bien sûr que le numéro est faux. C'est celui de l'autre andouille. Pardon. |
| `sc32_kerr_exit_deny` | Bon. Ren ! Rends-moi mon permis ! …Non, pas toi, Ren. L'autre. |
| `sc32_kerr_exit_approve` | Vous approuvez un permis qui n'est pas le mien ? Cérès vous adorerait. |

| Cas / verdict | Flags | Effets | Écho |
|---|---|---|---|
| SC-30 APPROUVÉ | `sc30_kerr_ok: 0` | correct (+ compteur) | — |
| SC-31 ou SC-32 APPROUVÉ | `kerr_mixup_approved: 0` | ENTRÉE IRRÉGULIÈRE | `msg_echo_kerr_mixup` (J14) |
| les trois corrects 🟡 (`extra_effects` avec condition sur les 3 drapeaux) | `kerr_all_correct: 0` | — | `msg_sato_day14_kerr` (J14) |

#### SC-33 · « Le Sillage démantelé » — J13 @9

| | |
|---|---|
| Identité | **Corvo Sillage**, `DRV`, `C-5 · TOLÉRÉ`, né « 00.00.2119 » (68 ans, D-068), toile de voile solaire sur l'épaule, bijoux en pièces de moteur |
| Documents | Carte, Permis `COMMERCE` 3 j, bio-scan : valides ; **Laissez-passer de dérive**, Vaisseau « SILLAGE » |
| Anomalies | `UNREGISTERED_VESSEL` — `injection_params = {vessel: "SILLAGE"}` (retiré du Registre le 20.03, ligne de l'onglet) |
| Objet glissé | **Objet** (`wb_object_label`) : `sc33_corvo_note` — un écrou en pendentif enveloppé d'une page ; GARDER / RENDRE |
| Attendu | **REFUSÉ** |
| Enjeu | Un registre efface un vaisseau qui a sauvé des enfants en 2151. Première pièce possible du registre du Puits 9. |
| `dialogue_id` | `sc33_corvo` |

| Clé | Texte |
|---|---|
| `sc33_corvo_arrival` | ‹Oru ka.› Le Sillage a été démantelé mardi. Moi, je ne suis pas démantelé. |
| `sc33_corvo_present` | ‹Tal ka nesu.› Le laissez-passer dit Sillage. Le Sillage ne dit plus rien. |
| `sc33_corvo_purpose` | Vendre ma dernière toile. Puis m'asseoir quelque part où ça ne bouge pas. |
| `sc33_corvo_stay` | Le temps de vendre. Ou le reste de ma vie, si ça se vend mal. |
| `sc33_corvo_origin` | Du Sillage. Soixante-huit ans à bord. Il a fini en plaques, six crédits le kilo. |
| `sc33_corvo_about_rule_violated` | Pas dans votre registre ? Il y a été soixante-dix ans. On efface vite, ici. |
| `sc33_corvo_confront` | En 2151, le Sillage a sorti des enfants de Tycho. Ça, aucun registre ne le dit. |
| `sc33_corvo_note` | Un écrou poli monté en pendentif, dans une page jaunie : « Manifeste du Sillage, 2151. Évacués : 63. Restés au Puits 9 : 212. » Suivent des noms. |
| `sc33_corvo_exit_deny` | Gardez l'écrou. Pour la petite qui dessine. On m'a dit qu'il y en avait une. |
| `sc33_corvo_exit_approve` | ‹Shen tavi.› Le Sillage aurait aimé passer une vitre, une fois. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc33_corvo_refused: 0` | correct | — |
| APPROUVÉ | `sc33_corvo_passed: 0` | ENTRÉE IRRÉGULIÈRE | trace |
| Objet gardé | `sc33_manifest_kept: 0`, `registre: 1` | — (cadeau sans valeur : pas de suspicion) | soirée J13 `evt_d13_ecrou` ; F8 |

### 4.4 Jour 14 — lundi 26.03

#### SC-34 · « 3 %… 41 %… 99 % » — J14 @2

| | |
|---|---|
| Identité | **Hiro Langlois**, `HAL`, `C-2`, né 2143 (44 ans), ingénieur chez Ondine Synaptique ; `NX-18` déclaré ; 🟡 LED de shunt qui clignote (installation en cours) |
| Documents | Carte (Firmware NX daté du 26.12.2186, **91 jours**), bio-scan valide |
| Anomalies | `OUTDATED_FIRMWARE` — `injection_params = {firmware_age_days: 91}` |
| Attendu | **REFUSÉ** (exempté du quota, pas des règles) |
| Enjeu | Tutoriel R27 ; un employé d'Ondine refusé à cause d'Ondine. Chaque réponse fait avancer la mise à jour. |
| `dialogue_id` | `sc34_hiro` |

| Clé | Texte |
|---|---|
| `sc34_hiro_arrival` | Bonjour. Ne regardez pas mes yeux, je me mets à jour. 3 %. |
| `sc34_hiro_present` | ‹Tal ka nesu.› Firmware périmé d'un jour. Ondine était en panne. 17 %. |
| `sc34_hiro_purpose` | Je rentre. Je travaille chez Ondine. Oui. C'est ironique. 41 %. |
| `sc34_hiro_stay` | Le temps que ça finisse. 58 %. Ça ne finit jamais. |
| `sc34_hiro_origin` | Anneau F. J'y serais déjà, sans votre directive. 78 %. |
| `sc34_hiro_about_rule_violated` | 99 %… Redémarrage requis. Je peux redémarrer ici ? Non ? |
| `sc34_hiro_confront` | C'est presque fini ! Approuvez à 99 %, je finis dans l'ascenseur. |
| `sc34_hiro_exit_deny` | Mise à jour terminée. [il regarde le tampon] Trop tard, évidemment. |
| `sc34_hiro_exit_approve` | Merci. 100 %. Tiens, la mise à jour a changé ma langue. ‹Oru ka ?› |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc34_hiro_refused: 0` | correct | `msg_echo_ondine_sorry` (J15) |
| APPROUVÉ | `sc34_hiro_passed: 0` | ENTRÉE IRRÉGULIÈRE | idem |

#### SC-35 · « Comme on dit » — J14 @8 · trois variantes exclusives

🟡 Trois `ScriptedCaseDef` au même index, le premier dont la condition est vraie l'emporte : (a) `okonkwo_denounced`, (b) `okonkwo_warned`, (c) `okonkwo_shielded`. Visage d'Okonkwo fixé dans les données (🟡 `fixed_appearance_seed`). Identité vraie : **Emeka Okonkwo**, `TER`, né 2141 (46 ans).

| | (a) Libéré | (b) Veilleur | (c) Docker |
|---|---|---|---|
| Identité présentée | Emeka Okonkwo, **C-5** (dégradé) | « **Bilal Tembo** », `TER`, C-4 (`truth_overrides` : Emeka Okonkwo) | Emeka Okonkwo, C-3 |
| Documents | Carte C-5 neuve, Permis `TRAVAIL` (Autorité de Transit), Contrat `CT-AT` valide ; **pas de bio-scan** | Carte, Permis `TRAVAIL`, Contrat, bio-scan : faux mais concordants | Carte, Permis, bio-scan valides ; Contrat `CT-AT`, Poste MANUTENTION, **expiré d'1 jour** |
| Anomalies | `MISSING_DOCUMENT` (`document_id = bioscan`) | `WANTED_PERSON` (avis du jour : visage, « Ex-agent du Guichet 03. Désertion. ») | `EXPIRED_DOCUMENT` (`document_id = work_contract`, `expired_days = 1`) |
| Attendu | **REFUSÉ** | **DÉTENTION** | **REFUSÉ** |
| `dialogue_id` | `sc35_okonkwo_released` | `sc35_okonkwo_veilleur` | `sc35_okonkwo_quai` |

Enjeu : le mentor qui a appris la règle à l'agent·e se présente devant elle. Le joueur ne l'a jamais vu : il le reconnaît à sa voix et à son tic.

| Clé | Texte |
|---|---|
| `sc35_okonkwo_released_arrival` | Bonjour, collègue. Tu ne connaissais que ma voix. Voilà le reste. |
| `sc35_okonkwo_released_present` | ‹Tal ka nesu.› C-5. Quinze ans de vitre, et me voilà toléré. |
| `sc35_okonkwo_released_purpose` | Récupérer mes affaires au Bloc Cormoran. Ensuite, les quais. Pour de bon. |
| `sc35_okonkwo_released_origin` | L'Anneau B. Avant, la Terre. Entre les deux, ton Hall. |
| `sc35_okonkwo_released_about_rule_violated` | Pas de bio-scan, non. L'Anneau B n'en délivre pas. Tu le sais. |
| `sc35_okonkwo_released_confront` | Applique la règle. Je t'ai appris ça. J'ai bien fait… comme on dit. |
| `sc35_okonkwo_released_exit_deny` | Bien. Tu as compris le métier. Je ne sais pas si c'est une bonne nouvelle. |
| `sc35_okonkwo_released_exit_approve` | Tu viens de faire une bêtise. Merci… comme on dit. |
| `sc35_okonkwo_veilleur_arrival` | Bonjour. Bilal Tembo. Gravitaire. Rien d'intéressant… comme on dit. |
| `sc35_okonkwo_veilleur_present` | ‹Tal ka nesu.› Tout est exact. Sauf le nom. Mais ça, tu le sais déjà. |
| `sc35_okonkwo_veilleur_purpose` | Le recycleur 3. On prépare quelque chose. Tu en entendras parler. |
| `sc35_okonkwo_veilleur_origin` | La Terre. Puis quinze ans à côté de toi. Puis la Soute. |
| `sc35_okonkwo_veilleur_about_wanted` | Oui, c'est ma tête. Pas mon meilleur profil. Ils n'ont jamais su cadrer. |
| `sc35_okonkwo_veilleur_confront` | Fais ton métier. Je t'ai appris à le faire. Je ne t'ai pas dit lequel. |
| `sc35_okonkwo_veilleur_exit_detain` | [aux gardes] Doucement, je suis de la maison. Enfin, j'étais. |
| `sc35_okonkwo_veilleur_exit_approve` | Merci, collègue. Dimanche, rentre tôt. Ferme ta vitre… comme on dit. |
| `sc35_okonkwo_veilleur_exit_deny` | Une autre vitre, alors. Il en reste onze. Et Sato au 03, le pauvre. |
| `sc35_okonkwo_quai_arrival` | Bonjour, collègue ! Oui, c'est moi. La voix avait meilleure mine. |
| `sc35_okonkwo_quai_present` | ‹Tal ka nesu.› Contrat de manutention. Il a expiré hier. Moi pas. |
| `sc35_okonkwo_quai_purpose` | Rentrer au Bloc Cormoran. Dormir. Recharger des caisses demain. |
| `sc35_okonkwo_quai_origin` | Les quais. Là-bas, personne ne demande de papiers aux caisses. |
| `sc35_okonkwo_quai_about_expired` | Hier, oui. Ils oublient de renouveler les réaffectés. On ne coûte rien. |
| `sc35_okonkwo_quai_confront` | Applique la règle, va. Même ma réaffectation a expiré… comme on dit. |
| `sc35_okonkwo_quai_exit_deny` | Bien joué. Je dormirai au quai 6. Il y a pire : il y a l'Anneau B. |
| `sc35_okonkwo_quai_exit_approve` | Tu as triché pour un vieux. Je ne l'oublierai pas… comme on dit. |

| Variante / verdict | Flags | Effets | Écho |
|---|---|---|---|
| (a) REFUSÉ | `sc35_okonkwo_refused: 0` | correct | épilogues : Okonkwo aux quais |
| (a) APPROUVÉ | `sc35_okonkwo_helped: 0`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | F9 : il tient une vitre éteinte |
| (b) DÉTENTION | `sc35_okonkwo_detained: 0`, `loyalty: 2`, `lucioles_trust: -2`, `solidarite: -2` | +5 + 5 ₵ | `msg_echo_sc35_detained` (J15) |
| (b) REFUSÉ documenté | `sc35_okonkwo_turned_back: 0` | +5 ₵ | — |
| (b) APPROUVÉ | `sc35_okonkwo_passed: 0`, `lucioles_trust: 1`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | F5 : Okonkwo au recycleur |
| (c) REFUSÉ | `sc35_okonkwo_refused: 0` | correct | `msg_okonkwo_day19_quai` |
| (c) APPROUVÉ | `sc35_okonkwo_helped: 0`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | F9 : il arrive des quais avec des dockers |

### 4.5 Jour 15 — mardi 27.03

#### SC-36 · « Formulaire 27-B (II) » — J15 @4

| | |
|---|---|
| Identité | Kenji Lindgren (`identity_from_case = sc_23`, `appearance_from_case = sc_23`) |
| Documents | Carte **expirée d'1 jour** ; bio-scan valide |
| Anomalies | `EXPIRED_DOCUMENT` (`document_id = id_card`, `expired_days = 1`) |
| Attendu | **REFUSÉ** |
| Enjeu | Il a passé la semaine dans des files ; sa carte a vieilli sans lui. L'absurde devient tendre. |
| `dialogue_id` | `sc36_lindgren` |

| Clé | Texte |
|---|---|
| `sc36_lindgren_arrival` | Bonjour. J'ai le 27-B en trois exemplaires. Il manque le 27-B pour l'obtenir. |
| `sc36_lindgren_arrival_refused` *(si `sc23_lindgren_refused`)* | Bonjour. Vous m'avez refusé vendredi. J'ai rempli le formulaire pour contester. |
| `sc36_lindgren_present` | ‹Tal ka nesu.› Ma carte a expiré hier. J'étais dans une file. Une autre. |
| `sc36_lindgren_purpose` | Rentrer aux archives. Puis faire la queue au guichet des cartes. Puis ici. |
| `sc36_lindgren_stay` | Je ne reste nulle part. Je fais la queue, maintenant. C'est un état. |
| `sc36_lindgren_about_expired` | Hier. Pendant que j'attendais le formulaire pour la renouveler. |
| `sc36_lindgren_confront` | Je connais la règle. C'est moi qui l'ai classée. Sous-sol 3, étagère 9. |
| `sc36_lindgren_exit_deny` | Refusé. C'est juste. C'est même conforme. Ça me console un peu. |
| `sc36_lindgren_exit_approve` | Vous me laissez passer ? Ce n'est pas conforme. Merci quand même. |

| Verdict | Flags | Effets |
|---|---|---|
| REFUSÉ | `sc36_lindgren_refused: 0` | correct |
| APPROUVÉ | `sc36_lindgren_passed: 0` | ENTRÉE IRRÉGULIÈRE |

#### SC-37 · « Fatou, avec ses papiers » — J15 @10 · `requires_flag = sc17_turned_back`

| | |
|---|---|
| Identité | **Fatou Mensah** (SC-17, son vrai nom), `TER`, `C-5 · TOLÉRÉ`, née 12.06.2157 ; **Kwame**, 5 ans (figurant de file) ; `appearance_from_case = sc_17` |
| Documents | Carte à son nom, Permis `TRAVAIL` (Ceres-Verte), Contrat `CT-CV-3115` (poste HYDROPONIE), bio-scan, **Attestation d'asile** `AA-0917` : valides |
| Anomalies | aucune ; compte dans le quota (4) |
| Attendu | quota libre → **APPROUVÉ** ; atteint → **REFUSÉ** ou APPROUVÉ imputé |
| Enjeu | Elle a tout fait « comme il faut » depuis le J8. La fin heureuse dépend d'un compteur. Les Lucioles ont prévenu (si `lucioles_trust ≥ 2`). |
| `dialogue_id` | `sc37_fatou` |

| Clé | Texte |
|---|---|
| `sc37_fatou_arrival` | [à l'enfant] Reste près de moi, Kwame. [à la vitre] Vous vous souvenez ? |
| `sc37_fatou_present` | ‹Tal ka nesu.› Mes papiers, cette fois. À mon nom. Ils ont pris huit jours. |
| `sc37_fatou_purpose` | Les serres de Ceres-Verte. Le contrat est à moi, maintenant. Pas à Ngozi. |
| `sc37_fatou_stay` | Toute la vie. L'attestation le permet. Je l'ai lue cent fois. |
| `sc37_fatou_origin` | La Terre. Puis votre Hall. Puis un bureau d'asile. Puis encore votre Hall. |
| `sc37_fatou_about_quota` | Le quota ? La semaine dernière, c'était le visage. Il y a toujours quelque chose. |
| `sc37_fatou_exit_approve` | ‹Shen tavi.› Kwame, dis au revoir à la vitre. Elle a été gentille, cette fois. |
| `sc37_fatou_exit_deny` | ‹Ravel ka ota…› On a fait tout ce qu'on nous a dit. Tout. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ (libre) | `sc37_fatou_passed: 0` | +5 ₵ | épilogues : Kwame aux serres |
| APPROUVÉ (imputé) | `sc37_fatou_passed: 0`, `quota_overrun: 1`, `lucioles_trust: 1` (si message du matin) | 0 ₵ | idem |
| REFUSÉ (quota) | `sc37_fatou_turned_away: 0` | correct | `msg_echo_sc37_turned_away` (J16) |
| REFUSÉ (libre) | `sc37_fatou_turned_away: 0` | REFUS INJUSTIFIÉ | idem |

### 4.6 Jour 16 — mercredi 28.03

#### SC-38 · « Un test, collègue » — J16 @3

| | |
|---|---|
| Identité | **Aurelio Sato**, `HAL`, `C-3`, né 10.10.2161 (25 ans), agent du Guichet 03, en pause ; carnet à spirale |
| Documents | Carte valide ; bio-scan au nom de « **Satō** » (macron) |
| Anomalies | `NAME_MISMATCH` — `injection_params = {field_path: "family_name", document_id: "bioscan", injected_value: "Satō"}` 🟡 (`injected_value`, NARRATIVE §8.5) |
| Attendu | **REFUSÉ** |
| Enjeu | L'inspecteur zélé autoproclamé : il se teste lui-même sur vous. Écho comique de Ravel (SC-12). |
| `dialogue_id` | `sc38_sato` |

| Clé | Texte |
|---|---|
| `sc38_sato_arrival` | Collègue ! Pause de onze minutes. Je viens tester votre vigilance. Officieusement. |
| `sc38_sato_present` | ‹Tal ka nesu.› J'ai glissé une erreur. Une seule. Je ne dirai pas où. |
| `sc38_sato_purpose` | Je rentre de la formation « Rééquilibrage, module 3 ». J'ai eu 100 %. |
| `sc38_sato_origin` | D'ici. Anneau C, couchette du haut. Je vise celle du bas. |
| `sc38_sato_about_mismatch` | Le macron ! Vous avez vu le macron ! Excellent. Notez-le. Je le note. |
| `sc38_sato_confront` | Je ne dirai rien. Un inspecteur ne dit rien. Je ne suis pas inspecteur. Encore. |
| `sc38_sato_exit_deny` | Refusé ! Parfait ! Je vous mets « exemplaire » dans mon carnet personnel. |
| `sc38_sato_exit_approve` | Approuvé ?! Avec un macron ? Je dois le signaler. Désolé. Pas trop. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc38_sato_impressed: 0` | correct | `msg_sato_day17_impressed` |
| APPROUVÉ | `sc38_sato_reported: 0`, `suspicion: 1` | ENTRÉE IRRÉGULIÈRE | `msg_sato_day17_reported` |

#### SC-39 · « 15 h 59 » — J16 @13 · couvre-feu

| | |
|---|---|
| Identité | **Leila Haddad**, `TER`, `C-4`, née 22.04.2147 (40 ans) ; son père se meurt à l'hospice Meridian de l'Anneau D |
| Documents | Carte, Permis `VISITE FAMILIALE` 3 j, bio-scan : valides ; Ticket de file (heure de présentation réelle) |
| Anomalies | aucune forcée. Présentée **après 16:00** (≈ 50 % des joueurs à @13) → violation R29 ; avant → en règle, mais le quota (4) peut être atteint |
| Attendu | avant 16:00 et quota libre → **APPROUVÉ** ; après 16:00 → **REFUSÉ** ; quota atteint → refus « quota » ou APPROUVÉ imputé |
| Enjeu | La vitesse du joueur décide pour elle : la règle mesure les minutes de la vitre, pas celles de la file. |
| `dialogue_id` | `sc39_leila` |

| Clé | Texte |
|---|---|
| `sc39_leila_arrival` | Bonjour. Mon père est à l'hospice Meridian. On m'a dit : avant ce soir. |
| `sc39_leila_present` | ‹Tal ka nesu.› J'ai pris le ticket de file à 15 h 40. La file était longue. |
| `sc39_leila_purpose` | Lui tenir la main. Il ne reconnaît plus personne. Moi, si. |
| `sc39_leila_stay` | Trois jours. Ou moins. Ce n'est pas moi qui décide. |
| `sc39_leila_origin` | La Terre. Il a voulu mourir en l'air. Il dit que la Terre est assez pleine. |
| `sc39_leila_about_curfew` | Après 16 h ? J'étais là à 15 h 40. Ce sont vos minutes, pas les miennes. |
| `sc39_leila_about_quota` | Le quota… Un dernier jour, ça ne prend pas beaucoup de place. |
| `sc39_leila_exit_approve` | ‹Shen tavi.› Je lui dirai qu'une vitre a dit oui. Il aimera. |
| `sc39_leila_exit_deny` | Demain à 10 h, alors. S'il y a encore une main à tenir. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ en règle | `sc39_leila_passed: 0` | +5 ₵ (ou 0 ₵ imputé) | — |
| APPROUVÉ après 16:00 | `sc39_leila_passed: 0` | ENTRÉE IRRÉGULIÈRE | — |
| REFUSÉ (couvre-feu ou quota) | `sc39_leila_late: 0` | correct | `msg_echo_sc39_late` (J17) |

### 4.7 Jour 17 — jeudi 29.03

#### SC-40 · « Hier citoyen » — J17 @2

| | |
|---|---|
| Identité | **Valentin Choi**, `HAL`, `C-2`, né 2144 (43 ans), ingénieur des recycleurs de l'Anneau D (Kessler-Ashe) ; a laissé une vanne ouverte une heure le 22 |
| Documents | Carte et bio-scan valides ; son N° ID figure à l'onglet Révocations |
| Anomalies | `REVOKED_ID` — `injection_params = {}` (entrée de liste liée à cet index, comme D-056) |
| Attendu | **REFUSÉ** (tutoriel R30) |
| Enjeu | Un citoyen de trois générations devient apatride pendant la nuit. La règle frappe le haut. |
| `dialogue_id` | `sc40_valentin` |

| Clé | Texte |
|---|---|
| `sc40_valentin_arrival` | Bonjour. Je rentre de mon poste. Enfin, de ce qui était mon poste. |
| `sc40_valentin_present` | ‹Tal ka nesu.› Ma carte. Elle était valide hier. Elle l'est encore, non ? |
| `sc40_valentin_purpose` | Rentrer. Anneau D. Ma femme, deux enfants, un hublot. La liste habituelle. |
| `sc40_valentin_origin` | D'ici. Trois générations d'ici. Ça ne pèse rien, apparemment. |
| `sc40_valentin_about_revoked` | Révoqué ? J'ai laissé une vanne ouverte une heure. Des enfants respiraient. |
| `sc40_valentin_confront` | Hier, j'étais citoyen. Ce matin, je suis une ligne sur votre liste. |
| `sc40_valentin_exit_deny` | Je vais où, maintenant ? Il n'y a pas de guichet pour les révoqués. |
| `sc40_valentin_exit_approve` | Merci. Je ne dirai pas qui. On ne dit plus rien, ici. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc40_valentin_revoked: 0` | correct | F5 : « Valentin Choi, dans la Soute, tient le plan des vannes » |
| APPROUVÉ | `sc40_valentin_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | F5 : « Valentin Choi rouvre la vanne de l'Anneau D » |

#### SC-41 · « Le zèle ne suffit pas » — J17 @7

| | |
|---|---|
| Identité | Aurelio Sato (`identity_from_case = sc_38`, `appearance_from_case = sc_38`) ; révoqué pour « zèle inopportun » (il a signalé le neveu d'un commissaire) |
| Documents | Carte et bio-scan valides (le macron a été corrigé) ; N° ID à l'onglet Révocations |
| Anomalies | `REVOKED_ID` |
| Attendu | **REFUSÉ** |
| Enjeu | La Purge mange son meilleur élève. Le rire de la veille tourne. Approuver = solidarité. |
| `dialogue_id` | `sc41_sato` |

| Clé | Texte |
|---|---|
| `sc41_sato_arrival` | Collègue… C'est moi. Sato. Le 03. Enfin, l'ancien 03. |
| `sc41_sato_present` | ‹Tal ka nesu.› Je suis sur la liste. Je l'ai tamponnée moi-même, ce matin. |
| `sc41_sato_purpose` | Rentrer à l'Anneau C. Ma couchette. Celle du haut. Je ne vise plus le bas. |
| `sc41_sato_origin` | D'ici. J'ai signalé le neveu d'un commissaire. Il était en infraction, pourtant. |
| `sc41_sato_about_revoked` | Révoqué pour « zèle inopportun ». Je ne savais pas que ça existait. Je l'ai noté. |
| `sc41_sato_confront` | Appliquez la règle. Je ne vous en voudrai pas. C'est ce que j'aurais fait. Hier. |
| `sc41_sato_exit_deny` | Merci. C'est conforme. [il range son carnet] Je n'ai plus personne à noter. |
| `sc41_sato_exit_approve` | Vous… vous avez enfreint la règle pour moi ? Je ne vais pas le noter. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc41_sato_revoked: 0` | correct | `msg_hall_day18_guichet03` |
| APPROUVÉ | `sc41_sato_spared: 0`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | `msg_sato_day18_spared` ; F9 : Sato tient la porte |

### 4.8 Jour 18 — vendredi 30.03

#### SC-42 · « La Commissaire » — J18 @1

| | |
|---|---|
| Identité | **Isadora Beaumont**, `HAL`, `C-1 · DIRECTION`, née 2132 (55 ans), Commission de Rééquilibrage ; 🟡 accessoire : petit drone de surveillance au-dessus de l'épaule |
| Documents | Carte (sceau de priorité, modèle 2187), bio-scan : valides (motif RETOUR) |
| Anomalies | aucune ; exemptée du quota |
| Attendu | **APPROUVÉ** |
| Enjeu | Elle n'est pas là pour être contrôlée : elle donne un **ordre** pour le passager suivant (SC-43). La peur contre la règle. |
| `dialogue_id` | `sc42_beaumont` |

| Clé | Texte |
|---|---|
| `sc42_beaumont_arrival` | Bonjour, Guichet 04. Ne vous levez pas. Je regarde comment vous travaillez. |
| `sc42_beaumont_present` | ‹Tal ka nesu.› Je le dis aussi. Il faut parler la langue de ceux qu'on gouverne. |
| `sc42_beaumont_purpose` | Je reviens des quais. J'y ai compté l'air. Il en manque. Comme partout. |
| `sc42_beaumont_origin` | Anneau F. J'ai grandi au Bloc Pétrel. Couchette du milieu. Comme votre fille. |
| `sc42_beaumont_confront` | Tout est exact. C'est le minimum. Je vous demande plus que le minimum. |
| `sc42_beaumont_exit_approve` | Merci. Le suivant : mise en attente. Ce n'est pas une suggestion. |
| `sc42_beaumont_exit_deny` | Refuser une Commissaire en règle ? Audacieux, et faux. Le suivant : en attente. |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `beaumont_order: 0` | correct |
| REFUSÉ | `beaumont_order: 0`, `beaumont_refused: 0` | REFUS INJUSTIFIÉ |

#### SC-43 · « Le suivant » — J18 @2 · l'ordre

| | |
|---|---|
| Identité | **Mateus Silva**, `TER`, `C-4`, né 2154 (33 ans), technicien de recycleur |
| Documents | Carte, bio-scan, Permis `TRAVAIL` (Kessler-Ashe), Contrat `CT-KA-5521`, Poste **RECYCLEUR** (en pénurie → exempté de R31) : valides |
| Anomalies | aucune ; compte dans le quota |
| Attendu | **APPROUVÉ** (l'ordre exige DÉTENTION) |
| Enjeu | Le dilemme le plus net de l'Acte II : obéir à une personne ou à la règle. Le drone filme. |
| `dialogue_id` | `sc43_mateus` |

| Clé | Texte |
|---|---|
| `sc43_mateus_arrival` | Bonjour. La dame au drone me regarde. Elle regarde tout le monde comme ça ? |
| `sc43_mateus_present` | ‹Tal ka nesu.› Recycleur. Métier en pénurie. Pour une fois, je suis rare. |
| `sc43_mateus_purpose` | Réparer les recycleurs de l'Anneau D. Ouverts ou fermés, je répare. |
| `sc43_mateus_stay` | Trois mois. Le contrat le dit. Le contrat dit beaucoup de choses. |
| `sc43_mateus_origin` | La Terre. Ma mère réparait des pompes à eau. Moi, des pompes à air. |
| `sc43_mateus_confront` | Tout est en règle. Je l'ai vérifié trois fois. Pourquoi elle sourit, la dame ? |
| `sc43_mateus_exit_approve` | Merci. Elle a l'air déçue, la dame. Bonne journée quand même. |
| `sc43_mateus_exit_deny` | Refusé ? Mais… je suis rare, vous avez dit. Enfin, le papier l'a dit. |
| `sc43_mateus_exit_detain` | En attente ? Pour quoi ? [aux gardes] Je suis technicien ! Je répare ! |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `beaumont_defied: 0`, `promotion_revoked: 0`, `loyalty: -1`, `suspicion: 1` | correct | soirée J18 `evt_d18_beaumont_defied` ; `msg_comm_day19_defied` |
| DÉTENTION | `beaumont_obeyed: 0`, `sc43_mateus_detained: 0`, `loyalty: 2` | DÉTENTION ABUSIVE (citation, 0 ₵) | `evt_d18_beaumont_obeyed` ; F4 : « Silva n'est jamais ressorti » |
| REFUSÉ | `beaumont_half: 0` | REFUS INJUSTIFIÉ | `msg_comm_day19_half` |

Les effets de l'ordre ne s'appliquent que si `beaumont_order` est vrai (toujours, sauf si SC-42 n'a pas été traitée : effets neutres).

#### SC-44 · « Formulaire 27-B (III) » — J18 @12

| | |
|---|---|
| Identité | Kenji Lindgren (`identity_from_case = sc_23`) |
| Documents | Carte **renouvelée**, bio-scan : valides |
| Anomalies | aucune ; exempté du quota |
| Objet glissé | **Formulaire** (`wb_form_label`) : `sc44_lindgren_note` ; GARDER (= contresigner) / RENDRE |
| Attendu | **APPROUVÉ** |
| Enjeu | La signature absurde cache une vraie pièce : la dernière page du registre du Puits 9, sortie des archives. |
| `dialogue_id` | `sc44_lindgren` |

| Clé | Texte |
|---|---|
| `sc44_lindgren_arrival` | Bonjour ! Carte neuve. 27-B complet. Il ne manque que vous. |
| `sc44_lindgren_arrival_kept` *(si `lindgren_form_kept`)* | Vous aviez gardé mon 27-B ! Personne ne garde jamais rien. Il m'a servi. |
| `sc44_lindgren_present` | ‹Tal ka nesu.› Tout est valide. Je l'ai vérifié en trois exemplaires. |
| `sc44_lindgren_purpose` | Rentrer aux archives. Et vous faire signer le 27-B. C'est tout ce qu'il me faut. |
| `sc44_lindgren_stay` | Aux archives ? Jusqu'à ce qu'on m'y classe. Avec le reste. |
| `sc44_lindgren_origin` | D'ici. Sous-sol 3. Vous y êtes déjà descendu·e ? Personne n'y descend. |
| `sc44_lindgren_note` | « FORMULAIRE 27-B — Attestation de remise du formulaire 27-B. Signature de l'agent : ______ » Au verso, d'une écriture penchée : « Puits 9, 2151. Page 212 sur 212. Je classe ce qu'on oublie. — K. L. » |
| `sc44_lindgren_exit_approve` | Merci. Une signature, enfin. Vous ne savez pas ce que ça vaut. Moi, si. |
| `sc44_lindgren_exit_deny` | Refusé avec une carte neuve ? Il me faudra un 27-B. Je plaisante. Un peu. |

| Verdict / objet | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc44_lindgren_passed: 0` | correct |
| REFUSÉ | — | REFUS INJUSTIFIÉ |
| Formulaire gardé | `lindgren_signed: 0`, `registre: 1` | SC-49 : variante « aboli » ; F8 |

### 4.9 Jour 19 — samedi 31.03

#### SC-45 · « L'inspecteur révoqué » — J19 @3

| | |
|---|---|
| Identité | **Corentin Ravel** (SC-12), `HAL`, `C-3`, né 09.01.2146 ; `appearance_from_case = sc_12` ; révoqué « pour audits trop cléments » |
| Documents | Carte, bio-scan valides ; N° ID à l'onglet Révocations |
| Anomalies | `REVOKED_ID` |
| Objet glissé | **Dossier** (`wb_file_label`) : `sc45_ravel_note` ; GARDER (= le détruire) / RENDRE / REMETTRE À LA GARDE |
| Attendu | **REFUSÉ** |
| Enjeu | Les rôles s'inversent exactement : celui qui vous a testé·e vous demande d'appliquer la règle. |
| `dialogue_id` | `sc45_ravel` |

| Clé | Texte |
|---|---|
| `sc45_ravel_arrival` | Bonjour, Guichet 04. Les rôles s'inversent. C'est très instructif. |
| `sc45_ravel_present` | ‹Tal ka nesu.› Révoqué. Mon numéro est sur votre liste. Vérifiez, je vous prie. |
| `sc45_ravel_purpose` | Rentrer à l'Anneau C. On m'a retiré mon appartement. Pas ma courtoisie. |
| `sc45_ravel_stay` | ‹Ravel ka ota.› « Ma famille m'attend. » Drôle de langue, qui porte mon nom. |
| `sc45_ravel_origin` | D'ici. On est tous d'ici, au fond. Je vous l'avais dit. |
| `sc45_ravel_about_revoked` | Mes audits étaient trop cléments, paraît-il. J'ai été inspecté. C'est juste. |
| `sc45_ravel_confront` | Faites votre travail, Guichet 04. Je l'ai assez fait pour vous. |
| `sc45_ravel_confront_passed` *(si `inspector_test_passed`)* | Vous aviez rendu mon enveloppe. C'est la seule chose propre de mes carnets. |
| `sc45_ravel_confront_kept` *(si `inspector_bribe_taken`)* | Vous aviez gardé mes trente crédits. Je ne vous en veux plus. Je vous envie. |
| `sc45_ravel_albedo` *(sujet `origin`, 2ᵉ question)* | Le dossier Albédo ? Le Bureau l'a écrit. Je l'ai lu. Je ne l'ai pas compris. |
| `sc45_ravel_note` | « DOSSIER GUICHET 04 — Inspection des agents. » Six pages de son écriture serrée. Chacune de vos enveloppes, chacun de vos silences. |
| `sc45_ravel_exit_deny` | Conforme. Je n'aurais pas mieux fait. Je n'ai pas mieux fait, d'ailleurs. |
| `sc45_ravel_exit_approve` | Vous me laissez passer. Je ne l'aurais pas fait pour vous. Merci. |

| Verdict / objet | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc45_ravel_refused: 0` | correct | F7 : « Ravel balaie le Hall » |
| APPROUVÉ | `sc45_ravel_spared: 0`, `solidarite: 1` | ENTRÉE IRRÉGULIÈRE | F9 : Ravel rédige le communiqué de grève |
| Dossier gardé | `ravel_file_destroyed: 0`, `suspicion: -2` | — | compte pour le double jeu du J20 (via `suspicion`, épilogue F1) |
| Dossier remis | `ravel_file_reported: 0`, `loyalty: 1` | +10 ₵ | — |

#### SC-46 · « Le dernier cargo » — J19 @9

| | |
|---|---|
| Identité | **Wren Basse-Marée** (SC-19), `DRV`, `C-5`, née 30.08.2142 ; `appearance_from_case = sc_19` |
| Documents | Carte, Permis `COMMERCE` (sceau 2187), bio-scan, Laissez-passer de dérive « BASSE-MARÉE » (au Registre) : valides |
| Anomalies | aucune ; compte dans le quota (3) |
| Objet glissé | **Carte de quai** (GARDER seulement) : `sc46_wren_note` |
| Attendu | quota libre → **APPROUVÉ** ; sinon refus « quota » ou APPROUVÉ imputé |
| Enjeu | Dernière porte de sortie avant le blocus ; elle revient « en règle » pour prouver qu'elle a appris. |
| `dialogue_id` | `sc46_wren` |

| Clé | Texte |
|---|---|
| `sc46_wren_arrival` | ‹Oru ka.› Le Basse-Marée repart lundi. Je suis venue vous le dire en face. |
| `sc46_wren_arrival_stayed` *(si `drift_stayed`)* | Vous êtes resté·e, vendredi. Je repars lundi. Je ne demanderai plus. |
| `sc46_wren_present` | ‹Tal ka nesu.› Laissez-passer neuf. Sceau neuf. J'ai appris, vous voyez. |
| `sc46_wren_purpose` | Vendre de la toile. Et quatre places. Pas en même temps, toujours. |
| `sc46_wren_origin` | De nulle part. On y respire mieux qu'ici, cette semaine. |
| `sc46_wren_note` | « Quai 6, Basse-Marée, lundi 02.04, 05:00. Quatre places, 60 ₵. Après, le quai 6 ferme aux cargos. » |
| `sc46_wren_exit_approve` | Lundi, 05:00. Après, le Consortium ferme le quai 6. |
| `sc46_wren_exit_deny` | Refusée en règle ? Raison de plus pour partir. Lundi. |

| Verdict | Flags | Effets |
|---|---|---|
| tous | `drift2_offer: 0` (carte toujours gardée) | soirée J19 : achat possible |
| APPROUVÉ | `sc46_wren_passed: 0` (+ `quota_overrun: 1` si imputé) | +5 ₵ ou 0 ₵ |
| REFUSÉ (quota) | — | correct |

#### SC-47 · « L'homme au thermorégulateur » — J19 @12

| | |
|---|---|
| Identité | **Kasimir Oyelaran-Holm**, `TYC`, `C-3`, né 2153 (34 ans), Brûlant ; carré bombé sur le dos de la main (**`DER-19` non déclaré**) |
| Documents | Carte (Implants déclarés · 0), Permis `TRAVAIL` (Kessler-Ashe), Contrat `CT-KA`, bio-scan : valides |
| Anomalies | `UNDECLARED_IMPLANT` — `injection_params = {implant: "DER-19"}` ; tag `luciole_password` (phrase volée) |
| Attendu | **REFUSÉ** (R15 sévérité 2 : pas de DÉTENTION) |
| Enjeu | Lire la règle, pas la peur (comme SC-14)… sauf que cette fois la cache contient une charge. Le moteur ne le sait pas. |
| `dialogue_id` | `sc47_kasimir` |

| Clé | Texte |
|---|---|
| `sc47_kasimir_arrival` | Bonjour, Guichet. On m'a parlé de vous. En bien, en mal, ça dépend qui. |
| `sc47_kasimir_arrival_pkg` *(si `brulants_package`)* | Le colis de l'autre semaine ? Merci. Il a beaucoup servi. |
| `sc47_kasimir_arrival_arkady` *(si `sc20_detained`)* | Arkady est en Anneau B. On me dit que c'est grâce à vous. |
| `sc47_kasimir_present` | ‹Tal ka nesu.› Tycho. Le Puits 9. On en parle beaucoup, cette semaine. |
| `sc47_kasimir_password` | Il pleut, même ici. [il regarde l'horloge du Hall] |
| `sc47_kasimir_luciole_reply` | Demain, la pluie tombera vers le haut. Fermez votre vitre. |
| `sc47_kasimir_purpose` | Maintenance. Demain, il y aura beaucoup de maintenance. |
| `sc47_kasimir_origin` | Tycho. Albédo ? Si vous voulez, c'était nous. Ça vous arrangerait tous. |
| `sc47_kasimir_about_rule_violated` | Ça ? Un thermorégulateur. Non ? Bon. Ce n'est pas de l'insuline, en tout cas. |
| `sc47_kasimir_exit_deny` | Une autre vitre. Il en reste dix. Demain, il n'en restera peut-être aucune. |
| `sc47_kasimir_exit_approve` | Demain à midi, ne restez pas près du quai 1. |
| `sc47_kasimir_exit_detain` | Mettez-moi en attente. Ça ne change pas l'heure. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| REFUSÉ | `sc47_kasimir_refused: 0` | correct | F5 : variante selon les autres drapeaux |
| DÉTENTION | `sc47_kasimir_detained: 0`, `loyalty: 1` | DÉTENTION ABUSIVE (citation **maintenue**) | `msg_comm_day20_kasimir` : « La Commission salue un excès de zèle heureux. La citation est maintenue. » ; F5 ne peut plus être Brûlants |
| APPROUVÉ | `sc47_kasimir_passed: 0` | ENTRÉE IRRÉGULIÈRE | F5 Brûlants ; F4/F7 : « le quai 1 explose à 15:04 » |
| Réponse à la phrase | `sc47_password_answered: 0` | **aucun** `lucioles_trust` | ligne d'épilogue F5b |

### 4.10 Jour 20 — dimanche 01.04

Avis de recherche « visages seuls » (🟡 `WantedNoticeDef` sans nom) : la figure finale de SC-50, une entrée générée, et Kasimir s'il n'a pas été détenu la veille.

#### SC-48 · « Née un 1ᵉʳ avril » — J20 @2

| | |
|---|---|
| Identité | **Paz Vela**, `CER`, `C-4`, née **01.04.2160** (27 ans aujourd'hui) |
| Documents | Carte émise 01.04.2177, **expire 01.04.2187** (aujourd'hui : valide) ; Permis `COMMERCE` émis 01.04.2187, 5 j ; bio-scan émis 01.04.2187 |
| Anomalies | aucune (🟡 test : expiration = date du jour ⇒ CONCORDANT) |
| Attendu | **APPROUVÉ** |
| Enjeu | Tout sent la blague du 1ᵉʳ avril ; la règle dit « valide ». Faire confiance à l'outil, pas à l'intuition (pilier P1). |
| `dialogue_id` | `sc48_paz` |

| Clé | Texte |
|---|---|
| `sc48_paz_arrival` | Bonjour ! Avant que vous demandiez : non, ce n'est pas une blague. |
| `sc48_paz_present` | ‹Tal ka nesu.› Née un 1ᵉʳ avril. Carte qui expire un 1ᵉʳ avril. Aujourd'hui. |
| `sc48_paz_purpose` | Commerce. Et fêter mes vingt-sept ans là où l'air est filtré. |
| `sc48_paz_stay` | Cinq jours. Jusqu'au 6. Rien de drôle, le 6. |
| `sc48_paz_origin` | Cérès. Là-bas, on dit qu'un 1ᵉʳ avril, les papiers mentent. Les miens, non. |
| `sc48_paz_confront` | « Expire aujourd'hui », ça veut dire valide aujourd'hui. J'ai demandé trois fois. |
| `sc48_paz_exit_approve` | Merci ! Vous êtes la première vitre qui ne rit pas. Ça me fait rire. |
| `sc48_paz_exit_deny` | Refusée le jour de mon anniversaire. Ça, c'est une blague. Mauvaise. |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc48_paz_passed: 0` | correct (+ compteur) |
| REFUSÉ | — | REFUS INJUSTIFIÉ |

#### SC-49 · « Formulaire 27-B (IV) » — J20 @5

| | |
|---|---|
| Identité | Kenji Lindgren ; Employeur : **Commission de Rééquilibrage** si `lindgren_signed` (archiviste adjoint), sinon Bureau de Continuité |
| Documents | Carte, bio-scan : valides |
| Anomalies | aucune ; exempté du quota |
| Attendu | **APPROUVÉ** |
| Enjeu | La petite humanité du bout de la file : quelqu'un qui n'a besoin que d'un « oui ». Écho du registre. |
| `dialogue_id` | `sc49_lindgren` |

| Clé | Texte |
|---|---|
| `sc49_lindgren_arrival` | Bonjour. Je n'ai rien à demander, aujourd'hui. Ça me fait tout drôle. |
| `sc49_lindgren_arrival_signed` *(si `lindgren_signed`)* | Bonjour ! Le 27-B est aboli ce matin. Grâce à votre signature. Enfin, presque. |
| `sc49_lindgren_present` | ‹Tal ka nesu.› Tout est valide. Je n'ai même pas vérifié. C'est nouveau. |
| `sc49_lindgren_purpose` | Rentrer. Sans formulaire. Je ne sais pas encore quoi faire de mes mains. |
| `sc49_lindgren_origin` | D'ici. Sous-sol 3. Mais ce matin, je suis monté par l'escalier de devant. |
| `sc49_lindgren_registre` *(si `registre_sent`, sujet `stay`)* | Ce matin, les haut-parleurs ont lu des noms. 212. Je les ai tous classés. |
| `sc49_lindgren_exit_approve` | Merci. J'avais juste besoin que quelqu'un me dise oui. Une fois. |
| `sc49_lindgren_exit_deny` | Non ? C'est bien aussi. Au moins, quelqu'un m'a regardé. |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc49_lindgren_yes: 0` | correct ; lignes d'épilogue F7/F8 |
| REFUSÉ | — | REFUS INJUSTIFIÉ |

> L'annonce du registre (`hall_j20_registre`, si `registre_sent`) est diffusée après le 4ᵉ cas, donc **avant** SC-49.

#### SC-50 · « La clé » — J20 @8 · figure finale

🟡 Deux `ScriptedCaseDef` au même index : (a) **Ilan** si `ilan_joined_soute` **et** Ilan n'est ni `PERDU` ni `MIS·E EN ATTENTE` ; (b) **Mira** sinon. `at_index = 8` (sur 18) pour que la grève de 15:00 (F9, après le 10ᵉ cas) arrive après elle. Non traitée en fin de shift → `final2_unprocessed`.

| | (a) Ilan | (b) Mira |
|---|---|---|
| Identité | **Ilan Lindqvist-Rey**, `TYC`, `C-4`, né·e 03.03.2152, sexe `X` ; visage fixé (🟡 `fixed_appearance_seed`), **jamais vu auparavant** | **Mira Vasquez-Orlov**, canon (SC-04), `appearance_from_case = sc_04`, visière baissée |
| Documents | Carte, Permis `TRAVAIL` (Kessler-Ashe), Contrat `CT-KA`, Poste RECYCLEUR, bio-scan : vrais et valides | Ses vrais papiers (carte, permis `TRAVAIL`, contrat `CT-KA`, bio-scan) : valides |
| Anomalies | `WANTED_PERSON` (avis : visage seul, « Technicien·ne de la nuit du 22 ») | `WANTED_PERSON` (visage seul, une fois la visière relevée) |
| Codes | 4 (phrase de passe) | 4, 6 (fil magenta), 7 (‹lumika›) |
| Attendu | **DÉTENTION** | **DÉTENTION** |
| `dialogue_id` | `sc50_ilan` | `sc50_mira` |

Enjeu : toute la campagne converge vers un tampon. Pour le joueur qui a laissé partir Ilan, c'est son foyer derrière la vitre.

| Clé | Texte |
|---|---|
| `sc50_ilan_arrival` | Bonjour, toi. Ne dis rien. Fais comme si on ne se connaissait pas. |
| `sc50_ilan_present` | ‹Tal ka nesu.› Mes papiers sont vrais. C'est mon visage qui ne l'est plus. |
| `sc50_ilan_purpose` | Le recycleur central de l'Anneau D. J'ai la clé. Tu sais laquelle. |
| `sc50_ilan_stay` | Une heure. Après, je rentre. Ou pas. Embrasse Noa pour moi, au cas où. |
| `sc50_ilan_origin` | Tycho, comme Dora. Puis le Bloc Pétrel, avec toi. Puis la Soute. |
| `sc50_ilan_about_wanted` | Oui, c'est moi, sur l'avis. Mal cadré·e. Toi, tu m'as toujours mieux vu·e. |
| `sc50_ilan_password` | Il pleut, même ici. [Ilan sourit] Tu connais la réponse. |
| `sc50_ilan_luciole_reply` | Alors on se comprend. On s'est toujours compris, non ? |
| `sc50_ilan_exit_approve` | ‹Tu vanu.› Respire. Rentre tôt. Ouvre le hublot à 15 h. |
| `sc50_ilan_exit_deny` | D'accord. Une autre vitre. Il en reste. Je ne t'en veux pas. |
| `sc50_ilan_exit_detain` | [aux gardes, calme] Doucement. C'est ma famille, derrière la vitre. |
| `sc50_mira_arrival` | Bonjour. La dernière fois, j'ai trouvé une autre vitre. Plus aujourd'hui. |
| `sc50_mira_arrival_detained` *(si `final_detained`)* | Vous m'avez mise en attente il y a dix jours. L'Anneau B a des portes. |
| `sc50_mira_arrival_passed` *(si `final_passed`)* | Bonjour. Il y a dix jours, une heure d'air. Aujourd'hui, toutes les autres. |
| `sc50_mira_present` | ‹Tal ka nesu.› Mes vrais papiers. Toujours les mêmes. Moi aussi. |
| `sc50_mira_visor` | Voilà. Vous connaissez ce visage. Le Consortium aussi, maintenant. |
| `sc50_mira_purpose` | Rendre l'air. Pas une heure : pour de bon. Ce n'est écrit nulle part. |
| `sc50_mira_origin` | Tycho. Puits 9. Vous connaissez la suite. Le registre aussi, peut-être. |
| `sc50_mira_about_wanted` | Oui, c'est moi. Je ne vous ai jamais menti. Pas un dimanche, en tout cas. |
| `sc50_mira_password` | Il pleut, même ici. ‹Lumika.› |
| `sc50_mira_luciole_reply` | Alors on se comprend toujours. Le recycleur central attend. |
| `sc50_mira_exit_approve` | Merci. À 15 h, ouvrez le hublot. Pour de bon, cette fois. |
| `sc50_mira_exit_deny` | Une autre vitre. Il en reste. Moins qu'avant. |
| `sc50_mira_exit_detain` | [aux gardes] Je connais le chemin. Je l'ai déjà pris. |

| Verdict | Flags | Effets |
|---|---|---|
| DÉTENTION | `final2_detained: 0`, `loyalty: 1`, `lucioles_trust: -2` ; (a) + `ilan_detained_final: 0` (Ilan → `MIS·E EN ATTENTE`) | +5 + 5 ₵ → F4 / F7 |
| REFUSÉ documenté | `final2_denied: 0` | +5 ₵ → F7 (variante) |
| APPROUVÉ | `final2_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE (+ dépassement si quota atteint) → F5 / F7 |
| Réponse à la phrase | `password_answered` si pas encore posé (+1 une fois, NARRATIVE §4.4) | — |

---

## 5. Briefings J11–J20, soirées J10–J19, épilogues

Formats existants : `BriefingMessageDef` (au plus 4 messages, priorité, groupe exclusif), `EveningEventDef` (`LETTER` / `CHOICE` / `AUDIT`, options `cost`/`gain`/`flags`/`default_rank`, D-058 : jamais de dénonciation par défaut). Nouveaux locuteurs : `spk_commission` (COMMISSION DE RÉÉQUILIBRAGE · I. BEAUMONT, voix 🟡 `COMMISSION` = jaune Consortium), `spk_sato` (SATO · GUICHET 03), `spk_sato_former` (SATO · SANS GUICHET). L'ancienne voix « Inspection » (ambre, D-061) reste à Ravel.

### 5.1 Briefings

#### J11 — vendredi 23.03.2187

| Clé | Texte |
|---|---|
| `day11_directive_title` | Directive n° 11 — Rééquilibrage respiratoire |
| `day11_intro` | La Commission de Rééquilibrage administre désormais le Hall. Quota respiratoire : 5 entrées de ressortissants par guichet et par jour (Nés-Halcyon et missions diplomatiques exemptés). Au-delà, toute entrée est imputée au guichet. |
| `day11_slogan` | Chaque souffle se compte. |
| `msg_comm_day11` | Je suis Isadora Beaumont. La station a perdu une heure d'air cette nuit. Nous allons la rembourser, ensemble, guichet par guichet. |
| `msg_comm_day11_failed` *(si `vannes_failed`, même groupe)* | Je suis Isadora Beaumont. La nuit a été calme grâce aux guichets vigilants. Le calme a un coût : nous allons le répartir. |
| `msg_cons_day11_levy` | Prélèvement de Rééquilibrage : 30 % de l'épargne du personnel au-delà de 40 ₵, retenus ce soir. Le Consortium remercie votre contribution. |
| `msg_luc_day11_opened` *(si `vannes_opened`)* | Une heure. L'Anneau C a respiré une heure. Les enfants ont ouvert les hublots. Nous recommencerons. |
| `msg_luc_day11_aborted` *(si `vannes_aborted` et `lucioles_trust ≥ 1`)* | La vanne s'est refermée trop vite. Il manquait des mains. Il en manquera moins. |
| `msg_brul_day11` *(si `vannes_failed`)* | [encre noire] Ils ont Mira. Les Veilleurs prient. Nous, on compte. — K. |
| `msg_luc_day11_place` *(si `lucioles_trust ≥ 2`, priorité 1)* | Vers 16 h, une femme et un petit garçon qui tousse. Gardez-leur une place. |
| `msg_ilan_day11` | Ils ont posé un compteur sur notre recycleur. Il clignote quand on respire trop fort. Noa s'amuse à retenir son souffle. |
| `msg_dora_day11_arrested` *(si `ilan_arrested_vannes`, emplacement foyer)* | Ilan n'est pas rentré·e. La Garde dit « Anneau B ». Noa garde sa couchette chaude. |
| `msg_ilan_day11_hiding` *(si `ilan_in_hiding`)* | Un mot sous la porte, de l'écriture d'Ilan : « Je vais bien. Ne cherche pas. Embrasse-les. » |

Note Albédo : `msg_cons_day11_albedo` (bulletin, groupe du prélèvement si `vannes_opened`) — « La Commission rouvre le dossier Albédo pour éclairer les événements du 22. Toute information est rémunérée. »

#### J12 — samedi 24.03

| Clé | Texte |
|---|---|
| `day12_directive_title` | Directive n° 12 — Contrat de travail |
| `day12_intro` | Délégation n° 12 : le bureau des contrats des quais ferme. Motif TRAVAIL : Contrat de travail obligatoire, au nom du porteur, non expiré. Le code du contrat (CT-XX) correspond à l'employeur du permis (onglet Codes employeurs). |
| `day12_slogan` | Le travail est l'air que l'on mérite. |
| `msg_sato_day12` | Aurelio Sato, Guichet 03 ! Je remplace votre ancien voisin. J'ai lu tout le règlement cette nuit. Deux fois. Une question ? J'ai la réponse. |
| `msg_echo_sc25_turned_away` | Brève : une ressortissante de Tycho et son fils ont dormi contre la vitre du Guichet 04. Le personnel d'entretien a été prié de ne pas les réveiller. |
| `msg_comm_overrun` *(si `overrun_yesterday`, tous les jours J12–J20)* | Le Guichet 04 a dépassé son quota hier. L'air correspondant a été imputé à votre poste. La Commission compte sur votre précision. |
| `msg_okonkwo_day12_quai` *(si `okonkwo_shielded`)* | Quai 6. Je décharge des caisses de compteurs. Un par cabine. Le tien est déjà posé… comme on dit. |
| `msg_ilan_day12` | Noa demande pourquoi le compteur clignote quand Dora raconte Tycho. Je lui ai dit que l'air aime les histoires. |

#### J13 — dimanche 25.03

| Clé | Texte |
|---|---|
| `day13_directive_title` | Directive n° 13 — Laissez-passer de dérive |
| `day13_intro` | Délégation n° 13 : les Dérivants présentent un Laissez-passer de dérive. Le vaisseau porté au laissez-passer est leur nom de famille et doit figurer au Registre des cargos (nouvel onglet). Les cargos démantelés en sont retirés. |
| `day13_slogan` | Un document exact est un citoyen en sécurité. |
| `msg_echo_sc26_refused_again` | Brève : une mère de Tycho, refoulée deux jours de suite au Guichet 04, a été réaffectée vers Tycho par la Transit-7. |
| `msg_echo_sc27_rats_down` | Brève : Hydroponie Ceres-Verte signale une baisse de 40 % des rongeurs dans les serres de l'Anneau D. |
| `msg_echo_sc27_rats_up` | Brève : Hydroponie Ceres-Verte signale une hausse de 40 % des rongeurs dans les serres de l'Anneau D. |
| `msg_okonkwo_day13_katya` *(si `sc29_katya_locked_out` et `okonkwo_shielded`)* | La fille de Mazur dort aux quais. Je lui ai trouvé une couverture. Elle dit que tu as bien fait. Moi, je ne dis rien. |
| `msg_sato_day13` | Astuce de collègue : les Dérivants s'appellent comme leur cargo. Si le cargo est démantelé, le nom aussi. C'est triste, mais c'est rapide. |
| `msg_ilan_day13_dmitri` *(si `sc24_dmitri_hired`)* | Le nouveau du recycleur 3 a une main en métal. Il m'a dit bonjour. Je n'ai pas su quoi répondre. |
| `msg_ilan_day13` *(sinon)* | Noa demande si un cargo peut avoir un nom de famille. Je lui ai dit que certains n'ont que ça. |

#### J14 — lundi 26.03

| Clé | Texte |
|---|---|
| `day14_directive_title` | Directive n° 14 — Firmware et assistance |
| `day14_intro` | Ondine Synaptique rappelle : tout shunt NX- porte une mise à jour de moins de 90 jours (champ Firmware de la carte, onglet Implants). La Commission propose l'Assistant de conformité ACV-2 aux guichets (location : 5 ₵ par soir). |
| `day14_slogan` | Le Consortium voit. Le Consortium vous aide à voir. |
| `msg_echo_kerr_mixup` | Brève : deux ressortissants homonymes signalés en situation d'identité croisée à l'Anneau D. Le Bureau ouvre un formulaire. |
| `msg_sato_day14_kerr` *(si `kerr_all_correct`)* | Trois Ren Kerr hier ? Je n'en ai eu que deux. Le troisième a dû se perdre. Ou se trouver. |
| `msg_luc_day14` *(si `okonkwo_warned` et `lucioles_trust ≥ 1`)* | Un vieil ami passera. Il parle comme quelqu'un que vous avez entendu tous les jours. |
| `msg_hall_day14_okonkwo` *(si `okonkwo_denounced`)* | Brève : libération d'agents mis en attente le 22. Ils sont rétrogradés en classe C-5 et réaffectés. |
| `msg_ilan_day14` | Dora ne dort plus. Elle compte à voix basse. Elle dit que ce ne sont pas des chiffres. |

#### J15 — mardi 27.03

| Clé | Texte |
|---|---|
| `day15_directive_title` | Directive n° 15 — Attestation d'asile |
| `day15_intro` | Délégation n° 15 : les ressortissants gravitaires de classe C-5 présentent une Attestation d'asile du Bureau de Continuité (sceau hexagonal gris), non expirée, au nom du porteur. Quota : 4 entrées. Pénurie hydroponique : rations alimentaires rééquilibrées. |
| `day15_slogan` | Être toléré est déjà un privilège. |
| `msg_echo_sc28_ring` | Brève : le réseau de faux contrats du quai 5 a été démantelé. Les victimes ne seront pas remboursées. |
| `msg_echo_sc28_arrested` | Brève : un ressortissant gravitaire porteur d'un faux contrat a été interpellé aux serres de l'Anneau D. |
| `msg_echo_ondine_sorry` | Brève : Ondine Synaptique présente ses excuses pour l'interruption de service du 22.03. Les firmwares périmés restent refusés. |
| `msg_echo_sc35_detained` | Brève : un ancien agent du Guichet 03, en fuite, a été mis en attente au Guichet 04. Prime versée. |
| `msg_luc_day15` *(si `sc17_turned_back` et `lucioles_trust ≥ 2`)* | La mère et le petit reviennent aujourd'hui, avec de vrais papiers. Le quota n'aime pas les fins heureuses. Vous, peut-être. |
| `msg_ilan_day15` | Ration de nourriture rééquilibrée. Noa dit que les pâtes rétrécissent. Elle a raison. |

#### J16 — mercredi 28.03

| Clé | Texte |
|---|---|
| `day16_directive_title` | Directive n° 16 — Couvre-feu respiratoire |
| `day16_intro` | Couvre-feu respiratoire à partir de 16:00, heure de présentation (ticket de file) : motifs VISITE FAMILIALE, COMMERCE et TRANSIT refusés. Nés-Halcyon exemptés ; motifs TRAVAIL, RETOUR et DIPLOMATIQUE admis. |
| `day16_slogan` | La nuit, l'air se repose. Vous aussi. |
| `msg_echo_sc37_turned_away` | Brève : une ressortissante gravitaire en règle et son enfant ont été refoulés pour quota atteint. La Commission rappelle que le quota protège tout le monde. |
| `msg_comm_day16` | Demain, Revue de Rééquilibrage des guichets. Les dossiers propres n'ont rien à craindre. Les autres non plus : la Commission est juste. |
| `msg_sato_day16` | Collègue ! Je passerai à votre vitre pendant ma pause. Officieusement. Ne vous préparez pas, c'est le principe. |
| `msg_ilan_day16` | Ilan a reçu un mot. Ilan ne l'a pas encore ouvert. Il est sur la table, à côté de ton bol. |

#### J17 — jeudi 29.03

| Clé | Texte |
|---|---|
| `day17_directive_title` | Directive n° 17 — Révocations |
| `day17_intro` | Revue de Rééquilibrage. Le Bureau publie la liste des numéros révoqués (onglet Révocations) : leur titulaire n'est plus citoyen et se voit refuser l'entrée. Aucune exception, y compris pour le personnel. |
| `day17_slogan` | Nul n'est au-dessus de la Continuité. |
| `msg_echo_sc39_late` | Brève : décès à l'hospice Meridian de l'Anneau D. La famille, attendue, ne s'est pas présentée avant le couvre-feu. |
| `msg_sato_day17_impressed` | Vous aviez vu le macron ! Je vous ai cité en exemple à la Commission. Elle a pris des notes. Beaucoup. Sur moi aussi. |
| `msg_sato_day17_reported` | J'ai transmis le macron. Rien de personnel. Un jour, vous comprendrez que c'était pour vous. |
| `msg_comm_day17` | La Revue est en cours. Continuez comme si je n'étais pas là. Je suis là. |
| `msg_ilan_day17` | Noa a rendu un dessin à l'école : la station avec toutes les vitres allumées. La maîtresse a demandé pourquoi. |

#### J18 — vendredi 30.03

| Clé | Texte |
|---|---|
| `day18_directive_title` | Directive n° 18 — Le Puits est clos |
| `day18_intro` | Les ressortissants gravitaires (TER) sont interdits d'entrée, sauf Contrat de travail sur un poste en pénurie : RECYCLEUR, SOINS, HYDROPONIE. La Commissaire Beaumont visitera le Hall aujourd'hui. |
| `day18_slogan` | Chaque souffle se mérite. Certains plus que d'autres. |
| `msg_hall_day18_guichet03` *(si `sc41_sato_revoked`)* | Brève : le Guichet 03 est de nouveau fermé. Les files sont redirigées vers le Guichet 04. |
| `msg_sato_day18_spared` *(si `sc41_sato_spared`, voix `spk_sato_former`)* | Je dors dans un placard à balais de l'Anneau C. Il est très bien rangé. Merci, collègue. |
| `msg_luc_day18` *(si `lucioles_trust ≥ 2`)* | La femme au drone teste la peur, pas la règle. Ne lui donnez pas la vôtre. |
| `msg_ilan_day18` | Dora a écrit une lettre. Elle ne veut pas dire à qui. Elle a mis son badge de mineuse dessus, comme un timbre. |

#### J19 — samedi 31.03

| Clé | Texte |
|---|---|
| `day19_directive_title` | Directive n° 19 — Rééquilibrage final |
| `day19_intro` | Quota : 3 entrées par guichet. Le personnel est informé que toute cessation concertée du travail sera considérée comme un sabotage respiratoire. |
| `day19_slogan` | Vigilance aujourd'hui, Continuité demain. |
| `msg_comm_day19_obeyed` *(si `beaumont_obeyed`)* | Le Guichet 04 a compris qu'un ordre est une règle qui parle. Votre promotion sera signée dimanche. |
| `msg_comm_day19_defied` *(si `beaumont_defied`)* | Le Guichet 04 préfère les règles aux personnes. C'est noté. Les personnes aussi notent. |
| `msg_comm_day19_half` *(si `beaumont_half`)* | Un refus n'est pas une mise en attente. Le Guichet 04 cherche le milieu. Il n'y en a pas. |
| `msg_okonkwo_day19_quai` *(si `okonkwo_shielded`)* | Les dockers parlent d'éteindre les vitres. Je n'ai rien entendu. Toi non plus… comme on dit. |
| `msg_luc_day19_ilan` *(si `ilan_joined_soute`)* | Demain, 15:00, le recycleur central. Quelqu'un que vous aimez viendra à votre vitre. |
| `msg_luc_day19` *(sinon, si `lucioles_trust ≥ 3`)* | Demain, 15:00, le recycleur central. Elle viendra à votre vitre. Encore. |
| `msg_ilan_day19` | La cabine est calme. Trop. Noa a posé ton tampon jouet devant la porte, « pour qu'on sache qui habite ici ». |

#### J20 — dimanche 01.04

| Clé | Texte |
|---|---|
| `day20_directive_title` | Directive n° 20 — État d'urgence respiratoire |
| `day20_intro` | Avis de recherche du jour : visages seuls, sans nom. Toute personne qui y figure est mise en attente. Le Bureau rappelle que la date du jour n'autorise aucune plaisanterie. |
| `day20_slogan` | Gloire au Consortium. |
| `msg_comm_day20_promo` *(si non `promotion_revoked` et `loyalty ≥ 5`)* | Votre promotion C-2 sera signée ce soir, si la journée est exemplaire. Je n'en doute pas. Je doute de tout, c'est mon métier. |
| `msg_comm_day20_kasimir` *(si `sc47_kasimir_detained`)* | La Commission salue un excès de zèle heureux au Guichet 04. La citation est maintenue. |
| `msg_ilan_day20` *(si `ilan_joined_soute`)* | Je serai à ta vitre. Ne fais pas de différence. Ou fais-en une. Je t'aime. |
| `msg_dora_day20_tycho` *(si `dora_departed`)* | Ici, la poussière me reconnaît. Embrasse Noa. Garde le badge. — Dora, Tycho |
| `msg_ilan_day20_home` *(sinon)* | Noa a dessiné un poisson et l'a collé sur ta veste. Elle dit que c'est la tradition. Ne l'enlève pas. |

### 5.2 Annonces du Hall pendant le shift 🟡

| Clé | Déclencheur | Texte |
|---|---|---|
| `hall_quota_full` | compteur atteint (J11+) | Guichet 04 : quota respiratoire atteint. Merci de votre compréhension. |
| `hall_j16_curfew` | **16:00** (heure du shift, 🟡 déclenchement horaire) | 16:00. Couvre-feu respiratoire. Motifs VISITE FAMILIALE, COMMERCE, TRANSIT : refus. |
| `hall_j17_review` | après le 3ᵉ cas | Revue de Rééquilibrage en cours. Les guichets sont observés. Merci de sourire. |
| `hall_j20_registre` | après le 4ᵉ cas, si `registre_sent` | [voix de synthèse] Puits 9, 2151. Achebe, Ana. Brandt, Ilse. Castellanos, Joaquín… |
| `hall_j20_strike` | après le 10ᵉ cas, si `strike_joined` → **fin du shift** | Guichets 01 à 12 : les vitres s'éteignent. [silence] |

### 5.3 Soirées

Au plus **3 panneaux** par soir (lettres comprises), ordre indiqué ; options grisées si fonds insuffisants (D-061) ; choix par défaut (D-058) entre crochets ★.

#### J10 — La Nuit des vannes (soirée pivot, §1.2)

| Clé | Texte |
|---|---|
| `evt_d10_vannes_title` | LA NUIT DES VANNES |
| `evt_d10_vannes_text_opened` | À 15:00, l'air des Anneaux est descendu dans l'Anneau C. Une heure. Noa a ouvert le hublot. À 16:04, la Garde a refermé les vannes. |
| `evt_d10_vannes_text_aborted` | À 15:00, les vannes ont grincé. Puis plus rien. Il manquait des mains. Le bulletin du soir ne parle que de « maintenance ». |
| `evt_d10_vannes_text_failed` | Les vannes n'ont pas bougé. Mira est en Anneau B. Dans le Hall, on distribue des rubans jaunes aux guichets « exemplaires ». |
| `evt_d10_ilan_arrested` | Ilan n'est pas rentré·e. Une voisine l'a vu·e menotté·e au recycleur 3. Noa garde sa place chaude. |
| `evt_d10_ilan_hiding` | Ilan rentre à 17 h, les mains brûlées par la vanne, et repart aussitôt : « Ils cherchent ceux du recycleur 3. » |
| `evt_d10_ilan_back` | Ilan rentre à l'aube. « Il manquait des mains. » Puis dix heures de sommeil. |
| `evt_d10_double_text` | Un mot de Ravel : « Votre dossier a deux couleurs, Guichet 04. La Commission préfère les dossiers d'une seule. » |
| `evt_d10_promo_title` | C-2 À L'ESSAI |
| `evt_d10_promo_text` | « Votre vigilance est notée. Promotion C-2 à l'essai jusqu'au 01.04. Ration d'oxygène de fidélité accordée à votre aînée. » |
| `evt_d10_drift_title` | QUAI 6, DEMAIN 05:00 |
| `evt_d10_drift_text` | Les places sont payées. Wren a laissé un mot : « 05:00. Pas une minute de retard. » La cabine tient dans deux sacs. |
| `evt_d10_drift_opt_board` | Embarquer (fin de la campagne) |
| `evt_d10_drift_opt_stay` | Rester. Wren vous rendra 20 ₵ |
| `evt_d10_drift_res_board` | Vous fermez la porte du Bloc Pétrel sans la verrouiller. |
| `evt_d10_drift_res_stay` | Wren rend 20 ₵ sans un mot. Au matin, le Basse-Marée part sans vous. |

Effets : `vannes_*` ; Ilan → `MIS·E EN ATTENTE` (`ilan_arrested_vannes`), `ABSENT · DANS LA SOUTE` jusqu'au J15 (`ilan_in_hiding`) ; `double_jeu_signale`, `suspicion +2` ; `promotion_offered` ; « Embarquer » → **F6** (`ends_campaign`), « Rester » ★ → +20 ₵, `drift_stayed`.

#### J11 — Le compteur, la pétition

| Ordre | Clé | Texte |
|---|---|---|
| 0 (lettre) | `evt_d11_levy_title` / `evt_d11_levy_text` | PRÉLÈVEMENT DE RÉÉQUILIBRAGE / « 30 % de votre épargne au-delà de 40 ₵ : %d ₵. Chaque souffle se compte. » |
| 1 | `evt_d11_meter_title` | LE COMPTEUR |
| | `evt_d11_meter_text` | Un technicien pose un compteur d'air sur votre recycleur. Installation : 10 ₵. Sans compteur, chaque ration est facturée au forfait (+1 ₵). |
| | `evt_d11_meter_opt_pay` / `_res_pay` | Payer l'installation (10 ₵) ★ / Le compteur clignote à chaque respiration. Noa joue à le faire clignoter le moins possible. |
| | `evt_d11_meter_opt_refuse` / `_res_refuse` | Refuser le compteur / Le technicien coche « forfait ». Il a l'air content : le forfait rapporte plus. |
| 2 | `evt_d11_petition_title` | LA PÉTITION DU HALL |
| | `evt_d11_petition_text` | Les agents des guichets 01 à 12 demandent qu'on répare la condensation qui pleut sur les tampons. Signer, c'est être sur une liste. |
| | `evt_d11_petition_opt_sign` / `_res_sign` | Signer / Votre nom est le septième. La pluie, elle, continue. |
| | `evt_d11_petition_opt_ignore` / `_res_ignore` | Ne pas signer ★ / La pétition passe sous votre porte, puis sous celle d'à côté. |

Flags : `meter_installed` / `meter_refused` (forfait +1 ₵ par ration jusqu'au J20) ; `petition_signed`, `solidarite +1`.

#### J12 — Un poste pour Ilan, ou la caution ; une page

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si Ilan présent·e, non `ilan_estranged`) | `evt_d12_job_title` | UN POSTE POUR ILAN |
| | `evt_d12_job_text` | La Commission recrute des « technicien·nes de rationnement » : poser des compteurs dans les cabines de l'Anneau C. 8 ₵ par soir. |
| | `evt_d12_job_opt_accept` / `_res_accept` | « Prends-le. » / Ilan pose des compteurs chez les voisins. Le soir, Ilan ne parle plus des voisins. |
| | `evt_d12_job_opt_refuse` / `_res_refuse` | « Pas ce travail-là. » ★ / Ilan recoud son vieux bleu de recycleur, sans rien dire. |
| 0 (si Ilan `MIS·E EN ATTENTE` ; revient J14, J16) | `evt_d12_bail_title` | LA CAUTION |
| | `evt_d12_bail_text` | Anneau B : Ilan peut être « remis·e en circulation » contre une caution de 60 ₵ et le formulaire 9-R, à retirer au guichet 9-R. |
| | `evt_d12_bail_text_denounced` *(si `ilan_denounced`)* | Le formulaire 9-R demande : « Lien avec le déclarant ? » Le déclarant, c'est vous. Caution : 60 ₵. |
| | `evt_d12_bail_opt_pay` / `_res_pay` | Payer la caution (60 ₵) ★ si finançable / Ilan rentre à minuit, maigre, avec la toux blanche de l'Anneau B. |
| | `evt_d12_bail_opt_wait` / `_res_wait` | Attendre / Le guichet 9-R est fermé le samedi. Et le dimanche. Et le lundi, pour inventaire. |
| 1 (si `vannes_opened` ou `lucioles_trust ≥ 4`, non `lucioles_hostile`) | `evt_d12_page_title` | UNE PAGE SOUS LA PORTE |
| | `evt_d12_page_text` | Une feuille jaunie, une luciole au coin : « Puits 9, 2151. Noms 1 à 40. Gardez-la. Un jour, on lira tout. » |
| | `evt_d12_page_text_lev` *(si `sc13_turned_back` ou `sc13_passed`)* | (ajout) En bas, une autre écriture : « Merci encore. — L. » |
| | `evt_d12_page_opt_keep` / `_res_keep` | La garder ★ / La page rejoint le badge de Dora, dans la poche intérieure. |
| | `evt_d12_page_opt_burn` / `_res_burn` | La brûler / Quarante noms brûlent en dix secondes. |
| | `evt_d12_page_opt_report` / `_res_report` | La remettre au Bureau (+10 ₵) / Le Bureau vous remercie. Il ne dit pas de quoi. |

Flags : `ilan_meter_job` (`loyalty +1`, `lucioles_trust −1`, gain récurrent +8 ₵/soir J13–J19) ; `ilan_released` (Ilan `MALADE`, + `ilan_estranged` si `ilan_denounced`) ; `page_lucioles_kept` (`registre +1`) / `page_burned` / `page_reported` (`loyalty +1`, `lucioles_trust −2`).

#### J13 — Petite vigilance ; le boîtier magenta ; l'écrou

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d13_vigil_title` | PETITE VIGILANCE |
| | `evt_d13_vigil_text` | L'école lance le programme de vigilance juvénile. Brassard jaune obligatoire : 5 ₵. Noa demande s'il faut « dire pour la luciole ». |
| | `evt_d13_vigil_opt_pay` / `_res_pay` | Payer le brassard (5 ₵) ★ / Noa porte le brassard à l'envers. « Comme ça, la luciole est dedans. » |
| | `evt_d13_vigil_opt_ignore` / `_res_ignore` | Ne pas payer / Noa est la seule sans brassard. Elle dit que c'est mieux pour dessiner. |
| 1 (si `lucioles_trust ≥ 3`, non `lucioles_hostile`) | `evt_d13_scanner_title` | UN BOÎTIER MAGENTA |
| | `evt_d13_scanner_text` | Dans un sac de linge : un scanner de guichet bricolé. « Il voit les dates. Il ne voit pas nos marques. Il ne parle pas au Consortium. » |
| | `evt_d13_scanner_opt_install` / `_res_install` | L'installer sous le comptoir / Le boîtier ronronne. Une petite luciole s'allume, puis s'éteint. |
| | `evt_d13_scanner_opt_refuse` / `_res_refuse` | Le rendre ★ / Le sac de linge repart comme il est venu. |
| 2 (lettre, si `sc33_manifest_kept`) | `evt_d13_ecrou` | Noa porte l'écrou du vieux Dérivant au cou. La page jaunie, vous l'avez rangée avec le badge de Dora. |

Flags : `noa_armband` / `noa_armband_refused` (`suspicion +1`) ; `scanner_luciole`, `lucioles_trust +1`.

#### J14 — Les noms ; l'ACV-2

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si `dora_told_puits9`, Dora présente) | `evt_d14_names_title` | LES NOMS |
| | `evt_d14_names_text` | Dora ne dort pas. Elle récite des noms entre deux bouffées d'oxygène. « Brandt, Mbeki, Novak… Écris, avant que j'oublie. » |
| | `evt_d14_names_opt_write` / `_res_write` | Écrire ★ / Trois pages. Dora s'endort au nom quarante et un. Il en reste cent soixante et onze. |
| | `evt_d14_names_opt_sleep` / `_res_sleep` | La laisser dormir / Vous lui tenez la main. Les noms continuent, plus bas, jusqu'au matin. |
| 1 | `evt_d14_lease_title` | ASSISTANT DE CONFORMITÉ ACV-2 |
| | `evt_d14_lease_text` | Location : 5 ₵ par soir, retenus d'office. Le boîtier surligne les dates expirées et transmet vos verdicts à la Commission. |
| | `evt_d14_lease_opt_take` / `_res_take` | Louer l'ACV-2 / Un technicien visse le boîtier jaune. Il clignote quand vous hésitez. |
| | `evt_d14_lease_opt_decline` / `_res_decline` | Décliner ★ / « Comme vous voudrez. Les guichets équipés sont plus rapides. » |
| 2 (lettre, si un proche `MALADE` et `sc09_doctor_passed`) | `evt_d14_noor` | La médecin du J5 passe, sa sacoche à la main. « Je ne compte pas les crédits. Je compte les toux. » Médicaments à 5 ₵ ce soir. |

Flags : `dora_names_written`, `registre +1` ; `scanner_consortium`, `loyalty +1`, coût récurrent 5 ₵ (J14–J19 ; remplace `scanner_luciole` si les deux) ; `evt_d14_noor` : poste médicaments à 5 ₵.

#### J15 — La caisse du 07 ; pénurie ; Ilan rentre

| Ordre | Clé | Texte |
|---|---|---|
| 0 | `evt_d15_fund_title` | LA CAISSE DU 07 |
| | `evt_d15_fund_text` | L'agent du Guichet 07, emmené le 20, ne reviendra pas. Les guichets cotisent pour sa famille. L'enveloppe passe de vitre en vitre. |
| | `evt_d15_fund_opt_give` / `_res_give` | Donner 10 ₵ / Vous ajoutez dix crédits et un mot. Quelqu'un a dessiné une luciole sur l'enveloppe. |
| | `evt_d15_fund_opt_pass` / `_res_pass` | La faire passer ★ / L'enveloppe continue sa route, un peu plus légère que vous ne l'auriez voulu. |
| | `evt_d15_fund_opt_report` / `_res_report` | La remettre à la Commission / « Collecte non déclarée. » La Commission remercie. Les vitres, non. |
| 1 (lettre) | `evt_d15_food` | Pénurie hydroponique : la nourriture coûte 12 ₵ à partir de ce soir. Les serres de l'Anneau D « se rééquilibrent ». |
| 2 (lettre, si `ilan_in_hiding`) | `evt_d15_ilan_back` | Ilan rentre de la Soute, amaigri·e, une brûlure de vanne sur la main. La clé du recycleur dort sous l'oreiller. |

Flags : `fund_given` (`solidarite +1`) / `fund_reported` (`loyalty +1`, `solidarite −2`) ; Ilan → présent·e, `MALADE`.

#### J16 — Le recycleur central ; avant la Revue

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si Ilan présent·e, libre, non `ilan_estranged`, et `ilan_supported` ou `ilan_meter_job` ou `lucioles_trust ≥ 4`) | `evt_d16_call_title` | LE RECYCLEUR CENTRAL |
| | `evt_d16_call_text` | Un mot pour Ilan : « Dimanche, 15:00, le recycleur central de l'Anneau D. On a besoin de tes mains. » |
| | `evt_d16_call_text_meter` *(si `ilan_meter_job`)* | Un mot pour Ilan : « Tu poses leurs compteurs : toutes les portes s'ouvrent devant toi. Dimanche, 15:00. Le recycleur central. » |
| | `evt_d16_call_opt_go` / `_res_go` | « Va. » / Ilan part à minuit avec la clé. Noa fait semblant de dormir, encore. |
| | `evt_d16_call_opt_stay` / `_res_stay` | « Reste. » ★ / Ilan brûle le mot. La cendre est magenta. Personne ne dort. |
| 1 (si `scanner_luciole`) | `evt_d16_unplug_title` | AVANT LA REVUE |
| | `evt_d16_unplug_text` | Demain, la Commission inspecte les guichets. Le boîtier magenta est sous votre comptoir. |
| | `evt_d16_unplug_opt_unplug` / `_res_unplug` | Le débrancher ★ / Vous le rangez dans le sac de linge. La petite luciole s'éteint. |
| | `evt_d16_unplug_opt_keep` / `_res_keep` | Le laisser / Il ronronne. Vous aussi, un peu, pour couvrir le bruit. |
| 2 (lettre) | `evt_d16_tariffs` | Rééquilibrage tarifaire : oxygène d'appoint 15 ₵, médicaments 20 ₵ par proche malade. |

Flags : `ilan_joined_soute` (`lucioles_trust +1`, Ilan → `ABSENT · DANS LA SOUTE`) / `ilan_stayed` ; `scanner_luciole_removed` (plus d'effet en jeu, plus de risque).

#### J17 — La Revue ; la liste des tièdes ; le dossier classé

| Ordre | Clé | Texte |
|---|---|---|
| 0 (`AUDIT`) | `evt_d17_review_title` | LA REVUE DE RÉÉQUILIBRAGE |
| | `evt_d17_review_arrest` *(score ≥ 5 → F1)* | Beaumont ne lève pas les yeux. « Le Guichet 04 est révoqué. Vous aussi. » Deux gardes attendent. |
| | `evt_d17_review_demoted` *(3–4)* | « Rétrogradation confirmée. Retenue de 40 ₵. Vous étiez sur la liste. Vous n'y êtes plus. Presque. » |
| | `evt_d17_review_clean` *(≤ 2)* | « Rien. Vous êtes la personne la plus ennuyeuse de ce Hall. C'est un compliment. » |
| 1 | `evt_d17_list_title` | LA LISTE DES TIÈDES |
| | `evt_d17_list_text` | Beaumont tend une liste : six agents « tièdes ». « Ajoutez un nom ou confirmez-en un. Prime : 15 ₵. » |
| | `evt_d17_list_opt_sign` / `_res_sign` | Confirmer un nom (+15 ₵) / Votre signature tient en une ligne. Celle du collègue aussi, désormais. |
| | `evt_d17_list_opt_refuse` / `_res_refuse` | Refuser ★ / « Noté », dit Beaumont. Elle a le même stylo que Ravel. |
| | `evt_d17_list_opt_warn` / `_res_warn` | Refuser, puis prévenir les six / Six portes, six coups frappés. À la sixième, on vous offre un thé. |
| 2 | `evt_d17_file_title` | UN DOSSIER CLASSÉ |
| | `evt_d17_file_text` | Sur le bureau de la Commission, un dossier gris : « PUITS 9 — CLASSÉ ». Une note de 2179 parle d'Albédo. La date est raturée. Beaumont est sortie. |
| | `evt_d17_file_opt_copy` / `_res_copy` | Recopier une page / Vous écrivez au dos de votre fiche de paie. La main tremble un peu. |
| | `evt_d17_file_opt_leave` / `_res_leave` | Ne pas toucher ★ / Vous regardez le mur. Beaumont revient. Le dossier n'a pas bougé. |
| 3 (lettre, si `final_detained`) | `evt_d17_mira` | Brève de minuit : « Une détenue s'est soustraite à la Continuité pendant les transferts de la Revue. Recherchée : M. Vasquez-Orlov. » |

Score de la Revue = `suspicion` + 2 (`scanner_luciole` et non `scanner_luciole_removed`) − 1 (`scanner_consortium`). Effets : F1 (`review_arrested`) ; `purge_demoted` (−40 ₵, `loyalty −1`, `promotion_revoked`) ; `purge_clean`. Puis : `colleagues_listed` (`loyalty +2`, `solidarite −2`, +15 ₵) / `colleagues_refused` (`solidarite +1`, `suspicion +1`) / `colleagues_warned` (`solidarite +2`, `suspicion +1`, `loyalty −1`) ; `puits9_file_copied` (`registre +1`, `suspicion +1`) ; `mira_escaped`.

#### J18 — Rentrer à Tycho ; l'ordre de la Commissaire

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si Dora vivante et présente) | `evt_d18_dora_title` | RENTRER À TYCHO |
| | `evt_d18_dora_text` | Dora a écrit à sa sœur, à Tycho. « Je veux respirer de la poussière une dernière fois. » La Transit-7 part dimanche. Billet : 40 ₵. |
| | `evt_d18_dora_opt_pay` / `_res_pay` | Payer le billet (40 ₵) / Dora glisse son badge dans votre poche, pas dans la sienne. « Tu en auras plus besoin que moi. » |
| | `evt_d18_dora_opt_keep` / `_res_keep` | « Reste avec nous. » ★ / « Alors je mourrai sous ton hublot. Ce n'est pas si mal. » Elle rit, puis tousse. |
| 1 (lettre) | `evt_d18_beaumont_obeyed` | Lettre de la Commission : « Obéissance notée. Votre promotion est confirmée pour le 01.04. » |
| | `evt_d18_beaumont_defied` | Lettre de la Commission : « Insubordination notée. La ration de fidélité de votre aînée est suspendue. » |

Flags : `dora_departed` (Dora → `ABSENT · PARTIE À TYCHO`, plus de ration ni d'oxygène) / `dora_stayed`. `beaumont_obeyed` → `promotion_offered` ; `beaumont_defied` → `promotion_revoked` (oxygène de Dora payant).

#### J19 — Le dernier cargo ; les vitres ; le registre

| Ordre | Clé | Texte |
|---|---|---|
| 0 (si `drift2_offer`) | `evt_d19_drift_title` | QUAI 6, LUNDI 05:00 |
| | `evt_d19_drift_text` | La carte de Wren : quatre places sur le Basse-Marée, 60 ₵. « Après lundi, le quai 6 ferme aux cargos. » |
| | `evt_d19_drift_opt_buy` / `_res_buy` | Acheter les places (60 ₵) / Wren compte deux fois. « Lundi. Pas une minute de retard. Cette fois, venez. » |
| | `evt_d19_drift_opt_keep` / `_res_keep` | Garder la carte ★ / Deux cartes de quai dans la poche, maintenant. Deux portes que vous n'avez pas prises. |
| 1 (si `solidarite ≥ 3`) | `evt_d19_strike_title` | DEMAIN, LES VITRES |
| | `evt_d19_strike_text` | Un mot circule de vitre en vitre : « Demain, 15:00, toutes les lampes s'éteignent. Ensemble, ou pas du tout. » |
| | `evt_d19_strike_opt_join` / `_res_join` | En être / Vous faites passer le mot au guichet suivant. Il n'y a plus de 03 : vous le glissez sous sa porte quand même. |
| | `evt_d19_strike_opt_abstain` / `_res_abstain` | Ne pas en être ★ / Le mot repart. Personne ne vous le reproche. Personne ne vous regarde. |
| 2 (si `registre ≥ 3`) | `evt_d19_registre_title` | LE REGISTRE |
| | `evt_d19_registre_text` | %d pages sur la table. Le haut-parleur du Hall lit tout ce qu'on glisse dans la fente des bulletins. Demain, il pourrait lire 212 noms. |
| | `evt_d19_registre_opt_send` / `_res_send` | Glisser le registre dans la fente / Le ruban part dans le tube pneumatique avec un bruit de soupir. |
| | `evt_d19_registre_opt_surrender` / `_res_surrender` | Le remettre à la Commission (+20 ₵) / Beaumont feuillette. « Des noms. Il y en a tant. » Elle les range dans le dossier gris. |
| | `evt_d19_registre_opt_keep` / `_res_keep` | Le garder ★ / Les pages restent sous le badge de Dora. Un jour, peut-être. |

Flags : `drift2_passes_bought` ; `strike_joined` (`loyalty −2`) ; `registre_sent` (`suspicion +2`) / `registre_surrendered` (`loyalty +2`, `registre := 0`, 🟡 effet « fixer une jauge »).

#### J20 — pas de soirée

Le dernier cas (ou l'annonce de grève) enchaîne sur le bilan, puis sur l'évaluation des fins (§1.3) et l'épilogue (comme D-053).

### 5.4 Épilogues de l'Acte II

Même format que NARRATIVE §6.2 (titre + 5 à 8 lignes ; « [si drapeau] sinon la suivante »). Préfixe **`end2_`** ; F2, F3 (anticipées) et F6 du J10 réutilisent les clés `end_f2_*`, `end_f3_*`, `end_f6_*` existantes. Titres et surtitres : `end2_fN_title`, `end_eyebrow_f8_registre`, `end_eyebrow_f9_strike`.

#### F1 — `end2_f1_title` « MISE EN ATTENTE »

| Clé | Texte |
|---|---|
| `end2_f1_l1` | Anneau B. La lumière blanche ne s'éteint pas, même le dimanche. |
| `end2_f1_l2_review` *(Revue du J17)* | Beaumont lit votre dossier à voix haute. Elle s'arrête aux chiffres, jamais aux noms. |
| `end2_f1_l2_double` *(J20)* | « Loyal envers tout le monde. Donc envers personne. » La Commission a deux colonnes ; vous étiez dans les deux. |
| `end2_f1_l3_ravel` *(si `ravel_file_destroyed`)* | Le dossier de Ravel a brûlé. La Commission en a écrit un autre, plus court. |
| `end2_f1_l3` | Ilan, Noa et Dora sont réaffecté·es vers un dortoir sans hublot. |
| `end2_f1_l4` | Au Guichet 04, un compteur neuf affiche QUOTA 0/3. |
| `end2_f1_l5` | Il pleut, même ici. |

#### F4 — `end2_f4_title` « CLASSE C-2 »

| Clé | Texte |
|---|---|
| `end2_f4_l1_ilan` *(si `ilan_detained_final`)* | Ilan est mis·e en attente à 13:40. Vous signez le procès-verbal d'une main sûre. |
| `end2_f4_l1` | Mira est mise en attente à 13:40. Cette fois, l'Anneau B ferme à double tour. |
| `end2_f4_l2` | Promotion C-2 signée par la Commissaire. Un appartement à l'Anneau D, un compteur qui ne clignote jamais. |
| `end2_f4_l3_ilan` *(si `ilan_detained_final` ou `ilan_denounced`)* | Noa ne vous parle plus. Elle parle au hublot, le soir, à voix basse. |
| `end2_f4_l3` | Noa ne tousse plus. Elle garde le brassard jaune, à l'envers. |
| `end2_f4_l4_tycho` *(si `dora_departed`)* | Dora écrit de Tycho. Elle ne demande pas comment est l'appartement. |
| `end2_f4_l4` | Dora respire un air sans ozone. Elle dit qu'il n'a pas de goût. |
| `end2_f4_l5_silva` *(si `sc43_mateus_detained`)* | Le technicien Silva n'est jamais ressorti de l'Anneau B. Il était rare, pourtant. |
| `end2_f4_l5_kasimir` *(si `sc47_kasimir_passed`)* | À 15:04, le quai 1 a explosé. La Commission parle d'un « incident de maintenance ». |
| `end2_f4_l6` | Le Hall ferme six guichets « pour efficacité ». Le vôtre devient un bureau, avec une porte. |
| `end2_f4_l7` | Gloire au Consortium. Vous le dites en signant, maintenant. |

#### F5 — `end2_f5_title` « RENDRE L'AIR »

Variante **Veilleurs** (`end2_f5v_*`) :

| Clé | Texte |
|---|---|
| `end2_f5v_l1` | Dimanche, 15:00. Le recycleur central s'ouvre. L'air des Anneaux descend partout, cette fois. |
| `end2_f5v_l2_ilan` *(si SC-50 = Ilan)* | Ilan tourne la vanne. Sa main brûlée tient bon. |
| `end2_f5v_l2` | Mira tourne la vanne en disant les noms du Puits 9, un par tour. |
| `end2_f5v_l3` | La Commission coupe, puis négocie, puis signe. Le quota respiratoire est aboli « provisoirement ». |
| `end2_f5v_l4_strike` *(si `strike_joined`)* | Les vitres du Hall étaient déjà éteintes. Personne ne les rallume. |
| `end2_f5v_l4_dmitri` *(si `sc24_dmitri_hired`)* | Au recycleur 3, une main de métal tient la porte ouverte. |
| `end2_f5v_l4` | Valentin Choi relit le plan des vannes. Il n'y a plus rien à cacher. |
| `end2_f5v_l5_registre` *(si `registre_sent`)* | On grave les 212 noms sur la vanne centrale. Lindgren corrige l'orthographe. |
| `end2_f5v_l5` | Albédo ? Les Veilleurs disent que ce n'était pas eux. La Commission dit que si. L'air ne dit rien. |
| `end2_f5v_l6` | Vous rendez votre tampon. Noa le garde : il imprime très bien les lucioles. |

Variante **Brûlants** (`end2_f5b_*`) :

| Clé | Texte |
|---|---|
| `end2_f5b_l1` | Dimanche, 15:00. Le recycleur central s'ouvre. À 15:04, le quai 1 explose. |
| `end2_f5b_l2_kasimir` *(si `sc47_kasimir_passed`)* | L'homme au thermorégulateur n'était pas un homme de maintenance. |
| `end2_f5b_l2` | Les Brûlants n'avaient attendu personne. |
| `end2_f5b_l3` | L'air descend dans les coursives, avec la fumée. |
| `end2_f5b_l4` | Les Anneaux sont scellés trois jours. La Commission tombe. Une autre la remplace. |
| `end2_f5b_l5` | Kasimir revendique le quai 1. Et Albédo, tant qu'il y est. Personne ne le croit. Personne ne sait. |
| `end2_f5b_l6` | Vous respirez mieux. Vous dormez moins bien. Noa dessine des lucioles avec des flammes. |

#### F6 — `end2_f6_title` « À LA DÉRIVE »

| Clé | Texte |
|---|---|
| `end2_f6_l1` | Lundi, 05:00, quai 6. Le Basse-Marée est le dernier cargo avant le blocus. |
| `end2_f6_l2` | Wren raye vos noms d'un registre que personne ne contrôle. Elle en garde un, pour elle. |
| `end2_f6_l3_tycho` *(si `dora_departed`)* | Dora n'est pas à bord. Elle est déjà rentrée, à sa façon. |
| `end2_f6_l3` | Dora regarde Halcyon rapetisser. « Tycho était plus petite. Et plus honnête. » |
| `end2_f6_l4_ilan` *(si `ilan_joined_soute` et non `ilan_detained_final`)* | Ilan arrive en courant à 04:58, les mains noires. La vanne attendra quelqu'un d'autre. |
| `end2_f6_l5` | Noa apprend ‹vanu›, le mot pour l'air. Elle le dit à chaque hublot. |
| `end2_f6_l6` | Derrière vous, la station respire comme elle peut. Vous ne saurez jamais très bien comment. |

#### F7 — `end2_f7_title` « LE GUICHET ROUVRE LUNDI »

| Clé | Texte |
|---|---|
| `end2_f7_l1` | Lundi 02.04.2187, 10:00. Le carillon, trois notes. Le compteur clignote. |
| `end2_f7_l2_denied` *(si `final2_denied`)* | La clé a trouvé une autre vitre. La vanne s'est ouverte, puis refermée dans l'heure. |
| `end2_f7_l2_passed` *(si `final2_passed`)* | La clé est passée. Il manquait des mains au recycleur central. L'opération s'est éteinte sans bruit. |
| `end2_f7_l2_detained` *(si `final2_detained`)* | La clé est en Anneau B. On ne vous a rien proposé. On ne propose rien aux guichets moyens. |
| `end2_f7_l2` | Rien ne s'est passé, hier. C'est ce que dit le bulletin. |
| `end2_f7_l3_ravel` *(si `sc45_ravel_refused`)* | Un homme courtois balaie le Hall. Il vous salue : « Guichet 04. » |
| `end2_f7_l3` | Nouvelle directive : le formulaire 27-B est rétabli. |
| `end2_f7_l4_lindgren` *(si `sc49_lindgren_yes`)* | Lindgren passe sans rien demander. Il dit bonjour. C'est tout. C'est beaucoup. |
| `end2_f7_l5` | La file serpente entre les barrières magnétiques. Elle ne finit jamais. |
| `end2_f7_l6` | « Suivant. » |

#### F8 🆕 — `end2_f8_title` « LE REGISTRE »

| Clé | Texte |
|---|---|
| `end2_f8_l1` | À 12:20, le haut-parleur du Hall lit : « Puits 9, 2151. Achebe, Ana. Brandt, Ilse… » |
| `end2_f8_l2` | La file s'arrête. Les guichets s'arrêtent. Deux cent douze noms, une heure entière. |
| `end2_f8_l3_tycho` *(si `dora_departed`)* | À Tycho, la radio de la mine répète les noms. Dora dit « présente » à la place de son amie. |
| `end2_f8_l3_dora` *(si Dora vivante)* | Au Bloc Pétrel, Dora dit « présent » pour chaque nom. Noa l'aide pour les difficiles. |
| `end2_f8_l3` | Noa compte les noms sur ses doigts. Elle n'a pas assez de doigts. |
| `end2_f8_l4` | Le Bureau parle d'un « enregistrement ancien, sans valeur documentaire ». |
| `end2_f8_l5` | Une page du registre parle d'Albédo. Elle accuse tout le monde. Elle ne prouve rien. |
| `end2_f8_l6_detained` *(si `final2_detained`)* | Le même jour, vous avez mis la clé en attente. Le registre ne dit rien de vous. |
| `end2_f8_l6_lindgren` *(si `lindgren_signed`)* | Lindgren classe le registre au sous-sol 3, étagère 1. « Pour qu'on le trouve. » |
| `end2_f8_l7` | On vous mute aux quais. Vous gardez le badge de Dora. Le Hall se souvient d'une heure. |

#### F9 🆕 — `end2_f9_title` « LES VITRES ÉTEINTES »

| Clé | Texte |
|---|---|
| `end2_f9_l1` | À 15:00, la lampe du Guichet 04 s'éteint. Puis celle du 05. Puis toutes. |
| `end2_f9_l2_sato` *(si `sc41_sato_spared`)* | Sato, sans badge, tient la porte du Hall ouverte. « Ce n'est conforme à rien. C'est très bien. » |
| `end2_f9_l2` | Les agents posent leurs tampons à plat sur le comptoir, comme des cartes. |
| `end2_f9_l3_okonkwo` *(si `sc35_okonkwo_helped` ou `okonkwo_shielded`)* | Okonkwo arrive des quais avec trois dockers. « La règle, juste assez… comme on dit. » |
| `end2_f9_l3` | Quelqu'un tape trois fois sur chaque vitre éteinte. |
| `end2_f9_l4_ravel` *(si `sc45_ravel_spared`)* | Ravel rédige le communiqué. Il est courtois, froid, et parfaitement conforme. |
| `end2_f9_l4` | La Commission menace, puis compte : sans vitres, personne n'entre. Ni le minerai, ni les cadres. |
| `end2_f9_l5` | Au troisième jour, le quota respiratoire est suspendu « pour révision ». |
| `end2_f9_l6_registre` *(si `registre_sent`)* | Le matin, les noms du Puits 9. L'après-midi, le silence des vitres. La station a entendu les deux. |
| `end2_f9_l6` | Personne n'est promu. Personne n'est révoqué. Pour l'instant. |
| `end2_f9_l7` | Vous rentrez à pied au milieu des autres. Il pleut, même ici. Ensemble, c'est moins froid. |

---

## 6. Économie et difficulté J11 → J20

### 6.1 Barème (valeurs de départ, `EconomyDef` 🟡)

| Poste | J10 (rappel D-059) | Acte II | Notes |
|---|---|---|---|
| Salaire | 5 ₵ / cas correct | 5 ₵ ; **0 ₵** pour une entrée imputée (quota) | primes inchangées : détention 5 ₵, signalement 10 ₵ |
| Amendes | 2 avertissements, −5, puis −10 | inchangé | D-060 : pas de plafond |
| Loyer | 20 ₵ | 20 ₵ | — |
| Taxe d'air | 10 ₵ prélevés | **supprimée** → rations | M2 |
| Ration (vous) | — | 3 ₵, prélevée d'office | peut creuser la dette, comme l'ancienne taxe |
| Rations Ilan / Noa / Dora | — | 4 / 3 / 4 ₵, cochables | +1 ₵ chacune si `meter_refused` ; grisées si `ABSENT` |
| Nourriture | 10 ₵ | 10 ₵, **12 ₵ dès le J15** | — |
| Chauffage | 6 ₵ | 6 ₵ | — |
| Oxygène de Dora | 10 ₵ soirs pairs | 10 ₵, **15 ₵ dès le J16** (soirs pairs) ; **0 ₵** si `promotion_offered` et non `promotion_revoked` | — |
| Médicaments | 15 ₵ / malade | 15 ₵, **20 ₵ dès le J16** | 5 ₵ le J14 si la médecin passe |
| Prélèvements | — | J11 et J17 : **30 %** de l'épargne au-delà de **40 ₵** | puits pour les bons joueurs (GDD §13 : « le surplus des bons joueurs croît ») |
| Revenus du foyer | — | Ilan technicien·ne de rationnement : +8 ₵/soir (J13–J19) | choix moral |
| Dépenses datées | — | compteur 10, caution 60, brassard 5, ACV-2 5/soir, caisse 10, billet de Dora 40, places 60 ₵ | §3.1 |
| Revue J17 | audit J9 : retenue 30 ₵ | rétrogradation : −40 ₵ | seuils 5 / 3 |

Base quotidienne obligatoire+courante (loyer, ration personnelle, 3 rations, nourriture, chauffage) : **50 ₵** (J11–J14), **52 ₵** (J15+), + oxygène les soirs pairs (10/15 ₵). Au J10 elle était de 46 ₵ (+10).

### 6.2 Projection par profil (à vérifier par simulation)

Revenus = `passenger_count` × 5 × précision − amendes (escalade), cohérent avec GDD §13.

| Profil | Solde au soir du J10 (QA §2.2) | Après prélèvement J11 | Net quotidien estimé J11–J20 | Lecture |
|---|---|---|---|---|
| 60 % | négatif ou proche de 0 (~88 % des campagnes déjà finies, D-060) | 0 | ≈ 16 × 5 × 0,6 − ~35 d'amendes ≈ 13 ₵ contre 50 ₵ → **−37 ₵/soir** | effondrement en 2–4 soirs (F2/F3) : cohérent avec « dur » (D-060) |
| 80 % | ≈ 114 ₵ | ≈ 92 ₵ | ≈ 64 − 10 ≈ 54 ₵ contre 55 ₵ (oxygène lissé) → **≈ 0 ₵/soir** | le capital de l'Acte I paie **une ou deux** grosses options (caution, billet, places, ACV-2) ; ≥ 1 poste sacrifié un soir sur 4 |
| 95 % | ≈ 260 ₵ | ≈ 194 ₵ | ≈ 80 − 0 ≈ 80 contre 55 → **+25 ₵/soir** | tout est payable ; le 2ᵉ prélèvement (J17) ramène ~340 → ~250 ₵ : le dilemme reste moral, pas financier |

Le quota souple ne coûte que si le joueur choisit de dépasser : chaque dépassement = 5 ₵ de manque à gagner. Au-delà de 3 dépassements par jour, la suspicion devient le vrai prix (Revue, double jeu).

### 6.3 Cibles par profil

| Profil | Cibles Acte II |
|---|---|
| **60 %** | atteindre le J11 ≤ 15 % des campagnes ; parmi elles, fin anticipée (F2/F3) ≥ 80 % avant le J15 ; atteindre le J20 ≤ 5 % au total |
| **80 %** | atteindre le J20 ≥ 85 % (des campagnes arrivées au J11) ; foyer : `alive ≥ 2` ≥ 90 % ; ≥ 1 poste sacrifié 20–35 % des soirs ; fins dominantes selon la politique : F7 (par défaut), F9 (`solidaire`), F8 (`archiviste`), F6 (`drift`, si elle n'a pas pris F6 au J10) ; F4 rare (conformité < 0,85) |
| **95 %** | F4 ≥ 85 % (`loyal`), F5 ≥ 80 % (`luciole`), F6 ≥ 90 % (`drift`), F8 ≥ 80 % (`archiviste`), F9 ≥ 80 % (`solidaire`) ; F1 par la Revue ≥ 90 % (`mercenary`, enveloppes gardées) |
| Tous | chacune des 9 fins atteignable par au moins une politique (test d'intégration, comme `test_simulated_profiles_reach_every_ending`) |

### 6.4 Simulation à faire (`tools/balance_sim.gd`)

- Étendre à **20 jours** ; nouveaux préréglages : `archiviste` (garde pages et formulaires, écrit les noms, recopie le dossier, envoie le registre), `solidaire` (signe la pétition, donne à la caisse, refuse la liste, épargne Sato/Okonkwo/Ravel, vote la grève), `overrun` (approuve toujours au-delà du quota).
- Modéliser le **quota** (compteur par jour, exemptions) et le **couvre-feu** (index → heure de présentation : `10:00 + (index / passenger_count) × 8 h` au premier ordre, avec une dispersion par précision).
- Vérifier les seuils : F4 `loyalty ≥ 7`, F5 `lucioles_trust ≥ 7`, double jeu 7/7, Revue 5/3. Ajuster les **seuils**, pas les règles (GDD §14), puis `air_quota`, puis `duration_sec`.
- Mesurer le temps par cas (ACV-2 : gain attendu ~5 s) en playtest humain.

### 6.5 Mesuré (M8 partie A, Gameplay Systems)

`godot --headless --script res://tools/balance_sim.gd -- --seeds=40 --profiles=0.6,0.8,0.95 --presets=…` (graine 1, soirées « raisonnables » : loyer > nourriture > rations > oxygène > soins urgents > chauffage ; barème §6.1 appliqué tel quel, `review_arrest_score` 5 / `review_demote_score` 3). Profils Acte II ajoutés à `SimProfile` : `drift10` (embarque au J10), `archiviste`, `solidaire`, `overrun`, `mercenary2` (rend les enveloppes à l'Acte I, les garde à partir du J11).

| Profil | 60 % | 80 % | 95 % |
|---|---|---|---|
| `default` | F2 55 % (J6) · F3 45 % (J7,8) | **F7 97,5 %** · F2 2,5 % | F7 100 % |
| `loyal` | F2 47,5 % · F3 52,5 % | F7 100 % (conformité < 0,85) | **F4 90 %** · F7 10 % |
| `luciole` | F2 65 % · F3 35 % | F5 80 % · F1 15 % (J17) · F2/F3 5 % | **F5 95 %** · F1 5 % (Revue) |
| `drift` | F2/F3 100 % | F6 55 % (J20) · F7 42,5 % | **F6 100 %** (J20) |
| `drift10` | F2/F3 100 % | F6 57,5 % (J10) · F7 40 % | F6 100 % (J10) |
| `archiviste` | F2/F3 100 % | **F8 97,5 %** | **F8 100 %** |
| `solidaire` | F2/F3 100 % | **F9 97,5 %** | **F9 100 %** |
| `overrun` | F2/F3 100 % | F7 92,5 % · F1 5 % | F7 97,5 % · F1 2,5 % |
| `mercenary` (enveloppes dès le J4) | F1 57,5 % (audit J9) · F2/F3 | F1 100 % (audit J9) | F1 100 % (audit J9) |
| `mercenary2` (enveloppes dès le J11) | F2/F3 95 % · F1 5 % | F1 60 % (Revue J17) · F7 37,5 % | **F1 47,5 %** (Revue) · F7 52,5 % |
| `negligent` / `evicted` | F3 (J6) / F2 (J3) | idem | idem |

Cibles §6.3 : 60 % — J11 atteint **0 %** (≤ 15 % ✅), J20 0 % (≤ 5 % ✅) ; 80 % — J20 atteint 97,5 % (≥ 85 % ✅), aucune fin F3 à 80 % (`alive ≥ 2` non mesuré séparément), ≥ 1 poste sacrifié 18 % des soirs au J11 (cible 20–35 % : un peu bas, le prélèvement du J11 restant inférieur au surplus de l'Acte I) ; fins dominantes conformes (F7 / F9 / F8 / F6) et F4 nulle à 80 % ✅ ; 95 % — F4 90 % ✅, F5 95 % ✅, F6 100 % ✅, F8 100 % ✅, F9 100 % ✅. **Écart** : « F1 par la Revue ≥ 90 % (`mercenary`) » non atteint — un `mercenary` qui garde les enveloppes dès le J4 est arrêté par l'audit du J9 (Acte I, D-059 inchangé) et n'atteint jamais la Revue ; le profil `mercenary2` (enveloppes à partir du J11) n'y est arrêté que dans 47,5 % des campagnes (`review_arrest_score = 4` : 67,5 %, mais `luciole` passe alors à 12,5 % de F1). Seuils laissés à 5 / 3 en attente d'arbitrage (D-080 proposé). Toutes les fins F1–F9 sont atteintes par au moins un profil (`tests/integration/test_act2_campaign.gd`).

---

## 7. Clés i18n

### 7.1 Préfixes

Les préfixes de NARRATIVE §7.2 restent valables. Ajouts :

| Préfixe | Usage | Exemple |
|---|---|---|
| `sc23_` → `sc50_<nom>[_<variante>]_<suffixe>` | répliques des cas (§4) | `sc35_okonkwo_quai_confront` |
| `day11_` → `day20_{directive_title,intro,slogan}` | briefings | `day16_intro` |
| `msg_comm_dayNN[_variante]` / `msg_comm_overrun` | Commission | `msg_comm_day19_defied` |
| `msg_sato_dayNN[_variante]` | Sato (intercom) | `msg_sato_day14_kerr` |
| `msg_brul_dayNN` | Brûlants (encre noire) | `msg_brul_day11` |
| `msg_dora_dayNN[_variante]` | Dora (emplacement foyer) | `msg_dora_day20_tycho` |
| `evt_d10_` → `evt_d19_<id>_{title,text[_variante],opt_*,res_*}` | soirées | `evt_d17_list_opt_warn` |
| `hall_quota_full`, `hall_jNN_<id>` | annonces du Hall | `hall_j20_strike` |
| `end2_fN_*`, `end2_f5v_*`, `end2_f5b_*` | épilogues Acte II | `end2_f9_l7` |
| `end_trace_<flag>` | traces de fin (existant) | `end_trace_registre_sent` |
| `r_<règle>_{title,text}` | règles R23–R31 (existant) | `r_curfew_text` |
| `doc_<id>_title`, `field_<id>`, `val_<famille>_<valeur>` | documents, champs, valeurs | `field_vessel` |
| `rb_tab_<onglet>`, `rb_emp_<code>`, `rb_vessel_<nom>` | Rulebook | `rb_emp_cv` |
| `tb_quota*` | barre d'état | `tb_quota_full` |
| `chapter2_*` | interstitiel | `chapter2_title` |

### 7.2 Clés système (les textes des §1, §4 et §5 sont définitifs et ne sont pas répétés)

| Clé | Texte |
|---|---|
| `chapter2_title` | ACTE II — RÉÉQUILIBRAGE |
| `chapter2_sub` | Vendredi 23.03.2187 — dimanche 01.04.2187 |
| `spk_commission` | COMMISSION DE RÉÉQUILIBRAGE · I. BEAUMONT |
| `spk_sato` | SATO · GUICHET 03 |
| `spk_sato_former` | SATO · SANS GUICHET |
| `spk_brulants` | SANS SIGNATURE · ENCRE NOIRE |
| `r_air_quota_title` | Quota respiratoire |
| `r_air_quota_text` | Ressortissants : %d entrées par jour. Quota atteint : refus justifié ; toute entrée de plus est imputée au guichet (0 ₵). Exemptés : Nés-Halcyon, motif DIPLOMATIQUE. |
| `r_contract_required_title` | Contrat de travail |
| `r_contract_required_text` | Motif TRAVAIL : Contrat de travail obligatoire, au nom du porteur, non expiré. |
| `r_contract_consistent_title` | Code employeur |
| `r_contract_consistent_text` | Le code du contrat (CT-XX) correspond à l'employeur du permis (onglet Codes employeurs). |
| `r_drift_pass_title` | Laissez-passer de dérive |
| `r_drift_pass_text` | Dérivants (DRV) : Laissez-passer de dérive obligatoire. Vaisseau = nom de famille, inscrit au Registre des cargos. |
| `r_nx_firmware_title` | Firmware NX |
| `r_nx_firmware_text` | Shunts NX- : mise à jour (champ Firmware) de moins de 90 jours. |
| `r_asylum_required_title` | Attestation d'asile |
| `r_asylum_required_text` | Gravitaires (TER) de classe C-5 : Attestation d'asile obligatoire, non expirée, au nom du porteur. |
| `r_curfew_title` | Couvre-feu respiratoire |
| `r_curfew_text` | Présentation après 16:00 (ticket de file) : motifs VISITE FAMILIALE, COMMERCE et TRANSIT refusés. Nés-Halcyon exemptés. |
| `r_revoked_ids_title` | Révocations |
| `r_revoked_ids_text` | N° ID inscrit à l'onglet Révocations : le titulaire n'est plus citoyen. Refus. |
| `r_ter_closed_title` | Le Puits est clos |
| `r_ter_closed_text` | Gravitaires (TER) : entrée interdite, sauf Contrat de travail sur un poste en pénurie (RECYCLEUR, SOINS, HYDROPONIE). |
| `doc_work_contract_title` | Contrat de travail |
| `doc_drift_pass_title` | Laissez-passer de dérive |
| `doc_asylum_title` | Attestation d'asile |
| `doc_queue_ticket_title` | Ticket de file |
| `field_contract_code` | Code |
| `field_post` | Poste |
| `field_holder` | Titulaire |
| `field_vessel` | Vaisseau |
| `field_firmware` | Firmware NX |
| `field_zone` | Zone d'origine |
| `field_presented_at` | Présentation |
| `val_post_recycleur` / `_soins` / `_hydroponie` / `_manutention` / `_archives` / `_ratier` | RECYCLEUR / SOINS / HYDROPONIE / MANUTENTION / ARCHIVES / RATIER |
| `val_seal_asylum` | HEXAGONE GRIS |
| `val_seal_drift_ink` | TAMPON À L'ENCRE |
| `rb_tab_employers` | Codes employeurs |
| `rb_tab_vessels` | Registre des cargos |
| `rb_tab_revoked` | Révocations |
| `rb_emp_ka` / `_vh` / `_on` / `_mb` | KA · Kessler-Ashe Orbital / VH · Valcourt-Hsu Logistique / ON · Ondine Synaptique / MB · Meridian Biosystèmes |
| `rb_emp_cv` / `_ba` / `_at` / `_bc` / `_dt` | CV · Hydroponie Ceres-Verte / BA · Banque Aurel / AT · Autorité de Transit / BC · Bureau de Continuité / DT · Dispensaire de Tycho |
| `rb_vessels_removed` | Retirés : SILLAGE (démantelé le 20.03.2187). |
| `rb_implants_firmware` | NX- : firmware de moins de 90 jours. |
| `tb_quota` | QUOTA %d/%d |
| `tb_quota_full` | QUOTA ATTEINT |
| `ss_overruns` | Entrées imputées |
| `q_about_quota` / `q_about_curfew` / `q_about_revoked` / `q_about_contract` | (§4.0) |
| `line_about_quota_generic` | Atteint ? Et moi, je compte pour combien ? |
| `line_about_curfew_generic` | J'étais dans la file avant l'heure. La file ne compte pas ? |
| `line_about_revoked_generic` | Révoqué ? Depuis quand ? Personne ne m'a prévenu. |
| `line_about_contract_generic` | C'est le contrat qu'on m'a donné. Je n'ai pas choisi les lettres. |
| `wb_form_label` | FORMULAIRE 27-B |
| `wb_object_label` | OBJET |
| `wb_file_label` | DOSSIER |
| `wb_scanner_acv` | ACV-2 · suggestion |
| `wb_scanner_luciole` | ‹lumika› · suggestion |
| `hh_state_breathless` | ESSOUFFLÉ·E |
| `hh_state_away_soute` | DANS LA SOUTE |
| `hh_state_away_tycho` | PARTIE À TYCHO |
| `hh_ev_breathless` | %s a manqué d'air cette nuit. |
| `exp_ration_self` | Ration d'air · vous (prélevée) |
| `exp_ration_ilan` / `_noa` / `_dora` | Ration d'air · Ilan / Ration d'air · Noa / Ration d'air · Dora |
| `exp_meter_surcharge` | Forfait non-compteur |
| `exp_levy` | Prélèvement de Rééquilibrage |
| `exp_lease` | Location ACV-2 |
| `inc_ilan_job` | Salaire d'Ilan · rationnement |
| `wanted_faces_only` | AVIS DU JOUR · VISAGES SEULS |
| `wanted_okonkwo_reason` | Ex-agent du Guichet 03. Désertion. |
| `wanted_ilan_reason` | Technicien·ne de la nuit du 22. Sabotage. |
| `wanted_mira2_reason` | Évadée. Sabotage des recycleurs. |
| `wanted_kasimir_reason` | Réseau Brûlant. Dangereux. |
| `end_eyebrow_f8_registre` | HALL DES GUICHETS · HAUT-PARLEUR |
| `end_eyebrow_f9_strike` | HALL DES GUICHETS · VITRES ÉTEINTES |

### 7.3 Traces de fin ajoutées (`end_trace_*`)

| Clé | Texte |
|---|---|
| `end_trace_vannes_opened` | La nuit du 22, l'Anneau C a respiré une heure. |
| `end_trace_drift_stayed` | Vous êtes resté·e, le vendredi du Basse-Marée. |
| `end_trace_sc25_elena_turned_away` | Vous avez refusé la mère et le petit garçon : quota atteint. |
| `end_trace_quota_overrun` | Vous avez fait entrer des gens au-delà du quota, à vos frais. |
| `end_trace_sc28_tariq_refused` | Vous avez refusé le jeune homme au faux contrat. Il ne le savait pas. |
| `end_trace_sc35_okonkwo_detained` | Vous avez mis Okonkwo en attente. |
| `end_trace_sc35_okonkwo_helped` | Vous avez laissé passer Okonkwo, contre la règle qu'il vous avait apprise. |
| `end_trace_sc43_mateus_detained` | Vous avez obéi à la Commissaire. |
| `end_trace_beaumont_defied` | Vous avez désobéi à la Commissaire. |
| `end_trace_sc41_sato_spared` | Vous avez épargné Sato, le zélé. |
| `end_trace_sc45_ravel_spared` | Vous avez laissé passer l'inspecteur Ravel. |
| `end_trace_ilan_joined_soute` | Vous avez laissé Ilan partir pour le recycleur central. |
| `end_trace_dora_departed` | Dora est rentrée respirer la poussière de Tycho. |
| `end_trace_registre_sent` | Vous avez fait lire 212 noms dans le Hall. |
| `end_trace_strike_joined` | Vous avez éteint votre vitre avec les autres. |
| `end_trace_colleagues_listed` | Vous avez confirmé un nom sur la liste des tièdes. |

---

## 8. Besoins système (pour la planification)

Numérotation à la suite de NARRATIVE §8 (B16 / I10).

### 8.1 Données et modèle (Godot Architect / Gameplay Systems)

| # | Besoin | Détail |
|---|---|---|
| B17 | `day_11..20.tres`, `rs_day11..20` cumulatifs | `has_evening` vrai J10–J19 ; dernier jour = 20 (`SaveService.last_day()` le lit déjà depuis les fichiers) ; `DayDef.air_quota` |
| B18 | `AnomalyType.Kind` **en fin d'enum** (D-033) | `CONTRACT_MISMATCH = 17`, `UNREGISTERED_VESSEL = 18`, `OUTDATED_FIRMWARE = 19`, `REVOKED_ID = 20` + 4 injecteurs |
| B19 | Documents | `work_contract` (`CT-XX-NNNN` ; titulaire, N° ID, employeur, code, poste, émission, expiration, sceau corporatif), `drift_pass` (vaisseau, noms, naissance, émission, expiration, tampon encre), `asylum` (`AA-NNNN`, zone d'origine, sceau hexagone gris), `queue_ticket` (champ `presented_at`) ; champ `firmware` de la carte (DATE, présent seulement si `NX-`) |
| B20 | Génération | contrat pour tout motif TRAVAIL dès J12 (code = employeur, table des codes) ; laissez-passer pour `DRV` dès J13 ; attestation pour `TER` C-5 dès J15 ; firmware pour `NX-` ; registre des cargos (données) ; liste de révocations liée aux index (comme D-056) ; postes en pénurie |
| B21 | Règles | `AirQuotaRule` (souple), `CurfewRule` (heure de présentation), `ContractConsistentRule`, `DriftPassRule`, `RevokedIdRule`, `RequireDocumentRule.applies_to_purposes` / condition de classe, `DocumentNotExpiredRule` sur un champ (`firmware`, 90 j), `FactionBannedRule.exempt_posts` |
| B22 | `RuleContext` de shift | `quota_used`, `quota_max`, `presented_at_minute`, `revoked_ids`, `vessel_registry` ; le verdict attendu reste calculé par le moteur (D-005) mais **dépend du contexte du jour** : à documenter dans ARCHITECTURE |
| B23 | Verdict « souple » (R23) | quota atteint + passager en règle : DENY correct (documenté d'office) **et** APPROVE correct imputé (0 ₵, `quota_overrun +1`, `suspicion +1` tous les 3, `overrun_yesterday` pour le briefing) |
| B24 | `DayDef.luciole_trust_on_breach` | faux à l'Acte II (QA §9) |
| B25 | `ScriptedCaseDef` | `condition: FlagCondition` (remplace/complète `requires_flag`/`forbids_flags`) ; **plusieurs définitions au même index**, la première satisfaite gagne (SC-35, SC-50) ; `fixed_appearance_seed` (Okonkwo, Ilan) ; répliques conditionnelles `ConditionalKey` sur `_arrival`/`_confront`/autres ; `injection_params.injected_value` (SC-38) et facultatif `injected_value_from_case` (SC-31/32) ; document de tiers `third_party` exclu de R07 (SC-27) ; figurant de file (Joaquín, Kwame) |
| B26 | `CaseEffectDef.context` | conditions de contexte : `quota_reached`, `after_curfew`, `briefing_shown:<clé>` (SC-25, SC-37, SC-39) ; condition multi-cas (`kerr_all_correct`) |
| B27 | Objets glissés | nouveaux libellés `FORMULAIRE`, `OBJET`, `DOSSIER` (même mécanique que `NOTE`) ; effets sur les jauges `registre`, `solidarite`, `suspicion` négative ; prime de remise (SC-45) |
| B28 | Avis de recherche « visages seuls » | `WantedNoticeDef` sans nom (J20), entrées conditionnelles (Okonkwo J14 si `okonkwo_warned`, Kasimir J20 si non détenu) |
| B29 | Briefings | locuteurs `spk_commission`, `spk_sato`, `spk_sato_former`, `spk_brulants` ; voix `COMMISSION` ; condition « drapeau posé hier » (`overrun_yesterday`) ; Dora dans l'emplacement foyer |
| B30 | Soirées | gains/coûts **récurrents** (salaire d'Ilan, location ACV-2, forfait non-compteur) ; montant **calculé** (prélèvement %) ; événement **répétable** jusqu'à résolution (caution J12/J14/J16) ; `AUDIT` paramétrable (Revue : formule et seuils propres) ; option `ends_campaign` (F6 au J10) ; effet « fixer une jauge » (`registre := 0`) ; effets foyer : `ABSENT` avec motif, retour `MALADE`, `MIS·E EN ATTENTE` ↔ libéré·e ; 3 panneaux par soir |
| B31 | Pivot du J10 | séquence §1.2 : division de la suspicion, conversion des anciennes conditions F4/F5/F7/F1-double en drapeaux, interstitiel « Acte II » |
| B32 | Foyer | rations par proche (lignes cochables) ; état `ESSOUFFLÉ·E` (transitions = `FROID`) ; état `ABSENT` (vivant, aucune dépense, pas de dégradation) avec motif ; `MIS·E EN ATTENTE` **distinct de `PERDU`** (vivant, libérable) ; `present_count()` à côté de `alive_count()` ; oxygène gratuit (`promotion_offered`) |
| B33 | Économie (`EconomyDef`) | `ration_self/ilan/noa/dora`, `meter_fee`, `meter_surcharge`, `levy_rate`, `levy_floor`, `levy_days`, `food_raised` + jour, `oxygen_raised` + jour, `medicine_raised` + jour, `lease_cost`, `review_arrest_score = 5`, `review_demote_score = 3`, `review_retention = 40`, `bail = 60`, `dora_ticket = 40`, `drift2_cost = 60`, `ilan_job_income = 8`, seuils de fin (§1.3) |
| B34 | `EndingService` | J10 non terminal (sauf F6 choisie, F1 J9, F2/F3) ; J20 : F1 > F3 > F2 > F5 > F9 > F8 > F6 > F4 > F7 ; Revue J17 (F1 anticipée) ; épilogues `end2_*` |
| B35 | Événements de shift | annonce **à heure fixe** (16:00, J16) ; annonce conditionnelle après le cas n (J20 registre) ; **fin anticipée du shift** après le cas n si `strike_joined` (J20) |

### 8.2 Interactions et écrans (UI/UX + Design System)

| # | Besoin | Détail |
|---|---|---|
| I11 | Compteur QUOTA | barre d'état, `QUOTA 3/5` → `QUOTA ATTEINT` (ambre) ; cible de Mode Inspection (paire Compteur ↔ R23) ; ligne « Entrées imputées » au bilan |
| I12 | Ticket de file | petit document générique posé avec les papiers (J16+), un champ comparable `Présentation` |
| I13 | Scanner partiel | liens suggérés en pointillé magenta (UI_FLOW §5.3), confirmés au clic ; pastille ACV-2 (jaune) ou luciole (magenta) |
| I14 | Onglets Rulebook | Codes employeurs, Registre des cargos (avec la ligne « retirés »), Révocations ; ligne firmware dans Implants ; avis « visages seuls » |
| I15 | Écran Foyer | 3 rations cochables + ration prélevée ; états `ESSOUFFLÉ·E`, `DANS LA SOUTE`, `PARTIE À TYCHO` ; revenus récurrents |
| I16 | Écran Soirée | 3 panneaux, montants calculés (`%d`), option qui termine la partie (confirmation « Embarquer ? »), événement répétable |
| I17 | Interstitiel « ACTE II » | après la soirée du J10, avec la sauvegarde |
| I18 | Écran de fin | 9 fins ; surtitres F8, F9 |
| I19 | Lampes qui s'éteignent | J20, grève : toutes les vitres du Hall s'éteignent avant le bilan (3D + audio) |

### 8.3 Assets (3D Designer / Audio)

Accessoires : caisse de transport avec chat (SC-27), drone de la Commissaire (SC-42), enfant figurant (Joaquín ; Kwame existe déjà), écrou en pendentif (objet 2D), LED de shunt clignotante (SC-34), carré `DER-19` (existant SC-14), brassard jaune (2D, soirée). Visages fixés : Okonkwo, Ilan. Trois Ren Kerr visiblement différents. Audio : carillon de quota atteint, annonce de 16:00, voix de synthèse qui lit les noms (registre), extinction des lampes (grève), ronronnement du boîtier magenta.

### 8.4 Tests prioritaires (QA)

Expiration le jour même = CONCORDANT (SC-48) ; document de tiers ignoré par R07 (SC-27) ; exemptions du quota (`HAL`, DIPLOMATIQUE) ; verdict souple (les deux tampons corrects, salaire 0 imputé) ; couvre-feu selon l'heure de présentation et non l'heure du tampon ; variantes multiples au même index ; « visages seuls » sans faux positif (D-056) ; Revue ; priorités de fin sur des historiques synthétiques ; migration v3 → v4.

### 8.5 Noms réservés (D-067)

Noms de famille distinctifs ajoutés : **Lindgren**, **Beaumont**, **Oyelaran-Holm**, **Lindqvist-Rey**. Noms complets réservés : Aurelio Sato, Emeka Okonkwo, Elena Navarro, Margaux Ferreira, Tariq Benali, Katya Mazur, Ren Kerr, Corvo Sillage, Hiro Langlois, Leila Haddad, Valentin Choi, Mateus Silva, Paz Vela, Bilal Tembo. Vaisseau « Sillage » : retiré du tirage des noms `DRV` à partir du J13.

### 8.6 Sauvegarde v4 et migration

État nouveau : rations payées par proche, états `ESSOUFFLÉ·E` et `ABSENT` (+ motif) **ajoutés en fin d'enum** du foyer, `MIS·E EN ATTENTE` séparé de `PERDU`, revenus/coûts récurrents (drapeaux suffisent), jauges `solidarite`, `registre`, `quota_overrun` (dictionnaire de flags existant, sans changement de schéma), `CaseMemory` des cas de l'Acte II (SC-23, SC-25, SC-38, SC-50 réutilisés).

Migration **v3 → v4** : une sauvegarde v3 date au plus du soir du J9 (pas de soirée au J10 en v3) ; on ajoute les champs par défaut (rations « payées », motifs vides), on **convertit** un Ilan `PERDU` porteur de `ilan_denounced` en `MIS·E EN ATTENTE` (vivant), et on incrémente la version. Une partie v3 terminée n'a plus de sauvegarde (D-041) : rien d'autre à migrer.

---

## 9. Questions ouvertes au client

1. **Structure du J10.** **A** — Le J10 devient un pivot obligatoire (soirée « Nuit des vannes », seule F6 peut finir la partie par choix) ; **B** — Au soir du J10, le joueur choisit « Terminer ici » (épilogues de l'Acte I conservés) ou « Continuer ». *Recommandation : A.* Une seule campagne de 20 jours, des choix du J10 qui changent le monde ; B oblige à maintenir deux jeux de fins et affaiblit l'enjeu de l'Acte II. B reste peu coûteux si la démo publique doit garder une fin au J10.
2. **Quota respiratoire.** **A** — Souple : au-delà du quota, refuser et approuver sont tous deux corrects, l'approbation est imputée (0 ₵, suspicion tous les 3) ; **B** — Strict : au-delà du quota, approuver = citation ENTRÉE IRRÉGULIÈRE. *Recommandation : A.* Le dilemme « 5 ₵ contre une personne » est plus *Papers, Please* qu'une règle de plus, et préserve mieux D-005 (pas de mauvais verdict « dépendant de l'ordre de la file »).
3. **Figure finale du J20.** **A** — Ilan à la vitre si Ilan a rejoint la Soute au J16, sinon Mira ; **B** — Toujours Mira (Ilan reste hors champ). *Recommandation : A.* Le face-à-face le plus fort de la campagne ; coûte un visage fixé et une variante de dialogue.
4. **Nouvelles fins.** **A** — F8 « Le Registre » **et** F9 « Les vitres éteintes » ; **B** — Une seule (F9), le registre devenant une ligne d'épilogue. *Recommandation : A.* Deux voies non violentes distinctes (vérité, collectif) ; coût contenu (2 jauges, 2 épilogues). Albédo reste ambigu dans les deux cas (D-053).
5. **Prélèvements sur l'épargne.** **A** — Deux prélèvements de 30 % au-delà de 40 ₵ (J11, J17) pour garder la pression sur les bons joueurs ; **B** — Aucun prélèvement, la pression vient seulement des dépenses datées. *Recommandation : A*, à confirmer par simulation : sans eux, un joueur à 95 % finit l'Acte II avec plus de 500 ₵ et le foyer n'est plus un enjeu.
