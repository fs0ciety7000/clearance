## Icône vectorielle dessinée (DS §6) : grille 24 px, trait 1,5–2 px, jointures
## carrées. Les formes d'état restent distinctes en niveaux de gris : cercle
## (approuvé), octogone (refusé), losange (discordance), triangle
## (avertissement), carré (information).
##
## Utilisable comme nœud (`UiIcon.make(kind, color)`) ou en dessin direct
## depuis un `_draw()` (`UiIcon.draw_icon(canvas, kind, rect, color)`).
## Pas d'asset SVG tant que `res://assets/icons/` est vide (Lucide, à venir).
class_name UiIcon
extends Control

enum Kind {
	DIAMOND, ## sélection / Mode Inspection (contour)
	DISCORDANCE, ## losange + « ≠ » (magenta)
	WARNING, ## triangle + « ! » (ambre / magenta)
	APPROVED, ## cercle + coche (vert)
	DENIED, ## octogone + croix (rouge)
	DETAIN, ## carré chanfreiné + barres (jaune)
	INFO, ## carré + « i » (cyan)
	CHAT, ## bulle (interroger)
	LOGO, ## losange Consortium plein (jaune)
	LOCK, ## cadenas (tampon verrouillé)
	CHECK, ## coche seule (concordant)
	EQUAL, ## « = » (concordant, sans couleur)
	SEAL_HEXAGON, ## sceau « hexagone solaire »
	SEAL_ORBIT, ## sceau « croix en orbite »
	SEAL_RING, ## sceau « anneau barré »
	BREATH, ## Acte II : trois souffles (ESSOUFFLÉ·E, rations d'air)
	AWAY, ## Acte II : porte et flèche sortante (absent·e : Soute, Tycho)
	FLAME, ## Acte II : flamme (voix des Brûlants)
	SCANNER, ## Acte II : réticule de balayage (scanner partiel, compteur)
	REGISTER, ## Acte II : registre à lignes (Commission, révocations)
	SCALES, ## Acte III : balance (Arbitrage, Enquête, convocations)
	STRIKE, ## Acte III : ligne barrée (règle ou document retiré·e)
}

@export var kind: Kind = Kind.DIAMOND:
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = DS.TEXT_PRIMARY:
	set(value):
		color = value
		queue_redraw()
@export var stroke: float = DS.ICON_STROKE:
	set(value):
		stroke = value
		queue_redraw()


static func make(p_kind: Kind, p_color: Color, icon_size: int = DS.ICON_M) -> UiIcon:
	var icon: UiIcon = UiIcon.new()
	icon.kind = p_kind
	icon.color = p_color
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon_size >= DS.ICON_L:
		icon.stroke = DS.BORDER_STRONG
	return icon


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var rect: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	draw_icon(self, kind, rect, color, stroke)


## Points d'un polygone régulier inscrit dans `rect` (rotation en radians).
static func regular(rect: Rect2, sides: int, angle_offset: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	for i: int in sides:
		var angle: float = angle_offset + TAU * i / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result


## Dessine `kind` dans `rect` (zone utile = 20/24 de la case, DS §6).
static func draw_icon(canvas: CanvasItem, p_kind: Kind, rect: Rect2, p_color: Color, p_stroke: float = DS.ICON_STROKE) -> void:
	var r: Rect2 = rect.grow(-rect.size.x * (2.0 / DS.ICON_GRID))
	var c: Vector2 = r.get_center()
	var u: float = r.size.x / 20.0 # unité de la grille utile
	match p_kind:
		Kind.DIAMOND:
			canvas.draw_polyline(closed(regular(r, 4, -PI / 2.0)), p_color, p_stroke, true)
			canvas.draw_colored_polygon(regular(r.grow(-6.0 * u), 4, -PI / 2.0), p_color)
		Kind.DISCORDANCE:
			canvas.draw_polyline(closed(regular(r, 4, -PI / 2.0)), p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-4, -2) * u, c + Vector2(4, -2) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(-4, 2) * u, c + Vector2(4, 2) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(2, -5) * u, c + Vector2(-2, 5) * u, p_color, p_stroke)
		Kind.WARNING:
			var tri: PackedVector2Array = [c + Vector2(0, -9) * u, c + Vector2(10, 8) * u, c + Vector2(-10, 8) * u]
			canvas.draw_polyline(closed(tri), p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(0, -3) * u, c + Vector2(0, 3) * u, p_color, p_stroke)
			canvas.draw_rect(Rect2(c + Vector2(-1, 4.5) * u, Vector2(2, 2) * u), p_color)
		Kind.APPROVED:
			canvas.draw_arc(c, r.size.x * 0.5, 0.0, TAU, 32, p_color, p_stroke, true)
			canvas.draw_polyline([c + Vector2(-5, 0) * u, c + Vector2(-1.5, 3.5) * u, c + Vector2(5, -3.5) * u], p_color, p_stroke, true)
		Kind.DENIED:
			canvas.draw_polyline(closed(regular(r, 8, PI / 8.0)), p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-4, -4) * u, c + Vector2(4, 4) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(4, -4) * u, c + Vector2(-4, 4) * u, p_color, p_stroke)
		Kind.DETAIN:
			var box: PackedVector2Array = [r.position + Vector2(4, 0) * u, r.end - Vector2(0, r.size.y), r.end - Vector2(0, 4) * u,
					r.end - Vector2(4, 0) * u, r.position + Vector2(0, r.size.y), r.position + Vector2(0, 4) * u]
			canvas.draw_polyline(closed(box), p_color, p_stroke, true)
			for x: float in [-4.0, 0.0, 4.0]:
				canvas.draw_line(c + Vector2(x, -6) * u, c + Vector2(x, 6) * u, p_color, p_stroke)
		Kind.INFO:
			canvas.draw_rect(r, p_color, false, p_stroke)
			canvas.draw_line(c + Vector2(0, -1) * u, c + Vector2(0, 6) * u, p_color, p_stroke)
			canvas.draw_rect(Rect2(c + Vector2(-1, -6) * u, Vector2(2, 2) * u), p_color)
		Kind.CHAT:
			var bubble: PackedVector2Array = [r.position + Vector2(0, 1) * u, Vector2(r.end.x, r.position.y + u),
					Vector2(r.end.x, c.y + 4 * u), c + Vector2(-2, 4) * u, c + Vector2(-7, 9) * u, c + Vector2(-7, 4) * u,
					Vector2(r.position.x, c.y + 4 * u)]
			canvas.draw_polyline(closed(bubble), p_color, p_stroke, true)
		Kind.LOGO:
			canvas.draw_colored_polygon(regular(r, 4, -PI / 2.0), p_color)
			canvas.draw_colored_polygon(regular(r.grow(-5.0 * u), 4, -PI / 2.0), DS.BG_VOID)
			canvas.draw_colored_polygon(regular(r.grow(-7.5 * u), 4, -PI / 2.0), p_color)
		Kind.LOCK:
			canvas.draw_rect(Rect2(c + Vector2(-7, -1) * u, Vector2(14, 10) * u), p_color, false, p_stroke)
			canvas.draw_arc(c + Vector2(0, -2) * u, 4.5 * u, PI, TAU, 12, p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-4.5, -2) * u, c + Vector2(-4.5, -1) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(4.5, -2) * u, c + Vector2(4.5, -1) * u, p_color, p_stroke)
		Kind.CHECK:
			canvas.draw_polyline([c + Vector2(-7, 0) * u, c + Vector2(-2, 5) * u, c + Vector2(7, -5) * u], p_color, p_stroke * 1.3, true)
		Kind.EQUAL:
			canvas.draw_line(c + Vector2(-6, -3) * u, c + Vector2(6, -3) * u, p_color, p_stroke * 1.3)
			canvas.draw_line(c + Vector2(-6, 3) * u, c + Vector2(6, 3) * u, p_color, p_stroke * 1.3)
		Kind.SEAL_HEXAGON:
			canvas.draw_polyline(closed(regular(r, 6, -PI / 2.0)), p_color, p_stroke, true)
			canvas.draw_arc(c, 4.0 * u, 0.0, TAU, 20, p_color, p_stroke, true)
			for i: int in 6:
				var dir: Vector2 = Vector2.from_angle(TAU * i / 6.0)
				canvas.draw_line(c + dir * 5.5 * u, c + dir * 7.5 * u, p_color, p_stroke)
		Kind.SEAL_ORBIT:
			canvas.draw_arc(c, r.size.x * 0.5, 0.0, TAU, 32, p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(0, -6) * u, c + Vector2(0, 6) * u, p_color, p_stroke * 1.4)
			canvas.draw_line(c + Vector2(-6, 0) * u, c + Vector2(6, 0) * u, p_color, p_stroke * 1.4)
			canvas.draw_set_transform(c, -0.5, Vector2(1.0, 0.35))
			canvas.draw_arc(Vector2.ZERO, 8.5 * u, 0.0, TAU, 32, p_color, p_stroke, true)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Kind.SEAL_RING:
			canvas.draw_arc(c, r.size.x * 0.5, 0.0, TAU, 32, p_color, p_stroke, true)
			canvas.draw_arc(c, r.size.x * 0.3, 0.0, TAU, 24, p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-9, 4) * u, c + Vector2(9, -4) * u, p_color, p_stroke * 1.6)
		Kind.BREATH:
			for i: int in 3:
				var y: float = (-5.0 + 5.0 * i) * u
				var length: float = (9.0 - 2.0 * absf(i - 1.0)) * u
				var wave: PackedVector2Array = []
				for k: int in 9:
					var t: float = float(k) / 8.0
					wave.append(c + Vector2(-length + 2.0 * length * t, 0.0) + Vector2(0.0, y + sin(t * TAU) * 1.4 * u))
				canvas.draw_polyline(wave, p_color, p_stroke, true)
		Kind.AWAY:
			var door: PackedVector2Array = [c + Vector2(1, -9) * u, c + Vector2(-8, -9) * u, c + Vector2(-8, 9) * u, c + Vector2(1, 9) * u]
			canvas.draw_polyline(door, p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-3, 0) * u, c + Vector2(9, 0) * u, p_color, p_stroke)
			canvas.draw_polyline([c + Vector2(5, -4) * u, c + Vector2(9, 0) * u, c + Vector2(5, 4) * u], p_color, p_stroke, true)
		Kind.FLAME:
			var flame: PackedVector2Array = [c + Vector2(0, -10) * u, c + Vector2(5, -2) * u, c + Vector2(6, 4) * u, c + Vector2(3, 9) * u,
					c + Vector2(-3, 9) * u, c + Vector2(-6, 4) * u, c + Vector2(-4, -1) * u, c + Vector2(-1, 2) * u]
			canvas.draw_polyline(closed(flame), p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(0, 3) * u, c + Vector2(0, 7) * u, p_color, p_stroke)
		Kind.SCANNER:
			var l: float = 5.0 * u
			for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				var dx: float = l if corner.x < c.x else -l
				var dy: float = l if corner.y < c.y else -l
				canvas.draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], p_color, p_stroke, true)
			canvas.draw_line(c + Vector2(-7, 0) * u, c + Vector2(7, 0) * u, p_color, p_stroke)
			canvas.draw_rect(Rect2(c + Vector2(-1.5, -1.5) * u, Vector2(3, 3) * u), p_color)
		Kind.REGISTER:
			canvas.draw_rect(Rect2(c + Vector2(-7, -9) * u, Vector2(14, 18) * u), p_color, false, p_stroke)
			for y: float in [-4.0, 0.0, 4.0]:
				canvas.draw_line(c + Vector2(-4, y) * u, c + Vector2(4, y) * u, p_color, p_stroke)
		Kind.SCALES:
			# Fléau, colonne, socle et deux plateaux suspendus.
			canvas.draw_line(c + Vector2(0, -9) * u, c + Vector2(0, 8) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(-5, 8) * u, c + Vector2(5, 8) * u, p_color, p_stroke)
			canvas.draw_line(c + Vector2(-8, -6) * u, c + Vector2(8, -6) * u, p_color, p_stroke)
			for side: float in [-1.0, 1.0]:
				var top: Vector2 = c + Vector2(7 * side, -6) * u
				canvas.draw_line(top, c + Vector2(7 * side - 3, 1) * u, p_color, p_stroke)
				canvas.draw_line(top, c + Vector2(7 * side + 3, 1) * u, p_color, p_stroke)
				canvas.draw_line(c + Vector2(7 * side - 4, 1) * u, c + Vector2(7 * side + 4, 1) * u, p_color, p_stroke)
		Kind.STRIKE:
			# Trois lignes de texte, la médiane barrée en travers.
			for y: float in [-5.0, 0.0, 5.0]:
				canvas.draw_line(c + Vector2(-7, y) * u, c + Vector2(7, y) * u, Color(p_color, 0.5), p_stroke)
			canvas.draw_line(c + Vector2(-9, 3) * u, c + Vector2(9, -3) * u, p_color, p_stroke)


## Icône du sceau d'un document (`seal_id` des `.tres`).
static func seal_kind(seal_id: StringName) -> Kind:
	match seal_id:
		&"seal_solar_hexagon":
			return Kind.SEAL_HEXAGON
		&"seal_orbit_cross":
			return Kind.SEAL_ORBIT
	return Kind.SEAL_RING
