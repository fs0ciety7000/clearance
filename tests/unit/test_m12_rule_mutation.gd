## M12 lot A — règles mutables en cours de shift (B54, ARCHITECTURE §11.3) :
## copie de shift, ajout / retrait / oubli / rétablissement, annulation par
## source, surcharges à portée, modificateurs, mise en attente (effet au
## passager suivant, D-077), jamais de mutation des ressources partagées.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")


func _base() -> RuleSet:
	return CaseFactory.rule_set_of([&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match",
			&"r_identity_fields_match"])


func test_shared_rule_set_refuses_changes_and_copy_is_isolated() -> void:
	var shared: RuleSet = _base()
	var before: Array[StringName] = shared.get_rule_ids()
	var refused: RuleDiff = shared.apply_changes([RuleChangeDef.retire(&"r_portrait_match")], &"x")
	assert_push_error("copie de shift")
	assert_true(refused.is_empty(), "un RuleSet partagé n'est jamais muté")
	var copy: RuleSet = shared.make_shift_copy()
	assert_true(copy.is_shift_copy)
	copy.apply_changes([RuleChangeDef.add(CaseFactory.rule(&"r_mrz_valid")), RuleChangeDef.retire(&"r_portrait_match")], &"s")
	assert_eq(shared.get_rule_ids(), before, "l'original est intact")
	assert_true(shared.retired_rules.is_empty())
	assert_true(copy.has_rule(&"r_mrz_valid"))
	assert_false(copy.has_rule(&"r_portrait_match"))


func test_add_retire_forget_restore_and_rulebook() -> void:
	var rs: RuleSet = _base().make_shift_copy()
	var diff: RuleDiff = rs.apply_changes([RuleChangeDef.add(CaseFactory.rule(&"r_mrz_valid"))], &"dir_1")
	assert_eq(diff.added, [&"r_mrz_valid"] as Array[StringName])
	assert_eq(rs.new_rule_ids, [&"r_mrz_valid"] as Array[StringName], "badge NOUVEAU")
	assert_eq(diff.rulebook.size(), 5)
	assert_true(diff.rulebook[4].is_new)
	# Une nouvelle directive remplace le badge.
	rs.apply_changes([RuleChangeDef.add(CaseFactory.rule(&"r_seals_valid"))], &"dir_2")
	assert_eq(rs.new_rule_ids, [&"r_seals_valid"] as Array[StringName])
	# Retrait : ligne barrée avec motif.
	diff = rs.apply_changes([RuleChangeDef.retire(&"r_portrait_match", "rb_retired_quais")], &"rot")
	assert_eq(diff.retired, [&"r_portrait_match"] as Array[StringName])
	assert_eq(diff.retired_entries.size(), 1)
	assert_eq(diff.retired_entries[0].note_key, "rb_retired_quais")
	assert_true(diff.retired_entries[0].retired)
	# Oubli : la ligne barrée disparaît.
	diff = rs.apply_changes([RuleChangeDef.forget(&"r_portrait_match")], &"rot_forget")
	assert_eq(diff.forgotten, [&"r_portrait_match"] as Array[StringName])
	assert_true(diff.retired_entries.is_empty())
	# Rétablissement à sa place d'origine (3ᵉ règle du socle).
	diff = rs.apply_changes([RuleChangeDef.restore(&"r_portrait_match")], &"restore")
	assert_eq(diff.restored, [&"r_portrait_match"] as Array[StringName])
	assert_eq(rs.get_rule_ids().find(&"r_portrait_match"), 2, "remis à sa place")
	# Sans effet : non journalisé.
	diff = rs.apply_changes([RuleChangeDef.add(CaseFactory.rule(&"r_mrz_valid")), RuleChangeDef.retire(&"r_absent")], &"noop")
	assert_true(diff.is_empty())
	assert_false(rs.active_sources().has(&"noop"))


func test_revert_source_undoes_only_that_source() -> void:
	var rs: RuleSet = _base().make_shift_copy()
	var ids_before: Array[StringName] = rs.get_rule_ids()
	rs.apply_changes([RuleChangeDef.add(CaseFactory.rule(&"r_mrz_valid"))], &"garde_dir_1")
	rs.apply_changes([RuleChangeDef.retire(&"r_mrz_valid", "sev_mrz_reader_rb"),
			RuleChangeDef.retire(&"r_identity_fields_match"),
			RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)], &"ev_01@g20")
	assert_false(rs.has_rule(&"r_mrz_valid"))
	assert_eq(rs.get_modifier(RuleChangeDef.MOD_COMPARATOR_DOWN), 1)
	var diff: RuleDiff = rs.revert_source(&"ev_01@g20")
	assert_true(diff.restored.has(&"r_mrz_valid") and diff.restored.has(&"r_identity_fields_match"))
	assert_true(rs.has_rule(&"r_mrz_valid"), "la directive reste en vigueur")
	assert_eq(rs.get_modifier(RuleChangeDef.MOD_COMPARATOR_DOWN), 0)
	assert_true(rs.retired_rules.is_empty(), "plus de ligne barrée")
	rs.revert_source(&"garde_dir_1")
	assert_eq(rs.get_rule_ids(), ids_before, "retour au socle")
	assert_true(rs.active_sources().is_empty())


func test_override_scope_by_origin_purpose_and_time() -> void:
	var rs: RuleSet = _base().make_shift_copy()
	var params: Dictionary[StringName, Variant] = {&"max_age_days": 7}
	rs.apply_changes([RuleChangeDef.override(&"r_bioscan_valid", params, [&"tyc"])], &"ev_03")
	assert_eq(rs.get_param(&"r_bioscan_valid", &"max_age_days", 30, &"tyc"), 7)
	assert_eq(rs.get_param(&"r_bioscan_valid", &"max_age_days", 30, &"hal"), 30, "autre origine")
	var exempt: Dictionary[StringName, Variant] = {&"exempt_purposes": [&"transit"]}
	rs.apply_changes([RuleChangeDef.override(&"r_bioscan_required", exempt, [], [&"transit"], 780, 840)], &"ev_08")
	assert_eq(rs.get_param(&"r_bioscan_required", &"exempt_purposes", [], &"tyc", &"transit", 779), [])
	assert_eq(rs.get_param(&"r_bioscan_required", &"exempt_purposes", [], &"tyc", &"transit", 780), [&"transit"])
	assert_eq(rs.get_param(&"r_bioscan_required", &"exempt_purposes", [], &"tyc", &"transit", 840), [], "14:00 exclu")
	assert_eq(rs.get_param(&"r_bioscan_required", &"exempt_purposes", [], &"tyc", &"work", 800), [], "autre motif")
	assert_eq(rs.get_param(&"r_bioscan_required", &"exempt_purposes", [], &"tyc", &"transit", -1), [], "heure inconnue")
	# Cas scénarisé : surcharges et modificateurs ignorés.
	rs.apply_changes([RuleChangeDef.modify(RuleChangeDef.MOD_CORRECT_BONUS, 2)], &"ev_04")
	rs.overlay_suspended = true
	assert_eq(rs.get_param(&"r_bioscan_valid", &"max_age_days", 30, &"tyc"), 30)
	assert_eq(rs.get_modifier(RuleChangeDef.MOD_CORRECT_BONUS), 0)
	rs.overlay_suspended = false
	assert_eq(rs.get_modifier(RuleChangeDef.MOD_CORRECT_BONUS), 2)
	rs.revert_source(&"ev_03")
	assert_eq(rs.get_param(&"r_bioscan_valid", &"max_age_days", 30, &"tyc"), 30, "surcharge défaite")


func test_context_queue_applies_on_next_passenger_and_param_reads_case() -> void:
	var ctx: RuleContext = CaseFactory.context(_base())
	var c: Case = CaseFactory.valid_case()
	assert_eq(ctx.param(&"r_bioscan_valid", &"max_age_days", 30, c), 30, "hors copie de shift : défaut")
	var params: Dictionary[StringName, Variant] = {&"max_age_days": 7}
	ctx.queue_changes([RuleChangeDef.override(&"r_bioscan_valid", params, [&"tyc"]),
			RuleChangeDef.add(CaseFactory.rule(&"r_mrz_valid"))], &"ev")
	assert_true(ctx.has_pending_changes())
	assert_false(ctx.rule_set.has_rule(&"r_mrz_valid"), "rien avant le passager suivant")
	var diff: RuleDiff = ctx.apply_pending()
	assert_false(ctx.has_pending_changes())
	assert_true(ctx.rule_set.is_shift_copy, "copie de shift créée à la demande")
	assert_true(diff.added.has(&"r_mrz_valid"))
	assert_true(diff.overridden.has(&"r_bioscan_valid"))
	assert_eq(ctx.param(&"r_bioscan_valid", &"max_age_days", 30, c), 7, "Mira est de Tycho")
	ctx.queue_revert(&"ev")
	ctx.apply_pending()
	assert_eq(ctx.param(&"r_bioscan_valid", &"max_age_days", 30, c), 30)
	assert_false(ctx.rule_set.has_rule(&"r_mrz_valid"))
	# Listes nommées.
	var entry: RevokedEntry = RevokedEntry.new()
	entry.id = &"stolen_1"
	entry.citizen_id = c.passenger_presented.citizen_id
	ctx.set_list(&"stolen", [entry] as Array[RevokedEntry])
	assert_true(ctx.is_listed(&"stolen", c.passenger_presented.citizen_id))
	assert_false(ctx.is_revoked(c.passenger_presented.citizen_id), "pas l'onglet Révocations")
	ctx.set_list(&"stolen", [] as Array[RevokedEntry])
	assert_true(ctx.get_list(&"stolen").is_empty())


func test_rule_engine_sees_mutation_and_shared_day_is_untouched() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var source: DayDef = data.get_day(3)
	var shared_ids: Array[StringName] = source.rule_set.get_rule_ids()
	var day: DayDef = source.make_shift_copy()
	assert_ne(day, source)
	assert_ne(day.rule_set, source.rule_set)
	var ctx: RuleContext = RuleContext.for_day(day, data.factions, data.documents)
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	c.documents[1].expiry_date = CaseFactory.today() - 2
	ctx.today = CaseFactory.today()
	var violated: Array[StringName] = CaseFactory.violated_ids(RuleEngine.validate(c, ctx.rule_set, ctx))
	assert_true(violated.has(&"r_permit_valid"), "permis expiré")
	ctx.apply_changes([RuleChangeDef.retire(&"r_permit_valid")], &"t")
	violated = CaseFactory.violated_ids(RuleEngine.validate(c, ctx.rule_set, ctx))
	assert_false(violated.has(&"r_permit_valid"), "règle retirée : plus évaluée")
	assert_eq(source.rule_set.get_rule_ids(), shared_ids, "le jour des données n'a pas bougé")
	day.passenger_count += 3
	assert_ne(day.passenger_count, source.passenger_count)


func test_day_controller_applies_pending_changes_at_presentation() -> void:
	var h: DayHarness = DayHarness.new()
	await h.setup(self, null, 3)
	var dc: DayController = h.controller
	assert_true(dc.day.rule_set.is_shift_copy, "le shift travaille sur une copie")
	assert_eq(dc.builder.ctx.rule_set, dc.day.rule_set, "générateur et moteur lisent le même RuleSet")
	assert_ne(dc.day, CaseFactory.catalog().get_day(3))
	var diffs: Array[RuleDiff] = []
	var on_changed: Callable = func(diff: RuleDiff) -> void: diffs.append(diff)
	EventBus.rules_changed.connect(on_changed)
	dc.close_intro()
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	var first: Case = dc.current_case
	# Changement en attente pendant que le passager est à la vitre.
	dc.builder.ctx.queue_changes([RuleChangeDef.retire(&"r_permit_valid", "rb_test")], &"test_src")
	assert_true(dc.day.rule_set.has_rule(&"r_permit_valid"), "rien ne change pour le passager à la vitre")
	assert_true(diffs.is_empty())
	EventBus.verdict_stamped.emit(Verdict.new(first.case_id, VerdictKind.Kind.APPROVE))
	EventBus.passenger_departed.emit(first.case_id)
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	assert_eq(diffs.size(), 1, "appliqué juste avant le passager suivant")
	assert_true(diffs[0].retired.has(&"r_permit_valid"))
	assert_false(dc.day.rule_set.has_rule(&"r_permit_valid"))
	assert_true(CaseFactory.catalog().get_day(3).rule_set.has_rule(&"r_permit_valid"), "données intactes")
	EventBus.rules_changed.disconnect(on_changed)
	h.teardown()
