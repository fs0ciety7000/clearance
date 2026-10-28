## QA (docs/QA.md §4) — robustesse de la vraie scène de jour (`day.tscn`) :
## spam de « Suivant », de tampons et d'Échap ; tampon maintenu pendant la
## pause. Les bugs ouverts sont marqués `pending("QA-xxx …")` tant qu'ils ne
## sont pas corrigés : la suite reste verte, le rapport GUT les liste.
extends GutTest

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const VK := VerdictKind.Kind

var scene: DayScene = null
var _saved_state: Dictionary = {}


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	GameState.new_campaign(20_871_315)
	scene = DAY_SCENE.instantiate()
	add_child_autofree(scene)


func after_each() -> void:
	get_tree().paused = false
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _ui() -> ComparisonUI:
	return scene.ui as ComparisonUI


func _push_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	get_viewport().push_input(event)


func _press_escape() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_process_frames(1)


## Ouvre le shift et attend les documents du premier passager.
func _first_case() -> bool:
	scene.briefing.close()
	_ui().request_next_case()
	return await wait_until(func() -> bool: return _ui().documents_shown, 6.0)


func test_spam_next_case_calls_exactly_one_passenger() -> void:
	scene.briefing.close()
	var dc: DayController = scene.day_controller
	for i: int in 12:
		_ui().request_next_case()
		EventBus.next_case_requested.emit()
		_push_action(&"next_case", true)
		_push_action(&"next_case", false)
		await wait_process_frames(1)
	assert_eq(dc.next_index, 1, "un seul passager appelé malgré le spam")
	var ok: bool = await wait_until(func() -> bool: return _ui().documents_shown, 6.0)
	assert_true(ok, "le passager arrive normalement")
	assert_eq(dc.phase, DayPhase.Kind.INSPECTING)


func test_spam_stamps_record_a_single_verdict() -> void:
	assert_true(await _first_case())
	var dc: DayController = scene.day_controller
	var case_id: StringName = dc.current_case_id()
	for kind: VK in [VK.APPROVE, VK.DENY, VK.APPROVE, VK.DETAIN, VK.DENY]:
		EventBus.verdict_stamped.emit(Verdict.new(case_id, kind))
	assert_eq(dc.summary.get_processed_count(), 1, "un seul verdict par cas")
	assert_eq(dc.summary.results[0].verdict_kind, VK.APPROVE, "le premier tampon fait foi")
	var ok: bool = await wait_until(func() -> bool: return dc.phase == DayPhase.Kind.WAITING_CASE, 6.0)
	assert_true(ok, "départ puis guichet rouvert")
	# Tampons tardifs (cas déjà parti) : ignorés.
	EventBus.verdict_stamped.emit(Verdict.new(case_id, VK.DENY))
	assert_eq(dc.summary.get_processed_count(), 1)


func test_stamp_keys_spammed_without_hold_never_stamp() -> void:
	assert_true(await _first_case())
	for i: int in 20:
		_push_action(&"stamp_deny", true)
		_push_action(&"stamp_deny", false)
		_push_action(&"stamp_approve", true)
		_push_action(&"stamp_approve", false)
		await wait_process_frames(1)
	await wait_seconds(0.6)
	assert_eq(scene.day_controller.summary.get_processed_count(), 0, "des appuis brefs ne tamponnent pas (maintien requis)")


func test_escape_spam_leaves_pause_state_consistent() -> void:
	scene.briefing.close()
	for i: int in 7:
		await _press_escape()
	assert_true(scene.pause_menu.is_open, "7 appuis : pause ouverte")
	assert_eq(get_tree().paused, scene.pause_menu.is_open, "arbre en pause ⇔ menu ouvert")
	await _press_escape()
	assert_false(scene.pause_menu.is_open)
	assert_false(get_tree().paused)


## QA-005 (corrigé) : un tampon maintenu au clavier, puis Échap (pause),
## relâché pendant la pause : le maintien est annulé à l'ouverture de la pause,
## aucun verdict ne tombe à la reprise.
func test_stamp_hold_does_not_survive_the_pause() -> void:
	assert_true(await _first_case())
	var dc: DayController = scene.day_controller
	_push_action(&"stamp_deny", true)
	await wait_process_frames(2)
	var button: StampButton = _ui().get_stamp_button(VK.DENY)
	assert_true(button.is_holding(), "maintien commencé")
	scene.pause_menu.open()
	_push_action(&"stamp_deny", false)
	await wait_process_frames(2)
	scene.pause_menu.close()
	await wait_seconds(DS.STAMP_HOLD + 0.4)
	assert_false(button.is_holding(), "maintien annulé par la pause")
	assert_eq(dc.summary.get_processed_count(), 0, "aucun verdict posé à la reprise")


## QA-006 (corrigé) : un réglage de session (`set_session_value` : argument
## `--reduce-motion`, tests GUT) n'est pas écrit à la fermeture de la pause
## (`PauseMenu.close()` → `Settings.save_settings()`) ; la suite écrit dans un
## fichier de test (`tests/helpers/gut_pre_run.gd`), jamais dans le réel.
func test_temporary_setting_is_not_persisted_by_the_pause() -> void:
	var path: String = Settings.settings_path
	assert_ne(path, Settings.SETTINGS_PATH, "suite isolée du settings.cfg réel")
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(Settings.SECTION, String(Settings.KEY_REDUCE_MOTION), false)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cfg.save(path)
	# `before_each` a posé reduce_motion = true pour la session.
	assert_true(Settings.reduce_motion)
	assert_true(Settings.is_session_value(Settings.KEY_REDUCE_MOTION))
	scene.briefing.close()
	scene.pause_menu.open()
	scene.pause_menu.close()
	var after: ConfigFile = ConfigFile.new()
	after.load(path)
	var persisted: bool = after.get_value(Settings.SECTION, String(Settings.KEY_REDUCE_MOTION), true)
	assert_false(persisted, "valeur de session non persistée")
	assert_true(Settings.reduce_motion, "toujours active pour la session")
	DirAccess.remove_absolute(path)
