## Implants visibles et codes portés sur le corps (M7, GDD §6 `UNDECLARED_IMPLANT`,
## LORE §8 « signes visibles », code Luciole 6) — pièces low-poly attachées aux
## os du rig M6 (`PassengerRig.implants_*`, repères en mètres) :
## - `OPT-` : iris annulaire lumineux (cyan pâle) cerclé de chrome, œil droit ;
## - `NX-` : port circulaire derrière l'oreille gauche, LED d'état ;
## - `MIL-` : plaques sombres tempe / mâchoire, œil gauche rouge mat ;
## - `KIN-` : main droite prothétique (polymère mat, jointures) ;
## - `DER-` : lignes lumineuses sous la peau du cou ; `DER-19` : carré bombé
##   sur le dos de la main ;
## - fil magenta au poignet (code 6, `magenta_thread`).
## Émissifs ≤ 1,2, désaturés, jamais sur le visage hors des yeux (lisibilité
## de la comparaison visage ↔ photo, BOOTH_SCENE §12).
class_name ImplantDecor
extends RefCounted

const OPT_GLOW: Color = Color(0.42, 0.82, 0.9)
const NX_LED: Color = Color(0.2, 0.75, 0.7)
const MIL_PLATE: Color = Color("#1A1D22")
const MIL_EYE: Color = Color(0.55, 0.05, 0.04)
const KIN_POLYMER: Color = Color("#3A414C")
const DER_GLOW: Color = Color(0.3, 0.62, 0.7)
const THREAD: Color = Color("#FF2E88") # = DS.ACCENT_MAGENTA (code des Lucioles)
const THREAD_GLOW: float = 0.55


## Familles présentes (`OPT`, `NX`…) d'une liste de codes (`OPT-3`).
static func families(implants: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = []
	for code: String in implants:
		var family: String = code.get_slice("-", 0).to_upper()
		if not family.is_empty() and not result.has(family):
			result.append(family)
	return result


## Reconstruit les pièces ; `implants` = codes visibles (`Passenger.implants`).
static func apply(rig: PassengerRig, implants: PackedStringArray, magenta_thread: bool) -> void:
	if rig == null or rig.implants_head == null:
		return
	for root: Node3D in [rig.implants_head, rig.implants_neck, rig.implants_hand]:
		PassengerRig.clear(root)
	var half: Vector3 = PassengerRig.head_half_size()
	var fams: PackedStringArray = families(implants)
	if fams.has("OPT"):
		var ring: TorusMesh = _torus(0.011, 0.018)
		rig.add_mesh(rig.implants_head, "OptIris", ring, _glow(rig, OPT_GLOW, 1.1), Vector3(-0.041, -0.014, half.z + 0.012),
				Vector3(90, 0, 0))
		rig.add_mesh(rig.implants_head, "OptChrome", _torus(0.018, 0.023), rig.make_material(Color("#9AA4AE"), 0.25, 0.9),
				Vector3(-0.041, -0.014, half.z + 0.009), Vector3(90, 0, 0))
	if fams.has("NX"):
		rig.add_mesh(rig.implants_head, "NxPort", PassengerRig.cylinder(0.016, 0.016, 0.008, 12),
				rig.make_material(Color("#5A6472"), 0.35, 0.8), Vector3(half.x + 0.006, -0.03, -0.04), Vector3(0, 0, 90))
		rig.add_mesh(rig.implants_head, "NxLed", PassengerRig.sphere(0.0045), _glow(rig, NX_LED, 1.2),
				Vector3(half.x + 0.011, -0.03, -0.04))
	if fams.has("MIL"):
		var plate: ShaderMaterial = rig.make_material(MIL_PLATE, 0.45, 0.6)
		rig.add_mesh(rig.implants_head, "MilTemple", PassengerRig.box(Vector3(0.012, 0.04, 0.055)), plate,
				Vector3(-half.x - 0.002, 0.015, 0.035))
		rig.add_mesh(rig.implants_head, "MilJaw", PassengerRig.box(Vector3(0.012, 0.025, 0.06)), plate,
				Vector3(-half.x * 0.82, -0.09, 0.06), Vector3(0, -20, 0))
		rig.add_mesh(rig.implants_head, "MilEye", PassengerRig.cylinder(0.012, 0.012, 0.004, 12), _glow(rig, MIL_EYE, 0.7),
				Vector3(0.041, -0.014, half.z + 0.01), Vector3(90, 0, 0))
	if fams.has("KIN"):
		var polymer: ShaderMaterial = rig.make_material(KIN_POLYMER, 0.5, 0.55)
		rig.add_mesh(rig.implants_hand, "KinHand", PassengerRig.box(Vector3(0.075, 0.1, 0.04)), polymer, Vector3(0, 0.055, 0.0))
		rig.add_mesh(rig.implants_hand, "KinJoint", PassengerRig.cylinder(0.03, 0.03, 0.02, 10), rig.make_material(Color("#7C8794"), 0.3, 0.9),
				Vector3(0, 0.0, 0.0))
	if fams.has("DER"):
		var glow: ShaderMaterial = _glow(rig, DER_GLOW, 1.0)
		rig.add_mesh(rig.implants_neck, "DerLine1", PassengerRig.box(Vector3(0.003, 0.065, 0.003)), glow, Vector3(0.035, 0.03, 0.05),
				Vector3(0, 0, 12))
		rig.add_mesh(rig.implants_neck, "DerLine2", PassengerRig.box(Vector3(0.003, 0.05, 0.003)), glow, Vector3(0.047, 0.025, 0.04),
				Vector3(0, 0, -8))
		if implants.has("DER-19"):
			rig.add_mesh(rig.implants_hand, "Der19", PassengerRig.box(Vector3(0.032, 0.032, 0.01)),
					rig.make_material(Color("#5B4A44"), 0.6), Vector3(0, 0.06, -0.025))
	if magenta_thread:
		rig.add_mesh(rig.implants_hand, "MagentaThread", _torus(0.036, 0.043), _glow(rig, THREAD, THREAD_GLOW), Vector3(0, -0.01, 0))


static func _torus(inner: float, outer: float) -> TorusMesh:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 16
	torus.ring_segments = 6
	return torus


static func _glow(rig: PassengerRig, color: Color, energy: float) -> ShaderMaterial:
	var mat: ShaderMaterial = rig.make_material(color.darkened(0.3), 0.4)
	mat.set_shader_parameter(&"emission_color", color * energy)
	return mat
