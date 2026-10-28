## Validation des données (ARCHITECTURE §12) : toutes les ressources de
## `res://data/` se chargent et sont cohérentes entre elles.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DS_SCRIPT: GDScript = preload("res://ui/theme/tokens.gd")

var _catalog: DataCatalog


func before_all() -> void:
	_catalog = DataCatalog.load_from()


func test_all_resources_load_without_error() -> void:
	assert_eq(_catalog.errors, PackedStringArray(), "erreurs de chargement / doublons")
	assert_gt(_catalog.paths.size(), 0)
	for path: String in DataCatalog.list_resource_paths(DataCatalog.DATA_ROOT):
		assert_not_null(load(path), path)


func test_expected_content_counts() -> void:
	assert_eq(_catalog.documents.size(), 4, "Carte, Permis, Bio-scan, Dérogation MIL (M7)")
	assert_eq(_catalog.factions.keys().size(), 6, "origines : TYC, HAL, TER + CER, THR, DRV (M7)")
	assert_eq(_catalog.rules.size(), 22, "R01–R22 (GDD §7)")
	assert_eq(_catalog.days.keys().size(), 10)
	for document_id: StringName in [&"id_card", &"entry_permit", &"bioscan", &"mil_waiver"]:
		assert_true(_catalog.documents.has(document_id), String(document_id))
	for faction_id: StringName in [&"tyc", &"hal", &"ter", &"cer", &"thr", &"drv"]:
		assert_true(_catalog.factions.has(faction_id), String(faction_id))


func test_factions() -> void:
	var codes: Array[String] = []
	var prefixes: Array[String] = []
	for faction: FactionDef in _catalog.factions.values():
		assert_eq(faction.code.length(), 3, String(faction.id))
		assert_eq(faction.code, faction.code.to_upper(), String(faction.id))
		assert_true(faction.id_prefix.begins_with("HG-") and faction.get_id_block_digit() >= 0, faction.id_prefix)
		assert_false(faction.name_key.is_empty(), String(faction.id))
		assert_gt(faction.origin_sectors.size(), 0, String(faction.id))
		assert_false(codes.has(faction.code), "code en double " + faction.code)
		assert_false(prefixes.has(faction.id_prefix), "préfixe en double " + faction.id_prefix)
		codes.append(faction.code)
		prefixes.append(faction.id_prefix)
	# LORE §5 : HAL 1, TER 2, TYC 4, CER 6, THR 7, DRV 9.
	assert_eq(_catalog.factions[&"cer"].get_id_block_digit(), 6)
	assert_eq(_catalog.factions[&"thr"].get_id_block_digit(), 7)
	assert_eq(_catalog.factions[&"drv"].get_id_block_digit(), 9)
	assert_eq(_catalog.factions[&"hal"].get_id_block_digit(), 1)
	assert_eq(_catalog.factions[&"ter"].get_id_block_digit(), 2)
	assert_eq(_catalog.factions[&"tyc"].get_id_block_digit(), 4)


func test_documents() -> void:
	var tokens: Dictionary = DS_SCRIPT.get_script_constant_map()
	for doc: DocumentTypeDef in _catalog.documents.values():
		var label: String = String(doc.id)
		assert_false(doc.title_key.is_empty(), label)
		assert_true(doc.validity_days.x > 0 and doc.validity_days.x <= doc.validity_days.y, label + " validity_days")
		assert_true(tokens.has(String(doc.holo_tint_token)), label + " holo_tint_token absent de DS")
		assert_false(doc.issuer_id == &"" or doc.seal_id == &"" or doc.serial_pattern.is_empty(), label)
		assert_gt(doc.fields.size(), 0, label)
		var ids: Array[StringName] = []
		var orders: Array[int] = []
		for field: FieldDef in doc.fields:
			assert_not_null(field, label)
			var where: String = "%s.%s" % [doc.id, field.id]
			assert_false(field.id == &"" or ids.has(field.id), where + " id vide ou en double")
			assert_false(orders.has(field.display_order), where + " display_order en double")
			ids.append(field.id)
			orders.append(field.display_order)
			assert_false(field.label_key.is_empty(), where)
			assert_true(_truth_path_exists(field.truth_path), where + " truth_path inconnu : " + String(field.truth_path))
			if field.kind == FieldDef.FieldKind.PORTRAIT:
				assert_eq(field.truth_path, &"appearance", where)
			if field.kind == FieldDef.FieldKind.DATE:
				assert_true(_is_date_path(field.truth_path), where + " DATE sur une donnée non datée")
		assert_not_null(doc.find_field_by_truth_path(&"document.expiry_date"), label + " sans date d'expiration")


func test_rules() -> void:
	for rule: Rule in _catalog.rules.values():
		var label: String = String(rule.id)
		assert_true(String(rule.id).begins_with("r_"), label)
		assert_false(rule.title_key.is_empty() or rule.rulebook_text_key.is_empty(), label)
		assert_between(rule.severity, 1, 3, label)
		var referenced: Dictionary[StringName, Array] = rule.get_referenced_truth_paths()
		for document_id: StringName in referenced:
			assert_true(_catalog.documents.has(document_id), "%s → document inconnu %s" % [label, document_id])
			if not _catalog.documents.has(document_id):
				continue
			for path: Variant in referenced[document_id]:
				assert_not_null(_catalog.documents[document_id].find_field_by_truth_path(StringName(str(path))),
						"%s → %s n'a pas de champ %s" % [label, document_id, path])
		if rule is FieldsMatchRule:
			var match_rule: FieldsMatchRule = rule
			for path: StringName in match_rule.truth_paths:
				assert_gte(_documents_with(path), 2, "%s : %s doit figurer sur ≥ 2 documents" % [label, path])
		if rule is RequireDocumentRule or rule is ProcedureRule:
			var factions: Array[StringName] = []
			if rule is RequireDocumentRule:
				factions = (rule as RequireDocumentRule).exempt_faction_ids
			else:
				factions = (rule as ProcedureRule).applies_to_faction_ids
			for faction_id: StringName in factions:
				assert_true(_catalog.factions.has(faction_id), "%s → origine inconnue %s" % [label, faction_id])


func test_rule_sets() -> void:
	for rule_set: RuleSet in _catalog.rule_sets.values():
		var label: String = String(rule_set.id)
		assert_gt(rule_set.rules.size(), 0, label)
		var ids: Array[StringName] = []
		for rule: Rule in rule_set.rules:
			assert_not_null(rule, label + " : règle nulle")
			if rule == null:
				continue
			assert_false(ids.has(rule.id), "%s : %s en double" % [label, rule.id])
			ids.append(rule.id)
			assert_true(_catalog.rules.has(rule.id), "%s : %s hors de data/rules" % [label, rule.id])
			var shared: Rule = _catalog.rules.get(rule.id)
			assert_same(shared, rule, "%s : %s doit être la ressource partagée" % [label, rule.id])
		for new_id: StringName in rule_set.new_rule_ids:
			assert_true(ids.has(new_id), "%s : NOUVEAU %s absent du RuleSet" % [label, new_id])
		assert_eq(rule_set.required_document_ids, rule_set.compute_required_document_ids(), label + " required_document_ids")


func test_days() -> void:
	var numbers: Array[int] = []
	numbers.assign(_catalog.days.keys())
	numbers.sort()
	assert_eq(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as Array[int])
	for n: int in numbers:
		var day: DayDef = _catalog.days[n]
		var label: String = "J%d" % n
		# J1 = mardi 13.03.2187 (LORE §2, GDD §3.2).
		assert_eq(day.game_date, GameDate.from_ymd(2187, 3, 12 + n), label)
		assert_not_null(day.rule_set, label)
		if day.rule_set == null:
			continue
		assert_true(_catalog.rule_sets.has(day.rule_set.id), label + " RuleSet hors de data/days")
		assert_gt(day.rule_set.rules.size(), 0, label)
		assert_gt(day.passenger_count, 0, label)
		assert_gt(day.duration_sec, 0.0, label)
		assert_false(day.intro_text_key.is_empty(), label)
		assert_eq(day.anomaly_count_weights.size(), 4, label)
		assert_almost_eq(_sum(Array(day.anomaly_count_weights)), 1.0, 0.001, label + " anomaly_count_weights")
		for kind: AnomalyType.Kind in day.anomaly_weights:
			assert_true(AnomalyType.is_valid(kind), label)
			assert_true(day.rule_set.can_detect(kind), "%s : %s non détectable par le RuleSet" % [label, AnomalyType.name_of(kind)])
			assert_gt(day.anomaly_weights[kind], 0.0, label)
		assert_almost_eq(_sum(day.faction_weights.values()), 1.0, 0.001, label + " faction_weights")
		for faction_id: StringName in day.faction_weights:
			assert_true(_catalog.factions.has(faction_id), "%s : origine inconnue %s" % [label, faction_id])
		for rate: float in [day.visor_down_rate, day.legit_noise_rate, day.bribe_rate, day.luciole_rate]:
			assert_between(rate, 0.0, 1.0, label)
		_check_scripted_cases(day, label)


func test_days_follow_gdd_progression() -> void:
	assert_eq(_catalog.get_day(1).rule_set.get_rule_ids(), [&"r_id_card_required", &"r_id_card_valid"] as Array[StringName])
	assert_eq(_catalog.get_day(2).rule_set.get_rule_ids().size(), 3)
	assert_eq(_catalog.get_day(3).rule_set.get_rule_ids().size(), 7)
	# Liste cumulative : chaque jour contient les règles de la veille.
	for n: int in [2, 3]:
		for rule_id: StringName in _catalog.get_day(n - 1).rule_set.get_rule_ids():
			assert_true(_catalog.get_day(n).rule_set.has_rule(rule_id), "J%d garde %s" % [n, rule_id])
	assert_eq(_catalog.get_day(3).rule_set.required_document_ids, [&"id_card", &"entry_permit"] as Array[StringName])
	# M7 (GDD §9) : 10, 14, 16, 17, 19, 21, 22 règles actives de J4 à J10, cumulatives.
	var counts: Array[int] = []
	for n: int in range(4, 11):
		counts.append(_catalog.get_day(n).rule_set.get_rule_ids().size())
		for rule_id: StringName in _catalog.get_day(n - 1).rule_set.get_rule_ids():
			assert_true(_catalog.get_day(n).rule_set.has_rule(rule_id), "J%d garde %s" % [n, rule_id])
	assert_eq(counts, [10, 14, 16, 17, 19, 21, 22] as Array[int])
	assert_eq(_catalog.get_day(5).rule_set.required_document_ids, [&"id_card", &"entry_permit", &"bioscan"] as Array[StringName])
	for n: int in range(1, 11):
		var day: DayDef = _catalog.get_day(n)
		assert_eq(day.detain_enabled, n >= 7, "J%d : DÉTENTION à partir du J7" % n)
		assert_eq(day.has_evening, n < 10, "J%d : pas de soirée au J10 (D-053)" % n)
	assert_eq(_catalog.get_day(10).wanted_notices.size(), 3, "avis de recherche du J10")


func _check_scripted_cases(day: DayDef, label: String) -> void:
	var indices: Array[int] = []
	var probe: Passenger = Passenger.new()
	for scripted: ScriptedCaseDef in day.scripted_cases:
		assert_not_null(scripted, label)
		if scripted == null:
			continue
		var where: String = "%s %s" % [label, scripted.id]
		assert_false(scripted.id == &"", where)
		assert_between(scripted.at_index, 0, day.passenger_count - 1, where)
		assert_false(indices.has(scripted.at_index), where + " index en double")
		indices.append(scripted.at_index)
		for kind: AnomalyType.Kind in scripted.forced_anomalies:
			assert_true(day.rule_set.can_detect(kind), "%s : %s non détectable" % [where, AnomalyType.name_of(kind)])
		for key: Variant in scripted.passenger_overrides:
			var path: StringName = StringName(str(key))
			assert_true(Passenger.has_truth_path(path), "%s : surcharge inconnue %s" % [where, path])
			assert_eq(typeof(scripted.passenger_overrides[key]), typeof(probe.get(path)), "%s : type de %s" % [where, path])
		var faction: Variant = scripted.passenger_overrides.get(&"faction_id", null)
		if faction != null:
			assert_true(_catalog.factions.has(StringName(str(faction))), where)
		var citizen_id: Variant = scripted.passenger_overrides.get(&"citizen_id", null)
		if citizen_id != null and faction != null:
			var faction_def: FactionDef = _catalog.factions[StringName(str(faction))]
			assert_true(faction_def.matches_citizen_id(str(citizen_id)), where + " N° ID incohérent avec l'origine")


func _truth_path_exists(path: StringName) -> bool:
	var text: String = String(path)
	if text.begins_with(FieldDef.DOCUMENT_PATH_PREFIX):
		return DocumentInstance.has_document_property(StringName(text.trim_prefix(FieldDef.DOCUMENT_PATH_PREFIX)))
	return Passenger.has_truth_path(path) and Passenger.new().get_property_list().any(
			func(p: Dictionary) -> bool: return str(p["name"]) == String(path))


func _is_date_path(path: StringName) -> bool:
	return path in [&"birth_date", &"document.issue_date", &"document.expiry_date"]


func _documents_with(path: StringName) -> int:
	var count: int = 0
	for doc: DocumentTypeDef in _catalog.documents.values():
		if doc.find_field_by_truth_path(path) != null:
			count += 1
	return count


func _sum(values: Array) -> float:
	var total: float = 0.0
	for v: Variant in values:
		var value: float = v
		total += value
	return total
