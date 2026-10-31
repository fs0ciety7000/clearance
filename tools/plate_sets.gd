## Décors et couches des planches de cinématique (M14 §3.4, §3.6 ; B89 phase 2 ;
## BOOTH_SCENE §19, §21) — catalogue utilisé par `tools/build_plates.gd`.
##
## Tous les lieux sont des **maquettes en volumes simples** construites ici (D-073 :
## format de sommets et matériaux du guichet, `booth_decor` + couches AmbientCG
## CC0, `booth_emissive`, `booth_holo`) : S1 Hall des Guichets (vues du Hall,
## façades, vues côté agent), S2 quai 2 / Transit-7, S3 quai 6 / cargo, S4 cabine
## du Bloc Pétrel, S5 Anneau B, S6 recycleur central, S7 Tycho, S8 lieux jamais
## modélisés (école, archives, bureau, coursive). **Aucun texte cuit** : plaques,
## écrans et tableaux sont vierges, les textes sont des `Label` posés à
## l'exécution sur les ancres renvoyées (`labels`, `holo_rects`).
## Personnes : silhouettes anonymes (maillages de la file, primitives) ; aucun
## visage (D-185) ; l'agent·e n'est jamais vu·e de face.
##
## Un fond `bg_<id>` = `func bg_<id>(root) -> Dictionary` : `camera`,
## `environment`, et selon le lieu `lit_regions` (zones d'état, PL-F9-1),
## `holo_rects`, `labels` (ancres en points monde), `lit_baked`.
## Une couche `<plate>_<nom>` (MID/FIG) = `func layer_<plate>_<nom>(root, info)` :
## ajoute ses nœuds au groupe `G_LAYER` dans le même décor (même caméra).
## Déterministe : aucune source aléatoire hors `hash()` de positions.
extends RefCounted

const BB = preload("res://tools/build_booth.gd")

const SILHOUETTE: String = "res://assets/models/passenger/imp_silhouette.res"
const SIL_HOOD: String = "res://assets/models/passenger/imp_silhouette_hood.res"
const SIL_CAP: String = "res://assets/models/passenger/imp_silhouette_cap.res"
const GUARD: String = "res://assets/models/passenger/imp_guard.res"

## Groupes de nœuds (visibilité par passe).
const G_BG: StringName = &"plate_bg"
const G_LIT: StringName = &"plate_lit"
const G_OFF: StringName = &"plate_off"
const G_LAYER: StringName = &"plate_layer"
const G_ADDITIVE: StringName = &"plate_additive"
const G_ID: StringName = &"plate_id"

var decor_mat: ShaderMaterial = null
var emissive_mat: ShaderMaterial = null
var holo_mat: ShaderMaterial = null
var _sil_shader: Shader = null
var _mesh_cache: Dictionary[String, Mesh] = {}
## Exposition des décors de phase 2 (lisibilité après peinture) ; la planche
## témoin PL-F9-1 validée garde la sienne (1,0).
var exposure_boost: float = 1.2


func _init(p_decor: ShaderMaterial, p_emissive: ShaderMaterial, p_holo: ShaderMaterial) -> void:
	decor_mat = p_decor
	emissive_mat = p_emissive
	holo_mat = p_holo
	_sil_shader = Shader.new()
	# Silhouettes anonymes figées : remplissage teinté, liseré teal/rose du monde,
	# marque émissive (`UV.x` = 1 : brassard jaune de la Garde).
	_sil_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 fill : source_color = vec4(0.063, 0.075, 0.106, 1.0);
uniform vec4 tint : source_color = vec4(0.23, 0.26, 0.32, 1.0);
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.9;
uniform float tint_mix = 0.35;
uniform vec4 mark_color : source_color = vec4(1.0, 0.902, 0.0, 1.0);
uniform float mark_energy = 0.0;
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
	vec3 col = mix(fill.rgb, tint.rgb, tint_mix) + rim * fresnel * rim_strength;
	ALBEDO = mix(col, mark_color.rgb * 0.8, step(0.5, UV.x) * mark_energy);
}
"""


# --- Bibliothèque des fonds -----------------------------------------------------------

## Vrai si le fond `stem` (`bg_h12`…) a un constructeur.
func has_bg(stem: String) -> bool:
	return has_method(stem)


func has_layer(stem: String) -> bool:
	return has_method("layer_" + stem)


# --- Kit géométrique (format de `build_booth.gd`) ---------------------------------------

## Pavé (voir `build_plates.gd` phase 1).
func box(geo: BB.Geo, size: Vector3, xf: Transform3D, uv2: Vector2, color: Color, tile: float = 1.0) -> void:
	var h: Vector3 = size * 0.5
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n: Vector3 in axes:
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = n.cross(u)
		var hn: float = absf(n.dot(h))
		var hu: float = absf(u.dot(h))
		var hv: float = absf(v.dot(h))
		var c: Vector3 = n * hn
		var pts: Array[Vector3] = [
			xf * (c - u * hu - v * hv), xf * (c + u * hu - v * hv), xf * (c + u * hu + v * hv), xf * (c - u * hu + v * hv),
		]
		var uvs: Array[Vector2] = []
		if geo.kind == BB.Geo.LIT:
			uvs = [Vector2(-hv, -hu) / tile, Vector2(-hv, hu) / tile, Vector2(hv, hu) / tile, Vector2(hv, -hu) / tile]
		else:
			uvs = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
		geo.quad(pts, (xf.basis * n).normalized(), uvs, uv2, color)


## Pavé posé (centre, taille, rotation en degrés) avec un matériau `lit()`.
func b(geo: BB.Geo, size: Vector3, pos: Vector3, m: Array, rot_deg: Vector3 = Vector3.ZERO, tile: float = 1.0) -> void:
	box(geo, size, Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), pos), m[0], m[1], tile)


## Matériau LIT : [uv2 (couche, mouillé), couleur (teinte, métal)].
func lit(layer: float, tint: Color, metal: float = 0.0, wet: float = 0.0) -> Array:
	return [Vector2(layer, wet), Color(tint.r, tint.g, tint.b, metal)]


func flat(tint: Color, metal: float = 0.1) -> Array:
	return lit(BB.L_FLAT, tint, metal)


## Quadrilatère orienté : centre, demi-axes `u` et `v`, normale = u × v.
func quad(geo: BB.Geo, center: Vector3, u: Vector3, v: Vector3, uv2: Vector2, color: Color) -> void:
	var pts: Array[Vector3] = [center - u - v, center + u - v, center + u + v, center - u + v]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	geo.quad(pts, u.cross(v).normalized(), uvs, uv2, color)


## Émissif (énergie, mode 0 fixe) teinté.
func glow_quad(geo: BB.Geo, center: Vector3, u: Vector3, v: Vector3, color: Color, energy: float, mode: int = 0) -> void:
	quad(geo, center, u, v, Vector2(energy, mode), Color(color.r, color.g, color.b, 0))


## Cylindre (axe Y local de `xf`), `segments` faces, chapeaux optionnels.
func cyl(geo: BB.Geo, radius: float, height: float, xf: Transform3D, m: Array, segments: int = 12, caps: bool = true) -> void:
	for k: int in segments:
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		var n0: Vector3 = Vector3(cos(a0), 0, sin(a0))
		var n1: Vector3 = Vector3(cos(a1), 0, sin(a1))
		var p: Array[Vector3] = [xf * (n0 * radius + Vector3(0, -height * 0.5, 0)), xf * (n1 * radius + Vector3(0, -height * 0.5, 0)),
				xf * (n1 * radius + Vector3(0, height * 0.5, 0)), xf * (n0 * radius + Vector3(0, height * 0.5, 0))]
		var uv: Array[Vector2] = [Vector2(a0 * radius, 0), Vector2(a1 * radius, 0), Vector2(a1 * radius, height), Vector2(a0 * radius, height)]
		geo.quad(p, (xf.basis * ((n0 + n1) * 0.5)).normalized(), uv, m[0], m[1])
		if caps:
			for s: float in [-1.0, 1.0]:
				var c: Vector3 = xf * Vector3(0, height * 0.5 * s, 0)
				var e0: Vector3 = xf * (n0 * radius + Vector3(0, height * 0.5 * s, 0))
				var e1: Vector3 = xf * (n1 * radius + Vector3(0, height * 0.5 * s, 0))
				var n: Vector3 = (xf.basis * Vector3(0, s, 0)).normalized()
				if s > 0.0:
					geo.tri(c, e1, e0, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, m[0], m[1])
				else:
					geo.tri(c, e0, e1, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, m[0], m[1])


## Cylindre couché le long de l'axe `axis` (X ou Z), centre `pos`.
func pipe(geo: BB.Geo, radius: float, length: float, pos: Vector3, axis: Vector3, m: Array, segments: int = 10) -> void:
	var basis: Basis = Basis(Vector3.BACK, PI * 0.5) if absf(axis.x) > 0.5 else Basis(Vector3.RIGHT, PI * 0.5)
	cyl(geo, radius, length, Transform3D(basis, pos), m, segments)


## Anneau plat (hublot, volant de vanne) dans le plan de `xf` (normale +Z local).
func ring(geo: BB.Geo, inner: float, outer: float, depth: float, xf: Transform3D, m: Array, segments: int = 24) -> void:
	for k: int in segments:
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		var d0: Vector3 = Vector3(cos(a0), sin(a0), 0)
		var d1: Vector3 = Vector3(cos(a1), sin(a1), 0)
		var p: Array[Vector3] = [xf * (d0 * inner + Vector3(0, 0, depth)), xf * (d1 * inner + Vector3(0, 0, depth)),
				xf * (d1 * outer + Vector3(0, 0, depth)), xf * (d0 * outer + Vector3(0, 0, depth))]
		var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		geo.quad(p, (xf.basis * Vector3.BACK).normalized(), uv, m[0], m[1])
		if depth > 0.0:
			var q: Array[Vector3] = [xf * (d0 * outer), xf * (d0 * outer + Vector3(0, 0, depth)), xf * (d1 * outer + Vector3(0, 0, depth)), xf * (d1 * outer)]
			geo.quad(q, (xf.basis * ((d0 + d1) * 0.5)).normalized(), uv, m[0], m[1])


## Disque (hublot, lampe) : anneau d'intérieur nul.
func disc(geo: BB.Geo, radius: float, xf: Transform3D, uv2: Vector2, color: Color, segments: int = 24) -> void:
	for k: int in segments:
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		geo.tri(xf * Vector3.ZERO, xf * (Vector3(cos(a0), sin(a0), 0) * radius), xf * (Vector3(cos(a1), sin(a1), 0) * radius), (xf.basis * Vector3.BACK).normalized(), Vector2(0.5, 0.5),
				Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5), Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5), uv2, color)


func node(parent: Node3D, geo: BB.Geo, mat: Material, group: StringName, additive: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	if geo.triangles == 0:
		return mi
	mi.mesh = geo.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(group)
	if additive:
		mi.add_to_group(G_ADDITIVE)
	parent.add_child(mi)
	return mi


## Pose les géométries d'un jeu (`set`) : {lit, emis, holo} → nœuds du groupe.
func commit(root: Node3D, set: Dictionary, group: StringName) -> void:
	node(root, set["lit"], decor_mat, group)
	node(root, set["emis"], emissive_mat, group)
	node(root, set["holo"], holo_mat, group, true)


func new_set() -> Dictionary:
	return {"lit": BB.Geo.new(BB.Geo.LIT), "emis": BB.Geo.new(BB.Geo.EMISSIVE), "holo": BB.Geo.new(BB.Geo.HOLO)}


func sil_material(tint: Color, rim: float = 0.9, mark: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _sil_shader
	mat.set_shader_parameter("fill", DS.BG_PANEL)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rim_left", BB.TEAL_DIM)
	mat.set_shader_parameter("rim_right", BB.ROSE_DIM)
	mat.set_shader_parameter("rim_strength", rim)
	mat.set_shader_parameter("mark_energy", mark)
	return mat


func _mesh(path: String) -> Mesh:
	if not _mesh_cache.has(path):
		_mesh_cache[path] = load(path) as Mesh
	return _mesh_cache[path]


## Silhouette debout anonyme (maillage de la file : `bare`, `hood`, `cap`, `guard`).
## `yaw_deg` : 0 = face à +Z (vers la caméra d'une vue de face), 180 = de dos.
func person(root: Node3D, pos: Vector3, yaw_deg: float, scale: float, tint: Color, group: StringName,
		shape: String = "bare", rim: float = 0.7) -> void:
	var path: String = {"bare": SILHOUETTE, "hood": SIL_HOOD, "cap": SIL_CAP, "guard": GUARD}.get(shape, SILHOUETTE)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _mesh(path)
	mi.material_override = sil_material(tint, rim, 1.0 if shape == "guard" else 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), pos)
	mi.add_to_group(group)
	root.add_child(mi)


## Primitive teintée (silhouettes assises, mains, accessoires souples).
func prim(root: Node3D, mesh: PrimitiveMesh, xf: Transform3D, tint: Color, group: StringName, rim: float = 0.55) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = sil_material(tint, rim)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xf
	mi.add_to_group(group)
	root.add_child(mi)


func capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 16
	m.rings = 4
	return m


func sphere(radius: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func boxm(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


## Personne assise vue de dos ou de trois quarts (buste, épaules, tête, coiffure) ;
## `yaw_deg` 180 = de dos. Aucun visage (rim faible sur la tête).
func seated(root: Node3D, seat: Vector3, h: float, tint: Color, hair: int, yaw_deg: float, group: StringName) -> void:
	var rot: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	prim(root, capsule(0.15, 0.56), Transform3D(rot.scaled(Vector3(1.25, 1.0, 0.85) * h), seat + Vector3(0, 0.27 * h, 0)), tint, group)
	prim(root, capsule(0.08, 0.44), Transform3D(rot * Basis(Vector3.BACK, PI * 0.5).scaled(Vector3.ONE * h), seat + Vector3(0, 0.5 * h, 0)), tint, group)
	var head: Vector3 = seat + Vector3(0, 0.7 * h, 0)
	var hair_tint: Color = DS.BG_ELEVATED.lerp(tint, 0.3)
	prim(root, sphere(0.11 if hair != 2 else 0.13), Transform3D(Basis.from_scale(Vector3(1.0, 1.08, 1.0) * h), head),
			tint.darkened(0.12) if hair == 2 else hair_tint, group, 0.12)
	# Jambes repliées devant (cachées de dos, visibles de trois quarts).
	prim(root, capsule(0.07, 0.42), Transform3D(rot * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * h),
			seat + rot * Vector3(0, 0.02, 0.2) * h), tint.darkened(0.2), group)


## Main stylisée (avant-bras, paume, quatre doigts, pouce) : jamais de visage ici
## (mains de l'agent·e, de Noa, d'un·e inconnu·e). `dir` : vers les doigts.
func hand(root: Node3D, wrist: Vector3, dir: Vector3, up: Vector3, scale: float, tint: Color, group: StringName,
		sleeve: Color = Color(0, 0, 0, 0), curl: float = 0.0) -> void:
	var f: Vector3 = dir.normalized()
	var u: Vector3 = up.normalized()
	var s: Vector3 = f.cross(u).normalized()
	u = s.cross(f).normalized()
	var basis: Basis = Basis(s, u, -f)
	var arm_len: float = 0.18 * scale
	var arm_col: Color = sleeve if sleeve.a > 0.0 else tint
	prim(root, capsule(0.034 * scale, arm_len), Transform3D(along(f), wrist - f * arm_len * 0.5), arm_col, group)
	prim(root, boxm(Vector3(0.085, 0.028, 0.09) * scale), Transform3D(basis, wrist + f * 0.05 * scale), tint, group)
	var fd: Vector3 = (f * (1.0 - curl) - u * curl).normalized()
	for k: int in 4:
		var off: float = (k - 1.5) * 0.021 * scale
		var length: float = (0.07 - absf(k - 1.5) * 0.008) * scale
		var base: Vector3 = wrist + f * 0.095 * scale + s * off
		prim(root, capsule(0.0095 * scale, length), Transform3D(along(fd), base + fd * length * 0.5), tint, group, 0.4)
	var thumb: Vector3 = (f * 0.6 - s * 0.8).normalized()
	prim(root, capsule(0.011 * scale, 0.06 * scale), Transform3D(along(thumb), wrist + f * 0.03 * scale - s * 0.045 * scale + thumb * 0.03 * scale),
			tint, group, 0.4)


## Base orthonormée dont l'axe Y local suit `dir` (primitives allongées).
static func along(dir: Vector3) -> Basis:
	var y: Vector3 = dir.normalized()
	var ref: Vector3 = Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x: Vector3 = ref.cross(y).normalized()
	return Basis(x, y, x.cross(y))


func omni(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)
	return l


func spot(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, light_range: float, angle: float) -> SpotLight3D:
	var l: SpotLight3D = SpotLight3D.new()
	parent.add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.BACK)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.spot_attenuation = 0.8
	l.shadow_enabled = false
	return l


func camera(root: Node3D, from: Vector3, to: Vector3, fov: float, far: float = 140.0) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = far
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	cam.look_at_from_position(from, to, Vector3.UP)
	return cam


func environment(ambient: Color, ambient_energy: float, fog: Color, fog_density: float, exposure: float) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DS.BG_VOID
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure * exposure_boost
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = fog_density > 0.0
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	return env


static func hash01(x: int) -> float:
	var h: int = (x * 73856093) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## Teintes de tenue (palettes du monde, désaturées) pour les foules anonymes.
func crowd_tint(k: int) -> Color:
	var row: Array = GreyboxStyle.PALETTES[k % GreyboxStyle.PALETTES.size()]
	var c: Color = Color(String(row[0]))
	return c.lerp(Color(c.get_luminance(), c.get_luminance(), c.get_luminance()), 0.35)


## Petite foule de silhouettes debout autour de `center` (largeur `spread`).
func crowd(root: Node3D, center: Vector3, count: int, spread: Vector2, yaw_deg: float, seed: int, group: StringName,
		scale_range: Vector2 = Vector2(0.9, 1.06), with_children: bool = true) -> void:
	for k: int in count:
		var p: Vector3 = center + Vector3(lerpf(-spread.x, spread.x, hash01(seed + k * 3)), 0, lerpf(-spread.y, spread.y, hash01(seed + k * 7 + 1)))
		var child: bool = with_children and hash01(seed + k * 11) < 0.22
		var sc: float = lerpf(0.58, 0.7, hash01(seed + k)) if child else lerpf(scale_range.x, scale_range.y, hash01(seed + k * 5))
		var shapes: Array[String] = ["bare", "cap", "bare", "bare"]
		person(root, p, yaw_deg + lerpf(-14.0, 14.0, hash01(seed + k * 13)), sc, crowd_tint(seed + k), group,
				shapes[int(hash01(seed + k * 17) * 3.99)], 0.55)


# === S1 · Hall des Guichets ===========================================================

## Matériaux du Hall (palette monde, BOOTH §5).
func hall_mats() -> Dictionary:
	return {
		"concrete": lit(BB.L_CONCRETE, Color(0.62, 0.64, 0.68), 0.0, 1.0),
		"panel": lit(BB.L_FLAT, DS.BG_ELEVATED.lerp(BB.STEEL, 0.5), 0.3),
		"chrome": lit(BB.L_CHROME, Color(0.78, 0.8, 0.84), 1.0),
		"plates": lit(BB.L_PLATES, Color(0.4, 0.43, 0.48), 0.7),
		"dark": lit(BB.L_PLATES, Color(0.2, 0.22, 0.26), 0.6),
		"hazard": lit(BB.L_HAZARD, Color(0.8, 0.8, 0.8), 0.2),
		"void": lit(BB.L_FLAT, DS.BG_PANEL, 0.0),
		"glass_off": lit(BB.L_FLAT, DS.BG_ELEVATED, 0.85),
		"plaque": lit(BB.L_FLAT, BB.SPILL.darkened(0.25), 0.1),
		"floor": lit(BB.L_CONCRETE, Color(0.42, 0.44, 0.47), 0.0, 1.0),
		"ceiling": lit(BB.L_FLAT, DS.BG_PANEL, 0.2),
	}


## Façade de guichet vue du Hall (repère `xf` : X à droite, +Z vers le Hall).
## `state` : `off` (vitre éteinte), `lit` (allumée, cuite), `split` (éteinte
## dans le fond + allumée dans `lit_set`, PL-F9-1), `open` (vitre levée),
## `sealed` (plombée, scellés jaunes), `charter` (vitre allumée, voile holo pour
## la Charte), `dark` (Hall éteint). Rend les ancres de la plaque et de la vitre.
func facade(root: Node3D, set: Dictionary, xf: Transform3D, width: float, index: int, state: String, agent: bool,
		lit_set: Dictionary = {}, last: bool = false) -> Dictionary:
	var m: Dictionary = hall_mats()
	var stat: BB.Geo = set["lit"]
	var inner: float = width - 0.34
	var window_tint: Color = BB.KEY.lerp(DS.ACCENT_CYAN, 0.1)
	var concrete: Array = m["concrete"]
	box(stat, Vector3(0.34, 6.2, 0.6), xf * Transform3D(Basis(), Vector3(-width * 0.5, 3.1, 0.05)), concrete[0], concrete[1], 1.5)
	box(stat, Vector3(0.38, 0.07, 0.64), xf * Transform3D(Basis(), Vector3(-width * 0.5, 1.15, 0.05)), m["chrome"][0], m["chrome"][1])
	box(stat, Vector3(0.36, 0.24, 0.62), xf * Transform3D(Basis(), Vector3(-width * 0.5, 0.12, 0.05)), m["hazard"][0], m["hazard"][1], 0.5)
	if last:
		box(stat, Vector3(0.34, 6.2, 0.6), xf * Transform3D(Basis(), Vector3(width * 0.5, 3.1, 0.05)), concrete[0], concrete[1], 1.5)
	box(stat, Vector3(inner, 1.0, 0.5), xf * Transform3D(Basis(), Vector3(0, 0.5, 0.25)), m["plates"][0], m["plates"][1], 0.8)
	box(stat, Vector3(inner, 0.04, 0.6), xf * Transform3D(Basis(), Vector3(0, 1.02, 0.28)), m["chrome"][0], m["chrome"][1])
	box(stat, Vector3(inner, 0.7, 0.36), xf * Transform3D(Basis(), Vector3(0, 2.75, 0.12)), m["dark"][0], m["dark"][1], 0.8)
	box(stat, Vector3(0.5, 0.24, 0.03), xf * Transform3D(Basis(), Vector3(0, 2.78, 0.315)), m["plaque"][0], m["plaque"][1])
	box(stat, Vector3(inner, 0.05, 0.1), xf * Transform3D(Basis(), Vector3(0, 2.38, 0.05)), m["chrome"][0], m["chrome"][1])
	box(stat, Vector3(width, 3.0, 0.3), xf * Transform3D(Basis(), Vector3(0, 4.6, -0.25)), m["panel"][0], m["panel"][1])
	box(stat, Vector3(0.05, 3.0, 0.06), xf * Transform3D(Basis(), Vector3(width * 0.25, 4.6, -0.08)), m["dark"][0], m["dark"][1])
	box(stat, Vector3(width, 0.05, 0.06), xf * Transform3D(Basis(), Vector3(0, 5.2, -0.08)), m["dark"][0], m["dark"][1])
	box(stat, Vector3(width, 0.06, 0.14), xf * Transform3D(Basis(), Vector3(0, 3.4, -0.05)), m["chrome"][0], m["chrome"][1])
	for side: float in [-1.0, 1.0]:
		box(stat, Vector3(0.05, 1.5, 1.7), xf * Transform3D(Basis(), Vector3(side * (inner * 0.5 - 0.03), 1.7, -0.85)), m["void"][0], m["void"][1])
	box(stat, Vector3(inner, 0.05, 1.7), xf * Transform3D(Basis(), Vector3(0, 2.42, -0.85)), m["void"][0], m["void"][1])
	box(stat, Vector3(inner - 0.1, 0.01, 0.1), xf * Transform3D(Basis(), Vector3(0, 0.005, 1.05)), m["hazard"][0], m["hazard"][1], 0.5)
	box(stat, Vector3(inner, 1.5, 0.05), xf * Transform3D(Basis(), Vector3(0, 1.7, -1.7)), m["void"][0], m["void"][1])
	if agent:
		var p: Vector3 = xf * Vector3(lerpf(-0.25, 0.25, hash01(index * 11)), -0.3, -0.95)
		var fwd: Vector3 = xf.basis.z
		person(root, p, rad_to_deg(atan2(fwd.x, fwd.z)), 1.0, BB.STEEL, G_BG, "bare", 0.9)
	var lit_target: Dictionary = set
	var glass: String = state
	if state == "split":
		lit_target = lit_set
		quad(set["lit"], xf * Vector3(0, 1.72, 0.02), xf.basis * Vector3(inner * 0.5, 0, 0), xf.basis * Vector3(0, 0.66, 0),
				m["glass_off"][0], m["glass_off"][1])
	if state in ["off", "sealed", "dark"]:
		quad(set["lit"], xf * Vector3(0, 1.72, 0.02), xf.basis * Vector3(inner * 0.5, 0, 0), xf.basis * Vector3(0, 0.66, 0),
				m["glass_off"][0], m["glass_off"][1])
	if state in ["lit", "split", "charter", "open"]:
		# Intérieur éclairé : 3 bandes (PL-F9-1 validée : énergies d'origine ;
		# ailleurs plus douces pour que la peinture garde les volumes).
		var soft: bool = state != "split"
		for band: int in 3:
			var y0: float = 1.06 + band * 0.45
			glow_quad(lit_target["emis"], xf * Vector3(0, y0 + 0.225, -1.66), xf.basis * Vector3(inner * 0.5, 0, 0),
					xf.basis * Vector3(0, 0.225, 0), window_tint.lerp(BB.STEEL, 0.35) if soft else window_tint,
					(0.32 + band * 0.12) if soft else (0.75 + band * 0.32))
		if state != "open":
			quad(lit_target["holo"], xf * Vector3(0, 1.72, 0.03), xf.basis * Vector3(inner * 0.5, 0, 0), xf.basis * Vector3(0, 0.66, 0),
					Vector2(0.6, 3), Color(window_tint.r, window_tint.g, window_tint.b, 0.18 if state != "charter" else 0.3))
		quad(lit_target["holo"], xf * Vector3(0, 0.012, 1.9), xf.basis * Vector3(inner * 0.45, 0, 0), xf.basis * Vector3(0, 0, -1.35),
				Vector2(1.0, 0), Color(window_tint.r, window_tint.g, window_tint.b, 0.4 if state == "split" else 0.14))
		quad(lit_target["holo"], xf * Vector3(0, 0.014, 3.2), xf.basis * Vector3(inner * 0.32, 0, 0), xf.basis * Vector3(0, 0, -2.6),
				Vector2(1.0, 0), Color(window_tint.r, window_tint.g, window_tint.b, 0.3 if state == "split" else 0.1))
	if state == "open":
		# Vitre levée : rangée sous le bandeau, comptoir dégagé.
		box(stat, Vector3(inner, 0.08, 0.04), xf * Transform3D(Basis(), Vector3(0, 2.33, 0.06)), m["chrome"][0], m["chrome"][1])
	if state == "sealed":
		# Scellés jaunes en croix (marque Consortium, aplats).
		for a: float in [32.0, -32.0]:
			box(stat, Vector3(inner * 1.12, 0.09, 0.01), xf * Transform3D(Basis(Vector3.BACK, deg_to_rad(a)), Vector3(0, 1.72, 0.05)),
					lit(BB.L_FLAT, BB.YELLOW.darkened(0.25), 0.1)[0], lit(BB.L_FLAT, BB.YELLOW.darkened(0.25), 0.1)[1])
		box(stat, Vector3(0.22, 0.3, 0.012), xf * Transform3D(Basis(), Vector3(0, 1.72, 0.058)), m["plaque"][0], m["plaque"][1])
	return {
		"plaque": [xf * Vector3(-0.25, 2.9, 0.33), xf * Vector3(0.25, 2.9, 0.33), xf * Vector3(-0.25, 2.66, 0.33), xf * Vector3(0.25, 2.66, 0.33)],
		"glass": [xf * Vector3(-inner * 0.5, 2.38, 0.03), xf * Vector3(inner * 0.5, 2.38, 0.03), xf * Vector3(-inner * 0.5, 1.06, 0.03),
				xf * Vector3(inner * 0.5, 1.06, 0.03)],
		"region": [xf * Vector3(-inner * 0.5, 2.45, 0.05), xf * Vector3(inner * 0.5, 2.45, 0.05), xf * Vector3(-inner * 0.5, 0.0, 3.3),
				xf * Vector3(inner * 0.5, 0.0, 3.3), xf * Vector3(-inner * 0.5, 1.0, 0.5), xf * Vector3(inner * 0.5, 1.0, 0.5)],
		"inner": inner,
	}


## Sol, plafond bas à bandeaux rayonnants, autour de `center`.
func hall_shell(set: Dictionary, center: Vector3, dark: bool = false) -> void:
	var m: Dictionary = hall_mats()
	box(set["lit"], Vector3(60, 0.2, 40), Transform3D(Basis(), Vector3(center.x, -0.1, center.z - 4.0)), m["concrete"][0], Color(0.42, 0.44, 0.47, 0.0), 3.0)
	box(set["lit"], Vector3(60, 0.3, 40), Transform3D(Basis(), Vector3(center.x, 6.35, center.z - 4.0)), m["ceiling"][0], m["ceiling"][1])
	for k: int in 7:
		var a: float = deg_to_rad(-48.0 + k * 16.0)
		var dir: Vector3 = Vector3(sin(a), 0, -cos(a))
		glow_quad(set["emis"], center + dir * 7.5 + Vector3(0, 6.19, 0), Vector3.UP.cross(dir) * 0.06, dir * 3.0, BB.KEY, 0.12 if dark else 0.55)


## Œil du Consortium (hologramme de marque, hexagone jaune) — décor, sans texte.
func consortium_eye(set: Dictionary, c: Vector3, r: float, alpha: float = 0.8) -> void:
	for k: int in 6:
		var a0: float = TAU * k / 6.0 + PI / 6.0
		var a1: float = TAU * (k + 1) / 6.0 + PI / 6.0
		var p0: Vector3 = c + Vector3(cos(a0), sin(a0), 0) * r
		var p1: Vector3 = c + Vector3(cos(a1), sin(a1), 0) * r
		quad(set["holo"], (p0 + p1) * 0.5, (p1 - p0) * 0.5, (p1 - p0).cross(Vector3.BACK).normalized() * 0.04 * r,
				Vector2(1.3, 1), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, alpha))
	quad(set["holo"], c, Vector3(0.5 * r, 0, 0), Vector3(0, 0.14 * r, 0), Vector2(1.2, 4), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, alpha * 0.7))
	quad(set["holo"], c, Vector3(0.12 * r, 0, 0), Vector3(0, 0.12 * r, 0), Vector2(1.6, 1), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, alpha))


## Arc de guichets (rayon 13 m, pas 8,4°) vu du Hall ; `states[i]` par façade.
func booth_arc(root: Node3D, set: Dictionary, count: int, states: Array, agents: bool, lit_set: Dictionary = {},
		center: Vector3 = Vector3(0, 0, 2.0)) -> Array:
	var radius: float = 13.0
	var step_deg: float = 8.4
	var width: float = 2.0 * radius * sin(deg_to_rad(step_deg) * 0.5)
	var out: Array = []
	for i: int in count:
		var a: float = deg_to_rad((float(i) - (count - 1) * 0.5) * step_deg)
		var fwd: Vector3 = Vector3(-sin(a), 0, cos(a))
		var right: Vector3 = Vector3(cos(a), 0, sin(a))
		var xf: Transform3D = Transform3D(Basis(right, Vector3.UP, fwd), center - fwd * radius)
		var info: Dictionary = facade(root, set, xf, width, i, String(states[i % states.size()]),
				agents and hash01(i * 7 + 3) > 0.2, lit_set, i == count - 1)
		info["xf"] = xf
		out.append(info)
	return out


## Avant-plan de file : barrières magnétiques (poteaux chromés, bande teal).
func barriers(set: Dictionary, start: Vector3, count: int, step: Vector3) -> void:
	var m: Dictionary = hall_mats()
	for k: int in count:
		var p: Vector3 = start + step * k + Vector3(0, 0.5, 0)
		b(set["lit"], Vector3(0.07, 1.0, 0.07), p, m["chrome"])
		b(set["lit"], Vector3(0.26, 0.04, 0.26), Vector3(p.x, 0.02, p.z), m["chrome"])
		if k < count - 1:
			var mid: Vector3 = p + step * 0.5 + Vector3(0, 0.42, 0)
			box(set["lit"], Vector3(step.length(), 0.05, 0.03), Transform3D(Basis(Vector3.UP, -atan2(step.z, step.x)), mid),
					flat(BB.TEAL_DIM, 0.3)[0], flat(BB.TEAL_DIM, 0.3)[1])


## Éclairage d'un Hall : plafonniers acier + rims teal/rose ; `scale` global.
func hall_lights(root: Node3D, scale: float, warm: float = 0.0, cold: float = 0.0) -> void:
	var key: Color = BB.KEY.lerp(BB.STEEL, 0.5).lerp(BB.SPILL, warm).lerp(Color("#B9C6D3"), cold)
	omni(root, Vector3(0, 4.4, -6), key, 1.6 * scale, 9.0)
	omni(root, Vector3(-6.0, 4.4, -3), key, 1.3 * scale, 8.0)
	omni(root, Vector3(6.0, 4.4, -3), key, 1.3 * scale, 8.0)
	omni(root, Vector3(-9.0, 2.5, 3.0), BB.TEAL_DIM, 2.0 * scale, 9.0)
	omni(root, Vector3(9.0, 2.5, 3.0), BB.ROSE_DIM, 2.0 * scale, 9.0)


func hall_env(scale: float = 1.0, warm: float = 0.0) -> Environment:
	return environment(DS.BG_ELEVATED.lerp(BB.SPILL, warm * 0.3), 0.6 * scale, DS.BG_PANEL.lerp(BB.STEEL, 0.35), 0.03, 1.1 * lerpf(0.8, 1.0, scale))


## BG-H12 · arc des douze vitres (PL-F9-1) : fond éteint, 12 zones d'état allumées.
func bg_h12(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var lit_set: Dictionary = new_set()
	var states: Array = []
	for i: int in 12:
		states.append("split")
	var booths: Array = booth_arc(root, set, 12, states, true, lit_set)
	hall_shell(set, Vector3(0, 0, 2.0))
	consortium_eye(set, Vector3(0, 4.7, 2.0 - 13.0 + 0.75), 0.85)
	var regions: Array = []
	var holo: Array = []
	var labels: Array = []
	for i: int in booths.size():
		var info: Dictionary = booths[i]
		var zone: BB.Geo = BB.Geo.new(BB.Geo.EMISSIVE)
		var xf: Transform3D = info["xf"]
		var inner: float = info["inner"]
		quad(zone, xf * Vector3(0, 1.72, 0.06), xf.basis * Vector3(inner * 0.5 + 0.04, 0, 0), xf.basis * Vector3(0, 0.7, 0), Vector2.ZERO, Color.BLACK)
		quad(zone, xf * Vector3(0, 0.02 + 0.004 * i, 2.05), xf.basis * Vector3(inner * 0.47, 0, 0), xf.basis * Vector3(0, 0, -1.5), Vector2.ZERO, Color.BLACK)
		var zone_node: MeshInstance3D = node(root, zone, null, G_ID)
		zone_node.set_meta(&"plate_id", i + 1)
		regions.append(info["region"])
		holo.append(info["glass"])
		labels.append({"id": "booth_%02d" % (i + 1), "text": "%02d" % (i + 1), "points": info["plaque"]})
	commit(root, set, G_BG)
	node(root, lit_set["emis"], emissive_mat, G_LIT)
	node(root, lit_set["holo"], holo_mat, G_LIT, true)
	hall_lights(root, 1.0)
	var env: Environment = hall_env()
	env.tonemap_exposure /= exposure_boost # planche témoin validée (D-195) : réglages d'origine
	return {
		"camera": camera(root, Vector3(0, 3.6, 12.0), Vector3(0, 1.5, -9.0), 40.0),
		"environment": env, "lit_regions": regions, "holo_rects": holo, "labels": labels,
	}


## Couche MID de PL-F9-1 : barrières et deux personnes de dos (bas de planche).
func layer_pl_f9_1_foreground(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	barriers(set, Vector3(-4.6, 0, 3.6), 4, Vector3(1.15, 0, 0.08))
	commit(root, set, G_LAYER)
	person(root, Vector3(-3.1, 0, 4.4), 172.0, 1.02, DS.BG_ELEVATED, G_LAYER, "bare", 0.5)
	person(root, Vector3(3.4, 0, 4.2), 194.0, 0.97, DS.BG_ELEVATED.lerp(BB.ROSE_DIM, 0.3), G_LAYER, "hood", 0.5)


## BG-H18 · douze vitres allumées (PL-EB-3), lumière chaude.
func bg_h18(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 12, ["lit"], true)
	hall_shell(set, Vector3(0, 0, 2.0))
	commit(root, set, G_BG)
	hall_lights(root, 1.05, 0.4)
	return {"camera": camera(root, Vector3(0, 3.2, 11.0), Vector3(0, 1.7, -9.0), 42.0), "environment": hall_env(1.0, 0.6)}


## BG-H13 · Hall éteint (PL-F9-2) : vitres noires, plafond presque éteint.
func bg_h13(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 9, ["dark"], false)
	hall_shell(set, Vector3(0, 0, 2.0), true)
	commit(root, set, G_BG)
	omni(root, Vector3(0, 4.0, -4), BB.STEEL.lightened(0.2), 1.4, 12.0)
	omni(root, Vector3(-8.0, 2.0, 4.0), BB.TEAL_DIM, 2.4, 12.0)
	omni(root, Vector3(8.0, 2.0, 4.0), BB.ROSE_DIM, 2.0, 12.0)
	omni(root, Vector3(0.0, 1.5, 6.0), BB.STEEL, 1.0, 8.0)
	return {"camera": camera(root, Vector3(0.0, 1.8, 9.5), Vector3(0, 1.4, -9.0), 46.0),
			"environment": environment(DS.BG_PANEL, 0.6, DS.BG_VOID, 0.03, 1.0)}


func layer_pl_f9_2_families(root: Node3D, _info: Dictionary) -> void:
	# Familles qui traversent le Hall éteint, de profil, vers la gauche.
	crowd(root, Vector3(-0.5, 0, 4.2), 9, Vector2(3.0, 1.2), -90.0, 1492, G_LAYER)


## BG-H6 · Hall large, Œil du Consortium en hologramme (PL-F4-4, PL-F7-1).
func bg_h6(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 11, ["lit", "lit", "off"], true)
	hall_shell(set, Vector3(0, 0, 2.0))
	consortium_eye(set, Vector3(0, 4.3, -6.5), 1.6, 0.9)
	var m: Dictionary = hall_mats()
	barriers(set, Vector3(-5.0, 0, 1.5), 9, Vector3(1.25, 0, 0))
	barriers(set, Vector3(-5.0, 0, -0.6), 9, Vector3(1.25, 0, 0))
	commit(root, set, G_BG)
	hall_lights(root, 1.0)
	omni(root, Vector3(0, 4.3, -5.5), BB.YELLOW.darkened(0.3), 0.8, 5.0)
	return {"camera": camera(root, Vector3(0, 4.2, 14.0), Vector3(0, 2.4, -8.0), 46.0), "environment": hall_env(),
			"holo_rects": [[Vector3(-1.7, 6.0, -6.5), Vector3(1.7, 6.0, -6.5), Vector3(-1.7, 2.6, -6.5), Vector3(1.7, 2.6, -6.5)]]}


## BG-H9 · rangée de vitres plombées, scellés jaunes (PL-F5B-3).
func bg_h9(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 12, ["sealed"], false)
	hall_shell(set, Vector3(0, 0, 2.0))
	commit(root, set, G_BG)
	hall_lights(root, 0.9, 0.0, 0.4)
	return {"camera": camera(root, Vector3(-5.5, 2.4, 5.0), Vector3(1.5, 1.6, -10.5), 44.0), "environment": hall_env(0.9)}


## Façade du Guichet 04 vue du Hall, voisines 03 et 05 (S1 `booth04`).
func _booth04(root: Node3D, set: Dictionary, state: String, agent: bool) -> Dictionary:
	var booths: Array = booth_arc(root, set, 5, ["lit", "off", state, "off", "lit"], false)
	if agent:
		var xf: Transform3D = (booths[2] as Dictionary)["xf"]
		person(root, xf * Vector3(0.1, -0.3, -0.95), rad_to_deg(atan2(xf.basis.z.x, xf.basis.z.z)), 1.0, BB.STEEL, G_BG, "bare", 0.9)
	hall_shell(set, Vector3(0, 0, 2.0))
	return booths[2]


## BG-H3 · le Guichet 04 vu du Hall (PL-F1-3, PL-EA-2, PL-E-FIG).
func bg_h3(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var b04: Dictionary = _booth04(root, set, "lit", false)
	commit(root, set, G_BG)
	hall_lights(root, 1.0)
	return {"camera": camera(root, Vector3(0.6, 1.75, -4.0), Vector3(0, 1.6, -11.0), 40.0), "environment": hall_env(),
			"holo_rects": [b04["glass"]], "labels": [{"id": "booth_04", "text": "04", "points": b04["plaque"]}]}


## FIG de PL-F1-3 : une autre silhouette derrière la vitre du 04.
func layer_pl_f1_3_newcomer(root: Node3D, _info: Dictionary) -> void:
	person(root, Vector3(0.05, -0.3, -11.95), 0.0, 1.0, BB.STEEL.lightened(0.15), G_LAYER, "bare", 0.95)


## MID de PL-EA-2 : file courte devant la vitre.
func layer_pl_ea_2_short_queue(root: Node3D, _info: Dictionary) -> void:
	for k: int in 3:
		person(root, Vector3(-0.7 - k * 0.6, 0, -10.0 + k * 0.7), 180.0 + 8.0 * k, lerpf(0.95, 1.05, hash01(k)), crowd_tint(1511 + k), G_LAYER,
				["bare", "cap", "bare"][k], 0.5)


## BG-H4 · le 04 avec une borne jaune devant la vitre (PL-F1-3 Acte III).
func bg_h4(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var b04: Dictionary = _booth04(root, set, "off", false)
	_borne(set, Vector3(0.0, 0, -9.3), 0.0, 1.0)
	commit(root, set, G_BG)
	hall_lights(root, 1.0)
	omni(root, Vector3(0, 1.6, -8.6), BB.YELLOW.darkened(0.2), 0.9, 3.0)
	return {"camera": camera(root, Vector3(0.6, 1.75, -4.0), Vector3(0, 1.5, -11.0), 40.0), "environment": hall_env(),
			"labels": [{"id": "booth_04", "text": "04", "points": b04["plaque"]}]}


## Borne ACV-3 (jaune Consortium) : socle, colonne, écran émissif vierge.
func _borne(set: Dictionary, pos: Vector3, yaw_deg: float, energy: float) -> void:
	var m: Dictionary = hall_mats()
	var rot: Vector3 = Vector3(0, yaw_deg, 0)
	b(set["lit"], Vector3(0.6, 0.08, 0.5), pos + Vector3(0, 0.04, 0), m["dark"], rot)
	b(set["lit"], Vector3(0.42, 1.3, 0.34), pos + Vector3(0, 0.73, 0), flat(BB.YELLOW.darkened(0.45), 0.4), rot)
	b(set["lit"], Vector3(0.46, 0.04, 0.38), pos + Vector3(0, 1.39, 0), m["chrome"], rot)
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	glow_quad(set["emis"], pos + basis * Vector3(0, 1.08, 0.175), basis * Vector3(0.16, 0, 0), basis * Vector3(0, 0.2, 0), BB.YELLOW, 1.4 * energy)
	glow_quad(set["emis"], pos + basis * Vector3(0, 0.62, 0.175), basis * Vector3(0.12, 0, 0), basis * Vector3(0, 0.025, 0), BB.YELLOW, 1.8 * energy)


## BG-H17 · Hall à 18:00, bornes jaunes allumées (PL-EA-1).
func bg_h17(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 9, ["off"], false)
	hall_shell(set, Vector3(0, 0, 2.0), true)
	for k: int in 5:
		_borne(set, Vector3(-4.0 + k * 2.0, 0, -5.0 - absf(k - 2) * 0.4), 0.0, 1.0)
	commit(root, set, G_BG)
	for k: int in 5:
		omni(root, Vector3(-4.0 + k * 2.0, 1.4, -4.4), BB.YELLOW.darkened(0.15), 0.9, 3.2)
	omni(root, Vector3(0, 4.0, -4), BB.SPILL.darkened(0.3), 0.6, 10.0)
	return {"camera": camera(root, Vector3(0, 2.6, 7.5), Vector3(0, 1.2, -9.0), 46.0),
			"environment": environment(DS.BG_PANEL.lerp(BB.SPILL, 0.15), 0.5, DS.BG_PANEL.lerp(BB.SPILL, 0.1), 0.035, 1.0)}


## BG-H7 · vitre ouverte (PL-F5-2) : le 04 levé, familles derrière.
func bg_h7(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var b04: Dictionary = _booth04(root, set, "open", false)
	commit(root, set, G_BG)
	hall_lights(root, 1.0, 0.2)
	return {"camera": camera(root, Vector3(-1.4, 1.7, -3.2), Vector3(0.2, 1.5, -11.0), 44.0), "environment": hall_env(1.0, 0.2),
			"holo_rects": [b04["glass"]]}


func layer_pl_f5_2_families(root: Node3D, _info: Dictionary) -> void:
	# Familles qui attendent derrière la vitre ouverte (côté gauche de la planche).
	crowd(root, Vector3(-2.6, 0, -8.6), 7, Vector2(1.0, 0.7), 150.0, 1452, G_LAYER)


## BG-H8 · vitre portant la Charte de l'air (PL-F5C-3, PL-EB-1) : gros plan.
func bg_h8(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var b04: Dictionary = _booth04(root, set, "charter", false)
	commit(root, set, G_BG)
	hall_lights(root, 1.0, 0.25)
	return {"camera": camera(root, Vector3(0.25, 1.75, -7.4), Vector3(0, 1.72, -11.0), 40.0), "environment": hall_env(1.0, 0.25),
			"holo_rects": [b04["glass"]]}


## MID de PL-EB-1 : une correction au crayon sur la vitre (trait gras, sans texte).
func layer_pl_eb_1_pencil(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	for k: int in 3:
		glow_quad(set["emis"], Vector3(-0.15 + k * 0.12, 1.86 - k * 0.02, -10.92), Vector3(0.06, 0.004, 0), Vector3(0, 0.006, 0), BB.KEY, 0.9)
	glow_quad(set["emis"], Vector3(0.0, 1.81, -10.92), Vector3(0.24, -0.01, 0), Vector3(0, 0.004, 0), BB.KEY, 0.8)
	commit(root, set, G_LAYER)


## Guichet vu du côté de l'agent·e : comptoir, montants, bandeau, vitre, Hall
## au-delà (barrières de file, mur du fond et baie, néons abstraits sans lettres).
## `glass` : alpha du reflet de vitre. Rend les ancres utiles.
func booth_inside(root: Node3D, set: Dictionary, light: float, dusk: float = 0.0) -> Dictionary:
	var m: Dictionary = hall_mats()
	var plates: Array = lit(BB.L_PLATES, Color(0.62, 0.64, 0.68), 0.9)
	var counter: Array = lit(BB.L_PLATES, Color(0.3, 0.32, 0.36), 0.6)
	for side: float in [-1.0, 1.0]:
		b(set["lit"], Vector3(0.18, 1.62, 0.22), Vector3(1.29 * side, 1.7, 0.0), plates)
		b(set["lit"], Vector3(0.035, 1.5, 0.24), Vector3(1.19 * side, 1.7, 0.0), m["chrome"])
		b(set["lit"], Vector3(0.6, 2.6, 1.6), Vector3(1.7 * side, 1.3, 0.8), m["dark"])
	b(set["lit"], Vector3(2.76, 0.16, 0.22), Vector3(0, 2.46, 0), plates)
	b(set["lit"], Vector3(2.76, 0.12, 0.26), Vector3(0, 0.96, 0), plates)
	b(set["lit"], Vector3(2.4, 0.03, 0.24), Vector3(0, 2.37, 0), m["chrome"])
	b(set["lit"], Vector3(2.8, 0.06, 0.9), Vector3(0, 0.93, 0.55), counter, Vector3.ZERO, 1.2)
	b(set["lit"], Vector3(2.8, 0.9, 0.05), Vector3(0, 0.45, 0.98), m["dark"])
	b(set["lit"], Vector3(0.44, 0.05, 0.32), Vector3(0, 1.02, 0), lit(BB.L_CHROME, Color(0.35, 0.37, 0.4), 1.0))
	# Hygiaphone (anneau chromé, grille perforée) et LED d'information (cyan).
	ring(set["lit"], 0.0, 0.088, 0.0, Transform3D(Basis(), Vector3(-0.4, 1.38, 0.012)), lit(BB.L_PERF, Color.WHITE, 0.0), 24)
	ring(set["lit"], 0.086, 0.12, 0.02, Transform3D(Basis(), Vector3(-0.4, 1.38, 0.02)), m["chrome"], 24)
	# Reflet de vitre (voile holo très léger).
	quad(set["holo"], Vector3(0, 1.7, 0.0), Vector3(1.2, 0, 0), Vector3(0, 0.67, 0), Vector2(0.4, 3), Color(BB.KEY.r, BB.KEY.g, BB.KEY.b, 0.06))
	hall_beyond(root, set, light, dusk)
	return {"glass": [Vector3(-1.2, 2.37, 0), Vector3(1.2, 2.37, 0), Vector3(-1.2, 1.03, 0), Vector3(1.2, 1.03, 0)]}


## Le Hall vu depuis la vitre : sol, barrières de file, colonnes, mur du fond et
## baie sur la ville (vitrages procéduraux), néons de marque **sans lettres**.
func hall_beyond(root: Node3D, set: Dictionary, light: float, dusk: float = 0.0) -> void:
	var m: Dictionary = hall_mats()
	b(set["lit"], Vector3(20, 0.2, 12), Vector3(0, -0.1, -4.5), lit(BB.L_CONCRETE, Color(0.2, 0.21, 0.24), 0.0, 1.0), Vector3.ZERO, 2.5)
	b(set["lit"], Vector3(20, 0.2, 12), Vector3(0, 5.0, -4.5), m["ceiling"])
	b(set["lit"], Vector3(20, 1.0, 0.3), Vector3(0, 0.5, -10.0), m["concrete"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(20, 0.9, 0.3), Vector3(0, 4.55, -10.0), m["concrete"], Vector3.ZERO, 2.0)
	for i: int in 6:
		b(set["lit"], Vector3(0.26, 3.0, 0.34), Vector3(-7.5 + i * 3.0, 2.55, -10.0), m["plates"])
	# Baie : la ville de l'Anneau (vitrages procéduraux du guichet, mode 3).
	quad(set["emis"], Vector3(0, 2.55, -10.3), Vector3(10, 0, 0), Vector3(0, 1.5, 0), Vector2(1.0, 3), Color(BB.WINDOW_TINTS[1].r,
			BB.WINDOW_TINTS[1].g, BB.WINDOW_TINTS[1].b, 37.0 / 255.0))
	for c: Vector3 in [Vector3(3.6, 0, -4.4), Vector3(-4.1, 0, -4.7), Vector3(5.6, 0, -7.0), Vector3(-6.6, 0, -7.6)]:
		b(set["lit"], Vector3(0.62, 4.6, 0.62), c + Vector3(0, 2.3, 0), m["concrete"], Vector3.ZERO, 1.6)
		b(set["lit"], Vector3(0.69, 0.14, 0.69), c + Vector3(0, 0.07, 0), m["hazard"])
	for z: float in [-3.9, -5.2, -6.6]:
		barriers(set, Vector3(-2.6, 0, z), 2, Vector3(1.6, 0, 0))
	# Néons de marque (jaune Consortium), bandeaux teal et rose — sans texte.
	glow_quad(set["emis"], Vector3(1.9, 2.5, -8.8), Vector3(1.6, 0, 0), Vector3(0, 0.03, 0), BB.YELLOW, 1.2)
	glow_quad(set["emis"], Vector3(1.9, 2.25, -8.8), Vector3(1.2, 0, 0), Vector3(0, 0.02, 0), BB.YELLOW.darkened(0.2), 1.0)
	glow_quad(set["emis"], Vector3(-3.4, 2.05, -8.85), Vector3(1.17, 0, 0), Vector3(0, 0.46, 0), BB.TEAL_DIM.darkened(0.55), 0.5, 2)
	glow_quad(set["emis"], Vector3(-4.95, 1.25, -8.6), Vector3(0.9, 0, 0), Vector3(0, 0.03, 0), BB.ROSE_DIM.lightened(0.35), 1.3)
	b(set["lit"], Vector3(3.6, 1.0, 0.06), Vector3(1.9, 2.32, -8.88), flat(Color(0.05, 0.055, 0.065), 0.0))
	omni(root, Vector3(-3.6, 2.4, -7.9), BB.TEAL_DIM, 3.0 * light, 6.0)
	omni(root, Vector3(3.4, 2.2, -7.6), BB.ROSE_DIM.lerp(BB.SPILL, dusk), 2.8 * light, 6.0)
	omni(root, Vector3(0.0, 3.6, -5.0), BB.KEY.lerp(BB.STEEL, 0.5).lerp(BB.SPILL, dusk * 0.7), 2.2 * light, 9.0)
	omni(root, Vector3(-1.8, 2.6, -2.5), BB.KEY.lerp(BB.STEEL, 0.5), 1.2 * light, 5.0)


## Tampon de l'agent·e (debout ou couché) et encreur.
func stamp(set: Dictionary, pos: Vector3, lying: bool, rot_deg: float = 0.0) -> void:
	var handle: Array = flat(Color(0.12, 0.12, 0.14), 0.3)
	var base: Array = lit(BB.L_CHROME, Color(0.55, 0.57, 0.6), 1.0)
	var r: Basis = Basis(Vector3.UP, deg_to_rad(rot_deg))
	if lying:
		r = r * Basis(Vector3.BACK, PI * 0.5)
	cyl(set["lit"], 0.03, 0.11, Transform3D(r, pos + r * Vector3(0, 0.1, 0)), handle, 10)
	box(set["lit"], Vector3(0.11, 0.035, 0.07), Transform3D(r, pos + r * Vector3(0, 0.03, 0)), base[0], base[1])
	box(set["lit"], Vector3(0.1, 0.012, 0.06), Transform3D(r, pos + r * Vector3(0, 0.006, 0)), flat(BB.ROSE_DIM.darkened(0.3))[0],
			flat(BB.ROSE_DIM.darkened(0.3))[1])


## BG-H1 · comptoir du 04 côté agent·e, vitre et Hall (PL-F3-3, PL-EA-3, PL-F8-2).
func bg_h1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var info: Dictionary = booth_inside(root, set, 1.0)
	b(set["lit"], Vector3(0.24, 0.015, 0.16), Vector3(0.42, 0.968, 0.42), flat(Color(0.08, 0.08, 0.1)))
	b(set["lit"], Vector3(0.3, 0.01, 0.22), Vector3(-0.35, 0.965, 0.48), flat(Color(0.72, 0.7, 0.62), 0.0), Vector3(0, 8, 0))
	commit(root, set, G_BG)
	omni(root, Vector3(0.2, 1.95, 0.8), BB.STEEL.lightened(0.35), 2.6, 2.6)
	omni(root, Vector3(0.0, 1.5, 0.6), BB.KEY.lerp(BB.SPILL, 0.2), 1.2, 1.6)
	return {"camera": camera(root, Vector3(0.12, 1.62, 1.35), Vector3(0.0, 1.22, -3.0), 54.0), "environment": hall_env(),
			"holo_rects": [info["glass"]]}


## MID de PL-F3-3 / PL-EA-3 : les mains de l'agent·e sur le tampon (jamais le visage).
func layer_pl_f3_3_hands(root: Node3D, _info: Dictionary) -> void:
	_hands_on_stamp(root)


func layer_pl_ea_3_hands(root: Node3D, _info: Dictionary) -> void:
	_hands_on_stamp(root)


func _hands_on_stamp(root: Node3D) -> void:
	var set: Dictionary = new_set()
	stamp(set, Vector3(0.0, 0.96, 0.38), false)
	commit(root, set, G_LAYER)
	var skin: Color = Color("#8C6A55")
	var sleeve: Color = BB.STEEL.darkened(0.2)
	hand(root, Vector3(0.0, 1.1, 0.56), Vector3(0, -0.6, -1), Vector3(0, 1, 0), 1.0, skin, G_LAYER, sleeve, 0.55)
	hand(root, Vector3(-0.32, 0.99, 0.62), Vector3(0.35, -0.1, -1), Vector3(0, 1, 0), 1.0, skin, G_LAYER, sleeve, 0.2)


## FIG de PL-F8-2 : reflet flou de l'agent·e dans la vitre (silhouette pâle, de face, sans visage).
func layer_pl_f8_2_reflection(root: Node3D, _info: Dictionary) -> void:
	var mi_root: Node3D = Node3D.new()
	root.add_child(mi_root)
	person(mi_root, Vector3(0.05, 0.25, -0.05), 180.0, 0.92, BB.KEY.darkened(0.55), G_LAYER, "bare", 0.35)


## BG-H14 · comptoir dans le noir, tampons posés à plat (PL-F9-3).
func bg_h14(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_inside(root, set, 0.25)
	stamp(set, Vector3(-0.25, 0.96, 0.4), true, 20.0)
	stamp(set, Vector3(0.12, 0.96, 0.46), true, -35.0)
	stamp(set, Vector3(0.42, 0.96, 0.36), true, 70.0)
	commit(root, set, G_BG)
	omni(root, Vector3(0.6, 1.6, 0.9), BB.STEEL.lightened(0.3), 2.0, 2.6)
	omni(root, Vector3(-0.8, 1.3, 0.6), BB.TEAL_DIM, 1.0, 2.0)
	return {"camera": camera(root, Vector3(0.05, 1.5, 1.2), Vector3(0.05, 0.98, -0.2), 44.0),
			"environment": environment(DS.BG_PANEL, 0.55, DS.BG_VOID, 0.03, 1.0)}


## BG-H16 · la vitre au soir, côté agent·e (PL-F10-4).
func bg_h16(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var info: Dictionary = booth_inside(root, set, 0.6, 0.8)
	commit(root, set, G_BG)
	omni(root, Vector3(0.6, 1.5, 0.6), BB.SPILL.darkened(0.1), 1.3, 2.4)
	return {"camera": camera(root, Vector3(-0.35, 1.62, 1.35), Vector3(0.1, 1.2, -0.8), 50.0),
			"environment": environment(DS.BG_PANEL.lerp(BB.SPILL, 0.2), 0.5, DS.BG_PANEL.lerp(BB.ROSE_DIM, 0.2), 0.035, 1.0),
			"holo_rects": [info["glass"]]}


## MID de PL-F10-4 : une main qui range une feuille pliée.
func layer_pl_f10_4_hand(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	b(set["lit"], Vector3(0.21, 0.006, 0.15), Vector3(0.12, 0.975, 0.38), flat(Color(0.8, 0.78, 0.7), 0.0), Vector3(0, -12, 0))
	b(set["lit"], Vector3(0.21, 0.006, 0.15), Vector3(0.13, 0.99, 0.37), flat(Color(0.86, 0.84, 0.76), 0.0), Vector3(-25, -12, 0))
	commit(root, set, G_LAYER)
	hand(root, Vector3(0.22, 1.04, 0.56), Vector3(-0.3, -0.5, -1), Vector3(0, 1, 0), 1.0, Color("#8C6A55"), G_LAYER, BB.STEEL.darkened(0.2), 0.35)


## BG-H2 · la file qui serpente, vue depuis la vitre (PL-F7-4).
func bg_h2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	hall_beyond(root, set, 1.0)
	commit(root, set, G_BG)
	return {"camera": camera(root, Vector3(0.2, 1.62, -0.4), Vector3(-1.6, 1.0, -6.5), 46.0), "environment": hall_env()}


func layer_pl_f7_4_queue(root: Node3D, _info: Dictionary) -> void:
	var slots: Array[Vector2] = [Vector2(-1.32, -3.45), Vector2(-1.95, -4.15), Vector2(-1.40, -4.85), Vector2(-2.25, -5.55),
			Vector2(-1.55, -6.30), Vector2(-2.45, -6.95), Vector2(-2.95, -7.60), Vector2(-3.45, -7.72), Vector2(-3.95, -7.95)]
	for k: int in slots.size():
		var s: Vector2 = slots[k]
		var nxt: Vector2 = slots[maxi(k - 1, 0)] - s if k > 0 else Vector2(0.3, 0.8)
		person(root, Vector3(s.x, 0, s.y), rad_to_deg(atan2(nxt.x, nxt.y)), lerpf(0.94, 1.06, hash01(1471 + k)), crowd_tint(1471 + k),
				G_LAYER, ["bare", "hood", "cap"][int(hash01(k * 5 + 1471) * 2.99)], 0.5)


## BG-H5 · porte du Hall, lecteur de badge rouge (PL-F2-1).
func bg_h5(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = hall_mats()
	b(set["lit"], Vector3(8, 0.2, 6), Vector3(0, -0.1, 0), m["floor"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(8, 4.5, 0.3), Vector3(0, 2.25, -1.5), m["concrete"], Vector3.ZERO, 1.6)
	b(set["lit"], Vector3(2.0, 2.6, 0.12), Vector3(-0.5, 1.3, -1.32), m["plates"])
	b(set["lit"], Vector3(0.04, 2.5, 0.14), Vector3(-0.5, 1.3, -1.26), m["dark"])
	for x: float in [-1.58, 0.58]:
		b(set["lit"], Vector3(0.16, 2.8, 0.3), Vector3(x, 1.4, -1.25), m["chrome"])
	b(set["lit"], Vector3(2.32, 0.18, 0.3), Vector3(-0.5, 2.78, -1.25), m["chrome"])
	b(set["lit"], Vector3(2.2, 0.12, 0.1), Vector3(-0.5, 0.06, -1.22), m["hazard"])
	# Lecteur de badge : boîtier, fente, voyant rouge.
	b(set["lit"], Vector3(0.16, 0.24, 0.06), Vector3(1.0, 1.35, -1.32), m["dark"])
	glow_quad(set["emis"], Vector3(1.0, 1.42, -1.288), Vector3(0.05, 0, 0), Vector3(0, 0.012, 0), DS.STATE_RED, 2.6)
	glow_quad(set["emis"], Vector3(1.0, 1.3, -1.288), Vector3(0.055, 0, 0), Vector3(0, 0.035, 0), DS.STATE_RED.darkened(0.6), 0.8)
	commit(root, set, G_BG)
	omni(root, Vector3(1.0, 1.45, -1.0), DS.STATE_RED, 0.8, 1.6)
	omni(root, Vector3(-1.0, 3.2, 1.0), BB.KEY.lerp(BB.STEEL, 0.5), 1.4, 6.0)
	omni(root, Vector3(-3.0, 1.8, 1.0), BB.TEAL_DIM, 1.4, 5.0)
	return {"camera": camera(root, Vector3(0.6, 1.5, 1.4), Vector3(0.2, 1.3, -1.4), 48.0), "environment": hall_env(0.9)}


func layer_pl_f2_1_hand(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	# Badge tenu entre pouce et index devant le lecteur.
	b(set["lit"], Vector3(0.085, 0.055, 0.004), Vector3(0.96, 1.36, -1.18), flat(Color(0.75, 0.76, 0.78), 0.2), Vector3(0, 0, 8))
	b(set["lit"], Vector3(0.03, 0.022, 0.005), Vector3(0.94, 1.365, -1.177), flat(BB.STEEL), Vector3(0, 0, 8))
	commit(root, set, G_LAYER)
	hand(root, Vector3(0.86, 1.28, -0.98), Vector3(0.35, 0.3, -1.0), Vector3(0, 1, 0), 1.0, Color("#8C6A55"), G_LAYER, BB.STEEL.darkened(0.2), 0.3)


## BG-H10 · écrans de formulaires (PL-F7-3) : rangée d'écrans vierges (Label « 27-B »).
func bg_h10(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = hall_mats()
	b(set["lit"], Vector3(10, 0.2, 6), Vector3(0, -0.1, 0), m["floor"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(10, 4.5, 0.3), Vector3(0, 2.25, -1.6), m["concrete"], Vector3.ZERO, 1.6)
	var holo: Array = []
	for row: int in 2:
		for col: int in 3:
			var c: Vector3 = Vector3(-1.9 + col * 1.9, 1.35 + row * 1.25, -1.42)
			b(set["lit"], Vector3(1.66, 1.06, 0.08), c + Vector3(0, 0, -0.04), flat(Color(0.05, 0.055, 0.065), 0.0))
			glow_quad(set["emis"], c, Vector3(0.78, 0, 0), Vector3(0, 0.48, 0), BB.TEAL_DIM.darkened(0.45), 0.8, 2)
			# Mise en page abstraite d'un formulaire : barres, cases (aucun caractère).
			for k: int in 5:
				glow_quad(set["emis"], c + Vector3(-0.2 + hash01(row * 31 + col * 7 + k) * 0.1, 0.32 - k * 0.15, 0.004),
						Vector3(0.42 + 0.2 * hash01(k + col), 0, 0), Vector3(0, 0.012, 0), BB.TEAL_DIM.lightened(0.4), 1.1)
				glow_quad(set["emis"], c + Vector3(-0.68, 0.32 - k * 0.15, 0.004), Vector3(0.035, 0, 0), Vector3(0, 0.035, 0), BB.TEAL_DIM.lightened(0.3), 1.0)
			holo.append([c + Vector3(-0.78, 0.48, 0), c + Vector3(0.78, 0.48, 0), c + Vector3(-0.78, -0.48, 0), c + Vector3(0.78, -0.48, 0)])
	commit(root, set, G_BG)
	omni(root, Vector3(0, 2.0, 0.8), BB.TEAL_DIM, 1.2, 5.0)
	omni(root, Vector3(0, 3.5, 2.0), BB.KEY.lerp(BB.STEEL, 0.5), 0.9, 7.0)
	return {"camera": camera(root, Vector3(-0.8, 1.9, 3.4), Vector3(0.1, 1.95, -1.4), 50.0), "environment": hall_env(0.9), "holo_rects": holo}


## BG-H11 · haut-parleur du Hall (PL-F8-1, PL-EC-1) : enceinte à pavillon
## fixée à une colonne, vue en contre-plongée ; ondes `HOLO` à l'exécution.
func bg_h11(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = hall_mats()
	b(set["lit"], Vector3(0.7, 7.0, 0.7), Vector3(-1.1, 3.5, -2.0), m["concrete"], Vector3.ZERO, 1.6)
	b(set["lit"], Vector3(0.76, 0.06, 0.76), Vector3(-1.1, 3.0, -2.0), m["chrome"])
	b(set["lit"], Vector3(0.9, 0.1, 0.12), Vector3(-0.55, 4.0, -1.75), m["dark"])
	# Caisson, pavillon carré évasé (4 pans), grille, câble.
	var c: Vector3 = Vector3(0.0, 3.85, -1.6)
	b(set["lit"], Vector3(0.5, 0.42, 0.42), c, m["plates"], Vector3(-14, 22, 0))
	var face: Basis = Basis.from_euler(Vector3(deg_to_rad(-14), deg_to_rad(22), 0))
	for k: int in 4:
		var r: Basis = face * Basis(Vector3.BACK, k * PI * 0.5)
		box(set["lit"], Vector3(0.62, 0.035, 0.5), Transform3D(r * Basis(Vector3.RIGHT, deg_to_rad(-28)), c + face * Vector3(0, 0, 0.21) + r * Vector3(0, 0.27, 0.22)),
				m["plates"][0], m["plates"][1])
	box(set["lit"], Vector3(0.42, 0.34, 0.02), Transform3D(face, c + face * Vector3(0, 0, 0.23)), lit(BB.L_PERF, Color(0.75, 0.77, 0.8), 0.5)[0],
			lit(BB.L_PERF, Color(0.75, 0.77, 0.8), 0.5)[1])
	pipe(set["lit"], 0.025, 1.4, Vector3(-0.5, 4.3, -1.8), Vector3.RIGHT, m["dark"], 8)
	# Fond : mur haut, plafond à bandeaux, enseigne sans lettres.
	b(set["lit"], Vector3(24, 8, 0.3), Vector3(0, 4.0, -8.0), m["panel"])
	b(set["lit"], Vector3(24, 0.3, 14), Vector3(0, 6.6, -2.0), m["ceiling"])
	for k: int in 6:
		glow_quad(set["emis"], Vector3(-7.5 + k * 3.0, 6.44, -2.0), Vector3(0.05, 0, 0), Vector3(0, 0, 3.0), BB.KEY, 0.7)
	glow_quad(set["emis"], Vector3(3.5, 3.4, -7.8), Vector3(1.6, 0, 0), Vector3(0, 0.03, 0), BB.YELLOW, 1.0)
	commit(root, set, G_BG)
	omni(root, Vector3(0.9, 3.4, -0.4), BB.KEY.lerp(BB.STEEL, 0.4), 1.8, 4.5)
	omni(root, Vector3(-2.2, 3.0, -0.8), BB.TEAL_DIM, 2.2, 5.0)
	omni(root, Vector3(2.5, 4.5, -4.0), BB.ROSE_DIM, 2.0, 7.0)
	var cam: Camera3D = camera(root, Vector3(0.9, 2.3, 1.4), Vector3(-0.1, 3.75, -1.7), 42.0)
	return {"camera": cam, "environment": hall_env(),
			"holo_rects": [[Vector3(0.45, 4.35, -1.2), Vector3(1.6, 4.35, -1.2), Vector3(0.45, 3.4, -1.2), Vector3(1.6, 3.4, -1.2)]]}


## BG-H15 · Main courante en hologramme dans le Hall (PL-F10-2).
func bg_h15(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	booth_arc(root, set, 9, ["lit", "off"], true)
	hall_shell(set, Vector3(0, 0, 2.0))
	# Registre holographique : cadre, lignes (numéros en `Label` à l'exécution).
	var c: Vector3 = Vector3(0, 2.6, -4.5)
	quad(set["holo"], c, Vector3(2.0, 0, 0), Vector3(0, 1.3, 0), Vector2(0.8, 1), Color(DS.STATE_GREEN.r, DS.STATE_GREEN.g, DS.STATE_GREEN.b, 0.08))
	for k: int in 9:
		quad(set["holo"], c + Vector3(0.2, 1.0 - k * 0.25, 0.01), Vector3(1.55, 0, 0), Vector3(0, 0.012, 0), Vector2(1.4, 1),
				Color(DS.STATE_GREEN.r, DS.STATE_GREEN.g, DS.STATE_GREEN.b, 0.5))
		quad(set["holo"], c + Vector3(-1.72, 1.0 - k * 0.25, 0.01), Vector3(0.16, 0, 0), Vector3(0, 0.05, 0), Vector2(1.2, 1),
				Color(DS.STATE_GREEN.r, DS.STATE_GREEN.g, DS.STATE_GREEN.b, 0.35))
	for e: float in [-1.0, 1.0]:
		quad(set["holo"], c + Vector3(2.0 * e, 0, 0.01), Vector3(0.012, 0, 0), Vector3(0, 1.3, 0), Vector2(1.6, 1),
				Color(DS.STATE_GREEN.r, DS.STATE_GREEN.g, DS.STATE_GREEN.b, 0.7))
	commit(root, set, G_BG)
	hall_lights(root, 0.85)
	omni(root, c + Vector3(0, 0, 0.6), DS.STATE_GREEN.lerp(BB.TEAL_DIM, 0.6), 0.9, 4.0)
	return {"camera": camera(root, Vector3(0.0, 2.3, 2.6), Vector3(0, 2.5, -6.0), 46.0), "environment": hall_env(0.85),
			"holo_rects": [[c + Vector3(-2.0, 1.3, 0), c + Vector3(2.0, 1.3, 0), c + Vector3(-2.0, -1.3, 0), c + Vector3(2.0, -1.3, 0)]]}


# === S8 · Lieux jamais modélisés (volumes simples, BOOTH_SCENE §19.3, §21) ============

## Adaptateur des constructeurs de la phase 1 (même rendu que les planches témoins).
func _mesh_node(root: Node3D, geo: BB.Geo, mat: Material, group: StringName, additive: bool = false) -> void:
	node(root, geo, mat, group, additive)


var _decor_mat: ShaderMaterial:
	get:
		return decor_mat
var _emissive_mat: ShaderMaterial:
	get:
		return emissive_mat
var _holo_mat: ShaderMaterial:
	get:
		return holo_mat


## BG-X1 · école de l'Anneau C (PL-F10-3, PL-EC-2) : salle, tableau holo vierge,
## pupitres d'origine ; les bancs **ajoutés** et les enfants sont la couche MID.
func bg_x1(root: Node3D) -> Dictionary:
	return _school(root, false)


func layer_pl_f10_3_benches(root: Node3D, _info: Dictionary) -> void:
	_school(root, true)


## MID de PL-EC-2 : registre ouvert sur un pupitre du premier rang.
func layer_pl_ec_2_register(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var c: Vector3 = Vector3(-0.15, 0.77, -3.4)
	b(set["lit"], Vector3(0.62, 0.02, 0.44), c, flat(Color(0.32, 0.2, 0.16), 0.1), Vector3(0, 6, 0))
	for side: float in [-1.0, 1.0]:
		b(set["lit"], Vector3(0.29, 0.012, 0.4), c + Vector3(0.15 * side, 0.016, 0), flat(Color(0.86, 0.84, 0.76), 0.0), Vector3(0, 6, -4.0 * side))
		for k: int in 9:
			b(set["lit"], Vector3(0.2, 0.002, 0.008), c + Vector3(0.15 * side, 0.024, -0.15 + k * 0.035), flat(Color(0.3, 0.3, 0.34), 0.0), Vector3(0, 6, 0))
	commit(root, set, G_LAYER)


func _school(root: Node3D, layer: bool) -> Dictionary:
	var stat: BB.Geo = BB.Geo.new(BB.Geo.LIT)
	var mid: BB.Geo = BB.Geo.new(BB.Geo.LIT)
	var emis: BB.Geo = BB.Geo.new(BB.Geo.EMISSIVE)
	var holo: BB.Geo = BB.Geo.new(BB.Geo.HOLO)
	# Grandes surfaces en aplats (L_FLAT) + joints en géométrie : les couches
	# texturées, vues de loin, deviennent du bruit sous le filtre de Kuwahara.
	var wall_hi: Array = lit(BB.L_FLAT, Color(0.5, 0.56, 0.52), 0.1)
	var wall_lo: Array = lit(BB.L_FLAT, Color(0.3, 0.37, 0.34), 0.15)
	var seam: Array = lit(BB.L_FLAT, Color(0.2, 0.24, 0.23), 0.2)
	var floor_m: Array = lit(BB.L_FLAT, Color(0.3, 0.33, 0.31), 0.15)
	var ceil_m: Array = lit(BB.L_FLAT, Color(0.32, 0.35, 0.34), 0.2)
	var chrome: Array = lit(BB.L_CHROME, Color(0.74, 0.76, 0.78), 1.0)
	var board: Array = lit(BB.L_FLAT, DS.BG_PANEL, 0.4)
	var desk_top: Array = lit(BB.L_FLAT, Color(0.52, 0.5, 0.44), 0.15)
	var seat_m: Array = lit(BB.L_FLAT, Color(0.36, 0.42, 0.4), 0.2)
	var crate: Array = lit(BB.L_FLAT, Color(0.6, 0.4, 0.24), 0.2)
	var plank: Array = lit(BB.L_FLAT, Color(0.62, 0.53, 0.4), 0.05)
	var hazard: Array = lit(BB.L_HAZARD, Color(0.9, 0.9, 0.9), 0.2)
	var shuttle: Array = lit(BB.L_FLAT, Color(0.42, 0.46, 0.58), 0.25)
	var odd_desk: Array = lit(BB.L_FLAT, BB.ROSE_DIM.lightened(0.15), 0.2)
	var lamp: Color = BB.KEY.lerp(BB.SPILL, 0.35)
	# Coque de la salle : x ∈ [-4,5 ; 4,5], z ∈ [-11 ; 1,5], y ∈ [0 ; 2,9].
	box(stat, Vector3(9.4, 0.2, 13), Transform3D(Basis(), Vector3(0, -0.1, -4.75)), floor_m[0], floor_m[1])
	for k: int in 11:
		box(stat, Vector3(9.0, 0.004, 0.025), Transform3D(Basis(), Vector3(0, 0.002, -10.5 + k * 1.2)), seam[0], seam[1])
	box(stat, Vector3(9.4, 0.2, 13), Transform3D(Basis(), Vector3(0, 3.0, -4.75)), ceil_m[0], ceil_m[1])
	for k: int in 11:
		box(stat, Vector3(9.0, 0.03, 0.04), Transform3D(Basis(), Vector3(0, 2.89, -10.5 + k * 1.2)), seam[0], seam[1])
	# Murs : soubassement sombre, rail chromé à 1 m, partie haute claire.
	box(stat, Vector3(9.4, 1.0, 0.2), Transform3D(Basis(), Vector3(0, 0.5, -11.1)), wall_lo[0], wall_lo[1])
	box(stat, Vector3(9.4, 2.0, 0.2), Transform3D(Basis(), Vector3(0, 2.0, -11.1)), wall_hi[0], wall_hi[1])
	box(stat, Vector3(0.2, 1.0, 13), Transform3D(Basis(), Vector3(-4.6, 0.5, -4.75)), wall_lo[0], wall_lo[1])
	box(stat, Vector3(0.2, 2.0, 13), Transform3D(Basis(), Vector3(-4.6, 2.0, -4.75)), wall_hi[0], wall_hi[1])
	box(stat, Vector3(0.06, 0.05, 13), Transform3D(Basis(), Vector3(-4.48, 1.0, -4.75)), chrome[0], chrome[1])
	box(stat, Vector3(9.0, 0.05, 0.06), Transform3D(Basis(), Vector3(0, 1.0, -10.98)), chrome[0], chrome[1])
	for k: int in 9:
		box(stat, Vector3(0.03, 3.0, 0.04), Transform3D(Basis(), Vector3(-4.49, 1.5, -10.5 + k * 1.5)), seam[0], seam[1])
	# Dessins d'enfants punaisés (aplats, sans texte) sur le mur gauche.
	var paper_tints: Array[Color] = [BB.KEY, BB.WINDOW_TINTS[0], BB.WINDOW_TINTS[1], BB.KEY.lerp(DS.STATE_GREEN, 0.25), BB.WINDOW_TINTS[3], BB.KEY]
	for k: int in paper_tints.size():
		var c: Vector3 = Vector3(-4.48, 1.55 + 0.18 * hash01(k * 5), -9.6 + k * 0.62)
		var p: Array = lit(BB.L_FLAT, paper_tints[k].darkened(0.1), 0.0)
		box(stat, Vector3(0.01, 0.34, 0.44), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lerpf(-5.0, 5.0, hash01(k)))), c), p[0], p[1])
	# Mur droit : baie basse sur l'Anneau (vitrages procéduraux lointains, D-073).
	box(stat, Vector3(0.2, 1.0, 13), Transform3D(Basis(), Vector3(4.6, 0.5, -4.75)), wall_lo[0], wall_lo[1])
	box(stat, Vector3(0.2, 0.9, 13), Transform3D(Basis(), Vector3(4.6, 2.45, -4.75)), wall_hi[0], wall_hi[1])
	for k: int in 9:
		box(stat, Vector3(0.12, 1.0, 0.1), Transform3D(Basis(), Vector3(4.55, 1.5, -10.6 + k * 1.5)), chrome[0], chrome[1])
	# Au-delà : l'autre rive de l'Anneau (fond sombre, fenêtres éparses par hachage).
	# (Les rayons qui passent par la baie filent vers le fond de la salle : la rive
	# opposée couvre z ∈ [-90 ; 20].)
	box(emis, Vector3(0.1, 40.0, 110.0), Transform3D(Basis(), Vector3(16.0, 1.5, -35.0)), Vector2(1.2, 0),
			Color(DS.BG_ELEVATED.r, DS.BG_ELEVATED.g, DS.BG_ELEVATED.b, 0))
	for k: int in 220:
		if hash01(k * 7 + 2) < 0.45:
			continue
		var wt: Color = BB.WINDOW_TINTS[k % BB.WINDOW_TINTS.size()]
		var wp: Vector3 = Vector3(15.8, lerpf(-4.0, 3.0, hash01(k * 3 + 1)), lerpf(-85.0, 10.0, hash01(k * 5 + 9)))
		box(emis, Vector3(0.05, 0.9, 0.7), Transform3D(Basis(), wp), Vector2(lerpf(1.6, 3.0, hash01(k)), 0), Color(wt.r, wt.g, wt.b, 0))
	# Conduites au plafond et luminaires chauds (une rangée de pavés de chaque côté).
	for x: float in [-3.6, 3.7]:
		box(stat, Vector3(0.16, 0.16, 12.5), Transform3D(Basis(), Vector3(x, 2.72, -4.75)), chrome[0], chrome[1], 0.6)
	for x: float in [-1.6, 1.6]:
		for k: int in 6:
			var z: float = -10.0 + k * 1.6
			box(stat, Vector3(0.34, 0.06, 1.1), Transform3D(Basis(), Vector3(x, 2.86, z)), chrome[0], chrome[1])
			quad(emis, Vector3(x, 2.825, z), Vector3(0.12, 0, 0), Vector3(0, 0, 0.5), Vector2(1.25, 0), Color(lamp.r, lamp.g, lamp.b, 0))
	# Tableau holographique (vierge : le contenu est posé à l'exécution, ancre HOLO).
	box(stat, Vector3(3.8, 1.6, 0.06), Transform3D(Basis(), Vector3(-0.3, 1.75, -10.97)), board[0], board[1])
	box(stat, Vector3(3.9, 0.05, 0.1), Transform3D(Basis(), Vector3(-0.3, 0.93, -10.94)), chrome[0], chrome[1])
	quad(holo, Vector3(-0.3, 1.75, -10.93), Vector3(1.85, 0, 0), Vector3(0, 0.75, 0), Vector2(0.5, 4),
			Color(DS.STATE_GREEN.r, DS.STATE_GREEN.g, DS.STATE_GREEN.b, 0.22))
	# Bancs d'origine : 4 rangées × 3 pupitres (plateau, banc, pieds chromés).
	var seats: Array[Vector3] = []
	for row: int in 4:
		for col: int in 3:
			var c: Vector3 = Vector3(-2.7 + col * 2.6, 0, -9.2 + row * 1.5)
			_desk(stat, c, 1.7, desk_top, seat_m, chrome)
			for s: int in 2:
				seats.append(c + Vector3(-0.42 + s * 0.84, 0.45, 0.48))
	if not layer:
		return _school_finish(root, stat, mid, emis, holo, lamp)
	# Bancs ajoutés, dépareillés, au fond de la salle (premier plan) : caisses de
	# fret + planche, rangée de sièges de navette à sangles jaunes, pupitre rose.
	for c: Vector3 in [Vector3(-2.5, 0, -3.15), Vector3(1.5, 0, -3.05)]:
		box(mid, Vector3(0.5, 0.4, 0.45), Transform3D(Basis(), c + Vector3(-0.62, 0.2, 0)), crate[0], crate[1])
		box(mid, Vector3(0.5, 0.4, 0.45), Transform3D(Basis(), c + Vector3(0.62, 0.2, 0)), crate[0], crate[1])
		box(mid, Vector3(0.52, 0.06, 0.47), Transform3D(Basis(), c + Vector3(-0.62, 0.12, 0)), hazard[0], hazard[1], 0.4)
		box(mid, Vector3(0.52, 0.06, 0.47), Transform3D(Basis(), c + Vector3(0.62, 0.12, 0)), hazard[0], hazard[1], 0.4)
		box(mid, Vector3(2.0, 0.05, 0.36), Transform3D(Basis(), c + Vector3(0, 0.425, 0)), plank[0], plank[1])
		for s: int in 3:
			seats.append(c + Vector3(-0.62 + s * 0.62, 0.45, 0))
	for k: int in 4:
		var c: Vector3 = Vector3(-3.2 + k * 0.66, 0, -2.0)
		box(mid, Vector3(0.6, 0.08, 0.5), Transform3D(Basis(), c + Vector3(0, 0.42, 0)), shuttle[0], shuttle[1])
		box(mid, Vector3(0.58, 0.46, 0.07), Transform3D(Basis(), c + Vector3(0, 0.69, 0.24)), shuttle[0], shuttle[1])
		box(mid, Vector3(0.6, 0.06, 0.09), Transform3D(Basis(), c + Vector3(0, 0.86, 0.27)), hazard[0], hazard[1], 0.3)
		seats.append(c + Vector3(0, 0.46, -0.04))
	box(mid, Vector3(2.7, 0.06, 0.5), Transform3D(Basis(), Vector3(-2.21, 0.04, -2.0)), chrome[0], chrome[1])
	_desk(mid, Vector3(-3.85, 0, -10.0), 0.9, odd_desk, seat_m, chrome)
	seats.append(Vector3(-3.85, 0.45, -9.52))
	# Enfants : silhouettes anonymes de dos (épaules, tête, coiffure) ; présence,
	# taille, coiffure et teinte par hachage (déterministe). Aucun visage (D-185).
	var child_tints: Array[Color] = [Color("#3B4252"), Color("#5B4A3F"), Color("#2F4A4C"), Color("#4C3A4F"), Color("#6B6355"), Color("#2E3A55")]
	for k: int in seats.size():
		if hash01(k * 13 + 5) < 0.16:
			continue
		var s: Vector3 = seats[k] + Vector3(lerpf(-0.05, 0.05, hash01(k * 3)), 0, 0)
		_child(root, s, lerpf(0.86, 1.06, hash01(k * 17 + 1)), child_tints[k % child_tints.size()], int(hash01(k * 31 + 7) * 4.0), lerpf(-10.0, 10.0, hash01(k * 29)))
	# Deux enfants debout près de l'entrée (arrivés sans place).
	for k: int in 2:
		person(root, Vector3(2.9 + k * 0.55, 0, -1.3 - k * 0.35), 180.0 + (k * 2 - 1) * 12.0, 0.64,
				child_tints[(k + 2) % child_tints.size()], G_LAYER, "bare", 0.5)
	_mesh_node(root, mid, _decor_mat, G_LAYER)
	return {}


func _school_finish(root: Node3D, stat: BB.Geo, _mid: BB.Geo, emis: BB.Geo, holo: BB.Geo, lamp: Color) -> Dictionary:
	_mesh_node(root, stat, _decor_mat, G_BG)
	_mesh_node(root, emis, _emissive_mat, G_BG)
	_mesh_node(root, holo, _holo_mat, G_BG, true)
	for z: float in [-9.0, -5.5, -2.0]:
		omni(root, Vector3(-1.6, 2.6, z), lamp, 1.3, 5.5)
		omni(root, Vector3(1.6, 2.6, z), lamp, 1.3, 5.5)
	omni(root, Vector3(-0.3, 1.8, -10.2), DS.STATE_GREEN.lerp(BB.TEAL_DIM, 0.6), 1.2, 4.5)
	var cam: Camera3D = camera(root, Vector3(0.9, 1.8, 1.2), Vector3(-0.4, 0.95, -10.0), 50.0)
	return {
		"camera": cam, "environment": environment(DS.BG_ELEVATED.lerp(BB.SPILL, 0.1), 0.8, DS.BG_PANEL.lerp(DS.STATE_GREEN, 0.06), 0.03, 1.05),
		"holo_rects": [[Vector3(-2.15, 2.5, -10.93), Vector3(1.55, 2.5, -10.93), Vector3(-2.15, 1.0, -10.93), Vector3(1.55, 1.0, -10.93)]],
	}


## Enfant assis vu de dos : buste aplati, épaules, tête, coiffure (0 courte,
## 1 queue de cheval, 2 capuche, 3 chignon). `h` : échelle de taille.
func _child(root: Node3D, seat: Vector3, h: float, tint: Color, hair: int, tilt_deg: float) -> void:
	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.12
	torso.height = 0.48
	prim(root, torso, Transform3D(Basis.from_scale(Vector3(1.3, 1.0, 0.8) * h), seat + Vector3(0, 0.24 * h, 0)), tint, G_LAYER)
	var shoulders: CapsuleMesh = CapsuleMesh.new()
	shoulders.radius = 0.07
	shoulders.height = 0.38
	prim(root, shoulders, Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3.ONE * h), seat + Vector3(0, 0.43 * h, 0)), tint, G_LAYER)
	var head_pos: Vector3 = seat + Vector3(0, 0.6 * h, 0.01)
	var tilt: Basis = Basis(Vector3.FORWARD, deg_to_rad(tilt_deg))
	var neck: CapsuleMesh = CapsuleMesh.new()
	neck.radius = 0.04
	neck.height = 0.14
	prim(root, neck, Transform3D(Basis.from_scale(Vector3.ONE * h), seat + Vector3(0, 0.5 * h, 0.0)),
			tint.lerp(BB.SPILL, 0.2).darkened(0.1), G_LAYER)
	# Vue de dos : la tête est la coiffure (ou la capuche), sans visage.
	var hair_tint: Color = DS.BG_ELEVATED.lerp(tint, 0.3)
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.1 if hair != 2 else 0.12
	head.height = 0.21 if hair != 2 else 0.24
	# Rim faible sur la tête : un anneau clair autour d'un disque sombre se lit comme un visage.
	prim(root, head, Transform3D(tilt.scaled(Vector3.ONE * h), head_pos), tint.darkened(0.12) if hair == 2 else hair_tint, G_LAYER, 0.12)
	if hair == 1 or hair == 3:
		var tail: SphereMesh = SphereMesh.new()
		# Chignon au sommet, queue de cheval sur la nuque : jamais au centre de la tête
		# (un disque cerné d'encre au milieu se lirait comme un visage).
		tail.radius = 0.05 if hair == 3 else 0.035
		tail.height = 0.1 if hair == 3 else 0.17
		var off: Vector3 = Vector3(0, 0.115, -0.01) if hair == 3 else Vector3(0, -0.12, 0.06)
		prim(root, tail, Transform3D(tilt.scaled(Vector3.ONE * h), head_pos + tilt * off * h), hair_tint, G_LAYER, 0.12)


func _desk(geo: BB.Geo, c: Vector3, w: float, top: Array, seat: Array, legs: Array) -> void:
	box(geo, Vector3(w, 0.05, 0.45), Transform3D(Basis(), c + Vector3(0, 0.74, 0)), top[0], top[1])
	box(geo, Vector3(w, 0.32, 0.03), Transform3D(Basis(), c + Vector3(0, 0.56, -0.21)), top[0], top[1])
	box(geo, Vector3(w, 0.05, 0.3), Transform3D(Basis(), c + Vector3(0, 0.43, 0.5)), seat[0], seat[1])
	for sx: float in [-0.5, 0.5]:
		box(geo, Vector3(0.05, 0.74, 0.05), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.37, -0.15)), legs[0], legs[1])
		box(geo, Vector3(0.05, 0.43, 0.05), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.215, 0.55)), legs[0], legs[1])
		box(geo, Vector3(0.04, 0.04, 0.75), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.06, 0.2)), legs[0], legs[1])



# === S2 · Quai 2 / Transit-7 ; S3 · quai 6, écluse 9, cargo ==========================

func dock_mats(rust: float = 0.0) -> Dictionary:
	var hull: Color = Color(0.46, 0.48, 0.52).lerp(Color(0.48, 0.3, 0.2), rust)
	return {
		"floor": lit(BB.L_PLATES, Color(0.32, 0.33, 0.36).lerp(Color(0.34, 0.27, 0.22), rust * 0.6), 0.25, 0.2),
		"wall": lit(BB.L_FLAT, Color(0.4, 0.42, 0.46).lerp(Color(0.44, 0.3, 0.22), rust), 0.2),
		"hull": lit(BB.L_PLATES, hull, 0.3),
		"beam": lit(BB.L_FLAT, Color(0.22, 0.24, 0.27).lerp(Color(0.3, 0.2, 0.14), rust), 0.6),
		"hazard": lit(BB.L_HAZARD, Color(0.85, 0.85, 0.85), 0.2),
		"chrome": lit(BB.L_CHROME, Color(0.7, 0.72, 0.76), 1.0),
		"crate": lit(BB.L_FLAT, Color(0.42, 0.36, 0.26).lerp(Color(0.5, 0.3, 0.18), rust), 0.2),
		"dark": lit(BB.L_FLAT, Color(0.1, 0.11, 0.13), 0.3),
		"glass": lit(BB.L_FLAT, DS.BG_ELEVATED, 0.85),
	}


## Hangar de quai : dalle, bandes de danger, mur du fond percé d'une baie sur
## l'espace (étoiles), collier d'arrimage, piliers, poutres, poste de Garde.
func dock_hangar(root: Node3D, set: Dictionary, rust: float, opening: bool = true) -> void:
	var m: Dictionary = dock_mats(rust)
	b(set["lit"], Vector3(36, 0.3, 26), Vector3(0, -0.15, -2), m["floor"], Vector3.ZERO, 2.0)
	for x: float in [-5.0, 5.0]:
		b(set["lit"], Vector3(0.3, 0.012, 22), Vector3(x, 0.006, -2), lit(BB.L_FLAT, BB.YELLOW.darkened(0.35), 0.2))
	b(set["lit"], Vector3(14, 0.02, 0.4), Vector3(0, 0.01, -8.5), m["hazard"], Vector3.ZERO, 0.5)
	# Mur du fond : baie (ouverture) entre deux panneaux, rebords.
	var wall_z: float = -12.0
	if opening:
		b(set["lit"], Vector3(8, 9, 0.6), Vector3(-10, 4.5, wall_z), m["wall"], Vector3.ZERO, 1.5)
		b(set["lit"], Vector3(8, 9, 0.6), Vector3(10, 4.5, wall_z), m["wall"], Vector3.ZERO, 1.5)
		b(set["lit"], Vector3(12, 2.0, 0.6), Vector3(0, 8.0, wall_z), m["wall"], Vector3.ZERO, 1.5)
		b(set["lit"], Vector3(12, 1.2, 0.6), Vector3(0, 0.6, wall_z), m["wall"], Vector3.ZERO, 1.5)
		b(set["lit"], Vector3(12, 0.12, 0.8), Vector3(0, 7.0, wall_z + 0.1), m["chrome"])
		b(set["lit"], Vector3(12, 0.12, 0.8), Vector3(0, 1.2, wall_z + 0.1), m["chrome"])
		for k: int in 160:
			var sp: Vector3 = Vector3(lerpf(-20, 20, hash01(k * 3 + 1)), lerpf(-4, 14, hash01(k * 5 + 2)), -40.0)
			var sz: float = lerpf(0.03, 0.09, hash01(k * 7))
			glow_quad(set["emis"], sp, Vector3(sz, 0, 0), Vector3(0, sz, 0), BB.KEY.lerp(BB.WINDOW_TINTS[k % 4], 0.3), lerpf(0.8, 2.0, hash01(k)))
	else:
		b(set["lit"], Vector3(28, 9, 0.6), Vector3(0, 4.5, wall_z), m["wall"], Vector3.ZERO, 1.5)
	for x: float in [-6.2, 6.2, -13.0, 13.0]:
		b(set["lit"], Vector3(0.8, 9, 0.8), Vector3(x, 4.5, wall_z + 0.6), m["beam"])
		b(set["lit"], Vector3(0.9, 0.5, 0.9), Vector3(x, 0.25, wall_z + 0.6), m["hazard"], Vector3.ZERO, 0.5)
	for z: float in [-9.0, -4.0, 1.0]:
		b(set["lit"], Vector3(30, 0.5, 0.4), Vector3(0, 8.6, z), m["beam"])
	b(set["lit"], Vector3(30, 0.3, 26), Vector3(0, 9.1, -2), m["dark"])
	# Collier d'arrimage (droite) : anneau épais, vérins.
	var collar: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(9.5, 3.2, -6.0))
	ring(set["lit"], 1.6, 2.3, 0.5, collar, m["chrome"], 28)
	ring(set["lit"], 0.0, 1.6, 0.0, collar * Transform3D(Basis(), Vector3(0, 0, -0.3)), m["dark"], 28)
	for k: int in 6:
		var a: float = TAU * k / 6.0
		pipe(set["lit"], 0.09, 1.6, Vector3(8.8, 3.2 + sin(a) * 2.6, -6.0 + cos(a) * 2.6), Vector3.RIGHT, m["chrome"], 8)
	# Poste de la Garde (gauche) : cabine, vitre allumée, gyrophare jaune éteint.
	b(set["lit"], Vector3(2.2, 2.4, 2.0), Vector3(-8.5, 1.2, -6.5), m["wall"])
	glow_quad(set["emis"], Vector3(-7.39, 1.6, -6.5), Vector3(0, 0, 0.7), Vector3(0, 0.4, 0), BB.KEY.lerp(BB.SPILL, 0.4), 0.9)
	b(set["lit"], Vector3(0.3, 0.2, 0.3), Vector3(-8.5, 2.5, -6.5), lit(BB.L_FLAT, BB.YELLOW.darkened(0.3), 0.3))
	# Caisses empilées, plots.
	for k: int in 7:
		var c: Vector3 = Vector3(-11.0 + (k % 3) * 1.25, 0.5 + floorf(k / 3.0) * 1.0, -2.0 - (k % 2) * 1.1)
		b(set["lit"], Vector3(1.2, 1.0, 1.0), c, m["crate"], Vector3(0, hash01(k) * 8.0, 0))
	for k: int in 6:
		glow_quad(set["emis"], Vector3(-4.0 + k * 1.6, 0.02, -8.2), Vector3(0.25, 0, 0), Vector3(0, 0, -0.04), BB.SPILL, 1.4)


func dock_lights(root: Node3D, rust: float, scale: float = 1.0) -> void:
	var sodium: Color = BB.SPILL.lerp(Color("#E0A060"), 0.5 + rust * 0.3)
	for x: float in [-7.0, 0.0, 7.0]:
		omni(root, Vector3(x, 7.6, -4.0), sodium, 3.2 * scale, 14.0)
		omni(root, Vector3(x, 6.0, -10.5), sodium, 1.6 * scale, 6.0)
	omni(root, Vector3(9.0, 3.0, -4.0), BB.KEY.lerp(BB.STEEL, 0.4), 1.4 * scale, 7.0)
	omni(root, Vector3(-8.0, 2.4, -4.5), BB.KEY.lerp(BB.SPILL, 0.4), 1.0 * scale, 5.0)
	omni(root, Vector3(0, 3.0, 4.0), BB.TEAL_DIM, 1.2 * scale, 10.0)


func dock_env(rust: float = 0.0, fog: float = 0.025) -> Environment:
	return environment(DS.BG_ELEVATED.lerp(BB.SPILL, 0.15 + rust * 0.15), 0.6, DS.BG_PANEL.lerp(BB.SPILL, 0.08 + rust * 0.1), fog, 1.05)


## BG-Q1 · quai 2 (PL-F4-1, PL-F5B-1, PL-F7-2, PL-F10-1) : hangar, baie vide.
func bg_q1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	dock_hangar(root, set, 0.0)
	commit(root, set, G_BG)
	dock_lights(root, 0.0)
	return {"camera": camera(root, Vector3(-1.5, 2.1, 9.0), Vector3(1.0, 2.6, -12.0), 50.0), "environment": dock_env()}


## MID de PL-F10-1 : la Transit-7 arrimée dans la baie (coque, hublots éclairés).
func layer_pl_f10_1_transit7(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var m: Dictionary = dock_mats()
	var c: Vector3 = Vector3(0.5, 4.0, -16.0)
	pipe(set["lit"], 2.6, 16.0, c, Vector3.RIGHT, m["hull"], 24)
	pipe(set["lit"], 2.2, 2.0, c + Vector3(-9.0, 0, 0), Vector3.RIGHT, m["hull"], 24)
	pipe(set["lit"], 1.5, 1.6, c + Vector3(-10.6, 0, 0), Vector3.RIGHT, m["chrome"], 20)
	for k: int in 9:
		disc(set["emis"], 0.18, Transform3D(Basis(), c + Vector3(-6.0 + k * 1.5, 0.4, 2.62)), Vector2(1.6, 0), Color(BB.SPILL.r, BB.SPILL.g, BB.SPILL.b, 0), 12)
	b(set["lit"], Vector3(16.0, 0.25, 0.3), c + Vector3(0, -1.2, 2.5), lit(BB.L_FLAT, BB.ROSE_DIM.lightened(0.15), 0.3))
	# Passerelle vers le collier (droite).
	b(set["lit"], Vector3(3.0, 0.2, 1.2), Vector3(8.0, 3.0, -9.0), m["chrome"], Vector3(0, -30, 0))
	commit(root, set, G_LAYER)
	for x: float in [-5.0, 1.0, 7.0]:
		omni(root, c + Vector3(x, 1.5, 4.0), BB.SPILL.lerp(BB.KEY, 0.4), 2.6, 7.0)


## FIG de PL-F4-1 : deux Gardes qui emmènent quelqu'un vers la droite (silhouettes).
func layer_pl_f4_1_guards(root: Node3D, _info: Dictionary) -> void:
	person(root, Vector3(2.4, 0, -1.0), 90.0, 1.03, Color("#4A515C"), G_LAYER, "guard", 0.6)
	person(root, Vector3(4.6, 0, -1.4), 90.0, 1.05, Color("#4A515C"), G_LAYER, "guard", 0.6)


## BG-Q2 · réservoirs de la Transit-7 (PL-F5S-1) : trois cuves, volants, conduites.
func bg_q2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = dock_mats(0.15)
	b(set["lit"], Vector3(16, 0.3, 14), Vector3(0, -0.15, -3), m["floor"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(16, 6, 0.4), Vector3(0, 3, -9), m["wall"], Vector3.ZERO, 1.5)
	b(set["lit"], Vector3(16, 0.3, 14), Vector3(0, 6.1, -3), m["dark"])
	for k: int in 3:
		var c: Vector3 = Vector3(-3.4 + k * 3.4, 1.6, -5.0)
		pipe(set["lit"], 1.35, 7.0, c, Vector3.BACK, m["hull"], 24)
		ring(set["lit"], 0.0, 1.35, 0.0, Transform3D(Basis(), c + Vector3(0, 0, 3.5)), m["hull"], 24)
		for z: float in [-1.5, 1.5]:
			ring(set["lit"], 1.33, 1.45, 0.12, Transform3D(Basis(), c + Vector3(0, 0, z)), m["chrome"], 24)
		# Vanne ouverte : volant sur le dôme avant, conduite vers le haut.
		var v: Transform3D = Transform3D(Basis(), c + Vector3(0, 0.0, 3.62))
		ring(set["lit"], 0.28, 0.34, 0.04, v, lit(BB.L_FLAT, DS.STATE_RED.darkened(0.45), 0.4), 18)
		for s: int in 3:
			b(set["lit"], Vector3(0.6, 0.04, 0.04), c + Vector3(0, 0, 3.64), lit(BB.L_FLAT, DS.STATE_RED.darkened(0.45), 0.4), Vector3(0, 0, s * 60))
		cyl(set["lit"], 0.16, 3.0, Transform3D(Basis(), c + Vector3(0, 2.8, 2.6)), m["chrome"], 10)
		glow_quad(set["emis"], c + Vector3(0.7, 0.9, 3.4), Vector3(0.08, 0, 0), Vector3(0, 0.05, 0), DS.STATE_GREEN, 2.0)
	for y: float in [4.6, 5.2]:
		pipe(set["lit"], 0.2, 16.0, Vector3(0, y, -2.0 - (y - 4.6) * 2.0), Vector3.RIGHT, m["chrome"], 10)
	commit(root, set, G_BG)
	omni(root, Vector3(0, 5.0, 0.0), BB.SPILL.lerp(BB.KEY, 0.3), 3.0, 12.0)
	omni(root, Vector3(0, 2.0, 3.5), BB.KEY.lerp(BB.STEEL, 0.4), 1.8, 6.0)
	omni(root, Vector3(-5, 2.0, 1.0), BB.TEAL_DIM, 1.4, 8.0)
	omni(root, Vector3(5, 2.0, 1.0), BB.ROSE_DIM, 1.2, 8.0)
	return {"camera": camera(root, Vector3(1.2, 1.4, 6.5), Vector3(-0.4, 1.9, -4.0), 52.0), "environment": dock_env(0.15)}


## Cabine de navette (Transit-7) : sièges, cloison à hublot sur l'espace.
func shuttle_cabin(root: Node3D, set: Dictionary) -> Dictionary:
	var m: Dictionary = dock_mats()
	b(set["lit"], Vector3(6, 0.2, 6), Vector3(0, -0.1, -1), m["floor"])
	b(set["lit"], Vector3(6, 0.2, 6), Vector3(0, 2.5, -1), lit(BB.L_FLAT, Color(0.5, 0.52, 0.56), 0.2))
	# Cloison du fond avec hublot (centre-haut de la planche).
	var pz: float = -3.0
	var hp: Vector3 = Vector3(0.0, 1.55, pz)
	wall_with_hole(set, Vector3(0, 1.25, pz - 0.1), Vector2(6.0, 2.5), hp + Vector3(0, 0, -0.1), 0.46, flat(Color(0.56, 0.58, 0.62), 0.2))
	ring(set["lit"], 0.42, 0.58, 0.12, Transform3D(Basis(), hp + Vector3(0, 0, 0.0)), m["chrome"], 28)
	space_backdrop(set, hp + Vector3(0, 0, -30.0), 9.0, 90)
	b(set["lit"], Vector3(0.2, 2.5, 6), Vector3(-2.6, 1.25, -1), lit(BB.L_PLATES, Color(0.5, 0.52, 0.56), 0.5))
	b(set["lit"], Vector3(0.2, 2.5, 6), Vector3(2.6, 1.25, -1), lit(BB.L_PLATES, Color(0.5, 0.52, 0.56), 0.5))
	# Rangées de sièges (dos vers la caméra) avec sangles jaunes.
	for row: int in 2:
		for col: int in 4:
			if col == 1 or col == 2:
				pass
			var c: Vector3 = Vector3(-1.8 + col * 1.2 + (0.25 if col >= 2 else 0.0), 0, -0.5 - row * 1.3)
			b(set["lit"], Vector3(0.55, 0.1, 0.5), c + Vector3(0, 0.45, 0), lit(BB.L_FLAT, Color(0.42, 0.46, 0.58), 0.25))
			b(set["lit"], Vector3(0.55, 0.7, 0.1), c + Vector3(0, 0.82, 0.24), lit(BB.L_FLAT, Color(0.42, 0.46, 0.58), 0.25))
			b(set["lit"], Vector3(0.56, 0.06, 0.12), c + Vector3(0, 1.08, 0.26), m["hazard"])
			b(set["lit"], Vector3(0.05, 0.45, 0.05), c + Vector3(0, 0.22, 0), m["chrome"])
	glow_quad(set["emis"], Vector3(0, 2.38, -1.0), Vector3(1.6, 0, 0), Vector3(0, 0, 0.05), BB.KEY, 0.9)
	return {"porthole": hp}


## BG-Q3 · cabine de la Transit-7, hublot sur l'espace (PL-F2-3, PL-F6T-1).
func bg_q3(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	shuttle_cabin(root, set)
	commit(root, set, G_BG)
	omni(root, Vector3(0, 2.2, 0.5), BB.KEY.lerp(BB.STEEL, 0.3), 1.6, 5.0)
	omni(root, Vector3(-2.0, 1.5, -2.0), BB.TEAL_DIM, 1.0, 4.0)
	omni(root, Vector3(2.0, 1.5, -2.0), BB.SPILL, 0.8, 4.0)
	return {"camera": camera(root, Vector3(0.2, 1.62, 2.4), Vector3(0.05, 1.35, -3.0), 50.0), "environment": dock_env(0.0, 0.01)}


## Cloison (plan XY, épaisseur 0,2 m) percée d'une ouverture carrée de demi-côté
## `hole` autour de `center` (le hublot rond la recouvre) : on voit au travers.
func wall_with_hole(set: Dictionary, pos: Vector3, size: Vector2, center: Vector3, hole: float, m: Array) -> void:
	var left: float = pos.x - size.x * 0.5
	var right: float = pos.x + size.x * 0.5
	var bottom: float = pos.y - size.y * 0.5
	var top: float = pos.y + size.y * 0.5
	var z: float = pos.z
	b(set["lit"], Vector3(center.x - hole - left, size.y, 0.2), Vector3((left + center.x - hole) * 0.5, pos.y, z), m)
	b(set["lit"], Vector3(right - center.x - hole, size.y, 0.2), Vector3((right + center.x + hole) * 0.5, pos.y, z), m)
	b(set["lit"], Vector3(hole * 2.0, top - center.y - hole, 0.2), Vector3(center.x, (top + center.y + hole) * 0.5, z), m)
	b(set["lit"], Vector3(hole * 2.0, center.y - hole - bottom, 0.2), Vector3(center.x, (bottom + center.y - hole) * 0.5, z), m)


## Fond d'espace lointain derrière un hublot (aplat noir + étoiles) : les couches
## posées entre le hublot et ce fond (Halcyon, feux de cargos) restent visibles.
func space_backdrop(set: Dictionary, c: Vector3, half: float, stars: int) -> void:
	b(set["lit"], Vector3(half * 2.0, half * 2.0, 0.1), c, flat(DS.BG_VOID, 0.0))
	for k: int in stars:
		var sp: Vector3 = c + Vector3(lerpf(-half, half, hash01(k * 3 + 9)), lerpf(-half, half, hash01(k * 5 + 4)), 0.1)
		var sz: float = lerpf(0.04, 0.1, hash01(k * 13))
		glow_quad(set["emis"], sp, Vector3(sz, 0, 0), Vector3(0, sz, 0), BB.KEY.lerp(BB.WINDOW_TINTS[k % 4], 0.3), lerpf(0.6, 1.6, hash01(k * 11)))


## Halcyon au loin (anneau, moyeu, rayons, points éclairés) — vue par un hublot.
func halcyon_far(set: Dictionary, c: Vector3, r: float, facing: Basis = Basis()) -> void:
	var xf: Transform3D = Transform3D(facing * Basis(Vector3.RIGHT, deg_to_rad(62)), c)
	ring(set["lit"], r * 0.86, r, r * 0.12, xf, lit(BB.L_PLATES, Color(0.5, 0.52, 0.56), 0.6), 36)
	disc(set["lit"], r * 0.16, xf, lit(BB.L_PLATES, Color(0.45, 0.47, 0.5), 0.6)[0], lit(BB.L_PLATES, Color(0.45, 0.47, 0.5), 0.6)[1], 16)
	for k: int in 4:
		var a: float = TAU * k / 4.0
		box(set["lit"], Vector3(r * 0.04, r * 0.75, r * 0.04), xf * Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO).translated_local(Vector3(0, r * 0.5, 0)),
				lit(BB.L_PLATES, Color(0.4, 0.42, 0.46), 0.6)[0], lit(BB.L_PLATES, Color(0.4, 0.42, 0.46), 0.6)[1])
	for k: int in 36:
		var a: float = TAU * k / 36.0
		var p: Vector3 = xf * (Vector3(cos(a), sin(a), r * 0.13 / r) * Vector3(r * 0.93, r * 0.93, 1.0))
		glow_quad(set["emis"], p, facing * Vector3(r * 0.025, 0, 0), facing * Vector3(0, r * 0.025, 0), BB.WINDOW_TINTS[k % 4], 1.8)


func layer_pl_f2_3_halcyon(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	halcyon_far(set, Vector3(0.05, 1.55, -9.0), 1.1)
	commit(root, set, G_LAYER)


## MID de PL-F6T-1 : deux sacs sur un siège (cabine presque vide).
func layer_pl_f6t_1_bags(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	b(set["lit"], Vector3(0.42, 0.3, 0.26), Vector3(0.85, 0.66, -0.5), lit(BB.L_FLAT, Color(0.36, 0.3, 0.22), 0.1), Vector3(0, 12, 4))
	b(set["lit"], Vector3(0.36, 0.26, 0.24), Vector3(1.12, 0.62, -0.42), lit(BB.L_FLAT, Color(0.25, 0.3, 0.32), 0.1), Vector3(0, -18, -6))
	b(set["lit"], Vector3(0.3, 0.03, 0.05), Vector3(0.85, 0.83, -0.5), lit(BB.L_FLAT, Color(0.2, 0.2, 0.22), 0.1), Vector3(0, 12, 0))
	commit(root, set, G_LAYER)


## BG-Q4 · passerelle du quai 2 (PL-F5B-2) : garde-corps, conduites, fumée (FX).
func bg_q4(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	dock_hangar(root, set, 0.1, false)
	var m: Dictionary = dock_mats(0.1)
	for side: float in [-1.0, 1.0]:
		for k: int in 10:
			b(set["lit"], Vector3(0.06, 1.1, 0.06), Vector3(side * 2.4, 0.55, 2.0 - k * 1.5), m["chrome"])
		b(set["lit"], Vector3(0.06, 0.06, 15.0), Vector3(side * 2.4, 1.1, -4.8), m["chrome"])
		b(set["lit"], Vector3(0.06, 0.06, 15.0), Vector3(side * 2.4, 0.6, -4.8), m["chrome"])
	commit(root, set, G_BG)
	dock_lights(root, 0.1, 0.8)
	omni(root, Vector3(0, 1.2, -6.0), DS.STATE_RED.lerp(BB.SPILL, 0.5), 1.4, 8.0)
	return {"camera": camera(root, Vector3(0.8, 1.7, 6.5), Vector3(-0.2, 1.4, -8.0), 54.0), "environment": dock_env(0.1, 0.045)}


func layer_pl_f5b_2_families(root: Node3D, _info: Dictionary) -> void:
	# Familles qui traversent la passerelle vers la caméra, dans la fumée.
	crowd(root, Vector3(0.0, 0, -2.5), 11, Vector2(1.7, 3.0), 10.0, 1453, G_LAYER)


## BG-Q5 · quai 6 à 05:00, coque rouillée du Basse-Marée (PL-F6E-1).
func bg_q5(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = dock_mats(0.85)
	b(set["lit"], Vector3(30, 0.3, 16), Vector3(0, -0.15, 0), m["floor"], Vector3.ZERO, 2.0)
	# Coque : grand cylindre couché, plaques rivetées, bandes de rouille.
	var c: Vector3 = Vector3(0, 5.0, -9.0)
	pipe(set["lit"], 6.0, 26.0, c, Vector3.RIGHT, m["hull"], 32)
	for k: int in 12:
		b(set["lit"], Vector3(0.08, 7.0, 0.2), Vector3(-11.0 + k * 2.0, 3.2, -3.4), lit(BB.L_PLATES, Color(0.4, 0.24, 0.16), 0.5))
	b(set["lit"], Vector3(26, 0.3, 0.3), Vector3(0, 1.4, -3.2), lit(BB.L_FLAT, Color(0.5, 0.26, 0.14), 0.3))
	# Plaque du nom (vierge : « BASSE-MARÉE » est un `Label`).
	b(set["lit"], Vector3(3.2, 0.8, 0.08), Vector3(-2.0, 4.2, -3.1), lit(BB.L_FLAT, Color(0.18, 0.16, 0.14), 0.3))
	# Passerelle, bittes d'amarrage, lampes ambre.
	b(set["lit"], Vector3(1.4, 0.15, 4.0), Vector3(3.5, 1.3, -1.5), m["chrome"], Vector3(-14, 0, 0))
	for x: float in [-6.0, -1.0, 6.0]:
		cyl(set["lit"], 0.25, 0.7, Transform3D(Basis(), Vector3(x, 0.35, 1.5)), m["beam"], 12)
	for x: float in [-8.0, 0.5, 8.0]:
		b(set["lit"], Vector3(0.12, 4.5, 0.12), Vector3(x, 2.25, 3.0), m["beam"])
		disc(set["emis"], 0.18, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(x, 4.45, 3.0)), Vector2(2.2, 0), Color(1.0, 0.68, 0.3, 0), 12)
	commit(root, set, G_BG)
	for x: float in [-8.0, 0.5, 8.0]:
		omni(root, Vector3(x, 4.2, 3.0), Color("#FFB060"), 2.2, 9.0)
	omni(root, Vector3(0, 8.0, 8.0), Color("#F0C8A8"), 0.8, 20.0)
	return {"camera": camera(root, Vector3(1.0, 1.7, 9.0), Vector3(-1.0, 3.6, -4.0), 50.0), "environment": dock_env(0.8, 0.05),
			"labels": [{"id": "hull_name", "text": "BASSE-MARÉE", "points": [Vector3(-3.6, 4.6, -3.0), Vector3(-0.4, 4.6, -3.0), Vector3(-3.6, 3.8, -3.0), Vector3(-0.4, 3.8, -3.0)]}]}


## Cale du cargo : caisses arrimées, filets, lampe de mine suspendue, petite table.
func cargo_hold(root: Node3D, set: Dictionary) -> void:
	var m: Dictionary = dock_mats(0.7)
	b(set["lit"], Vector3(10, 0.2, 10), Vector3(0, -0.1, -2), m["floor"])
	b(set["lit"], Vector3(10, 0.2, 10), Vector3(0, 3.2, -2), m["dark"])
	b(set["lit"], Vector3(10, 3.2, 0.2), Vector3(0, 1.6, -5.5), m["wall"], Vector3.ZERO, 1.2)
	for x: float in [-4.6, 4.6]:
		b(set["lit"], Vector3(0.2, 3.2, 10), Vector3(x, 1.6, -2), m["wall"], Vector3.ZERO, 1.2)
	for k: int in 9:
		var c: Vector3 = Vector3(-4.0 + (k % 3) * 1.0 + (2.8 if k >= 6 else 0.0), 0.45 + floorf((k % 6) / 3.0) * 0.9, -4.8 + (0.6 if k >= 6 else 0.0))
		b(set["lit"], Vector3(0.95, 0.88, 0.9), c, m["crate"], Vector3(0, hash01(k * 3) * 6.0, 0))
	for k: int in 5:
		b(set["lit"], Vector3(0.03, 2.4, 0.03), Vector3(-3.0 + k * 0.4, 1.4, -4.2), lit(BB.L_FLAT, Color(0.3, 0.26, 0.2), 0.1), Vector3(0, 0, 12))
	# Table et tabouret (registre posé dessus : couche MID).
	b(set["lit"], Vector3(1.2, 0.06, 0.7), Vector3(0.2, 0.78, -1.6), lit(BB.L_FLAT, Color(0.32, 0.24, 0.16), 0.1))
	for c: Vector2 in [Vector2(-0.5, -0.28), Vector2(0.5, -0.28), Vector2(-0.5, 0.28), Vector2(0.5, 0.28)]:
		b(set["lit"], Vector3(0.05, 0.78, 0.05), Vector3(0.2 + c.x, 0.39, -1.6 + c.y), m["beam"])
	# Lampe de mine suspendue.
	b(set["lit"], Vector3(0.02, 0.8, 0.02), Vector3(0.2, 2.8, -1.6), m["beam"])
	cyl(set["lit"], 0.16, 0.14, Transform3D(Basis(), Vector3(0.2, 2.35, -1.6)), m["beam"], 12)
	disc(set["emis"], 0.14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.2, 2.27, -1.6)), Vector2(2.6, 0), Color(1.0, 0.7, 0.35, 0), 14)


## BG-Q6 · cale du cargo de Wren (PL-F6-2).
func bg_q6(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cargo_hold(root, set)
	commit(root, set, G_BG)
	omni(root, Vector3(0.2, 2.2, -1.6), Color("#FFB45A"), 2.6, 6.0)
	omni(root, Vector3(-3.0, 1.0, 1.0), BB.TEAL_DIM, 0.6, 6.0)
	return {"camera": camera(root, Vector3(-1.1, 1.7, 2.2), Vector3(0.4, 1.2, -2.6), 50.0),
			"environment": environment(Color("#2A2018"), 0.55, Color("#1C1712"), 0.04, 1.05)}


func layer_pl_f6_2_ledger(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var c: Vector3 = Vector3(0.15, 0.82, -1.5)
	b(set["lit"], Vector3(0.5, 0.02, 0.36), c, flat(Color(0.25, 0.18, 0.12), 0.1), Vector3(0, -10, 0))
	for side: float in [-1.0, 1.0]:
		b(set["lit"], Vector3(0.24, 0.012, 0.33), c + Vector3(0.125 * side, 0.016, 0), flat(Color(0.8, 0.76, 0.64), 0.0), Vector3(0, -10, -3.0 * side))
		for k: int in 8:
			b(set["lit"], Vector3(0.17, 0.002, 0.006), c + Vector3(0.125 * side, 0.024, -0.12 + k * 0.032), flat(Color(0.25, 0.22, 0.2), 0.0), Vector3(0, -10, 0))
	# Un trait barré (nom rayé) — aplat d'encre, aucun caractère.
	b(set["lit"], Vector3(0.18, 0.003, 0.01), c + Vector3(-0.12, 0.027, -0.02), flat(Color(0.1, 0.08, 0.08), 0.0), Vector3(0, -14, 0))
	commit(root, set, G_LAYER)


## Grand hublot de cargo vu de l'intérieur (anneau riveté, vitre sur le noir).
func cargo_porthole(root: Node3D, set: Dictionary) -> Vector3:
	var m: Dictionary = dock_mats(0.6)
	var c: Vector3 = Vector3(0, 1.6, -1.2)
	wall_with_hole(set, Vector3(0, 1.6, -1.3), Vector2(6.0, 4.0), c + Vector3(0, 0, -0.1), 0.66, m["wall"])
	ring(set["lit"], 0.62, 0.86, 0.18, Transform3D(Basis(), c + Vector3(0, 0, -0.1)), m["chrome"], 36)
	ring(set["lit"], 0.86, 0.98, 0.08, Transform3D(Basis(), c + Vector3(0, 0, -0.12)), m["beam"], 36)
	for k: int in 16:
		var a: float = TAU * k / 16.0
		cyl(set["lit"], 0.022, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(cos(a) * 0.92, sin(a) * 0.92, -0.02)), m["chrome"], 8)
	space_backdrop(set, c + Vector3(0, 0, -30.0), 12.0, 140)
	quad(set["holo"], c + Vector3(0, 0, -0.06), Vector3(0.62, 0, 0), Vector3(0, 0.62, 0), Vector2(0.35, 3), Color(BB.KEY.r, BB.KEY.g, BB.KEY.b, 0.05))
	b(set["lit"], Vector3(6, 0.2, 4), Vector3(0, -0.1, 0.6), m["floor"])
	return c


## BG-Q7 · hublot du cargo sur le noir (PL-F6-3, PL-F6D-4, PL-F6E-4).
func bg_q7(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cargo_porthole(root, set)
	commit(root, set, G_BG)
	omni(root, Vector3(-1.4, 2.6, 0.8), Color("#FFB45A"), 1.2, 4.0)
	omni(root, Vector3(1.6, 0.8, 0.6), BB.TEAL_DIM, 0.8, 4.0)
	return {"camera": camera(root, Vector3(0.0, 1.55, 1.6), Vector3(0.0, 1.55, -1.2), 50.0),
			"environment": environment(DS.BG_PANEL, 0.45, DS.BG_VOID, 0.02, 1.0)}


func layer_pl_f6_3_halcyon(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	halcyon_far(set, Vector3(0.05, 1.8, -8.0), 0.55)
	commit(root, set, G_LAYER)


## FIG de PL-F6-3 : Noa de dos devant le hublot (silhouette d'enfant).
func layer_pl_f6_3_noa(root: Node3D, _info: Dictionary) -> void:
	person(root, Vector3(-0.55, 0.0, -0.3), 175.0, 0.62, Color("#4C3A4F"), G_LAYER, "bare", 0.5)


func layer_pl_f6d_4_cargo_lights(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	for k: int in 7:
		var p: Vector3 = Vector3(lerpf(-1.4, 1.4, hash01(k * 13 + 5)), lerpf(0.9, 2.3, hash01(k * 7 + 2)), -10.0 - hash01(k) * 6.0)
		glow_quad(set["emis"], p, Vector3(0.05, 0, 0), Vector3(0, 0.02, 0), [BB.SPILL, DS.STATE_RED, BB.KEY][k % 3], 2.2)
		glow_quad(set["emis"], p + Vector3(0.12, 0, 0), Vector3(0.02, 0, 0), Vector3(0, 0.02, 0), BB.KEY, 1.6)
	commit(root, set, G_LAYER)


## MID de PL-F6E-4 : main d'enfant posée sur la vitre du hublot.
func layer_pl_f6e_4_hand(root: Node3D, _info: Dictionary) -> void:
	hand(root, Vector3(0.0, 1.35, -1.05), Vector3(0, 1, -0.15), Vector3(0, 0, 1), 0.72, Color("#7A5A48"), G_LAYER, Color("#4C3A4F"), 0.0)


## BG-Q8 · écluse 9 et le remorqueur de Wren (PL-F6D-1), aube, brume.
func bg_q8(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	dock_hangar(root, set, 0.6)
	var m: Dictionary = dock_mats(0.6)
	# Remorqueur : coque trapue, cabine, projecteurs, dans la baie.
	b(set["lit"], Vector3(6.0, 2.2, 3.0), Vector3(-0.5, 3.4, -16.0), m["hull"])
	b(set["lit"], Vector3(2.4, 1.4, 2.4), Vector3(-1.5, 5.1, -16.0), m["hull"])
	glow_quad(set["emis"], Vector3(-1.5, 5.2, -14.79), Vector3(0.9, 0, 0), Vector3(0, 0.3, 0), BB.SPILL, 1.6)
	for x: float in [-3.0, 2.0]:
		disc(set["emis"], 0.25, Transform3D(Basis(), Vector3(x, 3.4, -14.48)), Vector2(2.4, 0), Color(1.0, 0.8, 0.5, 0), 12)
	b(set["lit"], Vector3(1.2, 1.2, 4.0), Vector3(2.0, 2.2, -16.0), m["beam"])
	commit(root, set, G_BG)
	dock_lights(root, 0.6, 0.7)
	omni(root, Vector3(0, 4.0, -12.0), Color("#F0C8A8"), 1.4, 10.0)
	return {"camera": camera(root, Vector3(2.0, 2.0, 8.0), Vector3(-0.5, 3.0, -14.0), 48.0), "environment": dock_env(0.6, 0.055)}


# === S4 · cabine du Bloc Pétrel (9 m²) et appartement de l'Anneau D ====================

func cabin_mats(warm: float = 0.0) -> Dictionary:
	return {
		"wall": lit(BB.L_FLAT, Color(0.44, 0.46, 0.48).lerp(Color(0.5, 0.44, 0.36), warm), 0.12),
		"floor": lit(BB.L_FLAT, Color(0.26, 0.25, 0.24), 0.1),
		"frame": lit(BB.L_CHROME, Color(0.55, 0.57, 0.6), 0.9),
		"mattress": lit(BB.L_FLAT, Color(0.36, 0.38, 0.42), 0.0),
		"sheet": lit(BB.L_FLAT, Color(0.72, 0.72, 0.68), 0.0),
		"wood": lit(BB.L_FLAT, Color(0.42, 0.32, 0.22), 0.05),
		"dark": lit(BB.L_FLAT, Color(0.1, 0.11, 0.13), 0.3),
		"carton": lit(BB.L_FLAT, Color(0.55, 0.42, 0.28), 0.0),
	}


## Cabine 3 × 3 m : couchette triple (gauche), réchaud, recycleur mural, hublot
## (fond), tablette ; `sheet_on` : couchettes garnies (sinon matelas nus).
func cabin(root: Node3D, set: Dictionary, sheets: int, warm: float) -> Dictionary:
	var m: Dictionary = cabin_mats(warm)
	b(set["lit"], Vector3(3.2, 0.1, 3.4), Vector3(0, -0.05, -1.5), m["floor"])
	b(set["lit"], Vector3(3.2, 0.1, 3.4), Vector3(0, 2.45, -1.5), m["wall"])
	b(set["lit"], Vector3(3.2, 2.5, 0.1), Vector3(0, 1.25, -3.2), m["wall"], Vector3.ZERO, 1.0)
	b(set["lit"], Vector3(0.1, 2.5, 3.4), Vector3(-1.6, 1.25, -1.5), m["wall"], Vector3.ZERO, 1.0)
	b(set["lit"], Vector3(0.1, 2.5, 3.4), Vector3(1.6, 1.25, -1.5), m["wall"], Vector3.ZERO, 1.0)
	for k: int in 6:
		b(set["lit"], Vector3(0.02, 2.5, 0.04), Vector3(-1.2 + k * 0.5, 1.25, -3.14), m["frame"])
	# Couchette triple (montants, cadres, matelas ; draps selon `sheets`).
	for y: float in [0.35, 1.05, 1.75]:
		b(set["lit"], Vector3(0.9, 0.06, 2.0), Vector3(-1.1, y, -2.1), m["frame"])
		b(set["lit"], Vector3(0.82, 0.1, 1.9), Vector3(-1.1, y + 0.08, -2.1), m["mattress"])
	for z: float in [-3.08, -1.12]:
		for x: float in [-1.53, -0.67]:
			b(set["lit"], Vector3(0.05, 2.1, 0.05), Vector3(x, 1.05, z), m["frame"])
	var bunks: Array[float] = [0.35, 1.05, 1.75]
	for i: int in mini(sheets, 3):
		b(set["lit"], Vector3(0.84, 0.04, 1.4), Vector3(-1.1, bunks[i] + 0.15, -1.85), m["sheet"], Vector3(0, 0, 2))
	# Réchaud et recycleur (droite), tablette.
	b(set["lit"], Vector3(0.6, 0.8, 0.5), Vector3(1.25, 0.4, -2.7), m["dark"])
	cyl(set["lit"], 0.12, 0.04, Transform3D(Basis(), Vector3(1.25, 0.82, -2.7)), m["frame"], 12)
	b(set["lit"], Vector3(0.6, 0.6, 0.25), Vector3(1.45, 1.8, -2.3), m["wall"])
	for k: int in 5:
		b(set["lit"], Vector3(0.5, 0.02, 0.02), Vector3(1.45, 1.6 + k * 0.08, -2.17), m["dark"])
	glow_quad(set["emis"], Vector3(1.28, 2.0, -2.17), Vector3(0.025, 0, 0), Vector3(0, 0.015, 0), DS.STATE_GREEN, 2.0)
	b(set["lit"], Vector3(0.9, 0.05, 0.5), Vector3(0.9, 0.8, -1.0), m["wood"])
	b(set["lit"], Vector3(0.05, 0.8, 0.05), Vector3(0.9, 0.4, -0.8), m["frame"])
	# Hublot du fond.
	var hp: Vector3 = Vector3(0.45, 1.55, -3.15)
	ring(set["lit"], 0.22, 0.3, 0.06, Transform3D(Basis(), hp), m["frame"], 24)
	disc(set["lit"], 0.23, Transform3D(Basis(), hp + Vector3(0, 0, -0.03)), m["dark"][0], m["dark"][1], 24)
	for k: int in 24:
		var sp: Vector3 = hp + Vector3(lerpf(-0.2, 0.2, hash01(k * 3 + 1)), lerpf(-0.2, 0.2, hash01(k * 7)), -0.02)
		if (sp - hp).length() < 0.19:
			glow_quad(set["emis"], sp, Vector3(0.003, 0, 0), Vector3(0, 0.003, 0), BB.WINDOW_TINTS[k % 4], 1.5)
	# Plafonnier.
	glow_quad(set["emis"], Vector3(0.4, 2.39, -1.5), Vector3(0.25, 0, 0), Vector3(0, 0, 0.08), BB.KEY.lerp(BB.SPILL, 0.5), 0.9)
	return {"porthole": hp}


func cabin_lights(root: Node3D, warm: float, scale: float = 1.0) -> void:
	omni(root, Vector3(0.4, 2.2, -1.4), BB.KEY.lerp(BB.SPILL, 0.4 + warm * 0.4), 1.8 * scale, 4.5)
	omni(root, Vector3(1.2, 1.2, -2.6), Color("#FFB060"), 0.6 * scale, 2.0)
	omni(root, Vector3(-0.6, 1.0, 0.8), BB.TEAL_DIM, 0.5 * scale, 4.0)


func cabin_env(warm: float = 0.5, scale: float = 1.0) -> Environment:
	return environment(Color("#2C2622").lerp(DS.BG_ELEVATED, 1.0 - warm), 0.55 * scale, Color("#1C1814"), 0.02, 1.05)


## BG-P1 · cabine vidée (PL-F2-2) : matelas nus, réchaud resté.
func bg_p1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cabin(root, set, 0, 0.5)
	commit(root, set, G_BG)
	cabin_lights(root, 0.5)
	return {"camera": camera(root, Vector3(0.6, 1.65, 1.0), Vector3(-0.3, 0.9, -2.8), 62.0), "environment": cabin_env()}


func layer_pl_f2_2_boxes(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var m: Dictionary = cabin_mats()
	var spots: Array[Vector3] = [Vector3(-0.85, 0.25, -0.75), Vector3(-0.35, 0.22, -0.55), Vector3(-0.65, 0.68, -0.68), Vector3(-1.1, 0.2, -0.3)]
	for k: int in spots.size():
		b(set["lit"], Vector3(0.52, 0.42, 0.42) * lerpf(0.85, 1.1, hash01(k)), spots[k], m["carton"], Vector3(0, hash01(k * 3) * 30.0 - 15.0, 0))
		b(set["lit"], Vector3(0.53, 0.02, 0.08), spots[k] + Vector3(0, 0.21, 0), lit(BB.L_FLAT, Color(0.7, 0.62, 0.42), 0.0),
				Vector3(0, hash01(k * 3) * 30.0 - 15.0, 0))
	commit(root, set, G_LAYER)


## BG-P2 · cabine de nuit, couchette triple, un seul drap (PL-F3-1).
func bg_p2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cabin(root, set, 1, 0.1)
	commit(root, set, G_BG)
	cabin_lights(root, 0.0, 0.3)
	omni(root, Vector3(0.45, 1.55, -2.9), Color("#7F9AB8"), 0.9, 3.0)
	return {"camera": camera(root, Vector3(0.9, 1.4, 0.6), Vector3(-1.1, 1.0, -2.2), 58.0), "environment": cabin_env(0.1, 0.5)}


## BG-P3 · hublot embué (PL-F3-2) : gros plan ; badge dessiné à demi effacé.
func bg_p3(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var info: Dictionary = cabin(root, set, 1, 0.1)
	var hp: Vector3 = info["porthole"]
	quad(set["holo"], hp + Vector3(0, 0, 0.005), Vector3(0.22, 0, 0), Vector3(0, 0.22, 0), Vector2(0.5, 0), Color(0.8, 0.84, 0.88, 0.16))
	# Badge dessiné du doigt (traits clairs sur la buée), à demi effacé.
	for e: Array in [[Vector3(-0.06, 0.05, 0), Vector3(0.0, 0.04, 0)], [Vector3(0.06, 0.05, 0), Vector3(0.0, 0.04, 0)],
			[Vector3(0.0, 0.09, 0), Vector3(0.06, 0.0, 0)], [Vector3(0.0, 0.01, 0), Vector3(0.06, 0.0, 0)], [Vector3(0.0, 0.05, 0), Vector3(0.015, 0.0, 0)]]:
		glow_quad(set["emis"], hp + e[0] + Vector3(0, 0, 0.008), e[1] if (e[1] as Vector3).x > 0.0 else Vector3(0.004, 0, 0),
				Vector3(0, 0.004, 0) if (e[1] as Vector3).x > 0.0 else e[1], Color(0.7, 0.74, 0.78), 0.55)
	commit(root, set, G_BG)
	cabin_lights(root, 0.0, 0.35)
	omni(root, hp + Vector3(0, 0, 0.5), Color("#7F9AB8"), 0.8, 1.5)
	return {"camera": camera(root, hp + Vector3(-0.08, 0.02, 0.85), hp + Vector3(0, 0, 0), 40.0), "environment": cabin_env(0.1, 0.5)}


## BG-P4 · sous la couchette (PL-F3-2 Lumika) : vue basse, dessous du cadre.
func bg_p4(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cabin(root, set, 1, 0.1)
	commit(root, set, G_BG)
	cabin_lights(root, 0.0, 0.35)
	omni(root, Vector3(-0.6, 0.2, -1.0), Color("#7F9AB8"), 0.6, 2.0)
	return {"camera": camera(root, Vector3(0.2, 0.18, -0.6), Vector3(-1.1, 0.42, -2.1), 70.0), "environment": cabin_env(0.1, 0.5)}


## MID de PL-F3-2 Lumika : luciole au crayon sous le cadre (seul magenta, D-073).
func layer_pl_f3_2_lumika_firefly(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var c: Vector3 = Vector3(-1.05, 0.315, -1.95)
	var down: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for s: Array in [[Vector2(-0.035, 0.04), 35.0], [Vector2(0.0, 0.05), 0.0], [Vector2(0.035, 0.04), -35.0]]:
		var o: Vector2 = s[0]
		box(set["emis"], Vector3(0.012, 0.07, 0.002), Transform3D(down * Basis(Vector3.BACK, deg_to_rad(s[1])), c + Vector3(o.x, 0, -o.y)),
				Vector2(0.9, 0), Color(BB.MAGENTA.r, BB.MAGENTA.g, BB.MAGENTA.b, 0))
	disc(set["emis"], 0.016, Transform3D(down, c + Vector3(0, -0.001, 0.02)), Vector2(0.9, 0), Color(BB.MAGENTA.r, BB.MAGENTA.g, BB.MAGENTA.b, 0), 10)
	commit(root, set, G_LAYER)


## BG-P5 · appartement de l'Anneau D, vraie fenêtre (PL-F4-3), aube.
func bg_p5(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = cabin_mats(0.6)
	b(set["lit"], Vector3(5, 0.1, 5), Vector3(0, -0.05, -1.5), m["wood"])
	b(set["lit"], Vector3(5, 2.8, 0.15), Vector3(0, 1.4, -3.6), lit(BB.L_FLAT, Color(0.62, 0.58, 0.5), 0.05))
	b(set["lit"], Vector3(0.15, 2.8, 5), Vector3(-2.4, 1.4, -1.5), lit(BB.L_FLAT, Color(0.56, 0.52, 0.46), 0.05))
	# Fenêtre (cadre, croisillon) sur la ville de l'Anneau D au lever.
	var w: Vector3 = Vector3(0.3, 1.6, -3.5)
	quad(set["emis"], w + Vector3(0, 0, -0.5), Vector3(1.0, 0, 0), Vector3(0, 0.7, 0), Vector2(1.0, 3), Color(BB.WINDOW_TINTS[0].r, BB.WINDOW_TINTS[0].g, BB.WINDOW_TINTS[0].b, 91.0 / 255.0))
	glow_quad(set["emis"], w + Vector3(0, 0, -0.6), Vector3(1.0, 0, 0), Vector3(0, 0.7, 0), Color("#F0C8A8").darkened(0.4), 0.7)
	for e: Array in [[Vector3(0, 0.72, 0), Vector3(1.1, 0.04, 0.12)], [Vector3(0, -0.72, 0), Vector3(1.1, 0.04, 0.12)],
			[Vector3(-1.04, 0, 0), Vector3(0.04, 0.72, 0.12)], [Vector3(1.04, 0, 0), Vector3(0.04, 0.72, 0.12)], [Vector3(0, 0, 0), Vector3(0.02, 0.7, 0.08)]]:
		box(set["lit"], (e[1] as Vector3) * 2.0, Transform3D(Basis(), w + e[0]), m["frame"][0], m["frame"][1])
	# Radiateur sous la fenêtre, table, chaise.
	for k: int in 8:
		b(set["lit"], Vector3(0.05, 0.5, 0.08), Vector3(-0.2 + k * 0.1, 0.45, -3.45), m["frame"])
	b(set["lit"], Vector3(1.4, 0.05, 0.8), Vector3(0.0, 0.75, -1.6), m["wood"])
	for c: Vector2 in [Vector2(-0.62, -0.32), Vector2(0.62, -0.32), Vector2(-0.62, 0.32), Vector2(0.62, 0.32)]:
		b(set["lit"], Vector3(0.05, 0.75, 0.05), Vector3(c.x, 0.375, -1.6 + c.y), m["wood"])
	commit(root, set, G_BG)
	omni(root, w + Vector3(0, 0, 0.6), Color("#F0C8A8"), 2.0, 5.0)
	omni(root, Vector3(1.6, 2.0, 0.5), BB.TEAL_DIM, 0.5, 5.0)
	return {"camera": camera(root, Vector3(0.6, 1.75, 0.9), Vector3(0.0, 0.9, -2.4), 56.0),
			"environment": environment(Color("#3A3A44"), 0.6, Color("#2C2830"), 0.015, 1.05)}


## Feuilles de dessins posées en éventail sur une table (aucun texte) ; `motif`
## : 0 portes, 1 navettes en flammes, 2 lucioles imprimées (magenta).
func drawings(set: Dictionary, c: Vector3, motif: int, count: int, seed: int) -> void:
	for k: int in count:
		var p: Vector3 = c + Vector3(lerpf(-0.42, 0.42, hash01(seed + k * 3)), 0.002 * k, lerpf(-0.18, 0.18, hash01(seed + k * 5)))
		var rot: float = lerpf(-28.0, 28.0, hash01(seed + k * 7))
		var r: Basis = Basis(Vector3.UP, deg_to_rad(rot))
		b(set["lit"], Vector3(0.21, 0.004, 0.29), p, flat(Color(0.86, 0.84, 0.78), 0.0), Vector3(0, rot, 0))
		var ink: Color = Color(0.2, 0.2, 0.24)
		match motif:
			0: # porte : cadre et poignée
				for e: Array in [[Vector3(-0.05, 0, 0), Vector3(0.006, 0.002, 0.18)], [Vector3(0.05, 0, 0), Vector3(0.006, 0.002, 0.18)],
						[Vector3(0, 0, -0.09), Vector3(0.1, 0.002, 0.006)], [Vector3(0.03, 0, 0.0), Vector3(0.012, 0.002, 0.012)]]:
					box(set["lit"], e[1], Transform3D(r, p + r * (e[0] as Vector3) + Vector3(0, 0.003, 0)), flat(ink, 0.0)[0], flat(ink, 0.0)[1])
			1: # navette et flammes
				box(set["lit"], Vector3(0.12, 0.002, 0.03), Transform3D(r, p + Vector3(0, 0.003, 0)), flat(ink, 0.0)[0], flat(ink, 0.0)[1])
				for f: int in 3:
					box(set["emis"], Vector3(0.025, 0.002, 0.02), Transform3D(r, p + r * Vector3(-0.08 - f * 0.02, 0.0035, (f - 1) * 0.012)),
							Vector2(1.1, 0), Color(DS.STATE_RED.r, DS.STATE_AMBER.g, 0.1, 0))
			2: # luciole imprimée au tampon
				for s: Array in [[Vector2(-0.02, 0.02), 35.0], [Vector2(0.0, 0.03), 0.0], [Vector2(0.02, 0.02), -35.0]]:
					var o: Vector2 = s[0]
					box(set["emis"], Vector3(0.008, 0.002, 0.045), Transform3D(r * Basis(Vector3.UP, deg_to_rad(s[1])), p + r * Vector3(o.x, 0.0035, -o.y)),
							Vector2(0.8, 0), Color(BB.MAGENTA.r, BB.MAGENTA.g, BB.MAGENTA.b, 0))


func layer_pl_f4_3_drawings(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	drawings(set, Vector3(0.0, 0.78, -1.55), 0, 7, 1431)
	commit(root, set, G_LAYER)


## BG-P6 · la table de Noa (PL-F5-4, PL-F5B-4) : plateau, lampe, tasse.
func bg_p6(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cabin(root, set, 2, 0.6)
	var m: Dictionary = cabin_mats(0.6)
	b(set["lit"], Vector3(1.3, 0.05, 0.8), Vector3(0.4, 0.8, -1.2), m["wood"])
	cyl(set["lit"], 0.04, 0.09, Transform3D(Basis(), Vector3(0.95, 0.87, -0.95)), lit(BB.L_FLAT, Color(0.6, 0.62, 0.66), 0.1), 12)
	b(set["lit"], Vector3(0.03, 0.4, 0.03), Vector3(-0.1, 1.02, -1.45), m["frame"], Vector3(0, 0, -12))
	cyl(set["lit"], 0.09, 0.08, Transform3D(Basis(Vector3.BACK, deg_to_rad(30)), Vector3(-0.02, 1.22, -1.45)), m["dark"], 12)
	commit(root, set, G_BG)
	cabin_lights(root, 0.6, 0.6)
	omni(root, Vector3(0.0, 1.15, -1.35), Color("#FFC080"), 1.4, 2.0)
	return {"camera": camera(root, Vector3(0.45, 1.75, -0.2), Vector3(0.4, 0.8, -1.25), 52.0), "environment": cabin_env(0.6)}


func layer_pl_f5_4_prints(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	drawings(set, Vector3(0.4, 0.83, -1.2), 2, 8, 1454)
	stamp(set, Vector3(0.62, 0.825, -1.05), false, 15.0)
	commit(root, set, G_LAYER)


func layer_pl_f5b_4_drawings(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	drawings(set, Vector3(0.4, 0.83, -1.2), 1, 7, 1455)
	commit(root, set, G_LAYER)


## BG-P7 · cabine, petite radio sur l'étagère (PL-F8-3).
func bg_p7(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	cabin(root, set, 3, 0.5)
	var m: Dictionary = cabin_mats(0.5)
	b(set["lit"], Vector3(0.9, 0.04, 0.3), Vector3(0.9, 1.25, -3.0), m["wood"])
	b(set["lit"], Vector3(0.36, 0.2, 0.14), Vector3(0.85, 1.37, -2.98), lit(BB.L_FLAT, Color(0.3, 0.2, 0.16), 0.2))
	ring(set["lit"], 0.0, 0.06, 0.0, Transform3D(Basis(), Vector3(0.76, 1.37, -2.905)), lit(BB.L_PERF, Color(0.7, 0.7, 0.7), 0.3), 14)
	cyl(set["lit"], 0.025, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.96, 1.38, -2.9)), m["frame"], 10)
	b(set["lit"], Vector3(0.01, 0.25, 0.01), Vector3(1.0, 1.58, -3.0), m["frame"], Vector3(0, 0, -20))
	glow_quad(set["emis"], Vector3(0.92, 1.43, -2.909), Vector3(0.04, 0, 0), Vector3(0, 0.012, 0), BB.SPILL, 1.4)
	commit(root, set, G_BG)
	cabin_lights(root, 0.5, 0.6)
	return {"camera": camera(root, Vector3(0.5, 1.5, -1.6), Vector3(0.88, 1.35, -3.0), 50.0), "environment": cabin_env(0.5)}


func layer_pl_f8_3_hand(root: Node3D, _info: Dictionary) -> void:
	hand(root, Vector3(1.1, 1.3, -2.62), Vector3(-0.3, 0.1, -1.0), Vector3(0, 1, 0), 0.9, Color("#6B5446"), G_LAYER, Color("#3F4F3A"), 0.4)


# === S5 · Anneau B : couloir blanc, cellule ============================================

func clinical_mats() -> Dictionary:
	return {
		"white": lit(BB.L_FLAT, Color(0.8, 0.82, 0.84), 0.1),
		"panel": lit(BB.L_FLAT, Color(0.72, 0.74, 0.77), 0.08),
		"floor": lit(BB.L_FLAT, Color(0.56, 0.58, 0.6), 0.2),
		"dark": lit(BB.L_FLAT, Color(0.2, 0.22, 0.25), 0.3),
		"steel": lit(BB.L_CHROME, Color(0.68, 0.7, 0.74), 0.9),
	}


## BG-B1 · couloir blanc de l'Anneau B (PL-F1-1).
func bg_b1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = clinical_mats()
	b(set["lit"], Vector3(2.8, 0.1, 30), Vector3(0, -0.05, -12), m["floor"])
	b(set["lit"], Vector3(2.8, 0.1, 30), Vector3(0, 2.75, -12), m["white"])
	for side: float in [-1.0, 1.0]:
		b(set["lit"], Vector3(0.1, 2.8, 30), Vector3(side * 1.4, 1.4, -12), m["panel"], Vector3.ZERO, 1.0)
		for k: int in 10:
			b(set["lit"], Vector3(0.12, 2.8, 0.05), Vector3(side * 1.36, 1.4, 2.0 - k * 3.0), m["white"])
			if k % 3 == 1:
				b(set["lit"], Vector3(0.06, 2.1, 1.0), Vector3(side * 1.34, 1.05, 0.5 - k * 3.0), m["dark"])
				glow_quad(set["emis"], Vector3(side * 1.3, 1.6, 0.5 - k * 3.0), Vector3(0, 0, 0.1) * side, Vector3(0, 0.1, 0), BB.KEY, 1.2)
	for k: int in 10:
		glow_quad(set["emis"], Vector3(0, 2.69, 1.0 - k * 3.0), Vector3(0.6, 0, 0), Vector3(0, 0, 0.12), BB.KEY, 1.8)
	b(set["lit"], Vector3(2.8, 2.8, 0.1), Vector3(0, 1.4, -27), m["dark"])
	commit(root, set, G_BG)
	for k: int in 5:
		omni(root, Vector3(0, 2.5, 0.0 - k * 5.0), Color("#F2F4F6"), 1.6, 6.0)
	return {"camera": camera(root, Vector3(0.0, 1.6, 4.5), Vector3(0, 1.3, -20.0), 48.0),
			"environment": environment(Color("#6E7680"), 0.7, Color("#C8CED6"), 0.03, 1.0)}


func layer_pl_f1_1_agent(root: Node3D, _info: Dictionary) -> void:
	person(root, Vector3(0.0, 0, -0.6), 180.0, 1.0, BB.STEEL.darkened(0.2), G_LAYER, "bare", 0.6)


func layer_pl_f1_1_guards(root: Node3D, _info: Dictionary) -> void:
	person(root, Vector3(-0.72, 0, -0.95), 172.0, 1.04, Color("#4A515C"), G_LAYER, "guard", 0.6)
	person(root, Vector3(0.72, 0, -0.95), 188.0, 1.04, Color("#4A515C"), G_LAYER, "guard", 0.6)


## BG-B2 · cellule, porte à hublot, lumière blanche (PL-F1-2, PL-F1-4).
func bg_b2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = clinical_mats()
	b(set["lit"], Vector3(3.0, 0.1, 3.4), Vector3(0, -0.05, -0.7), m["floor"])
	b(set["lit"], Vector3(3.0, 0.1, 3.4), Vector3(0, 2.6, -0.7), m["white"])
	b(set["lit"], Vector3(3.0, 2.6, 0.12), Vector3(0, 1.3, -2.4), m["panel"], Vector3.ZERO, 1.0)
	for side: float in [-1.0, 1.0]:
		b(set["lit"], Vector3(0.12, 2.6, 3.4), Vector3(side * 1.5, 1.3, -0.7), m["panel"], Vector3.ZERO, 1.0)
	# Porte (centrée), hublot, fente lumineuse sous la porte (repère des traits de PL-F1-4).
	b(set["lit"], Vector3(0.95, 2.05, 0.08), Vector3(0, 1.04, -2.32), lit(BB.L_FLAT, Color(0.42, 0.44, 0.48), 0.4))
	for x: float in [-0.5, 0.5]:
		b(set["lit"], Vector3(0.06, 2.1, 0.12), Vector3(x, 1.05, -2.3), m["dark"])
	b(set["lit"], Vector3(1.1, 0.06, 0.1), Vector3(0, 2.1, -2.3), m["dark"])
	ring(set["lit"], 0.12, 0.17, 0.04, Transform3D(Basis(), Vector3(0, 1.55, -2.27)), m["dark"], 20)
	disc(set["emis"], 0.12, Transform3D(Basis(), Vector3(0, 1.55, -2.28)), Vector2(1.5, 0), Color(0.95, 0.96, 0.98, 0), 20)
	b(set["lit"], Vector3(0.95, 0.02, 0.06), Vector3(0, 0.005, -2.25), m["dark"])
	# Banc.
	b(set["lit"], Vector3(1.8, 0.08, 0.5), Vector3(-0.2, 0.45, 0.4), m["white"])
	b(set["lit"], Vector3(1.8, 0.45, 0.05), Vector3(-0.2, 0.22, 0.62), m["dark"])
	commit(root, set, G_BG)
	omni(root, Vector3(0, 2.4, -0.6), Color("#F2F4F6"), 1.8, 4.5)
	omni(root, Vector3(0, 1.55, -2.0), Color("#F2F4F6"), 0.7, 1.4)
	return {"camera": camera(root, Vector3(0.1, 1.45, 1.8), Vector3(0.0, 1.0, -2.4), 50.0),
			"environment": environment(Color("#6E7680"), 0.6, Color("#B8BEC6"), 0.02, 1.0)}


func layer_pl_f1_2_seated(root: Node3D, _info: Dictionary) -> void:
	seated(root, Vector3(0.05, 0.05, -1.15), 1.0, BB.STEEL.darkened(0.2), 0, 180.0, G_LAYER)


func layer_pl_f1_4_light_lines(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	for k: int in 3:
		glow_quad(set["emis"], Vector3(-0.3 + k * 0.3, 0.006, -1.85), Vector3(0.05, 0, 0), Vector3(0, 0, -0.42), BB.KEY, 1.5)
	commit(root, set, G_LAYER)


# === S6 · recycleur central ============================================================

## Salle du recycleur : conduites géantes, collecteur, vanne à volant, passerelle.
func recycler(root: Node3D, set: Dictionary) -> void:
	var m: Dictionary = dock_mats(0.2)
	var green: Array = lit(BB.L_PLATES, Color(0.32, 0.42, 0.4), 0.6)
	b(set["lit"], Vector3(24, 0.3, 18), Vector3(0, -0.15, -4), m["floor"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(24, 10, 0.4), Vector3(0, 5, -12), m["wall"], Vector3.ZERO, 1.5)
	b(set["lit"], Vector3(24, 0.3, 18), Vector3(0, 10.0, -4), m["dark"])
	for k: int in 4:
		cyl(set["lit"], 0.7, 10.0, Transform3D(Basis(), Vector3(-7.5 + k * 5.0, 5.0, -10.5)), green, 18, false)
		for y: float in [1.0, 5.0, 9.0]:
			cyl(set["lit"], 0.78, 0.2, Transform3D(Basis(), Vector3(-7.5 + k * 5.0, y, -10.5)), m["chrome"], 18, false)
	pipe(set["lit"], 0.9, 24.0, Vector3(0, 7.5, -8.5), Vector3.RIGHT, green, 18)
	# Collecteur central et vanne (volant à rayons).
	cyl(set["lit"], 1.2, 2.6, Transform3D(Basis(), Vector3(0, 1.3, -6.0)), green, 22)
	pipe(set["lit"], 0.5, 4.0, Vector3(0, 1.6, -3.8), Vector3.BACK, m["chrome"], 14)
	var wheel: Transform3D = Transform3D(Basis(), Vector3(0, 1.6, -1.75))
	ring(set["lit"], 0.62, 0.72, 0.08, wheel, lit(BB.L_FLAT, DS.STATE_RED.darkened(0.4), 0.4), 28)
	for s: int in 4:
		box(set["lit"], Vector3(1.3, 0.06, 0.06), wheel * Transform3D(Basis(Vector3.BACK, s * PI * 0.25), Vector3(0, 0, 0.04)),
				lit(BB.L_FLAT, DS.STATE_RED.darkened(0.4), 0.4)[0], lit(BB.L_FLAT, DS.STATE_RED.darkened(0.4), 0.4)[1])
	# Passerelle haute et garde-corps.
	b(set["lit"], Vector3(20, 0.15, 1.6), Vector3(0, 4.0, -9.2), m["chrome"])
	for k: int in 14:
		b(set["lit"], Vector3(0.05, 1.0, 0.05), Vector3(-9.5 + k * 1.45, 4.5, -8.45), m["chrome"])
	b(set["lit"], Vector3(20, 0.05, 0.05), Vector3(0, 5.0, -8.45), m["chrome"])
	for k: int in 8:
		glow_quad(set["emis"], Vector3(-8.0 + k * 2.3, 0.02, -2.0), Vector3(0.3, 0, 0), Vector3(0, 0, -0.05), DS.STATE_GREEN.lerp(BB.TEAL_DIM, 0.5), 1.4)
	glow_quad(set["emis"], Vector3(1.25, 1.9, -6.0 + 1.21), Vector3(0.12, 0, 0), Vector3(0, 0.05, 0), DS.STATE_GREEN, 1.8)


func recycler_lights(root: Node3D) -> void:
	omni(root, Vector3(0, 8.5, -5.0), Color("#A8D8C8"), 2.4, 14.0)
	omni(root, Vector3(-6, 3.0, -3.0), BB.TEAL_DIM, 1.6, 8.0)
	omni(root, Vector3(6, 3.0, -3.0), BB.TEAL_DIM.lerp(BB.SPILL, 0.3), 1.4, 8.0)
	omni(root, Vector3(0, 2.2, -0.5), Color("#C8E0D8"), 1.0, 4.0)


## BG-R1 · la vanne du recycleur central (PL-F5C-1), particules d'air en FX.
func bg_r1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	recycler(root, set)
	commit(root, set, G_BG)
	recycler_lights(root)
	return {"camera": camera(root, Vector3(2.2, 1.8, 3.8), Vector3(-0.4, 2.2, -6.0), 52.0),
			"environment": environment(Color("#1E2526"), 0.6, Color("#1A2422"), 0.035, 1.05)}


## FIG de PL-F5C-1 : les Veilleurs (silhouettes) à la vanne, de trois quarts.
func layer_pl_f5c_1_watchers(root: Node3D, _info: Dictionary) -> void:
	for k: int in 4:
		person(root, Vector3(-2.6 + k * 0.62, 0, -1.4 - (k % 2) * 0.5), 120.0 + k * 6.0, lerpf(0.95, 1.05, hash01(1451 + k)),
				crowd_tint(1451 + k * 3), G_LAYER, ["bare", "cap", "bare", "cap"][k], 0.5)


## BG-R2 · le Conseil de l'air au recycleur (PL-EB-2) : salle vue de haut.
func bg_r2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	recycler(root, set)
	commit(root, set, G_BG)
	recycler_lights(root)
	omni(root, Vector3(0, 3.0, 0.5), Color("#E8CFA0"), 1.2, 6.0)
	return {"camera": camera(root, Vector3(0.0, 5.2, 6.5), Vector3(0.0, 0.6, -2.0), 50.0),
			"environment": environment(Color("#1E2526"), 0.65, Color("#1A2422"), 0.03, 1.05)}


func layer_pl_eb_2_council(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var c: Vector3 = Vector3(0.0, 0, 0.6)
	for k: int in 10:
		var a: float = TAU * k / 10.0 + 0.2
		var p: Vector3 = c + Vector3(cos(a) * 2.4, 0, sin(a) * 1.6)
		b(set["lit"], Vector3(0.45, 0.06, 0.45), p + Vector3(0, 0.45, 0), lit(BB.L_FLAT, Color(0.4, 0.34, 0.26), 0.1))
		seated(root, p + Vector3(0, 0.48, 0), 0.96, crowd_tint(1521 + k), k % 3, rad_to_deg(atan2(c.x - p.x, c.z - p.z)), G_LAYER)
	commit(root, set, G_LAYER)


# === S7 · Tycho ===========================================================================

func tycho_mats() -> Dictionary:
	return {
		"dust": lit(BB.L_CONCRETE, Color(0.5, 0.4, 0.3), 0.0, 0.0),
		"rust": lit(BB.L_PLATES, Color(0.46, 0.3, 0.2), 0.2),
		"wall": lit(BB.L_FLAT, Color(0.4, 0.34, 0.28), 0.15),
		"dark": lit(BB.L_FLAT, Color(0.12, 0.1, 0.09), 0.2),
		"wood": lit(BB.L_FLAT, Color(0.36, 0.26, 0.18), 0.05),
		"steel": lit(BB.L_CHROME, Color(0.55, 0.52, 0.48), 0.9),
	}


## Lampe de mine (abat-jour, ampoule) suspendue en `p`.
func mine_lamp(root: Node3D, set: Dictionary, p: Vector3, energy: float) -> void:
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(0.02, 1.2, 0.02), p + Vector3(0, 0.75, 0), m["dark"])
	cyl(set["lit"], 0.2, 0.16, Transform3D(Basis(), p + Vector3(0, 0.1, 0)), m["rust"], 14)
	disc(set["emis"], 0.17, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0.015, 0)), Vector2(2.6, 0), Color(1.0, 0.72, 0.36, 0), 14)
	omni(root, p - Vector3(0, 0.2, 0), Color("#FFB45A"), energy, 7.0)


## BG-T1 · le dôme de Tycho, la lumière revient (PL-F5S-3).
func bg_t1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(40, 0.3, 40), Vector3(0, -0.15, -8), m["dust"], Vector3.ZERO, 3.0)
	# Côtes du dôme (arceaux), vitrage clair en haut.
	for k: int in 9:
		var a: float = PI * k / 8.0
		for s: int in 12:
			var t0: float = PI * 0.5 * s / 12.0
			var t1: float = PI * 0.5 * (s + 1) / 12.0
			var p0: Vector3 = Vector3(cos(a) * cos(t0), sin(t0), -sin(a) * cos(t0)) * 14.0 + Vector3(0, 0, -10)
			var p1: Vector3 = Vector3(cos(a) * cos(t1), sin(t1), -sin(a) * cos(t1)) * 14.0 + Vector3(0, 0, -10)
			box(set["lit"], Vector3(0.25, (p1 - p0).length(), 0.25), Transform3D(along(p1 - p0), (p0 + p1) * 0.5), m["steel"][0], m["steel"][1])
	# Lumière qui revient : verrière au zénith (dégradé chaud) + halo bas sur l'horizon.
	for k: int in 4:
		quad(set["emis"], Vector3(0, 12.6 - k * 0.5, -12.5 - k * 0.6), Vector3(5.0 - k * 0.8, 0, 0), Vector3(0, 0.3, -0.5), Vector2(0.9 - k * 0.15, 0),
				Color(1.0, 0.8, 0.6, 0))
	quad(set["emis"], Vector3(0, 2.0, -23.5), Vector3(14, 0, 0), Vector3(0, 2.0, 0), Vector2(0.35, 0), Color(0.9, 0.6, 0.4, 0))
	# Habitations basses, serres, passerelle.
	for k: int in 7:
		var c: Vector3 = Vector3(-10.0 + k * 3.4, 0, -16.0 + hash01(k) * 3.0)
		b(set["lit"], Vector3(2.6, 1.6 + hash01(k * 3) * 1.4, 2.0), c + Vector3(0, 1.0, 0), m["wall"])
		glow_quad(set["emis"], c + Vector3(-0.5, 1.2, 1.01), Vector3(0.25, 0, 0), Vector3(0, 0.2, 0), Color("#FFB45A"), 1.4)
	commit(root, set, G_BG)
	omni(root, Vector3(0, 10.0, -12.0), Color("#F0C8A8"), 3.0, 22.0)
	omni(root, Vector3(-6, 2.0, -6.0), Color("#FFB45A"), 1.4, 8.0)
	return {"camera": camera(root, Vector3(0, 1.8, 6.0), Vector3(0, 4.5, -16.0), 58.0),
			"environment": environment(Color("#3A3028"), 0.7, Color("#4A3A2C"), 0.03, 1.05)}


## BG-T2 · poussière de Tycho, une vitre éclairée au loin (PL-F2-4).
func bg_t2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(200, 0.3, 200), Vector3(0, -0.15, -60), m["dust"], Vector3.ZERO, 6.0)
	for k: int in 14:
		var c: Vector3 = Vector3(lerpf(-60, 60, hash01(k * 3)), 0, lerpf(-120, -30, hash01(k * 5 + 1)))
		b(set["lit"], Vector3(lerpf(8, 24, hash01(k)), lerpf(1.5, 5.0, hash01(k * 7)), lerpf(6, 18, hash01(k * 11))), c, m["dust"], Vector3(0, hash01(k) * 40.0, 8.0))
	b(set["lit"], Vector3(9.0, 4.0, 6.0), Vector3(7.0, 2.0, -30.0), m["rust"])
	b(set["lit"], Vector3(3.0, 2.0, 3.0), Vector3(9.5, 4.8, -30.0), m["rust"])
	glow_quad(set["emis"], Vector3(5.6, 2.2, -26.98), Vector3(0.6, 0, 0), Vector3(0, 0.45, 0), Color("#FFC070"), 2.8)
	# Ciel de poussière : bandes d'horizon très douces (aucun astre).
	for k: int in 3:
		quad(set["emis"], Vector3(0, 6.0 + k * 10.0, -140.0), Vector3(180, 0, 0), Vector3(0, 5.0, 0), Vector2(0.25 - k * 0.07, 0), Color(0.75, 0.55, 0.38, 0))
	commit(root, set, G_BG)
	omni(root, Vector3(5.6, 2.2, -25.5), Color("#FFB45A"), 2.4, 9.0)
	omni(root, Vector3(0, 30.0, -40.0), Color("#C8A880"), 1.6, 120.0)
	return {"camera": camera(root, Vector3(-2.0, 1.7, 6.0), Vector3(3.0, 2.2, -50.0), 46.0, 300.0),
			"environment": environment(Color("#4A3A2C"), 0.6, Color("#6A5440"), 0.035, 1.0)}


## BG-T3 · sas Castellanos, lampe de mine (PL-F6T-3, PL-ED-1, PL-E-FIG D).
func bg_t3(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(10, 0.2, 10), Vector3(0, -0.1, -2), m["dust"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(10, 0.2, 10), Vector3(0, 3.6, -2), m["dark"])
	b(set["lit"], Vector3(10, 3.6, 0.3), Vector3(0, 1.8, -5.5), m["wall"], Vector3.ZERO, 1.2)
	for x: float in [-4.8, 4.8]:
		b(set["lit"], Vector3(0.3, 3.6, 10), Vector3(x, 1.8, -2), m["wall"], Vector3.ZERO, 1.2)
	# Porte du sas (rouillée), vitre de contrôle (même vitre « dans l'autre sens »).
	b(set["lit"], Vector3(2.2, 2.6, 0.2), Vector3(-1.8, 1.3, -5.3), m["rust"])
	for y: float in [0.6, 1.3, 2.0]:
		b(set["lit"], Vector3(2.3, 0.08, 0.26), Vector3(-1.8, y, -5.25), m["steel"])
	b(set["lit"], Vector3(2.4, 1.4, 0.3), Vector3(1.8, 1.0, -5.2), m["rust"])
	quad(set["lit"], Vector3(1.8, 2.15, -5.25), Vector3(1.1, 0, 0), Vector3(0, 0.55, 0), lit(BB.L_FLAT, DS.BG_ELEVATED, 0.85)[0], lit(BB.L_FLAT, DS.BG_ELEVATED, 0.85)[1])
	b(set["lit"], Vector3(2.5, 0.12, 0.4), Vector3(1.8, 2.75, -5.2), m["steel"])
	b(set["lit"], Vector3(2.5, 0.06, 0.6), Vector3(1.8, 1.72, -5.0), m["steel"])
	mine_lamp(root, set, Vector3(0.0, 2.8, -2.6), 2.8)
	for k: int in 4:
		b(set["lit"], Vector3(0.6, 0.5, 0.5), Vector3(-4.0 + k * 0.4, 0.25 + (k % 2) * 0.5, -4.6), lit(BB.L_FLAT, Color(0.3, 0.26, 0.2), 0.1))
	commit(root, set, G_BG)
	omni(root, Vector3(1.8, 1.8, -6.0), BB.SPILL, 0.8, 3.0)
	return {"camera": camera(root, Vector3(0.6, 1.7, 3.4), Vector3(0.2, 1.4, -5.4), 54.0),
			"environment": environment(Color("#2A2018"), 0.55, Color("#2A2018"), 0.045, 1.05),
			"holo_rects": [[Vector3(0.7, 2.7, -5.25), Vector3(2.9, 2.7, -5.25), Vector3(0.7, 1.6, -5.25), Vector3(2.9, 1.6, -5.25)]]}


func layer_pl_f6t_3_committee(root: Node3D, _info: Dictionary) -> void:
	for k: int in 6:
		person(root, Vector3(-2.0 + k * 0.75, 0, -2.0 - (k % 2) * 0.6), lerpf(-12.0, 12.0, hash01(1462 + k)), lerpf(0.94, 1.05, hash01(k)),
				Color("#5C4A36").lerp(crowd_tint(1462 + k), 0.4), G_LAYER, ["cap", "bare", "bare"][k % 3], 0.45)


## BG-T4 · réfectoire, une lampe pour toute la salle (PL-F6T-4, PL-ED-2).
func bg_t4(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(14, 0.2, 14), Vector3(0, -0.1, -4), m["dust"], Vector3.ZERO, 2.0)
	b(set["lit"], Vector3(14, 3.4, 0.3), Vector3(0, 1.7, -10.5), m["wall"], Vector3.ZERO, 1.2)
	b(set["lit"], Vector3(14, 0.2, 14), Vector3(0, 3.4, -4), m["dark"])
	for row: int in 3:
		var z: float = -2.0 - row * 2.6
		b(set["lit"], Vector3(6.0, 0.08, 0.9), Vector3(0, 0.76, z), m["wood"])
		for side: float in [-1.0, 1.0]:
			b(set["lit"], Vector3(6.0, 0.06, 0.32), Vector3(0, 0.45, z + side * 0.75), m["wood"])
		for x: float in [-2.8, 2.8]:
			b(set["lit"], Vector3(0.08, 0.76, 0.7), Vector3(x, 0.38, z), m["dark"])
		for k: int in 6:
			cyl(set["lit"], 0.07, 0.05, Transform3D(Basis(), Vector3(-2.3 + k * 0.92, 0.83, z + (0.22 if k % 2 == 0 else -0.22))), m["steel"], 10)
	mine_lamp(root, set, Vector3(0.0, 2.6, -4.6), 3.0)
	commit(root, set, G_BG)
	return {"camera": camera(root, Vector3(1.4, 1.75, 2.6), Vector3(-0.3, 0.9, -6.0), 54.0),
			"environment": environment(Color("#1E1610"), 0.45, Color("#1E1610"), 0.05, 1.05)}


## MID de PL-ED-2 : une place gardée (bol retourné, siège vide).
func layer_pl_ed_2_kept_seat(root: Node3D, _info: Dictionary) -> void:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(0.42, 0.04, 0.38), Vector3(0.1, 0.48, -1.2), lit(BB.L_FLAT, Color(0.5, 0.36, 0.24), 0.1))
	b(set["lit"], Vector3(0.42, 0.5, 0.04), Vector3(0.1, 0.72, -1.0), lit(BB.L_FLAT, Color(0.5, 0.36, 0.24), 0.1))
	cyl(set["lit"], 0.08, 0.06, Transform3D(Basis(), Vector3(0.1, 0.83, -1.55)), m["steel"], 12)
	b(set["lit"], Vector3(0.16, 0.01, 0.12), Vector3(0.28, 0.805, -1.55), flat(Color(0.82, 0.8, 0.74), 0.0), Vector3(0, 18, 0))
	commit(root, set, G_LAYER)


## BG-T5 · dehors, la poussière, des lampes (PL-ED-3).
func bg_t5(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = tycho_mats()
	b(set["lit"], Vector3(160, 0.3, 160), Vector3(0, -0.15, -50), m["dust"], Vector3.ZERO, 5.0)
	for k: int in 9:
		var p: Vector3 = Vector3(-8.0 + k * 2.2, 0, -6.0 - k * 4.0)
		b(set["lit"], Vector3(0.1, 3.4, 0.1), p + Vector3(0, 1.7, 0), m["dark"])
		mine_lamp(root, set, p + Vector3(0.3, 3.3, 0), 1.6)
	for k: int in 5:
		var c: Vector3 = Vector3(lerpf(-20, 20, hash01(k * 7)), 0, -40.0 - k * 6.0)
		b(set["lit"], Vector3(6.0, 3.0, 5.0), c + Vector3(0, 1.5, 0), m["rust"])
		glow_quad(set["emis"], c + Vector3(-1.0, 1.6, 2.51), Vector3(0.4, 0, 0), Vector3(0, 0.3, 0), Color("#FFC070"), 2.0)
	commit(root, set, G_BG)
	omni(root, Vector3(0, 30.0, -30.0), Color("#B89878"), 1.2, 100.0)
	return {"camera": camera(root, Vector3(-4.0, 1.7, 5.0), Vector3(2.0, 2.0, -30.0), 52.0, 250.0),
			"environment": environment(Color("#3A2E24"), 0.55, Color("#5A4634"), 0.045, 1.0)}


# === S8 · archives, bureau de l'Arbitrage, coursive de l'Anneau C ========================

## BG-X2 · archives du sous-sol 3 (PL-F8-4, PL-EC-3) : rayonnages, lampe de bureau.
func bg_x2(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = cabin_mats(0.3)
	b(set["lit"], Vector3(10, 0.1, 16), Vector3(0, -0.05, -6), m["floor"])
	b(set["lit"], Vector3(10, 0.1, 16), Vector3(0, 2.8, -6), lit(BB.L_FLAT, Color(0.2, 0.2, 0.22), 0.1))
	for row: int in 4:
		for side: float in [-1.0, 1.0]:
			var x: float = side * (1.2 + row * 0.0)
			var z0: float = -2.0 - row * 2.6
			b(set["lit"], Vector3(0.5, 2.4, 2.0), Vector3(x * 1.4, 1.2, z0), m["frame"])
			for shelf: int in 5:
				b(set["lit"], Vector3(0.52, 0.03, 2.0), Vector3(x * 1.4, 0.25 + shelf * 0.48, z0), m["frame"])
				for k: int in 6:
					var col: Color = Color(0.5, 0.42, 0.3).lerp(Color(0.36, 0.38, 0.4), hash01(row * 97 + shelf * 13 + k + int(side * 5)))
					b(set["lit"], Vector3(0.42, 0.34, 0.28), Vector3(x * 1.4 - side * 0.02, 0.44 + shelf * 0.48, z0 - 0.8 + k * 0.32), flat(col, 0.0))
	# Bureau et lampe au premier plan.
	b(set["lit"], Vector3(1.4, 0.05, 0.7), Vector3(0.1, 0.76, -0.6), m["wood"])
	b(set["lit"], Vector3(0.03, 0.42, 0.03), Vector3(0.6, 0.98, -0.75), m["frame"], Vector3(0, 0, -15))
	cyl(set["lit"], 0.1, 0.1, Transform3D(Basis(Vector3.BACK, deg_to_rad(35)), Vector3(0.5, 1.2, -0.75)), lit(BB.L_FLAT, DS.STATE_GREEN.darkened(0.6), 0.3), 12)
	for k: int in 3:
		b(set["lit"], Vector3(0.3, 0.008, 0.21), Vector3(-0.1 + k * 0.08, 0.79 + k * 0.006, -0.55), flat(Color(0.84, 0.8, 0.7), 0.0), Vector3(0, k * 9.0, 0))
	commit(root, set, G_BG)
	omni(root, Vector3(0.45, 1.05, -0.65), Color("#FFC890"), 1.8, 3.0)
	for k: int in 3:
		omni(root, Vector3(0, 2.5, -3.0 - k * 3.0), Color("#E8C890").darkened(0.3), 0.6, 4.0)
	return {"camera": camera(root, Vector3(-0.5, 1.5, 1.6), Vector3(0.2, 1.0, -8.0), 54.0),
			"environment": environment(Color("#1C1C1F"), 0.5, Color("#16161A"), 0.05, 1.05)}


## BG-X3 · bureau au-dessus du Hall (PL-F4-2) : porte, serrure, baie plongeante.
func bg_x3(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = cabin_mats(0.2)
	var o: Vector3 = Vector3(0, 4.0, 0) # le bureau surplombe le Hall de 4 m
	b(set["lit"], Vector3(6, 0.1, 5), o + Vector3(0, -0.05, -1.0), lit(BB.L_FLAT, Color(0.3, 0.3, 0.32), 0.2))
	b(set["lit"], Vector3(6, 0.1, 5), o + Vector3(0, 2.9, -1.0), lit(BB.L_FLAT, Color(0.4, 0.4, 0.42), 0.1))
	# Baie vitrée basse (mur du fond) donnant sur le Hall en contrebas.
	b(set["lit"], Vector3(6, 0.9, 0.2), o + Vector3(0, 0.45, -3.5), m["frame"])
	b(set["lit"], Vector3(6, 0.5, 0.2), o + Vector3(0, 2.65, -3.5), m["frame"])
	for x: float in [-2.0, 0.0, 2.0]:
		b(set["lit"], Vector3(0.08, 1.5, 0.12), o + Vector3(x, 1.65, -3.5), m["frame"])
	quad(set["holo"], o + Vector3(0, 1.65, -3.45), Vector3(3.0, 0, 0), Vector3(0, 0.75, 0), Vector2(0.4, 3), Color(BB.KEY.r, BB.KEY.g, BB.KEY.b, 0.05))
	# Porte à droite, serrure (voyant jaune), bureau, siège.
	b(set["lit"], Vector3(0.1, 2.2, 1.0), o + Vector3(2.9, 1.1, -0.2), m["dark"])
	b(set["lit"], Vector3(0.05, 0.16, 0.1), o + Vector3(2.84, 1.05, 0.15), m["frame"])
	glow_quad(set["emis"], o + Vector3(2.81, 1.12, 0.15), Vector3(0, 0, 0.02), Vector3(0, 0.01, 0), BB.YELLOW, 2.2)
	b(set["lit"], Vector3(1.8, 0.06, 0.8), o + Vector3(-1.2, 0.76, -1.6), lit(BB.L_FLAT, Color(0.16, 0.16, 0.18), 0.5))
	# Le Hall en contrebas (sol, barrières, bandeaux) vu à travers la baie.
	var hall: Dictionary = new_set()
	b(hall["lit"], Vector3(30, 0.2, 30), Vector3(0, -0.1, -12), lit(BB.L_CONCRETE, Color(0.36, 0.38, 0.42), 0.0, 1.0), Vector3.ZERO, 2.0)
	for z: float in [-7.0, -9.0, -11.0, -13.0]:
		barriers(hall, Vector3(-4.0, 0, z), 6, Vector3(1.6, 0, 0))
	for k: int in 6:
		glow_quad(hall["emis"], Vector3(-7.5 + k * 3.0, 0.02, -16.0), Vector3(0.6, 0, 0), Vector3(0, 0, -0.06), BB.TEAL_DIM.lightened(0.2), 1.4)
	commit(root, set, G_BG)
	commit(root, hall, G_BG)
	omni(root, o + Vector3(0, 2.4, -0.5), Color("#E8E0C0"), 1.4, 5.0)
	omni(root, Vector3(0, 5.0, -11.0), BB.KEY.lerp(BB.STEEL, 0.5), 2.4, 14.0)
	omni(root, Vector3(-6, 2.5, -10.0), BB.TEAL_DIM, 2.0, 9.0)
	omni(root, Vector3(6, 2.5, -10.0), BB.ROSE_DIM, 2.0, 9.0)
	return {"camera": camera(root, o + Vector3(0.3, 1.75, -2.85), Vector3(-0.5, 0.0, -10.0), 64.0),
			"environment": environment(Color("#2A2A2E"), 0.55, DS.BG_PANEL.lerp(BB.STEEL, 0.3), 0.025, 1.05)}


func layer_pl_f4_2_queue_below(root: Node3D, _info: Dictionary) -> void:
	for k: int in 16:
		var p: Vector3 = Vector3(-5.0 + (k % 8) * 1.4 + (0.7 if k >= 8 else 0.0), 0, -8.0 - (2.0 if k >= 8 else 0.0) - hash01(k) * 0.4)
		person(root, p, -90.0 + lerpf(-15.0, 15.0, hash01(1422 + k)), lerpf(0.92, 1.06, hash01(k * 3)), crowd_tint(1422 + k), G_LAYER,
				["bare", "hood", "cap"][k % 3], 0.5)


## BG-C1 · coursive de l'Anneau C (PL-F9-4) : passerelle couverte, pluie (FX).
func bg_c1(root: Node3D) -> Dictionary:
	var set: Dictionary = new_set()
	var m: Dictionary = hall_mats()
	b(set["lit"], Vector3(5, 0.2, 40), Vector3(0, -0.1, -14), lit(BB.L_CONCRETE, Color(0.3, 0.32, 0.36), 0.0, 1.0), Vector3.ZERO, 2.0)
	for side: float in [-1.0, 1.0]:
		for k: int in 14:
			b(set["lit"], Vector3(0.12, 3.4, 0.12), Vector3(side * 2.4, 1.7, 2.0 - k * 3.0), m["chrome"])
		b(set["lit"], Vector3(0.06, 0.06, 40), Vector3(side * 2.4, 1.05, -14), m["chrome"])
	b(set["lit"], Vector3(5.4, 0.12, 40), Vector3(0, 3.4, -14), m["dark"])
	for k: int in 12:
		glow_quad(set["emis"], Vector3(0, 3.33, 1.0 - k * 3.0), Vector3(0.5, 0, 0), Vector3(0, 0, 0.06), BB.KEY.lerp(BB.STEEL, 0.4), 1.4)
	# Façades de l'Anneau de part et d'autre (fenêtres procédurales).
	for side: float in [-1.0, 1.0]:
		quad(set["emis"], Vector3(side * 9.0, 4.0, -18.0), Vector3(0, 0, 20.0) * side, Vector3(0, 8.0, 0), Vector2(1.0, 3),
				Color(BB.WINDOW_TINTS[2].r, BB.WINDOW_TINTS[2].g, BB.WINDOW_TINTS[2].b, 77.0 / 255.0))
	commit(root, set, G_BG)
	for k: int in 5:
		omni(root, Vector3(0, 3.0, 0.0 - k * 6.0), BB.KEY.lerp(BB.STEEL, 0.5), 1.2, 6.0)
	omni(root, Vector3(-6, 3.0, -10.0), BB.TEAL_DIM, 1.6, 12.0)
	omni(root, Vector3(6, 3.0, -10.0), BB.ROSE_DIM, 1.4, 12.0)
	return {"camera": camera(root, Vector3(0.4, 1.65, 5.5), Vector3(0, 1.3, -20.0), 52.0),
			"environment": environment(DS.BG_PANEL, 0.5, DS.BG_PANEL.lerp(BB.STEEL, 0.3), 0.04, 1.0)}


func layer_pl_f9_4_crowd(root: Node3D, _info: Dictionary) -> void:
	crowd(root, Vector3(0.0, 0, -2.0), 16, Vector2(1.9, 4.0), 180.0, 1493, G_LAYER)
