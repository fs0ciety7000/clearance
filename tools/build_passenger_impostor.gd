## Étape 4 du pipeline personnage M6 (BOOTH_SCENE §11, ARCHITECTURE §8 bis.9) :
## silhouette de file d'attente **cohérente avec le passager final**.
## Le modèle Kenney du rig (proportions M6 : tête réduite, cou raccourci) est
## posé sur la 1ʳᵉ image d'`idle` (figée : sortie déterministe), skinné sur CPU, puis simplifié
## (LOD meshoptimizer d'`ImporterMesh`) sous le budget de 400 triangles.
## Sortie : `res://assets/models/passenger/imp_silhouette.res` (pieds à y = 0,
## face +Z, sans squelette ; teinte par `INSTANCE_COLOR` du MultiMesh).
## M14 (B86, B87) : `imp_silhouette_{bare,hood,cap}.res` (coiffes en volumes du
## rig, ≤ 400 triangles) et `imp_guard.res` (casque, brassard marqué par
## `uv.x` = 1, ≤ 600 triangles). Aucun bagage (indice de fouille, M13 IV-1).
##
## Usage : `godot --headless --script res://tools/build_passenger_impostor.gd`
extends SceneTree

const ACTOR: String = "res://scenes/passenger/passenger_actor.tscn"
const OUT_PATH: String = "res://assets/models/passenger/imp_silhouette.res"
## M14 (VH-1, B86) : une silhouette par forme de coiffe de `QueueSilhouette`.
const SHAPE_PATH: String = "res://assets/models/passenger/imp_silhouette_%s.res"
## M14 (VH-4, B87) : Garde (casque, brassard émissif par `uv.x`).
const GUARD_PATH: String = "res://assets/models/passenger/imp_guard.res"
const MAX_TRIS: int = 400
const GUARD_MAX_TRIS: int = 600


func _initialize() -> void:
	await process_frame
	var actor: PassengerActor = (load(ACTOR) as PackedScene).instantiate()
	get_root().add_child(actor)
	actor.assign(&"impostor", 1, 1)
	# Pose figée sur la 1ʳᵉ image d'`idle` (comme le portrait) : la sortie ne
	# dépend pas du temps écoulé, l'outil est déterministe (M10).
	actor.anim_tree.active = false
	actor.anim_player.play(PassengerAnims.clip_path(&"idle"))
	actor.anim_player.seek(0.0, true)
	actor.anim_player.pause()
	for i: int in 6:
		await process_frame
	var rig: PassengerRig = actor.rig
	var skeleton: Skeleton3D = rig.skeleton
	var mi: MeshInstance3D = rig.body_mesh
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / verts.size()
	var to_actor: Transform3D = actor.global_transform.affine_inverse() * skeleton.global_transform
	var out_v: PackedVector3Array = []
	var out_n: PackedVector3Array = []
	for v: int in verts.size():
		var p: Vector3 = Vector3.ZERO
		var n: Vector3 = Vector3.ZERO
		for k: int in per:
			var w: float = weights[v * per + k]
			if w <= 0.0:
				continue
			var bind: int = bones[v * per + k]
			var bone: int = skeleton.find_bone(mi.skin.get_bind_name(bind))
			var m: Transform3D = to_actor * skeleton.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bind)
			p += (m * verts[v]) * w
			n += (m.basis * normals[v]) * w
		out_v.append(p)
		out_n.append(n.normalized())
	var min_y: float = INF
	for p: Vector3 in out_v:
		min_y = minf(min_y, p.y)
	for i: int in out_v.size():
		out_v[i].y -= min_y
	var body_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Repères des pièces (repère acteur, pieds à y = 0) : tête (conteneur des
	# coiffes du rig, mêmes dimensions que `AppearanceApplier`) et bras gauche.
	var lift: Transform3D = Transform3D(Basis(), Vector3(0, -min_y, 0))
	var head_xf: Transform3D = lift * actor.global_transform.affine_inverse() * rig.headwear_root.global_transform
	var arm_bone: int = skeleton.find_bone("LeftUpperArm")
	var arm_xf: Transform3D = lift * to_actor * skeleton.get_bone_global_pose(arm_bone)
	arm_xf.basis = arm_xf.basis.orthonormalized()
	var failures: int = 0
	# Silhouette historique (M6, planches de phase 1) puis les trois formes de
	# la file réelle (M14 VH-1) et la Garde (VH-4).
	failures += _save(OUT_PATH, _merge(_body(out_v, out_n, body_indices, MAX_TRIS), Parts.new(), false), MAX_TRIS)
	for shape: StringName in [&"bare", &"hood", &"cap"]:
		var extra: Parts = _headwear(shape, head_xf)
		var mesh: ArrayMesh = _merge(_body(out_v, out_n, body_indices, MAX_TRIS - extra.triangles()), extra)
		failures += _save(SHAPE_PATH % shape, mesh, MAX_TRIS)
	var guard: Parts = _headwear(&"helmet", head_xf)
	guard.append(_armband(arm_xf))
	var guard_body: Dictionary = _body(out_v, out_n, body_indices, GUARD_MAX_TRIS - guard.triangles())
	# Carrure de la Garde (épaules plus larges, silhouette « stocky »).
	var gv: PackedVector3Array = guard_body["vertices"]
	for i: int in gv.size():
		gv[i] = Vector3(gv[i].x * 1.08, gv[i].y * 1.02, gv[i].z * 1.06)
	guard_body["vertices"] = gv
	for i: int in guard.vertices.size():
		guard.vertices[i] = Vector3(guard.vertices[i].x * 1.08, guard.vertices[i].y * 1.02, guard.vertices[i].z * 1.06)
	failures += _save(GUARD_PATH, _merge(guard_body, guard), GUARD_MAX_TRIS)
	quit(0 if failures == 0 else 1)


## Corps simplifié (meilleur LOD sous `max_tris`) : {vertices, normals, indices}.
func _body(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, max_tris: int) -> Dictionary:
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_INDEX] = indices
	var importer: ImporterMesh = ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface)
	importer.generate_lods(25.0, 60.0, [])
	var best: PackedInt32Array = indices
	for lod: int in importer.get_surface_lod_count(0):
		var lod_indices: PackedInt32Array = importer.get_surface_lod_indices(0, lod)
		best = lod_indices
		if lod_indices.size() / 3 <= max_tris:
			break
	return {"vertices": verts, "normals": normals, "indices": best}


## Pièces ajoutées au corps (coiffe, brassard) ; `uv.x` = 1 sur le brassard
## (marque émissive du shader `impostor_silhouette`).
class Parts:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []

	func triangles() -> int:
		return indices.size() / 3

	func append(other: Parts) -> void:
		var base: int = vertices.size()
		vertices.append_array(other.vertices)
		normals.append_array(other.normals)
		uvs.append_array(other.uvs)
		for i: int in other.indices:
			indices.append(base + i)

	## Pavé `size` centré en `center`, dans le repère `xf`.
	func box(xf: Transform3D, size: Vector3, center: Vector3, mark: float = 0.0) -> void:
		var h: Vector3 = size * 0.5
		for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
			var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
			var v: Vector3 = n.cross(u)
			var c: Vector3 = center + n * absf(n.dot(h))
			var hu: float = absf(u.dot(h))
			var hv: float = absf(v.dot(h))
			var base: int = vertices.size()
			for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				vertices.append(xf * (c + u * hu * k.x + v * hv * k.y))
				normals.append((xf.basis * n).normalized())
				uvs.append(Vector2(mark, 0.0))
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


## Coiffes en volumes du rig (mêmes cotes que `AppearanceApplier._apply_headwear`).
func _headwear(shape: StringName, head: Transform3D) -> Parts:
	var parts: Parts = Parts.new()
	var half: Vector3 = PassengerRig.head_half_size()
	match shape:
		&"hood":
			parts.box(head, Vector3(half.x * 2.0 + 0.05, half.y * 1.5, half.z * 2.0 + 0.04), Vector3(0, half.y * 0.38, -0.03))
			for side: float in [-1.0, 1.0]:
				parts.box(head, Vector3(0.03, half.y * 1.9, half.z * 1.6), Vector3((half.x + 0.022) * side, -half.y * 0.15, -0.04))
			parts.box(head, Vector3(half.x * 2.0 + 0.05, half.y * 1.6, 0.04), Vector3(0, -half.y * 0.3, -half.z - 0.03))
		&"cap":
			parts.box(head, Vector3(half.x * 2.0 + 0.02, 0.07, half.z * 2.0 + 0.02), Vector3(0, half.y - 0.01, 0))
			parts.box(head, Vector3(half.x * 1.7, 0.012, 0.08), Vector3(0, half.y - 0.04, half.z + 0.04))
		&"helmet":
			# Casque de la Garde : calotte + visière baissée (jamais de visage).
			parts.box(head, Vector3(half.x * 2.0 + 0.04, half.y * 0.9, half.z * 2.0 + 0.04), Vector3(0, half.y * 0.62, -0.01))
			parts.box(head, Vector3(half.x * 2.0 + 0.03, 0.1, 0.03), Vector3(0, half.y * 0.3 - 0.06, half.z + 0.03))
	return parts


## Brassard jaune (marque émissive) autour du haut du bras gauche.
func _armband(arm: Transform3D) -> Parts:
	var parts: Parts = Parts.new()
	var segments: int = 8
	var radius: float = 0.062
	var y0: float = 0.09
	var y1: float = 0.17
	for k: int in segments:
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		var base: int = parts.vertices.size()
		var n0: Vector3 = Vector3(cos(a0), 0, sin(a0))
		var n1: Vector3 = Vector3(cos(a1), 0, sin(a1))
		for p: Array in [[n0, y0], [n1, y0], [n1, y1], [n0, y1]]:
			var n: Vector3 = p[0]
			parts.vertices.append(arm * (n * radius + Vector3(0, float(p[1]), 0)))
			parts.normals.append((arm.basis * n).normalized())
			parts.uvs.append(Vector2(1.0, 0.0))
		parts.indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	return parts


func _merge(body: Dictionary, extra: Parts, with_uv: bool = true) -> ArrayMesh:
	var parts: Parts = Parts.new()
	parts.vertices = (body["vertices"] as PackedVector3Array).duplicate()
	parts.normals = (body["normals"] as PackedVector3Array).duplicate()
	parts.uvs.resize(parts.vertices.size())
	parts.uvs.fill(Vector2.ZERO)
	parts.indices = (body["indices"] as PackedInt32Array).duplicate()
	parts.append(extra)
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = parts.vertices
	surface[Mesh.ARRAY_NORMAL] = parts.normals
	if with_uv:
		surface[Mesh.ARRAY_TEX_UV] = parts.uvs
	surface[Mesh.ARRAY_INDEX] = parts.indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


func _save(path: String, mesh_or_body: Variant, max_tris: int) -> int:
	var mesh: ArrayMesh = mesh_or_body if mesh_or_body is ArrayMesh else _merge(mesh_or_body as Dictionary, Parts.new())
	var tris: int = mesh.surface_get_array_index_len(0) / 3
	var err: Error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("%s : %d triangles (plafond %d), hauteur %.2f m (%s)" % [path.get_file(), tris, max_tris,
			mesh.get_aabb().size.y, error_string(err)])
	return 0 if err == OK and tris <= max_tris else 1
