## HoloDocument générique (DS §7.1) construit depuis un `DocumentTypeDef` et
## une `DocumentInstance` : bandeau émetteur + titre + sceau, photo si champ
## `PORTRAIT`, DocFields dans l'ordre `display_order` (valeurs en mono), MRZ si
## le type en porte une (champ `mrz`), pied décoratif (n° de série, code-barres).
##
## Déplaçable (glisser), zoomable (molette / double-clic) et mis au premier plan
## par le `Workbench`, qui le contraint au plan de travail. En Mode Inspection
## le document est figé et ses champs deviennent sélectionnables.
class_name DocumentView
extends PanelContainer

signal grabbed(view: DocumentView)
signal drag_moved(view: DocumentView, relative: Vector2)
signal released(view: DocumentView)
## `steps` > 0 zoom avant, < 0 arrière, 0 = bascule (double-clic).
signal zoom_requested(view: DocumentView, steps: int)
signal field_picked(item: InspectableItem)

## Largeurs de référence (DS §7.1 : 480 px), photo incluse ou non.
const WIDTH_WITH_PORTRAIT: float = 528.0
const WIDTH_PLAIN: float = 440.0
## Types de champs courts groupés par deux sur une ligne (les champs texte
## consécutifs — nom / prénoms — sont aussi groupés entre eux).
const COMPACT_KINDS: Array[FieldDef.FieldKind] = [
	FieldDef.FieldKind.DATE, FieldDef.FieldKind.ENUM, FieldDef.FieldKind.NUMBER, FieldDef.FieldKind.BOOL,
	FieldDef.FieldKind.ID_CODE,
]
## Champs texte longs, toujours seuls sur leur ligne.
const WIDE_FIELD_IDS: Array[StringName] = [&"employer", &"origin_sector", &"mrz"]
const MRZ_FIELD_ID: StringName = &"mrz"
const SERIAL_PATH: StringName = &"document.serial"
const TOKENS: GDScript = preload("res://ui/theme/tokens.gd")

var instance: DocumentInstance = null
var fields: Array[DocFieldView] = []
var portrait_field: DocFieldView = null
## Zoom courant (1 = lecture normale, `DS.DOC_ZOOM` = loupe).
var zoom: float = 1.0
var inspection_active: bool = false
var active: bool = false:
	set(value):
		active = value
		_update_style()
var fx_intensity: float = 1.0
var flag_count: int = 0:
	set(value):
		flag_count = value
		queue_redraw()

var _tint: Color = DS.ACCENT_CYAN
var _header: Control = null
var _content: VBoxContainer = null
var _hovered: bool = false
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO
var _time: float = 0.0


static func create(p_instance: DocumentInstance, portrait_provider: Callable = Callable()) -> DocumentView:
	var view: DocumentView = DocumentView.new()
	view.build(p_instance, portrait_provider)
	return view


## Couleur d'un token `DS` nommé (`holo_tint_token`), cyan par défaut.
static func token_color(token: StringName) -> Color:
	var constants: Dictionary = TOKENS.get_script_constant_map()
	var value: Variant = constants.get(String(token))
	return value if value is Color else DS.ACCENT_CYAN


func build(p_instance: DocumentInstance, portrait_provider: Callable = Callable()) -> void:
	instance = p_instance
	var def: DocumentTypeDef = instance.type_def
	_tint = token_color(def.holo_tint_token)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", DS.SPACE_2)
	add_child(_content)

	var sorted: Array[FieldDef] = def.get_sorted_fields()
	var portrait_def: FieldDef = null
	var mrz_def: FieldDef = null
	var has_serial_field: bool = false
	var body_fields: Array[FieldDef] = []
	for field: FieldDef in sorted:
		if field.kind == FieldDef.FieldKind.PORTRAIT and portrait_def == null:
			portrait_def = field
		elif field.id == MRZ_FIELD_ID:
			mrz_def = field
		else:
			body_fields.append(field)
			has_serial_field = has_serial_field or field.truth_path == SERIAL_PATH
	custom_minimum_size.x = WIDTH_WITH_PORTRAIT if portrait_def != null else WIDTH_PLAIN

	_content.add_child(_build_header(def, not has_serial_field))
	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", DS.SPACE_4)
	_content.add_child(body)
	if portrait_def != null:
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_field = _make_field(portrait_def, portrait_provider)
		column.add_child(portrait_field)
		body.add_child(column)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", DS.SPACE_1)
	body.add_child(rows)
	_fill_rows(rows, body_fields, portrait_provider)
	if mrz_def != null:
		_content.add_child(_build_mrz(mrz_def, portrait_provider))
	_content.add_child(_build_footer())
	_update_style()


func get_document_id() -> StringName:
	return instance.get_document_id() if instance != null else &""


## Tous les éléments sélectionnables (photo comprise).
func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	if portrait_field != null:
		items.append(portrait_field)
	for item: DocFieldView in fields:
		items.append(item)
	return items


func find_item(ref: FieldRef) -> InspectableItem:
	for item: InspectableItem in get_items():
		if item.ref.equals(ref):
			return item
	return null


func set_inspection_active(enabled: bool) -> void:
	inspection_active = enabled
	_dragging = false
	for item: InspectableItem in get_items():
		item.set_inspection_active(enabled)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if enabled else Control.CURSOR_MOVE
	_update_style()


func set_fx_intensity(value: float) -> void:
	fx_intensity = value
	for item: InspectableItem in get_items():
		item.fx_intensity = value
	set_process(value > 0.0)
	queue_redraw()


## Rectangle visuel (zoom compris) dans le repère du parent.
func get_visual_rect() -> Rect2:
	return Rect2(position, size * scale)


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	set_process(fx_intensity > 0.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_header(def: DocumentTypeDef, show_serial: bool) -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", DS.SPACE_3)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", DS.SPACE_1)
	header.add_child(titles)
	var issuer: Label = Label.new()
	issuer.theme_type_variation = &"DocIssuer"
	issuer.text = UiText.issuer_name(instance.issuer_id)
	issuer.uppercase = true
	issuer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	issuer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(issuer)
	var title: Label = Label.new()
	title.theme_type_variation = &"DocTitle"
	title.text = UiText.document_title(def)
	title.uppercase = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_child(title)
	var side: VBoxContainer = VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(side)
	if show_serial and not instance.serial.is_empty():
		var serial: Label = Label.new()
		serial.theme_type_variation = &"DataSmall"
		serial.text = instance.serial
		serial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.add_child(serial)
	var seal: UiIcon = UiIcon.make(UiIcon.seal_kind(instance.seal_id), _tint, DS.ICON_L + DS.SPACE_2)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(seal)
	_header = header
	return header


func _make_field(field: FieldDef, portrait_provider: Callable) -> DocFieldView:
	var item: DocFieldView = DocFieldView.new()
	item.setup(get_document_id(), field, instance.get_value(field.id), portrait_provider)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.picked.connect(_on_item_picked)
	if field.kind != FieldDef.FieldKind.PORTRAIT:
		fields.append(item)
	return item


## Classe de groupement : 0 = seul, 1 = texte court, 2 = valeur compacte.
static func pair_class(field: FieldDef) -> int:
	if WIDE_FIELD_IDS.has(field.id):
		return 0
	if COMPACT_KINDS.has(field.kind):
		return 2
	if field.kind == FieldDef.FieldKind.TEXT:
		return 1
	return 0


## Lignes de champs : deux champs consécutifs de même classe partagent une
## ligne (dans l'ordre `display_order`), les autres sont seuls.
func _fill_rows(rows: VBoxContainer, body_fields: Array[FieldDef], portrait_provider: Callable) -> void:
	var current: HBoxContainer = null
	var current_class: int = 0
	for field: FieldDef in body_fields:
		var item: DocFieldView = _make_field(field, portrait_provider)
		var klass: int = pair_class(field)
		if current != null and klass != 0 and klass == current_class and current.get_child_count() == 1:
			current.add_child(item)
			current = null
			continue
		current = _new_row(rows)
		current.add_child(item)
		current_class = klass
		if klass == 0:
			current = null


func _new_row(rows: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_4)
	rows.add_child(row)
	return row


func _build_mrz(field: FieldDef, portrait_provider: Callable) -> Control:
	var item: DocFieldView = _make_field(field, portrait_provider)
	return item


## Pied décoratif : code-barres dérivé du n° de série (text.muted, DS §7.1 [5]).
func _build_footer() -> Control:
	var footer: Control = Control.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.custom_minimum_size = Vector2(0, DS.SPACE_4)
	footer.draw.connect(_draw_footer.bind(footer))
	return footer


func _draw_footer(footer: Control) -> void:
	var seed_value: int = hash(instance.serial + String(get_document_id()))
	var font: Font = get_theme_font(&"font", &"DataSmall")
	var font_size: int = get_theme_font_size(&"font_size", &"CaptionLabel")
	var text: String = instance.serial
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x: float = 0.0
	var h: float = footer.size.y
	var i: int = 0
	while x < footer.size.x - text_width - DS.SPACE_4:
		var w: float = 1.0 + float((seed_value >> (i % 24)) & 3)
		if i % 2 == 0:
			footer.draw_rect(Rect2(x, 0, w, h), DS.TEXT_MUTED)
		x += w + 1.0
		i += 1
	footer.draw_string(font, Vector2(footer.size.x - text_width, h - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DS.TEXT_MUTED)


# ---------------------------------------------------------------------------
# États, dessin
# ---------------------------------------------------------------------------

func _update_style() -> void:
	var holo_bg: Color = DS.BG_PANEL.blend(DS.CYAN_08)
	var border: Color = DS.CYAN_40
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(holo_bg, border, DS.BORDER_HAIRLINE, DS.CHAMFER_L, DS.SPACE_6)
	box.content_margin_top = DS.SPACE_4
	box.content_margin_bottom = DS.SPACE_3
	box.content_margin_left = DS.SPACE_5
	box.content_margin_right = DS.SPACE_5
	var glow: int = DS.GLOW_0
	if active:
		glow = DS.GLOW_2
	elif _hovered and not inspection_active:
		box.border_color = DS.ACCENT_CYAN
		glow = DS.GLOW_1
	if inspection_active:
		box.border_color = DS.CYAN_60
	if fx_intensity < 1.0:
		glow = mini(glow, DS.GLOW_1)
	if glow > 0:
		box.shadow_color = DS.CYAN_24 if glow == DS.GLOW_1 else DS.CYAN_60
		box.shadow_size = glow
	add_theme_stylebox_override(&"panel", box)


func _set_hovered(value: bool) -> void:
	_hovered = value
	_update_style()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	# Bandeau d'en-tête (voile cyan) + filet de séparation.
	if _header != null:
		var bottom: float = _header.position.y + _content.position.y + _header.size.y + DS.SPACE_2
		var band: PackedVector2Array = [Vector2(DS.CHAMFER_L, 0), Vector2(size.x, 0), Vector2(size.x, bottom), Vector2(0, bottom), Vector2(0, DS.CHAMFER_L)]
		draw_colored_polygon(band, DS.CYAN_08)
		draw_line(Vector2(0, bottom), Vector2(size.x, bottom), DS.CYAN_24, 1.0)
		draw_rect(Rect2(DS.CHAMFER_L, 0, DS.SPACE_10, 2), _tint)
	# Scanlines (cadre holo) : alpha ≤ 0,03 sous les données (DS §5).
	if fx_intensity > 0.0:
		var alpha: float = 0.03 * fx_intensity
		var offset: float = fmod(_time * DS.FX_SCANLINE_PERIOD_PX * 2.0, DS.FX_SCANLINE_PERIOD_PX * 2.0)
		var y: float = offset
		var line: Color = Color(DS.ACCENT_CYAN, alpha)
		while y < rect.size.y:
			draw_line(Vector2(DS.SPACE_1, y), Vector2(rect.size.x - DS.SPACE_1, y), line, 1.0)
			y += DS.FX_SCANLINE_PERIOD_PX * 2.0
		# Flicker du cadre (≤ 2 Hz, amplitude ≤ 0,06) : bord seulement.
		var flicker: float = 0.5 + 0.5 * sin(_time * TAU * DS.FX_FLICKER_HZ_MAX * 0.25)
		var edge: Color = Color(DS.ACCENT_CYAN, DS.FX_FLICKER_AMPLITUDE_MAX * flicker * fx_intensity)
		draw_line(Vector2(DS.CHAMFER_L, 1), Vector2(size.x - 1, 1), edge, 2.0)
	# Coins accentués (bas-gauche / haut-droit vifs).
	var corner: float = DS.SPACE_3
	draw_polyline([Vector2(0, rect.end.y - corner), Vector2(0, rect.end.y), Vector2(corner, rect.end.y)], _tint, DS.BORDER_STRONG)
	draw_polyline([Vector2(rect.end.x - corner, 0), Vector2(rect.end.x, 0), Vector2(rect.end.x, corner)], DS.ACCENT_CYAN, DS.BORDER_STRONG)
	# Badge « flagged » : losange magenta + compteur (DS §7.1).
	if flag_count > 0:
		var center: Vector2 = Vector2(rect.end.x - DS.SPACE_2, -DS.SPACE_2)
		InspectableItem.draw_number_badge(self, center + Vector2(DS.SPACE_3 * 0.5, -DS.SPACE_3 * 0.5), flag_count, DS.ACCENT_MAGENTA)


# ---------------------------------------------------------------------------
# Entrées (glisser, zoom, premier plan)
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					grabbed.emit(self)
					if button.double_click:
						zoom_requested.emit(self, 0)
					elif not inspection_active:
						_dragging = true
						_drag_last = get_global_mouse_position()
				elif _dragging:
					_dragging = false
					released.emit(self)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					zoom_requested.emit(self, 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					zoom_requested.emit(self, -1)
				accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		# Delta global (indépendant du zoom du document).
		var now: Vector2 = get_global_mouse_position()
		drag_moved.emit(self, now - _drag_last)
		_drag_last = now
		accept_event()


func _on_item_picked(item: InspectableItem) -> void:
	field_picked.emit(item)
