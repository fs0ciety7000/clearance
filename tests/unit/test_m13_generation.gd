## M13 « Gameplay » (docs/M13.md §1, §2, §4.1, §4.6 ; D-142 → D-149) — lot B :
## déclarations générées (zéro discordance chez un honnête), fausses
## déclarations AV-1 → AV-5, fouille (invariant « porteur ⇒ indice », indices
## des innocents et leur explication, contrebande, armes, implants
## dissimulés), règles R43 → R47 et comparateur, sur les vrais jours.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
## Passagers générés mesurés (QA M13 §4.6 : 10 000).
const PASSENGERS: int = 10_000
const SEARCH_KINDS: Array[AnomalyType.Kind] = [K.CONTRABAND, K.CONCEALED_IMPLANT, K.CONCEALED_WEAPON]

var data: DataCatalog = null
## `[builder, generated]` des passagers générés (J4 → J30).
static var _cases: Array[Array] = []


func before_all() -> void:
	data = Gen.data()
	if not _cases.is_empty():
		return
	var group: int = 0
	while _cases.size() < PASSENGERS:
		var n: int = 4 + group % 27
		var day: DayDef = data.get_day(n)
		var builder: CaseBuilder = CaseBuilder.new(data, day, Gen.day_seed(7000 + group, n))
		builder.presentation_minute = 12 * 60
		for generated: GeneratedCase in builder.build_day():
			if generated != null and generated.scripted_id == &"" and _cases.size() < PASSENGERS:
				_cases.append([builder, generated])
		group += 1


func _kinds(g: GeneratedCase) -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	for anomaly: Anomaly in g.key.anomalies:
		kinds.append(anomaly.type)
	return kinds


# ---------------------------------------------------------------------------
# Déclarations (D-142, D-143)
# ---------------------------------------------------------------------------

func test_r43_tiers_follow_the_calendar() -> void:
	var expected: Dictionary[int, int] = {3: 0, 4: 1, 11: 1, 12: 2, 13: 3, 23: 3, 24: 4, 30: 4}
	for n: int in expected:
		var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(data.get_day(n).rule_set)
		if expected[n] == 0:
			assert_null(rule, "J%d : pas de R43" % n)
			continue
		assert_not_null(rule, "J%d" % n)
		assert_eq(rule.tier, expected[n], "J%d : palier" % n)
		assert_eq(rule.rulebook_text_key, "r_statements_text_s%d" % expected[n])
		assert_eq(rule.id, &"r_statements", "même identifiant à tous les paliers")
	assert_eq(StatementsConsistentRule.active_in(data.get_day(4).rule_set).topics, [&"purpose", &"stay"] as Array[StringName])
	assert_true(data.get_day(4).rule_set.new_rule_ids.has(&"r_statements"), "NOUVEAU au J4")
	assert_true(data.get_day(24).rule_set.new_rule_ids.has(&"r_statements"), "palier s4 : NOUVEAU au J24")
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		for rule_id: StringName in [&"r_statements", &"r_search_cause", &"r_contraband", &"r_weapons_detain", &"r_belt_search"]:
			assert_false(data.get_epilogue_day(world).rule_set.has_rule(rule_id), "J31 inchangé (%s, %s)" % [world, rule_id])


func test_no_statement_discordance_for_honest_passengers() -> void:
	var failures: PackedStringArray = []
	var with_statements: int = 0
	var vague: int = 0
	var corrected: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		var c: Case = g.case
		if c.statements.is_empty():
			continue
		with_statements += 1
		var lying: bool = _kinds(g).has(K.STATEMENT_MISMATCH)
		var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(builder.day.rule_set)
		var clean: bool = g.key.anomalies.is_empty()
		for statement: Statement in c.statements:
			statement.given = true
			vague += 1 if statement.vague else 0
			corrected += 1 if statement.is_corrected() else 0
			if lying:
				continue
			var refs: Array[FieldRef] = []
			if clean:
				refs = rule.comparable_refs(c, statement)
			var primary: FieldRef = rule.primary_ref(c, statement)
			if primary != null:
				refs.append(primary)
			for ref: FieldRef in refs:
				var d: Discrepancy = DiscrepancyChecker.check(c, statement.get_ref(), ref, builder.ctx)
				if d.result == Discrepancy.Result.DISCORDANT:
					failures.append("%s %s ↔ %s (%s)" % [c.case_id, statement, ref.key(), _kinds(g)])
		if not lying and g.key.get_violated_rule_ids().has(&"r_statements"):
			failures.append("%s : R43 violée sans mensonge" % c.case_id)
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_gt(with_statements, PASSENGERS * 0.9, "déclarations générées J4+")
	assert_between(float(vague) / with_statements, 0.08, 0.16, "VN-1 ≈ 12 % des durées")
	assert_between(float(corrected) / with_statements, 0.05, 0.11, "VN-2 ≈ 8 %")


func test_each_lie_is_a_documentable_refusal() -> void:
	var specs: Array[Array] = [[4, &"purpose"], [4, &"stay"], [12, &"employer"], [13, &"origin"]]
	for spec: Array in specs:
		var n: int = spec[0]
		var topic: StringName = spec[1]
		var done: int = 0
		for s: int in 30:
			var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(9100 + s, n))
			for i: int in builder.day.passenger_count:
				if builder.get_scripted_case(i) != null or done >= 6:
					continue
				builder._probing = true
				var g: GeneratedCase = builder.build_with(i, [K.STATEMENT_MISMATCH], {&"topic": String(topic)})
				builder._probing = false
				if g == null or g.key.anomalies.size() != 1:
					continue
				done += 1
				var where: String = "J%d %s %s" % [n, topic, g.case.case_id]
				assert_eq(g.key.expected_verdict, VK.DENY, where)
				assert_eq(g.invariant_errors, PackedStringArray(), where)
				var statement: Statement = g.case.get_statement(topic)
				assert_not_null(statement, where)
				var violation: Violation = g.key.expected_violations[0]
				assert_true(violation.has_ref(FieldRef.statement(topic)), where)
				# Non obtenue : INCOMPARABLE ; obtenue : DISCORDANCE qui documente le refus.
				var before: Discrepancy = DiscrepancyChecker.check(g.case, violation.refs[0], violation.refs[1], builder.ctx)
				assert_eq(before.reason_key, Discrepancy.REASON_STATEMENT_NOT_GIVEN, where)
				statement.given = true
				var after: Discrepancy = DiscrepancyChecker.check(g.case, violation.refs[0], violation.refs[1], builder.ctx)
				assert_true(after.confirmed, where)
				assert_eq(after.reason_key, Discrepancy.REASON_STATEMENT_MISMATCH, where)
				assert_true(ScoringService.is_documented([after], g.key.expected_violations), where)
				if topic == &"stay":
					var span: Vector2i = statement.value
					var days: int = int(g.case.get_value(violation.refs[1]))
					var gap: int = maxi(4, ceili(0.4 * days))
					assert_true(span.y <= days - gap or span.x >= days + gap, "%s : AV-2 disjoint (%s, %d)" % [where, span, days])
					assert_false(statement.vague, where)
		assert_gt(done, 3, "J%d : %s injectable" % [n, topic])


func test_statement_frequencies_follow_the_balance_targets() -> void:
	var per_day: Dictionary[int, Vector2i] = {}
	for pair: Array in _cases:
		var g: GeneratedCase = pair[1]
		var n: int = (pair[0] as CaseBuilder).day.day_number
		var counts: Vector2i = per_day.get(n, Vector2i.ZERO)
		counts.x += 1
		counts.y += 1 if _kinds(g).has(K.STATEMENT_MISMATCH) else 0
		per_day[n] = counts
	var j4: float = float(per_day[4].y) / per_day[4].x
	assert_between(j4, 0.06, 0.13, "J4 : 8–11 %% visés (%.3f)" % j4)
	var later: Vector2i = Vector2i.ZERO
	for n: int in per_day:
		if n not in [4, 12, 13, 24]:
			later += per_day[n]
	var rate: float = float(later.y) / later.x
	assert_between(rate, 0.03, 0.08, "4–6 %% ensuite (%.3f)" % rate)


func test_vague_provenance_and_inactive_topics_are_incomparable() -> void:
	var seen: Dictionary[String, int] = {}
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		var card: FieldRef = Rule.find_ref(g.case, &"id_card", &"faction_id")
		var permit_stay: FieldRef = Rule.find_ref(g.case, &"entry_permit", &"stay_days")
		for statement: Statement in g.case.statements:
			statement.given = true
			var target: FieldRef = permit_stay if statement.id == Statement.ID_STAY else card
			if target == null:
				continue
			var d: Discrepancy = DiscrepancyChecker.check(g.case, statement.get_ref(), target, builder.ctx)
			if statement.vague:
				assert_eq(d.reason_key, Discrepancy.REASON_STATEMENT_VAGUE)
				seen["vague"] = seen.get("vague", 0) + 1
			elif statement.id == Statement.ID_PROVENANCE:
				assert_eq(d.reason_key, Discrepancy.REASON_PROVENANCE)
				seen["provenance"] = seen.get("provenance", 0) + 1
			var other: Discrepancy = DiscrepancyChecker.check(g.case, statement.get_ref(), FieldRef.passenger_face(), builder.ctx)
			assert_false(other.confirmed, "puce ↔ visage : jamais une discordance")
	assert_gt(seen.get("vague", 0), 50)
	assert_gt(seen.get("provenance", 0), 50)


func test_generated_answers_fit_ninety_characters() -> void:
	var too_long: PackedStringArray = []
	var translate: Callable = func(key: String) -> String: return UiText.t(key)
	var checked: int = 0
	for pair: Array in _cases:
		var g: GeneratedCase = pair[1]
		for question: StringName in g.case.statement_frames:
			var frame: String = g.case.statement_frames[question]
			assert_true(UiText.has(frame), frame)
			var text: String = Statement.compose(UiText.t(frame), g.case.statements, translate)
			checked += 1
			if text.length() > 90:
				too_long.append("%s %s : %s" % [g.case.case_id, frame, text])
			if text.count("‹") != text.count("›") or text.count("‹") > 1:
				too_long.append("%s : Tessar %s" % [g.case.case_id, text])
	assert_gt(checked, PASSENGERS)
	assert_eq(too_long.size(), 0, Gen.head(too_long))


# ---------------------------------------------------------------------------
# Fouille (D-145 → D-147)
# ---------------------------------------------------------------------------

func test_no_search_before_the_gate_and_layout_from_j8() -> void:
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		var n: int = builder.day.day_number
		if n < 8:
			assert_null(g.case.search_layout, "J%d : pas de portique" % n)
			assert_true(g.case.passenger_presented.concealed_implants.is_empty(), "J%d : aucun implant dissimulé" % n)
		else:
			assert_not_null(g.case.search_layout, "J%d : fouille générée" % n)
			assert_false(g.case.search_layout.items_in(SearchLayout.ZONE_LUGGAGE).is_empty(), "Z5 : 1 à 3 objets")


func test_every_carrier_shows_a_cue_and_innocent_cues_are_explained() -> void:
	var failures: PackedStringArray = []
	var innocents: int = 0
	var innocent_cues: int = 0
	var carriers: int = 0
	var cued: int = 0
	var carriers_cued: int = 0
	var hits: int = 0
	var evasive_innocents: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		if builder.day.day_number < 8 or g.case.search_layout == null:
			continue
		var carrier: bool = false
		for kind: AnomalyType.Kind in _kinds(g):
			carrier = carrier or SEARCH_KINDS.has(kind)
		var has_cue: bool = not g.case.search_cues.is_empty()
		cued += 1 if has_cue else 0
		if carrier:
			carriers += 1
			carriers_cued += 1 if has_cue else 0
			if not has_cue:
				failures.append("%s : porteur sans indice" % g.case.case_id)
			for anomaly: Anomaly in g.key.anomalies:
				if SEARCH_KINDS.has(anomaly.type):
					var item: SearchItem = g.case.get_scan_item(FieldRef.new(anomaly.document_id, anomaly.field_id))
					if item == null:
						failures.append("%s : objet introuvable %s" % [g.case.case_id, anomaly])
					elif has_cue and SearchLayout.zone_of_cue(g.case.search_cues[0]) == item.zone:
						hits += 1
			continue
		innocents += 1
		evasive_innocents += 1 if g.case.cargo_reply == Case.CARGO_EVASIVE else 0
		if has_cue:
			innocent_cues += 1
			var zone: StringName = SearchLayout.zone_of_cue(g.case.search_cues[0])
			if g.case.search_layout.items_in(zone).is_empty():
				failures.append("%s : indice %s sans explication" % [g.case.case_id, g.case.search_cues[0]])
		for item: SearchItem in g.case.search_layout.items:
			if item.is_forbidden():
				failures.append("%s : objet interdit chez un innocent" % g.case.case_id)
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_gt(carriers, 150, "porteurs mesurés")
	var noise: float = float(innocent_cues) / innocents
	assert_between(noise, 0.08, 0.14, "indices chez les innocents (%.3f)" % noise)
	var precision: float = float(carriers_cued) / cued
	assert_between(precision, 0.25, 0.50, "P(porteur | indice) (%.3f)" % precision)
	assert_between(float(hits) / carriers, 0.6, 0.9, "objet dans la zone de l'indice")
	assert_lt(float(evasive_innocents) / innocents, 0.07, "réponses évasives chez les innocents ≤ 5 %")


func test_search_rules_and_verdicts() -> void:
	var seen: Dictionary[AnomalyType.Kind, int] = {}
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		var kinds: Array[AnomalyType.Kind] = _kinds(g)
		for kind: AnomalyType.Kind in SEARCH_KINDS:
			if not kinds.has(kind):
				continue
			seen[kind] = seen.get(kind, 0) + 1
			var where: String = "%s %s" % [g.case.case_id, AnomalyType.name_of(kind)]
			assert_eq(g.invariant_errors, PackedStringArray(), where)
			if kind == K.CONCEALED_WEAPON:
				assert_eq(kinds.size(), 1, where + " : arme seule")
				assert_eq(g.key.expected_verdict, VK.DETAIN, where)
				assert_true(g.key.get_violated_rule_ids().has(&"r_weapons_detain"), where)
			if kind == K.CONTRABAND:
				assert_true(g.key.get_violated_rule_ids().has(&"r_contraband"), where)
			if kind == K.CONCEALED_IMPLANT:
				assert_true(g.key.get_violated_rule_ids().has(&"r_implants_declared"), where)
	for kind: AnomalyType.Kind in SEARCH_KINDS:
		assert_gt(seen.get(kind, 0), 20, AnomalyType.name_of(kind))
	# La preuve se lit après le scan : objet ↔ règle.
	var checked: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		if g.case.search_layout == null:
			continue
		var copy: SearchLayout = g.case.search_layout.copy()
		for item: SearchItem in copy.items:
			item.revealed = false
		var saved: SearchLayout = g.case.search_layout
		g.case.search_layout = copy
		for violation: Violation in g.key.expected_violations:
			if not violation.refs[0].is_scan():
				continue
			checked += 1
			var where: String = "%s %s" % [g.case.case_id, violation.rule_id]
			if not copy.is_scanned(violation.refs[0].get_scan_zone()):
				assert_false(DiscrepancyChecker.check(g.case, violation.refs[0], violation.refs[1], builder.ctx).confirmed,
						where + " : objet non révélé")
			copy.scan(violation.refs[0].get_scan_zone())
			assert_true(DiscrepancyChecker.check(g.case, violation.refs[0], violation.refs[1], builder.ctx).confirmed,
					where + " : objet révélé")
		g.case.search_layout = saved
	assert_gt(checked, 60)


func test_hidden_declared_implants_are_never_compared_to_the_face() -> void:
	var hidden: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var g: GeneratedCase = pair[1]
		if g.case.passenger_presented.concealed_implants.is_empty() or not g.key.anomalies.is_empty():
			continue
		var card: FieldRef = Rule.find_ref(g.case, &"id_card", &"implants")
		if card == null:
			continue
		hidden += 1
		var d: Discrepancy = DiscrepancyChecker.check(g.case, FieldRef.passenger_face(), card, builder.ctx)
		assert_eq(d.result, Discrepancy.Result.CONCORDANT, "%s : « non visible — fouille »" % g.case.case_id)
		for item: SearchItem in g.case.search_layout.items:
			if item.is_implant():
				g.case.search_layout.scan(item.zone)
				assert_eq(DiscrepancyChecker.check(g.case, item.get_ref(), card, builder.ctx).result,
						Discrepancy.Result.CONCORDANT, "%s : implant trouvé déclaré" % g.case.case_id)
	assert_gt(hidden, 100, "implants dissimulés déclarés mesurés")


func test_contraband_entry_and_twins() -> void:
	var catalog: SearchCatalogDef = data.search_catalog
	assert_not_null(catalog)
	var c: Case = Case.new()
	c.passenger_presented = Passenger.new()
	c.search_layout = SearchLayout.new()
	var sealed: SearchItem = c.search_layout.add(&"z2", catalog.get_item(&"ol04").instantiate())
	var unsealed: SearchItem = c.search_layout.add(&"z2", catalog.get_item(&"cb01").instantiate(6))
	var blade: SearchItem = c.search_layout.add(&"z3", catalog.get_item(&"cb06").instantiate())
	c.search_layout.scan(&"z2")
	c.search_layout.scan(&"z3")
	var ctx: RuleContext = data.make_context(9)
	var entry: FieldRef = FieldRef.contraband_entry(&"oxygen")
	assert_eq(DiscrepancyChecker.check(c, unsealed.get_ref(), entry, ctx).reason_key, Discrepancy.REASON_CONTRABAND)
	assert_eq(DiscrepancyChecker.check(c, sealed.get_ref(), entry, ctx).reason_key, Discrepancy.REASON_ITEM_ALLOWED)
	assert_eq(DiscrepancyChecker.check(c, blade.get_ref(), FieldRef.contraband_entry(&"blade"), ctx).reason_key,
			Discrepancy.REASON_WEAPON)
	assert_eq(DiscrepancyChecker.check(c, unsealed.get_ref(), FieldRef.rulebook_rule(&"r_contraband"), ctx).result,
			Discrepancy.Result.DISCORDANT)
	assert_eq(DiscrepancyChecker.check(c, sealed.get_ref(), FieldRef.rulebook_rule(&"r_contraband"), ctx).result,
			Discrepancy.Result.CONCORDANT)
	assert_eq(DiscrepancyChecker.check(c, blade.get_ref(), FieldRef.rulebook_rule(&"r_contraband"), ctx).result,
			Discrepancy.Result.INCOMPARABLE, "une arme relève de R46")
	var violations: Array[Violation] = RuleEngine.validate(c, ctx.rule_set, ctx)
	var ids: Array[StringName] = []
	for violation: Violation in violations:
		ids.append(violation.rule_id)
	assert_true(ids.has(&"r_contraband") and ids.has(&"r_weapons_detain"))
	assert_eq(RuleEngine.expected_verdict(violations), VK.DETAIN, "R46 : DÉTENTION")
	assert_eq(catalog.get_item(&"ol04").twin_id, &"cb01", "paire presque identique (Garde)")


func test_carriers_never_with_wanted_or_revoked_and_statement_pairs() -> void:
	for pair: Array in _cases:
		var g: GeneratedCase = pair[1]
		var kinds: Array[AnomalyType.Kind] = _kinds(g)
		if kinds.has(K.STATEMENT_MISMATCH) or kinds.has(K.CONTRABAND) or kinds.has(K.CONCEALED_IMPLANT):
			assert_lte(kinds.size(), 2, "%s : 0 ou 1 autre anomalie" % g.case.case_id)
			assert_false(kinds.has(K.WANTED_PERSON) or kinds.has(K.REVOKED_ID), g.case.case_id)
		var lies: int = 0
		for statement_kind: AnomalyType.Kind in kinds:
			lies += 1 if statement_kind == K.STATEMENT_MISMATCH else 0
		assert_lte(lies, 1, "au plus une fausse déclaration")


func test_generation_is_deterministic() -> void:
	for n: int in [4, 9, 19, 24]:
		var a: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(55, n))
		var b: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(55, n))
		for i: int in data.get_day(n).passenger_count:
			var ca: Case = a.build(i).case
			var cb: Case = b.build(i).case
			assert_eq(JSON.stringify(CaseSerializer.serialize_case(ca)), JSON.stringify(CaseSerializer.serialize_case(cb)), "J%d @%d" % [n, i])
