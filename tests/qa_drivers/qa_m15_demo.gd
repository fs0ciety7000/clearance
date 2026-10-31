## Passe QA M15 (docs/QA.md §18) — **démo J1 → J5 jouée en vraie scène**
## (`qa_campaign.gd` : `day.tscn`, bot `--autoplay`, soirées) avec `--demo`
## (debug) : après la soirée du J5, l'écran « Fin de la démo » doit s'ouvrir ;
## le pilote le lit (textes, focus, lien), presse VOIR LE JEU COMPLET (URL
## relevée sans ouvrir de navigateur), puis RETOUR AU TITRE, et lit le titre de
## la démo (Garde et Dossier grisés, CONTINUER, mention de version). Contrôle
## aussi les dossiers : tout dans `user://demo/saves`, rien dans `user://saves`.
## Sorties : QA15D_END …, QA15D_TITLE …, QA15D_DIRS …, QA_ISSUE.
## Usage :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --demo [--lang=en] \
##     --qa-node=res://tests/qa_drivers/qa_m15_demo.gd --autoplay --qa-seed=5 --qa-speed=10
extends "res://tools/qa_campaign.gd"

const MAIN_SCENE: String = "res://scenes/main/main.tscn"

var _demo_end_seen: bool = false
var _title_t: float = -1.0


func _process(delta: float) -> void:
	if _done:
		return
	var current: Node = get_tree().current_scene
	if _demo_end_seen:
		if current != null and current.scene_file_path == MAIN_SCENE:
			if _title_t < 0.0:
				_title_t = 0.0
			_title_t += delta / maxf(Engine.time_scale, 1.0)
			if _title_t > 1.0:
				_read_title(current)
		return
	var scene: DayScene = current as DayScene
	if scene != null and is_instance_valid(scene.screen) and scene.screen is DemoEndScreen \
			and not _handled.has(scene.screen.get_instance_id()):
		_handled[scene.screen.get_instance_id()] = true
		_read_demo_end.call_deferred(scene, scene.screen as DemoEndScreen)
		return
	super._process(delta)


func _read_demo_end(scene: DayScene, end: DemoEndScreen) -> void:
	_demo_end_seen = true
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: PackedStringArray = []
	_collect(end, texts)
	var focus: Control = end.get_viewport().gui_get_focus_owner()
	end.open_url = false
	end.store_button.pressed.emit()
	print("QA15D_END day=%d history=%s focus=%s store=%s title=%s urls=%s credits=%d" % [GameState.current_day,
			scene.screen_history, focus.name if focus != null else "∅", end.store_button.text, end.title_button.text,
			end.opened_urls, GameState.credits])
	print("QA15D_END_TEXT %s" % " | ".join(texts).replace("\n", "⏎"))
	if focus != end.store_button:
		_issue("fin de démo : focus initial %s" % (focus.name if focus != null else "aucun"))
	var meta: Dictionary = SaveService.load_meta(SLOT)
	var demo_dir: String = ProjectSettings.globalize_path(DemoMode.SAVES_DIR)
	var full_dir: String = ProjectSettings.globalize_path("user://saves")
	print("QA15D_DIRS resolve=%s demo_exists=%s full_exists=%s meta_status=%s meta_ending=%s meta_day=%s" % [
			SaveService.resolve_dir(SaveService.DEFAULT_DIR), DirAccess.dir_exists_absolute(demo_dir),
			DirAccess.dir_exists_absolute(full_dir), meta.get("status", ""), meta.get("ending_id", ""),
			meta.get("current_day", "")])
	if DirAccess.dir_exists_absolute(full_dir):
		_issue("la démo a écrit dans user://saves")
	if GameState.current_day > DemoMode.LAST_DAY + 1:
		_issue("état au-delà du J5 : J%d" % GameState.current_day)
	end.title_button.pressed.emit()


func _read_title(title: Node) -> void:
	var garde: Button = title.get(&"garde_button") as Button
	var dossier: Button = title.get(&"dossier_button") as Button
	var cont: Button = title.get(&"continue_button") as Button
	var locked: Label = title.get(&"garde_locked_label") as Label
	print("QA15D_TITLE garde_disabled=%s dossier_disabled=%s locked=%s continue=%s continue_disabled=%s version=%s" % [
			garde.disabled if garde != null else "?", dossier.disabled if dossier != null else "?",
			locked.text if locked != null else "?", cont.text if cont != null else "?",
			cont.disabled if cont != null else "?", title.call(&"version_text")])
	if garde == null or not garde.disabled or dossier == null or not dossier.disabled:
		_issue("titre de la démo : Garde ou Dossier accessibles")
	_finish(0)


func _collect(node: Node, out: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label or node is Button:
		var t: String = str(node.get(&"text")).strip_edges()
		if not t.is_empty():
			out.append(t)
	elif node is RichTextLabel:
		out.append((node as RichTextLabel).get_parsed_text().strip_edges())
	for child: Node in node.get_children():
		_collect(child, out)
