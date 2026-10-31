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
## sauvegardes), `--title=new|difficulty|overwrite|load|days`, `--damage-slot=N`
## (avec `--demo-saves` : emplacement de démonstration N rendu illisible et
## marqué endommagé, capture QA-043).
## M12 (lot C, I28 / I29) : entrées **GARDE DE NUIT** (`GardeScreen` ; active
## si `GardeService.is_unlocked(profil)`, sinon grisée avec « Terminez votre
## premier jour au Guichet 04. ») et **DOSSIER DE L'AGENT** (`DossierScreen` ;
## active dès qu'une fin est vue ou un personnage croisé, sinon « Aucun
## dossier. ») ; épilogue J31 lancé depuis Charger (`epilogue_requested`) ou
## le Dossier (graine du profil) ; Garde lancée par `Campaign.start_garde`
## puis `DayScene.pending_garde_run`. Captures : `--demo-profile` (profil de
## démonstration dans `user://qa_demo_saves`, avec `--demo-saves`),
## `--title=garde|dossier|dossier-people|dossier-garde|dossier-epilogues|dossier-last`.
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
## M12 : Garde de nuit et Dossier de l'agent, et leurs mentions « verrouillé ».
var garde_button: Button = null
var dossier_button: Button = null
var garde_locked_label: Label = null
var dossier_locked_label: Label = null
var options_button: Button = null
var quit_button: Button = null
var options: OptionsPanel = null
## Écran ouvert par-dessus le titre (Nouvelle partie, Charger), null sinon.
var screen: ScreenBase = null
## Faux : `_start_day` n'ouvre pas la scène de jour (tests).
var change_scene: bool = true
## Toasts du titre (chargement impossible), créés au premier besoin.
var title_toasts: ToastStack = null
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
	if args.has("demo-saves") or args.has("demo-profile"):
		if args.has("demo-saves"):
			write_demo_saves(DEMO_SAVES_DIR)
		if args.has("damage-slot"):
			damage_demo_slot(DEMO_SAVES_DIR, str(args["damage-slot"]).to_int())
		if args.has("demo-profile"):
			write_demo_profile(DEMO_SAVES_DIR, str(args.get("demo-profile", "full")))
		SaveService.use_root(DEMO_SAVES_DIR)
	# Le bouton de la scène devient « CONTINUER » (CTA principal).
	continue_button = _start_button
	continue_button.custom_minimum_size = Vector2(360, DS.HIT_TARGET_MIN + DS.SPACE_1)
	continue_button.pressed.connect(continue_game)
	_menu.append(continue_button)
	new_game_button = _add_button(UiText.t("title_new_game", "NOUVELLE PARTIE"), open_new_game)
	load_button = _add_button(UiText.t("title_load", "CHARGER"), open_load)
	garde_button = _add_button(UiText.t("title_garde", "GARDE DE NUIT"), open_garde)
	garde_locked_label = _add_locked_label(UiText.t("garde_locked", "Terminez votre premier jour au Guichet 04."))
	dossier_button = _add_button(UiText.t("title_dossier", "DOSSIER DE L'AGENT"), open_dossier)
	dossier_locked_label = _add_locked_label(UiText.t("dos_empty", "Aucun dossier."))
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
	EventBus.profile_changed.connect(refresh_menu)
	refresh_menu()
	default_focus().grab_focus.call_deferred()
	if GardeScreen.open_on_title:
		# « NOUVELLE GRAINE » depuis la fin de garde : retour à l'accueil de la Garde.
		GardeScreen.open_on_title = false
		open_garde.call_deferred()
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


## Mention sous une entrée verrouillée (grisée), masquée sinon.
func _add_locked_label(text: String) -> Label:
	var l: Label = ScreenBase.label(text, &"CaptionLabel", Palette.TEXT_SECONDARY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	_content.add_child(l)
	_menu.append(l)
	return l


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
	# Jamais un emplacement endommagé (QA-043, `SaveSlotCard.continue_slot`).
	var latest: int = SaveSlotCard.continue_slot()
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
	# M12 : Garde (D-128) et Dossier (D-131) selon le profil.
	var profile: Dictionary = ProfileService.load_profile()
	var garde_open: bool = GardeService.is_unlocked(profile)
	_set_enabled(garde_button, garde_open)
	garde_locked_label.set_meta(&"locked", not garde_open)
	var dossier_open: bool = DossierData.has_dossier(profile)
	_set_enabled(dossier_button, dossier_open)
	dossier_locked_label.set_meta(&"locked", not dossier_open)
	_sync_locked_labels()
	# CTA jaune : « CONTINUER » s'il est possible, sinon « NOUVELLE PARTIE ».
	continue_button.theme_type_variation = &"ButtonPrimary" if not continue_button.disabled else &"ButtonTool"
	new_game_button.theme_type_variation = &"ButtonTool" if not continue_button.disabled else &"ButtonPrimary"


## Mentions « verrouillé » visibles avec le menu, seulement si l'entrée l'est.
func _sync_locked_labels() -> void:
	for l: Label in [garde_locked_label, dossier_locked_label]:
		if l != null:
			l.visible = options == null or not options.visible
			l.visible = l.visible and l.get_meta(&"locked", false)


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
	_sync_locked_labels()
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
	load_screen.epilogue_requested.connect(play_epilogue_from_slot)
	_open_screen(load_screen, load_button)
	return load_screen


## M12 : accueil de la Garde de nuit.
func open_garde() -> GardeScreen:
	var garde: GardeScreen = GardeScreen.new()
	garde.name = "GardeScreen"
	garde.start_requested.connect(start_garde)
	_open_screen(garde, garde_button)
	return garde


## M12 : Dossier de l'agent.
func open_dossier() -> DossierScreen:
	var dossier: DossierScreen = DossierScreen.new()
	dossier.name = "DossierScreen"
	dossier.title_music = get_node_or_null(^"TitleMusic") as TitleMusic # REVOIR : thème de la fin (M14)
	dossier.epilogue_requested.connect(play_epilogue_from_profile)
	dossier.garde_requested.connect(start_garde)
	_open_screen(dossier, dossier_button)
	return dossier


# ---------------------------------------------------------------------------
# Lancement d'une partie
# ---------------------------------------------------------------------------

## « CONTINUER » : la partie active la plus récente.
func continue_game() -> bool:
	var slot: int = SaveSlotCard.continue_slot()
	if slot == SaveService.NO_SLOT or not GameState.load_from_slot(slot):
		refresh_menu()
		if slot != SaveService.NO_SLOT:
			_toast_load_failed(slot)
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
		_load_failed(slot)
		return false
	_start_day()
	return true


func resume_day(slot: int, day: int) -> bool:
	if not GameState.load_day_snapshot(slot, day):
		_load_failed(slot, day)
		return false
	_start_day()
	return true


## Chargement impossible depuis « Charger » : toast de l'écran (QA-043 / QA-045,
## jamais un bouton qui ne fait rien).
func _load_failed(slot: int, day: int = 0) -> void:
	var load_screen: LoadScreen = screen as LoadScreen
	if load_screen != null and is_instance_valid(load_screen):
		load_screen.show_load_failed(slot, day)
	else:
		_toast_load_failed(slot)


## Toast d'erreur sur le titre (CONTINUER qui échoue malgré tout).
func _toast_load_failed(slot: int) -> void:
	_ensure_title_toasts()
	title_toasts.push(ToastStack.Kind.ERROR, UiText.t("load_failed_title", "CHARGEMENT IMPOSSIBLE"),
			UiText.tf("load_failed_slot", [slot], "La sauvegarde de l'emplacement %d est illisible."))


func _ensure_title_toasts() -> void:
	if title_toasts == null:
		title_toasts = ToastStack.new()
		title_toasts.name = "Toasts"
		title_toasts.anchor_left = 1.0
		title_toasts.anchor_right = 1.0
		title_toasts.offset_left = -(SaveSlotCard.MIN_WIDTH + DS.SPACE_8)
		title_toasts.offset_right = -DS.SPACE_8
		title_toasts.offset_top = DS.SPACE_8
		title_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		add_child(title_toasts)


func _start_day() -> void:
	TutorialOverlay.pending = GameState.current_day == 1 and Settings.get_bool(Settings.KEY_TUTORIAL)
	shift_start_requested.emit()
	if change_scene:
		get_tree().change_scene_to_file(DAY_SCENE_PATH)


# ---------------------------------------------------------------------------
# M12 : Garde de nuit, épilogue J31
# ---------------------------------------------------------------------------

## Garde de nuit sur un code (graine du jour ou libre) : session Garde, puis
## la scène de jour la joue (`DayScene.pending_garde_run`).
func start_garde(code: String) -> bool:
	var run: GardeRun = Campaign.start_garde(code)
	if run == null:
		_toast_error(UiText.t("garde_start_failed", "GARDE IMPOSSIBLE"), UiText.t("garde_seed_invalid", "Code de garde invalide."))
		return false
	DayScene.pending_garde_run = run
	TutorialOverlay.pending = false
	shift_start_requested.emit()
	if change_scene:
		get_tree().change_scene_to_file(DAY_SCENE_PATH)
	return true


## Épilogue depuis un emplacement terminé (Charger, `day_31.json`).
func play_epilogue_from_slot(slot: int) -> bool:
	return _play_epilogue(Campaign.epilogue_seed_for_slot(slot), slot)


## Épilogue depuis la graine du profil (Dossier › Épilogues), même si
## l'emplacement a été supprimé (D-125).
func play_epilogue_from_profile(key: String) -> bool:
	return _play_epilogue(Campaign.epilogue_seed_from_profile(key), SaveService.NO_SLOT)


func _play_epilogue(epi: Dictionary, slot: int) -> bool:
	if Campaign.start_epilogue(epi, slot) == null:
		_toast_error(UiText.t("epi_start_failed", "ÉPILOGUE INDISPONIBLE"),
				UiText.t("epi_start_failed_body", "La graine de cet épilogue est illisible."))
		return false
	TutorialOverlay.pending = false
	shift_start_requested.emit()
	if change_scene:
		get_tree().change_scene_to_file(DAY_SCENE_PATH)
	return true


func _toast_error(title: String, body: String) -> void:
	var load_screen: LoadScreen = screen as LoadScreen
	if load_screen != null and is_instance_valid(load_screen) and load_screen.toasts != null:
		load_screen.toasts.push(ToastStack.Kind.ERROR, title, body)
		return
	_ensure_title_toasts()
	title_toasts.push(ToastStack.Kind.ERROR, title, body)


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
		"garde":
			if not garde_button.disabled:
				open_garde()
		"dossier", "dossier-people", "dossier-last", "dossier-garde", "dossier-epilogues":
			if not dossier_button.disabled:
				var dossier: DossierScreen = open_dossier()
				if which != "dossier":
					dossier.show_tab.call_deferred(StringName(which.trim_prefix("dossier-")))
		"dossier-replay":
			# M14 : REVOIR une fin vue (CIN-F10), figures en silhouette.
			if not dossier_button.disabled:
				var dossier_r: DossierScreen = open_dossier()
				_debug_replay.call_deferred(dossier_r, str(DebugArgs.parse(OS.get_cmdline_user_args()).get("replay", "cin_f10")))
		"options-m14":
			# M14 : options, section Audio (musique) visible.
			_show_options()
			_debug_options_m14.call_deferred()


## Capture M14 : REVOIR `id` depuis le Dossier, planche `--plate=N` à
## `--plate-t` s (figée avec `--plate-hold`).
func _debug_replay(dossier: DossierScreen, id: String) -> void:
	var b: Button = dossier.replay_buttons.get(id, null)
	if b == null:
		push_warning("main: REVOIR %s indisponible" % id)
		return
	b.pressed.emit()
	var args: Dictionary = DebugArgs.parse(OS.get_cmdline_user_args())
	var plate_n: int = str(args.get("plate", "0")).to_int()
	if dossier.replay != null and plate_n > 0:
		await get_tree().process_frame
		dossier.replay.jump_to(plate_n - 1, str(args.get("plate-t", "1.5")).to_float())
		if args.has("plate-hold"):
			dossier.replay.set_process(false)


## Capture M14 : options défilées jusqu'aux réglages de musique (`--opt-row=cinematic` : avance des cinématiques).
func _debug_options_m14() -> void:
	await get_tree().process_frame
	var row: String = str(DebugArgs.parse(OS.get_cmdline_user_args()).get("opt-row", "music"))
	var target: Control = options.controls.get(Settings.KEY_CINEMATIC_ADVANCE if row == "cinematic" else Settings.KEY_MUSIC_DYNAMICS, null)
	if target != null:
		target.grab_focus()
		options.scroll.ensure_control_visible(target)


## Capture QA-043 : `current.json` de l'emplacement de démonstration illisible,
## instantanés retirés, méta marquée `damaged` (dossier de démonstration seul).
static func damage_demo_slot(dir: String, slot: int) -> void:
	if dir != DEMO_SAVES_DIR or slot < 1 or slot > SaveService.SLOT_COUNT:
		return
	var file: FileAccess = FileAccess.open(SaveService.slot_path(slot, dir), FileAccess.WRITE)
	if file != null:
		file.store_string("{\"version\": 6, \"current_d")
		file.close()
	for day: int in SaveService.list_snapshots(slot, dir):
		DirAccess.remove_absolute(SaveService.snapshot_path(slot, day, dir))
	var meta: Dictionary = SaveService.load_meta(slot, dir)
	meta["damaged"] = true
	file = FileAccess.open(SaveService.meta_path(slot, dir), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(meta))
		file.close()


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


## Profil de démonstration (captures M12, jamais dans `user://saves`) :
## `full` — fins vues (dont l'Acte III : épilogues débloqués), personnages
## croisés, records de Garde ; `early` — partie au J5, aucune fin (anti-spoiler).
static func write_demo_profile(dir: String, kind: String = "full") -> void:
	if dir != DEMO_SAVES_DIR:
		return
	var profile: Dictionary = ProfileService.empty_profile()
	if kind == "early":
		profile["max_day_reached"] = 5
		profile["characters_met"] = ["tuto_concordant", "sc_01", "sc_02", "sc_03", "sc_04", "sc_05", "sc_20"]
		ProfileService.save_profile(profile, dir)
		return
	profile["max_day_reached"] = 30
	profile["endings_seen"] = [
		{"id": "f3_family_lost", "variant": "", "act": 1, "day": 6, "date": "2026-10-21T21:04:00", "count": 1,
			"last_date": "2026-10-21T21:04:00", "first_line_key": "end_f3_l1"},
		{"id": "f5_air", "variant": "c", "act": 3, "day": 30, "date": "2026-10-26T22:41:00", "count": 2,
			"last_date": "2026-10-28T23:10:00", "first_line_key": ""},
		{"id": "f10_pont", "variant": "", "act": 3, "day": 30, "date": "2026-10-28T20:12:00", "count": 1,
			"last_date": "2026-10-28T20:12:00", "first_line_key": ""},
	]
	var met: Array = []
	for id: String in ["tuto_concordant", "sc_01", "sc_02", "sc_03", "sc_04", "sc_05", "sc_08", "sc_10", "sc_14", "sc_20", "sc_23",
			"sc_25", "sc_35a", "sc_38", "sc_42", "sc_50a", "sc_56", "sc_82a", "sc_97", "sc_98", "sc_99", "sc_100a"]:
		met.append(id)
	profile["characters_met"] = met
	profile["known_names"] = ["chr_arkady"]
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true, &"climate_vanne": true}
	for ending: StringName in [EndingService.F5_AIR, EndingService.F10_PONT]:
		var epi: Dictionary = EpilogueService.make_seed(ending, flags, Household.new(), {}, 4242, 30)
		if epi.is_empty():
			continue
		var key: String = EpilogueService.profile_key(epi)
		var epilogues: Dictionary = profile["epilogues"]
		epilogues[key] = {"world": epi["world"], "key": epi["ending_key"], "seed": epi, "first_date": "", "count": 0,
				"last_date": "", "last_lines": []}
		profile["epilogue_unlocked"] = true
	var epis: Dictionary = profile["epilogues"]
	if epis.has("f10_pont:"):
		var played: Dictionary = epis["f10_pont:"]
		played["first_date"] = "2026-10-28T21:00:00"
		played["count"] = 1
		played["last_lines"] = ["epi_f10_open", "epi_c_fig_passed", "epi_f10_close"]
	profile["last_campaign"] = {"ending": "f10_pont", "variant": "", "ending_key": "f10", "act": 3, "day": 30,
		"date": "2026-10-28T20:12:00", "campaign_seed": 4242, "climate": "vanne",
		"traces": ["end_trace_sc02_mercy", "end_trace_met_mira", "end_trace_lucioles_note_burned"], "world": "c"}
	profile["best_runs"] = [
		{"score": 31, "seed_code": GardeService.today_code(), "kind": "daily", "date": "2026-10-29", "garde_version": GardeScreen.current_version(),
			"duration_sec": 1710, "directives": 6, "palier": 2},
		{"score": 18, "seed_code": "K2Q-9TX", "kind": "free", "date": "2026-10-27", "garde_version": GardeScreen.current_version(),
			"duration_sec": 940, "directives": 3, "palier": 1},
		{"score": 12, "seed_code": "H7W-PL3", "kind": "free", "date": "2026-10-20", "garde_version": 0,
			"duration_sec": 700, "directives": 2, "palier": 0},
	]
	profile["garde_daily"] = {GardeService.daily_date(GardeService.today_code()): {"best": 31, "first_try": 24, "attempts": 3,
			"garde_version": GardeScreen.current_version()}}
	profile["garde_seeds"] = [{"seed_code": "K2Q-9TX", "best": 18, "garde_version": GardeScreen.current_version()}]
	profile["garde_stats"] = {"runs": 7, "total_correct": 112, "longest_run": 34}
	# M14 : cinématiques vues (REVOIR) et portraits vus à la vitre (apparences
	# tirées du vrai générateur, graines fixes) ; deux personnes restent en initiales.
	profile["cinematics_seen"] = ["cin_f3", "cin_f5c", "cin_f10", "cin_ec"]
	profile["portraits"] = demo_portraits(met)
	ProfileService.save_profile(profile, dir)


## Portraits de démonstration (captures) : un visage par personnage croisé,
## sauf deux (2ᵉ et 5ᵉ : repli en initiales) ; une visière restée baissée.
static func demo_portraits(met: Array) -> Dictionary:
	var out: Dictionary = {}
	var table: CharacterTableDef = CharacterTableDef.load_default()
	var data: DataCatalog = DataCatalog.load_from()
	if table == null or data == null or data.appearance_catalog == null:
		return out
	var gen: AppearanceGenerator = AppearanceGenerator.new(data.appearance_catalog)
	var count: int = 0
	for i: int in met.size():
		if i == 1 or i == 4:
			continue
		var case_id: String = str(met[i])
		var chr: CharacterDef = table.character_of(StringName(str(case_id)))
		if chr == null or out.has(String(chr.id)):
			continue
		var app: PassengerAppearance = gen.generate(SeededRng.new(9_000 + count * 37), [&"hal", &"ter", &"tyc"][count % 3] as StringName)
		out[String(chr.id)] = {"appearance": app.serialize(), "visor": "down" if count == 3 else "none",
				"case_id": str(case_id), "day": 1 + count, "act": 1}
		count += 1
	return out
