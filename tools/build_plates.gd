## Pipeline des planches de cinématique (M14 §3.6, B89 phase 2, D-184, D-195 ;
## BOOTH_SCENE §19, §21).
##
## Lit les `PlateDef` du lot E (`data/cinematics/plates/*.tres`) et rend **hors
## ligne, de façon déterministe**, en **traitement B « lavis gravé »** sans papier
## cuit (le papier est posé à l'exécution par `plate_paper.gdshader`, D-195) :
## - un fond `BG` 2048×1152 par chemin de texture distinct (46 fonds), construit
##   par le catalogue `tools/plate_sets.gd` (décors S1 → S8 en volumes simples) ;
## - les couches `MID` / `FIG` de chaque planche (même décor, même caméra),
##   recadrées sur `PlateLayerDef.rect` (la donnée fait foi ; le manifeste signale
##   ce qui déborde) ;
## - les couches d'état `LIT` (PL-F9-1) découpées par la passe d'identifiants ;
## - les silhouettes de repli des figures nommées (`FigureSlotDef.silhouette_path`)
##   par `PlateFigureService` (même pose, anonyme, peinte comme les fonds).
## Écrit les PNG aux chemins des données (`assets/cinematics/{bg,mid,fig,lit}/`),
## leurs `.import` (Lossy WebP 0,75, sans mipmaps : voir BOOTH_SCENE §21 pour le
## choix face à « VRAM Compressed »), et `assets/cinematics/manifest.json`
## (SHA-256/MD5, tailles PNG et WebP estimé, VRAM, rectangles réels, ancres
## `HOLO`/`LABEL`, débordements, recette, adaptateur, durées).
##
## Usage (racine du projet, sous xvfb, pilote `opengl3`) :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/build_plates.gd -- [--only=bg_h12,pl_f4_1,…] [--force] [--verify]
##       [--mockups=pl_f9_1,…] [--no-figures] [--list]
## puis `godot --headless --path . --import` (imports). Reconstruction
## incrémentale : un fond (et ses couches) n'est rendu que si sa recette a changé
## (`--force` : tout). `--only` accepte des fonds (`bg_q1`) ou des planches
## (`pl_f4_1` : son fond et toutes ses couches). L'outil **échoue clairement**
## (code 1) si un shader ne compile pas, si un fond ou une couche n'a pas de
## constructeur, ou si une écriture échoue.
extends SceneTree

const BB = preload("res://tools/build_booth.gd")
const SETS = preload("res://tools/plate_sets.gd")
const COMPOSE = preload("res://tools/plate_compose.gd")

const PAINT_SHADER: String = "res://assets/shaders/plate_paint.gdshader"
const HOLO_SHADER: String = "res://assets/shaders/plate_holo.gdshader"
const PAPER_SHADER: String = "res://assets/shaders/plate_paper.gdshader"
const DECOR_SHADER: String = "res://assets/shaders/booth_decor.gdshader"
const EMISSIVE_SHADER: String = "res://assets/shaders/booth_emissive.gdshader"
const BOOTH_HOLO_SHADER: String = "res://assets/shaders/booth_holo.gdshader"
const ALBEDO_ARRAY: String = "res://assets/textures/booth/tex_booth_albedo_rough.png"
const NORMAL_ARRAY: String = "res://assets/textures/booth/tex_booth_normal_metal.png"
const PLATES_DIR: String = "res://data/cinematics/plates"
const OUT_DIR: String = "res://assets/cinematics"
const MANIFEST: String = "res://assets/cinematics/manifest.json"
const MOCKUP_DIR: String = "res://docs/mockups"
## Version des recettes (hachage de reconstruction incrémentale).
const RECIPE_VERSION: int = 6
## Qualité WebP des sources versionnées (fonds ; couches à alpha).
const BG_WEBP_QUALITY: float = 0.83
const LAYER_WEBP_QUALITY: float = 0.9

const PLATE_SIZE: Vector2i = Vector2i(2048, 1152)
const VIEW_SIZE: Vector2i = Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 4
const ID_BASE: int = 52
const ID_STEP: int = 12
## Éclairages chauds : tons clairs de la rampe tirés vers l'ambre monde.
const WARM_LIGHTING: Array[StringName] = [&"school", &"mine_lamp", &"cabin", &"dusk", &"dawn", &"hall_warm", &"archive", &"office"]
const WARM_MIX: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.06, 0.14, 0.2, 0.12]
## Composition figée des captures (M14 §3.3 : parallaxe ≤ 12 px, zoom ≤ 1,04).
const COMPOSE_T: float = 0.6
## Marge autour du contenu d'une couche recadrée (px de planche).
const LAYER_PAD: int = 12

var sets: SETS = null
var _decor_mat: ShaderMaterial = null
var _emissive_mat: ShaderMaterial = null
var _holo_mat: ShaderMaterial = null
var _gbuffer_mat: ShaderMaterial = null
var _mask_black: ShaderMaterial = null
var _mask_white: ShaderMaterial = null
var _failures: int = 0
var _manifest: Dictionary = {}
var _old_files: Dictionary = {}
var _old_groups: Dictionary = {}
var _old_figures: Dictionary = {}
var _plates: Array[PlateDef] = []
var _figures: PlateFigureService = null


func _initialize() -> void:
	await process_frame # autoloads (Settings, EventBus…) avant de charger les scripts
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: PackedStringArray = []
	var mockups: PackedStringArray = []
	var force: bool = false
	var verify: bool = false
	var figures: bool = true
	var list_only: bool = false
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--mockups="):
			mockups = arg.trim_prefix("--mockups=").split(",", false)
		elif arg == "--force":
			force = true
		elif arg == "--verify":
			verify = true
		elif arg == "--no-figures":
			figures = false
		elif arg == "--list":
			list_only = true
	UiText.ensure_translations()
	TranslationServer.set_locale("fr") # légendes des captures (fr.csv)
	if DisplayServer.get_name() == "headless":
		_fail("rendu requis — lancer sous xvfb avec --rendering-driver opengl3")
		quit(1)
		return
	_make_materials()
	if not await _check_shaders():
		quit(1)
		return
	_load_plates()
	var groups: Dictionary[String, Array] = _groups()
	if list_only:
		for stem: String in groups:
			var ids: PackedStringArray = []
			for p: PlateDef in groups[stem]:
				ids.append(String(p.id))
			print("%s%s ← %s" % [stem, "" if sets.has_bg(stem) else " (SANS CONSTRUCTEUR)", ", ".join(ids)])
		quit(0)
		return
	_load_old_manifest()
	_manifest = {
		"tool": "tools/build_plates.gd", "recipe_version": RECIPE_VERSION, "treatment": PlatePaintStyle.PRESET["label"],
		"paper": "runtime (plate_paper.gdshader, alpha %.2f)" % PlatePaintStyle.PAPER_ALPHA,
		"godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(), "api": RenderingServer.get_video_adapter_api_version(),
		"plate_size": [PLATE_SIZE.x, PLATE_SIZE.y], "groups": {}, "files": {}, "figures": {},
	}
	_figures = PlateFigureService.new()
	root.add_child(_figures)
	var t_all: int = Time.get_ticks_msec()
	for stem: String in groups:
		var plates: Array = groups[stem]
		var selected: bool = only.is_empty() or only.has(stem)
		for p: PlateDef in plates:
			selected = selected or only.has(String(p.id))
		var recipe: String = _recipe_hash(stem, plates)
		if not selected or (not force and _up_to_date(stem, recipe)):
			_keep_old(stem)
			continue
		var t0: int = Time.get_ticks_msec()
		var result: Dictionary = await _render_group(stem, plates)
		if verify:
			var again: Dictionary = await _render_group(stem, plates, true)
			var same: bool = true
			for path: String in result["files"]:
				if (result["files"][path] as Dictionary)["sha256"] != (again["files"].get(path, {}) as Dictionary).get("sha256", ""):
					same = false
					_fail("%s non déterministe" % path)
			result["deterministic"] = same
		result["recipe"] = recipe
		result["render_ms"] = Time.get_ticks_msec() - t0
		(_manifest["groups"] as Dictionary)[stem] = result
		for path: String in result["files"]:
			(_manifest["files"] as Dictionary)[path] = result["files"][path]
		print("build_plates: %s — %d couche(s), %d ms%s" % [stem, (result["files"] as Dictionary).size(), result["render_ms"],
				"" if not verify else (", déterministe" if result["deterministic"] else ", NON déterministe")])
	if figures:
		await _render_figures(only, force)
	_summarize(Time.get_ticks_msec() - t_all)
	_write_manifest()
	for id: String in mockups:
		await _mockup(id)
	print("build_plates: %s" % ("OK" if _failures == 0 else "ÉCHEC (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	push_error("build_plates: " + message)
	printerr("build_plates: ERREUR — " + message)
	_failures += 1


# --- Données ----------------------------------------------------------------------------

func _load_plates() -> void:
	_plates.clear()
	# Bibliothèque d'abord (charger les `PlateDef` avant elle laisse une fuite à
	# la sortie de Godot 4.7.2, constat des lots E/F).
	CinematicLibraryDef.load_default()
	var files: PackedStringArray = DirAccess.get_files_at(PLATES_DIR)
	files.sort()
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var plate: PlateDef = load(PLATES_DIR.path_join(f)) as PlateDef
		if plate == null:
			_fail("planche illisible %s" % f)
			continue
		_plates.append(plate)


static func stem_of(path: String) -> String:
	return path.get_file().get_basename()


## Fonds → planches qui l'utilisent (ordre stable).
func _groups() -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	for plate: PlateDef in _plates:
		for layer: PlateLayerDef in plate.layers:
			if layer != null and layer.kind == PlateLayerDef.KIND_BG and not layer.texture_path.is_empty():
				var stem: String = stem_of(layer.texture_path)
				if not out.has(stem):
					out[stem] = []
				(out[stem] as Array).append(plate)
	var keys: Array = out.keys()
	keys.sort()
	var sorted: Dictionary[String, Array] = {}
	for k: String in keys:
		sorted[k] = out[k]
	return sorted


## Dominante d'un fond : celle des planches si elles concordent, sinon neutre (acier).
static func group_dominant(plates: Array) -> StringName:
	var token: StringName = &""
	for p: PlateDef in plates:
		if token == &"":
			token = p.dominant
		elif p.dominant != token:
			return &"world.steel"
	return token if token != &"" else &"world.steel"


static func group_lighting(plates: Array) -> StringName:
	return (plates[0] as PlateDef).lighting if not plates.is_empty() else &"hall"


func _recipe_hash(stem: String, plates: Array) -> String:
	var parts: PackedStringArray = [str(RECIPE_VERSION), stem, str(PlatePaintStyle.PRESET), String(group_dominant(plates)),
			String(group_lighting(plates)), FileAccess.get_md5("res://tools/plate_sets.gd"), FileAccess.get_md5(PAINT_SHADER)]
	for p: PlateDef in plates:
		for layer: PlateLayerDef in p.layers:
			if layer != null:
				parts.append("%s|%s|%s" % [layer.kind, layer.texture_path, layer.get("state_index")])
	return "|".join(parts).md5_text()


func _load_old_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data is Dictionary:
		_old_files = (data as Dictionary).get("files", {})
		_old_groups = (data as Dictionary).get("groups", {})
		_old_figures = (data as Dictionary).get("figures", {})


func _up_to_date(stem: String, recipe: String) -> bool:
	if not _old_groups.has(stem) or (_old_groups[stem] as Dictionary).get("recipe", "") != recipe:
		return false
	for path: String in (_old_groups[stem] as Dictionary).get("files", {}):
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != ((_old_groups[stem] as Dictionary)["files"][path] as Dictionary)["sha256"]:
			return false
	return true


func _keep_old(stem: String) -> void:
	if not _old_groups.has(stem):
		return
	(_manifest["groups"] as Dictionary)[stem] = _old_groups[stem]
	for path: String in (_old_groups[stem] as Dictionary).get("files", {}):
		(_manifest["files"] as Dictionary)[path] = (_old_groups[stem] as Dictionary)["files"][path]


# --- Matériaux et contrôle des shaders -----------------------------------------------------

func _make_materials() -> void:
	_decor_mat = ShaderMaterial.new()
	_decor_mat.shader = load(DECOR_SHADER) as Shader
	_decor_mat.set_shader_parameter("albedo_rough", load(ALBEDO_ARRAY))
	_decor_mat.set_shader_parameter("normal_metal", load(NORMAL_ARRAY))
	_decor_mat.set_shader_parameter("wet_motion", 0.0) # temps figé
	_emissive_mat = ShaderMaterial.new()
	_emissive_mat.shader = load(EMISSIVE_SHADER) as Shader
	_emissive_mat.set_shader_parameter("fx_intensity", 0.0)
	_emissive_mat.set_shader_parameter("flicker", 0.0)
	_holo_mat = ShaderMaterial.new()
	_holo_mat.shader = load(BOOTH_HOLO_SHADER) as Shader
	_holo_mat.set_shader_parameter("fx_intensity", 0.0)
	_holo_mat.set_shader_parameter("flicker", 0.0)
	_gbuffer_mat = _inline_material("""
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;
// G-buffer des planches : normale de vue (octaédrique, rg) + profondeur log (b).
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
	sets = SETS.new(_decor_mat, _emissive_mat, _holo_mat)


func _inline_material(code: String) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


## Échec franc si un shader ne compile pas : chaque shader doit exposer ses
## uniformes (liste vide = erreur de compilation), et `plate_paint` doit
## réellement transformer une image de contrôle (sinon le moteur affiche le
## matériau de repli et les planches seraient fausses sans le dire).
func _check_shaders() -> bool:
	var ok: bool = true
	for path: String in [PAINT_SHADER, HOLO_SHADER, PAPER_SHADER, DECOR_SHADER, EMISSIVE_SHADER, BOOTH_HOLO_SHADER]:
		var shader: Shader = load(path) as Shader
		if shader == null or shader.get_shader_uniform_list().is_empty():
			_fail("le shader %s ne compile pas (aucun uniforme exposé)" % path)
			ok = false
	if not ok:
		return false
	var probe: Image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			probe.set_pixel(x, y, Color(x / 31.0, 0.3, y / 31.0, 1.0))
	var ramp: PackedColorArray = PlatePaintStyle.ramp(DS.STATE_RED, [1, 1, 1, 1, 1, 1, 1, 1])
	var painted: Image = await _paint_image(probe, null, null, ramp)
	var diff: float = 0.0
	for y: int in range(4, 28):
		for x: int in range(4, 28):
			var a: Color = probe.get_pixel(x, y)
			var c: Color = painted.get_pixel(x, y)
			diff += absf(a.r - c.r) + absf(a.g - c.g) + absf(a.b - c.b)
	if diff < 5.0:
		_fail("plate_paint.gdshader n'a pas transformé l'image de contrôle (shader non compilé ?)")
		return false
	return true


# --- Rendu d'un fond et de ses couches -------------------------------------------------------

func _new_viewport() -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = PLATE_SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 0
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _render_group(stem: String, plates: Array, dry: bool = false) -> Dictionary:
	var result: Dictionary = {"plates": [], "files": {}, "dominant": String(group_dominant(plates)), "lighting": String(group_lighting(plates))}
	for p: PlateDef in plates:
		(result["plates"] as Array).append(String(p.id))
	if not sets.has_bg(stem):
		_fail("aucun constructeur de fond pour %s (plate_sets.gd : func %s)" % [stem, stem])
		return result
	var vp: SubViewport = _new_viewport()
	var scene: Node3D = Node3D.new()
	vp.add_child(scene)
	var info: Dictionary = sets.call(stem, scene)
	var cam: Camera3D = info["camera"]
	cam.current = true
	var env: Environment = info["environment"]
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var token: StringName = group_dominant(plates)
	var warm: bool = WARM_LIGHTING.has(group_lighting(plates))
	var ramp: PackedColorArray = PlatePaintStyle.ramp(PlatePaintStyle.dominant_color(token), PlatePaintStyle.default_mix(token),
			BB.SPILL, WARM_MIX if warm else [])
	result["ramp"] = Array(ramp).map(func(c: Color) -> String: return c.to_html(false))
	var bg_groups: Array[StringName] = [SETS.G_BG, SETS.G_OFF]
	# Fond.
	var bg_path: String = ""
	for p: PlateDef in plates:
		for layer: PlateLayerDef in p.layers:
			if layer != null and layer.kind == PlateLayerDef.KIND_BG and stem_of(layer.texture_path) == stem:
				bg_path = layer.texture_path
	var bg: Image = await _paint_image(await _pass_color(vp, scene, bg_groups), await _pass_gbuffer(vp, scene, bg_groups, we, env), null, ramp)
	_save(bg, bg_path, Rect2i(Vector2i.ZERO, PLATE_SIZE), "bg", result, dry)
	# Couches d'état (LIT) d'après les zones d'identifiants.
	var lit_layers: Array[PlateLayerDef] = []
	for p: PlateDef in plates:
		for layer: PlateLayerDef in p.layers:
			if layer != null and layer.kind == &"lit" and not layer.texture_path.is_empty():
				lit_layers.append(layer)
	if not lit_layers.is_empty():
		var regions: Array = info.get("lit_regions", [])
		if regions.is_empty():
			_fail("%s : couches LIT sans zones d'état dans le décor" % stem)
		else:
			var lit_groups: Array[StringName] = [SETS.G_BG, SETS.G_LIT]
			var lit_full: Image = await _paint_image(await _pass_color(vp, scene, lit_groups), await _pass_gbuffer(vp, scene, lit_groups, we, env), null, ramp)
			var ids: Image = await _pass_ids(vp, scene, [SETS.G_BG, SETS.G_OFF, SETS.G_ID], we, env)
			for layer: PlateLayerDef in lit_layers:
				var n: int = int(layer.get("state_index")) + 1
				var cut: Array = _id_sprite(lit_full, ids, n, 18)
				if cut.is_empty():
					_fail("%s : zone d'état %d invisible" % [stem, n])
					continue
				# Découpe ajustée (rectangle publié au manifeste, relu par build_data_m14).
				_save(cut[0], layer.texture_path, cut[1], "lit", result, dry)
	# Couches MID / FIG de chaque planche.
	for p: PlateDef in plates:
		for layer: PlateLayerDef in p.layers:
			if layer == null or not (layer.kind == PlateLayerDef.KIND_MID or layer.kind == PlateLayerDef.KIND_FIG) or layer.texture_path.is_empty():
				continue
			var lstem: String = stem_of(layer.texture_path)
			if (result["files"] as Dictionary).has(layer.texture_path):
				continue
			if not sets.has_layer(lstem):
				_fail("aucun constructeur de couche pour %s (plate_sets.gd : func layer_%s)" % [lstem, lstem])
				continue
			var holder: Node3D = Node3D.new()
			scene.add_child(holder)
			sets.call("layer_" + lstem, holder, info)
			for n: Node in holder.find_children("*", "GeometryInstance3D", true, false):
				n.add_to_group(SETS.G_LAYER)
			var groups: Array[StringName] = [SETS.G_BG, SETS.G_OFF, SETS.G_LAYER]
			var color: Image = await _pass_color(vp, scene, groups)
			var gbuf: Image = await _pass_gbuffer(vp, scene, groups, we, env)
			var mask: Image = await _pass_mask(vp, scene, groups, we, env)
			var painted: Image = await _paint_image(color, gbuf, mask, ramp)
			# Recadrage sur le contenu réel (+ marge pour l'encre) : le rectangle rendu
			# est publié dans le manifeste et relu par `tools/build_data_m14.gd`
			# (les rectangles des données étaient des intentions, lot E).
			var used: Rect2i = painted.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				_fail("%s : couche %s vide (rien dans le cadre)" % [stem, lstem])
				used = Rect2i(0, 0, 4, 4)
			var crop: Rect2i = used.grow(LAYER_PAD).intersection(Rect2i(Vector2i.ZERO, PLATE_SIZE))
			var intent: Rect2i = _rect_px(layer.rect)
			var entry_extra: Dictionary = {"intent_rect": [intent.position.x, intent.position.y, intent.size.x, intent.size.y],
					"outside_intent": _clipped_share(painted, intent)}
			_save(painted.get_region(crop), layer.texture_path, crop, String(layer.kind), result, dry, entry_extra)
			scene.remove_child(holder)
			holder.free()
	# Ancres HOLO et LABEL (pixels de planche).
	var holo: Array = []
	for pts: Array in info.get("holo_rects", []):
		var r: Rect2i = _project_rect(cam, pts)
		holo.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var labels: Array = []
	for lab: Dictionary in info.get("labels", []):
		var r: Rect2i = _project_rect(cam, lab["points"])
		labels.append({"id": lab["id"], "text": lab["text"], "rect": [r.position.x, r.position.y, r.size.x, r.size.y],
				"rect_norm": _norm(r)})
	result["holo"] = holo
	result["labels"] = labels
	result["camera"] = {"fov": cam.fov, "transform": var_to_str(cam.global_transform)}
	vp.queue_free()
	await process_frame
	return result


## Part de l'alpha de la couche hors du rectangle des données (0 = rien de perdu).
static func _clipped_share(img: Image, rect: Rect2i) -> float:
	var data: PackedByteArray = img.get_data()
	var w: int = img.get_width()
	var total: float = 0.0
	var outside: float = 0.0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, w, 2):
			var a: float = data[(y * w + x) * 4 + 3] / 255.0
			total += a
			if not rect.has_point(Vector2i(x, y)):
				outside += a
	return snappedf(outside / total, 0.001) if total > 0.0 else 0.0


func _rect_px(r: Rect2) -> Rect2i:
	var p: Vector2i = Vector2i(roundi(r.position.x * PLATE_SIZE.x), roundi(r.position.y * PLATE_SIZE.y))
	var s: Vector2i = Vector2i(maxi(roundi(r.size.x * PLATE_SIZE.x), 1), maxi(roundi(r.size.y * PLATE_SIZE.y), 1))
	return Rect2i(p, s).intersection(Rect2i(Vector2i.ZERO, PLATE_SIZE))


static func _norm(r: Rect2i) -> Array:
	return [snappedf(float(r.position.x) / PLATE_SIZE.x, 0.0001), snappedf(float(r.position.y) / PLATE_SIZE.y, 0.0001),
			snappedf(float(r.size.x) / PLATE_SIZE.x, 0.0001), snappedf(float(r.size.y) / PLATE_SIZE.y, 0.0001)]


func _save(img: Image, path: String, rect: Rect2i, kind: String, result: Dictionary, dry: bool, extra: Dictionary = {}) -> void:
	# Sources versionnées en WebP (décision de l'Orchestrateur : ni PNG lourds ni
	# Git LFS, ≤ 15 Mo) : fonds et couches en perte contrôlée (alpha gardé). Sans
	# perte, les couches pesaient 7,5 Mo (total 17,8 Mo) : écarté. Un chemin `.png`
	# (anciennes données) reste écrit en PNG.
	var bytes: PackedByteArray = img.save_png_to_buffer()
	if path.get_extension() == "webp":
		bytes = img.save_webp_to_buffer(true, BG_WEBP_QUALITY if kind == "bg" else LAYER_WEBP_QUALITY)
	var entry: Dictionary = {
		"kind": kind, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "rect_norm": _norm(rect),
		"size": [img.get_width(), img.get_height()], "sha256": _sha256(bytes), "md5": _md5(bytes), "file_bytes": bytes.size(),
		"vram_bytes": img.get_width() * img.get_height() * (4 if kind != "bg" else 3),
	}
	entry.merge(extra)
	(result["files"] as Dictionary)[path] = entry
	if dry:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("écriture impossible %s" % path)
		return
	f.store_buffer(bytes)
	f.close()
	_write_import(path, kind != "bg")


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _md5(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Réglages d'import : Lossy (WebP) 0,75, sans mipmaps, bords alpha corrigés.
## Écrit une seule fois (Godot y ajoute ensuite l'uid et les destinations).
static func _write_import(path: String, alpha: bool) -> void:
	var import_path: String = path + ".import"
	if FileAccess.file_exists(import_path):
		return
	var f: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	f.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.75
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=%s
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % ("true" if alpha else "false"))
	f.close()


# --- Passes ---------------------------------------------------------------------------------

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


func _pass_color(vp: SubViewport, scene: Node3D, groups: Array[StringName]) -> Image:
	_show(scene, groups)
	vp.transparent_bg = false
	return await _grab(vp)


func _with_override(scene: Node3D, groups: Array[StringName], pick: Callable) -> Dictionary:
	var saved: Dictionary = {}
	_show(scene, groups)
	for n: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		saved[gi] = gi.material_override
		if gi.is_in_group(SETS.G_ADDITIVE):
			gi.visible = false # voiles additifs : pas de contour ni de masque
		gi.material_override = pick.call(gi)
	return saved


func _restore(saved: Dictionary, we: WorldEnvironment, env: Environment) -> void:
	for gi: GeometryInstance3D in saved:
		gi.material_override = saved[gi]
	we.environment = env


static func _flat_environment(background: Color) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	return env


func _pass_gbuffer(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var saved: Dictionary = _with_override(scene, groups, func(_gi: GeometryInstance3D) -> Material: return _gbuffer_mat)
	we.environment = _flat_environment(Color.WHITE)
	var prev: Viewport.MSAA = vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	vp.msaa_3d = prev
	_restore(saved, we, env)
	return img


func _pass_ids(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var mats: Dictionary = {}
	var saved: Dictionary = _with_override(scene, groups, func(gi: GeometryInstance3D) -> Material:
		if not gi.is_in_group(SETS.G_ID):
			return _mask_black
		var n: int = int(gi.get_meta(&"plate_id", 0))
		if not mats.has(n):
			mats[n] = _inline_material("shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nvoid fragment() { ALBEDO = vec3(%s); }\n"
					% String.num(float(ID_BASE + n * ID_STEP) / 255.0, 8))
		return mats[n])
	we.environment = _flat_environment(Color.BLACK)
	var prev: Viewport.MSAA = vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	vp.msaa_3d = prev
	_restore(saved, we, env)
	return img


func _pass_mask(vp: SubViewport, scene: Node3D, groups: Array[StringName], we: WorldEnvironment, env: Environment) -> Image:
	var saved: Dictionary = _with_override(scene, groups, func(gi: GeometryInstance3D) -> Material:
		return _mask_white if gi.is_in_group(SETS.G_LAYER) else _mask_black)
	we.environment = _flat_environment(Color.BLACK)
	vp.transparent_bg = false
	var img: Image = await _grab(vp)
	_restore(saved, we, env)
	return img


## Découpe de la zone `n` (voir phase 1) : [Image, Rect2i] ou [].
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


## Peinture (traitement B) d'une image ; `mask` non nul → couche transparente.
func _paint_image(color: Image, gbuf: Image, mask: Image, ramp: PackedColorArray) -> Image:
	var src: Image = color
	if mask != null:
		src = color.duplicate() as Image
		var data: PackedByteArray = src.get_data()
		var m: PackedByteArray = mask.get_data()
		for i: int in range(3, data.size(), 4):
			data[i] = m[i - 3]
		src.set_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8, data)
	var vp: SubViewport = SubViewport.new()
	vp.size = color.get_size()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(src)
	rect.size = Vector2(color.get_size())
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.material = PlatePaintStyle.paint_material(rect.texture, ImageTexture.create_from_image(gbuf) if gbuf != null else null, ramp, mask != null)
	vp.add_child(rect)
	var img: Image = await _grab(vp)
	vp.queue_free()
	return img


func _project_rect(cam: Camera3D, points: Array) -> Rect2i:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector3 in points:
		var s: Vector2 = cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2i(Vector2i(floori(lo.x), floori(lo.y)), Vector2i(ceili(hi.x - lo.x), ceili(hi.y - lo.y)))


# --- Silhouettes de repli des figures nommées -------------------------------------------------

func _render_figures(only: PackedStringArray, force: bool) -> void:
	var done: Dictionary = {}
	var old: Dictionary = _old_figures
	for plate: PlateDef in _plates:
		for slot: FigureSlotDef in plate.figures:
			if slot == null or slot.silhouette_path.is_empty() or done.has(slot.silhouette_path):
				continue
			done[slot.silhouette_path] = true
			var selected: bool = only.is_empty() or only.has(String(plate.id)) or only.has("figures")
			var recipe: String = "%d|%s|%s|%s|%s|%s|%s|%s" % [RECIPE_VERSION, slot.pose, slot.pose_frame, slot.framing, slot.lighting,
					slot.render_size, plate.dominant, FileAccess.get_md5("res://scripts/booth/plate_figure_service.gd")]
			recipe = recipe.md5_text()
			var prev: Dictionary = old.get(slot.silhouette_path, {})
			if not selected or (not force and prev.get("recipe", "") == recipe and FileAccess.file_exists(slot.silhouette_path)
					and FileAccess.get_sha256(slot.silhouette_path) == prev.get("sha256", "")):
				if not prev.is_empty():
					(_manifest["figures"] as Dictionary)[slot.silhouette_path] = prev
					(_manifest["files"] as Dictionary)[slot.silhouette_path] = prev
				continue
			var img: Image = await _figures.render_image(slot, null, plate.dominant, true)
			if img == null or img.is_empty():
				_fail("silhouette de figure %s non rendue" % slot.silhouette_path)
				continue
			var result: Dictionary = {"files": {}}
			_save(img, slot.silhouette_path, Rect2i(Vector2i.ZERO, img.get_size()), "fig_slot", result, false,
					{"slot": String(slot.id), "plate": String(plate.id), "recipe": recipe})
			var entry: Dictionary = result["files"][slot.silhouette_path]
			(_manifest["figures"] as Dictionary)[slot.silhouette_path] = entry
			(_manifest["files"] as Dictionary)[slot.silhouette_path] = entry
			print("build_plates: figure %s (%s)" % [slot.silhouette_path.get_file(), slot.id])


# --- Manifeste et budgets -------------------------------------------------------------------

func _summarize(ms: int) -> void:
	var png: int = 0
	var bg_count: int = 0
	var layer_count: int = 0
	for path: String in _manifest["files"]:
		var e: Dictionary = _manifest["files"][path]
		png += int(e.get("file_bytes", e.get("png_bytes", 0)))
		if e["kind"] == "bg":
			bg_count += 1
		else:
			layer_count += 1
	# VRAM transitoire : planche la plus lourde + la suivante (pire paire de la même séquence).
	var plate_vram: Dictionary = {}
	for plate: PlateDef in _plates:
		var v: int = 0
		for layer: PlateLayerDef in plate.layers:
			if layer != null and (_manifest["files"] as Dictionary).has(layer.texture_path):
				v += int((_manifest["files"][layer.texture_path] as Dictionary)["vram_bytes"])
		for slot: FigureSlotDef in plate.figures:
			if slot != null:
				v += slot.render_size.x * slot.render_size.y * 4
		plate_vram[String(plate.id)] = v
	var values: Array = plate_vram.values()
	values.sort()
	var pair: int = int(values[values.size() - 1]) + int(values[values.size() - 2]) if values.size() >= 2 else 0
	_manifest["summary"] = {
		"backgrounds": bg_count, "layers": layer_count, "plates": _plates.size(), "source_bytes": png,
		"vram_worst_pair_bytes": pair, "render_ms_this_run": ms,
	}
	print("build_plates: %d fonds, %d couches, sources %.2f Mo, VRAM pire paire %.1f Mo" % [bg_count, layer_count,
			png / 1048576.0, pair / 1048576.0])


func _write_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(_sorted(_manifest), "\t", false))
	f.close()


## Copie aux clés triées (manifeste stable d'une exécution à l'autre).
static func _sorted(v: Variant) -> Variant:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		keys.sort()
		var out: Dictionary = {}
		for k: Variant in keys:
			out[k] = _sorted((v as Dictionary)[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _sorted(x))
	return v


# --- Captures composées (docs/mockups) ---------------------------------------------------------

## Captures `docs/mockups/m14_<planche>_b[_deck].png` (1920×1080 et 1280×800),
## composées par `tools/plate_compose.gd` (même assemblage que l'audit M-16).
func _mockup(id: String) -> void:
	var plate: PlateDef = null
	for p: PlateDef in _plates:
		if String(p.id) == id:
			plate = p
	if plate == null:
		_fail("capture : planche inconnue %s" % id)
		return
	var composer: COMPOSE = COMPOSE.new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for size: Vector2i in [VIEW_SIZE, Vector2i(1280, 800)]:
		var img: Image = await composer.compose(root, plate, size, manifest, COMPOSE_T)
		var file: String = "m14_%s_b%s.png" % [id.trim_prefix("pl_"), "" if size == VIEW_SIZE else "_deck"]
		if img.save_png(MOCKUP_DIR.path_join(file)) != OK:
			_fail("écriture impossible %s" % file)
		else:
			print("build_plates: %s/%s (contraste de la légende %.1f:1)" % [MOCKUP_DIR, file,
					COMPOSE.contrast_under(img, composer.caption_rect, DS.TEXT_PRIMARY)])
