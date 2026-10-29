## Objet glissé avec les papiers (M7, NARRATIVE §8.2 I1, ARCHITECTURE §7.1) :
## enveloppe (pot-de-vin, montant visible), mot plié, carte de quai — posé sur
## le plan de travail, **physique** (papier, pas un hologramme : fond
## `bg.elevated`, liseré de la couleur sémantique de l'objet).
##
## Anatomie : bandeau « OBJET GLISSÉ » · dessin de l'objet · libellé
## (`label_key`, « ENVELOPPE · 20 ₵ ») · texte lisible (mot, carte) · boutons
## de décision autorisés (`SlippedItem.allowed` : GARDER / RENDRE / REMETTRE À
## LA GARDE), exclusifs, modifiables jusqu'au tampon · puce d'état.
## Couleurs : enveloppe = ambre (attention : argent non déclaré), mot Luciole =
## magenta (contenu narratif/rebelle, DS §2.1), carte de quai = cyan.
## Déplaçable dans le plan comme un document. N'émet qu'une **intention**
## (`decision_requested`) : la décision est confirmée par `item_decided`.
class_name SlippedItemView
extends PanelContainer

signal decision_requested(item_id: StringName, decision: SlippedItem.Decision)
signal grabbed(view: SlippedItemView)
signal drag_moved(view: SlippedItemView, relative: Vector2)

const WIDTH: float = 372.0
const ART_SIZE: Vector2 = Vector2(88, 64)
const DECISIONS: Array[SlippedItem.Decision] = [SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN,
		SlippedItem.Decision.REPORT]

var item: SlippedItem = null
var decision: SlippedItem.Decision = SlippedItem.Decision.NONE
## Boutons par décision autorisée.
var buttons: Dictionary[SlippedItem.Decision, Button] = {}
## Plus de décision possible (tampon posé).
var locked: bool = false

var _accent: Color = DS.STATE_AMBER
var _status: PanelContainer = null
var _status_label: Label = null
var _status_icon: UiIcon = null
var _art: Control = null
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO


static func create(p_item: SlippedItem) -> SlippedItemView:
	var view: SlippedItemView = SlippedItemView.new()
	view.build(p_item)
	return view


## Couleur sémantique de l'objet (DS §2.1).
static func accent_of(p_item: SlippedItem) -> Color:
	if p_item == null:
		return DS.TEXT_SECONDARY
	match p_item.kind:
		SlippedItem.Kind.ENVELOPE:
			return DS.STATE_AMBER
		SlippedItem.Kind.NOTE:
			return DS.ACCENT_MAGENTA
	return DS.ACCENT_CYAN


## Libellé d'une décision (`ev_slipped_item_*`).
static func decision_label(p_decision: SlippedItem.Decision) -> String:
	match p_decision:
		SlippedItem.Decision.KEEP:
			return UiText.t("ev_slipped_item_keep", "GARDER")
		SlippedItem.Decision.REPORT:
			return UiText.t("ev_slipped_item_report", "REMETTRE À LA GARDE")
	return UiText.t("ev_slipped_item_return", "RENDRE")


## Libellé de l'objet (« ENVELOPPE · 20 ₵ »).
static func item_label(p_item: SlippedItem) -> String:
	var fallback: String = "OBJET"
	match p_item.kind:
		SlippedItem.Kind.ENVELOPE:
			fallback = "ENVELOPPE · %d ₵"
		SlippedItem.Kind.NOTE:
			fallback = "MOT PLIÉ"
		SlippedItem.Kind.DOCK_CARD:
			fallback = "CARTE DE QUAI"
	var text: String = UiText.t(p_item.label_key, fallback)
	return text % p_item.amount if text.contains("%d") else text


func build(p_item: SlippedItem) -> void:
	item = p_item
	_accent = accent_of(item)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_ELEVATED, Color(_accent, 0.6), DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_4)
	box.border_width_left = DS.BORDER_STRONG + 1
	box.border_color = _accent
	box.shadow_color = Color(DS.BG_VOID, 0.6)
	box.shadow_size = DS.GLOW_2
	add_theme_stylebox_override(&"panel", box)
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	add_child(column)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	column.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.WARNING if item.kind == SlippedItem.Kind.ENVELOPE else UiIcon.Kind.DISCORDANCE,
			_accent, DS.ICON_S))
	head.add_child(ScreenBase.eyebrow(UiText.t("wb_item_eyebrow", "GLISSÉ AVEC LES PAPIERS"), _accent))
	var body: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	column.add_child(body)
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size = ART_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	body.add_child(_art)
	var texts: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(texts)
	var title: Label = ScreenBase.label(item_label(item), &"DataTitle", DS.TEXT_PRIMARY)
	title.name = "ItemLabel"
	texts.add_child(title)
	var hint: String = UiText.t("wb_item_hint_envelope", "Non déclaré. Personne ne compte.") \
			if item.kind == SlippedItem.Kind.ENVELOPE else ""
	if not hint.is_empty():
		texts.add_child(ScreenBase.label(hint, &"CaptionLabel"))
	var lines: PackedStringArray = []
	if not item.text_key.is_empty():
		lines.append(UiText.t(item.text_key, ""))
	for key: String in item.extra_text_keys:
		lines.append(UiText.t(key, ""))
	var text: String = "\n".join(lines).strip_edges()
	if not text.is_empty():
		var note: Label = ScreenBase.wrapped(ComparisonUI.passenger_text(text), &"BodySmall", DS.TEXT_PRIMARY)
		note.name = "ItemText"
		column.add_child(note)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	column.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	group.allow_unpress = false
	for kind: SlippedItem.Decision in DECISIONS:
		if not item.is_allowed(kind):
			continue
		var button: Button = ScreenBase.button(decision_label(kind), &"ButtonTool")
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = DS.HIT_TARGET_MIN
		button.tooltip_text = _decision_tooltip(kind)
		button.add_theme_stylebox_override(&"pressed", ThemeBuilder.chamfer_box(DS.BG_ELEVATED.blend(Color(_accent, 0.12)), _accent,
				DS.BORDER_STRONG, DS.CHAMFER_M, DS.SPACE_2))
		button.pressed.connect(request.bind(kind))
		row.add_child(button)
		buttons[kind] = button
	_status = PanelContainer.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_status.add_child(status_row)
	_status_icon = UiIcon.make(UiIcon.Kind.INFO, DS.TEXT_SECONDARY, DS.ICON_S)
	status_row.add_child(_status_icon)
	_status_label = ScreenBase.label("", &"BodySmall")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_label)
	column.add_child(_status)
	_refresh()


func _decision_tooltip(kind: SlippedItem.Decision) -> String:
	var credits: int = item.credits_for(kind)
	var text: String = decision_label(kind)
	if credits > 0:
		text += " · " + ScreenBase.credits(credits, true)
	return text


## Intention du joueur (clic, test) : émise seulement si autorisée.
func request(kind: SlippedItem.Decision) -> bool:
	if locked or item == null or not item.is_allowed(kind):
		_refresh()
		return false
	decision_requested.emit(item.id, kind)
	# La décision affichée attend la confirmation (`item_decided`).
	_refresh()
	return true


## Décision confirmée par le DayController (`item_decided`).
func set_decision(p_decision: SlippedItem.Decision, final: bool = false) -> void:
	decision = p_decision
	locked = locked or final
	_refresh()


func lock() -> void:
	locked = true
	_refresh()


func _refresh() -> void:
	for kind: SlippedItem.Decision in buttons:
		var button: Button = buttons[kind]
		button.set_pressed_no_signal(kind == decision)
		button.disabled = locked and kind != decision
		if kind == decision:
			button.add_theme_color_override(&"font_color", _accent)
			button.add_theme_color_override(&"font_pressed_color", _accent)
		else:
			button.remove_theme_color_override(&"font_color")
			button.remove_theme_color_override(&"font_pressed_color")
	var color: Color = DS.TEXT_SECONDARY
	var icon: UiIcon.Kind = UiIcon.Kind.INFO
	var text: String = UiText.t("wb_item_pending", "À trancher avant le tampon — sinon rendu d'office.")
	if item != null and item.default_decision == SlippedItem.Decision.KEEP:
		text = UiText.t("wb_item_pending_keep", "À trancher avant le tampon — sinon gardé.")
	match decision:
		SlippedItem.Decision.KEEP:
			color = DS.STATE_AMBER if item.kind == SlippedItem.Kind.ENVELOPE else DS.ACCENT_CYAN
			icon = UiIcon.Kind.WARNING if item.kind == SlippedItem.Kind.ENVELOPE else UiIcon.Kind.CHECK
			text = UiText.tf("wb_item_kept_envelope", [ScreenBase.credits(item.amount, true)], "Gardée dans le tiroir · %s divers non déclaré") \
					if item.kind == SlippedItem.Kind.ENVELOPE else UiText.t("wb_item_kept", "Gardé dans le tiroir.")
		SlippedItem.Decision.RETURN:
			icon = UiIcon.Kind.CHECK
			text = UiText.t("wb_item_returned", "Rendu par la fente.")
		SlippedItem.Decision.REPORT:
			color = DS.ACCENT_YELLOW
			icon = UiIcon.Kind.LOGO
			text = UiText.tf("wb_item_reported", [ScreenBase.credits(item.report_bonus, true)], "Remis à la Garde · prime %s") \
					if item.report_bonus > 0 else UiText.t("wb_item_reported_plain", "Remis à la Garde.")
	_status_icon.kind = icon
	_status_icon.color = color
	_status_label.text = text
	_status_label.add_theme_color_override(&"font_color", color if decision != SlippedItem.Decision.NONE else DS.TEXT_SECONDARY)
	var bg: Color = Color(color, 0.12) if decision != SlippedItem.Decision.NONE else Color(DS.BG_PANEL, 0.0)
	_status.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(bg, Color(color, 0.0), 0, DS.CHAMFER_S, DS.SPACE_1))
	if _art != null:
		_art.queue_redraw()


## Dessin de l'objet (trait 1,5–2 px, DS §6), dans le cadre `ART_SIZE`.
func _draw_art() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _art.size).grow(-DS.SPACE_1)
	var line: Color = _accent
	var paper: Color = DS.BG_PANEL.lerp(DS.TEXT_SECONDARY, 0.12)
	match item.kind:
		SlippedItem.Kind.ENVELOPE:
			var env: Rect2 = Rect2(r.position + Vector2(0, r.size.y * 0.12), Vector2(r.size.x, r.size.y * 0.76))
			_art.draw_rect(env, paper)
			_art.draw_rect(env, line, false, DS.BORDER_STRONG)
			var mid: Vector2 = Vector2(env.get_center().x, env.position.y + env.size.y * 0.55)
			_art.draw_polyline([env.position, mid, Vector2(env.end.x, env.position.y)], line, DS.ICON_STROKE)
			_art.draw_line(Vector2(env.position.x, env.end.y), mid + Vector2(-env.size.x * 0.12, 0), Color(line, 0.5), 1.0)
			_art.draw_line(env.end, mid + Vector2(env.size.x * 0.12, 0), Color(line, 0.5), 1.0)
			# Billets qui dépassent (crédits, jaune Consortium atténué).
			_art.draw_rect(Rect2(env.position + Vector2(env.size.x * 0.18, -DS.SPACE_2), Vector2(env.size.x * 0.5, DS.SPACE_2 + 2)),
					Color(DS.ACCENT_YELLOW, 0.55))
		SlippedItem.Kind.NOTE:
			var sheet: PackedVector2Array = [r.position + Vector2(r.size.x * 0.1, 0), Vector2(r.end.x, r.position.y + r.size.y * 0.1),
					Vector2(r.end.x - r.size.x * 0.1, r.end.y), Vector2(r.position.x, r.end.y - r.size.y * 0.1)]
			_art.draw_colored_polygon(sheet, paper)
			var closed: PackedVector2Array = sheet.duplicate()
			closed.append(sheet[0])
			_art.draw_polyline(closed, line, DS.BORDER_STRONG)
			_art.draw_line(sheet[0].lerp(sheet[3], 0.5), sheet[1].lerp(sheet[2], 0.5), Color(line, 0.5), 1.0)
			for i: int in 3:
				var y: float = r.position.y + r.size.y * (0.28 + 0.13 * i)
				_art.draw_line(Vector2(r.position.x + r.size.x * 0.22, y), Vector2(r.end.x - r.size.x * 0.25, y + 2.0),
						Color(DS.TEXT_SECONDARY, 0.6), 1.0)
			draw_luciole(_art, r.end - Vector2(r.size.x * 0.26, r.size.y * 0.3), DS.SPACE_3, line)
		SlippedItem.Kind.FORM:
			_draw_form(r, line, paper)
		SlippedItem.Kind.OBJECT:
			_draw_object(r, line, paper)
		SlippedItem.Kind.FILE:
			_draw_file(r, line, paper)
		_:
			_draw_dock_card(r, line, paper)


## Carte de quai (« Q6 ») : seulement pour `DOCK_CARD` (QA-035).
func _draw_dock_card(r: Rect2, line: Color, paper: Color) -> void:
	var card: Rect2 = Rect2(r.position + Vector2(0, r.size.y * 0.15), Vector2(r.size.x, r.size.y * 0.7))
	_art.draw_rect(card, paper)
	_art.draw_rect(card, line, false, DS.BORDER_STRONG)
	_art.draw_rect(Rect2(card.position, Vector2(card.size.x, DS.SPACE_3)), Color(line, 0.3))
	var font: Font = get_theme_font(&"font", &"DataSmall")
	var size_px: int = get_theme_font_size(&"font_size", &"CaptionLabel")
	_art.draw_string(font, card.position + Vector2(DS.SPACE_2, card.size.y * 0.72), "Q6", HORIZONTAL_ALIGNMENT_LEFT, -1,
			size_px + 6, line)


## Formulaire (27-B) ou convocation (ENQ) : feuille debout, en-tête, lignes à
## remplir, cases ; la convocation porte le cachet rond de l'Enquête.
func _draw_form(r: Rect2, line: Color, paper: Color) -> void:
	var w: float = r.size.y * 0.78
	var sheet: Rect2 = Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y), Vector2(w, r.size.y))
	_art.draw_rect(sheet, paper)
	_art.draw_rect(sheet, line, false, DS.BORDER_STRONG)
	_art.draw_rect(Rect2(sheet.position, Vector2(sheet.size.x, DS.SPACE_2)), Color(line, 0.3))
	var muted: Color = Color(DS.TEXT_SECONDARY, 0.6)
	for i: int in 4:
		var y: float = sheet.position.y + sheet.size.y * (0.32 + 0.15 * i)
		var box: Rect2 = Rect2(Vector2(sheet.position.x + DS.SPACE_1 + 1, y - 3.0), Vector2(5, 5))
		_art.draw_rect(box, muted, false, 1.0)
		_art.draw_line(Vector2(box.end.x + DS.SPACE_1, y), Vector2(sheet.end.x - DS.SPACE_2, y), muted, 1.0)
	if item.label_key == "wb_summons_label":
		var seal: Vector2 = sheet.end - Vector2(DS.SPACE_2 + 2, DS.SPACE_2 + 2)
		_art.draw_arc(seal, DS.SPACE_2, 0.0, TAU, 20, line, DS.ICON_STROKE)
		_art.draw_line(seal + Vector2(-4, 0), seal + Vector2(4, 0), line, 1.0)
		_art.draw_line(seal + Vector2(0, -4), seal + Vector2(0, 3), line, 1.0)


## Objet (écrou, liasse…) : petit colis ficelé, étiquette pendante.
func _draw_object(r: Rect2, line: Color, paper: Color) -> void:
	var box: Rect2 = Rect2(r.position + Vector2(r.size.x * 0.14, r.size.y * 0.22), Vector2(r.size.x * 0.56, r.size.y * 0.66))
	var depth: Vector2 = Vector2(r.size.x * 0.14, -r.size.y * 0.16)
	var top: PackedVector2Array = [box.position, box.position + depth, Vector2(box.end.x, box.position.y) + depth,
			Vector2(box.end.x, box.position.y)]
	var side: PackedVector2Array = [Vector2(box.end.x, box.position.y), Vector2(box.end.x, box.position.y) + depth, box.end + depth,
			box.end]
	_art.draw_colored_polygon(top, paper.lerp(DS.TEXT_SECONDARY, 0.1))
	_art.draw_colored_polygon(side, paper.lerp(DS.BG_VOID, 0.3))
	_art.draw_rect(box, paper)
	for poly: PackedVector2Array in [top, side]:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		_art.draw_polyline(closed, line, DS.BORDER_HAIRLINE + 0.5)
	_art.draw_rect(box, line, false, DS.BORDER_STRONG)
	# Ficelle en croix et étiquette.
	var string_color: Color = Color(line, 0.6)
	_art.draw_line(Vector2(box.get_center().x, box.position.y), Vector2(box.get_center().x, box.end.y), string_color, 1.0)
	_art.draw_line(Vector2(box.position.x, box.get_center().y), Vector2(box.end.x, box.get_center().y), string_color, 1.0)
	var knot: Vector2 = box.get_center()
	var tag: Rect2 = Rect2(Vector2(box.end.x + depth.x * 0.3, box.end.y - DS.SPACE_4), Vector2(DS.SPACE_4, DS.SPACE_3))
	_art.draw_line(knot, tag.position, string_color, 1.0)
	_art.draw_rect(tag, paper)
	_art.draw_rect(tag, line, false, 1.0)


## Dossier (`FILE`) : chemise à onglet, feuillets qui dépassent ; le registre
## de Tycho (`wb_registre_label`) est un cahier relié, dos et tranche.
func _draw_file(r: Rect2, line: Color, paper: Color) -> void:
	var muted: Color = Color(DS.TEXT_SECONDARY, 0.6)
	if item.label_key == "wb_registre_label":
		var book: Rect2 = Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.06), Vector2(r.size.x * 0.8, r.size.y * 0.88))
		_art.draw_rect(Rect2(book.position + Vector2(3, 3), book.size), Color(paper, 0.7))
		_art.draw_rect(Rect2(book.position + Vector2(3, 3), book.size), muted, false, 1.0)
		_art.draw_rect(book, paper)
		_art.draw_rect(book, line, false, DS.BORDER_STRONG)
		var spine: Rect2 = Rect2(book.position, Vector2(DS.SPACE_3, book.size.y))
		_art.draw_rect(spine, Color(line, 0.35))
		for i: int in 3:
			var y: float = book.position.y + book.size.y * (0.2 + 0.3 * i)
			_art.draw_line(Vector2(spine.position.x, y), Vector2(spine.end.x, y), line, 1.0)
		var label_rect: Rect2 = Rect2(Vector2(spine.end.x + DS.SPACE_2, book.position.y + book.size.y * 0.3),
				Vector2(book.end.x - spine.end.x - DS.SPACE_4, book.size.y * 0.24))
		_art.draw_rect(label_rect, line, false, 1.0)
		_art.draw_line(label_rect.position + Vector2(DS.SPACE_1, label_rect.size.y * 0.5),
				Vector2(label_rect.end.x - DS.SPACE_1, label_rect.position.y + label_rect.size.y * 0.5), muted, 1.0)
		return
	var back: Rect2 = Rect2(r.position + Vector2(0, r.size.y * 0.12), Vector2(r.size.x, r.size.y * 0.8))
	var tab: Rect2 = Rect2(back.position - Vector2(0, DS.SPACE_2), Vector2(back.size.x * 0.36, DS.SPACE_2 + 1))
	_art.draw_rect(tab, paper.lerp(line, 0.18))
	_art.draw_rect(tab, line, false, 1.0)
	_art.draw_rect(back, paper.lerp(line, 0.18))
	_art.draw_rect(back, line, false, 1.0)
	# Feuillets qui dépassent.
	_art.draw_rect(Rect2(back.position + Vector2(DS.SPACE_2, DS.SPACE_1), Vector2(back.size.x - DS.SPACE_4, back.size.y * 0.5)),
			DS.BG_PANEL.lerp(DS.TEXT_SECONDARY, 0.3))
	var front: Rect2 = Rect2(back.position + Vector2(0, back.size.y * 0.22), Vector2(back.size.x, back.size.y * 0.78))
	_art.draw_rect(front, paper)
	_art.draw_rect(front, line, false, DS.BORDER_STRONG)
	var label_rect: Rect2 = Rect2(front.position + Vector2(front.size.x * 0.3, front.size.y * 0.3), Vector2(front.size.x * 0.4, DS.SPACE_3))
	_art.draw_rect(label_rect, line, false, 1.0)


## Glyphe « luciole » (code 1, bulletin « Symboles subversifs ») : corps,
## ailes, halo — magenta (DS : narratif/rebelle).
static func draw_luciole(canvas: CanvasItem, center: Vector2, scale_px: float, color: Color) -> void:
	canvas.draw_circle(center, scale_px * 1.1, Color(color, 0.16))
	canvas.draw_circle(center + Vector2(0, scale_px * 0.35), scale_px * 0.32, color)
	canvas.draw_line(center + Vector2(0, -scale_px * 0.55), center + Vector2(0, scale_px * 0.2), color, maxf(scale_px * 0.18, 1.0))
	for side: float in [-1.0, 1.0]:
		var wing: PackedVector2Array = [center + Vector2(0, -scale_px * 0.3), center + Vector2(side * scale_px * 0.9, -scale_px * 0.75),
				center + Vector2(side * scale_px * 0.75, -scale_px * 0.05), center + Vector2(0, -scale_px * 0.05)]
		wing.append(wing[0])
		canvas.draw_polyline(wing, color, maxf(scale_px * 0.1, 1.0))
	canvas.draw_line(center + Vector2(-scale_px * 0.15, -scale_px * 0.55), center + Vector2(-scale_px * 0.4, -scale_px * 0.95), color, 1.0)
	canvas.draw_line(center + Vector2(scale_px * 0.15, -scale_px * 0.55), center + Vector2(scale_px * 0.4, -scale_px * 0.95), color, 1.0)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			grabbed.emit(self)
			_dragging = true
			_drag_last = get_global_mouse_position()
		else:
			_dragging = false
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		var now: Vector2 = get_global_mouse_position()
		drag_moved.emit(self, now - _drag_last)
		_drag_last = now
		accept_event()
