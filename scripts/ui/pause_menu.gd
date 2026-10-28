## Menu pause (UI_FLOW §3.5, §8 ; non diégétique, DS §1.5).
##
## S'ouvre par Échap **quand l'interface n'a rien à annuler** (`ComparisonUI`
## laisse alors passer l'événement, D-040 / UI_FLOW §3.5), F10 ou Menu/Start
## de la manette : arbre en pause (l'horloge du shift et le booth sont gelés),
## plan de travail flouté. Entrées : REPRENDRE · OPTIONS (`OptionsPanel`) ·
## QUITTER VERS LE TITRE (second appui de confirmation : la progression du jour
## en cours est perdue, la sauvegarde du matin reste). Échap / Ⓑ : retour /
## reprendre.
class_name PauseMenu
extends Control

signal quit_to_title_requested()

const BLUR_SHADER: Shader = preload("res://assets/shaders/ui_backdrop_blur.gdshader")
const PANEL_WIDTH: float = 560.0
const OPTIONS_WIDTH: float = 880.0

var is_open: bool = false
## Désactivé pendant les écrans qui ne doivent pas être mis en pause.
var enabled: bool = true
var resume_button: Button = null
var options: OptionsPanel = null

var _menu_box: VBoxContainer = null
var _panel: PanelContainer = null
var _quit_button: Button = null
var _quit_armed: bool = false
var _applied_min_px: int = -1


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_apply_theme()
	EventBus.settings_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key == Settings.KEY_TEXT_SCALE:
			_apply_theme())
	var blur: ColorRect = ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	blur.material = mat
	add_child(blur)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"SystemPanel"
	_panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(_panel)
	var stack: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	_panel.add_child(stack)
	_menu_box = ScreenBase.vbox(DS.SPACE_3)
	stack.add_child(_menu_box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	_menu_box.add_child(head)
	head.add_child(ScreenBase.label(UiText.t("pause_title", "PAUSE"), &"DisplayLabel"))
	head.add_child(ScreenBase.spacer())
	var keys: Label = ScreenBase.label(UiText.t("pause_keys", "ÉCHAP · F10 · MENU"), &"KeyCapLabel")
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(keys)
	_menu_box.add_child(ScreenBase.wrapped(UiText.t("pause_hint", "Le shift est suspendu : l'horloge et la file sont arrêtées."), &"BodySmall"))
	_menu_box.add_child(ScreenBase.rule_line())
	resume_button = ScreenBase.button(UiText.t("pause_resume", "REPRENDRE"), &"ButtonPrimary")
	resume_button.pressed.connect(close)
	_menu_box.add_child(resume_button)
	var options_button: Button = ScreenBase.button(UiText.t("pause_options", "OPTIONS"))
	options_button.pressed.connect(show_options)
	_menu_box.add_child(options_button)
	_quit_button = ScreenBase.button(UiText.t("pause_quit", "QUITTER VERS LE TITRE"))
	_quit_button.pressed.connect(_on_quit_pressed)
	_menu_box.add_child(_quit_button)
	options = OptionsPanel.new()
	options.visible = false
	options.back_requested.connect(show_menu)
	stack.add_child(options)


func _apply_theme() -> void:
	var min_px: int = ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x) if is_inside_tree() else 0
	_applied_min_px = min_px
	theme = ThemeBuilder.build(Settings.text_scale, min_px)


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	show_menu()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Settings.save_settings()
	get_tree().paused = false


func show_options() -> void:
	_menu_box.visible = false
	options.visible = true
	_panel.custom_minimum_size.x = OPTIONS_WIDTH
	options.focus_first.call_deferred()


func show_menu() -> void:
	options.visible = false
	_menu_box.visible = true
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_quit_armed = false
	_quit_button.text = UiText.t("pause_quit", "QUITTER VERS LE TITRE")
	_quit_button.theme_type_variation = &"ButtonTool"
	resume_button.grab_focus.call_deferred()


## Premier appui : demande confirmation ; second : retour au titre.
func _on_quit_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_button.text = UiText.t("pause_quit_confirm", "CONFIRMER : LE SHIFT EN COURS SERA PERDU")
		_quit_button.theme_type_variation = &"ButtonDanger"
		return
	close()
	quit_to_title_requested.emit()


static func is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"cancel", false, true):
		return true
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F10:
		return true
	var pad: InputEventJoypadButton = event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == JOY_BUTTON_START


func _unhandled_input(event: InputEvent) -> void:
	if is_open or not enabled:
		return
	if is_pause_event(event):
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if is_pause_event(event):
		if options.visible:
			show_menu()
		else:
			close()
		get_viewport().set_input_as_handled()
