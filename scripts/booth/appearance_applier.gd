## Applique une `PassengerAppearance` à un `PassengerRig` (ARCHITECTURE §8 bis.5,
## D-012/D-018). **Même code** pour l'acteur du guichet et le studio portrait :
## la photo d'un document et le passager sont construits depuis la même structure.
##
## Greybox (M4) : silhouette, taille, peau, forme du visage, oreilles, nez,
## lèvres, yeux, cheveux (coupe + couleur), coiffe (dont visière baissée/relevée),
## tenue (détails + palette) et accessoires en primitives colorées.
class_name AppearanceApplier
extends RefCounted


static func apply(rig: PassengerRig, app: PassengerAppearance) -> void:
	if rig == null or app == null:
		return
	var skin: Color = GreyboxStyle.skin_color(app)
	var pal: PackedColorArray = GreyboxStyle.palette(app)
	var rim: float = 0.7 if rig.rim_enabled else 0.0
	_set_color(rig.skin_material, skin, rim)
	_set_color(rig.top_material, pal[0], rim)
	_set_color(rig.bottom_material, pal[1], rim)

	rig.scale = Vector3.ONE * GreyboxStyle.height_scale(app)
	_apply_silhouette(rig, app)
	_apply_face(rig, app)
	_apply_hair(rig, app)
	_apply_headwear(rig, app, pal)
	_apply_outfit(rig, app, pal)
	_apply_accessory(rig, app, pal)


static func _set_color(mat: ShaderMaterial, color: Color, rim: float) -> void:
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"rim_strength", rim)


static func _apply_silhouette(rig: PassengerRig, app: PassengerAppearance) -> void:
	var s: Vector3 = GreyboxStyle.silhouette_scale(app)
	rig.torso.scale = Vector3(s.x, s.y, 0.72 * s.z)
	rig.arm_l.position.x = -0.235 * s.x
	rig.arm_r.position.x = 0.235 * s.x
	for leg: MeshInstance3D in rig.legs:
		leg.scale = Vector3(lerpf(1.0, s.x, 0.6), 1.0, lerpf(1.0, s.z, 0.6))
	for arm: MeshInstance3D in rig.arm_meshes:
		arm.scale = Vector3(lerpf(1.0, s.x, 0.7), 1.0, lerpf(1.0, s.x, 0.7))


static func _apply_face(rig: PassengerRig, app: PassengerAppearance) -> void:
	match GreyboxStyle.face_shape(app):
		&"round":
			rig.skull.scale = Vector3(1.07, 0.93, 1.02)
			rig.jaw.visible = false
		&"square":
			rig.skull.scale = Vector3(1.0, 0.97, 1.0)
			rig.jaw.visible = true
			rig.jaw.mesh = PassengerRig.sphere(0.1)
			rig.jaw.scale = Vector3(1.08, 0.62, 0.95)
			rig.jaw.position = Vector3(0, -0.062, -0.012)
			rig.jaw.rotation_degrees = Vector3.ZERO
		&"angular":
			rig.skull.scale = Vector3(0.95, 1.0, 0.97)
			rig.jaw.visible = true
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(0.17, 0.09, 0.14)
			rig.jaw.mesh = prism
			rig.jaw.scale = Vector3.ONE
			rig.jaw.position = Vector3(0, -0.08, -0.012)
			rig.jaw.rotation_degrees = Vector3(0, 0, 180)
		_: # oval
			rig.skull.scale = Vector3(0.93, 1.06, 0.96)
			rig.jaw.visible = false

	var ears: int = GreyboxStyle.ear_variant(app)
	for ear: MeshInstance3D in [rig.ear_l, rig.ear_r]:
		var side: float = -1.0 if ear == rig.ear_l else 1.0
		match ears:
			1:
				ear.mesh = PassengerRig.sphere(0.026)
				ear.scale = Vector3(0.55, 1.0, 0.8)
				ear.rotation_degrees = Vector3.ZERO
			2:
				ear.mesh = PassengerRig.sphere(0.036)
				ear.scale = Vector3(0.5, 1.15, 0.85)
				ear.rotation_degrees = Vector3.ZERO
			_:
				var prism: PrismMesh = PrismMesh.new()
				prism.size = Vector3(0.035, 0.07, 0.025)
				ear.mesh = prism
				ear.scale = Vector3.ONE
				ear.rotation_degrees = Vector3(0, 0, -18.0 * side)
		ear.position = Vector3(0.112 * side * rig.skull.scale.x, 0.005, -0.005)

	match GreyboxStyle.nose_variant(app):
		1:
			rig.nose.mesh = PassengerRig.box(Vector3(0.024, 0.04, 0.03))
		3:
			rig.nose.mesh = PassengerRig.box(Vector3(0.046, 0.055, 0.046))
		_:
			rig.nose.mesh = PassengerRig.box(Vector3(0.032, 0.05, 0.038))

	var eyes: PackedColorArray = GreyboxStyle.eye_colors(app)
	rig.face_material.set_shader_parameter(&"iris_color_left", eyes[0])
	rig.face_material.set_shader_parameter(&"iris_color_right", eyes[1])
	rig.face_material.set_shader_parameter(&"lip_scale", 1.0 if GreyboxStyle.lip_variant(app) == 1 else 1.7)
	# La plaque visage affleure le crâne (qui change d'échelle selon la forme).
	rig.face.position = Vector3(0, -0.01, 0.115 * rig.skull.scale.z + 0.005)


static func _apply_hair(rig: PassengerRig, app: PassengerAppearance) -> void:
	PassengerRig.clear(rig.hair_root)
	var headwear: StringName = app.get_trait(PassengerAppearance.SLOT_HEADWEAR)
	if headwear == &"hood":
		return # la capuche couvre les cheveux
	var color: Color = GreyboxStyle.hair_color(app)
	var cut: StringName = GreyboxStyle.hair_cut(app)
	var mat: ShaderMaterial = rig.make_material(color, 0.9)
	var root: Node3D = rig.hair_root
	var cap_tilt: Vector3 = Vector3(-24, 0, 0)
	match cut:
		&"shaved":
			var stubble: ShaderMaterial = rig.make_material(color.lerp(GreyboxStyle.skin_color(app), 0.55), 0.95)
			rig.add_mesh(root, "Cap", PassengerRig.sphere(0.119, 0.13, true), stubble, Vector3(0, 0.012, -0.004), cap_tilt)
		&"curly":
			rig.add_mesh(root, "Cap", PassengerRig.sphere(0.138, 0.16, true), mat, Vector3(0, 0.012, -0.012), cap_tilt,
					Vector3(1.08, 1.05, 1.05))
			for i: int in 5:
				var a: float = -1.0 + i * 0.5
				rig.add_mesh(root, "Curl%d" % i, PassengerRig.sphere(0.04), mat, Vector3(a * 0.1, 0.09 - absf(a) * 0.04, -0.03))
		&"mohawk":
			rig.add_mesh(root, "Crest", PassengerRig.box(Vector3(0.035, 0.08, 0.24)), mat, Vector3(0, 0.125, -0.01),
					Vector3(-8, 0, 0))
		_:
			rig.add_mesh(root, "Cap", PassengerRig.sphere(0.123, 0.14, true), mat, Vector3(0, 0.014, -0.006), cap_tilt)
			match cut:
				&"long":
					rig.add_mesh(root, "Back", PassengerRig.box(Vector3(0.23, 0.30, 0.07)), mat, Vector3(0, -0.09, -0.085))
				&"bun":
					rig.add_mesh(root, "Bun", PassengerRig.sphere(0.052), mat, Vector3(0, 0.1, -0.1))
				&"braids":
					for side: float in [-1.0, 1.0]:
						rig.add_mesh(root, "Braid", PassengerRig.capsule(0.024, 0.3), mat, Vector3(0.1 * side, -0.12, -0.035))


static func _apply_headwear(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray) -> void:
	PassengerRig.clear(rig.headwear_root)
	var root: Node3D = rig.headwear_root
	match app.get_trait(PassengerAppearance.SLOT_HEADWEAR):
		&"hood":
			var mat: ShaderMaterial = rig.make_material(pal[0].darkened(0.1), 0.9)
			rig.add_mesh(root, "Hood", PassengerRig.sphere(0.155, 0.2, true), mat, Vector3(0, 0.0, -0.025), Vector3(-30, 0, 0))
			rig.add_mesh(root, "HoodBack", PassengerRig.cylinder(0.14, 0.16, 0.2), mat, Vector3(0, -0.1, -0.05))
		&"cap":
			var mat: ShaderMaterial = rig.make_material(pal[2], 0.8)
			rig.add_mesh(root, "Crown", PassengerRig.sphere(0.127, 0.13, true), mat, Vector3(0, 0.03, -0.005), Vector3(-15, 0, 0))
			rig.add_mesh(root, "Brim", PassengerRig.box(Vector3(0.17, 0.012, 0.09)), mat, Vector3(0, 0.058, 0.13), Vector3(8, 0, 0))
		&"beanie":
			var mat: ShaderMaterial = rig.make_material(pal[2].darkened(0.15), 0.95)
			rig.add_mesh(root, "Beanie", PassengerRig.sphere(0.132, 0.17, true), mat, Vector3(0, 0.035, -0.008), Vector3(-18, 0, 0),
					Vector3(1.0, 1.15, 1.0))
		PassengerAppearance.VISOR_DOWN:
			_visor(rig, root, true)
		PassengerAppearance.VISOR_UP:
			_visor(rig, root, false)


## Visière opaque (D-021) : baissée, elle masque les yeux et le nez ; relevée,
## elle repose sur le front.
static func _visor(rig: PassengerRig, root: Node3D, down: bool) -> void:
	var glass: ShaderMaterial = rig.make_material(GreyboxStyle.VISOR_GLASS, 0.15, 0.6)
	var band: ShaderMaterial = rig.make_material(GreyboxStyle.WORLD_STEEL, 0.5, 0.4)
	var pivot: Node3D = Node3D.new()
	pivot.name = "Visor"
	pivot.position = Vector3(0, 0.05, -0.02)
	pivot.rotation_degrees = Vector3(0.0 if down else -62.0, 0.0, 0.0)
	root.add_child(pivot)
	rig.add_mesh(pivot, "Strap", PassengerRig.cylinder(0.126, 0.126, 0.035), band, Vector3(0, 0.0, 0.0))
	rig.add_mesh(pivot, "Shield", PassengerRig.box(Vector3(0.24, 0.10, 0.035)), glass, Vector3(0, -0.045, 0.135),
			Vector3(-6, 0, 0))
	var line: ShaderMaterial = rig.make_material(GreyboxStyle.INK, 0.4)
	line.set_shader_parameter(&"emission_color", GreyboxStyle.WORLD_TEAL_DIM * 1.6)
	rig.add_mesh(pivot, "Slit", PassengerRig.box(Vector3(0.2, 0.006, 0.004)), line, Vector3(0, -0.035, 0.154),
			Vector3(-6, 0, 0))


static func _apply_outfit(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray) -> void:
	PassengerRig.clear(rig.outfit_root)
	var index: int = GreyboxStyle.outfit_index(app)
	var s: Vector3 = GreyboxStyle.silhouette_scale(app)
	var root: Node3D = rig.outfit_root
	var accent: ShaderMaterial = rig.make_material(pal[2], 0.7)
	if (index & 1) != 0:
		rig.add_mesh(root, "Collar", PassengerRig.cylinder(0.085, 0.11, 0.08), rig.make_material(pal[0].darkened(0.2)),
				Vector3(0, 0.56, 0))
	if (index & 2) != 0:
		for side: float in [-1.0, 1.0]:
			rig.add_mesh(root, "Pad", PassengerRig.box(Vector3(0.12, 0.05, 0.16)), rig.make_material(pal[0].lightened(0.08)),
					Vector3(0.17 * side * s.x, 0.52, 0), Vector3(0, 0, -14.0 * side))
	if (index & 4) != 0:
		rig.add_mesh(root, "Stripe", PassengerRig.box(Vector3(0.05, 0.42, 0.02)), accent,
				Vector3(0.06 * s.x, 0.28, 0.135 * s.z))
	else:
		rig.add_mesh(root, "Seam", PassengerRig.box(Vector3(0.012, 0.44, 0.02)), accent, Vector3(0, 0.27, 0.136 * s.z))


static func _apply_accessory(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray) -> void:
	PassengerRig.clear(rig.head_accessory_root)
	PassengerRig.clear(rig.neck_wear_root)
	var accessory: StringName = app.get_trait(PassengerAppearance.SLOT_ACCESSORY)
	match accessory:
		&"half_visor":
			var tinted: StandardMaterial3D = StandardMaterial3D.new()
			tinted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tinted.albedo_color = Color(GreyboxStyle.WORLD_TEAL_DIM, 0.35)
			tinted.roughness = 0.1
			rig.add_mesh(rig.head_accessory_root, "HalfVisor", PassengerRig.box(Vector3(0.22, 0.045, 0.01)), tinted,
					Vector3(0, 0.022, 0.13))
		&"respirator_neck":
			var mat: ShaderMaterial = rig.make_material(GreyboxStyle.WORLD_STEEL, 0.5, 0.3)
			rig.add_mesh(rig.neck_wear_root, "Respirator", PassengerRig.cylinder(0.075, 0.08, 0.05), mat, Vector3(0, 0.6, 0.015))
			rig.add_mesh(rig.neck_wear_root, "Filter", PassengerRig.cylinder(0.03, 0.03, 0.04), mat, Vector3(0.08, 0.6, 0.04),
					Vector3(0, 0, 90))
		&"scarf":
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 0.05
			torus.outer_radius = 0.105
			rig.add_mesh(rig.neck_wear_root, "Scarf", torus, rig.make_material(pal[2], 0.95), Vector3(0, 0.575, 0.0),
					Vector3(8, 0, 0), Vector3(1.0, 1.6, 1.0))
		_:
			if String(accessory).begins_with("holo_tattoo_"):
				var n: int = String(accessory).trim_prefix("holo_tattoo_").to_int()
				var glow: StandardMaterial3D = StandardMaterial3D.new()
				glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				glow.albedo_color = GreyboxStyle.HOLO_TATTOO
				var quad: QuadMesh = QuadMesh.new()
				quad.size = Vector2(0.012 + 0.004 * n, 0.008 + 0.004 * (n % 2))
				var side: float = -1.0 if n % 2 == 1 else 1.0
				rig.add_mesh(rig.head_accessory_root, "HoloTattoo", quad, glow,
						Vector3(0.07 * side, -0.03 + 0.008 * n, 0.09), Vector3(0, 40.0 * side, 45.0 * (n % 2)))
