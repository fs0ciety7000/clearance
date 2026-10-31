## Passe QA M14 « Ambiance » (docs/QA.md §17) : non-régression et bugs
## QA-072 → QA-080 (`pending` tant qu'ils ne sont pas corrigés : chaque test
## décrit le comportement attendu et se met en attente avec sa référence s'il
## échoue encore). QA ne corrige pas le code de jeu.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const PROFILE_FIXTURE: String = "res://tests/fixtures/qa_profile_v2_013.json"
const SAVE_FIXTURE: String = "res://tests/fixtures/qa_save_v6_013_j19.json"
const TEST_DIR: String = "user://test_qa_m14"

## Fins atteignables en partie réelle et drapeaux qui les produisent :
## [fin, acte, jour, drapeaux].
const REACHABLE: Array = [
	["f1_arrested", 1, 9, {"audit_arrested": true}],
	["f1_arrested", 2, 17, {"act2_started": true, "review_arrested": true}],
	["f1_arrested", 3, 29, {"act2_started": true, "act3_started": true, "deposition_arrested": true}],
	["f2_reassigned", 1, 10, {}],
	["f3_family_lost", 2, 20, {"act2_started": true}],
	["f3_family_lost", 3, 30, {"act2_started": true, "act3_started": true, "lumika_learned": true}],
	["f4_glory", 3, 30, {"act2_started": true, "act3_started": true, "final3_dora": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true, "climate_vanne": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true}],
	["f5_air", 3, 30, {"act2_started": true, "act3_started": true, "vanne2_brulants": true}],
	["f6_drift", 1, 10, {}],
	["f6_drift", 2, 20, {"act2_started": true}],
	["f6_drift", 3, 30, {"act2_started": true, "act3_started": true, "exit3_drift": true}],
	["f6_drift", 3, 30, {"act2_started": true, "act3_started": true}],
	["f7_reopens", 3, 30, {"act2_started": true, "act3_started": true}],
	["f8_registre", 3, 30, {"act2_started": true, "act3_started": true}],
	["f9_strike", 3, 30, {"act2_started": true, "act3_started": true}],
	["f10_pont", 3, 30, {"act2_started": true, "act3_started": true}],
]

var _flags_before: Dictionary[StringName, Variant] = {}


func before_each() -> void:
	_flags_before = GameState.narrative_flags.duplicate()


func after_each() -> void:
	GameState.narrative_flags = _flags_before
	get_tree().paused = false
	var fade: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_FADE) as AudioEffectAmplify
	if fade != null:
		fade.volume_db = 0.0


static func _typed(d: Dictionary) -> Dictionary[StringName, Variant]:
	var out: Dictionary[StringName, Variant] = {}
	for k: Variant in d:
		out[StringName(str(k))] = d[k]
	return out


static func _sequence(def: CinematicDef, ctx: Dictionary[StringName, Variant], act: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if def != null:
		for plate: PlateDef in CinematicService.plates_for(def, ctx, act, {}):
			out.append("%s:%s" % [plate.id, CinematicService.caption_key(plate, ctx)])
	return out


## Pending avec référence si `ok` est faux, sinon une assertion verte.
func _pass_or_pending(ok: bool, bug: String, detail: String) -> void:
	if ok:
		assert_true(true, "%s corrigé" % bug)
	else:
		pending("%s : %s" % [bug, detail])


# ---------------------------------------------------------------------------
# Non-régression (verts)
# ---------------------------------------------------------------------------

## Toutes les fins atteignables ont une séquence de 3 à 5 planches, sans rien
## d'un acte ultérieur, avec des légendes traduites de 70 caractères au plus.
func test_reachable_endings_have_a_clean_sequence() -> void:
	for c: Array in REACHABLE:
		var ending: StringName = StringName(c[0])
		var act: int = c[1]
		var flags: Dictionary[StringName, Variant] = _typed(c[3])
		var variant: StringName = EpilogueService.variant_of(ending, flags)
		var def: CinematicDef = CinematicService.select(ending, variant, flags, act, c[2])
		assert_not_null(def, "%s/%s acte %d : séquence" % [ending, variant, act])
		if def == null:
			continue
		var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(flags, act, variant, c[2])
		var plates: Array[PlateDef] = CinematicService.plates_for(def, ctx, act, {})
		assert_between(plates.size(), CinematicService.MIN_PLATES, CinematicService.MAX_PLATES, "%s : planches" % def.id)
		for plate: PlateDef in plates:
			assert_true(plate.min_act <= act, "%s : %s (acte ≥ %d) dans une fin de l'acte %d" % [def.id, plate.id, plate.min_act, act])
			var key: String = CinematicService.caption_key(plate, ctx)
			assert_true(UiText.has(key), "%s : légende %s traduite" % [plate.id, key])
			assert_true(UiText.t(key, "").length() <= PlateDef.CAPTION_MAX_CHARS, "%s : ≤ 70 caractères" % key)


## La file réelle ne trahit jamais une anomalie : teinte et taille identiques
## au passager présenté ; seule la forme peut différer (visière baissée de
## présentation, documentée), à la même fréquence chez les passagers en règle
## et les autres (balayage `qa_m14_queue_scan` : 11,5 % / 12,4 %).
func test_queue_silhouette_matches_the_presented_passenger() -> void:
	var n: Dictionary = {"clean": 0, "anom": 0}
	var shape_diff: Dictionary = {"clean": 0, "anom": 0}
	for day_n: int in [3, 7, 12, 16, 22, 27]:
		var day: DayDef = Gen.data().get_day(day_n).duplicate(true)
		var builder: CaseBuilder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(4, day_n))
		for s: QueueSilhouette in QueueSilhouette.upcoming(builder.roster, 0, day.passenger_count, 40):
			var g: GeneratedCase = builder.build(s.index)
			var bucket: String = "clean" if g.key.anomalies.is_empty() and g.key.expected_verdict == VerdictKind.Kind.APPROVE else "anom"
			n[bucket] += 1
			var seen: QueueSilhouette = QueueSilhouette.from_appearance(s.index, g.case.passenger_presented.appearance)
			assert_eq(seen.palette_index, s.palette_index, "J%d #%d : teinte" % [day_n, s.index])
			assert_eq(seen.height_step, s.height_step, "J%d #%d : taille" % [day_n, s.index])
			if seen.shape != s.shape:
				assert_eq(seen.shape, QueueSilhouette.SHAPE_HOOD, "J%d #%d : seule la visière de présentation change la forme" % [day_n, s.index])
				shape_diff[bucket] += 1
	var rate_clean: float = float(shape_diff["clean"]) / maxf(n["clean"], 1)
	var rate_anom: float = float(shape_diff["anom"]) / maxf(n["anom"], 1)
	assert_almost_eq(rate_clean, rate_anom, 0.10, "forme ↔ anomalie : aucune corrélation (%.3f / %.3f)" % [rate_clean, rate_anom])


## L'intensité ne dépend que des signaux publics : un cas présenté (avec ses
## anomalies) ne change rien ; la valeur suit la formule sur les entrées publiées.
func test_intensity_follows_public_signals_only() -> void:
	var director: AudioDirector = AudioDirector.new()
	director.sync_barks = true
	add_child_autofree(director)
	var it: MusicIntensity = director.intensity
	EventBus.queue_progressed.emit(3, 14, [] as Array[QueueSilhouette])
	EventBus.quota_changed.emit(3, 4)
	var before: float = it.compute()
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(12), Gen.day_seed(2, 12))
	for i: int in 6:
		var g: GeneratedCase = builder.build(i)
		EventBus.case_presented.emit(g.case)
		assert_almost_eq(it.compute(), before, 0.0001, "cas #%d présenté (%d anomalie(s)) : intensité inchangée" % [i, g.key.anomalies.size()])
	var expect: float = MusicIntensity.formula(MusicIntensity.queue_term(11), 0.0, 0.0, MusicIntensity.quota_term(3, 4), 0.0, 0.0)
	assert_almost_eq(before, expect, 0.0001, "formule sur les seules entrées publiées")


## Annonces d'ambiance : ni code de règle ni nom de document (D-189, D-199).
func test_ambient_lines_carry_no_game_information() -> void:
	var documents: PackedStringArray = ["carte d'identité", "permis", "bio-scan", "certificat", "contrat", "visa",
			"laissez-passer", "main courante"]
	var re: RegEx = RegEx.create_from_string("\\bR\\d+\\b")
	var count: int = 0
	var table: Resource = PaScheduler.load_table()
	assert_not_null(table)
	for line: Variant in table.get(&"lines"):
		var key: String = str((line as HallAnnouncementDef).text_key)
		var text: String = UiText.t(key, "").to_lower()
		count += 1
		assert_null(re.search(UiText.t(key, "")), "%s : code de règle" % key)
		for doc: String in documents:
			assert_false(text.contains(doc), "%s cite « %s »" % [key, doc])
	assert_eq(count, 52)


## Vrai profil v2 et vraie sauvegarde écrits par la 0.13.0 (`git archive
## e4d6f71`, campagne réelle graine 5, J1 → J18) : migration v2 → v3.
func test_real_0_13_profile_migrates_with_last_encounter_portraits() -> void:
	var dir: String = SaveService.resolve_dir(TEST_DIR)
	DirAccess.make_dir_recursive_absolute(dir.path_join("slot_1"))
	for f: String in ["profile.json", "profile.v2.bak", "slot_1/current.json"]:
		if FileAccess.file_exists(dir.path_join(f)):
			DirAccess.remove_absolute(dir.path_join(f))
	var original: String = FileAccess.get_file_as_string(PROFILE_FIXTURE)
	var w: FileAccess = FileAccess.open(dir.path_join("profile.json"), FileAccess.WRITE)
	w.store_string(original)
	w.close()
	w = FileAccess.open(dir.path_join("slot_1/current.json"), FileAccess.WRITE)
	w.store_string(FileAccess.get_file_as_string(SAVE_FIXTURE))
	w.close()
	var profile: Dictionary = ProfileService.load_profile(TEST_DIR)
	assert_eq(int(profile["version"]), ProfileService.VERSION)
	assert_true(FileAccess.file_exists(dir.path_join("profile.v2.bak")), "profile.v2.bak")
	assert_eq(JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("profile.v2.bak")))),
			JSON.stringify(JSON.parse_string(original)), "copie fidèle du profil v2")
	var portraits: Dictionary = profile["portraits"]
	assert_eq(portraits.size(), 33, "33 personnages vus à la vitre en 18 jours")
	assert_eq(str(portraits["chr_mazur"]["case_id"]), "sc_11", "Mazur : SC-29 (Katya) exclu")
	assert_eq(str(portraits["chr_kerr_ceres"]["case_id"]), "sc_30", "Kerr : homonymes SC-31/32 exclus")
	assert_eq(str(portraits["chr_premiers"]["case_id"]), "tuto_concordant")
	assert_eq(str(portraits["chr_mira"]["visor"]), CaseMemory.VISOR_DOWN, "entrée 0.13 sans visière : baissée (anti-spoiler)")
	for chr_id: Variant in portraits:
		assert_true(JSON.stringify(portraits[chr_id]).to_utf8_buffer().size() <= ProfileService.PORTRAIT_MAX_BYTES, "%s ≤ 400 o" % chr_id)
	assert_true(JSON.stringify(portraits).to_utf8_buffer().size() <= 20 * 1024, "≤ 20 Ko")
	var met: Array = profile["characters_met"]
	assert_eq(met.size(), 54, "champs v2 conservés")


# ---------------------------------------------------------------------------
# Bugs (pending tant qu'ils ne sont pas corrigés)
# ---------------------------------------------------------------------------

## QA-072 : version non montée (export « CLEARANCE-0.13.0 », `game_version` des sauvegardes).
func test_qa072_version_is_0_14() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	_pass_or_pending(version.begins_with("0.14"), "QA-072", "config/version = %s" % version)


## QA-073 : REVOIR rejoue les planches conditionnelles telles que vues (F3 Lumika, F4 Dora).
func test_qa073_replay_shows_the_conditional_plates_seen() -> void:
	var bad: PackedStringArray = []
	for c: Array in REACHABLE:
		var ending: StringName = StringName(c[0])
		var act: int = c[1]
		var flags: Dictionary[StringName, Variant] = _typed(c[3])
		var variant: StringName = EpilogueService.variant_of(ending, flags)
		var def: CinematicDef = CinematicService.select(ending, variant, flags, act, c[2])
		var real: PackedStringArray = _sequence(def, CinematicService.context_flags(flags, act, variant, c[2]), act)
		# DossierScreen.replays_for / play_replay : drapeaux vides, variante et acte du profil.
		var empty: Dictionary[StringName, Variant] = {}
		var replay_def: CinematicDef = CinematicService.select(ending, variant, empty, act)
		var replay: PackedStringArray = _sequence(replay_def, CinematicService.context_flags(empty, act, variant), act)
		if replay != real:
			bad.append("%s/%s" % [ending, ",".join(PackedStringArray(Array(real).filter(func(p: String) -> bool: return not replay.has(p))))])
	_pass_or_pending(bad.is_empty(), "QA-073", "REVOIR ≠ séquence vue : %s" % "; ".join(bad))


## QA-074 : le fondu de sortie (1,5 s) n'est pas étouffé par le passe-bas de la pause.
func test_qa074_exit_fade_is_not_muffled_like_the_pause() -> void:
	var scene: DayScene = DAY_SCENE.instantiate() as DayScene
	add_child_autofree(scene)
	await wait_frames(3)
	var audio: AudioDirector = scene.get_node(^"%AudioDirector") as AudioDirector
	if not audio.music.is_playing():
		pending("QA-074 : musique absente (données non rendues)")
		return
	scene._leave_after_music_fade(func() -> void: pass)
	var paused: bool = get_tree().paused
	# L'arbre est en pause pendant le fondu : on fait tourner l'AudioDirector
	# (PROCESS_MODE_ALWAYS) à la main, comme une image du jeu.
	audio._process(0.016)
	var muffle: float = audio.music_muffle()
	get_tree().paused = false
	assert_true(paused, "précondition : arbre en pause pendant le fondu (D-208)")
	_pass_or_pending(is_zero_approx(muffle), "QA-074", "passe-bas %.0f Hz pendant le fondu de sortie (pause de l'arbre)" % muffle)


## QA-075 : titre → partie : la musique du titre s'éteint en fondu (pas de coupure nette).
func test_qa075_title_music_fades_out_before_the_game_scene() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	var title: MusicDirector = main.get_node_or_null(^"TitleMusic") as MusicDirector
	if title == null or not title.is_playing():
		pending("QA-075 : musique du titre absente")
		return
	await wait_seconds(1.8) # fondu d'entrée de 1,5 s terminé
	main.call(&"_start_day")
	await wait_frames(3)
	var fading: bool = title._fade_left > 0.0 or MusicDirector.get_fade_db() < -0.5
	_pass_or_pending(fading, "QA-075", "aucun fondu de sortie au départ vers day.tscn (main.gd change de scène tout de suite)")


## QA-076 : l'horloge de mesures du `MusicDirector` ne perd pas de temps sur
## une image longue (dt borné à 0,25 s) ; le fondu d'entrée ne saute pas.
func test_qa076_bar_clock_survives_a_long_frame() -> void:
	var d: MusicDirector = MusicDirector.new()
	add_child_autofree(d)
	var layers: Array[AudioStream] = []
	for i: int in 5:
		layers.append(AudioDsp.to_wav(AudioDsp.gain(AudioDsp.sine(3200, 220.0 * (i + 1), 32000), 0.1), 32000,
				PackedFloat32Array(), true))
	d.configure_set(&"ms_test", layers, 80.0)
	d.play(&"ms_test", 0, 1.5)
	var t0: int = Time.get_ticks_usec()
	OS.delay_msec(700) # image longue (chargement, compilation de shader)
	await wait_frames(2)
	var real_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var clock_ms: float = d._clock_usec / 1000.0
	var lag: float = real_ms - clock_ms
	var fade: float = MusicDirector.get_fade_db()
	_pass_or_pending(lag < 60.0, "QA-076", "horloge en retard de %.0f ms sur le flux après une image de 700 ms (fondu d'entrée à %.1f dB)" % [lag, fade])


## QA-077 : une annonce `drop` ne fait pas descendre le niveau sous le plancher du jour.
func test_qa077_drop_keeps_the_day_floor() -> void:
	var it: MusicIntensity = MusicIntensity.new()
	it.floor_level = 2
	it.smoothed = 0.62
	it.level = 3
	it.apply_action(HallAnnouncementDef.MUSIC_DROP)
	var decision: Dictionary = it.decide()
	assert_true((int(decision["mask"]) & MusicSetDef.MASK_POWER_DOWN) != 0, "drop : L0 seule pendant 4 mesures")
	_pass_or_pending(int(decision["level"]) >= it.floor_level, "QA-077",
			"niveau visé %d < plancher %d pendant le drop (J30 : N2 → N1, la musique revient un cran plus bas)" % [decision["level"], it.floor_level])


## QA-078 : chrono critique (< 15 s) → N4 atteint avant la sirène, même depuis N1
## (option Stable, journée calme) ; pire phase de mesure, 75 BPM (3,2 s).
func test_qa078_critical_clock_reaches_n4_in_time() -> void:
	var bar: float = 3.2
	var level: int = 1
	var since: int = 99
	var t: float = bar - 0.001 # la première mesure tombe juste après le début du chrono critique (pire cas)
	var reached: float = INF
	while t < MusicIntensity.CRITICAL_SEC:
		since += 1
		var next: int = MusicDirector.next_level(level, 4, since)
		if next != level:
			level = next
			since = 0
			if level == 4:
				reached = t
				break
		t += bar
	_pass_or_pending(reached < MusicIntensity.CRITICAL_SEC - 2.0, "QA-078",
			"depuis N1, N4 n'est pas atteint dans les 15 s (+1 / 2 mesures) ; mesuré en jeu : J15 Stable, N4 à 1 s de la sirène")


## QA-079 : fins simulées des actes I–II (F4, F5, F7, F8, F9) : pas de thème de
## fin, la musique du bilan continue (AUDIO §13.8, M14 §2.7).
func test_qa079_simulated_early_endings_keep_the_evening_music() -> void:
	var director: AudioDirector = AudioDirector.new()
	director.sync_barks = true
	add_child_autofree(director)
	GameState.narrative_flags = {&"act2_started": true}
	assert_null(CinematicService.select(&"f4_glory", &"", GameState.narrative_flags, 2, 20), "F4 acte II : aucune cinématique")
	director.music_state = &"evening"
	director.on_end_screen(&"f4_glory")
	_pass_or_pending(director.theme_id == &"", "QA-079", "F4 de l'acte II : thème %s lancé sous l'écran de fin" % director.theme_id)


## QA-080 : capture de debug `--cinematic=<id>` : la séquence demandée est jouée
## (F5 Charte et Brûlants, F6 Dérive ne passaient que par F5S / F6T).
func test_qa080_debug_cinematic_plays_the_requested_sequence() -> void:
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	var wrong: PackedStringArray = []
	for id: StringName in [&"cin_f1", &"cin_f5c", &"cin_f5s", &"cin_f5b", &"cin_f6d", &"cin_f6t", &"cin_f9"]:
		var def: CinematicDef = lib.get_cinematic(id)
		GameState.narrative_flags = {&"act2_started": true, &"act3_started": true}
		if not def.ending_variants.is_empty():
			DayScene.ctx_variant_flags(def.endings[0], def.ending_variants[0])
		var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
		var got: CinematicDef = CinematicService.select(def.endings[0], EpilogueService.variant_of(def.endings[0], flags), flags, 3, 30)
		if got == null or got.id != id:
			wrong.append("%s → %s" % [id, got.id if got != null else "aucune"])
	_pass_or_pending(wrong.is_empty(), "QA-080", ", ".join(wrong))
