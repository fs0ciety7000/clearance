## Fond flouté qui suit un panneau posé sur la vue 3D (bulle passager,
## compteurs) : le décor reste perceptible mais jamais lisible derrière le
## texte. Placé juste avant le panneau dans l'arbre, transparent aux clics.
class_name BlurBackdrop
extends ColorRect

const SHADER: Shader = preload("res://assets/shaders/ui_backdrop_blur.gdshader")

var target: Control = null


static func create(p_target: Control) -> BlurBackdrop:
	var backdrop: BlurBackdrop = BlurBackdrop.new()
	backdrop.target = p_target
	return backdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		visible = false
		return
	visible = target.is_visible_in_tree() and target.size != Vector2.ZERO
	global_position = target.global_position
	size = target.size
