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
	assert_eq(keys.size(), 13)
	assert_has(keys, &"audio_mono", "mode mono (docs/AUDIO.md §9, M6)")
	assert_has(keys, &"graphics_quality", "qualité graphique du guichet (M9)")


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


func test_graphics_quality_defaults_to_auto_and_snaps() -> void:
	var expected: Array[Array] = [[1.4, 1.0], [7, 2.0], [-3.0, -1.0], [0.0, 0.0]]
	var quality: float = _value(&"graphics_quality")
	assert_eq(quality, -1.0, "Auto par défaut")
	for pair: Array in expected:
		_set_no_persist(&"graphics_quality", pair[0])
		quality = _value(&"graphics_quality")
		var wanted: float = pair[1]
		assert_eq(quality, wanted)
	var level: int = _settings.call(&"graphics_quality_level")
	assert_eq(level, 0)


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


## QA-006 : une valeur de session n'est jamais écrite ; un choix du joueur
## (même différé) l'est, et remplace la valeur de session.
func test_session_value_is_never_persisted() -> void:
	var path: String = "user://test_settings/unit_settings.cfg"
	_settings.set(&"settings_path", path)
	_settings.call(&"set_session_value", &"reduce_motion", true)
	var current: bool = _value(&"reduce_motion")
	assert_true(current)
	_settings.call(&"save_settings")
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(path)
	var stored: bool = cfg.get_value("settings", "reduce_motion", true)
	assert_false(stored, "valeur persistée inchangée")
	_settings.call(&"clear_session_value", &"reduce_motion")
	current = _value(&"reduce_motion")
	assert_false(current, "retour à la valeur persistée")
	_settings.call(&"set_session_value", &"reduce_motion", true)
	_settings.call(&"set_value", &"reduce_motion", true)
	var session: bool = _settings.call(&"is_session_value", &"reduce_motion")
	assert_false(session, "choix du joueur")
	cfg.load(path)
	stored = cfg.get_value("settings", "reduce_motion", false)
	assert_true(stored, "choix du joueur persisté")
	DirAccess.remove_absolute(path)
