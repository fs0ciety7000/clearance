## Étape 3 du pipeline personnage M6 (ASSETS §5.1, §7.1) : convertit les skins
## Kenney (CC0, `art_src/kenney_skins/`, mêmes UV pour tous) en **cartes de
## zones** recolorables par `chr_toon.gdshader` :
## `res://assets/textures/passenger/tex_chr_zones_<skin>.png` (512², sans perte).
##
## Canaux : R = zone (0 peau · 1 haut · 2 bas · 3 accent · 4 chaussures ·
## 5 cheveux, valeur = zone × 40 / 255), G = détail (luminance relative à la
## couleur médiane de la zone, 0,5 = neutre : plis, salissures, coutures).
## Classement par texel : partie du corps (os dominant du triangle UV) +
## distance de couleur à la peau / aux cheveux de référence. Le visage peint est
## **effacé** (zone peau) : il est porté par la plaque d'atlas ditherée.
##
## Usage : `godot --headless --script res://tools/build_passenger_skins.gd`
extends SceneTree

const KENNEY_PATH: String = "res://assets/models/passenger/chr_kenney_medium.fbx"
const SRC_DIR: String = "res://art_src/kenney_skins"
const OUT_DIR: String = "res://assets/textures/passenger"
## Ordre = options `outfit_01` … `outfit_08` du catalogue.
const SKINS: Array[String] = [
	"criminalMaleA", "cyborgFemaleA", "skaterFemaleA", "skaterMaleA",
	"survivorFemaleA", "survivorMaleB", "humanFemaleA", "humanMaleA",
]
const WORK: int = 1024
const OUT: int = 512

enum Part { HEAD, TOP, FOREARM, HAND, BOTTOM, FEET }
enum Zone { SKIN, TOP, BOTTOM, ACCENT, SHOES, HAIR }

## Os dominant → partie du corps.
const PARTS: Dictionary[String, Part] = {
	"Head": Part.HEAD, "Head_end": Part.HEAD, "Neck": Part.HEAD,
	"Spine": Part.TOP, "Chest": Part.TOP, "UpperChest": Part.TOP,
	"LeftShoulder": Part.TOP, "RightShoulder": Part.TOP, "LeftUpperArm": Part.TOP, "RightUpperArm": Part.TOP,
	"LeftLowerArm": Part.FOREARM, "RightLowerArm": Part.FOREARM,
	"Hips": Part.BOTTOM, "HipsCtrl": Part.BOTTOM, "LeftUpperLeg": Part.BOTTOM, "RightUpperLeg": Part.BOTTOM,
	"LeftLowerLeg": Part.BOTTOM, "RightLowerLeg": Part.BOTTOM,
	"LeftFoot": Part.FEET, "RightFoot": Part.FEET, "LeftToes": Part.FEET, "RightToes": Part.FEET,
}

## Par texel couvert : partie, position de repos (espace squelette), normale.
var _part: PackedInt32Array = []
var _pos_y: PackedFloat32Array = []
var _normal: PackedVector3Array = []
var _head_top: float = 0.0
var _head_bottom: float = INF


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if not _rasterize_parts():
		quit(1)
		return
	var ok: bool = true
	for skin: String in SKINS:
		ok = _convert(skin) and ok
	quit(0 if ok else 1)


## Rastérise les triangles UV du modèle Kenney en carte « partie du corps ».
func _rasterize_parts() -> bool:
	var scene: Node = (load(KENNEY_PATH) as PackedScene).instantiate()
	var skeleton: Skeleton3D = scene.find_child("GeneralSkeleton", true, false) as Skeleton3D
	var mi: MeshInstance3D = skeleton.get_child(0) as MeshInstance3D if skeleton != null else null
	if mi == null or mi.skin == null:
		push_error("Modèle Kenney introuvable")
		return false
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per: int = bones.size() / verts.size()
	# Positions/normales de repos (espace squelette) et partie par sommet.
	var rest_pos: PackedVector3Array = []
	var rest_n: PackedVector3Array = []
	var vpart: PackedInt32Array = []
	for v: int in verts.size():
		var xf: Transform3D = Transform3D()
		xf.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		var best: int = 0
		var best_w: float = -1.0
		for k: int in per:
			var w: float = weights[v * per + k]
			if w <= 0.0:
				continue
			var bind: int = bones[v * per + k]
			var bone: int = skeleton.find_bone(mi.skin.get_bind_name(bind))
			var m: Transform3D = skeleton.get_bone_global_rest(bone) * mi.skin.get_bind_pose(bind)
			xf.basis.x += m.basis.x * w
			xf.basis.y += m.basis.y * w
			xf.basis.z += m.basis.z * w
			xf.origin += m.origin * w
			if w > best_w:
				best_w = w
				best = bone
		rest_pos.append(xf * verts[v])
		rest_n.append((xf.basis * normals[v]).normalized())
		var bone_name: String = skeleton.get_bone_name(best)
		var part: Part = PARTS.get(bone_name, Part.HAND if bone_name.contains("Hand") or bone_name.contains("Index") \
				or bone_name.contains("Thumb") else Part.TOP)
		vpart.append(part)
		if part == Part.HEAD and bone_name != "Neck":
			_head_top = maxf(_head_top, rest_pos[v].y)
			_head_bottom = minf(_head_bottom, rest_pos[v].y)
	_part.resize(WORK * WORK)
	_part.fill(-1)
	_pos_y.resize(WORK * WORK)
	_normal.resize(WORK * WORK)
	for i: int in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		var counts: Dictionary[int, int] = {}
		for v: int in [a, b, c]:
			counts[vpart[v]] = counts.get(vpart[v], 0) + 1
		var part: int = vpart[a]
		for p: int in counts:
			if counts[p] > counts.get(part, 0):
				part = p
		var n: Vector3 = (rest_n[a] + rest_n[b] + rest_n[c]).normalized()
		_fill_triangle(uvs[a] * WORK, uvs[b] * WORK, uvs[c] * WORK,
				Vector3(rest_pos[a].y, rest_pos[b].y, rest_pos[c].y), part, n)
	scene.free()
	return true


func _fill_triangle(a: Vector2, b: Vector2, c: Vector2, ys: Vector3, part: int, n: Vector3) -> void:
	var lo: Vector2i = Vector2i(floori(minf(a.x, minf(b.x, c.x))), floori(minf(a.y, minf(b.y, c.y))))
	var hi: Vector2i = Vector2i(ceili(maxf(a.x, maxf(b.x, c.x))), ceili(maxf(a.y, maxf(b.y, c.y))))
	var area: float = (b - a).cross(c - a)
	if absf(area) < 0.0001:
		return
	for y: int in range(maxi(lo.y, 0), mini(hi.y + 1, WORK)):
		for x: int in range(maxi(lo.x, 0), mini(hi.x + 1, WORK)):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var w0: float = (b - p).cross(c - p) / area
			var w1: float = (c - p).cross(a - p) / area
			var w2: float = 1.0 - w0 - w1
			if w0 < -0.01 or w1 < -0.01 or w2 < -0.01:
				continue
			var i: int = y * WORK + x
			_part[i] = part
			_pos_y[i] = ys.x * w0 + ys.y * w1 + ys.z * w2
			_normal[i] = n


func _convert(skin: String) -> bool:
	var src: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [SRC_DIR, skin]))
	if src == null or src.is_empty():
		push_error("Skin introuvable : %s" % skin)
		return false
	src.convert(Image.FORMAT_RGBA8)
	if src.get_width() != WORK:
		src.resize(WORK, WORK, Image.INTERPOLATE_NEAREST)
	var head_h: float = _head_top - _head_bottom
	# Références : peau (face avant de la tête, hors frange), cheveux (dessus de la tête).
	var skin_ref: Color = _median(src, func(i: int) -> bool:
		return _part[i] == Part.HEAD and _normal[i].z > 0.7 and _pos_y[i] < _head_top - 0.35 * head_h \
				and _pos_y[i] > _head_bottom + 0.1 * head_h)
	var hair_ref: Color = _median(src, func(i: int) -> bool:
		return _part[i] == Part.HEAD and _normal[i].y > 0.7)
	var zones: PackedByteArray = []
	zones.resize(WORK * WORK)
	zones.fill(255)
	for i: int in WORK * WORK:
		var part: int = _part[i]
		if part < 0:
			continue
		var c: Color = src.get_pixel(i % WORK, i / WORK)
		var near_skin: bool = _dist(c, skin_ref) < 0.16
		var zone: Zone = Zone.SKIN
		match part:
			Part.HEAD:
				var face: bool = _normal[i].z > 0.5 and _pos_y[i] < _head_top - 0.22 * head_h
				var to_skin: float = _dist(c, skin_ref)
				var to_hair: float = _dist(c, hair_ref)
				if face or near_skin or to_skin < to_hair:
					zone = Zone.SKIN
				elif to_hair < 0.3:
					zone = Zone.HAIR
				else:
					zone = Zone.ACCENT # plaque cybernétique, bandeau…
			Part.TOP, Part.FOREARM:
				zone = Zone.SKIN if near_skin else Zone.TOP
			Part.HAND:
				zone = Zone.SKIN if _dist(c, skin_ref) < 0.25 else Zone.ACCENT
			Part.BOTTOM:
				zone = Zone.SKIN if near_skin else Zone.BOTTOM
			Part.FEET:
				zone = Zone.SKIN if near_skin else Zone.SHOES
		zones[i] = zone
	# Accents : couleurs saturées dont la teinte s'écarte de la médiane du vêtement.
	for zone: Zone in [Zone.TOP, Zone.BOTTOM]:
		var ref: Color = _median(src, func(i: int) -> bool: return zones[i] == zone)
		for i: int in WORK * WORK:
			if zones[i] != zone:
				continue
			var c: Color = src.get_pixel(i % WORK, i / WORK)
			var hue_gap: float = absf(wrapf(c.h - ref.h, -0.5, 0.5))
			if c.s > 0.35 and (ref.s < 0.2 or hue_gap > 0.1) and _dist(c, ref) > 0.3:
				zones[i] = Zone.ACCENT
	var refs: Array[Color] = []
	for zone: int in 6:
		refs.append(_median(src, func(i: int) -> bool: return zones[i] == zone))
	var out: Image = Image.create_empty(WORK, WORK, false, Image.FORMAT_RGBA8)
	for i: int in WORK * WORK:
		var zone: int = zones[i]
		if zone == 255:
			continue
		var c: Color = src.get_pixel(i % WORK, i / WORK)
		var lum: float = c.get_luminance() / maxf(refs[zone].get_luminance(), 0.05)
		var detail: float = 0.5 if zone == Zone.SKIN else clampf(lum * 0.5, 0.15, 0.85)
		out.set_pixel(i % WORK, i / WORK, Color8(zone * 40, roundi(detail * 255.0), 0, 255))
	out.resize(OUT, OUT, Image.INTERPOLATE_NEAREST)
	_dilate(out, 4)
	var path: String = "%s/tex_chr_zones_%s.png" % [OUT_DIR, skin.to_snake_case()]
	var err: Error = out.save_png(ProjectSettings.globalize_path(path))
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for z: int in zones:
		if z != 255:
			counts[z] += 1
	print("%s : peau %s, cheveux %s, zones %s (%s)" % [path, skin_ref.to_html(false), hair_ref.to_html(false), counts,
			error_string(err)])
	return err == OK


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Médiane par canal des texels retenus (échantillonnés 1/4).
func _median(src: Image, keep: Callable) -> Color:
	var rs: PackedFloat32Array = []
	var gs: PackedFloat32Array = []
	var bs: PackedFloat32Array = []
	for i: int in range(0, WORK * WORK, 4):
		var kept: bool = _part[i] >= 0 and keep.call(i)
		if kept:
			var c: Color = src.get_pixel(i % WORK, i / WORK)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	if rs.is_empty():
		return Color(0.5, 0.5, 0.5)
	rs.sort()
	gs.sort()
	bs.sort()
	var m: int = rs.size() / 2
	return Color(rs[m], gs[m], bs[m])


## Étend les texels remplis sur les vides (évite les coutures au filtrage/mips).
static func _dilate(img: Image, passes: int) -> void:
	var size: int = img.get_width()
	for _p: int in passes:
		var copy: Image = img.duplicate() as Image
		for y: int in size:
			for x: int in size:
				if copy.get_pixel(x, y).a > 0.5:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < size and q.y < size and copy.get_pixelv(q).a > 0.5:
						img.set_pixel(x, y, copy.get_pixelv(q))
						break
