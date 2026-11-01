## HoloDocument générique (DS §7.1) construit depuis un `DocumentTypeDef` et
## une `DocumentInstance` : bandeau émetteur + titre + sceau, photo si champ
## `PORTRAIT`, DocFields dans l'ordre `display_order` (valeurs en mono), MRZ si
## le type en porte une (champ `mrz`), pied décoratif (n° de série, code-barres).
##
## Déplaçable (glisser), zoomable (molette / double-clic) et mis au premier plan
## par le `Workbench`, qui le contraint au plan de travail. En Mode Inspection
## le document est figé et ses champs deviennent sélectionnables.
## Acte II : document **d'un tiers** (`DocumentInstance.third_party`, SC-27)
## signalé par une puce « TIERS » (jamais comparé aux papiers du porteur) ;
## document sans sceau (ticket de file) : pas de sceau dessiné.
## Acte III (ARCHITECTURE §7.3) : lignes optionnelles du permis (Répondant,
## Convocation) seules sur leur ligne en bas, valeurs mono, absentes si vides ;
## puce « RETIRÉ » sur un document repris par les quais (`retired`, SC-58 :
## jamais contrôlé) ; puce « PROROGÉ (R32) » posée par le comparateur
## (`set_prorogated`) quand la date du document est couverte par la prorogation.
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
## M13 : « Nom du répondant » (`sponsor_name`, nom imprimé en petit sous la
## ligne Répondant, ACT3 §2.5) a sa propre ligne, comme le Répondant.
const WIDE_FIELD_IDS: Array[StringName] = [&"employer", &"origin_sector", &"mrz", &"sponsor", &"summons", &"sponsor_name"]
## Carte à photo (M11, D-085 rév.) : lignes de champs **à côté** de la photo ;
## les suivantes passent **sous** la photo, sur toute la largeur — la carte
## perd la colonne vide sous le portrait et ses libellés ne se replient plus.
const PORTRAIT_SIDE_ROWS: int = 3
const MRZ_FIELD_ID: StringName = &"mrz"
const SERIAL_PATH: StringName = &"document.serial"
## M15 (lot U) : lignes de l'émetteur dans l'en-tête (au-delà : ellipse).
const ISSUER_MAX_LINES: int = 2
## Champ renommé « TITULAIRE » sur un document d'un tiers (QA-028).
const HOLDER_PATH: StringName = &"family_name"
## M7 — marque « luciole » (code 1) : petit dessin magenta au coin bas-droit,
## lisible à la loupe (`DS.DOC_ZOOM`), discret à l'échelle 1.
const MARK_LUCIOLE: StringName = &"luciole"
const MARK_SIZE_PX: float = 5.0

## M13 (AG-02, Lampe de Wood) : le modèle du sceau s'écrit en clair sous le
## sceau de l'en-tête (lu au montage du document ; posé par la `ComparisonUI`).
static var wood_lamp: bool = false

var instance: DocumentInstance = null
var fields: Array[DocFieldView] = []
var portrait_field: DocFieldView = null
## M7 : marques au coin (luciole), sélectionnables en Mode Inspection (§4.9).
var mark_items: Array[DocMarkView] = []
## Acte III : puce « PROROGÉ (R32) » (null tant que le comparateur ne l'a pas posée).
var prorogated_chip: PanelContainer = null
var _titles: VBoxContainer = null
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
var _footer: Control = null
var _hovered: bool = false
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO
var _time: float = 0.0


static func create(p_instance: DocumentInstance, portrait_provider: Callable = Callable()) -> DocumentView:
	var view: DocumentView = DocumentView.new()
	view.build(p_instance, portrait_provider)
	return view


## Couleur d'un token `DS` nommé (`holo_tint_token`), cyan par défaut ;
## valeur de la palette active pour un token d'état (`Palette.token`).
static func token_color(token: StringName) -> Color:
	return Palette.token(token)


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
		elif field.optional and str(instance.get_value(field.id) if instance.get_value(field.id) != null else "").is_empty():
			# Acte III (B39) : ligne optionnelle du permis absente (Répondant, Convocation).
			continue
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
	var side_rows: int = PORTRAIT_SIDE_ROWS if portrait_def != null else -1
	var placed: int = _fill_rows(rows, body_fields, portrait_provider, side_rows)
	if placed < body_fields.size():
		var below: VBoxContainer = VBoxContainer.new()
		below.name = "BelowPortrait"
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		below.add_theme_constant_override("separation", DS.SPACE_1)
		_content.add_child(below)
		_fill_rows(below, body_fields.slice(placed), portrait_provider)
	if mrz_def != null:
		_content.add_child(_build_mrz(mrz_def, portrait_provider))
	_footer = _build_footer()
	_content.add_child(_footer)
	_build_marks()
	_update_style()


func has_luciole_mark() -> bool:
	return instance != null and instance.marks.has(MARK_LUCIOLE)


## Coin bas-droit, au-dessus du code-barres (repère local du document).
func luciole_mark_position() -> Vector2:
	return Vector2(size.x - DS.SPACE_5 - MARK_SIZE_PX, size.y - DS.SPACE_8)


## Acte III (R32) : la date de ce document est prorogée (comparateur) — puce
## « PROROGÉ (R32) » cyan sous le titre, posée une fois.
func set_prorogated() -> void:
	if prorogated_chip != null or _titles == null:
		return
	prorogated_chip = ScreenBase.chip(UiText.t("cmp_prorogated", "PROROGÉ (R32)"), UiIcon.Kind.CHECK, DS.ACCENT_CYAN)
	prorogated_chip.name = "Prorogated"
	prorogated_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_titles.add_child(prorogated_chip)


func get_document_id() -> StringName:
	return instance.get_document_id() if instance != null else &""


## Hauteur de l'« onglet » (repère local, échelle 1) : bandeau émetteur + titre,
## seule partie visible d'un document rangé derrière un autre dans une pile
## du plan de travail (QA-020).
func tab_height() -> float:
	var top: float = DS.SPACE_4
	var box: StyleBox = get_theme_stylebox(&"panel")
	if box != null:
		top = box.get_margin(SIDE_TOP)
	var header: float = _header.get_combined_minimum_size().y if _header != null else float(DS.SPACE_10)
	return top + header + DS.SPACE_3


## Marque `mark_id` affichée (null si le document ne la porte pas).
func get_mark_item(mark_id: StringName) -> DocMarkView:
	for item: DocMarkView in mark_items:
		if item.mark_id == mark_id:
			return item
	return null


## Tous les éléments sélectionnables (photo et marques comprises).
func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	if portrait_field != null:
		items.append(portrait_field)
	for item: DocFieldView in fields:
		items.append(item)
	for mark: DocMarkView in mark_items:
		items.append(mark)
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
	if Settings.holo_flicker:
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
	# M15 (lot U) : l'émetteur passe sur deux lignes plutôt que d'être coupé
	# par le n° de série (« CONSORTIUM · CONTINUITY BURE… » au Deck) ; au-delà,
	# ellipse (jamais plus de deux lignes).
	issuer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	issuer.max_lines_visible = ISSUER_MAX_LINES
	issuer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	issuer.name = "Issuer"
	titles.add_child(issuer)
	var title: Label = Label.new()
	title.theme_type_variation = &"DocTitle"
	title.text = UiText.document_title(def)
	title.uppercase = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_child(title)
	if instance.third_party:
		var third: PanelContainer = ScreenBase.chip(UiText.t("doc_third_party", "DOCUMENT D'UN TIERS"), UiIcon.Kind.INFO, Palette.TEXT_SECONDARY)
		third.name = "ThirdParty"
		third.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		titles.add_child(third)
	if instance.retired:
		# Acte III (M1, SC-58) : repris par les quais, plus contrôlé au guichet.
		var retired: PanelContainer = ScreenBase.chip(UiText.t("doc_retired", "RETIRÉ · NON CONTRÔLÉ"), UiIcon.Kind.STRIKE,
				Palette.TEXT_SECONDARY)
		retired.name = "Retired"
		retired.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		titles.add_child(retired)
	_titles = titles
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
	if instance.seal_id != &"":
		var seal: UiIcon = UiIcon.make(UiIcon.seal_kind(instance.seal_id), _tint, DS.ICON_L + DS.SPACE_2)
		seal.size_flags_horizontal = Control.SIZE_SHRINK_END
		side.add_child(seal)
		if wood_lamp:
			var model: Label = Label.new()
			model.name = "WoodLampCaption"
			model.theme_type_variation = &"DataSmall"
			model.mouse_filter = Control.MOUSE_FILTER_IGNORE
			model.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			model.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)
			model.text = seal_model_text(instance.seal_id)
			side.add_child(model)
	_header = header
	return header


## AG-02 : modèle du sceau en clair (« UV · MODÈLE 2187 », « UV · ANCIEN
## MODÈLE ») ; le nom du sceau seul s'il ne précise pas de modèle.
static func seal_model_text(seal_id: StringName) -> String:
	var full: String = UiText.t("val_" + String(seal_id), String(seal_id))
	var model: String = full.get_slice(" · ", 1) if full.contains(" · ") else full
	return UiText.tf("seal_uv", [model], "UV · %s")


func _make_field(field: FieldDef, portrait_provider: Callable) -> DocFieldView:
	var item: DocFieldView = DocFieldView.new()
	var label_text: String = ""
	if instance.third_party and field.truth_path == HOLDER_PATH:
		# Document d'un tiers (SC-27) : le nom est celui du titulaire, pas du porteur.
		label_text = UiText.t("field_holder", "Titulaire")
	item.setup(get_document_id(), field, instance.get_value(field.id), portrait_provider, label_text)
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
## ligne (dans l'ordre `display_order`), les autres sont seuls. `max_rows` ≥ 0 :
## s'arrête avant d'ouvrir une ligne de plus. Renvoie le nombre de champs posés.
func _fill_rows(rows: VBoxContainer, body_fields: Array[FieldDef], portrait_provider: Callable, max_rows: int = -1) -> int:
	var current: HBoxContainer = null
	var current_class: int = 0
	var row_count: int = 0
	var placed: int = 0
	for field: FieldDef in body_fields:
		var klass: int = pair_class(field)
		if current != null and klass != 0 and klass == current_class and current.get_child_count() == 1:
			current.add_child(_make_field(field, portrait_provider))
			placed += 1
			current = null
			continue
		if max_rows >= 0 and row_count >= max_rows:
			break
		current = _new_row(rows)
		row_count += 1
		current.add_child(_make_field(field, portrait_provider))
		placed += 1
		current_class = klass
		if klass == 0:
			current = null
	return placed


func _new_row(rows: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_4)
	rows.add_child(row)
	return row


func _build_mrz(field: FieldDef, portrait_provider: Callable) -> Control:
	var item: DocFieldView = _make_field(field, portrait_provider)
	# Bande MRZ sans libellé (elle se reconnaît d'elle-même, M11) : une ligne
	# de moins sur la carte ; le nom reste dans l'infobulle et les messages.
	item.hide_label()
	return item


## Marque luciole (M7) : élément sélectionnable porté par le pied (Control
## libre, hors du tri du conteneur), recentré sur `luciole_mark_position()`
## après chaque tri (taille du document, zoom compris via l'échelle).
func _build_marks() -> void:
	if not has_luciole_mark():
		return
	var mark: DocMarkView = DocMarkView.new()
	mark.setup(get_document_id(), MARK_LUCIOLE, MARK_SIZE_PX)
	mark.picked.connect(_on_item_picked)
	mark.fx_intensity = fx_intensity
	_footer.add_child(mark)
	mark_items.append(mark)
	_content.sort_children.connect(_place_marks)
	_place_marks()


func _place_marks() -> void:
	if _footer == null:
		return
	var origin: Vector2 = _content.position + _footer.position
	for mark: DocMarkView in mark_items:
		mark.center_on(luciole_mark_position() - origin)


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
		# « Scintillement holographique » coupé (M11) : scanlines figées, aucun
		# scintillement du cadre ; les lueurs restent (DESIGN_SYSTEM §5).
		var flickering: bool = Settings.holo_flicker
		var offset: float = fmod(_time * DS.FX_SCANLINE_PERIOD_PX * 2.0, DS.FX_SCANLINE_PERIOD_PX * 2.0) if flickering else 0.0
		var y: float = offset
		var line: Color = Color(DS.ACCENT_CYAN, alpha)
		while y < rect.size.y:
			draw_line(Vector2(DS.SPACE_1, y), Vector2(rect.size.x - DS.SPACE_1, y), line, 1.0)
			y += DS.FX_SCANLINE_PERIOD_PX * 2.0
		# Flicker du cadre (≤ 2 Hz, amplitude ≤ 0,06) : bord seulement.
		if flickering:
			var flicker: float = 0.5 + 0.5 * sin(_time * TAU * DS.FX_FLICKER_HZ_MAX * 0.25)
			var edge: Color = Color(DS.ACCENT_CYAN, DS.FX_FLICKER_AMPLITUDE_MAX * flicker * fx_intensity)
			draw_line(Vector2(DS.CHAMFER_L, 1), Vector2(size.x - 1, 1), edge, 2.0)
	# Coins accentués (bas-gauche / haut-droit vifs).
	var corner: float = DS.SPACE_3
	draw_polyline([Vector2(0, rect.end.y - corner), Vector2(0, rect.end.y), Vector2(corner, rect.end.y)], _tint, DS.BORDER_STRONG)
	draw_polyline([Vector2(rect.end.x - corner, 0), Vector2(rect.end.x, 0), Vector2(rect.end.x, corner)], DS.ACCENT_CYAN, DS.BORDER_STRONG)
	# La luciole est dessinée par sa `DocMarkView` (sélectionnable, M7 §4.9).
	# Badge « flagged » : losange magenta + compteur (DS §7.1).
	if flag_count > 0:
		var center: Vector2 = Vector2(rect.end.x - DS.SPACE_2, -DS.SPACE_2)
		InspectableItem.draw_number_badge(self, center + Vector2(DS.SPACE_3 * 0.5, -DS.SPACE_3 * 0.5), flag_count, Palette.ACCENT_MAGENTA)


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
