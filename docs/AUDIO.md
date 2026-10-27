# CLEARANCE — Audio Design

> Version 0.2 · Propriétaire : Audio Designer · Statut : **implémenté (M6)** — voir §12 pour l'état réel
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
 ├── Music      ── (sidechain-like ducking via script)
 ├── Ambience   ── LowPassFilter (automatisé), Reverb "Station"
 ├── SFX        ── Compressor léger
 │    └── SFX_World  (send) ── Reverb "Station" (sons 3D côté passager / hall)
 ├── Voice      ── BandPass "Hygiaphone" + Reverb "Booth" + Compressor
 └── UI         ── (sec, aucun effet)
```

| Bus | Effets (ordre) | Réglages de départ | Notes |
|---|---|---|---|
| `Master` | `AudioEffectLimiter` | ceiling −1 dB, threshold −3 dB | Option **Mono** : `AudioServer` → script qui somme L/R (cf. §9) |
| `Music` | `AudioEffectLowPassFilter` (désactivé par défaut) | cutoff 20 kHz → 2,5 kHz en pause/menu | Volume ducké de −6 dB pendant une voix |
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
| `amb.station_bed` | `day_started` → boucle | `Ambience` | 2D stéréo | Ventilation + rumeur hall, boucle 90 s | P2 |
| `amb.queue_murmur` | `day_started` → boucle ; volume ∝ taille de la file | `Ambience` | 2D | Murmures inintelligibles (langage inventé), boucle 45 s + toux/one-shots | P3 |
| `amb.pa_announce` | Timer aléatoire 60–150 s pendant le shift (jamais pendant un bark) | `Ambience` | 3D (haut-parleur lointain) | 6 annonces : carillon Consortium + voix PA borborygme filtrée + sous-titre optionnel | P3 |
| `amb.stop_all` | `day_ended` → fade-out 3 s | — | — | — | — |

### 4.5 Musique (états)

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
| `Music` | 2 (crossfade) | — |
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
| `mus_*` | `mus_shift_calm_loop.ogg`, `mus_shift_tension_loop.ogg`, `mus_briefing.ogg` |

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
5. `AudioStreamInteractive` (Godot 4.3+) pour la musique : OK côté Godot Architect ?

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

**Cues couvertes** : toutes celles de §4 sauf `passenger.bark_depart` (pas de sous-titre côté UI → règle « toujours sous-titré »), `booth.stamp_lift`, `ui.link_drag`, `ui.hover` et `ui.toast_*` (assets prêts, aucun signal public côté UI), `ui.rebel_message` (post-MVP). Sondes UI sans modifier l'UI : `ComparisonUI.selection.a` (sélection A) et `tool_bar.stamps[*].is_holding()` (tampon maintenu, `ui.stamp_hold`).

**Accessibilité vérifiée** : chaque cue critique a son doublage visuel existant (timer : barre ambre/rouge ; tampon : animation + empreinte ; discordance : lien magenta + numéro ; concordance : chip ; citation : ticket ; règle nouvelle : badge NOUVEAU ; barks : sous-titres). « Réduire les effets » (`fx_intensity < 1`) coupe `ui.timer_critical_tick` et adoucit les tampons de 4 dB.

## Changelog

- 0.1 — Création : intentions, bus, cue sheet, barks MVP, budget, mix, conventions, licences.
- 0.2 — M6 : implémentation (§12), registre des licences (§10.1), bus layout à la racine.
