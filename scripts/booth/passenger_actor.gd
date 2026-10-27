## Acteur 3D du passager (ARCHITECTURE §8 bis.2, D-009/D-010/D-021).
##
## Ne connaît **ni l'EventBus ni `Case`** : API impérative pilotée par
## `BoothDirector`, signaux locaux. M6 : rig Kenney retargeté (`PassengerRig`),
## bibliothèque `passenger` (clips Quaternius UAL, `PassengerAnims`), regard par
## deux `LookAtModifier3D` (cou 30 %, tête 100 %) dont la cible est bornée ici,
## plaque visage ditherée ancrée sur l'os `Head` (`ExpressionController`).
class_name PassengerActor
extends CharacterBody3D

signal arrived()
signal departed()
## Le sortant a libéré le guichet (marque `ClearMark`).
signal cleared()
signal anim_event(event_name: StringName)
signal reaction_finished(reaction: PassengerReaction.Kind)
signal face_clicked()

## Vitesse de marche nominale (m/s) ; la vitesse de référence du clip `walk`
## (`PassengerAnims.walk_v_ref()`, mesurée à l'import) donne `speed_scale = v / v_ref`.
const WALK_NOMINAL_SPEED: float = 1.15
## Limites du regard (BOOTH_SCENE §9.1) : lacet ±40°, tangage −25° (bas) / +15° (haut).
const LOOK_YAW_LIMIT: float = deg_to_rad(40.0)
const LOOK_DOWN_LIMIT: float = deg_to_rad(25.0)
const LOOK_UP_LIMIT: float = deg_to_rad(15.0)
const LOOK_SMOOTH: float = 8.0
const LOOK_FADE_SEC: float = 0.2
const REACTION_COOLDOWN_SEC: float = 0.4
const NOD_SEC: float = 0.5

enum State { FREE, ARRIVING, AT_DESK, LEAVING }

const REACTION_INPUT: Dictionary[PassengerReaction.Kind, StringName] = {
	PassengerReaction.Kind.ANGRY: &"angry",
	PassengerReaction.Kind.NERVOUS: &"nervous",
	PassengerReaction.Kind.SHRUG: &"shrug",
}
const REACTION_EXPRESSION: Dictionary[PassengerReaction.Kind, StringName] = {
	PassengerReaction.Kind.ANGRY: &"angry",
	PassengerReaction.Kind.NERVOUS: &"nervous",
	PassengerReaction.Kind.SHRUG: &"neutral",
	PassengerReaction.Kind.RELIEVED: &"relieved",
}

var state: State = State.FREE
var case_id: StringName = &""
## Ordre d'attribution (le pool force le plus ancien si aucun n'est libre).
var assigned_serial: int = 0
## Réduire les animations : réactions = expression seule.
var reduce_motion: bool = false

@onready var rig: PassengerRig = %Visual
@onready var locomotion: PassengerLocomotion = %Locomotion
@onready var anim_player: AnimationPlayer = %AnimationPlayer
@onready var anim_tree: AnimationTree = %AnimationTree
@onready var look_target: Marker3D = %LookTarget
@onready var expression: ExpressionController = %ExpressionController

var _documents_slot_fired: bool = false
var _pending_reaction: int = -1
var _reaction_left: float = 0.0
var _reaction_kind: PassengerReaction.Kind = PassengerReaction.Kind.SHRUG
var _reacting: bool = false
var _visor_app: PassengerAppearance = null
var _look_goal: Vector3 = Vector3.ZERO
var _look_enabled: bool = false
var _look_weight: float = 0.0
var _look_angles: Vector2 = Vector2.ZERO
var _nod_left: float = 0.0
## Temps restant de `present_documents` (le regard revient ensuite, §8 bis.4).
var _present_left: float = 0.0
var _playback: AnimationNodeStateMachinePlayback = null


func _ready() -> void:
	if not anim_player.has_animation_library(PassengerAnims.LIBRARY_NAME):
		anim_player.add_animation_library(PassengerAnims.LIBRARY_NAME, PassengerAnims.load_library())
	if anim_tree.tree_root == null:
		anim_tree.tree_root = PassengerAnims.build_tree()
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	_playback = anim_tree.get(&"parameters/Main/playback")
	locomotion.body = self
	locomotion.finished.connect(_on_locomotion_finished)
	locomotion.clear_reached.connect(_on_clear_reached)
	rig.head_area.input_event.connect(_on_head_input_event)
	look_target.top_level = true
	for look: LookAtModifier3D in [rig.neck_look, rig.head_look]:
		look.target_node = look.get_path_to(look_target)
	release()


## Remet l'acteur au repos pour un nouveau cas (habillage séparé).
func assign(p_case_id: StringName, serial: int, expression_seed: int) -> void:
	case_id = p_case_id
	assigned_serial = serial
	state = State.ARRIVING
	visible = true
	_documents_slot_fired = false
	_pending_reaction = -1
	_reacting = false
	_reaction_left = 0.0
	_visor_app = null
	_nod_left = 0.0
	_present_left = 0.0
	rig.papers.visible = false
	expression.paused = false
	expression.instant = reduce_motion
	expression.setup(rig.face_material, expression_seed)
	set_look_enabled(false)
	anim_tree.set(&"parameters/TalkBlend/blend_amount", 0.0)
	_playback.start(&"idle")


## Rendu au pool : masqué, immobile.
func release() -> void:
	state = State.FREE
	case_id = &""
	visible = false
	locomotion.stop()
	expression.paused = true
	set_look_enabled(false)


func is_free() -> bool:
	return state == State.FREE


func apply_appearance(app: PassengerAppearance) -> void:
	AppearanceApplier.apply(rig, app)


## Marche le long de `path` jusqu'à `snap` (arrivée) ; `arrived` à la fin.
func walk_to_desk(path: Path3D, speed: float, start_distance: float, snap: Node3D) -> void:
	state = State.ARRIVING
	_set_walk_speed(speed)
	_playback.travel(&"walk")
	locomotion.follow(path, speed, start_distance, -1.0, snap)


## Quitte le guichet : `leave` puis marche sur le chemin de sortie ;
## `cleared` au `ClearMark`, `departed` en fin de chemin.
func leave_along(path: Path3D, speed: float, clear_distance: float) -> void:
	state = State.LEAVING
	set_look_enabled(false)
	_set_walk_speed(speed)
	_playback.travel(&"leave")
	locomotion.follow(path, speed, 0.0, clear_distance, null, false)


func present_documents() -> void:
	set_look_enabled(false)
	_present_left = clip_length(&"present_documents")
	_playback.travel(&"present_documents")


## Durée nominale d'une étape (watchdogs du BoothDirector).
func remaining_walk_time() -> float:
	return locomotion.remaining_time()


func clip_length(clip: StringName) -> float:
	var anim: Animation = anim_player.get_animation(PassengerAnims.clip_path(clip))
	return anim.length if anim != null else 1.0


## Calage immédiat sur la fin du trajet courant (watchdog).
func force_finish_walk() -> void:
	locomotion.force_finish()


## Joue une réaction ; pendant la marche ou une autre réaction, elle est mise
## en file (1 max, la dernière gagne). RELIEVED : expression + hochement.
func play_reaction(kind: PassengerReaction.Kind) -> void:
	if state != State.AT_DESK or _reacting or locomotion.active:
		_pending_reaction = kind
		return
	_start_reaction(kind)


func has_pending_reaction() -> bool:
	return _pending_reaction >= 0 or _reacting


## Geste « retirer sa visière » (D-021) : l'apparence `after` est appliquée au
## repère `visor_off` du clip.
func remove_visor(after: PassengerAppearance) -> void:
	_visor_app = after
	if reduce_motion:
		_apply_visor_removed()
		return
	_fire_one_shot(&"remove_visor")
	_reacting = true
	_reaction_left = clip_length(&"remove_visor")
	_reaction_kind = PassengerReaction.Kind.SHRUG
	set_look_enabled(false)


func set_talking(talking: bool) -> void:
	anim_tree.set(&"parameters/TalkBlend/blend_amount", 1.0 if talking else 0.0)
	expression.set_talking(talking)


func set_expression(id: StringName, hold_sec: float = 0.0) -> void:
	expression.set_expression(id, hold_sec)


## Cible du regard (point monde), lissée.
func set_look_target(point: Vector3) -> void:
	_look_goal = point


func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled


func _set_walk_speed(speed: float) -> void:
	anim_tree.set(&"parameters/Main/walk/speed/scale", speed / PassengerAnims.walk_v_ref() / maxf(rig.leg_scale(), 0.01))


func _physics_process(delta: float) -> void:
	locomotion.physics_step(delta)


func _process(delta: float) -> void:
	_update_reaction(delta)
	_update_look(delta)


func _update_reaction(delta: float) -> void:
	if _reacting:
		_reaction_left -= delta
		if _reaction_left <= 0.0:
			_reacting = false
			if _visor_app != null:
				_apply_visor_removed()
			if state == State.AT_DESK:
				set_look_enabled(true)
			reaction_finished.emit(_reaction_kind)
	if not _reacting and _pending_reaction >= 0 and state == State.AT_DESK and not locomotion.active:
		var kind: PassengerReaction.Kind = _pending_reaction as PassengerReaction.Kind
		_pending_reaction = -1
		_start_reaction(kind)
	if _nod_left > 0.0:
		_nod_left = maxf(_nod_left - delta, 0.0)
	if _present_left > 0.0:
		_present_left -= delta
		if _present_left <= 0.0 and state == State.AT_DESK and not _reacting:
			set_look_enabled(true)


func _start_reaction(kind: PassengerReaction.Kind) -> void:
	_reaction_kind = kind
	expression.set_expression(REACTION_EXPRESSION[kind], 2.0)
	if kind == PassengerReaction.Kind.RELIEVED or reduce_motion:
		_nod_left = 0.0 if reduce_motion else NOD_SEC
		_reacting = true
		_reaction_left = NOD_SEC if not reduce_motion else 0.05
		return
	_fire_one_shot(REACTION_INPUT[kind])
	_reacting = true
	_reaction_left = clip_length(StringName(PassengerAnims.REACTION_INPUTS[REACTION_INPUT[kind]])) + REACTION_COOLDOWN_SEC
	set_look_enabled(false)


func _fire_one_shot(input: StringName) -> void:
	anim_tree.set(&"parameters/ReactionSelect/transition_request", String(input))
	anim_tree.set(&"parameters/Reaction/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _apply_visor_removed() -> void:
	if _visor_app != null:
		apply_appearance(_visor_app)
		_visor_app = null


## Regard (BOOTH_SCENE §9) : la cible est bornée ici (lacet ±40°, tangage
## −25°/+15° autour de l'avant du corps) puis confiée aux `LookAtModifier3D`
## (influence fondue sur 0,2 s) ; les pupilles finissent le mouvement (décalage
## UV de l'atlas) ; hochement procédural (RELIEVED) par décalage de la cible.
func _update_look(delta: float) -> void:
	var goal_weight: float = 1.0 if _look_enabled and state == State.AT_DESK else 0.0
	_look_weight = move_toward(_look_weight, goal_weight, delta / LOOK_FADE_SEC)
	rig.set_look_weight(_look_weight)
	var head: Vector3 = rig.head.global_position
	var body: Basis = global_basis.orthonormalized()
	var local: Vector3 = body.inverse() * (_look_goal - head)
	var horizontal: float = Vector2(local.x, local.z).length()
	var yaw: float = atan2(local.x, local.z)
	var pitch: float = -atan2(local.y, maxf(horizontal, 0.001))
	var clamped: Vector2 = Vector2(clampf(pitch, -LOOK_UP_LIMIT, LOOK_DOWN_LIMIT), clampf(yaw, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT))
	var wanted: Vector2 = clamped * _look_weight
	_look_angles = _look_angles.lerp(wanted, clampf(10.0 * delta, 0.0, 1.0))
	var nod: float = sin((1.0 - _nod_left / NOD_SEC) * TAU) * deg_to_rad(9.0) if _nod_left > 0.0 else 0.0
	# Direction bornée dans le repère du corps (+Z = avant, MODEL_FRONT ; tangage + = vers le bas).
	var p: float = clamped.x + nod
	var dir: Vector3 = Vector3(sin(clamped.y) * cos(p), -sin(p), cos(clamped.y) * cos(p))
	var goal: Vector3 = head + body * (dir * maxf(local.length(), 0.5))
	look_target.global_position = look_target.global_position.lerp(goal, clampf(LOOK_SMOOTH * delta, 0.0, 1.0))
	var residual: Vector2 = Vector2(clampf(yaw - clamped.y, -0.5, 0.5), clampf(pitch - clamped.x, -0.5, 0.5)) * _look_weight
	rig.face_material.set_shader_parameter(&"pupil_offset", Vector2(-residual.x * 0.03 - _look_angles.y * 0.04,
			residual.y * 0.03 + _look_angles.x * 0.03))


## Repères des clips (pistes « Call Method »).
func _on_anim_marker(marker: StringName) -> void:
	match marker:
		PassengerAnims.DOCUMENTS_SLOT:
			# Verrouillé une fois par cas (une piste de méthode peut se doubler).
			if _documents_slot_fired:
				return
			_documents_slot_fired = true
		&"papers_show":
			rig.papers.visible = true
		&"papers_hide":
			rig.papers.visible = false
		PassengerAnims.VISOR_OFF:
			_apply_visor_removed()
	anim_event.emit(marker)


## Émet `documents_slot` même si le repère n'a pas été joué (watchdog).
func force_documents_slot() -> void:
	_on_anim_marker(PassengerAnims.DOCUMENTS_SLOT)
	rig.papers.visible = false


func documents_slot_fired() -> bool:
	return _documents_slot_fired


func _on_locomotion_finished() -> void:
	if state == State.ARRIVING:
		state = State.AT_DESK
		_playback.travel(&"idle")
		set_look_enabled(true)
		arrived.emit()
	elif state == State.LEAVING:
		departed.emit()


func _on_clear_reached() -> void:
	if state == State.LEAVING:
		expression.paused = true
		cleared.emit()


func _on_head_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		face_clicked.emit()
