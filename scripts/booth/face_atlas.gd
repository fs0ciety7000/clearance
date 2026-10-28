## Atlas d'expressions **provisoire**, dessiné procéduralement (BOOTH_SCENE §10.3).
##
## 512×512, grille 4×4 de cellules 128 px. Lignes 0–1 : yeux + sourcils ;
## lignes 2–3 : bouches. Canaux : R = encre, G = iris, B = pupille, A = couverture.
## Remplacé en M6 par `tex_face_<type>_atlas.png` (même grille, mêmes canaux).
## Les formes sont tracées en « espace visuel » (x ∈ [0;1], y ∈ [0;1/ASPECT])
## car chaque demi-visage du quad est plus large que haut.
class_name FaceAtlas
extends RefCounted

const SIZE: int = 512
const CELL: int = 128
## Largeur / hauteur d'une demi-plaque visage (quad 0,165 × 0,20 m → 0,165 × 0,10).
const ASPECT: float = 1.65

# Cellules (index = ligne * 4 + colonne).
const EYES_NEUTRAL: int = 0
const EYES_NERVOUS: int = 1
const EYES_ANGRY: int = 2
const EYES_RELIEVED: int = 3
const EYES_SUSPICIOUS: int = 4
const EYES_SAD: int = 5
const EYES_WINK: int = 6
const EYES_CLOSED: int = 7
const MOUTH_NEUTRAL: int = 8
const MOUTH_TIGHT: int = 9
const MOUTH_OPEN_A: int = 10
const MOUTH_OPEN_O: int = 11
const MOUTH_SMILE: int = 12
const MOUTH_GRIMACE: int = 13
const MOUTH_POUT: int = 14
const MOUTH_CLENCHED: int = 15

const INK: Color = Color(1, 0, 0, 1)
const IRIS: Color = Color(0, 1, 0, 1)
const PUPIL: Color = Color(0, 0, 1, 1)
## Blanc de l'œil : couverture seule (aucun canal) → couleur de sclère du shader.
const SCLERA: Color = Color(0, 0, 0, 1)
const CLEAR: Color = Color(0, 0, 0, 0)

# Traits volontairement appuyés (lisibles à ~100 px de visage dans la bande 3D).
const EYE_Y: float = 0.40
const BROW_Y: float = 0.20
const EYE_LEFT_X: float = 0.28
const EYE_RIGHT_X: float = 0.72
const EYE_RX: float = 0.115
const EYE_RY: float = 0.075
const IRIS_R: float = 0.068
const PUPIL_R: float = 0.03
const LID: float = 0.028
const BROW: float = 0.034
const MOUTH_Y: float = 0.27
const LIP: float = 0.03

static var _texture: ImageTexture = null


## Texture partagée (construite une fois).
static func get_texture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(build_image())
	return _texture


static func build_image() -> Image:
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	_draw_eyes(img)
	_draw_mouths(img)
	return img


static func _draw_eyes(img: Image) -> void:
	# 0 neutre
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_open_eye(img, EYES_NEUTRAL, x, 1.0, 0.0)
	_brow(img, EYES_NEUTRAL, 0.0, 0.0)
	# 1 nerveux : yeux écarquillés, petites pupilles, sourcils relevés au centre
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_open_eye(img, EYES_NERVOUS, x, 1.3, 0.0, 0.7)
	_brow(img, EYES_NERVOUS, -0.05, 0.0)
	# 2 colère : sourcils froncés, paupière basse
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_open_eye(img, EYES_ANGRY, x, 1.0, 0.0)
		_lid_cut(img, EYES_ANGRY, x, -0.025)
	_brow(img, EYES_ANGRY, 0.06, -0.02)
	# 3 soulagé : paupières mi-closes, arc doux
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_open_eye(img, EYES_RELIEVED, x, 1.0, 0.01)
		_lid_cut(img, EYES_RELIEVED, x, 0.0)
	_brow(img, EYES_RELIEVED, -0.025, -0.01)
	# 4 suspicieux : œil gauche plissé, sourcil droit levé
	_open_eye(img, EYES_SUSPICIOUS, EYE_LEFT_X, 1.0, 0.0)
	_lid_cut(img, EYES_SUSPICIOUS, EYE_LEFT_X, -0.012)
	_open_eye(img, EYES_SUSPICIOUS, EYE_RIGHT_X, 1.05, 0.0)
	_line(img, EYES_SUSPICIOUS, Vector2(0.15, BROW_Y + 0.07), Vector2(0.41, BROW_Y + 0.08), BROW, INK)
	_line(img, EYES_SUSPICIOUS, Vector2(0.59, BROW_Y - 0.02), Vector2(0.85, BROW_Y - 0.06), BROW, INK)
	# 5 triste : sourcils en accent circonflexe, regard bas
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_open_eye(img, EYES_SAD, x, 0.95, 0.025)
	_brow(img, EYES_SAD, -0.05, 0.035)
	# 6 clin d'œil (œil droit fermé)
	_open_eye(img, EYES_WINK, EYE_LEFT_X, 1.0, 0.0)
	_closed_eye(img, EYES_WINK, EYE_RIGHT_X)
	_brow(img, EYES_WINK, 0.0, 0.0)
	# 7 fermés (clignement)
	for x: float in [EYE_LEFT_X, EYE_RIGHT_X]:
		_closed_eye(img, EYES_CLOSED, x)
	_brow(img, EYES_CLOSED, 0.0, 0.0)


static func _draw_mouths(img: Image) -> void:
	var c: Vector2 = Vector2(0.5, MOUTH_Y)
	_line(img, MOUTH_NEUTRAL, c + Vector2(-0.17, 0.0), c + Vector2(0.17, 0.0), LIP, INK)
	_line(img, MOUTH_TIGHT, c + Vector2(-0.10, 0.0), c + Vector2(0.10, 0.0), LIP * 1.5, INK)
	_ellipse(img, MOUTH_OPEN_A, c + Vector2(0, 0.01), Vector2(0.15, 0.06), INK)
	_ellipse(img, MOUTH_OPEN_O, c + Vector2(0, 0.01), Vector2(0.08, 0.075), INK)
	_arc(img, MOUTH_SMILE, c + Vector2(0, -0.05), 0.18, 0.075, 15.0, 165.0, LIP, INK)
	var zig: Array[Vector2] = [Vector2(-0.18, 0.0), Vector2(-0.1, -0.025), Vector2(-0.03, 0.02),
			Vector2(0.04, -0.025), Vector2(0.11, 0.02), Vector2(0.18, -0.005)]
	for i: int in zig.size() - 1:
		_line(img, MOUTH_GRIMACE, c + zig[i], c + zig[i + 1], LIP * 0.9, INK)
	_arc(img, MOUTH_POUT, c + Vector2(0, 0.065), 0.15, 0.06, 200.0, 340.0, LIP, INK)
	_rect_outline(img, MOUTH_CLENCHED, c + Vector2(-0.15, -0.035), c + Vector2(0.15, 0.035), LIP * 0.8)
	_fill_rect(img, MOUTH_CLENCHED, c + Vector2(-0.14, -0.025), c + Vector2(0.14, 0.025), SCLERA)
	for i: int in 5:
		var x: float = -0.1 + i * 0.05
		_line(img, MOUTH_CLENCHED, c + Vector2(x, -0.03), c + Vector2(x, 0.03), 0.012, INK)


## Œil ouvert : sclère, iris, pupille, paupière supérieure. `open` étire la
## hauteur, `look_y` baisse le regard, `pupil` règle la dilatation.
static func _open_eye(img: Image, cell: int, x: float, open: float, look_y: float, pupil: float = 1.0) -> void:
	var center: Vector2 = Vector2(x, EYE_Y)
	_ellipse(img, cell, center, Vector2(EYE_RX, EYE_RY * open), SCLERA)
	_disc(img, cell, center + Vector2(0, look_y), IRIS_R, IRIS)
	_disc(img, cell, center + Vector2(0, look_y), PUPIL_R * pupil, PUPIL)
	_arc(img, cell, center, EYE_RX * 1.02, EYE_RY * open * 1.02, 180.0, 360.0, LID, INK)


## Paupière basse : efface le haut de l'œil jusqu'à `dy` et trace le bord.
static func _lid_cut(img: Image, cell: int, x: float, dy: float) -> void:
	_fill_rect(img, cell, Vector2(x - EYE_RX * 1.2, EYE_Y - EYE_RY * 1.6), Vector2(x + EYE_RX * 1.2, EYE_Y + dy), CLEAR)
	_line(img, cell, Vector2(x - EYE_RX, EYE_Y + dy), Vector2(x + EYE_RX, EYE_Y + dy), LID, INK)


static func _closed_eye(img: Image, cell: int, x: float) -> void:
	_arc(img, cell, Vector2(x, EYE_Y - 0.01), EYE_RX, EYE_RY * 0.5, 0.0, 180.0, LID, INK)


## Paire de sourcils : `inner_dy` / `outer_dy` décalent les extrémités (y vers le bas).
static func _brow(img: Image, cell: int, inner_dy: float, outer_dy: float) -> void:
	_line(img, cell, Vector2(0.15, BROW_Y + outer_dy), Vector2(0.41, BROW_Y + inner_dy), BROW, INK)
	_line(img, cell, Vector2(0.59, BROW_Y + inner_dy), Vector2(0.85, BROW_Y + outer_dy), BROW, INK)


# --- Primitives (coordonnées visuelles d'une cellule) ------------------------

static func _row(cell: int) -> int:
	return cell >> 2


static func _pixel_to_visual(px: int, py: int) -> Vector2:
	return Vector2((px + 0.5) / CELL, (py + 0.5) / CELL / ASPECT)


static func _visual_to_pixel(cell: int, p: Vector2) -> Vector2i:
	var origin: Vector2i = Vector2i((cell % 4) * CELL, _row(cell) * CELL)
	return origin + Vector2i(int(p.x * CELL), int(p.y * ASPECT * CELL))


static func _plot(img: Image, cell: int, px: int, py: int, ch: Color) -> void:
	if px < 0 or py < 0 or px >= CELL or py >= CELL:
		return
	var x: int = (cell % 4) * CELL + px
	var y: int = _row(cell) * CELL + py
	var old: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, Color(maxf(old.r, ch.r), maxf(old.g, ch.g), maxf(old.b, ch.b), 1.0))


## Parcourt les pixels d'une boîte visuelle et appelle `inside(p)`.
static func _raster(img: Image, cell: int, lo: Vector2, hi: Vector2, ch: Color, inside: Callable) -> void:
	var a: Vector2i = _visual_to_pixel(0, lo) - Vector2i(1, 1)
	var b: Vector2i = _visual_to_pixel(0, hi) + Vector2i(2, 2)
	for py: int in range(maxi(a.y, 0), mini(b.y, CELL)):
		for px: int in range(maxi(a.x, 0), mini(b.x, CELL)):
			if inside.call(_pixel_to_visual(px, py)):
				_plot(img, cell, px, py, ch)


static func _disc(img: Image, cell: int, c: Vector2, r: float, ch: Color) -> void:
	_ellipse(img, cell, c, Vector2(r, r), ch)


static func _ellipse(img: Image, cell: int, c: Vector2, r: Vector2, ch: Color) -> void:
	_raster(img, cell, c - r, c + r, ch, func(p: Vector2) -> bool:
		var d: Vector2 = (p - c) / r
		return d.length_squared() <= 1.0)


static func _line(img: Image, cell: int, a: Vector2, b: Vector2, thickness: float, ch: Color) -> void:
	var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * thickness
	var hi: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * thickness
	_raster(img, cell, lo, hi, ch, func(p: Vector2) -> bool:
		return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= thickness * 0.5)


## Arc d'ellipse (degrés, 0° = +x, sens horaire écran car y descend).
static func _arc(img: Image, cell: int, c: Vector2, rx: float, ry: float, from_deg: float, to_deg: float,
		thickness: float, ch: Color) -> void:
	var steps: int = 16
	var prev: Vector2 = c + Vector2(cos(deg_to_rad(from_deg)) * rx, sin(deg_to_rad(from_deg)) * ry)
	for i: int in range(1, steps + 1):
		var t: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		var p: Vector2 = c + Vector2(cos(t) * rx, sin(t) * ry)
		_line(img, cell, prev, p, thickness, ch)
		prev = p


static func _rect_outline(img: Image, cell: int, lo: Vector2, hi: Vector2, thickness: float) -> void:
	_line(img, cell, lo, Vector2(hi.x, lo.y), thickness, INK)
	_line(img, cell, Vector2(hi.x, lo.y), hi, thickness, INK)
	_line(img, cell, hi, Vector2(lo.x, hi.y), thickness, INK)
	_line(img, cell, Vector2(lo.x, hi.y), lo, thickness, INK)


## Efface une zone (paupière qui couvre le haut de l'iris).
static func _fill_rect(img: Image, cell: int, lo: Vector2, hi: Vector2, value: Color) -> void:
	var a: Vector2i = _visual_to_pixel(0, lo)
	var b: Vector2i = _visual_to_pixel(0, hi)
	for py: int in range(maxi(a.y, 0), mini(b.y, CELL)):
		for px: int in range(maxi(a.x, 0), mini(b.x, CELL)):
			img.set_pixel((cell % 4) * CELL + px, _row(cell) * CELL + py, value)
