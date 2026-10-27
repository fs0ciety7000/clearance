## File d'attente en imposteurs (ARCHITECTURE §8 bis.9, BOOTH_SCENE §11).
##
## Un `MultiMeshInstance3D` de silhouettes (capsules greybox) posées sur les
## places du zigzag, teintées par un RNG cosmétique (graine du jour). La tête
## de file est masquée quand l'acteur entre en scène ; la file avance d'une
## place à chaque `passenger_departed` (interpolation 1,2 s, pas de squelette).
class_name QueueImpostors
extends MultiMeshInstance3D

const ADVANCE_SEC: float = 1.2

## Places au sol (x, z), de la tête de file (derrière le pilier) vers la queue.
@export var slots: PackedVector2Array = PackedVector2Array([
	Vector2(-1.32, -3.45), Vector2(-1.95, -4.15), Vector2(-1.40, -4.85), Vector2(-2.25, -5.55),
	Vector2(-1.55, -6.30), Vector2(-2.45, -6.95), Vector2(-2.95, -7.60),
])
@export var tint_seed: int = 0
@export var tints: PackedColorArray = PackedColorArray([
	Color("#3B4252"), Color("#5B4A3F"), Color("#2F4A4C"), Color("#4C3A4F"), Color("#6B6355"), Color("#2E3A55"),
])

## Position (index de place, flottant) de chaque instance.
var _places: PackedFloat32Array = []
var _hidden: Array[bool] = []
var _scales: PackedFloat32Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tween: Tween = null


func _ready() -> void:
	setup(tint_seed)


## (Ré)initialise la file avec une graine cosmétique (ex. graine du jour).
func setup(p_seed: int) -> void:
	_rng.seed = p_seed
	var count: int = slots.size() - 1
	if multimesh == null:
		multimesh = MultiMesh.new()
	multimesh.instance_count = 0
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = count
	_places.resize(count)
	_scales.resize(count)
	_hidden.clear()
	for i: int in count:
		_places[i] = float(i)
		_hidden.append(false)
		_restyle(i)
	_update()


## Masque l'imposteur de tête (l'acteur animé prend sa place).
func hide_head() -> void:
	for i: int in _places.size():
		if _places[i] < 0.5:
			_hidden[i] = true
	_update()


## Avance d'une place ; l'imposteur sorti repart en queue de file (nouvelle teinte).
func advance() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_snap_places()
	var start: PackedFloat32Array = _places.duplicate()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		for i: int in _places.size():
			_places[i] = start[i] - t
		_update(), 0.0, 1.0, ADVANCE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_snap_places)


func _snap_places() -> void:
	for i: int in _places.size():
		_places[i] = roundf(_places[i])
		if _places[i] < 0.0:
			_places[i] = float(_places.size() - 1)
			_hidden[i] = false
			_restyle(i)
	_update()


func _restyle(i: int) -> void:
	_scales[i] = _rng.randf_range(0.92, 1.08)
	var tint: Color = tints[_rng.randi_range(0, tints.size() - 1)] if not tints.is_empty() else Color.GRAY
	multimesh.set_instance_color(i, tint)


func _update() -> void:
	for i: int in _places.size():
		var p: Vector2 = _point_at(_places[i])
		var s: float = 0.0 if _hidden[i] else _scales[i]
		var xf: Transform3D = Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(p.x, 0.85 * s, p.y))
		multimesh.set_instance_transform(i, xf)


func _point_at(place: float) -> Vector2:
	var clamped: float = clampf(place, 0.0, float(slots.size() - 1))
	var a: int = floori(clamped)
	var b: int = mini(a + 1, slots.size() - 1)
	return slots[a].lerp(slots[b], clamped - a)
