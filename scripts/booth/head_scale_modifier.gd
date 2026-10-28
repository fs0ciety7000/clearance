## Modificateur de squelette (M6) : applique chaque frame, **après** l'animation,
## l'échelle de l'os `Head` du rig Kenney (tête « chibi » réduite × forme du
## visage, slot `face`). L'AnimationMixer réécrit la pose des os animés à chaque
## frame : une échelle posée une seule fois serait perdue. Premier modificateur
## du squelette (avant `NeckLook`/`HeadLook`).
class_name HeadScaleModifier
extends SkeletonModifier3D

var bone_name: StringName = &"Head"
var bone_scale: Vector3 = Vector3.ONE
## Raccourcit le cou : position de l'os = repos × facteur (la tête réduite
## laisserait sinon un cou d'une longueur « chibi »).
var neck_factor: float = 1.0

var _bone: int = -1


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	if _bone < 0:
		_bone = skeleton.find_bone(bone_name)
		if _bone < 0:
			return
	skeleton.set_bone_pose_scale(_bone, bone_scale)
	skeleton.set_bone_pose_position(_bone, skeleton.get_bone_rest(_bone).origin * neck_factor)
