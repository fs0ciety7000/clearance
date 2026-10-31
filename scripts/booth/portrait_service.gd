## Portraits des documents (ARCHITECTURE §8 bis.5, D-012/D-018, BOOTH_SCENE §12.6).
##
## `get_portrait(appearance) -> Texture2D` rend la `PassengerAppearance` avec le
## **même** `PassengerRig` (modèle Kenney final, M6) + `AppearanceApplier` que
## l'acteur du guichet, posé sur la 1ʳᵉ image d'`idle`, dans
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
## Coût (M10, BOOTH_SCENE §18.4) : un rendu `UPDATE_ONCE` par signature, puis
## rien — viewport `UPDATE_DISABLED` et modèle du studio en pause entre deux
## portraits ; les pièces fusionnées viennent du cache partagé avec l'acteur.
## M14 (B92, D-191 ; lot C) : `size` règle la taille du rendu — 256×320 pour les
## documents (défaut), **128×160** pour les vignettes du Dossier (`DOSSIER_SIZE`,
## instance autonome du `DossierScreen`, lot D). Changer la taille vide le cache.
class_name PortraitService
extends Node

signal portrait_ready(texture: Texture2D)

const SIZE: Vector2i = Vector2i(256, 320)
## Vignettes du Dossier (M14 §5.3), affichées à 96×120.
const DOSSIER_SIZE: Vector2i = Vector2i(128, 160)
const BACKDROP: Color = Color("#2A3140")
## Champ vertical et recul de la caméra portrait (épaules → haut du crâne).
const FOV: float = 18.0
const DISTANCE: float = 1.75
## Ligne des yeux à 42 % de la hauteur depuis le haut.
const EYE_LINE: float = 0.42

## QA-053 : plafond du cache (LRU). La Garde ne recharge jamais la scène : sans
## plafond, un portrait par passager s'accumule (+0,4 Mo chacun). Une texture
## évincée reste valide pour qui l'affiche encore ; redemandée, elle est
## re-rendue. Campagne : le cache est déjà vidé à chaque jour, le plafond
## (≥ la file d'un jour) n'évince presque jamais. Garde (session sans fin) :
## plafond serré — le passager à la vitre, les quelques précédents et les avis
## du Rulebook.
const DEFAULT_MAX_ENTRIES: int = 24
const GARDE_MAX_ENTRIES: int = 12

## Taille maximale du cache ; 0 = automatique (`GARDE_MAX_ENTRIES` en session
## de Garde, sinon `DEFAULT_MAX_ENTRIES`). Ordre d'insertion du dictionnaire =
## ordre d'utilisation (le plus ancien en tête).
var max_entries: int = 0
## Taille du rendu (et de l'esquisse) ; à poser avant l'entrée dans l'arbre de
## préférence (sinon le studio est redimensionné et le cache vidé).
var size: Vector2i = SIZE:
	set(value):
		var clamped: Vector2i = Vector2i(maxi(value.x, 16), maxi(value.y, 20))
		if clamped == size:
			return
		size = clamped
		_cache.clear()
		if _viewport != null:
			_viewport.size = size
var _cache: Dictionary[String, ImageTexture] = {}
var _queue: Array[Array] = []
var _busy: bool = false
var _headless: bool = false
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _rig: PassengerRig = null
var _pose_player: AnimationPlayer = null
var _sitter: Node3D = null


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
		# LRU : la signature redevient la plus récente.
		var cached: ImageTexture = _cache[key]
		_cache.erase(key)
		_cache[key] = cached
		return cached
	var texture: ImageTexture = ImageTexture.create_from_image(sketch(appearance, size))
	_cache[key] = texture
	_evict()
	if not _headless and is_inside_tree():
		_queue.append([appearance.copy(), texture])
		_pump.call_deferred()
	return texture


func clear_cache() -> void:
	_cache.clear()


func cache_size() -> int:
	return _cache.size()


## Plafond en vigueur (voir `max_entries`).
func cache_limit() -> int:
	if max_entries > 0:
		return max_entries
	return GARDE_MAX_ENTRIES if GameState.session_mode == GameState.SESSION_GARDE else DEFAULT_MAX_ENTRIES


## Retire les signatures les moins récemment utilisées au-delà de `cache_limit()`.
func _evict() -> void:
	var limit: int = cache_limit()
	while _cache.size() > limit:
		_cache.erase(_cache.keys()[0])


static func signature(appearance: PassengerAppearance) -> String:
	return JSON.stringify(appearance.serialize())


## Esquisse CPU (fallback headless et image d'attente) : fond, épaules, cou,
## visage (teinte de peau), cheveux, yeux. Même structure de couleurs que le rig.
## `p_size` : taille de l'image (défaut : celle des documents).
static func sketch(appearance: PassengerAppearance, p_size: Vector2i = SIZE) -> Image:
	var img: Image = Image.create_empty(p_size.x, p_size.y, false, Image.FORMAT_RGBA8)
	img.fill(BACKDROP)
	var skin: Color = GreyboxStyle.skin_color(appearance)
	var pal: PackedColorArray = GreyboxStyle.palette(appearance)
	var hair: Color = GreyboxStyle.hair_color(appearance)
	var eyes: PackedColorArray = GreyboxStyle.eye_colors(appearance)
	var cx: float = p_size.x * 0.5
	var shoulders: float = 0.36 * GreyboxStyle.silhouette_scale(appearance).x
	_fill_ellipse(img, Vector2(cx, p_size.y * 1.02), Vector2(p_size.x * shoulders, p_size.y * 0.26), pal[0])
	_fill_ellipse(img, Vector2(cx, p_size.y * 0.70), Vector2(p_size.x * 0.08, p_size.y * 0.1), skin.darkened(0.1))
	var face_w: float = 0.24
	match GreyboxStyle.face_shape(appearance):
		&"round":
			face_w = 0.27
		&"oval":
			face_w = 0.22
	_fill_ellipse(img, Vector2(cx, p_size.y * 0.47), Vector2(p_size.x * face_w, p_size.y * 0.2), skin)
	if GreyboxStyle.hair_cut(appearance) != &"shaved":
		_fill_ellipse(img, Vector2(cx, p_size.y * 0.33), Vector2(p_size.x * (face_w + 0.02), p_size.y * 0.1), hair)
	for side: int in [-1, 1]:
		var eye: Color = eyes[0] if side < 0 else eyes[1]
		_fill_ellipse(img, Vector2(cx + side * p_size.x * 0.085, p_size.y * EYE_LINE), Vector2(9, 7) * (p_size.x / 256.0), eye)
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
	_viewport.size = size
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

	# Le modèle posé sur la première image d'`idle` (bibliothèque `passenger`) :
	# l'AnimationPlayer vise « Visual/Armature/Skeleton3D », comme sur l'acteur.
	_sitter = Node3D.new()
	_sitter.name = "Sitter"
	_viewport.add_child(_sitter)
	_rig = PassengerRig.new()
	_rig.name = "Visual"
	_rig.set_rim_enabled(false)
	_sitter.add_child(_rig)
	_pose_player = AnimationPlayer.new()
	_sitter.add_child(_pose_player)
	_pose_player.add_animation_library(PassengerAnims.LIBRARY_NAME, PassengerAnims.load_library())
	_pose_player.play(PassengerAnims.clip_path(&"idle"))
	_pose_player.seek(0.0, true)
	_pose_player.pause()

	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_viewport.add_child(_camera)
	# Hors rendu, le studio ne coûte rien : viewport `UPDATE_DISABLED`, modèle
	# (squelette, modificateurs) en pause jusqu'au prochain portrait.
	_sitter.process_mode = Node.PROCESS_MODE_DISABLED


func _pump() -> void:
	if _busy or _queue.is_empty() or _viewport == null:
		return
	_busy = true
	var job: Array = _queue.pop_front()
	var appearance: PassengerAppearance = job[0]
	var texture: ImageTexture = job[1]
	_sitter.process_mode = Node.PROCESS_MODE_INHERIT
	AppearanceApplier.apply(_rig, appearance)
	# Pièces fusionnées tout de suite (même maillage en cache que l'acteur).
	_rig.rebuild_parts()
	_neutral_face()
	_pose_player.seek(0.0, true)
	_rig.skeleton.force_update_all_bone_transforms()
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
		if img.get_size() == Vector2i(texture.get_size()):
			texture.update(img)
		else:
			texture.set_image(img)
		portrait_ready.emit(texture)
	_busy = false
	if not _queue.is_empty():
		_pump()
	else:
		_sitter.process_mode = Node.PROCESS_MODE_DISABLED


func _neutral_face() -> void:
	var mat: ShaderMaterial = _rig.face_material
	mat.set_shader_parameter(&"eyes_from", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"eyes_to", FaceAtlas.EYES_NEUTRAL)
	mat.set_shader_parameter(&"mouth_from", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"mouth_to", FaceAtlas.MOUTH_NEUTRAL)
	mat.set_shader_parameter(&"blend", 1.0)
	mat.set_shader_parameter(&"pupil_offset", Vector2.ZERO)
