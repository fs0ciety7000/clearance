## Seul pont EventBus ↔ 3D du guichet (ARCHITECTURE §8 bis.1).
##
## Pool de 2 `PassengerActor` (D-017) : sur `case_presented`, l'acteur libre est
## habillé et marche le long d'`ArrivalPath` jusqu'à `DeskMark` ; ses signaux
## locaux deviennent `passenger_arrived`, `documents_presented` (repère
## `documents_slot`) et `passenger_departed` (au `ClearMark` de la sortie),
## **une seule fois par `case_id`**. Réactions, retrait de visière, regard
## (projection souris sur `LookTargetPlane`), clic visage en Mode Inspection,
## travelling visage, watchdogs locaux par étape.
## Ne lit que `Case.case_id`, `Case.passenger_presented.appearance` et
## `CaseResult.verdict_kind` : ni clé, ni règles, ni score.
## M7 : implants visibles et fil magenta posés sur l'acteur
## (`Passenger.implants`, code 6), trois tapes sur la vitre avant les papiers
## (code 5 : ondes sur la vitre + `glass_knocked`), **escorte de la Garde de
## Continuité** pour une DÉTENTION (un 3ᵉ acteur, hors pool, uniforme gris et
## brassard jaune, entre par la porte de la station, encadre le passager puis
## repart avec lui vers l'Anneau B).
## M8 (Acte II) : accessoires des cas scénarisés (`PropDecor` : enfant, caisse
## du chat, drone, LED de shunt) ; grève du J20 : `lights_out()` éteint les
## lampes du guichet (la ville reste visible par la baie).
class_name BoothDirector
extends Node3D

## M7 : une tape du code 5 (`knock` = 1, 2, 3) — audio, tests.
signal glass_knocked(case_id: StringName, knock: int)
## M7 : la Garde entre pour escorter le passager détenu.
signal escort_started(case_id: StringName)
## M7 : la Garde a quitté le champ (fin de l'escorte).
signal escort_finished(case_id: StringName)

const ACTOR_SCENE: PackedScene = preload("res://scenes/passenger/passenger_actor.tscn")
const POOL_SIZE: int = 2

const WALK_SPEED: float = 1.15
const EXIT_APPROVED_SPEED: float = 1.2
const EXIT_REFUSED_SPEED: float = 1.0
## Réduire les animations (§8 bis.7) : marche ×2,5, départ à 70 % du chemin,
## sortie coupée après 1 s.
const REDUCED_SPEED_FACTOR: float = 2.5
const REDUCED_START_RATIO: float = 0.7
const REDUCED_EXIT_CUT_SEC: float = 1.0
const PRESENT_DELAY_SEC: float = 0.3
const WATCHDOG_MARGIN_SEC: float = 1.5
## Attente maximale de la fin d'une réaction avant `leave`.
const LEAVE_REACTION_WAIT_SEC: float = 1.6
const TALK_SEC: float = 1.4

## Rectangle de projection du regard dans le plan de la vitre (m, repère monde) :
## le bas descend jusqu'au comptoir (le passager baisse les yeux, BOOTH_SCENE §9.1).
const LOOK_X_LIMIT: float = 0.6
const LOOK_Y_MIN: float = 0.85
const LOOK_Y_MAX: float = 1.8
## Travelling visage (BOOTH_SCENE §3.4).
const BASE_FOV: float = 14.0
const FACE_FOV: float = 6.5
const FACE_DOLLY: float = 0.3
const ZOOM_IN_SEC: float = 0.4
const ZOOM_OUT_SEC: float = 0.3
## Cadreur automatique (BOOTH_SCENE §3.3) : tilt vers la tête, borné, lissé.
## Désactivé par défaut au M4 (retour Orchestrateur : caméra stable hors zoom visage).
const FRAMER_EYE_HEIGHT: float = 1.55
const FRAMER_DISTANCE: float = 2.6
const FRAMER_MAX_PITCH: float = deg_to_rad(2.5)
const FRAMER_SMOOTH: float = 2.5
## Vitre (quad centré) : pour le point dégagé autour du visage.
const GLASS_SIZE: Vector2 = Vector2(2.4, 1.4)
## Demi-taille du cadre « VISAGE » autour du centre de la tête (m).
const FACE_HALF_SIZE: Vector2 = Vector2(0.15, 0.17)
## Rayon de la zone cliquable « Visage » (généreuse, R17).
const FACE_PICK_RADIUS: float = 0.17

## M7 — code 5 : trois tapes sur la vitre avant `present_documents`.
const PRESENTATION_KNOCK: StringName = &"knock_three"
const MAGENTA_THREAD_TAG: StringName = &"magenta_thread"
const KNOCK_COUNT: int = 3
const KNOCK_INTERVAL_SEC: float = 0.34
const KNOCK_LEAD_SEC: float = 0.2
## Point d'impact sur la vitre (côté passager, hauteur de la main).
const KNOCK_POINT: Vector3 = Vector3(0.16, 1.4, -0.03)
## M7 — escorte de la Garde (DÉTENTION).
const GUARD_SPEED: float = 1.35
const GUARD_SPOT: Vector3 = Vector3(0.58, 0.0, -1.3)
const GUARD_ENTRY: Array[Vector3] = [Vector3(2.8, 0, 0.25), Vector3(2.3, 0, -0.45), Vector3(1.6, 0, -1.0), GUARD_SPOT]
const GUARD_EXIT: Array[Vector3] = [GUARD_SPOT, Vector3(1.6, 0, -1.05), Vector3(2.3, 0, -0.5), Vector3(2.9, 0, 0.3)]
## Le détenu attend la Garde au plus ce délai avant de partir.
const GUARD_WAIT_MAX_SEC: float = 4.0
const GUARD_FOLLOW_DELAY_SEC: float = 0.55

## Acte II — lumières coupées (grève du J20) : énergie résiduelle.
const LIGHTS_OUT_KEEP: float = 0.06
const LIGHTS_OUT_CITY: float = 0.35

const FLAG_ARRIVED: int = 1
const FLAG_DOCUMENTS: int = 2
const FLAG_DEPARTED: int = 4

## Active le cadreur automatique (tilt vers la tête pendant la marche).
@export var framer_enabled: bool = false

@onready var camera: Camera3D = %BoothCamera
@onready var arrival_path: Path3D = %ArrivalPath
@onready var desk_mark: Marker3D = %DeskMark
@onready var exit_approved_path: Path3D = %ExitApprovedPath
@onready var exit_refused_path: Path3D = %ExitRefusedPath
@onready var look_target_plane: Marker3D = %LookTargetPlane
@onready var passenger_slots: Node3D = %PassengerSlots
@onready var queue: QueueImpostors = %QueueImpostors
@onready var slot_glow: OmniLight3D = %SlotGlow
@onready var gate_light: OmniLight3D = %GateLight
@onready var glass: MeshInstance3D = %Glass

var actors: Array[PassengerActor] = []
var inspection_mode: bool = false
## M7 : acteur de la Garde (hors pool, jamais relié à l'EventBus).
var guard: PassengerActor = null
## Cas escorté (vide si aucune escorte en cours).
var escort_case_id: StringName = &""
## Acte II : lampes éteintes (grève du J20).
var lights_dimmed: bool = false

var _by_case: Dictionary[StringName, PassengerActor] = {}
var _cases: Dictionary[StringName, Case] = {}
var _emitted: Dictionary[StringName, int] = {}
## Acteur au guichet (ou en route vers lui).
var _desk_actor: PassengerActor = null
var _serial: int = 0
var _time: float = 0.0
## Watchdog par acteur : [étape, échéance].
var _watch: Dictionary[PassengerActor, Array] = {}
## Départs en attente de la fin d'une réaction : acteur → [chemin, vitesse, échéance].
var _pending_leave: Dictionary[PassengerActor, Array] = {}
var _cut_at: Dictionary[PassengerActor, float] = {}
var _talk_left: float = 0.0
var _face_zoom: bool = false
var _zoom: float = 0.0
var _framer_pitch: float = 0.0
var _camera_rest: Transform3D = Transform3D.IDENTITY
var _last_mouse: Vector2 = Vector2(-1, -1)
var _mouse_seen: bool = false
var _escort_actor: PassengerActor = null
var _guard_ready: bool = false
var _guard_follow_at: float = -1.0
var _guard_in_path: Path3D = null
var _guard_out_path: Path3D = null
var _guard_mark: Marker3D = null
## Minuteurs en attente (`SceneTreeTimer`, rappel) : déconnectés à la sortie
## de l'arbre (rechargement de scène en plein shift).
var _timers: Array[Array] = []


func _ready() -> void:
	_camera_rest = camera.transform
	for i: int in POOL_SIZE:
		var actor: PassengerActor = ACTOR_SCENE.instantiate()
		actor.name = "Passenger%s" % ["A", "B"][i]
		passenger_slots.add_child(actor)
		actor.arrived.connect(_on_actor_arrived.bind(actor))
		actor.anim_event.connect(_on_actor_anim_event.bind(actor))
		actor.cleared.connect(_on_actor_cleared.bind(actor))
		actor.departed.connect(_on_actor_departed.bind(actor))
		actor.face_clicked.connect(_on_actor_face_clicked.bind(actor))
		actors.append(actor)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.passenger_reaction_triggered.connect(_on_reaction_triggered)
	EventBus.interrogation_answered.connect(_on_interrogation_answered)
	EventBus.case_resolved.connect(_on_case_resolved)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)
	EventBus.inspection_target_picked.connect(_on_inspection_target_picked)
	EventBus.day_started.connect(_on_day_started)
	_build_guard()


## Sortie de l'arbre (`reload_current_scene`, retour au titre) : minuteurs
## annulés ; plus aucune émission tant que le booth n'est pas dans l'arbre
## (`_emit_once`, `_knock`), l'UI sœur étant déjà sortie.
func _exit_tree() -> void:
	for entry: Array in _timers:
		var timer: SceneTreeTimer = entry[0]
		var callback: Callable = entry[1]
		if is_instance_valid(timer) and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
	_timers.clear()


## `callback` dans `sec` secondes, annulé si le booth sort de l'arbre.
func _after(sec: float, callback: Callable) -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(sec)
	var entry: Array = [timer, callback]
	_timers.append(entry)
	timer.timeout.connect(func() -> void: _timers.erase(entry))
	timer.timeout.connect(callback)


## Acteur lié à un cas (tests, debug).
func get_actor(case_id: StringName) -> PassengerActor:
	return _by_case.get(case_id, null)


func get_desk_actor() -> PassengerActor:
	return _desk_actor


## Clic sur le visage (Mode Inspection) : rayon caméra ↔ sphère de la tête.
## Les événements souris arrivent du `SubViewportContainer` (coordonnées du
## viewport du booth) ; test géométrique plutôt que picking physique (fiable en
## headless et sans dépendre de la frame physique).
func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not inspection_mode or _desk_actor == null or _desk_actor.state != PassengerActor.State.AT_DESK:
		return
	if hits_face(click.position):
		get_viewport().set_input_as_handled()
		_desk_actor.face_clicked.emit()


## Vrai si le point écran (viewport du booth) vise la tête de l'acteur au guichet.
func hits_face(screen_pos: Vector2) -> bool:
	if _desk_actor == null:
		return false
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var head: Vector3 = _desk_actor.rig.head.global_position
	var along: float = (head - origin).dot(direction)
	var closest: Vector3 = origin + direction * maxf(along, 0.0)
	return closest.distance_to(head) <= FACE_PICK_RADIUS * _desk_actor.rig.scale.y


## Rectangle du visage de l'acteur au guichet, en pixels du viewport du booth
## (projection caméra ; tête à `DeskMark` si personne). Sert au cadre « VISAGE ».
func get_face_viewport_rect() -> Rect2:
	var head: Vector3 = desk_mark.global_position + Vector3(0, 1.62, 0)
	var scale_y: float = 1.0
	if _desk_actor != null and _desk_actor.visible:
		head = _desk_actor.rig.head.global_position
		scale_y = _desk_actor.rig.scale.y
	if camera.is_position_behind(head):
		return Rect2()
	var right: Vector3 = camera.global_basis.x
	var up: Vector3 = camera.global_basis.y
	var top_left: Vector2 = camera.unproject_position(head - right * FACE_HALF_SIZE.x * scale_y + up * FACE_HALF_SIZE.y * scale_y)
	var bottom_right: Vector2 = camera.unproject_position(head + right * FACE_HALF_SIZE.x * scale_y - up * FACE_HALF_SIZE.y * scale_y)
	return Rect2(top_left, bottom_right - top_left).abs()


# --- EventBus → 3D -----------------------------------------------------------

func _on_day_started(day: DayDef, _rulebook: Array[RulebookEntry]) -> void:
	queue.setup(SeededRng.mix(day.day_number, day.game_date))


func _on_case_presented(case: Case) -> void:
	if case == null or _by_case.has(case.case_id):
		return # idempotence
	var actor: PassengerActor = _take_actor()
	_serial += 1
	var reduce: bool = Settings.reduce_motion
	actor.reduce_motion = reduce
	actor.assign(case.case_id, _serial, SeededRng.hash_string(String(case.case_id)))
	actor.apply_appearance(case.passenger_presented.appearance)
	actor.apply_markings(case.passenger_presented.implants, has_magenta_thread(case))
	actor.apply_props(case.dialogue_tags)
	_by_case[case.case_id] = actor
	_cases[case.case_id] = case
	_desk_actor = actor
	var length: float = arrival_path.curve.get_baked_length()
	var speed: float = WALK_SPEED * (REDUCED_SPEED_FACTOR if reduce else 1.0)
	actor.walk_to_desk(arrival_path, speed, length * REDUCED_START_RATIO if reduce else 0.0, desk_mark)
	_arm_watchdog(actor, &"arrive", actor.remaining_walk_time())
	queue.hide_head()


func _on_reaction_triggered(reaction: PassengerReaction.Kind) -> void:
	if _desk_actor != null:
		_desk_actor.play_reaction(reaction)


func _on_interrogation_answered(topic: StringName, line_key: String) -> void:
	if _desk_actor == null:
		return
	_desk_actor.set_talking(true)
	_talk_left = TALK_SEC
	if topic == InspectionSession.TOPIC_REMOVE_VISOR and line_key != InspectionSession.LINE_VISOR_NONE:
		var case: Case = _cases.get(_desk_actor.case_id, null)
		if case != null:
			_desk_actor.remove_visor(case.passenger_presented.appearance)


func _on_case_resolved(case_id: StringName, result: CaseResult) -> void:
	var actor: PassengerActor = _by_case.get(case_id, null)
	_set_face_zoom(false)
	if actor == null or actor.state == PassengerActor.State.LEAVING or actor.is_free():
		return
	var approved: bool = result != null and result.verdict_kind == VerdictKind.Kind.APPROVE
	var detained: bool = result != null and result.verdict_kind == VerdictKind.Kind.DETAIN
	# Couleurs d'état de la palette active (vision des couleurs, D-107).
	_pulse_light(gate_light, Palette.STATE_GREEN if approved else (DS.ACCENT_YELLOW if detained else Palette.STATE_RED),
			0.8 if detained else 1.4, 1.2 if detained else 0.6)
	_pulse_light(slot_glow, DS.ACCENT_CYAN, 0.8, 0.4)
	if actor.state == PassengerActor.State.ARRIVING:
		actor.force_finish_walk() # tampon reçu avant l'arrivée (timeouts) : calage
	# Détention : sortie par la porte de la station (vers l'Anneau B), escortée.
	var path: Path3D = exit_approved_path if approved or detained else exit_refused_path
	var speed: float = EXIT_APPROVED_SPEED if approved else EXIT_REFUSED_SPEED
	if actor.reduce_motion:
		speed *= REDUCED_SPEED_FACTOR
	var wait: float = LEAVE_REACTION_WAIT_SEC
	if detained:
		start_escort(actor)
		wait = GUARD_WAIT_MAX_SEC
	_pending_leave[actor] = [path, speed, _time + wait]
	if not approved:
		actor.set_expression(&"sad")


func _on_inspection_mode_changed(enabled: bool) -> void:
	inspection_mode = enabled
	if not enabled:
		_set_face_zoom(false)


func _on_inspection_target_picked(ref: FieldRef) -> void:
	if ref != null and ref.is_passenger_face() and inspection_mode:
		_set_face_zoom(true)


# --- Acteurs → EventBus ------------------------------------------------------

func _on_actor_arrived(actor: PassengerActor) -> void:
	var case_id: StringName = actor.case_id
	_watch.erase(actor)
	if not is_inside_tree():
		return
	_emit_once(case_id, FLAG_ARRIVED)
	var delay: float = PRESENT_DELAY_SEC
	var case: Case = _cases.get(case_id, null)
	if case != null and case.presentation == PRESENTATION_KNOCK:
		# Code 5 : trois tapes sur la vitre, puis les papiers.
		for i: int in KNOCK_COUNT:
			_after(KNOCK_LEAD_SEC + KNOCK_INTERVAL_SEC * i, _knock.bind(actor, case_id, i + 1))
		delay += KNOCK_LEAD_SEC + KNOCK_INTERVAL_SEC * KNOCK_COUNT
	_after(delay, func() -> void:
		if is_inside_tree() and actor.case_id == case_id and actor.state == PassengerActor.State.AT_DESK and not actor.documents_slot_fired():
			actor.present_documents()
			_arm_watchdog(actor, &"present", actor.clip_length(&"present_documents")))


func _on_actor_anim_event(event_name: StringName, actor: PassengerActor) -> void:
	if event_name == PassengerAnims.DOCUMENTS_SLOT:
		_watch.erase(actor)
		_pulse_light(slot_glow, DS.ACCENT_CYAN, 0.8, 0.4)
		_emit_once(actor.case_id, FLAG_DOCUMENTS)


func _on_actor_cleared(actor: PassengerActor) -> void:
	_watch.erase(actor)
	_emit_once(actor.case_id, FLAG_DEPARTED)


func _on_actor_departed(actor: PassengerActor) -> void:
	_emit_once(actor.case_id, FLAG_DEPARTED)
	_release(actor)


func _on_actor_face_clicked(actor: PassengerActor) -> void:
	if inspection_mode and actor == _desk_actor and actor.state == PassengerActor.State.AT_DESK:
		EventBus.inspection_target_picked.emit(FieldRef.passenger_face())


## Émet un signal du booth une seule fois par cas, dans l'ordre du contrat.
## Hors de l'arbre (scène en cours de rechargement) : rien n'est émis.
func _emit_once(case_id: StringName, flag: int) -> void:
	if case_id == &"" or not is_inside_tree():
		return
	var flags: int = _emitted.get(case_id, 0)
	if (flags & flag) != 0:
		return
	_emitted[case_id] = flags | flag
	match flag:
		FLAG_ARRIVED:
			EventBus.passenger_arrived.emit(case_id)
		FLAG_DOCUMENTS:
			if (flags & FLAG_ARRIVED) == 0:
				_emit_once(case_id, FLAG_ARRIVED)
			EventBus.documents_presented.emit(case_id)
		FLAG_DEPARTED:
			if _desk_actor != null and _desk_actor.case_id == case_id:
				_desk_actor = null
			queue.advance()
			EventBus.passenger_departed.emit(case_id)


# --- Pool --------------------------------------------------------------------

func _take_actor() -> PassengerActor:
	for actor: PassengerActor in actors:
		if actor.is_free():
			return actor
	# Aucun libre (sortant bloqué) : le plus ancien est caché de force.
	var oldest: PassengerActor = actors[0]
	for actor: PassengerActor in actors:
		if actor.assigned_serial < oldest.assigned_serial:
			oldest = actor
	push_warning("BoothDirector: pool plein, %s libéré de force" % oldest.case_id)
	_emit_once(oldest.case_id, FLAG_DEPARTED)
	_release(oldest)
	return oldest


func _release(actor: PassengerActor) -> void:
	_watch.erase(actor)
	_pending_leave.erase(actor)
	_cut_at.erase(actor)
	if actor.case_id != &"":
		_by_case.erase(actor.case_id)
		_cases.erase(actor.case_id)
	if _desk_actor == actor:
		_desk_actor = null
	actor.release()


# --- M7 : codes Lucioles, escorte de la Garde --------------------------------

## Code 6 : fil magenta au poignet (`magenta_thread`).
static func has_magenta_thread(case: Case) -> bool:
	return case != null and (case.dialogue_tags.has(MAGENTA_THREAD_TAG) or case.luciole_codes.has(6))


## Une tape sur la vitre : onde (anneau cyan pâle qui s'élargit et s'efface).
func _knock(actor: PassengerActor, case_id: StringName, knock: int) -> void:
	if not is_inside_tree() or actor.case_id != case_id or actor.state != PassengerActor.State.AT_DESK:
		return
	glass_knocked.emit(case_id, knock)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "KnockRipple%d" % knock
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.028
	torus.outer_radius = 0.034
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(GreyboxStyle.WORLD_KEY, 0.55 * Settings.fx_intensity)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = glass.global_position * Vector3(0, 0, 1) + KNOCK_POINT + Vector3(0.012 * (knock - 2), 0.01 * (knock % 2), 0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	if Settings.reduce_motion:
		_after(DS.DUR_SLOW, ring.queue_free)
		return
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, ^"scale", Vector3.ONE * 3.2, DS.DUR_SLOW + DS.DUR_FAST).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, ^"albedo_color:a", 0.0, DS.DUR_SLOW + DS.DUR_FAST)
	tween.chain().tween_callback(ring.queue_free)


## Acteur de la Garde (uniforme gris, visière baissée, brassard jaune) et
## chemins d'entrée / de sortie par la porte de la station.
func _build_guard() -> void:
	guard = ACTOR_SCENE.instantiate()
	guard.name = "GuardEscort"
	passenger_slots.add_child(guard)
	guard.collision_layer = 0
	guard.collision_mask = 0
	guard.arrived.connect(_on_guard_arrived)
	guard.departed.connect(_on_guard_departed)
	guard.release()
	_guard_in_path = _make_path("GuardInPath", GUARD_ENTRY)
	_guard_out_path = _make_path("GuardOutPath", GUARD_EXIT)
	_guard_mark = Marker3D.new()
	_guard_mark.name = "GuardMark"
	add_child(_guard_mark)
	_guard_mark.position = GUARD_SPOT
	_guard_mark.basis = Basis.looking_at(Vector3(-0.55, 0, 0.75).normalized(), Vector3.UP, true)


func _make_path(node_name: String, points: Array[Vector3]) -> Path3D:
	var path: Path3D = Path3D.new()
	path.name = node_name
	var curve: Curve3D = Curve3D.new()
	for point: Vector3 in points:
		curve.add_point(point)
	path.curve = curve
	add_child(path)
	return path


## Apparence de la Garde de Continuité (NARRATIVE §8.3 : uniforme gris, brassard jaune).
static func guard_appearance() -> PassengerAppearance:
	var traits: Dictionary[StringName, StringName] = {
		&"silhouette": &"silhouette_s1_stocky", &"face": &"face_square_e2", &"eyes": &"eyes_grey",
		&"nose_mouth": &"nose_mouth_n2_l1", &"skin": &"skin_04", &"hair": &"hair_shaved_c01",
		&"headwear": &"visor_down", &"outfit": &"outfit_06", &"accessory": &"none", &"palette": &"palette_11",
	}
	return PassengerAppearance.new(traits, 1)


## Lance l'escorte du passager détenu (idempotent par cas).
func start_escort(actor: PassengerActor) -> void:
	if actor == null or guard == null:
		return
	if not guard.is_free():
		guard.release()
	escort_case_id = actor.case_id
	_escort_actor = actor
	_guard_ready = false
	_guard_follow_at = -1.0
	guard.reduce_motion = actor.reduce_motion
	guard.assign(&"guard", 0, SeededRng.hash_string("guard"))
	guard.apply_appearance(guard_appearance())
	guard.apply_markings(PackedStringArray(), false)
	_add_armband(guard)
	var length: float = _guard_in_path.curve.get_baked_length()
	var speed: float = GUARD_SPEED * (REDUCED_SPEED_FACTOR if actor.reduce_motion else 1.0)
	guard.walk_to_desk(_guard_in_path, speed, length * 0.85 if actor.reduce_motion else 0.0, _guard_mark)
	escort_started.emit(escort_case_id)


func is_escorting() -> bool:
	return escort_case_id != &""


## Brassard jaune Consortium au bras gauche (os `LeftUpperArm`).
func _add_armband(actor: PassengerActor) -> void:
	var skeleton: Skeleton3D = actor.rig.skeleton
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(^"ArmbandAttachment") as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = "ArmbandAttachment"
		attachment.bone_name = "LeftUpperArm"
		skeleton.add_child(attachment)
		var space: Node3D = Node3D.new()
		space.name = "Space"
		attachment.add_child(space)
		var band: TorusMesh = TorusMesh.new()
		band.inner_radius = 0.05
		band.outer_radius = 0.068
		band.rings = 16
		band.ring_segments = 6
		var mat: ShaderMaterial = actor.rig.make_material(DS.ACCENT_YELLOW.darkened(0.25), 0.5)
		mat.set_shader_parameter(&"emission_color", DS.ACCENT_YELLOW * 0.35)
		actor.rig.add_mesh(space, "Armband", band, mat, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.0, 1.6, 1.0))
	var meter: Node3D = attachment.get_node(^"Space") as Node3D
	meter.scale = Vector3.ONE / actor.rig.armature.scale
	# M10 : le brassard rejoint les pièces fusionnées de l'acteur.
	actor.rig.queue_parts_rebuild()


func _on_guard_arrived() -> void:
	_guard_ready = true
	guard.set_look_enabled(false)


func _on_guard_departed() -> void:
	var case_id: StringName = escort_case_id
	escort_case_id = &""
	_escort_actor = null
	_guard_follow_at = -1.0
	guard.release()
	escort_finished.emit(case_id)


func _process_guard() -> void:
	if guard == null or guard.is_free():
		return
	if _escort_actor != null and is_instance_valid(_escort_actor) and _escort_actor.visible:
		guard.set_look_target(_escort_actor.rig.head.global_position)
	if _guard_follow_at >= 0.0 and _time >= _guard_follow_at and guard.state == PassengerActor.State.AT_DESK:
		_guard_follow_at = -1.0
		guard.leave_along(_guard_out_path, EXIT_APPROVED_SPEED * (REDUCED_SPEED_FACTOR if guard.reduce_motion else 1.0), -1.0)


func _start_leave(actor: PassengerActor, path: Path3D, speed: float) -> void:
	var clear_mark: Node3D = path.get_node_or_null(^"ClearMark")
	var clear_distance: float = -1.0
	if clear_mark != null:
		clear_distance = path.curve.get_closest_offset(path.to_local(clear_mark.global_position))
	actor.leave_along(path, speed, clear_distance)
	var to_clear: float = (clear_distance if clear_distance >= 0.0 else path.curve.get_baked_length()) / speed
	_arm_watchdog(actor, &"clear", to_clear + actor.clip_length(&"leave"))
	if actor.reduce_motion:
		_cut_at[actor] = _time + REDUCED_EXIT_CUT_SEC


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_process_watchdogs()
	_process_leaves()
	_process_guard()
	if _talk_left > 0.0:
		_talk_left -= delta
		if _talk_left <= 0.0 and _desk_actor != null:
			_desk_actor.set_talking(false)
	_update_look()
	_update_camera(delta)
	_update_glass()


func _arm_watchdog(actor: PassengerActor, step: StringName, expected_sec: float) -> void:
	_watch[actor] = [step, _time + expected_sec + WATCHDOG_MARGIN_SEC]


func _process_watchdogs() -> void:
	for actor: PassengerActor in _watch.keys():
		var entry: Array = _watch[actor]
		var deadline: float = entry[1]
		if _time < deadline:
			continue
		var step: StringName = entry[0]
		_watch.erase(actor)
		push_warning("BoothDirector: watchdog « %s » (%s)" % [step, actor.case_id])
		match step:
			&"arrive":
				actor.force_finish_walk()
			&"present":
				actor.force_documents_slot()
			&"clear":
				_emit_once(actor.case_id, FLAG_DEPARTED)
				_release(actor)
	for actor: PassengerActor in _cut_at.keys():
		if _time >= _cut_at[actor]:
			_emit_once(actor.case_id, FLAG_DEPARTED)
			_release(actor)


func _process_leaves() -> void:
	for actor: PassengerActor in _pending_leave.keys():
		var entry: Array = _pending_leave[actor]
		var wait_until: float = entry[2]
		var waiting_guard: bool = actor == _escort_actor and not _guard_ready
		if (actor.has_pending_reaction() or waiting_guard) and _time < wait_until:
			continue
		if actor == _escort_actor:
			_guard_follow_at = _time + GUARD_FOLLOW_DELAY_SEC
		_pending_leave.erase(actor)
		var path: Path3D = entry[0]
		var speed: float = entry[1]
		_start_leave(actor, path, speed)


## Regard : souris projetée sur le plan de la vitre (bornée), sinon la caméra.
func _update_look() -> void:
	if _desk_actor == null:
		return
	var target: Vector3 = camera.global_position
	var mouse: Vector2 = _booth_mouse_position()
	if mouse != _last_mouse:
		_mouse_seen = _last_mouse.x >= 0.0 or _mouse_seen
		_last_mouse = mouse
	if _mouse_seen and not _face_zoom:
		var origin: Vector3 = camera.project_ray_origin(mouse)
		var direction: Vector3 = camera.project_ray_normal(mouse)
		var plane: Plane = Plane(look_target_plane.global_basis.z, look_target_plane.global_position)
		var hit: Variant = plane.intersects_ray(origin, direction)
		if hit == null:
			# Rayon parallèle ou derrière : on vise le comptoir.
			target = Vector3(clampf(origin.x, -LOOK_X_LIMIT, LOOK_X_LIMIT), LOOK_Y_MIN, look_target_plane.global_position.z)
		else:
			var point: Vector3 = hit
			target = Vector3(clampf(point.x, -LOOK_X_LIMIT, LOOK_X_LIMIT), clampf(point.y, LOOK_Y_MIN, LOOK_Y_MAX), point.z)
	_desk_actor.set_look_target(target)


## Position de la souris dans la bande 3D (SubViewport sous un
## SubViewportContainer : conversion depuis la fenêtre, même hors de la bande).
func _booth_mouse_position() -> Vector2:
	var vp: Viewport = get_viewport()
	var sub: SubViewport = vp as SubViewport
	if sub != null:
		var container: SubViewportContainer = sub.get_parent() as SubViewportContainer
		if container != null and container.size.x > 0.0 and container.size.y > 0.0:
			var root_mouse: Vector2 = container.get_viewport().get_mouse_position()
			var local: Vector2 = container.get_global_transform_with_canvas().affine_inverse() * root_mouse
			return local * Vector2(sub.size) / container.size
	return vp.get_mouse_position()


func _set_face_zoom(enabled: bool) -> void:
	_face_zoom = enabled
	if Settings.reduce_motion:
		_zoom = 1.0 if enabled else 0.0


func _update_camera(delta: float) -> void:
	var goal: float = 1.0 if _face_zoom else 0.0
	var rate: float = 1.0 / (ZOOM_IN_SEC if _face_zoom else ZOOM_OUT_SEC)
	_zoom = move_toward(_zoom, goal, delta * rate)
	var t: float = ease(_zoom, -2.0)
	camera.fov = lerpf(BASE_FOV, FACE_FOV, t)
	if framer_enabled and _desk_actor != null and _desk_actor.visible \
			and _desk_actor.state == PassengerActor.State.ARRIVING:
		var head_y: float = _desk_actor.rig.head.global_position.y
		var wanted: float = clampf(atan((head_y - FRAMER_EYE_HEIGHT) / FRAMER_DISTANCE), -FRAMER_MAX_PITCH, FRAMER_MAX_PITCH)
		if Settings.reduce_motion:
			_framer_pitch = wanted
		else:
			_framer_pitch = lerpf(_framer_pitch, wanted, clampf(FRAMER_SMOOTH * delta, 0.0, 1.0))
	var rest: Transform3D = Transform3D(_camera_rest.basis * Basis(Vector3.RIGHT, _framer_pitch), _camera_rest.origin)
	if t <= 0.0 or _desk_actor == null:
		camera.transform = rest
		return
	var head: Vector3 = _desk_actor.rig.head.global_position
	var parent_inv: Transform3D = camera.get_parent_node_3d().global_transform.affine_inverse()
	var head_local: Vector3 = parent_inv * head
	var dolly: Vector3 = rest.origin + Vector3(0, 0, -FACE_DOLLY)
	var aimed: Transform3D = Transform3D(Basis.looking_at(head_local - dolly, Vector3.UP), dolly)
	camera.transform = rest.interpolate_with(aimed, t)


## Point dégagé de la vitre : intersection caméra → tête avec le plan de la vitre.
func _update_glass() -> void:
	var mat: ShaderMaterial = glass.material_override as ShaderMaterial
	if mat == null:
		return
	var head: Vector3 = desk_mark.global_position + Vector3(0, 1.62, 0)
	if _desk_actor != null and _desk_actor.visible:
		head = _desk_actor.rig.head.global_position
	var from: Vector3 = camera.global_position
	var dir: Vector3 = head - from
	if absf(dir.z) < 0.0001:
		return
	var t: float = (glass.global_position.z - from.z) / dir.z
	var p: Vector3 = from + dir * t - glass.global_position
	var uv: Vector2 = Vector2(p.x / GLASS_SIZE.x + 0.5, 0.5 - p.y / GLASS_SIZE.y)
	mat.set_shader_parameter(&"clear_point", uv)
	mat.set_shader_parameter(&"fx_intensity", Settings.fx_intensity)


## Acte II — grève du J20 (« les vitres s'éteignent ») : fondu des lampes du
## guichet et du Hall vers 6 % de leur énergie ; la lumière de la ville
## (`HalcyonSpill`) garde 35 %. Propriétés de nœuds seulement (rien de partagé
## n'est modifié : la scène suivante repart éclairée).
func lights_out(duration: float) -> void:
	lights_dimmed = true
	var lights_root: Node = get_node_or_null(^"Lights")
	if lights_root == null:
		return
	for child: Node in lights_root.get_children():
		var light: Light3D = child as Light3D
		if light == null:
			continue
		var keep: float = LIGHTS_OUT_CITY if light.name == &"HalcyonSpill" else LIGHTS_OUT_KEEP
		var tween: Tween = create_tween()
		tween.tween_property(light, ^"light_energy", light.light_energy * keep, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE)


func _pulse_light(light: OmniLight3D, color: Color, energy: float, duration: float) -> void:
	if light == null:
		return
	light.light_color = color
	light.light_energy = energy * (LIGHTS_OUT_KEEP if lights_dimmed else 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(light, ^"light_energy", 0.0, duration).set_ease(Tween.EASE_IN)
