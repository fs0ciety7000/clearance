## Gardes du Hall (M14 §4.3, VH-4, VH-5, B87, D-188) : postes fixes et
## patrouille en silhouettes (`imp_guard.res`, brassard jaune émissif), un seul
## `MultiMesh` (1 draw) pour tout le monde.
##
## - **Postes** (0 à 3) près du portique : immobiles, balancement seul.
## - **Patrouille** : au fond du Hall (Z ≈ −8,55), d'un pilier vers le centre
##   puis retour, à 1,1 m/s avec le « pas » du shader ; une seule Garde en
##   mouvement à la fois (`patrol` = 2 : deux passages l'un après l'autre, un de
##   chaque côté). **Jamais dans le cadre du visage** : les deux demi-chemins
##   s'arrêtent à |x| ≥ `PATROL_INNER_X` (rectangle projeté du visage + 15 %,
##   au cadrage normal comme au travelling ; GUT `test_m14_hall.gd`, M-15).
## - **À l'arrêt** pendant l'inspection (`DayPhase.INSPECTING`) et pendant une
##   escorte de DÉTENTION ; repart au départ du passager.
## - Coupure EV-05 / grève du J20 : silhouettes assombries, patrouille arrêtée.
## - J27 : traversée de l'Arbitre escortée (`start_arbiter_crossing`, à
##   `hall_j27_arbitre`), sur la moitié droite du Hall (hors cadre du visage).
## - Qualité Bas (D-074) : postes seuls.
## Calendrier : `HallAmbience.for_day`. Aucune donnée de cas.
class_name HallGuards
extends MultiMeshInstance3D

const MESH_PATH: String = "res://assets/models/passenger/imp_guard.res"
const SPEED: float = 1.1
const PATROL_Z: float = -8.55
## Bord intérieur des demi-chemins (m) : au-delà du rectangle du visage + 15 %.
const PATROL_INNER_X: float = 1.6
## Point de départ, hors champ (derrière un pilier du fond).
const PATROL_OUTER_X: float = 7.4
const PAUSE_AT_TURN_SEC: float = 2.5
## Postes près du portique (x, z, cap en degrés : 0 = face au guichet).
const POSTS: Array[Vector3] = [Vector3(4.15, -6.3, -12.0), Vector3(-5.2, -6.6, 15.0), Vector3(4.85, -6.95, -20.0)]
## Traversée de l'Arbitre (J27) : moitié droite, de l'entrée vers le portique et retour.
const ARBITER_PATH: Array[Vector2] = [Vector2(7.6, -7.6), Vector2(2.2, -8.6), Vector2(1.7, -9.2)]
const ARBITER_PAUSE_SEC: float = 4.0
## Teintes (monde : uniforme gris, Arbitre claire, civil du comité ocre).
const TINT_GUARD: Color = Color("#4A515C")
const TINT_ARBITER: Color = Color("#8E9099")
const TINT_CIVIL: Color = Color("#5C4A36")

## Réglages du jour (`HallAmbience.for_day`).
var settings: Dictionary = {}
var quality: int = 2
var inspecting: bool = false
var escorting: bool = false
var dimmed: bool = false
## Patrouille : `idle` (hors champ), `out` (vers le centre), `turn`, `back`.
var patrol_state: StringName = &"idle"
var patrol_side: int = -1
var patrol_x: float = PATROL_OUTER_X
var arbiter_active: bool = false
var arbiter_progress: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wait: float = 0.0
var _passes_left: int = 0
var _turn_left: float = 0.0
var _arbiter_pause: float = 0.0
var _arbiter_dir: int = 1
var _material: ShaderMaterial = null


func _ready() -> void:
	if multimesh == null:
		multimesh = MultiMesh.new()
	if ResourceLoader.exists(MESH_PATH):
		multimesh.mesh = load(MESH_PATH) as Mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = material_override as ShaderMaterial
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)
	_apply_motion()
	if settings.is_empty():
		configure(HallAmbience.for_day(1), 0)


func _exit_tree() -> void:
	if EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.disconnect(_on_settings_changed)


## (Re)configure pour un jour (`HallAmbience.for_day`) et une graine cosmétique.
func configure(p_settings: Dictionary, p_seed: int, p_quality: int = -1) -> void:
	settings = p_settings
	quality = clampi(Settings.graphics_quality_level() if p_quality < 0 else p_quality, 0, 2)
	_rng.seed = p_seed
	inspecting = false
	escorting = false
	dimmed = false
	arbiter_active = false
	patrol_state = &"idle"
	patrol_x = PATROL_OUTER_X
	_passes_left = 0
	_wait = _rng.randf_range(20.0, 60.0)
	_rebuild()


## Nombre de postes et de patrouilleurs effectifs (qualité Bas : postes seuls).
func posts() -> int:
	return clampi(int(settings.get("posts", 0)), 0, POSTS.size())


func patrol_count() -> int:
	return 0 if quality <= 0 else int(settings.get("patrol", 0))


## Points du chemin de patrouille d'un côté (−1 gauche, +1 droite), repère monde.
static func path_points(side: int) -> Array[Vector3]:
	return [Vector3(PATROL_OUTER_X * side, 0, PATROL_Z), Vector3(PATROL_INNER_X * side, 0, PATROL_Z)]


func set_inspecting(value: bool) -> void:
	inspecting = value


func set_escorting(value: bool) -> void:
	escorting = value


## Coupure (EV-05) ou grève : silhouettes assombries, patrouille arrêtée.
func set_dimmed(value: bool) -> void:
	dimmed = value
	_update_instances()


## Traversée de l'Arbitre escortée (J27, `hall_j27_arbitre`).
func start_arbiter_crossing() -> void:
	if arbiter_active or not bool(settings.get("arbiter", false)):
		return
	arbiter_active = true
	arbiter_progress = 0.0
	_arbiter_dir = 1
	_arbiter_pause = 0.0
	_rebuild()


func is_patrol_moving() -> bool:
	return patrol_state == &"out" or patrol_state == &"back"


func _process(delta: float) -> void:
	var dirty: bool = false
	if arbiter_active:
		dirty = _step_arbiter(delta) or dirty
	if patrol_count() > 0 and not dimmed:
		dirty = _step_patrol(delta) or dirty
	if dirty:
		_update_instances()


func _step_patrol(delta: float) -> bool:
	if inspecting or escorting:
		return false # à l'arrêt (sur place ou hors champ)
	match patrol_state:
		&"idle":
			_wait -= delta
			if _wait > 0.0:
				return false
			if _passes_left <= 0:
				_passes_left = patrol_count()
			patrol_side = -1 if _rng.randf() < 0.5 else 1
			patrol_state = &"out"
			patrol_x = PATROL_OUTER_X
		&"out":
			patrol_x = move_toward(patrol_x, PATROL_INNER_X, SPEED * delta)
			if patrol_x <= PATROL_INNER_X:
				patrol_state = &"turn"
				_turn_left = PAUSE_AT_TURN_SEC
		&"turn":
			_turn_left -= delta
			if _turn_left <= 0.0:
				patrol_state = &"back"
		&"back":
			patrol_x = move_toward(patrol_x, PATROL_OUTER_X, SPEED * delta)
			if patrol_x >= PATROL_OUTER_X:
				patrol_state = &"idle"
				_passes_left -= 1
				# Second passage (Acte II) : aussitôt, de l'autre côté.
				var interval: Vector2 = settings.get("interval", Vector2(150, 210))
				_wait = 3.0 if _passes_left > 0 else _rng.randf_range(interval.x, interval.y)
	return true


func _step_arbiter(delta: float) -> bool:
	if _arbiter_pause > 0.0:
		_arbiter_pause -= delta
		return false
	var length: float = _arbiter_length()
	arbiter_progress += _arbiter_dir * SPEED * 0.85 * delta / maxf(length, 0.01)
	if _arbiter_dir > 0 and arbiter_progress >= 1.0:
		arbiter_progress = 1.0
		_arbiter_dir = -1
		_arbiter_pause = ARBITER_PAUSE_SEC
	elif _arbiter_dir < 0 and arbiter_progress <= 0.0:
		arbiter_active = false
		_rebuild()
		return false
	return true


static func _arbiter_length() -> float:
	var total: float = 0.0
	for i: int in ARBITER_PATH.size() - 1:
		total += ARBITER_PATH[i].distance_to(ARBITER_PATH[i + 1])
	return total


static func arbiter_point(t: float) -> Vector2:
	var target: float = clampf(t, 0.0, 1.0) * _arbiter_length()
	for i: int in ARBITER_PATH.size() - 1:
		var seg: float = ARBITER_PATH[i].distance_to(ARBITER_PATH[i + 1])
		if target <= seg or i == ARBITER_PATH.size() - 2:
			return ARBITER_PATH[i].lerp(ARBITER_PATH[i + 1], clampf(target / maxf(seg, 0.001), 0.0, 1.0))
		target -= seg
	return ARBITER_PATH[ARBITER_PATH.size() - 1]


## Nombre d'instances : postes + 1 patrouilleur (+ Arbitre et son escorte).
func instance_total() -> int:
	return multimesh.instance_count


func _rebuild() -> void:
	var count: int = posts() + (1 if patrol_count() > 0 else 0) + (2 if arbiter_active else 0)
	if multimesh.instance_count != count:
		multimesh.instance_count = 0
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.instance_count = count
	visible = count > 0
	_update_instances()


func _update_instances() -> void:
	var k: int = 0
	var dim: float = 1.0 if dimmed else 0.0
	var post_mode: int = int(settings.get("post_mode", HallAmbience.POST_GUARD))
	for i: int in posts():
		var p: Vector3 = POSTS[i]
		_put(k, Vector3(p.x, 0, p.y), deg_to_rad(p.z), post_mode, TINT_CIVIL if post_mode == HallAmbience.POST_CIVIL else TINT_GUARD, 0.0, dim, 1.0)
		k += 1
	if patrol_count() > 0:
		var moving: float = 1.0 if is_patrol_moving() and not inspecting and not escorting and not dimmed else 0.0
		var heading: float = -patrol_side * (PI * 0.5) if patrol_state == &"out" else patrol_side * (PI * 0.5)
		var shown: float = 0.0 if patrol_state == &"idle" else 1.0
		_put(k, Vector3(patrol_x * patrol_side, 0, PATROL_Z), heading, 1, TINT_GUARD, moving, dim, shown)
		k += 1
	if arbiter_active:
		var walking: float = 0.0 if _arbiter_pause > 0.0 else 1.0
		var a: Vector2 = arbiter_point(arbiter_progress)
		var ahead: Vector2 = arbiter_point(arbiter_progress + 0.02 * _arbiter_dir) - a
		var yaw: float = atan2(ahead.x, ahead.y) if ahead.length() > 0.001 else 0.0
		_put(k, Vector3(a.x, 0, a.y), yaw, 2, TINT_ARBITER, walking, dim, 1.0)
		var e: Vector2 = arbiter_point(arbiter_progress - 0.12 * _arbiter_dir) + Vector2(0.45, 0.25)
		_put(k + 1, Vector3(e.x, 0, e.y), yaw, 1, TINT_GUARD, walking, dim, 1.0)


func _put(k: int, pos: Vector3, yaw: float, mode: int, tint: Color, walking: float, dim: float, shown: float) -> void:
	if k >= multimesh.instance_count:
		return
	var s: float = shown
	multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), pos))
	multimesh.set_instance_color(k, tint)
	multimesh.set_instance_custom_data(k, Color(walking, float(k) * 1.3, float(mode), dim))


func _apply_motion() -> void:
	if _material != null:
		_material.set_shader_parameter(&"motion", 0.0 if Settings.reduce_motion else 1.0)


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_REDUCE_MOTION:
		_apply_motion()
	elif key == Settings.KEY_GRAPHICS_QUALITY:
		quality = clampi(Settings.graphics_quality_level(), 0, 2)
		_rebuild()
