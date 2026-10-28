## Accessoires de l'Acte II (ARCHITECTURE §7.2, `Case.dialogue_tags`) — pièces
## low-poly au budget de rendu préservé (D-073, D-075 : ≤ 2 draw calls chacun) :
## - `prop_cat_crate` : caisse de transport du chat Mistigri (SC-27), tenue à la
##   main droite — pièces du rig, **fusionnées** au maillage skinné de l'acteur
##   (0 draw call de plus) ;
## - `prop_shunt_led` : LED ambre d'un shunt NX en mise à jour (SC-34), derrière
##   l'oreille — fusionnée elle aussi (0 draw call de plus) ;
## - `companion_child` : un enfant à côté du passager (SC-25, SC-26, SC-37) —
##   un maillage statique, un matériau (`chr_parts.gdshader`, attributs par
##   sommet comme les pièces des passagers) : 1 draw call + 1 d'ombre ;
## - `prop_drone` : drone de la Commissaire (SC-42) en vol stationnaire au-dessus
##   de son épaule — un maillage, un matériau, sans ombre : 1 draw call.
## Les compagnons (enfant, drone) sont des enfants de l'acteur : ils le suivent
## à l'arrivée et à la sortie ; reconstruits à chaque cas (pool de 2 acteurs).
## Acte III (ARCHITECTURE §7.3, ACT3 §8.3) — toutes **fusionnées** au maillage
## skinné de l'acteur (0 draw call de plus) :
## - `prop_bandaged_hands` : bandages de gaze sur la main et le poignet (SC-53) ;
## - `prop_certificate_crate` : caisse de certificats inutiles (SC-58) ;
## - `prop_school_satchel` : cartable de copies de la maîtresse (SC-56, SC-81) ;
## - `prop_armband_pocket` : brassard jaune de la Garde qui dépasse d'une poche
##   de poitrine (SC-79) ;
## - `sc81b` : badge « répondant » agrafé à la poitrine (réseau du J30).
class_name PropDecor
extends RefCounted

const TAG_CHILD: StringName = &"companion_child"
const TAG_CAT_CRATE: StringName = &"prop_cat_crate"
const TAG_DRONE: StringName = &"prop_drone"
const TAG_SHUNT_LED: StringName = &"prop_shunt_led"
## Acte III.
const TAG_BANDAGES: StringName = &"prop_bandaged_hands"
const TAG_CERTIFICATES: StringName = &"prop_certificate_crate"
const TAG_SATCHEL: StringName = &"prop_school_satchel"
const TAG_ARMBAND: StringName = &"prop_armband_pocket"
const TAG_SPONSOR_BADGE: StringName = &"sc81b"
const ALL_TAGS: Array[StringName] = [TAG_CHILD, TAG_CAT_CRATE, TAG_DRONE, TAG_SHUNT_LED, TAG_BANDAGES, TAG_CERTIFICATES,
		TAG_SATCHEL, TAG_ARMBAND, TAG_SPONSOR_BADGE]
## Accessoires tenus à la main droite (un seul à la fois : le premier l'emporte).
const HAND_TAGS: Array[StringName] = [TAG_CAT_CRATE, TAG_CERTIFICATES, TAG_SATCHEL]
## Pièces posées sur la poitrine (repère `outfit_root`, vidé à chaque cas).
const CHEST_PARTS: PackedStringArray = ["PropArmband", "PropArmbandFold", "PropBadge", "PropBadgeStripe", "PropBadgeClip"]
const NODE_CHILD: String = "PropChild"
const NODE_DRONE: String = "PropDrone"

## Teintes (désaturées, cohérentes avec `GreyboxStyle` et la palette des tenues).
const CHILD_SKIN: Color = Color("#8D5B45")
const CHILD_HAIR: Color = Color("#1E1714")
const CHILD_COAT: Color = Color("#3E6470")
const CHILD_SCARF: Color = Color("#B0543A")
const CHILD_TROUSERS: Color = Color("#2B2F38")
const CHILD_SHOES: Color = Color("#17191E")
const CRATE_SHELL: Color = Color("#B9AE95")
const CRATE_GRILLE: Color = Color("#2A2D33")
const CAT_EYES: Color = Color(0.9, 0.62, 0.15)
const LED_AMBER: Color = Color(1.0, 0.55, 0.1)
const DRONE_BODY: Color = Color("#262B33")
const DRONE_TRIM: Color = Color("#5C6675")
## Lentille du drone : bleu de registre de la Commission (DS.VOICE_COMMISSION).
const DRONE_LENS: Color = Color("#8E9CFF")
## Acte III : gaze, carton et feuillets, cuir du cartable, brassard de la
## Garde (jaune Consortium désaturé), badge (cyan du guichet).
const GAUZE: Color = Color("#D9D3C7")
const GAUZE_STAIN: Color = Color("#A9685E")
const CARDBOARD: Color = Color("#8C6E4A")
const SHEETS: Color = Color("#E4E6E1")
const LEATHER: Color = Color("#5A3B28")
const BUCKLE: Color = Color("#B8A46A")
const ARMBAND_YELLOW: Color = Color("#D8C21A")
const BADGE_BODY: Color = Color("#2A3038")
const BADGE_GLOW: Color = Color(0.0, 0.9, 1.0)
## Position des compagnons dans le repère de l'acteur (m).
const CHILD_OFFSET: Vector3 = Vector3(-0.46, 0.0, 0.08)
const DRONE_OFFSET: Vector3 = Vector3(0.36, 1.98, 0.05)
const DRONE_BOB: float = 0.035
const DRONE_BOB_SEC: float = 0.9

static var _meshes: Dictionary[String, ArrayMesh] = {}
static var _material: ShaderMaterial = null


## Étiquettes d'accessoires présentes parmi `tags`.
static func props_in(tags: Array[StringName]) -> Array[StringName]:
	var found: Array[StringName] = []
	for tag: StringName in ALL_TAGS:
		if tags.has(tag):
			found.append(tag)
	return found


## Pose les accessoires du cas ; à appeler **après** `ImplantDecor.apply` (qui
## vide les conteneurs d'implants du rig, donc les pièces portées précédentes).
static func apply(actor: Node3D, rig: PassengerRig, tags: Array[StringName]) -> void:
	for node_name: String in [NODE_CHILD, NODE_DRONE]:
		var old: Node = actor.get_node_or_null(node_name)
		if old != null:
			actor.remove_child(old)
			old.queue_free()
	if rig != null and rig.outfit_root != null:
		for part_name: String in CHEST_PARTS:
			var part: Node = rig.outfit_root.get_node_or_null(part_name)
			if part != null:
				rig.outfit_root.remove_child(part)
				part.queue_free()
	if rig != null and rig.implants_hand != null:
		var held: StringName = &""
		for tag: StringName in HAND_TAGS:
			if tags.has(tag):
				held = tag
				break
		match held:
			TAG_CAT_CRATE:
				_add_crate(rig)
			TAG_CERTIFICATES:
				_add_certificates(rig)
			TAG_SATCHEL:
				_add_satchel(rig)
		if tags.has(TAG_SHUNT_LED):
			_add_led(rig)
		if tags.has(TAG_BANDAGES):
			_add_bandages(rig)
		if rig.outfit_root != null:
			if tags.has(TAG_ARMBAND):
				_add_armband(rig)
			if tags.has(TAG_SPONSOR_BADGE):
				_add_badge(rig)
		rig.queue_parts_rebuild()
	if tags.has(TAG_CHILD):
		var child: MeshInstance3D = _instance(NODE_CHILD, _mesh("child"), true)
		child.position = CHILD_OFFSET
		actor.add_child(child)
	if tags.has(TAG_DRONE):
		var drone: MeshInstance3D = _instance(NODE_DRONE, _mesh("drone"), false)
		drone.position = DRONE_OFFSET
		actor.add_child(drone)
		if not Settings.reduce_motion:
			var bob: Tween = drone.create_tween().set_loops()
			bob.tween_property(drone, "position:y", DRONE_OFFSET.y + DRONE_BOB, DRONE_BOB_SEC).set_trans(Tween.TRANS_SINE)
			bob.tween_property(drone, "position:y", DRONE_OFFSET.y - DRONE_BOB, DRONE_BOB_SEC).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Pièces portées (fusionnées au maillage de l'acteur)
# ---------------------------------------------------------------------------

## Caisse de transport tenue par la poignée (repère de la main, axe Y = doigts).
static func _add_crate(rig: PassengerRig) -> void:
	var root: Node3D = rig.implants_hand
	var shell: ShaderMaterial = rig.make_material(CRATE_SHELL, 0.7)
	var grille: ShaderMaterial = rig.make_material(CRATE_GRILLE, 0.5, 0.6)
	rig.add_mesh(root, "CrateHandle", _torus(0.035, 0.045), grille, Vector3(0, 0.05, 0), Vector3(0, 0, 90))
	rig.add_mesh(root, "CrateShell", PassengerRig.box(Vector3(0.2, 0.19, 0.3)), shell, Vector3(0, 0.17, 0))
	rig.add_mesh(root, "CrateGrille", PassengerRig.box(Vector3(0.16, 0.14, 0.012)), grille, Vector3(0, 0.175, 0.152))
	var eyes: ShaderMaterial = rig.make_material(CAT_EYES.darkened(0.4), 0.4)
	eyes.set_shader_parameter(&"emission_color", CAT_EYES * 0.9)
	for x: float in [-0.022, 0.022]:
		rig.add_mesh(root, "CatEye", PassengerRig.sphere(0.008), eyes, Vector3(x, 0.19, 0.142))


## LED d'un shunt NX en cours de mise à jour (derrière l'oreille gauche).
static func _add_led(rig: PassengerRig) -> void:
	var half: Vector3 = PassengerRig.head_half_size()
	rig.add_mesh(rig.implants_head, "ShuntPort", PassengerRig.cylinder(0.014, 0.014, 0.008, 10),
			rig.make_material(Color("#4A525E"), 0.35, 0.8), Vector3(half.x + 0.005, -0.01, -0.055), Vector3(0, 0, 90))
	var led: ShaderMaterial = rig.make_material(LED_AMBER.darkened(0.3), 0.4)
	led.set_shader_parameter(&"emission_color", LED_AMBER * 1.4)
	rig.add_mesh(rig.implants_head, "ShuntLed", PassengerRig.sphere(0.006), led, Vector3(half.x + 0.011, -0.01, -0.055))


## Acte III — gaze enroulée autour de la main et du poignet (SC-53).
static func _add_bandages(rig: PassengerRig) -> void:
	var root: Node3D = rig.implants_hand
	var gauze: ShaderMaterial = rig.make_material(GAUZE, 0.95)
	rig.add_mesh(root, "BandageWrist", PassengerRig.cylinder(0.04, 0.042, 0.05, 10), gauze, Vector3(0, -0.02, 0))
	rig.add_mesh(root, "BandagePalm", PassengerRig.cylinder(0.046, 0.044, 0.045, 10), gauze, Vector3(0, 0.045, 0.005),
			Vector3.ZERO, Vector3(1.0, 1.0, 0.62))
	rig.add_mesh(root, "BandageStain", PassengerRig.box(Vector3(0.022, 0.016, 0.004)), rig.make_material(GAUZE_STAIN, 0.9),
			Vector3(0.01, 0.05, 0.034))


## Acte III — caisse de certificats de Meridian (SC-58), tenue par la poignée.
static func _add_certificates(rig: PassengerRig) -> void:
	var root: Node3D = rig.implants_hand
	var board: ShaderMaterial = rig.make_material(CARDBOARD, 0.9)
	rig.add_mesh(root, "CertHandle", _torus(0.03, 0.04), rig.make_material(CARDBOARD.darkened(0.35), 0.8), Vector3(0, 0.05, 0),
			Vector3(0, 0, 90))
	rig.add_mesh(root, "CertBox", PassengerRig.box(Vector3(0.26, 0.17, 0.2)), board, Vector3(0, 0.16, 0))
	var sheets: ShaderMaterial = rig.make_material(SHEETS, 0.6)
	for i: int in 3:
		rig.add_mesh(root, "CertSheet", PassengerRig.box(Vector3(0.21, 0.004, 0.15)), sheets,
				Vector3(-0.012 + 0.012 * i, 0.248 + 0.006 * i, 0.004 * i), Vector3(0, 4.0 * (i - 1), 0))


## Acte III — cartable de copies de la maîtresse (SC-56, SC-81).
static func _add_satchel(rig: PassengerRig) -> void:
	var root: Node3D = rig.implants_hand
	var leather: ShaderMaterial = rig.make_material(LEATHER, 0.8)
	rig.add_mesh(root, "SatchelHandle", _torus(0.028, 0.036), rig.make_material(LEATHER.darkened(0.3), 0.7), Vector3(0, 0.045, 0),
			Vector3(0, 0, 90))
	rig.add_mesh(root, "SatchelBody", PassengerRig.box(Vector3(0.3, 0.21, 0.08)), leather, Vector3(0, 0.17, 0))
	rig.add_mesh(root, "SatchelFlap", PassengerRig.box(Vector3(0.3, 0.12, 0.012)), rig.make_material(LEATHER.lightened(0.08), 0.75),
			Vector3(0, 0.215, 0.045))
	rig.add_mesh(root, "SatchelBuckle", PassengerRig.box(Vector3(0.04, 0.03, 0.01)), rig.make_material(BUCKLE, 0.35, 0.8),
			Vector3(0, 0.165, 0.054))
	rig.add_mesh(root, "SatchelCopies", PassengerRig.box(Vector3(0.24, 0.02, 0.05)), rig.make_material(SHEETS, 0.6),
			Vector3(0, 0.285, 0.0))


## Acte III — brassard jaune de la Garde, plié dans la poche de poitrine (SC-79).
static func _add_armband(rig: PassengerRig) -> void:
	var front: float = PassengerRig.CHEST_FRONT * PassengerRig.BASE_SCALE
	var x: float = -PassengerRig.CHEST_HALF_WIDTH * PassengerRig.BASE_SCALE * 0.42
	var yellow: ShaderMaterial = rig.make_material(ARMBAND_YELLOW, 0.85)
	rig.add_mesh(rig.outfit_root, "PropArmband", PassengerRig.box(Vector3(0.05, 0.05, 0.014)), yellow, Vector3(x, 0.02, front + 0.012),
			Vector3(0, 0, -12))
	rig.add_mesh(rig.outfit_root, "PropArmbandFold", PassengerRig.box(Vector3(0.056, 0.012, 0.02)), rig.make_material(ARMBAND_YELLOW.darkened(0.3), 0.85),
			Vector3(x, -0.005, front + 0.014))


## Acte III — badge « répondant » agrafé à la poitrine (réseau du J30, SC-81b).
static func _add_badge(rig: PassengerRig) -> void:
	var front: float = PassengerRig.CHEST_FRONT * PassengerRig.BASE_SCALE
	var x: float = PassengerRig.CHEST_HALF_WIDTH * PassengerRig.BASE_SCALE * 0.42
	rig.add_mesh(rig.outfit_root, "PropBadge", PassengerRig.box(Vector3(0.045, 0.06, 0.006)), rig.make_material(BADGE_BODY, 0.5, 0.3),
			Vector3(x, -0.01, front + 0.01))
	var glow: ShaderMaterial = rig.make_material(BADGE_GLOW.darkened(0.6), 0.4)
	glow.set_shader_parameter(&"emission_color", BADGE_GLOW * 0.9)
	rig.add_mesh(rig.outfit_root, "PropBadgeStripe", PassengerRig.box(Vector3(0.036, 0.008, 0.003)), glow,
			Vector3(x, 0.005, front + 0.0145))
	rig.add_mesh(rig.outfit_root, "PropBadgeClip", PassengerRig.box(Vector3(0.016, 0.014, 0.008)), rig.make_material(Color("#9AA4AE"), 0.3, 0.9),
			Vector3(x, 0.024, front + 0.011))


static func _torus(inner: float, outer: float) -> TorusMesh:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 10
	torus.ring_segments = 5
	return torus


# ---------------------------------------------------------------------------
# Compagnons : un maillage statique, un matériau partagé
# ---------------------------------------------------------------------------

static func _instance(node_name: String, mesh: ArrayMesh, shadow: bool) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Matériau partagé des compagnons (pièces des passagers, rim néon bicolore).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = PassengerRig.PARTS_SHADER
		_material.set_shader_parameter(&"rim_left", GreyboxStyle.WORLD_TEAL_DIM)
		_material.set_shader_parameter(&"rim_right", GreyboxStyle.WORLD_ROSE_DIM)
		_material.set_shader_parameter(&"rim_strength", 0.7)
	return _material


## Maillage d'un compagnon (`child`, `drone`), construit une fois.
static func _mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = bake(_child_pieces() if kind == "child" else _drone_pieces())
	return _meshes[kind]


## Surface unique d'un compagnon : nombre de surfaces (draw calls hors ombre).
static func surface_count(kind: String) -> int:
	return _mesh(kind).get_surface_count()


## Pièce : [maillage, transformation, albédo, émission, rugosité, métal].
static func _piece(mesh: Mesh, pos: Vector3, albedo: Color, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		emission: Color = Color.BLACK, rough: float = 0.75, metal: float = 0.0) -> Array:
	var basis: Basis = Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return [mesh, Transform3D(basis, pos), albedo, emission, rough, metal]


static func _child_pieces() -> Array[Array]:
	var pieces: Array[Array] = []
	for side: float in [-1.0, 1.0]:
		pieces.append(_piece(PassengerRig.box(Vector3(0.075, 0.05, 0.13)), Vector3(0.06 * side, 0.025, 0.015), CHILD_SHOES))
		pieces.append(_piece(PassengerRig.capsule(0.045, 0.44), Vector3(0.06 * side, 0.26, 0.0), CHILD_TROUSERS))
		pieces.append(_piece(PassengerRig.capsule(0.036, 0.36), Vector3(0.165 * side, 0.58, 0.0), CHILD_COAT, Vector3(0, 0, 8.0 * side)))
		pieces.append(_piece(PassengerRig.sphere(0.034), Vector3(0.19 * side, 0.4, 0.0), CHILD_SKIN))
		pieces.append(_piece(PassengerRig.sphere(0.012), Vector3(0.036 * side, 0.9, 0.093), CHILD_HAIR, Vector3.ZERO, Vector3.ONE,
				Color.BLACK, 0.3))
	pieces.append(_piece(PassengerRig.capsule(0.135, 0.46), Vector3(0, 0.6, 0.0), CHILD_COAT, Vector3.ZERO, Vector3(1.0, 1.0, 0.78)))
	pieces.append(_piece(_torus(0.05, 0.09), Vector3(0, 0.79, 0.0), CHILD_SCARF, Vector3.ZERO, Vector3(1.0, 1.6, 1.0)))
	pieces.append(_piece(PassengerRig.sphere(0.105), Vector3(0, 0.9, 0.0), CHILD_SKIN))
	pieces.append(_piece(PassengerRig.sphere(0.113, -1.0, true), Vector3(0, 0.915, -0.008), CHILD_HAIR, Vector3(-12, 0, 0)))
	return pieces


static func _drone_pieces() -> Array[Array]:
	var pieces: Array[Array] = []
	pieces.append(_piece(PassengerRig.box(Vector3(0.15, 0.05, 0.15)), Vector3.ZERO, DRONE_BODY, Vector3(0, 45, 0), Vector3.ONE,
			Color.BLACK, 0.45, 0.6))
	pieces.append(_piece(PassengerRig.sphere(0.03), Vector3(0, -0.03, 0.05), DRONE_LENS.darkened(0.5), Vector3.ZERO, Vector3.ONE,
			DRONE_LENS * 1.3, 0.3))
	for i: int in 4:
		var angle: float = PI * 0.25 + PI * 0.5 * i
		var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		pieces.append(_piece(PassengerRig.box(Vector3(0.16, 0.012, 0.02)), dir * 0.1, DRONE_TRIM, Vector3(0, -rad_to_deg(angle), 0)))
		pieces.append(_piece(PassengerRig.cylinder(0.055, 0.055, 0.006, 12), dir * 0.17 + Vector3(0, 0.02, 0), DRONE_TRIM.darkened(0.2),
				Vector3.ZERO, Vector3.ONE, Color.BLACK, 0.5, 0.3))
	return pieces


## Fusionne des pièces en une surface aux attributs de `chr_parts.gdshader`
## (CUSTOM0 = albédo + mode 0, CUSTOM1 = émission, UV2 = rugosité / métal).
static func bake(pieces: Array[Array]) -> ArrayMesh:
	var verts: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var uv2s: PackedVector2Array = []
	var custom0: PackedFloat32Array = []
	var custom1: PackedFloat32Array = []
	var indices: PackedInt32Array = []
	for piece: Array in pieces:
		var mesh: Mesh = piece[0]
		var xf: Transform3D = piece[1]
		var albedo: Color = piece[2]
		var emission: Color = piece[3]
		var rough: float = piece[4]
		var metal: float = piece[5]
		var rough_metal: Vector2 = Vector2(rough, metal)
		var normal_xf: Transform3D = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: int = pv.size()
			var base: int = verts.size()
			verts.append_array(xf * pv)
			var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var rotated: PackedVector3Array = normal_xf * pn
			for i: int in rotated.size():
				rotated[i] = rotated[i].normalized()
			normals.append_array(rotated)
			var puv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			puv.resize(n)
			uvs.append_array(puv)
			for i: int in n:
				uv2s.append(rough_metal)
				custom0.append_array(PackedFloat32Array([albedo.r, albedo.g, albedo.b, 0.0]))
				custom1.append_array(PackedFloat32Array([emission.r, emission.g, emission.b, 0.0]))
			var pi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if pi.is_empty():
				pi.resize(n)
				for i: int in n:
					pi[i] = i
			for i: int in pi.size():
				indices.append(base + pi[i])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_TEX_UV2] = uv2s
	out[Mesh.ARRAY_CUSTOM0] = custom0
	out[Mesh.ARRAY_CUSTOM1] = custom1
	out[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, PassengerRig.PARTS_FORMAT)
	return result
