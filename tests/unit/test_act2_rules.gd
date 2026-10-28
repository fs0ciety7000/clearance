## Acte II (docs/ACT2.md §2.4, §2.5, §4 ; D-077) — règles R23–R31, quota
## souple, couvre-feu, révocations, scanner partiel, nouveaux injecteurs et
## cas scénarisés SC-23 → SC-50 (verdict attendu calculé par le moteur, D-005).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
const CAMPAIGN_SEED: int = 20_871_315

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _day_ctx(day_number: int) -> RuleContext:
	var ctx: RuleContext = data.make_context(day_number)
	return ctx


## Cas valide « à la main » (CaseFactory) d'un jour de l'Acte II.
func _case(faction_id: StringName, docs: Array[StringName], on_day: int) -> Case:
	var c: Case = CaseFactory.valid_case([], faction_id, data.get_day(on_day).game_date)
	for document_id: StringName in docs:
		c.documents.append(_doc(document_id, c.passenger_presented, data.get_day(on_day).game_date))
	return c


func _doc(document_id: StringName, p: Passenger, today: int) -> DocumentInstance:
	var doc: DocumentInstance = CaseFactory.document(document_id, p, today)
	if doc.issue_date == 0:
		doc.issue_date = today - 10
		doc.expiry_date = today + 100
	return doc


func _violated(c: Case, day_number: int) -> Array[StringName]:
	var day: DayDef = data.get_day(day_number)
	return CaseFactory.violated_ids(RuleEngine.validate(c, day.rule_set, _day_ctx(day_number)))


# --- R23 : quota respiratoire souple (D-077) -----------------------------------

func test_quota_counts_non_exempt_approvals_only() -> void:
	var day: DayDef = data.get_day(11)
	var tracker: QuotaTracker = QuotaTracker.for_day(day)
	assert_true(tracker.is_active())
	assert_eq(tracker.maximum, 5)
	var worker: Case = _case(&"tyc", [&"id_card", &"entry_permit", &"bioscan"], 11)
	var native: Case = _case(&"hal", [&"id_card", &"bioscan"], 11)
	var diplomat: Case = _case(&"tyc", [&"id_card", &"entry_permit", &"bioscan"], 11)
	diplomat.get_document(&"entry_permit").set_value(&"purpose", Passenger.PURPOSE_DIPLOMATIC)
	assert_true(tracker.counts(worker))
	assert_false(tracker.counts(native), "Nés-Halcyon exemptés")
	assert_false(tracker.counts(diplomat), "motif DIPLOMATIQUE exempté")
	for i: int in 5:
		assert_false(tracker.before_verdict(worker))
		assert_false(tracker.after_verdict(worker, VK.APPROVE))
	assert_true(tracker.is_full())
	assert_false(tracker.after_verdict(worker, VK.DENY), "un refus ne compte pas")
	assert_false(tracker.after_verdict(native, VK.APPROVE), "exempté : jamais imputé")
	assert_true(tracker.before_verdict(worker))
	assert_true(tracker.after_verdict(worker, VK.APPROVE), "6ᵉ entrée : imputée")
	assert_eq(tracker.used, 6)
	assert_eq(tracker.overruns, 1)
	assert_false(QuotaTracker.for_day(data.get_day(10)).is_active(), "pas de quota à l'Acte I")


func test_soft_quota_scoring() -> void:
	var day: DayDef = data.get_day(11)
	var clean: CaseKey = CaseKey.new()
	clean.expected_verdict = VK.APPROVE
	var deny: CaseResult = ScoringService.score(Verdict.new(&"c", VK.DENY), clean, &"c", null, day, 5, true)
	assert_true(deny.correct, "quota atteint : refus correct")
	assert_true(deny.documented and deny.quota_refusal, "documenté d'office")
	assert_eq(deny.wage, 5)
	assert_eq(deny.citation_reason_key, "")
	var approve: CaseResult = ScoringService.score(Verdict.new(&"c", VK.APPROVE), clean, &"c", null, day, 5, true)
	assert_true(approve.correct, "entrée imputée : correcte")
	assert_eq(approve.wage, 0, "D-077 : 0 ₵ au-delà du quota")
	assert_eq(approve.citation_reason_key, "")
	var free: CaseResult = ScoringService.score(Verdict.new(&"c", VK.DENY), clean, &"c", null, day, 5, false)
	assert_eq(free.citation_reason_key, ScoringService.CIT_UNJUSTIFIED_DENIAL, "quota libre : refus injustifié")
	var fraud: CaseKey = CaseKey.new()
	fraud.expected_verdict = VK.DENY
	var waved: CaseResult = ScoringService.score(Verdict.new(&"c", VK.APPROVE), fraud, &"c", null, day, 5, true)
	assert_eq(waved.citation_reason_key, ScoringService.CIT_IRREGULAR_ENTRY, "un fraudeur reste une entrée irrégulière")


func test_overruns_raise_suspicion_every_third_time() -> void:
	var overrun: Array[StringName] = [CaseEffectDef.CONTEXT_OVERRUN]
	var flags: Dictionary[StringName, Variant] = {&"quota_overrun": 2}
	var third: Dictionary[StringName, Variant] = CaseConsequences.compute(null, null, VK.APPROVE, false, false, 11, flags,
			false, overrun)
	assert_eq(third[&"quota_overrun"], 3)
	assert_eq(third[&"suspicion"], 1, "3ᵉ dépassement : la Commission remarque")
	flags[&"quota_overrun"] = 0
	var first: Dictionary[StringName, Variant] = CaseConsequences.compute(null, null, VK.APPROVE, false, false, 11, flags,
			false, overrun)
	assert_false(first.has(&"suspicion"))


func test_quota_counter_pair_in_inspection_mode() -> void:
	var c: Case = _case(&"tyc", [&"id_card", &"entry_permit", &"bioscan"], 11)
	var ctx: RuleContext = _day_ctx(11)
	ctx.quota_max = 5
	ctx.quota_used = 2
	var rule_ref: FieldRef = FieldRef.rulebook_rule(&"r_air_quota")
	assert_eq(DiscrepancyChecker.check(c, FieldRef.quota_counter(), rule_ref, ctx).result, Discrepancy.Result.CONCORDANT)
	ctx.quota_used = 5
	var full: Discrepancy = DiscrepancyChecker.check(c, rule_ref, FieldRef.quota_counter(), ctx)
	assert_true(full.confirmed, "Compteur ↔ R23 : QUOTA ATTEINT")
	assert_eq(InspectionSession.family_of(full, c, ctx), InspectionSession.FAMILY_QUOTA)


# --- R24 / R25 : contrat de travail ------------------------------------------

## Violations des seules règles R24/R25 au J12 (le dossier « à la main » ne
## respecte pas l'âge apparent ni la MRZ du jeu de règles complet).
func _contract_violations(c: Case) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _violated(c, 12):
		if id == &"r_contract_required" or id == &"r_contract_consistent":
			out.append(id)
	return out


func test_contract_required_for_work_and_code_consistent() -> void:
	var c: Case = _case(&"ter", [&"id_card", &"entry_permit", &"bioscan"], 12)
	c.passenger_presented.employer_code = "KA"
	assert_true(_violated(c, 12).has(&"r_contract_required"), "motif TRAVAIL sans contrat")
	c.documents.append(_doc(&"work_contract", c.passenger_presented, data.get_day(12).game_date))
	assert_false(_contract_violations(c).size() > 0, "contrat au nom du porteur, code KA = Kessler-Ashe")
	var contract: DocumentInstance = c.get_document(&"work_contract")
	contract.set_value(&"contract_code", "MB")
	assert_eq(_contract_violations(c), [&"r_contract_consistent"] as Array[StringName], "code MB ≠ employeur")
	var ref: FieldRef = FieldRef.new(&"work_contract", &"contract_code")
	assert_true(DiscrepancyChecker.check(c, ref, FieldRef.rulebook_rule(&"r_contract_consistent"), _day_ctx(12)).confirmed)
	contract.set_value(&"contract_code", "KA")
	contract.expiry_date = data.get_day(12).game_date - 1
	assert_eq(_contract_violations(c), [&"r_contract_required"] as Array[StringName], "contrat expiré (« non expiré »)")
	c.get_document(&"entry_permit").set_value(&"purpose", Passenger.PURPOSE_FAMILY_VISIT)
	assert_eq(_contract_violations(c), [] as Array[StringName], "VISITE FAMILIALE : contrat non requis")


func test_third_party_contract_is_never_compared() -> void:
	var day: DayDef = data.get_day(12)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(CAMPAIGN_SEED, 12), [])
	var margaux: GeneratedCase = builder.build(3)
	assert_eq(margaux.scripted_id, &"sc_27")
	var contract: DocumentInstance = margaux.case.get_document(&"work_contract")
	assert_not_null(contract, "le contrat du chat est au dossier")
	assert_true(contract.third_party)
	assert_eq(str(contract.get_value(&"family_name")), "MISTIGRI")
	assert_eq(margaux.key.expected_verdict, VK.APPROVE, "SC-27 : R07 ignore le document d'un tiers")
	var card_name: FieldRef = FieldRef.new(&"id_card", &"family_name")
	var cat_name: FieldRef = FieldRef.new(&"work_contract", &"family_name")
	assert_eq(DiscrepancyChecker.check(margaux.case, card_name, cat_name, builder.ctx).result, Discrepancy.Result.INCOMPARABLE)
	assert_eq(margaux.case.find_refs_by_truth_path(&"family_name").size(), 2, "carte et bio-scan seulement")


# --- R26 : laissez-passer de dérive ------------------------------------------

func test_drift_pass_vessel_registry_and_name() -> void:
	var c: Case = _case(&"tyc", [&"id_card", &"entry_permit", &"bioscan"], 13)
	c.passenger_presented.faction_id = &"drv"
	c.passenger_presented.citizen_id = "HG-9471-K2Q9"
	c.passenger_presented.family_name = "Nadir"
	c.passenger_presented.vessel = "NADIR"
	c.passenger_presented.purpose = Passenger.PURPOSE_TRADE
	c.documents.clear()
	for id: StringName in [&"id_card", &"entry_permit", &"bioscan"]:
		c.documents.append(_doc(id, c.passenger_presented, data.get_day(13).game_date))
	assert_true(_violated(c, 13).has(&"r_drift_pass"), "Dérivant sans laissez-passer")
	c.documents.append(_doc(&"drift_pass", c.passenger_presented, data.get_day(13).game_date))
	assert_false(_violated(c, 13).has(&"r_drift_pass"), "NADIR : inscrit au Registre, nom de famille")
	var pass_doc: DocumentInstance = c.get_document(&"drift_pass")
	pass_doc.set_value(&"vessel", "SILLAGE")
	assert_true(_violated(c, 13).has(&"r_drift_pass"), "SILLAGE retiré du Registre (20.03)")
	pass_doc.set_value(&"vessel", "VARECH")
	assert_true(_violated(c, 13).has(&"r_drift_pass"), "vaisseau ≠ nom de famille")


# --- R27 : firmware NX --------------------------------------------------------

func test_nx_firmware_older_than_ninety_days() -> void:
	var today: int = data.get_day(14).game_date
	var c: Case = _case(&"hal", [&"id_card", &"bioscan"], 14)
	var card: DocumentInstance = c.get_document(&"id_card")
	card.set_value(&"implants", PackedStringArray(["NX-18"]))
	c.passenger_presented.implants = PackedStringArray(["NX-18"])
	card.values.erase(&"firmware")
	assert_false(_violated(c, 14).has(&"r_nx_firmware"), "champ vide : pas de contrôle")
	card.set_value(&"firmware", today - 89)
	assert_false(_violated(c, 14).has(&"r_nx_firmware"))
	var ref: FieldRef = FieldRef.new(&"id_card", &"firmware")
	assert_eq(DiscrepancyChecker.check(c, ref, FieldRef.today(), _day_ctx(14)).result, Discrepancy.Result.CONCORDANT)
	card.set_value(&"firmware", today - 91)
	assert_true(_violated(c, 14).has(&"r_nx_firmware"), "SC-34 : 91 jours")
	assert_true(DiscrepancyChecker.check(c, FieldRef.today(), ref, _day_ctx(14)).confirmed, "Firmware ↔ date du jour")
	assert_eq(DiscrepancyChecker.check(c, ref, FieldRef.today(), _day_ctx(13)).result, Discrepancy.Result.INCOMPARABLE,
			"règle inactive au J13")


# --- R28 : attestation d'asile ------------------------------------------------

func test_asylum_required_for_tolerated_gravitaires() -> void:
	var c: Case = _case(&"ter", [&"id_card", &"entry_permit", &"bioscan"], 15)
	c.get_document(&"entry_permit").set_value(&"purpose", Passenger.PURPOSE_FAMILY_VISIT)
	assert_false(_violated(c, 15).has(&"r_asylum_required"), "C-3 : pas d'attestation")
	c.get_document(&"id_card").set_value(&"citizen_class", &"C-5")
	assert_true(_violated(c, 15).has(&"r_asylum_required"), "TER C-5 sans attestation")
	c.documents.append(_doc(&"asylum", c.passenger_presented, data.get_day(15).game_date))
	assert_false(_violated(c, 15).has(&"r_asylum_required"))
	c.get_document(&"asylum").expiry_date = data.get_day(15).game_date - 3
	assert_true(_violated(c, 15).has(&"r_asylum_required"), "attestation expirée")


# --- R29 : couvre-feu respiratoire --------------------------------------------

func test_curfew_reads_the_queue_ticket() -> void:
	var c: Case = _case(&"ter", [&"id_card", &"entry_permit", &"bioscan"], 16)
	c.get_document(&"entry_permit").set_value(&"purpose", Passenger.PURPOSE_FAMILY_VISIT)
	assert_false(_violated(c, 16).has(&"r_curfew"), "sans ticket : règle de contexte inactive")
	var ticket: DocumentInstance = DocumentInstance.new(data.documents[&"queue_ticket"])
	ticket.presented_at = 15 * 60 + 59
	c.documents.append(ticket)
	assert_false(_violated(c, 16).has(&"r_curfew"), "15:59")
	ticket.presented_at = 16 * 60
	assert_true(_violated(c, 16).has(&"r_curfew"), "16:00 : VISITE FAMILIALE refusée")
	var ref: FieldRef = FieldRef.new(&"queue_ticket", &"presented_at")
	assert_true(DiscrepancyChecker.check(c, ref, FieldRef.rulebook_rule(&"r_curfew"), _day_ctx(16)).confirmed)
	assert_eq(FieldValue.to_display(ticket.presented_at, ticket.get_field(&"presented_at")), "16:00")
	c.get_document(&"entry_permit").set_value(&"purpose", Passenger.PURPOSE_WORK)
	assert_false(_violated(c, 16).has(&"r_curfew"), "TRAVAIL admis")


func test_scripted_curfew_case_depends_on_presentation_time() -> void:
	var day: DayDef = data.get_day(16)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(CAMPAIGN_SEED, 16), [])
	builder.presentation_minute = 15 * 60 + 40
	var early: GeneratedCase = builder.build(13)
	assert_eq(early.scripted_id, &"sc_39")
	assert_eq(early.case.get_document(&"queue_ticket").presented_at, 15 * 60 + 40)
	assert_eq(early.key.expected_verdict, VK.APPROVE, "Leila avant 16:00")
	builder.presentation_minute = 16 * 60 + 2
	var late: GeneratedCase = builder.build(13)
	assert_eq(late.key.expected_verdict, VK.DENY, "Leila après 16:00 (R29)")
	assert_true(late.key.get_violated_rule_ids().has(&"r_curfew"))
	var result: CaseResult = CaseResult.new(&"x")
	assert_true(CaseConsequences.contexts_for(day, late.case, result).has(CaseEffectDef.CONTEXT_AFTER_CURFEW))


# --- R30 : révocations ------------------------------------------------------

func test_revoked_ids_are_linked_to_passengers_of_the_day() -> void:
	var day: DayDef = data.get_day(17)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(CAMPAIGN_SEED, 17), [],
			CaseMemory.resolve(data, day, CAMPAIGN_SEED, {}))
	var entries: Array[RevokedEntry] = builder.get_revocations()
	assert_eq(entries.size(), 3 + day.revoked_decoys, "Choi, Sato, un passager généré + leurres")
	var ids: Array[String] = []
	for entry: RevokedEntry in entries:
		assert_false(ids.has(entry.citizen_id), "N° ID en double")
		ids.append(entry.citizen_id)
	for index: int in [2, 7, 11]:
		var revoked: GeneratedCase = builder.build(index)
		assert_eq(revoked.key.expected_verdict, VK.DENY, "cas %d" % index)
		assert_true(revoked.key.get_violated_rule_ids().has(&"r_revoked_ids"), "cas %d" % index)
		assert_eq(revoked.get_anomaly_kinds(), [K.REVOKED_ID] as Array[AnomalyType.Kind], "jamais combinée")
		var entry: RevokedEntry = null
		for candidate: RevokedEntry in entries:
			if candidate.case_index == index:
				entry = candidate
		var check: Discrepancy = DiscrepancyChecker.check(revoked.case, entry.get_ref(), FieldRef.new(&"id_card", &"citizen_id"),
				builder.ctx)
		assert_eq(check.reason_key, Discrepancy.REASON_REVOKED_MATCH)
	for index: int in [0, 1, 3]:
		assert_false(builder.build(index).key.get_violated_rule_ids().has(&"r_revoked_ids"), "aucun faux positif (%d)" % index)


# --- R31 : le Puits est clos ----------------------------------------------------

func test_ter_closed_except_shortage_posts() -> void:
	var c: Case = _case(&"ter", [&"id_card", &"entry_permit", &"bioscan"], 18)
	c.passenger_presented.employer_code = "KA"
	c.passenger_presented.post = &"post_recycleur"
	c.documents.append(_doc(&"work_contract", c.passenger_presented, data.get_day(18).game_date))
	assert_false(_violated(c, 18).has(&"r_ter_closed"), "RECYCLEUR en pénurie")
	c.get_document(&"work_contract").set_value(&"post", &"post_manutention")
	assert_true(_violated(c, 18).has(&"r_ter_closed"), "MANUTENTION : interdit")
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(18), SeededRng.day_seed(CAMPAIGN_SEED, 18), [])
	var ter_clean: int = 0
	for i: int in data.get_day(18).passenger_count:
		var g: GeneratedCase = builder.build_clean(i)
		if g.scripted_id == &"" and g.case.passenger_presented.faction_id == &"ter":
			ter_clean += 1
			assert_eq(g.key.expected_verdict, VK.APPROVE, "gravitaire propre : poste en pénurie")
	assert_gt(ter_clean, 0)


# --- SC-48 : expiration le jour même ------------------------------------------

func test_expiry_on_the_day_is_valid() -> void:
	var day: DayDef = data.get_day(20)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(CAMPAIGN_SEED, 20), [])
	var paz: GeneratedCase = builder.build(2)
	assert_eq(paz.scripted_id, &"sc_48")
	var card: DocumentInstance = paz.case.get_document(&"id_card")
	assert_eq(card.expiry_date, day.game_date, "la carte expire aujourd'hui")
	assert_eq(paz.key.expected_verdict, VK.APPROVE, "« Expire aujourd'hui » = valide")
	var check: Discrepancy = DiscrepancyChecker.check(paz.case, FieldRef.new(&"id_card", &"expiry_date"), FieldRef.today(), builder.ctx)
	assert_eq(check.result, Discrepancy.Result.CONCORDANT)


# --- Scanner partiel (M3) -------------------------------------------------------

func test_partial_scanner_suggests_only_discordant_dates() -> void:
	assert_eq(PartialScanner.source_for({}), &"")
	assert_eq(PartialScanner.source_for({&"scanner_luciole": true}), PartialScanner.SOURCE_LUCIOLE)
	assert_eq(PartialScanner.source_for({&"scanner_luciole": true, &"scanner_luciole_removed": true}), &"")
	assert_eq(PartialScanner.source_for({&"scanner_luciole": true, &"scanner_consortium": true}), PartialScanner.SOURCE_ACV,
			"l'ACV-2 remplace le boîtier magenta")
	var c: Case = _case(&"tyc", [&"id_card", &"entry_permit", &"bioscan"], 14)
	var ctx: RuleContext = _day_ctx(14)
	assert_eq(PartialScanner.suggestions(c, ctx).size(), 0, "dossier en règle : aucun lien")
	c.get_document(&"entry_permit").expiry_date = data.get_day(14).game_date - 2
	var links: Array[Discrepancy] = PartialScanner.suggestions(c, ctx)
	assert_eq(links.size(), 1)
	assert_true(links[0].confirmed, "zéro faux positif")
	assert_true(links[0].a.equals(FieldRef.new(&"entry_permit", &"expiry_date")))
	assert_true(links[0].b.is_today())


# --- Nouveaux injecteurs et cas scénarisés --------------------------------------

func test_act2_injectors_on_real_days() -> void:
	var failures: PackedStringArray = []
	var injected: Dictionary[AnomalyType.Kind, int] = {}
	var specs: Array[Array] = [[K.CONTRACT_MISMATCH, 12, &"r_contract_consistent"], [K.UNREGISTERED_VESSEL, 13, &"r_drift_pass"],
			[K.OUTDATED_FIRMWARE, 14, &"r_nx_firmware"]]
	for spec: Array in specs:
		var kind: AnomalyType.Kind = spec[0]
		var day_number: int = spec[1]
		var rule_id: StringName = spec[2]
		for s: int in 30:
			var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(day_number), Gen.day_seed(700 + s, day_number), [])
			var index: int = Gen.index_for(builder, kind, s % builder.day.passenger_count)
			if index < 0 or builder.get_scripted_case(index) != null:
				continue
			var g: GeneratedCase = builder.build_with(index, [kind])
			if g.key.anomalies.size() != 1:
				continue
			injected[kind] = injected.get(kind, 0) + 1
			if not g.key.get_violated_rule_ids().has(rule_id) or g.key.expected_verdict == VK.APPROVE:
				failures.append("%s %s : %s" % [AnomalyType.name_of(kind), g.case.case_id, g.key.get_violated_rule_ids()])
			if not g.invariant_errors.is_empty():
				failures.append("%s : %s" % [g.case.case_id, g.invariant_errors])
	assert_eq(failures.size(), 0, Gen.head(failures))
	for spec: Array in specs:
		var kind: AnomalyType.Kind = spec[0]
		assert_gt(injected.get(kind, 0), 5, AnomalyType.name_of(kind))


## Drapeaux qui activent chaque cas scénarisé conditionnel.
const SCRIPTED_FLAGS: Dictionary[StringName, Array] = {
	&"sc_24": [&"sc08_turned_away"], &"sc_26": [&"sc25_elena_turned_away"], &"sc_29": [&"sc11_veteran_passed"],
	&"sc_35a": [&"okonkwo_denounced"], &"sc_35b": [&"okonkwo_warned"], &"sc_35c": [&"okonkwo_shielded"],
	&"sc_37": [&"sc17_turned_back"], &"sc_49a": [&"lindgren_signed"], &"sc_50a": [&"ilan_joined_soute"],
}
## Verdict attendu de chaque cas (docs/ACT2.md §4.0), quota libre, avant 16:00.
const EXPECTED: Dictionary[StringName, VerdictKind.Kind] = {
	&"sc_23": VK.APPROVE, &"sc_24": VK.APPROVE, &"sc_25": VK.APPROVE, &"sc_26": VK.APPROVE, &"sc_27": VK.APPROVE,
	&"sc_28": VK.DENY, &"sc_29": VK.DENY, &"sc_30": VK.APPROVE, &"sc_31": VK.DENY, &"sc_32": VK.DENY, &"sc_33": VK.DENY,
	&"sc_34": VK.DENY, &"sc_35a": VK.DENY, &"sc_35b": VK.DETAIN, &"sc_35c": VK.DENY, &"sc_36": VK.DENY,
	&"sc_37": VK.APPROVE, &"sc_38": VK.DENY, &"sc_39": VK.APPROVE, &"sc_40": VK.DENY, &"sc_41": VK.DENY,
	&"sc_42": VK.APPROVE, &"sc_43": VK.APPROVE, &"sc_44": VK.APPROVE, &"sc_45": VK.DENY, &"sc_46": VK.APPROVE,
	&"sc_47": VK.DENY, &"sc_48": VK.APPROVE, &"sc_49a": VK.APPROVE, &"sc_49b": VK.APPROVE, &"sc_50a": VK.DETAIN,
	&"sc_50b": VK.DETAIN,
}


func test_scripted_cases_have_their_intended_verdicts() -> void:
	var seen: Array[StringName] = []
	for campaign: int in [CAMPAIGN_SEED, 7, 99]:
		for n: int in range(11, 21):
			var day: DayDef = data.get_day(n)
			for scripted: ScriptedCaseDef in day.scripted_cases:
				var flags: Array[StringName] = []
				flags.assign(SCRIPTED_FLAGS.get(scripted.id, []))
				var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), flags,
						CaseMemory.resolve(data, day, campaign, {}))
				builder.presentation_minute = 12 * 60
				var g: GeneratedCase = builder.build(scripted.at_index)
				if g.scripted_id != scripted.id:
					continue
				seen.append(scripted.id)
				var where: String = "%s (graine %d)" % [scripted.id, campaign]
				assert_eq(g.key.expected_verdict, EXPECTED[scripted.id], "%s : %s" % [where, g.key.get_violated_rule_ids()])
				assert_eq(g.invariant_errors, PackedStringArray(), where)
				assert_eq(g.clean_violation_count, 0, where + " : cas propre")
	for id: StringName in EXPECTED:
		assert_true(seen.has(id), "%s jamais construit" % id)


func test_scripted_continuity_and_variants() -> void:
	var day13: DayDef = data.get_day(13)
	var b13: CaseBuilder = CaseBuilder.new(data, day13, SeededRng.day_seed(CAMPAIGN_SEED, 13), [])
	var kerr31: GeneratedCase = b13.build(4)
	var kerr32: GeneratedCase = b13.build(5)
	assert_eq(str(kerr31.case.get_document(&"entry_permit").get_value(&"citizen_id")), kerr32.case.passenger_presented.citizen_id,
			"SC-31 porte le permis de SC-32")
	assert_eq(str(kerr32.case.get_document(&"entry_permit").get_value(&"citizen_id")), kerr31.case.passenger_presented.citizen_id)
	# SC-35 : trois variantes au même index, la première active l'emporte ; visage fixé.
	var day14: DayDef = data.get_day(14)
	var faces: Array[PassengerAppearance] = []
	for flag: StringName in [&"okonkwo_denounced", &"okonkwo_warned", &"okonkwo_shielded"]:
		var b14: CaseBuilder = CaseBuilder.new(data, day14, SeededRng.day_seed(CAMPAIGN_SEED, 14), [flag])
		var okonkwo: GeneratedCase = b14.build(8)
		assert_true(String(okonkwo.scripted_id).begins_with("sc_35"), String(flag))
		faces.append(okonkwo.case.passenger_presented.appearance.without_visor())
	assert_true(faces[0].equals(faces[1]) and faces[1].equals(faces[2]), "visage d'Okonkwo fixé")
	var b14_none: CaseBuilder = CaseBuilder.new(data, day14, SeededRng.day_seed(CAMPAIGN_SEED, 14), [])
	assert_eq(b14_none.build(8).scripted_id, &"", "sans drapeau du J9 : passager généré")
	# Répliques conditionnelles (SC-36) ; SC-50 Ilan ou Mira.
	var day15: DayDef = data.get_day(15)
	var refused: CaseBuilder = CaseBuilder.new(data, day15, SeededRng.day_seed(CAMPAIGN_SEED, 15), [&"sc23_lindgren_refused"])
	var lindgren: GeneratedCase = refused.build(4)
	assert_eq(lindgren.case.line_overrides.get("arrival", ""), "sc36_lindgren_arrival_refused")
	assert_eq(lindgren.case.scripted_key("arrival", "", func(_k: String) -> bool: return true), "sc36_lindgren_arrival_refused")
	var day20: DayDef = data.get_day(20)
	var with_ilan: CaseBuilder = CaseBuilder.new(data, day20, SeededRng.day_seed(CAMPAIGN_SEED, 20), [&"ilan_joined_soute"],
			CaseMemory.resolve(data, day20, CAMPAIGN_SEED, {}))
	var ilan: GeneratedCase = with_ilan.build(8)
	assert_eq(ilan.scripted_id, &"sc_50a")
	assert_eq(ilan.case.passenger_presented.full_name(), "Ilan Lindqvist-Rey")
	var notices: Array[WantedNotice] = with_ilan.get_wanted_notices()
	for notice: WantedNotice in notices:
		assert_eq(notice.full_name().strip_edges(), "", "J20 : avis « visages seuls »")
	var mira_builder: CaseBuilder = CaseBuilder.new(data, day20, SeededRng.day_seed(CAMPAIGN_SEED, 20), [],
			CaseMemory.resolve(data, day20, CAMPAIGN_SEED, {}))
	assert_eq(mira_builder.build(8).scripted_id, &"sc_50b")
	# Kasimir sur l'avis du J20 seulement s'il n'a pas été détenu la veille.
	var kasimir: CaseBuilder = CaseBuilder.new(data, day20, SeededRng.day_seed(CAMPAIGN_SEED, 20), [&"sc47_kasimir_detained"],
			CaseMemory.resolve(data, day20, CAMPAIGN_SEED, {}))
	assert_eq(kasimir.get_wanted_notices().size(), mira_builder.get_wanted_notices().size() - 1)


func test_kasimir_password_never_grants_trust() -> void:
	var day: DayDef = data.get_day(19)
	var kasimir: ScriptedCaseDef = null
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted.id == &"sc_47":
			kasimir = scripted
	var flags: Dictionary[StringName, Variant] = {&"lucioles_trust": 4}
	var changes: Dictionary[StringName, Variant] = CaseConsequences.compute(kasimir, null, VK.DENY, true, true, 19, flags)
	assert_eq(changes.get(&"sc47_password_answered", false), true)
	assert_false(changes.has(&"lucioles_trust"), "un Brûlant ne donne jamais de confiance")
	assert_false(changes.has(&"password_answered"))
