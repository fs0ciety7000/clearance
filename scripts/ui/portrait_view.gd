## Photo d'un document (champ `PORTRAIT`) : texture fournie par le
## `PortraitService` de l'intégrateur (via `ComparisonUI.portrait_provider`) ou,
## à défaut, **placeholder** vectoriel dérivé de l'apparence (forme du visage,
## teinte de peau, coiffure, yeux, implant, visière) : deux apparences
## différentes donnent deux silhouettes distinctes, ce qui garde la
## comparaison Visage ↔ Photo jouable sans le rendu 3D.
class_name PortraitView
extends Control

var appearance: PassengerAppearance = null:
	set(value):
		appearance = value
		queue_redraw()
var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()
## Fond, trame et cadre de photo (faux pour un acteur en pied, démo).
var framed: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## Hash stable (0..1) d'un identifiant d'option.
static func unit_hash(id: StringName, salt: int = 0) -> float:
	var h: int = hash(String(id)) ^ (salt * 0x9E3779B1)
	return float(posmod(h, 10007)) / 10007.0


## Teinte de peau dérivée de l'option `skin` (dégradé chaud, 8 niveaux).
static func skin_color(app: PassengerAppearance) -> Color:
	var skin: String = String(app.get_trait(&"skin"))
	var level: float = 0.5
	if skin.length() >= 2 and skin.right(2).is_valid_int():
		level = clampf((skin.right(2).to_int() - 1) / 7.0, 0.0, 1.0)
	else:
		level = unit_hash(app.get_trait(&"skin"))
	return Color.from_ok_hsl(0.17 + 0.03 * unit_hash(app.get_trait(&"skin"), 1), 0.32, lerpf(0.78, 0.32, level))


static func hair_color(app: PassengerAppearance) -> Color:
	var h: float = unit_hash(app.get_trait(&"hair"), 2)
	return Color.from_ok_hsl(0.08 + 0.06 * h, 0.25, lerpf(0.12, 0.55, unit_hash(app.get_trait(&"hair"), 3)))


static func eye_color(app: PassengerAppearance) -> Color:
	var eyes: String = String(app.get_trait(&"eyes"))
	if eyes.contains("blue"):
		return DS.ACCENT_CYAN.darkened(0.25)
	if eyes.contains("green"):
		return DS.STATE_GREEN.darkened(0.45)
	if eyes.contains("grey"):
		return DS.TEXT_SECONDARY
	if eyes.contains("hazel"):
		return DS.STATE_AMBER.darkened(0.45)
	if eyes.contains("heterochromia"):
		return DS.ACCENT_MAGENTA.darkened(0.2)
	return DS.STATE_AMBER.darkened(0.65)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if size.x < DS.SPACE_4 or size.y < DS.SPACE_4:
		return # pas encore mis en page : polygones dégénérés
	if framed:
		draw_rect(rect, DS.BG_VOID.blend(DS.CYAN_08))
	if texture != null:
		draw_texture_rect(texture, rect, false)
	elif appearance != null:
		_draw_placeholder(rect, appearance)
	else:
		_draw_silhouette(rect, DS.TEXT_MUTED, DS.LINE_SUBTLE)
	if not framed:
		return
	# Lignes de trame discrètes (cadre holo, jamais sur une donnée).
	var y: float = 0.0
	var line: Color = DS.CYAN_08
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
		y += DS.FX_SCANLINE_PERIOD_PX * 2.0
	draw_rect(rect, DS.CYAN_40, false, DS.BORDER_HAIRLINE)


func _draw_silhouette(rect: Rect2, head: Color, body: Color) -> void:
	var c: Vector2 = Vector2(rect.get_center().x, rect.size.y * 0.42)
	var r: float = rect.size.x * 0.22
	draw_colored_polygon(_shoulders(rect), body)
	draw_circle(c, r, head)


func _shoulders(rect: Rect2) -> PackedVector2Array:
	var w: float = rect.size.x
	var h: float = rect.size.y
	return PackedVector2Array([Vector2(w * 0.12, h), Vector2(w * 0.2, h * 0.76), Vector2(w * 0.4, h * 0.68),
			Vector2(w * 0.6, h * 0.68), Vector2(w * 0.8, h * 0.76), Vector2(w * 0.88, h)])


func _draw_placeholder(rect: Rect2, app: PassengerAppearance) -> void:
	var skin: Color = skin_color(app)
	var w: float = rect.size.x
	var h: float = rect.size.y
	var c: Vector2 = Vector2(w * 0.5, h * 0.42)
	var face_id: String = String(app.get_trait(&"face"))
	# Forme du visage (round / square / oval / angular), largeur selon la variante.
	var rx: float = w * (0.2 + 0.03 * unit_hash(app.get_trait(&"face"), 4))
	var ry: float = rx * 1.2
	if face_id.contains("oval"):
		ry = rx * 1.38
	elif face_id.contains("round"):
		ry = rx * 1.08
	# Épaules (tenue = palette).
	var outfit: Color = Color.from_ok_hsl(unit_hash(app.palette_id, 5), 0.18, 0.28)
	draw_colored_polygon(_shoulders(rect), outfit)
	draw_rect(Rect2(c.x - rx * 0.35, c.y + ry * 0.8, rx * 0.7, ry * 0.5), skin.darkened(0.15))
	# Cheveux longs derrière la tête.
	var hair: String = String(app.get_trait(&"hair"))
	var hair_c: Color = hair_color(app)
	if hair.contains("long"):
		draw_rect(Rect2(c.x - rx * 1.15, c.y - ry * 0.3, rx * 2.3, ry * 1.6), hair_c)
	# Tête.
	var head: PackedVector2Array = _head_shape(c, rx, ry, face_id)
	draw_colored_polygon(head, skin)
	# Cheveux (calotte) sauf crâne rasé.
	if not hair.contains("shaved") and not hair.contains("bald"):
		var cap: PackedVector2Array = []
		for i: int in 17:
			var a: float = PI + PI * i / 16.0
			cap.append(c + Vector2(cos(a) * rx * 1.06, sin(a) * ry * 1.05 - ry * 0.05))
		# Arc fermé par sa corde : polygone convexe (les deux points bas
		# ajoutés autrefois croisaient l'arc → triangulation impossible).
		draw_colored_polygon(cap, hair_c)
	# Yeux, nez/bouche.
	var eye_y: float = c.y + ry * 0.05
	var eye_dx: float = rx * 0.42
	var eye: Color = eye_color(app)
	var eyes_id: String = String(app.get_trait(&"eyes"))
	draw_rect(Rect2(c.x - eye_dx - rx * 0.16, eye_y - 1.5, rx * 0.32, 3.0), eye)
	var right_eye: Color = eye if not eyes_id.contains("heterochromia") else DS.ACCENT_CYAN.darkened(0.3)
	draw_rect(Rect2(c.x + eye_dx - rx * 0.16, eye_y - 1.5, rx * 0.32, 3.0), right_eye)
	var mouth_w: float = rx * (0.4 + 0.25 * unit_hash(app.get_trait(&"nose_mouth"), 6))
	draw_line(Vector2(c.x, eye_y + ry * 0.12), Vector2(c.x - 2.0, eye_y + ry * 0.38), skin.darkened(0.3), 1.5)
	draw_line(Vector2(c.x - mouth_w * 0.5, eye_y + ry * 0.6), Vector2(c.x + mouth_w * 0.5, eye_y + ry * 0.6), skin.darkened(0.4), 2.0)
	# Tatouage holo / implant visible (accessoire).
	var accessory: String = String(app.get_trait(&"accessory"))
	if accessory.contains("tattoo") or accessory.contains("implant"):
		draw_rect(Rect2(c.x - eye_dx - rx * 0.2, eye_y + ry * 0.25, 3.0, ry * 0.3), DS.ACCENT_CYAN)
	if hair.contains("mohawk"):
		draw_rect(Rect2(c.x - rx * 0.15, c.y - ry * 1.3, rx * 0.3, ry * 0.5), hair_c)
	elif hair.contains("bun"):
		draw_circle(Vector2(c.x, c.y - ry * 1.1), rx * 0.32, hair_c)
	# Visière baissée : bandeau opaque sur les yeux.
	if app.is_face_covered():
		draw_rect(Rect2(c.x - rx * 1.15, eye_y - ry * 0.3, rx * 2.3, ry * 0.5), DS.BG_ELEVATED)
		draw_line(Vector2(c.x - rx * 1.1, eye_y), Vector2(c.x + rx * 1.1, eye_y), DS.CYAN_40, 1.0)


func _head_shape(c: Vector2, rx: float, ry: float, face_id: String) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var square: bool = face_id.contains("square")
	var angular: bool = face_id.contains("angular")
	for i: int in 24:
		var a: float = TAU * i / 24.0
		var p: Vector2 = Vector2(cos(a) * rx, sin(a) * ry)
		if square:
			p = Vector2(signf(p.x) * pow(absf(cos(a)), 0.6) * rx, signf(p.y) * pow(absf(sin(a)), 0.6) * ry)
		elif angular and sin(a) > 0.0:
			p.x *= lerpf(1.0, 0.55, sin(a))
		points.append(c + p)
	return points
