## Garde-fous de l'acteur et du rendu greybox (ARCHITECTURE §12) :
## clips + marqueurs de la bibliothèque `passenger`, arbre d'animation,
## application de toutes les options d'apparence, atlas d'expressions,
## PortraitService (cache, fallback headless).
extends GutTest

const ACTOR_SCENE: PackedScene = preload("res://scenes/passenger/passenger_actor.tscn")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")


func _method_keys(anim: Animation) -> Array[Array]:
	var keys: Array[Array] = []
	for t: int in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_METHOD:
			continue
		for k: int in anim.track_get_key_count(t):
			var value: Dictionary = anim.track_get_key_value(t, k)
			var args: Array = value["args"]
			var method: StringName = value["method"]
			keys.append([anim.track_get_key_time(t, k), method, args[0]])
	return keys


func test_library_has_all_clips() -> void:
	var lib: AnimationLibrary = PassengerAnims.load_library()
	for clip: StringName in PassengerAnims.CLIPS:
		assert_true(lib.has_animation(clip), "clip %s" % clip)
	assert_eq(lib.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation(&"idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation(&"present_documents").loop_mode, Animation.LOOP_NONE)


func test_present_documents_carries_documents_slot_marker() -> void:
	var anim: Animation = PassengerAnims.load_library().get_animation(&"present_documents")
	var found: bool = false
	for key: Array in _method_keys(anim):
		var marker: StringName = key[2]
		if marker == PassengerAnims.DOCUMENTS_SLOT:
			found = true
			var time: float = key[0]
			var method: StringName = key[1]
			assert_almost_eq(time, PassengerAnims.DOCUMENTS_SLOT_TIME, 0.001)
			assert_eq(method, PassengerAnims.MARKER_METHOD)
	assert_true(found, "repère documents_slot (BOOTH_SCENE §7.3)")
	var visor: Array[Array] = _method_keys(PassengerAnims.load_library().get_animation(&"remove_visor"))
	assert_eq(visor.size(), 1)
	var visor_marker: StringName = visor[0][2]
	assert_eq(visor_marker, PassengerAnims.VISOR_OFF)


func test_tree_structure() -> void:
	var tree: AnimationNodeBlendTree = PassengerAnims.build_tree()
	for node_name: StringName in [&"Main", &"TalkBlend", &"Reaction", &"ReactionSelect", &"talk"]:
		assert_true(tree.has_node(node_name), String(node_name))
	var main: AnimationNodeStateMachine = tree.get_node(&"Main")
	for state: StringName in [&"walk", &"idle", &"present_documents", &"leave"]:
		assert_true(main.has_node(state), String(state))
	assert_true(main.has_transition(&"present_documents", &"idle"))
	assert_true(main.has_transition(&"leave", &"walk"))


func test_actor_instantiates_with_pool_api() -> void:
	var actor: PassengerActor = ACTOR_SCENE.instantiate()
	add_child_autofree(actor)
	assert_true(actor.is_free())
	assert_false(actor.visible)
	assert_true(actor.anim_tree.active)
	assert_true(actor.anim_player.has_animation(PassengerAnims.clip_path(&"present_documents")))
	actor.assign(&"c1", 1, 42)
	assert_false(actor.is_free())
	assert_true(actor.visible)
	actor.release()
	assert_true(actor.is_free())


func test_documents_slot_locked_once_per_case() -> void:
	var actor: PassengerActor = ACTOR_SCENE.instantiate()
	add_child_autofree(actor)
	actor.assign(&"c1", 1, 1)
	watch_signals(actor)
	actor._on_anim_marker(PassengerAnims.DOCUMENTS_SLOT)
	actor._on_anim_marker(PassengerAnims.DOCUMENTS_SLOT)
	assert_signal_emit_count(actor, "anim_event", 1)
	actor.assign(&"c2", 2, 2)
	actor._on_anim_marker(PassengerAnims.DOCUMENTS_SLOT)
	assert_signal_emit_count(actor, "anim_event", 2)


func test_every_catalog_option_applies() -> void:
	var rig: PassengerRig = PassengerRig.new()
	add_child_autofree(rig)
	var catalog: AppearanceCatalog = Gen.data().appearance_catalog
	var base: PassengerAppearance = PassengerAppearance.new()
	for slot: AppearanceSlotDef in catalog.slots:
		base.traits[slot.id] = slot.options[0].id
	for slot: AppearanceSlotDef in catalog.slots:
		for option: AppearanceOptionDef in slot.options:
			var app: PassengerAppearance = base.derive({slot.id: option.id})
			app.palette_id = app.get_trait(PassengerAppearance.SLOT_PALETTE)
			app.age_band = 2
			app.height_step = 2
			AppearanceApplier.apply(rig, app)
	assert_almost_eq(rig.scale.y, 1.06, 0.0001, "±3 % par pas de taille")
	var visor: PassengerAppearance = base.derive({PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN})
	AppearanceApplier.apply(rig, visor)
	assert_not_null(rig.headwear_root.get_node_or_null(^"Visor"))
	AppearanceApplier.apply(rig, visor.without_visor())
	var raised: Node3D = rig.headwear_root.get_node_or_null(^"Visor")
	assert_not_null(raised)
	assert_lt(raised.rotation_degrees.x, -30.0, "visière relevée")
	# Les accessoires remplacés sont libérés par `queue_free` : une image pour
	# qu'ils ne soient pas comptés comme orphelins (QA-016).
	await wait_process_frames(1)


func test_face_atlas_cells_all_drawn() -> void:
	var img: Image = FaceAtlas.build_image()
	assert_eq(img.get_size(), Vector2i(FaceAtlas.SIZE, FaceAtlas.SIZE))
	for cell: int in 16:
		var covered: int = 0
		var origin: Vector2i = Vector2i((cell % 4) * FaceAtlas.CELL, (cell >> 2) * FaceAtlas.CELL)
		for y: int in range(0, FaceAtlas.CELL, 2):
			for x: int in range(0, FaceAtlas.CELL, 2):
				if img.get_pixelv(origin + Vector2i(x, y)).a > 0.5:
					covered += 1
		assert_gt(covered, 20, "cellule %d dessinée" % cell)


func test_expression_ids_known() -> void:
	for id: StringName in [&"neutral", &"blink", &"talk_a", &"talk_b", &"nervous", &"angry", &"relieved",
			&"suspicious", &"contempt", &"sad", &"wink"]:
		assert_true(ExpressionController.EXPRESSIONS.has(id), String(id))


func test_portrait_service_cache_and_headless_fallback() -> void:
	var service: PortraitService = PortraitService.new()
	add_child_autofree(service)
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(1), Gen.day_seed(0, 1))
	var a: PassengerAppearance = builder.build(0).case.passenger_presented.appearance
	var b: PassengerAppearance = builder.build(1).case.passenger_presented.appearance
	var tex_a: Texture2D = service.get_portrait(a)
	assert_not_null(tex_a)
	assert_eq(Vector2i(tex_a.get_size()), PortraitService.SIZE)
	assert_same(service.get_portrait(a.copy()), tex_a, "cache par signature")
	assert_ne(service.get_portrait(b), tex_a)
	assert_eq(service.cache_size(), 2)
	var provider: Callable = service.get_portrait
	var provided: Texture2D = provider.call(a)
	assert_same(provided, tex_a, "contrat Callable portrait_provider")
	assert_null(service.get_portrait(null))
	service.clear_cache()
	assert_eq(service.cache_size(), 0)


# --- M6 : passager final (rig Kenney + clips Quaternius UAL) -----------------

func _marker_names(anim: Animation) -> Array[StringName]:
	var names: Array[StringName] = []
	for key: Array in _method_keys(anim):
		var marker: StringName = key[2]
		names.append(marker)
	return names


func test_imported_library_has_nine_clips_bones_and_markers() -> void:
	assert_true(ResourceLoader.exists(PassengerAnims.LIBRARY_PATH), "passenger_anims.res construite")
	var lib: AnimationLibrary = load(PassengerAnims.LIBRARY_PATH) as AnimationLibrary
	assert_eq(lib.get_animation_list().size(), 9)
	for clip: StringName in PassengerAnims.CLIPS:
		var anim: Animation = lib.get_animation(clip)
		assert_not_null(anim, String(clip))
		var bone_tracks: int = 0
		for t: int in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				assert_true(String(anim.track_get_path(t)).begins_with(PassengerAnims.SKELETON_PATH + ":"))
				bone_tracks += 1
		assert_gt(bone_tracks, 15, "%s : pistes d'os retargetées" % clip)
	assert_true(_marker_names(lib.get_animation(&"walk")).has(&"footstep_l"))
	assert_true(_marker_names(lib.get_animation(&"walk")).has(&"footstep_r"))
	assert_true(_marker_names(lib.get_animation(&"leave")).has(&"footstep_l"))
	assert_true(_marker_names(lib.get_animation(&"react_angry")).has(&"glass_hit"))
	assert_true(_marker_names(lib.get_animation(&"remove_visor")).has(PassengerAnims.VISOR_OFF))
	var present: Animation = lib.get_animation(&"present_documents")
	assert_almost_eq(present.length, 1.2, 0.01)
	for key: Array in _method_keys(present):
		if key[2] == PassengerAnims.DOCUMENTS_SLOT:
			var at: float = key[0]
			assert_almost_eq(at, 0.75, 0.001)
	assert_eq(lib.get_animation(&"talk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation(&"leave").loop_mode, Animation.LOOP_NONE)
	assert_gt(PassengerAnims.walk_v_ref(), 0.3, "v_ref mesurée")
	assert_lt(PassengerAnims.walk_v_ref(), 1.5)


func test_tracks_resolve_on_actor_skeleton() -> void:
	var actor: PassengerActor = ACTOR_SCENE.instantiate()
	add_child_autofree(actor)
	var skeleton: Skeleton3D = actor.get_node(NodePath(PassengerAnims.SKELETON_PATH)) as Skeleton3D
	assert_not_null(skeleton, "Visual/Armature/Skeleton3D")
	var walk: Animation = actor.anim_player.get_animation(PassengerAnims.clip_path(&"walk"))
	for t: int in walk.get_track_count():
		var path: NodePath = walk.track_get_path(t)
		if walk.track_get_type(t) == Animation.TYPE_METHOD:
			continue
		assert_gt(skeleton.find_bone(String(path.get_concatenated_subnames())), -1, String(path))
	for bone: String in ["Hips", "Neck", "Head", "RightHand"]:
		assert_gt(skeleton.find_bone(bone), -1, bone)
	assert_eq(actor.rig.head_look.bone_name, "Head")
	assert_eq(actor.rig.neck_look.bone_name, "Neck")
	assert_eq(actor.rig.head_look.target_node, actor.rig.head_look.get_path_to(actor.look_target))


func test_two_appearances_render_differently() -> void:
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(3), Gen.day_seed(0, 3))
	var a: PassengerAppearance = builder.build(0).case.passenger_presented.appearance
	var b: PassengerAppearance = a.derive({&"outfit": &"outfit_02" if a.get_trait(&"outfit") != &"outfit_02" else &"outfit_05",
			PassengerAppearance.SLOT_PALETTE: &"palette_03" if a.get_trait(&"palette") != &"palette_03" else &"palette_08",
			&"skin": &"skin_06" if a.get_trait(&"skin") != &"skin_06" else &"skin_02"})
	b.palette_id = b.get_trait(PassengerAppearance.SLOT_PALETTE)
	var rig_a: PassengerRig = PassengerRig.new()
	var rig_b: PassengerRig = PassengerRig.new()
	add_child_autofree(rig_a)
	add_child_autofree(rig_b)
	AppearanceApplier.apply(rig_a, a)
	AppearanceApplier.apply(rig_b, b)
	assert_ne(rig_a.body_material, rig_b.body_material, "un matériau par acteur")
	for param: StringName in [&"top_color", &"skin_color"]:
		var ca: Color = rig_a.body_material.get_shader_parameter(param)
		var cb: Color = rig_b.body_material.get_shader_parameter(param)
		assert_ne(ca, cb, String(param))
	var zones_a: Texture2D = rig_a.body_material.get_shader_parameter(&"zones")
	var zones_b: Texture2D = rig_b.body_material.get_shader_parameter(&"zones")
	assert_ne(zones_a, zones_b,
			"tenue = autre carte de zones Kenney")
	var top: Color = rig_a.body_material.get_shader_parameter(&"top_color")
	assert_gt(top.v, 0.2, "tenue lisible (pas un aplat noir)")
	assert_ne(PortraitService.sketch(a).get_data(), PortraitService.sketch(b).get_data(), "portraits différents")


func test_palettes_are_not_black() -> void:
	for i: int in GreyboxStyle.PALETTES.size():
		var app: PassengerAppearance = PassengerAppearance.new()
		app.palette_id = StringName("palette_%02d" % (i + 1))
		for c: Color in GreyboxStyle.palette(app):
			assert_gt(c.r + c.g + c.b, 0.1, "palette %d" % (i + 1))


func test_outfit_zone_maps_exist() -> void:
	for skin: String in AppearanceApplier.OUTFIT_SKINS:
		assert_not_null(PassengerRig.zone_texture(skin), skin)
