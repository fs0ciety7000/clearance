## Plan de travail holographique (UI_FLOW §2.2 zone C) : reçoit les documents
## par la fente (arrivée échelonnée), les range, les laisse glisser / zoomer /
## passer au premier plan en restant **dans** le plan (jamais au-dessus de la
## vitre, §4.4), affiche l'état vide, le cadre du Mode Inspection, le bandeau
## de résultat et l'empreinte du tampon.
## Acte II : pastille du scanner partiel dans l'en-tête (source ACV-2 ambre ou
## boîtier des Lucioles magenta, nombre de liens suggérés à confirmer).
class_name Workbench
extends Control

signal field_picked(item: InspectableItem)
signal document_focused(doc: DocumentInstance)
## Clic dans le vide en Mode Inspection (annule le champ A, UI_FLOW §3.3).
signal background_clicked()
## Documents mis en place (après `present()`, une passe de mise en page).
signal layout_done()
## Acte II : « CONFIRMER » de la pastille du scanner (lien suggéré suivant).
signal scanner_confirm_pressed()

enum BannerKind { DISCORDANT, CONCORDANT, INCOMPARABLE, INFO }

## Hauteur réservée à l'en-tête du plan (libellés).
const HEADER_H: float = 48.0
const GRID_STEP: float = 32.0
## Échelle minimale d'ajustement des documents à la hauteur du plan (QA-015) :
## en dessous, le texte deviendrait illisible ; le zoom de lecture reste dispo.
const MIN_FIT_SCALE: float = 0.72

var views: Array[DocumentView] = []
## M7 : objets glissés posés sur le plan (enveloppe, mot, carte de quai).
var items: Array[SlippedItemView] = []
var inspection_active: bool = false
var reduce_motion: bool = false
var fx_intensity: float = 1.0
var inspection_available: bool = false

var _title: Label = null
var _mode_label: Label = null
var _mode_icon: UiIcon = null
var _empty: VBoxContainer = null
var _empty_title: Label = null
var _empty_text: Label = null
var _docs_layer: Control = null
var _banner: PanelContainer = null
var _banner_icon: UiIcon = null
var _banner_title: Label = null
var _banner_text: Label = null
var _banner_tween: Tween = null
var _stamp: StampMark = null
var _unavailable_reason: String = ""
## Acte II : pastille de source du scanner partiel (masquée sans scanner).
var scanner_chip: PanelContainer = null
var _scanner_label: Label = null
var _scanner_count: Label = null
var _scanner_icon: UiIcon = null
var _scanner_text: String = ""
var scanner_button: Button = null
## Échelle de base des documents posés (≤ 1) : la plus grande pièce tient dans
## la hauteur du plan, sous l'en-tête et au-dessus de la barre d'outils.
var fit_scale: float = 1.0
## Rectangles d'arrivée des documents (repère du plan) : les objets glissés
## se posent à côté, jamais sur un champ (QA-015).
var _doc_targets: Array[Rect2] = []
## Vrai entre `present()` et la mise en place des documents (une image).
var layout_pending: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_docs_layer = Control.new()
	_docs_layer.name = "Documents"
	_docs_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_docs_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_docs_layer)
	_build_header()
	_build_empty_state()
	_build_banner()
	set_empty_state(UiText.t("wb_empty_title", "EN ATTENTE DES DOCUMENTS"),
			UiText.t("wb_empty_waiting", "Appelez le passager suivant à l'intercom."))
	_refresh_header()


# ---------------------------------------------------------------------------
# Documents
# ---------------------------------------------------------------------------

## Pose les documents : ils émergent du bord haut, au centre (fente de la
## vitre), puis rejoignent leur place, décalés de `DS.DOC_STAGGER`.
func present(documents: Array[DocumentInstance], portrait_provider: Callable = Callable()) -> void:
	clear(false)
	_empty.visible = false
	for doc: DocumentInstance in documents:
		var view: DocumentView = DocumentView.create(doc, portrait_provider)
		view.set_fx_intensity(fx_intensity)
		view.grabbed.connect(_on_grabbed)
		view.drag_moved.connect(_on_drag_moved)
		view.zoom_requested.connect(_on_zoom_requested)
		view.field_picked.connect(_on_field_picked)
		_docs_layer.add_child(view)
		view.set_inspection_active(inspection_active)
		view.modulate.a = 0.0
		views.append(view)
	_refresh_header()
	# Mise en place après une passe de mise en page : les champs repliés
	# (autowrap) n'ont leur hauteur définitive qu'une fois la largeur connue,
	# et l'échelle d'ajustement en dépend (QA-015).
	layout_pending = true
	if not get_tree().process_frame.is_connected(_on_layout_frame):
		get_tree().process_frame.connect(_on_layout_frame, CONNECT_ONE_SHOT)


func _on_layout_frame() -> void:
	if not layout_pending or not is_inside_tree():
		return
	_arrange_views()
	layout_pending = false
	layout_done.emit()


func _arrange_views() -> void:
	for view: DocumentView in views:
		view.size = view.get_combined_minimum_size()
	fit_scale = compute_fit_scale()
	var targets: Array[Vector2] = default_layout()
	_doc_targets.clear()
	var slot: Vector2 = Vector2(size.x * 0.5, -DS.SPACE_4)
	for i: int in views.size():
		var view: DocumentView = views[i]
		var target: Vector2 = targets[i]
		_doc_targets.append(Rect2(target, view.size * fit_scale))
		if reduce_motion:
			view.position = target
			view.scale = Vector2(fit_scale, fit_scale)
			view.modulate.a = 0.0
			create_tween().tween_property(view, "modulate:a", 1.0, DS.DUR_FAST).set_delay(DS.DOC_STAGGER * i * 0.5)
			continue
		view.position = slot - Vector2(view.size.x * 0.5, view.size.y * 0.3)
		view.scale = Vector2(0.9, 0.06) * fit_scale
		view.pivot_offset = Vector2(view.size.x * 0.5, 0.0)
		view.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		var delay: float = DS.DOC_STAGGER * i
		tween.tween_property(view, "modulate:a", 1.0, DS.DUR_FAST).set_delay(delay)
		tween.tween_property(view, "scale", Vector2(fit_scale, fit_scale), DS.DUR_SLOW).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "position", target, DS.DUR_SLOW + DS.DUR_FAST).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(_reset_pivot.bind(view))
	_refresh_header()


## Échelle qui fait tenir le plus haut document dans la hauteur utile du plan.
func compute_fit_scale() -> float:
	var tallest: float = 0.0
	for view: DocumentView in views:
		tallest = maxf(tallest, view.get_combined_minimum_size().y)
	var available: float = size.y - HEADER_H - DS.SPACE_4
	if tallest <= 0.0 or available <= 0.0 or tallest <= available:
		return 1.0
	return clampf(available / tallest, MIN_FIT_SCALE, 1.0)


func _reset_pivot(view: DocumentView) -> void:
	if is_instance_valid(view):
		view.pivot_offset = Vector2.ZERO


## M7 : pose un objet glissé (enveloppe, mot…) : il glisse par la fente
## après les documents puis se range dans le coin bas-droit du plan.
func add_slipped_item(view: SlippedItemView) -> void:
	_docs_layer.add_child(view)
	items.append(view)
	_empty.visible = false
	view.grabbed.connect(_on_item_grabbed)
	view.drag_moved.connect(_on_item_drag_moved)
	# Largeur fixée d'abord : les textes repliés se mesurent à la bonne largeur,
	# la hauteur est recalculée après une passe de mise en page.
	view.size = Vector2(view.custom_minimum_size.x, 0.0)
	view.modulate.a = 0.0
	_place_item.call_deferred(view, items.size() - 1)


func _place_item(view: SlippedItemView, index: int) -> void:
	if layout_pending:
		await layout_done
	if not is_instance_valid(view) or not view.is_inside_tree():
		return
	view.reset_size()
	var target: Vector2 = item_target(view.size, index)
	view.set_meta(&"target", target)
	if reduce_motion:
		view.position = target
		view.modulate.a = 0.0
		create_tween().tween_property(view, "modulate:a", 1.0, DS.DUR_FAST)
		return
	view.position = Vector2(size.x * 0.5 - view.size.x * 0.5, -view.size.y * 0.4)
	view.modulate.a = 0.0
	view.rotation_degrees = -3.0
	var delay: float = DS.DOC_STAGGER * (views.size() + index)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(view, "modulate:a", 1.0, DS.DUR_FAST).set_delay(delay)
	tween.tween_property(view, "position", target, DS.DUR_SLOW + DS.DUR_FAST).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "rotation_degrees", 2.0, DS.DUR_SLOW + DS.DUR_FAST).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Place d'un objet glissé : coin bas-droit par défaut, sinon la position libre
## (ou la moins couverte) le long des bords droit puis gauche, hors des
## documents et des autres objets (QA-015).
func item_target(item_size: Vector2, index: int) -> Vector2:
	var preferred: Vector2 = Vector2(size.x - item_size.x - DS.SPACE_8 - DS.SPACE_6 * index,
			maxf(size.y - item_size.y - DS.SPACE_6 - DS.SPACE_4 * index, HEADER_H))
	var obstacles: Array[Rect2] = _doc_targets.duplicate()
	for i: int in mini(index, items.size()):
		var other: SlippedItemView = items[i]
		if is_instance_valid(other):
			var placed: Vector2 = other.get_meta(&"target", other.position)
			obstacles.append(Rect2(placed, other.size))
	var candidates: Array[Vector2] = [preferred]
	var bottom: float = maxf(size.y - item_size.y - DS.SPACE_4, HEADER_H)
	var y: float = bottom
	while y >= HEADER_H:
		candidates.append(Vector2(size.x - item_size.x - DS.SPACE_4, y))
		candidates.append(Vector2(DS.SPACE_4, y))
		y -= DS.SPACE_6
	var best: Vector2 = preferred
	var best_overlap: float = INF
	for candidate: Vector2 in candidates:
		var rect: Rect2 = Rect2(candidate, item_size).grow(DS.SPACE_2)
		var overlap: float = 0.0
		for obstacle: Rect2 in obstacles:
			var inter: Rect2 = rect.intersection(obstacle)
			overlap += inter.get_area() if inter.has_area() else 0.0
		if overlap < best_overlap - 0.5:
			best = candidate
			best_overlap = overlap
			if overlap <= 0.0:
				break
	return best


func get_slipped_view(item_id: StringName) -> SlippedItemView:
	for view: SlippedItemView in items:
		if is_instance_valid(view) and view.item != null and view.item.id == item_id:
			return view
	return null


func _on_item_grabbed(view: SlippedItemView) -> void:
	_docs_layer.move_child(view, _docs_layer.get_child_count() - 1)


func _on_item_drag_moved(view: SlippedItemView, relative: Vector2) -> void:
	view.position += relative
	var max_pos: Vector2 = size - view.size
	view.position = Vector2(clampf(view.position.x, 0.0, maxf(max_pos.x, 0.0)), clampf(view.position.y, 0.0, maxf(max_pos.y, 0.0)))


## Retire les documents (rendus par la fente si `animated`).
func clear(animated: bool = true) -> void:
	if layout_pending:
		layout_pending = false
		layout_done.emit()
	_hide_stamp()
	hide_banner()
	for item_view: SlippedItemView in items:
		if not is_instance_valid(item_view):
			continue
		item_view.lock()
		if animated and not reduce_motion:
			var away: Vector2 = Vector2(item_view.position.x, size.y + DS.SPACE_4) \
					if item_view.decision == SlippedItem.Decision.KEEP else Vector2(size.x * 0.5 - item_view.size.x * 0.5, -item_view.size.y)
			var out: Tween = item_view.create_tween().set_parallel(true)
			out.tween_property(item_view, "position", away, DS.DUR_SLOW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			out.tween_property(item_view, "modulate:a", 0.0, DS.DUR_SLOW * 0.7).set_delay(DS.DUR_FAST)
			out.chain().tween_callback(item_view.queue_free)
		else:
			item_view.queue_free()
	items.clear()
	for view: DocumentView in views:
		if animated and not reduce_motion:
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "position", Vector2(size.x * 0.5 - view.size.x * 0.5, -view.size.y * 0.5), DS.DUR_SLOW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(view, "modulate:a", 0.0, DS.DUR_SLOW * 0.7).set_delay(DS.DUR_FAST)
			tween.chain().tween_callback(view.queue_free)
		elif animated:
			var fade: Tween = view.create_tween()
			fade.tween_property(view, "modulate:a", 0.0, DS.DUR_FAST)
			fade.tween_callback(view.queue_free)
		else:
			view.queue_free()
	views.clear()
	_refresh_header()


## Positions par défaut : de gauche à droite, légèrement décalées en hauteur
## (posées « à la main »), resserrées si la largeur manque. Les objets glissés
## déjà reçus gardent une colonne libre à droite (QA-015).
func default_layout() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var margin: float = DS.SPACE_8
	var reserve: float = 0.0
	for item_view: SlippedItemView in items:
		if is_instance_valid(item_view):
			reserve = maxf(reserve, item_view.get_combined_minimum_size().x + DS.SPACE_4)
	var available: float = maxf(size.x - margin * 2.0 - reserve, 1.0)
	var total: float = 0.0
	for view: DocumentView in views:
		total += view.get_combined_minimum_size().x * fit_scale
	var gap: float = DS.SPACE_10
	if views.size() > 1:
		gap = minf(DS.SPACE_10, (available - total) / (views.size() - 1))
	var used: float = total + gap * maxi(views.size() - 1, 0)
	var x: float = margin + maxf((available - used) * 0.5, 0.0)
	var offsets: Array[float] = [DS.SPACE_4, 0.0, DS.SPACE_6, DS.SPACE_2, DS.SPACE_4]
	for i: int in views.size():
		var min_size: Vector2 = views[i].get_combined_minimum_size() * fit_scale
		var y: float = HEADER_H + offsets[i % offsets.size()]
		y = minf(y, maxf(size.y - min_size.y - DS.SPACE_4, HEADER_H))
		result.append(Vector2(x, y))
		x += min_size.x + gap
	return result


func get_view(document_id: StringName) -> DocumentView:
	for view: DocumentView in views:
		if view.get_document_id() == document_id:
			return view
	return null


func find_item(ref: FieldRef) -> InspectableItem:
	var view: DocumentView = get_view(ref.document_id)
	return view.find_item(ref) if view != null else null


func get_items() -> Array[InspectableItem]:
	var fields: Array[InspectableItem] = []
	for view: DocumentView in views:
		fields.append_array(view.get_items())
	return fields


func set_inspection_active(enabled: bool) -> void:
	inspection_active = enabled
	for view: DocumentView in views:
		view.set_inspection_active(enabled)
	_refresh_header()
	queue_redraw()


func set_fx_intensity(value: float) -> void:
	fx_intensity = value
	for view: DocumentView in views:
		view.set_fx_intensity(value)


## Met un document au premier plan (glow.2) et émet `document_focused`.
func bring_to_front(view: DocumentView) -> void:
	_docs_layer.move_child(view, _docs_layer.get_child_count() - 1)
	for other: DocumentView in views:
		other.active = other == view
	if _stamp != null:
		_docs_layer.move_child(_stamp, _docs_layer.get_child_count() - 1)
	document_focused.emit(view.instance)


## Contraint le rectangle visuel (zoom compris) au plan de travail.
func clamp_view(view: DocumentView) -> void:
	var visual: Vector2 = view.size * view.scale
	var min_pos: Vector2 = Vector2(0.0, 0.0)
	var max_pos: Vector2 = size - visual
	view.position = Vector2(clampf(view.position.x, min_pos.x, maxf(max_pos.x, min_pos.x)),
			clampf(view.position.y, min_pos.y, maxf(max_pos.y, min_pos.y)))


## Zoom de lecture : bascule (0) ou pas de molette (±1) ; centre conservé.
func zoom_view(view: DocumentView, steps: int) -> void:
	var target: float = view.zoom
	if is_zero_approx(target):
		target = 1.0
	if steps == 0:
		target = 1.0 if view.zoom > 1.0 else DS.DOC_ZOOM
	elif steps > 0:
		target = DS.DOC_ZOOM
	else:
		target = 1.0
	if is_equal_approx(target, view.zoom):
		return
	bring_to_front(view)
	var center: Vector2 = view.position + view.size * view.scale * 0.5
	view.zoom = target
	# Le zoom de lecture s'applique à l'échelle d'ajustement du plan.
	var visual_scale: float = target * fit_scale
	var new_pos: Vector2 = center - view.size * visual_scale * 0.5
	var visual: Vector2 = view.size * visual_scale
	new_pos = Vector2(clampf(new_pos.x, 0.0, maxf(size.x - visual.x, 0.0)), clampf(new_pos.y, 0.0, maxf(size.y - visual.y, 0.0)))
	if reduce_motion:
		view.scale = Vector2(visual_scale, visual_scale)
		view.position = new_pos
		return
	var tween: Tween = view.create_tween().set_parallel(true)
	tween.tween_property(view, "scale", Vector2(visual_scale, visual_scale), DS.DUR_BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position", new_pos, DS.DUR_BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_grabbed(view: DocumentView) -> void:
	bring_to_front(view)


func _on_drag_moved(view: DocumentView, relative: Vector2) -> void:
	view.position += relative
	clamp_view(view)


func _on_zoom_requested(view: DocumentView, steps: int) -> void:
	zoom_view(view, steps)


func _on_field_picked(item: InspectableItem) -> void:
	field_picked.emit(item)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and inspection_active:
		background_clicked.emit()
		accept_event()


# ---------------------------------------------------------------------------
# En-tête, état vide, bandeau, tampon
# ---------------------------------------------------------------------------

func _build_header() -> void:
	_title = Label.new()
	_title.theme_type_variation = &"DocFieldLabel"
	_title.uppercase = true
	_title.position = Vector2(DS.SPACE_8, DS.SPACE_5)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var right: HBoxContainer = HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", DS.SPACE_2)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -DS.SPACE_8
	right.offset_top = DS.SPACE_4
	add_child(right)
	_mode_icon = UiIcon.make(UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY, DS.ICON_S)
	right.add_child(_mode_icon)
	_mode_label = Label.new()
	_mode_label.theme_type_variation = &"DocFieldLabel"
	_mode_label.uppercase = true
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_mode_label)
	_build_scanner_chip()


func _build_scanner_chip() -> void:
	scanner_chip = PanelContainer.new()
	scanner_chip.name = "ScannerChip"
	scanner_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	scanner_chip.visible = false
	add_child(scanner_chip)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_2)
	scanner_chip.add_child(row)
	_scanner_icon = UiIcon.make(UiIcon.Kind.SCANNER, DS.STATE_AMBER, DS.ICON_S)
	row.add_child(_scanner_icon)
	_scanner_label = Label.new()
	_scanner_label.theme_type_variation = &"DocFieldLabel"
	_scanner_label.uppercase = true
	_scanner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scanner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_scanner_label)
	var sep: Label = Label.new()
	sep.theme_type_variation = &"DocFieldLabel"
	sep.text = "·"
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)
	_scanner_count = Label.new()
	_scanner_count.theme_type_variation = &"DocFieldLabel"
	_scanner_count.uppercase = true
	_scanner_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_scanner_count)
	scanner_button = Button.new()
	scanner_button.name = "ScannerConfirm"
	scanner_button.theme_type_variation = &"ButtonGhost"
	scanner_button.focus_mode = Control.FOCUS_NONE
	scanner_button.text = UiText.t("wb_scanner_confirm", "CONFIRMER")
	scanner_button.pressed.connect(func() -> void: scanner_confirm_pressed.emit())
	row.add_child(scanner_button)


## Acte II : pastille du scanner (`text` vide la masque).
func set_scanner(text: String, color: Color, pending: int) -> void:
	_scanner_text = text
	scanner_chip.visible = not text.is_empty()
	if text.is_empty():
		return
	_scanner_label.text = text
	_scanner_label.add_theme_color_override(&"font_color", color)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		scanner_button.add_theme_color_override(state, color)
	_scanner_count.add_theme_color_override(&"font_color", color)
	_scanner_icon.color = color
	scanner_chip.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL.blend(Color(color, 0.12)), Color(color, 0.6),
			DS.BORDER_HAIRLINE, DS.CHAMFER_S, DS.SPACE_2))
	set_scanner_count(pending)


func set_scanner_count(pending: int) -> void:
	if _scanner_count == null:
		return
	_scanner_count.text = UiText.plural("wb_scanner_pending", pending, "%d lien à confirmer", "%d liens à confirmer") \
			if pending > 0 else UiText.t("wb_scanner_done", "dates conformes")
	scanner_button.visible = pending > 0
	_place_scanner_chip()


## Pastille juste après le titre du plan (jamais sur l'état du Mode Inspection).
func _place_scanner_chip() -> void:
	if scanner_chip == null or not scanner_chip.visible:
		return
	scanner_chip.reset_size()
	var left: float = _title.position.x + _title.get_combined_minimum_size().x + DS.SPACE_4
	scanner_chip.position = Vector2(left, (HEADER_H - scanner_chip.size.y) * 0.5 + DS.SPACE_1)


func get_scanner_text() -> String:
	return _scanner_text if scanner_chip.visible else ""


func _refresh_header() -> void:
	if _title == null:
		return
	if views.is_empty():
		_title.text = UiText.t("wb_title_empty", "PLAN DE TRAVAIL · VIDE")
	else:
		_title.text = UiText.plural("wb_title_count", views.size(), "PLAN DE TRAVAIL · %d DOCUMENT", "PLAN DE TRAVAIL · %d DOCUMENTS")
	_place_scanner_chip.call_deferred()
	if inspection_active:
		_mode_label.text = UiText.t("wb_mode_active", "MODE INSPECTION ACTIF")
		_mode_label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
		_mode_icon.color = DS.ACCENT_CYAN
	elif views.is_empty() or not inspection_available:
		_mode_label.text = _unavailable_reason if not _unavailable_reason.is_empty() and not views.is_empty() \
				else UiText.t("wb_mode_unavailable", "INSPECTION INDISPONIBLE · AUCUN DOCUMENT")
		_mode_label.add_theme_color_override(&"font_color", DS.TEXT_SECONDARY)
		_mode_icon.color = DS.TEXT_MUTED
	else:
		_mode_label.text = UiText.t("wb_mode_hint", "ESPACE · MODE INSPECTION")
		_mode_label.add_theme_color_override(&"font_color", DS.TEXT_SECONDARY)
		_mode_icon.color = DS.TEXT_SECONDARY


func set_inspection_available(available: bool, reason: String = "") -> void:
	inspection_available = available
	_unavailable_reason = reason
	_refresh_header()


func _build_empty_state() -> void:
	_empty = VBoxContainer.new()
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(_empty)
	var bar: ColorRect = ColorRect.new()
	bar.color = DS.LINE_SUBTLE
	bar.custom_minimum_size = Vector2(DS.SPACE_16 * 2, 3)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_child(bar)
	_empty_title = Label.new()
	_empty_title.theme_type_variation = &"PanelTitle"
	_empty_title.add_theme_color_override(&"font_color", DS.TEXT_SECONDARY)
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_child(_empty_title)
	_empty_text = Label.new()
	_empty_text.theme_type_variation = &"BodySmall"
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_child(_empty_text)


func set_empty_state(title: String, text: String) -> void:
	_empty_title.text = title
	_empty_text.text = text
	_empty.visible = views.is_empty() and items.is_empty()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_banner.offset_bottom = -DS.SPACE_4
	_banner.visible = false
	add_child(_banner)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_3)
	_banner.add_child(row)
	_banner_icon = UiIcon.make(UiIcon.Kind.WARNING, DS.ACCENT_MAGENTA, DS.ICON_M)
	row.add_child(_banner_icon)
	_banner_title = Label.new()
	_banner_title.theme_type_variation = &"BodyStrong"
	_banner_title.uppercase = true
	_banner_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_banner_title)
	var sep: ColorRect = ColorRect.new()
	sep.color = DS.LINE_SUBTLE
	sep.custom_minimum_size = Vector2(1, DS.SPACE_5)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)
	_banner_text = Label.new()
	_banner_text.theme_type_variation = &"BodyLabel"
	_banner_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_banner_text)


## Bandeau de résultat (bas du plan) ; `hold` > 0 : disparaît ensuite.
func show_banner(kind: BannerKind, title: String, text: String, hold: float = 0.0) -> void:
	var accent: Color = DS.ACCENT_MAGENTA
	var icon: UiIcon.Kind = UiIcon.Kind.WARNING
	match kind:
		BannerKind.CONCORDANT:
			accent = DS.ACCENT_CYAN
			icon = UiIcon.Kind.CHECK
		BannerKind.INCOMPARABLE:
			accent = DS.TEXT_SECONDARY
			icon = UiIcon.Kind.EQUAL
		BannerKind.INFO:
			accent = DS.ACCENT_CYAN
			icon = UiIcon.Kind.INFO
	var bg: Color = DS.BG_PANEL.blend(Color(accent, 0.12))
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(bg, accent, DS.BORDER_HAIRLINE, DS.CHAMFER_S, DS.SPACE_3)
	box.content_margin_left = DS.SPACE_4
	box.content_margin_right = DS.SPACE_5
	_banner.add_theme_stylebox_override(&"panel", box)
	_banner_icon.kind = icon
	_banner_icon.color = accent
	_banner_title.text = title
	_banner_title.add_theme_color_override(&"font_color", accent)
	_banner_text.text = text
	_banner_text.visible = not text.is_empty()
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.reset_size()
	if _banner_tween != null:
		_banner_tween.kill()
		_banner_tween = null
	if hold > 0.0:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(hold)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, DS.DUR_BASE)
		_banner_tween.tween_callback(_banner.hide)


func hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
		_banner_tween = null
	if _banner != null:
		_banner.visible = false


func is_banner_visible() -> bool:
	return _banner.visible


func get_banner_title() -> String:
	return _banner_title.text


## Empreinte du tampon sur le document au premier plan.
func show_stamp(kind: VerdictKind.Kind, caption: String, tilt_seed: int) -> void:
	_hide_stamp()
	var target: DocumentView = views.back() if not views.is_empty() else null
	for view: DocumentView in views:
		if view.active:
			target = view
	_stamp = StampMark.new()
	_stamp.kind = kind
	_stamp.caption = caption
	_docs_layer.add_child(_stamp)
	var anchor: Vector2 = size * 0.5
	if target != null:
		anchor = target.position + target.size * target.scale * Vector2(0.5, 0.55)
	_stamp.position = anchor - StampMark.SIZE * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tilt_seed
	_stamp.rotation_degrees = rng.randf_range(-DS.STAMP_TILT_MAX_DEG, DS.STAMP_TILT_MAX_DEG)
	if reduce_motion or fx_intensity <= 0.0:
		_stamp.modulate.a = 0.0
		create_tween().tween_property(_stamp, "modulate:a", 1.0, DS.DUR_INSTANT)
		return
	_stamp.scale = Vector2(1.08, 1.08) * 1.15
	_stamp.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_stamp, "modulate:a", 1.0, DS.DUR_INSTANT)
	tween.tween_property(_stamp, "scale", Vector2.ONE, DS.DUR_SLOW * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_stamp() -> void:
	if _stamp != null and is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, DS.BG_VOID)
	# Grille discrète du plan (décor, jamais d'information).
	var grid: Color = Color(DS.LINE_SUBTLE, 0.35)
	var x: float = GRID_STEP
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
		x += GRID_STEP
	var y: float = GRID_STEP
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
		y += GRID_STEP
	draw_line(Vector2(0, 0.5), Vector2(size.x, 0.5), DS.LINE_SUBTLE, 1.0)
	if inspection_active:
		draw_corner_brackets(self, rect.grow(-DS.SPACE_2), DS.ACCENT_CYAN)


## Équerres de coin cyan (cadre du Mode Inspection, UI_FLOW §3.4).
static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var l: float = DS.SPACE_6
	var w: float = DS.BORDER_STRONG
	canvas.draw_polyline([rect.position + Vector2(0, l), rect.position, rect.position + Vector2(l, 0)], color, w)
	canvas.draw_polyline([Vector2(rect.end.x - l, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + l)], color, w)
	canvas.draw_polyline([Vector2(rect.position.x, rect.end.y - l), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + l, rect.end.y)], color, w)
	canvas.draw_polyline([rect.end - Vector2(l, 0), rect.end, rect.end - Vector2(0, l)], color, w)
