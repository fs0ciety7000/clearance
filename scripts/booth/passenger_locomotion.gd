## Suivi d'un `Path3D` par échantillonnage de courbe + `move_and_slide`
## (ARCHITECTURE §8 bis.3, D-015) : pas de `PathFollow3D`, pas de re-parentage.
##
## Avance une distance paramétrique `distance += speed × delta`, vise un point
## « carotte » 0,3 m devant, oriente le corps dans le sens de la marche
## (`MODEL_FRONT = +Z`). En fin de courbe, si une marque de calage est fournie
## (`DeskMark`), interpole position et orientation dessus (0,2 s).
## Émet `clear_reached` au passage de `clear_distance` (marque `ClearMark`).
class_name PassengerLocomotion
extends Node

signal finished()
signal clear_reached()

const CARROT: float = 0.3
const ARRIVE_EPSILON: float = 0.05
const SNAP_SEC: float = 0.2
const TURN_RATE: float = 8.0

var body: CharacterBody3D = null
var path: Path3D = null
var speed: float = 1.15
var distance: float = 0.0
var length: float = 0.0
var clear_distance: float = -1.0
var snap_target: Node3D = null
var active: bool = false

var _cleared: bool = false
var _snapping: bool = false
var _snap_t: float = 0.0
var _snap_from: Transform3D = Transform3D.IDENTITY


## Lance le suivi. `start_distance` place l'acteur sur la courbe (téléport initial,
## hors champ) ; `snap` = marque finale de calage (sinon fin libre).
func follow(p_path: Path3D, p_speed: float, start_distance: float = 0.0, p_clear_distance: float = -1.0,
		snap: Node3D = null, teleport: bool = true) -> void:
	path = p_path
	speed = maxf(p_speed, 0.05)
	length = path.curve.get_baked_length() if path != null and path.curve != null else 0.0
	distance = clampf(start_distance, 0.0, length)
	clear_distance = p_clear_distance
	snap_target = snap
	_cleared = false
	_snapping = false
	active = path != null and length > 0.0
	if active and teleport:
		var start: Vector3 = point_at(distance)
		body.global_position = start
		var ahead: Vector3 = point_at(minf(distance + CARROT, length)) - start
		ahead.y = 0.0
		if ahead.length() > 0.001:
			body.global_basis = Basis.looking_at(ahead.normalized(), Vector3.UP, true)


func stop() -> void:
	active = false
	_snapping = false
	if body != null:
		body.velocity = Vector3.ZERO


## Point monde de la courbe à une distance donnée.
func point_at(d: float) -> Vector3:
	return path.global_transform * path.curve.sample_baked(d, true)


## Durée restante estimée (watchdogs).
func remaining_time() -> float:
	return maxf(length - distance + CARROT, 0.0) / speed + SNAP_SEC


## Calage immédiat sur l'état final (watchdog, réduire les animations).
func force_finish() -> void:
	if not active:
		return
	if snap_target != null:
		body.global_transform = snap_target.global_transform
	else:
		body.global_position = point_at(length)
	_finish()


func physics_step(delta: float) -> void:
	if not active or body == null:
		return
	if _snapping:
		_snap_t = minf(_snap_t + delta / SNAP_SEC, 1.0)
		var t: float = ease(_snap_t, -2.0)
		body.global_transform = _snap_from.interpolate_with(snap_target.global_transform, t)
		if _snap_t >= 1.0:
			_finish()
		return
	distance = minf(distance + speed * delta, length)
	if clear_distance >= 0.0 and not _cleared and distance >= clear_distance:
		_cleared = true
		clear_reached.emit()
	var target: Vector3 = point_at(minf(distance + CARROT, length))
	var to: Vector3 = target - body.global_position
	to.y = 0.0
	if distance >= length and to.length() < ARRIVE_EPSILON:
		body.velocity = Vector3.ZERO
		if snap_target != null:
			_snapping = true
			_snap_t = 0.0
			_snap_from = body.global_transform
		else:
			_finish()
		return
	var step: float = minf(speed, to.length() / maxf(delta, 0.0001))
	body.velocity = to.normalized() * step
	body.move_and_slide()
	if to.length() > 0.02:
		var wanted: Basis = Basis.looking_at(to.normalized(), Vector3.UP, true)
		body.global_basis = body.global_basis.slerp(wanted, clampf(TURN_RATE * delta, 0.0, 1.0)).orthonormalized()


func _finish() -> void:
	active = false
	_snapping = false
	body.velocity = Vector3.ZERO
	if clear_distance >= 0.0 and not _cleared:
		_cleared = true
		clear_reached.emit()
	finished.emit()
