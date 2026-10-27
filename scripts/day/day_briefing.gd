## Briefing du jour (INTRO, ARCHITECTURE §8) : « JOUR N — directive du jour ».
##
## Panneau DS minimal plein écran (voile `DS.SCRIM`), au-dessus de l'UI et du
## booth ; se ferme au clic, à une touche ou à un bouton de manette et émet
## `closed` (le DayScene y branche `DayController.close_intro()`).
## M5 : remplacé par l'écran d'intro de l'UI (nouveautés du Rulebook, famille…).
class_name DayBriefing
extends Control

signal closed()

var _closed: bool = false
var _title: Label = null
var _text: Label = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = ThemeBuilder.build()
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HoloPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", DS.SPACE_4)
	panel.add_child(box)
	var eyebrow: Label = Label.new()
	eyebrow.theme_type_variation = &"DocFieldLabel"
	eyebrow.text = UiText.t("briefing_eyebrow", "Halcyon Gate · Guichet 04 · Directive du jour")
	eyebrow.uppercase = true
	box.add_child(eyebrow)
	_title = Label.new()
	_title.theme_type_variation = &"DisplayLabel"
	_title.add_theme_color_override(&"font_color", DS.ACCENT_YELLOW)
	box.add_child(_title)
	_text = Label.new()
	_text.theme_type_variation = &"TitleLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = UiText.t("briefing_hint", "Cliquez ou appuyez sur une touche pour ouvrir le guichet")
	box.add_child(hint)


func setup(day: DayDef) -> void:
	if day == null:
		return
	_title.text = UiText.tf("briefing_title", [day.day_number], "JOUR %d")
	_text.text = UiText.t(day.intro_text_key, day.intro_text_key)


func close() -> void:
	if _closed:
		return
	_closed = true
	visible = false
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed or event is InputEventMouseMotion:
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
			and event.is_pressed() and not event.is_echo()
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	if pressed:
		close()
