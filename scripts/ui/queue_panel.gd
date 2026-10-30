## Compteurs de file (UI_FLOW §2.2 zone B droite) : passager n / total, en
## attente, discordances documentées (ou « EN APPROCHE »). Posé sur la vitre.
## M13 (lot C, I39) : **pastilles** des améliorations du guichet possédées
## (code + icône, nom en infobulle) ; AG-06 « Moniteur de file » : ligne de
## **manifeste** du passager pendant sa marche (données présentées).
class_name QueuePanel
extends PanelContainer

enum Status { IDLE, APPROACHING, INSPECTING }

var _passenger_value: Label = null
var _passenger_total: Label = null
var _waiting_value: Label = null
var _status_icon: UiIcon = null
var _status_label: Label = null
var _manifest: Label = null
var _upgrades_row: HBoxContainer = null


## M12 : file sans fin (Garde de nuit) — « ∞ » au lieu du total.
var endless: bool = false


func _ready() -> void:
	theme_type_variation = &"VeilPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(box)
	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", DS.SPACE_8)
	box.add_child(grid)
	var passenger: VBoxContainer = _stat(grid, UiText.t("qp_passenger", "PASSAGER"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_2)
	passenger.add_child(row)
	_passenger_value = Label.new()
	_passenger_value.theme_type_variation = &"DataTitle"
	row.add_child(_passenger_value)
	_passenger_total = Label.new()
	_passenger_total.theme_type_variation = &"DataSmall"
	_passenger_total.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_passenger_total)
	var waiting: VBoxContainer = _stat(grid, UiText.t("qp_waiting", "EN ATTENTE"))
	_waiting_value = Label.new()
	_waiting_value.theme_type_variation = &"DataTitle"
	waiting.add_child(_waiting_value)
	var line: ColorRect = ColorRect.new()
	line.color = Palette.LINE_SUBTLE
	line.custom_minimum_size.y = 1
	box.add_child(line)
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", DS.SPACE_2)
	box.add_child(status)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"DocFieldLabel"
	caption.uppercase = true
	caption.text = UiText.t("qp_discrepancies", "DISCORDANCES")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(caption)
	_status_icon = UiIcon.make(UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY, DS.ICON_S)
	status.add_child(_status_icon)
	_status_label = Label.new()
	_status_label.theme_type_variation = &"DocFieldLabel"
	_status_label.uppercase = true
	status.add_child(_status_label)
	_manifest = Label.new()
	_manifest.name = "Manifest"
	_manifest.theme_type_variation = &"DataSmall"
	_manifest.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	_manifest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_manifest.visible = false
	box.add_child(_manifest)
	_upgrades_row = HBoxContainer.new()
	_upgrades_row.name = "Upgrades"
	_upgrades_row.add_theme_constant_override("separation", DS.SPACE_2)
	_upgrades_row.visible = false
	box.add_child(_upgrades_row)
	set_queue(0, 0)
	set_status(Status.IDLE, 0)


func _stat(parent: Container, caption_text: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", DS.SPACE_1)
	parent.add_child(column)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"DocFieldLabel"
	caption.uppercase = true
	caption.text = caption_text
	column.add_child(caption)
	return column


## `number` 1-based (0 = aucun passager), `total` du jour.
func set_queue(number: int, total: int) -> void:
	_passenger_value.text = "%02d" % number if number > 0 else "—"
	_passenger_total.text = "/ %02d" % total if total > 0 else ""
	_waiting_value.text = "%02d" % maxi(total - number, 0) if total > 0 else "—"
	if endless:
		# M12 : Garde de nuit, file sans fin.
		_passenger_total.text = UiText.t("qp_endless_total", "/ ∞")
		_waiting_value.text = UiText.t("qp_endless", "∞")


func set_status(status: Status, discrepancies: int) -> void:
	match status:
		Status.APPROACHING:
			_status_icon.kind = UiIcon.Kind.DIAMOND
			_status_icon.color = Palette.STATE_AMBER
			_status_label.text = UiText.t("qp_approaching", "EN APPROCHE")
			_status_label.add_theme_color_override(&"font_color", Palette.STATE_AMBER)
		Status.INSPECTING when discrepancies > 0:
			_status_icon.kind = UiIcon.Kind.WARNING
			_status_icon.color = Palette.ACCENT_MAGENTA
			_status_label.text = UiText.plural("qp_documented", discrepancies, "%d DOCUMENTÉE", "%d DOCUMENTÉES")
			_status_label.add_theme_color_override(&"font_color", Palette.ACCENT_MAGENTA)
		Status.INSPECTING:
			_status_icon.kind = UiIcon.Kind.DIAMOND
			_status_icon.color = Palette.TEXT_SECONDARY
			_status_label.text = UiText.t("qp_none", "AUCUNE")
			_status_label.add_theme_color_override(&"font_color", Palette.TEXT_SECONDARY)
		_:
			_status_icon.kind = UiIcon.Kind.DIAMOND
			_status_icon.color = DS.TEXT_MUTED
			_status_label.text = "—"
			_status_label.add_theme_color_override(&"font_color", Palette.TEXT_SECONDARY)


func get_status_text() -> String:
	return _status_label.text


## M13 (AG-06) : ligne de manifeste du passager qui marche ; vide = masquée.
func set_manifest(text: String) -> void:
	if _manifest == null:
		return
	_manifest.text = text
	_manifest.visible = not text.is_empty()


func get_manifest_text() -> String:
	return _manifest.text if _manifest != null and _manifest.visible else ""


## M13 (I39) : pastilles des améliorations possédées (« AG-01 »…, icône
## d'outil, nom en infobulle) ; aucune = rangée masquée.
func set_upgrades(ids: Array[StringName]) -> void:
	if _upgrades_row == null:
		return
	for child: Node in _upgrades_row.get_children():
		_upgrades_row.remove_child(child)
		child.queue_free()
	_upgrades_row.visible = not ids.is_empty()
	if ids.is_empty():
		return
	var caption: Label = Label.new()
	caption.theme_type_variation = &"DocFieldLabel"
	caption.uppercase = true
	caption.text = UiText.t("qp_upgrades", "GUICHET")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_upgrades_row.add_child(caption)
	for upgrade_id: StringName in ids:
		var chip: PanelContainer = ScreenBase.chip(String(upgrade_id).to_upper().insert(2, "-"), UiIcon.Kind.TOOL, Palette.TEXT_SECONDARY)
		chip.name = "Upgrade_%s" % upgrade_id
		chip.tooltip_text = UiText.t("upg_%s_name" % upgrade_id, String(upgrade_id))
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		_upgrades_row.add_child(chip)


func upgrade_count() -> int:
	return maxi(_upgrades_row.get_child_count() - 1, 0) if _upgrades_row != null and _upgrades_row.visible else 0
