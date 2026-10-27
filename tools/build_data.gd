## Générateur des données M2 (`res://data/**/*.tres`) — documents, origines MVP,
## règles, RuleSets et DayDef des jours 1–3 (GDD §7, §8, §10, §12 ; LORE §5, §9).
##
## Usage (depuis la racine du projet, après `godot --headless --import`) :
##   godot --headless --script res://tools/build_data.gd
##
## Pourquoi un générateur : les `.tres` contiennent des sous-ressources, des
## références partagées (une règle dans plusieurs RuleSets), des dictionnaires
## typés à clés d'enum et des dates en jours absolus : écrits à la main, ils
## sont fragiles. Le script est la source de régénération ; les UID existants
## sont conservés et les sous-ressources ont des identifiants stables pour que
## les diffs restent lisibles. Si un designer retouche un `.tres` dans
## l'inspecteur, il reporte la valeur ici (ou abandonne le script pour ce
## fichier) : le test `test_data_integrity.gd` valide le résultat dans tous les cas.
extends SceneTree

const DOCS_DIR: String = "res://data/documents"
const FACTIONS_DIR: String = "res://data/factions"
const RULES_DIR: String = "res://data/rules"
const DAYS_DIR: String = "res://data/days"

const K := AnomalyType.Kind
const FK := FieldDef.FieldKind
const CAT := Rule.RuleCategory

var _failures: int = 0


func _init() -> void:
	_build()
	print("build_data : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _build() -> void:
	_build_factions()
	var docs: Dictionary[StringName, DocumentTypeDef] = _build_documents()
	var rules: Dictionary[StringName, Rule] = _build_rules()
	var sets: Array[RuleSet] = _build_rule_sets(rules)
	_build_days(sets)
	assert(docs.size() == 3)


# ---------------------------------------------------------------------------
# Origines (MVP : TYC, HAL, TER — GDD §8.3, LORE §5)
# ---------------------------------------------------------------------------

func _build_factions() -> void:
	_save(_faction(&"tyc", "TYC", "HG-4", ["Colonie Tycho (Lune)", "Cratère Tycho — dortoirs Kessler-Ashe"]), FACTIONS_DIR, "faction_tyc")
	_save(_faction(&"hal", "HAL", "HG-1", ["Anneaux D–F", "Anneau C — logements de service", "Coursives d'Halcyon Gate"]), FACTIONS_DIR, "faction_hal")
	_save(_faction(&"ter", "TER", "HG-2", ["Terre — Concordat des Zones Sèches"]), FACTIONS_DIR, "faction_ter")


func _faction(id: StringName, code: String, prefix: String, sectors: PackedStringArray) -> FactionDef:
	var f: FactionDef = FactionDef.new()
	f.id = id
	f.name_key = "faction_%s_name" % id
	f.code = code
	f.id_prefix = prefix
	f.origin_sectors = sectors
	return f


# ---------------------------------------------------------------------------
# Documents (GDD §7, LORE §9)
# ---------------------------------------------------------------------------

func _build_documents() -> Dictionary[StringName, DocumentTypeDef]:
	var result: Dictionary[StringName, DocumentTypeDef] = {}

	var card: DocumentTypeDef = _doc(&"id_card", &"bureau_continuite", &"seal_solar_hexagon",
			"HG-#NNN-XXXX", Vector2i(1825, 3650), &"ACCENT_YELLOW")
	card.fields = [
		_field(&"portrait", FK.PORTRAIT, &"appearance"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"sex", FK.ENUM, &"sex"),
		_field(&"origin", FK.ENUM, &"faction_id"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"citizen_class", FK.ENUM, &"citizen_class"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id", false),
	]
	result[card.id] = card

	var permit: DocumentTypeDef = _doc(&"entry_permit", &"autorite_transit", &"seal_barred_ring",
			"PE-YYYY-NNNNN", Vector2i(14, 180), &"ACCENT_CYAN")
	permit.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"purpose", FK.ENUM, &"purpose"),
		_field(&"stay_days", FK.NUMBER, &"stay_days"),
		_field(&"employer", FK.TEXT, &"employer"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id", false),
	]
	result[permit.id] = permit

	var bioscan: DocumentTypeDef = _doc(&"bioscan", &"clinique_meridian", &"seal_orbit_cross",
			"BS-NNNNN", Vector2i(30, 30), &"ACCENT_CYAN")
	bioscan.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"health_status", FK.ENUM, &"health_status"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
	]
	result[bioscan.id] = bioscan

	for doc: DocumentTypeDef in result.values():
		for i: int in doc.fields.size():
			doc.fields[i].display_order = i
			doc.fields[i].resource_scene_unique_id = "field_%s" % doc.fields[i].id
		_save(doc, DOCS_DIR, "doc_%s" % doc.id)
	return result


func _doc(id: StringName, issuer: StringName, seal: StringName, pattern: String,
		validity: Vector2i, tint: StringName) -> DocumentTypeDef:
	var d: DocumentTypeDef = DocumentTypeDef.new()
	d.id = id
	d.title_key = "doc_%s_title" % id
	d.issuer_id = issuer
	d.seal_id = seal
	d.serial_pattern = pattern
	d.validity_days = validity
	d.holo_tint_token = tint
	return d


func _field(id: StringName, kind: FieldDef.FieldKind, truth_path: StringName, comparable: bool = true) -> FieldDef:
	var f: FieldDef = FieldDef.new()
	f.id = id
	f.label_key = "field_%s" % id
	f.kind = kind
	f.truth_path = truth_path
	f.comparable = comparable
	if kind == FK.DATE:
		f.format = FieldDef.DEFAULT_DATE_FORMAT
	return f


# ---------------------------------------------------------------------------
# Règles (GDD §7) : R01–R08 (MVP + R08 procédure J4), R10–R14 (J4–J5)
# ---------------------------------------------------------------------------

func _build_rules() -> Dictionary[StringName, Rule]:
	var rules: Array[Rule] = []

	var r01: RequireDocumentRule = RequireDocumentRule.new()
	r01.document_id = &"id_card"
	rules.append(_rule(r01, &"r_id_card_required", CAT.DOCUMENTS, 2))

	var r02: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r02.document_id = &"id_card"
	rules.append(_rule(r02, &"r_id_card_valid", CAT.DOCUMENTS, 2))

	var r03: PortraitMatchRule = PortraitMatchRule.new()
	rules.append(_rule(r03, &"r_portrait_match", CAT.IDENTITY, 2))

	var r04: RequireDocumentRule = RequireDocumentRule.new()
	r04.document_id = &"entry_permit"
	r04.exempt_faction_ids = [&"hal"]
	rules.append(_rule(r04, &"r_permit_required", CAT.DOCUMENTS, 2))

	var r05: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r05.document_id = &"entry_permit"
	rules.append(_rule(r05, &"r_permit_valid", CAT.DOCUMENTS, 2))

	var r06: ProcedureRule = ProcedureRule.new()
	r06.procedure_id = ProcedureRule.PROCEDURE_FACE_UNCOVERED
	rules.append(_rule(r06, &"r_face_uncovered", CAT.SPECIAL, 1))

	var r07: FieldsMatchRule = FieldsMatchRule.new()
	r07.truth_paths = [&"family_name", &"given_name", &"birth_date", &"citizen_id"]
	r07.detected_anomalies = [K.NAME_MISMATCH, K.ID_MISMATCH]
	rules.append(_rule(r07, &"r_identity_fields_match", CAT.IDENTITY, 2))

	var r08: ProcedureRule = ProcedureRule.new()
	r08.procedure_id = ProcedureRule.PROCEDURE_TYCHO_INTERVIEW
	r08.applies_to_faction_ids = [&"tyc"]
	rules.append(_rule(r08, &"r_tycho_interview", CAT.SPECIAL, 1))

	var r10: OriginIdBlockRule = OriginIdBlockRule.new()
	rules.append(_rule(r10, &"r_origin_block", CAT.IDENTITY, 2))

	var r11: RequireDocumentRule = RequireDocumentRule.new()
	r11.document_id = &"bioscan"
	rules.append(_rule(r11, &"r_bioscan_required", CAT.DOCUMENTS, 2))

	var r12: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r12.document_id = &"bioscan"
	r12.max_age_days = 30
	rules.append(_rule(r12, &"r_bioscan_valid", CAT.DOCUMENTS, 2))

	var r13: IssuerAllowedRule = IssuerAllowedRule.new()
	r13.document_id = &"bioscan"
	r13.allowed_issuer_ids = [&"clinique_meridian"]
	rules.append(_rule(r13, &"r_bioscan_issuer", CAT.DOCUMENTS, 2))

	var r14: FieldValueAllowedRule = FieldValueAllowedRule.new()
	r14.document_id = &"bioscan"
	r14.truth_path = &"health_status"
	r14.allowed_values = [Passenger.HEALTH_FIT]
	r14.detected_anomalies = [K.BIOSCAN_UNFIT]
	rules.append(_rule(r14, &"r_bioscan_fit", CAT.SPECIAL, 2))

	var result: Dictionary[StringName, Rule] = {}
	for rule: Rule in rules:
		_save(rule, RULES_DIR, "rule_%s" % String(rule.id).trim_prefix("r_"))
		result[rule.id] = rule
	return result


func _rule(rule: Rule, id: StringName, category: Rule.RuleCategory, severity: int) -> Rule:
	rule.id = id
	rule.title_key = "%s_title" % id
	rule.rulebook_text_key = "%s_text" % id
	rule.category = category
	rule.severity = severity
	return rule


# ---------------------------------------------------------------------------
# RuleSets J1–J3 (liste explicite et cumulative, GDD §8.1)
# ---------------------------------------------------------------------------

func _build_rule_sets(rules: Dictionary[StringName, Rule]) -> Array[RuleSet]:
	var new_d1: Array[StringName] = [&"r_id_card_required", &"r_id_card_valid"]
	var new_d2: Array[StringName] = [&"r_portrait_match"]
	var new_d3: Array[StringName] = [&"r_permit_required", &"r_permit_valid", &"r_face_uncovered", &"r_identity_fields_match"]
	var d1: Array[StringName] = new_d1.duplicate()
	var d2: Array[StringName] = d1.duplicate()
	d2.append_array(new_d2)
	var d3: Array[StringName] = d2.duplicate()
	d3.append_array(new_d3)
	var sets: Array[RuleSet] = [
		_rule_set(&"rs_day01", rules, d1, new_d1),
		_rule_set(&"rs_day02", rules, d2, new_d2),
		_rule_set(&"rs_day03", rules, d3, new_d3),
	]
	for i: int in sets.size():
		_save(sets[i], DAYS_DIR, "ruleset_day_%02d" % (i + 1))
	return sets


func _rule_set(id: StringName, rules: Dictionary[StringName, Rule], ids: Array[StringName], new_ids: Array[StringName]) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	rs.id = id
	for rule_id: StringName in ids:
		rs.rules.append(rules[rule_id])
	rs.new_rule_ids = new_ids.duplicate()
	rs.required_document_ids = rs.compute_required_document_ids()
	return rs


# ---------------------------------------------------------------------------
# Jours 1–3 (GDD §10) et passagers scénarisés (GDD §12)
# ---------------------------------------------------------------------------

func _build_days(sets: Array[RuleSet]) -> void:
	var mvp_factions: Dictionary[StringName, float] = {&"tyc": 0.45, &"hal": 0.25, &"ter": 0.30}

	var d1: DayDef = _day(1, sets[0], 540.0, 8, [0.55, 0.45, 0.0, 0.0],
			{K.EXPIRED_DOCUMENT: 0.6, K.MISSING_DOCUMENT: 0.4}, mvp_factions, 0.0, 0.10)
	d1.scripted_cases = [
		_scripted(&"sc_01", 0, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN,
				&"origin_sector": "Anneau C — logements de service"}, [], &"sc01_returning_technician"),
		_scripted(&"sc_02", 1, {&"faction_id": &"ter", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4"},
				[K.EXPIRED_DOCUMENT], &"sc02_hurried_mother"),
		_scripted(&"tuto_concordant", 2, {}, [], &""),
		_scripted(&"tuto_missing_document", 3, {}, [K.MISSING_DOCUMENT], &""),
	]

	var d2: DayDef = _day(2, sets[1], 570.0, 10, [0.50, 0.45, 0.05, 0.0],
			{K.EXPIRED_DOCUMENT: 0.4, K.MISSING_DOCUMENT: 0.2, K.PORTRAIT_MISMATCH: 0.4}, mvp_factions, 0.0, 0.15)
	d2.scripted_cases = [
		_scripted(&"sc_03", 3, {&"faction_id": &"tyc", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
				&"purpose": Passenger.PURPOSE_WORK}, [K.PORTRAIT_MISMATCH], &"sc03_nervous_miner"),
	]

	var d3: DayDef = _day(3, sets[2], 600.0, 11, [0.45, 0.45, 0.10, 0.0],
			{K.EXPIRED_DOCUMENT: 0.25, K.MISSING_DOCUMENT: 0.15, K.PORTRAIT_MISMATCH: 0.2,
			K.ID_MISMATCH: 0.2, K.NAME_MISMATCH: 0.2}, mvp_factions, 0.15, 0.20)
	var mira: ScriptedCaseDef = _scripted(&"sc_04", 2, {
		&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
		&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc",
		&"citizen_id": "HG-4471-K2Q9", &"citizen_class": &"C-3",
		&"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital",
	}, [], &"sc04_mira")
	mira.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: &"visor_down"}
	mira.sets_flag = &"met_mira"
	var messenger: ScriptedCaseDef = _scripted(&"sc_05", 7, {&"faction_id": &"tyc", &"citizen_class": &"C-3"},
			[K.ID_MISMATCH], &"sc05_luciole_messenger")
	messenger.sets_flag = &"lucioles_contact"
	d3.scripted_cases = [mira, messenger]

	for day: DayDef in [d1, d2, d3]:
		for scripted: ScriptedCaseDef in day.scripted_cases:
			scripted.resource_scene_unique_id = "scripted_%s" % scripted.id
		_save(day, DAYS_DIR, "day_%02d" % day.day_number)


func _day(n: int, rule_set: RuleSet, duration: float, count: int, count_weights: Array[float],
		weights: Dictionary[AnomalyType.Kind, float], factions: Dictionary[StringName, float], visor: float, noise: float) -> DayDef:
	var d: DayDef = DayDef.new()
	d.day_number = n
	d.game_date = GameDate.from_ymd(2187, 3, 12 + n)
	d.rule_set = rule_set
	d.duration_sec = duration
	d.passenger_count = count
	d.anomaly_count_weights = PackedFloat32Array(count_weights)
	d.anomaly_weights = weights.duplicate()
	d.intro_text_key = "day%02d_intro" % n
	d.credit_per_correct = 5
	d.penalty_per_error = 5
	d.faction_weights = factions.duplicate()
	d.visor_down_rate = visor
	d.legit_noise_rate = noise
	d.bribe_rate = 0.0
	d.luciole_rate = 0.0
	d.free_citations_per_day = 2
	d.penalty_escalated = 10
	return d


func _scripted(id: StringName, index: int, overrides: Dictionary, anomalies: Array[AnomalyType.Kind],
		dialogue: StringName) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = ScriptedCaseDef.new()
	s.id = id
	s.at_index = index
	s.passenger_overrides = overrides
	s.forced_anomalies = anomalies
	s.dialogue_id = dialogue
	return s


# ---------------------------------------------------------------------------
# Sauvegarde (UID conservés, chemin pris en charge pour les références partagées)
# ---------------------------------------------------------------------------

func _save(res: Resource, dir: String, basename: String) -> void:
	var path: String = dir.path_join(basename + ".tres")
	var old_uid: int = ResourceUID.INVALID_ID
	if FileAccess.file_exists(path):
		old_uid = ResourceLoader.get_resource_uid(path)
	res.take_over_path(path)
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("build_data: échec de sauvegarde %s (%s)" % [path, error_string(err)])
		_failures += 1
		return
	# Hors éditeur, le TextResourceSaver n'écrit pas d'UID : on pose (ou on
	# conserve) celui du fichier pour des références stables (D-027).
	var uid: int = old_uid if old_uid != ResourceUID.INVALID_ID else ResourceUID.create_id_for_path(path)
	if ResourceSaver.set_uid(path, uid) != OK:
		push_error("build_data: UID non écrit pour %s" % path)
		_failures += 1
	print("  écrit %s" % path)
