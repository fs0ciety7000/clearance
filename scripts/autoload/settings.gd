## Settings — préférences du joueur (ARCHITECTURE §4).
##
## Persistées dans `user://settings.cfg` (`ConfigFile`, section `[settings]`).
## Toute modification passe par `set_value()` (ou les propriétés typées), qui
## valide la valeur, l'applique, la sauvegarde et émet
## `EventBus.settings_changed(key, value)`.
## Les volumes et le mode mono sont appliqués ici aux bus audio
## (`res://default_bus_layout.tres`, docs/AUDIO.md §2), la vision des couleurs
## à la palette active (`Palette.apply`, DESIGN_SYSTEM §2.5) ; les autres réglages
## (taille du texte, effets, animations, sous-titres, horloge) sont appliqués
## par leurs consommateurs à l'écoute de `settings_changed`.
##
## Réglages **persistés** ≠ réglages **de session** (QA-006) :
## - `set_value()` = choix du joueur ; `persist = false` ne fait que différer
##   l'écriture (glissement d'un slider), le prochain `save_settings()` l'écrit ;
## - `set_session_value()` = valeur temporaire (argument `--reduce-motion`,
##   outils, tests) : appliquée et notifiée, **jamais écrite** ;
##   `save_settings()` écrit pour cette clé la dernière valeur persistée.
##   `clear_session_value()` la retire ; un `set_value()` du joueur la remplace.
## - `use_storage(path)` change le fichier (tests GUT :
##   `tests/helpers/gut_pre_run.gd`, jamais le `settings.cfg` réel).
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
## « Qualité graphique » du guichet 3D (M9, BOOTH_SCENE §13) : -1 Auto
## (Steam Deck → Moyen, sinon Élevé), 0 Bas, 1 Moyen, 2 Élevé. Appliquée par
## `BoothQuality` (scripts/booth).
const KEY_GRAPHICS_QUALITY: StringName = &"graphics_quality"
const QUALITY_AUTO: float = -1.0
## M11 — « Vision des couleurs » (DESIGN_SYSTEM §2.5) : 0 Aucune,
## 1 Protanopie / Deutéranopie, 2 Tritanopie, 3 Contraste élevé. Remplace les
## couleurs sémantiques (`Palette.apply`) ; formes et icônes restent le
## premier porteur du sens.
const KEY_COLOR_VISION: StringName = &"color_vision"
const COLOR_VISION_MAX: float = 3.0
## M11 — « Scintillement holographique » : scintillement du cadre, défilement
## des scanlines et glitchs (DS §5), coupés **séparément** des lueurs et du
## niveau d'effets (`fx_intensity`).
const KEY_HOLO_FLICKER: StringName = &"holo_flicker"
## M11 — style des glyphes manette : -1 Auto (nom de la manette, Steam Deck),
## 0 Xbox / Steam Deck (A B X Y), 1 PlayStation (✕ ○ □ △).
const KEY_PAD_GLYPHS: StringName = &"pad_glyphs"
const PAD_GLYPHS_AUTO: float = -1.0

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
	&"graphics_quality": -1.0,
	&"color_vision": 0.0,
	&"holo_flicker": true,
	&"pad_glyphs": -1.0,
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
## Valeurs telles qu'écrites (ou lues) dans `settings_path`.
var _persisted: Dictionary[StringName, Variant] = {}
## Clés portant une valeur de session (jamais écrite).
var _session_keys: Dictionary[StringName, bool] = {}
## Fichier des préférences (`SETTINGS_PATH` ; autre chemin : `use_storage`).
var settings_path: String = SETTINGS_PATH

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

## Mode de vision des couleurs (`Palette.Mode`, 0–3).
var color_vision: int:
	get:
		return int(get_float(KEY_COLOR_VISION))
	set(value):
		set_value(KEY_COLOR_VISION, float(value))

var holo_flicker: bool:
	get:
		return get_bool(KEY_HOLO_FLICKER)
	set(value):
		set_value(KEY_HOLO_FLICKER, value)


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


## Niveau de qualité effectif (0 Bas, 1 Moyen, 2 Élevé) : « Auto » vaut Moyen
## sur Steam Deck, Élevé ailleurs.
func graphics_quality_level() -> int:
	var value: float = get_float(KEY_GRAPHICS_QUALITY)
	if value < 0.0:
		return 1 if is_steam_deck() else 2
	return int(value)


## Steam Deck (variable `SteamDeck=1` posée par Steam sur la console).
static func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1"


## Volume linéaire (0..1) d'un réglage `volume_*`.
func get_volume(key: StringName) -> float:
	return get_float(key)


## Modifie un réglage (choix du joueur). Renvoie `false` si la clé est
## inconnue. `persist = false` diffère l'écriture disque (ex. glissement d'un
## slider ; appeler `save_settings()` au relâchement). Remplace une éventuelle
## valeur de session de la clé.
func set_value(key: StringName, value: Variant, persist: bool = true) -> bool:
	if not has_key(key):
		push_error("Settings: clé inconnue '%s'" % key)
		return false
	_session_keys.erase(key)
	var changed: bool = _store(key, value)
	if persist and (changed or _persisted[key] != _values[key]):
		save_settings()
	return true


## Valeur temporaire pour la session (arguments, outils, tests) : appliquée et
## notifiée comme `set_value`, mais jamais écrite par `save_settings()`.
func set_session_value(key: StringName, value: Variant) -> bool:
	if not has_key(key):
		push_error("Settings: clé inconnue '%s'" % key)
		return false
	_session_keys[key] = true
	_store(key, value)
	return true


## Retire la valeur de session d'une clé : revient à la valeur persistée.
func clear_session_value(key: StringName) -> void:
	if not _session_keys.has(key):
		return
	_session_keys.erase(key)
	_store(key, _persisted[key])


func is_session_value(key: StringName) -> bool:
	return _session_keys.has(key)


## Change le fichier des préférences (tests) : valeurs par défaut, sessions
## effacées, puis lecture de `path` s'il existe.
func use_storage(path: String) -> void:
	settings_path = path
	_session_keys.clear()
	_reset_values()
	load_settings()
	apply_all()
	for key: StringName in DEFAULTS:
		EventBus.settings_changed.emit(key, _values[key])


## Affecte, applique et notifie ; `false` si la valeur ne change pas.
func _store(key: StringName, value: Variant) -> bool:
	var sanitized: Variant = _sanitize(key, value)
	if _values[key] == sanitized:
		return false
	_values[key] = sanitized
	_apply(key)
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
	var err: Error = config.load(settings_path)
	if err == ERR_FILE_NOT_FOUND:
		return OK
	if err != OK:
		push_warning("Settings: lecture de %s impossible (%s), valeurs par défaut." % [settings_path, error_string(err)])
		return err
	for key: StringName in DEFAULTS:
		var stored: Variant = config.get_value(SECTION, String(key), DEFAULTS[key])
		_persisted[key] = _sanitize(key, stored)
		if not _session_keys.has(key):
			_values[key] = _persisted[key]
	return OK


## Écrit les choix du joueur ; une clé de session garde sa valeur persistée.
func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in DEFAULTS:
		if not _session_keys.has(key):
			_persisted[key] = _values[key]
		config.set_value(SECTION, String(key), _persisted[key])
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var err: Error = config.save(settings_path)
	if err != OK:
		push_warning("Settings: écriture de %s impossible (%s)." % [settings_path, error_string(err)])
	return err


## Applique tous les réglages qui relèvent de Settings (volumes, mono,
## palette de vision des couleurs).
func apply_all() -> void:
	for key: StringName in DEFAULTS:
		_apply(key)


func _reset_values() -> void:
	_values.clear()
	_persisted.clear()
	for key: StringName in DEFAULTS:
		_values[key] = DEFAULTS[key]
		_persisted[key] = DEFAULTS[key]


func _apply(key: StringName) -> void:
	if key == KEY_COLOR_VISION:
		Palette.apply(int(get_float(key)))
		return
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
	if key == KEY_GRAPHICS_QUALITY:
		return clampf(roundf(number), QUALITY_AUTO, 2.0)
	if key == KEY_COLOR_VISION:
		return clampf(roundf(number), 0.0, COLOR_VISION_MAX)
	if key == KEY_PAD_GLYPHS:
		return clampf(roundf(number), PAD_GLYPHS_AUTO, 1.0)
	return clampf(number, 0.0, 1.0) # volumes


func _nearest_fx_level(value: float) -> float:
	var best: float = FX_LEVELS[0]
	for level: float in FX_LEVELS:
		if absf(level - value) < absf(best - value):
			best = level
	return best
