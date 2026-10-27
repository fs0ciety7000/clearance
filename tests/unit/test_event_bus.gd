## Tests EventBus : le catalogue ARCHITECTURE §7 (rév. 2) est complet.
extends GutTest

## Nom du signal → nombre d'arguments attendu.
const EXPECTED_SIGNALS: Dictionary = {
	# Jour
	&"day_started": 2,
	&"day_clock_ticked": 1,
	&"day_time_expired": 0,
	&"day_ended": 1,
	&"day_phase_changed": 2,
	# Passager
	&"next_case_requested": 0,
	&"case_presented": 1,
	&"passenger_arrived": 1,
	&"documents_presented": 1,
	&"document_focused": 1,
	&"passenger_reaction_triggered": 1,
	&"passenger_departed": 1,
	&"inspection_target_picked": 1,
	# Inspection / comparaison
	&"inspection_mode_changed": 1,
	&"discrepancy_check_requested": 2,
	&"discrepancy_checked": 1,
	&"interrogation_requested": 1,
	&"interrogation_answered": 2,
	# Verdict / score
	&"verdict_stamped": 1,
	&"case_resolved": 2,
	&"citation_issued": 1,
	&"credits_changed": 2,
	# Méta
	&"narrative_flag_changed": 2,
	&"settings_changed": 2,
	&"game_saved": 1,
	&"game_loaded": 1,
	# M7 : objets glissés, avis de recherche, annonces du Hall.
	&"item_slipped": 1,
	&"item_decision_requested": 2,
	&"item_decided": 2,
	&"wanted_notices_published": 1,
	&"hall_announced": 1,
}


func _script_signals() -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	var script: Script = EventBus.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var args: Array = info["args"]
		found[StringName(info["name"])] = args.size()
	return found


func test_all_expected_signals_exist_with_arity() -> void:
	for signal_name: StringName in EXPECTED_SIGNALS:
		assert_has_signal(EventBus, signal_name)
	var found: Dictionary[StringName, int] = _script_signals()
	for signal_name: StringName in EXPECTED_SIGNALS:
		assert_eq(found.get(signal_name, -1), EXPECTED_SIGNALS[signal_name], "arité de %s" % signal_name)


func test_no_unexpected_signals() -> void:
	var found: Dictionary[StringName, int] = _script_signals()
	for signal_name: StringName in found:
		assert_true(EXPECTED_SIGNALS.has(signal_name), "signal hors catalogue : %s" % signal_name)
	assert_eq(found.size(), EXPECTED_SIGNALS.size())


func test_removed_signal_absent() -> void:
	assert_false(EventBus.has_signal(&"document_handed"), "remplacé par documents_presented (D-014)")


func test_event_bus_has_no_state() -> void:
	var script: Script = EventBus.get_script()
	assert_eq(script.get_script_property_list().filter(
		func(p: Dictionary) -> bool: return (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
	).size(), 0, "EventBus ne porte aucun état")


## M2 : les types provisoires sont remplacés par les classes du modèle.
func test_model_types_resolved_in_m2() -> void:
	var expected: Dictionary = {
		&"day_started": ["DayDef", "Array"],
		&"case_presented": ["Case"],
		&"document_focused": ["DocumentInstance"],
		&"inspection_target_picked": ["FieldRef"],
		&"discrepancy_check_requested": ["FieldRef", "FieldRef"],
		&"discrepancy_checked": ["Discrepancy"],
		&"verdict_stamped": ["Verdict"],
	}
	var script: Script = EventBus.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var signal_name: StringName = str(info["name"])
		if not expected.has(signal_name):
			continue
		var args: Array = info["args"]
		var classes: Array = expected[signal_name]
		for i: int in classes.size():
			var arg: Dictionary = args[i]
			var arg_type: int = arg["type"]
			var actual: String = str(arg["class_name"]) if classes[i] != "Array" else type_string(arg_type)
			var wanted: String = classes[i]
			assert_eq(actual, wanted, "%s arg %d" % [signal_name, i])
