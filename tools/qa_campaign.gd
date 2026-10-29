## Campagne QA réelle (docs/QA.md §2) — la vraie scène de jour (`day.tscn` :
## booth 3D, `ComparisonUI`, écrans, `reload_current_scene`) jouée du J1 au J30 (fin anticipée possible)
## par le bot `--autoplay`, accélérée par `Engine.time_scale`.
##
## Le pilote ne fait que ce que ferait un joueur pressé : ferme le bilan,
## pose les choix du soir d'un `SimProfile` (sinon laisse les choix par défaut
## via `confirm()`), valide, passe au jour suivant, puis lit l'écran de fin.
## Contrôles à chaque soir : la sauvegarde automatique relue (`SaveService`)
## redonne exactement `GameState.to_save_dict()` ; solde dans des bornes ;
## aucune clé i18n brute dans l'épilogue. Imprime `QA_DAY` par jour, `QA_END`.
##
## Usage (racine du projet ; lancé par `tools/qa_boot.gd`, autoloads requis) :
##   godot --headless --script res://tools/qa_boot.gd -- --autoplay \
##       --qa-seed=7 --qa-profile=default --qa-speed=8 [--qa-credits=N] [--qa-reload] [--qa-load=slot.json]
##       [--qa-story] [--no-booth] [--approve-all]
## M11 (sauvegarde v6, D-101) : la partie QA occupe l'emplacement
## `SaveService.DEFAULT_SLOT` (vidé au départ et à la fin) ; `--qa-load` accepte
## un ancien `slot_0.json` (v1–v5 : vraie migration `SaveService.migrate_legacy`)
## ou un `current.json` v6 ; à la fin, la partie doit être archivée
## (`meta.status = ended`), plus effacée. `--qa-story` : mode Récit (D-102).
## Acte II : l'interstitiel « CHAPITRE II » est fermé comme un joueur ; une
## option qui termine la campagne (« Embarquer », J10) passe par la boîte de
## confirmation ; `QA_EVENING` liste les postes (rations, prélèvements).
## `--qa-reload` : à chaque nouveau jour, « Quitter → Continuer » réel
## (`GameState.load_from_slot()` puis `reload_current_scene`).
## (`--autoplay` est lu par `DayScene` ; ne pas passer `--seed` : il relance une
## partie neuve à chaque rechargement de scène, cf. QA.md.)
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"
## Garde-fou : temps réel max par jour (ms) avant de déclarer un blocage.
const DAY_TIMEOUT_MSEC: int = 420_000

var _seed: int = 7
var _profile: SimProfile = null
var _speed: float = 8.0
## `--qa-credits=N` : solde de départ (le bot `--autoplay`, ~70 % de précision,
## s'effondre sinon avant l'Acte II ; permet de jouer la vraie scène jusqu'au J30).
var _credits: int = -1
var _data: DataCatalog = null
var _day_started_msec: int = 0
var _last_day: int = 0
var _handled: Dictionary = {}
var _issues: PackedStringArray = []
var _done: bool = false
var _reload: bool = false
## `--qa-load=/chemin/slot.json` : reprend une sauvegarde réelle (migrations en chaîne jusqu’à v5).
var _load_path: String = ""
var _reloaded_day: int = 0
## `--qa-story` : partie en mode Récit (D-102).
var _story: bool = false
const SLOT: int = SaveService.DEFAULT_SLOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-seed="):
			_seed = arg.trim_prefix("--qa-seed=").to_int()
		elif arg.begins_with("--qa-speed="):
			_speed = maxf(arg.trim_prefix("--qa-speed=").to_float(), 1.0)
		elif arg.begins_with("--qa-credits="):
			_credits = arg.trim_prefix("--qa-credits=").to_int()
		elif arg == "--qa-reload":
			_reload = true
		elif arg == "--qa-story":
			_story = true
		elif arg.begins_with("--qa-load="):
			_load_path = arg.trim_prefix("--qa-load=")
		elif arg.begins_with("--qa-profile="):
			_profile = SimProfile.preset(StringName(arg.trim_prefix("--qa-profile=")))
	if _profile == null:
		_profile = SimProfile.preset(&"default")
	_data = DataCatalog.load_from()
	SaveService.delete_slot(SLOT)
	Campaign.new_game(_data, _seed, SLOT, GameState.DIFFICULTY_STORY if _story else GameState.DIFFICULTY_HARD)
	if not _load_path.is_empty():
		if not _import_save(_load_path) or not GameState.load_from_slot(SLOT):
			_issue("sauvegarde %s refusée" % _load_path)
			_finish(1)
			return
		_seed = GameState.campaign_seed
		print("QA_LOADED %s day=%d credits=%d home=%s" % [_load_path.get_file(), GameState.current_day, GameState.credits,
				GameState.household.to_dict()])
	if _credits >= 0:
		GameState.credits = _credits
		if not _load_path.is_empty():
			# La sauvegarde reprise suit le solde imposé (contrôle de rechargement).
			GameState.save_to_slot(SLOT)
	Engine.time_scale = _speed
	print("QA_START seed=%d profile=%s speed=%.1f difficulty=%s" % [_seed, _profile.name, _speed, GameState.difficulty])
	get_tree().change_scene_to_file(DAY_SCENE)
	_day_started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if _done:
		return
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null:
		return
	if GameState.current_day != _last_day:
		_on_new_day()
	if _reload and GameState.current_day > 1 and _reloaded_day != GameState.current_day and scene.screen is BriefingScreen \
			and not GameState.has_flag(Campaign.FLAG_ENDING):
		_reload_from_save()
		return
	if Time.get_ticks_msec() - _day_started_msec > DAY_TIMEOUT_MSEC:
		_issue("BLOCAGE J%d : phase %s, écrans %s" % [GameState.current_day,
				DayPhase.Kind.keys()[scene.day_controller.phase], scene.screen_history])
		_finish(1)
		return
	var screen: ScreenBase = scene.screen
	if screen == null or not is_instance_valid(screen) or screen.is_closing() or _handled.has(screen.get_instance_id()):
		return
	if screen is ShiftSummaryScreen:
		_handled[screen.get_instance_id()] = true
		_check_summary(scene)
		(screen as ShiftSummaryScreen).continue_button.pressed.emit.call_deferred()
	elif screen is EveningScreen:
		_handled[screen.get_instance_id()] = true
		_drive_evening.call_deferred(screen as EveningScreen)
	elif screen is ChapterScreen:
		_handled[screen.get_instance_id()] = true
		print("QA_CHAPTER day=%d recap=%s act2=%s" % [GameState.current_day, (screen as ChapterScreen).recap_keys,
				Campaign.is_act2()])
		(screen as ChapterScreen).continue_button.pressed.emit.call_deferred()
	elif screen is EndScreen:
		_handled[screen.get_instance_id()] = true
		_on_end(scene, screen as EndScreen)


## `--qa-load` : sauvegarde v1–v5 (`slot_0.json`) migrée par le vrai
## `SaveService.migrate_legacy`, ou état v6 écrit tel quel dans l'emplacement.
func _import_save(path: String) -> bool:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	var raw: Dictionary = parsed
	if SaveService.as_int(raw.get("version", 0)) < SaveService.VERSION:
		var legacy: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR).path_join(SaveService.LEGACY_FILE)
		DirAccess.make_dir_recursive_absolute(legacy.get_base_dir())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(legacy))
		return SaveService.migrate_legacy() == SLOT
	var data: Dictionary = SaveService.parse(text, path)
	return not data.is_empty() and SaveService.save_slot(data, SLOT) == OK


func _on_new_day() -> void:
	# Après la fin (J30 ou fin anticipée), la partie est archivée (D-101).
	if _last_day > 0 and not GameState.has_flag(Campaign.FLAG_ENDING):
		_check_save_roundtrip()
	_last_day = GameState.current_day
	_day_started_msec = Time.get_ticks_msec()


## `--qa-reload` : « Quitter → Continuer » au briefing du nouveau jour (la
## scène précédente, soirée ou « CHAPITRE II », est terminée).
func _reload_from_save() -> void:
	_reloaded_day = GameState.current_day
	var before: String = JSON.stringify(GameState.to_save_dict(), "", true)
	if not GameState.load_from_slot():
		_issue("J%d : sauvegarde illisible au rechargement" % GameState.current_day)
		return
	if GameState.active_slot != SLOT:
		_issue("J%d : « Continuer » a repris l'emplacement %d" % [GameState.current_day, GameState.active_slot])
	if JSON.stringify(GameState.to_save_dict(), "", true) != before:
		_issue("J%d : état chargé ≠ état en mémoire" % GameState.current_day)
	print("QA_RELOAD day=%d" % GameState.current_day)
	_handled.clear()
	get_tree().reload_current_scene.call_deferred()


func _check_summary(scene: DayScene) -> void:
	var s: DaySummary = scene.last_summary
	if s == null:
		_issue("J%d : bilan sans DaySummary" % GameState.current_day)
		return
	var home: PackedStringArray = []
	for member: Household.Member in GameState.household.members:
		home.append("%s:%s" % [member.id, member.state_key().trim_prefix("hh_state_")])
	print("QA_DAY day=%d processed=%d/%d correct=%d citations=%d net=%d overrun=%d quota_refusals=%d credits=%d flags=%s home=%s" % [
			GameState.current_day, s.get_processed_count(), s.planned_cases, s.get_correct_count(),
			s.get_citation_count(), s.get_net(), s.get_overrun_count(), s.get_quota_refusal_count(), GameState.credits,
			_flags_text(), ",".join(home)])
	if s.get_processed_count() > s.planned_cases:
		_issue("J%d : traités %d > prévus %d" % [GameState.current_day, s.get_processed_count(), s.planned_cases])


func _drive_evening(evening: EveningScreen) -> void:
	var day: int = GameState.current_day
	var before: int = GameState.credits
	for event_id: StringName in _profile.choices:
		var event: EveningEvent = evening.get_event(event_id)
		# QA-036 : option choisie par intention (variante conditionnelle au même libellé).
		var option: EveningOptionDef = _profile.option_for(event)
		var option_id: StringName = option.id if option != null else _profile.choices[event_id]
		if option != null and option.ends_campaign != &"":
			# Chemin joueur : la boîte « QUITTER HALCYON ? » puis CONFIRMER.
			evening.request_choice(event_id, option_id)
			if evening.confirm_layer == null:
				_issue("J%d : pas de confirmation pour %s:%s" % [day, event_id, option_id])
			elif not evening.accept_final_confirm():
				print("QA_NOTE J%d : choix %s:%s refusé par l'écran" % [day, event_id, option_id])
			continue
		if event != null and not evening.choose(event_id, option_id):
			print("QA_NOTE J%d : choix %s:%s refusé par l'écran" % [GameState.current_day, event_id, option_id])
	if evening.luciole_pending and _profile.report_note:
		evening.call(&"_decide_luciole", true)
	var parts: PackedStringArray = []
	for line: ExpenseLine in evening.lines:
		parts.append("%s:%d%s%s" % [line.id, line.cost, "" if line.paid else "(non)", "!" if line.mandatory else ""])
	var events: PackedStringArray = []
	for event: EveningEvent in evening.events:
		events.append(String(event.id))
	evening.confirm()
	print("QA_EVENING day=%d before=%d income=%d choices=%s events=%s lines=%s" % [day, before, evening.income_total(),
			evening.choices, ",".join(events), " ".join(parts)])
	await get_tree().process_frame
	var button: Button = evening.get_report_button()
	if button == null:
		_issue("J%d : pas de bouton après la nuit" % (GameState.current_day - 1))
		return
	if GameState.credits < -200 or GameState.credits > 2000:
		_issue("J%d : solde aberrant %d" % [GameState.current_day - 1, GameState.credits])
	button.pressed.emit()


func _check_save_roundtrip() -> void:
	if not SaveService.has_save(SLOT):
		_issue("J%d : pas de sauvegarde automatique après la soirée" % GameState.current_day)
		return
	if not SaveService.list_snapshots(SLOT).has(GameState.current_day):
		_issue("J%d : pas d'instantané du matin" % GameState.current_day)
	var probe: Dictionary = GameState.to_save_dict()
	GameState.apply_save_dict(SaveService.load_current(SLOT))
	var reloaded: Dictionary = GameState.to_save_dict()
	for key: String in probe:
		if JSON.stringify(probe[key], "", true) != JSON.stringify(reloaded.get(key), "", true):
			_issue("J%d : sauvegarde relue ≠ état (clé %s)" % [GameState.current_day, key])
	GameState.apply_save_dict(probe)


func _on_end(scene: DayScene, end: EndScreen) -> void:
	var ending: String = str(GameState.get_flag(Campaign.FLAG_ENDING, end.ending))
	var lines: PackedStringArray = end.epilogue_lines()
	for line: String in lines:
		if _looks_like_key(line):
			_issue("fin %s : clé brute « %s »" % [ending, line])
	print("QA_END seed=%d profile=%s ending=%s day=%d credits=%d compliance=%.2f screens=%s epilogue_lines=%d" % [
			_seed, _profile.name, ending, GameState.current_day, GameState.credits, Campaign.compliance(),
			scene.screen_history, lines.size()])
	var meta: Dictionary = SaveService.load_meta(SLOT)
	if SaveService.has_save(SLOT) and (str(meta.get("status", "")) != SaveService.STATUS_ENDED
			or str(meta.get("ending_id", "")) != ending):
		_issue("partie non archivée après la fin (%s)" % meta)
	if EndingService.ALL_ENDINGS.has(StringName(ending)) \
			and not ProfileService.has_seen_ending(ProfileService.load_profile(), ending):
		_issue("fin %s absente du profil" % ending)
	_finish(0)


static func _looks_like_key(text: String) -> bool:
	var re: RegEx = RegEx.create_from_string("^[a-z0-9]+(_[a-z0-9]+)+$")
	return re.search(text.strip_edges()) != null


func _flags_text() -> String:
	var parts: PackedStringArray = []
	for flag: StringName in [&"loyalty", &"lucioles_trust", &"suspicion", &"solidarite", &"registre", &"quota_overrun"]:
		parts.append("%s:%s" % [flag, GameState.get_flag(flag, 0)])
	return ",".join(parts)


func _issue(text: String) -> void:
	_issues.append(text)
	print("QA_ISSUE %s" % text)


func _finish(code: int) -> void:
	_done = true
	Engine.time_scale = 1.0
	print("QA_DONE issues=%d" % _issues.size())
	SaveService.delete_slot(SLOT)
	# Sons arrêtés et retirés par l'AudioServer avant de quitter (QA-025).
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", code)
	else:
		get_tree().quit(code)
