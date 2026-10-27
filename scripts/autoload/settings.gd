## Settings — préférences du joueur (ARCHITECTURE §4).
##
## Persistées dans `user://settings.cfg` (`ConfigFile`, section `[settings]`).
## Toute modification passe par `set_value()` (ou les propriétés typées), qui
## valide la valeur, l'applique, la sauvegarde et émet
## `EventBus.settings_changed(key, value)`.
## Les volumes et le mode mono sont appliqués ici aux bus audio
## (`res://default_bus_layout.tres`, docs/AUDIO.md §2) ; les autres réglages
## (taille du texte, effets, animations, sous-titres, horloge) sont appliqués
## par leurs consommateurs à l'écoute de `settings_changed`.
## Pas de `class_name` (autoload).
extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

const KEY_VOLUME_MASTER: StringName = &"volume_master"
const KEY_VOLUME_MUSIC: StringName = &"volume_music"
const KEY_VOLUME_AMBIENCE: StringName = &"volume_ambience"
const KEY_VOLUME_SFX: StringName = &"volume_sfx"
const KEY_VOLUME_VOICE: StringName = &"volume_voice"
const KEY_VOLUME_UI: StringName = &"volume_ui"
## « Effets visuels » : 1.0 Complets / 0.5 Réduits / 0.0 Désactivés (DS §5).
const KEY_FX_INTENSITY: StringName = &"fx_intensity"
## « Réduire les animations » (§8 bis.7) — indépendant des effets visuels.
const KEY_REDUCE_MOTION: StringName = &"reduce_motion"
## Échelle du texte/UI : 0.9 à 1.5 par pas de 0.1 (UI_FLOW §6).
const KEY_TEXT_SCALE: StringName = &"text_scale"
const KEY_SUBTITLES: StringName = &"subtitles"
## Horloge de shift ralentie (accessibilité « Temps », UI_FLOW §6).
const KEY_CLOCK_SLOW_ACCESSIBILITY: StringName = &"clock_slow_accessibility"
## Audio mono (audition unilatérale, docs/AUDIO.md §9) : somme L/R sur `Master`.
const KEY_AUDIO_MONO: StringName = &"audio_mono"

const FX_LEVELS: PackedFloat32Array = [1.0, 0.5, 0.0]
const TEXT_SCALE_MIN: float = 0.9
const TEXT_SCALE_MAX: float = 1.5
const TEXT_SCALE_STEP: float = 0.1

## Valeurs par défaut ; leur type (bool / float) définit le type du réglage.
const DEFAULTS: Dictionary = {
	&"volume_master": 1.0,
	&"volume_music": 0.8,
	&"volume_ambience": 0.8,
	&"volume_sfx": 1.0,
	&"volume_voice": 1.0,
	&"volume_ui": 1.0,
	&"fx_intensity": 1.0,
	&"reduce_motion": false,
	&"text_scale": 1.0,
	&"subtitles": true,
	&"clock_slow_accessibility": false,
	&"audio_mono": false,
}

## Réglage de volume → nom du bus audio (docs/AUDIO.md §2).
const VOLUME_BUSES: Dictionary = {
	&"volume_master": &"Master",
	&"volume_music": &"Music",
	&"volume_ambience": &"Ambience",
	&"volume_sfx": &"SFX",
	&"volume_voice": &"Voice",
	&"volume_ui": &"UI",
}

var _values: Dictionary[StringName, Variant] = {}

var fx_intensity: float:
	get:
		return get_float(KEY_FX_INTENSITY)
	set(value):
		set_value(KEY_FX_INTENSITY, value)

var reduce_motion: bool:
	get:
		return get_bool(KEY_REDUCE_MOTION)
	set(value):
		set_value(KEY_REDUCE_MOTION, value)

var text_scale: float:
	get:
		return get_float(KEY_TEXT_SCALE)
	set(value):
		set_value(KEY_TEXT_SCALE, value)

var subtitles: bool:
	get:
		return get_bool(KEY_SUBTITLES)
	set(value):
		set_value(KEY_SUBTITLES, value)

var clock_slow_accessibility: bool:
	get:
		return get_bool(KEY_CLOCK_SLOW_ACCESSIBILITY)
	set(value):
		set_value(KEY_CLOCK_SLOW_ACCESSIBILITY, value)


func _init() -> void:
	_reset_values()


func _ready() -> void:
	load_settings()
	apply_all()


## Liste des clés connues.
func get_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in DEFAULTS:
		keys.append(key)
	return keys


func has_key(key: StringName) -> bool:
	return DEFAULTS.has(key)


func get_default(key: StringName) -> Variant:
	return DEFAULTS.get(key)


func get_value(key: StringName) -> Variant:
	if not _values.has(key):
		push_error("Settings: clé inconnue '%s'" % key)
		return null
	return _values[key]


func get_float(key: StringName) -> float:
	var value: Variant = get_value(key)
	return value if value is float else 0.0


func get_bool(key: StringName) -> bool:
	var value: Variant = get_value(key)
	return value if value is bool else false


## Volume linéaire (0..1) d'un réglage `volume_*`.
func get_volume(key: StringName) -> float:
	return get_float(key)


## Modifie un réglage. Renvoie `false` si la clé est inconnue.
## `persist = false` évite l'écriture disque (ex. glissement d'un slider ;
## appeler `save_settings()` au relâchement).
func set_value(key: StringName, value: Variant, persist: bool = true) -> bool:
	if not has_key(key):
		push_error("Settings: clé inconnue '%s'" % key)
		return false
	var sanitized: Variant = _sanitize(key, value)
	if _values[key] == sanitized:
		return true
	_values[key] = sanitized
	_apply(key)
	if persist:
		save_settings()
	EventBus.settings_changed.emit(key, sanitized)
	return true


## Restaure toutes les valeurs par défaut (émet `settings_changed` pour chacune).
func reset_to_defaults(persist: bool = true) -> void:
	for key: StringName in DEFAULTS:
		set_value(key, DEFAULTS[key], false)
	if persist:
		save_settings()


func load_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return OK
	if err != OK:
		push_warning("Settings: lecture de %s impossible (%s), valeurs par défaut." % [SETTINGS_PATH, error_string(err)])
		return err
	for key: StringName in DEFAULTS:
		var stored: Variant = config.get_value(SECTION, String(key), DEFAULTS[key])
		_values[key] = _sanitize(key, stored)
	return OK


func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in DEFAULTS:
		config.set_value(SECTION, String(key), _values[key])
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Settings: écriture de %s impossible (%s)." % [SETTINGS_PATH, error_string(err)])
	return err


## Applique tous les réglages qui relèvent de Settings (volumes, mono).
func apply_all() -> void:
	for key: StringName in DEFAULTS:
		_apply(key)


func _reset_values() -> void:
	_values.clear()
	for key: StringName in DEFAULTS:
		_values[key] = DEFAULTS[key]


func _apply(key: StringName) -> void:
	if key == KEY_AUDIO_MONO:
		AudioBuses.set_effect_enabled(AudioBuses.MASTER, AudioBuses.FX_MONO, get_bool(key))
		return
	if VOLUME_BUSES.has(key):
		var bus_name: StringName = VOLUME_BUSES[key]
		var bus: int = AudioServer.get_bus_index(bus_name)
		if bus < 0:
			return # bus absent (layout non chargé)
		var volume: float = get_float(key)
		AudioServer.set_bus_mute(bus, volume <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))


## Ramène une valeur dans le domaine du réglage ; défaut si type incompatible.
func _sanitize(key: StringName, value: Variant) -> Variant:
	var default_value: Variant = DEFAULTS[key]
	if default_value is bool:
		if value is bool:
			return value
		if value is int or value is float:
			return value != 0
		push_warning("Settings: valeur invalide pour '%s', défaut utilisé." % key)
		return default_value
	if not (value is int or value is float):
		push_warning("Settings: valeur invalide pour '%s', défaut utilisé." % key)
		return default_value
	var number: float = value # int → float converti à l’affectation
	if key == KEY_FX_INTENSITY:
		return _nearest_fx_level(number)
	if key == KEY_TEXT_SCALE:
		return clampf(snappedf(number, TEXT_SCALE_STEP), TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	return clampf(number, 0.0, 1.0) # volumes


func _nearest_fx_level(value: float) -> float:
	var best: float = FX_LEVELS[0]
	for level: float in FX_LEVELS:
		if absf(level - value) < absf(best - value):
			best = level
	return best
