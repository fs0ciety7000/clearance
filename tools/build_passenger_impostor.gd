## Étape 4 du pipeline personnage M6 (BOOTH_SCENE §11, ARCHITECTURE §8 bis.9) :
## silhouette de file d'attente **cohérente avec le passager final**.
## Le modèle Kenney du rig (proportions M6 : tête réduite, cou raccourci) est
## posé sur la 1ʳᵉ image d'`idle`, skinné sur CPU, puis simplifié
## (LOD meshoptimizer d'`ImporterMesh`) sous le budget de 400 triangles.
## Sortie : `res://assets/models/passenger/imp_silhouette.res` (pieds à y = 0,
## face +Z, sans squelette ni UV ; teinte par `INSTANCE_COLOR` du MultiMesh).
##
## Usage : `godot --headless --script res://tools/build_passenger_impostor.gd`
extends SceneTree

const ACTOR: String = "res://scenes/passenger/passenger_actor.tscn"
const OUT_PATH: String = "res://assets/models/passenger/imp_silhouette.res"
const MAX_TRIS: int = 400


func _initialize() -> void:
	await process_frame
	var actor: PassengerActor = (load(ACTOR) as PackedScene).instantiate()
	get_root().add_child(actor)
	actor.assign(&"impostor", 1, 1)
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
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = out_v
	surface[Mesh.ARRAY_NORMAL] = out_n
	surface[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var importer: ImporterMesh = ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface)
	importer.generate_lods(25.0, 60.0, [])
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var best: PackedInt32Array = indices
	for lod: int in importer.get_surface_lod_count(0):
		var lod_indices: PackedInt32Array = importer.get_surface_lod_indices(0, lod)
		if lod_indices.size() / 3 <= MAX_TRIS:
			best = lod_indices
			break
		best = lod_indices
	surface[Mesh.ARRAY_INDEX] = best
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	var err: Error = ResourceSaver.save(mesh, OUT_PATH, ResourceSaver.FLAG_COMPRESS)
	print("imp_silhouette.res : %d → %d triangles, hauteur %.2f m (%s)" % [indices.size() / 3, best.size() / 3,
			mesh.get_aabb().size.y, error_string(err)])
	quit(0 if err == OK else 1)
