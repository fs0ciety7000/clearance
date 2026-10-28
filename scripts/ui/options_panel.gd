## Options (UI_FLOW §6, §8 « Pause / Options ») — composant non diégétique
## (DS §1.5 : style plat, aucun effet holo), partagé par le menu pause et
## l'écran titre. **Accessibilité en premier** : taille du texte 90–150 %
## (`text_scale`, D-026), effets visuels Complets / Réduits / Désactivés
## (`fx_intensity`), « Réduire les animations » (`reduce_motion` : marche du
## passager ≤ 1 s dès le passager suivant), sous-titres, horloge ralentie,
## qualité graphique du guichet 3D Bas / Moyen / Élevé (`graphics_quality`,
## M9 ; « Auto » par défaut = Moyen sur Steam Deck, Élevé ailleurs).
## Puis **Audio** : un volume par bus (docs/AUDIO.md §2) et « Son mono »
## (`audio_mono`, audition unilatérale, AUDIO.md §9). Chaque réglage passe
## par `Settings.set_value()` (persisté dans `user://settings.cfg`).
class_name OptionsPanel
extends VBoxContainer

signal back_requested()

const SLIDER_WIDTH: float = 360.0
const VOLUME_KEYS: Array[StringName] = [Settings.KEY_VOLUME_MASTER, Settings.KEY_VOLUME_MUSIC, Settings.KEY_VOLUME_AMBIENCE,
		Settings.KEY_VOLUME_SFX, Settings.KEY_VOLUME_VOICE, Settings.KEY_VOLUME_UI]
const FX_KEYS: Array[String] = ["opt_fx_full", "opt_fx_reduced", "opt_fx_off"]
const QUALITY_KEYS: Array[String] = ["opt_quality_low", "opt_quality_medium", "opt_quality_high"]

var back_button: Button = null
## Contrôles par clé de réglage (tests).
var controls: Dictionary[StringName, Control] = {}


func _ready() -> void:
	add_theme_constant_override("separation", DS.SPACE_3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ScreenBase.section(UiText.t("opt_accessibility", "ACCESSIBILITÉ"), UiIcon.Kind.INFO, DS.ACCENT_CYAN))
	_add_slider(Settings.KEY_TEXT_SCALE, UiText.t("opt_text_scale", "Taille du texte"), Settings.TEXT_SCALE_MIN,
			Settings.TEXT_SCALE_MAX, Settings.TEXT_SCALE_STEP, true)
	_add_fx_row()
	_add_quality_row()
	_add_toggle(Settings.KEY_REDUCE_MOTION, UiText.t("opt_reduce_motion", "Réduire les animations"),
			UiText.t("opt_reduce_motion_hint", "Marche du passager raccourcie (≤ 1 s), pas de travelling."))
	_add_toggle(Settings.KEY_SUBTITLES, UiText.t("opt_subtitles", "Sous-titres"),
			UiText.t("opt_subtitles_hint", "Voix des passagers en tessar, sous-titrées en français."))
	_add_toggle(Settings.KEY_CLOCK_SLOW_ACCESSIBILITY, UiText.t("opt_clock_slow", "Horloge du shift ralentie (×0,5)"),
			UiText.t("opt_clock_slow_hint", "Les gains par cas sont inchangés."))
	add_child(ScreenBase.section(UiText.t("opt_audio", "AUDIO"), UiIcon.Kind.CHAT, DS.TEXT_SECONDARY))
	for key: StringName in VOLUME_KEYS:
		_add_slider(key, UiText.t("opt_%s" % key, String(key)), 0.0, 1.0, 0.05, true)
	_add_toggle(Settings.KEY_AUDIO_MONO, UiText.t("opt_audio_mono", "Son mono"),
			UiText.t("opt_audio_mono_hint", "Gauche et droite mélangées : aucun son ne se perd d'une seule oreille."))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	add_child(row)
	row.add_child(ScreenBase.label(UiText.t("opt_saved", "Réglages enregistrés automatiquement."), &"CaptionLabel"))
	row.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("opt_back", "RETOUR"))
	back_button.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back_button)


func focus_first() -> void:
	var first: Control = controls.get(Settings.KEY_TEXT_SCALE, null)
	if first != null:
		first.grab_focus()


func _row(caption: String, hint: String = "") -> HBoxContainer:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	row.custom_minimum_size.y = DS.HIT_TARGET_MIN
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(ScreenBase.label(caption, &"BodyLabel"))
	if not hint.is_empty():
		texts.add_child(ScreenBase.label(hint, &"CaptionLabel"))
	add_child(row)
	return row


func _add_slider(key: StringName, caption: String, min_value: float, max_value: float, step: float, percent: bool) -> void:
	var row: HBoxContainer = _row(caption)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = Settings.get_float(key)
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, DS.HIT_TARGET_MIN)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	_style_slider(slider)
	row.add_child(slider)
	var value_label: Label = ScreenBase.label(_percent(slider.value) if percent else str(slider.value), &"DocFieldValue")
	value_label.custom_minimum_size.x = 64.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _percent(value) if percent else str(value)
		Settings.set_value(key, value, false))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	slider.focus_exited.connect(Settings.save_settings)
	controls[key] = slider


func _add_fx_row() -> void:
	var row: HBoxContainer = _row(UiText.t("opt_fx", "Effets visuels"), UiText.t("opt_fx_hint", "Scanlines, scintillement, lueurs des hologrammes."))
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: HBoxContainer = ScreenBase.hbox(0)
	row.add_child(buttons)
	for i: int in FX_KEYS.size():
		var level: float = Settings.FX_LEVELS[i]
		var b: Button = Button.new()
		b.theme_type_variation = &"ToggleTab"
		b.toggle_mode = true
		b.button_group = group
		b.text = UiText.t(FX_KEYS[i], FX_KEYS[i])
		b.custom_minimum_size = Vector2(120, DS.HIT_TARGET_MIN)
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = is_equal_approx(Settings.fx_intensity, level)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(Settings.KEY_FX_INTENSITY, level))
		buttons.add_child(b)
		if i == 0:
			controls[Settings.KEY_FX_INTENSITY] = b


## Qualité graphique : le bouton actif reflète le niveau effectif (« Auto »
## résolu) ; un clic fixe le niveau choisi.
func _add_quality_row() -> void:
	var row: HBoxContainer = _row(UiText.t("opt_quality", "Qualité graphique"),
			UiText.t("opt_quality_hint", "Guichet 3D : ombres, lueurs, pluie. Visage jamais dégradé."))
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: HBoxContainer = ScreenBase.hbox(0)
	row.add_child(buttons)
	var current: int = Settings.graphics_quality_level()
	for i: int in QUALITY_KEYS.size():
		var b: Button = Button.new()
		b.theme_type_variation = &"ToggleTab"
		b.toggle_mode = true
		b.button_group = group
		b.text = UiText.t(QUALITY_KEYS[i], QUALITY_KEYS[i])
		b.custom_minimum_size = Vector2(120, DS.HIT_TARGET_MIN)
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = i == current
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(Settings.KEY_GRAPHICS_QUALITY, float(i)))
		buttons.add_child(b)
		if i == 0:
			controls[Settings.KEY_GRAPHICS_QUALITY] = b


func _add_toggle(key: StringName, caption: String, hint: String) -> void:
	var row: HBoxContainer = _row(caption, hint)
	var b: Button = Button.new()
	b.theme_type_variation = &"ToggleTab"
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(160, DS.HIT_TARGET_MIN)
	b.button_pressed = Settings.get_bool(key)
	b.text = _toggle_text(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		b.text = _toggle_text(on)
		Settings.set_value(key, on))
	row.add_child(b)
	controls[key] = b


static func _toggle_text(on: bool) -> String:
	return ("✓ " + UiText.t("opt_on", "ACTIVÉ")) if on else UiText.t("opt_off", "DÉSACTIVÉ")


static func _percent(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)


## Piste et poignée DS (rectangles, pas d'arrondi ; cyan = interactif).
static func _style_slider(slider: HSlider) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = DS.LINE_SUBTLE
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = DS.CYAN_60
	var fill_hot: StyleBoxFlat = track.duplicate()
	fill_hot.bg_color = DS.ACCENT_CYAN
	slider.add_theme_stylebox_override(&"slider", track)
	slider.add_theme_stylebox_override(&"grabber_area", fill)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", fill_hot)
	var image: Image = Image.create(10, 22, false, Image.FORMAT_RGBA8)
	image.fill(DS.TEXT_PRIMARY)
	var grabber: ImageTexture = ImageTexture.create_from_image(image)
	var hot: Image = image.duplicate()
	hot.fill(DS.ACCENT_CYAN)
	slider.add_theme_icon_override(&"grabber", grabber)
	slider.add_theme_icon_override(&"grabber_highlight", ImageTexture.create_from_image(hot))
	slider.add_theme_stylebox_override(&"focus", ThemeBuilder.focus_box(0))
