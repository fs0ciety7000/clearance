## Étape 2 du pipeline personnage M6 (ASSETS §5.2, BOOTH_SCENE §7.3, §10.1) :
## construit `res://assets/models/passenger/passenger_anims.res`, la bibliothèque
## `passenger` (9 clips du contrat) à partir des clips **Quaternius UAL**
## retargetés à l'import sur le profil `SkeletonProfileHumanoid` (cf.
## `build_passenger_bonemaps.gd`), appliqués au squelette **Kenney**.
##
## - Rééchantillonnage à 30 i/s, découpe, boucle ; seules les rotations des os
##   mappés (sans doigts) et la position de `Hips` sont gardées.
## - `Hips` : le squelette Kenney a un parent non mappé (`HipsCtrl`) ; son
##   décalage de repos est retiré des clés (normalisées par `motion_scale`).
## - Gestes absents d'UAL (présentation des papiers, colère, nervosité, haussement
##   d'épaules, retrait de visière) : **couches procédurales** en rotations
##   « espace personnage » (degrés) posées sur `Idle`, converties en rotations
##   locales par cinématique directe sur le vrai squelette Kenney.
## - Repères (« Call Method » → `PassengerActor._on_anim_marker`) : `footstep_l/r`
##   (détectés sur les contacts des pieds), `documents_slot` @0,75 s,
##   `papers_show/hide`, `glass_hit`, `visor_off`.
## - Métadonnée `walk_v_ref` : vitesse de référence (m/s, rig à l'échelle 1)
##   mesurée sur le pied d'appui → `speed_scale = v / v_ref`.
##
## Usage : `godot --headless --script res://tools/build_passenger_anims.gd`
## (après `build_passenger_bonemaps.gd` et `godot --headless --import`).
extends SceneTree

const UAL_PATH: String = "res://assets/models/passenger/anim_ual1_standard.glb"
const KENNEY_PATH: String = "res://assets/models/passenger/chr_kenney_medium.fbx"
const OUT_PATH: String = "res://assets/models/passenger/passenger_anims.res"
const FPS: float = 30.0
## Chemin des pistes, relatif à l'acteur (racine de l'AnimationPlayer).
const SKELETON_PATH: String = "Visual/Armature/Skeleton3D"
const MARKER_METHOD: StringName = &"_on_anim_marker"
## Échelle du squelette Kenney dans le rig (PassengerRig.BASE_SCALE).
const BASE_SCALE: float = 0.58

## Os conservés (profil humanoïde, sans doigts).
const BONES: Array[StringName] = [
	&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes",
]

var _skeleton: Skeleton3D = null
var _src: AnimationPlayer = null
var _hips_offset: Vector3 = Vector3.ZERO
## Correction de tangage de la tête (degrés), mesurée sur `Idle`.
var _head_fix: float = 0.0
## Pose courante (cinématique directe maison : le squelette hors boucle de rendu
## ne recalcule pas ses poses globales).
var _rot: Array[Quaternion] = []
var _pos: Array[Vector3] = []


func _initialize() -> void:
	var kenney: Node = (load(KENNEY_PATH) as PackedScene).instantiate()
	_skeleton = kenney.find_child("GeneralSkeleton", true, false) as Skeleton3D
	var ual: Node = (load(UAL_PATH) as PackedScene).instantiate()
	_src = ual.get_node("AnimationPlayer") as AnimationPlayer
	if _skeleton == null or _src == null:
		push_error("Sources introuvables (importer d'abord)")
		quit(1)
		return
	for bone: int in _skeleton.get_bone_count():
		_rot.append(_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		_pos.append(_skeleton.get_bone_rest(bone).origin)
	var ctrl: int = _skeleton.find_bone("HipsCtrl")
	if ctrl >= 0:
		_hips_offset = _skeleton.get_bone_global_rest(ctrl).origin / _skeleton.motion_scale

	_head_fix = _measure_head_pitch()
	var lib: AnimationLibrary = AnimationLibrary.new()
	var walk: Animation = _clip(&"Walk", 0.0, -1.0, true)
	var steps: Array = _footsteps(walk)
	_add_markers(walk, steps)
	lib.add_animation(&"walk", walk)
	lib.add_animation(&"idle", _clip(&"Idle", 0.0, -1.0, true))
	lib.add_animation(&"talk", _clip(&"Idle_Talking", 0.0, -1.0, true))
	var leave: Animation = _clip(&"Walk", 0.0, 0.8, false)
	var leave_steps: Array = []
	for step: Array in steps:
		var t: float = step[0]
		if t < 0.8:
			leave_steps.append(step)
	_add_markers(leave, leave_steps)
	lib.add_animation(&"leave", leave)
	lib.add_animation(&"present_documents", _layered(1.2, _present_layers(),
			[[0.3, &"papers_show"], [0.75, &"documents_slot"], [0.85, &"papers_hide"]]))
	lib.add_animation(&"react_angry", _layered(1.2, _angry_layers(), [[0.45, &"glass_hit"]]))
	lib.add_animation(&"react_nervous", _layered(1.3, _nervous_layers(), []))
	lib.add_animation(&"shrug", _layered(0.9, _shrug_layers(), []))
	lib.add_animation(&"remove_visor", _layered(1.1, _visor_layers(), [[0.55, &"visor_off"]]))

	var v_ref: float = _walk_v_ref(walk)
	lib.set_meta(&"walk_v_ref", v_ref)
	lib.set_meta(&"head_pitch_fix_deg", _head_fix)
	lib.set_meta(&"source", "Quaternius UAL1 Standard (CC0) retargeté sur Kenney characterMedium (CC0)")
	var err: Error = ResourceSaver.save(lib, OUT_PATH, ResourceSaver.FLAG_COMPRESS)
	print("passenger_anims.res : %d clips, walk_v_ref = %.3f m/s, tête redressée de %.1f°, pas = %s (%s)" % [
		lib.get_animation_list().size(), v_ref, _head_fix, str(steps), error_string(err)])
	for clip: StringName in lib.get_animation_list():
		var a: Animation = lib.get_animation(clip)
		print("  %-18s %.3f s  pistes=%d  boucle=%d" % [clip, a.length, a.get_track_count(), a.loop_mode])
	quit(0 if err == OK else 1)


# --- Clips rééchantillonnés --------------------------------------------------

## Copie [from, to] d'un clip UAL (to < 0 = fin), rééchantillonné à 30 i/s.
func _clip(src_name: StringName, from: float, to: float, loop: bool) -> Animation:
	var raw: Animation = _clip_raw(src_name, from, to, loop)
	if is_zero_approx(_head_fix):
		return raw
	var fix: Vector3 = Vector3(-_head_fix * 0.5, 0, 0)
	return _apply_layers(raw, {&"Neck": [[0.0, fix]], &"Head": [[0.0, fix]]})


func _clip_raw(src_name: StringName, from: float, to: float, loop: bool) -> Animation:
	var src: Animation = _src.get_animation(src_name)
	var end: float = src.length if to < 0.0 else minf(to, src.length)
	var length: float = end - from
	var frames: int = roundi(length * FPS)
	var anim: Animation = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for bone: StringName in BONES:
		var rot_src: int = src.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D)
		if rot_src >= 0:
			var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [SKELETON_PATH, bone]))
			for f: int in frames + 1:
				var time: float = minf(f / FPS, length)
				# Boucle : la dernière clé = la première (pas de saut).
				var at: float = from if loop and f == frames else from + time
				anim.rotation_track_insert_key(t, time, src.rotation_track_interpolate(rot_src, at))
		if bone == &"Hips":
			var pos_src: int = src.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
			if pos_src >= 0:
				var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
				anim.track_set_path(t, NodePath("%s:Hips" % SKELETON_PATH))
				for f: int in frames + 1:
					var time: float = minf(f / FPS, length)
					var at: float = from if loop and f == frames else from + time
					anim.position_track_insert_key(t, time, src.position_track_interpolate(pos_src, at) - _hips_offset)
	return anim


## Pose le squelette Kenney sur `anim` à l'instant t (rotations + Hips).
func _pose(anim: Animation, time: float) -> void:
	for bone: int in _skeleton.get_bone_count():
		_rot[bone] = _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		_pos[bone] = _skeleton.get_bone_rest(bone).origin
	for t: int in anim.get_track_count():
		var path: String = String(anim.track_get_path(t))
		if not path.begins_with(SKELETON_PATH + ":"):
			continue
		var bone: int = _skeleton.find_bone(path.get_slice(":", 1))
		if bone < 0:
			continue
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				_rot[bone] = anim.rotation_track_interpolate(t, time)
			Animation.TYPE_POSITION_3D:
				_pos[bone] = anim.position_track_interpolate(t, time) * _skeleton.motion_scale


func _bone_global(bone_name: StringName) -> Transform3D:
	return _global(_skeleton.find_bone(bone_name))


func _global(bone: int) -> Transform3D:
	if bone < 0:
		return Transform3D.IDENTITY
	var local: Transform3D = Transform3D(Basis(_rot[bone]), _pos[bone])
	return _global(_skeleton.get_bone_parent(bone)) * local


# --- Couches procédurales (gestes absents d'UAL) -----------------------------

## Clip = `Idle` (début) + couches. `layers` : {os: [[t, Vector3 degrés], …]}
## (rotation globale, espace personnage : +X = gauche du personnage, +Y = haut,
## +Z = avant ; X+ = pencher vers l'avant / baisser la tête).
func _layered(length: float, layers: Dictionary, markers: Array) -> Animation:
	var anim: Animation = _apply_layers(_clip(&"Idle", 0.0, length, false), layers)
	_add_markers(anim, markers)
	return anim


## Applique des couches de rotations globales (espace personnage) à une copie de `base`.
func _apply_layers(base: Animation, layers: Dictionary) -> Animation:
	var anim: Animation = base.duplicate(true)
	var order: Array[StringName] = []
	for bone: StringName in BONES:
		if layers.has(bone):
			order.append(bone)
	var length: float = base.length
	var frames: int = roundi(length * FPS)
	for f: int in frames + 1:
		var time: float = minf(f / FPS, length)
		_pose(base, time)
		for bone: StringName in order:
			var keys: Array = layers[bone]
			var deg: Vector3 = _sample(keys, time)
			if deg.is_zero_approx():
				continue
			var index: int = _skeleton.find_bone(bone)
			var global: Transform3D = _global(index)
			var parent_global: Transform3D = _global(_skeleton.get_bone_parent(index))
			var turned: Basis = Basis.from_euler(deg * PI / 180.0) * global.basis
			var local: Quaternion = (parent_global.basis.inverse() * turned).get_rotation_quaternion()
			_rot[index] = local
			var track: int = anim.find_track(NodePath("%s:%s" % [SKELETON_PATH, bone]), Animation.TYPE_ROTATION_3D)
			if track < 0:
				track = anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, bone]))
			var key: int = anim.track_find_key(track, time, Animation.FIND_MODE_APPROX)
			if key >= 0 and is_equal_approx(anim.track_get_key_time(track, key), time):
				anim.track_set_key_value(track, key, local)
			else:
				anim.rotation_track_insert_key(track, time, local)
	return anim


## Redressement du regard : le retarget UAL → Kenney laisse la tête penchée vers
## le bas (≈ 30° sur `Idle`) ; l'écart mesuré sur la 1ʳᵉ image d'`Idle` est
## compensé (moitié cou, moitié tête) sur **tous** les clips.
func _measure_head_pitch() -> float:
	_pose(_clip_raw(&"Idle", 0.0, 0.1, false), 0.0)
	var fwd: Vector3 = _bone_global(&"Head").basis.z.normalized()
	return rad_to_deg(asin(clampf(-fwd.y, -1.0, 1.0)))


## Interpolation douce (smoothstep) entre clés [t, Vector3].
static func _sample(keys: Array, time: float) -> Vector3:
	var first: Array = keys[0]
	var first_t: float = first[0]
	if time <= first_t:
		return first[1]
	for i: int in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		var ta: float = a[0]
		var tb: float = b[0]
		if time <= tb:
			var u: float = smoothstep(0.0, 1.0, (time - ta) / maxf(tb - ta, 0.0001))
			var va: Vector3 = a[1]
			var vb: Vector3 = b[1]
			return va.lerp(vb, u)
	var last: Array = keys[keys.size() - 1]
	return last[1]


## 0,00–0,40 main à la veste ; 0,40–0,75 penché, main vers la fente (sort du
## cadre par le bas) ; 0,75 = `documents_slot` ; 0,75–1,20 retour à `idle`.
func _present_layers() -> Dictionary:
	var z: Vector3 = Vector3.ZERO
	return {
		&"Spine": [[0.0, z], [0.4, Vector3(3, -6, 0)], [0.75, Vector3(9, 0, 0)], [1.2, z]],
		&"Chest": [[0.0, z], [0.75, Vector3(5, 0, 0)], [1.2, z]],
		&"Head": [[0.0, z], [0.75, Vector3(10, 0, 0)], [1.2, z]],
		&"RightUpperArm": [[0.0, z], [0.4, Vector3(-35, 0, 18)], [0.75, Vector3(-62, 0, 6)], [1.2, z]],
		&"RightLowerArm": [[0.0, z], [0.4, Vector3(-75, 0, 25)], [0.75, Vector3(-12, 0, 0)], [1.2, z]],
	}


## Buste en avant, deux mains sur le comptoir, secousse de tête ; `glass_hit` 0,45 s.
func _angry_layers() -> Dictionary:
	var z: Vector3 = Vector3.ZERO
	return {
		&"Spine": [[0.0, z], [0.3, Vector3(10, 0, 0)], [0.85, Vector3(8, 0, 0)], [1.2, z]],
		&"Head": [[0.0, z], [0.3, Vector3(-6, 0, 0)], [0.5, Vector3(-6, 9, 0)], [0.62, Vector3(-6, -9, 0)],
				[0.74, Vector3(-6, 7, 0)], [0.85, Vector3(-5, 0, 0)], [1.2, z]],
		&"RightUpperArm": [[0.0, z], [0.3, Vector3(-48, 0, -8)], [0.85, Vector3(-45, 0, -8)], [1.2, z]],
		&"RightLowerArm": [[0.0, z], [0.3, Vector3(-20, 0, 0)], [0.85, Vector3(-18, 0, 0)], [1.2, z]],
		&"LeftUpperArm": [[0.0, z], [0.3, Vector3(-48, 0, 8)], [0.85, Vector3(-45, 0, 8)], [1.2, z]],
		&"LeftLowerArm": [[0.0, z], [0.3, Vector3(-20, 0, 0)], [0.85, Vector3(-18, 0, 0)], [1.2, z]],
	}


## Regard fuyant, main à la nuque.
func _nervous_layers() -> Dictionary:
	var z: Vector3 = Vector3.ZERO
	return {
		&"Spine": [[0.0, z], [0.4, Vector3(-2, 6, 0)], [1.0, Vector3(-1, -4, 0)], [1.3, z]],
		&"Head": [[0.0, z], [0.3, Vector3(8, 24, 0)], [0.6, Vector3(10, -16, 0)], [0.95, Vector3(6, 20, 0)], [1.3, z]],
		&"RightUpperArm": [[0.0, z], [0.4, Vector3(-60, 0, -95)], [0.95, Vector3(-58, 0, -98)], [1.3, z]],
		&"RightLowerArm": [[0.0, z], [0.4, Vector3(-100, 0, -120)], [0.95, Vector3(-104, 0, -118)], [1.3, z]],
	}


## Haussement d'épaules : épaules hautes, avant-bras ouverts paumes en l'air.
func _shrug_layers() -> Dictionary:
	var z: Vector3 = Vector3.ZERO
	return {
		&"Head": [[0.0, z], [0.35, Vector3(0, 0, 9)], [0.9, z]],
		&"RightShoulder": [[0.0, z], [0.35, Vector3(0, 0, 14)], [0.9, z]],
		&"LeftShoulder": [[0.0, z], [0.35, Vector3(0, 0, -14)], [0.9, z]],
		&"RightLowerArm": [[0.0, z], [0.35, Vector3(-70, 0, -30)], [0.9, z]],
		&"LeftLowerArm": [[0.0, z], [0.35, Vector3(-70, 0, 30)], [0.9, z]],
		&"RightHand": [[0.0, z], [0.35, Vector3(0, 0, -60)], [0.9, z]],
		&"LeftHand": [[0.0, z], [0.35, Vector3(0, 0, 60)], [0.9, z]],
	}


## Main droite au front (0,45), visière relevée (0,55 = `visor_off`), retour.
func _visor_layers() -> Dictionary:
	var z: Vector3 = Vector3.ZERO
	return {
		&"Head": [[0.0, z], [0.45, Vector3(-4, 0, 0)], [0.65, Vector3(-9, 0, 0)], [1.1, z]],
		&"RightUpperArm": [[0.0, z], [0.45, Vector3(-120, 0, -25)], [0.65, Vector3(-138, 0, -22)], [1.1, z]],
		&"RightLowerArm": [[0.0, z], [0.45, Vector3(-150, 0, 35)], [0.65, Vector3(-160, 0, 25)], [1.1, z]],
	}


# --- Repères et mesures ------------------------------------------------------

func _add_markers(anim: Animation, markers: Array) -> void:
	if markers.is_empty():
		return
	var t: int = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t, ^".")
	for marker: Array in markers:
		var at: float = marker[0]
		anim.track_insert_key(t, at, {"method": MARKER_METHOD, "args": [marker[1]]})


## Contacts des pieds : instant où chaque pied est le plus en avant (attaque du talon).
func _footsteps(walk: Animation) -> Array:
	var best: Dictionary[StringName, Array] = {&"footstep_l": [0.0, -INF], &"footstep_r": [0.0, -INF]}
	var frames: int = roundi(walk.length * FPS)
	for f: int in frames:
		var time: float = f / FPS
		_pose(walk, time)
		for pair: Array in [[&"footstep_l", &"LeftFoot"], [&"footstep_r", &"RightFoot"]]:
			var foot: StringName = pair[1]
			var z: float = _bone_global(foot).origin.z
			var marker: StringName = pair[0]
			var entry: Array = best[marker]
			var best_z: float = entry[1]
			if z > best_z:
				best[marker] = [time, z]
	var result: Array = []
	for marker: StringName in best:
		var entry: Array = best[marker]
		var at: float = entry[0]
		result.append([snappedf(at, 1.0 / FPS), marker])
	result.sort_custom(func(a: Array, b: Array) -> bool:
		var ta: float = a[0]
		var tb: float = b[0]
		return ta < tb)
	return result


## Vitesse du pied d'appui (le plus bas) en milieu d'appui, à l'échelle du rig.
func _walk_v_ref(walk: Animation) -> float:
	var frames: int = roundi(walk.length * FPS)
	var total: float = 0.0
	var count: int = 0
	for f: int in frames:
		var t0: float = f / FPS
		var t1: float = t0 + 1.0 / FPS
		_pose(walk, t0)
		var l0: Vector3 = _bone_global(&"LeftFoot").origin
		var r0: Vector3 = _bone_global(&"RightFoot").origin
		_pose(walk, t1)
		var l1: Vector3 = _bone_global(&"LeftFoot").origin
		var r1: Vector3 = _bone_global(&"RightFoot").origin
		var stance: Array = [l0, l1] if l0.y < r0.y else [r0, r1]
		var a: Vector3 = stance[0]
		var b: Vector3 = stance[1]
		var dz: float = a.z - b.z # le pied d'appui recule
		if dz > 0.0:
			total += dz * FPS
			count += 1
	return total / maxf(count, 1) * BASE_SCALE
