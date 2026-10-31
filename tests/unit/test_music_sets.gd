## Catalogue musical M14 (docs/M14.md §6.2 M-06, M-12 ; §6.3) : ensembles
## MS-01 → MS-07 et thèmes présents, couches de longueur **exacte**, `.import`
## cohérents, une fin (et chaque variante d'`EpilogueService`) → un thème,
## mondes du J31, MO-1 et MO-2 jamais dans la même mesure hors TH-F5C et TH-F10
## (lecture des partitions), sélection de l'`AudioDirector` identique à
## `MusicLibraryDef`, budget disque.
extends GutTest

const SETS: Array[StringName] = [&"ms_01", &"ms_02", &"ms_03", &"ms_04", &"ms_05", &"ms_06", &"ms_07"]
const MANIFEST_PATH: String = "res://assets/audio/music/manifest.json"
const MOTIF_EXCEPTIONS: Array[String] = ["thf5c", "thf10"]
## Fins et variantes de l'Acte III (EpilogueService.variant_of) qui ont un thème.
const ENDING_VARIANTS: Array[Array] = [
	[&"f1_arrested", &"double"], [&"f1_arrested", &"audit"], [&"f1_arrested", &"review"], [&"f1_arrested", &"deposition"],
	[&"f2_reassigned", &""], [&"f3_family_lost", &""], [&"f4_glory", &""], [&"f5_air", &"c"], [&"f5_air", &"s"],
	[&"f5_air", &"b"], [&"f6_drift", &"j10"], [&"f6_drift", &"j20"], [&"f6_drift", &"d"], [&"f6_drift", &"t"],
	[&"f7_reopens", &""], [&"f8_registre", &""], [&"f9_strike", &""], [&"f10_pont", &""],
]

var library: MusicLibraryDef = null


func before_all() -> void:
	library = MusicLibraryDef.load_default()


func test_every_set_exists_with_exact_layers() -> void:
	if library == null:
		pending("musique pas encore rendue")
		return
	for set_id: StringName in SETS:
		var s: MusicSetDef = library.get_set(set_id)
		assert_not_null(s, "%s dans la bibliothèque" % set_id)
		if s == null:
			continue
		assert_true(s.is_sample_exact(32000) and s.is_sample_exact(48000), "%s : tempo exact" % set_id)
		assert_eq(s.sample_rate, 32000)
		assert_gt(s.layers.size(), 1)
		for layer: MusicLayerDef in s.layers:
			assert_not_null(layer.stream, "%s/%s rendue" % [set_id, layer.id])
			if layer.stream == null:
				continue
			assert_eq(roundi(layer.stream.get_length() * s.sample_rate), s.loop_samples(),
					"%s/%s : longueur exacte (M-06)" % [set_id, layer.id])
			var text: String = FileAccess.get_file_as_string(layer.stream.resource_path + ".import")
			assert_true(text.contains("loop=true"), "%s/%s : loop" % [set_id, layer.id])
			assert_true(text.contains("bpm=%s" % str(snappedf(s.tempo_bpm, 0.001))), "%s/%s : bpm" % [set_id, layer.id])
			assert_true(text.contains("beat_count=%d" % (s.bars * s.beats_per_bar)), "%s/%s : beat_count" % [set_id, layer.id])
			assert_true(text.contains("bar_beats=%d" % s.beats_per_bar), "%s/%s : bar_beats" % [set_id, layer.id])
	# Rôles : MS-02 → MS-05 canoniques ; MS-01, MS-06 au niveau 0 ; MS-07 par monde.
	for set_id: StringName in [&"ms_02", &"ms_03", &"ms_04", &"ms_05"]:
		var s5: MusicSetDef = library.get_set(set_id)
		assert_eq(s5.active_layers(4), PackedInt32Array([0, 1, 2, 4]), "%s : N4 = L0 L1 L2 L4" % set_id)
		assert_eq(s5.active_layers(0, MusicSetDef.MASK_EXPOSED), PackedInt32Array([0, 3]), "%s : exposé = L0 + L3" % set_id)
	assert_eq(library.get_set(&"ms_01").max_level, 0)
	assert_eq(library.get_set(&"ms_06").max_level, 0)
	var ms06: MusicSetDef = library.get_set(&"ms_06")
	assert_eq(ms06.active_layers(0, 0, [&"warm"] as Array[StringName]).size(), 2, "soirée : lit + chaud")
	assert_eq(ms06.active_layers(0, 0, [&"crisis"] as Array[StringName]).size(), 2, "soirée : lit + crise")
	var ms01: MusicSetDef = library.get_set(&"ms_01")
	assert_eq(ms01.active_layers(0).size(), 3, "titre sans fin vue : 3 couches")
	assert_eq(ms01.active_layers(0, 0, [&"ending_seen"] as Array[StringName]).size(), 4, "titre : MO-2 après une fin vue")
	var ms07: MusicSetDef = library.get_set(&"ms_07")
	for w: StringName in [&"a", &"b", &"c", &"d"]:
		var groups: Array[StringName] = [MusicLibraryDef.world_group(w)]
		assert_eq(ms07.active_layers(1, 0, groups).size(), 3, "J31 monde %s : 2 couches communes + 1" % w)


func test_every_ending_and_variant_has_a_theme() -> void:
	if library == null:
		pending("musique pas encore rendue")
		return
	var index: Dictionary = AudioDirector.music_index()
	assert_false(index.is_empty(), "index.json")
	for pair: Array in ENDING_VARIANTS:
		var theme: MusicThemeDef = library.theme_for_ending(pair[0], pair[1])
		assert_not_null(theme, "%s/%s → thème" % pair)
		if theme == null:
			continue
		assert_eq(AudioDirector.theme_path_for_ending(pair[0], pair[1], index), theme.resource_path,
				"%s/%s : sélection de l'AudioDirector = MusicLibraryDef" % pair)
		assert_not_null(theme.stream, "%s : flux" % theme.id)
		assert_eq(theme.sample_rate, 48000, "%s : 48 kHz" % theme.id)
		assert_true(MusicDirector.theme_gain_db(theme) < 6.0 and MusicDirector.theme_gain_db(theme) > -24.0,
				"%s : gain d'exécution plausible" % theme.id)
		if theme.reuse_set_id == &"":
			assert_not_null(theme.tail_stream, "%s : queue" % theme.id)
	assert_eq(library.theme_for_ending(&"f5_air", &"s").id, &"th_f5s")
	assert_eq(library.theme_for_ending(&"f5_air", &"b").id, &"th_f5b")
	assert_eq(library.theme_for_ending(&"f6_drift", &"t").id, &"th_f6t")
	assert_eq(library.theme_for_ending(&"f6_drift", &"j10").id, &"th_f6")
	assert_not_null(library.get_theme(&"th_f5b").reduced_fx_stream, "F5B : flux « effets réduits »")
	var flags: Dictionary[StringName, Variant] = {&"okonkwo_warned": true}
	assert_eq(library.get_theme(&"th_f1").variant_for(flags).id, &"okonkwo_warned")
	flags = {&"lumika_learned": true}
	assert_eq(library.get_theme(&"th_f3").variant_for(flags).id, &"lumika_learned")
	flags = {&"final3_dora": true}
	assert_eq(library.get_theme(&"th_f4").variant_for(flags).id, &"dora")
	assert_null(library.get_theme(&"th_f4").variant_for({}), "sans drapeau : thème de base")
	assert_eq(library.get_theme(&"th_f7").reuse_set_id, &"ms_02", "TH-F7 reprend MS-02")
	for w: StringName in [&"a", &"b", &"c", &"d"]:
		var wt: MusicThemeDef = library.theme_for_world(w)
		assert_not_null(wt, "monde %s → thème" % w)
		assert_eq(AudioDirector.theme_path_for_world(w, index), wt.resource_path)


func test_theme_streams_chain_into_their_tails() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		pending("musique pas encore rendue")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	for score_id: String in manifest["scores"]:
		var entry: Dictionary = manifest["scores"][score_id]
		if str(entry["kind"]) != "theme":
			continue
		var bar_n: int = int(entry["bar_samples"])
		for name: String in entry["files"]:
			var f: Dictionary = entry["files"][name]
			if str(f.get("role", "")) == "main":
				assert_eq(int(f["samples"]), (int(entry["tail_from_bar"]) + int(entry["main_tail_bars"])) * bar_n,
						"%s : ouverture → B + %d mesures de queue" % [name, int(entry["main_tail_bars"])])
			elif str(f.get("role", "")) == "tail":
				assert_eq(int(f["samples"]), int(entry["tail_bars"]) * bar_n, "%s : queue de %d mesures" % [name, int(entry["tail_bars"])])


func test_mo1_and_mo2_never_share_a_bar() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://art_src/music")
	var checked: int = 0
	for file: String in files:
		if not file.ends_with(".json") or MOTIF_EXCEPTIONS.has(file.get_basename()):
			continue
		var score: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/music/" + file))
		var motifs: Dictionary = score.get("motifs", {})
		# [motif (« MO-1 » / « MO-2 »), groupe de la couche, variante, mesures occupées]
		var spans: Array[Array] = []
		for stem: Dictionary in score.get("stems", []):
			var group: String = str(stem.get("layer", {}).get("group", ""))
			for track: Dictionary in stem.get("tracks", []):
				for ev: Dictionary in track.get("events", []):
					var name: String = str(ev.get("motif", ""))
					if name.is_empty():
						continue
					var family: String = "MO-1" if name.begins_with("MO-1") else ("MO-2" if name.begins_with("MO-2") else "")
					if family.is_empty():
						continue
					var length: float = 0.0
					for m: Dictionary in motifs.get(name, []):
						length = maxf(length, float(m.get("step", 0)) + float(m.get("len", 1)))
					var stretch: float = float(ev.get("stretch", 1.0))
					var first: int = int(ev.get("bar", 0)) * 16 + int(ev.get("step", 0))
					var last: int = first + ceili(length * stretch) - 1
					spans.append([family, group, str(track.get("variant", "")), range(first / 16, last / 16 + 1)])
		for a: Array in spans:
			for b: Array in spans:
				if a[0] != "MO-1" or b[0] != "MO-2":
					continue
				if a[1] != "" and b[1] != "" and a[1] != b[1]:
					continue # groupes exclusifs (mondes du J31) : jamais ensemble
				if a[2] != "" and b[2] != "" and a[2] != b[2]:
					continue
				for bar: int in a[3]:
					assert_false((b[3] as Array).has(bar), "%s : MO-1 et MO-2 dans la mesure %d" % [file, bar + 1])
		checked += 1
	assert_gt(checked, 10, "partitions lues")


func test_director_set_selection_matches_library() -> void:
	for day: int in range(1, 32):
		assert_eq(AudioDirector.set_id_for(day), MusicLibraryDef.set_id_for_day(day), "J%d" % day)
	assert_eq(AudioDirector.set_id_for(5, DayDef.MODE_GARDE), MusicLibraryDef.set_id_for_day(5, DayDef.MODE_GARDE))
	assert_eq(AudioDirector.set_id_for(31, DayDef.MODE_EPILOGUE), MusicLibraryDef.set_id_for_day(31, DayDef.MODE_EPILOGUE))


func test_music_fits_the_disk_budget() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		pending("musique pas encore rendue")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_lte(int(manifest.get("total_ogg_bytes", 0)), 24 * 1024 * 1024, "musique ≤ 24 Mo (M-12)")
	for legacy: String in ["mus_briefing_loop", "mus_shift_calm_loop", "mus_shift_tension_loop", "mus_debrief_loop",
			"mus_debrief_minor_loop"]:
		assert_false(FileAccess.file_exists("res://assets/audio/music/%s.ogg" % legacy), "%s supprimée (M6)" % legacy)
