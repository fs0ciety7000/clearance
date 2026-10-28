## Rig du passager **final** (M6, ARCHITECTURE §8 bis.2, BOOTH_SCENE §12–§13).
##
## Modèle Kenney Animated Characters (`characterMedium`, CC0, 1 604 triangles)
## retargeté sur le profil `SkeletonProfileHumanoid` (os `Hips`, `Neck`, `Head`…),
## animé par la bibliothèque `passenger` (clips Quaternius UAL ; choix de rig : ASSETS §5.4).
##
## ```
## Visual (PassengerRig)            échelle uniforme = taille (±3 % par pas)
## └── Armature                     échelle = BASE_SCALE × silhouette
##     └── Skeleton3D               squelette Kenney (pistes « Visual/Armature/Skeleton3D:Os »)
##         ├── Body (MeshInstance3D)       chr_toon.gdshader, carte de zones de la tenue
##         ├── HeadAttachment → Head (repère en mètres, centre de la tête)
##         │   └── Face, Nose, EarL/R, Hair, Headwear, HeadAccessory, HeadArea
##         ├── NeckAttachment → NeckWear     ChestAttachment → Outfit
##         ├── HandAttachment → Papers
##         ├── Parts (MeshInstance3D)      M10 : pièces fusionnées, skinnées (chr_parts.gdshader)
##         └── NeckLook / HeadLook (LookAtModifier3D, D-010)
## ```
## Les repères « en mètres » (`Head`, `NeckWear`, `Outfit`, `Papers`) annulent
## l'échelle du squelette : les pièces d'apparence sont modélisées en mètres.
## La forme de la tête (slot `face`) et sa taille passent par l'échelle de l'os
## `Head` (les pièces de tête suivent). Les pièces variables sont reconstruites
## par `AppearanceApplier` dans les conteneurs dédiés.
##
## M10 (BOOTH_SCENE §18, D-075 proposée) : les pièces restent des nœuds **sources**
## (noms stables, tests, débogage) mais ne sont pas rendues : `rebuild_parts()`
## les fusionne en **un seul maillage skinné** (`Parts`, un matériau
## `chr_parts.gdshader`, une liaison d'os par repère), mis en cache par
## signature. Un acteur = 2 instances (corps + pièces), + 1 seulement pour la
## demi-visière translucide. Toute modification de pièces est suivie de
## `queue_parts_rebuild()` (différé, une fois par image) ou `rebuild_parts()`.
class_name PassengerRig
extends Node3D

const MODEL: PackedScene = preload("res://assets/models/passenger/chr_kenney_medium.fbx")
const BODY_SHADER: Shader = preload("res://assets/shaders/chr_toon.gdshader")
const PART_SHADER: Shader = preload("res://assets/shaders/passenger_body.gdshader")
const FACE_SHADER: Shader = preload("res://assets/shaders/face_dither.gdshader")
const PARTS_SHADER: Shader = preload("res://assets/shaders/chr_parts.gdshader")
const ZONES_DIR: String = "res://assets/textures/passenger/tex_chr_zones_%s.png"

## Kenney mesure ≈ 3,7 unités : ramené à ≈ 1,78 m (tête réduite comprise, centre de tête ≈ 1,62 m).
const BASE_SCALE: float = 0.58
## Tête Kenney (« chibi ») réduite pour des proportions adultes stylisées.
const HEAD_SCALE: float = 0.45
## Longueur du cou conservée (os `Head` rapproché de `Neck`).
const NECK_FACTOR: float = 0.55
## Boîte de la tête dans l'espace de l'os `Head` (unités Kenney, mesurée sur le maillage).
const HEAD_BOX_CENTER: Vector3 = Vector3(0.0, 0.489, -0.019)
const HEAD_BOX_SIZE: Vector3 = Vector3(0.878, 1.157, 1.048)
## Haut du torse (os `UpperChest`) : demi-largeur et avant du buste (unités Kenney).
const CHEST_HALF_WIDTH: float = 0.35
const CHEST_FRONT: float = 0.26
## Couche de collision du clic « Visage » (BOOTH_SCENE : HeadArea).
const FACE_PICK_LAYER: int = 1 << 3
## Galbe de la plaque visage (VERTEX.z -= k · r²), cuit dans le maillage fusionné.
const FACE_CURVATURE: float = 1.2
## Mode de rendu d'une pièce fusionnée (CUSTOM0.a, `chr_parts.gdshader`).
enum PartMode { SOLID = 0, FACE = 1, UNSHADED = 2, PAPERS = 3 }
## Maillages fusionnés gardés en cache (acteur et portrait d'une même apparence).
const PARTS_CACHE_MAX: int = 48
const PARTS_FORMAT: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

## Fusion des pièces (défaut). `false` : chaque pièce rendue seule (rendu de
## référence M6, comparaisons avant/après) ; lu à la construction du rig.
static var merge_parts: bool = true

var armature: Node3D = null
var skeleton: Skeleton3D = null
var body_mesh: MeshInstance3D = null
## Centre de la tête, repère en mètres (regard, clic visage, zoom, portrait).
var head: Node3D = null
var face: MeshInstance3D = null
var nose: MeshInstance3D = null
var ear_l: MeshInstance3D = null
var ear_r: MeshInstance3D = null
var head_area: Area3D = null
## Liasse de papiers dans la main droite (pièce source ; affichée pendant
## `present_documents` par `set_papers_visible`).
var papers: MeshInstance3D = null
## Pièces fusionnées (M10) : enfant du squelette, skinné, `parts_material`.
var parts_mesh: MeshInstance3D = null
var parts_material: ShaderMaterial = null
var papers_visible: bool = false
var neck_look: LookAtModifier3D = null
var head_look: LookAtModifier3D = null
# Conteneurs reconstruits à chaque apparence.
var hair_root: Node3D = null
var headwear_root: Node3D = null
var head_accessory_root: Node3D = null
var neck_wear_root: Node3D = null
var outfit_root: Node3D = null
## M7 : implants visibles et fil magenta (`ImplantDecor`), hors apparence :
## jamais effacés par `AppearanceApplier` (retrait de visière compris).
var implants_head: Node3D = null
var implants_neck: Node3D = null
var implants_hand: Node3D = null
## Repère en mètres de la main droite (papiers, prothèse, poignet).
var hand_space: Node3D = null

var body_material: ShaderMaterial = null
## Uniformes du visage (expressions, regard, iris) : `parts_material` quand
## les pièces sont fusionnées, sinon le matériau de la plaque seule.
var face_material: ShaderMaterial = null
## Matériau des pièces couleur peau (nez, oreilles).
var skin_material: ShaderMaterial = null
## Rim néon (désactivé pour le studio portrait).
var rim_enabled: bool = true
## Échelle de l'os `Head` (forme du visage × réduction), réappliquée chaque frame
## après l'animation par `HeadScaleModifier`.
var head_bone_scale: Vector3 = Vector3.ONE * HEAD_SCALE

var head_scaler: HeadScaleModifier = null
var _meter_spaces: Array[Node3D] = []
var _head_bone: int = -1
var _merge: bool = true
var _parts_dirty: bool = false
var _parts_key: String = ""
static var _zone_cache: Dictionary[String, Texture2D] = {}
## Signature des pièces → [ArrayMesh, Skin].
static var _parts_cache: Dictionary[String, Array] = {}


func _init() -> void:
	_build()


## Matériau de pièce (couleur unie + rim bicolore).
func make_material(color: Color, roughness: float = 0.75, metallic: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PART_SHADER
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
	m.radial_segments = 12
	m.rings = 4
	return m


static func sphere(radius: float, height: float = -1.0, hemisphere: bool = false) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = height if height > 0.0 else radius * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 16
	m.rings = 8
	return m


static func box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, height: float, segments: int = 12) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


## Vide un conteneur de pièces variables.
static func clear(container: Node3D) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Demi-dimensions de la tête en mètres (avant réduction par la forme du visage).
static func head_half_size() -> Vector3:
	return HEAD_BOX_SIZE * 0.5 * BASE_SCALE * HEAD_SCALE


## Carte de zones d'une skin Kenney (`criminal_male_a`…), partagée.
static func zone_texture(skin: String) -> Texture2D:
	if not _zone_cache.has(skin):
		var path: String = ZONES_DIR % skin
		_zone_cache[skin] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _zone_cache[skin]


## Silhouette (largeur, hauteur, profondeur) et forme de tête : recalcule les
## repères « en mètres » pour que les pièces gardent leurs dimensions.
func set_proportions(silhouette: Vector3, head_shape: Vector3) -> void:
	armature.scale = silhouette * BASE_SCALE
	head_bone_scale = head_shape * HEAD_SCALE / silhouette
	_apply_head_scale()
	_refresh_meter_spaces()
	queue_parts_rebuild()


func set_rim_enabled(enabled: bool) -> void:
	rim_enabled = enabled
	for mat: ShaderMaterial in [body_material, parts_material]:
		if mat != null:
			mat.set_shader_parameter(&"rim_strength", 0.7 if enabled else 0.0)


## Liasse de papiers en main (repères `papers_show` / `papers_hide`).
func set_papers_visible(shown: bool) -> void:
	papers_visible = shown
	if _merge:
		parts_material.set_shader_parameter(&"papers_visible", shown)
	else:
		papers.visible = shown


## Demande une refusion des pièces (une seule par image, avant le rendu).
func queue_parts_rebuild() -> void:
	if not _merge or _parts_dirty:
		return
	_parts_dirty = true
	_flush_parts.call_deferred()


func _flush_parts() -> void:
	if _parts_dirty:
		rebuild_parts()


## Fusionne immédiatement les pièces sources attachées aux os en un maillage
## skinné (`parts_mesh`) ; les sources sont masquées. Les pièces dont le
## matériau n'est pas fusionnable (transparence) restent rendues seules.
func rebuild_parts() -> void:
	_parts_dirty = false
	if not _merge:
		return
	var parts: Array[Array] = []
	for child: Node in skeleton.get_children():
		var attachment: BoneAttachment3D = child as BoneAttachment3D
		if attachment != null:
			_collect_parts(attachment, Transform3D.IDENTITY, attachment.bone_name, parts)
	var key: PackedStringArray = []
	for part: Array in parts:
		key.append(_part_key(part))
	var signature: String = "\n".join(key)
	if signature == _parts_key and parts_mesh.mesh != null:
		return
	_parts_key = signature
	var built: Array = _parts_cache.get(signature, [])
	if built.is_empty():
		built = _bake_parts(parts)
		if _parts_cache.size() >= PARTS_CACHE_MAX:
			_parts_cache.erase(_parts_cache.keys()[0])
		_parts_cache[signature] = built
	parts_mesh.mesh = built[0]
	parts_mesh.skin = built[1]


## Vide le cache des maillages fusionnés (tests).
static func clear_parts_cache() -> void:
	_parts_cache.clear()


static func parts_cache_size() -> int:
	return _parts_cache.size()


## Pièces sources : [os, transformation dans l'espace de l'os, maillage, mode,
## albédo, émission, rugosité, métal, galbe].
func _collect_parts(node: Node, xf: Transform3D, bone: String, out: Array[Array]) -> void:
	for child: Node in node.get_children():
		var spatial: Node3D = child as Node3D
		if spatial == null or spatial == parts_mesh:
			continue
		var local: Transform3D = xf * spatial.transform
		var mi: MeshInstance3D = spatial as MeshInstance3D
		if mi != null and mi.mesh != null:
			var part: Array = _describe_part(mi, bone, local)
			mi.visible = part.is_empty()
			if not part.is_empty():
				out.append(part)
		_collect_parts(spatial, local, bone, out)


func _describe_part(mi: MeshInstance3D, bone: String, xf: Transform3D) -> Array:
	if mi == face:
		return [bone, xf, mi.mesh, PartMode.FACE, Color.BLACK, Color.BLACK, 0.6, 0.0, FACE_CURVATURE]
	var shader_mat: ShaderMaterial = mi.material_override as ShaderMaterial
	if shader_mat != null and shader_mat.shader == PART_SHADER:
		var albedo: Color = _param(shader_mat, &"albedo", Color(0.5, 0.5, 0.5))
		var emission: Color = _param(shader_mat, &"emission_color", Color.BLACK)
		var rough: float = _param(shader_mat, &"roughness", 0.75)
		var metal: float = _param(shader_mat, &"metallic", 0.0)
		var mode: PartMode = PartMode.PAPERS if mi == papers else PartMode.SOLID
		return [bone, xf, mi.mesh, mode, albedo, emission, rough, metal, 0.0]
	var std: BaseMaterial3D = mi.material_override as BaseMaterial3D
	if std != null and std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			and std.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return [bone, xf, mi.mesh, PartMode.UNSHADED, std.albedo_color, Color.BLACK, 1.0, 0.0, 0.0]
	return []


static func _param(mat: ShaderMaterial, param: StringName, fallback: Variant) -> Variant:
	var value: Variant = mat.get_shader_parameter(param)
	return fallback if value == null else value


## Signature d'une pièce : os, transformation, paramètres du maillage, rendu.
static func _part_key(part: Array) -> String:
	var mesh: Mesh = part[2]
	var props: Array = [mesh.get_class()]
	for prop: Dictionary in mesh.get_property_list():
		var usage: int = prop["usage"]
		var prop_name: StringName = prop["name"]
		if (usage & PROPERTY_USAGE_STORAGE) != 0 and prop_name != &"resource_name":
			props.append(mesh.get(prop_name))
	return str([part[0], part[1], props, part[3], part[4], part[5], part[6], part[7], part[8]])


## Construit le maillage fusionné et sa peau (une liaison identité par os :
## les sommets sont exprimés dans l'espace de l'os, comme sous un `BoneAttachment3D`).
static func _bake_parts(parts: Array[Array]) -> Array:
	var skin: Skin = Skin.new()
	var binds: Dictionary[String, int] = {}
	var verts: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var uv2s: PackedVector2Array = []
	var custom0: PackedFloat32Array = []
	var custom1: PackedFloat32Array = []
	var bones: PackedInt32Array = []
	var weights: PackedFloat32Array = []
	var indices: PackedInt32Array = []
	for part: Array in parts:
		var bone: String = part[0]
		if not binds.has(bone):
			binds[bone] = skin.get_bind_count()
			skin.add_named_bind(bone, Transform3D.IDENTITY)
		var xf: Transform3D = part[1]
		var mesh: Mesh = part[2]
		var mode: int = part[3]
		var albedo: Color = part[4]
		var emission: Color = part[5]
		var rough: float = part[6]
		var metal: float = part[7]
		var rough_metal: Vector2 = Vector2(rough, metal)
		var curvature: float = part[8]
		var normal_xf: Transform3D = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: int = pv.size()
			if curvature != 0.0:
				for i: int in n:
					var v: Vector3 = pv[i]
					pv[i] = Vector3(v.x, v.y, v.z - curvature * (v.x * v.x + v.y * v.y))
			var base: int = verts.size()
			verts.append_array(xf * pv)
			var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if pn.size() == n:
				normals.append_array(normal_xf * pn)
			else:
				var filler: PackedVector3Array = []
				filler.resize(n)
				filler.fill(Vector3.UP)
				normals.append_array(filler)
			var puv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if puv.size() != n:
				puv.resize(n)
			uvs.append_array(puv)
			var chunk2: PackedVector2Array = []
			chunk2.resize(n)
			chunk2.fill(rough_metal)
			uv2s.append_array(chunk2)
			var c0: PackedFloat32Array = PackedFloat32Array([albedo.r, albedo.g, albedo.b, float(mode)])
			var c1: PackedFloat32Array = PackedFloat32Array([emission.r, emission.g, emission.b, 0.0])
			var bw: PackedInt32Array = PackedInt32Array([binds[bone], 0, 0, 0])
			var ww: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
			for i: int in n:
				custom0.append_array(c0)
				custom1.append_array(c1)
				bones.append_array(bw)
				weights.append_array(ww)
			var pi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if pi.is_empty():
				pi.resize(n)
				for i: int in n:
					pi[i] = i
			var flip: bool = xf.basis.determinant() < 0.0
			for t: int in range(0, pi.size(), 3):
				indices.append(base + pi[t])
				indices.append(base + (pi[t + 2] if flip else pi[t + 1]))
				indices.append(base + (pi[t + 1] if flip else pi[t + 2]))
	var mesh_out: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return [mesh_out, skin]
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_TEX_UV2] = uv2s
	out[Mesh.ARRAY_CUSTOM0] = custom0
	out[Mesh.ARRAY_CUSTOM1] = custom1
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = indices
	mesh_out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, PARTS_FORMAT)
	mesh_out.resource_name = "chr_parts"
	return [mesh_out, skin]


func _apply_head_scale() -> void:
	head_scaler.bone_scale = head_bone_scale
	# Pose de base aussi (rendu sans AnimationPlayer, tests headless).
	if _head_bone >= 0:
		skeleton.set_bone_pose_scale(_head_bone, head_bone_scale)
		skeleton.set_bone_pose_position(_head_bone, skeleton.get_bone_rest(_head_bone).origin * NECK_FACTOR)


func _build() -> void:
	_merge = merge_parts
	armature = Node3D.new()
	armature.name = "Armature"
	armature.scale = Vector3.ONE * BASE_SCALE
	add_child(armature)
	var model: Node = MODEL.instantiate()
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	skeleton.get_parent().remove_child(skeleton)
	model.free()
	skeleton.name = "Skeleton3D"
	skeleton.unique_name_in_owner = false
	armature.add_child(skeleton)
	_head_bone = skeleton.find_bone("Head")
	body_mesh = skeleton.get_child(0) as MeshInstance3D
	body_mesh.name = "Body"
	body_material = ShaderMaterial.new()
	body_material.shader = BODY_SHADER
	body_material.set_shader_parameter(&"zones", zone_texture("survivor_male_b"))
	body_material.set_shader_parameter(&"rim_left", GreyboxStyle.WORLD_TEAL_DIM)
	body_material.set_shader_parameter(&"rim_right", GreyboxStyle.WORLD_ROSE_DIM)
	body_mesh.material_override = body_material
	skin_material = make_material(GreyboxStyle.SKINS[&"skin_03"], 0.7)

	head = _meter_space("Head", "Head")
	_build_face()
	hair_root = _container(head, "Hair")
	headwear_root = _container(head, "Headwear")
	head_accessory_root = _container(head, "HeadAccessory")
	neck_wear_root = _meter_space("NeckWear", "Neck")
	outfit_root = _meter_space("Outfit", "UpperChest")
	var hand: Node3D = _meter_space("HandSpace", "RightHand")
	hand_space = hand
	implants_head = _container(head, "Implants")
	implants_neck = _meter_space("ImplantsNeck", "Neck")
	implants_hand = _container(hand, "Implants")
	papers = add_mesh(hand, "Papers", box(Vector3(0.10, 0.14, 0.012)), make_material(Color("#C9D3D8"), 0.5),
			Vector3(0.0, 0.07, 0.03), Vector3(0, 0, 0))
	papers.visible = false
	if _merge:
		parts_mesh = MeshInstance3D.new()
		parts_mesh.name = "Parts"
		parts_mesh.material_override = parts_material
		skeleton.add_child(parts_mesh)
		parts_mesh.skeleton = NodePath("..")

	head_scaler = HeadScaleModifier.new()
	head_scaler.name = "HeadScale"
	head_scaler.neck_factor = NECK_FACTOR
	skeleton.add_child(head_scaler)
	neck_look = _look_modifier("NeckLook", "Neck", 0.3)
	head_look = _look_modifier("HeadLook", "Head", 1.0)
	_apply_head_scale()
	_refresh_meter_spaces()
	rebuild_parts()


func _build_face() -> void:
	var half: Vector3 = head_half_size()
	var face_mesh: QuadMesh = QuadMesh.new()
	face_mesh.size = Vector2(0.19, 0.23)
	face_mesh.subdivide_width = 6
	face_mesh.subdivide_depth = 6
	var plate: ShaderMaterial = ShaderMaterial.new()
	plate.shader = FACE_SHADER
	plate.set_shader_parameter(&"atlas", FaceAtlas.get_texture())
	plate.set_shader_parameter(&"curvature", FACE_CURVATURE)
	face_material = plate
	if _merge:
		parts_material = ShaderMaterial.new()
		parts_material.shader = PARTS_SHADER
		parts_material.set_shader_parameter(&"atlas", FaceAtlas.get_texture())
		parts_material.set_shader_parameter(&"rim_left", GreyboxStyle.WORLD_TEAL_DIM)
		parts_material.set_shader_parameter(&"rim_right", GreyboxStyle.WORLD_ROSE_DIM)
		parts_material.set_shader_parameter(&"rim_strength", 0.7 if rim_enabled else 0.0)
		face_material = parts_material
	face = add_mesh(head, "Face", face_mesh, plate, Vector3(0, -0.045, half.z + 0.004))
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nose = add_mesh(head, "Nose", box(Vector3(0.021, 0.03, 0.016)), skin_material, Vector3(0, -0.05, half.z + 0.008))
	ear_l = add_mesh(head, "EarL", sphere(0.03), skin_material, Vector3(half.x + 0.004, -0.05, 0.0))
	ear_r = add_mesh(head, "EarR", sphere(0.03), skin_material, Vector3(-half.x - 0.004, -0.05, 0.0))

	head_area = Area3D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = FACE_PICK_LAYER
	head_area.collision_mask = 0
	head_area.monitoring = false
	# Le clic « Visage » est testé par BoothDirector (rayon ↔ tête) : pas de picking physique.
	head_area.input_ray_pickable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.17
	shape.shape = sphere_shape
	head_area.add_child(shape)
	head.add_child(head_area)


## Repère en mètres attaché à un os (annule l'échelle du squelette).
func _meter_space(node_name: String, bone: String) -> Node3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = bone + "Attachment"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var space: Node3D = Node3D.new()
	space.name = node_name
	attachment.add_child(space)
	_meter_spaces.append(space)
	return space


func _refresh_meter_spaces() -> void:
	for space: Node3D in _meter_spaces:
		if space == head:
			# Échelle globale de l'os ≈ BASE × HEAD × forme : on garde la forme
			# (les pièces de tête suivent le visage), pas la réduction.
			space.position = HEAD_BOX_CENTER
			space.scale = Vector3.ONE / (BASE_SCALE * HEAD_SCALE)
		else:
			space.scale = Vector3.ONE / armature.scale


func _container(parent: Node3D, node_name: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


## Regard (D-010, BOOTH_SCENE §9.1) : cible posée par l'acteur ; limites
## lacet ±40°, tangage −25°/+15° (la cible est aussi bornée en amont).
func _look_modifier(node_name: String, bone: String, base_influence: float) -> LookAtModifier3D:
	var look: LookAtModifier3D = LookAtModifier3D.new()
	look.name = node_name
	look.bone_name = bone
	look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	look.primary_rotation_axis = Vector3.AXIS_Y
	look.use_secondary_rotation = true
	look.use_angle_limitation = true
	look.symmetry_limitation = false
	look.primary_positive_limit_angle = deg_to_rad(40.0)
	look.primary_negative_limit_angle = deg_to_rad(40.0)
	look.secondary_positive_limit_angle = deg_to_rad(25.0)
	look.secondary_negative_limit_angle = deg_to_rad(25.0)
	look.duration = 0.25
	look.transition_type = Tween.TRANS_SINE
	look.ease_type = Tween.EASE_OUT
	look.influence = 0.0
	look.active = false
	look.set_meta(&"base_influence", base_influence)
	skeleton.add_child(look)
	return look


## Influence du regard (0–1) répartie cou (30 %) / tête (100 %).
func set_look_weight(weight: float) -> void:
	for look: LookAtModifier3D in [neck_look, head_look]:
		var base: float = look.get_meta(&"base_influence", 1.0)
		look.influence = clampf(weight, 0.0, 1.0) * base
		look.active = weight > 0.001


## Échelle des jambes par rapport au rig nominal (anti-patinage de `walk`).
func leg_scale() -> float:
	return scale.y * armature.scale.y / BASE_SCALE
