## MusicIntensity (M14 §2.5, D-177 ; docs/M14.md §6.3) : bornes, monotonie,
## hystérésis, vitesse des changements, cas particuliers (Récit / J31, Stable,
## chrono critique, coupure, Inspection, annonces, plancher, Garde) et
## **aucune entrée issue de `CaseKey`** (analyse des dépendances du code).
extends GutTest

const SOURCES: Array[String] = ["res://scripts/audio/music_intensity.gd"]


func _canonical_set() -> MusicSetDef:
	var s: MusicSetDef = MusicSetDef.new()
	s.id = &"ms_test"
	var metas: Array[Array] = [[&"l0", 0, -1, true, false, true], [&"l1", 1, -1, false, false, false],
		[&"l2", 2, -1, false, false, false], [&"l3", 3, 4, true, true, false], [&"l4", 4, -1, false, false, false]]
	for m: Array in metas:
		var layer: MusicLayerDef = MusicLayerDef.new()
		layer.id = m[0]
		layer.enter_level = m[1]
		layer.exit_level = m[2]
		layer.exposed = m[3]
		layer.melodic = m[4]
		layer.keeps_on_power_down = m[5]
		s.layers.append(layer)
	return s


func test_terms_follow_m14_formulas() -> void:
	assert_eq(MusicIntensity.queue_term(2), 0.0)
	assert_almost_eq(MusicIntensity.queue_term(5), 0.5, 0.0001)
	assert_eq(MusicIntensity.queue_term(8), 1.0)
	assert_eq(MusicIntensity.queue_term(-1), 0.0, "Garde : file ignorée")
	assert_eq(MusicIntensity.clock_term(0.4), 0.0)
	assert_eq(MusicIntensity.clock_term(1.0), 1.0)
	assert_almost_eq(MusicIntensity.discrepancy_term(1), 0.5, 0.0001)
	assert_eq(MusicIntensity.discrepancy_term(5), 1.0)
	assert_eq(MusicIntensity.quota_term(3, 0), 0.0, "sans quota")
	assert_eq(MusicIntensity.quota_term(5, 10), 0.0)
	assert_eq(MusicIntensity.quota_term(10, 10), 1.0)
	assert_eq(MusicIntensity.tension_term(3), 0.20)
	assert_almost_eq(MusicIntensity.formula(1, 1, 1, 1, 1, 0.2), 1.0, 0.0001, "borné à 1")
	assert_almost_eq(MusicIntensity.formula(1, 0, 0, 0, 0, 0.0), 0.25, 0.0001)
	assert_almost_eq(MusicIntensity.formula(0, 1, 0, 0, 0, 0.0), 0.35, 0.0001)
	assert_almost_eq(MusicIntensity.garde_value(2, 1), 0.30 + 0.24 + 0.10, 0.0001)


func test_value_is_bounded_and_monotonic_in_each_input() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 14
	for trial: int in 200:
		var m: MusicIntensity = MusicIntensity.new()
		m.queue_remaining = rng.randi_range(-1, 12)
		m.elapsed_ratio = rng.randf()
		m.discrepancies = rng.randi_range(0, 4)
		m.quota_max = rng.randi_range(0, 10)
		m.quota_used = rng.randi_range(0, 12)
		m.event_weight = rng.randf()
		m.tension = rng.randi_range(0, 3)
		var base: float = m.compute()
		assert_between(base, 0.0, 1.0)
		for field: String in ["queue_remaining", "discrepancies", "quota_used", "tension"]:
			var up: MusicIntensity = _copy(m)
			up.set(field, int(m.get(field)) + 1)
			assert_true(up.compute() >= base - 0.000001, "monotone en %s" % field)
		for field: String in ["elapsed_ratio", "event_weight"]:
			var up2: MusicIntensity = _copy(m)
			up2.set(field, minf(float(m.get(field)) + 0.1, 1.0))
			assert_true(up2.compute() >= base - 0.000001, "monotone en %s" % field)


func _copy(m: MusicIntensity) -> MusicIntensity:
	var c: MusicIntensity = MusicIntensity.new()
	for field: String in ["queue_remaining", "elapsed_ratio", "timed", "discrepancies", "quota_used", "quota_max",
			"event_weight", "tension"]:
		c.set(field, m.get(field))
	return c


func test_hysteresis_around_thresholds() -> void:
	assert_eq(MusicIntensity.quantize(0.37, 1), 1, "0,35 franchi de moins de 0,05 : reste N1")
	assert_eq(MusicIntensity.quantize(0.41, 1), 2)
	assert_eq(MusicIntensity.quantize(0.32, 2), 2, "redescend seulement sous 0,30")
	assert_eq(MusicIntensity.quantize(0.29, 2), 1)
	assert_eq(MusicIntensity.quantize(1.0, 0), 4)
	var s: MusicSetDef = _canonical_set()
	for v: float in [0.0, 0.2, 0.37, 0.41, 0.66, 0.9]:
		for cur: int in 5:
			assert_eq(MusicIntensity.quantize(v, cur, s), MusicIntensity.quantize(v, cur), "même règle que MusicSetDef")


func test_level_changes_are_rate_limited_per_bar() -> void:
	# +1 au plus toutes les 2 mesures, −1 toutes les 4 (MusicDirector.next_level).
	var level: int = 0
	var since: int = 0
	var changes: Array[int] = []
	for bar: int in 20:
		since += 1
		var next: int = MusicDirector.next_level(level, 4, since)
		if next != level:
			changes.append(bar)
			assert_eq(next, level + 1)
			level = next
			since = 0
	assert_eq(level, 4)
	for k: int in range(1, changes.size()):
		assert_true(changes[k] - changes[k - 1] >= 2, "≥ 2 mesures entre deux montées")
	since = 0
	var downs: Array[int] = []
	for bar: int in 30:
		since += 1
		var next: int = MusicDirector.next_level(level, 0, since)
		if next != level:
			downs.append(bar)
			assert_eq(next, level - 1)
			level = next
			since = 0
	for k: int in range(1, downs.size()):
		assert_true(downs[k] - downs[k - 1] >= 4, "≥ 4 mesures entre deux descentes")


func test_smoothing_rises_faster_than_it_falls() -> void:
	var m: MusicIntensity = MusicIntensity.new()
	m.queue_remaining = 8
	m.elapsed_ratio = 1.0
	m.discrepancies = 2
	m.quota_used = 10
	m.quota_max = 10
	m.event_weight = 1.0
	m.step(4.0)
	assert_almost_eq(m.smoothed, 1.0 - exp(-1.0), 0.01, "montée τ = 4 s")
	m.smoothed = 1.0
	m.queue_remaining = 0
	m.elapsed_ratio = 0.0
	m.discrepancies = 0
	m.quota_used = 0
	m.event_weight = 0.0
	m.step(8.0)
	assert_almost_eq(m.smoothed, exp(-1.0), 0.01, "descente τ = 8 s")


func _hot() -> MusicIntensity:
	var m: MusicIntensity = MusicIntensity.new()
	m.smoothed = 1.0
	m.level = 4
	return m


func test_special_cases() -> void:
	var s: MusicSetDef = _canonical_set()
	var m: MusicIntensity = _hot()
	assert_eq(int(m.decide(s)["level"]), 4)
	m = _hot()
	m.capped = true
	assert_eq(int(m.decide(s)["level"]), 2, "Récit et J31 : plafond N2")
	m = _hot()
	m.stable = true
	assert_eq(int(m.decide(s)["level"]), 1, "Stable : N1")
	m = MusicIntensity.new()
	m.remaining_sec = 10.0
	var crit: Dictionary = m.decide(s)
	assert_eq(int(crit["level"]), 4, "chrono critique : N4")
	assert_true((int(crit["mask"]) & MusicSetDef.MASK_NO_MELODY) != 0, "chrono critique : L3 coupée")
	assert_eq(s.active_layers(4, int(crit["mask"])), PackedInt32Array([0, 1, 2, 4]))
	m = _hot()
	m.power_down = true
	var pd: Dictionary = m.decide(s)
	assert_eq(s.active_layers(int(pd["level"]), int(pd["mask"])), PackedInt32Array([0]), "coupure : L0 seule")
	assert_eq(float(pd["extra_db"]), -6.0, "coupure : L0 −6 dB")
	m = _hot()
	m.level = 3
	m.smoothed = 0.7
	m.inspection_reduce = true
	var insp: Dictionary = m.decide(s)
	assert_false(s.active_layers(int(insp["level"]), int(insp["mask"])).has(3), "Inspection : aucune mélodie")
	m = MusicIntensity.new()
	m.floor_level = 2
	assert_eq(int(m.decide(s)["level"]), 2, "plancher du jour")
	m = MusicIntensity.new()
	m.garde = true
	m.garde_tier = 2
	m.queue_remaining = 8
	assert_almost_eq(m.compute(), MusicIntensity.garde_value(2, 0), 0.0001, "Garde : file et chrono ignorés")
	m.stable = true
	m.smoothed = m.compute()
	assert_true(int(m.decide(s)["level"]) >= 2, "la Garde ignore l'option Stable (pas de shift)")


func test_hall_announcement_actions() -> void:
	var s: MusicSetDef = _canonical_set()
	var m: MusicIntensity = _hot()
	m.apply_action(HallAnnouncementDef.MUSIC_DROP)
	var d: Dictionary = m.decide(s)
	assert_eq(s.active_layers(int(d["level"]), int(d["mask"])), PackedInt32Array([0]), "drop : L0 seule")
	assert_eq(float(d["extra_db"]), -6.0)
	for bar: int in MusicIntensity.ACTION_BARS:
		m.on_bar()
	assert_eq(m.action, &"", "drop : 4 mesures")
	m = MusicIntensity.new()
	m.smoothed = 0.4
	m.level = 2
	m.apply_action(HallAnnouncementDef.MUSIC_SWELL)
	assert_eq(int(m.decide(s)["level"]), 3, "swell : +1 niveau")
	m = _hot()
	m.apply_action(HallAnnouncementDef.MUSIC_SILENCE)
	for bar: int in 10:
		m.on_bar()
	assert_true((int(m.decide(s)["mask"]) & MusicSetDef.MASK_POWER_DOWN) != 0, "silence : power down jusqu'à la fin")
	m.apply_action(&"inconnu")
	assert_eq(m.action, HallAnnouncementDef.MUSIC_SILENCE, "action inconnue ignorée")


func test_no_input_comes_from_case_key() -> void:
	for path: String in SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		for forbidden: String in ["CaseKey", "case_key", "Case.key", ".key.", "anomal", "verdict"]:
			assert_false(text.findn(forbidden) >= 0 and not _only_in_comments(text, forbidden),
					"%s ne lit pas « %s »" % [path.get_file(), forbidden])
	# L'AudioDirector nourrit l'intensité depuis des signaux publics seulement.
	var director: String = FileAccess.get_file_as_string("res://scripts/audio/audio_director.gd")
	for line: String in director.split("\n"):
		if line.contains("intensity.") and not line.strip_edges().begins_with("#"):
			for forbidden: String in ["CaseKey", "_current_case", ".key", "anomal"]:
				assert_false(line.contains(forbidden), "entrée d'intensité sans « %s » : %s" % [forbidden, line.strip_edges()])


static func _only_in_comments(text: String, word: String) -> bool:
	for line: String in text.split("\n"):
		var code: String = line.get_slice("#", 0)
		if code.findn(word) >= 0:
			return false
	return true
