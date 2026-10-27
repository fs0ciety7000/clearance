## Générateur du guichet **greybox** (M4) : `res://scenes/booth/booth.tscn`.
##
## Usage : `godot --headless --script res://tools/build_booth_greybox.gd`
## Construit la scène en code (primitives, matériaux aux couleurs du DS et de
## la palette monde, BOOTH_SCENE §2–§6, §14) puis la sauvegarde (Godot 4.7 tire des
## `unique_id` de nœuds au hasard : régénérer seulement pour modifier le décor). Les noms de nœuds sont contractuels
## (ARCHITECTURE §8 bis.1) ; positions = valeurs de départ de BOOTH_SCENE.
## En M6 le décor est remplacé par le kit modulaire (le contrat de nœuds reste).
extends SceneTree

const OUT_PATH: String = "res://scenes/booth/booth.tscn"
const DIRECTOR: String = "res://scripts/booth/booth_director.gd"
const QUEUE: String = "res://scripts/booth/queue_impostors.gd"
const GLASS_SHADER: String = "res://assets/shaders/booth_glass.gdshader"
const RAIN_SHADER: String = "res://assets/shaders/rain_sheet.gdshader"
const IMPOSTOR_SHADER: String = "res://assets/shaders/impostor_silhouette.gdshader"
const FONT_DISPLAY: String = "res://assets/fonts/ChakraPetch-Bold.ttf"
const FONT_MONO: String = "res://assets/fonts/JetBrainsMono-Variable.ttf"

# Palette (DS + palette monde, BOOTH_SCENE §5.1).
const BG_VOID: Color = Color("#07080C")
const BG_PANEL: Color = Color("#0E1118")
const BG_ELEVATED: Color = Color("#161B26")
const YELLOW: Color = Color("#FFE600")
const CYAN: Color = Color("#00E5FF")
const TEAL_DIM: Color = Color("#2B6E78")
const ROSE_DIM: Color = Color("#7E3A5C")
const STEEL: Color = Color("#3A4556")
const RAIN: Color = Color("#4E5868")
const KEY: Color = Color("#E8F1F5")
const SPILL: Color = Color("#C9B85A")

var booth: Node3D = null


func _initialize() -> void:
	await process_frame # autoloads (EventBus…) enregistrés avant de charger les scripts
	booth = Node3D.new()
	booth.name = "Booth"
	booth.set_script(load(DIRECTOR))
	_environment()
	_camera()
	_lights()
	_hall()
	_pillar()
	_background()
	_rain()
	_queue()
	_door()
	_booth_front()
	_paths()
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(booth)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_booth_greybox: %s → %s" % [OUT_PATH, error_string(err)])
	booth.free()
	quit(0 if err == OK else 1)


# --- Utilitaires -------------------------------------------------------------

func _add(parent: Node, node: Node, node_name: String, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node, true)
	node.owner = booth
	if unique:
		node.unique_name_in_owner = true
	return node


func _node(parent: Node, node_name: String, pos: Vector3 = Vector3.ZERO, unique: bool = false) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	return _add(parent, n, node_name, unique)


func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, shadows: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, mesh, pos, mat, rot_deg, shadows)


func _mesh(parent: Node, node_name: String, mesh: Mesh, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, shadows: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _add(parent, mi, node_name)


func _label(parent: Node, node_name: String, text: String, pos: Vector3, pixel_size: float, color: Color,
		font_path: String = FONT_DISPLAY, font_size: int = 96) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = pixel_size
	l.font = load(font_path)
	l.font_size = font_size
	l.outline_size = 0
	l.modulate = color
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return _add(parent, l, node_name)


func _omni(parent: Node, node_name: String, pos: Vector3, color: Color, energy: float, light_range: float,
		unique: bool = false) -> OmniLight3D:
	var o: OmniLight3D = OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.omni_attenuation = 1.2
	o.shadow_enabled = false
	return _add(parent, o, node_name, unique)


## Chemin lissé (poignées automatiques) passant par `points` (repère monde).
func _path(node_name: String, points: Array[Vector3]) -> Path3D:
	var curve: Curve3D = Curve3D.new()
	curve.bake_interval = 0.05
	for i: int in points.size():
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent: Vector3 = (next - prev) * 0.22
		var handle_in: Vector3 = -tangent if i > 0 else Vector3.ZERO
		var handle_out: Vector3 = tangent if i < points.size() - 1 else Vector3.ZERO
		curve.add_point(points[i], handle_in, handle_out)
	var path: Path3D = Path3D.new()
	path.curve = curve
	return _add(booth, path, node_name, true)


# --- Contenu -----------------------------------------------------------------

func _environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = BG_ELEVATED
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = BG_PANEL.lerp(STEEL, 0.25)
	env.fog_light_energy = 1.0
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_add(booth, we, "WorldEnvironment")


func _camera() -> void:
	var rig: Node3D = _node(booth, "CameraRig", Vector3(0, 1.55, 2.0))
	var cam: Camera3D = Camera3D.new()
	cam.fov = 14.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 40.0
	cam.current = true
	_add(rig, cam, "BoothCamera", true)


func _lights() -> void:
	var lights: Node3D = _node(booth, "Lights")
	var key: SpotLight3D = SpotLight3D.new()
	key.transform = Transform3D(Basis.looking_at(Vector3(0, 1.55, -0.6) - Vector3(0.25, 2.3, 0.4), Vector3.UP),
			Vector3(0.25, 2.3, 0.4))
	key.light_color = KEY
	key.light_energy = 3.0
	key.spot_range = 5.0
	key.spot_angle = 22.0
	key.spot_attenuation = 0.8
	key.shadow_enabled = true
	_add(lights, key, "KeyLight")
	_omni(lights, "RimLeft", Vector3(-0.9, 2.0, -1.8), TEAL_DIM, 2.2, 2.6)
	_omni(lights, "RimRight", Vector3(0.9, 2.0, -1.8), ROSE_DIM, 2.2, 2.6)
	_omni(lights, "Fill", Vector3(-1.5, 1.8, -1.0), STEEL, 0.6, 3.0)
	_omni(lights, "HalcyonSpill", Vector3(-0.8, 1.6, -2.3), SPILL, 0.6, 1.6)
	_omni(lights, "SlotGlow", Vector3(0, 1.05, -0.1), CYAN, 0.0, 0.6, true)
	_omni(lights, "GateLight", Vector3(2.2, 1.2, -0.6), Color("#2EFF9A"), 0.0, 2.0, true)
	_omni(lights, "HallTeal", Vector3(-3.0, 2.6, -6.5), TEAL_DIM, 1.5, 5.0)
	_omni(lights, "HallRose", Vector3(2.5, 2.6, -6.0), ROSE_DIM, 1.5, 5.0)


func _hall() -> void:
	var hall: Node3D = _node(booth, "Hall")
	var floor_mat: StandardMaterial3D = _mat(Color("#10141B"), 0.16, 0.75)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(16, 14)
	_mesh(hall, "Floor", plane, Vector3(0, 0, -5.5), floor_mat)
	var wall_mat: StandardMaterial3D = _mat(Color("#0C0F15"), 0.9)
	_box(hall, "BackWall", Vector3(16, 6, 0.3), Vector3(0, 3, -10.0), wall_mat)
	_box(hall, "LeftWall", Vector3(0.3, 6, 12), Vector3(-6.5, 3, -4.5), wall_mat)
	_box(hall, "RightWall", Vector3(0.3, 6, 12), Vector3(7.5, 3, -4.5), wall_mat)
	_box(hall, "Ceiling", Vector3(16, 0.3, 7.5), Vector3(0, 3.3, -3.2), _mat(Color("#0A0C11"), 0.9))
	# Bord de l'auvent (au-delà : pluie) et plafonniers acier.
	_box(hall, "CanopyEdge", Vector3(16, 0.25, 0.25), Vector3(0, 3.05, -7.0), _mat(Color("#141922"), 0.6, 0.5))
	for i: int in 4:
		_box(hall, "CeilingLight%d" % i, Vector3(1.6, 0.04, 0.12), Vector3(-3.0 + i * 2.0, 3.12, -2.5 - (i % 2) * 2.2),
				_emissive(STEEL.lightened(0.3), 2.0))
	# Néons d'ambiance (teintes monde désaturées) : tubes muraux.
	_box(hall, "NeonTealTube", Vector3(0.04, 1.8, 0.04), Vector3(-4.8, 1.9, -8.6), _emissive(TEAL_DIM, 5.0))
	_box(hall, "NeonTealTube2", Vector3(2.6, 0.035, 0.035), Vector3(-4.0, 2.85, -8.6), _emissive(TEAL_DIM, 5.0))
	_box(hall, "NeonRoseTube", Vector3(2.2, 0.03, 0.03), Vector3(4.9, 1.45, -8.7), _emissive(ROSE_DIM, 5.0))
	_box(hall, "NeonRoseTube2", Vector3(2.2, 0.03, 0.03), Vector3(4.9, 0.95, -8.7), _emissive(ROSE_DIM, 5.0))


func _pillar() -> void:
	var pillar: Node3D = _node(booth, "Pillar", Vector3(-1.1, 0, -2.6))
	_box(pillar, "PillarBody", Vector3(0.5, 3.3, 0.5), Vector3(0, 1.65, 0), _mat(Color("#12161E"), 0.6, 0.3), Vector3.ZERO, true)
	_box(pillar, "SignPanel", Vector3(0.3, 1.25, 0.03), Vector3(0, 1.58, 0.26), _mat(Color("#0A0B0E"), 0.4))
	_box(pillar, "SignEdgeL", Vector3(0.012, 1.25, 0.02), Vector3(-0.15, 1.58, 0.28), _emissive(YELLOW, 2.2))
	_box(pillar, "SignEdgeR", Vector3(0.012, 1.25, 0.02), Vector3(0.15, 1.58, 0.28), _emissive(YELLOW, 2.2))
	_label(pillar, "SignHalcyon", "H\nA\nL\nC\nY\nO\nN", Vector3(0, 1.58, 0.285), 0.00105,
			Color(YELLOW.r * 1.6, YELLOW.g * 1.6, YELLOW.b, 1.0), FONT_DISPLAY, 112)
	# Affiches usées.
	_box(pillar, "Poster", Vector3(0.3, 0.42, 0.01), Vector3(0.255, 1.35, 0.05), _mat(Color("#2A2E36"), 0.95),
			Vector3(0, 90, 0))


func _background() -> void:
	var bg: Node3D = _node(booth, "Background")
	# Grande enseigne HALCYON (marque Consortium) au fond, dans le champ.
	_label(bg, "NeonHalcyon", "HALCYON", Vector3(1.9, 2.5, -8.8), 0.0045,
			Color(YELLOW.r * 2.2, YELLOW.g * 2.2, YELLOW.b * 0.6, 1.0), FONT_DISPLAY, 128)
	_label(bg, "NeonHalcyonSub", "GATE · ANNEAU A", Vector3(1.9, 2.2, -8.8), 0.0022,
			Color(YELLOW.r * 1.2, YELLOW.g * 1.2, 0.2, 1.0), FONT_DISPLAY, 96)
	# Écran des départs (décor : teal désaturé).
	_box(bg, "DeparturesFrame", Vector3(2.4, 1.0, 0.08), Vector3(-3.4, 2.05, -8.85), _mat(Color("#0B0E13"), 0.5, 0.3))
	_box(bg, "DeparturesScreen", Vector3(2.25, 0.86, 0.02), Vector3(-3.4, 2.05, -8.8), _emissive(TEAL_DIM.darkened(0.55), 1.4))
	_label(bg, "DeparturesText", "DÉPARTS  ·  NAVETTES\nTYC-07   TYCHO        QUAI 3\nHAL-12   ANNEAU B     QUAI 1\nTER-03   LAGRANGE 4   QUAI 5",
			Vector3(-3.4, 2.05, -8.78), 0.0022, Color(TEAL_DIM.r * 2.6, TEAL_DIM.g * 2.6, TEAL_DIM.b * 2.6, 1.0),
			FONT_MONO, 64)
	# Enseigne « TRANSIT·7 » en rose monde (BOOTH_SCENE §5.1).
	_label(bg, "NeonTransit", "TRANSIT·7", Vector3(-5.0, 1.25, -8.6), 0.0035,
			Color(ROSE_DIM.r * 3.0, ROSE_DIM.g * 3.0, ROSE_DIM.b * 3.0, 1.0), FONT_DISPLAY, 96)
	# Panneau du guichet (droite) en acier monde.
	_box(bg, "BoothSignFrame", Vector3(2.0, 0.42, 0.06), Vector3(4.9, 1.2, -8.8), _mat(Color("#0B0E13"), 0.5, 0.3))
	_label(bg, "BoothSign", "CONTRÔLE · GUICHET 04", Vector3(4.9, 1.2, -8.75), 0.0024,
			Color(STEEL.r * 3.2, STEEL.g * 3.2, STEEL.b * 3.2, 1.0), FONT_DISPLAY, 96)
	# Silhouettes de la ville au-delà du quai.
	var city: StandardMaterial3D = _mat(Color("#090B10"), 1.0)
	for i: int in 7:
		var h: float = 3.0 + float((i * 37) % 5) * 0.9
		_box(bg, "Tower%d" % i, Vector3(1.6, h, 1.0), Vector3(-6.0 + i * 2.1, h * 0.5 + 0.2, -13.0 - (i % 3)), city)
		_box(bg, "TowerLight%d" % i, Vector3(0.9, 0.03, 0.02), Vector3(-6.0 + i * 2.1, h * 0.6, -12.48 - (i % 3)),
				_emissive(TEAL_DIM if i % 2 == 0 else ROSE_DIM, 3.0))


func _rain() -> void:
	var rain: Node3D = _node(booth, "Rain")
	var shader: Shader = load(RAIN_SHADER)
	var params: Array[Array] = [[-7.4, 1.4, 0.0, 0.32], [-8.2, 1.9, 3.0, 0.26], [-11.0, 2.4, 7.0, 0.22]]
	for i: int in params.size():
		var p: Array = params[i]
		var z: float = p[0]
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"color", RAIN.lightened(0.15))
		mat.set_shader_parameter(&"speed", p[1])
		mat.set_shader_parameter(&"seed", p[2])
		mat.set_shader_parameter(&"intensity", p[3])
		mat.set_shader_parameter(&"columns", 160.0 + i * 40.0)
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(18, 6)
		_mesh(rain, "RainSheet%d" % i, quad, Vector3(0, 3.0, z), mat)


func _queue() -> void:
	var q: Node3D = _node(booth, "Queue")
	var post_mat: StandardMaterial3D = _mat(Color("#2A303B"), 0.35, 0.8)
	var belt_mat: StandardMaterial3D = _mat(Color("#3A2F45"), 0.7)
	var posts: Array[Vector2] = [Vector2(-1.0, -3.9), Vector2(-2.6, -3.9), Vector2(-1.0, -5.2), Vector2(-2.6, -5.2),
			Vector2(-1.0, -6.6), Vector2(-2.6, -6.6)]
	var post_mesh: CylinderMesh = CylinderMesh.new()
	post_mesh.top_radius = 0.03
	post_mesh.bottom_radius = 0.03
	post_mesh.height = 1.0
	for i: int in posts.size():
		_mesh(q, "Post%d" % i, post_mesh, Vector3(posts[i].x, 0.5, posts[i].y), post_mat)
	_box(q, "Belt0", Vector3(1.6, 0.05, 0.01), Vector3(-1.8, 0.95, -3.9), belt_mat)
	_box(q, "Belt1", Vector3(1.6, 0.05, 0.01), Vector3(-1.8, 0.95, -5.2), belt_mat)
	_box(q, "Belt2", Vector3(1.6, 0.05, 0.01), Vector3(-1.8, 0.95, -6.6), belt_mat)
	var mm: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm.set_script(load(QUEUE))
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 1.7
	capsule.radial_segments = 12
	capsule.rings = 4
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = capsule
	mm.multimesh = multimesh
	var imat: ShaderMaterial = ShaderMaterial.new()
	imat.shader = load(IMPOSTOR_SHADER)
	mm.material_override = imat
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(booth, mm, "QueueImpostors", true)


func _door() -> void:
	var door: Node3D = _node(booth, "StationDoor", Vector3(2.3, 0, -0.4))
	var frame: StandardMaterial3D = _mat(Color("#1B212C"), 0.4, 0.7)
	_box(door, "FrameL", Vector3(0.12, 2.4, 0.2), Vector3(-0.55, 1.2, 0), frame)
	_box(door, "FrameR", Vector3(0.12, 2.4, 0.2), Vector3(0.55, 1.2, 0), frame)
	_box(door, "FrameTop", Vector3(1.22, 0.12, 0.2), Vector3(0, 2.4, 0), frame)
	_box(door, "Turnstile", Vector3(0.9, 0.9, 0.08), Vector3(0, 0.6, 0), _mat(Color("#20262F"), 0.5, 0.5))


func _booth_front() -> void:
	var front: Node3D = _node(booth, "BoothFront")
	var metal: StandardMaterial3D = _mat(Color("#1A1F28"), 0.35, 0.85)
	var dark_metal: StandardMaterial3D = _mat(Color("#0F1218"), 0.5, 0.7)
	# Vitre (sans collision, BOOTH_SCENE §4).
	var glass_mat: ShaderMaterial = ShaderMaterial.new()
	glass_mat.shader = load(GLASS_SHADER)
	glass_mat.set_shader_parameter(&"aspect", 2.4 / 1.4)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.4, 1.4)
	var glass: MeshInstance3D = _mesh(front, "Glass", quad, Vector3(0, 1.7, 0), glass_mat)
	glass.unique_name_in_owner = true
	glass.sorting_offset = 1.0
	# Cadre métal (montants latéraux visibles aux bords de la bande).
	_box(front, "FrameLeft", Vector3(0.14, 1.6, 0.16), Vector3(-1.27, 1.7, 0), metal)
	_box(front, "FrameRight", Vector3(0.14, 1.6, 0.16), Vector3(1.27, 1.7, 0), metal)
	_box(front, "FrameTop", Vector3(2.68, 0.14, 0.16), Vector3(0, 2.44, 0), metal)
	_box(front, "FrameBottom", Vector3(2.68, 0.1, 0.18), Vector3(0, 0.98, 0), metal)
	for side: float in [-1.0, 1.0]:
		for j: int in 4:
			_box(front, "Rivet", Vector3(0.018, 0.018, 0.01), Vector3(1.27 * side, 1.2 + j * 0.38, 0.085),
					_mat(Color("#3A4250"), 0.3, 0.9))
	# Hygiaphone : disque perforé + anneau LED (cyan quand le passager parle).
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.012
	# Côté agent peu éclairé : légère émission pour lire la matière (pas un trou noir).
	var plate: StandardMaterial3D = _mat(Color("#3A4250"), 0.55, 0.25)
	plate.emission_enabled = true
	plate.emission = STEEL
	plate.emission_energy_multiplier = 0.35
	_mesh(front, "Hygiaphone", disc, Vector3(-0.4, 1.38, 0.01), plate, Vector3(90, 0, 0))
	for k: int in 3:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.016 + k * 0.022
		ring.outer_radius = ring.inner_radius + 0.007
		_mesh(front, "HygiaphoneRing%d" % k, ring, Vector3(-0.4, 1.38, 0.017), _mat(Color("#05070A"), 0.9),
				Vector3(90, 0, 0))
	var led: TorusMesh = TorusMesh.new()
	led.inner_radius = 0.088
	led.outer_radius = 0.097
	_mesh(front, "HygiaphoneLed", led, Vector3(-0.4, 1.38, 0.016), _emissive(CYAN, 0.9), Vector3(90, 0, 0))
	# Fente à documents (hors champ) et comptoir de l'agent.
	_box(front, "DocumentSlot", Vector3(0.42, 0.05, 0.3), Vector3(0, 1.02, 0), dark_metal)
	_box(front, "Counter", Vector3(2.8, 0.06, 0.9), Vector3(0, 0.95, 0.55), _mat(Color("#141821"), 0.4, 0.4))
	_box(front, "PassengerShelf", Vector3(1.4, 0.05, 0.35), Vector3(0, 1.0, -0.2), metal)


func _paths() -> void:
	_path("ArrivalPath", [Vector3(-1.27, 0, -3.3), Vector3(-0.9, 0, -2.0), Vector3(-0.35, 0, -1.05), Vector3(0, 0, -0.6)])
	var desk: Marker3D = Marker3D.new()
	desk.position = Vector3(0, 0, -0.6)
	_add(booth, desk, "DeskMark", true)
	var approved: Path3D = _path("ExitApprovedPath", [Vector3(0, 0, -0.6), Vector3(0.7, 0, -0.85), Vector3(1.5, 0, -0.7),
			Vector3(2.3, 0, -0.4), Vector3(2.8, 0, 0.3)])
	var refused: Path3D = _path("ExitRefusedPath", [Vector3(0, 0, -0.6), Vector3(-0.45, 0, -1.4), Vector3(-1.0, 0, -2.4),
			Vector3(-1.55, 0, -3.1), Vector3(-2.6, 0, -4.5)])
	var clear_a: Marker3D = Marker3D.new()
	clear_a.position = Vector3(0.7, 0, -0.85)
	_add(approved, clear_a, "ClearMark")
	var clear_r: Marker3D = Marker3D.new()
	clear_r.position = Vector3(-0.25, 0, -1.15)
	_add(refused, clear_r, "ClearMark")
	var look: Marker3D = Marker3D.new()
	look.position = Vector3(0, 1.40, 0)
	look.rotation_degrees = Vector3(0, 180, 0)
	_add(booth, look, "LookTargetPlane", true)
	_node(booth, "PassengerSlots", Vector3.ZERO, true)
