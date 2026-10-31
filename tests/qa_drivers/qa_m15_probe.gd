## Sonde QA M15 (docs/QA.md §18), lancée dans un **processus séparé** par
## `tests/integration/test_qa_m15.gd` : un comportement qui dérègle la pile de
## GDScript (QA-083) ne doit pas fausser la suite GUT.
##   godot --headless --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m15_probe.gd \
##       --probe=retranslate --text=<texte>
## Sortie : `QA15_PROBE in=<json> out=<json>` par texte, puis `QA15_PROBE_DONE`.
extends Node


func _ready() -> void:
	var texts: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--text="):
			texts.append(arg.trim_prefix("--text="))
	for text: String in texts:
		var out: String = Localization.retranslate_text(text)
		print("QA15_PROBE in=%s out=%s" % [JSON.stringify(text), JSON.stringify(out)])
	print("QA15_PROBE_DONE")
	get_tree().quit(0)
