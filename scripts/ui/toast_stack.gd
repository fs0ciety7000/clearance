## Toasts et avis imprimés (DS §7.8, §7.9) : empilés en haut à droite, sous les
## compteurs, max 3, `DS.TOAST_HOLD` (×2 au-delà de 80 caractères).
class_name ToastStack
extends VBoxContainer

enum Kind { INFO, SUCCESS, WARNING, ERROR, NARRATIVE }

const MAX_VISIBLE: int = 3
const LONG_TEXT: int = 80


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", DS.SPACE_2)


static func accent_of(kind: Kind) -> Color:
	match kind:
		Kind.SUCCESS:
			return DS.STATE_GREEN
		Kind.WARNING:
			return DS.STATE_AMBER
		Kind.ERROR:
			return DS.STATE_RED
		Kind.NARRATIVE:
			return DS.ACCENT_MAGENTA
	return DS.ACCENT_CYAN


static func icon_of(kind: Kind) -> UiIcon.Kind:
	match kind:
		Kind.SUCCESS:
			return UiIcon.Kind.APPROVED
		Kind.WARNING:
			return UiIcon.Kind.WARNING
		Kind.ERROR:
			return UiIcon.Kind.DENIED
		Kind.NARRATIVE:
			return UiIcon.Kind.DISCORDANCE
	return UiIcon.Kind.INFO


static func variation_of(kind: Kind) -> StringName:
	match kind:
		Kind.SUCCESS:
			return &"ToastSuccess"
		Kind.WARNING:
			return &"ToastWarning"
		Kind.ERROR:
			return &"ToastError"
		Kind.NARRATIVE:
			return &"ToastNarrative"
	return &"ToastInfo"


## Toast simple ; `side` = texte mono à droite du titre (ex. « +5 CR »).
func push(kind: Kind, title: String, message: String, side: String = "") -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = variation_of(kind)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_3)
	panel.add_child(row)
	row.add_child(UiIcon.make(icon_of(kind), accent_of(kind), DS.ICON_M))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DS.SPACE_1)
	row.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title_label: Label = Label.new()
	title_label.theme_type_variation = &"BodyStrong"
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	if not side.is_empty():
		var side_label: Label = Label.new()
		side_label.theme_type_variation = &"DocFieldValue"
		side_label.add_theme_color_override(&"font_color", accent_of(kind))
		side_label.text = side
		head.add_child(side_label)
	if not message.is_empty():
		var text: Label = Label.new()
		text.theme_type_variation = &"BodySmall"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = message
		column.add_child(text)
	_add(panel, title.length() + message.length())
	return panel


## Avis d'infraction du Consortium (DS §7.9) : en-tête jaune, motif, sanction.
func push_citation(reason: String, sanction: String, warning: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"CitationTicket"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var header: PanelContainer = PanelContainer.new()
	header.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.ACCENT_YELLOW, DS.ACCENT_YELLOW, 0, DS.CHAMFER_S, DS.SPACE_2))
	column.add_child(header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", DS.SPACE_2)
	header.add_child(header_row)
	header_row.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.TEXT_ON_ACCENT, DS.ICON_S))
	var header_label: Label = Label.new()
	header_label.theme_type_variation = &"BadgeLabel"
	header_label.uppercase = true
	header_label.text = UiText.t("cit_header", "CONSORTIUM · AVIS D'INFRACTION")
	header_row.add_child(header_label)
	var body: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, DS.SPACE_3)
	column.add_child(body)
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", DS.SPACE_1)
	body.add_child(body_box)
	var reason_label: Label = Label.new()
	reason_label.theme_type_variation = &"BodyStrong"
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.text = reason
	body_box.add_child(reason_label)
	var sanction_row: HBoxContainer = HBoxContainer.new()
	sanction_row.add_theme_constant_override("separation", DS.SPACE_2)
	body_box.add_child(sanction_row)
	var accent: Color = DS.STATE_AMBER if warning else DS.STATE_RED
	sanction_row.add_child(UiIcon.make(UiIcon.Kind.WARNING if warning else UiIcon.Kind.DENIED, accent, DS.ICON_S))
	var sanction_label: Label = Label.new()
	sanction_label.theme_type_variation = &"DocFieldValue"
	sanction_label.add_theme_color_override(&"font_color", accent)
	sanction_label.text = sanction
	sanction_row.add_child(sanction_label)
	_add(panel, reason.length())
	return panel


func _add(panel: PanelContainer, length: int) -> void:
	add_child(panel)
	while get_child_count() > MAX_VISIBLE:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, DS.DUR_BASE)
	tween.tween_interval(DS.TOAST_HOLD * (2.0 if length > LONG_TEXT else 1.0))
	tween.tween_property(panel, "modulate:a", 0.0, DS.DUR_BASE * 0.7)
	tween.tween_callback(panel.queue_free)
