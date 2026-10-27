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
	var lib: AnimationLibrary = PlaceholderAnims.load_library()
	for clip: StringName in PlaceholderAnims.CLIPS:
		assert_true(lib.has_animation(clip), "clip %s" % clip)
	assert_eq(lib.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation(&"idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation(&"present_documents").loop_mode, Animation.LOOP_NONE)


func test_present_documents_carries_documents_slot_marker() -> void:
	var anim: Animation = PlaceholderAnims.load_library().get_animation(&"present_documents")
	var found: bool = false
	for key: Array in _method_keys(anim):
		var marker: StringName = key[2]
		if marker == PlaceholderAnims.DOCUMENTS_SLOT:
			found = true
			var time: float = key[0]
			var method: StringName = key[1]
			assert_almost_eq(time, PlaceholderAnims.DOCUMENTS_SLOT_TIME, 0.001)
			assert_eq(method, PlaceholderAnims.MARKER_METHOD)
	assert_true(found, "repère documents_slot (BOOTH_SCENE §7.3)")
	var visor: Array[Array] = _method_keys(PlaceholderAnims.load_library().get_animation(&"remove_visor"))
	assert_eq(visor.size(), 1)
	var visor_marker: StringName = visor[0][2]
	assert_eq(visor_marker, PlaceholderAnims.VISOR_OFF)


func test_tree_structure() -> void:
	var tree: AnimationNodeBlendTree = PlaceholderAnims.build_tree()
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
	assert_true(actor.anim_player.has_animation(PlaceholderAnims.clip_path(&"present_documents")))
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
	actor._on_anim_marker(PlaceholderAnims.DOCUMENTS_SLOT)
	actor._on_anim_marker(PlaceholderAnims.DOCUMENTS_SLOT)
	assert_signal_emit_count(actor, "anim_event", 1)
	actor.assign(&"c2", 2, 2)
	actor._on_anim_marker(PlaceholderAnims.DOCUMENTS_SLOT)
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
