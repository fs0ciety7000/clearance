## Portraits des documents (ARCHITECTURE §8 bis.5, D-012/D-018, BOOTH_SCENE §12.6).
##
## `get_portrait(appearance) -> Texture2D` rend la `PassengerAppearance` avec le
## **même** `PassengerRig` + `AppearanceApplier` que l'acteur du guichet, dans
## un studio `SubViewport` 256×320 (`UPDATE_ONCE`) : éclairage plat, fond uni,
## sans rim néon, expression neutre, ligne des yeux à hauteur fixe. L'apparence
## est rendue **telle quelle** (la photo officielle sans coiffe ni accessoire est
## déjà produite par le générateur).
##
## Contrat pour l'UI : un `Callable` `portrait_provider = service.get_portrait`.
## La texture est renvoyée **immédiatement** (esquisse CPU) puis mise à jour sur
## place quand le rendu GPU est prêt (`portrait_ready`) : un `TextureRect` qui
## l'affiche se rafraîchit seul. Cache par signature d'apparence (vider au
## changement de jour : `clear_cache()`). En headless (tests), l'esquisse CPU est
## la seule sortie : la comparaison se fait de toute façon sur les traits.
class_name PortraitService
extends Node

signal portrait_ready(texture: Texture2D)

const SIZE: Vector2i = Vector2i(256, 320)
const BACKDROP: Color = Color("#2A3140")
## Champ vertical et recul de la caméra portrait (épaules → haut du crâne).
const FOV: float = 18.0
const DISTANCE: float = 1.25
## Ligne des yeux à 42 % de la hauteur depuis le haut.
const EYE_LINE: float = 0.42

var _cache: Dictionary[String, ImageTexture] = {}
var _queue: Array[Array] = []
var _busy: bool = false
var _headless: bool = false
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _rig: PassengerRig = null


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		_build_studio()


## Portrait d'une apparence (même objet `Texture2D` pour une même signature).
func get_portrait(appearance: PassengerAppearance) -> Texture2D:
	if appearance == null:
		return null
	var key: String = signature(appearance)
	if _cache.has(key):
		return _cache[key]
	var texture: ImageTexture = ImageTexture.create_from_image(sketch(appearance))
	_cache[key] = texture
	if not _headless and is_inside_tree():
		_queue.append([appearance.copy(), texture])
		_pump.call_deferred()
	return texture


func clear_cache() -> void:
	_cache.clear()


func cache_size() -> int:
	return _cache.size()


static func signature(appearance: PassengerAppearance) -> String:
	return JSON.stringify(appearance.serialize())


## Esquisse CPU (fallback headless et image d'attente) : fond, épaules, cou,
## visage (teinte de peau), cheveux, yeux. Même structure de couleurs que le rig.
static func sketch(appearance: PassengerAppearance) -> Image:
	var img: Image = Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(BACKDROP)
	var skin: Color = GreyboxStyle.skin_color(appearance)
	var pal: PackedColorArray = GreyboxStyle.palette(appearance)
	var hair: Color = GreyboxStyle.hair_color(appearance)
	var eyes: PackedColorArray = GreyboxStyle.eye_colors(appearance)
	var cx: float = SIZE.x * 0.5
	var shoulders: float = 0.36 * GreyboxStyle.silhouette_scale(appearance).x
	_fill_ellipse(img, Vector2(cx, SIZE.y * 1.02), Vector2(SIZE.x * shoulders, SIZE.y * 0.26), pal[0])
	_fill_ellipse(img, Vector2(cx, SIZE.y * 0.70), Vector2(SIZE.x * 0.08, SIZE.y * 0.1), skin.darkened(0.1))
	var face_w: float = 0.24
	match GreyboxStyle.face_shape(appearance):
		&"round":
			face_w = 0.27
		&"oval":
			face_w = 0.22
	_fill_ellipse(img, Vector2(cx, SIZE.y * 0.47), Vector2(SIZE.x * face_w, SIZE.y * 0.2), skin)
	if GreyboxStyle.hair_cut(appearance) != &"shaved":
		_fill_ellipse(img, Vector2(cx, SIZE.y * 0.33), Vector2(SIZE.x * (face_w + 0.02), SIZE.y * 0.1), hair)
	for side: int in [-1, 1]:
		var eye: Color = eyes[0] if side < 0 else eyes[1]
		_fill_ellipse(img, Vector2(cx + side * SIZE.x * 0.085, SIZE.y * EYE_LINE), Vector2(9, 7), eye)
	return img


static func _fill_ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var x0: int = maxi(int(center.x - radius.x), 0)
	var x1: int = mini(int(center.x + radius.x) + 1, img.get_width())
	var y0: int = maxi(int(center.y - radius.y), 0)
	var y1: int = mini(int(center.y + radius.y) + 1, img.get_height())
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var d: Vector2 = (Vector2(x + 0.5, y + 0.5) - center) / radius
			if d.length_squared() <= 1.0:
				img.set_pixel(x, y, color)


func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "PortraitStudio"
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8A97A8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18, -20, 0)
	key.light_energy = 1.1
	key.light_color = GreyboxStyle.WORLD_KEY
	_viewport.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-5, 30, 0)
	fill.light_energy = 0.35
	_viewport.add_child(fill)

	_rig = PassengerRig.new()
	_rig.name = "Sitter"
	_rig.set_rim_enabled(false)
	_viewport.add_child(_rig)

	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_viewport.add_child(_camera)


func _pump() -> void:
	if _busy or _queue.is_empty() or _viewport == null:
		return
	_busy = true
	var job: Array = _queue.pop_front()
	var appearance: PassengerAppearance = job[0]
	var texture: ImageTexture = job[1]
	AppearanceApplier.apply(_rig, appearance)
	_neutral_face()
	# Ligne des yeux à hauteur fixe dans le cadre, quelle que soit la taille.
	var eyes_y: float = _rig.head.global_position.y + 0.02 * _rig.scale.y
	var half_height: float = DISTANCE * tan(deg_to_rad(FOV * 0.5))
	var center_y: float = eyes_y - half_height * 2.0 * (0.5 - EYE_LINE)
	_camera.position = Vector3(0, center_y, DISTANCE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img: Image = _viewport.get_texture().get_image()
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() == SIZE:
			texture.update(img)
		else:
			texture.set_image(img)
		portrait_ready.emit(texture)
	_busy = false
	if not _queue.is_empty():
		_pump()


func _neutral_face() -> void:
	var mat: ShaderMaterial = _rig.face_material
	mat.set_shader_parameter(&"eyes_from", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"eyes_to", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"mouth_from", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"mouth_to", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"blend", 1.0)
	mat.set_shader_parameter(&"pupil_offset", Vector2.ZERO)
