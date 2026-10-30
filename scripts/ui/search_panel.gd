## Portique holographique PH-1 (M13 lot C, I36 ; M13 §2.2, §2.12 ;
## ARCHITECTURE §12.5) : posé dans la bande 3D **à la place du panneau File**
## (jamais devant le visage) pendant la fouille.
##
## - En-tête « PORTIQUE · FOUILLE », TOUT SCANNER, FERMER (Ⓑ / Échap).
## - Bandeau **MOTIF** : motif figé à la demande (`search_opened`) ou « AUCUN
##   MOTIF ÉTABLI » (icône + texte ambre, la fouille a été confirmée).
## - **Silhouette filaire** et **5 zones étiquetées** (Z1 tête et nuque · Z2
##   torse · Z3 bras et mains · Z4 jambes · Z5 bagage) : clic sur la zone ou
##   sur son bouton (croix + Ⓐ) ; chaque zone dit son état en toutes lettres
##   (— · EN FILE · SCAN… · RAS · n OBJETS). Balayage vertical pendant le
##   scan, remplacé par un fond hachuré fixe sous « Réduire les animations ».
## - **Objets révélés** (`SearchItemView`) par zone, sélectionnables en Mode
##   Inspection ; une zone vide affiche « RAS ».
## La logique est celle de la session : le panneau n'émet que des demandes
## (`search_requested` par la `ComparisonUI`), et n'affiche un objet qu'à
## réception de `search_zone_scanned`.
class_name SearchPanel
extends PanelContainer

signal zone_requested(zone: StringName)
signal scan_all_requested()
signal close_requested()
signal item_picked(item: InspectableItem)

const STATE_IDLE: StringName = &"idle"
const STATE_QUEUED: StringName = &"queued"
const STATE_SCANNING: StringName = &"scanning"
const STATE_DONE: StringName = &"done"
## Colonne des boutons de zone (nom de zone + état sur une ligne).
const ZONES_COLUMN_W: float = 256.0

var motive: StringName = &""
var motive_text: String = ""
var zone_states: Dictionary[StringName, StringName] = {}
var zone_counts: Dictionary[StringName, int] = {}
var zone_buttons: Dictionary[StringName, Button] = {}
var item_views: Array[SearchItemView] = []
var scan_all_button: Button = null
var close_button: Button = null
var busy: bool = false
var inspection_active: bool = false
var reduce_motion: bool = false
var fx_intensity: float = 1.0
## Zone mise en avant (survol ou focus de son bouton).
var highlighted: StringName = &""

var _motive_row: HBoxContainer = null
var _motive_icon: UiIcon = null
var _motive_label: Label = null
var _silhouette: Control = null
var _items_box: VBoxContainer = null
var _items_scroll: ScrollContainer = null
var _empty_label: Label = null
var _sweep: float = 0.0
var _order: Array[StringName] = []


func _ready() -> void:
	theme_type_variation = &"VeilPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = DS.SEARCH_PANEL_WIDTH
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	add_child(col)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	head.name = "Header"
	col.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.GATE, DS.ACCENT_CYAN, DS.ICON_M))
	var title: Label = ScreenBase.label(UiText.t("srch_title", "PORTIQUE · FOUILLE"), &"DocIssuer", DS.ACCENT_CYAN)
	title.uppercase = true
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	head.add_child(ScreenBase.spacer())
	scan_all_button = ScreenBase.button(UiText.t("srch_scan_all", "TOUT SCANNER"), &"ButtonTool")
	scan_all_button.name = "ScanAll"
	scan_all_button.custom_minimum_size.y = DS.HIT_TARGET_MIN
	scan_all_button.pressed.connect(func() -> void: scan_all_requested.emit())
	head.add_child(scan_all_button)
	close_button = ScreenBase.button(UiText.t("srch_close", "FERMER"), &"ButtonGhost")
	close_button.name = "Close"
	close_button.custom_minimum_size.y = DS.HIT_TARGET_MIN
	close_button.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close_button)
	head.add_child(PromptGlyph.make(&"cancel"))
	_motive_row = ScreenBase.hbox(DS.SPACE_2)
	_motive_row.name = "Motive"
	col.add_child(_motive_row)
	_motive_icon = UiIcon.make(UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN, DS.ICON_S)
	_motive_row.add_child(_motive_icon)
	_motive_label = ScreenBase.label("", &"DocFieldLabel", DS.ACCENT_CYAN)
	_motive_label.uppercase = true
	_motive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_motive_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_motive_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_motive_row.add_child(_motive_label)
	var body: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	body.name = "Body"
	col.add_child(body)
	_silhouette = Control.new()
	_silhouette.name = "Silhouette"
	_silhouette.custom_minimum_size = Vector2(DS.SEARCH_SILHOUETTE_W, DS.HIT_TARGET_MIN * 5 + DS.SPACE_1 * 4)
	_silhouette.mouse_filter = Control.MOUSE_FILTER_STOP
	_silhouette.draw.connect(_draw_silhouette)
	_silhouette.gui_input.connect(_on_silhouette_input)
	_silhouette.mouse_exited.connect(func() -> void: set_highlight(&""))
	body.add_child(_silhouette)
	var zones: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	zones.name = "Zones"
	zones.custom_minimum_size.x = ZONES_COLUMN_W
	body.add_child(zones)
	for zone: StringName in SearchLayout.ZONES:
		var button: Button = Button.new()
		button.name = "Zone_%s" % zone
		button.theme_type_variation = &"ButtonQuestion"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size.y = DS.HIT_TARGET_MIN
		button.pressed.connect(_on_zone_pressed.bind(zone))
		# Nom de la zone à gauche (rogné si besoin), état en toutes lettres à droite.
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = DS.SPACE_3
		row.offset_right = -DS.SPACE_3
		button.add_child(row)
		var zone_label: Label = ScreenBase.label("Z%d  %s" % [SearchLayout.ZONES.find(zone) + 1, UiText.t("zone_%s" % zone, String(zone))],
				&"BodySmall", DS.TEXT_PRIMARY)
		zone_label.name = "Name"
		zone_label.clip_text = true
		zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(zone_label)
		var state_label: Label = ScreenBase.label("", &"DocFieldLabel", Palette.TEXT_SECONDARY)
		state_label.name = "State"
		state_label.uppercase = true
		state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(state_label)
		button.mouse_entered.connect(set_highlight.bind(zone))
		button.focus_entered.connect(set_highlight.bind(zone))
		zones.add_child(button)
		zone_buttons[zone] = button
	_items_scroll = ScrollContainer.new()
	_items_scroll.name = "Items"
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_scroll.follow_focus = true
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.custom_minimum_size.y = _silhouette.custom_minimum_size.y
	body.add_child(_items_scroll)
	_items_box = ScreenBase.vbox(DS.SPACE_1)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_box)
	_empty_label = ScreenBase.wrapped(UiText.t("srch_pick_zone", "Choisissez une zone à scanner, ou TOUT SCANNER."), &"CaptionLabel")
	_empty_label.name = "EmptyHint"
	_items_box.add_child(_empty_label)
	reset()


## Nouveau cas : silhouette vide, rien de révélé.
func reset() -> void:
	motive = &""
	motive_text = ""
	busy = false
	highlighted = &""
	_order.clear()
	for zone: StringName in SearchLayout.ZONES:
		zone_states[zone] = STATE_IDLE
		zone_counts[zone] = 0
	_clear_items()
	visible = false
	_refresh()


## Fouille engagée : motif figé (`SearchLayout.MOTIVE_*`) et son texte.
func open(p_motive: StringName, text: String) -> void:
	motive = p_motive
	motive_text = text
	visible = true
	var none: bool = p_motive == SearchLayout.MOTIVE_NONE
	_motive_icon.kind = UiIcon.Kind.WARNING if none else UiIcon.Kind.DIAMOND
	_motive_icon.color = Palette.STATE_AMBER if none else DS.ACCENT_CYAN
	_motive_label.add_theme_color_override(&"font_color", Palette.STATE_AMBER if none else DS.ACCENT_CYAN)
	_motive_label.text = text
	# Une zone demandée et non scannée à la fermeture redevient libre.
	for zone: StringName in SearchLayout.ZONES:
		if zone_states[zone] != STATE_DONE:
			zone_states[zone] = STATE_IDLE
	_order.clear()
	_refresh()


func close() -> void:
	visible = false
	for zone: StringName in SearchLayout.ZONES:
		if zone_states[zone] != STATE_DONE:
			zone_states[zone] = STATE_IDLE
	_order.clear()
	busy = false


func is_open() -> bool:
	return visible


func get_motive_text() -> String:
	return _motive_label.text if _motive_label != null else ""


## Premier bouton de zone encore à scanner (focus manette), sinon TOUT SCANNER
## ou FERMER.
func first_focus() -> Control:
	for zone: StringName in SearchLayout.ZONES:
		var button: Button = zone_buttons[zone]
		if zone_states[zone] == STATE_IDLE and not button.disabled:
			return button
	return close_button


## Demande d'une zone (mise en file côté UI ; la session fait foi).
func request_zone(zone: StringName) -> bool:
	if busy or not visible or not SearchLayout.ZONES.has(zone) or zone_states[zone] != STATE_IDLE:
		return false
	zone_states[zone] = STATE_QUEUED
	_order.append(zone)
	_advance_queue()
	zone_requested.emit(zone)
	_refresh()
	return true


## TOUT SCANNER : toutes les zones libres, dans l'ordre Z1 → Z5.
func request_all() -> bool:
	if busy or not visible:
		return false
	var any: bool = false
	for zone: StringName in SearchLayout.ZONES:
		if zone_states[zone] == STATE_IDLE:
			zone_states[zone] = STATE_QUEUED
			_order.append(zone)
			any = true
	if not any:
		return false
	_advance_queue()
	scan_all_requested.emit()
	_refresh()
	return true


## Résultat d'une zone (`search_zone_scanned`).
func mark_scanned(zone: StringName, items: Array[SearchItem]) -> void:
	if not SearchLayout.ZONES.has(zone):
		return
	zone_states[zone] = STATE_DONE
	zone_counts[zone] = items.size()
	_order.erase(zone)
	_advance_queue()
	_add_zone_items(zone, items)
	_refresh()


## Zone en cours de scan (première de la file), vide sinon.
func scanning_zone() -> StringName:
	for zone: StringName in _order:
		if zone_states[zone] == STATE_SCANNING:
			return zone
	return &""


func _advance_queue() -> void:
	for zone: StringName in _order:
		if zone_states[zone] == STATE_SCANNING:
			return
	if not _order.is_empty():
		zone_states[_order[0]] = STATE_SCANNING


func scanned_zones() -> Array[StringName]:
	var result: Array[StringName] = []
	for zone: StringName in SearchLayout.ZONES:
		if zone_states[zone] == STATE_DONE:
			result.append(zone)
	return result


## Interface suspendue (`inspection_busy`) : aucune nouvelle demande.
func set_busy(value: bool) -> void:
	busy = value
	_refresh()


func set_highlight(zone: StringName) -> void:
	if highlighted != zone:
		highlighted = zone
		_silhouette.queue_redraw()


# ---------------------------------------------------------------------------
# Objets
# ---------------------------------------------------------------------------

func _add_zone_items(zone: StringName, items: Array[SearchItem]) -> void:
	if _empty_label != null and is_instance_valid(_empty_label):
		_empty_label.visible = false
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	head.name = "Zone_%s" % zone
	_items_box.add_child(head)
	head.add_child(ScreenBase.label(UiText.t("zone_%s" % zone, String(zone)), &"DocFieldLabel", Palette.TEXT_SECONDARY))
	if items.is_empty():
		var ras: PanelContainer = ScreenBase.chip(UiText.t("srch_nothing", "RAS"), UiIcon.Kind.CHECK, Palette.TEXT_SECONDARY)
		ras.name = "Nothing"
		head.add_child(ras)
		return
	for item: SearchItem in items:
		var view: SearchItemView = SearchItemView.new()
		view.setup(item)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_box.add_child(view)
		view.set_inspection_active(inspection_active)
		view.picked.connect(func(picked: InspectableItem) -> void: item_picked.emit(picked))
		item_views.append(view)


func _clear_items() -> void:
	item_views.clear()
	if _items_box == null:
		return
	for child: Node in _items_box.get_children():
		if child == _empty_label:
			continue
		_items_box.remove_child(child)
		child.queue_free()
	if _empty_label != null:
		_empty_label.visible = true


func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	for view: SearchItemView in item_views:
		if is_instance_valid(view):
			items.append(view)
	return items


func find_item(ref: FieldRef) -> SearchItemView:
	for view: SearchItemView in item_views:
		if is_instance_valid(view) and view.ref.equals(ref):
			return view
	return null


func set_inspection_active(enabled: bool) -> void:
	inspection_active = enabled
	for item: InspectableItem in get_items():
		item.set_inspection_active(enabled)


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

## Libellé d'état d'une zone, en toutes lettres (jamais la couleur seule).
func zone_status_text(zone: StringName) -> String:
	match zone_states.get(zone, STATE_IDLE):
		STATE_QUEUED:
			return UiText.t("srch_zone_queued", "EN FILE")
		STATE_SCANNING:
			return UiText.t("srch_zone_scanning", "SCAN…")
		STATE_DONE:
			var count: int = zone_counts.get(zone, 0)
			if count == 0:
				return UiText.t("srch_nothing", "RAS")
			return UiText.plural("srch_zone_items", count, "%d OBJET", "%d OBJETS")
	return "—"


func _refresh() -> void:
	if zone_buttons.is_empty():
		return
	var any_idle: bool = false
	for i: int in SearchLayout.ZONES.size():
		var zone: StringName = SearchLayout.ZONES[i]
		var button: Button = zone_buttons[zone]
		var state: StringName = zone_states[zone]
		button.tooltip_text = "Z%d %s · %s" % [i + 1, UiText.t("zone_%s" % zone, String(zone)), zone_status_text(zone)]
		button.disabled = busy or state != STATE_IDLE
		var color: Color = DS.TEXT_PRIMARY
		if state == STATE_DONE:
			color = Palette.TEXT_SECONDARY
		elif state == STATE_SCANNING or state == STATE_QUEUED:
			color = DS.ACCENT_CYAN
		var name_label: Label = button.get_node("Row/Name") as Label
		var state_label: Label = button.get_node("Row/State") as Label
		name_label.add_theme_color_override(&"font_color", color)
		state_label.text = zone_status_text(zone)
		state_label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN if state == STATE_SCANNING or state == STATE_QUEUED
				else Palette.TEXT_SECONDARY)
		any_idle = any_idle or state == STATE_IDLE
	scan_all_button.disabled = busy or not any_idle
	set_process(visible and scanning_zone() != &"" and animated_sweep())
	_silhouette.queue_redraw()


## Balayage animé seulement avec les animations, les effets et le scintillement
## holographique (D-109) ; sinon fond hachuré fixe.
func animated_sweep() -> bool:
	return not reduce_motion and fx_intensity > 0.0 and Settings.holo_flicker


func _process(delta: float) -> void:
	_sweep = fmod(_sweep + delta * 0.8, 1.0)
	_silhouette.queue_redraw()


func _on_zone_pressed(zone: StringName) -> void:
	request_zone(zone)


## Rectangles des zones dans la silhouette (repère local, mis à l'échelle).
func zone_rects(zone: StringName) -> Array[Rect2]:
	var s: Vector2 = _silhouette.size / Vector2(132.0, 216.0) if _silhouette != null else Vector2.ONE
	var rects: Array[Rect2] = []
	match zone:
		SearchLayout.ZONE_HEAD:
			rects.append(Rect2(Vector2(44, 4) * s, Vector2(40, 40) * s))
		SearchLayout.ZONE_TORSO:
			rects.append(Rect2(Vector2(38, 48) * s, Vector2(52, 66) * s))
		SearchLayout.ZONE_ARMS:
			rects.append(Rect2(Vector2(16, 48) * s, Vector2(20, 80) * s))
			rects.append(Rect2(Vector2(92, 48) * s, Vector2(20, 80) * s))
		SearchLayout.ZONE_LEGS:
			rects.append(Rect2(Vector2(40, 116) * s, Vector2(48, 96) * s))
		SearchLayout.ZONE_LUGGAGE:
			rects.append(Rect2(Vector2(96, 156) * s, Vector2(34, 46) * s))
	return rects


func zone_at(point: Vector2) -> StringName:
	for zone: StringName in SearchLayout.ZONES:
		for rect: Rect2 in zone_rects(zone):
			if rect.has_point(point):
				return zone
	return &""


func _on_silhouette_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		set_highlight(zone_at(motion.position))
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var zone: StringName = zone_at(click.position)
		if zone != &"":
			request_zone(zone)
			_silhouette.accept_event()


func _draw_silhouette() -> void:
	var canvas: Control = _silhouette
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(DS.BG_VOID, 0.5))
	for zone: StringName in SearchLayout.ZONES:
		var state: StringName = zone_states.get(zone, STATE_IDLE)
		for rect: Rect2 in zone_rects(zone):
			var line: Color = DS.CYAN_40
			if state == STATE_DONE:
				line = Palette.TEXT_SECONDARY if zone_counts.get(zone, 0) == 0 else DS.ACCENT_CYAN
			elif state == STATE_SCANNING or state == STATE_QUEUED:
				line = DS.ACCENT_CYAN
			if zone == highlighted and state == STATE_IDLE and not busy:
				canvas.draw_rect(rect, DS.CYAN_12)
			if state == STATE_SCANNING:
				canvas.draw_rect(rect, DS.CYAN_12)
				if not animated_sweep():
					_draw_hatch(canvas, rect, DS.CYAN_24)
				else:
					var y: float = rect.position.y + rect.size.y * _sweep
					canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), DS.ACCENT_CYAN, DS.BORDER_STRONG)
			if zone == SearchLayout.ZONE_HEAD:
				canvas.draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 24, line, 1.5, true)
			elif state == STATE_DONE or state == STATE_SCANNING:
				canvas.draw_rect(rect, line, false, 1.5)
			else:
				_draw_dashed_rect(canvas, rect, line)
		if state == STATE_DONE:
			var anchor: Rect2 = zone_rects(zone)[0]
			var icon_rect: Rect2 = Rect2(anchor.end - Vector2(DS.ICON_S, DS.ICON_S), Vector2(DS.ICON_S, DS.ICON_S))
			UiIcon.draw_icon(canvas, UiIcon.Kind.CHECK if zone_counts.get(zone, 0) == 0 else UiIcon.Kind.ITEM, icon_rect,
					line_color(zone))
	# Étiquettes Z1 → Z5 sur la silhouette (le texte double toujours la forme).
	var font: Font = canvas.get_theme_font(&"font", &"DocFieldLabel")
	var font_size: int = canvas.get_theme_font_size(&"font_size", &"DocFieldLabel")
	for i: int in SearchLayout.ZONES.size():
		var rect: Rect2 = zone_rects(SearchLayout.ZONES[i])[0]
		var at: Vector2 = rect.position + Vector2(DS.SPACE_1, font.get_ascent(font_size) + 1.0)
		if SearchLayout.ZONES[i] == SearchLayout.ZONE_ARMS:
			# Bras : étiquette au bas de la manche (le haut est contre le torse).
			at = Vector2(rect.position.x + 1.0, rect.end.y - font.get_descent(font_size) - 1.0)
		canvas.draw_string(font, at, "Z%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.TEXT_SECONDARY)


func line_color(zone: StringName) -> Color:
	return Palette.TEXT_SECONDARY if zone_counts.get(zone, 0) == 0 else DS.ACCENT_CYAN


static func _draw_dashed_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in 4:
		canvas.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.0, InspectableItem.DASH, true)


static func _draw_hatch(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var h: float = rect.size.y
	var x: float = -h
	while x < rect.size.x:
		var seg: PackedVector2Array = InspectableItem.clip_segment(rect.position + Vector2(x, h), rect.position + Vector2(x + h, 0.0), rect)
		if seg.size() == 2:
			canvas.draw_line(seg[0], seg[1], color, 1.0)
		x += InspectableItem.HATCH_STEP
