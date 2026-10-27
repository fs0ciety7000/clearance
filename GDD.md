# CLEARANCE — Game Design Document

> Auteur : Game Designer · Statut : v0.2 (proposition, à valider par l'Orchestrateur puis le client) · Date : 2026-10-27
> Sources faisant foi : `DECISIONS.md` (D-001 → D-024, toutes 🟢), `LORE.md` (noms, codes, origines, Lucioles, implants, documents, calendrier), `docs/UI_FLOW.md`, `docs/ARCHITECTURE.md` (§5 modèle de données, §6 règles, §9 génération).
>
> Toutes les valeurs chiffrées sont des **valeurs de départ** destinées à remplir directement les `DayDef` / `RuleSet` `.tres` (§10). Elles seront réajustées après playtest (§14). Le barème de dépenses du Lore (§11 de `LORE.md`) est indicatif ; l'équilibrage ci-dessous fait référence. 🟡 = élément **proposé** ici qui touche un autre propriétaire (enum, champ de `DayDef`, écran) et demande son accord.

---

## 1. Vision & piliers

**Pitch.** Mardi 13 mars 2187. Vous prenez votre poste au **Guichet 04** du Hall des Guichets de **Halcyon Gate**, seul passage vers les Anneaux habitables, pour l'**Autorité de Transit** du **Consortium**. Chaque passager arrive derrière la vitre, glisse ses papiers par la fente et attend votre tampon. Votre salaire nourrit et chauffe Ilan, Noa et Dora dans une cabine de 9 m² du Bloc Pétrel. Chaque jour, le Bureau de Continuité publie de nouvelles règles ; chaque passager porte un visage, des papiers, des implants, et parfois un mensonge — ou une luciole.

| # | Pilier | Ce que ça veut dire en jeu | Garde-fou de design |
|---|---|---|---|
| P1 | **Enquêter, pas deviner** | Le joueur *trouve* la discordance en comparant deux champs (Mode Inspection A ↔ B, D-006), y compris le **visage du passager** ↔ la photo (D-012/D-018). Une discordance documentée est la seule preuve. | L'outil ne ment jamais (zéro faux positif) ; il ne dit jamais « illégal ». Refuser sans preuve est sanctionné (D-024). |
| P2 | **La pression du guichet** | L'horloge du shift tourne en continu, y compris pendant la marche du passager (D-019). La file ne se vide jamais tout à fait. | Pas de timer par passager ; la pression vient du nombre de cas et des factures du soir. |
| P3 | **Le prix humain de la règle** | Salaire ↔ famille ↔ conscience. Pots-de-vin, Lucioles, familles séparées, détentions : chaque choix a un coût visible le soir même. | Le jeu ne juge pas ; les conséquences sont narratives et économiques, jamais un « mauvais choix » affiché comme tel. |
| P4 | **Présence physique** | Un passager 3D unique (apparence modulaire), qui marche, attend, regarde, se découvre (visière), réagit derrière la vitre. | Les réactions informent sur l'émotion, jamais sur la vérité (UI_FLOW §4.7). |

---

## 2. Public & références

- **Public cible** : joueurs PC et **Steam Deck** (D-023), 16+, amateurs de déduction et de narration systémique ; sessions de 10–15 min (un shift + soirée), campagne de **≈ 3,5–4 h** (10 jours + épilogue).
- **Références de gameplay** : *Papers, Please* (boucle, règles cumulatives, économie familiale, citations), *Return of the Obra Dinn* (déduction par la preuve), *Beholder* (dilemmes de surveillance), *Not Tonight* (contrôle d'identité sous pression), *Contraband Police* (inspection physique).
- **Références esthétiques / ton** : *Blade Runner*, *Ghost in the Shell* (1995), *Deus Ex: Human Revolution* (implants, classes sociales) ; cyberpunk stylisé et lisible (`DESIGN_SYSTEM.md`).
- **Ce que CLEARANCE ajoute** : le **visage comme pièce du dossier** (sosies, papiers d'un parent, visière, implants visibles), un **Mode Inspection** qui inclut le Rulebook et le passager 3D, la **preuve obligatoire** pour refuser, et des **codes Lucioles** que le joueur peut apprendre à lire mieux que le Consortium.

---

## 3. Boucle de jeu

### 3.1 Micro — un cas (cible : 35–60 s réelles, cf. §14)

```
« Suivant » ──► ARRIVING (marche ≤ 3–4 s, horloge tourne : lire le Rulebook)
            ──► PRESENTING (~1,2 s, « Tal ka nesu. » — documents par la fente)
            ──► INSPECTING : lire → comparer (A ↔ B) → [interroger] → [faire retirer la visière]
            ──► VERDICT : APPROUVÉ / REFUSÉ / DÉTENTION (J7+)
            ──► DEPARTING (~2 s) ──► avis d'infraction éventuel
```

Décisions du joueur pendant un cas : quoi comparer en premier (priorisation sous la pression du temps), quand arrêter de chercher, interroger ou non, accepter un pot-de-vin, reconnaître (ou non) un code Luciole, appliquer la règle ou sa conscience.

### 3.2 Méso — un jour

```
Briefing (bulletin du Bureau de Continuité, règles NOUVEAU, message perso) ─► Shift (8 h in-game = duration_sec réelles)
─► Sirène, dernier passager terminé ─► Bilan (traités, corrects, citations, amendes, pots-de-vin)
─► Soirée au Bloc Pétrel : dépenses cochables ─► État du foyer (Ilan, Noa, Dora)
─► Événements narratifs (messages, Lucioles) ─► Sauvegarde auto ─► jour suivant
```

Shift de **10:00 à 18:00** in-game (barre d'état, UI_FLOW §2). Calendrier (`GameDate`, grégorien) : **J1 = mardi 13.03.2187** … **J7 = lundi 19.03.2187** … **J10 = jeudi 22.03.2187**.

### 3.3 Macro — campagne

- **10 jours** jouables + épilogue. Une nouvelle couche de règles quasiment chaque jour (§8), deux jours de « respiration » (J4, J9).
- **Justification diégétique de la progression** : en 2187, permis et bio-scan sont obligatoires depuis des années (LORE §2), mais le Guichet 04 rouvre avec un·e agent·e novice : l'Autorité de Transit lui **délègue progressivement** les contrôles jusque-là faits aux quais (permis au J3, bio-scan au J5 quand le poste Meridian des quais ferme, implants au J6…).
- Trois jauges cachées pilotent les fins (§11) : **Loyauté** (`flag loyalty`), **Confiance des Lucioles** (`flag lucioles_trust`), **Suspicion** (`flag suspicion`, pots-de-vin et irrégularités repérées par les Inspecteurs). Deux états visibles : **crédits** et **foyer**.
- Fins anticipées possibles (réaffectation, arrestation, famille perdue) dès le J3.

---

## 4. Mécaniques détaillées

### 4.1 Inspection (Mode Inspection A ↔ B, D-006)

Bascule Espace / LT ; champ A puis champ B (document, Rulebook, date du jour, **Visage** du passager). Résultat en ~250 ms (400 ms pour le visage) : **CONCORDANT**, **DISCORDANCE** (épinglée jusqu'au verdict) ou **INCOMPARABLE** (aucune pénalité).

Paires valides (à refléter dans `FieldDef.comparable` / `DiscrepancyChecker`) :

| Champ A | Champ B | Discordance si… | Anomalies révélées |
|---|---|---|---|
| Date d'expiration (tout document) | Date du jour (Rulebook) | expiration < aujourd'hui | `EXPIRED_DOCUMENT` |
| Même `truth_path` sur 2 documents (nom, n° ID, naissance) | idem | valeurs ≠ | `NAME_MISMATCH`, `ID_MISMATCH` |
| N° ID (premier chiffre du bloc) | Origine (code 3 lettres) / onglet **Origines** du Rulebook | chiffre ≠ origine (HAL 1, TER 2, TYC 4, CER 6, THR 7, DRV 9) | `ORIGIN_ID_MISMATCH` 🟡 |
| Bande MRZ (carte) | Nom / N° ID / Origine (carte) | recopie fausse — **les 2 derniers chiffres (guichet émetteur) ne sont jamais comparés** | `MRZ_MISMATCH` 🟡 |
| **Visage** (`FieldRef.PASSENGER_FACE`) | Photo d'un document | ≥ 1 trait d'identité visible différent | `PORTRAIT_MISMATCH`, `IMPOSTOR_LOOKALIKE`, `RELATIVE_DOCUMENTS` |
| Visage | Date de naissance | âge apparent hors tranche (`age_band` ±1 toléré) | `RELATIVE_DOCUMENTS` |
| Visage | « Implants déclarés » (carte d'identité) | implant visible non déclaré (ou déclaré mais absent) | `UNDECLARED_IMPLANT` 🟡 |
| Champ (origine, classe, motif, durée, employeur, émetteur, sceau, statut, implants) | Règle du Rulebook | valeur interdite par la règle | `BANNED_FACTION`, `PURPOSE_MISMATCH`, `WRONG_ISSUER`, `INVALID_SEAL`, `BIOSCAN_UNFIT` 🟡, `BANNED_IMPLANT` 🟡 |
| Règle « Documents requis : X » | Dossier du passager (n'importe quel document posé) | X absent du plan de travail | `MISSING_DOCUMENT` — « ⚠ DOCUMENT MANQUANT : Permis d'entrée » 🟡 (UI/UX) |
| Photo | Photo (2 documents) | ≥ 1 trait différent | idem visage |
| Visage / Nom | Avis de recherche du jour (Rulebook, J10) | correspondance | `WANTED_PERSON` 🟡 |
| Marque « luciole » (coin du document, visible au zoom) | Bulletin « Symboles subversifs » (Rulebook, J7+) | correspondance | aucune anomalie — **signalement** (§4.7) |

- **Bruit légitime** (jamais une discordance) : photo plus ancienne (`years_before_issue` 1–8 ans), coiffure / barbe / couvre-chef différents, `age_band` ±1, nom composé tycho abrégé sur un document secondaire (« Vasquez-O. ») si une règle le tolère, date de naissance « 00.00.AAAA » des Dérivants (tolérée par règle, LORE §5.6). Taux de cas avec bruit visible : J1 10 % → J10 35 % (§8.3). C'est ce bruit qui empêche « différence visible = refus ».

### 4.2 Discordances et preuve

- Une discordance confirmée est **épinglée** (max 4 visibles) et **débloque une question** d'interrogatoire.
- **Documentation d'un refus** (D-024) : un REFUS ou une DÉTENTION est « documenté » si, au moment du tampon, **au moins une discordance confirmée** épinglée recoupe une violation attendue (`Discrepancy.a/b` ∩ `Violation.refs` ≠ ∅), **ou** si l'interrogatoire a établi le motif (refus de retirer la visière, aveu « je n'ai pas de permis »).
- Le système ne donne **jamais** de faux positif : l'ambiguïté vient des règles, du bruit légitime et du récit.

### 4.3 Interrogatoire

- Ouverture : Q / Ⓨ ou clic sur le passager. Chaque question consomme **3–5 s réelles** (voix en Tessar sous-titrée, D-020) — l'horloge tourne.
- **Questions de base** (toujours disponibles) : « Motif de votre visite ? », « Durée du séjour ? », « D'où venez-vous ? », « Retirez votre visière. » (seulement si visière baissée, §4.4).
- **Questions débloquées** (une par discordance) : « Votre permis a expiré. », « Ce n'est pas vous sur cette photo. », « Le numéro ne correspond pas. », « Où est votre [document] ? », « Cet implant n'est pas déclaré. »…
- Réponses (`dialogue_tags`) : **explication** (bruit légitime : « vieille photo »), **aveu** (vaut documentation), **supplication** (« *Ravel ka ota.* » — ma famille m'attend), **pot-de-vin** (J4+), **colère** (ANGRY), **code Luciole** (« Il pleut, même ici. », *lumika*). Question répétée → ANGRY ; question sans rapport → SHRUG.
- **Interrogatoire obligatoire des ressortissants TYC** (règle R08, J4+, LORE §2) : tamponner un passager `TYC` sans avoir posé au moins une question = citation **INTERROGATOIRE OMIS**.
- Les réactions (NERVOUS, ANGRY, SHRUG, RELIEVED) ne prouvent rien : un innocent peut être nerveux.

### 4.4 Visière (D-021)

- Certains passagers arrivent **visière baissée** (slot `headwear` = option couvrante). En Mode Inspection, le champ Visage affiche « VISAGE MASQUÉ » ; toute comparaison avec lui renvoie **INCOMPARABLE — demandez le retrait de la visière (Q)**.
- Question « Retirez votre visière, s'il vous plaît. » → clip `remove_visor` (~2 s) ; le visage devient comparable.
- **Refus de se découvrir** (J7+, 10 % des passagers masqués, plus cas scénarisés) : « *Nai.* » + ANGRY. Le refus vaut **documentation** d'un REFUS (règle R06).
- **Procédure** (J3+, règle R06 « Visage découvert ») : APPROUVER un passager encore masqué = citation **VISAGE NON CONTRÔLÉ**, même si ses papiers sont valides.
- **Taux** (`DayDef.visor_down_rate` 🟡) : J3–J6 **0,15**, J7–J10 **0,20**. Multiplicateur ×1,5 si le cas porte une anomalie de visage (plafond 0,40) : signal statistique léger, jamais une preuve — la majorité des passagers masqués restent innocents.

### 4.5 Verdicts

| Tampon | Disponible | Bonne réponse quand… | Sortie du passager |
|---|---|---|---|
| **APPROUVÉ** (vert, cercle) | J1 | aucune violation (`expected_verdict = APPROVE`) | vers les Anneaux |
| **REFUSÉ** (rouge, octogone) | J1 | ≥ 1 violation | demi-tour vers la file |
| **DÉTENTION** (« mise en attente », J7+) | J7 (`VerdictKind.DETAIN`, prévu extensible dans ARCHITECTURE) | violation **identité frauduleuse** (`IMPOSTOR_LOOKALIKE`, `RELATIVE_DOCUMENTS` J8+, `WANTED_PERSON` J10) ou implant `MIL-` **non déclaré** | escorté par la **Garde de Continuité** vers l'Anneau B ; ne revient pas dans la file |

- Calcul proposé (`RuleEngine`) : `expected_verdict = DETAIN` si une violation provient d'une règle `severity ≥ 3` ; sinon `DENY` si ≥ 1 violation ; sinon `APPROVE`.
- Maintien 0,4 s sur chaque tampon (anti-erreur, UI_FLOW §3.5).

### 4.6 Citations

Au plus **une citation par cas** (la plus grave). Les deux premières de la journée sont des **avertissements** ; ensuite des amendes (§5.2).

| Code (`reason_key`) | Déclencheur | Gravité |
|---|---|---|
| `cit_irregular_entry` — ENTRÉE IRRÉGULIÈRE | APPROUVÉ alors qu'une violation existait | 3 |
| `cit_unjustified_denial` — REFUS INJUSTIFIÉ | REFUSÉ/DÉTENTION d'un passager en règle (hors signalement Luciole valide, §4.7) | 3 |
| `cit_undocumented_denial` — REFUS NON MOTIVÉ | REFUSÉ correct mais sans discordance documentée (§4.2, D-024) | 2 |
| `cit_face_unchecked` — VISAGE NON CONTRÔLÉ | APPROUVÉ avec visière baissée (J3+) | 2 |
| `cit_interview_skipped` — INTERROGATOIRE OMIS | tampon sur un `TYC` sans question (J4+) | 1 |
| `cit_abusive_detention` — DÉTENTION ABUSIVE | DÉTENTION quand seul un REFUS était attendu | 2 |
| `cit_undocumented_detention` — PROCÉDURE DE DÉTENTION | DÉTENTION attendue mais non documentée | 2 |

Un REFUSÉ documenté là où une DÉTENTION était attendue n'est **pas** une citation : le cas est correct, sans prime de détention (§5.1).

### 4.7 Les Lucioles au guichet

Les 7 codes de reconnaissance (LORE §7) **ne sont pas des discordances** : un passager Luciole peut avoir des papiers parfaitement en règle.

| Code | Où le joueur le voit | Introduit | Connu du Consortium ? |
|---|---|---|---|
| 1. Dessin de luciole au coin d'un document | zoom Inspection | J3 (SC-05) | **Oui à partir du J7** (bulletin « Symboles subversifs ») |
| 2. MRZ terminée par `07` au lieu de `04` | bande MRZ | J5 | non |
| 3. Permis terminé par 7 + motif « VISITE FAMILIALE » | Permis d'entrée | J5 | non |
| 4. Phrase de passe « Il pleut, même ici. » | dialogue | J7 (réponse « La pluie ne tombe que vers le bas. » débloquée si `lucioles_trust ≥ 2`) | non |
| 5. Trois tapes sur la vitre | animation avant `present_documents` | J4 | non |
| 6. Bracelet de fil magenta | accessoire 3D (poignet) | J6 | non |
| 7. Mot *lumika* dans un bark (« [mot inconnu] ») | sous-titre | J3 | non |

- **Aider** : approuver un Luciole en règle ne coûte rien ; approuver un Luciole en infraction = citation, `lucioles_trust +1`.
- **Ignorer** : traiter selon les règles.
- **Dénoncer** (J7+) : DÉTENTION d'un passager portant le **code 1**, documentée par la paire « marque luciole ↔ bulletin » = signalement valide : pas de citation, prime de 5 ₵, `loyalty +1`, `lucioles_trust −2`. Les codes 2–7 ne sont pas connus du Consortium : détenir sur cette seule base = DÉTENTION ABUSIVE. *Le joueur qui apprend les codes en sait plus que le Consortium : c'est voulu.*
- Avant le J7, un bouton **« Signaler »** sur les messages Lucioles reçus (soirée) permet aussi la dénonciation : `loyalty +1`, `lucioles_trust −2`, prime 10 ₵.

---

## 5. Scoring & économie

### 5.1 Gains par cas (`ScoringService` → `CaseResult.credits_delta`)

| Situation | `correct` | Crédits | Citation |
|---|---|---|---|
| APPROUVÉ correct | ✓ | **+5 ₵** (`credit_per_correct`) | — |
| REFUSÉ correct **documenté** | ✓ | **+5 ₵** | — |
| REFUSÉ correct **non documenté** | ✗ (procédure) | **0 ₵** | REFUS NON MOTIVÉ |
| DÉTENTION correcte documentée (ou signalement Luciole valide) | ✓ | **+5 ₵ + 5 ₵ prime de détention** | — |
| REFUSÉ documenté au lieu de DÉTENTION | ✓ | +5 ₵ (pas de prime) | — |
| DÉTENTION au lieu de REFUS | ✗ | 0 ₵ | DÉTENTION ABUSIVE |
| Erreur de verdict (approuver un fraudeur, refuser un innocent) | ✗ | 0 ₵ | ENTRÉE IRRÉGULIÈRE / REFUS INJUSTIFIÉ |
| Verdict correct mais procédure manquée (visière, interrogatoire TYC) | ✗ (procédure) | 0 ₵ | VISAGE NON CONTRÔLÉ / INTERROGATOIRE OMIS |
| Passagers non traités en fin de shift | — | 0 ₵ | — (manque à gagner) |

`score_total` (GameState) = crédits gagnés par le travail (hors pots-de-vin et primes de signalement). **Indice de conformité** = cas corrects / cas traités, cumulé : utilisé par les fins (§11).

### 5.2 Citations & amendes (fin de shift)

| Citation du jour n° | Effet |
|---|---|
| 1 et 2 | **Avertissement** (0 ₵) — avis imprimé, rappel de la règle |
| 3 | **−5 ₵** |
| 4 et suivantes | **−10 ₵** chacune |

Valeurs : `penalty_per_error = 5` (3ᵉ citation) ; `free_citations_per_day = 2` et `penalty_escalated = 10` 🟡 (champs `DayDef` ou constantes `ScoringService`). Le solde peut devenir négatif (dette, §5.4). Le Lore proposait −5 ₵ fixe à partir de la 3ᵉ : l'escalade à −10 ₵ est retenue pour qu'une journée bâclée coûte réellement.

### 5.3 Dépenses du soir (écran Foyer)

Solde de départ : **0 ₵**. Chaque poste est cochable, sauf la taxe d'air ; ce qui n'est pas payé a une conséquence (§5.4).

| Poste | Coût | Fréquence | Notes |
|---|---|---|---|
| **Loyer** (cabine du Bloc Pétrel) | **15 ₵** | chaque soir | **20 ₵** à partir du J8 (« ajustement sectoriel ») |
| **Taxe d'air** (quota respiratoire du foyer) | **5 ₵** | chaque soir | **prélevée d'office** (non cochable) ; peut creuser la dette |
| **Nourriture** | **10 ₵** | chaque soir | nourrit tout le foyer |
| **Chauffage** | **8 ₵** | chaque soir | Noa tousse quand il est coupé |
| **Oxygène d'appoint de Dora** | **10 ₵** | soirs pairs (J2, J4, J6, J8, J10) | non payé → Dora `MALADE` le lendemain |
| **Médicaments** | **15 ₵ par proche malade** | si quelqu'un est `MALADE` / `GRAVEMENT MALADE` | Clinique Orbitale Meridian |
| **Bio-scan de Noa** | **25 ₵** | J6 (événement) | suspicion de Fièvre grise ; non payé → Noa `MALADE`, puis l'événement revient au J8 |
| Extras narratifs | 5–40 ₵ | ponctuels | cadeau, faux laissez-passer de dérive (Lucioles, J9 : 40 ₵)… |

Base quotidienne : **38 ₵** (loyer + taxe + nourriture + chauffage) ; 48 ₵ les soirs pairs. Revenus : J1 max 40 ₵ (8 × 5), médiane ~30–35 ₵ → la plupart des joueurs ne peuvent pas payer le chauffage le premier soir (amorce dramatique, UI_FLOW §7). J10 : max 80 ₵, médiane ~60–65 ₵, coûts 43–58 ₵ + soins. **Intention** : un joueur moyen sacrifie un poste **1 soir sur 3** ; un joueur parfait et intègre survit juste ; les pots-de-vin rendent la vie confortable mais font monter la Suspicion.

### 5.4 Foyer : états et conséquences

Foyer (LORE §11, à confirmer par le Scénariste) : **Ilan** (conjoint·e, technicien·ne de recycleur réaffecté·e — porte l'arc Lucioles), **Noa** (8 ans — porte l'arc santé / chauffage), **Dora** (mère d'Ilan, ancienne mineuse de Tycho, sous oxygène — la plus fragile, alerte précoce).

États par proche : `BIEN` → `AFFAMÉ` / `FROID` → `MALADE` → `GRAVEMENT MALADE` → `PERDU`.

| Cause | Effet |
|---|---|
| 1 soir sans nourriture | tous `AFFAMÉ` |
| 2 soirs consécutifs sans nourriture | chaque proche `AFFAMÉ` → `MALADE` |
| 1 soir sans chauffage | tous `FROID` ; Noa `MALADE` à 50 % |
| 2 soirs consécutifs sans chauffage | chaque proche `FROID` → `MALADE` |
| Oxygène de Dora non payé | Dora `MALADE` ; 2ᵉ manquement → `GRAVEMENT MALADE` |
| `MALADE` sans médicaments 2 soirs | → `GRAVEMENT MALADE` |
| `GRAVEMENT MALADE` sans médicaments 2 soirs | → `PERDU` |
| Médicaments payés | `MALADE` → `BIEN` le lendemain ; `GRAVEMENT MALADE` → `MALADE` |
| Loyer impayé | dette ; **2 loyers impayés consécutifs → « réaffectation »** (expulsion, fin F2) |
| Solde < 0 trois soirs consécutifs | réaffectation (licenciement, fin F2) |

### 5.5 Pots-de-vin (J4+)

- Le passager glisse une **enveloppe de crédits** avec ses documents. La garder (la glisser dans le tiroir) = **+10 / +20 ₵** (J4–J6), **+20 / +30 ₵** (J7–J9), jusqu'à **+50 ₵** (cas scénarisé J10). La rendre = rien.
- Le pot-de-vin ne change pas la vérité : approuver un fraudeur reste une ENTRÉE IRRÉGULIÈRE.
- Chaque enveloppe gardée : **Suspicion +1**. Audit des **Inspecteurs** au **J9** : Suspicion ≥ 4 → arrestation (fin F1) ; 2–3 → retenue de 30 ₵ et `loyalty −1`.
- Fréquence : ~1 offre par jour à partir du J4 (cas scénarisés + `bribe_rate` sur les cas avec anomalie). Profils typiques (LORE) : Nés-Halcyon `C-1` arrogants, Ceinturiers contrebandiers.

---

## 6. Catalogue des anomalies

Noms alignés sur `AnomalyType` (ARCHITECTURE §5.3) ; 🟡 = type proposé à ajouter (revue Godot Architect).

| Type | Ce que fait l'injecteur (résumé) | Comment le joueur la détecte | Règle | Jour |
|---|---|---|---|---|
| `EXPIRED_DOCUMENT` | `expiry_date` = aujourd'hui − 1…30 j (J1–J3 : 1–10 j, pathos du « presque valide ») | Expiration ↔ date du jour | R02, R05, R12 | J1 |
| `MISSING_DOCUMENT` | retire un document requis | Règle « Documents requis » ↔ dossier ; question « Où est votre… ? » | R01, R04, R11 | J1 |
| `PORTRAIT_MISMATCH` | photo d'une autre personne (≥ 3 traits d'identité) | Visage ↔ Photo | R03 | J2 |
| `ID_MISMATCH` | 1–2 caractères du n° ID altérés sur un document (en évitant `O I 0 1`, LORE §5) | N° ID carte ↔ N° ID permis | R07 | J3 |
| `NAME_MISMATCH` | nom ou date de naissance altéré (1 lettre, partie d'un nom composé, inversion jour/mois) | Nom ↔ Nom, Naissance ↔ Naissance | R07 | J3 |
| *(visière baissée)* | **pas une anomalie** : état de présentation (`visor_down_rate`) | Visage « MASQUÉ » → question de retrait | R06 (procédure) | J3 |
| `ORIGIN_ID_MISMATCH` 🟡 | premier chiffre du bloc ID ≠ code d'origine (« ID d'origine falsifiée ») | N° ID ↔ Origine + onglet Origines | R10 | J4 |
| `PURPOSE_MISMATCH` | motif oral ≠ motif du permis ; durée > validité ; `C-4` avec permis > 30 j ; motif TRAVAIL « SANS EMPLOYEUR » | Question « Motif ? » ↔ champ Motif ; Classe ↔ durée ; Employeur ↔ règle | R09 | J4 |
| `WRONG_ISSUER` | certificat d'une clinique inexistante (« Clinique Meridiane ») ou centre non agréé | Émetteur ↔ règle | R13 | J5 |
| `BIOSCAN_UNFIT` 🟡 | statut ≠ SAIN (QUARANTAINE, À REVOIR) | Statut ↔ règle | R14 | J5 |
| `UNDECLARED_IMPLANT` 🟡 | implant visible sur le modèle 3D (OPT, NX, MIL, KIN, DER) absent de « Implants déclarés » | Visage ↔ Implants déclarés | R15 (DÉTENTION si `MIL-`, J7+) | J6 |
| `BANNED_IMPLANT` 🟡 | implant `MIL-` déclaré sans dérogation, ou `DER-19` | Implants déclarés ↔ règle | R16 | J6 |
| `IMPOSTOR_LOOKALIKE` | photo dérivée du passager, **1–2** traits d'identité modifiés ; vise surtout des identités `HAL` (valeur élevée) | Visage ↔ Photo (traits nommés en magenta) | R03 + R17 → **DÉTENTION** | J7 |
| `RELATIVE_DOCUMENTS` | papiers d'un parent (souvent décédé, profil `TER`) : même nom de famille, photo « air de famille », `age_band` ±2 | Visage ↔ Photo ; Visage ↔ Date de naissance | R03 + R18 → **DÉTENTION** | J8 |
| `BANNED_FACTION` | faction vraie = origine interdite du jour (`THR` sauf motif DIPLOMATIQUE), cohérente sur tous les documents | Origine ↔ règle ; Motif ↔ règle | R19 | J8 |
| `INVALID_SEAL` | sceau d'un ancien modèle ou mauvais sceau (hexagone solaire, anneau barré, croix en orbite) | Sceau ↔ onglet Sceaux | R20 | J9 |
| `MRZ_MISMATCH` 🟡 | la MRZ ne recopie pas le nom / n° / origine (jamais sur les 2 derniers chiffres) | MRZ ↔ champs de la carte | R21 | J9 |
| `WANTED_PERSON` 🟡 | le passager figure sur l'avis de recherche du jour (nom **ou** visage), papiers sinon valides | Nom / Visage ↔ avis | R22 → **DÉTENTION** | J10 |

Règles d'injection : jamais deux anomalies sur le même champ ; anomalies de visage mutuellement exclusives ; `BANNED_FACTION` et `WANTED_PERSON` combinées avec 0–1 autre anomalie au plus (lisibilité) ; un code Luciole n'est jamais injecté comme anomalie (c'est un `dialogue_tag` / un trait d'apparence).

---

## 7. Rulebook : règles et documents

Documents (ids proposés) : `doc_id_card` (**Carte d'identité**, Bureau de Continuité, hexagone solaire, `HG-NNNN-XXXX`, MRZ, « Implants déclarés »), `doc_entry_permit` (**Permis d'entrée**, Autorité de Transit, anneau barré, `PE-AAAA-NNNNN`), `doc_bioscan` (**Certificat bio-scan**, Clinique Orbitale Meridian, croix en orbite, `BS-NNNNN`). Documents d'extension (LORE §9 : dérogation MIL, contrat de travail, laissez-passer de dérive, attestation d'asile, licence de cargaison) : **après J10**.

| Id | Règle (texte Rulebook, abrégé) | Sous-classe | Jour | Catégorie / sévérité |
|---|---|---|---|---|
| R01 `r_id_card_required` | Tout passager présente une Carte d'identité | `RequireDocumentRule` | J1 | DOCUMENTS / 2 |
| R02 `r_id_card_valid` | La Carte d'identité n'est pas expirée | `DocumentNotExpiredRule` | J1 | DOCUMENTS / 2 |
| R03 `r_portrait_match` | La photo correspond au porteur | `PortraitMatchRule` | J2 | IDENTITY / 2 |
| R04 `r_permit_required` | Ressortissants (toute origine sauf `HAL`) : Permis d'entrée obligatoire | `RequireDocumentRule` (condition d'origine) | J3 | DOCUMENTS / 2 |
| R05 `r_permit_valid` | Le Permis d'entrée n'est pas expiré | `DocumentNotExpiredRule` | J3 | DOCUMENTS / 2 |
| R06 `r_face_uncovered` | Le visage doit être découvert pour le contrôle | procédure (`ScoringService`) 🟡 | J3 | SPECIAL / 1 |
| R07 `r_identity_fields_match` | Nom, date de naissance et n° ID identiques sur tous les documents | `FieldsMatchRule` | J3 | IDENTITY / 2 |
| R08 `r_tycho_interview` | Ressortissants `TYC` : interrogatoire obligatoire | procédure (`ScoringService`) 🟡 | J4 | SPECIAL / 1 |
| R09 `r_purpose_consistent` | Motif et durée conformes au permis ; `C-4` : permis ≤ 30 jours ; motif TRAVAIL : employeur indiqué | `PurposeRequiresDocumentRule` | J4 | PURPOSE / 2 |
| R10 `r_origin_block` | Le 1ᵉʳ chiffre du bloc ID correspond à l'origine (onglet Origines) | nouvelle sous-classe 🟡 | J4 | IDENTITY / 2 |
| R11 `r_bioscan_required` | Certificat bio-scan obligatoire | `RequireDocumentRule` | J5 | DOCUMENTS / 2 |
| R12 `r_bioscan_valid` | Bio-scan émis il y a moins de 30 jours | `DocumentNotExpiredRule` | J5 | DOCUMENTS / 2 |
| R13 `r_bioscan_issuer` | Émetteur agréé : Clinique Orbitale Meridian uniquement | `IssuerAllowedRule` | J5 | DOCUMENTS / 2 |
| R14 `r_bioscan_fit` | Statut bio-scan : SAIN uniquement | nouvelle sous-classe 🟡 | J5 | SPECIAL / 2 |
| R15 `r_implants_declared` | Tout implant visible figure dans « Implants déclarés » | nouvelle sous-classe 🟡 | J6 | IDENTITY / 2 (3 si `MIL-`, J7+) |
| R16 `r_banned_implants` | `MIL-` interdits sans dérogation ; `DER-19` toujours interdit ; `OPT-`, `NX-`, `KIN-`, `DER-1…13` autorisés si déclarés | nouvelle sous-classe 🟡 | J6 | SPECIAL / 2 |
| R17 `r_identity_fraud_detain` | Usurpation d'identité : DÉTENTION | méta (sévérité 3 sur R03 pour `IMPOSTOR`) | J7 | IDENTITY / 3 |
| R18 `r_apparent_age` | L'âge apparent correspond à la date de naissance ; papiers d'autrui : DÉTENTION | `PortraitMatchRule` (option âge) | J8 | IDENTITY / 3 |
| R19 `r_tharsis_banned` | Ressortissants `THR` : entrée interdite, sauf motif DIPLOMATIQUE | `FactionBannedRule` | J8 | FACTION / 2 |
| R20 `r_seals_valid` | Sceaux conformes à l'onglet Sceaux (nouveau modèle d'anneau barré au 21.03) | nouvelle sous-classe 🟡 | J9 | DOCUMENTS / 2 |
| R21 `r_mrz_valid` | La MRZ recopie fidèlement nom, n° ID et origine | `FieldsMatchRule` (champ MRZ) | J9 | IDENTITY / 2 |
| R22 `r_wanted_detain` | Personnes de l'avis de recherche du jour : DÉTENTION | nouvelle sous-classe 🟡 | J10 | IDENTITY / 3 |

Onglets Rulebook : Règles (J1), Origines (J4 : code, bloc ID, documents attendus), Implants (J6), Symboles subversifs (J7), Sceaux (J9), Avis de recherche (J10).

---

## 8. Progression jour par jour (J1–J10)

### 8.1 Table de synthèse

| Jour | Date | Nouvelles règles | Nouveau document / outil | Nouveaux types d'anomalies | `passenger_count` | `duration_sec` | `anomaly_count_weights` [0,1,2,3] | Événement narratif |
|---|---|---|---|---|---|---|---|---|
| **J1** | mar. 13.03.2187 | R01, R02 | Carte d'identité | `EXPIRED_DOCUMENT`, `MISSING_DOCUMENT` | 8 | 540 | [0.55, 0.45, 0.00, 0.00] | Prise de poste ; tutoriel diégétique d'**Okonkwo** (Guichet 03) ; le soir, chauffage impayable pour la plupart des joueurs |
| **J2** | mer. 14.03.2187 | R03 | champ **Visage** | `PORTRAIT_MISMATCH` | 10 | 570 | [0.50, 0.45, 0.05, 0.00] | Noa tousse ; première facture d'oxygène de Dora ; bulletin : « Un document exact est un citoyen en sécurité. » |
| **J3** | jeu. 15.03.2187 | R04, R05, R06, R07 | Permis d'entrée (contrôle transféré des quais) ; visière | `ID_MISMATCH`, `NAME_MISMATCH` | 11 | 600 | [0.45, 0.45, 0.10, 0.00] | Premier contact **Lucioles** (dessin de luciole, *lumika*) — **fin du MVP** |
| **J4** | ven. 16.03.2187 | R08, R09, R10 | onglet Origines ; **Ceinturiers** dans la file | `ORIGIN_ID_MISMATCH`, `PURPOSE_MISMATCH` | 12 | 600 | [0.45, 0.45, 0.10, 0.00] | *Respiration* ; licenciés Kessler-Ashe de Tycho par la Transit-7 ; premier **pot-de-vin** |
| **J5** | sam. 17.03.2187 | R11, R12, R13, R14 | Certificat bio-scan (le poste Meridian des quais ferme) | `WRONG_ISSUER`, `BIOSCAN_UNFIT` | 12 | 630 | [0.40, 0.45, 0.15, 0.00] | Alerte Fièvre grise ; les Lucioles demandent de laisser passer « une médecin » sans certificat (code MRZ `07`) |
| **J6** | dim. 18.03.2187 | R15, R16 | onglet Implants ; **Tharsiens** dans la file | `UNDECLARED_IMPLANT`, `BANNED_IMPLANT` | 13 | 630 | [0.35, 0.45, 0.15, 0.05] | Bio-scan de Noa (25 ₵) ; vétéran tharsien `MIL-` qui veut voir sa fille |
| **J7** | lun. 19.03.2187 | R17 | tampon **DÉTENTION** ; onglet Symboles subversifs | `IMPOSTOR_LOOKALIKE` (+ refus de visière 10 %) | 14 | 660 | [0.35, 0.40, 0.20, 0.05] | Prime de détention annoncée ; un Luciole se présente avec les papiers d'un Né-Halcyon ; phrase de passe |
| **J8** | mar. 20.03.2187 | R18, R19 | **Dérivants** dans la file | `RELATIVE_DOCUMENTS`, `BANNED_FACTION` | 14 | 660 | [0.30, 0.40, 0.22, 0.08] | Attentat au quai (rumeur Tharsis-Luciole) → Tharsiens interdits ; **familles séparées** ; loyer à 20 ₵ |
| **J9** | mer. 21.03.2187 | R20, R21 | onglet Sceaux ; MRZ comparable | `INVALID_SEAL`, `MRZ_MISMATCH` | 15 | 690 | [0.30, 0.40, 0.22, 0.08] | *Respiration* ; **audit des Inspecteurs** ; Ilan avoue travailler pour les Veilleurs ; offre de faux laissez-passer de dérive (40 ₵) |
| **J10** | jeu. 22.03.2187 | R22 | onglet Avis de recherche | `WANTED_PERSON` | 16 | 720 | [0.25, 0.40, 0.25, 0.10] | Les Lucioles tentent de « rendre l'air » : un agent recherché se présente au Guichet 04 → choix final → épilogue |

Implicite : `credit_per_correct = 5` tous les jours ; `penalty_per_error = 5` ; `game_date` = conversion `GameDate` de la date ; `rule_set` = `rs_dayNN` (liste **explicite et cumulative** des règles actives, `new_rule_ids` = colonne « Nouvelles règles »).

### 8.2 `anomaly_weights` par jour (poids relatifs, filtrés par le générateur sur les types couverts)

| Type | J1 | J2 | J3 | J4 | J5 | J6 | J7 | J8 | J9 | J10 |
|---|---|---|---|---|---|---|---|---|---|---|
| `EXPIRED_DOCUMENT` | 0.6 | 0.4 | 0.25 | 0.15 | 0.12 | 0.10 | 0.08 | 0.07 | 0.06 | 0.05 |
| `MISSING_DOCUMENT` | 0.4 | 0.2 | 0.15 | 0.10 | 0.10 | 0.07 | 0.05 | 0.05 | 0.04 | 0.04 |
| `PORTRAIT_MISMATCH` | — | 0.4 | 0.20 | 0.10 | 0.08 | 0.06 | 0.04 | 0.04 | 0.03 | 0.03 |
| `ID_MISMATCH` | — | — | 0.20 | 0.12 | 0.10 | 0.08 | 0.07 | 0.06 | 0.05 | 0.05 |
| `NAME_MISMATCH` | — | — | 0.20 | 0.12 | 0.10 | 0.08 | 0.07 | 0.06 | 0.05 | 0.05 |
| `ORIGIN_ID_MISMATCH` | — | — | — | 0.20 | 0.08 | 0.07 | 0.06 | 0.05 | 0.05 | 0.04 |
| `PURPOSE_MISMATCH` | — | — | — | 0.21 | 0.10 | 0.08 | 0.07 | 0.06 | 0.05 | 0.05 |
| `WRONG_ISSUER` | — | — | — | — | 0.16 | 0.08 | 0.06 | 0.05 | 0.05 | 0.04 |
| `BIOSCAN_UNFIT` | — | — | — | — | 0.16 | 0.08 | 0.06 | 0.05 | 0.05 | 0.04 |
| `UNDECLARED_IMPLANT` | — | — | — | — | — | 0.20 | 0.10 | 0.08 | 0.07 | 0.06 |
| `BANNED_IMPLANT` | — | — | — | — | — | 0.10 | 0.07 | 0.06 | 0.05 | 0.05 |
| `IMPOSTOR_LOOKALIKE` | — | — | — | — | — | — | 0.27 | 0.10 | 0.08 | 0.08 |
| `RELATIVE_DOCUMENTS` | — | — | — | — | — | — | — | 0.14 | 0.08 | 0.07 |
| `BANNED_FACTION` | — | — | — | — | — | — | — | 0.13 | 0.08 | 0.07 |
| `INVALID_SEAL` | — | — | — | — | — | — | — | — | 0.13 | 0.07 |
| `MRZ_MISMATCH` | — | — | — | — | — | — | — | — | 0.08 | 0.06 |
| `WANTED_PERSON` | — | — | — | — | — | — | — | — | — | 0.10 |

Principe : un type nouveau pèse ~15–40 % le jour de son introduction (le joueur doit le rencontrer 2–3 fois), puis se dilue.

### 8.3 Paramètres complémentaires 🟡 (nouveaux champs `DayDef` ou constantes du générateur)

| Paramètre | J1 | J2 | J3 | J4 | J5 | J6 | J7 | J8 | J9 | J10 |
|---|---|---|---|---|---|---|---|---|---|---|
| `faction_weights` TYC / HAL / TER / CER / THR / DRV | .45/.25/.30/0/0/0 | idem | idem | .38/.20/.25/.17/0/0 | idem | .33/.18/.22/.15/.12/0 | idem | .30/.17/.20/.13/.12/.08 | idem | idem |
| `visor_down_rate` | 0 | 0 | 0.15 | 0.15 | 0.15 | 0.15 | 0.20 | 0.20 | 0.20 | 0.20 |
| `legit_noise_rate` | 0.10 | 0.15 | 0.20 | 0.20 | 0.25 | 0.25 | 0.30 | 0.30 | 0.35 | 0.35 |
| `bribe_rate` (cas avec anomalie) | 0 | 0 | 0 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 |
| `luciole_rate` (passager porteur d'un code, hors scénarisés) | 0 | 0 | 0 | 0.04 | 0.05 | 0.06 | 0.06 | 0.07 | 0.07 | 0.08 |

MVP (J1–J3) : 3 origines seulement (Tycho, Nés-Halcyon, Gravitaires), conformément à la question ouverte n° 5 du Lore. Ceinturiers au J4, Tharsiens au J6, Dérivants au J8 (avec la date « 00.00.AAAA » tolérée par une ligne de l'onglet Origines).

---

## 9. Courbe de difficulté

Trois leviers seulement, tous dans `DayDef` : charge de vérification (règles × documents), proportion et subtilité des fraudes, budget de temps par cas.

| Jour | Docs | Règles actives | Comparaisons pour valider un passager « propre » | Budget/cas (≈ `duration_sec` / `passenger_count` − 6 s de marche/départ) | Subtilité |
|---|---|---|---|---|---|
| J1 | 1 | 2 | 2 (présence, expiration) | ~61 s | grossière |
| J2 | 1 | 3 | 3 (+ visage) | ~51 s | grossière (≥ 3 traits) |
| J3 | 2 | 7 | 6–7 (+ ID, nom, naissance, expiration permis, visière) | ~49 s | 1–2 caractères |
| J4 | 2 | 10 | 8–9 (+ bloc ID, motif/durée, question TYC) | ~44 s | **respiration** (pas de nouveau document) |
| J5 | 3 | 14 | 11–12 | ~46 s | nouveau document = pic |
| J6 | 3 | 16 | 12–13 | ~42 s | implants (lecture du visage) |
| J7 | 3 | 17 | 12–13 | ~41 s | **1–2 traits** (sosies) = pic |
| J8 | 3 | 19 | 13–14 | ~41 s | air de famille, âge apparent, interdiction THR |
| J9 | 3 | 21 | 14–15 | ~40 s | **respiration** (sceaux, MRZ : vérifications rapides) |
| J10 | 3 | 22 | 14–15 | ~39 s | avis de recherche |

Forme visée : dents de scie montantes (pics J3, J5, J7, J10 ; respirations J4, J9). Le budget par cas décroît de ~61 s à ~39 s pendant que le joueur gagne en expertise : la *sensation* de pression reste constante, la *performance* progresse. La médiane traite ~85–95 % de la file (§14).

Accessibilité (UI_FLOW §6) : vitesse du shift ×0.5–×1.5, « Inspection ralentit le temps », mode Récit sans fin chronométrée ; gains par cas inchangés dans ces modes.

---

## 10. `DayDef` prêts à saisir (J1–J3, MVP)

```text
# data/days/day_01.tres
day_number = 1 ; game_date = GameDate(2187, 3, 13) ; rule_set = rs_day01 (R01, R02 ; new = R01, R02)
duration_sec = 540.0 ; passenger_count = 8
anomaly_count_weights = [0.55, 0.45, 0.0, 0.0]
anomaly_weights = { EXPIRED_DOCUMENT: 0.6, MISSING_DOCUMENT: 0.4 }
credit_per_correct = 5 ; penalty_per_error = 5 ; intro_text_key = "day01_intro"
scripted_cases = [SC-01 @0, SC-02 @1, tuto @2 (forced_anomalies = []), tuto @3 (forced_anomalies = [MISSING_DOCUMENT])]
# 🟡 faction_weights = {TYC: .45, HAL: .25, TER: .30} ; visor_down_rate = 0.0 ; legit_noise_rate = 0.10

# data/days/day_02.tres
day_number = 2 ; game_date = GameDate(2187, 3, 14) ; rule_set = rs_day02 (R01–R03 ; new = R03)
duration_sec = 570.0 ; passenger_count = 10
anomaly_count_weights = [0.50, 0.45, 0.05, 0.0]
anomaly_weights = { EXPIRED_DOCUMENT: 0.4, MISSING_DOCUMENT: 0.2, PORTRAIT_MISMATCH: 0.4 }
credit_per_correct = 5 ; penalty_per_error = 5 ; intro_text_key = "day02_intro"
scripted_cases = [SC-03 @3]
# 🟡 faction_weights = {TYC: .45, HAL: .25, TER: .30} ; visor_down_rate = 0.0 ; legit_noise_rate = 0.15

# data/days/day_03.tres
day_number = 3 ; game_date = GameDate(2187, 3, 15) ; rule_set = rs_day03 (R01–R07 ; new = R04, R05, R06, R07)
duration_sec = 600.0 ; passenger_count = 11
anomaly_count_weights = [0.45, 0.45, 0.10, 0.0]
anomaly_weights = { EXPIRED_DOCUMENT: 0.25, MISSING_DOCUMENT: 0.15, PORTRAIT_MISMATCH: 0.2, ID_MISMATCH: 0.2, NAME_MISMATCH: 0.2 }
credit_per_correct = 5 ; penalty_per_error = 5 ; intro_text_key = "day03_intro"
scripted_cases = [SC-04 @2, SC-05 @7]
# 🟡 faction_weights = {TYC: .45, HAL: .25, TER: .30} ; visor_down_rate = 0.15 ; legit_noise_rate = 0.20
```

Au J3, les Nés-Halcyon (`HAL`, ~25 %) n'ont pas de Permis d'entrée : c'est la première lecture conditionnelle d'une règle (R04), et un `MISSING_DOCUMENT` de permis ne doit jamais être injecté sur un `HAL`.

---

## 11. Dilemmes moraux & fins

### 11.1 Dilemmes

| Dilemme | Jours | Forme | Conséquences |
|---|---|---|---|
| **Supplication** | J1+ | Document « presque valide », « *Somi, sa tiru ka.* » | Approuver = citation ; refuser = ANGRY / larmes, écho parfois dans le bulletin du lendemain |
| **Pots-de-vin** | J4+ | Enveloppe glissée avec les papiers (§5.5) | +10–50 ₵, Suspicion +1 ; audit J9 |
| **Lucioles** | J3, J5, J7, J9, J10 | Codes de reconnaissance (§4.7) ; demandes : laisser passer une médecin sans bio-scan (J5), ne pas détenir un usurpateur luciole (J7), transmettre un message à Ilan (J9), laisser passer l'agent recherché (J10) | Aider = `lucioles_trust +1` et souvent une citation ; ignorer = rien ; dénoncer = `loyalty +1`, `lucioles_trust −2`, prime |
| **Familles séparées** | J8 (scénarisé), J9–J10 (généré, rare) | Couple tharsien dont un seul a le motif DIPLOMATIQUE ; famille gravitaire dont la mère porte les papiers de sa sœur décédée (`RELATIVE_DOCUMENTS`) ; enfants dérivants non documentés | Appliquer la règle = famille séparée (message du lendemain) ; laisser passer = citation, `lucioles_trust +1` si les Lucioles les avaient signalés |
| **Détention** | J7+ | Prime de 5 ₵ pour une « mise en attente » ; parfois un Luciole, un vétéran, quelqu'un qui fuit pour sa famille | Détenir = `loyalty +1` (+ prime) ; refuser simplement = correct sans prime ; le sort des détenus (Anneau B) apparaît dans les bulletins |
| **Famille du joueur** | toute la campagne | Arbitrages du soir (chauffage de Noa vs oxygène de Dora vs médicaments) | États du foyer (§5.4) ; Ilan et les Veilleurs (J9) ; faux laissez-passer de dérive (J9, 40 ₵) → débloque F6 |

### 11.2 Fins (évaluées en fin de J10, ou anticipées)

| # | Fin | Condition |
|---|---|---|
| F1 | **Arrestation** | Audit J9 avec Suspicion ≥ 4 ; **ou** double jeu découvert le J10 (`lucioles_trust ≥ 3` et `loyalty ≥ 3`) |
| F2 | **Réaffectation** (anticipée) | 2 loyers impayés consécutifs ; ou solde < 0 trois soirs consécutifs |
| F3 | **Famille perdue** (anticipée) | Ilan, Noa et Dora tous `PERDU` |
| F4 | **Gloire au Consortium** | J10 : l'agent recherché est détenu, `loyalty ≥ 3`, conformité ≥ 85 %, ≥ 2 proches en vie → promotion `C-2`, appartement chauffé dans les Anneaux ; la station se ferme un peu plus |
| F5 | **Rendre l'air** | J10 : l'agent recherché passe, `lucioles_trust ≥ 4` → les Lucioles prennent les recycleurs (variante Veilleurs / Brûlants selon les choix du J9, à écrire par le Scénariste) ; l'agent·e disparaît dans la Soute avec sa famille |
| F6 | **À la dérive** | Faux laissez-passer achetés au J9 + ≥ 2 proches en vie + solde ≥ 30 ₵ au J10 → la famille embarque sur un cargo dérivant |
| F7 | **Le guichet rouvre demain** (par défaut) | J10 atteint sans autre condition : rien n'a changé |

Priorité d'évaluation : F1 > F3 > F2 > F5 > F6 > F4 > F7.

---

## 12. Passagers scénarisés du MVP

Format `ScriptedCaseDef` : `at_index` = index 0-based dans la file du jour. Noms et dialogues finaux : Scénariste (placeholders sauf mention).

| Id | Jour / index | Passager | Configuration (`passenger_overrides`, `forced_anomalies`) | Attendu | Intention / flags |
|---|---|---|---|---|---|
| **SC-01** | J1 / 0 | Technicien `HAL` de l'Anneau C qui rentre de mission, habitué du guichet | Carte d'identité valide ; `forced_anomalies = []` ; Okonkwo commente à l'intercom (touche Inspection) | APPROUVÉ | Apprendre le flux complet sans risque |
| **SC-02** | J1 / 1 | Mère gravitaire `TER` pressée | `EXPIRED_DOCUMENT` sur la carte, expirée de **3 jours** ; « *Ravel ka ota.* » | REFUSÉ (documenté) | Tutoriel expiration ↔ date du jour → 1ʳᵉ question → 1ᵉʳ dilemme. Si approuvé : avertissement |
| **SC-03** | J2 / 3 | Mineur `TYC` nerveux, toux grise | `PORTRAIT_MISMATCH` (photo d'un autre, 3 traits) ; « c'est une vieille photo » ; la photo porte aussi du bruit (coiffure) | REFUSÉ | Enseigner Visage ↔ Photo et distinguer bruit légitime / trait d'identité |
| **SC-04** | J3 / 2 | **Mira Vasquez-Orlov** (proposition : personnage canon, `TYC`, Kessler-Ashe Orbital, `HG-4471-K2Q9`, née 02.11.2151) | Arrive **visière baissée** (`appearance_overrides.headwear = visor_down`) ; papiers valides (carte + permis motif TRAVAIL) ; retire la visière à la demande | APPROUVÉ (après retrait) | Tutoriel visière (R06). Approuver sans retrait = VISAGE NON CONTRÔLÉ. `sets_flag = met_mira` |
| **SC-05** | J3 / 7 | Messager des Lucioles (`TYC`) | `ID_MISMATCH` (1 caractère) sur le permis ; code 1 (luciole au coin du permis) + code 7 (*lumika*) ; message glissé : « Laissez-le passer. Nous vous aiderons. » | REFUSÉ (correct) ; APPROUVÉ = citation | `sets_flag = lucioles_contact` ; APPROUVÉ → `lucioles_trust +1` ; « Signaler » le message le soir → `loyalty +1` (MVP : flag seulement) |

Cas contraints du tutoriel (sans dialogue dédié, J1) : index 2 sans anomalie (le joueur découvre « CONCORDANT »), index 3 `MISSING_DOCUMENT` (premier REFUS autonome), conformément à UI_FLOW §7.

---

## 13. Périmètre MVP = jours 1–3 jouables

**Dedans**
- J1–J3 complets (`day_01..03.tres`, `rs_day01..03`), règles R01–R07, Carte d'identité + Permis d'entrée, origines TYC / HAL / TER.
- Anomalies : `EXPIRED_DOCUMENT`, `MISSING_DOCUMENT`, `PORTRAIT_MISMATCH`, `ID_MISMATCH`, `NAME_MISMATCH` ; visière (J3).
- Mode Inspection A ↔ B, dont Visage ↔ Photo et Règle ↔ Dossier (document manquant).
- Interrogatoire : questions de base + débloquées + « Retirez votre visière ».
- Verdicts APPROUVÉ / REFUSÉ ; citations (2 avertissements puis amendes) ; REFUS NON MOTIVÉ ; VISAGE NON CONTRÔLÉ.
- Soirée : loyer, taxe d'air, nourriture, chauffage, oxygène de Dora (J2), médicaments ; états du foyer ; fins anticipées F2 et F3.
- 5 passagers scénarisés (§12) ; code Luciole 1 et 7 (SC-05 uniquement) ; sauvegarde entre jours ; options d'accessibilité du temps.
- PC + Steam Deck (manette, 1280×800).

**État M5 (implémenté, Gameplay Systems)** : tout le « Dedans » ci-dessus sauf les fins F1/F4–F7 (hors MVP) ; valeurs de §5 et §10 **inchangées** (aucun rééquilibrage). Précisions de lecture : Noa malade à 50 % au 1ᵉʳ soir sans chauffage (aléa seedé) ; un poste facultatif ne peut pas rendre le solde négatif (seule la taxe d'air le peut) ; amendes retenues au fil du shift (ticket immédiat) ; refus d'un dossier à document manquant documenté d'office (D-032). Mesuré (simulation, graine 20 871 315) : joueur parfait J1/J2/J3 = 40/50/55 ₵, solde 2/4/21 ₵, foyer en bonne santé ; bot « approuve tout » → réaffectation (F2) au soir du J2 ; joueur à ~80 % → foyer malade dès le J2 (à surveiller en playtest : §14 « sacrifier 1 poste sur 3 » paraît plus dur que prévu).

**Dehors (post-MVP)**
- Tampon DÉTENTION et prime (J7) — le code prévoit néanmoins `VerdictKind.DETAIN`.
- `IMPOSTOR_LOOKALIKE`, `RELATIVE_DOCUMENTS` (🟡 optionnel MVP dans ARCHITECTURE : **reporté**), et tous les types J4+ ; Certificat bio-scan, implants, interdiction THR, sceaux, MRZ, avis de recherche.
- Origines CER / THR / DRV ; onglets Origines, Implants, Symboles, Sceaux, Avis.
- Pots-de-vin, audit, codes Lucioles 2–6 et génération aléatoire de Lucioles, jauges au-delà des flags `lucioles_contact` / `met_mira`.
- Fins F1, F4–F7 ; documents d'extension (LORE §9) ; Scanner partiel (UI_FLOW §5.2).

---

## 14. Métriques de playtest

| Métrique | J1 | J2 | J3 | J4–J6 | J7–J10 |
|---|---|---|---|---|---|
| Taux de verdicts corrects (cible médiane) | ≥ 90 % | ≥ 85 % | ≥ 80 % | 75–85 % | 70–80 % |
| Temps moyen par cas (`Verdict.elapsed_sec`) | 55–60 s | 50–55 s | 45–55 s | 40–50 s | 35–45 s |
| Part de la file traitée (médiane) | 100 % | ≥ 90 % | ≥ 85 % | ≥ 85 % | ≥ 85 % |
| Citations / jour (médiane) | ≤ 1 | ≤ 1 | ≤ 2 | ≤ 2 | ≤ 3 |
| Refus non motivés (part des refus) | — (tutoriel) | ≤ 15 % | ≤ 10 % | ≤ 5 % | ≤ 5 % |
| Approbations visière baissée | — | — | ≤ 20 % des masqués | ≤ 10 % | ≤ 5 % |
| Discordances Visage trouvées quand présentes | — | ≥ 80 % | ≥ 80 % | ≥ 80 % | ≥ 65 % (sosies) |
| Code Luciole 1 remarqué (SC-05) | — | — | ≥ 50 % | — | — |
| Joueurs ayant sacrifié ≥ 1 poste du soir | ≥ 60 % | — | ≥ 80 % cumulé | — | — |

- **Steam Deck** : tolérance +10 % sur le temps par cas ; au-delà de 15 % d'écart, revoir le focus magnétique manette et la lisibilité MRZ / luciole avant de toucher aux `DayDef`.
- Leviers d'ajustement, dans cet ordre : `duration_sec` (±30 s), `passenger_count` (±1–2), `anomaly_count_weights`, `anomaly_weights`. Jamais les règles.
- Télémétrie locale (debug) proposée : par cas `case_seed`, `elapsed_sec`, comparaisons faites, questions posées, verdict, citation ; par jour : crédits, dépenses choisies, états du foyer.

---

## 15. Questions ouvertes (à valider)

1. **Preuve du MISSING_DOCUMENT** : valider la comparaison « Règle Documents requis ↔ Dossier » (UI/UX), ou se contenter de la question « Où est votre … ? » comme preuve.
2. **Ajouts au modèle de données** : types `ORIGIN_ID_MISMATCH`, `MRZ_MISMATCH`, `BIOSCAN_UNFIT`, `UNDECLARED_IMPLANT`, `BANNED_IMPLANT`, `WANTED_PERSON` ; champs `DayDef` `faction_weights`, `visor_down_rate`, `legit_noise_rate`, `bribe_rate`, `luciole_rate`, `free_citations_per_day`, `penalty_escalated` ; règles procédurales R06/R08 dans `ScoringService` (accord Godot Architect).
3. **REFUS correct non documenté = 0 ₵ + citation** : assez lisible et juste pour le client, ou demi-paie (2 ₵) + citation ?
4. **Ton des pertes** : « PERDU » = décès (à la *Papers, Please*) ou départ / hospitalisation à l'Anneau B ? À trancher avec le Lore Master, le Scénariste et le client.
5. **Calendrier des contrôles** : le Lore situe l'interrogatoire obligatoire des Tycho dès 2187 et le bio-scan obligatoire depuis 2183 ; le GDD les fait entrer au guichet aux J4 et J5 via la « délégation progressive des quais » (§3.3). ✅ Validé par le client (D-028) et intégré au Lore (§3 « La délégation progressive des quais »).
