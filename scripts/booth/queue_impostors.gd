## File d'attente en imposteurs (ARCHITECTURE §8 bis.9, §12 ter.4 ; BOOTH_SCENE
## §11, §20).
##
## M6 : silhouette = modèle Kenney du passager posé en `idle`, simplifié à
## 400 triangles (`tools/build_passenger_impostor.gd`), orientée vers la place
## suivante.
##
## M14 (VH-1 → VH-3, B86, D-187) : **la file est vraie**. Sur
## `EventBus.queue_progressed(processed, total, upcoming)`, chaque silhouette
## est un vrai passager à venir (`QueueSilhouette` : teinte de la tenue, forme
## de coiffe, taille — jamais d'information d'anomalie). La tête de file
## (`upcoming[0]`) attend derrière le pilier (place 0) jusqu'à sa présentation
## (l'acteur animé prend sa place) ; les places 1 → 6 du zigzag montrent
## `upcoming[1 …]`, au plus `QueueSilhouette.visible_count` ; la file se vide,
## sans retour en queue. EV-06 (« Foule nerveuse ») : +3 places le long de la
## barrière (Z ≈ −7,6 → −8,2). Trois maillages (`imp_silhouette_{bare,hood,cap}`),
## donc trois `MultiMesh` (3 draws) : ce nœud porte `bare`, deux enfants portent
## `hood` et `cap`. Qualité Bas (D-074) : un seul maillage, pas de débordement.
## Avance : translation de 1,2 s et « pas » (rebond de shader, `INSTANCE_CUSTOM.x`) ;
## `reduce_motion` : ni balancement ni pas, la translation reste.
##
## Sans `queue_progressed` (démo, tests anciens, M13) : file cosmétique d'avant
## (teintes tirées de la graine du jour, retour en queue à l'infini).
class_name QueueImpostors
extends MultiMeshInstance3D

const ADVANCE_SEC: float = 1.2
const SILHOUETTE_PATH: String = "res://assets/models/passenger/imp_silhouette.res"
const SHAPE_PATHS: Dictionary[StringName, String] = {
	QueueSilhouette.SHAPE_BARE: "res://assets/models/passenger/imp_silhouette_bare.res",
	QueueSilhouette.SHAPE_HOOD: "res://assets/models/passenger/imp_silhouette_hood.res",
	QueueSilhouette.SHAPE_CAP: "res://assets/models/passenger/imp_silhouette_cap.res",
}
## Places du zigzag (hors tête de file) et places de débordement (VH-3).
const PLACES: int = 6
const OVERFLOW_PLACES: int = 3
## Désaturation de la teinte de tenue (mêlée ensuite au remplissage sombre).
const TINT_DESATURATE: float = 0.4

## Places au sol (x, z), de la tête de file (derrière le pilier) vers la queue.
@export var slots: PackedVector2Array = PackedVector2Array([
	Vector2(-1.32, -3.45), Vector2(-1.95, -4.15), Vector2(-1.40, -4.85), Vector2(-2.25, -5.55),
	Vector2(-1.55, -6.30), Vector2(-2.45, -6.95), Vector2(-2.95, -7.60),
])
## Débordement EV-06 le long de la barrière, puis point d'entrée (hors file).
@export var overflow_slots: PackedVector2Array = PackedVector2Array([
	Vector2(-3.45, -7.72), Vector2(-3.95, -7.95), Vector2(-4.45, -8.18), Vector2(-5.2, -8.4),
])
@export var tint_seed: int = 0
@export var tints: PackedColorArray = PackedColorArray([
	Color("#3B4252"), Color("#5B4A3F"), Color("#2F4A4C"), Color("#4C3A4F"), Color("#6B6355"), Color("#2E3A55"),
])

## --- File cosmétique (sans `queue_progressed`) ---
## Position (index de place, flottant) de chaque instance.
var _places: PackedFloat32Array = []
var _hidden: Array[bool] = []
var _scales: PackedFloat32Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tween: Tween = null
## Hauteur du pivot du maillage (capsule centrée : 0,85 m ; silhouette M6 : pieds à 0).
var _pivot_y: float = 0.85

## --- File réelle (M14) ---
## Vrai dès le premier `queue_progressed` du jour.
var driven: bool = false
## Dernier état reçu.
var processed: int = 0
var total: int = 0
## Passagers présentés à la vitre depuis le début du jour (tête masquée si
## `presented > processed`).
var presented: int = 0
## Débordement EV-06 actif.
var overflow: bool = false
## Silhouettes suivies : index → {sil, from, to, place, step}.
var _people: Dictionary[int, Dictionary] = {}
var _move_t: float = 1.0
var _shape_nodes: Dictionary[StringName, MultiMeshInstance3D] = {}
var _quality: int = 2


func _ready() -> void:
	_quality = clampi(Settings.graphics_quality_level(), 0, 2)
	_apply_motion()
	if not EventBus.queue_progressed.is_connected(_on_queue_progressed):
		EventBus.queue_progressed.connect(_on_queue_progressed)
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)
	if not EventBus.station_event_started.is_connected(_on_station_event_started):
		EventBus.station_event_started.connect(_on_station_event_started)
		EventBus.station_event_ended.connect(_on_station_event_ended)
	setup(tint_seed)


func _exit_tree() -> void:
	for sig: Signal in [EventBus.queue_progressed, EventBus.settings_changed, EventBus.station_event_started, EventBus.station_event_ended]:
		for c: Dictionary in sig.get_connections():
			if (c["callable"] as Callable).get_object() == self:
				sig.disconnect(c["callable"])


## (Ré)initialise la file avec une graine cosmétique (ex. graine du jour) et
## revient à la file cosmétique jusqu'au prochain `queue_progressed`.
func setup(p_seed: int) -> void:
	_rng.seed = p_seed
	driven = false
	processed = 0
	total = 0
	presented = 0
	overflow = false
	_people.clear()
	_move_t = 1.0
	var count: int = slots.size() - 1
	if multimesh == null:
		multimesh = MultiMesh.new()
	var mesh: Mesh = _load_mesh(SILHOUETTE_PATH)
	multimesh.instance_count = 0
	if mesh != null:
		multimesh.mesh = mesh
		_pivot_y = 0.0
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.instance_count = count
	for node: MultiMeshInstance3D in _shape_nodes.values():
		node.multimesh.instance_count = 0
		node.visible = false # (créés à la première file réelle qui en a besoin)
	_places.resize(count)
	_scales.resize(count)
	_hidden.clear()
	for i: int in count:
		_places[i] = float(i)
		_hidden.append(false)
		_restyle(i)
	_update()


## Masque l'imposteur de tête (l'acteur animé prend sa place).
func hide_head() -> void:
	if driven:
		presented += 1
		_refresh_driven(false)
		return
	presented += 1
	for i: int in _places.size():
		if _places[i] < 0.5:
			_hidden[i] = true
	_update()


## Avance d'une place (file cosmétique) ; l'imposteur sorti repart en queue.
## File réelle : sans effet (l'avance suit `queue_progressed`).
func advance() -> void:
	if driven:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_snap_places()
	var start: PackedFloat32Array = _places.duplicate()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		for i: int in _places.size():
			_places[i] = start[i] - t
		_update(), 0.0, 1.0, ADVANCE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_snap_places)


# --- File réelle (M14) ---------------------------------------------------------

## Nombre de places du zigzag et de débordement utilisables à ce niveau de qualité.
func capacity() -> int:
	return PLACES + (OVERFLOW_PLACES if overflow and _quality >= 1 else 0)


## Silhouettes visibles hors tête de file (VH-2) : `min(restants − 1, places)`.
func visible_queue_count() -> int:
	return QueueSilhouette.visible_count(processed, total, capacity()) if driven else -1


## Index des passagers affichés (tête comprise si elle attend encore), tests.
func shown_indices() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for index: int in _people:
		out.append(index)
	out.sort()
	return out


## Données d'une silhouette affichée (tests) : {sil, place, shape}.
func person(index: int) -> Dictionary:
	return _people.get(index, {})


## Nombre d'instances par maillage (tests, budget de draws).
func instance_counts() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	out[QueueSilhouette.SHAPE_BARE] = multimesh.instance_count
	for shape: StringName in _shape_nodes:
		var node: MultiMeshInstance3D = _shape_nodes[shape]
		out[shape] = node.multimesh.instance_count if node.visible else 0
	return out


func _on_queue_progressed(p_processed: int, p_total: int, upcoming: Array[QueueSilhouette]) -> void:
	apply_queue(p_processed, p_total, upcoming)


## Applique un état de file (signal `queue_progressed` ; appelable par les tests).
func apply_queue(p_processed: int, p_total: int, upcoming: Array[QueueSilhouette]) -> void:
	if not driven:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		driven = true
		_people.clear()
		_move_t = 1.0
	processed = p_processed
	total = p_total
	# Tête de file (index `processed`) + au plus `capacity()` silhouettes visibles.
	var visible_n: int = QueueSilhouette.visible_count(processed, total, capacity())
	var keep: Dictionary[int, QueueSilhouette] = {}
	for s: QueueSilhouette in upcoming:
		if s == null:
			continue
		var place: int = s.index - processed
		if place >= 0 and place <= visible_n:
			keep[s.index] = s
	# Positions courantes (mouvement en cours figé à l'instant présent).
	for index: int in _people:
		var p: Dictionary = _people[index]
		p["from"] = _current_place(p)
	for index: int in _people.keys():
		if not keep.has(index):
			_people.erase(index) # parti vers la vitre (acteur) ou hors file
	for index: int in keep:
		var target: float = float(index - processed)
		if _people.has(index):
			_people[index]["sil"] = keep[index]
			_people[index]["to"] = target
		else:
			# Nouvelle silhouette : arrive d'une place derrière (au plus le point d'entrée).
			_people[index] = {"sil": keep[index], "from": minf(target + 1.0, _max_place()), "to": target}
	_move_t = 0.0
	_refresh_driven(true)


func _current_place(p: Dictionary) -> float:
	var t: float = ease_in_out(_move_t)
	return lerpf(float(p["from"]), float(p["to"]), t)


static func ease_in_out(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


func _max_place() -> float:
	return float(slots.size() - 1 + overflow_slots.size())


func _process(delta: float) -> void:
	if not driven or _move_t >= 1.0:
		return
	_move_t = minf(_move_t + delta / ADVANCE_SEC, 1.0)
	_update_driven_transforms()


## Répartit les silhouettes sur les trois `MultiMesh` (formes) et pose les teintes.
func _refresh_driven(_moved: bool) -> void:
	var groups: Dictionary[StringName, Array] = {}
	for shape: StringName in QueueSilhouette.SHAPES:
		groups[shape] = []
	var indices: Array = _people.keys()
	indices.sort()
	for index: int in indices:
		var sil: QueueSilhouette = _people[index]["sil"]
		var shape: StringName = sil.shape if _quality >= 1 else QueueSilhouette.SHAPE_BARE
		(groups[shape] as Array).append(index)
		_people[index]["shape"] = shape
	for shape: StringName in QueueSilhouette.SHAPES:
		var list: Array = groups[shape]
		if shape != QueueSilhouette.SHAPE_BARE and list.is_empty() and not _shape_nodes.has(shape):
			continue
		var node: MultiMeshInstance3D = _shape_node(shape)
		var mm: MultiMesh = node.multimesh
		var mesh: Mesh = _load_mesh(SHAPE_PATHS[shape])
		if mesh != null and mm.mesh != mesh:
			mm.instance_count = 0
			mm.mesh = mesh
		if mm.instance_count != list.size():
			mm.instance_count = 0
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.instance_count = list.size()
		for k: int in list.size():
			var sil: QueueSilhouette = _people[list[k]]["sil"]
			mm.set_instance_color(k, tint_of(sil.palette_index))
			_people[list[k]]["slot"] = k
		if node != self:
			node.visible = list.size() > 0 # (ce nœud porte les deux autres : jamais masqué)
	_pivot_y = 0.0
	_update_driven_transforms()


## Teinte d'une palette de tenue : couleur principale désaturée (le shader la
## mêle au remplissage sombre). Ni visage, ni accessoire, ni implant.
static func tint_of(palette_index: int) -> Color:
	var row: Array = GreyboxStyle.PALETTES[clampi(palette_index, 0, GreyboxStyle.PALETTES.size() - 1)]
	var c: Color = Color(String(row[0]))
	var l: float = c.get_luminance()
	return c.lerp(Color(l, l, l), TINT_DESATURATE)


func _update_driven_transforms() -> void:
	var moving: bool = _move_t < 1.0
	for index: int in _people:
		var p: Dictionary = _people[index]
		if not p.has("shape"):
			continue
		var node: MultiMeshInstance3D = _shape_node(p["shape"])
		var k: int = p["slot"]
		var place: float = _current_place(p)
		var sil: QueueSilhouette = p["sil"]
		var hidden: bool = index - processed == 0 and presented > processed
		var s: float = 0.0 if hidden else 1.0 + 0.03 * sil.height_step
		var pos: Vector2 = _chain_point(place)
		var ahead: Vector2 = _chain_point(place - 0.5) - pos
		var yaw: float = atan2(ahead.x, ahead.y) if ahead.length() > 0.01 else 0.0
		node.multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(pos.x, 0.0, pos.y)))
		var walking: float = 1.0 if moving and absf(float(p["to"]) - float(p["from"])) > 0.01 else 0.0
		node.multimesh.set_instance_custom_data(k, Color(walking, float(index % 7) * 0.9, 0.0, 0.0))


## Point au sol d'une place flottante sur la chaîne zigzag → débordement → entrée.
func _chain_point(place: float) -> Vector2:
	var chain: PackedVector2Array = slots.duplicate()
	chain.append_array(overflow_slots)
	var clamped: float = clampf(place, 0.0, float(chain.size() - 1))
	var a: int = floori(clamped)
	var b: int = mini(a + 1, chain.size() - 1)
	return chain[a].lerp(chain[b], clamped - a)


## `MultiMesh` d'une forme (ce nœud pour `bare`), créé à la première utilisation.
func _shape_node(shape: StringName) -> MultiMeshInstance3D:
	if shape == QueueSilhouette.SHAPE_BARE:
		return self
	if not _shape_nodes.has(shape):
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "Queue_" + String(shape)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = material_override
		node.layers = layers
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		node.multimesh = mm
		node.visible = false
		add_child(node, false, Node.INTERNAL_MODE_FRONT)
		_shape_nodes[shape] = node
	return _shape_nodes[shape]


func _load_mesh(path: String) -> Mesh:
	return load(path) as Mesh if ResourceLoader.exists(path) else null


func _apply_motion() -> void:
	var mat: ShaderMaterial = material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"motion", 0.0 if Settings.reduce_motion else 1.0)


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_REDUCE_MOTION:
		_apply_motion()
	elif key == Settings.KEY_GRAPHICS_QUALITY:
		_quality = clampi(Settings.graphics_quality_level(), 0, 2)
		if driven:
			_refresh_driven(false)


func _on_station_event_started(plan: StationEventPlan) -> void:
	if plan != null and plan.event != null and plan.event.id == &"ev_06":
		overflow = true


func _on_station_event_ended(plan: StationEventPlan) -> void:
	if plan != null and plan.event != null and plan.event.id == &"ev_06":
		overflow = false


# --- File cosmétique ---------------------------------------------------------------

func _snap_places() -> void:
	for i: int in _places.size():
		_places[i] = roundf(_places[i])
		if _places[i] < 0.0:
			_places[i] = float(_places.size() - 1)
			_hidden[i] = false
			_restyle(i)
	_update()


func _restyle(i: int) -> void:
	_scales[i] = _rng.randf_range(0.92, 1.08)
	var tint: Color = tints[_rng.randi_range(0, tints.size() - 1)] if not tints.is_empty() else Color.GRAY
	multimesh.set_instance_color(i, tint)


func _update() -> void:
	for i: int in _places.size():
		var p: Vector2 = _point_at(_places[i])
		var s: float = 0.0 if _hidden[i] else _scales[i]
		# Face à la place suivante (vers la tête de file), MODEL_FRONT = +Z.
		var ahead: Vector2 = _point_at(_places[i] - 0.5) - p
		var yaw: float = atan2(ahead.x, ahead.y) if ahead.length() > 0.01 else 0.0
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(p.x, _pivot_y * s, p.y))
		multimesh.set_instance_transform(i, xf)
		var moving: float = 1.0 if _tween != null and _tween.is_valid() and _tween.is_running() else 0.0
		multimesh.set_instance_custom_data(i, Color(moving, 0.0, 0.0, 0.0))


func _point_at(place: float) -> Vector2:
	var clamped: float = clampf(place, 0.0, float(slots.size() - 1))
	var a: int = floori(clamped)
	var b: int = mini(a + 1, slots.size() - 1)
	return slots[a].lerp(slots[b], clamped - a)
