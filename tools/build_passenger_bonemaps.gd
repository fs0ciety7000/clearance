## Étape 1 du pipeline personnage M6 (ASSETS §5.1–§5.2, §8) : écrit les deux
## `BoneMap` (profil **`SkeletonProfileHumanoid`** commun) utilisés par les
## réglages d'import (`*.import`, `_subresources` → `retarget/bone_map`) :
## - `bonemap_kenney.tres` : squelette Kenney Animated Characters (`characterMedium`) ;
## - `bonemap_ual.tres` : squelette Quaternius UAL (convention Unreal).
## Après retarget, les deux squelettes portent les **noms du profil** (`Hips`,
## `Neck`, `Head`, `LeftUpperArm`…) et des repos normalisés : les clips UAL
## s'appliquent tels quels au modèle Kenney.
##
## Usage : `godot --headless --script res://tools/build_passenger_bonemaps.gd`
## puis `godot --headless --import` (les `.import` référencent ces fichiers).
extends SceneTree

const DIR: String = "res://assets/models/passenger"

## Profil humanoïde → os Kenney (pas d'os racine : `HipsCtrl` n'est pas mappé).
const KENNEY: Dictionary[StringName, StringName] = {
	&"Hips": &"Hips", &"Spine": &"Spine", &"Chest": &"Chest", &"UpperChest": &"UpperChest",
	&"Neck": &"Neck", &"Head": &"Head",
	&"LeftShoulder": &"LeftShoulder", &"LeftUpperArm": &"LeftArm", &"LeftLowerArm": &"LeftForeArm",
	&"LeftHand": &"LeftHand",
	&"LeftThumbProximal": &"LeftHandThumb1", &"LeftThumbDistal": &"LeftHandThumb2",
	&"LeftIndexProximal": &"LeftHandIndex1", &"LeftIndexIntermediate": &"LeftHandIndex2",
	&"LeftIndexDistal": &"LeftHandIndex3",
	&"RightShoulder": &"RightShoulder", &"RightUpperArm": &"RightArm", &"RightLowerArm": &"RightForeArm",
	&"RightHand": &"RightHand",
	&"RightThumbProximal": &"RightHandThumb1", &"RightThumbDistal": &"RightHandThumb2",
	&"RightIndexProximal": &"RightHandIndex1", &"RightIndexIntermediate": &"RightHandIndex2",
	&"RightIndexDistal": &"RightHandIndex3",
	&"LeftUpperLeg": &"LeftUpLeg", &"LeftLowerLeg": &"LeftLeg", &"LeftFoot": &"LeftFoot", &"LeftToes": &"LeftToes",
	&"RightUpperLeg": &"RightUpLeg", &"RightLowerLeg": &"RightLeg", &"RightFoot": &"RightFoot",
	&"RightToes": &"RightToes",
}

## Profil humanoïde → os UAL (doigts complets ; inutilisés en jeu mais mappés
## pour que « Remove Unmapped Bones » ne laisse pas de pistes orphelines).
const UAL: Dictionary[StringName, StringName] = {
	&"Root": &"root", &"Hips": &"pelvis", &"Spine": &"spine_01", &"Chest": &"spine_02", &"UpperChest": &"spine_03",
	&"Neck": &"neck_01", &"Head": &"Head",
	&"LeftShoulder": &"clavicle_l", &"LeftUpperArm": &"upperarm_l", &"LeftLowerArm": &"lowerarm_l",
	&"LeftHand": &"hand_l",
	&"RightShoulder": &"clavicle_r", &"RightUpperArm": &"upperarm_r", &"RightLowerArm": &"lowerarm_r",
	&"RightHand": &"hand_r",
	&"LeftUpperLeg": &"thigh_l", &"LeftLowerLeg": &"calf_l", &"LeftFoot": &"foot_l", &"LeftToes": &"ball_l",
	&"RightUpperLeg": &"thigh_r", &"RightLowerLeg": &"calf_r", &"RightFoot": &"foot_r", &"RightToes": &"ball_r",
}
const UAL_FINGERS: Dictionary[String, String] = {
	"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Little": "pinky",
}


func _initialize() -> void:
	var ual: Dictionary[StringName, StringName] = UAL.duplicate()
	for side: String in ["Left", "Right"]:
		var s: String = "l" if side == "Left" else "r"
		for finger: String in UAL_FINGERS:
			var segments: PackedStringArray = PackedStringArray(["Metacarpal", "Proximal", "Distal"]) \
					if finger == "Thumb" else PackedStringArray(["Proximal", "Intermediate", "Distal"])
			for i: int in 3:
				ual[StringName(side + finger + segments[i])] = StringName("%s_%02d_%s" % [UAL_FINGERS[finger], i + 1, s])
	var ok: bool = _save(KENNEY, "bonemap_kenney.tres") and _save(ual, "bonemap_ual.tres")
	quit(0 if ok else 1)


func _save(mapping: Dictionary[StringName, StringName], file: String) -> bool:
	var map: BoneMap = BoneMap.new()
	map.profile = SkeletonProfileHumanoid.new()
	for profile_bone: StringName in mapping:
		if map.profile.find_bone(profile_bone) < 0:
			push_error("Os de profil inconnu : %s" % profile_bone)
			return false
		map.set_skeleton_bone_name(profile_bone, mapping[profile_bone])
	var err: Error = ResourceSaver.save(map, "%s/%s" % [DIR, file])
	print("%s : %d os mappés (%s)" % [file, mapping.size(), error_string(err)])
	return err == OK
