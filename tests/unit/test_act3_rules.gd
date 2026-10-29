## Acte III (docs/ACT3.md §2.4, §2.5, §4 ; D-086 → D-089) — règles R32–R37,
## Retour aux quais (documents retirés), Main courante et répondants (même
## jour, cascade), convocations, injecteurs 21–23, cas scénarisés SC-51 → SC-82
## (verdict attendu calculé par le moteur, D-005), pivot du J20, Enquête et
## Déposition, chaque fin F1–F10 par un scénario.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
const CAMPAIGN_SEED: int = 20_871_315
const DIR: String = "user://test_act3_rules_saves"

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()


func after_each() -> void:
	SaveService.delete(0, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _builder(day_number: int, flags: Array[StringName] = [], campaign: int = CAMPAIGN_SEED) -> CaseBuilder:
	var day: DayDef = data.get_day(day_number)
	return CaseBuilder.new(data, day, SeededRng.day_seed(campaign, day_number), flags,
			CaseMemory.resolve(data, day, campaign, {}))


## Premier passager généré propre d'une origine (cas propre, aucune anomalie).
func _clean_of(builder: CaseBuilder, faction_id: StringName, purpose: StringName = &"") -> GeneratedCase:
	for i: int in builder.day.passenger_count:
		if builder.get_scripted_case(i) != null or builder.wanted_indices.has(i) or builder.revoked_indices.has(i):
			continue
		if builder.roster.get_entry(i).faction_id != faction_id:
			continue
		var g: GeneratedCase = builder.build_with(i, [])
		if purpose != &"" and g.case.passenger_presented.purpose != purpose:
			continue
		if g.key.expected_verdict == VK.APPROVE:
			return g
	return null


func _violated(c: Case, builder: CaseBuilder) -> Array[StringName]:
	var ids: Array[StringName] = []
	for v: Violation in RuleEngine.validate(c, builder.day.rule_set, builder.ctx):
		ids.append(v.rule_id)
	return ids


# --- R32 : Prorogation de Continuité (M1) -------------------------------------

func test_prorogation_window_and_end() -> void:
	var b21: CaseBuilder = _builder(21)
	var ctx: RuleContext = b21.ctx
	assert_not_null(ctx.prorogation(), "R32 active au J21")
	assert_true(ctx.is_prorogated(GameDate.from_ymd(2187, 3, 25)), "expiré le 25.03 : prorogé")
	assert_true(ctx.is_prorogated(GameDate.from_ymd(2187, 4, 1)), "01.04 inclus")
	assert_false(ctx.is_prorogated(GameDate.from_ymd(2187, 3, 21)), "21.03 : hors fenêtre (SC-73)")
	assert_true(ctx.is_document_expired(GameDate.from_ymd(2187, 3, 21)))
	assert_false(ctx.is_document_expired(GameDate.from_ymd(2187, 3, 25)))
	var g: GeneratedCase = _clean_of(b21, &"hal")
	assert_not_null(g)
	var card: DocumentInstance = g.case.get_document(&"id_card")
	card.expiry_date = GameDate.from_ymd(2187, 3, 28)
	assert_false(_violated(g.case, b21).has(&"r_id_card_valid"), "carte prorogée valide au J21")
	card.expiry_date = GameDate.from_ymd(2187, 3, 20)
	assert_true(_violated(g.case, b21).has(&"r_id_card_valid"), "expirée avant la fenêtre")
	# J29 : dernier jour ; J30 : la prorogation a pris fin (piège voulu, SC-80).
	var b29: CaseBuilder = _builder(29)
	assert_false(b29.ctx.is_document_expired(GameDate.from_ymd(2187, 3, 28)), "J29 : encore prorogé")
	var b30: CaseBuilder = _builder(30)
	assert_true(b30.ctx.is_document_expired(GameDate.from_ymd(2187, 3, 28)), "J30 : prorogation échue")
	assert_null(_builder(20).ctx.prorogation(), "pas de R32 au J20")


# --- R33 : Réintégrations ----------------------------------------------------

func test_reinstated_ids_are_valid_and_excluded_ones_refused() -> void:
	var b22: CaseBuilder = _builder(22, [&"sc40_valentin_revoked"])
	var reinstated: int = 0
	var excluded: int = 0
	for entry: RevokedEntry in b22.ctx.revoked:
		if entry.is_reinstated(b22.ctx.today):
			reinstated += 1
		if not entry.excluded_reason_key.is_empty():
			excluded += 1
	assert_gt(reinstated, 0, "réintégré·es inscrit·es (SC-54, bruit légitime)")
	assert_gt(excluded, 0, "exclu·e de la réintégration (SC-55)")
	var results: Dictionary[StringName, GeneratedCase] = {}
	for g: GeneratedCase in b22.build_day():
		if g.scripted_id != &"":
			results[g.scripted_id] = g
	assert_eq(results[&"sc_54"].key.expected_verdict, VK.APPROVE, "Sato réintégré")
	assert_eq(results[&"sc_55"].key.expected_verdict, VK.DENY, "Valentin exclu")
	assert_true(results[&"sc_55"].key.get_violated_rule_ids().has(&"r_revoked_ids"))


# --- M1 : Retour aux quais ---------------------------------------------------

func test_retired_documents_leave_the_rules() -> void:
	assert_false(data.get_day(21).rule_set.has_rule(&"r_curfew"), "ticket retiré : couvre-feu levé")
	assert_true(data.get_day(22).rule_set.required_document_ids.has(&"bioscan"))
	assert_false(data.get_day(23).rule_set.required_document_ids.has(&"bioscan"), "bio-scan retiré au J23")
	assert_eq(data.get_day(23).rule_set.build_retired_entries().size(), 4, "règles retirées au Rulebook")
	# SC-58 : le bio-scan retiré, présenté et expiré, n'est plus contrôlé.
	var b23: CaseBuilder = _builder(23)
	var ophelie: GeneratedCase = b23.build(7)
	assert_eq(ophelie.scripted_id, &"sc_58")
	var bioscan: DocumentInstance = ophelie.case.get_document(&"bioscan")
	assert_not_null(bioscan, "certificat présenté quand même")
	assert_true(bioscan.retired and bioscan.is_foreign())
	assert_lt(bioscan.expiry_date, b23.ctx.today)
	assert_eq(ophelie.key.expected_verdict, VK.APPROVE)


# --- R34 : Répondants et Main courante (M2) ----------------------------------

func test_ledger_records_only_eligible_admissions() -> void:
	var b24: CaseBuilder = _builder(24)
	var native: GeneratedCase = _clean_of(b24, &"hal")
	assert_not_null(native)
	assert_null(b24.record_verdict(native.case, VK.DENY), "un refus n'inscrit rien")
	var entry: LedgerEntry = b24.record_verdict(native.case, VK.APPROVE)
	var eligible: bool = SponsorRule.ELIGIBLE_CLASSES.has(native.case.passenger_presented.citizen_class)
	assert_eq(entry != null, eligible, "C-1 à C-3 seulement")
	var other: GeneratedCase = _clean_of(b24, &"cer")
	if other != null:
		assert_null(b24.record_verdict(other.case, VK.APPROVE), "hors HAL : pas répondant")
	assert_null(_builder(23).record_verdict(native.case, VK.APPROVE), "pas de Main courante avant R34")


func test_sponsor_chain_cascades_the_same_day() -> void:
	# SC-60 → SC-61 : Amara est APPROUVÉE si Margaux a été admise ce jour.
	for admitted: bool in [true, false]:
		var b24: CaseBuilder = _builder(24)
		for i: int in 2:
			var g: GeneratedCase = b24.build(i)
			b24.record_verdict(g.case, g.key.expected_verdict if (i != 1 or admitted) else VK.DENY)
		var amara: GeneratedCase = b24.build(2)
		assert_eq(amara.scripted_id, &"sc_61")
		var margaux: ScriptedCaseDef = b24.get_scripted_case(1)
		assert_eq(margaux.id, &"sc_60")
		assert_eq(amara.case.passenger_presented.sponsor_id, b24.peek_citizen_id(1), "répondant = N° ID de SC-60")
		assert_eq(amara.key.expected_verdict, VK.APPROVE if admitted else VK.DENY, "Margaux admise : %s" % admitted)
		if not admitted:
			assert_true(amara.key.get_violated_rule_ids().has(&"r_sponsor"))


func test_generated_wards_follow_their_sponsor() -> void:
	var checked: int = 0
	for campaign: int in [CAMPAIGN_SEED, 7, 99]:
		var b28: CaseBuilder = _builder(28, [], campaign)
		var results: Array[GeneratedCase] = b28.build_day()
		for ward: int in b28.wards:
			var sponsor: int = b28.wards[ward]
			assert_lt(sponsor, ward, "répondant avant le protégé dans la file")
			var g: GeneratedCase = results[ward]
			if g.scripted_id != &"" or not g.key.anomalies.is_empty():
				continue
			checked += 1
			assert_eq(g.case.passenger_presented.purpose, Passenger.PURPOSE_FAMILY_VISIT)
			assert_eq(g.key.expected_verdict, VK.APPROVE if results[sponsor].key.expected_verdict == VK.APPROVE else VK.DENY,
					"%s : %s" % [g.case.case_id, g.key.get_violated_rule_ids()])
	assert_gt(checked, 3, "protégés générés contrôlés")


# --- R35 : Lock-out ; R36 : convocations ; R37 : Tycho fermé ------------------

func test_lockout_summons_and_tycho_closure_on_real_days() -> void:
	var failures: PackedStringArray = []
	var injected: Dictionary[AnomalyType.Kind, int] = {}
	var specs: Array[Array] = [[K.SUSPENDED_CONTRACT, 25, &"r_tycho_lockout"], [K.FORGED_SUMMONS, 26, &"r_summons"],
			[K.SPONSOR_MISMATCH, 24, &"r_sponsor"], [K.BANNED_FACTION, 28, &"r_tycho_closed"]]
	for spec: Array in specs:
		var kind: AnomalyType.Kind = spec[0]
		var day_number: int = spec[1]
		var rule_id: StringName = spec[2]
		for s: int in 30:
			var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(day_number), Gen.day_seed(900 + s, day_number), [])
			var index: int = Gen.index_for(builder, kind, s % builder.day.passenger_count)
			if kind == K.SPONSOR_MISMATCH:
				index = _first_ward(builder, s)
			elif kind == K.BANNED_FACTION:
				index = _first_of(builder, &"tyc", s)
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
		var count: int = injected.get(kind, 0)
		assert_gt(count, 5, AnomalyType.name_of(kind))


func _first_of(builder: CaseBuilder, faction_id: StringName, start: int) -> int:
	var count: int = builder.day.passenger_count
	for offset: int in count:
		var i: int = (start + offset) % count
		if builder.roster.get_entry(i).faction_id == faction_id and not builder.wanted_indices.has(i) \
				and not builder.revoked_indices.has(i) and not builder.summoned_numbers.has(i):
			return i
	return -1


## Protégé généré (VISITE FAMILIALE, répondant planifié), non convoqué.
func _first_ward(builder: CaseBuilder, start: int) -> int:
	var count: int = builder.day.passenger_count
	for offset: int in count:
		var i: int = (start + offset) % count
		if builder.wards.has(i) and not builder.summoned_numbers.has(i) and not builder.wanted_indices.has(i) \
				and not builder.revoked_indices.has(i):
			return i
	return -1


func test_summons_exempts_from_bans_but_not_from_wanted() -> void:
	# SC-67 : Hana (THR, R19) convoquée par l'Enquête : APPROUVÉE.
	var b26: CaseBuilder = _builder(26, [&"sc16_family_split"])
	var hana: GeneratedCase = null
	for g: GeneratedCase in b26.build_day():
		if g.scripted_id == &"sc_67":
			hana = g
	assert_not_null(hana)
	assert_eq(hana.key.expected_verdict, VK.APPROVE, str(hana.key.get_violated_rule_ids()))
	assert_true(b26.ctx.has_valid_summons(hana.case), "N° ENQ à l'onglet, au nom du porteur")
	assert_false(b26.ctx.summons.is_empty(), "onglet Convocations publié")
	# Sans convocation, la même passagère tombe sous R19.
	var permit: DocumentInstance = hana.case.get_document(&"entry_permit")
	permit.set_value(&"summons", "")
	assert_false(b26.ctx.has_valid_summons(hana.case))
	assert_true(_violated(hana.case, b26).has(&"r_tharsis_banned"))
	# Fausse convocation (numéro absent) : refus R36.
	permit.set_value(&"summons", "ENQ-0000")
	assert_true(_violated(hana.case, b26).has(&"r_summons"))
	assert_true(SummonsRule.new().summons_exempt == false, "R36 ne s'exempte pas elle-même")
	assert_false((data.rules[&"r_wanted_detain"] as Rule).summons_exempt, "pas l'avis de recherche")


func test_tycho_closed_except_sponsored_family_visits() -> void:
	var b28: CaseBuilder = _builder(28)
	var results: Array[GeneratedCase] = b28.build_day()
	var tyc: int = 0
	for g: GeneratedCase in results:
		if g.scripted_id != &"" or g.case.passenger_presented.faction_id != &"tyc" or not g.key.anomalies.is_empty():
			continue
		tyc += 1
		var exempt: bool = SponsorRule.has_valid_sponsor(g.case, b28.ctx) or b28.ctx.has_valid_summons(g.case)
		assert_true(exempt, "%s : ressortissant propre de Tycho avec répondant ou convocation" % g.case.case_id)
		assert_eq(g.key.expected_verdict, VK.APPROVE, "%s : %s" % [g.case.case_id, g.key.get_violated_rule_ids()])
	assert_gt(tyc, 0)


# --- Cas scénarisés SC-51 → SC-82 --------------------------------------------

## Drapeaux qui activent chaque cas scénarisé conditionnel ou variante.
const SCRIPTED_FLAGS: Dictionary[StringName, Array] = {
	&"sc_55": [&"sc40_valentin_revoked"], &"sc_63": [&"sc24_dmitri_hired"], &"sc_67": [&"sc16_family_split"],
	&"sc_71a": [&"sc47_kasimir_passed"], &"sc_71b": [&"sc47_kasimir_detained"],
	&"sc_75a": [&"okonkwo_shielded"], &"sc_75b": [&"okonkwo_denounced"],
	&"sc_75c": [&"okonkwo_warned", &"sc35_okonkwo_detained"], &"sc_75d": [&"okonkwo_warned"],
	&"sc_78": [&"sc11_veteran_passed"], &"sc_82a": [&"dora_departed"],
	&"sc_81b_lindgren": [&"sc64_lindgren_passed", &"sc77_lindgren_passed"], &"sc_81b_sato": [&"sc54_sato_reinstated"],
	&"sc_81b_valentin": [&"sc55_valentin_passed"], &"sc_81b_kerr": [&"sc68_kerr_passed"],
	&"sc_81b_beaumont": [&"sc59_beaumont_spared"],
}
## Verdict attendu (docs/ACT3.md §4.0) ; chaînes de répondants : répondant admis.
const EXPECTED: Dictionary[StringName, VerdictKind.Kind] = {
	&"sc_51": VK.DENY, &"sc_52": VK.APPROVE, &"sc_53": VK.DETAIN, &"sc_54": VK.APPROVE, &"sc_55": VK.DENY,
	&"sc_56": VK.APPROVE, &"sc_57": VK.APPROVE, &"sc_58": VK.APPROVE, &"sc_59": VK.DENY, &"sc_60": VK.APPROVE,
	&"sc_61": VK.APPROVE, &"sc_62": VK.DENY, &"sc_63": VK.DENY, &"sc_64": VK.APPROVE, &"sc_65": VK.APPROVE,
	&"sc_66": VK.DENY, &"sc_67": VK.APPROVE, &"sc_68": VK.APPROVE, &"sc_69": VK.APPROVE, &"sc_70": VK.DENY,
	&"sc_71a": VK.DETAIN, &"sc_71b": VK.APPROVE, &"sc_71c": VK.APPROVE, &"sc_72": VK.DENY, &"sc_73": VK.DENY,
	&"sc_74": VK.DENY, &"sc_75a": VK.APPROVE, &"sc_75b": VK.APPROVE, &"sc_75c": VK.APPROVE, &"sc_75d": VK.DENY,
	&"sc_76": VK.DENY, &"sc_77": VK.APPROVE, &"sc_78": VK.APPROVE, &"sc_79": VK.APPROVE, &"sc_80": VK.DENY,
	&"sc_81": VK.APPROVE, &"sc_81b_lindgren": VK.APPROVE, &"sc_81b_sato": VK.APPROVE, &"sc_81b_valentin": VK.APPROVE,
	&"sc_81b_kerr": VK.APPROVE, &"sc_81b_beaumont": VK.APPROVE, &"sc_82a": VK.DETAIN, &"sc_82b": VK.DETAIN,
}


func test_scripted_cases_have_their_intended_verdicts() -> void:
	var seen: Array[StringName] = []
	for campaign: int in [CAMPAIGN_SEED, 7, 99]:
		for n: int in range(21, 31):
			var day: DayDef = data.get_day(n)
			for scripted: ScriptedCaseDef in day.scripted_cases:
				var wanted: Array = SCRIPTED_FLAGS.get(scripted.id, [])
				var flags: Array[StringName] = []
				flags.assign(wanted)
				var builder: CaseBuilder = _builder(n, flags, campaign)
				# File jouée dans l'ordre : la Main courante suit les verdicts attendus.
				for g: GeneratedCase in builder.build_day():
					if g.scripted_id != scripted.id:
						continue
					seen.append(scripted.id)
					var where: String = "%s (graine %d)" % [scripted.id, campaign]
					assert_eq(g.key.expected_verdict, EXPECTED[scripted.id], "%s : %s" % [where, g.key.get_violated_rule_ids()])
					assert_eq(g.invariant_errors, PackedStringArray(), where)
					assert_eq(g.clean_violation_count, 0, where + " : cas propre")
	for id: StringName in EXPECTED:
		assert_true(seen.has(id), "%s jamais construit" % id)


func test_sc74_follows_sc73_and_network_fills_its_slots() -> void:
	var b28: CaseBuilder = _builder(28)
	var celeste: GeneratedCase = b28.build(2)
	b28.record_verdict(b28.build(0).case, VK.APPROVE)
	b28.record_verdict(celeste.case, VK.APPROVE)
	var elena: GeneratedCase = b28.build(3)
	assert_eq(elena.scripted_id, &"sc_74")
	assert_eq(elena.key.expected_verdict, VK.APPROVE, "Céleste admise (à tort) : Elena garantie")
	# J30 : jusqu'à 4 membres du réseau, emplacements 8, 11, 13, 15.
	var all: Array[StringName] = [&"sc64_lindgren_passed", &"sc77_lindgren_passed", &"sc54_sato_reinstated",
			&"sc55_valentin_passed", &"sc68_kerr_passed", &"sc59_beaumont_spared"]
	var b30: CaseBuilder = _builder(30, all)
	var slots: Array[int] = []
	for scripted: ScriptedCaseDef in b30.get_active_scripted_cases():
		if scripted.slot_group == &"reseau":
			slots.append(scripted.at_index)
	slots.sort()
	assert_eq(slots, [8, 11, 13, 15] as Array[int], "4 répondants au plus")
	var none: CaseBuilder = _builder(30, [])
	for scripted: ScriptedCaseDef in none.get_active_scripted_cases():
		assert_ne(scripted.slot_group, &"reseau", "réseau vide sans drapeau")
	assert_false(none.wards.has(9), "protégé d'un répondant absent : passager générique")


func test_final_figure_is_dora_if_she_left_for_tycho() -> void:
	assert_eq(_builder(30, [&"dora_departed"]).get_scripted_case(10).id, &"sc_82a")
	assert_eq(_builder(30, []).get_scripted_case(10).id, &"sc_82b")
	var notices: Array[WantedNotice] = _builder(30, []).get_wanted_notices()
	for notice: WantedNotice in notices:
		assert_eq(notice.full_name().strip_edges(), "", "J30 : avis « visages seuls »")


# --- Pivot du J20 (D-086) ----------------------------------------------------

func _start_at(day_number: int, flags: Dictionary, credits: int = 200) -> void:
	Campaign.new_game(data, CAMPAIGN_SEED)
	GameState.current_day = day_number
	GameState.credits = credits
	for flag: Variant in flags:
		GameState.set_flag(StringName(str(flag)), flags[flag])


func _close(choices: Dictionary[StringName, StringName] = {}) -> StringName:
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var picked: Dictionary[StringName, StringName] = Campaign.default_choices(events, lines)
	for id: StringName in choices:
		picked[id] = choices[id]
	var report: EveningReport = Campaign.preview_evening(data, lines, events, picked)
	return Campaign.close_evening(data, null, report, 0, DIR)


func _event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for event: EveningEvent in Campaign.prepare_events(data):
		ids.append(event.id)
	return ids


func test_pivot_evening_opens_act_three_with_a_climate() -> void:
	_start_at(20, {"act2_started": true, "final2_passed": true, "lucioles_trust": 8, "suspicion": 6})
	var ids: Array[StringName] = _event_ids()
	assert_true(ids.has(&"d20_card_vanne"), "carte de fin d'acte : climat Vanne prévisualisé %s" % [ids])
	assert_true(ids.has(&"d20_night"))
	assert_eq(_close(), EveningReport.ENDING_NONE, "le pivot ne termine pas la partie")
	assert_true(Campaign.is_act3())
	assert_true(GameState.has_flag(&"climate_vanne"))
	assert_eq(SaveService.as_int(GameState.get_flag(&"suspicion", 0)), 3, "soupçon divisé par deux au pivot")
	assert_eq(GameState.current_day, 21)


func test_pivot_terminal_endings_f1_f2_f3_f6() -> void:
	# F6 : « Embarquer » au J20 (D-086).
	_start_at(20, {"act2_started": true, "drift2_passes_bought": true})
	assert_true(_event_ids().has(&"d20_drift"))
	assert_eq(_close({&"d20_drift": &"board"}), EndingService.F6_DRIFT)
	# Par défaut on reste : +30 ₵, Acte III.
	_start_at(20, {"act2_started": true, "drift2_passes_bought": true}, 100)
	assert_eq(_close(), EveningReport.ENDING_NONE)
	assert_eq(GameState.credits, 100 + 30 - _last_spent(), "Wren rend 30 ₵")
	# F3 : plus personne au foyer.
	_start_at(20, {"act2_started": true})
	for member: Household.Member in GameState.household.members:
		member.health = Household.Health.LOST
	assert_eq(_close(), EndingService.F3_FAMILY_LOST)
	# F2 : troisième loyer impayé.
	_start_at(20, {"act2_started": true}, -200)
	GameState.household.unpaid_rent_streak = data.get_economy().eviction_unpaid_rent - 1
	assert_eq(_close(), EndingService.F2_REASSIGNED)


func _last_spent() -> int:
	var entry: Dictionary = GameState.day_history[GameState.day_history.size() - 1]
	return SaveService.as_int(entry.get("spent", 0))


func test_double_game_at_the_pivot_marks_the_enquiry_target() -> void:
	_start_at(20, {"act2_started": true, "lucioles_trust": 9, "loyalty": 9})
	assert_eq(_close(), EveningReport.ENDING_NONE, "le double jeu ne termine plus au J20")
	assert_true(GameState.has_flag(&"enquete_cible"))


# --- Enquête et Déposition (J22–J29) ----------------------------------------

func test_enquiry_questions_share_options_and_default_to_silence() -> void:
	for day_number: int in [22, 26, 28]:
		_start_at(day_number, {"act2_started": true, "act3_started": true, "final_passed": true, "final2_passed": true})
		var question: EveningEvent = null
		for event: EveningEvent in Campaign.prepare_events(data):
			if String(event.id).ends_with("_q1") or String(event.id).ends_with("_q2") or String(event.id).ends_with("_q3"):
				question = event
		assert_not_null(question, "J%d : question de l'Enquête" % day_number)
		var ids: Array[StringName] = []
		for option: EveningOptionDef in question.options:
			ids.append(option.id)
		assert_eq(ids, [&"tell", &"silent", &"accuse"] as Array[StringName])
		var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, [question])
		assert_eq(Campaign.default_choices([question], lines)[question.id], &"silent", "D-058 : jamais accuser par défaut")


func test_deposition_arrests_blames_or_clears() -> void:
	# Score ≥ 7 → F1 au soir du J29.
	_start_at(29, {"act2_started": true, "act3_started": true, "suspicion": 4, "enquete_cible": true, "aveux": 1})
	assert_eq(_close(), EndingService.F1_ARRESTED, "Déposition : arrestation")
	# Score 4–6 → blâme : −30 ₵, promotion révoquée.
	_start_at(29, {"act2_started": true, "act3_started": true, "suspicion": 4}, 300)
	assert_eq(_close(), EveningReport.ENDING_NONE)
	assert_true(GameState.has_flag(&"deposition_blamed"))
	assert_true(GameState.has_flag(&"promotion_revoked"))
	# « Dire ce qu'on attend » (−2) : sans suite.
	_start_at(29, {"act2_started": true, "act3_started": true, "suspicion": 4}, 300)
	assert_eq(_close({&"d29_deposition": &"loyal"}), EveningReport.ENDING_NONE)
	assert_true(GameState.has_flag(&"deposition_clean"))
	assert_true(GameState.has_flag(&"deposition_loyal"))


func test_conditional_aids_and_loan() -> void:
	_start_at(21, {"act2_started": true, "act3_started": true, "quota_overrun": 3}, 20)
	var ids: Array[StringName] = _event_ids()
	assert_true(ids.has(&"d21_recall"), "rappel des salaires imputés")
	assert_true(ids.has(&"d21_loan"), "avance proposée sous 40 ₵")
	var before: int = GameState.credits
	assert_eq(_close({&"d21_loan": &"take"}), EveningReport.ENDING_NONE)
	var entry: Dictionary = GameState.day_history[GameState.day_history.size() - 1]
	assert_eq(SaveService.as_int(entry["gained"]), 15 + 30, "rappel 3 × 5 ₵ + avance 30 ₵")
	assert_true(GameState.has_flag(&"arbitre_loan"))
	assert_eq(GameState.credits, before + 45 - SaveService.as_int(entry["spent"]))
	_start_at(21, {"act2_started": true, "act3_started": true}, 300)
	assert_false(_event_ids().has(&"d21_loan"), "pas d'avance pour un solde confortable")
	assert_eq(data.get_economy().levy_for(25, 300), roundi((300 - 60) * 0.20), "Contribution du J25 : 20 % au-delà de 60 ₵")
	assert_eq(data.get_economy().levy_for(24, 300), 0)


# --- Fins F1–F10 (D-088) -----------------------------------------------------

func _flags(values: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	for key: Variant in values:
		flags[StringName(str(key))] = values[key]
	return flags


func test_each_act_three_ending_has_a_scenario() -> void:
	var economy: EconomyDef = data.get_economy()
	var home: Household = Household.new()
	var scenarios: Dictionary[StringName, Dictionary] = {
		EndingService.F1_ARRESTED: {"lucioles_trust": 10, "loyalty": 10},
		EndingService.F5_AIR: {"final3_passed": true, "lucioles_trust": 10},
		EndingService.F9_STRIKE: {"strike2_joined": true, "solidarite": 5},
		EndingService.F10_PONT: {"pont": economy.pont_threshold},
		EndingService.F8_REGISTRE: {"deposition_truth": true, "verite": 3, "registre": 5},
		EndingService.F6_DRIFT: {"exit3_bought": true, "exit3_tycho": true},
		EndingService.F4_GLORY: {"final3_detained": true, "loyalty": 10},
		EndingService.F7_REOPENS: {},
	}
	for ending: StringName in scenarios:
		var flags: Dictionary[StringName, Variant] = _flags(scenarios[ending])
		assert_eq(EndingService.evaluate_final_act3(flags, home, 100, 0.95, economy), ending, String(ending))
		var epilogue: Dictionary = EndingService.epilogue_act3(ending, flags, home)
		assert_true(UiText.has(str(epilogue["title_key"])), "%s : %s" % [ending, epilogue["title_key"]])
		for line: String in epilogue["lines"]:
			assert_true(UiText.has(line), "%s : %s" % [ending, line])
	var empty: Household = Household.new()
	for member: Household.Member in empty.members:
		member.health = Household.Health.LOST
	assert_eq(EndingService.evaluate_final_act3({}, empty, 100, 0.95, economy), EndingService.F3_FAMILY_LOST)
	# Priorité F1 > F3 > F2 > F5 > F9 > F10 > F8 > F6 > F4 > F7.
	var all: Dictionary[StringName, Variant] = _flags({"final3_passed": true, "lucioles_trust": 10, "strike2_joined": true,
			"solidarite": 5, "pont": 9, "deposition_truth": true, "verite": 3, "registre": 5})
	assert_eq(EndingService.evaluate_final_act3(all, home, 100, 0.95, economy), EndingService.F5_AIR)
	all.erase(&"final3_passed")
	assert_eq(EndingService.evaluate_final_act3(all, home, 100, 0.95, economy), EndingService.F9_STRIKE)
	all.erase(&"strike2_joined")
	assert_eq(EndingService.evaluate_final_act3(all, home, 100, 0.95, economy), EndingService.F10_PONT)
	all[&"final3_detained"] = true
	assert_eq(EndingService.evaluate_final_act3(all, home, 100, 0.95, economy), EndingService.F8_REGISTRE,
			"F10 exclue si la figure finale est mise en attente")


func test_pont_counts_correct_tycho_admissions_only() -> void:
	var b30: CaseBuilder = _builder(30)
	var gauges: Dictionary[StringName, StringName] = data.get_day(30).admission_gauges
	var gauge: StringName = gauges.get(&"tyc", &"")
	assert_eq(gauge, &"pont")
	var results: Array[GeneratedCase] = b30.build_day()
	var flags: Dictionary[StringName, Variant] = {}
	for g: GeneratedCase in results:
		if g.case.passenger_presented.faction_id != &"tyc":
			continue
		var changes: Dictionary[StringName, Variant] = CaseConsequences.compute(null, g.case, VK.APPROVE,
				not g.key.expected_violations.is_empty(), false, 30, flags, false, [], false, gauges)
		assert_eq(changes.has(&"pont"), g.key.expected_violations.is_empty(), "%s : admission correcte seulement" % g.case.case_id)
		CaseConsequences.merge_into(flags, changes)
	assert_gt(FlagCondition.gauge_value(flags, &"pont"), 0)
