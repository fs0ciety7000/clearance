## Figures nommées des cinématiques, rendues **à l'exécution** avec le visage
## vu pendant la partie (M14 §3.5, B90, D-185 ; ARCHITECTURE §12 ter.3).
##
## Le studio de `PortraitService` en plus grand : même `PassengerRig` +
## `AppearanceApplier` que l'acteur du guichet, posé sur une image fixe d'une
## pose (`idle`, `present_docs`, `leave`), cadré (`full`, `bust`, `profile`) et
## éclairé par emplacement (`FigureSlotDef.lighting`), dans une `SubViewport`
## de `FigureSlotDef.render_size` (512×768) à fond transparent ; puis **peint en
## espace écran** par `plate_paint.gdshader` (traitement B, D-195,
## `PlatePaintStyle`) : même rendu que les fonds, contours par G-buffer.
##
## - `request(slot, appearance, dominant)` rend **tout de suite** une texture :
##   la silhouette de repli (`slot.silhouette_path`) si `appearance` est null
##   (REVOIR depuis le Dossier, headless, tests, figure jamais vue), sinon une
##   `ImageTexture` (silhouette en attendant) **mise à jour sur place** quand le
##   rendu est prêt (`figure_ready`). À appeler pendant la carte de titre (3,5 s).
## - `request_for(slot, memory, flags, dominant)` : idem à partir de la mémoire
##   des cas (`CinematicService.figure_appearance`, visage tel que vu, visière
##   remise si jamais relevée).
## - `render_image(slot, appearance, dominant, silhouette)` (await) : l'image
##   peinte ; `silhouette = true` rend une silhouette anonyme de même pose (sans
##   visage : remplissage sombre et liseré) — c'est ainsi que `build_plates.gd`
##   produit les replis `assets/cinematics/fig/`.
## **L'agent·e n'a jamais de visage** : aucun emplacement ne le désigne.
## Headless : aucun rendu (silhouette de repli seulement). Coût hors rendu : nul
## (viewports `UPDATE_DISABLED`, modèle en pause).
class_name PlateFigureService
extends Node

signal figure_ready(slot_id: StringName, texture: Texture2D)

## Poses des données → clips de la bibliothèque `passenger`.
const POSE_CLIPS: Dictionary[StringName, StringName] = {
	&"idle": &"idle", &"present_docs": &"present_documents", &"present_documents": &"present_documents",
	&"leave": &"leave", &"talk": &"talk", &"sit": &"idle",
}
## Éclairages préréglés : [clé, énergie, rim gauche, rim droit, ambiante].
const LIGHTING: Dictionary[StringName, Array] = {
	&"hall": [Color("#C8D6E0"), 1.0, Color("#2B6E78"), Color("#7E3A5C"), Color("#3A4556")],
	&"hall_warm": [Color("#E8CFA0"), 1.0, Color("#2B6E78"), Color("#C9B85A"), Color("#4A4436")],
	&"hall_dark": [Color("#8A97A8"), 0.45, Color("#2B6E78"), Color("#7E3A5C"), Color("#161B26")],
	&"dock": [Color("#E0B070"), 1.1, Color("#3A4556"), Color("#C9B85A"), Color("#3A3A3A")],
	&"clinical": [Color("#F2F4F6"), 1.25, Color("#B9C6D3"), Color("#B9C6D3"), Color("#6E7680")],
	&"night": [Color("#7F9AB8"), 0.55, Color("#2B6E78"), Color("#2E3A55"), Color("#161B26")],
	&"mine_lamp": [Color("#FFB45A"), 1.3, Color("#5C3F2A"), Color("#C9B85A"), Color("#2A2018")],
	&"cabin": [Color("#E8C08A"), 0.9, Color("#3A4556"), Color("#7E3A5C"), Color("#2C2622")],
	&"recycler": [Color("#A8D8C8"), 0.95, Color("#2B6E78"), Color("#2F4A4C"), Color("#1E2526")],
	&"dawn": [Color("#F0C8A8"), 0.9, Color("#5E9AA3"), Color("#C9B85A"), Color("#3A3A44")],
	&"dusk": [Color("#D8A880"), 0.85, Color("#7E3A5C"), Color("#C9B85A"), Color("#2C2630")],
	&"school": [Color("#F0DCA8"), 1.0, Color("#3F4F3A"), Color("#C9B85A"), Color("#3A4038")],
	&"archive": [Color("#E8C890"), 0.9, Color("#2E3A55"), Color("#C9B85A"), Color("#1C1C1F")],
	&"office": [Color("#E8E0C0"), 1.0, Color("#3A4556"), Color("#FFE600"), Color("#2A2A2E")],
}
const FOV: float = 20.0
## Silhouette anonyme (repli) : remplissage sombre, liseré teal/rose du monde.
const SILHOUETTE_FILL: Color = Color("#0E1118")

var _headless: bool = false
var _studio: SubViewport = null
var _camera: Camera3D = null
var _sitter: Node3D = null
var _rig: PassengerRig = null
var _pose_player: AnimationPlayer = null
var _key: DirectionalLight3D = null
var _rims: Array[OmniLight3D] = []
var _env: Environment = null
var _queue: Array[Array] = []
var _busy: bool = false
var _gbuffer_mat: ShaderMaterial = null
var _silhouette_mat: ShaderMaterial = null


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"


## Texture d'une figure : silhouette de repli si `appearance` est null, sinon
## rendu à l'exécution (mis à jour sur place).
func request(slot: FigureSlotDef, appearance: PassengerAppearance, dominant: StringName = &"world.steel") -> Texture2D:
	if slot == null:
		return null
	var fallback: Texture2D = silhouette_texture(slot)
	if appearance == null or _headless or not is_inside_tree():
		return fallback
	var placeholder: Image = null
	if fallback != null:
		placeholder = fallback.get_image()
	if placeholder == null or placeholder.is_empty():
		placeholder = Image.create_empty(slot.render_size.x, slot.render_size.y, false, Image.FORMAT_RGBA8)
	else:
		placeholder = placeholder.duplicate() as Image
		if placeholder.is_compressed():
			placeholder.decompress()
		placeholder.convert(Image.FORMAT_RGBA8)
	var texture: ImageTexture = ImageTexture.create_from_image(placeholder)
	_queue.append([slot, appearance.copy(), dominant, texture])
	_pump.call_deferred()
	return texture


## Même chose depuis la mémoire des cas de la partie (vide → silhouette).
func request_for(slot: FigureSlotDef, memory: Dictionary, flags: Dictionary[StringName, Variant],
		dominant: StringName = &"world.steel") -> Texture2D:
	return request(slot, CinematicService.figure_appearance(slot, memory, flags), dominant)


## Silhouette de repli d'un emplacement (null si absente).
static func silhouette_texture(slot: FigureSlotDef) -> Texture2D:
	if slot == null or slot.silhouette_path.is_empty() or not ResourceLoader.exists(slot.silhouette_path):
		return null
	return load(slot.silhouette_path) as Texture2D


## Rendus en attente (tests).
func pending() -> int:
	return _queue.size() + (1 if _busy else 0)


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var job: Array = _queue.pop_front()
	var slot: FigureSlotDef = job[0]
	var img: Image = await render_image(slot, job[1], job[2], false)
	if img != null and not img.is_empty():
		var texture: ImageTexture = job[3]
		if img.get_size() == Vector2i(texture.get_size()):
			texture.update(img)
		else:
			texture.set_image(img)
		figure_ready.emit(slot.id, texture)
	_busy = false
	if not _queue.is_empty():
		_pump()


## Image peinte d'une figure (RGBA8, fond transparent, `slot.render_size`).
## `silhouette` : silhouette anonyme de même pose (repli), `appearance` ignorée
## si null. Rend null en headless.
func render_image(slot: FigureSlotDef, appearance: PassengerAppearance, dominant: StringName, silhouette: bool) -> Image:
	if _headless or slot == null:
		return null
	_ensure_studio()
	var size: Vector2i = slot.render_size if slot.render_size.x > 0 and slot.render_size.y > 0 else Vector2i(512, 768)
	_studio.size = size
	_sitter.process_mode = Node.PROCESS_MODE_INHERIT
	var app: PassengerAppearance = appearance if appearance != null else anonymous_appearance()
	AppearanceApplier.apply(_rig, app)
	_rig.rebuild_parts()
	_neutral_face()
	var clip: StringName = POSE_CLIPS.get(slot.pose, &"idle")
	_pose_player.play(PassengerAnims.clip_path(clip))
	_pose_player.seek(maxf(slot.pose_frame, 0.0), true)
	_pose_player.pause()
	_rig.skeleton.force_update_all_bone_transforms()
	_frame(slot)
	_light(slot.lighting)
	var geometry: Array[GeometryInstance3D] = _geometry()
	var saved: Dictionary = {}
	for g: GeometryInstance3D in geometry:
		saved[g] = g.material_override
		if silhouette:
			g.material_override = _silhouette_mat
	var color: Image = await _grab(_studio)
	for g: GeometryInstance3D in geometry:
		g.material_override = _gbuffer_mat
	# Passe technique : codes bruts (tonemap linéaire, fond « vide » b = 1).
	var flat_bg: Color = _env.background_color
	_env.background_color = Color(0.5, 0.5, 1.0, 1.0)
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_studio.transparent_bg = false
	var gbuf: Image = await _grab(_studio)
	_studio.transparent_bg = true
	_env.background_color = flat_bg
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	for g: GeometryInstance3D in geometry:
		g.material_override = saved[g]
	_sitter.process_mode = Node.PROCESS_MODE_DISABLED
	var ramp: PackedColorArray = PlatePaintStyle.ramp(PlatePaintStyle.dominant_color(dominant), PlatePaintStyle.default_mix(dominant))
	return await paint(color, gbuf, ramp, true)


## Peint une image (passe plein écran `plate_paint`, traitement B) ; `gbuf` peut être null.
func paint(color: Image, gbuf: Image, ramp: PackedColorArray, transparent: bool) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = color.get_size()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(color)
	rect.size = Vector2(color.get_size())
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.material = PlatePaintStyle.paint_material(rect.texture, ImageTexture.create_from_image(gbuf) if gbuf != null else null,
			ramp, transparent)
	vp.add_child(rect)
	var img: Image = await _grab(vp)
	vp.queue_free()
	return img


## Apparence anonyme fixe des silhouettes de repli (jamais affichée en clair).
static func anonymous_appearance() -> PassengerAppearance:
	var traits: Dictionary[StringName, StringName] = {
		&"silhouette": &"silhouette_s2_average", &"face": &"face_oval_e1", &"eyes": &"eyes_grey",
		&"nose_mouth": &"nose_mouth_n1_l1", &"skin": &"skin_03", &"hair": &"hair_short_c01",
		&"headwear": &"none", &"outfit": &"outfit_02", &"accessory": &"none", &"palette": &"palette_10",
	}
	return PassengerAppearance.new(traits, 1)


func _grab(vp: SubViewport) -> Image:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if vp == _studio:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _geometry() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in _rig.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n as GeometryInstance3D
		if g.is_visible_in_tree():
			out.append(g)
	return out


## Cadrage : `full` (pieds → tête), `bust` (poitrine → tête), `profile` (corps
## entier vu de côté).
func _frame(slot: FigureSlotDef) -> void:
	_sitter.rotation_degrees = Vector3(0, 90.0 if slot.framing == &"profile" else 0.0, 0)
	var head_y: float = _rig.head.global_position.y + 0.12 * _rig.scale.y
	var low: float = 0.0
	if slot.framing == &"bust":
		low = head_y - 0.75
	var height: float = (head_y - low) * 1.12
	var distance: float = height * 0.5 / tan(deg_to_rad(FOV * 0.5))
	_camera.position = Vector3(0, low + (head_y - low) * 0.5, distance)
	_camera.rotation = Vector3.ZERO


func _light(preset: StringName) -> void:
	var spec: Array = LIGHTING.get(preset, LIGHTING[&"hall"])
	_key.light_color = spec[0]
	_key.light_energy = float(spec[1])
	_rims[0].light_color = spec[2]
	_rims[1].light_color = spec[3]
	_env.ambient_light_color = spec[4]


func _neutral_face() -> void:
	var mat: ShaderMaterial = _rig.face_material
	if mat == null:
		return
	mat.set_shader_parameter(&"eyes_from", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"eyes_to", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"mouth_from", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"mouth_to", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"blend", 1.0)
	mat.set_shader_parameter(&"pupil_offset", Vector2.ZERO)


func _ensure_studio() -> void:
	if _studio != null:
		return
	_studio = SubViewport.new()
	_studio.name = "FigureStudio"
	_studio.own_world_3d = true
	_studio.transparent_bg = true
	_studio.msaa_3d = Viewport.MSAA_4X
	_studio.use_taa = false
	_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_studio)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = _env
	_studio.add_child(we)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-24, -28, 0)
	_studio.add_child(_key)
	for side: float in [-1.0, 1.0]:
		var rim: OmniLight3D = OmniLight3D.new()
		rim.position = Vector3(1.1 * side, 1.7, -0.9)
		rim.light_energy = 2.4
		rim.omni_range = 3.2
		rim.omni_attenuation = 1.2
		_studio.add_child(rim)
		_rims.append(rim)
	_sitter = Node3D.new()
	_sitter.name = "Sitter"
	_studio.add_child(_sitter)
	_rig = PassengerRig.new()
	_rig.name = "Visual"
	_sitter.add_child(_rig)
	_pose_player = AnimationPlayer.new()
	_sitter.add_child(_pose_player)
	_pose_player.add_animation_library(PassengerAnims.LIBRARY_NAME, PassengerAnims.load_library())
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_studio.add_child(_camera)
	_gbuffer_mat = ShaderMaterial.new()
	_gbuffer_mat.shader = Shader.new()
	_gbuffer_mat.shader.code = """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;
// G-buffer des figures : normale de vue (octaédrique, rg) + profondeur log (b).
void fragment() {
	vec3 n = normalize(NORMAL);
	vec2 o = n.xy / (abs(n.x) + abs(n.y) + abs(n.z));
	if (n.z < 0.0) {
		o = (1.0 - abs(o.yx)) * vec2(o.x >= 0.0 ? 1.0 : -1.0, o.y >= 0.0 ? 1.0 : -1.0);
	}
	float d = clamp(log(max(-VERTEX.z, 0.2) / 0.2) / log(600.0), 0.0, 0.998);
	ALBEDO = vec3(o * 0.5 + 0.5, d);
}
"""
	_silhouette_mat = ShaderMaterial.new()
	_silhouette_mat.shader = Shader.new()
	_silhouette_mat.shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
// Silhouette anonyme de repli : remplissage sombre + liseré teal/rose (aucun trait).
uniform vec4 fill : source_color = vec4(0.055, 0.067, 0.094, 1.0);
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rim = mix(vec3(0.169, 0.431, 0.471), vec3(0.494, 0.227, 0.361), smoothstep(-0.3, 0.3, NORMAL.x));
	ALBEDO = fill.rgb + rim * fresnel * 0.6;
}
"""
	_sitter.process_mode = Node.PROCESS_MODE_DISABLED
