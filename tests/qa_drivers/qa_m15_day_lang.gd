## Passe QA M15 (docs/QA.md §18) — une journée sans bot (`qa_m14_day.gd` :
## J31, Garde de nuit, journée quelconque) **lue à l'écran** par
## `qa_m15_scan.gd` toutes les 15 images (textes restés dans l'autre langue,
## clés brutes, spécificateurs non résolus). `--qa-dump=/chemin.txt`.
## Usage :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --lang=en \
##     --qa-node=res://tests/qa_drivers/qa_m15_day_lang.gd --garde --qa-max-sec=500 [--qa-dump=…]
extends "res://tests/qa_drivers/qa_m14_day.gd"

const Scan := preload("res://tests/qa_drivers/qa_m15_scan.gd")

var _scan: RefCounted = null
var _frame_n: int = 0


func _ready() -> void:
	var dump: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-dump="):
			dump = arg.trim_prefix("--qa-dump=")
	_scan = Scan.new(dump)
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_frame_n += 1
	if _frame_n % 15 == 0 and _scan != null:
		_scan.call(&"scan", get_tree().root, "J%d" % GameState.current_day)


func _finish() -> void:
	if _done:
		return
	if _scan != null:
		_scan.call(&"scan", get_tree().root, "end")
		print("QA15_DAY_SUMMARY lang=%s %s" % [Localization.language(), _scan.call(&"summary")])
	super._finish()
