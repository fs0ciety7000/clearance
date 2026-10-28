## Tests GameState : nouvelle campagne, crédits, drapeaux (instance isolée).
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")

var _state: Node


func before_each() -> void:
	_state = autofree(GameStateScript.new())


func test_new_campaign_resets_state() -> void:
	_state.set(&"credits", 50)
	_state.call(&"new_campaign", 1234)
	assert_eq(_state.get(&"campaign_seed"), 1234)
	assert_eq(_state.get(&"current_day"), 1)
	assert_eq(_state.get(&"credits"), 0)


func test_random_campaign_seed_is_non_zero() -> void:
	_state.call(&"new_campaign")
	assert_ne(_state.get(&"campaign_seed"), 0)


func test_day_seed_is_deterministic() -> void:
	_state.call(&"new_campaign", 42)
	assert_eq(_state.call(&"get_day_seed"), SeededRng.day_seed(42, 1))


func test_add_credits_emits() -> void:
	watch_signals(EventBus)
	_state.call(&"add_credits", 10)
	assert_eq(_state.get(&"credits"), 10)
	assert_signal_emitted_with_parameters(EventBus, "credits_changed", [10, 10])


func test_flags() -> void:
	watch_signals(EventBus)
	_state.call(&"set_flag", &"met_okonkwo", true)
	assert_true(_state.call(&"has_flag", &"met_okonkwo"))
	assert_eq(_state.call(&"get_flag", &"met_okonkwo"), true)
	assert_signal_emit_count(EventBus, "narrative_flag_changed", 1)
	_state.call(&"set_flag", &"met_okonkwo", true)
	assert_signal_emit_count(EventBus, "narrative_flag_changed", 1)


func test_record_day_advances() -> void:
	_state.call(&"new_campaign", 1)
	_state.call(&"record_day", 8, 2, 40)
	assert_eq(_state.get(&"current_day"), 2)
	var history: Array[Dictionary] = _state.get(&"day_history")
	assert_eq(history.size(), 1)
