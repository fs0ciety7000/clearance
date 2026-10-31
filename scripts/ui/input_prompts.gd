## Invites de commandes (M11, UI_FLOW §9) : dernier périphérique utilisé
## (clavier / souris ou manette) et nom de la touche ou du bouton d'une action
## de `project.godot` pour ce périphérique.
##
## - API statique : `device`, `is_gamepad()`, `text_for(action)`,
##   `glyph_for(action)` (description dessinée par `PromptGlyph`).
## - Une instance (nœud) suit les entrées : `ensure(tree)` l'ajoute à la racine
##   au premier besoin (aucun autoload) ; son signal `device_changed` fait
##   suivre les glyphes. Elle tourne aussi pendant la pause.
## - Style des glyphes manette : réglage `pad_glyphs` (Auto : nom de la manette,
##   Steam Deck reconnu ; ou forcé Xbox / PlayStation).
## Aucun asset externe : les glyphes sont dessinés aux tokens DS (PromptGlyph).
class_name InputPrompts
extends Node

signal device_changed(device: Device)

enum Device { KEYBOARD, XBOX, PLAYSTATION, DECK }

## Forme d'un glyphe (dessin de `PromptGlyph`).
enum Shape { KEY, FACE, SHOULDER, DPAD, STICK, SYSTEM }

## Seuil d'un axe de manette pris pour un geste (pas une dérive du stick).
const AXIS_THRESHOLD: float = 0.5
## Déplacement de souris (px) qui rend la main au clavier / à la souris.
const MOUSE_THRESHOLD: float = 6.0
const PS_HINTS: Array[String] = ["playstation", "dualsense", "dualshock", "ps4", "ps5", "sony", "wireless controller"]

const KEY_NAMES: Dictionary[int, String] = {
	KEY_SPACE: "ESPACE", KEY_ESCAPE: "ÉCHAP", KEY_TAB: "TAB", KEY_ENTER: "ENTRÉE", KEY_KP_ENTER: "ENTRÉE",
	KEY_PAGEUP: "PG ↑", KEY_PAGEDOWN: "PG ↓", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_BACKSPACE: "RETOUR", KEY_SHIFT: "MAJ",
}
## Boutons (JoyButton) → nom, par famille de manette.
const XBOX_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "VUE",
	JOY_BUTTON_GUIDE: "GUIDE", JOY_BUTTON_START: "MENU", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
}
const DECK_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "VUE",
	JOY_BUTTON_GUIDE: "STEAM", JOY_BUTTON_START: "MENU", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
}
## PlayStation : formes en toutes lettres dans les phrases (le dessin du
## glyphe porte la forme ✕ ○ □ △).
const PS_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "CROIX", JOY_BUTTON_B: "ROND", JOY_BUTTON_X: "CARRÉ", JOY_BUTTON_Y: "TRIANGLE",
	JOY_BUTTON_BACK: "CREATE", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
}

## M15 : noms de touches et de boutons en toutes lettres → clé de traduction
## (repli : le nom français de la table). Les sigles (LT, RB, A, TAB…) ne se
## traduisent pas.
const NAME_KEYS: Dictionary[String, String] = {
	"ESPACE": "key_space", "ÉCHAP": "key_escape", "ENTRÉE": "key_enter", "RETOUR": "key_backspace", "MAJ": "key_shift",
	"VUE": "pad_view", "CROIX": "pad_cross", "ROND": "pad_circle", "CARRÉ": "pad_square", "TRIANGLE": "pad_triangle",
}

## Dernier périphérique utilisé (Steam Deck : manette d'emblée).
static var device: Device = Device.DECK if OS.get_environment("SteamDeck") == "1" else Device.KEYBOARD
static var _instance: InputPrompts = null


## Nœud de suivi (créé et ajouté à la racine au premier appel).
static func ensure(tree: SceneTree) -> InputPrompts:
	if _instance == null or not is_instance_valid(_instance):
		_instance = InputPrompts.new()
		_instance.name = "InputPrompts"
		_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if tree != null:
			tree.root.add_child.call_deferred(_instance)
	return _instance


static func is_gamepad() -> bool:
	return device != Device.KEYBOARD


## Force le périphérique (outils de capture, tests) et prévient les glyphes.
static func simulate_device(p_device: Device) -> void:
	_set_device(p_device)


static func _set_device(p_device: Device) -> void:
	if p_device == device:
		return
	device = p_device
	if _instance != null and is_instance_valid(_instance):
		_instance.device_changed.emit(device)


## Famille de glyphes d'une manette (`pad_glyphs`, nom de la manette).
static func pad_style(joy_device: int = 0) -> Device:
	var forced: int = roundi(Settings.get_float(Settings.KEY_PAD_GLYPHS))
	var deck: bool = OS.get_environment("SteamDeck") == "1"
	if forced == 0:
		return Device.DECK if deck else Device.XBOX
	if forced == 1:
		return Device.PLAYSTATION
	var joy_name: String = Input.get_joy_name(joy_device).to_lower()
	for hint: String in PS_HINTS:
		if joy_name.contains(hint):
			return Device.PLAYSTATION
	if deck or joy_name.contains("steam deck"):
		return Device.DECK
	return Device.XBOX


## Périphérique désigné par un événement (−1 : sans effet, ex. dérive d'un stick).
static func device_of(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		return pad_style(event.device) if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		return pad_style(event.device) if absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD else -1
	if event is InputEventKey:
		return Device.KEYBOARD if (event as InputEventKey).pressed else -1
	if event is InputEventMouseButton:
		return Device.KEYBOARD if (event as InputEventMouseButton).pressed else -1
	if event is InputEventMouseMotion:
		return Device.KEYBOARD if (event as InputEventMouseMotion).relative.length() >= MOUSE_THRESHOLD else -1
	return -1


func _ready() -> void:
	EventBus.settings_changed.connect(_on_settings_changed)


func _input(event: InputEvent) -> void:
	var found: int = device_of(event)
	if found >= 0:
		_set_device(found as Device)


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_LANGUAGE:
		# M15 : noms de touches traduits — les phrases d'invite sont réécrites.
		device_changed.emit(device)
		return
	if key == Settings.KEY_PAD_GLYPHS and is_gamepad():
		var style: Device = pad_style()
		if style != device:
			device = style
			device_changed.emit(device)


# ---------------------------------------------------------------------------
# Liaisons et noms
# ---------------------------------------------------------------------------

## Premier événement de `action` pour la manette (`pad`) ou le clavier.
static func binding(action: StringName, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		var is_pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad == pad and (pad or event is InputEventKey):
			return event
	return null


## Nom court de la commande de `action` pour `p_device` (texte des phrases :
## « ESPACE », « LT », « CROIX »). Vide si l'action n'a rien pour ce périphérique.
static func text_for(action: StringName, p_device: int = -1) -> String:
	var d: Device = device if p_device < 0 else p_device as Device
	var event: InputEvent = binding(action, d != Device.KEYBOARD)
	if event == null:
		return ""
	return event_text(event, d)


static func event_text(event: InputEvent, d: Device) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key_text(key)
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		var names: Dictionary[int, String] = XBOX_BUTTONS
		if d == Device.PLAYSTATION:
			names = PS_BUTTONS
		elif d == Device.DECK:
			names = DECK_BUTTONS
		return named(names.get(button.button_index, "?"))
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		return axis_text(motion.axis, motion.axis_value, d)
	return ""


static func key_text(key: InputEventKey) -> String:
	var code: Key = key.keycode
	if code == KEY_NONE and key.physical_keycode != KEY_NONE:
		code = key.physical_keycode
		# Disposition réelle (AZERTY : la touche physique Q s'affiche « A ») ;
		# le serveur headless (tests, outils) ne la connaît pas, le Web non plus
		# (« Not supported by this display server » à chaque appel, docs/WEB.md).
		if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
			var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			if mapped != KEY_NONE:
				code = mapped
	if KEY_NAMES.has(code):
		return named(KEY_NAMES[code])
	if code > KEY_SPACE and code < 127:
		return String.chr(code).to_upper() # touche imprimable : son caractère ([, ], ,, .)
	return OS.get_keycode_string(code).to_upper()


## M15 : nom en toutes lettres traduit (`NAME_KEYS`), sigle inchangé.
static func named(text: String) -> String:
	return UiText.t(NAME_KEYS[text], text) if NAME_KEYS.has(text) else text


static func axis_text(axis: int, value: float, d: Device) -> String:
	var xbox: bool = d == Device.XBOX
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "LT" if xbox else "L2"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT" if xbox else "R2"
		JOY_AXIS_LEFT_X:
			return ("LS " if xbox else "L ") + ("←" if value < 0.0 else "→")
		JOY_AXIS_LEFT_Y:
			return ("LS " if xbox else "L ") + ("↑" if value < 0.0 else "↓")
		JOY_AXIS_RIGHT_X:
			return ("RS " if xbox else "R ") + ("←" if value < 0.0 else "→")
		JOY_AXIS_RIGHT_Y:
			return ("RS " if xbox else "R ") + ("↑" if value < 0.0 else "↓")
	return "?"


## Description dessinable de la commande de `action` : {shape, text, index,
## value}. `shape` = `Shape` ; `index` = bouton ou axe ; `value` = sens d'un axe.
static func glyph_for(action: StringName, p_device: int = -1) -> Dictionary:
	var d: Device = device if p_device < 0 else p_device as Device
	var event: InputEvent = binding(action, d != Device.KEYBOARD)
	if event == null and d != Device.KEYBOARD:
		# Action sans liaison manette : on montre la touche (jamais vide).
		d = Device.KEYBOARD
		event = binding(action, false)
	if event == null:
		return {"shape": Shape.KEY, "text": "?", "index": -1, "value": 0.0, "device": d}
	var glyph: Dictionary = {"shape": Shape.KEY, "text": event_text(event, d), "index": -1, "value": 0.0, "device": d}
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		glyph["index"] = button.button_index
		match button.button_index:
			JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
				glyph["shape"] = Shape.FACE
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				glyph["shape"] = Shape.SHOULDER
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				glyph["shape"] = Shape.DPAD
			JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
				glyph["shape"] = Shape.STICK
			_:
				glyph["shape"] = Shape.SYSTEM
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		glyph["index"] = motion.axis
		glyph["value"] = motion.axis_value
		glyph["shape"] = Shape.SHOULDER if motion.axis >= JOY_AXIS_TRIGGER_LEFT else Shape.STICK
	return glyph
