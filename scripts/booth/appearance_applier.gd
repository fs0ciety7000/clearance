## Applique une `PassengerAppearance` à un `PassengerRig` (ARCHITECTURE §8 bis.5,
## D-012/D-018). **Même code** pour l'acteur du guichet et le studio portrait :
## la photo d'un document et le passager sont construits depuis la même structure.
##
## M6 (rig Kenney) : la tenue choisit la carte de zones d'une skin Kenney
## (8 tenues = 8 skins), recolorée par `chr_toon.gdshader` (peau, palette haut/
## bas/accent, chaussures, cheveux) ; silhouette = échelle du squelette ; forme
## du visage = échelle de l'os `Head` (+ menton) ; oreilles, nez, lèvres, yeux,
## coupes, coiffes (dont visière baissée/relevée), accessoires et détails de
## tenue (col, liseré émissif) en pièces low-poly attachées aux os.
## Correspondance identifiants → rendu : `GreyboxStyle` (couleurs) et ici
## (pièces) ; le catalogue (`appearance_catalog.tres`) ne porte que les ids.
## M10 : les pièces créées ici sont des sources, fusionnées par
## `PassengerRig.rebuild_parts()` (un draw call pour toutes, BOOTH_SCENE §18).
class_name AppearanceApplier
extends RefCounted

## Skins Kenney par tenue (`outfit_01` … `outfit_08`), cf. tools/build_passenger_skins.gd.
const OUTFIT_SKINS: Array[String] = [
	"criminal_male_a", "cyborg_female_a", "skater_female_a", "skater_male_a",
	"survivor_female_a", "survivor_male_b", "human_female_a", "human_male_a",
]
## Échelle (largeur, hauteur, profondeur) de la tête par forme de visage.
const FACE_SHAPES: Dictionary[StringName, Vector3] = {
	&"round": Vector3(1.07, 0.95, 1.02),
	&"square": Vector3(1.05, 0.98, 1.0),
	&"oval": Vector3(0.92, 1.05, 0.97),
	&"angular": Vector3(0.95, 1.0, 0.96),
}
const SHOES: Color = Color("#17181B")
## Liseré émissif des tenues « tech » (≤ 1,5, désaturé, loin du visage).
const OUTFIT_GLOW: Color = Color(0.17, 0.43, 0.47) * 1.1


static func apply(rig: PassengerRig, app: PassengerAppearance) -> void:
	if rig == null or app == null:
		return
	var skin: Color = GreyboxStyle.skin_color(app)
	var pal: PackedColorArray = GreyboxStyle.palette(app)
	var rim: float = 0.7 if rig.rim_enabled else 0.0
	var outfit: int = GreyboxStyle.outfit_index(app)
	var mat: ShaderMaterial = rig.body_material
	mat.set_shader_parameter(&"zones", PassengerRig.zone_texture(OUTFIT_SKINS[outfit]))
	mat.set_shader_parameter(&"skin_color", skin)
	mat.set_shader_parameter(&"top_color", garment(pal[0], 0.5))
	mat.set_shader_parameter(&"bottom_color", garment(pal[1], 0.34))
	mat.set_shader_parameter(&"accent_color", garment(pal[2], 0.6))
	mat.set_shader_parameter(&"shoes_color", SHOES.lerp(pal[1], 0.25))
	mat.set_shader_parameter(&"hair_color", _scalp_color(app, skin))
	mat.set_shader_parameter(&"rim_strength", rim)
	rig.skin_material.set_shader_parameter(&"albedo", skin)
	rig.skin_material.set_shader_parameter(&"rim_strength", rim)

	rig.scale = Vector3.ONE * GreyboxStyle.height_scale(app)
	var shape: StringName = GreyboxStyle.face_shape(app)
	var head_shape: Vector3 = FACE_SHAPES.get(shape, Vector3.ONE)
	rig.set_proportions(GreyboxStyle.silhouette_scale(app), head_shape)
	_apply_face(rig, app, skin)
	_apply_hair(rig, app)
	_apply_headwear(rig, app, pal)
	_apply_outfit(rig, app, pal, outfit)
	_apply_accessory(rig, app, pal)
	# M10 : pièces fusionnées en un maillage skinné (une fois par image).
	rig.queue_parts_rebuild()


## Couleur de tissu pour le toon : les palettes (très désaturées, sombres) sont
## relevées en valeur et légèrement en saturation (plafond 0,34 : jamais de
## teinte sémantique saturée, DS) pour rester lisibles et distinctes sous la
## lampe du guichet sans devenir des aplats noirs.
static func garment(c: Color, value: float) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 1.4, 0.06, 0.34), clampf(maxf(c.v * 1.5, value), 0.2, 0.72))


## Couleur de la zone « cheveux » de la skin : chevelure, ou chaume (rasé, crête).
static func _scalp_color(app: PassengerAppearance, skin: Color) -> Color:
	var hair: Color = GreyboxStyle.hair_color(app)
	match GreyboxStyle.hair_cut(app):
		&"shaved", &"mohawk":
			return hair.lerp(skin, 0.6)
	return hair


static func _apply_face(rig: PassengerRig, app: PassengerAppearance, skin: Color) -> void:
	var half: Vector3 = PassengerRig.head_half_size()
	PassengerRig.clear(rig.head_accessory_root)
	var ears: int = GreyboxStyle.ear_variant(app)
	for ear: MeshInstance3D in [rig.ear_l, rig.ear_r]:
		var side: float = 1.0 if ear == rig.ear_l else -1.0
		match ears:
			1:
				ear.mesh = PassengerRig.box(Vector3(0.022, 0.045, 0.03))
				ear.rotation_degrees = Vector3.ZERO
			2:
				ear.mesh = PassengerRig.box(Vector3(0.026, 0.065, 0.04))
				ear.rotation_degrees = Vector3(-8, 0, 0)
			_:
				var prism: PrismMesh = PrismMesh.new()
				prism.size = Vector3(0.024, 0.07, 0.035)
				ear.mesh = prism
				ear.rotation_degrees = Vector3(0, 0, -16.0 * side)
		ear.position = Vector3((half.x + 0.008) * side, -0.04, 0.005)
	match GreyboxStyle.nose_variant(app):
		1:
			rig.nose.mesh = PassengerRig.box(Vector3(0.016, 0.026, 0.012))
		3:
			rig.nose.mesh = PassengerRig.box(Vector3(0.028, 0.034, 0.02))
		_:
			rig.nose.mesh = PassengerRig.box(Vector3(0.021, 0.03, 0.016))
	rig.nose.position = Vector3(0, -0.05, half.z + 0.008)

	var eyes: PackedColorArray = GreyboxStyle.eye_colors(app)
	rig.face_material.set_shader_parameter(&"iris_color_left", eyes[0])
	rig.face_material.set_shader_parameter(&"iris_color_right", eyes[1])
	rig.face_material.set_shader_parameter(&"lip_scale", 1.0 if GreyboxStyle.lip_variant(app) == 1 else 1.7)
	rig.face_material.set_shader_parameter(&"ink_color", Color("#100D0E").lerp(skin.darkened(0.7), 0.25))
	rig.face.position = Vector3(0, -0.045, half.z + 0.004)


static func _apply_hair(rig: PassengerRig, app: PassengerAppearance) -> void:
	PassengerRig.clear(rig.hair_root)
	var headwear: StringName = app.get_trait(PassengerAppearance.SLOT_HEADWEAR)
	if headwear == &"hood":
		return # la capuche couvre les cheveux
	var half: Vector3 = PassengerRig.head_half_size()
	var mat: ShaderMaterial = rig.make_material(GreyboxStyle.hair_color(app), 0.85)
	var root: Node3D = rig.hair_root
	var top: float = half.y
	match GreyboxStyle.hair_cut(app):
		&"long":
			rig.add_mesh(root, "Back", PassengerRig.box(Vector3(half.x * 2.1, half.y * 1.9, 0.06)), mat,
					Vector3(0, -half.y * 0.45, -half.z - 0.02))
			for side: float in [-1.0, 1.0]:
				rig.add_mesh(root, "Side", PassengerRig.box(Vector3(0.022, half.y * 1.4, half.z * 0.9)), mat,
						Vector3((half.x + 0.008) * side, -half.y * 0.45, -half.z * 0.5))
		&"bun":
			rig.add_mesh(root, "Bun", PassengerRig.sphere(0.055), mat, Vector3(0, top * 0.75, -half.z - 0.02))
		&"braids":
			for side: float in [-1.0, 1.0]:
				rig.add_mesh(root, "Braid", PassengerRig.capsule(0.022, 0.26), mat,
						Vector3((half.x - 0.01) * side, -half.y - 0.05, -half.z * 0.6))
		&"curly":
			for i: int in 7:
				var a: float = (i - 3) / 3.0
				rig.add_mesh(root, "Curl%d" % i, PassengerRig.sphere(0.05), mat,
						Vector3(a * half.x * 0.85, top - 0.01 - absf(a) * 0.035, -0.02 + (i % 2) * 0.05))
		&"mohawk":
			rig.add_mesh(root, "Crest", PassengerRig.box(Vector3(0.04, 0.07, half.z * 2.0)), mat,
					Vector3(0, top + 0.02, -0.01), Vector3(-6, 0, 0))


static func _apply_headwear(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray) -> void:
	PassengerRig.clear(rig.headwear_root)
	var root: Node3D = rig.headwear_root
	var half: Vector3 = PassengerRig.head_half_size()
	match app.get_trait(PassengerAppearance.SLOT_HEADWEAR):
		&"hood":
			var mat: ShaderMaterial = rig.make_material(pal[0].darkened(0.15), 0.9)
			rig.add_mesh(root, "Hood", PassengerRig.box(Vector3(half.x * 2.0 + 0.05, half.y * 1.5, half.z * 2.0 + 0.04)), mat,
					Vector3(0, half.y * 0.38, -0.03))
			for side: float in [-1.0, 1.0]:
				rig.add_mesh(root, "HoodSide", PassengerRig.box(Vector3(0.03, half.y * 1.9, half.z * 1.6)), mat,
						Vector3((half.x + 0.022) * side, -half.y * 0.15, -0.04))
			rig.add_mesh(root, "HoodBack", PassengerRig.box(Vector3(half.x * 2.0 + 0.05, half.y * 1.6, 0.04)), mat,
					Vector3(0, -half.y * 0.3, -half.z - 0.03))
		&"cap":
			var mat: ShaderMaterial = rig.make_material(pal[2], 0.8)
			rig.add_mesh(root, "Crown", PassengerRig.box(Vector3(half.x * 2.0 + 0.02, 0.07, half.z * 2.0 + 0.02)), mat,
					Vector3(0, half.y - 0.01, 0))
			rig.add_mesh(root, "Brim", PassengerRig.box(Vector3(half.x * 1.7, 0.012, 0.08)), mat,
					Vector3(0, half.y - 0.04, half.z + 0.04), Vector3(8, 0, 0))
		&"beanie":
			var mat: ShaderMaterial = rig.make_material(pal[2].darkened(0.2), 0.95)
			rig.add_mesh(root, "Beanie", PassengerRig.box(Vector3(half.x * 2.0 + 0.025, 0.1, half.z * 2.0 + 0.025)), mat,
					Vector3(0, half.y - 0.03, 0))
			rig.add_mesh(root, "Cuff", PassengerRig.box(Vector3(half.x * 2.0 + 0.035, 0.03, half.z * 2.0 + 0.035)), mat,
					Vector3(0, half.y - 0.085, 0))
		PassengerAppearance.VISOR_DOWN:
			_visor(rig, root, true)
		PassengerAppearance.VISOR_UP:
			_visor(rig, root, false)


## Visière opaque (D-021) : bandeau fixe autour de la tête + écran articulé au
## front. Baissée, l'écran masque les yeux et le nez ; relevée (−150°), il repose
## à plat sur le sommet du crâne, le visage est dégagé.
static func _visor(rig: PassengerRig, root: Node3D, down: bool) -> void:
	var half: Vector3 = PassengerRig.head_half_size()
	var glass: ShaderMaterial = rig.make_material(GreyboxStyle.VISOR_GLASS, 0.12, 0.7)
	var band: ShaderMaterial = rig.make_material(GreyboxStyle.WORLD_STEEL, 0.45, 0.6)
	rig.add_mesh(root, "Strap", PassengerRig.box(Vector3(half.x * 2.0 + 0.02, 0.03, half.z * 2.0 + 0.02)), band,
			Vector3(0, half.y * 0.3, 0))
	var pivot: Node3D = Node3D.new()
	pivot.name = "Visor"
	pivot.position = Vector3(0, half.y * 0.3, half.z + 0.012)
	pivot.rotation_degrees = Vector3(0.0 if down else -150.0, 0.0, 0.0)
	root.add_child(pivot)
	rig.add_mesh(pivot, "Shield", PassengerRig.box(Vector3(half.x * 2.0 + 0.03, 0.1, 0.02)), glass,
			Vector3(0, -0.06, 0.018))
	var line: ShaderMaterial = rig.make_material(GreyboxStyle.INK, 0.4)
	line.set_shader_parameter(&"emission_color", GreyboxStyle.WORLD_TEAL_DIM * 1.6)
	rig.add_mesh(pivot, "Slit", PassengerRig.box(Vector3(half.x * 1.7, 0.007, 0.004)), line, Vector3(0, -0.05, 0.03))


## Détails de tenue (repère `UpperChest`, en mètres) : col montant, liseré
## émissif (tenues « tech »).
static func _apply_outfit(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray, outfit: int) -> void:
	PassengerRig.clear(rig.outfit_root)
	var root: Node3D = rig.outfit_root
	var s: Vector3 = GreyboxStyle.silhouette_scale(app)
	var k: float = PassengerRig.BASE_SCALE
	var width: float = PassengerRig.CHEST_HALF_WIDTH * k * s.x
	var front: float = PassengerRig.CHEST_FRONT * k * s.z
	var variant: int = app.get_trait(PassengerAppearance.SLOT_PALETTE).hash() + outfit
	if (variant & 1) != 0:
		rig.add_mesh(root, "Collar", PassengerRig.cylinder(0.075, 0.1, 0.07, 8), rig.make_material(pal[0].darkened(0.25), 0.8),
				Vector3(0, 0.16, -0.01))
	if outfit % 3 == 1:
		var glow: ShaderMaterial = rig.make_material(GreyboxStyle.INK, 0.4)
		glow.set_shader_parameter(&"emission_color", OUTFIT_GLOW)
		rig.add_mesh(root, "Strip", PassengerRig.box(Vector3(0.012, 0.2, 0.01)), glow,
				Vector3(width * 0.45, -0.02, front + 0.012))


static func _apply_accessory(rig: PassengerRig, app: PassengerAppearance, pal: PackedColorArray) -> void:
	PassengerRig.clear(rig.neck_wear_root)
	var half: Vector3 = PassengerRig.head_half_size()
	var accessory: StringName = app.get_trait(PassengerAppearance.SLOT_ACCESSORY)
	match accessory:
		&"half_visor":
			var tinted: StandardMaterial3D = StandardMaterial3D.new()
			tinted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tinted.albedo_color = Color(GreyboxStyle.WORLD_TEAL_DIM, 0.35)
			tinted.roughness = 0.1
			tinted.metallic = 0.4
			rig.add_mesh(rig.head_accessory_root, "HalfVisor", PassengerRig.box(Vector3(half.x * 2.0, 0.035, 0.01)), tinted,
					Vector3(0, 0.03, half.z + 0.03))
		&"respirator_neck":
			var mat: ShaderMaterial = rig.make_material(GreyboxStyle.WORLD_STEEL, 0.45, 0.5)
			rig.add_mesh(rig.neck_wear_root, "Respirator", PassengerRig.box(Vector3(0.13, 0.05, 0.07)), mat,
					Vector3(0, 0.02, 0.07))
			var filter: ShaderMaterial = rig.make_material(pal[2].darkened(0.3), 0.6, 0.3)
			rig.add_mesh(rig.neck_wear_root, "Filter", PassengerRig.cylinder(0.028, 0.028, 0.04, 8), filter,
					Vector3(0.08, 0.02, 0.08), Vector3(0, 0, 90))
		&"scarf":
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 0.055
			torus.outer_radius = 0.11
			torus.rings = 12
			torus.ring_segments = 6
			rig.add_mesh(rig.neck_wear_root, "Scarf", torus, rig.make_material(pal[2], 0.95), Vector3(0, 0.0, 0.01),
					Vector3(8, 0, 0), Vector3(1.0, 1.5, 1.0))
		_:
			if String(accessory).begins_with("holo_tattoo_"):
				# Tatouage holo projeté (amovible, non biométrique) : liseré émissif teal désaturé.
				var n: int = String(accessory).trim_prefix("holo_tattoo_").to_int()
				var glow: StandardMaterial3D = StandardMaterial3D.new()
				glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				glow.albedo_color = GreyboxStyle.HOLO_TATTOO
				var quad: QuadMesh = QuadMesh.new()
				quad.size = Vector2(0.014 + 0.005 * n, 0.01 + 0.005 * (n % 2))
				var side: float = -1.0 if n % 2 == 1 else 1.0
				rig.add_mesh(rig.head_accessory_root, "HoloTattoo", quad, glow,
						Vector3((half.x * 0.62) * side, -0.07 + 0.01 * n, half.z + 0.006), Vector3(0, 0, 45.0 * (n % 2)))
