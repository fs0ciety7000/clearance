## Lanceur des outils QA qui ont besoin des autoloads (docs/QA.md §2).
##
## Un script `--script` est compilé avant l'enregistrement des autoloads
## (`GameState`, `Settings`, `EventBus`) : ce lanceur ne référence aucune classe
## du projet, attend la première frame puis ajoute à la racine le nœud QA
## désigné par `--qa-node=res://tools/qa_campaign.gd` (défaut).
##   godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_campaign.gd …
extends SceneTree

var _path: String = "res://tools/qa_campaign.gd"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-node="):
			_path = arg.trim_prefix("--qa-node=")
	_boot.call_deferred()


func _boot() -> void:
	await process_frame
	var script: GDScript = load(_path) as GDScript
	if script == null:
		push_error("qa_boot: %s illisible" % _path)
		quit(2)
		return
	var node: Node = script.new()
	node.name = "QA"
	root.add_child(node)
