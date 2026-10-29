## M12 (docs/M12.md §1.5–§1.8, §3 ; B55, B56) — règles de l'épilogue R38 → R42
## sur les jours J31 réels, paramètres surchargés en cours de shift (EV-03,
## EV-07, EV-08) lus par les familles et respectés par le générateur, file
## allongée (EV-06), anomalies subtiles et exercice des directives de Garde.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
const SEEDS: int = 12

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _epi_builder(world: StringName, seed: int, flags: Array[StringName] = []) -> CaseBuilder:
	var day: DayDef = data.get_epilogue_day(world)
	var values: Dictionary[StringName, Variant] = FlagCondition.from_true_flags(flags)
	return CaseBuilder.new(data, day, SeededRng.day_seed(seed, 31), flags, CaseMemory.resolve(data, day, seed, {}), values)


func _violated(c: Case, builder: CaseBuilder) -> Array[StringName]:
	var ids: Array[StringName] = []
	for v: Violation in RuleEngine.validate(c, builder.day.rule_set, builder.ctx):
		ids.append(v.rule_id)
	return ids


## Premier passager généré propre d'une origine (sans anomalie), ou null.
func _clean_of(builder: CaseBuilder, faction_id: StringName) -> GeneratedCase:
	for i: int in builder.day.passenger_count:
		if builder.get_scripted_case(i) != null or builder.wanted_indices.has(i) or builder.revoked_indices.has(i) \
				or builder.sponsor_indices.has(i) or builder.wards.has(i):
			continue
		if builder.roster.get_entry(i).faction_id != faction_id:
			continue
		var g: GeneratedCase = builder.build_with(i, [])
		if g != null and g.key.expected_verdict == VK.APPROVE:
			return g
	return null


func test_epilogue_rules_exist_with_their_parameters() -> void:
	var r38: FactionBannedRule = data.rules[&"r_ep_tycho_ka"]
	assert_eq(r38.banned_faction_ids, [&"tyc"] as Array[StringName])
	assert_eq(r38.exempt_contract_codes, PackedStringArray(["KA"]))
	var r39: RequireDocumentRule = data.rules[&"r_ep_welcome"]
	assert_true(r39.exempt_if_sponsor)
	assert_eq(r39.document_id, &"entry_permit")
	var r40: RevokedIdRule = data.rules[&"r_ep_council_list"]
	assert_true(r40.honor_reinstatements)
	assert_eq(r40.list_title_key, "rb_tab_council")
	var r41: IssuerAllowedRule = data.rules[&"r_ep_issuer_tycho"]
	assert_eq(r41.allowed_issuer_ids, [&"clinique_meridian", &"dispensaire_tycho"] as Array[StringName])
	var r42: ContractSuspendedRule = data.rules[&"r_ep_ka_cadres"]
	assert_true(r42.any_origin)
	assert_eq(r42.classes, [&"C-1", &"C-2"] as Array[StringName])
	for rule_id: StringName in [&"r_ep_tycho_ka", &"r_ep_welcome", &"r_ep_council_list", &"r_ep_issuer_tycho", &"r_ep_ka_cadres"]:
		assert_eq((data.rules[rule_id] as Rule).severity, 2, String(rule_id))
	# Les règles de campagne gardent leur comportement (paramètres par défaut).
	assert_true((data.rules[&"r_tycho_closed"] as FactionBannedRule).exempt_contract_codes.is_empty())
	assert_false((data.rules[&"r_tycho_lockout"] as ContractSuspendedRule).any_origin)
	assert_false((data.rules[&"r_revoked_ids"] as RevokedIdRule).honor_reinstatements)


## R38 : un ressortissant de Tycho en règle porte un contrat CT-KA valide ; un
## autre code ou un contrat expiré le fait refuser ; un Né-Halcyon n'est pas visé.
func test_r38_tycho_needs_a_valid_ka_contract() -> void:
	var tested: int = 0
	for s: int in SEEDS:
		var builder: CaseBuilder = _epi_builder(&"a", 100 + s)
		var g: GeneratedCase = _clean_of(builder, &"tyc")
		if g == null:
			continue
		tested += 1
		var contract: DocumentInstance = g.case.get_own_document(&"work_contract")
		assert_not_null(contract, "contrat présent")
		if contract == null:
			continue
		assert_eq(str(PurposeConsistentRule._value(g.case, &"work_contract", &"employer_code")), "KA")
		assert_false(_violated(g.case, builder).has(&"r_ep_tycho_ka"))
		contract.expiry_date = builder.ctx.today - 1
		assert_true(_violated(g.case, builder).has(&"r_ep_tycho_ka"), "contrat expiré : refus")
		var field: StringName = AnomalyInjector.field_for(g.case, &"work_contract", &"employer_code")
		contract.expiry_date = builder.ctx.today + 30
		contract.set_value(field, "VH")
		assert_true(_violated(g.case, builder).has(&"r_ep_tycho_ka"), "autre employeur : refus")
	assert_gt(tested, 3)
	# L'injecteur BANNED_FACTION produit un TYC sans contrat KA, refusé par R38.
	var injected: int = 0
	for s: int in SEEDS:
		var builder: CaseBuilder = _epi_builder(&"a", 200 + s)
		for i: int in builder.day.passenger_count:
			if builder.get_scripted_case(i) != null or builder.roster.get_entry(i).faction_id != &"tyc":
				continue
			var g: GeneratedCase = builder.build_with(i, [K.BANNED_FACTION])
			if g.key.anomalies.size() == 1:
				injected += 1
				assert_true(g.invariant_errors.is_empty(), str(g.invariant_errors))
				assert_true(_violated(g.case, builder).has(&"r_ep_tycho_ka"))
				assert_eq(g.key.expected_verdict, VK.DENY)
			break
	assert_gt(injected, 2)


## R39 : permis **ou** répondant admis aujourd'hui (Main courante) ; SC-95
## (Yara) passe si le passager @3 a été admis, sinon refus.
func test_r39_sponsor_card_replaces_the_permit() -> void:
	for s: int in SEEDS:
		var builder: CaseBuilder = _epi_builder(&"b", 300 + s)
		var cases: Array[GeneratedCase] = []
		for i: int in 4:
			cases.append(builder.build(i))
		var sponsor: GeneratedCase = cases[3]
		assert_eq(sponsor.case.passenger_presented.faction_id, &"hal", "répondant né-Halcyon")
		assert_true(SponsorRule.is_eligible(&"hal", sponsor.case.passenger_presented.citizen_class))
		for i: int in 3:
			builder.record_verdict(cases[i].case, cases[i].key.expected_verdict)
		# @3 refusé : Yara n'a pas de répondant à la Main courante.
		var refused: GeneratedCase = builder.build(4)
		assert_eq(refused.scripted_id, &"sc_95")
		assert_true(refused.case.has_own_document(&"sponsor_card"), "carte de répondant")
		assert_false(refused.case.has_own_document(&"entry_permit"), "pas de permis")
		assert_true(_violated(refused.case, builder).has(&"r_ep_welcome"), "ni permis ni répondant admis")
		assert_eq(refused.key.expected_verdict, VK.DENY)
		builder.record_verdict(sponsor.case, VK.APPROVE)
		var admitted: GeneratedCase = builder.build(4)
		assert_eq(admitted.key.expected_verdict, VK.APPROVE, "répondant admis : Yara passe")
		# Comparaison Répondant ↔ Main courante : concordante.
		var entry: LedgerEntry = builder.get_ledger()[builder.get_ledger().size() - 1]
		var sponsor_ref: FieldRef = SponsorRule.find_sponsor_ref(admitted.case)
		assert_not_null(sponsor_ref)
		var result: Discrepancy = DiscrepancyChecker.check(admitted.case, sponsor_ref, FieldRef.ledger(entry.id), builder.ctx)
		assert_eq(result.result, Discrepancy.Result.CONCORDANT)


## R40 : Beaumont sur la Liste du Conseil (refus) ; réintégrée par le Conseil
## (date en colonne, sans R33) : admise, paire N° ID ↔ liste concordante.
func test_r40_council_list_with_reinstatement() -> void:
	var listed: CaseBuilder = _epi_builder(&"b", 400)
	var beaumont: GeneratedCase = listed.build(2)
	assert_eq(beaumont.scripted_id, &"sc_94a")
	assert_eq(beaumont.key.expected_verdict, VK.DENY)
	assert_true(_violated(beaumont.case, listed).has(&"r_ep_council_list"))
	assert_eq(listed.get_revocations().size(), 3, "1 entrée liée + 2 leurres")
	var flags: Array[StringName] = [&"sc59_beaumont_spared", &"sc81b_beaumont_passed"]
	var cleared: CaseBuilder = _epi_builder(&"b", 400, flags)
	var back: GeneratedCase = cleared.build(2)
	assert_eq(back.scripted_id, &"sc_94b")
	assert_eq(back.key.expected_verdict, VK.APPROVE)
	var entry: RevokedEntry = null
	for e: RevokedEntry in cleared.get_revocations():
		if e.case_index == 2:
			entry = e
	assert_not_null(entry)
	assert_true(entry.is_reinstated(cleared.ctx.today))
	var card: FieldRef = Rule.find_ref(back.case, &"id_card", &"citizen_id")
	var check: Discrepancy = DiscrepancyChecker.check(back.case, card, entry.get_ref(), cleared.ctx)
	assert_eq(check.result, Discrepancy.Result.CONCORDANT, "réintégrée : concordant")


## R41 : bio-scan Meridian ou Dispensaire de Tycho admis au J31-D ; tout autre
## émetteur refusé ; en campagne (R13), le Dispensaire reste refusé.
func test_r41_tycho_dispensary_is_an_allowed_issuer() -> void:
	var dispensary: int = 0
	for s: int in SEEDS:
		var builder: CaseBuilder = _epi_builder(&"d", 500 + s)
		var dmitri: GeneratedCase = builder.build(2)
		assert_eq(dmitri.scripted_id, &"sc_101")
		assert_eq(dmitri.case.get_own_document(&"bioscan").issuer_id, &"dispensaire_tycho")
		assert_eq(dmitri.key.expected_verdict, VK.APPROVE)
		for i: int in [1, 3, 5]:
			var g: GeneratedCase = builder.build_with(i, [])
			if g.case.get_own_document(&"bioscan").issuer_id == &"dispensaire_tycho":
				dispensary += 1
				assert_false(_violated(g.case, builder).has(&"r_ep_issuer_tycho"))
		var wrong: GeneratedCase = builder.build_with(1, [K.WRONG_ISSUER])
		assert_true(wrong.invariant_errors.is_empty(), str(wrong.invariant_errors))
		assert_false(wrong.case.get_own_document(&"bioscan").issuer_id in [&"clinique_meridian", &"dispensaire_tycho"])
		assert_true(_violated(wrong.case, builder).has(&"r_ep_issuer_tycho"))
	assert_gt(dispensary, 0, "bruit légitime : bio-scans du Dispensaire générés")
	var j5: CaseBuilder = CaseBuilder.new(data, data.get_day(5), SeededRng.day_seed(7, 5))
	var g5: GeneratedCase = j5.build_with(0, [])
	g5.case.get_own_document(&"bioscan").issuer_id = &"dispensaire_tycho"
	assert_true(_violated(g5.case, j5).has(&"r_bioscan_issuer"), "campagne : Meridian seule (R13)")


## R42 : contrat CT-KA d'un·e cadre (C-1, C-2) refusé quelle que soit
## l'origine ; un·e C-3 admis·e ; le générateur ne produit aucun cadre propre.
func test_r42_ka_cadres_by_class() -> void:
	var injected: int = 0
	for s: int in SEEDS * 2:
		var builder: CaseBuilder = _epi_builder(&"d", 600 + s)
		for i: int in [1, 3, 5]:
			var clean: GeneratedCase = builder.build_with(i, [])
			var contract: DocumentInstance = clean.case.get_own_document(&"work_contract")
			if contract != null:
				var code: String = str(PurposeConsistentRule._value(clean.case, &"work_contract", &"employer_code"))
				var cls: StringName = clean.case.passenger_presented.citizen_class
				assert_false(code == "KA" and cls in [&"C-1", &"C-2"], "aucun cadre KA propre")
			if contract == null:
				continue
			var g: GeneratedCase = builder.build_with(i, [K.SUSPENDED_CONTRACT])
			if g.key.anomalies.size() == 1:
				injected += 1
				assert_true(g.invariant_errors.is_empty(), str(g.invariant_errors))
				assert_true(_violated(g.case, builder).has(&"r_ep_ka_cadres"))
				var card_class: Variant = PurposeConsistentRule._value(g.case, &"id_card", &"citizen_class")
				assert_true(str(card_class) in ["C-1", "C-2"])
				var field: StringName = AnomalyInjector.field_for(g.case, &"id_card", &"citizen_class")
				g.case.get_own_document(&"id_card").set_value(field, &"C-3")
				assert_false(_violated(g.case, builder).has(&"r_ep_ka_cadres"), "technicien·ne C-3 admis·e")
	assert_gt(injected, 3)


## EV-03 : `max_age_days` = 7 pour TYC (surcharge de shift) — un bio-scan de
## 10 jours viole R12 pour un ressortissant de Tycho, pas pour un autre ; les
## cas propres générés pendant l'alerte respectent la surcharge.
func test_quarantine_override_is_read_by_r12_and_the_generator() -> void:
	var day: DayDef = data.get_day(14).make_shift_copy()
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(9, 14))
	builder.ctx.apply_changes([RuleChangeDef.override(&"r_bioscan_valid", {&"max_age_days": 7}, [&"tyc"])], &"ev_03")
	var checked_tyc: int = 0
	for i: int in day.passenger_count:
		if builder.get_scripted_case(i) != null:
			continue
		var g: GeneratedCase = builder.build_with(i, [])
		var scan: DocumentInstance = g.case.get_own_document(&"bioscan")
		if scan == null:
			continue
		if g.case.passenger_presented.faction_id == &"tyc":
			checked_tyc += 1
			assert_lt(day.game_date - scan.issue_date, 7, "cas propre : scan de moins de 7 jours")
			scan.issue_date = day.game_date - 10
			assert_true(_violated(g.case, builder).has(&"r_bioscan_valid"), "TYC : 10 jours > 7")
		else:
			scan.issue_date = day.game_date - 10
			assert_false(_violated(g.case, builder).has(&"r_bioscan_valid"), "autres origines : 30 jours")
	assert_gt(checked_tyc, 0)


## EV-08 : TRANSIT dispensé de bio-scan de 13:00 à 14:00 seulement.
func test_exemption_override_follows_purpose_and_clock() -> void:
	var day: DayDef = data.get_day(14).make_shift_copy()
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(9, 14))
	var event: StationEventDef = data.events[&"ev_08"]
	builder.ctx.apply_changes(event.changes, &"ev_08")
	var transit: GeneratedCase = null
	for i: int in day.passenger_count:
		if builder.get_scripted_case(i) != null:
			continue
		var g: GeneratedCase = builder.build_with(i, [])
		if g.case.passenger_presented.purpose == Passenger.PURPOSE_TRANSIT:
			transit = g
			break
	assert_not_null(transit, "un passager en TRANSIT")
	if transit == null:
		return
	var kept: Array[DocumentInstance] = []
	for doc: DocumentInstance in transit.case.documents:
		if doc.get_document_id() != &"bioscan":
			kept.append(doc)
	transit.case.documents = kept
	for spec: Array in [[12 * 60 + 59, true], [13 * 60, false], [13 * 60 + 59, false], [14 * 60, true], [14 * 60 + 1, true]]:
		builder.ctx.now_minute = spec[0]
		assert_eq(_violated(transit.case, builder).has(&"r_bioscan_required"), spec[1], "minute %d" % spec[0])
	# Pendant la fenêtre, le générateur peut omettre le bio-scan d'un TRANSIT.
	builder.ctx.now_minute = 13 * 60 + 20
	builder.presentation_minute = 13 * 60 + 20
	var ids: Array[StringName] = builder.required_documents_for_passenger(transit.case.passenger_presented)
	assert_false(ids.has(&"bioscan"))


## EV-07 : bulletin « Cartes volées » publié à l'ajout de la règle (liste
## nommée `stolen`) : porteurs parmi les passagers suivants, refusés (R30
## sur la liste nommée), paire N° ID ↔ bulletin discordante.
func test_stolen_ids_list_is_published_and_carried() -> void:
	var day: DayDef = data.get_day(14).make_shift_copy()
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(11, 14))
	for i: int in 3:
		builder.build(i)
	var diff: RuleDiff = builder.ctx.apply_changes((data.events[&"ev_07"] as StationEventDef).changes, &"ev_07")
	builder.on_rules_changed(diff)
	assert_true(builder.changed_lists.has("stolen"))
	var entries: Array[RevokedEntry] = builder.ctx.get_list(&"stolen")
	assert_eq(entries.size(), 3)
	var carriers: int = 0
	for entry: RevokedEntry in entries:
		if entry.case_index < 0:
			continue
		carriers += 1
		var g: GeneratedCase = builder.build(entry.case_index)
		assert_true(g.invariant_errors.is_empty(), str(g.invariant_errors))
		assert_eq(g.key.expected_verdict, VK.DENY)
		assert_true(_violated(g.case, builder).has(&"r_ev_stolen_ids"))
		var card: FieldRef = Rule.find_ref(g.case, &"id_card", &"citizen_id")
		assert_eq(DiscrepancyChecker.check(g.case, card, entry.get_ref(), builder.ctx).result, Discrepancy.Result.DISCORDANT)
	assert_between(carriers, 1, 2)


## EV-06 : la file s'allonge en cours de shift (roster étendu, tirages des
## premiers passagers inchangés).
func test_queue_extends_mid_shift() -> void:
	var day: DayDef = data.get_day(28).make_shift_copy()
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(13, 28))
	var before: String = builder.build(0).case.passenger_presented.citizen_id
	var count: int = day.passenger_count
	builder.extend_queue(count + 3)
	assert_eq(day.passenger_count, count + 3)
	assert_eq(builder.build(0).case.passenger_presented.citizen_id, before)
	for i: int in range(count, count + 3):
		var g: GeneratedCase = builder.build(i)
		assert_not_null(g)
		assert_eq(g.clean_violation_count, 0, "cas propre au-delà de la file d'origine (R37)")


## Anomalies subtiles : un seul caractère sosie, une diacritique, la veille.
func test_subtle_variants() -> void:
	var rng: SeededRng = SeededRng.new(3)
	assert_eq(IdMismatchInjector.confuse_one(rng, "HG-4123-AB5Z", [8, 9, 10, 11]).length(), 12)
	var confused: String = IdMismatchInjector.confuse_one(rng, "HG-4123-KMNP", [8, 9, 10, 11])
	assert_eq(confused, "", "aucun sosie possible")
	var accented: String = NameMismatchInjector.accent_one(rng, "Brandt")
	assert_eq(accented, "Brändt")
	assert_false(FieldValue.equals("Brandt", accented), "diacritique : discordance réelle")
	var day: DayDef = data.garde.day_template.make_shift_copy()
	day.subtle_rate = 1.0
	day.rule_set.apply_changes([RuleChangeDef.add(data.rules[&"r_permit_required"]),
			RuleChangeDef.add(data.rules[&"r_permit_valid"])], &"t")
	var builder: CaseBuilder = CaseBuilder.new(data, day, 77)
	var expired: int = 0
	for i: int in 60:
		var g: GeneratedCase = builder.build(i)
		assert_true(g.invariant_errors.is_empty(), str(g.invariant_errors))
		for anomaly: Anomaly in g.key.anomalies:
			if anomaly.type == K.EXPIRED_DOCUMENT and anomaly.document_id != &"bioscan":
				var doc: DocumentInstance = g.case.get_own_document(anomaly.document_id)
				assert_eq(doc.expiry_date, day.game_date - 1, "expiré la veille")
				expired += 1
	assert_gt(expired, 0)
