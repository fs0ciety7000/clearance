# CLEARANCE — Audio Design

> Version 0.6 · Propriétaire : Audio Designer · Statut : **implémenté (M6)** — voir §12 pour l'état réel ; **M14** (musique dynamique, annonces d'ambiance, lits par acte) — phase 1 (moteur, stress D-083, chaîne de rendu, échantillons) et **phase 2 (production, branchement)** — voir §13
> Cohérent avec `DESIGN_SYSTEM.md` §9 (Audio-UI), §11 (Assets libres) et `docs/ARCHITECTURE.md` §7 (catalogue `EventBus`).
> Moteur : Godot 4.7.2. Dossier cible : `res://assets/audio/{sfx,ambience,music,voice}/`.

---

## 1. Intentions sonores

**Pitch sonore** : *un guichet climatisé, étroit, au milieu d'une station qui ne dort jamais.* Le joueur est **à l'abri derrière une vitre** ; tout ce qui vient « de l'autre côté » (passager, file, station) est légèrement étouffé, filtré, lointain. Tout ce qui est **à lui** (tampons, fente, hologrammes, UI) est proche, sec, net, mono-centré.

| Couche | Intention | Référence de caractère |
|---|---|---|
| **Station (dehors)** | Grande, réverbérante, indifférente. Annonces PA corporatives lointaines (Consortium Halcyon), file d'attente qui piétine, toux, murmures inintelligibles, ventilation industrielle. | Hall de gare de nuit, réverb longue (RT60 ≈ 2,5 s) |
| **Pluie sur la vitre** | Signature de la DA « métal mouillé ». Pluie de condensation/arrosage du dôme qui ruisselle sur la vitre du guichet : grésillement fin + gouttes lourdes ponctuelles. Elle **masque doucement** les silences. | Pluie sur pare-brise, proche, stéréo large |
| **Néon / électronique du poste** | Bourdonnement 50/100 Hz + harmoniques, très bas (−30 dBFS), qui *grésille* brièvement aux transitions (allumage holo, citation). Le poste « vit ». | Transformateur, tube fluorescent |
| **Passager** | Humain, fatigué, de l'autre côté de la vitre : pas sur métal mouillé, souffle, froissement de documents, voix passée par l'**hygiaphone**. | Guichet de banque / parloir |
| **Guichet (outils du joueur)** | Mécanique, lourd, satisfaisant : fente à documents, tampons, intercom. C'est le « toucher » du jeu. | Papers, Please (tampon), matériel de bureau années 80 |
| **UI holographique** | Courte (< 300 ms), synthétique, sémantique (cf. DS §9). | Sinus, clicks capacitifs, glitches légers |
| **Musique** | Rare et sobre : nappes synthé froides, pulsation basse, motif du **carillon Consortium (3 notes)** décliné. Elle **ne couvre jamais** la lecture : sous l'ambiance pendant le shift. | Synthwave minimaliste, Vangelis froid |

**Règles transverses**

1. **Lisibilité d'abord** (DS §1.1) : aucun son ne doit gêner la concentration. Pas de stinger musical à chaque cas.
2. **Le jaune sonne Consortium, le magenta sonne rébellion** (DS §1.6) : carillon 3 notes = autorité ; glitch radio = résistance. On ne mélange jamais.
3. **Tout son critique a un équivalent visuel** (et inversement) — cf. §9 Accessibilité.
4. **Ducking** : la voix (`Voice`) baisse l'ambiance et la musique ; un tampon baisse brièvement tout sauf `UI`.

---

## 2. Architecture des bus

Fichier : `res://default_bus_layout.tres` (chemin par défaut de Godot, aucune entrée `project.godot`), **généré** depuis `scripts/audio/audio_buses.gd` (`AudioBuses`, source de vérité des noms et effets) par `tools/build_audio.gd`.

```
Master ── Limiter (ceiling −1 dBTP)
 ├── Music      ── (sidechain-like ducking via script) ; M14 : effet « Fade » (fondus globaux, §13.2)
 ├── Ambience   ── LowPassFilter (automatisé), Reverb "Station"
 ├── SFX        ── Compressor léger
 │    └── SFX_World  (send) ── Reverb "Station" (sons 3D côté passager / hall)
 ├── Voice      ── BandPass "Hygiaphone" + Reverb "Booth" + Compressor
 └── UI         ── (sec, aucun effet)
```

| Bus | Effets (ordre) | Réglages de départ | Notes |
|---|---|---|---|
| `Master` | `AudioEffectLimiter` | ceiling −1 dB, threshold −3 dB | Option **Mono** : `AudioServer` → script qui somme L/R (cf. §9) |
| `Music` | `AudioEffectAmplify` (« Duck »), `AudioEffectLowPassFilter` (« Muffle », désactivé par défaut), `AudioEffectAmplify` (« Fade », M14) | cutoff 20 kHz → 2,5 kHz en pause/menu ; Fade 0 dB | Volume ducké de −6 dB pendant une voix ; **Fade** = seul gain animé de la musique (D-176, D-083 ; §13.2) |
| `Ambience` | `AudioEffectLowPassFilter`, `AudioEffectReverb` (« Station ») | LPF 8 kHz (vitre), reverb room 0,8, damping 0,4, wet 0,25 | LPF descend à 4 kHz quand l'intercom est **off** (l'extérieur se referme) |
| `SFX` | `AudioEffectCompressor` | ratio 3:1, threshold −12 dB, attack 5 ms | Tampons, fente, hologrammes, pas |
| `SFX_World` (enfant de `SFX`) | `AudioEffectReverb` (« Station ») | wet 0,2 | Sons 3D derrière la vitre (pas, porte station) |
| `Voice` | `AudioEffectBandPassFilter` (« Hygiaphone »), `AudioEffectEQ6`, `AudioEffectReverb` (« Booth »), `AudioEffectCompressor` | BP centre 1,6 kHz, resonance 0,5 (≈ 300 Hz–4 kHz) ; reverb room 0,15, wet 0,12, predelay 8 ms ; comp 4:1 | Intercom **off** → BP centre 900 Hz + volume −8 dB (on entend « à travers le verre ») |
| `UI` | aucun | — | Jamais ducké, jamais filtré (feedback garanti) |

**Ducking** : Godot n'a pas de sidechain natif. Un nœud `AudioDirector` (instancié par `day.tscn`, pas un autoload — cf. ARCHITECTURE P6) écoute l'EventBus et tween les `volume_db` des bus (`Music` −6 dB, `Ambience` −4 dB, attaque 80 ms, release 400 ms) quand un bark démarre/finit.

**Réglages joueur** (`Settings`, persistés dans `user://settings.cfg`) : `volume_master`, `volume_music`, `volume_ambience`, `volume_sfx`, `volume_voice`, `volume_ui` (0–100 %, conversion `linear_to_db`), `audio_mono` (bool), `subtitles` (bool, **ON par défaut**), `subtitle_size`. Application sur `EventBus.settings_changed`.

---

## 3. Passager (3D)

- Nœud `AudioStreamPlayer3D` **`VoiceEmitter`** attaché à l'os tête (bus `Voice`) et **`FootEmitter`** attaché à la racine (bus `SFX_World`), + **`BodyEmitter`** au torse (souffle, froissement, bus `SFX`).
- `attenuation_model = ATTENUATION_INVERSE_DISTANCE`, `unit_size = 3`, `max_distance = 20`, `doppler` off. `panning_strength = 0.6` (on garde le passager lisible même en stéréo étroite).
- **Pas** : déclenchés par **method tracks** dans les clips `walk` et `leave` (`_on_footstep(foot: StringName)`) aux frames de contact. Le script choisit le stream selon la surface (`surface = &"metal_wet"` pour le MVP ; prévu : `metal_dry`, `grating`, `rubber_mat`).
- **Variations** : `AudioStreamRandomizer` par famille — `random_pitch = 1.08` (±8 %), `random_volume_offset_db = 2.0`, `playback_mode = PLAYBACK_RANDOM_NO_REPEATS`, 6 à 8 samples par surface. Pied gauche/droit : léger décalage de pitch (−2 %/+2 %) pour casser la régularité.
- **Morphologie** : un paramètre `weight_class` (`light`/`medium`/`heavy`) décale le pitch de base (+6 % / 0 / −8 %) et le volume (−2 / 0 / +2 dB). Pas d'assets supplémentaires.

---

## 4. Cue sheet

Légende priorité : **P1** critique (jamais volé, jamais coupé) · **P2** important · **P3** confort (peut être coupé si budget dépassé). « Marqueur » = method track dans l'`AnimationPlayer`.

### 4.1 Passager

| ID d'événement | Déclencheur | Bus | 2D/3D | Variations | Priorité |
|---|---|---|---|---|---|
| `passenger.step` | Marqueur `walk`/`leave` → `_on_footstep(foot)` | `SFX_World` | 3D (`FootEmitter`) | Randomizer 8 samples `metal_wet`, pitch ±8 %, vol ±2 dB, no-repeat ; L/R ±2 % | P3 |
| `passenger.step_stop` | Marqueur fin de `walk` (arrêt au comptoir) | `SFX_World` | 3D | 3 samples (pied qui se pose + petit éclaboussement) | P3 |
| `passenger.queue_advance` | `case_presented` (la file avance d'un pas, hors champ) | `Ambience` | 2D | 4 samples de piétinement lointain | P3 |
| `passenger.breath_idle` | `passenger_arrived` → boucle aléatoire (toutes les 4–9 s) pendant l'inspection | `SFX` | 3D (`BodyEmitter`) | Randomizer 6 samples, pitch ±5 % ; fréquence ×2 si état `nervous` | P3 |
| `passenger.breath_sigh` | `passenger_reaction_triggered(&"shrug")` / `(&"relieved")` | `SFX` | 3D | 4 samples, pitch selon `weight_class` | P2 |
| `passenger.breath_nervous` | `passenger_reaction_triggered(&"nervous")` | `SFX` | 3D | 4 samples (inspiration courte, déglutition) | P2 |
| `passenger.cloth_rustle` | Marqueur clip `present_docs` (main dans la poche) | `SFX` | 3D | 6 samples tissu synthétique/imper mouillé | P3 |
| `passenger.paper_rustle` | `documents_presented` (froissement avant glisse dans la fente) | `SFX` | 3D | 5 samples (papier, plastique de carte) | P2 |
| `passenger.bark_greet` | `passenger_arrived` (après `step_stop`, délai 0,3 s) | `Voice` | 3D (`VoiceEmitter`) | 3–4 lignes, pitch ±4 % par passager (seedé) | P1 |
| `passenger.bark_present` | `documents_presented` | `Voice` | 3D | 3–4 lignes | P1 |
| `passenger.bark_answer` | `interrogation_answered(topic, line_key)` → `line_key` = ID du bark | `Voice` | 3D | Ligne exacte (pas aléatoire : sens porté par le sous-titre) | P1 |
| `passenger.bark_nervous` | `passenger_reaction_triggered(&"nervous")` | `Voice` | 3D | 2–3 lignes | P1 |
| `passenger.bark_angry` | `passenger_reaction_triggered(&"angry")` | `Voice` | 3D | 2–3 lignes | P1 |
| `passenger.bark_shrug` | `passenger_reaction_triggered(&"shrug")` | `Voice` | 3D | 2 lignes (ou soupir seul, 50 %) | P2 |
| `passenger.bark_relieved` | `passenger_reaction_triggered(&"relieved")` | `Voice` | 3D | 2–3 lignes | P1 |
| `passenger.bark_depart` | `passenger_departed` (avant 1er pas de `leave`) | `Voice` | 3D | 2 lignes selon verdict (neutre / amer) | P2 |
| `passenger.knock_glass` | `passenger_reaction_triggered(&"angry")` (30 % de chance) | `SFX` | 3D | 3 samples poing sur vitre, LPF | P3 |

### 4.2 Guichet (diégétique, côté joueur)

| ID d'événement | Déclencheur | Bus | 2D/3D | Variations | Priorité |
|---|---|---|---|---|---|
| `booth.slot_in` | `documents_presented` (+ marqueur `present_docs` frame de dépôt) | `SFX` | 3D (fente, proche) | 4 samples : clapet métal + glissement | P1 |
| `booth.slot_out` | `case_resolved` (documents rendus) | `SFX` | 3D | 4 samples (clapet inverse) | P2 |
| `booth.holo_on` | `documents_presented(case_id)` (chaque doc projeté, échelonné par l’UI) | `SFX` | 2D | Swell filtré 300 ms + grain ; pitch ±3 % ; 3 variantes | P1 |
| `booth.holo_off` | `case_resolved` / fermeture d'un doc | `SFX` | 2D | Swell inversé 150 ms, 2 variantes | P2 |
| `booth.holo_hum` | Boucle tant qu'au moins un doc est ouvert | `SFX` | 2D | Boucle −28 dB, modulée par `inspection_mode_changed` (+4 dB, LPF ouvert) | P3 |
| `booth.inspect_mode_on` / `_off` | `inspection_mode_changed(enabled)` | `UI` | 2D | 1 sample chacun (scanner qui s'arme / se coupe) | P2 |
| `booth.stamp_approved` | `verdict_stamped(verdict)` avec `APPROVED` | `SFX` | 2D | 3 samples : impact lourd + clic métallique aigu ; pitch ±2 % | P1 |
| `booth.stamp_denied` | `verdict_stamped(verdict)` avec `DENIED` | `SFX` | 2D | 3 samples : impact lourd + buzz grave | P1 |
| `booth.stamp_lift` | Marqueur anim tampon (remontée) | `SFX` | 2D | 2 samples ressort | P3 |
| `booth.intercom_on` | `passenger_arrived` (le joueur « ouvre » le micro) ou action joueur | `SFX` | 2D | Clic + souffle de larsen bref, 2 variantes | P2 |
| `booth.intercom_off` | `passenger_departed` | `SFX` | 2D | Clic + coupure, 2 variantes | P2 |
| `station.door_open` | `case_presented` (la porte du hall s'ouvre pour le passager) | `SFX_World` | 3D (fond de scène) | 2 samples sas pneumatique | P2 |
| `station.door_close` | `passenger_departed` + 2,5 s (ou marqueur fin `leave`) | `SFX_World` | 3D | 2 samples | P3 |
| `booth.printer_citation` | `citation_issued(reason_key)` | `SFX` | 2D | Imprimante thermique 1,2 s, 2 variantes | P1 |

### 4.3 UI (non-diégétique / holographique — reprend DS §9)

| ID d'événement | Déclencheur | Bus | 2D/3D | Variations | Priorité |
|---|---|---|---|---|---|
| `ui.hover` | `mouse_entered` / focus (Control) | `UI` | 2D | Tick −18 dB, pitch ±3 % | P3 |
| `ui.field_select_a` | Sélection champ A (UI → avant `discrepancy_check_requested`) | `UI` | 2D | Blip sinus pitch montant (base) | P2 |
| `ui.field_select_b` | Sélection champ B | `UI` | 2D | Même blip, **+1 quinte** (lien perceptible A→B) | P2 |
| `ui.link_drag` | Tracé A→B en cours | `UI` | 2D | Boucle bourdon électrique, pitch suit la longueur | P3 |
| `ui.match` (CONCORDANT) | `discrepancy_checked(result)` avec `confirmed == false` | `UI` | 2D | Note neutre descendante, 1 sample | P1 |
| `ui.discrepancy` (DISCORDANCE) | `discrepancy_checked(result)` avec `confirmed == true` | `UI` | 2D | Seconde mineure dissonante, 2 variantes | P1 |
| `ui.rule_new` | `day_started` (si règles ajoutées vs jour précédent) | `UI` | 2D | **Carillon Consortium 3 notes** | P1 |
| `ui.timer_warning` | `day_clock_ticked(remaining_sec)` franchit le seuil warning (ex. 60 s) | `UI` | 2D | Bip unique | P1 |
| `ui.timer_critical_tick` | `day_clock_ticked` sous seuil critical (ex. 15 s), 1 Hz | `UI` | 2D | Tick, pitch +1 demi-ton toutes les 5 s | P1 |
| `ui.citation_chime` | `citation_issued(reason_key)` (après imprimante) | `UI` | 2D | Carillon Consortium **mineur** | P1 |
| `ui.toast_info` / `_success` / `_error` | Toasts UI | `UI` | 2D | Variantes du blip (neutre / montant / descendant) | P2 |
| `ui.rebel_message` | (narratif, hors MVP) | `UI` | 2D | Glitch radio + voix filtrée | P2 |

### 4.4 Ambiance

| ID d'événement | Déclencheur | Bus | 2D/3D | Variations | Priorité |
|---|---|---|---|---|---|
| `amb.rain_glass` | `day_started` → boucle (fade-in 2 s) | `Ambience` | 2D stéréo | 1 boucle 60 s + one-shots gouttes lourdes aléatoires (4–12 s) | P2 |
| `amb.neon_hum` | `day_started` → boucle | `Ambience` | 2D | Boucle 20 s ; grésillement one-shot sur `booth.holo_on` (20 %) | P3 |
| `amb.station_bed` | `day_started` → boucle | `Ambience` | 2D stéréo | Ventilation + rumeur hall, boucle 32 s ; **M14** : variante par acte (`amb.station_bed_a2` : ventilation qui siffle, alarme lointaine rare ; `_a3` : rumeur de foule au quai) et monde D du J31 (`_d` : vent de poussière), §13.10 | P2 |
| `amb.queue_murmur` | `day_started` → boucle ; **M14** : volume ∝ silhouettes visibles (`queue_progressed`, 0 → −6 dB, une écriture par avance de la file) | `Ambience` | 2D | Murmures inintelligibles (langage inventé), boucle 22 s + toux/one-shots | P3 |
| `amb.pa_announce` | **M14** : annonces **de jeu** seulement (`hall_announced` : bandeau « HAUT-PARLEUR · HALL ») — le minuteur aléatoire est retiré | `Ambience` | 2D | 3 fichiers : carillon Consortium + voix PA borborygme filtrée | P3 |
| `amb.pa_ambient` | **M14** (VH-6) : `PaScheduler` (45–75 s puis 90–180 s, ≤ 6 par shift, exclusions) | `Ambience` (lecteur `PAVoice`) | 2D | 52 lignes `pa_*` (lot E) : jingle (MO-1 ; monde B adouci ; monde A + bip ; monde D : MO-2) + voix Tessar **synthétisée à l'exécution** ; sous-titre « [Haut-parleur] » via `ambient_announced` ; 0 octet sur disque, §13.10 | P3 |
| `amb.stop_all` | `day_ended` → fade-out 3 s | — | — | — | — |

### 4.5 Musique (états)

> **M14 (phase 2)** : remplacé par la musique dynamique en couches (§13 ; docs/M14.md §2). `AudioDirector.set_music()`, ses deux lecteurs et ses tweens sont **supprimés** ; les boucles `mus_*` ci-dessous n'existent plus (historique M6).

Lecteur unique `AudioStreamPlayer` (bus `Music`) avec **`AudioStreamInteractive`** (Godot 4.3+) : transitions synchronisées sur la mesure, fades 2–4 s.

| État / clip | Déclencheur | Contenu | Niveau relatif | Priorité |
|---|---|---|---|---|
| `mus.briefing` | Écran briefing avant `day_started` | Nappe + motif Consortium exposé, 80 BPM, boucle 90 s | 0 dB (premier plan) | P2 |
| `mus.shift_calm` | `day_started` | Pulsation basse + nappe, très peu mélodique, boucle 120 s | −8 dB vs briefing | P2 |
| `mus.shift_tension` | `day_clock_ticked` < 25 % du temps restant | Même tonalité, + hi-hat/arp, filtre qui s'ouvre (transition sur la mesure) | −6 dB | P2 |
| `mus.debrief` | `day_ended(summary)` | Nappe résolutive ; variante mineure si solde négatif (`summary`) | 0 dB | P2 |
| `mus.stinger_citation` | — | **Pas de stinger musical** (carillon UI suffit) | — | — |

---

## 5. Barks vocaux

### 5.1 Recommandation : **langage inventé (« borborygmes filtrés ») + sous-titres FR**

| Critère | Voix FR enregistrées | Langage inventé + sous-titres |
|---|---|---|
| Coût production MVP | Élevé (casting, ~20 lignes × N voix) | Faible (quelques comédiens/TTS, syllabes recombinables) |
| Localisation | À refaire par langue | **Zéro** : seuls les sous-titres se traduisent |
| Variété des passagers | Limitée par le nb de voix | Pitch/formants + recombinaison → beaucoup de « voix » |
| Diégèse | Peut sonner « doublage » | Station multiculturelle de 2187 : crédible (langues de factions) |
| Charge cognitive | Le joueur écoute **et** lit | Le sens passe par le texte → le joueur garde les yeux sur les documents |
| Accessibilité | Bon si sous-titré | Équivalent (sous-titres obligatoires dans les deux cas) |
| Risque | Fausse note de jeu = immersion cassée | Peut sembler « gadget » si mal mixé |

**Recommandation** : langage inventé pour tous les barks MVP, **sous-titres FR toujours affichés dans la bulle (DS §7.10)**, l'option « sous-titres » ne pilotant que le doublage non-diégétique (annonces PA, murmures). Justification : coût, zéro localisation audio, cohérence avec le genre (Papers, Please), et le sens reste lisible pendant la lecture comparative. **Exception possible** : la voix PA du Consortium en FR robotique (TTS) pour la signature de marque — à valider.

Production du langage inventé : 1 banque de ~60 syllabes par « famille de voix » (4 familles MVP : grave, médium, aigu, voix âgée), assemblées procéduralement ou pré-montées par ligne ; intonation calquée sur la phrase FR (question montante, colère accentuée). Le bus `Voice` (hygiaphone) fait le reste.

### 5.2 Liste des barks MVP (FR = sous-titre ; durée cible 0,5–2 s)

| ID (`line_key`) | Catégorie | Sous-titre FR | Durée | Note de jeu |
|---|---|---|---|---|
| `bark_greet_01` | Arrivée | « Bonsoir. » | 0,6 s | Fatigué |
| `bark_greet_02` | Arrivée | « C'est bien ici, le contrôle ? » | 1,4 s | Hésitant |
| `bark_greet_03` | Arrivée | « Enfin mon tour… » | 1,0 s | Soupir |
| `bark_present_01` | Présentation | « Voici mes papiers… » | 1,2 s | Neutre (demande client) |
| `bark_present_02` | Présentation | « Tout est en règle. » | 1,0 s | Assuré |
| `bark_present_03` | Présentation | « Tenez. » | 0,5 s | Sec |
| `bark_answer_purpose_work` | Interrogatoire | « Je viens pour le travail. » | 1,3 s | Réponse topic `purpose` |
| `bark_answer_purpose_family` | Interrogatoire | « Je rends visite à ma famille. » | 1,5 s | Réponse topic `purpose` |
| `bark_answer_duration` | Interrogatoire | « Trois jours, pas plus. » | 1,2 s | Réponse topic `duration` |
| `bark_answer_origin` | Interrogatoire | « J’arrive de la colonie Tycho. » | 1,6 s | Réponse topic `origin` (nom à valider Lore) |
| `bark_answer_mismatch` | Interrogatoire | « Ça doit être une erreur du système. » | 1,8 s | Face à une discordance |
| `bark_nervous_01` | Nerveux | « Il y a un problème ? » | 1,0 s | Voix qui monte |
| `bark_nervous_02` | Nerveux | « Je… je peux expliquer. » | 1,3 s | Hésitation |
| `bark_angry_01` | Colère | « Vous vous fichez de moi ?! » | 1,2 s | Accentué |
| `bark_angry_02` | Colère | « J'attends depuis des heures ! » | 1,4 s | Frappe possible sur la vitre |
| `bark_shrug_01` | Haussement d'épaules | « Si vous le dites. » | 0,9 s | Résigné |
| `bark_shrug_02` | Haussement d'épaules | « Hmf. » | 0,5 s | Souffle seul |
| `bark_relieved_01` | Soulagé | « Merci… vraiment. » | 1,1 s | Expiration |
| `bark_relieved_02` | Soulagé | « Ouf. Bonne soirée. » | 1,0 s | |
| `bark_depart_ok` | Départ | « Gloire au Consortium. » | 1,2 s | Formule rituelle (ironique ou non) |
| `bark_depart_denied` | Départ | « Vous n'avez pas de cœur. » | 1,3 s | Après refus |

Les textes vivent dans les fichiers de traduction (`tr("bark_present_01")`), jamais en dur. Le Lore Master valide les noms propres.

### 5.3 Sous-titres

- Affichés dans la **bulle passager** (DS §7.10) synchronisée au début du stream ; durée d'affichage = `max(durée audio + 0,8 s, 1,5 s)`.
- Les sons non verbaux significatifs (annonces PA, frappe sur la vitre) ont des **sous-titres descriptifs** optionnels entre crochets : `[Annonce lointaine du Consortium]`, `[Il frappe sur la vitre]`.

---

## 6. Budget et voix simultanées

| Bus | Voix max simultanées | Politique de vol |
|---|---|---|
| `Music` | **1 lecteur** (M14 : `MusicDirector`, ≤ 5 couches Vorbis dans le flux + fondu croisé de 2 mesures → ≤ 8 flux décodés) | — |
| `Ambience` | 6 (4 boucles + 2 one-shots) | Coupe le plus ancien one-shot P3 |
| `SFX` + `SFX_World` | 10 | Vole la voix P3 la plus faible ; P1 jamais volé |
| `Voice` | **1 bark** (+1 PA) | Un nouveau bark P1 coupe le bark en cours (fade 60 ms) ; pas de chevauchement de barks |
| `UI` | 4 | `ui.hover` limité à 1 instance (`max_polyphony = 1`) |
| **Total** | **≤ 24 voix** | `AudioStreamPlayer.max_polyphony` par émetteur ; un pool de 8 `AudioStreamPlayer` 2D réutilisés pour SFX/UI |

Mémoire cible MVP : ≤ 40 Mo audio en RAM (SFX WAV chargés, musique/ambiances OGG streamées).

---

## 7. Mix — niveaux cibles indicatifs

Mesure en LUFS intégré (court-terme pour les SFX), sortie Master stéréo, volume joueur à 100 %.

| Élément | Cible | Remarque |
|---|---|---|
| **Mix global en jeu** | **−16 LUFS** intégré (± 1), true peak ≤ −1 dBTP | Norme console/PC courante |
| Musique (shift) | −26 à −24 LUFS | Sous l'ambiance pendant le travail |
| Musique (briefing/bilan) | −20 LUFS | Premier plan |
| Ambiance totale | −28 à −24 LUFS | Pluie + station + néon |
| Voix (barks) | −18 à −16 LUFS court-terme | Toujours intelligible, ducking actif |
| Tampons | crête −6 dBFS, ≈ −14 LUFS court-terme | Le son le plus « gros » du jeu |
| SFX guichet (fente, holo) | −20 à −18 LUFS court-terme | |
| Pas passager | −30 à −26 LUFS court-terme | Discrets, derrière la vitre |
| UI | −22 à −18 LUFS court-terme ; hover −30 | Courts, secs |

Masters normalisés à **−1 dBTP** à l'export ; le gain de mix se fait dans Godot (`volume_db`), pas dans les fichiers.

---

## 8. Conventions de fichiers

### 8.1 Nommage

`<catégorie>_<sujet>_<action>[_<variante>]_<NN>.<ext>` — minuscules, `snake_case`, ASCII sans accents, index sur 2 chiffres.

| Catégorie | Exemples |
|---|---|
| `sfx_passenger_*` | `sfx_passenger_step_metal_wet_01.wav`, `sfx_passenger_breath_nervous_03.wav`, `sfx_passenger_paper_rustle_02.wav` |
| `sfx_booth_*` | `sfx_booth_stamp_approved_01.wav`, `sfx_booth_slot_in_02.wav`, `sfx_booth_holo_on_01.wav`, `sfx_booth_intercom_off_01.wav` |
| `sfx_station_*` | `sfx_station_door_open_01.wav` |
| `ui_*` | `ui_field_select_a_01.wav`, `ui_discrepancy_01.wav`, `ui_timer_critical_tick_01.wav`, `ui_rule_new_01.wav` |
| `vo_<voix>_<line_key>` | `vo_low_bark_present_01.wav`, `vo_high_bark_angry_02.wav`, `vo_pa_announce_03.ogg` |
| `amb_*` | `amb_rain_glass_loop.ogg`, `amb_station_bed_loop.ogg`, `amb_rain_drop_heavy_04.wav` |
| `mus_<ensemble>_<couche>_loop` (M14) | `ms02/mus_ms02_l0_loop.ogg`, `ms01/mus_ms01_bed_loop.ogg`, `ms07/mus_ms07_world_d_loop.ogg` |
| `mus_th_<fin>[_<variante>][_tail_loop]` (M14) | `themes/mus_th_f9.ogg`, `themes/mus_th_f9_tail_loop.ogg`, `themes/mus_th_f1_okonkwo_warned.ogg`, `themes/mus_th_f5c_s_tail_loop.ogg` |
| partitions (M14) | `art_src/music/ms01.json` … `thf10.json` (format §13.4) |

Ressources Godot : `<id>.tres` pour les `AudioStreamRandomizer` (ex. `res://assets/audio/sfx/passenger/rnd_passenger_step_metal_wet.tres`).

Arborescence : `res://assets/audio/{sfx/{passenger,booth,station},ui,voice/{low,mid,high,old,pa},ambience,music}/`.

### 8.2 Formats

| Type | Format | Spécs | Import Godot |
|---|---|---|---|
| SFX courts, UI, barks | **WAV** PCM 16 bits | 48 kHz, **mono** (sauf UI stéréo si besoin) | `compress/mode = IMA ADPCM` pour les longs (> 2 s), sinon PCM ; `force/mono` pour la 3D |
| Musique | **OGG Vorbis** | 48 kHz stéréo, q6 (~192 kbps) | `loop = true`, `bpm`, `beat_count`, `bar_beats` renseignés (pour `AudioStreamInteractive`) |
| Ambiances (boucles) | **OGG Vorbis** | 48 kHz stéréo, q5 | `loop = true`, boucles sans clic (crossfade dans le fichier) |
| One-shots d'ambiance | WAV | 48 kHz mono | |

Tous les sons 3D sont **mono** (sinon Godot ne les spatialise pas correctement).

---

## 9. Accessibilité

| Besoin | Mesure |
|---|---|
| Sourds / malentendants | Sous-titres des barks **toujours** visibles dans la bulle ; sous-titres descriptifs optionnels (PA, frappe vitre, porte) |
| Mixage personnel | 6 sliders (Master + 5 bus) dans Options → Audio |
| Audition unilatérale | Option **Mono** (somme L/R sur `Master`, et `panning_strength = 0` pour les `AudioStreamPlayer3D`) |
| Sons critiques doublés visuellement | Timer bas → pulse barre (DS §8.3) + couleur + icône ; tampon → animation + empreinte visible ; discordance → trait magenta + chip « ≠ » ; concordance → chip « = » ; citation → ticket imprimé à l'écran ; règle nouvelle → RuleCard + badge ambre ; arrivée passager → animation + bulle |
| Hypersensibilité | Option « réduire les effets » : coupe `ui.timer_critical_tick` (garde le visuel), adoucit tampons (−4 dB), retire glitches |
| Ne jamais cacher une info | Aucune information de gameplay transmise **uniquement** par le son (règle de revue) |

---

## 10. Sources et licences

| Source | Licence | Usage prévu | Vigilance |
|---|---|---|---|
| **Kenney** (Interface Sounds, Sci-Fi Sounds, Impact Sounds) — kenney.nl | CC0 | UI, holo, impacts de tampon (base à retravailler) | Aucune ; créditer par courtoisie |
| **Freesound** — freesound.org | CC0 / **CC BY** | Pluie, pas sur métal, ambiances de hall, papier | **CC BY = attribution obligatoire** (auteur + titre + lien + licence dans les crédits). **CC BY-NC interdit** (projet commercial). Vérifier chaque fichier individuellement |
| **Sonniss GDC Game Audio Bundles** — sonniss.com/gameaudiogdc | Licence royalty-free Sonniss | Ambiances industrielles, mécaniques, portes | Usage commercial OK, **redistribution des sons bruts interdite** ; conserver la copie de la licence |
| **OpenGameArt** — opengameart.org | Variable (CC0, CC BY, CC BY-SA, GPL) | Complément | Éviter CC BY-SA / GPL (contaminants) sauf validation |
| **TTS / génération de voix** (plus tard) | Selon le service | Voix PA, barks de base | **Vérifier les droits commerciaux** des voix générées selon le plan/abonnement du service utilisé (certains interdisent l'usage commercial ou exigent une mention) ; conserver les CGU datées ; pas de clonage de voix réelle sans consentement écrit |

### 10.1 Registre des licences

À tenir à jour à chaque import (et à reporter dans `docs/ASSETS.md` / écran Crédits).

| Fichier (`res://…`) | Source (URL) | Auteur | Licence | Attribution requise | Modifié ? | Date d'import | Importé par |
|---|---|---|---|---|---|---|---|
| `assets/audio/sfx/passenger/sfx_passenger_step_*`, `step_stop_*`, `knock_glass_*` ; `assets/audio/ambience/amb_queue_advance_*` | kenney.nl/assets/impact-sounds (Impact Sounds 1.0 : `footstep_concrete_*`, `impactMetal_light_*`, `impactGlass_heavy_*`, `impactSoft_heavy_*`) | Kenney | CC0 1.0 | non (crédit de courtoisie) | oui : rééchantillonnage, filtres, superposition d'éclaboussures synthétiques | 2026-10-27 | Audio Designer |
| `assets/audio/sfx/booth/sfx_booth_stamp_*`, `slot_in_*`, `slot_out_*` | kenney.nl/assets/impact-sounds (`impactPlate_heavy_*`, `impactPunch_heavy_*`, `impactMetal_light_*`) + kenney.nl/assets/interface-sounds (`click_*`) | Kenney | CC0 1.0 | non | oui : couches + clic métallique / buzz synthétiques, saturation douce | 2026-10-27 | Audio Designer |
| `assets/audio/sfx/booth/sfx_booth_intercom_*` | kenney.nl/assets/interface-sounds (`switch_*`) | Kenney | CC0 1.0 | non | oui : + souffle de larsen synthétique | 2026-10-27 | Audio Designer |
| `assets/audio/sfx/station/sfx_station_door_*` ; chocs du lit `amb_station_bed_loop.ogg` | kenney.nl/assets/sci-fi-sounds (`doorOpen_*`, `doorClose_*`) + impact-sounds (`impactMetal_heavy_*`) | Kenney | CC0 1.0 | non | oui : sifflement pneumatique, passe-bas « lointain » | 2026-10-27 | Audio Designer |
| Tous les autres fichiers de `assets/audio/` (UI, holo, imprimante, souffles, papiers, pluie, néon, murmure, annonces PA, musique) | synthèse procédurale `tools/build_audio.gd` (graines fixes) ; voix : `TessarVoice` | studio CLEARANCE | propriété du projet | — | — | 2026-10-27 | Audio Designer |
| Barks des passagers (aucun fichier) | synthèse à l'exécution `scripts/audio/tessar_voice.gd` | studio CLEARANCE | propriété du projet | — | — | — | Audio Designer |

Régénération : `bash tools/fetch_assets.sh` (packs Kenney dans `art_src/downloads/`, ignoré par git) puis `bash tools/build_audio.sh` (ffmpeg + libvorbis requis).

---

## 11. Signaux EventBus — note d'intégration

Les signaux `passenger_arrived`, `documents_presented`, `passenger_reaction_triggered(reaction: StringName)` et `passenger_departed` sont utilisés ici mais **absents du catalogue `docs/ARCHITECTURE.md` §7** (qui contient `document_handed`). À ajouter par le Godot Architect. Valeurs de `reaction` attendues par l'audio : `&"nervous"`, `&"angry"`, `&"shrug"`, `&"relieved"`.

L'`AudioDirector` (nœud de `day.tscn`) est le **seul** écouteur audio de l'EventBus pour les sons 2D/musique/ambiance ; les sons 3D du passager sont joués par la scène passager (method tracks + écoute des signaux de réaction).

---

## Questions ouvertes (à valider)

1. Langage inventé pour les barks MVP (recommandé) — ou voix FR ? Voix PA du Consortium en FR TTS robotique ?
2. Ajout au catalogue EventBus des 4 signaux passager (§11) + éventuel `intercom_toggled(enabled)` si l'intercom devient une action joueur.
3. Seuils timer warning / critical (60 s / 15 s proposés) : à aligner avec le Game Design et DS §7.6.
4. Formule rituelle « Gloire au Consortium » : validation Lore Master.
5. ~~`AudioStreamInteractive` (Godot 4.3+) pour la musique : OK côté Godot Architect ?~~ **Close** (M14, D-176) : oui, avec des clips `AudioStreamSynchronized` — prototype de stress D-083 passé (§13.3).

## 12. Implémentation M6 (état réel)

| Élément | Implémentation | Écart vs §2–§8 |
|---|---|---|
| Bus | `AudioBuses` → `default_bus_layout.tres` : Master [Mono (StereoEnhance `pan_pullout=0`, off), HardLimiter −1 dB] ; Music [Duck, Muffle LPF 2,5 kHz (pause)] ; Ambience [Duck, LPF 8 kHz, Reverb Station] ; SFX [Compressor 3:1] → SFX_World [Reverb Hall] ; Voice [Duck, HP 380 Hz + LP 3,4 kHz (« Hygiaphone »), EQ6, grain, Reverb Booth, Compressor 4:1] ; UI sec | Hygiaphone = HP+LP (au lieu d'un BandPass unique, plus large et intelligible) ; filtre « intercom off » non fait (pas d'action intercom) |
| Ducking | Effets `AudioEffectAmplify` « Duck » pilotés par `AudioDirector` (voix : Music −6 / Ambience −4, 80/400 ms ; tampon : −3 dB 150 ms sur Music/Ambience/Voice) | Les volumes joueur restent sur `volume_db` des bus (Settings), sans conflit |
| Réglages | `Settings` applique volumes **et** `audio_mono` (nouvelle clé) ; `PassengerAudio` met `panning_strength = 0` en mono | Le toggle Mono n'est pas encore dans `OptionsPanel` (UI/UX) |
| Directeur | `scripts/audio/audio_director.gd` (nœud `AudioDirector` de `day.tscn`), pools `VoicePool` : SFX 8, SFX_World 2, UI 4, Ambience 2 (+ 4 boucles, 2 lecteurs musique, 1 bourdon holo, 1 voix 2D de secours) ; vol P3→P1, P1 jamais volé ; polyphonie par cue | Pas d'`AudioStreamRandomizer` en `.tres` : construits en code depuis `AudioCueBank` |
| Passager 3D | `PassengerAudio` ajouté **à l'exécution** sous chaque `PassengerActor` du pool (`BoothDirector.actors`) : FootEmitter (SFX_World), BreathEmitter / BodyEmitter (SFX), VoiceEmitter (Voice) ; écoute `anim_event` et `arrived` ; respirations d'attente 4–9 s (÷2 nerveux). `AudioListener3D` « AgentEars » placé à 1,3 m du comptoir côté caméra (la caméra télé est trop loin pour l'atténuation) ; écoute 3D activée sur le viewport du booth | Émetteurs à hauteur fixe (pas d'os) : le rig final change en parallèle |
| Barks | `TessarVoice` : phrase du lexique LORE §10 sinon syllabes V/CV/CVn/s/r tirées de la clé (longueur ∝ sous-titre, `sa?` final pour une question) ; synthèse source-filtre 16 kHz (impulsions de Rosenberg, 3 formants interpolés, bruits filtrés pour s/sh/h/v et occlusives) ; timbre par passager (sexe → f0, tranche d'âge → jitter/vibrato, taille → formants, graine d'apparence → ±) ; prosodie par humeur (accent pénultième, déclinaison, colère/nervosité/soulagement). Rendu dans un `WorkerThreadPool` (~25–55 ms) + cache 48 | Pas de banque de syllabes enregistrées ; aucun fichier voix |
| Musique | 5 boucles 24 s à 80 BPM (briefing, shift calme, shift tension < 25 % du temps, bilan, bilan mineur si solde négatif), fondus 2,5 s entre 2 lecteurs | `AudioStreamInteractive` non utilisé (transitions sur la mesure à faire si besoin) |
| Formats | SFX/UI/one-shots : WAV 16 bits mono 48 kHz ; boucles : OGG Vorbis 48 kHz stéréo (q4–5), `loop`/`bpm` dans les `.import` ; total ≈ 9 Mo | — |

**Cues couvertes** : toutes celles de §4 sauf `ui.link_drag` et `ui.rebel_message` (post-MVP). Branchées lors de la passe de finition : `passenger.bark_depart` (sous-titré 1,5 s après le tampon via `ComparisonUI.departure_line_shown`), `booth.stamp_lift` (0,4 s après le tampon), `ui.hover` (signal `ComparisonUI.hovered`, 90 ms minimum entre deux) et `ui.toast_*` (signal `toast_shown(kind)`). Sondes UI sans modifier l'UI : `ComparisonUI.selection.a` (sélection A) et `tool_bar.stamps[*].is_holding()` (tampon maintenu, `ui.stamp_hold`).

**M7 (interfaces J4–J10) — cues existantes réutilisées, aucun nouveau fichier** :

| Événement | Cue | Doublage visuel |
|---|---|---|
| Objet glissé avec les papiers (`item_slipped`) | `passenger.paper_rustle` (+0,45 s) | carte de l'objet sur le plan |
| Décision : garder / rendre / remettre à la Garde (`item_decided`) | `passenger.paper_rustle` / `booth.slot_out` / `booth.intercom_on` | puce d'état de l'objet, toast « Objet remis à la Garde » |
| Répliques hors interrogatoire (`_bribe*`, `_password`) | bark Tessar via `ComparisonUI.passenger_line_shown` | sous-titre + bulle |
| Trois tapes sur la vitre (code 5, `BoothDirector.glass_knocked`) | `passenger.knock_glass` ×3 (émetteur du corps) | ondes sur la vitre + didascalie |
| Annonce du Hall (`hall_announced`) | `amb.pa_announce` (bus Ambience) ; l'annonce aléatoire suivante est repoussée | bandeau « HAUT-PARLEUR · HALL » (toast si sous-titres coupés) |
| Escorte de la Garde (`escort_started` / `escort_finished`) | `station.door_open` / `station.door_close` | Garde 3D, lumière de porte jaune |
| Sortie détenue / refusée scénarisée (`_exit_detain`, `_exit_deny`) | humeur nerveuse / en colère du bark de départ | sous-titre « [en partant] » |

**M8 (interfaces de l'Acte II) — cues existantes réutilisées, aucun nouveau fichier ni branchement dans `AudioDirector`** :

| Événement | Cue (déjà branchée) | Doublage visuel |
|---|---|---|
| Lien suggéré du scanner confirmé (`confirm_suggestion` → `discrepancy_check_requested`) | cue d'évaluation du lien puis `discrepancy_checked` (comme une sélection A → B) | pointillé → fil → discordance numérotée |
| Compteur plein (`hall_quota_full`) | `amb.pa_announce` | compteur ambre « ATTEINT » + bandeau du haut-parleur |
| Grève du J20 (`hall_j20_strike`, lumières coupées) | `amb.pa_announce` ; la sirène de fin de shift reste celle du `day_ended` existant | lampes du guichet éteintes, voile noir, fondu au noir avant le bilan |
| Confirmation « Embarquer » (soirée du J10) | `ui.hover` / clics de boutons existants | boîte « QUITTER HALCYON ? » |

À proposer à l'Audio Designer (post-M8) : une coupure de bourdonnement (« power down ») sur la grève du J20 et un *tick* discret par lien suggéré.

**M9 (interfaces de l'Acte III) — aucune cue nouvelle ni branchement** : carte « FIN DE L'ACTE II », « CHAPITRE III », verdict de la Déposition et onglets Main courante / Convocations utilisent les clics et survols existants ; une comparaison Répondant ↔ Main courante passe par les cues d'évaluation habituelles. À proposer : carillon grave « quota suspendu » et annonce de la Transit-7 (ACT3 §8.3).

**Accessibilité vérifiée** : chaque cue critique a son doublage visuel existant (timer : barre ambre/rouge ; tampon : animation + empreinte ; discordance : lien magenta + numéro ; concordance : chip ; citation : ticket ; règle nouvelle : badge NOUVEAU ; barks : sous-titres). « Réduire les effets » (`fx_intensity < 1`) coupe `ui.timer_critical_tick` et adoucit les tampons de 4 dB.

## 13. Musique dynamique M14 — lot B, phases 1 et 2 (état réel)

> Conception : `docs/M14.md` §2 (D-174, D-176 → D-182), cibles §6.2 (D-192), contrat d'interfaces `docs/ARCHITECTURE.md` §12 ter. Phase 1 (§13.1 → §13.6) = **avant validation client** : moteur et prototype de stress D-083 (B82), chaîne de rendu minimale (B79/B80), échantillons MS-02 et TH-F9, audit objectif (B94). Phase 2 (§13.7 → §13.15, après D-198) : production complète (7 ensembles, 14 thèmes de fin + 4 de monde, variantes), branchement dans le jeu, intensité, annonces d'ambiance, lits par acte, mesures CPU et mémoire.

### 13.1 Fichiers

| Fichier | Rôle |
|---|---|
| `scripts/audio/music_director.gd` | `MusicDirector` (nœud de scène) : un lecteur, `AudioStreamInteractive` de clips `AudioStreamSynchronized`, niveaux N0 → N4 à la mesure, fondus par l'effet `Fade` |
| `scripts/audio/audio_buses.gd` → `default_bus_layout.tres` | effet `Fade` (`AudioEffectAmplify`, `AudioBuses.FX_FADE`) ajouté en 3ᵉ position du bus `Music` (UID du fichier conservé par `build_audio.gd`) |
| `scripts/audio/audio_dsp.gd` | briques de synthèse ajoutées (§13.4) |
| `scripts/audio/music_renderer.gd` | `MusicRenderer` : séquenceur, instruments, rendu d'une couche (repli de queue, longueur exacte) |
| `scripts/audio/audio_loudness.gd` | `AudioLoudness` : sonie BS.1770-4 (pondération K, portes −70 / −10) |
| `scripts/audio/ffmpeg_audio.gd` | `FfmpegAudio` : encodage Vorbis déterministe, mesures `ebur128` (outils seulement) |
| `tools/build_music.gd` | rendu des partitions → WAV → OGG + `.import` + `manifest.json` ; `--demos` ; `--defs` (`.tres`) |
| `art_src/music/ms02.json`, `thf9.json` | partitions (format §13.4) |
| `assets/audio/music/ms02/mus_ms02_l{0..4}_loop.ogg` | couches de MS-02 (32 kHz, q3) |
| `assets/audio/music/themes/mus_th_f9.ogg`, `mus_th_f9_tail_loop.ogg` | TH-F9 (48 kHz, q3) |
| `assets/audio/music/sets/ms_02.tres`, `themes/th_f9.tres`, `music_library.tres` | données au format du lot A (`MusicSetDef`, `MusicThemeDef`, `MusicLibraryDef`), écrites par `build_music.gd --defs` |
| `assets/audio/music/manifest.json` | SHA-256 (WAV, OGG), échantillons, LUFS, true peak, LRA, gains des niveaux, hachage des partitions et de l'outil |
| `tools/qa_audio_stress.gd`, `tools/qa_audio_stress.sh` | stress D-083 (M-17) |
| `tools/qa_audio_audit.gd` | audit M-01 → M-09, M-12 |
| `tests/unit/test_music_director.gd`, `tests/unit/test_music_render.gd` | 21 tests GUT (règles de niveau, lecteur unique à volume fixe, rampes, `Fade`, sortie propre, masques `MusicSetDef`, thème → queue, bibliothèque ; briques DSP, longueurs exactes, déterminisme, jointure, linéarité, sonie BS.1770, partitions MO-1/MO-2, manifeste et `.import`) |
| `docs/mockups/m14_music_ms02_demo.ogg`, `m14_music_thf9_demo.ogg` | démos de direction musicale (validation client) |

### 13.2 Moteur (`MusicDirector`, D-176)

- **Un seul** `AudioStreamPlayer` (`MusicPlayer`, bus `Music`), `volume_db = 0` **jamais modifié** (ni tween, ni écriture par image).
- Flux : un `AudioStreamInteractive` dont chaque clip est un ensemble (`AudioStreamSynchronized`, ≤ 5 couches) ou un thème ; transition `CLIP_ANY → CLIP_ANY` à la mesure suivante, fondu croisé de 8 temps (2 mesures) dans le flux ; thème → queue par **avance automatique** du clip (`configure_theme(…, tail)`), `skip_to_tail()` pour une cinématique passée.
- Niveaux : volume de chaque couche par `AudioStreamSynchronized.set_sync_stream_volume()` (lu par le thread de mixage, aucune allocation, aucun `bus_details` remplacé) ; rampe linéaire en amplitude d'**une mesure** ; une écriture au plus par couche et par image, seulement si la valeur change ; couche muette = −80 dB exactement.
- Horloge : Godot 4.7 ne donne pas la position d'un `AudioStreamInteractive` (`get_playback_position()` = 0, vérifié) → horloge de mesures en temps réel (`Time.get_ticks_usec`, insensible à `Engine.time_scale` et à la pause), **sans borne** depuis QA-076 (§13.16). `request_level()` s'applique en début de mesure (+1 toutes les 2 mesures, −1 toutes les 4 ; +1 à chaque mesure au chrono critique, D-211 : `next_level(…, fast)`, pur) ; `force_level()` pour les outils.
- Masques : `configure_from_def(MusicSetDef)` → couches de `MusicSetDef.active_layers(level, mask, groups)` (exposé, sans mélodie, power down, groupes) et gain « exposé » ; sans donnée, la table de M14 §2.5. API de la phase 2 déjà présente sous forme minimale : `use_library()`, `set_groups()`, `set_mask()`, `play_theme()`, `skip_to_tail()`.
- Fondus globaux : `fade_to(db, s, stop_at_end)` écrit l'effet `Fade` une fois par image (rampe en amplitude) ; la première image après l'appel n'avance pas le fondu (un fondu d'entrée part du silence, QA-076).
- `_exit_tree` : `stop()`, `stream = null`, `Fade` remis à 0 dB (QA-039). `AudioDirector._exit_tree` arrête de toute façon tous les lecteurs de ses enfants.

### 13.3 Stress D-083 (B82, M-17) — résultat : **le moteur ne déclenche pas la course**

Outil : `bash tools/qa_audio_stress.sh <journal> [args]` (lance `tools/qa_audio_stress.gd` via `qa_boot`, `user://` jetable). Le vrai `MusicDirector` est **greffé** sous l'`AudioDirector` de chaque `day.tscn` chargée (signal `node_added`, sans modifier le jeu) avec les 5 couches de MS-02, un 2ᵉ ensemble de 3 couches et un thème, puis brutalisé : niveau forcé (−1 → 4) toutes les 0,5 s, mélodie coupée au hasard, changement de clip toutes les 1–6 s (fondu croisé dans le flux), fondu `Fade` toutes les 0,5–3 s, relance de `play()` toutes les 5–15 s. Modes : `reload` (protocole de QA-030 : la vraie scène, bot `--autoplay`, `Engine.time_scale` 8, `reload_current_scene` toutes les 1–240 images, briefing comme plein shift), `campaign` (ajoute `qa_campaign.gd`, « Quitter → Continuer » réels), `bare` (le moteur seul, scène minimale rechargée toutes les 1–30 images). Contrôles : `--qa-control=legacy` (deux lecteurs dont le `volume_db` est réécrit à chaque image : le schéma abandonné), `--qa-control=off`, `--qa-no-barrier` (`AudioMixBarrier` en pause). Fin par `AudioMixBarrier.quit_after_silence()` ; le script compte `signal 11`, fuites (« leaked », « still in use »), « Playback can only happen… », `SCRIPT ERROR`.

| Série | Mode, barrière | Volume | Opérations sur le moteur | Plantages | Fuites à la sortie |
|---|---|---|---|---|---|
| **Rechargements de la vraie scène** (13 tronçons ≤ 10 min, jours 1, 2, 4, 7, 10, 12, 15, 18, 20, 25 ; graines variées) | `reload`, barrière active | **3 400 rechargements** de `day.tscn` (2 tronçons coupés par le délai : comptés au dernier relevé) | 10 878 changements de niveau, 1 144 changements de clip, 2 290 fondus `Fade`, 395 relances, 601 557 écritures de volume de couche | **0** | 0 (1 tronçon : 6 objets / 3 ressources, non reproduit en 3 reprises de la même graine, ni en ligne de base sans moteur) |
| **Campagne réelle J1 → J30** (graine 23, profil `solidaire`, +3 000 ₵, `--qa-reload`, 3 tronçons repris de la vraie sauvegarde) | `campaign`, barrière active | 30 jours joués, **31 « Quitter → Continuer »** réels, 55 moteurs greffés, fin **F9** au J30 | 1 982 changements de niveau, 284 changements de clip, 562 fondus, 96 relances, 186 596 écritures | **0** | 0 ; 0 `SCRIPT ERROR` |
| Moteur seul, niveau changé **à chaque image** | `bare`, barrière active | 3 000 + 1 000 cycles lecture → libération | 55 685 changements de niveau, 165 341 écritures | **0** | 0 (après correctif, ci-dessous) |
| Moteur seul **sans `AudioMixBarrier`** | `bare`, barrière en pause | 3 000 cycles | 3 624 changements de niveau, 10 072 écritures | **0** | 0 |
| Contrôle : schéma abandonné (2 lecteurs, `volume_db` réécrit à chaque image), sans barrière | `bare --qa-control=legacy --qa-no-barrier` | 3 000 cycles | 93 338 écritures de `volume_db` | 0 | (fuite de scripts du prototype de l'époque, voir ci-dessous) |
| Ligne de base : jeu seul (`--qa-control=off`), J20 | `reload`, barrière active | 250 rechargements | — | 0 | 0 |

**Lecture** : sur le protocole qui avait reproduit QA-030 (≈ 1 plantage pour 2 100 rechargements de la vraie scène **sans** barrière), le moteur M14 n'a produit **aucun plantage** en 3 400 rechargements et une campagne complète, avec un trafic de changements de niveau très supérieur au jeu réel (un niveau forcé toutes les 0,5 s ; en jeu : au plus un changement toutes les 2 mesures). Mécanisme : la musique ne réécrit **jamais** le volume d'une lecture de l'`AudioServer` (0 écriture de `volume_db` mesurée, sonde GUT) ; les niveaux vivent dans le flux et les fondus dans un effet de bus. Limite : le mode `bare` ne reproduit pas la course même sans barrière (charge trop faible) — la sensibilité de l'outil repose sur le protocole de QA-030 dans la vraie scène, pas sur un contrôle positif refait ici. **Le repli prémixé n'est pas nécessaire.**

**Défaut trouvé et corrigé par le stress** : une version intermédiaire de `MusicDirector.use_library(library: MusicLibraryDef)` faisait fuir à la sortie **tout le graphe de scripts du jeu** (≈ 160 « GDScript leaked », 157 ressources « still in use ») dès que la classe était chargée — reproduit par une sonde minimale (référencer `MusicDirector` suffit ; `MusicLibraryDef` seule : rien) et isolé par bissection à la référence de type `MusicLibraryDef` (dont les statiques tirent `DayDef`) dans la signature. Correctif : paramètre typé `Resource`, lu par propriétés ; 0 fuite ensuite (moteur seul 1 000 cycles, J20 250 rechargements). À garder en tête pour le lot A : une référence de type vers `MusicLibraryDef` depuis un script chargé tôt reproduirait la fuite.

### 13.4 Chaîne de rendu hors ligne (B79/B80, D-180)

`art_src/music/<id>.json` → `tools/build_music.gd` (`MusicRenderer` + `AudioDsp`) → WAV 16 bits (`art_src/downloads/_music_build/`, ignoré par git) → ffmpeg Vorbis → `assets/audio/music/…` + `.import` + `manifest.json`. Point d'entrée : `bash tools/build_audio.sh --only=music:ms02` (une partition ; `music:all` toutes ; `--force`, `--demos`) qui enchaîne rendu, import et `--defs` ; ou directement `godot --headless --path . --script res://tools/build_music.gd -- [--only=…] [--force] [--demos] [--defs]`.

**Partition** (JSON) : `id`, `def_id` (`ms_02`, `th_f9`), `kind` (`set` | `theme`), `tempo`, `beats_per_bar`, `bars`, `tail_bars` (queue repliée, 2), `sample_rate`, `seed` ; `chords[]` (`bar`, `bars`, `bass`, `notes`) ; `motifs` (MO-n : pas, durée, note) ; `instruments` (préréglages nommés : `pad`, `choir`, `bass`, `bell`, `pluck`, `musicbox`, `arp`, `tick`, `brush`, `noise_swell`, `neon`, `tone` [sinus, triangle, dent de scie, air, souffle]) ; `mix` (`eq[]` en cloche, `reverb` FDN `rt60`/`size`/`damp_hz`/`predelay`, `width`) ; `stems[]` (une couche : `id`, `layer` facultatif [rôle, seuils, masques], `eq`/`width` propres facultatifs) → `tracks[]` (`instrument`, `gain_db`, `send`, `pan`, `humanize_ms` seedé, et `chords` [nappe : `octave`, `only`, `from_bar`, `to_bar`], `pattern` [`bars`, `steps` : `step` en doubles croches, `len`, `note` (`A3`, `chord:k`, `bass`, `rest`), `notes`, `oct`, `vel`, `prob` seedée], `events` [y compris `{"motif": "MO-1", "bar", "step", "stretch", "transpose"}`], `automation` [`cutoff`, `gain_db` par mesure, par bloc de 64 échantillons], `bitcrush`) ; thèmes : `sections[]` (`opening`, `a`, `b`, `tail` bouclable), `endings` ; `demo` (niveaux par mesure ou queue, présentation).

**Briques `AudioDsp`** (statiques pures) : `blep_saw` (polyBLEP, vibrato), `blep_pulse` (PWM), `sine`, `triangle`, `fm2` (cloche 2 opérateurs), `karplus` (pincé), `env_adsr`, `svf` (TPT passe-bas / bande / haut, coupure par bloc de 64), `block_curve`, `eq_peak`, `chorus`, `delay`, `fdn_reverb` (4 lignes, Hadamard, amortissement, pré-délai ; linéaire), `bitcrush`, `ms_width`, `dc_block`. Les anciennes (`filter`, `one_pole`, `space`…) sont inchangées.

**Boucles** : chaque couche est rendue sur `bars + 2` mesures ; la queue des 2 dernières est **repliée** sur le début ; longueur = `bars × échantillons par mesure` exactement (tempos à double croche entière : 80 BPM à 32 kHz = 96 000 éch. par mesure ; 75 BPM à 48 kHz = 153 600). Une note avancée par l'humanisation avant le début est calée sur l'échantillon 0 : une attaque à cheval sur la jointure serait codée de part et d'autre du bord du flux Vorbis (clic mesuré, §13.5).

**Thème** : `stream` = ouverture → A → B **suivis du premier passage de la queue**, d'un seul tenant ; `tail_stream` = la queue repliée en boucle. La fin de `stream` enchaîne donc sur `tail_stream` sans couture (la queue a la même fin dans les deux fichiers). `MusicThemeDef.main_bars()` (14 pour TH-F9) reste la fin de B ; la queue commence à la mesure 14 de `stream`.

**Mixage et gains** : même réverbération et même égaliseur pour chaque couche (somme des couches = mixage complet, linéarité testée) ; un **gain commun** par ensemble (crête de la couche la plus forte à −1,3 dBFS, abaissé tant qu'un OGG décodé dépasse −1 dBTP). Les gains de niveau ne sont **pas** dans les fichiers : `build_music` les calcule exactement (énergies pondérées K croisées des couches par sous-blocs de 100 ms, dichotomie couche par couche, bus Music à 0,8 = −1,94 dB) et les écrit dans `MusicLayerDef.gain_db` ; le gain « exposé » (L0 + L3 à −20 LUFS) dans `MusicSetDef.exposed_gain_db`.

**Déterminisme** : graines dérivées de `seed`, de l'id, de la couche, de la piste et de l'index ; aucun ordre de dictionnaire ; ffmpeg `-map_metadata -1 -fflags +bitexact -flags:a +bitexact -serial_offset <hachage du nom>`. **Deux builds `--force --demos` successifs : WAV, OGG et démos identiques au bit près** (SHA-256 comparés). Incrémental : une partition n'est rendue que si son texte, `music_renderer.gd`, `audio_dsp.gd` ou `TOOL_VERSION` (à incrémenter quand la normalisation ou l'encodage de `build_music.gd` changent) ont changé, ou si un OGG ne correspond plus au manifeste ; un 3ᵉ build après modification de l'outil a redonné les mêmes SHA-256. Les `.tres` de `--defs` gardent leurs UID et des identifiants de sous-ressources stables (`layer_l0`, `section_a`…) ; les identifiants `ext_resource` restent tirés par Godot (normalisation à faire en phase 2, comme `build_booth.gd`). **Anciens OGG** (`amb_*`, `mus_*` de `build_audio.sh`) : mêmes options (serial = CRC du nom) → deux builds identiques ; leur PCM décodé est identique à celui des fichiers précédents (seuls les octets du conteneur changent).

**Durées de rendu** (machine de dev, 1 cœur, autres processus actifs) : MS-02 (5 couches × 48 s) ≈ 82 s ; TH-F9 (70,4 s + queue 25,6 s, chœur de 24 voix) ≈ 200 s ; audit complet ≈ 45 s.

### 13.5 Mesures objectives (`tools/qa_audio_audit.gd`, M14 §6.2)

`godot --headless --path . --script res://tools/qa_audio_audit.gd -- [--json=rapport.json] [--only=ms02]` : tout est mesuré sur les **OGG décodés** par ffmpeg (et les WAV intermédiaires pour M-05 b) ; code de sortie 1 au premier échec. Résultat au rendu final : **105 mesures, 0 échec**.

| # | Mesure | Résultat |
|---|---|---|
| M-01 | 0 échantillon ≥ 0,999 ; true peak ≤ −1 dBTP | couches MS-02 : −1,3 / −12,7 / −12,4 / −11,5 / −6,1 dBTP ; TH-F9 −1,0 ; queue −3,5 ; démos −1,8 et −4,5 ; 0 échantillon saturé |
| M-02 | crête d'ensemble −1 dBTP (±0,5) ; DC ≤ 0,001 | MS-02 −1,3 dBTP ; DC ≤ 0,0001 |
| M-03 | N0 → N4 (gains du manifeste, bus par défaut) | **−30,0 / −28,0 / −26,6 / −25,1 / −24,1 LUFS**, croissance monotone ; N4 recoupé par ffmpeg à 0,01 LU près ; gains L0 → L4 : −15,2 / −4,7 / +3,3 / −3,1 / −5,8 dB ; exposé : +7,2 dB |
| M-04 | thème −18 ±1 LUFS | TH-F9 −18,0 LUFS au gain d'exécution −3,3 dB (gain à porter dans les données : voir §13.7) |
| M-05 | boucles sans clic | toutes les boucles : clic ≤ 99,9ᵉ centile du fichier, erreur de codage à la jointure ≤ 99ᵉ centile, aucun silence > 20 ms (voir l'écart de méthode ci-dessous) |
| M-06 | longueur exacte, `.import` | décodé = 1 536 000 éch. (MS-02), 3 379 200 et 1 228 800 (TH-F9) ; `loop`, `bpm`, `beat_count`, `bar_beats` cohérents ; aussi GUT |
| M-07 | mono : perte ≤ 3 dB, corrélation ≥ 0 / 400 ms | pertes 0,0 → 1,1 dB ; corrélations minimales 0,08 → 0,99 (largeur M/S 0,55, L4 0,35, TH-F9 0,4) |
| M-08 | UI ≥ musique + 12 dB dans 1–4 kHz | marge des cues P1 en bande : **37 / 37 / 36 / 25 / 28 dB** (N0 → N4) ; 12 cues jugées toutes ≥ 12 dB ; 3 cues « hors bande » non jugées (§13.7) |
| M-09 | déterminisme | SHA-256 = manifeste ; deux builds identiques (§13.4) |
| M-12 | taille | musique M14 : 3,26 Mo (MS-02 2,13 Mo, TH-F9 1,13 Mo) |

**Écarts de méthode (à valider par la QA)** :
- **M-05** — le critère du document (saut ≤ 3 × la médiane, RMS 10 ms ±1 dB) suppose un contenu continu : il échoue sur toute attaque placée au temps 1 (basse, cliquetis), aussi aux débuts de mesure **intérieurs**. Il est imprimé pour information ; le critère retenu compare la jointure **au reste du même fichier** : (a) énergie HF (dérivée seconde, 1 ms) ≤ son 99,9ᵉ centile ; (b) erreur de codage (OGG − WAV, ±50 ms) ≤ son 99ᵉ centile (le WAV est continu par construction, test GUT) ; (c) silence. Constat utile : Vorbis étale les attaques vers l'arrière (pré-écho) partout **sauf** à la jointure ; une attaque à cheval sur la jointure y crée un vrai clic (3,9 × le 99,9ᵉ centile) — d'où le calage des notes humanisées sur l'échantillon 0.
- **M-08** — musique : RMS maximale sur 3 s dans la bande (filtres d'ordre 4) ; cue : crête d'échantillon dans la bande. Trois cues P1/P2 n'ont presque pas d'énergie dans 1–4 kHz (crête en bande > 12 dB sous leur crête totale : `ui.match`, `ui.incomparable`, `ui.toast_error`) : elles ne sont pas jugées ici (leur lisibilité se joue dans le grave). À trancher par la QA et l'UI/UX : critère par bande propre de chaque cue, ou éclaircir ces trois cues.

### 13.6 Échantillons de direction musicale (validation client)

| Démo | Contenu | Mesures |
|---|---|---|
| `docs/mockups/m14_music_ms02_demo.ogg` (78 s, 32 kHz stéréo, Vorbis q5) | **MS-02, Acte I** — la mineur, 80 BPM ; 26 mesures : N0 (mes. 1–4, nappe seule) → N1 (5–8, + basse en croches) → N2 (9–12, + cliquetis et balais) → N3 (13–18, + arpège ; **MO-1** à la cloche FM en mesure 17) → N4 (19–24, L3 sort, seconde mineure mi–fa tenue et bruit qui s'ouvre sur 4 mesures), fondu final de 2 mesures. Rampes d'une mesure et gains exacts du jeu, **+8 dB de présentation** (niveaux relatifs du jeu conservés) | −18,1 LUFS intégré, −1,8 dBTP, LRA 6,3 LU, 0 échantillon saturé ; par palier : N0 −22,0 · N1 −20,0 · N2 −18,6 · N3 −16,9 · N4 −15,9 LUFS (en jeu : −30 → −24) |
| `docs/mockups/m14_music_thf9_demo.ogg` (83,2 s, 48 kHz stéréo, Vorbis q5) | **TH-F9 « Les vitres éteintes »** — ré majeur, 75 BPM ; ouverture : bourdonnement de néon (impulsion étroite à 110 Hz, papillotement) qui descend et s'éteint (mes. 1–2), déclic de relais, 2 mesures de quasi-silence (air de salle vide à −60 dBFS) ; A : chœur synthétique (4 notes × 3 voix × 2 côtés = 24 voix, formants « a ») ré – si m, **MO-2 chanté** lent (la la la · mi) sur si m ; B : sol – ré/fa♯ – mi m7 – la sus4, chœur aigu « ou », bourdon de ré grave, MO-2 deux fois ; queue de 8 mesures (ré – sol – si m – la sus4/la), MO-2 une fois ; **MO-1 absent**. Démo = `stream` (70,4 s) + 4 mesures de la queue, fondu final de 4 mesures | −18,0 LUFS intégré (cible des fins), −4,5 dBTP, LRA 13,2 LU, 0 échantillon saturé |

Jointures des boucles de jeu : voir M-05 (§13.5) ; les démos sont des montages linéaires sans jointure.

### 13.7 Phase 2 — ce qui a été fait (les points ouverts de la phase 1)

Tous les points de la liste de la phase 1 sont traités (§13.8 → §13.14), sauf : `gain_db` de `MusicThemeDef` (lot A, voir §13.15 : écrit en **métadonnée** `gain_db` en attendant) ; la règle « aucune attaque à cheval sur la jointure » reste appliquée par le moteur de rendu.

### 13.8 Branchement (`AudioDirector`, `TitleMusic`)

- **Jour** (`day.tscn`) : l'`AudioDirector` crée son `MusicDirector` (enfant `MusicDirector`, **aucune modification de `day.tscn`**). `set_music()`, ses deux lecteurs `Music0/1` et leurs tweens de `volume_db` sont **supprimés** ; `_fade()` ne sert plus qu'aux ambiances. Un seul lecteur sur le bus `Music` (test GUT).
- **Titre** (`main.tscn`) : nœud `TitleMusic` (`scripts/audio/title_music.gd`, `extends MusicDirector`) — seule modification de `scenes/main/` : MS-01 au niveau 0, couche MO-2 (`ending_seen`) si le profil a une fin vue, fondu d'entrée 1,5 s.
- **Ensembles chargés par chemin** (`assets/audio/music/sets/<id>.tres`) et thèmes choisis par `assets/audio/music/index.json` (écrit par `build_music --defs`) : `MusicLibraryDef.load_default()` chargerait **tout** le catalogue (≈ 19 Mo d'OGG) ; l'`AudioDirector` ne le fait jamais (RAM ≤ 6 Mo). `AudioDirector.set_id_for()` et `theme_path_for_ending()` reproduisent `MusicLibraryDef.set_id_for_day` / `theme_for_ending` (aucune référence de type à `MusicLibraryDef` dans un script de scène, D-197) ; l'égalité est testée pour tous les jours, fins et variantes.

| État (`music_state`) | Entrée | Musique |
|---|---|---|
| `briefing` | `day_started` | ensemble du jour (`set_id_for` : MS-02 / 03 / 04 par acte, MS-05 Garde, MS-07 J31 + groupe `world_<x>`) au niveau **exposé** (L0 + L3), fondu `Fade` de 1,5 s ; MS-06 préparé dans le même flux |
| `shift` | `day_phase_changed` INTRO → autre phase | N0 à la mesure suivante, puis `MusicIntensity` à 4 Hz → `request_level` (+1 / 2 mesures, −1 / 4) et masques |
| `evening` | `day_ended` (campagne) | MS-06, **fondu croisé de 2 mesures dans le flux** ; couche `crisis` (solde < 0, bilan négatif, proche malade ou froid) sinon `warm`, réévaluée à l'ouverture d'`EveningScreen` |
| `garde_end` / `epilogue_end` | `day_ended` (Garde / J31) | MS-05 au niveau N1 / MS-07 au repos |
| `cinematic` | écran dont la classe globale est `CinematicScreen` (lot D) | thème de la fin (J31 : thème du monde) après un fondu `Fade` de 2 s ; `finished(true)` → `skip_to_tail()` |
| `end` | `EndScreen` | thème de la fin (`EpilogueService.variant_of`, variante de drapeaux, « effets réduits » si `fx_intensity` < 1) ; TH-F7 : la **sortie** directement ; démo et fins simulées des actes I–II (F4, F5, F7, F8, F9 avant l'Acte III : `SIMULATED_EARLY_ENDINGS`, QA-079) : MS-06 continue |
| `epilogue_end` | `EpilogueConclusion` | **queue** du thème de la fin d'origine (graine d'épilogue) |

Les écrans sont **lus** sur `DayScene.screen` (comme l'UI est lue sur `ComparisonUI`) : `day_scene.gd` n'est pas modifié. `AudioDirector.fade_out_music(1,5 s)` est fourni pour les fondus de sortie avant rechargement (soirée → jour suivant, fin → titre) : à appeler par le lot D (§13.15).

### 13.9 Intensité (`MusicIntensity`, B83) et cas particuliers

`scripts/audio/music_intensity.gd` (`RefCounted` pur) : termes P1 → P7 et formule de M14 §2.5, lissage (montée 4 s, descente 8 s), quantification avec hystérésis (règle et précision de `MusicSetDef.level_for`), `decide()` → niveau, masque (`MASK_NO_MELODY`, `MASK_POWER_DOWN`), gain additionnel. Entrées : `queue_progressed` (P1 ; Garde `total = −1` ignorée), `day_clock_ticked` (P2, chrono critique), `discrepancy_checked` **DISCORDANT** seulement (P3, remis à 0 deux mesures après `case_resolved`, décompte par le signal local `MusicDirector.bar_passed`), `quota_changed` (P4), `station_event_started/_ended` (P5 `music_weight` ; EV-05 → power down), `DayDef.music_tension` / `music_floor` (P6, P7), `garde_tier_changed` / `garde_error` (Garde : 0,30 + 0,12·palier + 0,10·erreurs). Analyse de dépendances testée : aucune ligne qui nourrit l'intensité ne lit `CaseKey`, le cas courant ou une anomalie.

| Cas (ordre de M14 §2.5) | Effet réalisé |
|---|---|
| Power down (EV-05, annonce `ends_shift` / `music_action = silence`) | couches `keeps_on_power_down` seules (L0), −6 dB (effet `Duck`), passe-bas **400 Hz** (effet `Muffle`) |
| Chrono critique (< 15 s, chronométré, hors Récit) | N4 visé, **montée d'un niveau par mesure** depuis tout niveau (`fast_up`, D-211), **L3 coupée** ; en Stable : L3 coupée seulement, aucune montée |
| Mode Inspection + `music_inspection_reduce` | **−6 dB** (rampe 0,5 s sur `Duck`), passe-bas **3,5 kHz** (`Muffle`), L3 coupée |
| `music_dynamics` = Stable | N1 figé pendant le shift (le plancher du jour s'il est plus haut, D-211 ; pas en Garde) |
| Récit, J31 | plafond N2 |
| Annonce `drop` / `swell` | L0 seule −6 dB pendant 4 mesures, **niveau conservé** (jamais sous le plancher, D-211, QA-077) / +1 niveau pendant 4 mesures |
| Plancher du jour | niveau ≥ `music_floor` |
| `volume_music` = 0 | lecteur **arrêté** (CPU nul), repris sur le même clip au retour |
| Annonce PA (jeu ou ambiance) | musique −3 dB pendant l'annonce (`Duck`) |

L'effet `Muffle` (passe-bas) sert à la pause (2,5 kHz ; **pas** la pause de l'arbre pendant le fondu de sortie avant un changement de scène, QA-074), au Mode Inspection (3,5 kHz) et au power down (400 Hz) : la fréquence la plus basse l'emporte, écrite seulement quand l'état change ; remise à 2,5 kHz et coupée à la sortie de l'arbre. Aucun `volume_db` de lecteur de musique n'est jamais écrit.

### 13.10 Annonces d'ambiance (B85) et lits par acte (B88, son)

- `scripts/audio/pa_scheduler.gd` (`PaScheduler`, pur) : lignes, conditions et poids **lus dans `data/audio/pa_lines.tres`** (`PaLineTable` du lot F : pseudo-drapeaux `pa_act`, `pa_day`, `pa_event_<ev>`, `pa_world_<x>`, `pa_garde`) ; première annonce 45–75 s après l'ouverture du guichet, puis 90–180 s, ≤ 6 par shift (Garde 120–200 s sans plafond, pool qui repart sans répéter la dernière) ; reports de 10 s (3 au plus) si bark en cours ou < 4 s, annonce de jeu ou d'événement < 25 s, chrono < 30 s, coupure ; pas de répétition dans la journée ; les 3 dernières lignes (ordre déterministe) de la veille exclues. Graine : campagne + jour (Garde : graine du jour).
- Rendu à l'exécution (`PaScheduler.render`, thread de travail, objet `PaJob` sans nœud comme `BarkJob`, attendu à la sortie : QA-030) : jingle 16 kHz (MO-1 cloche FM ; monde B : MO-1 au sinus en la majeur ; monde A : MO-1 + bip de borne ; monde D : MO-2 au pincé) puis voix Tessar `MOOD_PA` (passe-bande 1,5 kHz, saturation, espace « Hall »), lecteur `PAVoice` (bus Ambience, −9 dB). **0 octet sur disque.** `EventBus.ambient_announced(key, durée)` avec `max(audio + 0,8 ; 0,06 × caractères ; 2,5)` s ; clé non traduite : rien. `amb.pa_announce` ne sert plus qu'aux annonces de jeu.
- Lits : `amb_station_bed_a2_loop` (J11–J20 : + ventilation qui siffle, alarme lointaine une fois par boucle), `_a3` (J21–J30 : + rumeur de foule au quai, voix Tessar très filtrées), `_d` (J31 monde D : + vent de poussière) — 32 s, 24 kHz, Vorbis q4, construits par `build_audio.sh --only=beds` sur le **même** lit M6 (mêmes graines : `amb_station_bed_loop` inchangé). Monde A, B, C et Garde : le lit actuel.
- Murmure de la file : volume = gain de la cue + `lerp(−6, 0, silhouettes visibles / 6)` (`QueueSilhouette.visible_count`), **une** écriture par avance de la file (jamais par image ni par tween).

### 13.11 Catalogue rendu (M14 §2.2, §2.7)

| Partition | Tempo · fréquence | Fichiers | Durée rendue | Disque | Sonie (gains d'exécution) | Qualités |
|---|---|---|---|---|---|---|
| MS-01 titre | 60 BPM · 32 kHz | 4 | 256.0 s | 1.67 Mo | bed −23.0 / bed+rain −21.5 / titre −20.0 / titre+MO−2 −19.6 LUFS | q1/3 |
| MS-02 Acte I | 80 BPM · 32 kHz | 5 | 240.0 s | 1.53 Mo | N0 −30.0 / N1 −28.0 / N2 −26.5 / N3 −25.0 / N4 −24.0 LUFS | q1/3 |
| MS-03 Acte II | 75 BPM · 32 kHz | 5 | 256.0 s | 1.61 Mo | N0 −30.0 / N1 −28.0 / N2 −26.5 / N3 −25.0 / N4 −24.0 LUFS | q1/3 |
| MS-04 Acte III | 64 BPM · 32 kHz | 5 | 300.0 s | 1.78 Mo | N0 −30.0 / N1 −28.0 / N2 −26.5 / N3 −25.0 / N4 −24.0 LUFS | q1/4 |
| MS-05 Garde | 96 BPM · 32 kHz | 5 | 200.0 s | 1.36 Mo | N0 −30.0 / N1 −28.0 / N2 −26.5 / N3 −25.0 / N4 −24.0 LUFS | q1/4 |
| MS-06 bilan, soirée | 60 BPM · 32 kHz | 3 | 144.0 s | 1.12 Mo | bed −22.5 / chaud −20.0 / crise −20.0 LUFS | q1/2/3 |
| MS-07 épilogue | 60 BPM · 32 kHz | 6 | 384.0 s | 2.29 Mo | N0 nappe −31.5 / N0 A −30.0 / N0 B −30.0 / N0 C −30.0 / N0 D −30.0 / N1 A −28.0 LUFS | q1/4 |
| TH-F1 (+ okonkwo_warned) | 60 BPM · 48 kHz | 3 | 128.0 s | 1.17 Mo | −18 LUFS au gain −4.37 dB | q2/3 |
| TH-F2 | 75 BPM · 48 kHz | 2 | 70.4 s | 0.67 Mo | −18 LUFS au gain −4.96 dB | q2/3 |
| TH-F3 (+ lumika_learned) | 60 BPM · 48 kHz | 3 | 112.0 s | 0.67 Mo | −18 LUFS au gain −3.79 dB | q2/3 |
| TH-F4 (+ Dora) | 80 BPM · 48 kHz | 3 | 120.0 s | 1.18 Mo | −18 LUFS au gain −2.13 dB | q2/3 |
| TH-F5C + TH-F5S | 75 BPM · 48 kHz | 4 | 153.6 s | 1.50 Mo | −18 LUFS au gain −4.79 dB | q2/3 |
| TH-F5B (+ effets réduits) | 75 BPM · 48 kHz | 3 | 128.0 s | 1.13 Mo | −18 LUFS au gain −2.65 dB | q2/3 |
| TH-F6 + F6D + F6T | 64 BPM · 48 kHz | 4 | 165.0 s | 1.81 Mo | −18 LUFS au gain −4.97 dB | q2/7 |
| TH-F7 (sortie) | 80 BPM · 48 kHz | 1 | 24.0 s | 0.25 Mo | −18 LUFS au gain −5.23 dB | q3 |
| TH-F8 | 64 BPM · 48 kHz | 2 | 75.0 s | 0.77 Mo | −18 LUFS au gain −4.18 dB | q2/3 |
| TH-F9 | 75 BPM · 48 kHz | 2 | 76.8 s | 0.81 Mo | −18 LUFS au gain −2.95 dB | q2/4 |
| TH-F10 | 72 BPM · 48 kHz | 2 | 73.3 s | 0.71 Mo | −18 LUFS au gain −5.03 dB | q2/3 |
| **Total** | | 62 | | **22.03 Mo** (≤ 24) | | |

Thèmes sans fichier (données seulement) : **TH-EA → TH-ED** (couches de MS-07), `stream` de **TH-F7** (L0 + L1 de MS-02). Durée de rendu complète ≈ 30 min (1 cœur), un processus par partition (≤ 3,5 min chacun).

Partitions : `art_src/music/ms01.json` … `thf10.json` (format §13.4, plus : `level_plan` et `exposed_layers` des ensembles non canoniques, `world_themes` de MS-07, `variants[]` des thèmes — `flag` → `MusicThemeVariantDef`, `def_id` → thème sélectionné par variante de fin, `reduced_fx` → `reduced_fx_stream` —, pistes marquées `variant` / `not_variant` (une piste `variant: "inactive"` ne sonne jamais), `tail_only` + `reuse` pour TH-F7 ; instruments `tone` `square` (bips) et `thump` (coup sourd)).

**Format des thèmes (révision de D-197)** : `stream` = ouverture → B **suivis des 2 premières mesures de la queue** (au lieu de la queue entière) ; `tail_stream` = la queue repliée **commençant à sa 3ᵉ mesure** (rotation d'une boucle : sans couture) ; la jointure `stream` → `tail_stream` reste continue (même rendu linéaire). Gain : ≈ 6 mesures de moins par thème et par variante (≈ 2,4 Mo).
**Thèmes sans fichier** : TH-EA → TH-ED = `AudioStreamSynchronized` des couches `l0`, `l1`, `world_<x>` de MS-07 (−18 LUFS sans le bus) ; `stream` de TH-F7 = L0 + L1 de MS-02 au niveau N1 (`reuse_set_id = ms_02`), seule la sortie de 8 mesures est rendue.
**Qualité Vorbis** (révision de D-180, budget ≤ 24 Mo) : couches clairsemées q1 à 32 kHz (le débit visé par M14 §2.8, ≈ 56 kb/s ; q3 donnait 71 kb/s) ; **nappes toujours présentes (`pad`, `bed`) q3** ; flux principaux des thèmes q2 à 48 kHz ; **queues bouclées q3**. Raison mesurée : à q1/q2, le codage de la jointure d'une boucle dense crée un clic (M-05 : énergie HF à la jointure jusqu'à 11,8 × le 99,9ᵉ centile du fichier pour une nappe à q1, ≤ 1 à q3). **Recherche de qualité des boucles** : après encodage, `build_music` décode chaque boucle et mesure le clic de jointure (`FfmpegAudio.junction_click_rank`, critère M-05 retenu) ; s'il dépasse 1, la qualité monte d'un cran (jusqu'à q8) — l'effet de bord Vorbis à la jointure n'est pas monotone en qualité (MS-07 L0 : 4,5 à q3, 0,11 à q5, 1,05 à q7), la recherche s'arrête au premier encodage propre ; déterministe ; qualité retenue et rang du clic écrits au manifeste. Les couches clairsemées reçoivent un **plancher tonal** (fondamentale de l'accord au sinus, très bas) : plus aucun silence numérique > 20 ms dans une boucle (M-05).

**Défaut corrigé (phase 2)** : les indices `chords.only` d'une piste étaient lus comme des flottants JSON et jamais reconnus (`Array.has(0)` ≠ `0.0`) : les pistes concernées étaient muettes. Corrigé dans `MusicRenderer` ; la seule piste de la phase 1 touchée (chœur aigu de TH-F9, muet dans la démo validée D-198) est gardée **inactive** pour ne pas changer TH-F9.

### 13.12 Mesures (audit, CPU, mémoire, déterminisme, stress)

| Mesure | Résultat |
|---|---|
| **Audit** (`qa_audio_audit.gd`, une partition par processus) | **791 mesures, 0 échec** sur les 18 partitions (M-01, M-02, M-03 par palier du plan de niveaux, M-04, M-05, M-06, M-07, M-08 sur MS-02 → MS-05 et MS-07, M-09, M-12) |
| M-03 | MS-02 → MS-05 : N0 −30,0 · N1 −28,0 · N2 −26,5 · N3 −25,0 · N4 −24,0 LUFS (monotone) ; MS-07 : −30,0 par monde, N1 −28,0 ; titre −20,0 ; soirée chaud / crise −20,0 |
| M-04 | 14 thèmes et variantes à −18 ±1 LUFS au gain d'exécution |
| M-08 | marges UI (bande propre de chaque cue) ≥ 12 dB à tous les niveaux de MS-02 → MS-05 et MS-07 (MS-04 N3 : 9,9 dB avant correction → motifs de L3 descendus d'une octave) |
| **M-10 CPU** (`qa_audio_load.gd`, 60 s par phase, 60 images/s, machine de développement, pilote audio Dummy) | MS-02 au pire cas (N4, 5 couches décodées, changement de clip toutes les 8 s vers MS-06) : **+2,08 %** d'un cœur (5,12 → 7,20 %) ; MS-04 : **+2,42 %** (5,50 → 7,92 %) — cible ≤ 3 % ; **à refaire sur Steam Deck** |
| **M-11 mémoire** | OGG résidents (ensemble de jeu + MS-06 + le plus gros thème, TH-F6D + la queue de TH-F6) : MS-02 3,66 Mo · MS-03 3,74 · MS-04 3,90 · MS-05 3,48 · MS-07 4,42 Mo (Δ `MEMORY_STATIC` ≤ 5,55 Mo) — cible ≤ 6 Mo |
| **M-09 déterminisme** | build A → build B (moteur de rendu modifié entre les deux) : les **51** WAV dont le contenu ne devait pas changer sont identiques ; build C (`--force`) de MS-01, MS-04, MS-07, TH-F6, TH-F7, TH-F8 : **62 / 62 fichiers identiques** (SHA-256 des WAV et des OGG, recherche de qualité comprise) |
| M-12 | musique **22,03 Mo** ≤ 24 (anciennes boucles `mus_*` supprimées, −2,0 Mo) ; lits par acte 1,15 Mo (ambiance) |
| Chargement | ensemble du jour + MS-06 chargés par chemin au `day_started` (≈ 2,5 Mo d'OGG compressés, aucun décodage) |
| **Stress D-083** (jeu réel, `--qa-control=off` : seul le `MusicDirector` branché) | **1 000 rechargements** de `day.tscn` (4 × 250, J2, J12, J20 — grève et power down —, J25 ; `--autoplay`, `Engine.time_scale` 8, rechargement toutes les 1–240 images, barrière active) : **0 plantage, 0 fuite, 0 « Playback can only happen », 0 SCRIPT ERROR**. Écran titre (`TitleMusic`) lancé puis quitté : 0 fuite. La campagne réelle J1 → J30 sur le jeu branché reste à refaire par la QA (M-17) |

### 13.13 Tests

GUT **unit** : 671 tests, 670 passent — le seul échec (`test_m14_plates`, manifeste des planches) appartient au lot C ; **intégration** : 338 / 338 (36 fichiers lancés un par un). Nouveaux : `test_music_intensity` (8 : formules, bornes, monotonie, hystérésis, vitesse +1/2 −1/4 mesures, lissage, Récit/J31, Stable, chrono critique, coupure, Inspection, annonces, plancher, Garde, **aucune entrée issue de `CaseKey`** par lecture du code), `test_music_sets` (6 : M-06, rôles des couches, une fin et une variante → un thème, sélection de l'`AudioDirector` = `MusicLibraryDef`, mondes, chaînage thème → queue, MO-1 / MO-2 jamais dans la même mesure hors F5C et F10 — étendue des motifs et groupes exclusifs —, budget), `test_pa_scheduler` (7), `test_music_director` (+4 : gain des thèmes dans le flux, fin → thème après le fondu, volume 0, `bar_passed`), `test_audio_director` (états musicaux réécrits sur le nouveau moteur — plus de `set_music` —, Inspection / coupure / murmure, annonce d'ambiance sous-titrée). Fuite à la sortie de `test_music_director` (≈ 340 objets) : présente aussi avec les versions de la phase 1 du test et du moteur dans l'arbre actuel — vient des données des autres lots (famille D-197), signalée à l'Architecte.

### 13.14 Fichiers de la phase 2

| Fichier | Rôle |
|---|---|
| `scripts/audio/music_intensity.gd` | `MusicIntensity` (pur) |
| `scripts/audio/pa_scheduler.gd` | `PaScheduler` (pur) + rendu des annonces |
| `scripts/audio/title_music.gd` | `TitleMusic` (`main.tscn`) |
| `scripts/audio/audio_director.gd` | branchement M14 (§13.8 → §13.10), `set_music()` retiré |
| `scripts/audio/music_director.gd` | `bar_passed`, gain des thèmes dans le flux, `play_theme_after_fade`, `set_suspended`, `theme_gain_db` |
| `scripts/audio/music_renderer.gd` | variantes de pistes, `square`, `thump` |
| `scripts/audio/audio_cue_bank.gd` | `amb.station_bed_a2/_a3/_d` ; cues `mus.*` retirées |
| `tools/build_music.gd` | plans de niveaux, variantes, format des thèmes, thèmes de couches, `index.json`, qualités |
| `tools/build_audio.gd`, `build_audio.sh` | lits par acte (`--only=beds`) ; boucles `mus_*` M6 retirées |
| `tools/qa_audio_audit.gd` | plans de niveaux, thèmes au nouveau format, M-08 hors titre et soirée |
| `tools/qa_audio_load.gd` | M-10 (CPU) et M-11 (mémoire) |
| `tools/qa_audio_stress.gd` | couches de repli MS-03 (les `mus_*` n'existent plus) |
| `art_src/music/*.json` | 18 partitions |
| `assets/audio/music/{ms01…ms07,themes}/`, `sets/`, `themes/*.tres`, `music_library.tres`, `index.json`, `manifest.json` | rendus et données |
| `assets/audio/ambience/amb_station_bed_{a2,a3,d}_loop.ogg` | lits par acte |
| `scenes/main/main.tscn` | + nœud `TitleMusic` |
| `tests/unit/test_music_intensity.gd`, `test_music_sets.gd`, `test_pa_scheduler.gd` ; `test_music_director.gd` (+4) ; `tests/integration/test_audio_director.gd` (états musicaux réécrits, +2) | tests |

### 13.15 Besoins envers les autres lots et points ouverts

- **Lot A (Architecte)** : (1) champ `gain_db` dans `MusicThemeDef` (D-197) — en attendant, `build_music --defs` écrit la métadonnée `gain_db` et `MusicDirector.theme_gain_db()` lit le champ s'il existe, sinon la métadonnée ; (2) `MusicLibraryDef.load_default()` charge tout le catalogue (≈ 19 Mo d'OGG) : à réserver aux outils et aux tests, ou faire porter des **chemins** à la bibliothèque (le jeu passe par `index.json`) ; (3) `PaLineTable` (lot F, `scripts/generation/`) à reprendre dans `scripts/core/` sous le nom choisi (`PaScheduler` la lit par méthodes, typée `Resource`) ; (4) valider la révision du format des thèmes (§13.11) et des qualités Vorbis.
- **Lot D (UI)** : (1) sous-titre « [Haut-parleur] … » sur `ambient_announced` (option sous-titres) ; (2) `CinematicScreen` : la musique démarre d'elle-même quand l'écran est ouvert par `DayScene._open` (classe globale `CinematicScreen`, propriété `ending` lue si elle existe, signal `finished(skipped)` écouté) ; appel direct possible : `AudioDirector.skip_music_to_tail()` ; (3) fondus de sortie de 1,5 s avant `reload_current_scene` (soirée → jour suivant, chapitres) et `change_scene_to_file` (fin → titre) : `await get_tree().create_timer(audio.fade_out_music()).timeout` ; (4) Options : « Musique discrète pendant l'inspection » et « Musique : Dynamique / Stable » sont déjà écoutées (`settings_changed`) ; (5) Dossier › REVOIR : `TitleMusic.play_theme_after_fade(theme)` (thème chargé par `index.json`).
- **Lot C (3D)** : rien de bloquant ; le murmure suit `queue_progressed` avec `QueueSilhouette.visible_count(…, 6)` (6 places) — à aligner si `QueueImpostors` change le nombre de places.
- **Lot E (Scénariste)** : `pa_ev07` cite « carte d'identité » (nom d'un document du jeu) : contraire à la règle 1 de M14 §4.4 au sens strict ; texte validé en conception (D-189), toléré par le test et signalé pour relecture (« Gardez vos papiers sur vous… »).
- **QA** : M-10 et M-11 sur Steam Deck avec `tools/qa_audio_load.gd` ; écoute des transitions (fondu croisé shift → soirée, fin → thème) ; playtest « Musique discrète ».
- **Écarts assumés** : `swell` = +1 niveau seulement (pas de « MO-1 entier » forcé) ; la Garde ne transpose pas MO-1 à chaque palier (le palier élève l'intensité) ; MS-07 n'a que deux couches communes (N2 = N1 au J31) ; jingles et voix des annonces rendus à 16 kHz.

### 13.16 Correctifs de la passe QA M14 (QA-074, QA-076 → QA-079, D-211)

| Bug | Correctif | Test (strict) |
|---|---|---|
| **QA-076** horloge de mesures en retard sur le flux | `MusicDirector._process` : l'horloge avance du temps réel écoulé **sans borne** (le flux avance en temps réel dans le thread de mixage pendant une image longue ; sa position n'est toujours pas exposée par Godot 4.7 pour un `AudioStreamInteractive`, d'où le temps réel depuis `play()`) ; les rampes de couches suivent le même temps. Le fondu `fade_to()` n'avance pas à la première image qui suit l'appel (`_fade_fresh`) : un fondu d'entrée commence au silence (−80 dB) même après une image longue | `test_qa076_bar_clock_survives_a_long_frame` : retard < 60 ms après une image de 700 ms, fondu encore < −30 dB |
| **QA-074** fondu de sortie étouffé | `AudioDirector.fade_out_music()` pose `_leaving` ; `_update_pause` ignore la pause de l'arbre pendant ce fondu (fondu de bus seul) ; remis à faux à `start_day_music` | `test_qa074_exit_fade_is_not_muffled_like_the_pause` |
| **QA-077** `drop` sous le plancher | `MusicIntensity.decide` : `drop` = masque `POWER_DOWN` (L0 seule) et −6 dB, **niveau conservé** | `test_qa077_drop_keeps_the_day_floor` (+ −6 dB) |
| **QA-078** N4 hors d'atteinte au chrono critique | `decide()` renvoie `fast_up` au chrono critique ; `MusicDirector.fast_up` → `next_level(…, fast = true)` : +1 niveau **à chaque mesure** (N1 → N4 en 3 mesures, 9,6 s au pire à 75 BPM). Stable : L3 coupée, **aucune** montée ; le niveau Stable respecte le plancher du jour | `test_qa078_critical_clock_reaches_n4_in_time` (+ décision Stable) ; la vitesse générique (+1 / 2 mesures) reste testée par `test_music_intensity` / `test_music_director` |
| **QA-079** thème joué sous une fin simulée des actes I–II | `AudioDirector.on_end_screen` : F4, F5, F7, F8, F9 avec `EpilogueService.act_of(flags) < 3` → MS-06 continue | `test_qa079_simulated_early_endings_keep_the_evening_music` (+ `music_state` = `evening`) |
| **QA-075** (appel par `main.gd`, lot UI) | API `TitleMusic.fade_out(seconds = 1,5) -> float` : fondu `Fade` puis arrêt du lecteur, renvoie la durée à attendre (0 sans musique) ; annule un thème REVOIR en attente | `test_qa075_*` (lot UI) |

**Vérifications** (2026-10-31, après correctifs) : GUT unit **671 / 671** ; integration **38 fichiers** un par un, 0 échec (`test_qa_m14` : 13 verts, 1 `pending` = QA-072, hors audio). Audit `qa_audio_audit.gd` (18 partitions) : **791 mesures, 0 échec** (aucun fichier audio régénéré). Stress D-083 : **320 rechargements** de `day.tscn` (160 jeu seul J20 graine 3, `--qa-control=off` ; 160 moteur greffé J30 graine 12 : 481 changements de niveau, 48 changements de clip, 99 fondus, 30 459 écritures de couche) : **0 plantage, 0 fuite, 0 « Playback can only happen », 0 SCRIPT ERROR**. Journées réelles (`qa_m14_day`) : J15 Stable → aucune montée au chrono critique (N4 non atteint, voulu) ; J15 Dynamique → N4 atteint au chrono critique ; J30 graine 3 → `drop` à N3 avec plancher N2, jamais sous N2.

**À reprendre côté QA** : `tests/qa_drivers/qa_m14_day.gd` et `qa_m14_campaign.gd` comptent `fast_up` toute montée en moins de `BARS_PER_STEP_UP` mesures ; depuis D-211, une montée d'une mesure au chrono critique est voulue (J15 Dynamique : `fast_up=1`). Le pilote peut lire `BARS_PER_STEP_UP_FAST` quand `rem ≤ 15 s`.

## Changelog

- 0.1 — Création : intentions, bus, cue sheet, barks MVP, budget, mix, conventions, licences.
- 0.2 — M6 : implémentation (§12), registre des licences (§10.1), bus layout à la racine.
- 0.3 — M8 : interfaces de l'Acte II sans cue nouvelle (§12).
- 0.4 — M9 : interfaces de l'Acte III sans cue nouvelle (§12).
- 0.5 — M14 phase 1 (lot B) : §13 musique dynamique — `MusicDirector` (moteur D-176), stress D-083 (B82), chaîne de rendu `build_music.gd` (partitions JSON, `AudioDsp` étendu, Vorbis déterministe, `manifest.json`), audit `qa_audio_audit.gd`, échantillons MS-02 et TH-F9 ; effet `Fade` du bus Music (§2) ; OGG d'ambiance et de musique M6 rendus déterministes ; question n° 5 close.
- 0.6 — M14 phase 2 (lot B) : musique branchée (`MusicDirector` du jour et du titre, `set_music()` retiré), `MusicIntensity`, Mode Inspection / Stable / power down, catalogue complet (MS-01 → MS-07, TH-F1 → TH-F10 et variantes, TH-EA → TH-ED), annonces d'ambiance (`PaScheduler`, voix synthétisée), lits par acte, murmure ∝ file, `qa_audio_load.gd`, audit du catalogue ; §4.4, §4.5, §6, §8.1 mis à jour ; boucles `mus_*` M6 supprimées.
- 0.7 — Passe QA M14 : QA-074 (fondu de sortie sans passe-bas de pause), QA-076 (horloge de mesures sans borne, fondu d'entrée depuis le silence), QA-077 / QA-078 (D-211 : `drop` au plancher, montée d'un niveau par mesure au chrono critique, Stable sans montée), QA-079 (fins simulées des actes I–II : MS-06), `TitleMusic.fade_out()` pour QA-075 (§13.16).
