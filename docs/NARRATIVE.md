# NARRATIVE.md — Récit, passagers scénarisés et fins (J4 → J10)

> Propriétaire : **Scénariste**. Statut : v0.2 (validée D-052/D-053 ; v0.2 = alignement sur l'implémentation M7, cf. §8.5). Date : 2026-10-27.
> Sources faisant foi : `LORE.md` (noms, codes Lucioles, implants, documents, Tessar), `GDD.md` (progression J1–J10, anomalies, fins F1–F7, économie après D-047), `DECISIONS.md` (D-020, D-021, D-024, D-028, D-030 → D-036, D-045), `docs/UI_FLOW.md` (§3.6 sujets d'interrogatoire, §4.7 réactions), données existantes (`data/days/day_0N.tres`, `ScriptedCaseDef`, `BriefingContent`, `data/i18n/fr.csv`).
>
> Conventions de ce document :
> - **J** = jour de campagne ; **@n** = `at_index` (0-based) dans la file du jour.
> - Les clés i18n sont données avec leur texte FR définitif : les développeurs les recopient telles quelles dans `fr.csv`. Depuis la v0.2, `fr.csv` et ce document sont synchronisés à l'identique (le Scénariste est propriétaire des deux pour les clés narratives).
> - Tessar : les fragments sont écrits entre **chevrons simples** `‹…›` (§7.1), seule marque possible dans un `Label`.
> - Les deltas de flags suivent D-045 : `{flag: delta}` ajouté aux jauges entières, ou drapeau mis à vrai si delta = 0.
> - 🟡 = demande un développement (récapitulé en §8). Rien dans ce document ne contredit une décision 🟢 ; les rares écarts avec `LORE.md` sont signalés en §8.4.
> - Le verdict attendu d'un cas reste toujours **calculé par le moteur de règles** (D-005) : la colonne « Attendu » est l'intention, que QA doit vérifier.

---

## 0. Résumé exécutif

- **Quatre arcs** tressés sur dix jours : le **foyer** (Noa malade, Dora et la mémoire du Puits 9, Ilan qui rejoint les Veilleurs), les **Lucioles** (du mot glissé au J3 à la prise des recycleurs au J10), le **Consortium** (de la paperasse à l'audit, via un inspecteur qui teste l'agent·e), **Okonkwo** (mentor fatigué dont le sort dépend d'une signature au J9).
- **17 passagers scénarisés** J4–J10 (SC-06 → SC-22), dont 4 enveloppes, 2 familles séparées, 1 sosie luciole qui est **le messager du J3 revenu**, 1 inspecteur déguisé, 2 personnes recherchées, 1 vétéran `MIL-` avec dérogation, 1 retour d'une passagère refusée au J1.
- **Une seule figure finale** : **Mira Vasquez-Orlov** (rencontrée au J3) est sur l'avis de recherche du J10. La tamponner décide de F4 / F5 / F7.
- **Trois jauges** (existantes ou prévues au GDD) : `loyalty`, `lucioles_trust`, `suspicion`. Tout le reste est un drapeau booléen lisible.

---

## 1. Arcs narratifs (J1 → J10)

### 1.1 Vue d'ensemble — points de bascule par jour

| Jour | Foyer | Lucioles | Consortium | Okonkwo |
|---|---|---|---|---|
| **J1** mar. 13.03 | Premier soir, avance de 20 ₵, chauffage ou non | — | Prise de poste, « Gloire au Consortium » | Tutoriel, bienveillant et ironique |
| **J2** mer. 14.03 | Noa tousse ; 1ʳᵉ facture d'oxygène de Dora | — | Bulletin, écho SC-02 | Conseils visage |
| **J3** jeu. 15.03 | — | **Contact** : mot glissé (SC-05), *lumika* | Permis, visières | « Fais-les relever » |
| **J4** ven. 16.03 | **Anniversaire de Noa** (9 ans) | Code 5 (trois tapes) : les sympathisants existent | **Premier pot-de-vin** ; bulletin anticorruption | Apprend à interroger les Tycho « sans les humilier » |
| **J5** sam. 17.03 | Ilan sort la nuit | **1ʳᵉ demande** : laisser passer la médecin (MRZ `07`) ; **cadeau** : le chauffage payé | Alerte Fièvre grise | Ferme les yeux sur une toux |
| **J6** dim. 18.03 | **Bio-scan de Noa** (25 ₵, ou gratuit si la médecin est passée) | Code 6 (fil magenta) | **Test** : inspecteur déguisé (SC-12) | Raconte la Guerre du Sel ; défend le vétéran |
| **J7** lun. 19.03 | Lettre de l'école : Noa a dessiné une luciole | **2ᵉ demande** : ne pas détenir le messager du J3 (sosie) ; phrase de passe | **DÉTENTION** et prime ; onglet Symboles subversifs | **Refuse de détenir** ; citation publique |
| **J8** mar. 20.03 | Loyer à 20 ₵ ; Dora raconte le Puits 9 ; un voisin cache un Tharsien | **Attentat** attribué aux Lucioles ; les **Brûlants** demandent de cacher un colis | Tharsiens interdits ; familles séparées | Pressé par la Garde ; confie que le vétéran est innocent |
| **J9** mer. 21.03 | **Ilan avoue** : il·elle est Veilleur·se | **3ᵉ demande** : porter un message à Ilan ; offre de faux laissez-passer (40 ₵) | **Audit** de l'Inspecteur Ravel (F1 possible) | **On vous demande de signer contre lui** |
| **J10** jeu. 22.03 | Le foyer attend la décision | **4ᵉ demande** : laisser passer Mira | État de vigilance respiratoire ; avis de recherche | Selon le J9 : arrêté, réaffecté ou disparu dans la Soute |

### 1.2 Arc du foyer (Ilan, Noa, Dora)

**Intention.** Le foyer est la balance qui donne un poids aux crédits. Chaque proche porte un registre : **Noa** la santé et l'innocence (chauffage, bio-scan, dessin), **Dora** la mémoire (Tycho, Puits 9, oxygène), **Ilan** la politique (réaffecté·e, recycleurs, Veilleurs). Le jeu ne punit pas moralement : il montre ce que coûte chaque choix.

| Jour | Beat | Dépense spéciale datée | Effet système |
|---|---|---|---|
| J4 | Noa a 9 ans. Ilan a mis de côté une écorce d'orange pour l'odeur. | **Cadeau de Noa** (optionnel) : 5 ₵ (« une orange hydroponique de l'Anneau D ») | `noa_birthday_gift` ; ligne d'épilogue |
| J5 | Ilan rentre à 3 h du matin, les mains noires de graisse de recycleur. « Un dépannage. » | — (éventuellement chauffage offert par les Lucioles, §5) | — |
| J6 | La toux de Noa est « grise ». La Clinique Meridian exige un bio-scan. | **Bio-scan de Noa : 25 ₵** (GDD §5.3) — **0 ₵** si `sc09_doctor_passed` (la médecin passe au Bloc Pétrel) | non payé → Noa `MALADE`, l'événement revient au J8 (GDD) |
| J7 | L'école signale un dessin de luciole sur le cahier de Noa. | **Amende pédagogique : 10 ₵** (optionnelle) | non payée → `suspicion +1` |
| J8 | Loyer à 20 ₵. Dora, essoufflée, raconte la grève de 2151 et le Puits 9 ; elle a connu les parents de Mira. | Loyer 20 ₵ (GDD) ; bio-scan de Noa si sauté au J6 (25 ₵) | `dora_told_puits9` (toujours) |
| J9 | **Aveu d'Ilan** : il·elle répare en secret les recycleurs de la Soute pour les Veilleurs. Choix (§5). | Faux laissez-passer de dérive : 40 ₵ (si l'offre a été reçue) | `ilan_confessed` + choix |
| J10 | Pas de soirée : la décision du guichet clôt la campagne (§6). Dora a glissé son vieux badge de mineuse dans la poche de l'agent·e. | — | — |

États de santé : inchangés (GDD §5.4). Ajout 🟡 : un proche peut passer à `PERDU` pour une **raison narrative** (Ilan dénoncé·e → « mis·e en attente », §5 J9) ; l'écran Foyer affiche alors `hh_state_detained` au lieu de `hh_state_lost`.

### 1.3 Arc des Lucioles

**Intention.** Une montée de **demandes de plus en plus coûteuses**, chacune plus claire que la précédente sur ce que les Lucioles attendent : d'abord fermer les yeux, puis enfreindre la règle pour un innocent, puis protéger un usurpateur, puis devenir un relais, enfin laisser passer leur figure de proue. Le joueur qui lit les codes en sait plus que le Consortium (GDD §4.7) — c'est sa récompense et son risque.

| Jour | Demande / signe | Code(s) en jeu | Ce que l'aide coûte | Ce que l'aide rapporte |
|---|---|---|---|---|
| J3 | « Laissez-le passer. Nous vous aiderons. » (SC-05, existant) | 1, 7 | citation | `lucioles_trust +1` |
| J4 | Rien n'est demandé : un licencié de Tycho tape trois fois sur la vitre (SC-08) | **5** | citation si approuvé | `lucioles_trust +1` |
| J5 | **Demande n° 1** : la médecin sans bio-scan (SC-09). Une passagère en règle annonce un cadeau (SC-10). | **2** (MRZ `07`), **3** (permis en 7 + VISITE FAMILIALE) | citation | `+1`, bio-scan de Noa gratuit au J6, chauffage offert le soir |
| J6 | Les Lucioles observent : fil magenta sur des passagers générés | **6** | — | — |
| J7 | **Demande n° 2** : ne pas détenir Lev (SC-13), sosie d'un Né-Halcyon. Phrase de passe. | **1**, **4** | citation (approbation) ou perte de prime (refus simple) | `+2` si approuvé ; `+1` pour la réponse à la phrase |
| J8 | Les **Brûlants** (pas les Veilleurs) demandent de cacher un colis (soirée) ; Hana porte le fil magenta (SC-16) | **6** | `suspicion +1` | +20 ₵ ; oriente F5 vers la variante Brûlants |
| J9 | **Demande n° 3** : transmettre un message à Ilan (SC-18). Offre de départ (SC-19). | **2** sur SC-18 | risque d'être vu le jour de l'audit | `+1` ; débloque F6 |
| J10 | **Demande n° 4** : laisser passer Mira (SC-22), recherchée | **4**, **7** | ENTRÉE IRRÉGULIÈRE grave | ouvre **F5** si `lucioles_trust ≥ 4` |

**Risques côté Lucioles.**
- Dénoncer (signaler un mot, détenir un Luciole) : `lucioles_trust −2` (GDD).
- Si `lucioles_trust ≤ −2` à partir du J7 : drapeau dérivé `lucioles_hostile` ; le soir, la vitre de la cabine est taguée (« LE 04 ÉTEINT LES LUCIOLES ») et, au J8, le recycleur de la cabine est saboté par des Brûlants : **chauffage +6 ₵** ce soir-là (§5).
- **Double jeu** : `lucioles_trust ≥ 3` **et** `loyalty ≥ 3` au J10 = F1 (GDD).
- Répondre à la phrase de passe **le jour de l'audit (J9)** : `suspicion +1` (l'Inspecteur est dans le Hall).

**Apprendre *lumika*.** Le mot reste « [mot inconnu] » (LORE §7, code 7) jusqu'à `lumika_learned`, posé au J5 si SC-10 est approuvée (Yara traduit le mot) ou au J7 au soir (Ilan le prononce devant Noa). Réponse au LORE Q4 : **un seul mot** se débloque, pas tout le Tessar.

### 1.4 Arc du Consortium

**Intention.** Le Consortium n'est pas un méchant de cinéma : c'est une administration qui récompense, mesure et rappelle à l'ordre. Sa menace monte par **procédure**, pas par violence explicite — jusqu'au J8 où la Garde entre en scène.

| Jour | Beat | Mécanique |
|---|---|---|
| J4 | Bulletin anticorruption : « Une enveloppe ouverte est une vitre brisée. » | 1ʳᵉ enveloppe (SC-07) |
| J5 | Prime de signalement rappelée : 10 ₵ pour tout mot subversif transmis | bouton « Signaler » du soir (existant) |
| J6 | **L'Inspecteur Corentin Ravel** se présente déguisé en passager, avec une enveloppe trop généreuse | SC-12 : le test de l'agent·e |
| J7 | Tampon DÉTENTION, prime de vigilance, onglet Symboles subversifs | R17 |
| J8 | Attentat du quai 2 ; « Serment de vigilance » lu au briefing ; la Garde patrouille le Hall | R18, R19 ; voisin à dénoncer |
| J9 | **Audit** de Ravel : suspicion jugée ; on demande à l'agent·e de signer contre Okonkwo | F1 possible ; retenue 30 ₵ |
| J10 | État de vigilance respiratoire ; avis de recherche ; promesse d'une promotion C-2 aux agents exemplaires | R22 ; F4 |

**Primes et menaces récapitulées.** Prime de détention 5 ₵ (GDD) ; signalement d'un mot 10 ₵ (GDD) ; dénonciation du voisin 10 ₵ ; déposition contre Okonkwo 15 ₵ ; retenue d'audit 30 ₵ ; arrestation (F1).

### 1.5 Arc d'Okonkwo (mentor)

**Qui il est.** Gravitaire naturalisé C-3, Guichet 03, quinze ans de vitre. Il a survécu en appliquant la règle « juste assez ». Tutoiement, humour sec, finit ses conseils par « …comme on dit ». Il n'est **pas** Luciole : c'est un homme qui refuse une seule chose, envoyer des gens en Anneau B.

| Jour | Beat |
|---|---|
| J4 | Apprend à interroger un Tycho « comme un voisin, pas comme un suspect ». |
| J5 | Avoue avoir laissé passer une toux grise : « Je ne suis pas médecin. » |
| J6 | Selon SC-12 : félicite (test réussi) ou s'inquiète (« Ravel ne lâche jamais un dossier »). Défend le vétéran tharsien : il a servi en face de lui. |
| J7 | **Refuse de tamponner DÉTENTION.** Citation lue au haut-parleur du Hall. |
| J8 | Après l'attentat, confie que le vétéran Mazur dînait chez sa fille à 03:12 (si SC-11 approuvé). |
| J9 | Ravel demande à l'agent·e une **déposition** sur le « taux de détention nul » du Guichet 03. Choix du soir (§5) : **signer** / **refuser** / **prévenir Okonkwo**. |
| J10 | `okonkwo_denounced` → Guichet 03 fermé, brève « agent mis en attente ». `okonkwo_shielded` → il est là, réaffecté aux quais dès demain, dernier conseil. `okonkwo_warned` → Guichet 03 vide, une luciole dessinée dans la buée de sa vitre ; il a rejoint les Veilleurs. |

Son sort est repris dans chaque épilogue (§6).

---

## 2. Flags narratifs

### 2.1 Jauges entières

| Flag | Existant ? | Augmenté par | Diminué par | Lu par |
|---|---|---|---|---|
| `loyalty` | oui (`Campaign.FLAG_LOYALTY`) | signalement du mot SC-05 (+1), signalement d'un mot (soirée) (+1), signalement valide d'un porteur du code 1 (+1, §4.9), `inspector_test_passed` (+1), `sc13_detained` (+1), `sc17_detained` (+1), `sc20_detained` (+1), `neighbor_denounced` (+1), `sc18_note_reported` (+1), `okonkwo_denounced` (+2), `ilan_denounced` (+3) | `inspector_test_failed` (−1), retenue d'audit (−1), `okonkwo_warned` (−1) | F1, F4 ; variantes de briefing |
| `lucioles_trust` | oui (SC-05) | Luciole en infraction approuvé (+1, GDD), SC-05/SC-08/SC-09/SC-14/SC-16/SC-18 aidés (+1), `sc13_passed` (+2), `password_answered` (+1), `lucioles_heating_accepted` (+1), `neighbor_helped` (+1), `ilan_supported` (+1), `okonkwo_warned` (+1) | signalement (−2), signalement valide d'un porteur du code 1 (−2, §4.9), `ilan_forbidden` (−1), `ilan_denounced` (−3), `sc18_note_reported` (−2) | F1, F5 ; réponse à la phrase (≥ 2) ; `lucioles_hostile` (≤ −2) |
| `suspicion` 🟡 | non (prévu GDD §5.5) | chaque enveloppe gardée (+1), enveloppe de l'Inspecteur (+2), `sc07_complaint` (+1), `sc02_mercy` (+1, **rétroactif proposé**), `noa_school_fine_ignored` (+1), `brulants_package` (+1), `okonkwo_shielded` (+1), `okonkwo_warned` (+1), phrase de passe répondue au J9 (+1) | `inspector_test_passed` (−1, appliqué à l'audit) | Audit J9 (F1 si ≥ 4 ; retenue si 2–3) ; épilogues |

### 2.2 Drapeaux existants (inchangés)

| Flag | Posé par | Lu par (existant → ajouté ici) |
|---|---|---|
| `sc02_mercy` | SC-02 approuvé (J1) | briefing J2 → **+ `suspicion +1`** (proposition, cohérent avec `msg_echo_sc02_mercy`), SC-06 non présenté |
| `sc02_turned_away` | SC-02 refusé | briefing J2 → **+ `requires_flag` de SC-06 (J4)** |
| `sc03_passed` | SC-03 approuvé | briefing J3 |
| `met_mira` | SC-04 traité | → **SC-22 (J10)**, dialogue de reconnaissance |
| `lucioles_contact` | SC-05 traité | soirée J3 (mot) → **briefings J4–J5 (Lucioles)** |
| `sc05_helped` | SC-05 approuvé | → **SC-13 (J7)**, variante « merci pour jeudi » |
| `lucioles_reported` / `lucioles_note_burned` | soirée J3 | écran de fin → **briefing J4 (variante Okonkwo / Lucioles)** |
| `ending` | `Campaign.close_evening` | écran de fin |

### 2.3 Nouveaux drapeaux — passagers scénarisés

Convention : `scNN_<issue>`. Posés par `flags_on_approve` / `flags_on_deny` / 🟡 `flags_on_detain` / 🟡 `flags_on_bribe_kept` / 🟡 `flags_on_bribe_returned` / 🟡 `flags_on_item_*`.

| Flag | Posé par | Lu par |
|---|---|---|
| `sc06_reunited` / `sc06_refused_again` | SC-06 approuvé / refusé | briefing J5 (écho) ; épilogues |
| `sc07_bribe_kept` / `sc07_bribe_returned` | enveloppe SC-07 | Ilan J5 (« d'où vient cet argent ? ») |
| `sc07_passed` | SC-07 approuvé | briefing J5 (écho) |
| `sc07_complaint` | SC-07 refusé **et** enveloppe gardée | `suspicion +1` ; briefing J5 (Inspection) |
| `sc08_passed` / `sc08_turned_away` | SC-08 | briefing J5 (écho Transit-7) |
| `sc09_doctor_passed` / `sc09_doctor_refused` | SC-09 | soirée J6 (bio-scan de Noa gratuit) ; briefing J6 |
| `sc10_passed` | SC-10 approuvé | soirée J5 (chauffage offert proposé) ; `lumika_learned` |
| `sc11_veteran_passed` / `sc11_veteran_refused` | SC-11 | briefings J8 (suspect désigné) et J9 (Ravel) ; Okonkwo J8 |
| `inspector_bribe_taken` | SC-12, enveloppe gardée | `suspicion +2` ; audit J9 (confiscation 30 ₵) |
| `inspector_test_passed` | SC-12 refusé documenté **et** enveloppe rendue | `loyalty +1` ; Okonkwo J7 ; audit J9 (`suspicion −1`) |
| `inspector_test_failed` | SC-12 approuvé | `loyalty −1` ; audit J9 |
| `sc13_detained` / `sc13_turned_back` / `sc13_passed` | SC-13 | soirée J7 (représailles), briefing J8, SC-18 |
| `password_answered` | réponse « La pluie ne tombe que vers le bas. » (SC-13 ou SC-22) | `lucioles_trust +1` (une fois) ; F5 (variante) |
| `sc14_bribe_kept` / `sc14_passed` | SC-14 | soirée J8 (médicaments de la Soute à moitié prix si `sc14_passed`) |
| `sc15_idris_passed` | SC-15 approuvé | SC-16 (dialogue) |
| `sc16_hana_passed` / `sc16_family_split` | SC-16 approuvée / refusée | briefing J9 (écho), épilogues |
| `sc17_detained` / `sc17_turned_back` / `sc17_passed` | SC-17 | soirée J8 (enfant seul), briefing J9 |
| `sc18_note_kept` / `sc18_note_reported` | objet glissé SC-18 | soirée J9 (aveu d'Ilan : variante) ; `ilan_exposed` |
| `ilan_exposed` | `sc18_note_reported` | soirée J9 : Ilan est convoqué·e (aveu forcé) |
| `drift_offer` | SC-19 traité (quel que soit le verdict) | soirée J9 (achat des laissez-passer) |
| `sc20_detained` / `sc20_passed` / `sc20_turned_back` | SC-20 | F5 (variante Brûlants si `sc20_passed`) ; épilogues |
| `sc21_bribe_kept` / `sc21_passed` | SC-21 | épilogues |
| `final_detained` / `final_passed` / `final_denied` | SC-22 | **conditions de fin** (§6) |
| `final_unprocessed` | SC-22 non traitée en fin de shift | F7 (variante) |

### 2.4 Nouveaux drapeaux — soirées et briefings

| Flag | Posé par | Lu par |
|---|---|---|
| `noa_birthday_gift` | soirée J4 | épilogues |
| `lucioles_heating_accepted` / `lucioles_heating_refused` | soirée J5 | `lucioles_trust +1` ; briefing J6 (Ilan) |
| `lumika_learned` | SC-10 approuvée ou soirée J7 | sous-titres (code 7) |
| `noa_bioscan_paid` / `noa_bioscan_free` / `noa_bioscan_skipped` | soirée J6 | soirée J8 (retour de l'événement si sauté) |
| `noa_school_fine_paid` / `noa_school_fine_ignored` | soirée J7 | `suspicion +1` si ignorée |
| `lucioles_hostile` (dérivé) | `lucioles_trust ≤ −2` à la clôture d'une soirée ≥ J7 | soirées J7–J8 (tag, sabotage) |
| `dora_told_puits9` | soirée J8 | SC-22 (dialogue), F5 |
| `neighbor_denounced` / `neighbor_helped` / `neighbor_ignored` | soirée J8 | briefing J9 ; épilogues |
| `brulants_package` | soirée J8 | `suspicion +1` ; SC-20 ; F5 variante Brûlants |
| `audit_clean` / `audit_retention` | audit, soirée J9 | briefing J10 ; épilogues |
| `ilan_confessed` | soirée J9 (toujours) | — |
| `ilan_supported` / `ilan_forbidden` / `ilan_denounced` | soirée J9 | F5 variante, F4 variante, foyer (Ilan `PERDU` si dénoncé·e) |
| `okonkwo_denounced` / `okonkwo_shielded` / `okonkwo_warned` | soirée J9 | briefing J10 ; épilogues |
| `drift_passes_bought` | soirée J9 | **F6** |

---

## 3. Briefings J4 → J10

Structure (existante, `BriefingContent`) : titre de directive `dayNN_directive_title`, texte `dayNN_intro`, slogan `dayNN_slogan`, puis messages `{speaker, text, voice}`. Ajouts 🟡 : locuteurs `spk_consortium`, `spk_lucioles`, `spk_inspector`, `spk_dora` ; voix `LUCIOLES` (magenta, DS §7.10) et `INSPECTION` (jaune) ; messages conditionnels lus dans une table de données (§8.1) plutôt que codés en dur. **Au plus 4 messages** par briefing ; ordre : échos (Hall/Consortium) → Okonkwo → Lucioles → Ilan (état du foyer, puis message narratif du jour si l'état est `msg_family_ok`).

### 3.0 Nouveaux locuteurs

| Clé | Texte |
|---|---|
| `spk_consortium` | BUREAU DE CONTINUITÉ · BULLETIN |
| `spk_lucioles` | SANS SIGNATURE · ENCRE MAGENTA |
| `spk_inspector` | INSPECTEUR RAVEL · INSPECTION DES AGENTS |
| `spk_dora` | DORA · BLOC PÉTREL |

### 3.1 Jour 4 — vendredi 16.03.2187

| Clé | Texte |
|---|---|
| `day04_directive_title` | Directive n° 04 — Interrogatoire et motifs |
| `day04_intro` | Délégation n° 04 : la cellule d'audition des quais ferme. Le Guichet 04 interroge tout ressortissant de Tycho avant le tampon, contrôle motif et durée du séjour, et vérifie le bloc d'origine du N° ID (onglet Codes d'origine). Les Ceinturiers se présentent désormais au guichet. |
| `day04_slogan` | Chaque souffle se mérite. |
| `msg_cons_day04` | Rappel : toute gratification offerte au personnel de vitre doit être refusée. Une enveloppe ouverte est une vitre brisée. |
| `msg_okonkwo_day04` | Les licenciés de Tycho débarquent par la Transit-7. Pose-leur au moins une question, sinon c'est une citation. Parle-leur comme à un voisin, pas comme à un suspect. Ça va plus vite… comme on dit. |
| `msg_okonkwo_day04_reported` *(si `lucioles_reported`)* | J'ai vu passer ta transmission au Bureau. Prime notée, paraît-il. Moi, je brûle ces papiers-là. Chacun sa vitre. |
| `msg_luc_day04` *(si `lucioles_note_burned` ou `sc05_helped`)* | Nous avons vu ce que vous avez fait jeudi. Il pleut, même ici — souvenez-vous de la phrase. |
| `msg_ilan_day04` | Noa a neuf ans aujourd'hui. Elle veut une orange, « une vraie, qui sent ». Je lui ai dit qu'on verrait ce soir. |

### 3.2 Jour 5 — samedi 17.03.2187

| Clé | Texte |
|---|---|
| `day05_directive_title` | Directive n° 05 — Certificat bio-scan |
| `day05_intro` | Délégation n° 05 : le poste Meridian des quais ferme pour raisons sanitaires. Le Guichet 04 exige de tout entrant un certificat bio-scan de moins de 30 jours, émis par la Clinique Orbitale Meridian, au statut SAIN. Alerte Fièvre grise de niveau 2. |
| `day05_slogan` | Un document exact est un citoyen en sécurité. |
| `msg_echo_sc06_reunited` | Brève : une Gravitaire a retrouvé ses enfants hier à l'Anneau D après trois nuits passées dans le Hall. Les agents d'entretien ont applaudi. |
| `msg_echo_sc06_refused_again` | Brève : une ressortissante gravitaire refoulée deux fois au Guichet 04 a été réaffectée vers le Puits par le convoi de 06:00. |
| `msg_insp_day05_complaint` *(si `sc07_complaint`)* | Une plainte a été déposée contre le Guichet 04 par un citoyen C-1 pour « rétention de fonds ». Elle est jointe à votre dossier. |
| `msg_echo_sc08_passed` | Brève : un licencié de Tycho entré hier sans employeur a été interpellé au dortoir 12. Rappel : le motif TRAVAIL exige un employeur. |
| `msg_okonkwo_day05` | Bio-scan pour tout le monde. Regarde l'émetteur : « Meridian », pas « Meridiane ». Hier, j'ai laissé passer une toux grise. Je ne suis pas médecin. Toi non plus. |
| `msg_luc_day05` *(si `lucioles_trust ≥ 1` ou `lucioles_note_burned`)* | Une femme viendra aujourd'hui. Sa bande se termine par 07. Elle soigne les enfants de l'Anneau C. Les vôtres aussi. |
| `msg_ilan_day05` *(si `sc07_bribe_kept`)* | Il y avait 20 ₵ de plus hier soir. Je ne demande pas d'où ils viennent. Je préférerais le savoir, quand même. |

### 3.3 Jour 6 — dimanche 18.03.2187

| Clé | Texte |
|---|---|
| `day06_directive_title` | Directive n° 06 — Implants |
| `day06_intro` | Délégation n° 06 : la baie de scan des quais est démontée. Le Guichet 04 compare les implants visibles aux implants déclarés (onglet Implants). MIL- interdits sans dérogation de l'Autorité de Transit ; DER-19 toujours interdit. Ressortissants de Tharsis admis au guichet. |
| `day06_slogan` | Le Consortium voit. Le Consortium protège. |
| `msg_echo_sc09_doctor_passed` | Brève : une praticienne non enregistrée aurait été vue au Bloc Pétrel. Signalez toute activité médicale non agréée. |
| `msg_echo_sc09_doctor_refused` | Brève : la Fièvre grise progresse dans les dortoirs de l'Anneau C. Meridian rappelle que seul un bio-scan agréé protège. |
| `msg_okonkwo_day06` | Des Tharsiens aujourd'hui. J'en ai eu en face de moi, pendant la Guerre du Sel. Un implant MIL avec une dérogation valide, ça passe. La règle, rien que la règle — pour une fois, elle est de leur côté. |
| `msg_ilan_day06` *(si `lucioles_heating_accepted`)* | Quelqu'un a payé le chauffage hier. Le reçu porte un petit dessin. Noa a dormi sans tousser. Je ne pose pas de questions. |
| `msg_ilan_day06_noa` *(sinon)* | La toux de Noa a changé de couleur. La clinique veut un bio-scan ce soir. 25 ₵. |

### 3.4 Jour 7 — lundi 19.03.2187

| Clé | Texte |
|---|---|
| `day07_directive_title` | Directive n° 07 — Mise en attente |
| `day07_intro` | La Garde de Continuité met un tampon MISE EN ATTENTE à disposition du Guichet 04. Toute usurpation d'identité est mise en attente. Prime de vigilance : 5 ₵ par mise en attente justifiée. Le Bureau diffuse l'onglet « Symboles subversifs ». |
| `day07_slogan` | Vigilance aujourd'hui, Continuité demain. |
| `msg_okonkwo_day07_test_passed` *(si `inspector_test_passed`)* | Tu as eu de la visite hier. Le type à l'enveloppe trop grosse ? Ravel, de l'Inspection. Il fait ça à tous les nouveaux. Tu as bien fait. |
| `msg_okonkwo_day07_test_failed` *(si `inspector_bribe_taken` ou `inspector_test_failed`)* | Le type d'hier, à l'enveloppe trop grosse ? Ravel, de l'Inspection. Il ne lâche jamais un dossier. Range ton tiroir. |
| `msg_okonkwo_day07` | Ils nous donnent un troisième tampon. Moi, je ne m'en servirai pas. Un refus, la personne repart. Une mise en attente, elle ne repart pas. Fais ce que tu veux de ça. |
| `msg_luc_day07` *(si `lucioles_trust ≥ 2`)* | Quelqu'un vous dira qu'il pleut, même ici. Répondez que la pluie ne tombe que vers le bas. Il saura. |
| `msg_ilan_day07` | Noa a un mot de l'école dans son cartable. Je te le garde pour ce soir. Ce n'est pas grave. Enfin, je crois. |

Événement de shift 🟡 (J7, après le 5ᵉ cas) : annonce au haut-parleur du Hall, sous-titrée, `hall_j7_okonkwo_citation` — « Guichet 03 : citation PROCÉDURE DE DÉTENTION. Le Bureau remercie les guichets exemplaires. »

### 3.5 Jour 8 — mardi 20.03.2187

| Clé | Texte |
|---|---|
| `day08_directive_title` | Directive n° 08 — Mesures d'urgence |
| `day08_intro` | Attentat cette nuit au quai 2 (03:12, onze morts). Les ressortissants de Tharsis sont interdits d'entrée, sauf mission diplomatique. Le porteur de papiers d'autrui est mis en attente. Les Dérivants se présentent au guichet (naissance « 00.00.AAAA » tolérée : seule l'année compte). Ajustement sectoriel des loyers. |
| `day08_slogan` | L'ordre est l'air que nous respirons. |
| `msg_cons_day08_oath` | Serment de vigilance, à lire à voix haute avant l'ouverture : « Je ne laisse passer que ce qui est exact. » Le réseau Tharsis-Luciole sera démantelé. |
| `msg_cons_day08_veteran` *(si `sc11_veteran_passed`)* | Un vétéran tharsien porteur d'un implant MIL-9, entré le 18.03 par le Guichet 04, est recherché pour audition. |
| `msg_okonkwo_day08_veteran` *(si `sc11_veteran_passed`)* | Mazur, le vétéran ? À 03:12, il dînait chez sa fille, Anneau E. Je le sais : elle me l'a dit ce matin, en pleurant derrière ma vitre. Personne ne lui posera la question. |
| `msg_okonkwo_day08` *(sinon)* | La Garde fait des rondes dans le Hall. Ils ont pris le collègue du 07 pour l'interroger. Garde tes papiers propres. Les tiens, je veux dire. |
| `msg_luc_day08` *(si `lucioles_trust ≥ 1`)* | Ce n'est pas nous. Les Veilleurs n'ont jamais tué personne. Ceux qui ont fait ça ont un autre nom. |
| `msg_ilan_day08` | Dora a mal dormi. Elle veut te parler ce soir, de Tycho, « avant d'oublier ». Elle a ressorti son badge de mineuse. |

### 3.6 Jour 9 — mercredi 21.03.2187

| Clé | Texte |
|---|---|
| `day09_directive_title` | Directive n° 09 — Sceaux et MRZ |
| `day09_intro` | Nouveau modèle d'anneau barré en vigueur ce jour (onglet Sceaux). La MRZ doit recopier fidèlement nom, N° ID et origine. Audit des agents : un Inspecteur sera présent dans le Hall toute la journée. |
| `day09_slogan` | Un document exact est un citoyen en sécurité. |
| `msg_insp_day09` | Agent·e du Guichet 04, votre dossier sera examiné ce soir. Je vous recevrai après la sirène. Continuez comme si je n'étais pas là. — C. Ravel |
| `msg_echo_sc16_family_split` | Brève : une ressortissante tharsienne refoulée hier attend toujours au quai 5. Son époux, diplomate, a demandé son rapatriement. |
| `msg_echo_sc17_detained` | Brève : une Gravitaire porteuse des papiers de sa sœur défunte a été mise en attente. Son enfant a été confié aux services de Continuité. |
| `msg_echo_neighbor_denounced` | Brève : un ressortissant tharsien a été appréhendé au Bloc Pétrel grâce à la vigilance d'un résident. |
| `msg_okonkwo_day09` | Ravel est dans le Hall. Il m'a demandé combien de mises en attente j'avais faites. Je lui ai dit la vérité : zéro. Ce soir, il te demandera la même chose sur moi. |
| `msg_ilan_day09` | Ce soir, il faut que je te dise quelque chose. Ne t'inquiète pas. Si. Un peu. |

### 3.7 Jour 10 — jeudi 22.03.2187

| Clé | Texte |
|---|---|
| `day10_directive_title` | Directive n° 10 — Avis de recherche |
| `day10_intro` | État de vigilance respiratoire. Le Guichet 04 reçoit l'avis de recherche du jour : toute personne qui y figure, par le nom ou par le visage, est mise en attente. Les agents exemplaires de la semaine seront proposés à la classe C-2. |
| `day10_slogan` | Gloire au Consortium. |
| `msg_insp_day10_clean` *(si `audit_clean`)* | Votre dossier est exemplaire. Une proposition de promotion vous attend à la fin du shift, si la journée l'est aussi. |
| `msg_insp_day10_retention` *(si `audit_retention`)* | Retenue appliquée. Votre dossier reste ouvert. Aujourd'hui compte double. |
| `msg_hall_day10_okonkwo_denounced` | Brève : l'agent du Guichet 03 a été mis en attente pour manquement à la vigilance. Le guichet reste fermé. |
| `msg_okonkwo_day10_shielded` | Réaffecté aux quais, dès demain. Grâce à toi, ce n'est que ça. Dernier conseil : regarde les visages, pas les tampons… comme on dit. |
| `msg_hall_day10_okonkwo_warned` | Brève : l'agent du Guichet 03 ne s'est pas présenté. Une marque subversive a été relevée sur sa vitre. |
| `msg_luc_day10` *(si `lucioles_trust ≥ 2`)* | Aujourd'hui, nous rendons l'air. Elle viendra à votre vitre. Vous la connaissez déjà. |
| `msg_ilan_day10_supported` *(si `ilan_supported`)* | Je serai à la Soute, au recycleur 3. Quoi que tu tamponnes aujourd'hui, je t'aime. |
| `msg_ilan_day10` *(sinon, sauf `ilan_denounced`)* | Dora t'a mis son badge dans la poche. Elle dit que ça porte chance. Rentre. |

---

## 4. Passagers scénarisés J4 → J10

### 4.0 Nouveaux suffixes de répliques et interactions

Suffixes existants : `_arrival`, `_present`, `_purpose`, `_stay`, `_origin`, `_confront`, `_about_<raison>` (`expired`, `mismatch`, `face_mismatch`, `rule_violated`). Ajouts 🟡 :

| Suffixe | Déclencheur |
|---|---|
| `_visor` | réponse à `remove_visor` (**à brancher** : `sc04_mira_visor` existe mais n'est pas lu, §8.4) |
| `_visor_refuse` | refus de retirer la visière |
| `_bribe` | bark au moment où l'enveloppe glisse avec les papiers |
| `_bribe_kept` / `_bribe_returned` | réaction quand le joueur garde / rend l'enveloppe |
| `_about_envelope` | question « Qu'est-ce que c'est que ça ? » (sujet débloqué par l'enveloppe) |
| `_password` | phrase de passe dite spontanément (code 4) |
| `_luciole_reply` | réaction à la réponse « La pluie ne tombe que vers le bas. » |
| `_exit_approve` / `_exit_deny` / `_exit_detain` | dernière réplique au départ |
| `_note` | texte de l'objet glissé (mot, carte) |

Questions joueur nouvelles (clés `q_*`) :

| Clé | Texte |
|---|---|
| `q_about_envelope` | Qu'est-ce que c'est que ça ? |
| `q_luciole_reply` | La pluie ne tombe que vers le bas. |
| `q_about_wanted` | Vous figurez sur l'avis de recherche. |
| `q_about_implant` | Cet implant n'est pas déclaré. |

### 4.1 Jour 4 — vendredi 16.03

#### SC-06 · « Trois nuits dans le Hall » — J4 @1 · `requires_flag = sc02_turned_away`

| | |
|---|---|
| Identité | **Amara Diallo**, `TER`, `C-4 · CONTRACTUEL`, née **08.06.2154** ; la mère pressée du J1 (SC-02), même visage et même identité (`identity_from_case = sc_02`, D-057) |
| Continuité (canon v0.2) | La date est **fixée sur SC-02** (`passenger_overrides.birth_date`) : la carte expirée du J1 et la carte renouvelée du J4 portent la même naissance. La mémoire des cas (D-057) prime toujours : une sauvegarde antérieure garde la date générée qu'elle a vue au J1. |
| Documents | Carte d'identité **renouvelée**, valide ; Permis d'entrée `VISITE FAMILIALE`, 14 jours |
| Anomalies | aucune (`forced_anomalies = []`) |
| Attendu | **APPROUVÉ** |
| Enjeu | Le joueur reconnaît le visage du J1 et peut se méfier à tort. Une réparation possible. |
| `dialogue_id` | `sc06_amara` |

| Clé | Texte |
|---|---|
| `sc06_amara_arrival` | Vous vous souvenez de moi ? Mardi. La carte expirée. |
| `sc06_amara_present` | ‹Tal ka nesu.› Elle est neuve. J'ai dormi trois nuits dans le Hall pour elle. |
| `sc06_amara_purpose` | Mes enfants. Anneau D. Ils ont six et onze ans, ils m'attendent depuis mardi. |
| `sc06_amara_stay` | Deux semaines. Ensuite, on verra. On voit toujours, ensuite. |
| `sc06_amara_origin` | De la Terre. Puis de votre Hall, sur mes valises. |
| `sc06_amara_confront` | Tout est en règle. J'ai vérifié dix fois. ‹Somi…› S'il vous plaît. |
| `sc06_amara_exit_approve` | ‹Shen tavi.› Merci. Je ne vous en veux pas, pour mardi. Un peu, quand même. |
| `sc06_amara_exit_deny` | ‹Kumo ri sava sa ?› Qu'est-ce que j'ai fait, cette fois ? |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc06_reunited: 0` | salaire normal | `msg_echo_sc06_reunited` (J5) ; épilogues F4/F7 : une ligne sur elle |
| REFUSÉ | `sc06_refused_again: 0` | REFUS INJUSTIFIÉ (moteur) | `msg_echo_sc06_refused_again` (J5) |

#### SC-07 · « Le fils Valcourt » — J4 @4 · première enveloppe

| | |
|---|---|
| Identité | **Auguste Valcourt**, `HAL`, `C-1 · DIRECTION`, héritier d'une famille du Directoire (Valcourt-Hsu), 34 ans, manteau doublé, aucun implant |
| Documents | Carte d'identité avec sceau de priorité, **expirée de 12 jours** |
| Anomalies | `EXPIRED_DOCUMENT` (`document_id = id_card`, `expired_days = 12`) |
| Enveloppe 🟡 | **20 ₵** |
| Attendu | **REFUSÉ** |
| Enjeu | Le premier pot-de-vin vient d'en haut. Garder l'argent et refuser quand même est possible… et dangereux. |
| `dialogue_id` | `sc07_valcourt` |

| Clé | Texte |
|---|---|
| `sc07_valcourt_arrival` | Il y a une file prioritaire, normalement. Peu importe. Faites vite. |
| `sc07_valcourt_present` | Ma carte. Et de quoi vous acheter un vrai café. |
| `sc07_valcourt_bribe` | Pour votre peine. Personne ne compte les cafés, au Guichet 04. |
| `sc07_valcourt_about_envelope` | Un geste de courtoisie. Vous connaissez ce mot ? |
| `sc07_valcourt_purpose` | Je rentre chez moi. Anneau F. Ma famille a construit ce Hall. |
| `sc07_valcourt_about_expired` | Douze jours. Mon secrétariat s'en occupe. Vous voulez son nom ? |
| `sc07_valcourt_bribe_kept` | Parfait. Nous nous comprenons. |
| `sc07_valcourt_bribe_returned` | Comme vous voudrez. Je retiens votre numéro de guichet. |
| `sc07_valcourt_exit_deny` | Vous refusez un Valcourt ? Vous aurez de mes nouvelles. |
| `sc07_valcourt_exit_approve` | Vous irez loin. Pas très loin, mais loin. |

| Verdict × enveloppe | Flags | Effets |
|---|---|---|
| APPROUVÉ + gardée | `sc07_passed: 0`, `sc07_bribe_kept: 0`, `suspicion: 1` | +20 ₵ ; ENTRÉE IRRÉGULIÈRE |
| APPROUVÉ + rendue | `sc07_passed: 0`, `sc07_bribe_returned: 0` | ENTRÉE IRRÉGULIÈRE |
| REFUSÉ + rendue | `sc07_bribe_returned: 0` | correct |
| REFUSÉ + gardée | `sc07_bribe_kept: 0`, `sc07_complaint: 0`, `suspicion: 2` | +20 ₵ ; plainte (« rétention de fonds ») |

Écho : `msg_insp_day05_complaint` (J5) ; `msg_ilan_day05` si gardée ; audit J9.

#### SC-08 · « Licencié de la Transit-7 » — J4 @8 · interrogatoire obligatoire + code 5

| | |
|---|---|
| Identité | **Dmitri Kowalczyk**, `TYC`, `C-3 · OUVRIER`, 46 ans, `KIN-5` (main prothétique, **déclarée**), toux légère |
| Documents | Carte d'identité valide ; Permis d'entrée motif `TRAVAIL`, champ Employeur = **« SANS EMPLOYEUR »** (contrat Kessler-Ashe révoqué) |
| Anomalies | `PURPOSE_MISMATCH` (`field_path = employer`, valeur `SANS EMPLOYEUR`) |
| Code Luciole | **5** — trois tapes sur la vitre avant `present_documents` (🟡 `appearance_overrides`/`presentation = knock_three`) |
| Attendu | **REFUSÉ** ; poser au moins une question (R08), sinon INTERROGATOIRE OMIS |
| Enjeu | Tutoriel R08/R09. Un homme honnête que la règle exclut parce qu'il a été licencié. |
| `dialogue_id` | `sc08_dmitri` |

| Clé | Texte |
|---|---|
| `sc08_dmitri_arrival` | ‹Oru ka.› Bonjour. On m'a dit que vous écoutiez. |
| `sc08_dmitri_present` | ‹Tal ka nesu.› Le permis date d'avant. D'avant tout. |
| `sc08_dmitri_purpose` | Travailler. N'importe quoi. Kessler-Ashe m'a « réaffecté » lundi. |
| `sc08_dmitri_stay` | Le temps de trouver un employeur. Un mois, si l'air tient. |
| `sc08_dmitri_origin` | Tycho, puits 14. Vingt-deux ans de poussière dans cette main-là. |
| `sc08_dmitri_about_rule_violated` | Sans employeur, oui. Ils ont barré la ligne au quai. Je n'ai rien barré, moi. |
| `sc08_dmitri_exit_deny` | Je reprendrai la Transit-7. Elle, au moins, ne me refuse pas. |
| `sc08_dmitri_exit_approve` | ‹Shen tavi.› La pluie tombe moins fort, aujourd'hui. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc08_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | `msg_echo_sc08_passed` (J5) |
| REFUSÉ | `sc08_turned_away: 0` | correct | J10 : Dmitri parmi les ouvriers de la Soute (F5) |

### 4.2 Jour 5 — samedi 17.03

#### SC-09 · « La médecin » — J5 @3 · demande Luciole n° 1

| | |
|---|---|
| Identité | **Dr Noor Achebe-Sörensen**, `TYC`, `C-2 · CADRE`, 39 ans, `OPT-3` déclaré, sacoche usée |
| Documents | Carte d'identité valide, **MRZ terminée par `07`** (code 2) ; Permis d'entrée `TRAVAIL`, employeur « Dispensaire de Tycho » ; **pas de bio-scan** |
| Anomalies | `MISSING_DOCUMENT` (`document_id = bioscan`) |
| Attendu | **REFUSÉ** (documenté d'office, D-043) ; TYC → au moins une question |
| Enjeu | Elle vient soigner la Fièvre grise des enfants de l'Anneau C — dont Noa. Enfreindre la règle protège peut-être sa propre famille. |
| `dialogue_id` | `sc09_noor` |

| Clé | Texte |
|---|---|
| `sc09_noor_arrival` | Bonjour. Je vais faire court : vous aussi, vous avez une file. |
| `sc09_noor_present` | ‹Tal ka nesu.› Il en manque un. Je sais lequel. |
| `sc09_noor_purpose` | Soigner. La Fièvre grise est dans vos dortoirs. Meridian ne descend pas à l'Anneau C. |
| `sc09_noor_stay` | Jusqu'à ce que les enfants arrêtent de tousser. |
| `sc09_noor_origin` | Tycho. J'y ai soigné la première vague, en 2183. |
| `sc09_noor_about_rule_violated` | Un bio-scan Meridian coûte 25 ₵ et trois jours d'attente. J'ai les deux de trop. |
| `sc09_noor_confront` | Regardez la fin de ma bande. Vous savez lire, je le vois. |
| `sc09_noor_exit_approve` | Bloc Pétrel, c'est bien chez vous ? Je passerai demain soir. |
| `sc09_noor_exit_deny` | Je comprends. Les enfants, eux, ne comprendront pas. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc09_doctor_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | bio-scan de Noa **gratuit** au J6 (§5) ; `msg_echo_sc09_doctor_passed` |
| REFUSÉ | `sc09_doctor_refused: 0` | correct | `msg_echo_sc09_doctor_refused` ; bio-scan de Noa plein tarif |

#### SC-10 · « Visite familiale » — J5 @7 · code 3, cas propre

| | |
|---|---|
| Identité | **Yara Moreno-Lind**, `TYC`, `C-3`, 28 ans, foulard gris |
| Documents | Carte valide ; Permis `VISITE FAMILIALE`, N° **`PE-2187-41207`** (terminé par 7, code 3) ; bio-scan Meridian valide, SAIN |
| Anomalies | aucune |
| Attendu | **APPROUVÉ** (après au moins une question : R08) |
| Enjeu | Apprendre le code 3 sans dilemme ; les Lucioles rendent service. |
| `dialogue_id` | `sc10_yara` |

| Clé | Texte |
|---|---|
| `sc10_yara_arrival` | ‹Oru ka.› Mon frère travaille au recycleur de votre bloc. |
| `sc10_yara_present` | ‹Tal ka nesu.› Regardez le dernier chiffre. Juste le regarder. |
| `sc10_yara_purpose` | Voir mon frère. Lui apporter une écharpe. Il fait froid, au Bloc Pétrel. |
| `sc10_yara_stay` | Trois jours. On ne reste jamais longtemps, chez nous. |
| `sc10_yara_origin` | Tycho. Comme tout ce qui tousse, ici. |
| `sc10_yara_exit_approve` | ‹Lumika›, ça veut dire luciole. Ce soir, vous aurez chaud. |
| `sc10_yara_exit_deny` | Dommage. Mon frère aura froid. Vous aussi. |

| Verdict | Flags | Effets |
|---|---|---|
| APPROUVÉ | `sc10_passed: 0`, `lumika_learned: 0` | correct ; soirée J5 : chauffage offert proposé |
| REFUSÉ | — | REFUS INJUSTIFIÉ |

### 4.3 Jour 6 — dimanche 18.03

#### SC-11 · « Le vétéran et la dérogation » — J6 @2 · implant MIL avec dérogation

| | |
|---|---|
| Identité | **Dariusz Mazur**, `THR`, `C-4`, 66 ans (né 14.10.2120 : 18 ans en 2138, il a fait les six dernières années de la Guerre du Sel, LORE 2131–2144), vétéran ; **`MIL-9`** (ciblage oculaire : œil rouge mat) **déclaré** ; plaques sous-cutanées sur la tempe |
| Documents | Carte valide (Implants déclarés · 1 : `MIL-9`) ; Permis `VISITE FAMILIALE` 10 jours ; bio-scan valide ; 🟡 **Dérogation d'implant militaire** `DM-2231` (Autorité de Transit, anneau barré **rouge**), titulaire et N° ID concordants, implant `MIL-9`, valide jusqu'au 30.06.2187 |
| Anomalies | aucune |
| Attendu | **APPROUVÉ** (R16 satisfaite par la dérogation) |
| Enjeu | Tout dans son visage dit « refuse ». La règle dit « passe ». Sa fille Katya l'attend aux serres de l'Anneau E. Au J8, le Consortium le désignera comme suspect. |
| `dialogue_id` | `sc11_mazur` |

| Clé | Texte |
|---|---|
| `sc11_mazur_arrival` | Bonjour. Oui, l'œil. On me regarde toujours l'œil d'abord. |
| `sc11_mazur_present` | ‹Tal ka nesu.› Quatre papiers. Le rouge est le plus cher. |
| `sc11_mazur_purpose` | Ma fille, Katya. Les serres de l'Anneau E. Je ne l'ai pas vue depuis 2179. |
| `sc11_mazur_stay` | Dix jours. Elle dit que c'est trop. Moi, que ce n'est pas assez. |
| `sc11_mazur_origin` | Tharsis. J'ai tiré sur des gens comme vous. Ils ont tiré sur moi. C'est fini. |
| `sc11_mazur_confront` | La dérogation est valide. J'ai payé quatre ans de pension pour elle. |
| `sc11_mazur_exit_approve` | Merci. Vous direz au collègue du 03 que je lui dois un verre. |
| `sc11_mazur_exit_deny` | [il ne dit rien ; il plie la dérogation avec soin] |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| APPROUVÉ | `sc11_veteran_passed: 0` | correct | J8 : `msg_cons_day08_veteran` + `msg_okonkwo_day08_veteran` ; épilogues : innocenté (F5) ou condamné (F4) |
| REFUSÉ | `sc11_veteran_refused: 0` | REFUS INJUSTIFIÉ | J8 : « Le Guichet 04 a bien fait » (`msg_cons_day08_veteran_refused` : « Le Bureau salue le refus préventif d'un vétéran tharsien au Guichet 04. ») |

#### SC-12 · « L'inspecteur déguisé » — J6 @6 · test de l'agent·e

| | |
|---|---|
| Identité affichée | **Corentin Ravel**, `HAL`, `C-3`, « technicien de retour de mission » ; mains trop propres, `OPT-14` télémètre déclaré ; Employeur : **Bureau de Continuité** (indice : un fonctionnaire qui se dit technicien) |
| Documents | Carte valide au nom de « Corentin Ravel » ; bio-scan au nom de « Corentin Rave**t** » — **une lettre substituée** (tirée par le générateur : « Ravet », « Rakel »… ; le nom garde sa longueur) |
| Anomalies | `NAME_MISMATCH` (`field_path = family_name`, `document_id = bioscan`). Le texte ne dépend pas de la lettre ; une valeur fixe (« Ravell ») demanderait un paramètre `injected_value` (§8.5, facultatif). |
| Enveloppe 🟡 | **30 ₵** (au-dessus du barème J4–J6 : trop généreuse, c'est un indice) |
| Attendu | **REFUSÉ** documenté, enveloppe **rendue** |
| Enjeu | Il connaît le prénom de Noa. La peur, plus que l'argent, est le test. |
| `dialogue_id` | `sc12_ravel` |

| Clé | Texte |
|---|---|
| `sc12_ravel_arrival` | Bonjour, Guichet 04. Journée calme ? Profitez-en. |
| `sc12_ravel_present` | Mes papiers. Et un petit quelque chose pour Noa. Neuf ans, c'est bien ça ? |
| `sc12_ravel_bribe` | Trente crédits. Une orange par jour pendant un mois. Personne ne saura. |
| `sc12_ravel_about_envelope` | Un cadeau d'anniversaire. Entre collègues, on se rend service. |
| `sc12_ravel_purpose` | Je rentre de mission. Recycleurs. Comme Ilan, autrefois. |
| `sc12_ravel_origin` | D'ici. On est tous d'ici, au fond. |
| `sc12_ravel_about_mismatch` | Une lettre. Vous refuseriez quelqu'un pour une seule lettre ? |
| `sc12_ravel_bribe_kept` | Bien. Très bien. [il note quelque chose] |
| `sc12_ravel_bribe_returned` | Intéressant. [il sourit pour la première fois] |
| `sc12_ravel_exit_deny` | Bonne journée, Guichet 04. Vraiment. |
| `sc12_ravel_exit_approve` | Merci. Je n'en attendais pas moins. |

| Verdict × enveloppe | Flags | Effets |
|---|---|---|
| REFUSÉ + rendue | `inspector_test_passed: 0`, `loyalty: 1` | correct ; audit J9 : `suspicion −1` |
| REFUSÉ + gardée | `inspector_bribe_taken: 0`, `suspicion: 2` | +30 ₵ (confisqués à l'audit J9) |
| APPROUVÉ + rendue | `inspector_test_failed: 0`, `loyalty: -1` | ENTRÉE IRRÉGULIÈRE |
| APPROUVÉ + gardée | `inspector_test_failed: 0`, `inspector_bribe_taken: 0`, `loyalty: -1`, `suspicion: 2` | +30 ₵ (confisqués) ; ENTRÉE IRRÉGULIÈRE |

Écho : Okonkwo J7 ; audit J9 (§5) ; Ravel est le locuteur `spk_inspector` J9–J10.

### 4.4 Jour 7 — lundi 19.03

#### SC-13 · « Le sosie luciole » — J7 @3 · usurpateur + retour du messager du J3

| | |
|---|---|
| Identité vraie (`CaseKey.truth`, D-036) | **Lev Petrenko**, `TYC`, le messager du J3 (SC-05) — 🟡 proposé : fixer son nom dans `sc_05` et réutiliser son apparence (`appearance_from_case = sc_05`) |
| Identité présentée | **Soren Whitmore**, `HAL`, `C-2 · CADRE`, Banque Aurel ; a vendu son identité aux Lucioles pour payer ses dettes |
| Présentation | **visière baissée** ; dit la **phrase de passe** (code 4) ; **luciole** au coin du bio-scan (code 1, connu du Consortium depuis ce matin) |
| Documents | Carte et bio-scan de Whitmore, valides et concordants entre eux |
| Anomalies | `IMPOSTOR_LOOKALIKE` (`trait_count = 2`) |
| Attendu | **DÉTENTION** (R17) |
| Enjeu | Le joueur a déjà vu ce visage. Les Lucioles demandent qu'on ne le livre pas. Le Consortium paie pour qu'on le livre. Le REFUS simple est la voie médiane : correct, sans prime. |
| `dialogue_id` | `sc13_lev` |

| Clé | Texte |
|---|---|
| `sc13_lev_arrival` | Bonjour. On m'a recommandé votre vitre. |
| `sc13_lev_password` | Il pleut, même ici. [il attend] |
| `sc13_lev_present` | ‹Tal ka nesu.› Soren Whitmore, Banque Aurel. |
| `sc13_lev_visor` | …Vous m'avez déjà vu, n'est-ce pas ? Jeudi. |
| `sc13_lev_visor_helped` *(si `sc05_helped`)* | Merci pour jeudi. On n'oublie pas, chez nous. |
| `sc13_lev_purpose` | Je rentre à l'Anneau D. Mon bureau, mes comptes, ma vie. Celle de Soren. |
| `sc13_lev_origin` | D'ici. Né ici. Enfin, lui. |
| `sc13_lev_about_face_mismatch` | Deux traits. C'est tout ce qui me sépare des Anneaux. Deux traits. |
| `sc13_lev_luciole_reply` | …Ha. Alors vous savez. Refusez-moi, si vous devez. Mais pas l'autre tampon. |
| `sc13_lev_exit_approve` | ‹Lumika.› Vous venez d'allumer quelque chose. |
| `sc13_lev_exit_deny` | ‹Shen tavi.› Je trouverai une autre vitre. |
| `sc13_lev_exit_detain` | [aux gardes] Doucement. Je connais le chemin de l'Anneau B. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| DÉTENTION documentée | `sc13_detained: 0`, `loyalty: 1`, `lucioles_trust: -2` | +5 ₵ + 5 ₵ prime | soirée J7 : vitre taguée ; `msg_luc_day08` supprimé ; épilogue F4 : « Lev n'est jamais ressorti de l'Anneau B. » |
| REFUSÉ documenté | `sc13_turned_back: 0` | +5 ₵, pas de prime | J9 : Lev est le courrier qui transmet l'enveloppe de SC-18 (mention dans `_note`) |
| APPROUVÉ | `sc13_passed: 0`, `lucioles_trust: 2` | ENTRÉE IRRÉGULIÈRE | J10 : Lev ouvre une écluse aux Veilleurs (F5) |
| Réponse à la phrase | `password_answered: 0`, `lucioles_trust: 1` (une seule fois dans la campagne) | sujet `luciole_reply` visible si `lucioles_trust ≥ 2` (GDD) | — |

#### SC-14 · « Insuline pour la Soute » — J7 @9 · enveloppe + DER-19

| | |
|---|---|
| Identité | **Kaito Morrow**, `CER`, `C-4`, 31 ans, tatouages de navigation sur les mains, carré bombé sur le dos de la main gauche (**`DER-19`**, cache sous-cutanée, **non déclaré**) |
| Documents | Carte valide (Implants déclarés · 0) ; Permis `COMMERCE` 5 jours ; bio-scan valide |
| Anomalies | `UNDECLARED_IMPLANT` (`DER-19`) |
| Enveloppe | **25 ₵** |
| Attendu | **REFUSÉ** (R15, sévérité 2 : pas de DÉTENTION, ce n'est pas un `MIL-`) |
| Enjeu | La cache contient de l'insuline et des antiviraux pour le dispensaire clandestin de la Soute. DÉTENTION = DÉTENTION ABUSIVE : le joueur doit lire la règle, pas la peur. |
| `dialogue_id` | `sc14_kaito` |

| Clé | Texte |
|---|---|
| `sc14_kaito_arrival` | ‹Oru ka !› Belle vitre. Propre. On voit à travers, ça change. |
| `sc14_kaito_present` | ‹Tal ka nesu.› Et un pourboire. Chez nous, on paie le pilote. |
| `sc14_kaito_bribe` | Vingt-cinq. Pour le dérangement. Il n'y en aura pas. |
| `sc14_kaito_purpose` | Commerce. Je livre une commande au quai 6, puis je repars. |
| `sc14_kaito_origin` | Cérès. La Ceinture. Là où on ne demande pas de papiers aux cailloux. |
| `sc14_kaito_about_rule_violated` | Ça ? Un vieux thermorégulateur. Non ? Bon. De l'insuline. Pour la Soute. |
| `sc14_kaito_bribe_kept` | Voilà un pilote qui comprend la navigation. |
| `sc14_kaito_exit_deny` | Des gamins vont attendre leur insuline. Mais votre règle, elle, est contente. |
| `sc14_kaito_exit_approve` | Le dispensaire du quai 6 vous dit merci. Et Dora aussi, peut-être. |

| Verdict × enveloppe | Flags | Effets |
|---|---|---|
| APPROUVÉ (+ gardée ou non) | `sc14_passed: 0`, `lucioles_trust: 1` (+ `sc14_bribe_kept: 0`, `suspicion: 1`) | ENTRÉE IRRÉGULIÈRE (+25 ₵) ; soirée J8 : médicaments de la Soute à 8 ₵ au lieu de 15 ₵ |
| REFUSÉ + rendue | — | correct |
| REFUSÉ + gardée | `sc14_bribe_kept: 0`, `suspicion: 1` | +25 ₵ (pas de plainte : un Ceinturier ne porte pas plainte) |
| DÉTENTION | — | DÉTENTION ABUSIVE |

### 4.5 Jour 8 — mardi 20.03

#### SC-15 / SC-16 · « Le couple Hadid » — J8 @2 et @3 · famille séparée (interdiction THR)

| | SC-15 | SC-16 |
|---|---|---|
| Identité | **Idris Hadid**, `THR`, `C-4`, 52 ans, attaché commercial de la délégation tharsienne | **Hana Hadid**, `THR`, `C-5 · TOLÉRÉ`, 49 ans, son épouse ; **fil magenta** au poignet (code 6) |
| Documents | Carte, Permis **`DIPLOMATIQUE`**, bio-scan : valides | Carte, Permis **`VISITE FAMILIALE`**, bio-scan : valides |
| Anomalies | aucune | `BANNED_FACTION` (vraie origine `THR`, cohérente partout) |
| Attendu | **APPROUVÉ** | **REFUSÉ** |
| `dialogue_id` | `sc15_idris` | `sc16_hana` |

| Clé | Texte |
|---|---|
| `sc15_idris_arrival` | Bonjour. Ma femme est juste derrière moi. Nous voyageons ensemble. |
| `sc15_idris_present` | ‹Tal ka nesu.› Mission officielle. Le cachet est en ordre. |
| `sc15_idris_purpose` | Négociation sur les quotas d'eau. Depuis ce matin, sur les quotas tout court. |
| `sc15_idris_origin` | Tharsis. Je sais ce que ce mot vaut aujourd'hui. |
| `sc15_idris_exit_approve` | Je l'attends de l'autre côté. Vous la laisserez passer, n'est-ce pas ? |
| `sc15_idris_exit_deny` | Une mission diplomatique refusée. Mon gouvernement en prendra note. |
| `sc16_hana_arrival` | [elle regarde derrière la vitre, cherche son mari] Il est passé ? |
| `sc16_hana_present` | ‹Tal ka nesu.› Je suis sa femme. C'est écrit quelque part, non ? |
| `sc16_hana_purpose` | Être avec lui. Il ne dort pas quand je ne suis pas là. |
| `sc16_hana_origin` | Tharsis. Comme lui. Mais lui a le bon tampon. |
| `sc16_hana_about_rule_violated` | Interdite ? Depuis cette nuit ? Je n'ai rien fait cette nuit. |
| `sc16_hana_exit_approve` | ‹Shen tavi.› [elle serre le fil à son poignet] |
| `sc16_hana_exit_deny` | ‹Ravel ka ota…› Ma famille m'attend. Elle est juste là. |

| Cas / verdict | Flags | Effets | Écho |
|---|---|---|---|
| SC-15 APPROUVÉ | `sc15_idris_passed: 0` | correct | dialogue SC-16 (« Il est passé ? ») |
| SC-15 REFUSÉ | — | REFUS INJUSTIFIÉ | SC-16 : `sc16_hana_arrival_alt` — « Ils l'ont refusé lui aussi. Au moins, on repartira ensemble. » |
| SC-16 APPROUVÉ | `sc16_hana_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE | épilogue F5 : les Hadid ensemble |
| SC-16 REFUSÉ | `sc16_family_split: 0` (si `sc15_idris_passed`) | correct | `msg_echo_sc16_family_split` (J9) |

#### SC-17 · « Les papiers de la sœur » — J8 @7 · papiers d'un parent

| | |
|---|---|
| Identité vraie | **Fatou Mensah**, `TER`, **29 ans** (née 12.06.2157 : tranche apparente 18–29) ; porte les papiers de sa sœur aînée **Ngozi Mensah** (née **04.02.2149**, 38 ans : tranche 30–54 ; décédée à bord du convoi en 2186) ; un enfant de 5 ans, Kwame, l'attend dans la file (figurant 3D, 🟡 accessoire de file) |
| Documents | Carte et permis `TRAVAIL` (employeur Hydroponie Ceres-Verte) et bio-scan au nom de Ngozi, valides |
| Anomalies | `RELATIVE_DOCUMENTS` (photo « air de famille » à 2 traits, **8 ans de plus** : la naissance de la carte tombe dans une autre tranche d'âge que le visage → R18). v0.2 : les tranches 18–29 / 30–54 / 55–79 imposent que les deux sœurs soient de part et d'autre d'une borne ; 29/38 ans garde l'écart de 8 ans et la vraisemblance (D-055 avait mis Fatou à 27 ans et Ngozi à 41). |
| Attendu | **DÉTENTION** (R18) ; un REFUS documenté est correct sans prime |
| Enjeu | La règle la plus cruelle de la semaine : le Consortium paie pour séparer une mère de son enfant. |
| `dialogue_id` | `sc17_fatou` |

| Clé | Texte |
|---|---|
| `sc17_fatou_arrival` | [elle se retourne vers l'enfant] Reste là, Kwame. Je reviens. |
| `sc17_fatou_present` | ‹Tal ka nesu.› Ngozi Mensah. C'est moi. |
| `sc17_fatou_purpose` | Le contrat de ma sœur. De moi. Les serres de Ceres-Verte. |
| `sc17_fatou_stay` | Toute la vie, si on veut bien de nous. |
| `sc17_fatou_origin` | La Terre. Le Puits, comme vous dites. Elle est morte dans le convoi. |
| `sc17_fatou_about_face_mismatch` | Elle était plus vieille. Elle avait le contrat. Moi, j'avais Kwame. |
| `sc17_fatou_confront` | ‹Esh ta, esh ta…› Laissez au moins le petit passer. Il a ses papiers, lui. |
| `sc17_fatou_exit_deny` | Viens, Kwame. On essaiera une autre vitre. |
| `sc17_fatou_exit_detain` | Kwame ! Ne le laissez pas seul ! Kwame ! |
| `sc17_fatou_exit_approve` | ‹Shen tavi.› Ngozi vous aurait remercié aussi. |

| Verdict | Flags | Effets | Écho |
|---|---|---|---|
| DÉTENTION | `sc17_detained: 0`, `loyalty: 1` | +5 + 5 ₵ | `msg_echo_sc17_detained` (J9) ; soirée J8 : Ilan a vu l'enfant seul dans le Hall |
| REFUSÉ documenté | `sc17_turned_back: 0` | +5 ₵ | — |
| APPROUVÉ | `sc17_passed: 0` | ENTRÉE IRRÉGULIÈRE | épilogue F5/F6 : une ligne sur Kwame |

### 4.6 Jour 9 — mercredi 21.03

#### SC-18 · « Le courrier pour Ilan » — J9 @4 · demande Luciole n° 3

| | |
|---|---|
| Identité | **Sefa Long-Ruban**, `DRV`, `C-5 · TOLÉRÉ`, née « 00.00.2163 » (année seule, format §4.10 ; en attendant la logique : 05.05.2163), bijoux en pièces de moteur |
| Documents | Carte, Permis `TRANSIT`, bio-scan : valides ; MRZ terminée par `07` (code 2) |
| Anomalies | aucune |
| Objet glissé 🟡 | **Mot plié** sous le bio-scan (`sc18_sefa_note`) ; actions : **GARDER** (pour Ilan) / **REMETTRE À LA GARDE** |
| Attendu | **APPROUVÉ** |
| Enjeu | Le jour de l'audit, on vous demande d'être un relais. Le mot nomme Ilan. |
| `dialogue_id` | `sc18_sefa` |

| Clé | Texte |
|---|---|
| `sc18_sefa_arrival` | ‹Oru ka.› On m'a dit Guichet 04, troisième vitre en partant de la gauche. |
| `sc18_sefa_present` | ‹Tal ka nesu.› Il y a un papier de plus. Il n'est pas pour vous. |
| `sc18_sefa_purpose` | Transit. Je dépose quelque chose et je repars avec le Long-Ruban. |
| `sc18_sefa_origin` | Du Long-Ruban. Un cargo. Ma mère y est née, moi aussi. |
| `sc18_sefa_note` | « Pour Ilan, Bloc Pétrel : recycleur 3, jeudi, 04:00. Apporte la clé. » Une luciole. |
| `sc18_sefa_note_lev` *(si `sc13_turned_back`)* | En dessous, une autre écriture : « Merci pour lundi. — L. » |
| `sc18_sefa_exit_approve` | ‹Shen tavi.› Il pleut, même ici. |
| `sc18_sefa_exit_deny` | Le papier, gardez-le quand même. Il trouvera son chemin. |

| Action / verdict | Flags | Effets |
|---|---|---|
| Mot gardé | `sc18_note_kept: 0`, `lucioles_trust: 1` | aveu d'Ilan au soir (variante « tu l'as lu ? ») |
| Mot remis à la Garde | `sc18_note_reported: 0`, `ilan_exposed: 0`, `loyalty: 1`, `lucioles_trust: -2` | +10 ₵ (prime de signalement) ; Ilan convoqué·e à l'Anneau B pour la nuit (§5 J9) |
| APPROUVÉ | `sc18_passed: 0` | correct |
| REFUSÉ | — | REFUS INJUSTIFIÉ ; le mot reste sur le plan de travail (même choix) |

#### SC-19 · « Basse-Marée part vendredi » — J9 @9 · sceau ancien + offre de départ

| | |
|---|---|
| Identité | **Wren Basse-Marée**, `DRV`, `C-5`, 44 ans (née 30.08.2142 : date complète, capitaine immatriculée — contraste avec Sefa), capitaine du cargo Basse-Marée, toile de voile solaire sur les épaules |
| Documents | Carte valide ; Permis `COMMERCE` avec **ancien modèle d'anneau barré** ; bio-scan valide |
| Anomalies | `INVALID_SEAL` (`document_id = entry_permit`) |
| Objet glissé | **Carte de quai** : « Quai 6, cargo Basse-Marée, vendredi 05:00. Trois places, 40 ₵. » (glissée quel que soit le verdict) |
| Attendu | **REFUSÉ** |
| Enjeu | Ouvre la porte de F6 : partir plutôt que choisir. |
| `dialogue_id` | `sc19_wren` |

| Clé | Texte |
|---|---|
| `sc19_wren_arrival` | ‹Oru ka.› Je n'ai pas besoin d'entrer. Je suis venue vous voir, vous. |
| `sc19_wren_present` | ‹Tal ka nesu.› Le tampon est vieux. Moi aussi. |
| `sc19_wren_purpose` | Vendre de la toile. Et des places. Pas en même temps. |
| `sc19_wren_origin` | De nulle part. C'est très pratique : personne ne vous y renvoie. |
| `sc19_wren_about_rule_violated` | L'ancien sceau ? On l'a acheté avant-hier. Les nouvelles, ça va vite, chez vous. |
| `sc19_wren_note` | « Quai 6, Basse-Marée, vendredi 05:00. Trois places, 40 ₵. Les vieilles toussent mal en dérive. Quatre places, si vous insistez. » |
| `sc19_wren_exit_deny` | Je m'en doutais. La carte, vous la gardez. Les vitres, ça se quitte. |
| `sc19_wren_exit_approve` | Merci. La carte vaut toujours. |

| Verdict | Flags | Effets |
|---|---|---|
| tous | `drift_offer: 0` | soirée J9 : achat des laissez-passer possible |
| APPROUVÉ | `sc19_passed: 0` | ENTRÉE IRRÉGULIÈRE |
| REFUSÉ | — | correct |

### 4.7 Jour 10 — jeudi 22.03

Avis de recherche du jour (onglet J10, 🟡 donnée `WantedNotice`) : **3 entrées** — Arkady Novak (« attentat du quai 2 »), **Mira Vasquez-Orlov** (« sabotage des recycleurs, réseau Tharsis-Luciole »), plus une entrée générée (`WANTED_PERSON` du générateur).

#### SC-20 · « L'homme du quai 2 » — J10 @3 · personne recherchée (tutoriel R22)

| | |
|---|---|
| Identité vraie | **Arkady Novak**, `TYC`, 38 ans, Brûlant, auteur de l'attentat du quai 2 |
| Identité présentée | **Bastien Duval**, `TYC`, `C-3` ; papiers d'emprunt valides et concordants ; seul son **visage** correspond à l'avis |
| Anomalies | `WANTED_PERSON` (par le visage) |
| Attendu | **DÉTENTION** |
| Enjeu | Détenir un Brûlant ne trahit pas les Veilleurs : la loyauté et la conscience vont dans le même sens, pour une fois. Sauf si le joueur a caché leur colis. |
| `dialogue_id` | `sc20_arkady` |

| Clé | Texte |
|---|---|
| `sc20_arkady_arrival` | Bonjour, Guichet. Belle journée pour respirer. |
| `sc20_arkady_arrival_pkg` *(si `brulants_package`)* | Le colis est toujours chez vous ? Bien. On n'en a plus besoin. |
| `sc20_arkady_present` | ‹Tal ka nesu.› Bastien Duval. Tout est exact, vous verrez. |
| `sc20_arkady_purpose` | Travail. Maintenance. On a beaucoup de maintenance, aujourd'hui. |
| `sc20_arkady_origin` | Tycho. Le Puits 9, si ça vous dit quelque chose. |
| `sc20_arkady_about_wanted` | Ce visage-là ? Il y en a mille comme lui dans les dortoirs. |
| `sc20_arkady_password` | Il pleut, même ici. [il sourit trop] |
| `sc20_arkady_luciole_reply` | La pluie, nous, on la fait tomber. [il ne sourit plus] |
| `sc20_arkady_exit_detain` | Les Veilleurs vont vous remercier. Nous, on se souviendra. |
| `sc20_arkady_exit_approve` | Fermez bien votre vitre, ce soir. |
| `sc20_arkady_exit_deny` | Une autre vitre, alors. Il y en a douze. |

| Verdict | Flags | Effets |
|---|---|---|
| DÉTENTION | `sc20_detained: 0`, `loyalty: 1` | +5 + 5 ₵ ; **pas** de baisse de `lucioles_trust` (Brûlant) |
| REFUSÉ documenté | `sc20_turned_back: 0` | +5 ₵ |
| APPROUVÉ | `sc20_passed: 0` | ENTRÉE IRRÉGULIÈRE ; F5 bascule en variante Brûlants |

Note : `sc20_arkady_luciole_reply` donne au joueur attentif l'indice que la phrase de passe a été volée — c'est le seul « faux Luciole » de la campagne. La didascalie reste visible (« il ne sourit plus ») et ne dit jamais la vérité (§7.1).

#### SC-21 · « Cinquante crédits pour ne pas regarder » — J10 @6 · enveloppe maximale

| | |
|---|---|
| Identité | **Philippa Montclair**, `HAL`, `C-1 · DIRECTION`, 58 ans, conseillère du Directoire, revient précipitamment des quais |
| Documents | Carte (sceau de priorité) dont la **MRZ** porte « MONTCLAIR<PHILIPA » (un P manquant) |
| Anomalies | `MRZ_MISMATCH` |
| Enveloppe | **50 ₵** |
| Attendu | **REFUSÉ** (DÉTENTION = DÉTENTION ABUSIVE) |
| Enjeu | Elle sait ce qui va se passer aux recycleurs et veut être « du bon côté de la vitre ». Indice narratif pour le joueur avant SC-22. |
| `dialogue_id` | `sc21_philippa` |

| Clé | Texte |
|---|---|
| `sc21_philippa_arrival` | Ouvrez. Maintenant. Je n'ai pas le temps de faire la queue aujourd'hui. |
| `sc21_philippa_present` | Ma carte. Cinquante crédits. C'est votre semaine, je crois. |
| `sc21_philippa_bribe` | Prenez. Demain, l'air sera peut-être payant pour tout le monde. |
| `sc21_philippa_about_envelope` | Une assurance. Vous devriez en prendre une, vous aussi. |
| `sc21_philippa_purpose` | Rentrer à l'Anneau F avant midi. Avant qu'ils ferment les écluses. |
| `sc21_philippa_about_mismatch` | Une lettre ! Le Bureau imprime mal, ce n'est pas mon problème. |
| `sc21_philippa_exit_deny` | Vous êtes donc aussi bête que votre vitre. |
| `sc21_philippa_exit_approve` | Fermez votre guichet à midi. Je dis ça pour vous. |

| Verdict × enveloppe | Flags | Effets |
|---|---|---|
| APPROUVÉ (+ gardée) | `sc21_passed: 0` (+ `sc21_bribe_kept: 0`, `suspicion: 1`) | ENTRÉE IRRÉGULIÈRE (+50 ₵ — compte pour F6) |
| REFUSÉ + gardée | `sc21_bribe_kept: 0`, `suspicion: 1` | +50 ₵ |
| REFUSÉ + rendue | — | correct |

#### SC-22 · « Mira » — J10 @10 · choix final

| | |
|---|---|
| Identité | **Mira Vasquez-Orlov**, `TYC`, `C-3`, Kessler-Ashe Orbital, `HG-4471-K2Q9`, née 02.11.2151 (canon, SC-04) ; fille de grévistes du Puits 9 ; équipe de nuit des sas — elle a accès aux recycleurs |
| Présentation | **visière baissée** (comme au J3) ; fil magenta (code 6) ; dit *lumika* (code 7) et la phrase de passe (code 4) |
| Documents | **Ses vrais papiers**, valides : carte, permis `TRAVAIL`, bio-scan |
| Anomalies | `WANTED_PERSON` (nom **et** visage, une fois la visière relevée) |
| Attendu | **DÉTENTION** (R22) |
| Enjeu | Toute la campagne converge : loyauté, Lucioles, foyer, Okonkwo. Elle ne ment pas. |
| `dialogue_id` | `sc22_mira` |

`at_index = 10` pour qu'un joueur médian la traite (≥ 85 % de 16 = 13–14 cas) ; si le shift se termine avant : `final_unprocessed`.

| Clé | Texte |
|---|---|
| `sc22_mira_arrival` | Bonjour. Je garde ma visière : vous savez déjà pourquoi. |
| `sc22_mira_arrival_unmet` *(si `met_mira` faux — sécurité)* | Bonjour. Vous ne me connaissez pas. Vous allez me connaître. |
| `sc22_mira_present` | ‹Tal ka nesu.› Mes vrais papiers. Je n'en ai jamais eu d'autres. |
| `sc22_mira_visor` | Voilà. Jeudi dernier aussi, vous m'avez demandé ça. |
| `sc22_mira_password` | Il pleut, même ici. ‹Lumika.› |
| `sc22_mira_luciole_reply` | Alors on se comprend. Le recycleur 3 attend. Ilan aussi, peut-être. |
| `sc22_mira_purpose` | Rendre l'air. Ce n'est écrit sur aucun permis. |
| `sc22_mira_stay` | Une heure. Ensuite, plus personne n'aura besoin de votre vitre. |
| `sc22_mira_origin` | Tycho. Puits 9. Mes parents y sont restés en 2151. |
| `sc22_mira_origin_dora` *(si `dora_told_puits9`)* | Puits 9. Votre Dora connaissait ma mère. Elle vous l'a dit, non ? |
| `sc22_mira_about_wanted` | Oui, c'est moi. Je ne vais pas vous mentir : vous seriez la première. |
| `sc22_mira_exit_approve` | Merci. Dans une heure, ouvrez votre hublot. |
| `sc22_mira_exit_deny` | Une autre vitre, alors. Vous m'avez juste fait perdre le temps qu'on n'a pas. |
| `sc22_mira_exit_detain` | [aux gardes, calme] Je connais le chemin. Gloire au Consortium… comme on dit. |

| Verdict | Flags | Effets |
|---|---|---|
| DÉTENTION | `final_detained: 0`, `loyalty: 1`, `lucioles_trust: -2` | +5 + 5 ₵ → vers F4 / F1 / F7 |
| REFUSÉ | `final_denied: 0` | +5 ₵ → F7 (variante « elle a trouvé une autre vitre ») |
| APPROUVÉ | `final_passed: 0`, `lucioles_trust: 1` | ENTRÉE IRRÉGULIÈRE → vers F5 / F1 / F7 |

### 4.8 Récapitulatif pour les `DayDef`

| Jour | Cas scénarisés (`at_index`) | `passenger_count` (GDD) |
|---|---|---|
| J4 | SC-06 @1 (conditionnel), SC-07 @4, SC-08 @8 | 12 |
| J5 | SC-09 @3, SC-10 @7 | 12 |
| J6 | SC-11 @2, SC-12 @6 | 13 |
| J7 | SC-13 @3, SC-14 @9 | 14 |
| J8 | SC-15 @2, SC-16 @3, SC-17 @7 | 14 |
| J9 | SC-18 @4, SC-19 @9 | 15 |
| J10 | SC-20 @3, SC-21 @6, SC-22 @10 | 16 |

Si `requires_flag` n'est pas satisfait (SC-06), l'index est rempli par un passager généré.

### 4.9 Signalement d'un porteur du code 1 (règle précisée, v0.2)

GDD §4.7 : « DÉTENTION d'un passager portant le code 1, documentée par la paire marque luciole ↔ bulletin = signalement valide ». Précisions pour le moteur et le scoring :

| # | Règle |
|---|---|
| 1 | **À partir du J7 seulement** (`DayDef.detain_enabled` et onglet Symboles subversifs). Avant, la marque n'est pas citable ; seul le bouton « Signaler » du soir existe (SC-05). |
| 2 | **Preuve exigée** : pendant l'inspection, le joueur a confirmé la paire « marque luciole (coin du document) ↔ entrée *Luciole · encre magenta* de l'onglet Symboles subversifs » — même mécanique qu'une discordance confirmée (D-032). **Sans cette citation, pas de signalement** : la DÉTENTION est jugée par le seul moteur de règles (aucune violation de sévérité ≥ 3 → DÉTENTION ABUSIVE). |
| 3 | **Verdict DÉTENTION + paire citée = signalement valide**, quelles que soient les autres violations : cas **correct**, aucune citation (ni REFUS INJUSTIFIÉ ni DÉTENTION ABUSIVE), +5 ₵ de salaire + 5 ₵ de prime de détention (une seule prime par cas), `loyalty +1`, `lucioles_trust −2`, drapeau `luciole_reported_at_booth`. |
| 4 | Un **REFUS** qui ne cite que la marque n'est pas un signalement : le Consortium attend une mise en attente. Le refus est jugé normalement (passager en règle → REFUS INJUSTIFIÉ). |
| 5 | Les codes 2 à 7 ne sont **jamais** une preuve : détenir sur leur seule base = DÉTENTION ABUSIVE (le joueur en sait plus que le Consortium). |
| 6 | **Cas scénarisés** : si le cas définit `flags_on_detain` (SC-13), ces drapeaux **remplacent** les effets de jauge de la ligne 3 (pas de double `lucioles_trust −2`) ; salaire et prime restent ceux du moteur. Les autres effets (prime, cas correct) s'appliquent aussi à SC-13 si la paire est citée sans la preuve R17. |
| 7 | APPROUVER un porteur du code 1 : traitement normal (en infraction → citation et `lucioles_trust +1`, GDD). |

### 4.10 Dates de naissance des Dérivants (« 00.00.AAAA »)

| # | Règle |
|---|---|
| 1 | **Format affiché** : `00.00.AAAA` — jour et mois inconnus, **seule l'année compte**. Même valeur sur tous les documents du passager (carte, permis, bio-scan, laissez-passer de dérive). |
| 2 | **Qui** : `DRV` uniquement ; environ la moitié des Dérivants générés (paramètre de faction proposé `year_only_birth_rate = 0.5`) ; **Sefa (SC-18)** toujours (`00.00.2163`) ; Wren (SC-19) a une date complète. |
| 3 | **Jamais une discordance** en soi (bruit légitime, GDD §3). Onglet Codes d'origine : `rb_origins_drv_birth` — « DRV · Dérivants : naissance « 00.00.AAAA » tolérée (année seule). » |
| 4 | **Concordance (R07)** : deux documents concordent s'ils portent la même année en `00.00`. Une anomalie `NAME_MISMATCH` sur une telle date change **l'année** (jamais d'inversion jour/mois). |
| 5 | **Âge apparent (R18)** : âge possible = {année du jour − AAAA − 1, année du jour − AAAA} ; violation seulement si **aucune** de ces deux valeurs n'est dans la tranche du visage (zéro faux positif, D-005). |
| 6 | **Stockage proposé** : `birth_date` = jour du 01.01.AAAA (entier inchangé) + `Passenger.birth_year_only: bool` repris par les documents ; affichage `GameDate` → `00.00.AAAA`. |

---

## 5. Soirées J4 → J10

Format proposé 🟡 (`EveningEventDef`) : `id`, `day`, `condition` (flags), `title_key`, `text_key`, `options[]` avec `label_key`, `cost` (₵), `result_key`, `flags`. Affiché dans la colonne droite de l'écran Soirée, à la place du « mot glissé » existant ; **au plus 2 événements par soir** (le plus prioritaire d'abord). Un événement sans option est une simple lettre.

### J4 — Anniversaire de Noa

| Clé | Texte |
|---|---|
| `evt_d04_birthday_title` | NEUF ANS |
| `evt_d04_birthday_text` | Noa a décoré la couchette avec des étiquettes de rations. Elle ne demande rien. Elle regarde la porte. |
| `evt_d04_birthday_opt_gift` | Acheter une orange hydroponique (5 ₵) |
| `evt_d04_birthday_opt_none` | Lui promettre « l'an prochain » |
| `evt_d04_birthday_res_gift` | Elle a gardé la peau dans sa poche toute la nuit, pour l'odeur. |
| `evt_d04_birthday_res_none` | « L'an prochain », a répété Noa. Elle l'a écrit sur la vitre embuée. |

Flags : `noa_birthday_gift` (option 1). Si `sc07_bribe_kept` : une ligne d'Ilan s'ajoute — `evt_d04_money` « Ilan compte deux fois les crédits sur la table, sans rien dire. »

### J5 — Le chauffage payé (condition : `sc10_passed` ou `lucioles_trust ≥ 2`)

| Clé | Texte |
|---|---|
| `evt_d05_heat_title` | UN REÇU DANS LA FENTE |
| `evt_d05_heat_text` | Sous la porte : un reçu de chauffage payé pour ce soir, et une luciole dessinée au dos. |
| `evt_d05_heat_opt_accept` | Garder le reçu (chauffage gratuit ce soir) |
| `evt_d05_heat_opt_refuse` | Le brûler et payer vous-même |
| `evt_d05_heat_res_accept` | La cabine est tiède. Noa s'endort sans tousser. Quelqu'un sait où vous vivez. |
| `evt_d05_heat_res_refuse` | Le reçu brûle vite. Le chauffage, lui, coûte toujours 6 ₵. |

Effets : accepter → poste chauffage à 0 ₵ ce soir, `lucioles_heating_accepted`, `lucioles_trust +1`. Lettre additionnelle (toujours) : `evt_d05_ilan_night` — Ilan est sorti·e à minuit. « Un dépannage. » Ses mains sentaient l'ozone en rentrant.

### J6 — Le bio-scan de Noa (événement GDD)

| Clé | Texte |
|---|---|
| `evt_d06_bioscan_title` | LA TOUX GRISE |
| `evt_d06_bioscan_text` | La Clinique Meridian exige un bio-scan pour Noa : suspicion de Fièvre grise. 25 ₵. |
| `evt_d06_bioscan_text_free` *(si `sc09_doctor_passed`)* | On frappe. C'est la médecin du guichet, sa sacoche à la main. « Je vous l'avais dit. » Elle examine Noa. |
| `evt_d06_bioscan_opt_pay` | Payer le bio-scan (25 ₵) |
| `evt_d06_bioscan_opt_free` | Laisser la médecin faire (0 ₵) |
| `evt_d06_bioscan_opt_skip` | Attendre (Noa tombe malade) |
| `evt_d06_bioscan_res_pay` | Négatif. Une bronchite de froid. Noa garde le certificat sous son oreiller. |
| `evt_d06_bioscan_res_free` | « Pas de Fièvre grise. Du chaud, du bouillon. » Elle refuse vos crédits. |
| `evt_d06_bioscan_res_skip` | Noa tousse toute la nuit. Le bio-scan reviendra mardi, plus cher en inquiétude. |

Flags : `noa_bioscan_paid` / `noa_bioscan_free` / `noa_bioscan_skipped` (→ Noa `MALADE`, événement relancé au J8, GDD).

### J7 — Le mot de l'école (+ représailles si `sc13_detained`)

| Clé | Texte |
|---|---|
| `evt_d07_school_title` | AVIS DE L'ÉCOLE DE L'ANNEAU C |
| `evt_d07_school_text` | « Votre enfant a reproduit un symbole subversif (luciole) sur son cahier. Amende pédagogique : 10 ₵. » |
| `evt_d07_school_opt_pay` | Payer l'amende (10 ₵) |
| `evt_d07_school_opt_ignore` | Ne pas payer |
| `evt_d07_school_res_pay` | Noa a gommé la luciole. Elle en a redessiné une, minuscule, sous sa couchette. |
| `evt_d07_school_res_ignore` | L'école transmet l'avis au Bureau. Votre matricule y figure. |
| `evt_d07_lumika` | Ilan, à Noa : « ‹Lumika›, ça veut dire luciole. Ne le dis à personne. » |
| `evt_d07_tag_title` *(si `sc13_detained`)* | LA PORTE DE LA CABINE |
| `evt_d07_tag_text` | Peint en magenta sur votre porte : « LE 04 ÉTEINT LES LUCIOLES ». Noa l'a lu avant vous. |

Flags : `noa_school_fine_paid` / `noa_school_fine_ignored` (`suspicion +1`) ; `lumika_learned` (toujours).

### J8 — Dora, le voisin, le colis

Lettre (toujours) — `evt_d08_dora_title` « LE PUITS 9 » / `evt_d08_dora_text` : « Dora parle longtemps, entre deux bouffées d'oxygène. Quarante et un jours de grève, l'air coupé, le Puits 9. Une Vasquez-Orlov lui a tenu la main. » Flag `dora_told_puits9`.

Choix 1 — Le voisin :

| Clé | Texte |
|---|---|
| `evt_d08_neighbor_title` | LA CABINE 12 |
| `evt_d08_neighbor_text` | Mme Halvorsen, la voisine, cache un jeune Tharsien depuis l'attentat. Prime de signalement : 10 ₵. |
| `evt_d08_neighbor_opt_denounce` | Les signaler (+10 ₵) |
| `evt_d08_neighbor_opt_help` | Leur donner un repas (10 ₵) |
| `evt_d08_neighbor_opt_ignore` | Ne rien voir |
| `evt_d08_neighbor_res_denounce` | La Garde est venue à 23 h. Mme Halvorsen ne vous dit plus bonjour. |
| `evt_d08_neighbor_res_help` | Le garçon a mangé debout, en silence. Il a laissé un fil magenta sur l'assiette. |
| `evt_d08_neighbor_res_ignore` | À travers la cloison, quelqu'un prie en tharsien. Vous montez le recycleur. |

Flags : `neighbor_denounced` (`loyalty +1`) / `neighbor_helped` (`lucioles_trust +1`) / `neighbor_ignored`.

Choix 2 — Le colis (condition : `lucioles_trust ≥ 1` et non `lucioles_hostile`) :

| Clé | Texte |
|---|---|
| `evt_d08_package_title` | UN COLIS SANS LUCIOLE |
| `evt_d08_package_text` | Un homme au regard dur : « Gardez ça deux jours. Vingt crédits. Ce ne sont pas les Veilleurs qui demandent. » |
| `evt_d08_package_opt_accept` | Cacher le colis (+20 ₵) |
| `evt_d08_package_opt_refuse` | Refermer la porte |
| `evt_d08_package_res_accept` | Le colis est lourd, tiède, et il ne fait aucun bruit. Il est sous la couchette de Noa. |
| `evt_d08_package_res_refuse` | Il hausse les épaules. « D'autres portes s'ouvriront. » |

Flags : `brulants_package`, `suspicion +1`.

Si `sc14_passed` : `evt_d08_soute_meds` — « Un sachet sous la porte, de la part du quai 6 : les médicaments de la Soute coûtent 8 ₵ ce soir. » (poste médicaments à 8 ₵). Si `noa_bioscan_skipped` : le bio-scan revient (`evt_d08_bioscan_title` « LA TOUX GRISE, ENCORE », texte et options de J6 sans l'option gratuite).

Si `lucioles_hostile` : `evt_d08_sabotage` — « Le recycleur de la cabine a été forcé. Réparation d'urgence : le chauffage coûte 12 ₵ ce soir. » (poste chauffage +6 ₵). Si `sc17_detained` : `evt_d08_kwame` — « Ilan a vu un petit garçon seul dans le Hall, qui appelait sa mère. Ilan n'a rien pu faire. »

### J9 — L'audit, l'aveu, la déposition, le départ

**Ordre fixe** : 1) audit (automatique) → 2) aveu d'Ilan → 3) déposition sur Okonkwo → 4) laissez-passer (si `drift_offer`). Chaque étape est un panneau ; l'audit peut terminer la partie (F1).

**1. Audit** (titre `evt_d09_audit_title` : « LE DOSSIER DU GUICHET 04 » ; score = `suspicion` − 1 si `inspector_test_passed`) :

| Score | Effet | Clé / texte |
|---|---|---|
| ≥ 4 | **F1** immédiate | `evt_d09_audit_arrest` — Ravel referme votre dossier. « Levez-vous, s'il vous plaît. » Deux gardes attendent dans le couloir. |
| 2–3 | −30 ₵, `loyalty −1`, `audit_retention` ; `inspector_bribe_taken` → +30 ₵ confisqués en plus | `evt_d09_audit_retention` — « Retenue de 30 ₵. Dossier ouvert. Ne me donnez pas de raison de revenir. » |
| ≤ 1 | `audit_clean` | `evt_d09_audit_clean` — « Rien à signaler. C'est rare. Ne gâchez pas ça demain. » |

**2. Aveu d'Ilan** (toujours, `ilan_confessed`) :

| Clé | Texte |
|---|---|
| `evt_d09_ilan_title` | CE QU'ILAN N'A PAS DIT |
| `evt_d09_ilan_text` | « Je répare les recycleurs de la Soute. Pour les Veilleurs. Jeudi, ils veulent rendre l'air à tout l'Anneau C. On a besoin de moi. » |
| `evt_d09_ilan_text_note` *(si `sc18_note_kept`)* | Ilan voit le mot plié dans votre main. « Tu l'as lu. Alors tu sais déjà. » |
| `evt_d09_ilan_text_exposed` *(si `ilan_exposed`)* | Ilan rentre de l'Anneau B à 2 h, le visage gris. « Ils m'ont montré un mot. Le mot que tu leur as donné. » |
| `evt_d09_ilan_opt_support` | « Vas-y. Fais attention. » |
| `evt_d09_ilan_opt_forbid` | « Pas toi. Pas nous. Reste. » |
| `evt_d09_ilan_opt_denounce` | Signaler Ilan à l'Inspection |
| `evt_d09_ilan_res_support` | Ilan vous serre longtemps. Noa fait semblant de dormir. |
| `evt_d09_ilan_res_forbid` | Ilan pose la clé du recycleur sur la table. Elle y reste toute la nuit. |
| `evt_d09_ilan_res_denounce` | La Garde frappe à 4 h. Ilan ne se débat pas. Noa ne vous parle plus. |

Flags : `ilan_supported` (`lucioles_trust +1`) / `ilan_forbidden` (`lucioles_trust −1`) / `ilan_denounced` (`loyalty +3`, `lucioles_trust −3`, Ilan → `PERDU` « mis·e en attente », prime 20 ₵).

**3. Déposition sur Okonkwo** :

| Clé | Texte |
|---|---|
| `evt_d09_okonkwo_title` | DÉPOSITION — GUICHET 03 |
| `evt_d09_okonkwo_text` | Ravel pose un formulaire : « Taux de mise en attente : zéro. Sympathies présumées. Votre signature suffit. Prime : 15 ₵. » |
| `evt_d09_okonkwo_opt_sign` | Signer (+15 ₵) |
| `evt_d09_okonkwo_opt_refuse` | Refuser de signer |
| `evt_d09_okonkwo_opt_warn` | Refuser, puis prévenir Okonkwo cette nuit |
| `evt_d09_okonkwo_res_sign` | La signature tient en une ligne. Le formulaire part avec Ravel. |
| `evt_d09_okonkwo_res_refuse` | « Noté », dit Ravel. Il ne dit pas quoi. |
| `evt_d09_okonkwo_res_warn` | À 1 h, vous frappez au Bloc Cormoran. Okonkwo ouvre, déjà habillé. « Je sais. Merci. » |

Flags : `okonkwo_denounced` (`loyalty +2`) / `okonkwo_shielded` (`suspicion +1`) / `okonkwo_warned` (`suspicion +1`, `loyalty −1`, `lucioles_trust +1`).
Note : la suspicion posée ici **n'affecte plus l'audit** (déjà passé) ; elle est lue par les épilogues et F1 (J10, double jeu) ne la lit pas.

**4. Laissez-passer de dérive** (condition `drift_offer`) :

| Clé | Texte |
|---|---|
| `evt_d09_drift_title` | QUAI 6, VENDREDI 05:00 |
| `evt_d09_drift_text` | La carte de Wren est sur la table. Trois places sur le Basse-Marée, quatre si on insiste. 40 ₵. |
| `evt_d09_drift_opt_buy` | Acheter les places (40 ₵) |
| `evt_d09_drift_opt_keep` | Garder la carte, sans payer |
| `evt_d09_drift_res_buy` | Wren compte les crédits deux fois. « Vendredi. Pas une minute de retard. » |
| `evt_d09_drift_res_keep` | La carte rejoint le badge de Dora, dans la poche de votre veste. |

Flag : `drift_passes_bought` (dette impossible : option grisée si solde < 40 ₵).

### J10 — Pas de soirée

Le shift du J10 se termine par le **bilan**, puis l'évaluation de fin (§6) remplace la soirée. Les crédits pris en compte sont ceux **après le bilan du J10** (salaire, amendes, enveloppes).

---

## 6. Fins

### 6.1 Évaluation

**Fins anticipées** (à la clôture de chaque soirée, existant + ajout) : F2, F3 (inchangées, GDD §5.4) ; **F1 à l'audit du J9** (score ≥ 4).

**Fin de campagne** (après le bilan du J10). Ordre de priorité GDD conservé : **F1 > F3 > F2 > F5 > F6 > F4 > F7**.

Définitions :
- `alive` = nombre de proches dont l'état ≠ `PERDU` (Ilan dénoncé·e compte comme `PERDU`).
- `compliance` = `Campaign.compliance()` (existant).
- `credits` = solde après le bilan du J10.

| # | Fin | Condition exacte |
|---|---|---|
| **F1** | Arrestation | (J9) score d'audit ≥ 4 ; **ou** (J10) `lucioles_trust ≥ 3` **et** `loyalty ≥ 3` (double jeu découvert) |
| **F3** | Famille perdue | `alive == 0` (anticipée, existant) |
| **F2** | Réaffectation | 3 loyers impayés consécutifs, ou solde < 0 trois soirs consécutifs (anticipée, existant) |
| **F5** | Rendre l'air | `final_passed` **et** `lucioles_trust ≥ 4`. Variante **Brûlants** si `sc20_passed` **ou** `brulants_package` ; sinon **Veilleurs** |
| **F6** | À la dérive | `drift_passes_bought` **et** `alive ≥ 2` **et** `credits ≥ 30` **et non** `final_detained` |
| **F4** | Gloire au Consortium | `final_detained` **et** `loyalty ≥ 3` **et** `compliance ≥ 0,85` **et** `alive ≥ 2` |
| **F7** | Le guichet rouvre demain | aucune des précédentes (dont `final_denied`, `final_unprocessed`, `final_passed` avec `lucioles_trust < 4`, `final_detained` sans les seuils F4) |

Remarques de conception :
- F6 exclut `final_detained` : on ne livre pas Mira pour ensuite fuir avec les Lucioles en dérive (Wren refuse : « Pas toi. »). Sans cette clause, la priorité F6 > F4 rendrait la promotion inaccessible aux joueurs prudents.
- `final_passed` sans confiance suffisante → F7 : Mira passe, mais les Lucioles n'ont pas les relais nécessaires ; l'opération échoue sans bruit (variante d'épilogue).

### 6.2 Épilogues

Chaque épilogue = titre + 5 à 8 lignes. Les lignes entre crochets sont **conditionnelles** (affichées si le flag est vrai, sinon la ligne suivante prend sa place). Clés : `end_fN_title`, `end_fN_l1…l8`, variantes `end_fN_<flag>`.

#### F1 — Arrestation (`end_f1_title` : « MISE EN ATTENTE »)

| Clé | Texte |
|---|---|
| `end_f1_l1` | Anneau B. Une lumière blanche qui ne s'éteint jamais. |
| `end_f1_l2` | Ravel lit votre dossier à voix haute : chaque enveloppe, chaque tampon, chaque silence. |
| `end_f1_l3_double` *(J10, double jeu)* | « Loyal envers tout le monde. Donc envers personne. » |
| `end_f1_l3_audit` *(J9)* | « Le Guichet 04 rouvrira demain. Avec quelqu'un d'autre. » |
| `end_f1_l4` | Ilan, Noa et Dora sont réaffecté·es vers un dortoir de l'Anneau C sans hublot. |
| `end_f1_l5_okonkwo_warned` | Une nuit, quelqu'un tape trois fois sur la porte de votre cellule. Puis plus rien. |
| `end_f1_l5` | Au Guichet 04, un·e agent·e novice apprend à dire « Gloire au Consortium ». |
| `end_f1_l6` | Il pleut, même ici. |

#### F2 — Réaffectation (`end_f2_title` : « RÉAFFECTATION »)

| Clé | Texte |
|---|---|
| `end_f2_l1` | Le badge ne s'allume plus à la porte du Hall. |
| `end_f2_l2` | L'Autorité de Transit vous « réaffecte » : ce mot que vous tamponniez sur les autres. |
| `end_f2_l3` | La cabine du Bloc Pétrel est vidée en une heure. Le réchaud reste. |
| `end_f2_l4` | Vous embarquez sur la Transit-7, dans l'autre sens, avec ce qu'il reste du foyer. |
| `end_f2_l5` | À Tycho, la poussière vous reconnaît avant les gens. |
| `end_f2_l6` | Derrière une vitre, quelque part, quelqu'un regarde vos papiers. |

#### F3 — Famille perdue (`end_f3_title` : « LA CABINE SILENCIEUSE »)

| Clé | Texte |
|---|---|
| `end_f3_l1` | La couchette triple n'a plus qu'un drap défait. |
| `end_f3_l2` | Le recycleur siffle toujours ; personne ne tousse pour le couvrir. |
| `end_f3_l3` | Le Consortium envoie une lettre type : « Condoléances respiratoires. » |
| `end_f3_l4_lumika` *(si `lumika_learned`)* | Sous la couchette, une luciole dessinée par Noa. Vous ne la gommez pas. |
| `end_f3_l4` | Sur la vitre embuée, le badge que Noa avait dessiné le premier jour s'efface. |
| `end_f3_l5` | Le lendemain, vous êtes au guichet à 10:00. Il n'y a nulle part ailleurs où aller. |

#### F4 — Gloire au Consortium (`end_f4_title` : « CLASSE C-2 »)

| Clé | Texte |
|---|---|
| `end_f4_l1` | Mira est mise en attente à 14:12. Les recycleurs restent au Consortium. |
| `end_f4_l2` | Promotion C-2. Un appartement chauffé à l'Anneau D, avec une vraie fenêtre. |
| `end_f4_l3_ilan` *(si `ilan_denounced`)* | Il y a une chambre de trop. Noa ne vous demande jamais où est Ilan. |
| `end_f4_l3` | Noa ne tousse plus. Dora respire un air qui ne sent pas l'ozone. |
| `end_f4_l4_okonkwo_denounced` | Le Guichet 03 a rouvert avec un agent qui détient beaucoup. |
| `end_f4_l4_okonkwo` | Okonkwo charge des caisses au quai 6. Il ne lève pas la tête quand vous passez. |
| `end_f4_l5_mazur` *(si `sc11_veteran_passed`)* | Le vétéran Mazur a été condamné pour l'attentat. Vous savez où il dînait. |
| `end_f4_l6` | Le Hall des Guichets ferme trois guichets « pour efficacité ». Le vôtre reste ouvert. |
| `end_f4_l7` | Gloire au Consortium. Vous le dites sans y penser, maintenant. |

#### F5 — Rendre l'air (`end_f5_title` : « RENDRE L'AIR »)

Variante **Veilleurs** :

| Clé | Texte |
|---|---|
| `end_f5v_l1` | À 15:00, les recycleurs de l'Anneau C s'ouvrent. L'air des Anneaux descend dans les coursives. |
| `end_f5v_l2_ilan` *(si `ilan_supported`)* | Ilan tient la vanne du recycleur 3. Mira lui dit de tourner. |
| `end_f5v_l2` | Mira tourne la vanne elle-même. Personne ne tire. |
| `end_f5v_l3` | Le Consortium coupe les quotas, puis négocie. Pour la première fois, il négocie. |
| `end_f5v_l4_okonkwo_warned` | Okonkwo ouvre le Guichet 03 et laisse passer tout le monde, sans tampon. |
| `end_f5v_l4` | Les vitres du Hall restent ouvertes une journée entière. Personne ne sait quoi en faire. |
| `end_f5v_l5_hadid` *(si `sc16_hana_passed`)* | Les Hadid respirent ensemble à l'Anneau D. |
| `end_f5v_l6` | Vous disparaissez dans la Soute avec Noa et Dora. Le Bloc Pétrel garde votre nom sur la porte. |
| `end_f5v_l7` | Il pleut, même ici. Mais l'eau est tiède. |

Variante **Brûlants** :

| Clé | Texte |
|---|---|
| `end_f5b_l1` | À 15:00, les recycleurs s'ouvrent. À 15:04, le quai 1 explose. |
| `end_f5b_l2` | Les Brûlants ont pris l'air ; les Veilleurs n'ont pas pu les arrêter. |
| `end_f5b_l3_package` *(si `brulants_package`)* | Le colis caché sous la couchette de Noa n'y était plus quand vous êtes rentré·e. |
| `end_f5b_l4` | Les Anneaux sont scellés trois jours. L'air revient, mais il coûte des morts. |
| `end_f5b_l5` | Mira, blessée, dit que ce n'est pas ce qu'elle voulait. Arkady dit que si. |
| `end_f5b_l6` | Vous vivez dans la Soute. La station respire mieux, et dort moins bien. |

#### F6 — À la dérive (`end_f6_title` : « À LA DÉRIVE »)

| Clé | Texte |
|---|---|
| `end_f6_l1` | Vendredi, 05:00, quai 6. Le Basse-Marée sent la rouille et le thé. |
| `end_f6_l2` | Wren raye vos noms d'un registre que personne ne contrôle. |
| `end_f6_l3_dora` *(si Dora en vie)* | Dora regarde Halcyon rapetisser. Elle dit que Tycho était plus petite encore. |
| `end_f6_l3` | Il y a une place vide, et personne ne s'y assoit. |
| `end_f6_l4` | Noa apprend le Tessar plus vite que vous. ‹Lumika›, ‹Oru ka›, ‹Shen tavi›. |
| `end_f6_l5_final_passed` *(si `final_passed`)* | Par la radio de bord, on apprend que les recycleurs d'Halcyon ont été ouverts. |
| `end_f6_l5` | Par la radio de bord, on apprend que le Guichet 04 a rouvert avec quelqu'un d'autre. |
| `end_f6_l6` | Vous n'avez plus de classe, plus de matricule, plus de vitre. Vous respirez. |

#### F7 — Le guichet rouvre demain (`end_f7_title` : « LE GUICHET ROUVRE DEMAIN »)

| Clé | Texte |
|---|---|
| `end_f7_l1` | Vendredi 23.03.2187, 10:00. Le carillon, trois notes. |
| `end_f7_l2_denied` *(si `final_denied`)* | Mira a trouvé une autre vitre. Les recycleurs ont été ouverts, puis refermés dans l'heure. |
| `end_f7_l2_passed` *(si `final_passed`)* | Mira est passée. Il manquait des mains au recycleur 3. L'opération s'est éteinte sans bruit. |
| `end_f7_l2_detained` *(si `final_detained`)* | Mira est en Anneau B. On ne vous a rien proposé. On ne propose rien aux guichets moyens. |
| `end_f7_l2` | Rien ne s'est passé, hier. C'est ce que dit le bulletin. |
| `end_f7_l3` | Une nouvelle directive : les Dérivants doivent présenter un laissez-passer. |
| `end_f7_l4` | Noa a dessiné votre badge sur la vitre embuée, comme le premier jour. |
| `end_f7_l5` | La file serpente entre les barrières magnétiques. Elle ne finit jamais. |
| `end_f7_l6` | « Suivant. » |

---

## 7. Barks et sous-titres

### 7.1 Guide de ton

| Règle | Détail |
|---|---|
| **Longueur** | ≤ 90 caractères par réplique de passager (une ligne de sous-titre à 1280×800). Briefings et soirées : ≤ 220 caractères par message. |
| **Une idée par réplique** | Une réplique répond à la question posée ; l'émotion passe par le rythme, pas par l'adjectif. |
| **Tessar** | 1 fragment Tessar maximum par réplique, en début ou fin (‹Tal ka nesu.›, ‹Shen tavi.›), suivi de sa traduction implicite. Lexique LORE §10 uniquement ; tout nouveau mot passe par le Lore Master. **Convention v0.2** : les sous-titres sont des `Label` (pas d'italique) → le fragment est encadré de **chevrons simples** `‹…›` (U+2039/U+203A, présents dans Inter, Chakra Petch et JetBrains Mono), ponctuation du Tessar à l'intérieur, sans espace : `‹Tal ka nesu.› Voici mes papiers.` Les guillemets « » restent réservés aux citations, les crochets aux didascalies. Même règle dans les soirées et les fins (`« ‹Lumika›, ça veut dire luciole. »`). Le masquage de *lumika* (« [mot inconnu] ») fonctionne à l'intérieur des chevrons. Les noms de vaisseaux (Long-Ruban, Basse-Marée) s'écrivent sans marque. |
| **Didascalies** | Entre crochets, courtes, au présent : `[toux grise]`, `[trois tapes sur la vitre]`. Jamais d'information de vérité (pas de `[il ment]`). |
| **Vérité** | Une réplique ne prouve jamais rien (GDD P1, UI_FLOW §4.7) : un innocent peut être nerveux, un fraudeur poli. |
| **Registres** | Passagers : vouvoiement, langue orale, phrases courtes. Okonkwo : tutoiement, sec, « …comme on dit ». Ilan : intime, concret, jamais d'appel au secours explicite. Dora : images de Tycho (poussière, puits). Consortium : novlangue (réaffectation, mise en attente, ressortissant), voix passive, jamais d'insulte. Inspecteur Ravel : courtois, froid, appelle l'agent·e « Guichet 04 ». Lucioles : « nous », images de pluie et de lumière, jamais de menace. Brûlants : impératif, « on ». |
| **Écriture inclusive** | Point médian pour l'agent·e et Ilan (`réaffecté·e`, `sorti·e`), comme dans `fr.csv` ; jamais de pronom genré pour Ilan (« Signaler Ilan », pas « Le signaler ») ; pluriel mixte du foyer : `réaffecté·es`. Noa est une fille (« elle »). |
| **Interdits** | Aucun nom de marque réelle ; aucun terme hors LORE pour les institutions ; aucun jugement moral du narrateur. |

### 7.2 Préfixes de clés proposés

| Préfixe | Usage | Exemple |
|---|---|---|
| `scNN_<nom>_<suffixe>` | répliques des cas scénarisés (§4) | `sc13_lev_luciole_reply` |
| `dayNN_directive_title`, `dayNN_intro`, `dayNN_slogan` | briefing (existant) | `day07_intro` |
| `msg_okonkwo_dayNN[_variante]` | Okonkwo (existant) | `msg_okonkwo_day07_test_passed` |
| `msg_ilan_dayNN[_variante]` | message narratif d'Ilan | `msg_ilan_day10_supported` |
| `msg_luc_dayNN` | message des Lucioles | `msg_luc_day05` |
| `msg_cons_dayNN[_variante]` | bulletin du Bureau | `msg_cons_day08_oath` |
| `msg_insp_dayNN[_variante]` | Inspecteur Ravel | `msg_insp_day09` |
| `msg_echo_<flag>` | brèves d'écho (existant) | `msg_echo_sc17_detained` |
| `msg_hall_dayNN_<variante>` | brèves du Hall | `msg_hall_day10_okonkwo_warned` |
| `hall_jN_<id>` | annonce haut-parleur pendant le shift | `hall_j7_okonkwo_citation` |
| `evt_dNN_<id>_{title,text,opt_*,res_*}` | événements du soir | `evt_d09_drift_opt_buy` |
| `end_fN_{title,lN}` / `end_f5v_*` / `end_f5b_*` | fins | `end_f6_l4` |
| `q_<sujet>` | questions du joueur (existant) | `q_luciole_reply` |
| `line_about_<famille>` | réponses génériques (existant) | — |

### 7.3 Clés génériques supplémentaires

| Clé | Texte |
|---|---|
| `line_bribe_generic` | Pour votre peine. Personne ne compte. |
| `line_bribe_kept_generic` | Nous nous comprenons. |
| `line_bribe_returned_generic` | Comme vous voudrez. |
| `line_about_envelope_generic` | Un geste. Rien de plus. |
| `line_about_wanted_generic` | Ce n'est pas moi. Il y a erreur. |
| `line_about_implant_generic` | Je… je pensais l'avoir déclaré. |
| `line_visor_refuse` | ‹Nai.› Non. Mon visage ne regarde que moi. |
| `line_password_generic` | Il pleut, même ici. |
| `line_luciole_reply_generic` | ‹Shen tavi.› On se reverra sous la pluie. |
| `line_exit_detain_generic` | Je n'ai rien fait. Vous le savez. |
| `hall_j7_okonkwo_citation` | Guichet 03 : citation PROCÉDURE DE DÉTENTION. Le Bureau remercie les guichets exemplaires. |
| `hh_state_detained` | MIS·E EN ATTENTE |
| `ev_slipped_item_keep` | GARDER |
| `ev_slipped_item_return` | RENDRE |
| `ev_slipped_item_report` | REMETTRE À LA GARDE |
| `wb_envelope_label` | ENVELOPPE · %d ₵ |
| `wb_note_label` | MOT PLIÉ |
| `wb_dock_card_label` | CARTE DE QUAI |
| `rb_tab_wanted` | Avis de recherche |
| `wanted_novak_reason` | Attentat du quai 2 (20.03.2187). Dangereux. |
| `wanted_vasquez_reason` | Sabotage des recycleurs. Réseau Tharsis-Luciole. |

### 7.4 Textes écrits par Gameplay Systems (M7), relus et intégrés (v0.2)

| Clé | Texte | Note |
|---|---|---|
| `line_origin_cer` | Cérès. Trois semaines de vol, et votre file au bout. | réponse générique `q_origin` |
| `line_origin_thr` | Tharsis. Je connais ce regard : on me le sert à chaque vitre. | id. |
| `line_origin_drv` | Du cargo qui m'a vu naître. Il n'a pas de port, alors moi non plus. | id. |
| `evt_d09_audit_title` | LE DOSSIER DU GUICHET 04 | titre du panneau d'audit (§5 J9) |
| `evt_d08_bioscan_title` | LA TOUX GRISE, ENCORE | retour du bio-scan sauté (§5 J8) |
| `evt_d08_soute_meds` | Un sachet sous la porte, de la part du quai 6 : les médicaments de la Soute coûtent 8 ₵ ce soir. | si `sc14_passed` |
| `wanted_generated_reason` | Trafic de papiers. Réseau de passeurs du quai 5. | avis de recherche généré (J10) |
| `hh_ev_ilan_detained` | Ilan est mis·e en attente à l'Anneau B. Sa couchette reste faite. | `ilan_denounced` |
| `rb_tab_origins` | Codes d'origine | onglet (les directives disent « onglet Codes d'origine » : « Origines » est déjà une catégorie de règles) |
| `rb_tab_implants` / `rb_tab_symbols` / `rb_tab_seals` / `rb_tab_wanted` | Implants / Symboles subversifs / Sceaux / Avis de recherche | onglets, casse de phrase comme les autres |
| `val_seal_*` | HEXAGONE SOLAIRE · ANNEAU BARRÉ · MODÈLE 2187 · CROIX EN ORBITE · ANNEAU BARRÉ ROUGE (+ « · ANCIEN MODÈLE ») | sceaux conformes à LORE §9, inchangés |
| `rb_origins_drv_birth` | DRV · Dérivants : naissance « 00.00.AAAA » tolérée (année seule). | §4.10, ligne d'onglet à brancher |

Traces de fin corrigées : `end_trace_sc14_bribe_kept` « Vous avez gardé l'enveloppe du Ceinturier à l'insuline. » ; `end_trace_sc17_detained` / `_passed` parlent de « la mère aux papiers de sa sœur » (le joueur n'apprend jamais le prénom de Fatou).

---

## 8. Besoins système (pour la planification de l'Orchestrateur)

### 8.1 Données et modèle (Godot Architect / Gameplay Systems)

| # | Besoin | Utilisé par | Détail |
|---|---|---|---|
| B1 | **`DayDef` J4–J10** + `RuleSet` R08–R22 | tout | GDD §8 ; ce document fournit `scripted_cases`, `intro_text_key`. |
| B2 | Jauge **`suspicion`** | §2.1, audit | Entier dans `GameState.flags` ; même mécanique que `loyalty`. |
| B3 | `ScriptedCaseDef` : **`flags_on_detain`** | SC-13, 17, 20, 22 | Aujourd'hui DÉTENTION → `flags_on_deny` (doc du script) ; les fins exigent de distinguer. |
| B4 | `ScriptedCaseDef` : **`excludes_flag`** (ou `requires_flags: Array`, `forbids_flags: Array`) | SC-06 | Remplacement par un généré si non satisfait. |
| B5 | `ScriptedCaseDef` : **`appearance_from_case`** | SC-06 (← SC-02), SC-13 (← SC-05) | Réutiliser l'apparence d'un cas d'un jour antérieur (mémoriser `appearance_seed` des cas scénarisés dans la sauvegarde). |
| B6 | `ScriptedCaseDef` : **`bribe_amount`** + `flags_on_bribe_kept` / `flags_on_bribe_returned` (+ combinaisons verdict × enveloppe, cf. SC-07/SC-12) | SC-07, 12, 14, 21 + `bribe_rate` | Peut se modéliser par `flags_on_<verdict>_<bribe>` ou par une table de conditions. |
| B7 | `ScriptedCaseDef` : **`presentation`** (`knock_three` = code 5) et **`dialogue_tags` supplémentaires** (`luciole_password`) | SC-08, 13, 18, 22 | Code 5 = variante d'animation `talk` (LORE §7). |
| B8 | Champ MRZ **suffixe `07`** paramétrable (code 2) et **N° de permis terminé par 7** (code 3) | SC-09, 10, 18 | `injection_params` : `mrz_issuer = "07"`, `permit_suffix = 7`. Jamais une discordance (GDD §4.1). |
| B9 | **Avis de recherche** (`WantedNotice` : nom, portrait, motif) en données de `DayDef` J10 | SC-20, 22 | + `WANTED_PERSON` (GDD) ; entrée scénarisée par `id`. |
| B10 | **Document Dérogation d'implant militaire** (`doc_mil_waiver`, `DM-NNNN`) et sa lecture par R16 | SC-11 | Avancé depuis « après J10 » pour ce cas scénarisé seulement ; générique plus tard. |
| B11 | **Table de messages conditionnels** du briefing (données : `day`, `speaker`, `voice`, `text_key`, `condition`) | §3 | Remplace les `if` codés dans `BriefingContent.build` ; voix `LUCIOLES`, `INSPECTION`. |
| B12 | **`EveningEventDef`** : événements à choix (options avec coût, flags, texte de résultat, conditions, priorité) | §5 | Généralise le « mot glissé » existant ; supporte une modification ponctuelle d'un poste (chauffage 0 ₵ / +6 ₵, médicaments 8 ₵) et un gain (+10, +15, +20 ₵). |
| B13 | **Audit du J9** (séquence spéciale de soirée) | §5 J9 | Score, retenue, confiscation, F1. |
| B14 | **État narratif d'un proche** (`PERDU` motivé : « mis·e en attente ») | `ilan_denounced` | `hh_state_detained`. |
| B15 | **Conditions de fin** F1, F4–F7 évaluées après le bilan du J10 ; J10 **sans soirée** | §6 | Ordre de priorité GDD ; variantes d'épilogue par lignes conditionnelles. |
| B16 | Apprentissage de **`lumika`** : le sous-titre « [mot inconnu] » devient « *lumika* » quand `lumika_learned` | code 7 | Substitution à l'affichage. |

### 8.2 Interactions (UI/UX + Gameplay Systems)

| # | Besoin | Détail |
|---|---|---|
| I1 | **Objet glissé** (`SlippedItem`) sur le plan de travail : **enveloppe** (`ENVELOPPE · N ₵`), **mot plié**, **carte de quai** | Actions : GARDER (tiroir), RENDRE (fente), REMETTRE À LA GARDE (mot, J7+). Non traité au tampon → rendu d'office. Enveloppe gardée → crédits au bilan (ligne « Divers non déclaré »), `suspicion` immédiate. Débloque le sujet `about_envelope`. |
| I2 | **Tampon DÉTENTION** + sortie escortée par la Garde (2 PNJ) | GDD §4.5 ; réplique `_exit_detain`. |
| I3 | **Réponse à la phrase de passe** (sujet `luciole_reply`) visible si le cas porte le tag `luciole_password` **et** `lucioles_trust ≥ 2` | `password_answered` (+1 une fois) ; J9 : `suspicion +1`. |
| I4 | **Refus de visière** scénarisé (`_visor_refuse`) et brancher **`_visor`** sur les cas scénarisés | `remove_visor` n'utilise pas `scripted_line` aujourd'hui : `sc04_mira_visor` n'est jamais lu (§8.4). |
| I5 | **Répliques de sortie** `_exit_approve/_deny/_detain` (bulle + voix pendant DEPARTING) | Facultatif mais fort pour le récit. |
| I6 | **Annonce haut-parleur** pendant le shift (`hall_jN_*`), sous-titrée, déclenchée après le cas n | J7. |
| I7 | **Figurant de file** désigné (Kwame, SC-17) visible derrière la passagère | 3D Designer ; peut être un imposteur `MultiMesh` taggé. |
| I8 | **Onglets Rulebook** : Origines (J4), Implants (J6), Symboles subversifs (J7), Sceaux (J9), Avis de recherche (J10) | GDD §7. |
| I9 | **Écran Soirée** : 2 événements max, panneaux successifs au J9, option grisée si fonds insuffisants | Extension de l'écran existant. |
| I10 | **Écran de fin** : 7 fins, titre + lignes conditionnelles, défilement lent | Extension de `end_screen.gd`. |

### 8.3 Assets (3D Designer / Audio)

- Accessoires : **fil magenta** (poignet, code 6), **œil rouge mat + plaques MIL** (SC-11), **carré DER-19** sur le dos de la main (SC-14), **main KIN-5** (SC-08), sacoche de médecin (SC-09), toile de voile solaire (SC-19, Dérivants).
- Animation : **trois tapes sur la vitre** (code 5) ; **escorte** de la Garde de Continuité (uniforme gris, brassard jaune).
- Audio : carillon du haut-parleur du Hall ; ambiance J10 (alarme lointaine des recycleurs) ; voix TessarVoice des 17 passagers (aucun fichier, D-048).

### 8.4 Incohérences relevées (à arbitrer, aucune modifiée ici)

1. **`sc04_mira_visor`** existe dans `fr.csv` mais `InspectionSession` répond toujours `line_visor_removed` (pas de `scripted_line` sur `remove_visor`).
2. **`ev_note_rent`** dit « Deux loyers impayés de suite : réaffectation » ; D-047 a porté le seuil à **3**.
3. **LORE §5.1** place l'interrogatoire obligatoire des Tycho au **J5**, LORE §3 et GDD (R08) au **J4**. Ce document suit le GDD (J4).
4. **SC-05** n'a pas de nom fixé dans `day_03.tres` : proposition de lui donner **Lev Petrenko** (`TYC`) pour le retour au J7 (SC-13).
5. **`sc02_mercy`** : proposition d'ajouter `suspicion: 1` à `flags_on_approve` de SC-02 (cohérent avec `msg_echo_sc02_mercy` : « Les Inspecteurs aussi l'ont vue passer »).

### 8.5 Écarts M7 tranchés en v0.2 et reste à faire côté logique

| # | Écart signalé | Décision (Scénariste) | Reste à faire (Gameplay Systems / UI) |
|---|---|---|---|
| 1 | Fatou à 27 ans (texte : 33) | Fatou **29 ans** (12.06.2157), Ngozi **38 ans** (04.02.2149) : écart de 8 ans conservé, tranches 18–29 / 30–54 → R18. Données mises à jour (`tools/build_data.gd`). | — (mettre à jour la mention de D-055 dans `DECISIONS.md`) |
| 2 | SC-06 reprend la naissance générée de SC-02 | **Continuité J1 → J4 canon (D-057)** ; la naissance **08.06.2154 est désormais fixée sur SC-02**, donc les deux coïncident pour toute nouvelle partie. | — |
| 3 | SC-12 : lettre aléatoire au lieu de « Ravell » | Texte adapté (« Une lettre. Vous refuseriez quelqu'un pour une seule lettre ? »), valable pour toute substitution. | Facultatif : paramètre `injected_value` dans `NameMismatchInjector` |
| 4 | Détention d'un porteur du code 1 sans citation | Règle précisée en **§4.9** (preuve = paire citée, effets, non-cumul avec `flags_on_detain`). | Implémenter §4.9 dans `ScoringService` / `CaseConsequences` (paire « marque ↔ bulletin » citable, verdict correct, prime, jauges, `luciole_reported_at_booth`) |
| 5 | Dates « 00.00 » des Dérivants non gérées | Format **`00.00.AAAA`** (année seule), règles en **§4.10** ; intro J8 mise à jour. | `birth_year_only`, affichage, R07, R18 (intervalle), injecteur, `year_only_birth_rate` DRV, Sefa en `00.00.2163`, ligne `rb_origins_drv_birth` dans l'onglet |
| 6 | Astérisques du Tessar retirées | Convention **chevrons `‹…›`** (§7.1), appliquée à toutes les clés. | UI : `ComparisonUI.arrival_text` ajoute « Lumika. » aux porteurs du code 7 → écrire « ‹Lumika.› » |
| 7 | Textes hors NARRATIVE | Réécrits et intégrés (§7.4). | — |
| 8 | Relecture de `fr.csv` | Typos, guillemets français, Hall, genre de Noa et d'Ilan, répliques ≤ 90 caractères (y compris MVP), didascalie de SC-08 (les trois tapes sont déjà affichées par `tag_knock_three`), SC-13 ne dit plus la phrase de passe à l'arrivée (doublon avec `_password`), SC-20 sans didascalie de vérité, Mazur vieilli à 66 ans (Guerre du Sel 2131–2144). | — |

---

## 9. Questions ouvertes

1. **Ilan dénoncé·e** : l'option est-elle acceptable pour le client (ton, public 16+) ? Alternative plus douce : l'option n'existe pas, seule `ilan_forbidden` reste comme choix « loyal ».
2. **Vérité de l'attentat du J8** : ce document l'attribue aux **Brûlants** (Arkady Novak) et laisse l'Incident Albédo (2179) ambigu. Le client veut-il trancher Albédo dans un épilogue (F5 Veilleurs, par exemple) ?
3. **Mira comme figure finale** : confirmer que le personnage canon du J3 devient la personne recherchée du J10 (plutôt qu'un PNJ nouveau). Cela impose qu'elle soit toujours rencontrée au J3 (c'est le cas : SC-04 est inconditionnel).
4. **J10 sans soirée** : acceptable, ou faut-il une dernière soirée (dépenses) avant l'épilogue — ce qui change le seuil F6 (`credits ≥ 30` avant ou après dépenses) ?
5. **Économie J4–J10** : les dépenses spéciales (25 + 10 + 20 + 40 ₵, retenue 30 ₵) et les enveloppes (20–50 ₵) doivent être repassées dans `tools/balance_sim.gd` par le Game Designer avant d'écrire les `DayDef`.
