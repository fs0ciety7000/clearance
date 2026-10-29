## Bootstrap : applique le thème DS et affiche l'écran titre (UI_FLOW §8, §8.5).
## M11 (lot C, D-101 / D-102) : menu « CONTINUER » (partie active la plus
## récente, `SaveService.latest_slot` ; désactivé s'il n'y en a pas) ·
## « NOUVELLE PARTIE » (`NewGameScreen` : emplacement puis difficulté) ·
## « CHARGER » (`LoadScreen` : reprendre, reprendre un jour passé, supprimer) ·
## « OPTIONS » (`OptionsPanel`) · « QUITTER ». Le jour courant est ensuite
## joué dans `day.tscn` ; au J1, le tutoriel interactif est demandé
## (`TutorialOverlay.pending`) si le réglage `tutorial_j1` est actif.
## Arguments de capture (debug, `DebugArgs.enabled`) : `--demo-saves` (trois
## emplacements de démonstration dans `user://qa_demo_saves`, jamais les vraies
## sauvegardes), `--title=new|difficulty|overwrite|load|days`.
extends Control

const DAY_SCENE_PATH: String = "res://scenes/main/day.tscn"
## Dossier des sauvegardes de démonstration (`--demo-saves`).
const DEMO_SAVES_DIR: String = "user://qa_demo_saves"

## Émis quand le joueur demande à commencer le shift.
signal shift_start_requested()

@onready var _background: ColorRect = %Background
@onready var _title: Label = %Title
@onready var _start_button: Button = %StartButton
@onready var _content: VBoxContainer = %Content

var continue_button: Button = null
var new_game_button: Button = null
var load_button: Button = null
var options_button: Button = null
var quit_button: Button = null
var options: OptionsPanel = null
## Écran ouvert par-dessus le titre (Nouvelle partie, Charger), null sinon.
var screen: ScreenBase = null
## Faux : `_start_day` n'ouvre pas la scène de jour (tests).
var change_scene: bool = true
var _menu: Array[Control] = []
var _applied_min_px: int = -1


func _ready() -> void:
	get_tree().paused = false
	_apply_theme()
	EventBus.settings_changed.connect(func(key: StringName, _value: Variant) -> void:
		if key == Settings.KEY_TEXT_SCALE:
			_apply_theme())
	get_viewport().size_changed.connect(_on_viewport_resized)
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	_background.color = DS.BG_VOID
	_title.add_theme_font_size_override(&"font_size", DS.FS_DISPLAY_XL)
	_title.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	_content.add_theme_constant_override(&"separation", DS.SPACE_4)
	var version: Label = _content.get_node_or_null("Version") as Label
	if version != null:
		version.text = version_text()
	var args: Dictionary = DebugArgs.parse(OS.get_cmdline_user_args()) if DebugArgs.enabled() else {}
	if args.has("demo-saves"):
		write_demo_saves(DEMO_SAVES_DIR)
		SaveService.use_root(DEMO_SAVES_DIR)
	# Le bouton de la scène devient « CONTINUER » (CTA principal).
	continue_button = _start_button
	continue_button.custom_minimum_size = Vector2(360, DS.HIT_TARGET_MIN + DS.SPACE_1)
	continue_button.pressed.connect(continue_game)
	_menu.append(continue_button)
	new_game_button = _add_button(UiText.t("title_new_game", "NOUVELLE PARTIE"), open_new_game)
	load_button = _add_button(UiText.t("title_load", "CHARGER"), open_load)
	options_button = _add_button(UiText.t("title_options", "OPTIONS"), _show_options)
	quit_button = _add_button(UiText.t("title_quit", "QUITTER"), func() -> void: get_tree().quit())
	if version != null:
		_content.move_child(version, _content.get_child_count() - 1)
	options = OptionsPanel.new()
	options.visible = false
	options.custom_minimum_size.x = 800.0
	options.back_requested.connect(_show_menu)
	_content.add_child(options)
	EventBus.save_slots_changed.connect(refresh_menu)
	refresh_menu()
	default_focus().grab_focus.call_deferred()
	_debug_title(str(args.get("title", "")))


## Mention de version : « Démo · v0.8.0 » (`application/config/version`) ;
## « Démo » seul si la version n'est pas définie (QA-013).
static func version_text() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version.is_empty():
		return UiText.t("title_version_none", "Démo")
	if not version.begins_with("v"):
		version = "v" + version
	return UiText.tf("title_version", [version], "Démo · %s")


## Thème DS avec le plancher de texte Steam Deck (D-023), comme `ScreenBase` :
## reconstruit quand l'échelle du texte ou la taille de la fenêtre change (QA-004).
func _apply_theme() -> void:
	_applied_min_px = _min_text_px()
	theme = ThemeBuilder.build(Settings.text_scale, _applied_min_px)


func _min_text_px() -> int:
	return ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x)


func _on_viewport_resized() -> void:
	if _min_text_px() != _applied_min_px:
		_apply_theme()


func _add_button(text: String, callback: Callable) -> Button:
	var b: Button = ScreenBase.button(text, &"ButtonTool")
	b.custom_minimum_size.x = 360.0
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(callback)
	_content.add_child(b)
	_menu.append(b)
	return b


## État du menu d'après les emplacements : « CONTINUER — JOUR n » (désactivé
## sans partie active), « CHARGER » (désactivé sans aucune partie).
func refresh_menu() -> void:
	var latest: int = SaveService.latest_slot()
	var meta: Dictionary = SaveService.load_meta(latest) if latest != SaveService.NO_SLOT else {}
	var day: int = SaveService.as_int(meta.get("current_day", 0))
	if latest != SaveService.NO_SLOT and day > 0:
		var text: String = UiText.tf("title_continue", [day], "CONTINUER — JOUR %d")
		if str(meta.get("difficulty", "")) == SaveService.DIFFICULTY_STORY:
			text = UiText.tf("title_continue_story", [text], "%s · RÉCIT")
		continue_button.text = text
		_set_enabled(continue_button, true)
	else:
		continue_button.text = UiText.t("title_continue_none", "CONTINUER")
		_set_enabled(continue_button, false)
	var used: bool = false
	for slot_meta: Dictionary in SaveService.list_slots():
		used = used or not slot_meta.is_empty()
	_set_enabled(load_button, used)
	# CTA jaune : « CONTINUER » s'il est possible, sinon « NOUVELLE PARTIE ».
	continue_button.theme_type_variation = &"ButtonPrimary" if not continue_button.disabled else &"ButtonTool"
	new_game_button.theme_type_variation = &"ButtonTool" if not continue_button.disabled else &"ButtonPrimary"


## Bouton désactivé : jamais focalisable (la croix le saute).
static func _set_enabled(b: Button, enabled: bool) -> void:
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


## Focus par défaut du titre : CONTINUER, sinon NOUVELLE PARTIE.
func default_focus() -> Control:
	return continue_button if not continue_button.disabled else new_game_button


func _show_options() -> void:
	for item: Control in _menu:
		item.visible = false
	options.visible = true
	options.focus_first.call_deferred()


func _show_menu() -> void:
	options.visible = false
	for item: Control in _menu:
		item.visible = true
	options_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if screen == null and options != null and options.visible and event.is_action_pressed(&"cancel", false, true):
		_show_menu()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Écrans Nouvelle partie / Charger
# ---------------------------------------------------------------------------

func _open_screen(p_screen: ScreenBase, focus_back: Button) -> void:
	screen = p_screen
	_set_menu_visible(false)
	p_screen.finished.connect(func(_choice: StringName) -> void:
		screen = null
		_set_menu_visible(true)
		refresh_menu()
		var target: Button = focus_back if not focus_back.disabled else default_focus() as Button
		target.grab_focus.call_deferred())
	add_child(p_screen)


func _set_menu_visible(value: bool) -> void:
	var center: Control = _content.get_parent().get_parent() as Control
	if center != null:
		center.visible = value


func open_new_game() -> NewGameScreen:
	var ng: NewGameScreen = NewGameScreen.new()
	ng.name = "NewGameScreen"
	ng.start_requested.connect(start_new_game)
	_open_screen(ng, new_game_button)
	return ng


func open_load() -> LoadScreen:
	var load_screen: LoadScreen = LoadScreen.new()
	load_screen.name = "LoadScreen"
	load_screen.resume_requested.connect(resume_slot)
	load_screen.resume_day_requested.connect(resume_day)
	_open_screen(load_screen, load_button)
	return load_screen


# ---------------------------------------------------------------------------
# Lancement d'une partie
# ---------------------------------------------------------------------------

## « CONTINUER » : la partie active la plus récente.
func continue_game() -> bool:
	if not GameState.load_from_slot():
		refresh_menu()
		return false
	_start_day()
	return true


## Nouvelle partie dans `slot` (vidé d'abord) et à la difficulté choisie ;
## écrite tout de suite (l'emplacement est occupé dès maintenant, matin du J1).
func start_new_game(slot: int, difficulty: StringName) -> void:
	SaveService.delete_slot(slot)
	Campaign.new_game(DataCatalog.load_from(), 0, slot, difficulty)
	GameState.save_to_slot(slot)
	_start_day()


func resume_slot(slot: int) -> bool:
	if not GameState.load_from_slot(slot):
		return false
	_start_day()
	return true


func resume_day(slot: int, day: int) -> bool:
	if not GameState.load_day_snapshot(slot, day):
		return false
	_start_day()
	return true


func _start_day() -> void:
	TutorialOverlay.pending = GameState.current_day == 1 and Settings.get_bool(Settings.KEY_TUTORIAL)
	shift_start_requested.emit()
	if change_scene:
		get_tree().change_scene_to_file(DAY_SCENE_PATH)


# ---------------------------------------------------------------------------
# Captures (debug)
# ---------------------------------------------------------------------------

func _debug_title(which: String) -> void:
	match which:
		"new":
			open_new_game()
		"difficulty":
			open_new_game().show_difficulty(1)
		"overwrite":
			var ng: NewGameScreen = open_new_game()
			ng.choose_slot.call_deferred(1)
		"load":
			open_load()
		"days":
			var load_screen: LoadScreen = open_load()
			load_screen.open_day_picker.call_deferred(1)


## Trois emplacements de démonstration (captures) : partie en Dur au J12,
## partie terminée (F10, J30), partie en Récit au J04. Jamais dans `user://saves`.
static func write_demo_saves(dir: String) -> void:
	var specs: Array[Dictionary] = [
		{"slot": 1, "days": 12, "credits": 37, "story": false, "flags": {"act2_started": true}, "time": 9420},
		{"slot": 2, "days": 30, "credits": 112, "story": false, "flags": {"act2_started": true, "act3_started": true},
			"time": 31260, "ending": "f10_pont"},
		{"slot": 3, "days": 4, "credits": 18, "story": true, "flags": {}, "time": 2280},
	]
	for spec: Dictionary in specs:
		var slot: int = spec["slot"]
		SaveService.delete_slot(slot, dir)
		var data: Dictionary = {
			"campaign_seed": 1000 + slot, "credits": spec["credits"], "score_total": 0, "citations": 2,
			"narrative_flags": spec["flags"], "day_history": [], "household": Household.new().to_dict(), "case_memory": {},
			"difficulty": "story" if spec["story"] else "hard", "play_time_sec": spec["time"], "portrait_seed": slot,
		}
		for day: int in range(1, int(spec["days"]) + 1):
			data["current_day"] = day
			SaveService.save_slot(data, slot, dir, "2026-10-%02dT%02d:%02d:00" % [20 + slot, 8 + day % 12, (day * 7) % 60])
		if spec.has("ending"):
			SaveService.mark_ended(slot, spec["ending"], dir)
