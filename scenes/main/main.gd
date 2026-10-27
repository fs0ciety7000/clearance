## Bootstrap : applique le thème DS et affiche l'écran titre (UI_FLOW §8).
## M5 : « CONTINUER » (CTA jaune, focus par défaut) si une sauvegarde existe
## (`SaveService`, chargée par `GameState.load_from_slot`), « NOUVELLE
## PARTIE » (efface l'ancienne sauvegarde), « OPTIONS » (`OptionsPanel`),
## « QUITTER ». Le jour courant est ensuite joué dans `day.tscn`.
extends Control

const DAY_SCENE_PATH: String = "res://scenes/main/day.tscn"

## Émis quand le joueur demande à commencer le shift.
signal shift_start_requested()

@onready var _background: ColorRect = %Background
@onready var _title: Label = %Title
@onready var _start_button: Button = %StartButton
@onready var _content: VBoxContainer = %Content

var continue_button: Button = null
var new_game_button: Button = null
var options_button: Button = null
var quit_button: Button = null
var options: OptionsPanel = null
var _menu: Array[Control] = []
var _saved_day: int = 0


func _ready() -> void:
	get_tree().paused = false
	theme = ThemeBuilder.build(Settings.text_scale)
	EventBus.settings_changed.connect(func(key: StringName, value: Variant) -> void:
		if key == Settings.KEY_TEXT_SCALE:
			var scale_value: float = value
			theme = ThemeBuilder.build(scale_value))
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	_background.color = DS.BG_VOID
	_title.add_theme_font_size_override(&"font_size", DS.FS_DISPLAY_XL)
	_title.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	_content.add_theme_constant_override(&"separation", DS.SPACE_4)
	var version: Label = _content.get_node_or_null("Version") as Label
	if version != null:
		version.text = UiText.t("title_version", "Vertical slice M5 — Jours 1 à 3")
	var save: Dictionary = SaveService.load_slot()
	_saved_day = SaveService.as_int(save.get("current_day", 0)) if not save.is_empty() else 0
	# Le bouton de la scène devient le CTA principal (Continuer ou Nouvelle partie).
	_start_button.custom_minimum_size = Vector2(360, DS.HIT_TARGET_MIN + DS.SPACE_1)
	if _saved_day > 0:
		continue_button = _start_button
		continue_button.text = UiText.tf("title_continue", [_saved_day], "CONTINUER — JOUR %d")
		continue_button.pressed.connect(_on_continue_pressed)
		new_game_button = _add_button(UiText.t("title_new_game", "NOUVELLE PARTIE"), _on_new_game_pressed)
	else:
		new_game_button = _start_button
		new_game_button.text = UiText.t("title_new_game", "NOUVELLE PARTIE")
		new_game_button.pressed.connect(_on_new_game_pressed)
	_menu.append(_start_button)
	options_button = _add_button(UiText.t("title_options", "OPTIONS"), _show_options)
	quit_button = _add_button(UiText.t("title_quit", "QUITTER"), func() -> void: get_tree().quit())
	if version != null:
		_content.move_child(version, _content.get_child_count() - 1)
	options = OptionsPanel.new()
	options.visible = false
	options.custom_minimum_size.x = 800.0
	options.back_requested.connect(_show_menu)
	_content.add_child(options)
	_start_button.grab_focus.call_deferred()


func _add_button(text: String, callback: Callable) -> Button:
	var b: Button = ScreenBase.button(text, &"ButtonTool")
	b.custom_minimum_size.x = 360.0
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(callback)
	_content.add_child(b)
	_menu.append(b)
	return b


func _show_options() -> void:
	for item: Control in _menu:
		item.visible = false
	options.visible = true
	options.focus_first.call_deferred()


func _show_menu() -> void:
	options.visible = false
	for item: Control in _menu:
		item.visible = true
	options_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if options != null and options.visible and event.is_action_pressed(&"cancel", false, true):
		_show_menu()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	if not GameState.load_from_slot():
		_on_new_game_pressed()
		return
	_start_day()


func _on_new_game_pressed() -> void:
	SaveService.delete()
	Campaign.new_game(DataCatalog.load_from())
	_start_day()


func _start_day() -> void:
	shift_start_requested.emit()
	get_tree().change_scene_to_file(DAY_SCENE_PATH)
