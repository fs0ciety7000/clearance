## M15 (lot A, D-215) — démo J1–J5 : campagne bornée au J5 (fin de la démo
## après la soirée du J5), sauvegardes et profil séparés (`user://demo/saves`),
## écran « Fin de la démo » (CTA jeu complet, retour au titre, manette), titre
## (Garde et Dossier désactivés, mention de version). `DemoMode.force` simule
## l'export ; aucune écriture hors des dossiers de test.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DIR: String = "user://test_m15_demo_saves"
const CAMPAIGN_SEED: int = 20_871_315

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	DemoMode.force = 1
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	SaveService.delete_slot(1, DIR)


func after_each() -> void:
	DemoMode.force = -1
	DayScene.force_null_booth = false
	SaveService.delete_slot(1, DIR)
	SaveService.remove_with_fallbacks(ProfileService.profile_path(DIR))
	get_tree().paused = false
	GameState.end_session()
	GameState.apply_save_dict(_saved_state)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


func _evening() -> StringName:
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data)
	var report: EveningReport = Campaign.preview_evening(data, lines)
	return Campaign.close_evening(data, null, report, 1, DIR)


func test_demo_mode_bounds_and_platform_default() -> void:
	assert_eq(DemoMode.last_day(30), 5)
	assert_eq(DemoMode.last_day(3), 3, "données plus courtes : inchangé")
	assert_true(DemoMode.is_locked_day(6))
	assert_false(DemoMode.is_locked_day(5))
	DemoMode.force = 0
	assert_eq(DemoMode.last_day(30), 30, "jeu complet")
	assert_false(DemoMode.is_locked_day(6))
	DemoMode.force = -1
	assert_eq(DemoMode.is_demo(), OS.has_feature(DemoMode.FEATURE), "suite GUT : jeu complet (pas d'argument --demo)")


func test_demo_campaign_ends_after_the_day_5_evening() -> void:
	Campaign.new_game(data, CAMPAIGN_SEED)
	for day: int in range(1, 5):
		GameState.current_day = day
		var ending: StringName = _evening()
		if ending != EveningReport.ENDING_NONE:
			# Une fin anticipée (F2/F3) reste possible avant le J5.
			assert_ne(ending, Campaign.ENDING_DEMO_COMPLETE, "pas de fin de démo avant le J5 (J%d)" % day)
			return
		assert_eq(GameState.current_day, day + 1)
	assert_eq(GameState.current_day, 5)
	var last: StringName = _evening()
	if last == EveningReport.ENDING_NONE or last == Campaign.ENDING_DEMO_COMPLETE:
		assert_eq(last, Campaign.ENDING_DEMO_COMPLETE, "la soirée du J5 termine la démo")
	var meta: Dictionary = SaveService.load_meta(1, DIR)
	assert_eq(str(meta.get("status", "")), SaveService.STATUS_ENDED, "partie de démo archivée")
	assert_lte(SaveService.as_int(meta.get("current_day", 0)), DemoMode.LAST_DAY, "jamais d'état au-delà du J5")


func test_full_game_continues_after_day_5() -> void:
	DemoMode.force = 0
	Campaign.new_game(data, CAMPAIGN_SEED)
	GameState.current_day = 5
	var ending: StringName = _evening()
	assert_ne(ending, Campaign.ENDING_DEMO_COMPLETE, "jeu complet : le J6 suit")


func test_demo_saves_and_profile_are_separate() -> void:
	var test_root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	assert_ne(test_root, SaveService.DEFAULT_DIR, "suite : dossier de test (use_root)")
	SaveService.use_root("")
	var demo_dir: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	var demo_profile: String = ProfileService.profile_path()
	DemoMode.force = 0
	var full_dir: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	SaveService.use_root(test_root)
	assert_eq(demo_dir, DemoMode.SAVES_DIR, "démo : user://demo/saves")
	assert_true(demo_profile.begins_with(DemoMode.ROOT_DIR), "profil de la démo séparé : %s" % demo_profile)
	assert_eq(full_dir, "user://saves", "jeu complet inchangé")
	assert_eq(SaveService.resolve_dir("user://elsewhere"), "user://elsewhere", "dossier explicite jamais redirigé")
	DemoMode.force = 1
	assert_eq(SaveService.resolve_dir(SaveService.DEFAULT_DIR), test_root, "use_root (tests) prioritaire")


func test_day_scene_opens_the_demo_end_screen() -> void:
	DayScene.force_null_booth = true
	GameState.new_campaign(CAMPAIGN_SEED)
	GameState.current_day = 5
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	scene.show_end(Campaign.ENDING_DEMO_COMPLETE)
	var end: DemoEndScreen = scene.screen as DemoEndScreen
	assert_not_null(end, "fin de la démo : écran dédié")
	if end == null:
		return
	assert_eq(scene.screen_history.back(), &"demo_end")
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), end.store_button, "focus : VOIR LE JEU COMPLET (manette)")
	assert_eq(end.store_button.focus_mode, Control.FOCUS_ALL)
	assert_eq(end.title_button.focus_mode, Control.FOCUS_ALL)
	end.open_url = false
	end.store_button.pressed.emit()
	assert_eq(end.opened_urls, PackedStringArray([DemoMode.FULL_GAME_URL]), "lien vers le jeu complet")
	assert_true(end.find_child("Thanks", true, false) is Label, "remerciement")


func test_demo_end_screen_back_to_title_with_cancel() -> void:
	var end: DemoEndScreen = DemoEndScreen.new()
	end.setup(42, 0.8, Household.new())
	end.open_url = false
	add_child_autofree(end)
	await wait_process_frames(2)
	var choices: Array[StringName] = []
	end.finished.connect(func(choice: StringName) -> void: choices.append(choice))
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"cancel"
	cancel.pressed = true
	end._unhandled_input(cancel)
	assert_eq(choices, [DemoEndScreen.CHOICE_TITLE] as Array[StringName], "Ⓑ / Échap : retour au titre")


func test_title_in_demo_locks_garde_and_dossier() -> void:
	var title: Control = TITLE_SCENE.instantiate()
	title.set(&"change_scene", false)
	add_child_autofree(title)
	await wait_process_frames(2)
	var garde: Button = title.get(&"garde_button") as Button
	var dossier: Button = title.get(&"dossier_button") as Button
	assert_true(garde.disabled, "Garde de nuit désactivée en démo")
	assert_true(dossier.disabled, "Dossier désactivé en démo")
	var locked: Label = title.get(&"garde_locked_label") as Label
	assert_eq(locked.text, UiText.t("demo_full_game_only", "Dans le jeu complet."))
	assert_string_starts_with(title.call(&"version_text"), UiText.t("title_version_none", "Démo"), "mention « Démo »")
	DemoMode.force = 0
	assert_false(str(title.call(&"version_text")).contains(UiText.t("title_version_none", "Démo")), "jeu complet : version seule")
