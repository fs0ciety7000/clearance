## M11 lot B — accessibilité et commandes (DESIGN_SYSTEM §2.5, UI_FLOW §9) :
## validation des nouveaux réglages (`Settings._sanitize`), palette de vision
## des couleurs (valeurs, contrastes WCAG AA, écarts simulés), liaisons
## clavier + manette de chaque action, noms d'invites par périphérique.
extends GutTest

## Machado, Oliveira & Fernandes 2009, sévérité 1,0 (RVB linéaire).
const CVD: Dictionary[StringName, Array] = {
	&"protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	&"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	&"tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
## Paires qui ne doivent jamais se confondre : approbation / refus,
## concordance / discordance, refus / avertissement, discordance / refus.
const PAIRS: Array[Array] = [[&"STATE_GREEN", &"STATE_RED"], [&"STATE_GREEN", &"ACCENT_MAGENTA"],
	[&"STATE_RED", &"STATE_AMBER"], [&"ACCENT_MAGENTA", &"STATE_RED"]]
## Couleurs posées en texte (AA ≥ 4,5:1 sur bg.panel et bg.elevated).
const TEXT_TOKENS: Array[StringName] = [&"STATE_GREEN", &"STATE_RED", &"ACCENT_MAGENTA", &"STATE_AMBER",
	&"VOICE_COMMISSION", &"VOICE_BRULANTS", &"TEXT_SECONDARY"]

var _cv_before: float = 0.0


func before_each() -> void:
	_cv_before = Settings.get_float(Settings.KEY_COLOR_VISION)


func after_each() -> void:
	Settings.set_value(Settings.KEY_COLOR_VISION, _cv_before, false)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


# ---------------------------------------------------------------------------
# Réglages
# ---------------------------------------------------------------------------

func test_new_settings_defaults() -> void:
	assert_eq(Settings.get_default(Settings.KEY_COLOR_VISION), 0.0, "vision des couleurs : aucune par défaut")
	assert_eq(Settings.get_default(Settings.KEY_HOLO_FLICKER), true, "scintillement holographique actif par défaut")
	assert_eq(Settings.get_default(Settings.KEY_PAD_GLYPHS), -1.0, "glyphes manette : auto par défaut")


func test_sanitize_color_vision() -> void:
	assert_eq(Settings._sanitize(Settings.KEY_COLOR_VISION, 2), 2.0)
	assert_eq(Settings._sanitize(Settings.KEY_COLOR_VISION, 2.6), 3.0, "arrondi au mode le plus proche")
	assert_eq(Settings._sanitize(Settings.KEY_COLOR_VISION, 9.0), 3.0, "borné au contraste élevé")
	assert_eq(Settings._sanitize(Settings.KEY_COLOR_VISION, -4.0), 0.0, "borné à « aucune »")
	assert_eq(Settings._sanitize(Settings.KEY_COLOR_VISION, "protan"), 0.0, "type invalide : défaut")


func test_sanitize_holo_flicker_and_pad_glyphs() -> void:
	assert_eq(Settings._sanitize(Settings.KEY_HOLO_FLICKER, 0), false, "nombre → booléen")
	assert_eq(Settings._sanitize(Settings.KEY_HOLO_FLICKER, "oui"), true, "type invalide : défaut (actif)")
	assert_eq(Settings._sanitize(Settings.KEY_PAD_GLYPHS, 5.0), 1.0, "borné à PlayStation")
	assert_eq(Settings._sanitize(Settings.KEY_PAD_GLYPHS, -3.0), -1.0, "borné à Auto")
	assert_eq(Settings._sanitize(Settings.KEY_PAD_GLYPHS, 0.4), 0.0)


func test_new_settings_persist_and_reload() -> void:
	var path: String = "user://test_m11_settings.cfg"
	var config: ConfigFile = ConfigFile.new()
	config.set_value(Settings.SECTION, "color_vision", 7.0)
	config.set_value(Settings.SECTION, "holo_flicker", 0)
	config.set_value(Settings.SECTION, "pad_glyphs", 1)
	config.save(path)
	var previous: String = Settings.settings_path
	Settings.use_storage(path)
	assert_eq(Settings.color_vision, 3, "valeur hors bornes ramenée au contraste élevé")
	assert_false(Settings.holo_flicker)
	assert_eq(Settings.get_float(Settings.KEY_PAD_GLYPHS), 1.0)
	assert_eq(Palette.mode, Palette.Mode.HIGH_CONTRAST, "palette appliquée au chargement")
	Settings.use_storage(previous)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(Palette.mode, Palette.Mode.NONE)


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

func test_palette_none_equals_contract_tokens() -> void:
	Settings.set_value(Settings.KEY_COLOR_VISION, 0.0, false)
	var constants: Dictionary = (load("res://ui/theme/tokens.gd") as GDScript).get_script_constant_map()
	for token: StringName in Palette.NAMES:
		assert_eq(Palette.get_color(token), constants[String(token)], "%s = DS (mode Aucun)" % token)


func test_setting_applies_palette_and_alpha_variants() -> void:
	Settings.set_value(Settings.KEY_COLOR_VISION, 1.0, false)
	assert_eq(Palette.mode, Palette.Mode.PROTAN_DEUTAN)
	assert_eq(Palette.STATE_GREEN, Color("#4A90F0"), "approbation → bleu")
	assert_almost_eq(Palette.GREEN_12.a, 0.12, 0.002)
	assert_eq(Color(Palette.GREEN_12, 1.0), Color("#4A90F0"), "variante alpha dérivée de la nouvelle teinte")
	assert_eq(DocumentView.token_color(&"STATE_RED"), Palette.STATE_RED, "teinte de document d'état : palette active")
	assert_eq(DocumentView.token_color(&"ACCENT_CYAN"), DS.ACCENT_CYAN, "cyan (information, focus) inchangé")
	Settings.set_value(Settings.KEY_COLOR_VISION, 0.0, false)
	assert_eq(Palette.STATE_GREEN, DS.STATE_GREEN, "retour à la palette du contrat")


func test_palette_text_contrast_is_wcag_aa_in_every_mode() -> void:
	for mode: int in [0, 1, 2, 3]:
		Palette.apply(mode)
		for token: StringName in TEXT_TOKENS:
			var color: Color = Palette.get_color(token)
			for bg: Color in [DS.BG_PANEL, DS.BG_ELEVATED, DS.BG_VOID]:
				assert_gte(_contrast(color, bg), 4.5, "mode %d : %s sur %s ≥ 4,5:1" % [mode, token, bg.to_html(false)])
	Palette.apply(3)
	assert_gte(_contrast(Palette.LINE_SUBTLE, DS.BG_PANEL), 3.0, "contraste élevé : filet ≥ 3:1 (élément d'interface)")
	Palette.apply(int(Settings.get_float(Settings.KEY_COLOR_VISION)))


## Écart CIE76 simulé entre paires critiques : ≥ 35 pour chaque déficience
## visée par un mode ; et la palette dédiée bat nettement le contrat là où il
## échoue (deutéranopie : vert / rouge / ambre ; tritanopie : magenta / rouge).
## Mesures CIEDE2000 détaillées : DESIGN_SYSTEM §2.5.
func test_palettes_separate_critical_pairs_under_simulation() -> void:
	var targets: Dictionary[int, Array] = {1: [&"protan", &"deutan"], 2: [&"tritan"]}
	for mode: int in targets:
		for kind: StringName in targets[mode]:
			Palette.apply(0)
			var base_min: float = _min_pair_distance(kind)
			Palette.apply(mode)
			var min_distance: float = _min_pair_distance(kind)
			assert_gte(min_distance, 35.0, "mode %d sous %s : paires critiques distinctes" % [mode, kind])
			if kind != &"protan":
				assert_gt(min_distance, base_min * 1.4, "mode %d nettement meilleur que le contrat sous %s" % [mode, kind])
	Palette.apply(int(Settings.get_float(Settings.KEY_COLOR_VISION)))


# ---------------------------------------------------------------------------
# Commandes
# ---------------------------------------------------------------------------

func test_every_game_action_has_keyboard_and_gamepad_bindings() -> void:
	for action: StringName in ControlsMap.GAME_ACTIONS:
		assert_true(InputMap.has_action(action), "%s déclarée" % action)
		assert_not_null(InputPrompts.binding(action, false), "%s : touche clavier" % action)
		assert_not_null(InputPrompts.binding(action, true), "%s : bouton ou axe de manette" % action)
	for entry: Array in ControlsMap.SUMMARY:
		assert_true(ControlsMap.GAME_ACTIONS.has(entry[0]), "rappel des Options : %s" % entry[0])
		assert_true(UiText.has(entry[1]), "libellé %s traduit" % entry[1])


## La croix sert au focus (inspection, menus) : aucune action du guichet ne
## la réserve ; deux actions du guichet ne partagent un bouton que par
## contexte documenté (A = suivant / valider, B = annuler, R3 = visage / loupe).
func test_gamepad_bindings_do_not_collide() -> void:
	var dpad: Array[int] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
	var shared_ok: Array[Array] = [[&"next_case", &"ui_accept"], [&"cancel", &"ui_cancel"], [&"inspect_face", &"doc_zoom"]]
	var owners: Dictionary[String, StringName] = {}
	for action: StringName in ControlsMap.GAME_ACTIONS:
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			var button: InputEventJoypadButton = event as InputEventJoypadButton
			if button != null:
				assert_false(dpad.has(button.button_index), "%s ne prend pas la croix (focus)" % action)
			var key: String = _pad_key(event)
			if key.is_empty():
				continue
			if owners.has(key):
				var pair: Array = [owners[key], action]
				var allowed: bool = false
				for ok: Array in shared_ok:
					allowed = allowed or (ok.has(pair[0]) and ok.has(pair[1]))
				assert_true(allowed, "%s et %s partagent %s" % [owners[key], action, key])
			owners[key] = action
	var accept: InputEvent = InputPrompts.binding(&"ui_accept", true)
	assert_true(accept is InputEventJoypadButton and (accept as InputEventJoypadButton).button_index == JOY_BUTTON_A,
			"ui_accept : Ⓐ (les boutons se valident à la manette)")
	var back: InputEvent = InputPrompts.binding(&"ui_cancel", true)
	assert_true(back is InputEventJoypadButton and (back as InputEventJoypadButton).button_index == JOY_BUTTON_B)


func test_prompt_names_follow_the_device() -> void:
	assert_eq(InputPrompts.text_for(&"inspect_toggle", InputPrompts.Device.KEYBOARD), "ESPACE")
	assert_eq(InputPrompts.text_for(&"inspect_toggle", InputPrompts.Device.XBOX), "LT")
	assert_eq(InputPrompts.text_for(&"inspect_toggle", InputPrompts.Device.PLAYSTATION), "L2")
	assert_eq(InputPrompts.text_for(&"stamp_deny", InputPrompts.Device.PLAYSTATION), "CARRÉ")
	assert_eq(InputPrompts.text_for(&"rulebook_next", InputPrompts.Device.DECK), "R1")
	assert_eq(InputPrompts.text_for(&"rulebook_prev", InputPrompts.Device.KEYBOARD), "[")
	assert_eq(InputPrompts.text_for(&"doc_next", InputPrompts.Device.XBOX), "RS →")
	var face: Dictionary = InputPrompts.glyph_for(&"next_case", InputPrompts.Device.PLAYSTATION)
	assert_eq(face["shape"], InputPrompts.Shape.FACE, "Ⓐ / ✕ : bouton de façade dessiné")


func test_last_device_switches_prompts() -> void:
	var tool_glyph: PromptGlyph = PromptGlyph.make(&"interrogate")
	add_child_autofree(tool_glyph)
	await wait_process_frames(1)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	assert_eq(tool_glyph.get_text(), "Q")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	assert_ne(InputPrompts.device_of(pad), InputPrompts.Device.KEYBOARD, "un bouton de manette désigne la manette")
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	assert_eq(tool_glyph.get_text(), "Y", "le glyphe suit la manette")
	var drift: InputEventJoypadMotion = InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2
	assert_eq(InputPrompts.device_of(drift), -1, "dérive d'un stick : sans effet")
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_Q
	assert_eq(InputPrompts.device_of(key), InputPrompts.Device.KEYBOARD)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	assert_eq(tool_glyph.get_text(), "Q", "retour au clavier")


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

func _pad_key(event: InputEvent) -> String:
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		return "b%d" % button.button_index
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		return "a%d%s" % [motion.axis, "+" if motion.axis_value > 0.0 else "-"]
	return ""


static func _luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lab(c: Color, kind: StringName) -> Vector3:
	var l: Color = c.srgb_to_linear()
	var m: Array = CVD[kind]
	var rgb: Vector3 = Vector3(l.r, l.g, l.b)
	var sim: Vector3 = Vector3(
		clampf(Vector3(m[0][0], m[0][1], m[0][2]).dot(rgb), 0.0, 1.0),
		clampf(Vector3(m[1][0], m[1][1], m[1][2]).dot(rgb), 0.0, 1.0),
		clampf(Vector3(m[2][0], m[2][1], m[2][2]).dot(rgb), 0.0, 1.0))
	var x: float = (0.4124 * sim.x + 0.3576 * sim.y + 0.1805 * sim.z) / 0.95047
	var y: float = 0.2126 * sim.x + 0.7152 * sim.y + 0.0722 * sim.z
	var z: float = (0.0193 * sim.x + 0.1192 * sim.y + 0.9505 * sim.z) / 1.08883
	var f: Callable = func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _min_pair_distance(kind: StringName) -> float:
	var result: float = INF
	for pair: Array in PAIRS:
		result = minf(result, _lab(Palette.get_color(pair[0]), kind).distance_to(_lab(Palette.get_color(pair[1]), kind)))
	return result
