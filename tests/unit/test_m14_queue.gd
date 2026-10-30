## M14 lot A — file réelle (B86, D-187 ; ARCHITECTURE §12 ter.4) : `QueueSilhouette`
## ne porte que teinte, coiffe et taille ; elle vient du roster du jour (graine
## seule), **jamais** d'une anomalie, d'un document ni d'un verdict ; elle est
## déterministe ; `upcoming` et `visible_count` bornent la file (VH-2, Garde).
extends GutTest

const GF = preload("res://tests/helpers/generation_fixtures.gd")


func test_only_whitelisted_fields() -> void:
	var s: QueueSilhouette = QueueSilhouette.new()
	var fields: PackedStringArray = []
	for p: Dictionary in s.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(str(p["name"]))
	assert_eq(fields, QueueSilhouette.FIELDS, "aucun champ hors liste blanche")
	assert_eq(s.serialize().keys().size(), QueueSilhouette.FIELDS.size())
	for forbidden: String in ["faction", "anomal", "verdict", "document", "case", "key", "visor", "accessory", "implant"]:
		for f: String in fields:
			assert_false(f.contains(forbidden), "champ « %s » interdit" % f)


func test_shapes_hide_a_lowered_visor() -> void:
	var app: PassengerAppearance = PassengerAppearance.new()
	for row: Array in [[&"none", QueueSilhouette.SHAPE_BARE], [&"beanie", QueueSilhouette.SHAPE_BARE],
			[&"hood", QueueSilhouette.SHAPE_HOOD], [&"visor_down", QueueSilhouette.SHAPE_HOOD],
			[&"visor_up", QueueSilhouette.SHAPE_HOOD], [&"cap", QueueSilhouette.SHAPE_CAP], [&"", QueueSilhouette.SHAPE_BARE]]:
		app.traits[PassengerAppearance.SLOT_HEADWEAR] = row[0]
		assert_eq(QueueSilhouette.shape_of(app), row[1], "coiffe %s" % row[0])
	app.traits[PassengerAppearance.SLOT_PALETTE] = &"palette_07"
	app.height_step = 5
	var s: QueueSilhouette = QueueSilhouette.from_appearance(3, app)
	assert_eq(s.palette_index, 6)
	assert_eq(s.height_step, 2, "taille bornée −2..+2")
	assert_eq(s.index, 3)
	assert_eq(QueueSilhouette.from_appearance(0, null).shape, QueueSilhouette.SHAPE_BARE)
	assert_eq(QueueSilhouette.make(0, 99, &"wings", 0).serialize(), {"index": 0, "palette_index": 11, "shape": "bare", "height_step": 0})


func _builder(day: DayDef, seed: int) -> CaseBuilder:
	return CaseBuilder.new(GF.data(), day, seed)


func _serialized(list: Array[QueueSilhouette]) -> Array:
	var out: Array = []
	for s: QueueSilhouette in list:
		out.append(s.serialize())
	return out


func test_silhouettes_are_deterministic_and_blind_to_anomalies() -> void:
	var day: DayDef = GF.full_day([0.0, 0.0, 1.0, 0.0], 12)
	for group: int in 6:
		var seed: int = GF.day_seed(group, 5)
		var clean: CaseBuilder = _builder(day, seed)
		var before: Array = _serialized(QueueSilhouette.upcoming(clean.roster, 0, 12, 12))
		assert_eq(before.size(), 12)
		assert_eq(before, _serialized(QueueSilhouette.upcoming(_builder(day, seed).roster, 0, 12, 12)), "déterministe")
		# Même graine, chaque passager construit avec deux anomalies (puis sans) :
		# les silhouettes ne bougent pas.
		var dirty: CaseBuilder = _builder(day, seed)
		for i: int in 12:
			dirty.build(i)
		assert_eq(_serialized(QueueSilhouette.upcoming(dirty.roster, 0, 12, 12)), before, "graine %d : aucune trace des anomalies" % group)
		for i: int in 12:
			clean.build_clean(i)
		assert_eq(_serialized(QueueSilhouette.upcoming(clean.roster, 0, 12, 12)), before)


func test_silhouette_matches_the_roster_entry() -> void:
	var day: DayDef = GF.full_day()
	var builder: CaseBuilder = _builder(day, GF.day_seed(1, 5))
	var list: Array[QueueSilhouette] = QueueSilhouette.upcoming(builder.roster, 0, 12, 12)
	for s: QueueSilhouette in list:
		var app: PassengerAppearance = builder.roster.get_entry(s.index).appearance
		assert_eq(s.shape, QueueSilhouette.shape_of(app))
		assert_eq(s.height_step, app.height_step)
		assert_eq(s.palette_index, QueueSilhouette.palette_index_of(app))
		assert_between(s.palette_index, 0, QueueSilhouette.PALETTE_COUNT - 1)


func test_upcoming_and_visible_count_bound_the_queue() -> void:
	var day: DayDef = GF.full_day()
	var roster: AppearanceRoster = _builder(day, GF.day_seed(2, 5)).roster
	var list: Array[QueueSilhouette] = QueueSilhouette.upcoming(roster, 0, 12)
	assert_eq(list.size(), QueueSilhouette.MAX_UPCOMING, "tête + 6 places + 3 de débordement")
	assert_eq(list[0].index, 0, "upcoming[0] = le prochain appelé")
	list = QueueSilhouette.upcoming(roster, 9, 12)
	assert_eq(list.size(), 3)
	assert_eq(list[2].index, 11)
	assert_eq(QueueSilhouette.upcoming(roster, 12, 12).size(), 0, "file vide après le dernier")
	assert_eq(QueueSilhouette.upcoming(roster, 0, 4).size(), 4, "jamais au-delà de total")
	assert_eq(QueueSilhouette.upcoming(roster, 5, -1, 4).size(), 4, "Garde : bornée par le roster")
	assert_eq(QueueSilhouette.upcoming(null, 0, 12).size(), 0)
	# VH-2 : min(restants − 1, places).
	assert_eq(QueueSilhouette.visible_count(0, 12, 6), 6)
	assert_eq(QueueSilhouette.visible_count(8, 12, 6), 3)
	assert_eq(QueueSilhouette.visible_count(11, 12, 6), 0, "le dernier arrive devant une file vide")
	assert_eq(QueueSilhouette.visible_count(12, 12, 6), 0)
	assert_eq(QueueSilhouette.visible_count(40, -1, 6), 6, "Garde : file toujours pleine")


func test_queue_progressed_signal_carries_typed_silhouettes() -> void:
	var received: Array = []
	var cb: Callable = func(processed: int, total: int, upcoming: Array[QueueSilhouette]) -> void:
		received.append([processed, total, upcoming.size()])
	EventBus.queue_progressed.connect(cb)
	var roster: AppearanceRoster = _builder(GF.full_day(), GF.day_seed(3, 5)).roster
	EventBus.queue_progressed.emit(2, 12, QueueSilhouette.upcoming(roster, 2, 12))
	EventBus.queue_progressed.disconnect(cb)
	assert_eq(received, [[2, 12, 10]])
