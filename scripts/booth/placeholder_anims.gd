## Clips et `AnimationTree` **placeholder** du passager (ARCHITECTURE §8 bis.3,
## BOOTH_SCENE §10.1, §14) — générés par code, sur le rig capsule.
##
## Bibliothèque `passenger` : `walk`, `idle`, `present_documents`, `leave`,
## `react_angry`, `react_nervous`, `shrug`, `talk` (+ `remove_visor`, D-021).
## Marqueurs (pistes « Call Method » vers `PassengerActor._on_anim_marker`) :
## `footstep_l/r`, `documents_slot` (0,75 s de `present_documents`),
## `papers_show/hide`, `glass_hit`, `visor_off`.
## En M6, `assets/models/passenger/passenger_anims.res` (clips Quaternius UAL
## retargetés) remplace la bibliothèque ; l'arbre et les noms ne changent pas.
class_name PlaceholderAnims
extends RefCounted

const LIBRARY_NAME: StringName = &"passenger"
const LIBRARY_PATH: String = "res://assets/models/passenger/passenger_anims.res"
const CLIPS: Array[StringName] = [
	&"walk", &"idle", &"present_documents", &"leave", &"react_angry", &"react_nervous", &"shrug", &"talk",
	&"remove_visor",
]
const MARKER_METHOD: StringName = &"_on_anim_marker"
const DOCUMENTS_SLOT: StringName = &"documents_slot"
const DOCUMENTS_SLOT_TIME: float = 0.75
const VISOR_OFF: StringName = &"visor_off"
const WALK_CYCLE: float = 1.05

# Pistes animées (chemins relatifs à l'acteur).
const BODY: NodePath = ^"Visual/Body"
const ARM_L: NodePath = ^"Visual/Body/ArmL"
const ARM_R: NodePath = ^"Visual/Body/ArmR"
const NECK: NodePath = ^"Visual/Body/Neck"

const HIP_Y: float = 0.88
const ARM_REST_Z: float = 6.0

## Entrée de `ReactionSelect` (Transition) → clip.
const REACTION_INPUTS: Dictionary[StringName, StringName] = {
	&"angry": &"react_angry",
	&"nervous": &"react_nervous",
	&"shrug": &"shrug",
	&"remove_visor": &"remove_visor",
}


## Bibliothèque du passager : fichier importé s'il existe (M6), sinon placeholder.
static func load_library() -> AnimationLibrary:
	if ResourceLoader.exists(LIBRARY_PATH):
		var lib: AnimationLibrary = load(LIBRARY_PATH)
		if lib != null:
			return lib
	return build_library()


static func build_library() -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(&"walk", _walk())
	lib.add_animation(&"idle", _idle())
	lib.add_animation(&"present_documents", _present_documents())
	lib.add_animation(&"leave", _leave())
	lib.add_animation(&"react_angry", _react_angry())
	lib.add_animation(&"react_nervous", _react_nervous())
	lib.add_animation(&"shrug", _shrug())
	lib.add_animation(&"talk", _talk())
	lib.add_animation(&"remove_visor", _remove_visor())
	return lib


static func clip_path(clip: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY_NAME, clip])


## Arbre (ARCHITECTURE §8 bis.3) :
## `Main (StateMachine) → TalkBlend (Blend2, filtre cou) → Reaction (OneShot ← ReactionSelect) → Output`.
static func build_tree() -> AnimationNodeBlendTree:
	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()

	var main: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	var walk_tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	walk_tree.add_node(&"anim", _anim_node(&"walk"), Vector2(0, 0))
	walk_tree.add_node(&"speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	walk_tree.connect_node(&"speed", 0, &"anim")
	walk_tree.connect_node(&"output", 0, &"speed")
	main.add_node(&"walk", walk_tree, Vector2(200, 0))
	main.add_node(&"idle", _anim_node(&"idle"), Vector2(200, 150))
	main.add_node(&"present_documents", _anim_node(&"present_documents"), Vector2(450, 150))
	main.add_node(&"leave", _anim_node(&"leave"), Vector2(450, 0))
	main.add_transition(&"Start", &"idle", _transition(0.0, true, false))
	main.add_transition(&"idle", &"walk", _transition(0.25, false, false))
	main.add_transition(&"walk", &"idle", _transition(0.25, false, false))
	main.add_transition(&"idle", &"present_documents", _transition(0.10, false, false))
	main.add_transition(&"present_documents", &"idle", _transition(0.25, true, true))
	main.add_transition(&"idle", &"leave", _transition(0.10, false, false))
	main.add_transition(&"present_documents", &"leave", _transition(0.10, false, false))
	main.add_transition(&"leave", &"walk", _transition(0.20, true, true))
	main.add_transition(&"walk", &"leave", _transition(0.10, false, false))

	var talk_blend: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	talk_blend.filter_enabled = true
	talk_blend.set_filter_path(NECK, true)

	var select: AnimationNodeTransition = AnimationNodeTransition.new()
	select.input_count = REACTION_INPUTS.size()
	var i: int = 0
	for input: StringName in REACTION_INPUTS:
		select.set_input_name(i, input)
		i += 1
	select.xfade_time = 0.0

	var one_shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	one_shot.fadein_time = 0.10
	one_shot.fadeout_time = 0.25

	root.add_node(&"Main", main, Vector2(0, 0))
	root.add_node(&"talk", _anim_node(&"talk"), Vector2(0, 200))
	root.add_node(&"TalkBlend", talk_blend, Vector2(250, 0))
	i = 0
	for input: StringName in REACTION_INPUTS:
		var node_name: StringName = StringName("clip_%s" % input)
		root.add_node(node_name, _anim_node(REACTION_INPUTS[input]), Vector2(250, 300 + i * 100))
		i += 1
	root.add_node(&"ReactionSelect", select, Vector2(500, 300))
	root.add_node(&"Reaction", one_shot, Vector2(750, 0))
	root.connect_node(&"TalkBlend", 0, &"Main")
	root.connect_node(&"TalkBlend", 1, &"talk")
	i = 0
	for input: StringName in REACTION_INPUTS:
		root.connect_node(&"ReactionSelect", i, StringName("clip_%s" % input))
		i += 1
	root.connect_node(&"Reaction", 0, &"TalkBlend")
	root.connect_node(&"Reaction", 1, &"ReactionSelect")
	root.connect_node(&"output", 0, &"Reaction")
	return root


static func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip_path(clip)
	return node


static func _transition(xfade: float, at_end: bool, auto: bool) -> AnimationNodeStateMachineTransition:
	var t: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END if at_end \
			else AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if auto \
			else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	return t


# --- Construction des clips --------------------------------------------------

## Clip à partir de clés par piste : `{piste: [[t, valeur], …]}`. Les pistes
## absentes sont posées au repos (début et fin) pour des fondus propres.
## Rotations en degrés (Vector3 d'Euler), position du bassin en mètres.
static func _clip(length: float, loop: bool, keys: Dictionary, markers: Array = []) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var body_pos: Array = keys.get(&"body_pos", [[0.0, 0.0], [length, 0.0]])
	var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, BODY)
	for k: Array in body_pos:
		var time: float = k[0]
		var dy: float = k[1]
		anim.position_track_insert_key(t, time, Vector3(0, HIP_Y + dy, 0))
	var tracks: Array[Array] = [[BODY, &"body", Vector3.ZERO], [ARM_L, &"arm_l", Vector3(0, 0, -ARM_REST_Z)],
			[ARM_R, &"arm_r", Vector3(0, 0, ARM_REST_Z)], [NECK, &"neck", Vector3.ZERO]]
	for track: Array in tracks:
		var track_keys: Array = keys.get(track[1], [])
		var path: NodePath = track[0]
		var rest: Vector3 = track[2]
		_rotation_track(anim, path, track_keys, rest)
	if not markers.is_empty():
		var m: int = anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(m, ^".")
		for marker: Array in markers:
			var at: float = marker[0]
			anim.track_insert_key(m, at, {"method": MARKER_METHOD, "args": [marker[1]]})
	return anim


static func _rotation_track(anim: Animation, path: NodePath, keys: Array, rest_deg: Vector3) -> void:
	var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, path)
	var list: Array = keys
	if list.is_empty():
		list = [[0.0, Vector3.ZERO], [anim.length, Vector3.ZERO]]
	for k: Array in list:
		var time: float = k[0]
		var deg: Vector3 = k[1]
		anim.rotation_track_insert_key(t, time, Basis.from_euler((deg + rest_deg) * PI / 180.0).get_rotation_quaternion())


static func _walk() -> Animation:
	var c: float = WALK_CYCLE
	var h: float = c * 0.5
	var q: float = c * 0.25
	return _clip(c, true, {
		&"body_pos": [[0.0, 0.0], [q, 0.022], [h, 0.0], [h + q, 0.022], [c, 0.0]],
		&"body": [[0.0, Vector3(3, 0, 0)], [q, Vector3(3, 2, 1.5)], [h, Vector3(3, 0, 0)], [h + q, Vector3(3, -2, -1.5)],
				[c, Vector3(3, 0, 0)]],
		&"arm_l": [[0.0, Vector3(20, 0, 0)], [h, Vector3(-20, 0, 0)], [c, Vector3(20, 0, 0)]],
		&"arm_r": [[0.0, Vector3(-20, 0, 0)], [h, Vector3(20, 0, 0)], [c, Vector3(-20, 0, 0)]],
		&"neck": [[0.0, Vector3(-2, 0, 0)], [c, Vector3(-2, 0, 0)]],
	}, [[0.0, &"footstep_l"], [h, &"footstep_r"]])


static func _idle() -> Animation:
	return _clip(6.0, true, {
		&"body_pos": [[0.0, 0.0], [1.6, 0.006], [3.0, 0.0], [4.6, 0.006], [6.0, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [3.0, Vector3(0.5, 0, 0.9)], [6.0, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [3.0, Vector3(2, 0, -1)], [6.0, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [3.0, Vector3(1, 0, 1)], [6.0, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [2.0, Vector3(1.5, 0, 0)], [4.5, Vector3(0, 0, -1)], [6.0, Vector3.ZERO]],
	})


## 0,00–0,40 main dans la veste ; 0,40–0,75 se penche, main vers la fente ;
## 0,75 = `documents_slot` ; 0,75–1,20 retrait (BOOTH_SCENE §7.2).
static func _present_documents() -> Animation:
	return _clip(1.2, false, {
		&"body_pos": [[0.0, 0.0], [0.75, -0.02], [1.2, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.4, Vector3(3, -4, 0)], [0.75, Vector3(13, 0, 0)], [1.2, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [0.75, Vector3(-8, 0, 0)], [1.2, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.4, Vector3(-35, 0, -25)], [0.75, Vector3(-70, 0, -8)], [1.2, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [0.75, Vector3(14, 0, 0)], [1.2, Vector3.ZERO]],
	}, [[0.3, &"papers_show"], [DOCUMENTS_SLOT_TIME, DOCUMENTS_SLOT], [0.85, &"papers_hide"]])


static func _leave() -> Animation:
	return _clip(0.8, false, {
		&"body_pos": [[0.0, 0.0], [0.4, 0.02], [0.8, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.4, Vector3(4, 0, 0)], [0.8, Vector3(3, 0, 0)]],
		&"arm_l": [[0.0, Vector3.ZERO], [0.8, Vector3(20, 0, 0)]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.8, Vector3(-20, 0, 0)]],
		&"neck": [[0.0, Vector3.ZERO], [0.8, Vector3(6, 0, 0)]],
	}, [[0.2, &"footstep_l"], [0.7, &"footstep_r"]])


static func _react_angry() -> Animation:
	return _clip(1.2, false, {
		&"body_pos": [[0.0, 0.0], [0.25, -0.015], [1.2, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.25, Vector3(11, 0, 0)], [0.85, Vector3(9, 0, 0)], [1.2, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [0.3, Vector3(-48, 0, 12)], [0.85, Vector3(-45, 0, 12)], [1.2, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.3, Vector3(-48, 0, -12)], [0.85, Vector3(-45, 0, -12)], [1.2, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [0.45, Vector3(-6, 0, 0)], [0.55, Vector3(-6, 7, 0)], [0.65, Vector3(-6, -7, 0)],
				[0.75, Vector3(-6, 6, 0)], [0.85, Vector3(-6, 0, 0)], [1.2, Vector3.ZERO]],
	}, [[0.45, &"glass_hit"]])


static func _react_nervous() -> Animation:
	return _clip(1.3, false, {
		&"body_pos": [[0.0, 0.0], [0.4, -0.012], [1.3, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.4, Vector3(-2, 6, 0)], [1.0, Vector3(-1, -4, 0)], [1.3, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [1.3, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.4, Vector3(-120, 0, -35)], [0.95, Vector3(-115, 0, -38)], [1.3, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [0.3, Vector3(6, 22, 0)], [0.6, Vector3(8, -14, 0)], [0.9, Vector3(5, 18, 0)],
				[1.3, Vector3.ZERO]],
	})


static func _shrug() -> Animation:
	return _clip(0.9, false, {
		&"body_pos": [[0.0, 0.0], [0.35, 0.025], [0.9, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.9, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [0.35, Vector3(-20, 0, -22)], [0.9, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.35, Vector3(-20, 0, 22)], [0.9, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [0.35, Vector3(0, 0, 9)], [0.9, Vector3.ZERO]],
	})


static func _talk() -> Animation:
	return _clip(2.0, true, {
		&"neck": [[0.0, Vector3.ZERO], [0.5, Vector3(3, 2, 0)], [1.0, Vector3(-1, 0, 0)], [1.5, Vector3(2, -2, 0)],
				[2.0, Vector3.ZERO]],
	})


## Retrait de la visière (D-021) : main à la tête, visière relevée à 0,55 s.
static func _remove_visor() -> Animation:
	return _clip(1.1, false, {
		&"body_pos": [[0.0, 0.0], [1.1, 0.0]],
		&"body": [[0.0, Vector3.ZERO], [0.5, Vector3(-2, 0, 0)], [1.1, Vector3.ZERO]],
		&"arm_l": [[0.0, Vector3.ZERO], [1.1, Vector3.ZERO]],
		&"arm_r": [[0.0, Vector3.ZERO], [0.45, Vector3(-158, 0, -28)], [0.65, Vector3(-165, 0, -20)], [1.1, Vector3.ZERO]],
		&"neck": [[0.0, Vector3.ZERO], [0.5, Vector3(-8, 0, 0)], [1.1, Vector3.ZERO]],
	}, [[0.55, VISOR_OFF]])
