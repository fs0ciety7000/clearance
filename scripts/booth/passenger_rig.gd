## Rig **placeholder** du passager (ARCHITECTURE §8 bis.2, BOOTH_SCENE §14) :
## capsules et primitives, sans squelette. Remplacé en M6 par le rig Kenney.
##
## Construit sa hiérarchie à l'instanciation ; les noms de nœuds sont ceux que
## visent les clips placeholder (`PlaceholderAnims`) :
## `Body` (bassin) › `ArmL`/`ArmR` (épaules) › `Neck` › `HeadLook` (regard,
## piloté par script) › `Head` (crâne, plaque visage, cheveux, coiffe, `HeadArea`).
## Les pièces variables (cheveux, coiffe, accessoires, détails de tenue) sont
## reconstruites par `AppearanceApplier` dans les conteneurs dédiés.
class_name PassengerRig
extends Node3D

const BODY_SHADER: Shader = preload("res://assets/shaders/passenger_body.gdshader")
const FACE_SHADER: Shader = preload("res://assets/shaders/face_dither.gdshader")

## Hauteur des hanches (pivot de `Body`).
const HIP_Y: float = 0.88
## Couche de collision du clic « Visage » (BOOTH_SCENE : HeadArea).
const FACE_PICK_LAYER: int = 1 << 3

var body: Node3D = null
var torso: MeshInstance3D = null
var arm_l: Node3D = null
var arm_r: Node3D = null
var neck: Node3D = null
var head_look: Node3D = null
var head: Node3D = null
var skull: MeshInstance3D = null
var jaw: MeshInstance3D = null
var ear_l: MeshInstance3D = null
var ear_r: MeshInstance3D = null
var nose: MeshInstance3D = null
var face: MeshInstance3D = null
var head_area: Area3D = null
## Liasse de papiers dans la main droite (visible pendant `present_documents`).
var papers: MeshInstance3D = null
var legs: Array[MeshInstance3D] = []
var arm_meshes: Array[MeshInstance3D] = []
var hands: Array[MeshInstance3D] = []
var neck_mesh: MeshInstance3D = null
# Conteneurs reconstruits à chaque apparence.
var hair_root: Node3D = null
var headwear_root: Node3D = null
var head_accessory_root: Node3D = null
var neck_wear_root: Node3D = null
var outfit_root: Node3D = null

var face_material: ShaderMaterial = null
## Matériaux partagés au sein du rig (un jeu par acteur, jamais entre acteurs).
var skin_material: ShaderMaterial = null
var top_material: ShaderMaterial = null
var bottom_material: ShaderMaterial = null
## Rim néon (désactivé pour le studio portrait).
var rim_enabled: bool = true


func _init() -> void:
	_build()


## Matériau de pièce (couleur unie + rim bicolore).
func make_material(color: Color, roughness: float = 0.75, metallic: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BODY_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"roughness", roughness)
	mat.set_shader_parameter(&"metallic", metallic)
	mat.set_shader_parameter(&"rim_left", GreyboxStyle.WORLD_TEAL_DIM)
	mat.set_shader_parameter(&"rim_right", GreyboxStyle.WORLD_ROSE_DIM)
	mat.set_shader_parameter(&"rim_strength", 0.7 if rim_enabled else 0.0)
	return mat


## Ajoute un maillage sous `parent`.
func add_mesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi, true)
	return mi


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 6
	return m


static func sphere(radius: float, height: float = -1.0, hemisphere: bool = false) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = height if height > 0.0 else radius * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 24
	m.rings = 12
	return m


static func box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	return m


## Vide un conteneur de pièces variables.
static func clear(container: Node3D) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build() -> void:
	skin_material = make_material(GreyboxStyle.SKINS[&"skin_03"], 0.65)
	top_material = make_material(GreyboxStyle.PALETTES[0][0])
	bottom_material = make_material(GreyboxStyle.PALETTES[0][1])

	for side: float in [-1.0, 1.0]:
		legs.append(add_mesh(self, "LegL" if side < 0.0 else "LegR", capsule(0.075, HIP_Y + 0.02), bottom_material,
				Vector3(0.09 * side, (HIP_Y + 0.02) * 0.5, 0.0)))

	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, HIP_Y, 0)
	add_child(body)
	torso = add_mesh(body, "Torso", capsule(0.19, 0.64), top_material, Vector3(0, 0.27, 0), Vector3.ZERO,
			Vector3(1.0, 1.0, 0.72))
	outfit_root = _container(body, "Outfit")
	neck_wear_root = _container(body, "NeckWear")

	arm_l = _arm("ArmL", -1.0)
	arm_r = _arm("ArmR", 1.0)
	papers = add_mesh(arm_r, "Papers", box(Vector3(0.10, 0.012, 0.14)), make_material(Color("#C9D3D8"), 0.5),
			Vector3(0.0, -0.62, 0.05), Vector3(10, 0, 0))
	papers.visible = false

	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.55, 0)
	body.add_child(neck)
	neck_mesh = add_mesh(neck, "NeckMesh", cylinder(0.048, 0.055, 0.12), skin_material, Vector3(0, 0.05, 0))

	head_look = Node3D.new()
	head_look.name = "HeadLook"
	head_look.position = Vector3(0, 0.07, 0)
	neck.add_child(head_look)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.12, 0.0)
	head_look.add_child(head)

	skull = add_mesh(head, "Skull", sphere(0.115, 0.26), skin_material)
	jaw = add_mesh(head, "Jaw", box(Vector3(0.19, 0.08, 0.16)), skin_material, Vector3(0, -0.075, 0.0))
	ear_l = add_mesh(head, "EarL", sphere(0.03), skin_material, Vector3(-0.112, 0.0, -0.005))
	ear_r = add_mesh(head, "EarR", sphere(0.03), skin_material, Vector3(0.112, 0.0, -0.005))
	nose = add_mesh(head, "Nose", box(Vector3(0.03, 0.05, 0.04)), skin_material, Vector3(0, -0.012, 0.112))

	var face_mesh: QuadMesh = QuadMesh.new()
	face_mesh.size = Vector2(0.165, 0.2)
	face_mesh.subdivide_width = 8
	face_mesh.subdivide_depth = 8
	face_material = ShaderMaterial.new()
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter(&"atlas", FaceAtlas.get_texture())
	face = add_mesh(head, "Face", face_mesh, face_material, Vector3(0, -0.01, 0.12))
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	hair_root = _container(head, "Hair")
	headwear_root = _container(head, "Headwear")
	head_accessory_root = _container(head, "HeadAccessory")

	head_area = Area3D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = FACE_PICK_LAYER
	head_area.collision_mask = 0
	head_area.monitoring = false
	head_area.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.17
	shape.shape = sphere_shape
	head_area.add_child(shape)
	head.add_child(head_area)


func _container(parent: Node3D, node_name: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


func _arm(node_name: String, side: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(0.235 * side, 0.5, 0)
	pivot.rotation_degrees = Vector3(0, 0, 6.0 * side)
	body.add_child(pivot)
	arm_meshes.append(add_mesh(pivot, "ArmMesh", capsule(0.055, 0.62), top_material, Vector3(0, -0.29, 0)))
	hands.append(add_mesh(pivot, "Hand", sphere(0.045), skin_material, Vector3(0, -0.6, 0.0)))
	return pivot


## Rim néon on/off (studio portrait : off).
func set_rim_enabled(enabled: bool) -> void:
	rim_enabled = enabled
