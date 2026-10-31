## Passe QA M14 (docs/QA.md §17) — migration du profil v2 → v3 sur un **vrai**
## `user://` écrit par la 0.13.0 (profil v2 + emplacement avec `case_memory`),
## puis Dossier PERSONNES ouvert par le vrai titre (`main.tscn`).
## Contrôles : version 3, `profile.v2.bak` identique à l'original, champs v2
## conservés, portraits = **dernière** rencontre de chaque personnage (liste
## blanche `portrait_cases`, visière telle que vue), aucun portrait pour un
## personnage jamais vu à la vitre, cartes du Dossier (portrait ou initiales).
##   XDG_DATA_HOME=<copie du user:// 0.13> godot --headless --script res://tools/qa_boot.gd -- \
##     --qa-node=res://tests/qa_drivers/qa_m14_profile.gd
## Sorties : QA14P_*, QA_ISSUE.
extends Node

var _issues: int = 0


func _ready() -> void:
	_run.call_deferred()


func _issue(text: String) -> void:
	_issues += 1
	print("QA_ISSUE %s" % text)


func _run() -> void:
	var dir: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	var before: Dictionary = SaveService.read_json(dir.path_join("profile.json"))
	var before_text: String = FileAccess.get_file_as_string(dir.path_join("profile.json"))
	print("QA14P_BEFORE version=%s keys=%s met=%d" % [before.get("version"), before.keys(), (before.get("characters_met", []) as Array).size()])
	# Mémoire des emplacements (référence indépendante de la migration).
	var memory: Dictionary = {}
	for slot: int in range(1, 4):
		var cur: Dictionary = SaveService.read_json(dir.path_join("slot_%d/current.json" % slot))
		if cur.is_empty():
			continue
		var mem: Variant = cur.get("case_memory", {})
		if mem is Dictionary:
			for k: Variant in mem:
				memory[k] = mem[k]
	print("QA14P_MEMORY entries=%d" % memory.size())
	# Le titre réel charge le profil (TitleMusic, Dossier) : migration.
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	await get_tree().create_timer(2.0).timeout
	var after: Dictionary = SaveService.read_json(dir.path_join("profile.json"))
	var bak: String = FileAccess.get_file_as_string(dir.path_join("profile.v2.bak"))
	print("QA14P_AFTER version=%s portraits=%d cinematics_seen=%s bak=%s bak_bytes_identical=%s bak_same_content=%s" % [after.get("version"),
			(after.get("portraits", {}) as Dictionary).size(), after.get("cinematics_seen"), not bak.is_empty(), bak == before_text,
			JSON.stringify(JSON.parse_string(bak)) == JSON.stringify(before)])
	if int(after.get("version", 0)) != ProfileService.VERSION:
		_issue("profil non migré (version %s)" % after.get("version"))
	if bak.is_empty() or JSON.stringify(JSON.parse_string(bak)) != JSON.stringify(before):
		_issue("profile.v2.bak absent ou différent")
	for key: Variant in before:
		if key != "version" and JSON.stringify(before[key]) != JSON.stringify(after.get(key)):
			_issue("champ v2 « %s » modifié par la migration" % key)
	# Référence : dernière rencontre de chaque personnage d'après la mémoire.
	var expected: Dictionary = ProfileService.portraits_from_memory(memory)
	var got: Dictionary = after.get("portraits", {})
	var chars: CharacterTableDef = CharacterTableDef.load_default()
	for chr_id: Variant in got:
		var e: Dictionary = got[chr_id]
		var mem_entry: Dictionary = memory.get(str(e.get("case_id", "")), {})
		var bytes: int = JSON.stringify(e).to_utf8_buffer().size()
		print("QA14P_PORTRAIT %s case=%s day=%s act=%s visor=%s mem_visor=%s bytes=%d" % [chr_id, e.get("case_id"), e.get("day"),
				e.get("act"), e.get("visor"), mem_entry.get("visor", "(0.13 : absent)"), bytes])
		if bytes > ProfileService.PORTRAIT_MAX_BYTES:
			_issue("portrait %s : %d o" % [chr_id, bytes])
		var want: Dictionary = expected.get(chr_id, {})
		if want.is_empty() or str(want.get("case_id")) != str(e.get("case_id")) or int(want.get("day", 0)) != int(e.get("day", 0)) \
				or str(want.get("visor")) != str(e.get("visor")) or JSON.stringify(want.get("appearance")) != JSON.stringify(e.get("appearance")):
			_issue("portrait %s ≠ dernière rencontre de la mémoire" % chr_id)
		var character: CharacterDef = chars.character_of(StringName(str(e.get("case_id", "")))) if chars != null else null
		if character != null and String(character.id) != str(chr_id):
			_issue("portrait %s rangé sous le mauvais personnage (%s)" % [chr_id, character.id])
		if character != null and not character.allows_portrait(StringName(str(e.get("case_id", "")))):
			_issue("portrait %s depuis un cas hors liste blanche %s" % [chr_id, e.get("case_id")])
		if mem_entry.is_empty():
			_issue("portrait %s sans rencontre en mémoire" % chr_id)
	for chr_id: Variant in expected:
		if not got.has(chr_id):
			_issue("portrait attendu absent : %s" % chr_id)
	print("QA14P_TOTAL bytes=%d" % JSON.stringify(got).to_utf8_buffer().size())
	# Dossier PERSONNES (vrai titre, vraie `DossierScreen`).
	var main: Node = get_tree().current_scene
	if main != null and main.has_method(&"open_dossier"):
		var dossier: Node = main.call(&"open_dossier")
		await get_tree().create_timer(1.0).timeout
		if dossier != null and dossier.has_method(&"show_tab"):
			dossier.call(&"show_tab", &"people")
		await get_tree().create_timer(2.0).timeout
		print("QA14P_DOSSIER opened=%s" % (dossier != null))
	print("QA14P_DONE issues=%d" % _issues)
	get_tree().quit(0)
