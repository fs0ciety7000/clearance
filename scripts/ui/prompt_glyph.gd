## Glyphe d'invite d'une action (M11, UI_FLOW §9) : touche de clavier ou
## bouton de manette, **dessiné** aux tokens DS (aucune image) et mis à jour
## quand le joueur change de périphérique (`InputPrompts.device_changed`).
##
## Formes : touche (cadre chanfreiné + nom) · bouton de façade (cercle + lettre
## A B X Y, ou forme ✕ ○ □ △ PlayStation) · gâchette / tranche (onglet
## chanfreiné + nom) · croix directionnelle (branche pleine) · stick (cercle,
## point, flèche) · bouton système (cadre + nom). Monochrome : un glyphe
## n'est jamais porteur d'un état.
class_name PromptGlyph
extends Control

## Action de `project.godot` illustrée.
var action: StringName = &"":
	set(value):
		action = value
		_refresh()
## Couleur du trait et du texte (texte secondaire par défaut).
var color: Color = Palette.TEXT_SECONDARY:
	set(value):
		color = value
		queue_redraw()
## Périphérique imposé (−1 : celui d'`InputPrompts`).
var forced_device: int = -1:
	set(value):
		forced_device = value
		_refresh()

var _glyph: Dictionary = {}


static func make(p_action: StringName, p_color: Color = Palette.TEXT_SECONDARY) -> PromptGlyph:
	var glyph: PromptGlyph = PromptGlyph.new()
	glyph.action = p_action
	glyph.color = p_color
	return glyph


## Périphérique imposé (rappel des commandes : clavier et manette côte à côte).
func with_device(p_device: int) -> PromptGlyph:
	forced_device = p_device
	return self


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	InputPrompts.ensure(get_tree()).device_changed.connect(_on_device_changed)
	_refresh()


func _on_device_changed(_device: InputPrompts.Device) -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh()


## Description courante (tests) : {shape, text, index, value, device}.
func get_glyph() -> Dictionary:
	return _glyph


func get_text() -> String:
	return str(_glyph.get("text", ""))


func _font() -> Font:
	return get_theme_font(&"font", &"KeyCapLabel")


func _font_size() -> int:
	return get_theme_font_size(&"font_size", &"KeyCapLabel")


func _refresh() -> void:
	_glyph = InputPrompts.glyph_for(action, forced_device)
	if is_inside_tree():
		update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if _glyph.is_empty() or not is_inside_tree():
		return Vector2(DS.ICON_M, DS.ICON_M)
	var font_size: int = _font_size()
	var h: float = float(font_size) + DS.SPACE_2 + DS.SPACE_1
	var shape: int = _glyph["shape"]
	match shape:
		InputPrompts.Shape.FACE, InputPrompts.Shape.DPAD:
			return Vector2(h, h)
		InputPrompts.Shape.STICK:
			var text_w: float = _font().get_string_size(_stick_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			return Vector2(h + (text_w + DS.SPACE_1 if not _stick_label().is_empty() else 0.0), h)
	var w: float = _font().get_string_size(get_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(maxf(w + DS.SPACE_3, h), h)


func _draw() -> void:
	if _glyph.is_empty():
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var h: float = minf(size.y, get_minimum_size().y)
	rect = Rect2(Vector2(0.0, (size.y - h) * 0.5), Vector2(size.x, h))
	var shape: int = _glyph["shape"]
	match shape:
		InputPrompts.Shape.FACE:
			_draw_face(Rect2(rect.position, Vector2(h, h)))
		InputPrompts.Shape.DPAD:
			_draw_dpad(Rect2(rect.position, Vector2(h, h)))
		InputPrompts.Shape.STICK:
			_draw_stick(rect, h)
		InputPrompts.Shape.SHOULDER:
			_draw_frame(rect, true)
			_draw_text(rect, get_text())
		_:
			_draw_frame(rect, false)
			_draw_text(rect, get_text())


## Cadre chanfreiné : touche (coins bas-droite / haut-gauche) ou tranche
## (deux coins hauts coupés).
func _draw_frame(rect: Rect2, shoulder: bool) -> void:
	var c: float = DS.CHAMFER_S
	var r: Rect2 = rect.grow(-0.5)
	var pts: PackedVector2Array = []
	if shoulder:
		pts = [r.position + Vector2(c * 1.5, 0), Vector2(r.end.x - c * 1.5, r.position.y), Vector2(r.end.x, r.position.y + c * 1.5),
				r.end, Vector2(r.position.x, r.end.y), r.position + Vector2(0, c * 1.5)]
	else:
		pts = [r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - c),
				Vector2(r.end.x - c, r.end.y), Vector2(r.position.x, r.end.y), r.position + Vector2(0, c)]
	draw_colored_polygon(pts, DS.BG_VOID)
	pts.append(pts[0])
	draw_polyline(pts, color, DS.BORDER_DEFAULT, true)


func _draw_text(rect: Rect2, text: String) -> void:
	var font: Font = _font()
	var font_size: int = _font_size()
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(rect.get_center().x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DS.TEXT_PRIMARY)


## Bouton de façade : cercle, lettre (Xbox, Deck) ou forme (PlayStation).
func _draw_face(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = rect.size.x * 0.5 - 1.0
	draw_circle(center, radius, DS.BG_VOID)
	draw_arc(center, radius, 0.0, TAU, 32, color, DS.BORDER_DEFAULT, true)
	var d: int = _glyph["device"]
	if d != InputPrompts.Device.PLAYSTATION:
		_draw_text(rect, get_text())
		return
	var s: float = radius * 0.48
	var w: float = DS.ICON_STROKE
	match int(_glyph["index"]):
		JOY_BUTTON_A: # croix
			draw_line(center + Vector2(-s, -s), center + Vector2(s, s), DS.TEXT_PRIMARY, w, true)
			draw_line(center + Vector2(-s, s), center + Vector2(s, -s), DS.TEXT_PRIMARY, w, true)
		JOY_BUTTON_B: # rond
			draw_arc(center, s, 0.0, TAU, 24, DS.TEXT_PRIMARY, w, true)
		JOY_BUTTON_X: # carré
			draw_rect(Rect2(center - Vector2(s, s) * 0.9, Vector2(s, s) * 1.8), DS.TEXT_PRIMARY, false, w)
		_: # triangle
			var tri: PackedVector2Array = [center + Vector2(0, -s), center + Vector2(s, s * 0.75), center + Vector2(-s, s * 0.75), center + Vector2(0, -s)]
			draw_polyline(tri, DS.TEXT_PRIMARY, w, true)


## Croix directionnelle : contour en « + », branche du bouton pleine.
func _draw_dpad(rect: Rect2) -> void:
	var u: float = rect.size.x / 3.0
	var o: Vector2 = rect.position
	var arms: Dictionary[int, Rect2] = {
		JOY_BUTTON_DPAD_UP: Rect2(o + Vector2(u, 0), Vector2(u, u)),
		JOY_BUTTON_DPAD_DOWN: Rect2(o + Vector2(u, 2 * u), Vector2(u, u)),
		JOY_BUTTON_DPAD_LEFT: Rect2(o + Vector2(0, u), Vector2(u, u)),
		JOY_BUTTON_DPAD_RIGHT: Rect2(o + Vector2(2 * u, u), Vector2(u, u)),
	}
	draw_rect(Rect2(o + Vector2(u, u), Vector2(u, u)), DS.BG_VOID)
	for index: int in arms:
		var arm: Rect2 = arms[index]
		draw_rect(arm, DS.TEXT_PRIMARY if index == int(_glyph["index"]) else DS.BG_VOID)
		draw_rect(arm, color, false, DS.BORDER_HAIRLINE)


## Stick : cercle + point central ; clic = cercle double ; direction = flèche.
func _draw_stick(rect: Rect2, h: float) -> void:
	var circle: Rect2 = Rect2(rect.position, Vector2(h, h))
	var center: Vector2 = circle.get_center()
	var radius: float = h * 0.5 - 1.0
	draw_circle(center, radius, DS.BG_VOID)
	draw_arc(center, radius, 0.0, TAU, 32, color, DS.BORDER_DEFAULT, true)
	var index: int = _glyph["index"]
	var value: float = _glyph["value"]
	var is_axis: bool = absf(value) > 0.0
	if not is_axis:
		draw_arc(center, radius * 0.55, 0.0, TAU, 24, DS.TEXT_PRIMARY, DS.BORDER_DEFAULT, true)
	else:
		var dir: Vector2 = Vector2(signf(value), 0.0) if index == JOY_AXIS_LEFT_X or index == JOY_AXIS_RIGHT_X else Vector2(0.0, signf(value))
		var tip: Vector2 = center + dir * radius * 0.6
		var side: Vector2 = Vector2(-dir.y, dir.x) * radius * 0.3
		draw_colored_polygon([tip, tip - dir * radius * 0.45 + side, tip - dir * radius * 0.45 - side], DS.TEXT_PRIMARY)
		draw_circle(center - dir * radius * 0.25, 1.5, DS.TEXT_PRIMARY)
	var label: String = _stick_label()
	if not label.is_empty():
		var font: Font = _font()
		var font_size: int = _font_size()
		var baseline: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(circle.end.x + DS.SPACE_1, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DS.TEXT_PRIMARY)


## Nom du stick à côté du cercle (« LS », « R3 », « RS »…), sans la flèche.
func _stick_label() -> String:
	return get_text().get_slice(" ", 0)
