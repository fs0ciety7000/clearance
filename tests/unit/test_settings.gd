## Tests Settings : valeurs par défaut et validation (sans toucher user://).
extends GutTest

const SettingsScript: GDScript = preload("res://scripts/autoload/settings.gd")

var _settings: Node


func before_each() -> void:
	# Instance neuve hors de l'arbre : `_ready` (lecture du fichier) n'est pas appelé.
	_settings = autofree(SettingsScript.new())


func _value(key: StringName) -> Variant:
	return _settings.call(&"get_value", key)


func _set_no_persist(key: StringName, value: Variant) -> bool:
	return _settings.call(&"set_value", key, value, false)


func test_default_values() -> void:
	assert_eq(_value(&"volume_master"), 1.0)
	assert_eq(_value(&"volume_music"), 0.8)
	assert_eq(_value(&"volume_ambience"), 0.8)
	assert_eq(_value(&"volume_sfx"), 1.0)
	assert_eq(_value(&"volume_voice"), 1.0)
	assert_eq(_value(&"volume_ui"), 1.0)
	assert_eq(_value(&"fx_intensity"), 1.0)
	assert_eq(_value(&"reduce_motion"), false)
	assert_eq(_value(&"text_scale"), 1.0)
	assert_eq(_value(&"subtitles"), true, "sous-titres ON par défaut (AUDIO.md)")
	assert_eq(_value(&"clock_slow_accessibility"), false)


func test_expected_key_set() -> void:
	var keys: Array[StringName] = _settings.call(&"get_keys")
	assert_eq(keys.size(), 12)
	assert_has(keys, &"audio_mono", "mode mono (docs/AUDIO.md §9, M6)")


func test_typed_properties_read_defaults() -> void:
	assert_eq(_settings.get(&"fx_intensity"), 1.0)
	assert_eq(_settings.get(&"subtitles"), true)
	assert_eq(_settings.get(&"reduce_motion"), false)


func test_fx_intensity_snaps_to_levels() -> void:
	_set_no_persist(&"fx_intensity", 0.6)
	assert_eq(_value(&"fx_intensity"), 0.5)
	_set_no_persist(&"fx_intensity", 0.1)
	assert_eq(_value(&"fx_intensity"), 0.0)
	_set_no_persist(&"fx_intensity", 3)
	assert_eq(_value(&"fx_intensity"), 1.0)


func test_volume_and_text_scale_are_clamped() -> void:
	_set_no_persist(&"volume_sfx", 1.7)
	assert_eq(_value(&"volume_sfx"), 1.0)
	_set_no_persist(&"volume_sfx", -1.0)
	assert_eq(_value(&"volume_sfx"), 0.0)
	_set_no_persist(&"text_scale", 3.0)
	assert_almost_eq(_value(&"text_scale") as float, 1.5, 0.0001)
	_set_no_persist(&"text_scale", 0.5)
	assert_almost_eq(_value(&"text_scale") as float, 0.9, 0.0001)


func test_unknown_key_rejected() -> void:
	assert_false(_set_no_persist(&"does_not_exist", 1))
	assert_push_error_count(1)


func test_settings_changed_emitted() -> void:
	watch_signals(EventBus)
	_set_no_persist(&"subtitles", false)
	assert_signal_emitted_with_parameters(EventBus, "settings_changed", [&"subtitles", false])


func test_no_signal_when_value_unchanged() -> void:
	watch_signals(EventBus)
	_set_no_persist(&"subtitles", true)
	assert_signal_not_emitted(EventBus, "settings_changed")
