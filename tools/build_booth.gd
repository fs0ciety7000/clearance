## Générateur du décor **définitif** du guichet (M9) — remplace `build_booth_greybox.gd`.
##
## Produit :
## - `assets/textures/booth/tex_booth_albedo_rough.png` / `tex_booth_normal_metal.png`
##   (Texture2DArray de 5 couches AmbientCG CC0, 512 px) — seulement avec `-- --textures` ;
## - `assets/models/booth/booth_*.res` : décor **fusionné** en 5 maillages
##   (statique proche, statique lointain, émissifs, hologrammes additifs, pluie) ;
## - `scenes/booth/booth.tscn` : nœuds du contrat (ARCHITECTURE §8 bis.1),
##   lumières, environnement, vitre, file, qualité.
##
## Usage (racine du projet, après `bash tools/fetch_assets.sh`) :
##   godot --headless --script res://tools/build_booth.gd -- --textures   # textures (puis --import)
##   godot --headless --import
##   godot --headless --script res://tools/build_booth.gd                 # maillages + scène
##
## **Déterministe** (deux exécutions = fichiers identiques) : aucune source
## aléatoire (hachages de positions), UID des `.res` conservés, et la scène est
## normalisée après sauvegarde : `unique_id` des nœuds = hachage du chemin du
## nœud (Godot 4.7 les tire au hasard), identifiants `ext_resource` /
## `sub_resource` renumérotés dans l'ordre d'écriture.
## Budget (BOOTH_SCENE §13) : décor = 7 draw calls (5 maillages + vitre + file).
extends SceneTree

const OUT_SCENE: String = "res://scenes/booth/booth.tscn"
const MODEL_DIR: String = "res://assets/models/booth"
const TEX_DIR: String = "res://assets/textures/booth"
const ALBEDO_ARRAY: String = "res://assets/textures/booth/tex_booth_albedo_rough.png"
const NORMAL_ARRAY: String = "res://assets/textures/booth/tex_booth_normal_metal.png"
const ACG_DIR: String = "res://art_src/downloads/ambientcg"
const CITY_DIR: String = "res://art_src/downloads/city-kit-commercial/Models/GLB format"
const CITY_COLORMAP: String = "res://art_src/downloads/city-kit-commercial/Models/GLB format/Textures/colormap.png"

const DIRECTOR: String = "res://scripts/booth/booth_director.gd"
const QUEUE: String = "res://scripts/booth/queue_impostors.gd"
const QUALITY: String = "res://scripts/booth/booth_quality.gd"
const DECOR_SHADER: String = "res://assets/shaders/booth_decor.gdshader"
const EMISSIVE_SHADER: String = "res://assets/shaders/booth_emissive.gdshader"
const HOLO_SHADER: String = "res://assets/shaders/booth_holo.gdshader"
const GLASS_SHADER: String = "res://assets/shaders/booth_glass.gdshader"
const RAIN_SHADER: String = "res://assets/shaders/rain_sheet.gdshader"
const IMPOSTOR_SHADER: String = "res://assets/shaders/impostor_silhouette.gdshader"
const FONT_DISPLAY: String = "res://assets/fonts/ChakraPetch-Bold.ttf"
## JetBrains Mono (variable) a des contours qui se croisent : TextMesh échoue sur
## certains glyphes (Q, 3, ›) → Chakra Petch SemiBold pour les écrans du décor.
const FONT_BOARD: String = "res://assets/fonts/ChakraPetch-SemiBold.ttf"

## Couches des Texture2DArray (ordre = indice de couche, ASSETS §10).
const LAYER_SOURCES: Array[String] = ["Metal050C", "MetalPlates001", "Concrete044B", "PaintedMetal016", "SheetMetal001"]
const LAYER_SIZE: int = 512
const L_CHROME: float = 0.0
const L_PLATES: float = 1.0
const L_CONCRETE: float = 2.0
const L_HAZARD: float = 3.0
const L_PERF: float = 4.0
const L_FLAT: float = 7.0
## Calque de rendu du guichet (cadre, hygiaphone) : lampe intérieure seulement.
const DECOR_LAYER: int = 2

# Palette (DS + palette monde, BOOTH_SCENE §5.1, D-051).
const BG_VOID: Color = Color("#07080C")
const BG_PANEL: Color = Color("#0E1118")
const BG_ELEVATED: Color = Color("#161B26")
const YELLOW: Color = Color("#FFE600")
const CYAN: Color = Color("#00E5FF")
const MAGENTA: Color = Color("#FF2E88")
const TEAL_DIM: Color = Color("#2B6E78")
const ROSE_DIM: Color = Color("#7E3A5C")
const STEEL: Color = Color("#3A4556")
const RAIN: Color = Color("#4E5868")
const KEY: Color = Color("#E8F1F5")
const SPILL: Color = Color("#C9B85A")
## Fenêtres de la ville de l'Anneau : sodium, blanc froid, teal et rose monde.
const WINDOW_TINTS: Array[Color] = [Color("#D9B877"), Color("#B9C6D3"), Color("#5E9AA3"), Color("#A0667F")]

var booth: Node3D = null
var near_geo: Geo = Geo.new(Geo.LIT)
var far_geo: Geo = Geo.new(Geo.LIT)
var emissive_geo: Geo = Geo.new(Geo.EMISSIVE)
var holo_geo: Geo = Geo.new(Geo.HOLO)
var rain_geo: Geo = Geo.new(Geo.RAIN)
var _font_display: Font = null
var _font_board: Font = null
var _failures: int = 0
var _windows: int = 0


## Accumulateur de triangles d'un maillage fusionné (un seul matériau).
## LIT : UV = tuilage (m), UV2 = (couche, mouillé), COLOR = (teinte, métal).
## EMISSIVE / HOLO : UV = repère local, UV2 = (énergie, mode), COLOR = (teinte, graine / opacité).
## RAIN : UV = repère du quad, UV2 = (vitesse, graine), COLOR = (rang, -, colonnes, intensité).
class Geo:
	extends RefCounted
	const LIT: int = 0
	const EMISSIVE: int = 1
	const HOLO: int = 2
	const RAIN: int = 3
	var kind: int = LIT
	var st: SurfaceTool = SurfaceTool.new()
	var triangles: int = 0

	func _init(p_kind: int) -> void:
		kind = p_kind
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Triangle (sommets dans n'importe quel ordre : remis en sens horaire vu
	## depuis `n`, convention des faces avant de Godot).
	func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2,
			uv2: Vector2, color: Color) -> void:
		if (b - a).cross(c - a).dot(n) > 0.0:
			_vertex(a, n, ua, uv2, color)
			_vertex(c, n, uc, uv2, color)
			_vertex(b, n, ub, uv2, color)
		else:
			_vertex(a, n, ua, uv2, color)
			_vertex(b, n, ub, uv2, color)
			_vertex(c, n, uc, uv2, color)
		triangles += 1

	func quad(p: Array[Vector3], n: Vector3, uv: Array[Vector2], uv2: Vector2, color: Color) -> void:
		tri(p[0], p[1], p[2], n, uv[0], uv[1], uv[2], uv2, color)
		tri(p[0], p[2], p[3], n, uv[0], uv[2], uv[3], uv2, color)

	func _vertex(p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, color: Color) -> void:
		st.set_normal(n)
		st.set_uv(uv)
		st.set_uv2(uv2)
		st.set_color(color)
		st.add_vertex(p)

	func commit() -> ArrayMesh:
		st.index()
		if kind == LIT:
			st.generate_tangents()
		return st.commit(null, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)


## Matériau d'une pièce éclairée : couche, teinte, métal, tuilage (m), mouillé.
class Mat:
	extends RefCounted
	var layer: float = 7.0
	var tint: Color = Color.WHITE
	var metal: float = 0.0
	var tile: float = 1.0
	var wet: float = 0.0

	func _init(p_layer: float, p_tint: Color, p_metal: float = 0.0, p_tile: float = 1.0, p_wet: float = 0.0) -> void:
		layer = p_layer
		tint = p_tint
		metal = p_metal
		tile = p_tile
		wet = p_wet

	func color() -> Color:
		return Color(tint.r, tint.g, tint.b, metal)

	func uv2() -> Vector2:
		return Vector2(layer, wet)


func _initialize() -> void:
	await process_frame # autoloads (EventBus…) enregistrés avant de charger les scripts
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--textures"):
		_build_textures()
		print("build_booth: textures %s" % ("OK" if _failures == 0 else "ÉCHEC"))
		quit(0 if _failures == 0 else 1)
		return
	if not ResourceLoader.exists(ALBEDO_ARRAY) or not ResourceLoader.exists(NORMAL_ARRAY):
		push_error("build_booth: textures absentes — lancer d'abord `-- --textures` puis `godot --headless --import`")
		quit(1)
		return
	_font_display = load(FONT_DISPLAY) as Font
	_font_board = load(FONT_BOARD) as Font
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODEL_DIR))
	_build_booth_front()
	_build_pillar()
	_build_door()
	_build_queue()
	_build_hall()
	_build_signage()
	_build_city()
	_build_rain()
	var meshes: Dictionary[String, ArrayMesh] = {
		"near": _save_mesh(near_geo, "booth_static_near"),
		"far": _save_mesh(far_geo, "booth_static_far"),
		"emissive": _save_mesh(emissive_geo, "booth_emissive"),
		"holo": _save_mesh(holo_geo, "booth_holo"),
		"rain": _save_mesh(rain_geo, "booth_rain"),
	}
	print("build_booth: triangles proche %d, lointain %d, émissifs %d (dont %d fenêtres), holo %d, pluie %d" % [
			near_geo.triangles, far_geo.triangles, emissive_geo.triangles, _windows, holo_geo.triangles, rain_geo.triangles])
	_build_scene(meshes)
	print("build_booth: %s" % ("OK" if _failures == 0 else "ÉCHEC (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# --- Textures (couches PBR AmbientCG) ------------------------------------------

func _build_textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX_DIR))
	var count: int = LAYER_SOURCES.size()
	var albedo: PackedByteArray = PackedByteArray()
	var normal: PackedByteArray = PackedByteArray()
	for id: String in LAYER_SOURCES:
		var base: String = ACG_DIR.path_join(id).path_join(id + "_1K-JPG_")
		var color: Image = _load_layer(base + "Color.jpg", Image.FORMAT_RGB8, Color(0.5, 0.5, 0.5))
		var rough: Image = _load_layer(base + "Roughness.jpg", Image.FORMAT_L8, Color(0.6, 0.6, 0.6))
		var nrm: Image = _load_layer(base + "NormalGL.jpg", Image.FORMAT_RGB8, Color(0.5, 0.5, 1.0))
		var metal: Image = _load_layer(base + "Metalness.jpg", Image.FORMAT_L8, Color.BLACK)
		var ao: Image = _load_layer(base + "AmbientOcclusion.jpg", Image.FORMAT_L8, Color.WHITE)
		var opacity: Image = _load_layer(base + "Opacity.jpg", Image.FORMAT_L8, Color.WHITE)
		if color == null:
			return
		var c: PackedByteArray = color.get_data()
		var r: PackedByteArray = rough.get_data()
		var n: PackedByteArray = nrm.get_data()
		var m: PackedByteArray = metal.get_data()
		var o: PackedByteArray = ao.get_data()
		var op: PackedByteArray = opacity.get_data()
		var pixels: int = LAYER_SIZE * LAYER_SIZE
		var layer_albedo: PackedByteArray = PackedByteArray()
		layer_albedo.resize(pixels * 4)
		var layer_normal: PackedByteArray = PackedByteArray()
		layer_normal.resize(pixels * 4)
		for i: int in pixels:
			# Tôle perforée : trous = noir mat, normale plate, sans métal.
			var hole: float = op[i] / 255.0
			layer_albedo[i * 4] = int(c[i * 3] * hole)
			layer_albedo[i * 4 + 1] = int(c[i * 3 + 1] * hole)
			layer_albedo[i * 4 + 2] = int(c[i * 3 + 2] * hole)
			layer_albedo[i * 4 + 3] = int(lerpf(255.0, r[i], hole))
			layer_normal[i * 4] = int(lerpf(128.0, n[i * 3], hole))
			layer_normal[i * 4 + 1] = int(lerpf(128.0, n[i * 3 + 1], hole))
			layer_normal[i * 4 + 2] = int(m[i] * hole)
			layer_normal[i * 4 + 3] = o[i]
		albedo.append_array(layer_albedo)
		normal.append_array(layer_normal)
	_save_array_png(Image.create_from_data(LAYER_SIZE, LAYER_SIZE * count, false, Image.FORMAT_RGBA8, albedo), ALBEDO_ARRAY, count)
	_save_array_png(Image.create_from_data(LAYER_SIZE, LAYER_SIZE * count, false, Image.FORMAT_RGBA8, normal), NORMAL_ARRAY, count)


func _load_layer(path: String, format: Image.Format, fallback: Color) -> Image:
	var image: Image = Image.new()
	if not FileAccess.file_exists(path):
		if path.ends_with("Color.jpg"):
			push_error("build_booth: %s introuvable — lancer `bash tools/fetch_assets.sh`" % path)
			_failures += 1
			return null
		image = Image.create(LAYER_SIZE, LAYER_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(fallback)
	elif image.load(path) != OK:
		push_error("build_booth: lecture impossible de %s" % path)
		_failures += 1
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != LAYER_SIZE:
		image.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_LANCZOS)
	image.convert(format)
	return image


## PNG empilé verticalement + `.import` de Texture2DArray s'il manque.
func _save_array_png(image: Image, path: String, slices: int) -> void:
	if image.save_png(path) != OK:
		push_error("build_booth: écriture impossible de %s" % path)
		_failures += 1
		return
	var import_path: String = path + ".import"
	if FileAccess.file_exists(import_path):
		print("  écrit %s" % path)
		return
	var f: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"2d_array_texture\"\ntype=\"CompressedTexture2DArray\"\n\n[deps]\n\n"
			+ "source_file=\"%s\"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n" % path
			+ "compress/hdr_compression=1\ncompress/channel_pack=1\nmipmaps/generate=true\nmipmaps/limit=-1\n"
			+ "slices/horizontal=1\nslices/vertical=%d\n" % slices)
	f.close()
	print("  écrit %s (+ .import)" % path)


# --- Primitives -----------------------------------------------------------------

## Pseudo-aléa déterministe [0, 1) d'une position (variété des UV, fenêtres…).
static func hash3(p: Vector3) -> float:
	var h: float = sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453
	return h - floorf(h)


## UV monde d'un point selon la normale dominante (tuilage continu entre pièces).
static func world_uv(p: Vector3, n: Vector3, tile: float, offset: Vector2) -> Vector2:
	var a: Vector3 = n.abs()
	var uv: Vector2
	if a.y >= a.x and a.y >= a.z:
		uv = Vector2(p.x, p.z)
	elif a.x >= a.z:
		uv = Vector2(p.z * signf(n.x), -p.y)
	else:
		uv = Vector2(-p.x * signf(n.z), -p.y)
	return uv / tile + offset


## Pavé centré sur `xf.origin`.
func box(geo: Geo, size: Vector3, xf: Transform3D, mat: Mat) -> void:
	var h: Vector3 = size * 0.5
	var offset: Vector2 = Vector2(hash3(xf.origin), hash3(xf.origin + Vector3.ONE)) * 4.0
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3.DOWN, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	]
	for face: Array in faces:
		var nl: Vector3 = face[0]
		var n: Vector3 = (xf.basis * nl).normalized()
		var pts: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for k: int in 4:
			var pl: Vector3 = face[k + 1]
			var p: Vector3 = xf * pl
			pts.append(p)
			uvs.append(world_uv(p, n, mat.tile, offset))
		geo.quad(pts, n, uvs, mat.uv2(), mat.color())


func box_at(geo: Geo, size: Vector3, pos: Vector3, mat: Mat, rot_deg: Vector3 = Vector3.ZERO) -> void:
	box(geo, size, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos), mat)


## Cylindre d'axe Y local (`xf.origin` = centre), capuchons optionnels.
func cylinder(geo: Geo, radius: float, height: float, segments: int, xf: Transform3D, mat: Mat, caps: bool = true) -> void:
	var c: Color = mat.color()
	var uv2: Vector2 = mat.uv2()
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		var d0: Vector3 = Vector3(sin(a0), 0, cos(a0))
		var d1: Vector3 = Vector3(sin(a1), 0, cos(a1))
		var p: Array[Vector3] = [xf * (d0 * radius + Vector3.DOWN * height * 0.5), xf * (d1 * radius + Vector3.DOWN * height * 0.5),
				xf * (d1 * radius + Vector3.UP * height * 0.5), xf * (d0 * radius + Vector3.UP * height * 0.5)]
		var n: Vector3 = (xf.basis * (d0 + d1).normalized()).normalized()
		var u0: float = a0 * radius / mat.tile
		var u1: float = a1 * radius / mat.tile
		var v: float = height / mat.tile
		var uv: Array[Vector2] = [Vector2(u0, v), Vector2(u1, v), Vector2(u1, 0), Vector2(u0, 0)]
		geo.quad(p, n, uv, uv2, c)
		if caps:
			for s: float in [1.0, -1.0]:
				var center: Vector3 = xf * (Vector3.UP * height * 0.5 * s)
				var nc: Vector3 = (xf.basis * (Vector3.UP * s)).normalized()
				var e0: Vector3 = xf * (d0 * radius + Vector3.UP * height * 0.5 * s)
				var e1: Vector3 = xf * (d1 * radius + Vector3.UP * height * 0.5 * s)
				geo.tri(center, e0, e1, nc, Vector2(0.5, 0.5) * radius / mat.tile,
						Vector2(d0.x, d0.z) * radius / mat.tile, Vector2(d1.x, d1.z) * radius / mat.tile, uv2, c)


## Anneau plat (disque troué si `inner` > 0) face à +Z local, épaisseur `depth` vers −Z.
func ring(geo: Geo, inner: float, outer: float, depth: float, segments: int, xf: Transform3D, mat: Mat) -> void:
	var c: Color = mat.color()
	var uv2: Vector2 = mat.uv2()
	var n: Vector3 = (xf.basis * Vector3.BACK).normalized()
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		var d0: Vector3 = Vector3(cos(a0), sin(a0), 0)
		var d1: Vector3 = Vector3(cos(a1), sin(a1), 0)
		var p: Array[Vector3] = [xf * (d0 * inner), xf * (d1 * inner), xf * (d1 * outer), xf * (d0 * outer)]
		var uv: Array[Vector2] = [Vector2(d0.x, -d0.y) * inner / mat.tile, Vector2(d1.x, -d1.y) * inner / mat.tile,
				Vector2(d1.x, -d1.y) * outer / mat.tile, Vector2(d0.x, -d0.y) * outer / mat.tile]
		if inner <= 0.0:
			geo.tri(p[0], p[2], p[3], n, uv[0], uv[2], uv[3], uv2, c)
		else:
			geo.quad(p, n, uv, uv2, c)
		if depth > 0.0:
			var back: Vector3 = Vector3(0, 0, -depth)
			var ns: Vector3 = (xf.basis * (d0 + d1).normalized()).normalized()
			var side: Array[Vector3] = [xf * (d0 * outer), xf * (d1 * outer), xf * (d1 * outer + back), xf * (d0 * outer + back)]
			var su: Array[Vector2] = [Vector2(a0 * outer, 0), Vector2(a1 * outer, 0), Vector2(a1 * outer, depth), Vector2(a0 * outer, depth)]
			geo.quad(side, ns, su, uv2, c)


## Quad émissif / holo / pluie : `xf` place un rectangle `size` face à +Z local, UV 0..1.
func panel(geo: Geo, size: Vector2, xf: Transform3D, uv2: Vector2, color: Color) -> void:
	var h: Vector2 = size * 0.5
	var p: Array[Vector3] = [xf * Vector3(-h.x, h.y, 0), xf * Vector3(h.x, h.y, 0), xf * Vector3(h.x, -h.y, 0), xf * Vector3(-h.x, -h.y, 0)]
	var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	geo.quad(p, (xf.basis * Vector3.BACK).normalized(), uv, uv2, color)


func panel_at(geo: Geo, size: Vector2, pos: Vector3, uv2: Vector2, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	panel(geo, size, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos), uv2, color)


## Texte cuit en triangles (TextMesh), plan XY face à +Z local, centré sur `xf.origin`.
func text(geo: Geo, value: String, font: Font, height: float, xf: Transform3D, uv2: Vector2, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, line_spacing: float = 0.0) -> void:
	var tm: TextMesh = TextMesh.new()
	tm.font = font
	tm.font_size = 64
	tm.pixel_size = height / 64.0
	tm.depth = 0.0
	tm.curve_step = 1.0
	tm.text = value
	tm.horizontal_alignment = align
	tm.line_spacing = line_spacing
	var arrays: Array = tm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n: Vector3 = (xf.basis * Vector3.BACK).normalized()
	var count: int = indices.size() if indices.size() > 0 else verts.size()
	for i: int in range(0, count, 3):
		var ia: int = indices[i] if indices.size() > 0 else i
		var ib: int = indices[i + 1] if indices.size() > 0 else i + 1
		var ic: int = indices[i + 2] if indices.size() > 0 else i + 2
		geo.tri(xf * verts[ia], xf * verts[ib], xf * verts[ic], n, uvs[ia], uvs[ib], uvs[ic], uv2, color)


func text_at(geo: Geo, value: String, font: Font, height: float, pos: Vector3, uv2: Vector2, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, line_spacing: float = 0.0) -> void:
	text(geo, value, font, height, Transform3D(Basis.IDENTITY, pos), uv2, color, align, line_spacing)


## UV2 émissif (énergie, mode) ; graine dans l'alpha de la couleur.
static func glow(energy: float, mode: int = 0) -> Vector2:
	return Vector2(energy, mode)


static func seeded(color: Color, seed_value: int) -> Color:
	return Color(color.r, color.g, color.b, (seed_value % 255) / 255.0)


# --- Contenu : guichet (côté agent → passager) ------------------------------------

func _build_booth_front() -> void:
	var plates: Mat = Mat.new(L_PLATES, Color(0.62, 0.64, 0.68), 0.9, 0.9)
	var chrome: Mat = Mat.new(L_CHROME, Color(0.92, 0.94, 0.97), 1.0, 0.6)
	var dark: Mat = Mat.new(L_PLATES, Color(0.22, 0.24, 0.27), 0.7, 0.9)
	var rivet: Mat = Mat.new(L_CHROME, Color(0.75, 0.77, 0.8), 1.0, 0.2)
	# Montants blindés (bords de la bande) + liserés chromés côté vitre.
	for side: float in [-1.0, 1.0]:
		box_at(near_geo, Vector3(0.18, 1.62, 0.22), Vector3(1.29 * side, 1.7, 0.0), plates)
		box_at(near_geo, Vector3(0.035, 1.5, 0.24), Vector3(1.19 * side, 1.7, 0.0), chrome)
		box_at(near_geo, Vector3(0.012, 1.5, 0.05), Vector3(1.165 * side, 1.7, -0.02), dark)
		for j: int in 15:
			for col: float in [-0.05, 0.05]:
				var at: Vector3 = Vector3(1.29 * side + col, 1.0 + j * 0.1, 0.112)
				cylinder(near_geo, 0.009, 0.008, 6, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), at), rivet)
	box_at(near_geo, Vector3(2.76, 0.16, 0.22), Vector3(0, 2.46, 0), plates)
	box_at(near_geo, Vector3(2.76, 0.12, 0.26), Vector3(0, 0.96, 0), plates)
	box_at(near_geo, Vector3(2.4, 0.03, 0.24), Vector3(0, 2.37, 0), chrome)
	box_at(near_geo, Vector3(2.4, 0.03, 0.24), Vector3(0, 1.03, 0), chrome)
	# Fente à documents (hors champ) et comptoir de l'agent.
	box_at(near_geo, Vector3(0.44, 0.05, 0.32), Vector3(0, 1.02, 0), Mat.new(L_CHROME, Color(0.35, 0.37, 0.4), 1.0, 0.4))
	box_at(near_geo, Vector3(2.8, 0.06, 0.9), Vector3(0, 0.93, 0.55), Mat.new(L_PLATES, Color(0.3, 0.32, 0.36), 0.6, 1.2))
	# Hygiaphone : lunette chromée, grille perforée, 4 vis, LED (cyan = information).
	var hyg: Vector3 = Vector3(-0.4, 1.38, 0.0)
	ring(near_geo, 0.0, 0.088, 0.0, 40, Transform3D(Basis.IDENTITY, hyg + Vector3(0, 0, 0.012)),
			Mat.new(L_PERF, Color(1.0, 1.0, 1.0), 0.0, 0.09))
	ring(near_geo, 0.086, 0.112, 0.02, 40, Transform3D(Basis.IDENTITY, hyg + Vector3(0, 0, 0.026)), chrome)
	ring(near_geo, 0.112, 0.124, 0.012, 40, Transform3D(Basis.IDENTITY, hyg + Vector3(0, 0, 0.016)), dark)
	for k: int in 4:
		var a: float = PI * 0.25 + k * PI * 0.5
		cylinder(near_geo, 0.006, 0.006, 6, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)),
				hyg + Vector3(cos(a) * 0.099, sin(a) * 0.099, 0.029)), rivet)
	var led: Geo = emissive_geo
	for i: int in 40:
		var a0: float = TAU * i / 40.0
		var a1: float = TAU * (i + 1) / 40.0
		var p: Array[Vector3] = [hyg + Vector3(cos(a0) * 0.113, sin(a0) * 0.113, 0.0235), hyg + Vector3(cos(a1) * 0.113, sin(a1) * 0.113, 0.0235),
				hyg + Vector3(cos(a1) * 0.119, sin(a1) * 0.119, 0.0235), hyg + Vector3(cos(a0) * 0.119, sin(a0) * 0.119, 0.0235)]
		var uv: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		led.quad(p, Vector3.BACK, uv, glow(0.9), seeded(CYAN, 1))


func _build_pillar() -> void:
	var base: Vector3 = Vector3(-1.1, 0, -2.6)
	var concrete: Mat = Mat.new(L_CONCRETE, Color(0.42, 0.44, 0.48), 0.0, 1.6, 1.0)
	var plates: Mat = Mat.new(L_PLATES, Color(0.5, 0.52, 0.56), 0.9, 0.8, 0.6)
	var chrome: Mat = Mat.new(L_CHROME, Color(0.85, 0.87, 0.9), 1.0, 0.5, 0.5)
	box_at(near_geo, Vector3(0.5, 3.3, 0.5), base + Vector3(0, 1.65, 0), concrete)
	box_at(near_geo, Vector3(0.54, 0.9, 0.54), base + Vector3(0, 0.45, 0), plates)
	box_at(near_geo, Vector3(0.56, 0.05, 0.56), base + Vector3(0, 0.92, 0), chrome)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		box_at(near_geo, Vector3(0.04, 3.3, 0.04), base + Vector3(c.x * 0.255, 1.65, c.y * 0.255), chrome)
	# Enseigne verticale HALCYON (marque Consortium : jaune sémantique).
	box_at(near_geo, Vector3(0.32, 1.32, 0.04), base + Vector3(0, 1.58, 0.27), Mat.new(L_PLATES, Color(0.12, 0.12, 0.13), 0.5, 0.8))
	var face: float = base.z + 0.292
	for side: float in [-1.0, 1.0]:
		panel_at(emissive_geo, Vector2(0.012, 1.26), Vector3(base.x + 0.15 * side, 1.58, face), glow(2.2), seeded(YELLOW, 2))
	var letters: String = "HALCYON"
	for i: int in letters.length():
		text_at(emissive_geo, letters[i], _font_display, 0.2, Vector3(base.x, 2.12 - i * 0.18, face),
				glow(2.6), seeded(YELLOW, 3))
	# Affiche usée sur la face droite (aplat) + bande de danger au pied.
	box_at(near_geo, Vector3(0.012, 0.44, 0.32), base + Vector3(0.258, 1.36, 0.02), Mat.new(L_FLAT, Color(0.16, 0.17, 0.2), 0.0))
	text(near_geo, "GLOIRE\nAU\nCONSORTIUM", _font_display, 0.045,
			Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)), base + Vector3(0.265, 1.42, 0.02)),
			Vector2(L_FLAT, 0), Color(0.45, 0.42, 0.25, 0.0))
	box_at(near_geo, Vector3(0.545, 0.12, 0.545), base + Vector3(0, 0.06, 0), Mat.new(L_HAZARD, Color(0.55, 0.52, 0.45), 0.3, 0.5))


func _build_door() -> void:
	var door: Vector3 = Vector3(2.3, 0, -0.4)
	var hazard: Mat = Mat.new(L_HAZARD, Color(0.6, 0.58, 0.5), 0.3, 0.6)
	var plates: Mat = Mat.new(L_PLATES, Color(0.4, 0.42, 0.46), 0.9, 0.9)
	box_at(near_geo, Vector3(0.14, 2.4, 0.24), door + Vector3(-0.56, 1.2, 0), hazard)
	box_at(near_geo, Vector3(0.14, 2.4, 0.24), door + Vector3(0.56, 1.2, 0), hazard)
	box_at(near_geo, Vector3(1.26, 0.16, 0.24), door + Vector3(0, 2.44, 0), plates)
	box_at(near_geo, Vector3(0.9, 0.9, 0.08), door + Vector3(0, 0.6, 0), plates)
	panel_at(emissive_geo, Vector2(0.9, 0.03), door + Vector3(0, 2.33, 0.125), glow(1.2), seeded(STEEL.lightened(0.4), 4))


## Barrières magnétiques de la file (LORE §3) : poteaux chromés + champ teal.
func _build_queue() -> void:
	var post: Mat = Mat.new(L_CHROME, Color(0.8, 0.82, 0.86), 1.0, 0.3)
	var foot: Mat = Mat.new(L_PLATES, Color(0.3, 0.32, 0.35), 0.8, 0.5)
	var rows: Array[float] = [-3.9, -5.2, -6.6]
	for z: float in rows:
		for x: float in [-1.0, -2.6]:
			cylinder(far_geo, 0.035, 0.98, 10, Transform3D(Basis.IDENTITY, Vector3(x, 0.49, z)), post)
			cylinder(far_geo, 0.15, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(x, 0.015, z)), foot)
			cylinder(far_geo, 0.05, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(x, 0.99, z)), foot)
			panel_at(emissive_geo, Vector2(0.03, 0.05), Vector3(x, 0.95, z + 0.051), glow(1.4), seeded(TEAL_DIM.lightened(0.2), 5))
		panel_at(emissive_geo, Vector2(1.5, 0.012), Vector3(-1.8, 0.93, z), glow(1.5), seeded(TEAL_DIM.lightened(0.15), 6))
		panel_at(holo_geo, Vector2(1.5, 0.22), Vector3(-1.8, 0.93, z), glow(1.0, 2), Color(TEAL_DIM.r, TEAL_DIM.g, TEAL_DIM.b, 0.35))


# --- Hall (fond) ---------------------------------------------------------------

func _build_hall() -> void:
	var concrete: Mat = Mat.new(L_CONCRETE, Color(0.36, 0.38, 0.42), 0.0, 2.0, 0.8)
	var plates: Mat = Mat.new(L_PLATES, Color(0.42, 0.44, 0.48), 0.9, 1.0, 0.5)
	var chrome: Mat = Mat.new(L_CHROME, Color(0.7, 0.72, 0.76), 1.0, 0.8, 0.4)
	# Sol béton mouillé (hors cadre au FOV 14°, gardé pour les autres cadrages).
	var floor_mat: Mat = Mat.new(L_CONCRETE, Color(0.2, 0.21, 0.24), 0.0, 2.5, 0.0)
	var fp: Array[Vector3] = [Vector3(-9, 0, -10), Vector3(9, 0, -10), Vector3(9, 0, 1), Vector3(-9, 0, 1)]
	var fu: Array[Vector2] = []
	for p: Vector3 in fp:
		fu.append(world_uv(p, Vector3.UP, floor_mat.tile, Vector2.ZERO))
	far_geo.quad(fp, Vector3.UP, fu, floor_mat.uv2(), floor_mat.color())
	# Mur du fond : soubassement béton + grande baie sur la ville de l'Anneau.
	var wall_z: float = -10.0
	box_at(far_geo, Vector3(20, 1.0, 0.3), Vector3(0, 0.5, wall_z), concrete)
	box_at(far_geo, Vector3(20, 0.12, 0.45), Vector3(0, 1.04, wall_z + 0.05), chrome)
	box_at(far_geo, Vector3(20, 0.9, 0.3), Vector3(0, 4.55, wall_z), concrete)
	box_at(far_geo, Vector3(20, 0.16, 0.4), Vector3(0, 4.05, wall_z + 0.02), plates)
	# Meneaux tous les 3 m, décalés : aucun ne pousse « dans la tête » du passager.
	for i: int in 6:
		var x: float = -7.5 + i * 3.0
		box_at(far_geo, Vector3(0.26, 3.0, 0.34), Vector3(x, 2.55, wall_z), plates)
		box_at(far_geo, Vector3(0.05, 3.0, 0.38), Vector3(x + 0.13, 2.55, wall_z), chrome)
	box_at(far_geo, Vector3(20, 0.08, 0.2), Vector3(0, 3.25, wall_z), plates)
	# Colonnes du hall : béton, collier riveté, bande de danger, conduite de recyclage.
	# Aux bords du cadre : jamais devant les enseignes ni derrière le visage.
	for c: Vector3 in [Vector3(3.6, 0, -4.4), Vector3(-4.1, 0, -4.7), Vector3(5.6, 0, -7.0), Vector3(-6.6, 0, -7.6)]:
		box_at(far_geo, Vector3(0.62, 4.6, 0.62), c + Vector3(0, 2.3, 0), concrete)
		box_at(far_geo, Vector3(0.68, 1.1, 0.68), c + Vector3(0, 0.55, 0), plates)
		box_at(far_geo, Vector3(0.7, 0.05, 0.7), c + Vector3(0, 1.12, 0), chrome)
		box_at(far_geo, Vector3(0.69, 0.14, 0.69), c + Vector3(0, 0.07, 0), Mat.new(L_HAZARD, Color(0.5, 0.48, 0.42), 0.3, 0.5))
		cylinder(far_geo, 0.06, 4.6, 10, Transform3D(Basis.IDENTITY, c + Vector3(0.25, 2.3, 0.37)), chrome, false)
		for y: float in [0.6, 1.6, 2.6]:
			box_at(far_geo, Vector3(0.18, 0.04, 0.1), c + Vector3(0.25, y, 0.33), plates)
	# Signalétique de colonne (écran holo d'information, teal désaturé).
	var col_screen: Vector3 = Vector3(3.6, 1.75, -4.4 + 0.315)
	box_at(far_geo, Vector3(0.5, 0.3, 0.03), col_screen + Vector3(0, 0, -0.01), Mat.new(L_PLATES, Color(0.15, 0.16, 0.18), 0.6, 0.6))
	panel_at(emissive_geo, Vector2(0.44, 0.24), col_screen + Vector3(0, 0, 0.007), glow(0.55, 2), seeded(TEAL_DIM.darkened(0.3), 7))
	text_at(emissive_geo, "ANNEAU B  ›\nPORTE 2", _font_board, 0.05, col_screen + Vector3(0, 0.01, 0.009), glow(1.3),
			seeded(TEAL_DIM.lightened(0.45), 8), HORIZONTAL_ALIGNMENT_CENTER, -4.0)
	# Graffiti des Lucioles (LORE §7 : trois traits et un point, magenta = rébellion),
	# un seul, discret, hors de la fenêtre utile du visage.
	var g: Vector3 = Vector3(1.9, 0.45, wall_z + 0.16)
	for s: Array in [[Vector2(-0.05, 0.06), 35.0], [Vector2(0.0, 0.08), 0.0], [Vector2(0.05, 0.06), -35.0]]:
		var off: Vector2 = s[0]
		var rot: float = s[1]
		panel_at(emissive_geo, Vector2(0.018, 0.11), g + Vector3(off.x, off.y, 0), glow(0.8), seeded(MAGENTA, 9), Vector3(0, 0, rot))
	# (Mat détourné : couche = énergie, métal = graine.)
	ring(emissive_geo, 0.0, 0.025, 0.0, 10, Transform3D(Basis.IDENTITY, g + Vector3(0, -0.03, 0.001)), Mat.new(0.8, MAGENTA, 9.0 / 255.0))


## Enseignes et écrans du fond (portique devant la baie, z ≈ −8,8).
func _build_signage() -> void:
	var backplate: Mat = Mat.new(L_FLAT, Color(0.05, 0.055, 0.065), 0.0)
	var cable: Mat = Mat.new(L_CHROME, Color(0.5, 0.52, 0.55), 1.0, 0.5)
	# Grand néon HALCYON (marque Consortium).
	var hz: float = -8.8
	box_at(far_geo, Vector3(3.6, 1.0, 0.06), Vector3(1.9, 2.32, hz - 0.08), backplate)
	for x: float in [0.4, 3.4]:
		box_at(far_geo, Vector3(0.015, 2.0, 0.015), Vector3(x, 3.8, hz - 0.08), cable)
	text_at(emissive_geo, "HALCYON", _font_display, 0.58, Vector3(1.9, 2.5, hz), glow(2.3), seeded(Color(1.0, 0.9, 0.05), 10))
	text_at(emissive_geo, "GATE · ANNEAU A", _font_display, 0.24, Vector3(1.9, 2.07, hz), glow(1.5), seeded(Color(0.95, 0.85, 0.2), 11))
	panel_at(emissive_geo, Vector2(3.3, 0.018), Vector3(1.9, 1.89, hz), glow(1.6), seeded(Color(0.95, 0.85, 0.2), 12))
	# Écran des départs (décor : teal désaturé, pas une information de jeu).
	var dep: Vector3 = Vector3(-3.4, 2.05, -8.85)
	box_at(far_geo, Vector3(2.5, 1.08, 0.1), dep + Vector3(0, 0, -0.06), backplate)
	box_at(far_geo, Vector3(0.015, 2.0, 0.015), dep + Vector3(-1.0, 1.5, -0.06), cable)
	box_at(far_geo, Vector3(0.015, 2.0, 0.015), dep + Vector3(1.0, 1.5, -0.06), cable)
	panel_at(emissive_geo, Vector2(2.34, 0.92), dep, glow(0.75, 2), seeded(TEAL_DIM.darkened(0.55), 13))
	panel_at(emissive_geo, Vector2(2.34, 0.13), dep + Vector3(0, 0.395, 0.002), glow(0.9), seeded(TEAL_DIM.darkened(0.15), 14))
	text_at(emissive_geo, "DÉPARTS  ·  NAVETTES", _font_board, 0.075, dep + Vector3(0, 0.395, 0.004), glow(1.6),
			seeded(TEAL_DIM.lightened(0.6), 15))
	var departures: Array[PackedStringArray] = [
		PackedStringArray(["TYC-07", "TYCHO", "QUAI 3", "À L'HEURE"]),
		PackedStringArray(["HAL-12", "ANNEAU B", "QUAI 1", "EMBARQUEMENT"]),
		PackedStringArray(["TER-03", "LAGRANGE 4", "QUAI 5", "RETARDÉ"]),
		PackedStringArray(["KAO-21", "KESSLER-ASHE", "QUAI 6", "ANNULÉ"]),
	]
	var columns: PackedFloat32Array = [-1.08, -0.6, 0.12, 0.52]
	for row: int in departures.size():
		for col: int in columns.size():
			text_at(emissive_geo, departures[row][col], _font_board, 0.07,
					dep + Vector3(columns[col], 0.2 - row * 0.155, 0.004), glow(1.25 if col < 3 else 1.05),
					seeded(TEAL_DIM.lightened(0.5 if col < 3 else 0.3), 16 + row), HORIZONTAL_ALIGNMENT_LEFT)
	# TRANSIT·7 (rose monde) et panneau du guichet (acier monde, liserés rose).
	var transit: Vector3 = Vector3(-4.95, 1.25, -8.6)
	box_at(far_geo, Vector3(2.1, 0.5, 0.06), transit + Vector3(0, 0, -0.06), backplate)
	text_at(emissive_geo, "TRANSIT·7", _font_display, 0.34, transit, glow(2.4, 1), seeded(ROSE_DIM.lightened(0.35), 17))
	# À droite du passager, sous le grand néon : visible entre la bulle et le panneau de file.
	var bs: Vector3 = Vector3(2.5, 1.06, -8.75)
	box_at(far_geo, Vector3(1.75, 0.4, 0.06), bs + Vector3(0, 0, -0.06), backplate)
	text_at(emissive_geo, "CONTRÔLE · GUICHET 04", _font_display, 0.12, bs, glow(1.9), seeded(STEEL.lightened(0.55), 18))
	for dy: float in [0.16, -0.16]:
		panel_at(emissive_geo, Vector2(1.6, 0.02), bs + Vector3(0, dy, 0.0), glow(2.0), seeded(ROSE_DIM.lightened(0.2), 19))
	# Hologramme du Consortium : hexagone solaire (« l'Œil »), additif, lent.
	var eye: Vector3 = Vector3(-1.75, 2.45, -8.5)
	var yellow_holo: Color = Color(1.0, 0.86, 0.1, 0.55)
	for k: int in 6:
		var a: float = TAU * k / 6.0 + PI / 6.0
		var mid: Vector3 = eye + Vector3(cos(a + PI / 6.0), sin(a + PI / 6.0), 0) * 0.26
		panel_at(holo_geo, Vector2(0.27, 0.025), mid, glow(1.4, 1), yellow_holo, Vector3(0, 0, rad_to_deg(a + PI / 6.0) + 90.0))
	# (Mat détourné pour les additifs : couche = énergie, mouillé = mode, métal = opacité.)
	ring(holo_geo, 0.07, 0.1, 0.0, 24, Transform3D(Basis.IDENTITY, eye), Mat.new(1.2, Color(1.0, 0.86, 0.1), 0.5, 1.0, 1.0))
	ring(holo_geo, 0.0, 0.035, 0.0, 16, Transform3D(Basis.IDENTITY, eye), Mat.new(1.6, Color(1.0, 0.9, 0.2), 0.6, 1.0, 1.0))
	panel_at(holo_geo, Vector2(0.9, 0.9), eye + Vector3(0, 0, -0.01), glow(0.5, 1), Color(1.0, 0.8, 0.1, 0.08))
	text_at(holo_geo, "GLOIRE AU CONSORTIUM", _font_display, 0.07, eye + Vector3(0, -0.4, 0), glow(1.3, 1), Color(1.0, 0.88, 0.2, 0.6))


## Ville de l'Anneau habitable vue par la baie (Kenney City Kit Commercial, CC0) :
## silhouettes sombres sur un sol qui se relève (courbure de l'anneau),
## fenêtres en émissifs ; halo additif au-dessus.
func _build_city() -> void:
	var colormap: Image = Image.new()
	if colormap.load(CITY_COLORMAP) != OK:
		push_error("build_booth: %s introuvable — lancer `bash tools/fetch_assets.sh`" % CITY_COLORMAP)
		_failures += 1
		return
	colormap.convert(Image.FORMAT_RGB8)
	var towers: Array = ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c",
			"building-skyscraper-d", "building-skyscraper-e"]
	var rows: Array[Array] = [
		# [z, échelle, x min, x max, nombre, modèles] ; la rangée du fond reste en silhouettes.
		[-44.0, 2.6, -28.0, 28.0, 8, towers],
		[-64.0, 3.4, -40.0, 40.0, 8, towers],
		[-86.0, 6.0, -54.0, 54.0, 10, ["low-detail-building-b", "low-detail-building-d", "low-detail-building-i",
				"low-detail-building-l", "low-detail-building-wide-b"]],
	]
	var cache: Dictionary[String, Array] = {}
	for r: int in rows.size():
		var row: Array = rows[r]
		var z: float = row[0]
		var scale: float = row[1]
		var x_min: float = row[2]
		var x_max: float = row[3]
		var count: int = row[4]
		var models: Array = row[5]
		for i: int in count:
			var t: float = (i + 0.5) / count
			var x: float = lerpf(x_min, x_max, t) + (hash3(Vector3(i, r, 1)) - 0.5) * 2.5
			var zz: float = z - hash3(Vector3(i, r, 2)) * 6.0
			var ground: float = -3.0 + x * x / 320.0
			var model_name: String = models[(i * 3 + r) % models.size()]
			if not cache.has(model_name):
				cache[model_name] = _load_glb(CITY_DIR.path_join(model_name + ".glb"))
			var tilt: float = asin(clampf(x / 160.0, -0.4, 0.4))
			var basis: Basis = Basis(Vector3.BACK, tilt) * Basis(Vector3.UP, PI * 0.5 * floorf(hash3(Vector3(i, r, 3)) * 4.0)) \
					* Basis.from_scale(Vector3.ONE * scale * (0.85 + 0.3 * hash3(Vector3(i, r, 4))))
			_append_building(cache[model_name], Transform3D(basis, Vector3(x, ground, zz)), colormap, i * 7 + r)
	# Halo de la ville (au-dessus des toits) et brume basse.
	panel_at(holo_geo, Vector2(120, 20), Vector3(0, 4.0, -90), glow(0.5, 4), Color(TEAL_DIM.r, TEAL_DIM.g, TEAL_DIM.b, 0.12))
	panel_at(holo_geo, Vector2(60, 12), Vector3(16, 3.0, -86), glow(0.5, 4), Color(ROSE_DIM.r, ROSE_DIM.g, ROSE_DIM.b, 0.1))


## Triangles d'un .glb Kenney (repère de la scène glTF) : [[sommets, uv], …].
func _load_glb(path: String) -> Array:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var surfaces: Array = []
	if doc.append_from_file(path, state) != OK:
		push_error("build_booth: %s illisible" % path)
		_failures += 1
		return surfaces
	var scene_root: Node = doc.generate_scene(state)
	for node: Node in scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var xf: Transform3D = Transform3D.IDENTITY
		var walker: Node = mi
		while walker != null and walker != scene_root:
			var n3: Node3D = walker as Node3D
			if n3 != null:
				xf = n3.transform * xf
			walker = walker.get_parent()
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var world: PackedVector3Array = PackedVector3Array()
			for v: Vector3 in verts:
				world.append(xf * v)
			surfaces.append([world, uvs, indices])
	scene_root.free()
	return surfaces


func _append_building(surfaces: Array, xf: Transform3D, colormap: Image, seed_value: int) -> void:
	var size: Vector2i = colormap.get_size()
	var tint: Color = WINDOW_TINTS[seed_value % WINDOW_TINTS.size()]
	for surface: Array in surfaces:
		var verts: PackedVector3Array = surface[0]
		var uvs: PackedVector2Array = surface[1]
		var indices: PackedInt32Array = surface[2]
		var count: int = indices.size() if indices.size() > 0 else verts.size()
		for i: int in range(0, count, 3):
			var ia: int = indices[i] if indices.size() > 0 else i
			var ib: int = indices[i + 1] if indices.size() > 0 else i + 1
			var ic: int = indices[i + 2] if indices.size() > 0 else i + 2
			var a: Vector3 = xf * verts[ia]
			var b: Vector3 = xf * verts[ib]
			var c: Vector3 = xf * verts[ic]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() < 1e-10:
				continue
			n = -n.normalized() # glTF : faces avant en sens trigonométrique
			var uv: Vector2 = (uvs[ia] + uvs[ib] + uvs[ic]) / 3.0 if uvs.size() > 0 else Vector2.ZERO
			var px: Color = colormap.get_pixel(clampi(int(uv.x * size.x), 0, size.x - 1), clampi(int(uv.y * size.y), 0, size.y - 1))
			var window: bool = px.b > px.r + 0.07 and px.b > 0.35 and px.b < 0.72 # cellules ardoise = vitrages
			var centroid: Vector3 = (a + b + c) / 3.0
			var cell: Vector3 = (centroid / 1.2).floor()
			if window:
				var e: float = 0.4 + 0.35 * hash3(cell * 1.7)
				var wc: Color = tint.lerp(WINDOW_TINTS[int(hash3(cell * 2.3) * 4.0) % 4], 0.35)
				_windows += 1
				emissive_geo.tri(a, b, c, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, glow(e, 3),
						seeded(wc, int(hash3(cell) * 250.0)))
			else:
				# Silhouettes : aplats non éclairés (aucune lampe ne porte si loin) —
				# dans le maillage émissif, hors du chemin PBR (coût par pixel minimal).
				var lum: float = px.get_luminance()
				var dark: Color = Color(0.03, 0.034, 0.045).lerp(Color(0.065, 0.07, 0.09), lum)
				emissive_geo.tri(a, b, c, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, glow(1.0), seeded(dark, 0))


## Pluie de condensation : 3 nappes (rang 0 → 2 : la qualité Bas n'en garde
## qu'une) + rideau de gouttes sous la conduite, au-delà des colonnes.
func _build_rain() -> void:
	var sheets: Array[Array] = [
		# [z, vitesse, graine, intensité, colonnes, largeur, hauteur, y centre]
		[-7.4, 1.4, 0.0, 0.32, 160.0, 18.0, 6.0, 3.0],
		[-8.3, 1.9, 3.0, 0.26, 200.0, 18.0, 6.0, 3.0],
		[-9.6, 2.4, 7.0, 0.22, 240.0, 20.0, 6.0, 3.0],
	]
	for i: int in sheets.size():
		var s: Array = sheets[i]
		var z: float = s[0]
		var speed: float = s[1]
		var seed_value: float = s[2]
		var intensity: float = s[3]
		var columns: float = s[4]
		var w: float = s[5]
		var h: float = s[6]
		var y: float = s[7]
		panel_at(rain_geo, Vector2(w, h), Vector3(0, y, z), Vector2(speed, seed_value),
				Color(i / 8.0, 0.0, columns / 512.0, intensity))


# --- Scène ---------------------------------------------------------------------

func _save_mesh(geo: Geo, basename: String) -> ArrayMesh:
	var mesh: ArrayMesh = geo.commit()
	mesh.resource_name = basename
	var path: String = MODEL_DIR.path_join(basename + ".res")
	var old_uid: int = ResourceUID.INVALID_ID
	if FileAccess.file_exists(path):
		old_uid = ResourceLoader.get_resource_uid(path)
	mesh.take_over_path(path)
	var err: Error = ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("build_booth: échec de sauvegarde %s (%s)" % [path, error_string(err)])
		_failures += 1
		return mesh
	var uid: int = old_uid if old_uid != ResourceUID.INVALID_ID else ResourceUID.create_id_for_path(path)
	ResourceSaver.set_uid(path, uid)
	print("  écrit %s" % path)
	return mesh


func _add(parent: Node, node: Node, node_name: String, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node, true)
	node.owner = booth
	if unique:
		node.unique_name_in_owner = true
	return node


func _node(parent: Node, node_name: String, pos: Vector3 = Vector3.ZERO, unique: bool = false) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	return _add(parent, n, node_name, unique) as Node3D


func _mesh_node(parent: Node, node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _add(parent, mi, node_name) as MeshInstance3D


func _omni(parent: Node, node_name: String, pos: Vector3, color: Color, energy: float, light_range: float,
		unique: bool = false) -> OmniLight3D:
	var o: OmniLight3D = OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.omni_attenuation = 1.2
	o.shadow_enabled = false
	return _add(parent, o, node_name, unique) as OmniLight3D


## Chemin lissé (poignées automatiques) passant par `points` (repère monde).
func _path(node_name: String, points: Array[Vector3]) -> Path3D:
	var curve: Curve3D = Curve3D.new()
	curve.bake_interval = 0.05
	for i: int in points.size():
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent: Vector3 = (next - prev) * 0.22
		var handle_in: Vector3 = -tangent if i > 0 else Vector3.ZERO
		var handle_out: Vector3 = tangent if i < points.size() - 1 else Vector3.ZERO
		curve.add_point(points[i], handle_in, handle_out)
	var path: Path3D = Path3D.new()
	path.curve = curve
	return _add(booth, path, node_name, true) as Path3D


func _build_scene(meshes: Dictionary[String, ArrayMesh]) -> void:
	booth = Node3D.new()
	booth.name = "Booth"
	booth.set_script(load(DIRECTOR))
	var env: Environment = _environment()
	var cam_rig: Node3D = _node(booth, "CameraRig", Vector3(0, 1.55, 2.0))
	var cam: Camera3D = Camera3D.new()
	cam.fov = 14.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 120.0
	cam.current = true
	_add(cam_rig, cam, "BoothCamera", true)
	var key: SpotLight3D = _lights()
	# Décor fusionné : 5 draw calls.
	var decor: Node3D = _node(booth, "Decor")
	var decor_mat: ShaderMaterial = ShaderMaterial.new()
	decor_mat.shader = load(DECOR_SHADER) as Shader
	decor_mat.set_shader_parameter(&"albedo_rough", load(ALBEDO_ARRAY))
	decor_mat.set_shader_parameter(&"normal_metal", load(NORMAL_ARRAY))
	var emissive_mat: ShaderMaterial = ShaderMaterial.new()
	emissive_mat.shader = load(EMISSIVE_SHADER) as Shader
	var holo_mat: ShaderMaterial = ShaderMaterial.new()
	holo_mat.shader = load(HOLO_SHADER) as Shader
	var rain_mat: ShaderMaterial = ShaderMaterial.new()
	rain_mat.shader = load(RAIN_SHADER) as Shader
	rain_mat.set_shader_parameter(&"color", RAIN.lightened(0.15))
	# Calque 2 : seul le guichet reçoit la lampe intérieure (jamais le passager).
	_mesh_node(decor, "StaticNear", meshes["near"], decor_mat).layers = 1 | DECOR_LAYER
	_mesh_node(decor, "StaticFar", meshes["far"], decor_mat)
	_mesh_node(decor, "Emissive", meshes["emissive"], emissive_mat)
	_mesh_node(decor, "Holo", meshes["holo"], holo_mat)
	_mesh_node(decor, "Rain", meshes["rain"], rain_mat)
	# Vitre (sans collision, BOOTH_SCENE §4) : seule pièce du guichet hors fusion.
	var front: Node3D = _node(booth, "BoothFront")
	var glass_mat: ShaderMaterial = ShaderMaterial.new()
	glass_mat.shader = load(GLASS_SHADER) as Shader
	glass_mat.set_shader_parameter(&"aspect", 2.4 / 1.4)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.4, 1.4)
	var glass: MeshInstance3D = _mesh_node(front, "Glass", quad, glass_mat)
	glass.position = Vector3(0, 1.7, 0)
	glass.unique_name_in_owner = true
	glass.sorting_offset = 1.0
	_queue_node()
	_paths()
	var quality: Node = Node.new()
	quality.set_script(load(QUALITY))
	_add(booth, quality, "Quality")
	quality.set(&"environment", env)
	quality.set(&"key_light", key)
	quality.set(&"decor_material", decor_mat)
	quality.set(&"emissive_material", emissive_mat)
	quality.set(&"holo_material", holo_mat)
	quality.set(&"rain_material", rain_mat)
	quality.set(&"glass_material", glass_mat)
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(booth)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_SCENE)
	if err == OK:
		err = _normalize_scene(OUT_SCENE)
	print("build_booth: %s → %s" % [OUT_SCENE, error_string(err)])
	if err != OK:
		_failures += 1
	booth.free()


func _environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_VOID
	# Reflets : environnement analytique dans booth_decor.gdshader (pas de Sky).
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = BG_ELEVATED
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = BG_PANEL.lerp(STEEL, 0.3)
	env.fog_light_energy = 1.0
	env.fog_density = 0.024
	env.fog_sky_affect = 0.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_add(booth, we, "WorldEnvironment")
	return env


func _lights() -> SpotLight3D:
	var lights: Node3D = _node(booth, "Lights")
	var key: SpotLight3D = SpotLight3D.new()
	key.transform = Transform3D(Basis.looking_at(Vector3(0, 1.55, -0.6) - Vector3(0.25, 2.3, 0.4), Vector3.UP),
			Vector3(0.25, 2.3, 0.4))
	key.light_color = KEY
	key.light_energy = 3.0
	key.spot_range = 5.0
	key.spot_angle = 22.0
	key.spot_attenuation = 0.8
	key.shadow_enabled = true
	_add(lights, key, "KeyLight")
	_omni(lights, "RimLeft", Vector3(-0.9, 2.0, -1.8), TEAL_DIM, 2.2, 2.6)
	_omni(lights, "RimRight", Vector3(0.9, 2.0, -1.8), ROSE_DIM, 2.2, 2.6)
	_omni(lights, "Fill", Vector3(-1.5, 1.8, -1.0), STEEL, 0.6, 3.0)
	_omni(lights, "HalcyonSpill", Vector3(-0.8, 1.6, -2.3), SPILL, 0.6, 1.6)
	_omni(lights, "SlotGlow", Vector3(0, 1.05, -0.1), CYAN, 0.0, 0.6, true)
	_omni(lights, "GateLight", Vector3(2.2, 1.2, -0.6), Color("#2EFF9A"), 0.0, 2.0, true)
	# Lampe intérieure du guichet (côté agent) : lit le cadre et l'hygiaphone.
	var interior: OmniLight3D = _omni(lights, "BoothInterior", Vector3(0.2, 1.95, 0.8), STEEL.lightened(0.35), 3.5, 2.4)
	interior.light_cull_mask = DECOR_LAYER
	_omni(lights, "HallTeal", Vector3(-3.6, 2.4, -7.9), TEAL_DIM, 2.4, 4.5)
	_omni(lights, "HallRose", Vector3(3.4, 2.2, -7.6), ROSE_DIM, 2.2, 4.5)
	return key


func _queue_node() -> void:
	var mm: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm.set_script(load(QUEUE))
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	mm.multimesh = multimesh
	var imat: ShaderMaterial = ShaderMaterial.new()
	imat.shader = load(IMPOSTOR_SHADER) as Shader
	mm.material_override = imat
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(booth, mm, "QueueImpostors", true)


func _paths() -> void:
	_path("ArrivalPath", [Vector3(-1.27, 0, -3.3), Vector3(-0.9, 0, -2.0), Vector3(-0.35, 0, -1.05), Vector3(0, 0, -0.6)])
	var desk: Marker3D = Marker3D.new()
	desk.position = Vector3(0, 0, -0.6)
	_add(booth, desk, "DeskMark", true)
	var approved: Path3D = _path("ExitApprovedPath", [Vector3(0, 0, -0.6), Vector3(0.7, 0, -0.85), Vector3(1.5, 0, -0.7),
			Vector3(2.3, 0, -0.4), Vector3(2.8, 0, 0.3)])
	var refused: Path3D = _path("ExitRefusedPath", [Vector3(0, 0, -0.6), Vector3(-0.45, 0, -1.4), Vector3(-1.0, 0, -2.4),
			Vector3(-1.55, 0, -3.1), Vector3(-2.6, 0, -4.5)])
	var clear_a: Marker3D = Marker3D.new()
	clear_a.position = Vector3(0.7, 0, -0.85)
	_add(approved, clear_a, "ClearMark")
	var clear_r: Marker3D = Marker3D.new()
	clear_r.position = Vector3(-0.25, 0, -1.15)
	_add(refused, clear_r, "ClearMark")
	var look: Marker3D = Marker3D.new()
	look.position = Vector3(0, 1.40, 0)
	look.rotation_degrees = Vector3(0, 180, 0)
	_add(booth, look, "LookTargetPlane", true)
	_node(booth, "PassengerSlots", Vector3.ZERO, true)


## Rend la scène texte stable entre deux exécutions : `unique_id` = hachage du
## chemin du nœud ; identifiants de ressources renumérotés dans l'ordre.
func _normalize_scene(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var lines: PackedStringArray = f.get_as_text().split("\n")
	f.close()
	var id_map: Dictionary[String, String] = {}
	var ext_count: int = 0
	var sub_counts: Dictionary[String, int] = {}
	var id_re: RegEx = RegEx.create_from_string("^\\[(ext_resource|sub_resource) type=\"([A-Za-z0-9_]+)\".* id=\"([^\"]+)\"\\]$")
	for line: String in lines:
		var m: RegExMatch = id_re.search(line)
		if m == null:
			continue
		var old_id: String = m.get_string(3)
		if m.get_string(1) == "ext_resource":
			ext_count += 1
			id_map[old_id] = "%d_booth" % ext_count
		else:
			var type_name: String = m.get_string(2)
			sub_counts[type_name] = sub_counts.get(type_name, 0) + 1
			id_map[old_id] = "%s_%d" % [type_name, sub_counts[type_name]]
	var node_re: RegEx = RegEx.create_from_string("^\\[node name=\"([^\"]+)\"(?: type=\"[^\"]+\")?(?: parent=\"([^\"]+)\")?.*? unique_id=(\\d+)")
	var ref_re: RegEx = RegEx.create_from_string("(ExtResource|SubResource)\\(\"([^\"]+)\"\\)")
	var out: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var text_line: String = line
		if text_line.begins_with("shader_parameter/") and text_line.ends_with(" = null"):
			continue # paramètre non posé = valeur par défaut du shader
		var decl: RegExMatch = id_re.search(text_line)
		if decl != null:
			text_line = text_line.replace("id=\"%s\"" % decl.get_string(3), "id=\"%s\"" % id_map[decl.get_string(3)])
		var node: RegExMatch = node_re.search(text_line)
		if node != null:
			var parent: String = node.get_string(2)
			var node_path: String = node.get_string(1) if parent.is_empty() else "%s/%s" % [parent, node.get_string(1)]
			var stable: int = (hash(node_path) & 0x3FFFFFFF) + 1
			text_line = text_line.replace("unique_id=%s" % node.get_string(3), "unique_id=%d" % stable)
		for ref: RegExMatch in ref_re.search_all(text_line):
			var old_ref: String = ref.get_string(2)
			if id_map.has(old_ref):
				text_line = text_line.replace(ref.get_string(0), "%s(\"%s\")" % [ref.get_string(1), id_map[old_ref]])
		out.append(text_line)
	var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		return FileAccess.get_open_error()
	w.store_string("\n".join(out))
	w.close()
	return OK
