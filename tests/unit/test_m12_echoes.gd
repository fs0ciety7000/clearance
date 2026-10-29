## M12 lot A — échos (B59, D-130, ARCHITECTURE §11.9) : pseudo-drapeaux de
## verdict `cm_<cas>_<verdict>` dérivés de `CaseMemory` (lecture seule, au
## matin, jamais sauvegardés), visage de la photo mémorisé.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")


var _saved_state: Dictionary = {}
var _saved_slot: int = SaveService.DEFAULT_SLOT


func before_all() -> void:
	_saved_state = GameState.to_save_dict()
	_saved_slot = GameState.active_slot


## L'autoload retrouve exactement son état d'avant la suite.
func after_each() -> void:
	GameState.apply_save_dict(_saved_state)
	GameState.active_slot = _saved_slot


func test_pseudo_flags_from_known_verdicts_only() -> void:
	var memory: Dictionary = {
		"sc_03": {"day": 2, "verdict": "deny"},
		"tuto_missing_document": {"day": 1, "verdict": "approve"},
		"sc_14": {"day": 7, "verdict": "detain"},
		"sc_04": {"day": 3, "verdict": "", "recalled": true},
		"broken": "x",
	}
	var flags: Dictionary[StringName, Variant] = CaseMemory.pseudo_flags(memory)
	assert_eq(flags.size(), 3, "verdicts connus seulement")
	assert_true(FlagCondition.is_flag_true(flags, &"cm_sc_03_deny"))
	assert_true(FlagCondition.is_flag_true(flags, &"cm_tuto_missing_document_approve"))
	assert_true(FlagCondition.is_flag_true(flags, &"cm_sc_14_detain"))
	assert_false(flags.has(&"cm_sc_03_approve"))
	assert_eq(CaseMemory.pseudo_flag("sc_01", "deny"), &"cm_sc_01_deny")
	var real: Dictionary[StringName, Variant] = {&"cm_sc_03_deny": false, &"loyalty": 2}
	var merged: Dictionary[StringName, Variant] = CaseMemory.with_pseudo_flags(real, memory)
	assert_false(FlagCondition.is_flag_true(merged, &"cm_sc_03_deny"), "un vrai drapeau l'emporte")
	assert_true(FlagCondition.is_flag_true(merged, &"cm_sc_14_detain"))
	assert_eq(real.size(), 2, "drapeaux d'origine intacts")
	var condition: FlagCondition = FlagCondition.make([&"cm_sc_14_detain"] as Array[StringName])
	assert_true(condition.evaluate(merged), "lisible par FlagCondition")
	assert_true(CaseMemory.pseudo_flag_names(memory).has(&"cm_sc_03_deny"))


func test_snapshot_remembers_photo_only_when_it_differs() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	c.index = 3
	var entry: Dictionary = CaseMemory.snapshot(2, c, VerdictKind.Kind.APPROVE)
	assert_false(entry.has("photo_appearance"), "photo = visage du porteur")
	assert_null(CaseMemory.photo_appearance_of(entry))
	var overrides: Dictionary[StringName, StringName] = {&"face": &"face_09", &"hair": &"hair_11"}
	var other: PassengerAppearance = c.passenger_presented.appearance.derive(overrides)
	for field: FieldDef in c.documents[0].type_def.fields:
		if field.kind == FieldDef.FieldKind.PORTRAIT:
			c.documents[0].values[field.id] = PortraitValue.new(other, 3, 1)
	entry = CaseMemory.snapshot(2, c, VerdictKind.Kind.APPROVE)
	assert_true(entry.has("photo_appearance"), "SC-03 : la photo est celle du titulaire")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(entry))
	assert_true(CaseMemory.photo_appearance_of(restored).equals(other), "aller-retour JSON")
	assert_eq(entry["verdict"], "approve")


func test_day_controller_feeds_pseudo_flags_to_the_generator() -> void:
	GameState.new_campaign(31337, SaveService.DEFAULT_SLOT)
	GameState.current_day = 4
	GameState.remember_case(&"sc_03", {"day": 2, "verdict": "deny"})
	var h: DayHarness = DayHarness.new()
	h.setup(self, null, 4)
	var values: Dictionary[StringName, Variant] = h.controller.builder.get_flag_values()
	assert_true(FlagCondition.is_flag_true(values, &"cm_sc_03_deny"), "conditions des cas : pseudo-drapeau lisible")
	assert_true(h.controller.builder.flags.has(&"cm_sc_03_deny"), "requires_flag : pseudo-drapeau vrai")
	assert_false(GameState.has_flag(&"cm_sc_03_deny"), "jamais écrit dans les drapeaux de la partie")
	assert_false(GameState.to_save_dict()["narrative_flags"].has("cm_sc_03_deny"), "jamais sauvegardé")
	h.teardown()
