## M7 — branchements minimaux de `day.tscn` (jeu jouable J1–J10 sans écrans
## dédiés) : le J10 démarre avec la mémoire des passagers (SC-22 a le visage
## de SC-04) et publie l'avis de recherche ; il n'a pas de soirée (D-053) ;
## l'écran de fin affiche l'épilogue d'une fin M7.
extends GutTest

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")

var _day_before: int = 0
var _seed_before: int = 0
var _notices: Array[WantedNotice] = []


func before_each() -> void:
	_day_before = GameState.current_day
	_seed_before = GameState.campaign_seed
	_notices.clear()
	EventBus.wanted_notices_published.connect(_on_notices)


func after_each() -> void:
	EventBus.wanted_notices_published.disconnect(_on_notices)
	GameState.current_day = _day_before
	GameState.campaign_seed = _seed_before


func _on_notices(notices: Array[WantedNotice]) -> void:
	_notices = notices.duplicate()


func test_day_ten_starts_with_memory_and_wanted_notices() -> void:
	GameState.new_campaign(20_871_315)
	GameState.current_day = 10
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	assert_eq(scene.day_controller.day.day_number, 10)
	assert_true(scene.day_controller.builder.memory.has("sc_04"), "mémoire recalculée (CaseMemory.recall)")
	assert_eq(_notices.size(), 3, "avis de recherche publié avec le jour")
	assert_false(Campaign.has_evening(scene.data), "pas de soirée au J10 (D-053)")
	var mira: GeneratedCase = scene.day_controller.builder.build(10)
	assert_eq(mira.scripted_id, &"sc_22")
	assert_true(mira.case.passenger_presented.appearance.is_face_covered())


func test_end_screen_shows_the_epilogue() -> void:
	GameState.new_campaign(20_871_315)
	GameState.current_day = 4
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	GameState.set_flag(&"final_detained", true)
	scene.show_end(EndingService.F4_GLORY)
	var end: EndScreen = scene.screen as EndScreen
	assert_not_null(end)
	assert_eq(end.epilogue["title_key"], "end_f4_title")
	var lines: PackedStringArray = end.epilogue["lines"]
	assert_gt(lines.size(), 4)
