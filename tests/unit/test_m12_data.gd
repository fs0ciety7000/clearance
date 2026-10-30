## M12 (docs/M12.md §1, §2.3, §3.2, §4, §5.2 ; B60, B61, B63) — données
## produites par `tools/build_data_m12.gd` : jours J31 des quatre mondes et
## leurs cas scénarisés (verdict attendu calculé par le moteur, D-005), échos
## SC-83 → SC-89 insérés dans la campagne, unités de Garde, événements, table
## des personnages, textes FR.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const VK := VerdictKind.Kind
const SEEDS: int = 8

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _builder(day: DayDef, seed: int, flags: Array[StringName]) -> CaseBuilder:
	var values: Dictionary[StringName, Variant] = FlagCondition.from_true_flags(flags)
	return CaseBuilder.new(data, day, SeededRng.day_seed(seed, day.day_number), flags,
			CaseMemory.resolve(data, day, seed, {}), values)


## Joue la file d'un jour avec le verdict attendu (Main courante tenue) et
## renvoie `{scripted_id: GeneratedCase}`.
func _play(builder: CaseBuilder) -> Dictionary:
	var result: Dictionary = {}
	for i: int in builder.day.passenger_count:
		var g: GeneratedCase = builder.build(i)
		assert_not_null(g)
		if g == null:
			continue
		assert_true(g.invariant_errors.is_empty(), "J%d @%d %s" % [builder.day.day_number, i, g.invariant_errors])
		assert_eq(g.clean_violation_count, 0, "J%d @%d cas propre" % [builder.day.day_number, i])
		builder.record_verdict(g.case, g.key.expected_verdict)
		if g.scripted_id != &"":
			result[g.scripted_id] = g
	return result


func test_catalog_holds_the_m12_data() -> void:
	assert_eq(data.errors, PackedStringArray())
	assert_eq(data.epilogue_days.keys().size(), 4)
	assert_eq(data.days.keys().size(), 30, "J31 hors des jours de campagne")
	assert_eq(data.get_last_day_number(), 30)
	assert_not_null(data.epilogue)
	assert_not_null(data.garde)
	assert_not_null(data.station_events)
	assert_not_null(data.characters)
	# M13 : U21 → U24 (D-152) et EV-09 (D-153).
	assert_eq(data.garde_units.size(), 24)
	assert_eq(data.events.size(), 9)
	assert_same(EpilogueService.load_def(), data.epilogue, "même ressource que le service")


func test_epilogue_days_follow_m12() -> void:
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		var day: DayDef = data.get_epilogue_day(world)
		var label: String = "J31-%s" % world
		assert_eq(day.day_number, 31, label)
		assert_eq(day.game_date, GameDate.from_ymd(2188, 4, 11), label + " : vendredi 11.04.2188")
		assert_eq(day.passenger_count, 7, label)
		assert_eq(day.mode, DayDef.MODE_EPILOGUE, label)
		assert_eq(day.epilogue_world, world, label)
		assert_true(day.economy_disabled and day.untimed, label)
		assert_false(day.has_evening, label)
		assert_true(day.detain_enabled, label)
		assert_eq(day.anomaly_count_weights, PackedFloat32Array([0.40, 0.40, 0.17, 0.03]), label)
		assert_eq(day.get_scripted_case(0).id, &"sc_90", label + " : SC-90 en tête")
		assert_true(data.rule_sets.has(day.rule_set.id), label)
		for kind: AnomalyType.Kind in day.anomaly_weights:
			assert_true(day.rule_set.can_detect(kind), "%s : %s" % [label, AnomalyType.name_of(kind)])
	var rule_counts: Array[int] = []
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		rule_counts.append(data.get_epilogue_day(world).rule_set.rules.size())
	assert_eq(rule_counts, [17, 14, 12, 13] as Array[int], "règles du jour (M12 §1.5–§1.8)")
	assert_eq(data.get_epilogue_day(&"a").air_quota, 3)
	assert_true(data.get_epilogue_day(&"a").rule_set.has_rule(&"r_ep_tycho_ka"))
	assert_true(data.get_epilogue_day(&"b").rule_set.has_rule(&"r_ep_welcome"))
	assert_false(data.get_epilogue_day(&"b").rule_set.has_rule(&"r_permit_required"), "B : permis ou répondant")
	assert_true(data.get_epilogue_day(&"d").rule_set.has_rule(&"r_ep_ka_cadres"))
	assert_false(data.get_epilogue_day(&"d").rule_set.has_rule(&"r_bioscan_issuer"), "D : R41 remplace R13")


func test_epilogue_definition() -> void:
	var def: EpilogueDef = data.epilogue
	assert_eq(def.worlds.size(), 4)
	assert_eq(def.endings.size(), 13)
	for ending: EpilogueEndingDef in def.endings:
		assert_eq(EpilogueService.WORLD_OF_KEY.get(ending.key, &""), ending.world, String(ending.key))
		assert_same(def.get_world(ending.world).day_def, data.get_epilogue_day(ending.world), String(ending.key))
	assert_eq(def.get_ending(&"f10").open_gauge, &"pont31")
	assert_true(def.get_ending(&"f3").no_home_line)
	assert_eq(def.get_ending(&"f6t").intro_key, "day31_d_intro_f6t")
	assert_between(def.read_flags.size(), 25, 70, "liste blanche ≈ 45 drapeaux")
	for flag: StringName in [&"final3_dora", &"okonkwo_denounced", &"sc59_beaumont_spared", &"ilan_estranged", &"exit3_drift"]:
		assert_true(def.read_flags.has(flag), String(flag))
	for flag: StringName in def.read_flags:
		assert_false(String(flag).begins_with("sc9") or String(flag).begins_with("sc10"), "%s posé au J31" % flag)
	assert_eq(data.get_epilogue_day(&"c").admission_gauges, {&"tyc": &"pont31"} as Dictionary[StringName, StringName])


## Monde A : Sato (test MRZ ou déclassé), Okonkwo (3 variantes), la figure.
func test_world_a_cases() -> void:
	var day: DayDef = data.get_epilogue_day(&"a")
	for s: int in SEEDS:
		var cases: Dictionary = _play(_builder(day, s, [&"sc54_sato_reinstated", &"okonkwo_denounced", &"final3_dora",
				&"dora_detained_final", &"hh_dora_alive"]))
		assert_eq((cases[&"sc_90"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((cases[&"sc_91a"] as GeneratedCase).key.expected_verdict, VK.DENY, "SAT0 : test → refus")
		assert_eq((cases[&"sc_92b"] as GeneratedCase).key.expected_verdict, VK.DENY, "permis expiré de 2 jours")
		assert_eq((cases[&"sc_93a"] as GeneratedCase).key.expected_verdict, VK.DENY, "Dora sans contrat KA (R38)")
		var other: Dictionary = _play(_builder(day, s, [&"okonkwo_warned", &"final3_detained", &"hh_ilan_alive"]))
		assert_eq((other[&"sc_91b"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((other[&"sc_92c"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((other[&"sc_93b"] as GeneratedCase).key.expected_verdict, VK.APPROVE, "Mira, contrat KA imposé")
		var ilan: Dictionary = _play(_builder(day, s, [&"okonkwo_shielded", &"hh_ilan_alive"]))
		assert_eq((ilan[&"sc_92a"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((ilan[&"sc_93c"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		var none: Dictionary = _play(_builder(day, s, []))
		assert_false(none.has(&"sc_92a") or none.has(&"sc_92b") or none.has(&"sc_92c"), "sans drapeau : pas d'Okonkwo")
		var bearer: GeneratedCase = none[&"sc_93d"]
		assert_eq(bearer.key.expected_verdict, VK.APPROVE)
		assert_eq(bearer.case.slipped_items.size(), 1, "le mot de la figure")


## Monde B : Beaumont, Yara (chaîne de répondant @3 → @4), la figure.
func test_world_b_cases() -> void:
	var day: DayDef = data.get_epilogue_day(&"b")
	for s: int in SEEDS:
		var cases: Dictionary = _play(_builder(day, s, [&"final3_dora", &"final3_passed", &"hh_dora_alive"]))
		assert_eq((cases[&"sc_94a"] as GeneratedCase).key.expected_verdict, VK.DENY)
		assert_eq((cases[&"sc_95"] as GeneratedCase).key.expected_verdict, VK.APPROVE, "répondant admis juste devant")
		assert_eq((cases[&"sc_96a"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		var mira: Dictionary = _play(_builder(day, s, []))
		var figure: GeneratedCase = mira[&"sc_96b"]
		assert_eq(figure.key.expected_verdict, VK.APPROVE)
		assert_true(figure.visor_down, "visière baissée")
		var freed: Dictionary = _play(_builder(day, s, [&"final3_detained"]))
		assert_eq((freed[&"sc_96d"] as GeneratedCase).key.expected_verdict, VK.APPROVE)


## Monde C : Lindgren, la chaîne Okafor → Elena, la figure convoquée.
func test_world_c_cases() -> void:
	var day: DayDef = data.get_epilogue_day(&"c")
	for s: int in SEEDS:
		var cases: Dictionary = _play(_builder(day, s, [&"final3_dora", &"hh_dora_alive"]))
		assert_eq((cases[&"sc_90"] as GeneratedCase).key.expected_verdict, VK.APPROVE, "convoqué·e du Bureau des Témoins")
		assert_eq((cases[&"sc_97"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((cases[&"sc_98"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((cases[&"sc_99"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		assert_eq((cases[&"sc_100a"] as GeneratedCase).key.expected_verdict, VK.APPROVE, "convocation authentique (R36)")
		# Okafor refusée : Elena n'a plus de répondant (R34, R37).
		var builder: CaseBuilder = _builder(day, s, [])
		for i: int in 4:
			var g: GeneratedCase = builder.build(i)
			builder.record_verdict(g.case, VK.DENY if g.scripted_id == &"sc_98" else g.key.expected_verdict)
		var elena: GeneratedCase = builder.build(4)
		assert_eq(elena.scripted_id, &"sc_99")
		assert_eq(elena.key.expected_verdict, VK.DENY)
		assert_eq((_play(_builder(day, s, []))[&"sc_100b"] as GeneratedCase).key.expected_verdict, VK.APPROVE)


## Monde D : Dmitri (Dispensaire), Wren (bio-scan de 40 jours), Mira.
func test_world_d_cases() -> void:
	var day: DayDef = data.get_epilogue_day(&"d")
	for s: int in SEEDS:
		var cases: Dictionary = _play(_builder(day, s, [&"exit3_drift"]))
		assert_eq((cases[&"sc_101"] as GeneratedCase).key.expected_verdict, VK.APPROVE)
		var wren: GeneratedCase = cases[&"sc_102"]
		assert_eq(wren.key.expected_verdict, VK.DENY)
		assert_eq(day.game_date - wren.case.get_own_document(&"bioscan").issue_date, 40, "émis il y a 40 jours")
		assert_eq(wren.case.line_overrides.get("arrival", ""), "sc102_wren_arrival_drift")
		var mira: GeneratedCase = cases[&"sc_103"]
		assert_eq(mira.key.expected_verdict, VK.APPROVE)
		assert_true(mira.visor_down)
		assert_eq(mira.case.get_own_document(&"bioscan").issuer_id, &"dispensaire_tycho")
		assert_false(mira.case.has_own_document(&"entry_permit"), "Tycho ne délivre pas de permis")


## Échos (M12 §4) : présents seulement si leur déclencheur est vrai, sur un
## index libre, verdict attendu conforme ; sinon passager généré.
func test_echoes_appear_on_their_trigger_with_expected_verdicts() -> void:
	# `[jour, cas, drapeaux, attendu (APPROVE = aucune violation hors quota)]`.
	var specs: Array[Array] = [
		[4, &"sc_84a", [&"cm_sc_03_deny"], VK.APPROVE],
		[11, &"sc_85a", [&"cm_tuto_missing_document_deny"], VK.APPROVE],
		[11, &"sc_85b", [&"cm_tuto_missing_document_approve"], VK.APPROVE],
		[12, &"sc_87", [&"cm_sc_15_deny"], VK.APPROVE],
		[12, &"sc_83b", [&"cm_sc_01_deny"], VK.APPROVE],
		[13, &"sc_89a", [&"sc18_note_reported"], VK.DENY],
		[13, &"sc_89b", [&"sc18_note_kept"], VK.APPROVE],
		[14, &"sc_86b", [&"sc14_passed"], VK.DENY],
		[15, &"sc_86a", [&"cm_sc_14_detain"], VK.APPROVE],
		[16, &"sc_83a", [&"cm_sc_01_approve"], VK.APPROVE],
		[18, &"sc_84b", [&"sc03_passed"], VK.DENY],
		[19, &"sc_88b", [&"sc17_passed"], VK.DETAIN],
		[27, &"sc_88a", [&"sc17_detained"], VK.APPROVE],
	]
	for spec: Array in specs:
		var day: DayDef = data.get_day(spec[0])
		var flags: Array[StringName] = []
		flags.assign(spec[2])
		for s: int in 4:
			var cases: Dictionary = _play(_builder(day, s, flags))
			var label: String = "J%d %s" % [spec[0], spec[1]]
			assert_true(cases.has(spec[1]), label + " présent")
			if not cases.has(spec[1]):
				continue
			var g: GeneratedCase = cases[spec[1]]
			var expected: VerdictKind.Kind = spec[3]
			if expected == VK.APPROVE:
				for violation: Violation in g.key.expected_violations:
					assert_eq(violation.rule_id, &"r_air_quota", "%s : %s" % [label, violation.rule_id])
			else:
				assert_eq(g.key.expected_verdict, expected, label)
		var absent: Dictionary = _play(_builder(day, 0, []))
		assert_false(absent.has(spec[1]), "J%d %s absent sans déclencheur" % [spec[0], spec[1]])
	# SC-89a : le Long-Ruban est retiré du registre ce jour-là seulement.
	var reported: CaseBuilder = _builder(data.get_day(13), 1, [&"sc18_note_reported"])
	assert_false((reported.day.rule_set.get_rule(&"r_drift_pass") as DriftPassRule).is_registered("LONG-RUBAN", reported.ctx.today))
	var kept: CaseBuilder = _builder(data.get_day(13), 1, [&"sc18_note_kept"])
	assert_true((kept.day.rule_set.get_rule(&"r_drift_pass") as DriftPassRule).is_registered("LONG-RUBAN", kept.ctx.today))
	assert_false(data.get_day(13).rule_set.is_shift_copy, "le .tres partagé n'est jamais muté")


func test_echo_indices_are_free() -> void:
	var M12: GDScript = load("res://tools/build_data_m12.gd")
	for n: int in data.days:
		var day: DayDef = data.get_day(n)
		var seen: Dictionary[int, StringName] = {}
		for scripted: ScriptedCaseDef in day.scripted_cases:
			if not String(scripted.id).begins_with("sc_8") or String(scripted.id) < "sc_83":
				continue
			var copy: DayDef = day.duplicate() as DayDef
			copy.scripted_cases = []
			for other: ScriptedCaseDef in day.scripted_cases:
				if other.at_index != scripted.at_index:
					copy.scripted_cases.append(other)
			assert_eq(M12.call("check_free_index", copy, scripted.at_index, scripted.id), "", "J%d %s" % [n, scripted.id])
			seen[scripted.at_index] = scripted.id
	assert_eq(data.get_day(12).get_scripted_case(14).id, &"sc_83b")
	assert_eq(data.get_day(18).get_scripted_case(11).id, &"sc_84b")


func test_garde_units_and_tiers() -> void:
	var g: GardeDef = data.garde
	assert_eq(g.units.size(), 24, "U01 → U20 (M12) + U21 → U24 (M13)")
	var tiers: Dictionary[int, int] = {}
	for unit: GardeUnitDef in g.units:
		tiers[unit.tier] = tiers.get(unit.tier, 0) + 1
		assert_false(unit.rules.is_empty(), String(unit.id))
		for rule: Rule in unit.rules:
			var shared: Rule = data.rules[rule.id]
			if rule is StatementsConsistentRule and (rule as StatementsConsistentRule).tier > 1:
				shared = data.rule_tiers["%s@%d" % [rule.id, (rule as StatementsConsistentRule).tier]]
			assert_same(rule, shared, "%s : règle partagée" % unit.id)
			assert_false(String(rule.id).begins_with("r_ep_"), "pas de règle de l'épilogue")
			assert_false(rule.id in [&"r_air_quota", &"r_curfew", &"r_ter_closed"], "exclues (M12 §2.3)")
		for prerequisite: StringName in unit.prerequisites:
			assert_not_null(g.get_unit(prerequisite), "%s → %s" % [unit.id, prerequisite])
	assert_eq(tiers, {1: 5, 2: 7, 3: 12} as Dictionary[int, int], "M13 : U21 au tier 2, U22 → U24 au tier 3")
	assert_true(g.get_unit(&"u11").enables_detain)
	assert_eq(g.get_unit(&"u15").renews_lists, PackedStringArray(["wanted"]))
	assert_eq(g.get_unit(&"u20").renews_lists, PackedStringArray(["revoked"]))
	assert_eq(g.tiers.size(), 5)
	assert_eq(g.tiers[4].from_passenger, 101)
	assert_true(g.tiers[4].rotation)
	assert_eq(g.day_template.rule_set.get_rule_ids(), [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match",
			&"r_identity_fields_match"] as Array[StringName], "socle R01, R02, R03, R07")
	assert_eq(g.day_template.mode, DayDef.MODE_GARDE)
	var total: float = 0.0
	for weight: float in g.day_template.faction_weights.values():
		total += weight
	assert_almost_eq(total, 1.0, 0.001, "origines TYC .25 / HAL .20 / TER .20 / CER .15 / THR .12 / DRV .08")


func test_station_events() -> void:
	var def: StationEventsDef = data.station_events
	assert_eq(def.events.size(), 9, "EV-01 → EV-08 (M12) + EV-09 (M13)")
	assert_eq(def.eligible_days.size(), 18)
	for excluded: int in [1, 2, 3, 9, 10, 11, 17, 20, 21, 24, 29, 30]:
		assert_false(def.eligible_days.has(excluded), "J%d exclu" % excluded)
	for day_number: int in [4, 5, 7, 12, 13, 15, 16, 26]:
		assert_eq(def.eligible_days[day_number], StationEventsDef.CLASS_A, "J%d : classe A seulement" % day_number)
	var classes: Dictionary[StringName, int] = {}
	for event: StationEventDef in def.events:
		classes[event.id] = int(event.event_class)
		assert_false(event.announce_key.is_empty() or event.title_key.is_empty(), String(event.id))
	assert_eq(classes, {&"ev_01": 1, &"ev_02": 2, &"ev_03": 2, &"ev_04": 1, &"ev_05": 1, &"ev_06": 1, &"ev_07": 2,
			&"ev_08": 1, &"ev_09": 1} as Dictionary[StringName, int])
	assert_false((data.events[&"ev_06"] as StationEventDef).garde_allowed, "EV-06 hors Garde")
	assert_eq((data.events[&"ev_07"] as StationEventDef).list_size, 3)


func test_character_table() -> void:
	var table: CharacterTableDef = data.characters
	assert_eq(table.characters.size(), 44)
	var known_ids: Dictionary[StringName, bool] = {}
	for n: int in data.days:
		for scripted: ScriptedCaseDef in data.get_day(n).scripted_cases:
			known_ids[scripted.id] = true
	for world: StringName in data.epilogue_days:
		for scripted: ScriptedCaseDef in data.get_epilogue_day(world).scripted_cases:
			known_ids[scripted.id] = true
	var used: Dictionary[StringName, StringName] = {}
	var chr_ids: Dictionary[StringName, bool] = {}
	for c: CharacterDef in table.characters:
		assert_false(chr_ids.has(c.id), "%s en double" % c.id)
		chr_ids[c.id] = true
		assert_true(String(c.id).begins_with("chr_"))
		for case_id: StringName in c.case_ids:
			assert_true(known_ids.has(case_id), "%s : cas inconnu %s" % [c.id, case_id])
			assert_false(used.has(case_id), "%s dans %s et %s" % [case_id, used.get(case_id, &""), c.id])
			used[case_id] = c.id
	assert_eq(table.character_of(&"sc_84b").id, &"chr_titulaire")
	assert_eq(table.character_of(&"sc_103").id, &"chr_mira")
	assert_null(table.character_of(&"sc_93d"), "porteur généré du mot : personne")
	var arkady: CharacterDef = table.character_of(&"sc_20")
	assert_false(arkady.is_name_known({}), "« Bastien Duval » tant que rien n'est appris")
	assert_true(arkady.is_name_known({&"sc20_detained": true}))
	assert_true(arkady.is_name_known({}, true), "nom appris dès une fin vue")


## Toutes les clés de texte des données M12 existent dans `fr.csv` ; répliques
## ≤ 90 caractères, Tessar entre chevrons équilibrés.
func test_every_m12_text_key_exists() -> void:
	var keys: PackedStringArray = []
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		var day: DayDef = data.get_epilogue_day(world)
		keys.append_array(["day31_%s_directive_title" % world, "day31_%s_slogan" % world, day.intro_text_key])
		_collect_day_keys(day, keys)
	for n: int in data.days:
		var day: DayDef = data.get_day(n)
		for scripted: ScriptedCaseDef in day.scripted_cases:
			if String(scripted.id) >= "sc_83":
				_collect_case_keys(scripted, keys)
		for message: BriefingMessageDef in day.briefing_messages:
			if message.text_key.contains("day16_tech"):
				keys.append(message.text_key)
		for revocation: RevocationDef in day.revocations:
			if not revocation.reason_key.is_empty():
				keys.append(revocation.reason_key)
	var def: EpilogueDef = data.epilogue
	keys.append_array([def.title_key, def.tally_key])
	for list: Array[ConditionalKey] in [def.first_lines, def.home_lines]:
		for line: ConditionalKey in list:
			keys.append(line.key)
	for world: EpilogueWorldDef in def.worlds:
		keys.append_array([world.eyebrow_key, world.name_key])
		for group: EpilogueLineGroupDef in world.line_groups:
			for line: ConditionalKey in group.lines:
				keys.append(line.key)
		for line: ConditionalKey in world.farewell_lines:
			keys.append(line.key)
	for ending: EpilogueEndingDef in def.endings:
		keys.append_array([ending.open_key, ending.close_key, ending.intro_key])
		for line: ConditionalKey in ending.home_lines:
			keys.append(line.key)
	for event: StationEventDef in data.events.values():
		keys.append_array([event.announce_key, event.title_key, event.rulebook_key, event.end_key, event.garde_announce_key])
		for change: RuleChangeDef in event.changes:
			if change.rule != null:
				keys.append_array([change.rule.title_key, change.rule.rulebook_text_key])
	for unit: GardeUnitDef in data.garde.units:
		keys.append(unit.title_key)
	for tier: GardeTierDef in data.garde.tiers:
		keys.append(tier.name_key)
	keys.append(data.garde.day_template.intro_text_key)
	for c: CharacterDef in data.characters.characters:
		keys.append_array([c.display_name, c.blurb_key, c.true_name])
	for rule_id: StringName in [&"r_ep_tycho_ka", &"r_ep_welcome", &"r_ep_council_list", &"r_ep_issuer_tycho", &"r_ep_ka_cadres"]:
		keys.append_array([(data.rules[rule_id] as Rule).title_key, (data.rules[rule_id] as Rule).rulebook_text_key])
	keys.append_array(["doc_sponsor_card_title", "issuer_dispensaire_tycho", "issuer_conseil_air", "rb_tab_council",
			"rb_col_council_reinstated", "rb_tab_stolen"])
	for n: int in range(1, 11):
		keys.append_array(["dos_end_hint1_f%d" % n, "dos_end_hint2_f%d" % n])
	for flag: StringName in EndingService.TRACE_FLAGS:
		if String(flag).begins_with("sc8"):
			keys.append("end_trace_%s" % flag)
	var missing: PackedStringArray = []
	for key: String in keys:
		if not key.is_empty() and not UiText.has(key) and not missing.has(key):
			missing.append(key)
	assert_eq(missing, PackedStringArray(), "clés M12 absentes de fr.csv")
	var too_long: PackedStringArray = []
	var unbalanced: PackedStringArray = []
	var line_key: RegEx = RegEx.create_from_string("^sc(8[3-9]|9[0-9]|10[0-3])_[a-z0-9_]+$")
	var non_line: RegEx = RegEx.create_from_string("(note|label|desc|title|_doc|_item|_form$)")
	var csv: FileAccess = FileAccess.open("res://data/i18n/fr.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() < 2:
			continue
		if line_key.search(row[0]) != null and non_line.search(row[0]) == null and row[1].length() > 90:
			too_long.append("%s (%d)" % [row[0], row[1].length()])
		var m12: bool = line_key.search(row[0]) != null or row[0].begins_with("epi_") or row[0].begins_with("day31_") \
				or row[0].begins_with("sev_") or row[0].begins_with("dos_")
		if m12 and row[1].count("‹") != row[1].count("›"):
			unbalanced.append(row[0])
	assert_eq(too_long, PackedStringArray(), "sous-titres > 90 caractères")
	assert_eq(unbalanced, PackedStringArray(), "chevrons Tessar déséquilibrés")


func _collect_day_keys(day: DayDef, keys: PackedStringArray) -> void:
	for scripted: ScriptedCaseDef in day.scripted_cases:
		_collect_case_keys(scripted, keys)
	for message: BriefingMessageDef in day.briefing_messages:
		keys.append_array([message.text_key, message.speaker_key])
	for notice: WantedNoticeDef in day.wanted_notices:
		keys.append(notice.reason_key)
	for revocation: RevocationDef in day.revocations:
		keys.append(revocation.reason_key)
	for summons: SummonsDef in day.summons:
		keys.append(summons.reason_key)


func _collect_case_keys(scripted: ScriptedCaseDef, keys: PackedStringArray) -> void:
	for variant: ConditionalKey in scripted.line_variants:
		keys.append(variant.key)
	if scripted.slipped_item != null:
		keys.append_array([scripted.slipped_item.label_key, scripted.slipped_item.text_key])
	if scripted.dialogue_id != &"":
		keys.append("%s_arrival" % scripted.dialogue_id)
