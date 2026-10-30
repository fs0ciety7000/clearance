## Pipeline des planches de cinématique (M14 §3.6, B89 phase 1, D-184).
##
## Rend **hors ligne et de façon déterministe** des planches peintes à partir
## de décors 3D figés construits par l'outil (mêmes matériaux que le guichet,
## D-073 : `booth_decor` + couches AmbientCG CC0, `booth_emissive`,
## `booth_holo`), puis applique la passe `plate_paint.gdshader` (Kuwahara,
## rampe de 8 tons, encre, grain). **Aucun texte n'est cuit** : numéros,
## écrans et légendes sont des `Label` posés à l'exécution (le manifeste donne
## leurs ancres en pixels de planche).
##
## Chaque planche est une pile de couches (M14 §3.3) :
## - `BG` fond opaque 2048×1152 ;
## - `MID` / `FIG` couches transparentes (même caméra ; alpha = passe de masque) ;
## - `LIT_nn` (PL-F9-1) : découpes de l'état « allumé » d'un élément du fond,
##   que l'écran éteint une à une (le fond peint est l'état éteint) ;
## - ancres `HOLO` (rectangles où l'écran pose `plate_holo.gdshader`) et
##   `LABEL` (textes runtime).
## Passes par couche : couleur (MSAA 4×, sans TAA, glow figé, temps figé :
## `wet_motion`, `fx_intensity`, `flicker` à 0), G-buffer (normale de vue
## octaédrique + profondeur log), masque (MID/FIG), puis peinture.
##
## Usage (racine du projet, sous xvfb, pilote `opengl3` comme `qa_capture.gd`) :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/build_plates.gd -- [--only=PL-F9-1,PL-F10-3] [--variant=a|b|all]
##       [--mockups] [--verify]
## `--mockups` : écrit aussi `docs/mockups/m14_plate_<id>[_alt][_composed].png`
## (planche à plat 1920×1080, et composition figée : parallaxe, HOLO, légende).
## `--verify` : rend chaque planche deux fois et compare les SHA-256.
## Variable d'environnement `PLATES_DEBUG=<dossier>` : y écrit aussi la passe
## couleur brute du fond et la passe d'identifiants (mise au point).
## Sorties : `art_src/plates/<plate>/<variante>/*.png` (sources 8 bits) + `.webp`
## (mesure du poids à l'import Lossy 0,75), `art_src/plates/manifest.json`.
##
## Phase 1 (validation de DA) : les recettes des planches sont des
## dictionnaires de ce fichier, champ pour champ alignés sur `PlateDef` /
## `PlateLayerDef` (ARCHITECTURE, section M14, lot A) ; en phase 2 elles seront
## lues dans `data/cinematics/plates/*.tres`.
extends SceneTree

const BB = preload("res://tools/build_booth.gd")

const PAINT_SHADER: String = "res://assets/shaders/plate_paint.gdshader"
const HOLO_SHADER: String = "res://assets/shaders/plate_holo.gdshader"
const DECOR_SHADER: String = "res://assets/shaders/booth_decor.gdshader"
const EMISSIVE_SHADER: String = "res://assets/shaders/booth_emissive.gdshader"
const BOOTH_HOLO_SHADER: String = "res://assets/shaders/booth_holo.gdshader"
const ALBEDO_ARRAY: String = "res://assets/textures/booth/tex_booth_albedo_rough.png"
const NORMAL_ARRAY: String = "res://assets/textures/booth/tex_booth_normal_metal.png"
const SILHOUETTE: String = "res://assets/models/passenger/imp_silhouette.res"
const SRC_DIR: String = "res://art_src/plates"
const MOCKUP_DIR: String = "res://docs/mockups"

## Format des fonds (M14 §3.3) : 1920×1080 + ≈ 6 % de marge (parallaxe, zoom).
const PLATE_SIZE: Vector2i = Vector2i(2048, 1152)
const VIEW_SIZE: Vector2i = Vector2i(1920, 1080)
## Zone sûre Steam Deck (16:10) au centre de la vue 1080p.
const SAFE_SIZE: Vector2i = Vector2i(1728, 1080)
## Images attendues avant lecture (pipeline de rendu stabilisé, glow compris).
const SETTLE_FRAMES: int = 4
## Parallaxe et zoom figés pour la capture composée (M14 §3.3 : ≤ 12 px, ≤ 1,04).
const COMPOSE_PARALLAX: Vector2 = Vector2(-8.0, -3.0)
const COMPOSE_ZOOM: float = 1.02
## Légende : style sous-titre DS §7.10 agrandi (≥ 1,25 × corps, M14 §3.3).
const CAPTION_SCALE: float = 1.25

## Groupes de nœuds (visibilité par passe).
const G_BG: StringName = &"plate_bg"
const G_LIT: StringName = &"plate_lit"
const G_OFF: StringName = &"plate_off"
const G_MID: StringName = &"plate_mid"
const G_ADDITIVE: StringName = &"plate_additive"
## Zones d'état (une par élément éteignable) : passe d'identifiants seulement.
const G_ID: StringName = &"plate_id"
## Code d'identifiant n (1..12) dans le rouge de la passe d'identifiants :
## ID_BASE + n × ID_STEP (les codes < 48 sont déformés par la sortie 8 bits).
const ID_BASE: int = 52
const ID_STEP: int = 12

## Traitements picturaux (variantes soumises au client, M14 §8).
## A « aplats encrés » : Kuwahara r4, 8 tons francs, encre 2 px, grain ordonné.
## B « lavis gravé » : Kuwahara r6, marches adoucies, chroma plus présente,
## encre fine, hachures dans les ombres, papier.
const VARIANTS: Dictionary[String, Dictionary] = {
	"a": {
		"label": "A — aplats encrés", "suffix": "", "radius": 4, "tone_gamma": 0.72, "band_soft": 0.0, "chroma_keep": 0.3,
		"ink_alpha": 0.92, "ink_width": 1.0, "hatch_alpha": 0.0, "grain_alpha": 0.04, "paper_alpha": 0.0,
	},
	"b": {
		"label": "B — lavis gravé", "suffix": "_alt", "radius": 6, "tone_gamma": 0.8, "band_soft": 0.45, "chroma_keep": 0.5,
		"ink_alpha": 0.6, "ink_width": 1.0, "hatch_alpha": 0.32, "grain_alpha": 0.03, "paper_alpha": 0.05,
	},
}

## Recettes (phase 1) — champs alignés sur `PlateDef` (M14 §3.3–§3.6).
## `dominant` : couleur de la fin (M14 §3.3, « Couleur ») ; `ramp_mix` : part de
## la dominante dans chaque ton de la rampe (sombre → clair).
var plates: Dictionary[String, Dictionary] = {
	"PL-F9-1": {
		"background": "BG-H12", "decor": "S1", "builder": "_scene_h12", "mockup": "m14_plate_f9_1",
		"dominant": BB.STEEL, "ramp_mix": [0.0, 0.2, 0.3, 0.35, 0.3, 0.2, 0.1, 0.0],
		"caption_key": "cin_f9_1", "caption": "14:00. Le 04 s'éteint. Puis le 05. Puis toutes.",
		## Instant figé de la capture composée : 04 et 05 éteintes, 06 s'éteint.
		"compose_off": {3: 0.0, 4: 0.0, 5: 0.45},
	},
	"PL-F10-3": {
		"background": "BG-X1", "decor": "S8", "builder": "_scene_x1", "mockup": "m14_plate_f10_3",
		"dominant": DS.STATE_GREEN, "ramp_mix": [0.0, 0.06, 0.1, 0.13, 0.12, 0.08, 0.04, 0.0],
		## Lumières chaudes (lampes de classe) : les tons clairs tirent vers l'ambre monde.
		"light": BB.SPILL, "light_mix": [0.0, 0.0, 0.0, 0.0, 0.06, 0.14, 0.2, 0.12],
		"caption_key": "cin_f10_3", "caption": "À l'école de l'Anneau C, on ajoute des bancs.",
		"compose_off": {},
	},
}

var _decor_mat: ShaderMaterial = null
var _emissive_mat: ShaderMaterial = null
var _holo_mat: ShaderMaterial = null
var _gbuffer_mat: ShaderMaterial = null
var _mask_black: ShaderMaterial = null
var _mask_white: ShaderMaterial = null
var _silhouette_shader: Shader = null
var _failures: int = 0
var _manifest: Dictionary = {}


func _initialize() -> void:
	await process_frame # autoloads (Settings, EventBus…) avant de charger les scripts
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: PackedStringArray = []
	var variants: PackedStringArray = ["a", "b"]
	var mockups: bool = false
	var verify: bool = false
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--variant="):
			var v: String = arg.trim_prefix("--variant=")
			variants = PackedStringArray(["a", "b"]) if v == "all" else PackedStringArray([v])
		elif arg == "--mockups":
			mockups = true
		elif arg == "--verify":
			verify = true
	if DisplayServer.get_name() == "headless":
		push_error("build_plates: rendu requis — lancer sous xvfb avec --rendering-driver opengl3")
		quit(1)
		return
	_make_materials()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SRC_DIR))
	_manifest = {
		"tool": "tools/build_plates.gd", "godot": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "plates": {},
	}
	for plate_id: String in plates:
		if not only.is_empty() and not only.has(plate_id):
			continue
		for variant: String in variants:
			var t0: int = Time.get_ticks_msec()
			var result: Dictionary = await _build_plate(plate_id, variant, mockups)
			result["render_ms"] = Time.get_ticks_msec() - t0
			if verify:
				var first: Dictionary = (result["files"] as Dictionary).duplicate(true)
				var again: Dictionary = await _build_plate(plate_id, variant, false)
				var identical: bool = true
				for path: String in first:
					if (first[path] as Dictionary)["sha256"] != ((again["files"] as Dictionary)[path] as Dictionary)["sha256"]:
						identical = false
						push_error("build_plates: %s non déterministe (rect %s / %s)" % [path, (first[path] as Dictionary)["rect"],
								((again["files"] as Dictionary)[path] as Dictionary)["rect"]])
				result["deterministic"] = identical
				if not identical:
					_failures += 1
			(_manifest["plates"] as Dictionary)["%s/%s" % [plate_id, variant]] = result
			print("build_plates: %s variante %s — %d ms, %s, VRAM %.1f Mo%s" % [plate_id, variant, result["render_ms"],
					_kb(result["webp_bytes"]), float(result["vram_bytes"]) / 1048576.0,
					("" if not verify else (", déterministe" if result["deterministic"] else ", NON déterministe"))])
	var f: FileAccess = FileAccess.open(SRC_DIR.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_manifest, "\t", true))
	f.close()
	print("build_plates: %s" % ("OK" if _failures == 0 else "ÉCHEC (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


static func _kb(bytes: Variant) -> String:
	return "%d Ko (WebP)" % int(round(float(bytes) / 1024.0))


# --- Matériaux --------------------------------------------------------------------

func _make_materials() -> void:
	_decor_mat = ShaderMaterial.new()
	_decor_mat.shader = load(DECOR_SHADER) as Shader
	_decor_mat.set_shader_parameter("albedo_rough", load(ALBEDO_ARRAY))
	_decor_mat.set_shader_parameter("normal_metal", load(NORMAL_ARRAY))
	_decor_mat.set_shader_parameter("wet_motion", 0.0) # temps figé (ruissellement)
	_emissive_mat = ShaderMaterial.new()
	_emissive_mat.shader = load(EMISSIVE_SHADER) as Shader
	_emissive_mat.set_shader_parameter("fx_intensity", 0.0) # néons et vitrages figés
	_emissive_mat.set_shader_parameter("flicker", 0.0)
	_holo_mat = ShaderMaterial.new()
	_holo_mat.shader = load(BOOTH_HOLO_SHADER) as Shader
	_holo_mat.set_shader_parameter("fx_intensity", 0.0)
	_holo_mat.set_shader_parameter("flicker", 0.0)
	_gbuffer_mat = _inline_material("""
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;
// G-buffer des planches : normale de vue (octaédrique, rg) + profondeur log (b).
// Passe technique (environnement plat, tonemap linéaire) : codes écrits tels quels.
const float NEAR_D = 0.2;
const float FAR_D = 120.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	vec2 o = n.xy / (abs(n.x) + abs(n.y) + abs(n.z));
	if (n.z < 0.0) {
		o = (1.0 - abs(o.yx)) * vec2(o.x >= 0.0 ? 1.0 : -1.0, o.y >= 0.0 ? 1.0 : -1.0);
	}
	float d = clamp(log(max(-VERTEX.z, NEAR_D) / NEAR_D) / log(FAR_D / NEAR_D), 0.0, 0.998);
	ALBEDO = vec3(o * 0.5 + 0.5, d);
}
""")
	_mask_black = _inline_material("shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nvoid fragment() { ALBEDO = vec3(0.0); }\n")
	_mask_white = _inline_material("shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nvoid fragment() { ALBEDO = vec3(1.0); }\n")
	_silhouette_shader = Shader.new()
	# Silhouettes anonymes des planches : `impostor_silhouette` sans balancement (figé).
	_silhouette_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 fill : source_color = vec4(0.063, 0.075, 0.106, 1.0);
uniform vec4 tint : source_color = vec4(0.23, 0.26, 0.32, 1.0);
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.9;
uniform float tint_mix = 0.35;
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
	ALBEDO = mix(fill.rgb, tint.rgb, tint_mix) + rim * fresnel * rim_strength;
}
"""


func _inline_material(code: String) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _silhouette_material(tint: Color, rim: float = 0.9) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _silhouette_shader
	mat.set_shader_parameter("fill", DS.BG_PANEL)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rim_left", BB.TEAL_DIM)
	mat.set_shader_parameter("rim_right", BB.ROSE_DIM)
	mat.set_shader_parameter("rim_strength", rim)
	return mat


# --- Géométrie (format de sommets de `build_booth.gd`, D-073) ---------------------

## Pavé : `uv2` / `color` selon le type de `geo` (LIT : couche + mouillé, teinte +
## métal ; EMISSIVE : énergie + mode, teinte + graine ; HOLO : énergie + mode,
## teinte + opacité). `tile` : tuilage en mètres (LIT), sinon UV 0..1 par face.
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


func lit(layer: float, tint: Color, metal: float = 0.0, wet: float = 0.0) -> Array:
	return [Vector2(layer, wet), Color(tint.r, tint.g, tint.b, metal)]


## Quadrilatère orienté : centre, demi-axes `u` et `v` (monde), normale = u × v.
func quad(geo: BB.Geo, center: Vector3, u: Vector3, v: Vector3, uv2: Vector2, color: Color) -> void:
	var pts: Array[Vector3] = [center - u - v, center + u - v, center + u + v, center - u + v]
	# UV : x le long de u, y = 0 en haut (côté +v) → 1 en bas.
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	geo.quad(pts, u.cross(v).normalized(), uvs, uv2, color)


func _mesh_node(parent: Node3D, geo: BB.Geo, mat: Material, group: StringName, additive: bool = false) -> MeshInstance3D:
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


func _silhouette(parent: Node3D, pos: Vector3, yaw_deg: float, scale: float, tint: Color, group: StringName, rim: float = 0.9) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = load(SILHOUETTE) as Mesh
	mi.material_override = _silhouette_material(tint, rim)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), pos)
	mi.add_to_group(group)
	parent.add_child(mi)


func _primitive(parent: Node3D, mesh: PrimitiveMesh, xf: Transform3D, tint: Color, group: StringName, rim: float = 0.55) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _silhouette_material(tint, rim)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xf
	mi.add_to_group(group)
	parent.add_child(mi)


func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)


func _environment(ambient: Color, ambient_energy: float, fog: Color, fog_density: float, exposure: float) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DS.BG_VOID
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	return env


## Environnement des passes techniques (G-buffer, masque) : sortie brute.
func _flat_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	return env


static func _hash(x: int) -> float:
	var h: int = (x * 73856093) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


# --- S1 : BG-H12 « arc des douze vitres » (PL-F9-1) --------------------------------

## Douze façades de guichet sur un arc concave vu depuis le Hall. Le fond est
## l'état **éteint** ; l'état allumé (vitre, intérieur, lueur au sol, reflet)
## est rendu à part et découpé en 12 couches `LIT_nn` que l'écran éteint une à
## une (1 toutes les 0,5 s, M14 §3.4). Plaques de numéro vierges : les numéros
## sont des `Label` (ancres `labels`).
func _scene_h12(root: Node3D) -> Dictionary:
	var stat: BB.Geo = BB.Geo.new(BB.Geo.LIT)
	var off: BB.Geo = BB.Geo.new(BB.Geo.LIT)
	var mid: BB.Geo = BB.Geo.new(BB.Geo.LIT)
	var emis: BB.Geo = BB.Geo.new(BB.Geo.EMISSIVE)
	var emis_lit: BB.Geo = BB.Geo.new(BB.Geo.EMISSIVE)
	var holo: BB.Geo = BB.Geo.new(BB.Geo.HOLO)
	var holo_lit: BB.Geo = BB.Geo.new(BB.Geo.HOLO)
	var concrete: Array = lit(BB.L_CONCRETE, Color(0.62, 0.64, 0.68), 0.0, 1.0)
	var panel: Array = lit(BB.L_FLAT, DS.BG_ELEVATED.lerp(BB.STEEL, 0.5), 0.3)
	var chrome: Array = lit(BB.L_CHROME, Color(0.78, 0.8, 0.84), 1.0)
	var plates_m: Array = lit(BB.L_PLATES, Color(0.4, 0.43, 0.48), 0.7)
	var dark_m: Array = lit(BB.L_PLATES, Color(0.2, 0.22, 0.26), 0.6)
	var hazard: Array = lit(BB.L_HAZARD, Color(0.8, 0.8, 0.8), 0.2)
	var void_m: Array = lit(BB.L_FLAT, DS.BG_PANEL, 0.0)
	var glass_off: Array = lit(BB.L_FLAT, DS.BG_ELEVATED, 0.85)
	var plaque: Array = lit(BB.L_FLAT, BB.SPILL.darkened(0.25), 0.1)
	var window_tint: Color = BB.KEY.lerp(DS.ACCENT_CYAN, 0.1)
	var center: Vector3 = Vector3(0, 0, 2.0)
	var radius: float = 13.0
	var step_deg: float = 8.4
	var count: int = 12
	var width: float = 2.0 * radius * sin(deg_to_rad(step_deg) * 0.5)
	var inner: float = width - 0.34
	var booths: Array[Transform3D] = []
	for i: int in count:
		var a: float = deg_to_rad((float(i) - (count - 1) * 0.5) * step_deg)
		var fwd: Vector3 = Vector3(-sin(a), 0, cos(a))
		var right: Vector3 = Vector3(cos(a), 0, sin(a))
		var xf: Transform3D = Transform3D(Basis(right, Vector3.UP, fwd), center - fwd * radius)
		booths.append(xf)
		# Pilier gauche (béton mouillé, collier chromé, pied de danger).
		box(stat, Vector3(0.34, 6.2, 0.6), xf * Transform3D(Basis(), Vector3(-width * 0.5, 3.1, 0.05)), concrete[0], concrete[1], 1.5)
		box(stat, Vector3(0.38, 0.07, 0.64), xf * Transform3D(Basis(), Vector3(-width * 0.5, 1.15, 0.05)), chrome[0], chrome[1])
		box(stat, Vector3(0.36, 0.24, 0.62), xf * Transform3D(Basis(), Vector3(-width * 0.5, 0.12, 0.05)), hazard[0], hazard[1], 0.5)
		if i == count - 1:
			box(stat, Vector3(0.34, 6.2, 0.6), xf * Transform3D(Basis(), Vector3(width * 0.5, 3.1, 0.05)), concrete[0], concrete[1], 1.5)
		# Comptoir côté Hall, liseré chromé.
		box(stat, Vector3(inner, 1.0, 0.5), xf * Transform3D(Basis(), Vector3(0, 0.5, 0.25)), plates_m[0], plates_m[1], 0.8)
		box(stat, Vector3(inner, 0.04, 0.6), xf * Transform3D(Basis(), Vector3(0, 1.02, 0.28)), chrome[0], chrome[1])
		# Bandeau haut et plaque de numéro (vierge : `Label` à l'exécution).
		box(stat, Vector3(inner, 0.7, 0.36), xf * Transform3D(Basis(), Vector3(0, 2.75, 0.12)), dark_m[0], dark_m[1], 0.8)
		box(stat, Vector3(0.5, 0.24, 0.03), xf * Transform3D(Basis(), Vector3(0, 2.78, 0.315)), plaque[0], plaque[1])
		box(stat, Vector3(inner, 0.05, 0.1), xf * Transform3D(Basis(), Vector3(0, 2.38, 0.05)), chrome[0], chrome[1])
		# Mur au-dessus, rail chromé.
		box(stat, Vector3(width, 3.0, 0.3), xf * Transform3D(Basis(), Vector3(0, 4.6, -0.25)), panel[0], panel[1])
		box(stat, Vector3(0.05, 3.0, 0.06), xf * Transform3D(Basis(), Vector3(width * 0.25, 4.6, -0.08)), dark_m[0], dark_m[1])
		box(stat, Vector3(width, 0.05, 0.06), xf * Transform3D(Basis(), Vector3(0, 5.2, -0.08)), dark_m[0], dark_m[1])
		box(stat, Vector3(width, 0.06, 0.14), xf * Transform3D(Basis(), Vector3(0, 3.4, -0.05)), chrome[0], chrome[1])
		# Cabine : parois sombres.
		box(stat, Vector3(0.05, 1.5, 1.7), xf * Transform3D(Basis(), Vector3(-inner * 0.5 + 0.03, 1.7, -0.85)), void_m[0], void_m[1])
		box(stat, Vector3(0.05, 1.5, 1.7), xf * Transform3D(Basis(), Vector3(inner * 0.5 - 0.03, 1.7, -0.85)), void_m[0], void_m[1])
		box(stat, Vector3(inner, 0.05, 1.7), xf * Transform3D(Basis(), Vector3(0, 2.42, -0.85)), void_m[0], void_m[1])
		# Bande de danger au sol devant le comptoir.
		box(stat, Vector3(inner - 0.1, 0.01, 0.1), xf * Transform3D(Basis(), Vector3(0, 0.005, 1.05)), hazard[0], hazard[1], 0.5)
		# Agent·e (silhouette, de face derrière la vitre) : jamais de visage (LORE §11).
		if _hash(i * 7 + 3) > 0.2:
			var p: Vector3 = xf * Vector3(lerpf(-0.25, 0.25, _hash(i * 11)), -0.3, -0.95)
			var yaw: float = rad_to_deg(atan2(fwd.x, fwd.z))
			_silhouette(root, p, yaw, 1.0, BB.STEEL, G_BG)
		# État éteint : vitre sombre réfléchissante, fond de cabine noir.
		quad(off, xf * Vector3(0, 1.72, 0.02), xf.basis * Vector3(inner * 0.5, 0, 0), xf.basis * Vector3(0, 0.66, 0),
				glass_off[0], glass_off[1])
		box(stat, Vector3(inner, 1.5, 0.05), xf * Transform3D(Basis(), Vector3(0, 1.7, -1.7)), void_m[0], void_m[1])
		# État allumé : fond de cabine lumineux (3 bandes), reflet de vitre, lueur et reflet au sol.
		for band: int in 3:
			var y0: float = 1.06 + band * 0.45
			quad(emis_lit, xf * Vector3(0, y0 + 0.225, -1.66), xf.basis * Vector3(inner * 0.5, 0, 0),
					xf.basis * Vector3(0, 0.225, 0), Vector2(0.75 + band * 0.32, 0), Color(window_tint.r, window_tint.g, window_tint.b, 0))
		quad(holo_lit, xf * Vector3(0, 1.72, 0.03), xf.basis * Vector3(inner * 0.5, 0, 0), xf.basis * Vector3(0, 0.66, 0),
				Vector2(0.6, 3), Color(window_tint.r, window_tint.g, window_tint.b, 0.18))
		quad(holo_lit, xf * Vector3(0, 0.012, 1.9), xf.basis * Vector3(inner * 0.45, 0, 0), xf.basis * Vector3(0, 0, -1.35),
				Vector2(1.0, 0), Color(window_tint.r, window_tint.g, window_tint.b, 0.4))
		quad(holo_lit, xf * Vector3(0, 0.014, 3.2), xf.basis * Vector3(inner * 0.32, 0, 0), xf.basis * Vector3(0, 0, -2.6),
				Vector2(1.0, 0), Color(window_tint.r, window_tint.g, window_tint.b, 0.3))
		# Zone d'état de la vitre (passe d'identifiants) : vitre + lueur au sol.
		var zone: BB.Geo = BB.Geo.new(BB.Geo.EMISSIVE)
		quad(zone, xf * Vector3(0, 1.72, 0.06), xf.basis * Vector3(inner * 0.5 + 0.04, 0, 0), xf.basis * Vector3(0, 0.7, 0), Vector2.ZERO, Color.BLACK)
		# Hauteur propre à chaque zone : les zones voisines se chevauchent près de la
		# caméra ; coplanaires, elles se disputeraient la profondeur (rendu instable).
		quad(zone, xf * Vector3(0, 0.02 + 0.004 * i, 2.05), xf.basis * Vector3(inner * 0.47, 0, 0), xf.basis * Vector3(0, 0, -1.5), Vector2.ZERO, Color.BLACK)
		var zone_node: MeshInstance3D = _mesh_node(root, zone, null, G_ID)
		zone_node.set_meta(&"plate_id", i + 1)
	# Sol, plafond bas, bandeaux lumineux rayonnants.
	box(stat, Vector3(60, 0.2, 40), Transform3D(Basis(), Vector3(0, -0.1, -2)), concrete[0], Color(0.42, 0.44, 0.47, 0.0), 3.0)
	box(stat, Vector3(60, 0.3, 40), Transform3D(Basis(), Vector3(0, 6.35, -2)), lit(BB.L_FLAT, DS.BG_PANEL, 0.2)[0], lit(BB.L_FLAT, DS.BG_PANEL, 0.2)[1])
	for k: int in 7:
		var a: float = deg_to_rad(-48.0 + k * 16.0)
		var dir: Vector3 = Vector3(sin(a), 0, -cos(a))
		var mid_p: Vector3 = center + dir * 7.5 + Vector3(0, 6.19, 0)
		quad(emis, mid_p, Vector3.UP.cross(dir) * 0.06, dir * 3.0, Vector2(0.55, 0), Color(BB.KEY.r, BB.KEY.g, BB.KEY.b, 0))
	# Œil du Consortium (hologramme de marque, hexagone) au-dessus de l'arc.
	var eye_c: Vector3 = center + Vector3(0, 4.7, -radius + 0.75)
	for k: int in 6:
		var a0: float = TAU * k / 6.0 + PI / 6.0
		var a1: float = TAU * (k + 1) / 6.0 + PI / 6.0
		var p0: Vector3 = eye_c + Vector3(cos(a0), sin(a0), 0) * 0.85
		var p1: Vector3 = eye_c + Vector3(cos(a1), sin(a1), 0) * 0.85
		quad(holo, (p0 + p1) * 0.5, (p1 - p0) * 0.5, (p1 - p0).cross(Vector3.BACK).normalized() * 0.035,
				Vector2(1.3, 1), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, 0.8))
	quad(holo, eye_c, Vector3(0.42, 0, 0), Vector3(0, 0.12, 0), Vector2(1.2, 4), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, 0.55))
	quad(holo, eye_c, Vector3(0.1, 0, 0), Vector3(0, 0.1, 0), Vector2(1.6, 1), Color(BB.YELLOW.r, BB.YELLOW.g, BB.YELLOW.b, 0.9))
	# Avant-plan (MID) : barrières magnétiques et deux personnes de dos.
	for k: int in 4:
		var p: Vector3 = Vector3(-4.6 + k * 1.15, 0.5, 3.6 + k * 0.08)
		box(mid, Vector3(0.07, 1.0, 0.07), Transform3D(Basis(), p), chrome[0], chrome[1])
		box(mid, Vector3(0.26, 0.04, 0.26), Transform3D(Basis(), Vector3(p.x, 0.02, p.z)), chrome[0], chrome[1])
		if k < 3:
			box(mid, Vector3(1.15, 0.05, 0.03), Transform3D(Basis(), Vector3(p.x + 0.575, 0.92, p.z + 0.04)),
					lit(BB.L_FLAT, BB.TEAL_DIM, 0.3)[0], lit(BB.L_FLAT, BB.TEAL_DIM, 0.3)[1])
	_silhouette(root, Vector3(-3.1, 0, 4.4), 180.0 - 8.0, 1.02, DS.BG_ELEVATED, G_MID, 0.5)
	_silhouette(root, Vector3(3.4, 0, 2.2), 180.0 + 14.0, 0.97, DS.BG_ELEVATED.lerp(BB.ROSE_DIM, 0.3), G_MID, 0.5)
	_mesh_node(root, stat, _decor_mat, G_BG)
	_mesh_node(root, off, _decor_mat, G_OFF)
	_mesh_node(root, mid, _decor_mat, G_MID)
	_mesh_node(root, emis, _emissive_mat, G_BG)
	_mesh_node(root, emis_lit, _emissive_mat, G_LIT)
	_mesh_node(root, holo, _holo_mat, G_BG, true)
	_mesh_node(root, holo_lit, _holo_mat, G_LIT, true)
	# Lumières : plafonniers acier, rims de hall teal / rose (palette monde).
	_omni(root, Vector3(0, 4.4, -6), BB.KEY.lerp(BB.STEEL, 0.5), 1.6, 9.0)
	_omni(root, Vector3(-6.0, 4.4, -3), BB.KEY.lerp(BB.STEEL, 0.5), 1.3, 8.0)
	_omni(root, Vector3(6.0, 4.4, -3), BB.KEY.lerp(BB.STEEL, 0.5), 1.3, 8.0)
	_omni(root, Vector3(-9.0, 2.5, 3.0), BB.TEAL_DIM, 2.0, 9.0)
	_omni(root, Vector3(9.0, 2.5, 3.0), BB.ROSE_DIM, 2.0, 9.0)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.1
	cam.far = 100.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.6, 12.0), Vector3(0, 1.5, -9.0), Vector3.UP)
	# Ancres : zone de chaque vitre (état allumé + lueur au sol), plaque de numéro.
	var lit_regions: Array = []
	var holo_rects: Array = []
	var labels: Array = []
	for i: int in count:
		var xf: Transform3D = booths[i]
		lit_regions.append([xf * Vector3(-inner * 0.5, 2.45, 0.05), xf * Vector3(inner * 0.5, 2.45, 0.05),
				xf * Vector3(-inner * 0.5, 0.0, 3.3), xf * Vector3(inner * 0.5, 0.0, 3.3),
				xf * Vector3(-inner * 0.5, 1.0, 0.5), xf * Vector3(inner * 0.5, 1.0, 0.5)])
		holo_rects.append([xf * Vector3(-inner * 0.5, 2.38, 0.03), xf * Vector3(inner * 0.5, 2.38, 0.03),
				xf * Vector3(-inner * 0.5, 1.06, 0.03), xf * Vector3(inner * 0.5, 1.06, 0.03)])
		labels.append({"id": "booth_%02d" % (i + 1), "text": "%02d" % (i + 1), "font": "mono",
				"points": [xf * Vector3(-0.25, 2.9, 0.33), xf * Vector3(0.25, 2.9, 0.33), xf * Vector3(-0.25, 2.66, 0.33), xf * Vector3(0.25, 2.66, 0.33)]})
	return {
		"camera": cam, "environment": _environment(DS.BG_ELEVATED, 0.6, DS.BG_PANEL.lerp(BB.STEEL, 0.35), 0.03, 1.1),
		"has_lit": true, "has_mid": true, "lit_regions": lit_regions, "holo_rects": holo_rects, "labels": labels,
	}


# --- S8 : BG-X1 « école de l'Anneau C » (PL-F10-3) ---------------------------------

## Lieu jamais modélisé : maquette en volumes simples construite par l'outil
## (pas de kit), même matériau et même peinture que le guichet. Fond = salle
## (murs, tableau holographique vierge, plafond, baie sur l'Anneau) ; MID =
## bancs d'origine, bancs **ajoutés** dépareillés (caisses de fret, rangée de
## sièges de navette, pupitre d'une autre couleur) et enfants en silhouettes
## anonymes, de dos (D-185 : aucun visage).
func _scene_x1(root: Node3D) -> Dictionary:
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
		var c: Vector3 = Vector3(-4.48, 1.55 + 0.18 * _hash(k * 5), -9.6 + k * 0.62)
		var p: Array = lit(BB.L_FLAT, paper_tints[k].darkened(0.1), 0.0)
		box(stat, Vector3(0.01, 0.34, 0.44), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lerpf(-5.0, 5.0, _hash(k)))), c), p[0], p[1])
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
		if _hash(k * 7 + 2) < 0.45:
			continue
		var wt: Color = BB.WINDOW_TINTS[k % BB.WINDOW_TINTS.size()]
		var wp: Vector3 = Vector3(15.8, lerpf(-4.0, 3.0, _hash(k * 3 + 1)), lerpf(-85.0, 10.0, _hash(k * 5 + 9)))
		box(emis, Vector3(0.05, 0.9, 0.7), Transform3D(Basis(), wp), Vector2(lerpf(1.6, 3.0, _hash(k)), 0), Color(wt.r, wt.g, wt.b, 0))
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
			_desk(mid, c, 1.7, desk_top, seat_m, chrome)
			for s: int in 2:
				seats.append(c + Vector3(-0.42 + s * 0.84, 0.45, 0.48))
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
		if _hash(k * 13 + 5) < 0.16:
			continue
		var s: Vector3 = seats[k] + Vector3(lerpf(-0.05, 0.05, _hash(k * 3)), 0, 0)
		_child(root, s, lerpf(0.86, 1.06, _hash(k * 17 + 1)), child_tints[k % child_tints.size()], int(_hash(k * 31 + 7) * 4.0), lerpf(-10.0, 10.0, _hash(k * 29)))
	# Deux enfants debout près de l'entrée (arrivés sans place).
	for k: int in 2:
		_silhouette(root, Vector3(2.9 + k * 0.55, 0, -1.3 - k * 0.35), 180.0 + (k * 2 - 1) * 12.0, 0.64,
				child_tints[(k + 2) % child_tints.size()], G_MID, 0.5)
	_mesh_node(root, stat, _decor_mat, G_BG)
	_mesh_node(root, mid, _decor_mat, G_MID)
	_mesh_node(root, emis, _emissive_mat, G_BG)
	_mesh_node(root, holo, _holo_mat, G_BG, true)
	for z: float in [-9.0, -5.5, -2.0]:
		_omni(root, Vector3(-1.6, 2.6, z), lamp, 1.3, 5.5)
		_omni(root, Vector3(1.6, 2.6, z), lamp, 1.3, 5.5)
	_omni(root, Vector3(-0.3, 1.8, -10.2), DS.STATE_GREEN.lerp(BB.TEAL_DIM, 0.6), 1.2, 4.5)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = 140.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.9, 1.8, 1.2), Vector3(-0.4, 0.95, -10.0), Vector3.UP)
	return {
		"camera": cam, "environment": _environment(DS.BG_ELEVATED.lerp(BB.SPILL, 0.1), 0.8, DS.BG_PANEL.lerp(DS.STATE_GREEN, 0.06), 0.03, 1.05),
		"has_lit": false, "has_mid": true, "lit_regions": [],
		"holo_rects": [[Vector3(-2.15, 2.5, -10.93), Vector3(1.55, 2.5, -10.93), Vector3(-2.15, 1.0, -10.93), Vector3(1.55, 1.0, -10.93)]],
		"labels": [],
	}


## Enfant assis vu de dos : buste aplati, épaules, tête, coiffure (0 courte,
## 1 queue de cheval, 2 capuche, 3 chignon). `h` : échelle de taille.
func _child(root: Node3D, seat: Vector3, h: float, tint: Color, hair: int, tilt_deg: float) -> void:
	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.12
	torso.height = 0.48
	_primitive(root, torso, Transform3D(Basis.from_scale(Vector3(1.3, 1.0, 0.8) * h), seat + Vector3(0, 0.24 * h, 0)), tint, G_MID)
	var shoulders: CapsuleMesh = CapsuleMesh.new()
	shoulders.radius = 0.07
	shoulders.height = 0.38
	_primitive(root, shoulders, Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3.ONE * h), seat + Vector3(0, 0.43 * h, 0)), tint, G_MID)
	var head_pos: Vector3 = seat + Vector3(0, 0.6 * h, 0.01)
	var tilt: Basis = Basis(Vector3.FORWARD, deg_to_rad(tilt_deg))
	var neck: CapsuleMesh = CapsuleMesh.new()
	neck.radius = 0.04
	neck.height = 0.14
	_primitive(root, neck, Transform3D(Basis.from_scale(Vector3.ONE * h), seat + Vector3(0, 0.5 * h, 0.0)),
			tint.lerp(BB.SPILL, 0.2).darkened(0.1), G_MID)
	# Vue de dos : la tête est la coiffure (ou la capuche), sans visage.
	var hair_tint: Color = DS.BG_ELEVATED.lerp(tint, 0.3)
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.1 if hair != 2 else 0.12
	head.height = 0.21 if hair != 2 else 0.24
	# Rim faible sur la tête : un anneau clair autour d'un disque sombre se lit comme un visage.
	_primitive(root, head, Transform3D(tilt.scaled(Vector3.ONE * h), head_pos), tint.darkened(0.12) if hair == 2 else hair_tint, G_MID, 0.12)
	if hair == 1 or hair == 3:
		var tail: SphereMesh = SphereMesh.new()
		# Chignon au sommet, queue de cheval sur la nuque : jamais au centre de la tête
		# (un disque cerné d'encre au milieu se lirait comme un visage).
		tail.radius = 0.05 if hair == 3 else 0.035
		tail.height = 0.1 if hair == 3 else 0.17
		var off: Vector3 = Vector3(0, 0.115, -0.01) if hair == 3 else Vector3(0, -0.12, 0.06)
		_primitive(root, tail, Transform3D(tilt.scaled(Vector3.ONE * h), head_pos + tilt * off * h), hair_tint, G_MID, 0.12)


func _desk(geo: BB.Geo, c: Vector3, w: float, top: Array, seat: Array, legs: Array) -> void:
	box(geo, Vector3(w, 0.05, 0.45), Transform3D(Basis(), c + Vector3(0, 0.74, 0)), top[0], top[1])
	box(geo, Vector3(w, 0.32, 0.03), Transform3D(Basis(), c + Vector3(0, 0.56, -0.21)), top[0], top[1])
	box(geo, Vector3(w, 0.05, 0.3), Transform3D(Basis(), c + Vector3(0, 0.43, 0.5)), seat[0], seat[1])
	for sx: float in [-0.5, 0.5]:
		box(geo, Vector3(0.05, 0.74, 0.05), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.37, -0.15)), legs[0], legs[1])
		box(geo, Vector3(0.05, 0.43, 0.05), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.215, 0.55)), legs[0], legs[1])
		box(geo, Vector3(0.04, 0.04, 0.75), Transform3D(Basis(), c + Vector3(sx * (w - 0.1), 0.06, 0.2)), legs[0], legs[1])


# --- Rendu ---------------------------------------------------------------------------

func _build_plate(plate_id: String, variant: String, mockups: bool) -> Dictionary:
	var recipe: Dictionary = plates[plate_id]
	var preset: Dictionary = VARIANTS[variant]
	var vp: SubViewport = SubViewport.new()
	vp.size = PLATE_SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 0
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Node3D = Node3D.new()
	vp.add_child(scene)
	var info: Dictionary = call(recipe["builder"], scene)
	var cam: Camera3D = info["camera"]
	cam.current = true
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = info["environment"]
	scene.add_child(we)
	var ramp: PackedColorArray = _ramp(recipe["dominant"], recipe["ramp_mix"], recipe.get("light", Color.WHITE), recipe.get("light_mix", []))
	var out_dir: String = SRC_DIR.path_join(plate_id).path_join(variant)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var files: Dictionary = {}
	var layers: Array = []
	var vram: int = 0
	var webp_total: int = 0
	# BG : état de base (éteint si la planche a un état allumé).
	var bg_color: Image = await _pass_color(vp, scene, [G_BG, G_OFF], info["environment"])
	if OS.has_environment("PLATES_DEBUG"):
		bg_color.save_png(OS.get_environment("PLATES_DEBUG") + "/%s_color.png" % plate_id)
	var bg_gbuf: Image = await _pass_gbuffer(vp, scene, [G_BG, G_OFF], we, info["environment"])
	var bg: Image = await _paint(bg_color, bg_gbuf, null, ramp, preset)
	_save_layer(bg, out_dir, "bg", files, layers, {"kind": "BG", "rect": [0, 0, PLATE_SIZE.x, PLATE_SIZE.y]})
	# Couches d'état allumé (découpes adoucies de l'état allumé, une par vitre).
	var lit_layers: Array = []
	if info["has_lit"]:
		var lit_color: Image = await _pass_color(vp, scene, [G_BG, G_LIT], info["environment"])
		var lit_gbuf: Image = await _pass_gbuffer(vp, scene, [G_BG, G_LIT], we, info["environment"])
		var lit_full: Image = await _paint(lit_color, lit_gbuf, null, ramp, preset)
		var ids: Image = await _pass_ids(vp, scene, [G_BG, G_OFF, G_ID], we, info["environment"])
		if OS.has_environment("PLATES_DEBUG"):
			ids.save_png(OS.get_environment("PLATES_DEBUG") + "/ids_%d.png" % Time.get_ticks_usec())
		var regions: Array = info["lit_regions"]
		for i: int in regions.size():
			var cut: Array = _id_sprite(lit_full, ids, i + 1, 18)
			if cut.is_empty():
				push_error("build_plates: zone d'état %d invisible" % (i + 1))
				_failures += 1
				continue
			var rect: Rect2i = cut[1]
			var sprite: Image = cut[0]
			var name: String = "lit_%02d" % (i + 1)
			_save_layer(sprite, out_dir, name, files, layers, {"kind": "LIT", "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
			lit_layers.append({"image": sprite, "rect": rect})
	# MID : avant-plan / foule, fond transparent (alpha = passe de masque).
	var mid_img: Image = null
	if info["has_mid"]:
		var groups: Array[StringName] = [G_BG, G_MID]
		if info["has_lit"]:
			groups.append(G_OFF)
		var mid_color: Image = await _pass_color(vp, scene, groups, info["environment"])
		var mid_gbuf: Image = await _pass_gbuffer(vp, scene, groups, we, info["environment"])
		var mask: Image = await _pass_mask(vp, scene, groups, we, info["environment"])
		mid_img = await _paint(mid_color, mid_gbuf, mask, ramp, preset)
		var used: Rect2i = mid_img.get_used_rect()
		var cropped: Image = mid_img.get_region(used)
		_save_layer(cropped, out_dir, "mid", files, layers, {"kind": "MID", "rect": [used.position.x, used.position.y, used.size.x, used.size.y]})
		mid_img = cropped
		(layers[layers.size() - 1] as Dictionary)["image_rect"] = used
	# Ancres HOLO et LABEL (pixels de planche).
	var holo_anchors: Array = []
	for pts: Array in info["holo_rects"]:
		var r: Rect2i = _project_rect(cam, pts)
		holo_anchors.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var label_anchors: Array = []
	for lab: Dictionary in info["labels"]:
		var r: Rect2i = _project_rect(cam, lab["points"])
		label_anchors.append({"id": lab["id"], "text": lab["text"], "font": lab["font"], "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
	for path: String in files:
		vram += int((files[path] as Dictionary)["vram_bytes"])
		webp_total += int((files[path] as Dictionary)["webp_bytes"])
	var result: Dictionary = {
		"background": recipe["background"], "decor": recipe["decor"], "variant": preset["label"],
		"size": [PLATE_SIZE.x, PLATE_SIZE.y], "camera": {"fov": cam.fov, "transform": var_to_str(cam.global_transform)},
		"ramp": Array(ramp).map(func(c: Color) -> String: return c.to_html(false)),
		"files": files, "holo": holo_anchors, "labels": label_anchors,
		"vram_bytes": vram, "webp_bytes": webp_total,
	}
	if mockups:
		var suffix: String = preset["suffix"]
		var flat: Image = _flatten(bg, lit_layers, layers, mid_img)
		_save_mockup(flat, "%s%s.png" % [recipe["mockup"], suffix])
		var composed: Image = await _compose(bg, lit_layers, layers, mid_img, recipe, holo_anchors, label_anchors)
		_save_mockup(composed, "%s%s_composed.png" % [recipe["mockup"], suffix])
		result["caption_contrast"] = _caption_contrast_min
	vp.queue_free()
	await process_frame
	return result


func _save_layer(img: Image, out_dir: String, layer_name: String, files: Dictionary, layers: Array, meta: Dictionary) -> void:
	var png: String = out_dir.path_join(layer_name + ".png")
	var webp: String = out_dir.path_join(layer_name + ".webp")
	if img.save_png(png) != OK or img.save_webp(webp, true, 0.75) != OK:
		push_error("build_plates: écriture impossible %s" % png)
		_failures += 1
		return
	var entry: Dictionary = meta.duplicate()
	# `PlateLayerDef.rect` (ARCHITECTURE §12 ter.1) : 0..1 sur 2048×1152.
	var r: Array = meta["rect"]
	entry["rect_norm"] = [float(r[0]) / PLATE_SIZE.x, float(r[1]) / PLATE_SIZE.y, float(r[2]) / PLATE_SIZE.x, float(r[3]) / PLATE_SIZE.y]
	entry["sha256"] = FileAccess.get_sha256(png)
	entry["md5"] = FileAccess.get_md5(png)
	entry["png_bytes"] = FileAccess.get_file_as_bytes(png).size()
	entry["webp_bytes"] = FileAccess.get_file_as_bytes(webp).size()
	entry["vram_bytes"] = img.get_width() * img.get_height() * 4
	files[png.trim_prefix(SRC_DIR + "/")] = entry
	meta["image"] = img
	layers.append(meta)


## Visibilité des groupes pour une passe ; les additifs restent visibles en couleur.
func _show(scene: Node3D, groups: Array[StringName]) -> void:
	for n: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		var visible: bool = false
		for g: StringName in groups:
			if gi.is_in_group(g):
				visible = true
		gi.visible = visible


func _grab(vp: SubViewport) -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _pass_color(vp: SubViewport, scene: Node3D, groups: Array[StringName], _env: Environment) -> Image:
	_show(scene, groups)
	vp.transparent_bg = false
	return await _grab(vp)


func _with_override(scene: Node3D, groups: Array[StringName], pick: Callable) -> Dictionary:
	var saved: Dictionary = {}
	_show(scene, groups)
	for n: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		saved[gi] = gi.material_override
		if gi.is_in_group(G_ADDITIVE):
			gi.visible = false # voiles additifs : pas de contour ni de masque
		gi.material_override = pick.call(gi)
	return saved


func _restore(saved: Dictionary, we: WorldEnvironment, env: Environment) -> void:
	for gi: GeometryInstance3D in saved:
		gi.material_override = saved[gi]
	we.environment = env


func _pass_gbuffer(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var saved: Dictionary = _with_override(scene, groups, func(_gi: GeometryInstance3D) -> Material: return _gbuffer_mat)
	we.environment = _flat_environment()
	var prev_msaa: Viewport.MSAA = vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED # pas de normales moyennées aux bords
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	vp.msaa_3d = prev_msaa
	_restore(saved, we, env)
	return img


## Passe d'identifiants : chaque zone d'état (groupe G_ID, méta `plate_id` = n)
## en rouge ID_BASE + n × ID_STEP, tout le reste en noir (occultants compris).
func _pass_ids(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var mats: Dictionary = {}
	var saved: Dictionary = _with_override(scene, groups, func(gi: GeometryInstance3D) -> Material:
		if not gi.is_in_group(G_ID):
			return _mask_black
		var n: int = int(gi.get_meta(&"plate_id", 0))
		if not mats.has(n):
			mats[n] = _inline_material("shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nvoid fragment() { ALBEDO = vec3(%s); }\n"
					% String.num(float(ID_BASE + n * ID_STEP) / 255.0, 8))
		return mats[n])
	var flat: Environment = _flat_environment()
	flat.background_color = Color.BLACK
	we.environment = flat
	var prev_msaa: Viewport.MSAA = vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	vp.msaa_3d = prev_msaa
	_restore(saved, we, env)
	return img


## Découpe de la zone `n` : boîte englobante des pixels d'identifiant n (+ marge),
## alpha = masque binaire flouté (deux flous en boîte de rayon `soft`, dilaté ×2).
## Rend [Image, Rect2i] ou [] si la zone est invisible.
func _id_sprite(src: Image, ids: Image, n: int, soft: int) -> Array:
	var data: PackedByteArray = ids.get_data()
	var w: int = ids.get_width()
	var h: int = ids.get_height()
	var lo: Vector2i = Vector2i(w, h)
	var hi: Vector2i = Vector2i(-1, -1)
	var code: int = ID_BASE + n * ID_STEP
	for y: int in h:
		var row: int = y * w * 4
		for x: int in w:
			if absi(data[row + x * 4] - code) <= 4:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return []
	var rect: Rect2i = Rect2i(lo, hi - lo + Vector2i.ONE).grow(soft * 2).intersection(Rect2i(Vector2i.ZERO, Vector2i(w, h)))
	var rw: int = rect.size.x
	var rh: int = rect.size.y
	var mask: PackedFloat32Array = []
	mask.resize(rw * rh)
	for y: int in rh:
		for x: int in rw:
			var v: int = data[((rect.position.y + y) * w + rect.position.x + x) * 4]
			mask[y * rw + x] = 1.0 if absi(v - code) <= 4 else 0.0
	for k: int in 2:
		mask = _box_blur(mask, rw, rh, soft)
	var img: Image = src.get_region(rect)
	img.convert(Image.FORMAT_RGBA8)
	var px: PackedByteArray = img.get_data()
	for i: int in rw * rh:
		px[i * 4 + 3] = int(round(clampf(mask[i] * 2.0, 0.0, 1.0) * 255.0))
	img.set_data(rw, rh, false, Image.FORMAT_RGBA8, px)
	return [img, rect]


## Flou en boîte séparable (sommes glissantes), bords répétés.
static func _box_blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp: PackedFloat32Array = []
	tmp.resize(w * h)
	var out: PackedFloat32Array = []
	out.resize(w * h)
	var norm: float = 1.0 / float(2 * r + 1)
	for y: int in h:
		var acc: float = 0.0
		for k: int in range(-r, r + 1):
			acc += src[y * w + clampi(k, 0, w - 1)]
		for x: int in w:
			tmp[y * w + x] = acc * norm
			acc += src[y * w + clampi(x + r + 1, 0, w - 1)] - src[y * w + clampi(x - r, 0, w - 1)]
	for x: int in w:
		var acc: float = 0.0
		for k: int in range(-r, r + 1):
			acc += tmp[clampi(k, 0, h - 1) * w + x]
		for y: int in h:
			out[y * w + x] = acc * norm
			acc += tmp[clampi(y + r + 1, 0, h - 1) * w + x] - tmp[clampi(y - r, 0, h - 1) * w + x]
	return out


func _pass_mask(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var saved: Dictionary = _with_override(scene, groups, func(gi: GeometryInstance3D) -> Material:
		return _mask_white if gi.is_in_group(G_MID) else _mask_black)
	var flat: Environment = _flat_environment()
	flat.background_color = Color.BLACK
	we.environment = flat
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	_restore(saved, we, env)
	return img


## Rampe de 8 tons : gris de la palette monde (DS + BOOTH §5) teintés par la dominante.
func _ramp(dominant: Color, mix_amounts: Array, light: Color, light_mix: Array) -> PackedColorArray:
	var base: Array[Color] = [DS.BG_VOID, DS.BG_PANEL, DS.BG_ELEVATED, BB.STEEL, DS.TEXT_MUTED, DS.TEXT_SECONDARY,
			BB.KEY.lerp(DS.TEXT_SECONDARY, 0.4), DS.TEXT_PRIMARY]
	var out: PackedColorArray = []
	for i: int in 8:
		var c: Color = base[i].lerp(dominant, float(mix_amounts[i]))
		out.append(c.lerp(light, float(light_mix[i])) if i < light_mix.size() else c)
	return out


func _paint(color: Image, gbuf: Image, mask: Image, ramp: PackedColorArray, preset: Dictionary) -> Image:
	var src: Image = color
	if mask != null:
		src = color.duplicate() as Image
		_apply_mask(src, mask)
	var vp: SubViewport = SubViewport.new()
	vp.size = PLATE_SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(src)
	rect.size = Vector2(PLATE_SIZE)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(PAINT_SHADER) as Shader
	mat.set_shader_parameter("source", rect.texture)
	mat.set_shader_parameter("gbuffer", ImageTexture.create_from_image(gbuf))
	mat.set_shader_parameter("ramp", ramp)
	mat.set_shader_parameter("ink_color", DS.BG_VOID)
	mat.set_shader_parameter("transparent_layer", mask != null)
	for key: String in ["radius", "tone_gamma", "band_soft", "chroma_keep", "ink_alpha", "ink_width", "hatch_alpha", "grain_alpha", "paper_alpha"]:
		mat.set_shader_parameter(key, preset[key])
	rect.material = mat
	vp.add_child(rect)
	var img: Image = await _grab(vp)
	vp.queue_free()
	return img


## Alpha = masque (rouge) ; couleur non prémultipliée (fond opaque derrière).
func _apply_mask(img: Image, mask: Image) -> void:
	var data: PackedByteArray = img.get_data()
	var m: PackedByteArray = mask.get_data()
	for i: int in range(3, data.size(), 4):
		data[i] = m[i - 3]
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


func _project_rect(cam: Camera3D, points: Array) -> Rect2i:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector3 in points:
		var s: Vector2 = cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2i(Vector2i(floori(lo.x), floori(lo.y)), Vector2i(ceili(hi.x - lo.x), ceili(hi.y - lo.y)))


# --- Aperçus (docs/mockups) -------------------------------------------------------

## Planche à plat (toutes les vitres allumées, MID en place) recadrée en 1920×1080.
func _flatten(bg: Image, lit_layers: Array, layers: Array, mid_img: Image) -> Image:
	var img: Image = bg.duplicate() as Image
	for l: Dictionary in lit_layers:
		var sprite: Image = l["image"]
		img.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), (l["rect"] as Rect2i).position)
	if mid_img != null:
		var used: Rect2i = (layers[layers.size() - 1] as Dictionary)["image_rect"]
		img.blend_rect(mid_img, Rect2i(Vector2i.ZERO, mid_img.get_size()), used.position)
	var margin: Vector2i = (PLATE_SIZE - VIEW_SIZE) / 2
	return img.get_region(Rect2i(margin, VIEW_SIZE))


var _caption_contrast_min: float = 0.0


## Composition telle qu'à l'écran (M14 §3.3) à un instant figé : parallaxe
## (MID décalé de COMPOSE_PARALLAX), zoom lent, vitres éteintes selon
## `compose_off`, couche HOLO (`plate_holo`, temps figé), `Label` des numéros,
## bandeau de légende (voile `bg.void` 72 %, style sous-titre ×1,25).
func _compose(bg: Image, lit_layers: Array, layers: Array, mid_img: Image, recipe: Dictionary,
		holo_anchors: Array, label_anchors: Array) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = VIEW_SIZE
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var ui: Control = Control.new()
	ui.size = Vector2(VIEW_SIZE)
	ui.theme = ThemeBuilder.build(1.0)
	vp.add_child(ui)
	var stage: Control = Control.new()
	stage.size = Vector2(PLATE_SIZE)
	stage.position = -Vector2((PLATE_SIZE - VIEW_SIZE) / 2)
	stage.pivot_offset = Vector2(PLATE_SIZE) * 0.5
	stage.scale = Vector2.ONE * COMPOSE_ZOOM
	ui.add_child(stage)
	_add_tex(stage, bg, Vector2.ZERO, 1.0)
	var off: Dictionary = recipe["compose_off"]
	for i: int in lit_layers.size():
		var power: float = float(off.get(i, 1.0))
		var l: Dictionary = lit_layers[i]
		_add_tex(stage, l["image"], Vector2((l["rect"] as Rect2i).position), power)
	var holo_shader: Shader = load(HOLO_SHADER) as Shader
	for i: int in holo_anchors.size():
		var r: Array = holo_anchors[i]
		var power: float = float(off.get(i, 1.0))
		var holo: ColorRect = ColorRect.new()
		var halo: float = 0.18
		var size: Vector2 = Vector2(float(r[2]), float(r[3])) / (1.0 - 2.0 * halo)
		holo.position = Vector2(float(r[0]), float(r[1])) - (size - Vector2(float(r[2]), float(r[3]))) * 0.5
		holo.size = size
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = holo_shader
		mat.set_shader_parameter("tint", BB.KEY.lerp(DS.ACCENT_CYAN, 0.25) if lit_layers.size() > 0 else DS.STATE_GREEN.lerp(DS.ACCENT_CYAN, 0.3))
		mat.set_shader_parameter("power", power)
		mat.set_shader_parameter("halo", halo)
		mat.set_shader_parameter("plate_time", 1.7)
		holo.material = mat
		stage.add_child(holo)
	if mid_img != null:
		var used: Rect2i = (layers[layers.size() - 1] as Dictionary)["image_rect"]
		_add_tex(stage, mid_img, Vector2(used.position) + COMPOSE_PARALLAX, 1.0)
	for i: int in label_anchors.size():
		var a: Dictionary = label_anchors[i]
		var r: Array = a["rect"]
		var lab: Label = Label.new()
		lab.text = a["text"]
		lab.add_theme_font_override("font", load(DS.FONT_MONO_PATH) as Font)
		lab.add_theme_font_size_override("font_size", maxi(DS.FS_CAPTION, int(float(r[3]) * 0.8)))
		var lit_now: bool = float(off.get(i, 1.0)) > 0.5
		lab.add_theme_color_override("font_color", DS.TEXT_PRIMARY if lit_now else DS.TEXT_SECONDARY)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.position = Vector2(float(r[0]), float(r[1]))
		lab.size = Vector2(float(r[2]), float(r[3]))
		stage.add_child(lab)
	# Légende (hors effets, dans la zone sûre 16:10).
	var caption_text: String = tr(String(recipe["caption_key"]))
	if caption_text == recipe["caption_key"]:
		caption_text = recipe["caption"] # clé `cin_*` pas encore dans fr.csv (lot E)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.chamfer_box(DS.SCRIM, Color(0, 0, 0, 0), 0, DS.CHAMFER_S, DS.SPACE_4, true))
	var cap: Label = Label.new()
	cap.text = caption_text
	cap.theme_type_variation = &"SubtitleText"
	cap.add_theme_font_size_override("font_size", roundi(DS.FS_SUBTITLE * CAPTION_SCALE))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(cap)
	ui.add_child(panel)
	await process_frame
	panel.reset_size()
	panel.position = Vector2((VIEW_SIZE.x - panel.size.x) * 0.5, VIEW_SIZE.y - panel.size.y - DS.SPACE_16)
	var img: Image = await _grab(vp)
	_caption_contrast_min = _contrast_under(img, Rect2i(Vector2i(panel.position), Vector2i(panel.size)), DS.TEXT_PRIMARY)
	vp.queue_free()
	return img


func _add_tex(parent: Control, img: Image, pos: Vector2, alpha: float) -> void:
	var t: TextureRect = TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.position = pos
	t.size = Vector2(img.get_size())
	t.modulate.a = alpha
	parent.add_child(t)


## Contraste WCAG minimal du texte `fg` sur le fond le plus clair du bandeau
## (pixels du voile hors glyphes : on prend le 95ᵉ centile de luminance).
func _contrast_under(img: Image, rect: Rect2i, fg: Color) -> float:
	var lums: PackedFloat32Array = []
	for y: int in range(rect.position.y + 2, rect.end.y - 2, 3):
		for x: int in range(rect.position.x + 2, rect.end.x - 2, 3):
			var c: Color = img.get_pixel(x, y)
			if absf(c.get_luminance() - fg.get_luminance()) > 0.25:
				lums.append(_rel_lum(c))
	if lums.is_empty():
		return 0.0
	lums.sort()
	var bg_l: float = lums[int(lums.size() * 0.95)]
	return (_rel_lum(fg) + 0.05) / (bg_l + 0.05)


static func _rel_lum(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func _save_mockup(img: Image, file: String) -> void:
	var path: String = MOCKUP_DIR.path_join(file)
	if img.save_png(path) != OK:
		push_error("build_plates: écriture impossible %s" % path)
		_failures += 1
	else:
		print("build_plates: %s" % path)
