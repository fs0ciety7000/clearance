## Contrat d'animation du passager (ARCHITECTURE §8 bis.3, BOOTH_SCENE §7.3, §10.1).
##
## Bibliothèque `passenger` = `res://assets/models/passenger/passenger_anims.res`,
## produite par `tools/build_passenger_anims.gd` (clips Quaternius UAL retargetés
## sur le squelette Kenney, M6) : `walk`, `idle`, `present_documents`, `leave`,
## `react_angry`, `react_nervous`, `shrug`, `talk` (+ `remove_visor`, D-021).
## Marqueurs (pistes « Call Method » vers `PassengerActor._on_anim_marker`) :
## `footstep_l/r`, `documents_slot` (0,75 s de `present_documents`),
## `papers_show/hide`, `glass_hit`, `visor_off`.
## Si le fichier manque (clone sans import), une bibliothèque **de secours**
## (clips vides aux durées nominales, mêmes marqueurs) garde le flux de jeu intact.
class_name PassengerAnims
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
## Vitesse de référence de `walk` (m/s, rig à l'échelle 1) si la métadonnée manque.
const DEFAULT_WALK_V_REF: float = 0.65
const SKELETON_PATH: String = "Visual/Armature/Skeleton3D"
## Os du haut du corps : filtre de la couche `talk` (colonne + bras + tête).
const UPPER_BODY: Array[StringName] = [
	&"Spine", &"Chest", &"UpperChest", &"Neck", &"Head", &"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm",
	&"LeftHand", &"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
]

## Entrée de `ReactionSelect` (Transition) → clip.
const REACTION_INPUTS: Dictionary[StringName, StringName] = {
	&"angry": &"react_angry",
	&"nervous": &"react_nervous",
	&"shrug": &"shrug",
	&"remove_visor": &"remove_visor",
}

static var _library: AnimationLibrary = null


## Bibliothèque partagée par tous les acteurs (chargée une fois).
static func load_library() -> AnimationLibrary:
	if _library != null:
		return _library
	if ResourceLoader.exists(LIBRARY_PATH):
		_library = load(LIBRARY_PATH) as AnimationLibrary
	if _library == null:
		push_warning("PassengerAnims: %s absent, bibliothèque de secours" % LIBRARY_PATH)
		_library = build_fallback()
	return _library


static func walk_v_ref() -> float:
	var v_ref: float = load_library().get_meta(&"walk_v_ref", DEFAULT_WALK_V_REF)
	return v_ref


static func clip_path(clip: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY_NAME, clip])


## Clips sans pistes d'os, aux durées nominales, avec les marqueurs du contrat.
static func build_fallback() -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	var specs: Dictionary[StringName, Array] = {
		&"walk": [1.05, true, [[0.0, &"footstep_l"], [0.525, &"footstep_r"]]],
		&"idle": [2.5, true, []],
		&"present_documents": [1.2, false, [[0.3, &"papers_show"], [DOCUMENTS_SLOT_TIME, DOCUMENTS_SLOT],
				[0.85, &"papers_hide"]]],
		&"leave": [0.8, false, [[0.2, &"footstep_l"], [0.7, &"footstep_r"]]],
		&"react_angry": [1.2, false, [[0.45, &"glass_hit"]]],
		&"react_nervous": [1.3, false, []],
		&"shrug": [0.9, false, []],
		&"talk": [2.0, true, []],
		&"remove_visor": [1.1, false, [[0.55, VISOR_OFF]]],
	}
	for clip: StringName in specs:
		var spec: Array = specs[clip]
		var anim: Animation = Animation.new()
		anim.length = spec[0]
		var loop: bool = spec[1]
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		var markers: Array = spec[2]
		if not markers.is_empty():
			var t: int = anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(t, ^".")
			for marker: Array in markers:
				var at: float = marker[0]
				anim.track_insert_key(t, at, {"method": MARKER_METHOD, "args": [marker[1]]})
		lib.add_animation(clip, anim)
	return lib


## Arbre (ARCHITECTURE §8 bis.3) :
## `Main (StateMachine) → TalkBlend (Blend2, filtre haut du corps) → Reaction (OneShot ← ReactionSelect) → Output`.
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
	for bone: StringName in UPPER_BODY:
		talk_blend.set_filter_path(NodePath("%s:%s" % [SKELETON_PATH, bone]), true)

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
