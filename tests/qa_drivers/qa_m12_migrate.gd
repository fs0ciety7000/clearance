## Pilote QA M12 — profil M11 réel (v1) ouvert par M12 : migration, titre, Dossier, Charger, épilogue.
## Usage (docs/QA.md §15.12) — dossier XDG contenant un profil M11 (v1) et ses emplacements :
##   XDG_DATA_HOME=<copie> godot --headless --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m12_migrate.gd [--qa-play --autoplay]
extends Node

const MAIN: String = "res://scenes/main/main.tscn"
var _phase: String = "title"
var _done: Dictionary = {}
var _t0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 10.0
	var root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	print("QA_MIG before files=%s" % [DirAccess.get_files_at(root)])
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("profile.json")))
	print("QA_MIG v1 raw=%s" % JSON.stringify(raw))
	EventBus.day_ended.connect(func(s: DaySummary) -> void:
		print("QA_MIG epilogue day processed=%d/%d" % [s.get_processed_count(), s.planned_cases]))
	get_tree().change_scene_to_file.call_deferred(MAIN)
	_t0 = Time.get_ticks_msec()


func _process(_d: float) -> void:
	if Time.get_ticks_msec() - _t0 > 300000:
		print("QA_ISSUE BLOCAGE %s" % _phase)
		_quit()
		return
	var scene: Node = get_tree().current_scene
	if scene == null or _done.has(_phase):
		return
	if _phase == "title" and scene.has_method(&"open_load"):
		_done[_phase] = true
		_title(scene)
	elif _phase == "epi" and scene is DayScene:
		var s: DayScene = scene
		if s.screen is EpilogueScreen and (s.screen as EpilogueScreen).mode == EpilogueScreen.Mode.CONCLUSION:
			_done[_phase] = true
			var card: Dictionary = (s.screen as EpilogueScreen).card
			print("QA_MIG conclusion world=%s key=%s lines=%s" % [card.get("world"), card.get("ending_key"),
					" | ".join(EpilogueScreen.conclusion_lines(card))])
			var root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
			print("QA_MIG after_epi slot files=%s meta=%s" % [DirAccess.get_files_at(root.path_join("slot_1")),
					JSON.stringify(SaveService.load_meta(1))])
			_quit()


func _title(main: Node) -> void:
	await get_tree().create_timer(0.3).timeout
	var root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	var prof: Dictionary = ProfileService.load_profile()
	print("QA_MIG after files=%s" % [DirAccess.get_files_at(root)])
	print("QA_MIG v2 version=%s max_day=%s unlocked=%s endings=%s" % [prof.get("version"), prof.get("max_day_reached"),
			prof.get("epilogue_unlocked"), JSON.stringify(prof.get("endings_seen"))])
	print("QA_MIG v2 epilogues=%s" % [(prof.get("epilogues", {}) as Dictionary).keys()])
	print("QA_MIG v2 last_campaign=%s known_names=%s characters=%d" % [JSON.stringify(prof.get("last_campaign")),
			prof.get("known_names"), (prof.get("characters_met", []) as Array).size()])
	if DirAccess.dir_exists_absolute(root.path_join("slot_1")):
		print("QA_MIG slot_1 files=%s meta=%s" % [DirAccess.get_files_at(root.path_join("slot_1")), JSON.stringify(SaveService.load_meta(1))])
	print("QA_MIG title garde_disabled=%s dossier_disabled=%s continue=%s" % [(main.get(&"garde_button") as Button).disabled,
			(main.get(&"dossier_button") as Button).disabled, (main.get(&"continue_button") as Button).visible])
	var dossier: DossierScreen = main.call(&"open_dossier")
	await get_tree().process_frame
	print("QA_MIG dossier tabs=%s" % [dossier.tabs])
	var labels: PackedStringArray = []
	for l: Node in dossier.find_children("*", "Label", true, false):
		var t: String = (l as Label).text
		if t.contains("fin") or t.contains("/") or t.contains("NON VUE"):
			labels.append(t)
	print("QA_MIG dossier labels=%s" % [" ¦ ".join(labels.slice(0, 14))])
	dossier.go_back()
	await get_tree().create_timer(0.3).timeout
	var load_screen: LoadScreen = main.call(&"open_load")
	await get_tree().process_frame
	print("QA_MIG load epilogue_buttons=%s" % [load_screen.epilogue_buttons.keys()])
	if OS.get_cmdline_user_args().has("--qa-play") and load_screen.epilogue_buttons.has(1):
		_phase = "epi"
		load_screen.epilogue_buttons[1].pressed.emit()
	else:
		_quit()


var _quitting: bool = false


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	print("QA_MIG_DONE")
	Engine.time_scale = 1.0
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
