## M13 lot A (ARCHITECTURE §12) : modèle des déclarations (comparables, zéro
## discordance chez un honnête au niveau du modèle, composition des cadres),
## pseudo-documents `FieldRef`, fouille (zones, objets, trouvailles),
## améliorations (`UpgradeDef`), coûts en temps, intercom piloté par les
## données, sérialisation (format 2) et déterminisme.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")

## Formules de durée à intervalle de M13 §1.6 (VN-6).
const FORMULA_INTERVALS: Array[Vector2i] = [
	Vector2i(6, 8), Vector2i(9, 11), Vector2i(12, 16), Vector2i(18, 24), Vector2i(26, 34), Vector2i(38, 46),
	Vector2i(55, 65), Vector2i(80, 100), Vector2i(170, 190), Vector2i(350, 380), Vector2i(1050, 1150),
]

const TEXTS: Dictionary[String, String] = {
	"stmt_purpose_trade_1": "Le commerce",
	"stmt_dur_d5": "Cinq jours",
	"stmt_dur_w1": "Une semaine",
	"stmt_dur_d10": "Dix jours",
	"stmt_dur_n": "%d jours",
	"stmt_employer": "chez {employeur}",
	"stmt_host_son": "mon fils, %s",
	"line_stmt_frame_gen_1": "{motif}. {duree}.",
	"line_stmt_frame_correct_1": "{motif}. {duree_barree}… non, {duree}.",
	"line_stmt_frame_work_1": "{motif}, {employeur}. {duree}.",
}

var spoken: Array[Array] = []


func _t(key: String) -> String:
	return TEXTS.get(key, key)


# --- Déclarations ----------------------------------------------------------------

func test_duration_statement_compares_by_interval() -> void:
	var said: Statement = Statement.duration(18, 24, "stmt_dur_w3")
	assert_eq(said.id, Statement.ID_STAY)
	assert_eq(said.truth_path, Statement.PATH_STAY)
	assert_eq(said.topic, Statement.QUESTION_STAY)
	assert_eq(said.compare_to(20), Statement.Match.CONCORDANT, "trois semaines ~ 20 jours (VN-6)")
	assert_eq(said.compare_to(18), Statement.Match.CONCORDANT, "borne incluse")
	assert_eq(said.compare_to(5), Statement.Match.DISCORDANT, "AV-2 : permis 5 jours")
	assert_eq(said.compare_to("5"), Statement.Match.INCOMPARABLE, "valeur non entière")
	assert_eq(said.compare_to(null), Statement.Match.INCOMPARABLE)
	assert_eq(Statement.duration(7, 5).value, Vector2i(5, 7), "bornes remises dans l'ordre")


func test_vague_provenance_and_struck_values_are_never_comparable() -> void:
	var vague: Statement = Statement.vague_answer(Statement.ID_STAY, "stmt_dur_vague_1")
	assert_false(vague.is_comparable())
	for days: int in [1, 5, 30, 400]:
		assert_eq(vague.compare_to(days), Statement.Match.INCOMPARABLE, "VN-1")
	var provenance: Statement = Statement.make(Statement.ID_PROVENANCE, &"tyc", "stmt_prov_tessar")
	assert_eq(provenance.truth_path, &"", "la provenance n'a pas de champ")
	assert_eq(provenance.compare_to(&"cer"), Statement.Match.INCOMPARABLE, "VN-3 : jamais comparée")
	var corrected: Statement = Statement.duration(10, 10, "stmt_dur_d10")
	corrected.corrected_from = "stmt_dur_w1"
	assert_true(corrected.is_corrected())
	assert_eq(corrected.compare_to(10), Statement.Match.CONCORDANT, "VN-2 : la dernière valeur fait foi")
	assert_eq(corrected.compare_to(7), Statement.Match.DISCORDANT, "la valeur barrée n'est pas comparée")


func test_text_statements_compare_normalized_values() -> void:
	var purpose: Statement = Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_TRADE)
	assert_eq(purpose.compare_to(&"trade"), Statement.Match.CONCORDANT)
	assert_eq(purpose.compare_to(&"transit"), Statement.Match.DISCORDANT, "AV-1")
	var host: Statement = Statement.make(Statement.ID_HOST, "Tomás Moreno-Lind")
	assert_eq(host.truth_path, Statement.PATH_SPONSOR_NAME)
	assert_eq(host.compare_to("TOMAS MORENO LIND"), Statement.Match.CONCORDANT, "sans casse ni diacritique")
	assert_eq(host.compare_to("Tomás Kerr"), Statement.Match.DISCORDANT, "AV-5 : autre nom de famille")
	var employer: Statement = Statement.make(Statement.ID_EMPLOYER, "Kessler-Ashe Orbital")
	assert_eq(employer.compare_to("kessler ashe orbital"), Statement.Match.CONCORDANT)
	assert_eq(employer.compare_to("Ceres-Verte"), Statement.Match.DISCORDANT, "AV-3")
	assert_eq(Statement.normalize_text("  Élodie   Ñúñez-Ørsted "), "elodie nunez orsted")
	assert_eq(Statement.make(Statement.ID_ORIGIN, &"cer").truth_path, Statement.PATH_ORIGIN)


## D-143 : un passager honnête (valeurs lues sur ses papiers, durée exacte ou
## formule qui la contient, vague, auto-correction finale vraie, casse et
## accents perdus à l'oral, provenance) ne produit **jamais** de DISCORDANCE
## avec ses documents, sur de vrais cas générés sans anomalie J4 → J30.
func test_honest_statements_never_discordant_on_generated_cases() -> void:
	var checked: int = 0
	var failures: PackedStringArray = []
	for day_number: int in range(4, 31):
		var day: DayDef = Gen.data().get_day(day_number)
		if day == null:
			continue
		for group: int in 2:
			var builder: CaseBuilder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(group, day_number))
			for index: int in day.passenger_count:
				var generated: GeneratedCase = builder.build(index)
				if generated == null or generated.case == null or not generated.key.anomalies.is_empty():
					continue
				var c: Case = generated.case
				for statement: Statement in _honest_statements(c):
					for ref: FieldRef in c.find_refs_by_truth_path(statement.truth_path):
						checked += 1
						if statement.compare_to(c.get_value(ref)) == Statement.Match.DISCORDANT:
							failures.append("J%d %s %s ↔ %s" % [day_number, c.case_id, statement, ref.key()])
	assert_gt(checked, 500, "assez de comparaisons")
	assert_eq(failures.size(), 0, Gen.head(failures))


## Déclarations honnêtes d'un cas, lues sur son premier document portant
## chaque champ (comme le générateur du lot B) : chaque variante de bruit.
func _honest_statements(c: Case) -> Array[Statement]:
	var result: Array[Statement] = []
	var stay_refs: Array[FieldRef] = c.find_refs_by_truth_path(Statement.PATH_STAY)
	if not stay_refs.is_empty() and c.get_value(stay_refs[0]) is int:
		var days: int = c.get_value(stay_refs[0])
		result.append(Statement.duration(days, days, "stmt_dur_n", [days]))
		for interval: Vector2i in FORMULA_INTERVALS:
			if days >= interval.x and days <= interval.y:
				result.append(Statement.duration(interval.x, interval.y))
		var corrected: Statement = Statement.duration(days, days)
		corrected.corrected_from = "stmt_dur_w1"
		result.append(corrected)
		result.append(Statement.vague_answer(Statement.ID_STAY))
	var ids: Dictionary[StringName, StringName] = {
		Statement.PATH_PURPOSE: Statement.ID_PURPOSE,
		Statement.PATH_EMPLOYER: Statement.ID_EMPLOYER,
		Statement.PATH_ORIGIN: Statement.ID_ORIGIN,
	}
	for path: StringName in ids:
		var refs: Array[FieldRef] = c.find_refs_by_truth_path(path)
		if refs.is_empty() or c.get_value(refs[0]) == null:
			continue
		var value: Variant = c.get_value(refs[0])
		result.append(Statement.make(ids[path], value))
		if value is String:
			# Variante orale : casse et accents perdus.
			result.append(Statement.make(ids[path], Statement.normalize_text(str(value)).to_upper()))
	result.append(Statement.make(Statement.ID_PROVENANCE, &"drv"))
	return result


func test_fragments_frames_and_segments() -> void:
	var purpose: Statement = Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_TRADE, "stmt_purpose_trade_1")
	var stay: Statement = Statement.duration(5, 5, "stmt_dur_d5")
	var statements: Array[Statement] = [purpose, stay]
	assert_eq(Statement.compose(_t("line_stmt_frame_gen_1"), statements, _t), "Le commerce. Cinq jours.")
	var corrected: Statement = Statement.duration(10, 10, "stmt_dur_d10")
	corrected.corrected_from = "stmt_dur_w1"
	assert_eq(Statement.compose(_t("line_stmt_frame_correct_1"), [purpose, corrected] as Array[Statement], _t),
			"Le commerce. Une semaine… non, dix jours.")
	var employer: Statement = Statement.make(Statement.ID_EMPLOYER, "Kessler-Ashe Orbital", "stmt_employer",
			["Kessler-Ashe"])
	assert_eq(employer.fragment_text(_t), "chez Kessler-Ashe", "jeton {…} remplacé")
	assert_eq(Statement.duration(12, 12, "stmt_dur_n", [12]).fragment_text(_t), "12 jours", "formatage %d")
	assert_eq(Statement.make(Statement.ID_HOST, "Tomás", "stmt_host_son", ["Tomás"]).fragment_text(_t), "mon fils, Tomás")
	assert_eq(Statement.compose(_t("line_stmt_frame_work_1"), statements, _t), "Le commerce, . Cinq jours.",
			"emplacement sans déclaration : vide")
	var segments: Array[Dictionary] = Statement.segments("{motif}. {duree_barree}… non, {duree}. {inconnu}")
	assert_eq(segments[0], {"statement": Statement.ID_PURPOSE, "struck": false, "sentence_start": true})
	assert_eq(segments[1], {"text": ". "})
	assert_eq(segments[2], {"statement": Statement.ID_STAY, "struck": true, "sentence_start": true})
	assert_eq(segments[4], {"statement": Statement.ID_STAY, "struck": false, "sentence_start": false})
	assert_eq(segments[segments.size() - 1], {"text": "{inconnu}"}, "jeton inconnu gardé en texte")
	assert_eq(Statement.ids_for_question(Statement.QUESTION_PURPOSE),
			[Statement.ID_PURPOSE, Statement.ID_STAY, Statement.ID_EMPLOYER, Statement.ID_HOST] as Array[StringName])


## Finition M13 : casse des fragments selon leur place dans la phrase.
func test_fragment_case_follows_the_sentence() -> void:
	var purpose: Statement = Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_TRADE, "stmt_purpose_trade_1")
	var stay: Statement = Statement.duration(5, 5, "stmt_dur_d5")
	var statements: Array[Statement] = [purpose, stay]
	var tr: Callable = func(key: String) -> String: return UiText.t(key)
	assert_eq(Statement.compose(tr.call("line_stmt_frame_gen_2"), statements, tr),
			"Le commerce, pour cinq jours. C'est écrit sur le permis.", "minuscule en milieu de phrase")
	assert_eq(Statement.compose(tr.call("line_stmt_frame_gen_3"), statements, tr), "Euh… le commerce. Cinq jours, normalement.")
	assert_eq(Statement.compose(tr.call("line_stmt_frame_tyc_2"), statements, tr),
			"‹Esh ta.› Le commerce. Cinq jours. On ne demande pas plus, chez nous.", "après une phrase tessar")
	var host: Statement = Statement.make(Statement.ID_HOST, "Tomás", "stmt_host_son", ["Tomás"])
	var visit: Statement = Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_FAMILY_VISIT, "stmt_purpose_family_visit_1")
	assert_eq(Statement.compose(tr.call("line_stmt_frame_visit_2"), [host, visit, stay] as Array[Statement], tr),
			"Mon fils, Tomás. Voir ma famille. Cinq jours, pas plus.", "majuscule en début de phrase")
	assert_eq(Statement.compose(tr.call("line_stmt_frame_visit_1"), [host, visit, stay] as Array[Statement], tr),
			"Voir ma famille : mon fils, Tomás. Cinq jours.", "deux-points : minuscule")
	var origin: Statement = Statement.make(Statement.ID_ORIGIN, &"tyc", "stmt_origin_tyc")
	var provenance: Statement = Statement.make(Statement.ID_PROVENANCE, &"shuttle", "stmt_prov_place", ["Cérès"])
	assert_eq(Statement.compose(tr.call("line_stmt_origin_3"), [origin, provenance] as Array[Statement], tr),
			"J'arrive de Cérès. Mais je suis de Tycho, oui.", "les noms propres des arguments gardent leur casse")
	assert_eq(Statement.apply_case("PH-2 calibré", false), "PH-2 calibré", "sigle intact")
	assert_eq(Statement.apply_case("%s jours", true), "%s jours", "gabarit qui commence par un argument")
	assert_eq(Statement.duration(12, 12).cased_fragment_text(tr, false), "12", "valeur brute")


func test_case_statement_helpers() -> void:
	var c: Case = CaseFactory.valid_case()
	c.statements = [Statement.duration(30, 30), Statement.make(Statement.ID_ORIGIN, &"tyc"),
			Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_WORK)] as Array[Statement]
	var for_purpose: Array[Statement] = c.statements_for_question(Statement.QUESTION_PURPOSE)
	assert_eq(for_purpose.size(), 2)
	assert_eq(for_purpose[0].id, Statement.ID_PURPOSE, "ordre de IDS_BY_QUESTION")
	assert_eq(c.statements_for_question(Statement.QUESTION_ORIGIN).size(), 1)
	assert_false(c.is_statement_given(Statement.ID_STAY))
	c.get_statement(Statement.ID_STAY).given = true
	assert_true(c.is_statement_given(Statement.ID_STAY))
	assert_eq(c.get_statement_by_ref(FieldRef.statement(&"origin")).value, &"tyc")
	assert_null(c.get_statement_by_ref(FieldRef.new(&"entry_permit", &"purpose")))
	assert_null(c.get_statement(Statement.ID_HOST))


# --- FieldRef ---------------------------------------------------------------------

func test_m13_pseudo_documents() -> void:
	var chip: FieldRef = FieldRef.statement(Statement.ID_STAY)
	assert_true(chip.is_statement())
	assert_eq(chip.get_statement_id(), &"stay")
	assert_eq(chip.key(), "__statement__/stay")
	var item: FieldRef = FieldRef.scan(SearchLayout.ZONE_ARMS, 1)
	assert_true(item.is_scan())
	assert_eq(item.get_scan_zone(), &"z3")
	assert_eq(item.get_scan_index(), 1)
	assert_false(item.is_mark(), "le séparateur « : » n'en fait pas une marque")
	var entry: FieldRef = FieldRef.contraband_entry(&"oxygen")
	assert_true(entry.is_contraband_entry())
	for ref: FieldRef in [chip, item, entry]:
		assert_false(ref.is_document_field(), "%s n'est pas un champ de document" % ref.key())
		assert_false(ref.is_rule())
	assert_eq(FieldRef.new(&"entry_permit", &"purpose").get_scan_index(), -1)
	assert_eq(FieldRef.new(&"entry_permit", &"purpose").get_statement_id(), &"")


# --- Fouille ----------------------------------------------------------------------

func _layout() -> SearchLayout:
	var layout: SearchLayout = SearchLayout.new()
	layout.add(SearchLayout.ZONE_LUGGAGE, SearchItem.make(&"ol09", SearchItem.Kind.LEGIT, &"clothes"))
	layout.add(SearchLayout.ZONE_LUGGAGE, SearchItem.make(&"cb01", SearchItem.Kind.CONTRABAND, &"oxygen"))
	layout.add(SearchLayout.ZONE_ARMS, SearchItem.implant("KIN-11"))
	layout.add(SearchLayout.ZONE_TORSO, SearchItem.implant("DER-19"))
	layout.items[3].unreadable = true
	return layout


func test_search_layout_zones_items_and_refs() -> void:
	var layout: SearchLayout = _layout()
	assert_eq(layout.items_in(SearchLayout.ZONE_LUGGAGE).size(), 2)
	var cartridge: SearchItem = layout.get_item(SearchLayout.ZONE_LUGGAGE, 1)
	assert_eq(cartridge.id, &"z5:1")
	assert_eq(cartridge.name_key, "item_cb01_name")
	assert_true(cartridge.get_ref().equals(FieldRef.scan(&"z5", 1)))
	assert_eq(layout.get_item_by_ref(FieldRef.scan(&"z5", 1)), cartridge)
	assert_null(layout.get_item_by_ref(FieldRef.scan(&"z4", 0)))
	assert_eq(layout.implant_codes(), PackedStringArray(["KIN-11", "DER-19"]))
	assert_false(cartridge.revealed, "caché jusqu'au scan")
	assert_eq(layout.scan(SearchLayout.ZONE_LEGS).size(), 0, "RAS")
	assert_true(layout.is_scanned(SearchLayout.ZONE_LEGS))
	assert_eq(layout.scan(&"z9").size(), 0, "zone inconnue ignorée")
	assert_false(layout.is_scanned(&"z9"))
	assert_eq(layout.scan(SearchLayout.ZONE_LUGGAGE).size(), 2)
	assert_true(cartridge.revealed)
	assert_eq(layout.revealed_items().size(), 2)
	assert_eq(SearchLayout.zone_of_cue(SearchLayout.CUE_GLOVE), SearchLayout.ZONE_ARMS)
	assert_eq(SearchLayout.cue_line_key(SearchLayout.CUE_SATCHEL, Passenger.SEX_F), "cue_satchel_f")
	assert_eq(SearchLayout.cue_line_key(SearchLayout.CUE_SATCHEL, Passenger.SEX_M), "cue_satchel_m")
	assert_eq(SearchLayout.cue_line_key(SearchLayout.CUE_COLLAR), "cue_collar")
	var copy: SearchLayout = layout.copy()
	copy.items[0].revealed = false
	assert_true(layout.items[0].revealed, "copie profonde")


func test_revealed_forbidden_reads_only_what_was_scanned() -> void:
	var layout: SearchLayout = _layout()
	var declared: PackedStringArray = ["KIN-11"]
	assert_false(layout.revealed_forbidden(declared), "rien de révélé")
	layout.scan(SearchLayout.ZONE_ARMS)
	assert_false(layout.revealed_forbidden(declared), "implant déclaré (OL-10)")
	assert_true(layout.revealed_forbidden(PackedStringArray()), "implant non déclaré")
	layout.scan(SearchLayout.ZONE_TORSO)
	assert_false(layout.revealed_forbidden(declared), "DER-19 illisible : ne compte pas")
	layout.scan(SearchLayout.ZONE_LUGGAGE)
	assert_true(layout.revealed_forbidden(declared), "cartouche sans scellé")
	assert_false(SearchItem.make(&"cb08", SearchItem.Kind.SUBVERSIVE).is_forbidden(), "imprimé : signalement, pas R45")


func test_case_search_helpers_and_declared_implants() -> void:
	var c: Case = CaseFactory.valid_case()
	assert_false(c.search_found_forbidden(), "sans fouille")
	assert_null(c.get_scan_item(FieldRef.scan(&"z5", 0)))
	c.passenger_presented.implants = PackedStringArray(["KIN-11"])
	c.documents[0] = CaseFactory.document(CaseFactory.ID_CARD, c.passenger_presented)
	assert_eq(c.declared_implants(), PackedStringArray(["KIN-11"]), "lus sur la carte")
	c.search_layout = _layout()
	assert_false(c.is_scan_item_revealed(FieldRef.scan(&"z3", 0)))
	c.search_layout.scan(SearchLayout.ZONE_ARMS)
	assert_true(c.is_scan_item_revealed(FieldRef.scan(&"z3", 0)))
	assert_false(c.search_found_forbidden(), "KIN-11 déclaré")
	c.search_layout.scan(SearchLayout.ZONE_LUGGAGE)
	assert_true(c.search_found_forbidden())


func test_passenger_concealed_implants_is_a_copied_truth_path() -> void:
	var p: Passenger = CaseFactory.passenger()
	p.concealed_implants = PackedStringArray(["MIL-15"])
	assert_true(Passenger.has_truth_path(&"concealed_implants"))
	var copy: Passenger = p.copy()
	assert_eq(copy.concealed_implants, PackedStringArray(["MIL-15"]))
	copy.concealed_implants.append("KIN-17")
	assert_eq(p.concealed_implants.size(), 1, "copie indépendante")


# --- Coûts, améliorations, intercom -----------------------------------------------

func test_interrogation_timing_defaults_follow_m13() -> void:
	var timing: InterrogationTiming = InterrogationTiming.new()
	assert_eq(timing.question_cost(false), 3.0)
	assert_eq(timing.question_cost(true), 2.0, "AG-01")
	assert_eq(timing.question_cost(false, false, true), 4.0, "auto-correction +1 s")
	assert_eq(timing.question_cost(true, true), 2.0, "répétée : 2 s, AG-01 sans effet")
	assert_eq(timing.confront_cost(false), 4.0)
	assert_eq(timing.confront_cost(true), 3.0)
	assert_eq(timing.full_search_cost(false), 12.0, "fouille complète 12 s")
	assert_eq(timing.full_search_cost(true), 6.0, "AG-03 : 6 s")
	assert_eq(timing.activation_cost(false) + 2.0 * timing.zone_cost(false), 6.0, "fouille ciblée 2 zones")
	assert_eq(timing.zone_cost_in_full_scan(false), 2.0)
	var economy: EconomyDef = EconomyDef.new()
	assert_not_null(economy.get_interrogation_timing(), "valeurs par défaut sans données")
	assert_eq(economy.upgrades_per_evening, 1)
	assert_eq(economy.shop_open_evening, 5)


func _upgrade(id: StringName, price: int, first: int, last: int) -> UpgradeDef:
	var def: UpgradeDef = UpgradeDef.new()
	def.id = id
	def.price = price
	def.first_evening = first
	def.last_evening = last
	return def


func test_upgrade_def_flags_window_condition_and_drawer() -> void:
	var hygiaphone: UpgradeDef = _upgrade(UpgradeDef.ID_HYGIAPHONE, 20, 5, 29)
	var flags: Dictionary[StringName, Variant] = {}
	assert_eq(hygiaphone.owned_flag(), &"upg_ag01")
	assert_false(hygiaphone.is_offered(4, flags), "avant le J5")
	assert_true(hygiaphone.is_offered(5, flags))
	assert_true(hygiaphone.is_new(5))
	assert_false(hygiaphone.is_offered(30, flags), "après le J29")
	assert_false(hygiaphone.can_buy(6, flags, 19), "pas de découvert")
	assert_true(hygiaphone.can_buy(6, flags, 20))
	flags[&"upg_ag01"] = true
	assert_true(hygiaphone.is_owned(flags))
	assert_false(hygiaphone.is_offered(6, flags), "déjà acquise")
	var book: UpgradeDef = _upgrade(UpgradeDef.ID_ANNOTATED_BOOK, 10, 6, 8)
	book.condition = FlagCondition.make([], [&"okonkwo_gone"])
	assert_true(book.is_offered(7, flags))
	assert_false(book.is_offered(7, {&"okonkwo_gone": true} as Dictionary[StringName, Variant]), "Okonkwo absent")
	var drawer: Dictionary[StringName, Variant] = {&"upg_ag04": true}
	assert_true(UpgradeDef.owns(drawer, UpgradeDef.ID_DOUBLE_DRAWER))
	drawer[UpgradeDef.FLAG_DRAWER_FOUND] = true
	assert_false(UpgradeDef.owns(drawer, UpgradeDef.ID_DOUBLE_DRAWER), "tiroir confisqué")
	var gate: UpgradeDef = _upgrade(UpgradeDef.ID_CALIBRATED_GATE, 20, 9, 29)
	gate.effects = {UpgradeDef.EFFECT_SUSPICION_ON_FOUND: 1} as Dictionary[StringName, Variant]
	assert_eq(gate.get_effect(UpgradeDef.EFFECT_SUSPICION_ON_FOUND, 0), 1)
	assert_eq(gate.get_effect(UpgradeDef.EFFECT_AUDIT_PENALTY, 2), 2)
	var economy: EconomyDef = EconomyDef.new()
	economy.upgrades = [hygiaphone, gate] as Array[UpgradeDef]
	assert_eq(economy.get_upgrade(&"ag03"), gate)
	assert_null(economy.get_upgrade(&"ag06"))


func test_game_state_reads_upgrades_from_flags() -> void:
	var saved: Dictionary[StringName, Variant] = GameState.narrative_flags.duplicate()
	GameState.narrative_flags = {&"upg_ag03": true, &"upg_ag05": true} as Dictionary[StringName, Variant]
	assert_true(GameState.has_upgrade(UpgradeDef.ID_CALIBRATED_GATE))
	assert_false(GameState.has_upgrade(UpgradeDef.ID_HYGIAPHONE))
	assert_eq(GameState.owned_upgrades([&"ag01", &"ag03", &"ag05"] as Array[StringName]), [&"ag03", &"ag05"] as Array[StringName])
	GameState.narrative_flags = saved


func _on_spoke(speaker: String, text_key: String) -> void:
	spoken.append([speaker, text_key])


func test_intercom_lines_are_data_driven() -> void:
	spoken.clear()
	var intercom: OkonkwoIntercom = OkonkwoIntercom.new()
	intercom.use_game_state = false
	add_child_autofree(intercom)
	intercom.spoke.connect(_on_spoke)
	var day: DayDef = DayDef.new()
	day.day_number = 12
	var sato: IntercomLineDef = IntercomLineDef.make("sato_j12_employer", IntercomLineDef.TRIGGER_STATEMENT_GIVEN,
			Statement.ID_EMPLOYER, "spk_sato")
	var zeal: IntercomLineDef = IntercomLineDef.make("okonkwo_j8_search_nomotive", IntercomLineDef.TRIGGER_SEARCH_OPENED,
			IntercomLineDef.ARG_NO_MOTIVE)
	var missed: IntercomLineDef = IntercomLineDef.make("okonkwo_j4_statement_missed", IntercomLineDef.TRIGGER_CASE_RESOLVED,
			&"sc_104:approve")
	var gated: IntercomLineDef = IntercomLineDef.make("gated", IntercomLineDef.TRIGGER_STATEMENT_PINNED)
	gated.condition = FlagCondition.make([&"never_set"])
	day.intercom_lines = [sato, zeal, missed, gated] as Array[IntercomLineDef]
	EventBus.day_started.emit(day, [] as Array[RulebookEntry])
	assert_false(intercom.active, "le tutoriel du J1 reste au J1")
	EventBus.statement_given.emit(&"c1", [Statement.make(Statement.ID_PURPOSE, &"work")] as Array[Statement])
	assert_eq(spoken.size(), 0, "pas de puce employeur")
	EventBus.statement_given.emit(&"c1", [Statement.make(Statement.ID_EMPLOYER, "Ondine")] as Array[Statement])
	EventBus.statement_given.emit(&"c2", [Statement.make(Statement.ID_EMPLOYER, "Ondine")] as Array[Statement])
	assert_eq(spoken, [["spk_sato", "sato_j12_employer"]], "une fois par shift")
	EventBus.search_opened.emit(&"c2", SearchLayout.MOTIVE_CUE)
	assert_eq(spoken.size(), 1, "fouille avec motif")
	EventBus.search_opened.emit(&"c2", SearchLayout.MOTIVE_NONE)
	assert_eq(spoken[1], ["spk_okonkwo", "okonkwo_j8_search_nomotive"])
	var result: CaseResult = CaseResult.new(&"c3")
	result.scripted_id = &"sc_104"
	result.verdict_kind = VerdictKind.Kind.DENY
	EventBus.case_resolved.emit(&"c3", result)
	assert_eq(spoken.size(), 2, "refusé : rien")
	result.verdict_kind = VerdictKind.Kind.APPROVE
	EventBus.case_resolved.emit(&"c3", result)
	assert_eq(spoken[2][1], "okonkwo_j4_statement_missed")
	assert_eq(intercom.fire(IntercomLineDef.TRIGGER_STATEMENT_PINNED), 0, "condition fausse")
	assert_true(IntercomLineDef.make("x", IntercomLineDef.TRIGGER_CASE_RESOLVED, &"sc_104").matches(
			IntercomLineDef.TRIGGER_CASE_RESOLVED, &"sc_104:deny"), "argument sans verdict : tout verdict")


# --- Résumé, sérialisation, déterminisme ------------------------------------------

func test_day_summary_counts_searches_and_statement_mismatches() -> void:
	var summary: DaySummary = DaySummary.new()
	var plain: CaseResult = CaseResult.new(&"a")
	plain.verdict = Verdict.new(&"a")
	var searched: CaseResult = CaseResult.new(&"b")
	searched.verdict = Verdict.new(&"b")
	searched.verdict.search_done = true
	searched.verdict.search_motive = SearchLayout.MOTIVE_CUE
	var zealous: CaseResult = CaseResult.new(&"c")
	zealous.verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	zealous.verdict.search_done = true
	var pinned: Discrepancy = Discrepancy.new(FieldRef.statement(&"stay"), FieldRef.new(&"entry_permit", &"stay_days"))
	pinned.set_result(Discrepancy.Result.DISCORDANT, "disc_statement_mismatch")
	zealous.verdict.flagged = [pinned] as Array[Discrepancy]
	for result: CaseResult in [plain, searched, zealous]:
		summary.add_result(result)
	assert_eq(summary.get_search_count(), 2)
	assert_eq(summary.get_unmotivated_search_count(), 1)
	assert_eq(summary.get_statement_mismatch_count(), 1)


func test_case_serializer_v2_carries_m13_and_is_deterministic() -> void:
	var day: DayDef = Gen.data().get_day(8)
	var first: CaseBuilder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(3, 8))
	var second: CaseBuilder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(3, 8))
	for index: int in 4:
		var a: GeneratedCase = first.build(index)
		var b: GeneratedCase = second.build(index)
		assert_eq(CaseSerializer.to_json(a), CaseSerializer.to_json(b), "même graine, même cas (index %d)" % index)
	var generated: GeneratedCase = first.build(4)
	generated.case.statements = [Statement.duration(18, 24, "stmt_dur_w3"),
			Statement.vague_answer(Statement.ID_PURPOSE)] as Array[Statement]
	generated.case.statement_frames = {&"purpose": "line_stmt_frame_gen_1"} as Dictionary[StringName, String]
	generated.case.search_layout = _layout()
	generated.case.search_cues = [SearchLayout.CUE_SATCHEL] as Array[StringName]
	generated.case.cargo_reply = Case.CARGO_EVASIVE
	var parsed: Variant = JSON.parse_string(CaseSerializer.to_json(generated))
	assert_true(parsed is Dictionary)
	var root: Dictionary = parsed
	assert_eq(int(root["version"]), CaseSerializer.VERSION)
	assert_eq(CaseSerializer.VERSION, 2)
	var serialized: Dictionary = root["case"]
	var statements: Array = serialized["statements"]
	assert_eq(statements.size(), 2)
	var stay: Dictionary = statements[0]
	assert_eq(stay["value"], [18.0, 24.0], "intervalle sérialisé")
	assert_eq(serialized["statement_frames"], {"purpose": "line_stmt_frame_gen_1"})
	var layout: Dictionary = serialized["search_layout"]
	assert_eq((layout["items"] as Array).size(), 4)
	assert_eq(serialized["search_cues"], ["satchel"])
	assert_eq(serialized["cargo_reply"], "evasive")
	var passenger: Dictionary = serialized["passenger"]
	assert_true(passenger.has("concealed_implants"), "nouveau truth_path sérialisé")
	# Le même cas, re-sérialisé après une session (puce obtenue, zone scannée) :
	# l'état de session n'entre pas dans le format.
	var before: String = CaseSerializer.to_json(generated)
	generated.case.statements[0].given = true
	generated.case.search_layout.scan(SearchLayout.ZONE_LUGGAGE)
	assert_eq(CaseSerializer.to_json(generated), before)
