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
## M11 : « Vision des couleurs » (`color_vision`, palette distinguable,
## DESIGN_SYSTEM §2.5), « Scintillement holographique » (`holo_flicker`, coupé
## séparément des lueurs), section **Commandes** (glyphes manette `pad_glyphs`,
## rappel du schéma). Les réglages défilent (stick droit, Pg↑ / Pg↓, focus
## suivi) : le panneau tient au Steam Deck et en texte 150 %.
## M11 lot C : section **Partie** — « Tutoriel du jour 1 » (`tutorial_j1`) et,
## dans le menu pause seulement (`in_game`) et en mode Récit, « Passer en mode
## Dur » (`hard_mode_requested` : le menu pause demande confirmation,
## irréversible, D-102).
## M14 (I44) : Accessibilité › « Cinématiques » Automatique / Manuelle
## (`cinematic_advance`) ; Audio › « Musique pendant l'inspection » Réduite /
## Normale (`music_inspection_reduce`) et « Musique » Dynamique / Stable
## (`music_dynamics`), lus par l'`AudioDirector` (`settings_changed`).
## M15 (lot A, D-213) : section **Langue** en tête — Français / English
## (noms dans leur propre langue, jamais traduits), appliquée à chaud
## (`Settings.KEY_LANGUAGE` → `Localization` : tous les écrans ouverts sont
## retraduits, ce panneau compris ; le focus reste sur le bouton choisi).
## La pseudo-localisation `en-XA` (debug) n'a **pas** de ligne : réglage caché.
class_name OptionsPanel
extends VBoxContainer

signal back_requested()
## « PASSER EN MODE DUR » (menu pause, partie en Récit).
signal hard_mode_requested()

const SLIDER_WIDTH: float = 360.0
const VOLUME_KEYS: Array[StringName] = [Settings.KEY_VOLUME_MASTER, Settings.KEY_VOLUME_MUSIC, Settings.KEY_VOLUME_AMBIENCE,
		Settings.KEY_VOLUME_SFX, Settings.KEY_VOLUME_VOICE, Settings.KEY_VOLUME_UI]
const FX_KEYS: Array[String] = ["opt_fx_full", "opt_fx_reduced", "opt_fx_off"]
const QUALITY_KEYS: Array[String] = ["opt_quality_low", "opt_quality_medium", "opt_quality_high"]
## Vision des couleurs : libellés des modes `Palette.Mode` (0–3).
const COLOR_VISION_KEYS: Array[Array] = [["opt_cv_none", "AUCUNE"], ["opt_cv_protan", "PROTAN · DEUTAN"],
	["opt_cv_tritan", "TRITAN"], ["opt_cv_contrast", "CONTRASTE ÉLEVÉ"]]
## M14 (I44) : musique pendant l'inspection (réduite / normale), musique
## dynamique / stable, avance des cinématiques (automatique / manuelle).
const MUSIC_INSPECT_KEYS: Array[Array] = [["opt_music_reduced", "RÉDUITE"], ["opt_music_normal", "NORMALE"]]
const MUSIC_DYNAMICS_KEYS: Array[Array] = [["opt_music_dynamic", "DYNAMIQUE"], ["opt_music_stable", "STABLE"]]
const CINEMATIC_KEYS: Array[Array] = [["opt_cinematic_auto", "AUTOMATIQUE"], ["opt_cinematic_manual", "MANUELLE"]]
## Glyphes manette : Auto (−1), Xbox / Steam Deck (0), PlayStation (1).
const PAD_GLYPH_KEYS: Array[Array] = [["opt_pad_auto", "AUTO"], ["opt_pad_xbox", "XBOX · DECK"], ["opt_pad_ps", "PLAYSTATION"]]
## M15 : langues proposées, libellé dans leur propre langue (endonymes).
const LANGUAGE_LABELS: Array[Array] = [["fr", "FRANÇAIS"], ["en", "ENGLISH"]]
## Hauteur laissée hors de la zone défilante (titre du panneau, marges, retour).
const SCROLL_RESERVE: float = 320.0

var back_button: Button = null
## Contrôles par clé de réglage (tests).
var controls: Dictionary[StringName, Control] = {}
## Zone défilante des réglages (focus suivi).
var scroll: ScrollContainer = null
## Menu pause (partie en cours) : ligne « Passer en mode Dur » possible.
var in_game: bool = false
var hard_mode_row: Control = null
var hard_mode_button: Button = null
## M15 : boutons de langue par code (`fr`, `en`).
var language_buttons: Dictionary[String, Button] = {}
var _rows: VBoxContainer = null


func _ready() -> void:
	add_theme_constant_override("separation", DS.SPACE_3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new()
	scroll.name = "OptionsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_rows = ScreenBase.vbox(DS.SPACE_3)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Marge droite : la barre de défilement ne recouvre jamais un contrôle.
	var pad: MarginContainer = MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", DS.SPACE_4)
	pad.add_child(_rows)
	scroll.add_child(pad)
	_rows.minimum_size_changed.connect(_fit_height)
	_add_language_row()
	_rows.add_child(ScreenBase.section(UiText.t("opt_accessibility", "ACCESSIBILITÉ"), UiIcon.Kind.INFO, DS.ACCENT_CYAN))
	_add_slider(Settings.KEY_TEXT_SCALE, UiText.t("opt_text_scale", "Taille du texte"), Settings.TEXT_SCALE_MIN,
			Settings.TEXT_SCALE_MAX, Settings.TEXT_SCALE_STEP, true)
	_add_fx_row()
	_add_choice_row(Settings.KEY_COLOR_VISION, UiText.t("opt_color_vision", "Vision des couleurs"),
			UiText.t("opt_color_vision_hint", "Couleurs d'état distinguables ; icônes et motifs restent affichés."),
			COLOR_VISION_KEYS, [0.0, 1.0, 2.0, 3.0])
	_add_toggle(Settings.KEY_HOLO_FLICKER, UiText.t("opt_holo_flicker", "Scintillement holographique"),
			UiText.t("opt_holo_flicker_hint", "Désactivé : plus aucun clignotement ni défilement (cadres des documents, hologrammes, néons instables et écrans du guichet). Les lueurs restent."))
	_add_quality_row()
	_add_toggle(Settings.KEY_REDUCE_MOTION, UiText.t("opt_reduce_motion", "Réduire les animations"),
			UiText.t("opt_reduce_motion_hint", "Marche du passager raccourcie (≤ 1 s), pas de travelling."))
	_add_toggle(Settings.KEY_SUBTITLES, UiText.t("opt_subtitles", "Sous-titres"),
			UiText.t("opt_subtitles_hint", "Voix des passagers en tessar, sous-titrées en français."))
	_add_toggle(Settings.KEY_CLOCK_SLOW_ACCESSIBILITY, UiText.t("opt_clock_slow", "Horloge du shift ralentie (×0,5)"),
			UiText.t("opt_clock_slow_hint", "Les gains par cas sont inchangés."))
	_add_choice_row(Settings.KEY_CINEMATIC_ADVANCE, UiText.t("opt_cinematic_advance", "Cinématiques"),
			UiText.t("opt_cinematic_hint", "Manuelle : chaque planche attend un appui. Maintenir pour tout passer."),
			CINEMATIC_KEYS, [Settings.CINEMATIC_AUTO, Settings.CINEMATIC_MANUAL])
	_rows.add_child(ScreenBase.section(UiText.t("opt_audio", "AUDIO"), UiIcon.Kind.CHAT, Palette.TEXT_SECONDARY))
	for key: StringName in VOLUME_KEYS:
		_add_slider(key, UiText.t("opt_%s" % key, String(key)), 0.0, 1.0, 0.05, true)
	_add_toggle(Settings.KEY_AUDIO_MONO, UiText.t("opt_audio_mono", "Son mono"),
			UiText.t("opt_audio_mono_hint", "Gauche et droite mélangées : aucun son ne se perd d'une seule oreille."))
	_add_bool_choice_row(Settings.KEY_MUSIC_INSPECTION_REDUCE, UiText.t("opt_music_inspect", "Musique pendant l'inspection"),
			UiText.t("opt_music_inspect_hint", "Réduite : plus basse et sans mélodie en Mode Inspection."), MUSIC_INSPECT_KEYS)
	_add_choice_row(Settings.KEY_MUSIC_DYNAMICS, UiText.t("opt_music_dynamics", "Musique"),
			UiText.t("opt_music_dynamics_hint", "Stable : un seul niveau pendant le shift, sans montée de tension."),
			MUSIC_DYNAMICS_KEYS, [Settings.MUSIC_DYNAMIC, Settings.MUSIC_STABLE])
	_rows.add_child(ScreenBase.section(UiText.t("opt_controls", "COMMANDES"), UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY))
	_add_choice_row(Settings.KEY_PAD_GLYPHS, UiText.t("opt_pad_glyphs", "Glyphes de manette"),
			UiText.t("opt_pad_glyphs_hint", "Les invites suivent le dernier appareil utilisé, clavier ou manette."),
			PAD_GLYPH_KEYS, [-1.0, 0.0, 1.0])
	_rows.add_child(_controls_summary())
	_add_game_section()
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	add_child(row)
	row.add_child(ScreenBase.label(UiText.t("opt_saved", "Réglages enregistrés automatiquement."), &"CaptionLabel"))
	row.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("opt_back", "RETOUR"))
	back_button.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back_button)


## Section « PARTIE » : tutoriel du J1, cartes d'aide M13 ; « Passer en mode
## Dur » (pause, Récit).
func _add_game_section() -> void:
	_rows.add_child(ScreenBase.section(UiText.t("opt_game", "PARTIE"), UiIcon.Kind.LOGO, Palette.TEXT_SECONDARY))
	_add_toggle(Settings.KEY_TUTORIAL, UiText.t("opt_tutorial", "Tutoriel du jour 1"),
			UiText.t("opt_tutorial_hint", "Gestes guidés au premier jour d'une partie ; se désactive une fois terminé ou passé."))
	# M13 : cartes d'aide du premier jour des déclarations (R43) et du portique (R44).
	_add_toggle(Settings.KEY_TUTORIAL_M13_STATEMENTS, UiText.t("opt_help_statements", "Aide : déclarations"),
			UiText.t("opt_help_statements_hint", "Carte d'aide au premier jour où les réponses orales se comparent (J4)."))
	_add_toggle(Settings.KEY_TUTORIAL_M13_SEARCH, UiText.t("opt_help_search", "Aide : portique"),
			UiText.t("opt_help_search_hint", "Carte d'aide au premier jour du portique de fouille (J8)."))
	var row: HBoxContainer = _row(UiText.t("opt_hard_mode", "Mode Récit en cours"),
			UiText.t("opt_hard_mode_hint", "Passer en Dur rétablit le chrono et les amendes. Irréversible pour cette partie."))
	row.name = "HardModeRow"
	hard_mode_button = ScreenBase.button(UiText.t("opt_hard_mode_button", "PASSER EN MODE DUR"), &"ButtonTool")
	hard_mode_button.name = "HardMode"
	hard_mode_button.custom_minimum_size.y = DS.HIT_TARGET_MIN
	hard_mode_button.pressed.connect(func() -> void: hard_mode_requested.emit())
	row.add_child(hard_mode_button)
	hard_mode_row = row
	refresh_game_section()


## Ligne « Passer en mode Dur » visible seulement en jeu et en mode Récit.
func refresh_game_section() -> void:
	if hard_mode_row != null:
		hard_mode_row.visible = in_game and GameState.is_story_mode()


func focus_first() -> void:
	var first: Control = first_control()
	if first != null:
		first.grab_focus()


## Premier réglage (focus par défaut, manette) : la langue active (M15).
func first_control() -> Control:
	var active: Button = language_buttons.get(Settings.language, null)
	if active != null:
		return active
	return controls.get(Settings.KEY_LANGUAGE, controls.get(Settings.KEY_TEXT_SCALE, null))


## M15 : section « LANGUE » — un bouton par langue, l'actif coché ; un clic
## applique la langue à chaud (`Settings.set_value`).
func _add_language_row() -> void:
	_rows.add_child(ScreenBase.section(UiText.t("opt_language_section", "LANGUE"), UiIcon.Kind.CHAT, DS.ACCENT_CYAN))
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.name = "LanguageRow"
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.add_child(ScreenBase.label(UiText.t("opt_language", "Langue du jeu"), &"BodyLabel"))
	texts.add_child(ScreenBase.wrapped(UiText.t("opt_language_hint",
			"Textes, documents, sous-titres et annonces. Noms propres, tessar et codes ne sont pas traduits."), &"CaptionLabel"))
	box.add_child(texts)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 0)
	buttons.add_theme_constant_override("v_separation", DS.SPACE_1)
	box.add_child(buttons)
	var group: ButtonGroup = ButtonGroup.new()
	var current: String = Settings.language
	for entry: Array in LANGUAGE_LABELS:
		var code: String = entry[0]
		var b: Button = Button.new()
		b.name = "Lang_%s" % code
		b.theme_type_variation = &"ToggleTab"
		b.toggle_mode = true
		b.button_group = group
		b.text = entry[1]
		b.custom_minimum_size = Vector2(160, DS.HIT_TARGET_MIN)
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = current == code
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(Settings.KEY_LANGUAGE, code))
		buttons.add_child(b)
		language_buttons[code] = b
		if code == Localization.LANG_FR:
			controls[Settings.KEY_LANGUAGE] = b
	_rows.add_child(box)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_fit_height.call_deferred()


## Hauteur de la zone défilante : tout le contenu s'il tient, sinon la
## hauteur de l'écran moins `SCROLL_RESERVE` (le reste défile).
func _fit_height() -> void:
	if scroll == null or _rows == null or not is_inside_tree():
		return
	var room: float = get_viewport_rect().size.y - SCROLL_RESERVE
	scroll.custom_minimum_size.y = clampf(_rows.get_combined_minimum_size().y, DS.HIT_TARGET_MIN * 4.0, maxf(room, DS.HIT_TARGET_MIN * 4.0))


## Rappel du schéma de commandes (UI_FLOW §9) : glyphes clavier + manette.
func _controls_summary() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = "ControlsSummary"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_2)
	for entry: Array in ControlsMap.SUMMARY:
		var action: StringName = entry[0]
		var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
		keys.add_child(PromptGlyph.make(action).with_device(InputPrompts.Device.KEYBOARD))
		keys.add_child(PromptGlyph.make(action).with_device(InputPrompts.pad_style()))
		grid.add_child(keys)
		var caption: Label = ScreenBase.label(UiText.t(entry[1], entry[2]), &"CaptionLabel")
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(caption)
	return grid


func _row(caption: String, hint: String = "") -> HBoxContainer:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	row.custom_minimum_size.y = DS.HIT_TARGET_MIN
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(ScreenBase.label(caption, &"BodyLabel"))
	if not hint.is_empty():
		texts.add_child(ScreenBase.wrapped(hint, &"CaptionLabel"))
	_rows.add_child(row)
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
	var row: HBoxContainer = _row(UiText.t("opt_fx", "Effets visuels"), UiText.t("opt_fx_hint", "Intensité des lueurs et halos, des scanlines et des animations d'effet (liens, tampons, néons, pluie). Désactivés : tout est fixe, sans halo."))
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


## Choix exclusif (boutons à bascule) ; `values` = valeur du réglage par bouton.
## Les boutons passent sous le libellé (ils ne tiendraient pas à côté au Deck).
func _add_choice_row(key: StringName, caption: String, hint: String, labels: Array[Array], values: Array[float]) -> void:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.add_child(ScreenBase.label(caption, &"BodyLabel"))
	if not hint.is_empty():
		texts.add_child(ScreenBase.wrapped(hint, &"CaptionLabel"))
	box.add_child(texts)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 0)
	buttons.add_theme_constant_override("v_separation", DS.SPACE_1)
	box.add_child(buttons)
	var group: ButtonGroup = ButtonGroup.new()
	var current: float = Settings.get_float(key)
	for i: int in labels.size():
		var value: float = values[i]
		var b: Button = Button.new()
		b.theme_type_variation = &"ToggleTab"
		b.toggle_mode = true
		b.button_group = group
		b.text = UiText.t(labels[i][0], labels[i][1])
		b.custom_minimum_size = Vector2(120, DS.HIT_TARGET_MIN)
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = is_equal_approx(current, value)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(key, value))
		buttons.add_child(b)
		if i == 0:
			controls[key] = b
	_rows.add_child(box)


## Choix exclusif sur un réglage booléen : premier bouton = vrai, second = faux.
func _add_bool_choice_row(key: StringName, caption: String, hint: String, labels: Array[Array]) -> void:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.add_child(ScreenBase.label(caption, &"BodyLabel"))
	if not hint.is_empty():
		texts.add_child(ScreenBase.wrapped(hint, &"CaptionLabel"))
	box.add_child(texts)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 0)
	buttons.add_theme_constant_override("v_separation", DS.SPACE_1)
	box.add_child(buttons)
	var group: ButtonGroup = ButtonGroup.new()
	var current: bool = Settings.get_bool(key)
	for i: int in labels.size():
		var value: bool = i == 0
		var b: Button = Button.new()
		b.theme_type_variation = &"ToggleTab"
		b.toggle_mode = true
		b.button_group = group
		b.text = UiText.t(labels[i][0], labels[i][1])
		b.custom_minimum_size = Vector2(120, DS.HIT_TARGET_MIN)
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = current == value
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(key, value))
		buttons.add_child(b)
		if i == 0:
			controls[key] = b
	_rows.add_child(box)


static func _toggle_text(on: bool) -> String:
	if not on:
		return UiText.t("opt_off", "DÉSACTIVÉ")
	return UiText.remember_call("✓ " + UiText.t("opt_on", "ACTIVÉ"), _toggle_text.bind(on))


static func _percent(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)


## Piste et poignée DS (rectangles, pas d'arrondi ; cyan = interactif).
static func _style_slider(slider: HSlider) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Palette.LINE_SUBTLE
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
