## Compteur « QUOTA n/max » de la barre d'état (Acte II, R23, D-077 ;
## ARCHITECTURE §7.2, UI_FLOW §8.3) : entrées imputables du shift sur le
## maximum du jour, ambre « QUOTA ATTEINT » dès que le compteur est plein.
## **Sélectionnable en Mode Inspection** comme un champ (`FieldRef.quota_counter()`) :
## la paire « Compteur ↔ R23 » documente un refus motivé par le quota.
## Masqué tant que le jour n'a pas de quota (`maximum` 0).
class_name QuotaCounterView
extends InspectableItem

var used: int = 0
var maximum: int = 0

var _caption: Label = null
var _value: Label = null
var _icon: UiIcon = null


func _init() -> void:
	super._init()
	ref = FieldRef.quota_counter()
	comparable = true
	visible = false
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_2)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_2)
	margin.add_child(row)
	_icon = UiIcon.make(UiIcon.Kind.BREATH, DS.TEXT_SECONDARY, DS.ICON_M)
	row.add_child(_icon)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	_caption = Label.new()
	_caption.theme_type_variation = &"DocFieldLabel"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_caption)
	_value = Label.new()
	_value.theme_type_variation = &"DocFieldValue"
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_value)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)
	set_quota(0, 0)


func is_full() -> bool:
	return maximum > 0 and used >= maximum


## `maximum` 0 = pas de quota ce jour (compteur masqué, non comparable).
func set_quota(p_used: int, p_maximum: int) -> void:
	used = maxi(p_used, 0)
	maximum = maxi(p_maximum, 0)
	visible = maximum > 0
	comparable = maximum > 0
	_caption.text = UiText.t("tb_quota_caption", "QUOTA")
	if is_full():
		_value.text = UiText.tf("tb_quota_reached", [used, maximum], "ATTEINT · %d / %d")
	else:
		_value.text = UiText.tf("tb_quota_value", [used, maximum], "%d / %d")
	display_label = "%s %s" % [_caption.text, _value.text]
	tooltip_text = UiText.t("tb_quota_tip", "Entrées imputables du jour. Mode Inspection : comparez le compteur à la règle du quota.")
	_refresh_content()
	queue_redraw()


func get_value_text() -> String:
	return _value.text


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size = Vector2(maxf(margin.get_combined_minimum_size().x, DS.HIT_TARGET_MIN),
			maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y))


func _refresh_content() -> void:
	if _value == null:
		return
	var color: Color = DS.STATE_AMBER if is_full() else DS.TEXT_PRIMARY
	if is_flagged():
		color = DS.ACCENT_MAGENTA
	elif selected:
		color = DS.ACCENT_CYAN
	_value.add_theme_color_override(&"font_color", color)
	_caption.add_theme_color_override(&"font_color", DS.STATE_AMBER if is_full() and not is_flagged() and not selected else DS.TEXT_SECONDARY)
	_icon.color = color if is_full() or is_flagged() or selected else DS.TEXT_SECONDARY


func _draw() -> void:
	if is_full() and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.AMBER_12)
		draw_rect(Rect2(Vector2(0.0, size.y - DS.BORDER_STRONG), Vector2(size.x, DS.BORDER_STRONG)), DS.STATE_AMBER)
	super._draw()


## Cadre complet en inspection (comme une règle) : la barre n'a pas de ligne de base.
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
