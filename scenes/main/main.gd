## Bootstrap (M1) : applique le thème DS et affiche l'écran titre placeholder.
## Le lancement du shift sera branché en M5 (chargement de `day.tscn`).
extends Control

## Émis quand le joueur demande à commencer le shift (placeholder M1).
signal shift_start_requested()

@onready var _background: ColorRect = %Background
@onready var _title: Label = %Title
@onready var _start_button: Button = %StartButton
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	theme = ThemeBuilder.build()
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	_background.color = DS.BG_VOID
	_title.add_theme_font_size_override(&"font_size", DS.FS_DISPLAY_XL)
	_title.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	_content.add_theme_constant_override(&"separation", DS.SPACE_6)
	_start_button.custom_minimum_size = Vector2(0, DS.HIT_TARGET_MIN + DS.SPACE_1)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus.call_deferred()


func _on_start_pressed() -> void:
	print_rich("[CLEARANCE] Commencer le shift — à brancher en M5 (DayController).")
	shift_start_requested.emit()
