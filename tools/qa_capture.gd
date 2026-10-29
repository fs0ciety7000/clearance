## Capture QA réelle d'un écran (docs/QA.md §3) sans `override.cfg` : charge la
## scène de jour (ou `--qa-scene=`) avec les arguments de debug habituels
## (`--day`, `--screen`, `--flags`…), fixe la taille de la fenêtre
## (`--qa-size=1280x800` : Steam Deck), attend `--qa-wait` secondes de temps
## réel puis enregistre la dernière image dans `--qa-out=/chemin.png` et quitte.
## `--qa-quota=n/max` : publie un compteur QUOTA (capture de l'état « ATTEINT »).
## `--qa-after-check=s` : capture `s` secondes après la première comparaison
## (`discrepancy_checked`) — un résultat CONCORDANT ne reste affiché qu'un
## instant (M9 : Répondant ↔ Main courante) ; `--qa-wait` reste le délai maximal.
## M11 (lot B) : `--qa-set=clé:valeur,…` réglages de session (jamais écrits,
## ex. `color_vision:1`) ; `--qa-pad` simule une manette (glyphes d'invite) ;
## `--qa-focus-booth` donne le focus au plan de travail comme le ferait un
## appui sur la croix ; `--qa-measure` écrit dans la sortie la taille physique
## des valeurs de chaque document posé (D-085 : ≥ 12 px Deck, ≥ 13 px 1080p) ;
## `--qa-discord` cherche une paire de champs réellement discordante du cas
## courant (`DiscrepancyChecker`) et la compare en Mode Inspection (capture
## d'un bandeau DISCORDANCE, avec `--qa-after-check`).
## Correctifs M11 : `--qa-focus=tutorial-skip|tutorial-start|close-booth` pose le
## focus (comme la croix) sur PASSER L'ÉTAPE / COMMENCER du tutoriel ou sur
## FERMER LE GUICHET, 1,5 s avant la capture ; `--qa-close-briefing` ferme le
## briefing sans appeler de passager (guichet en attente, SUIVANT visible).
## Correctifs M12 : `--qa-focus=end-garde` ouvre la boîte « Terminer la garde »
## (barre) et pousse la croix → (focus TERMINER LA GARDE, piégé dans la boîte,
## QA-057).
## Lancé par `tools/qa_boot.gd` (autoloads requis), sous xvfb :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1280x800 \
##       --qa-wait=25 --qa-out=/tmp/qa/j12.png --day=12 --screen=shift --flags=scanner_luciole
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"
## `--qa-discord` : champs comparés (identité, validité) — jamais deux n° de série.
const IDENTITY_FIELDS: Array[StringName] = [&"family_name", &"given_name", &"birth_date", &"citizen_id", &"sex"]

var _scene: String = DAY_SCENE
var _size: Vector2i = Vector2i(1920, 1080)
var _wait: float = 20.0
var _out: String = ""
var _quota: PackedInt32Array = []
var _after_check: float = -1.0
var _measure: bool = false
var _pad: bool = false
var _focus_booth: bool = false
var _discord: bool = false
var _inspect: bool = false
var _focus_target: String = ""
var _close_briefing: bool = false
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts: PackedStringArray = arg.trim_prefix("--qa-size=").split("x")
			_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--qa-wait="):
			_wait = arg.trim_prefix("--qa-wait=").to_float()
		elif arg.begins_with("--qa-out="):
			_out = arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--qa-scene="):
			_scene = arg.trim_prefix("--qa-scene=")
		elif arg.begins_with("--qa-quota="):
			var q: PackedStringArray = arg.trim_prefix("--qa-quota=").split("/")
			_quota = PackedInt32Array([q[0].to_int(), q[1].to_int()])
		elif arg.begins_with("--qa-after-check="):
			_after_check = arg.trim_prefix("--qa-after-check=").to_float()
		elif arg.begins_with("--qa-set="):
			for pair: String in arg.trim_prefix("--qa-set=").split(",", false):
				var kv: PackedStringArray = pair.split(":")
				if kv.size() == 2:
					var key: StringName = StringName(kv[0])
					var current: Variant = Settings.get_default(key)
					Settings.set_session_value(key, (kv[1] == "true" or kv[1] == "1") if current is bool else kv[1].to_float())
		elif arg == "--qa-measure":
			_measure = true
		elif arg == "--qa-pad":
			_pad = true
		elif arg == "--qa-focus-booth":
			_focus_booth = true
		elif arg == "--qa-discord":
			_discord = true
		elif arg == "--qa-inspect":
			_inspect = true
		elif arg == "--qa-close-briefing":
			_close_briefing = true
		elif arg.begins_with("--qa-focus="):
			_focus_target = arg.trim_prefix("--qa-focus=")
	if _after_check >= 0.0:
		EventBus.discrepancy_checked.connect(_on_checked, CONNECT_ONE_SHOT)
	get_window().size = _size
	get_tree().change_scene_to_file(_scene)


func _on_checked(_result: Discrepancy) -> void:
	_wait = minf(_wait, _t + _after_check)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _quota.size() == 2 and _t > 2.0:
		EventBus.quota_changed.emit(_quota[0], _quota[1])
	if _pad and _t > 1.0:
		_pad = false
		InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	if _close_briefing and _t > 1.5:
		_close_briefing = false
		var day: DayScene = _find(get_tree().root, func(n: Node) -> bool: return n is DayScene) as DayScene
		if day != null and day.briefing != null and is_instance_valid(day.briefing):
			day.briefing.close()
	if _inspect and _t > 8.0:
		_inspect = false
		var booth: ComparisonUI = _find(get_tree().root, func(n: Node) -> bool: return n is ComparisonUI) as ComparisonUI
		if booth != null:
			booth.set_inspection_active(true)
	if _discord and _t > 8.0:
		_discord = false
		_compare_discordant_pair()
	if _focus_booth and _t > _wait - 1.5:
		_focus_booth = false
		var ui: Node = _find(get_tree().root, func(n: Node) -> bool: return n is ComparisonUI)
		if ui != null:
			(ui as ComparisonUI).focus_default()
	if not _focus_target.is_empty() and _t > _wait - 1.5:
		_apply_focus_target()
		_focus_target = ""
	if _t < _wait:
		return
	_done = true
	if _measure:
		_print_measure()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if _out.is_empty() or image == null:
		push_error("qa_capture: rien à enregistrer")
		get_tree().quit(1)
		return
	image.save_png(_out)
	print("QA_CAPTURE %s %dx%d" % [_out, image.get_width(), image.get_height()])
	# Sons arrêtés et retirés par l'AudioServer avant de quitter (QA-025).
	get_tree().root.get_node("AudioMixBarrier").call(&"quit_after_silence", 0)


func _apply_focus_target() -> void:
	var target: Control = null
	match _focus_target:
		"tutorial-skip", "tutorial-start":
			var tut: TutorialOverlay = _find(get_tree().root, func(n: Node) -> bool: return n is TutorialOverlay) as TutorialOverlay
			if tut != null:
				target = tut.skip_step_button if _focus_target == "tutorial-skip" else tut.start_button
		"end-garde":
			var day: DayScene = _find(get_tree().root, func(n: Node) -> bool: return n is DayScene) as DayScene
			if day != null and day.request_end_garde() != null:
				await get_tree().process_frame
				await get_tree().process_frame
				var right: InputEventAction = InputEventAction.new()
				right.action = &"ui_right"
				right.pressed = true
				Input.parse_input_event(right)
				return
		"close-booth":
			var ui: ComparisonUI = _find(get_tree().root, func(n: Node) -> bool: return n is ComparisonUI) as ComparisonUI
			if ui != null:
				target = ui.top_bar.close_button
	if target != null and target.is_visible_in_tree():
		target.grab_focus()
	else:
		print("QA_FOCUS %s introuvable" % _focus_target)


func _find(node: Node, pred: Callable) -> Node:
	if pred.call(node):
		return node
	for child: Node in node.get_children():
		var found: Node = _find(child, pred)
		if found != null:
			return found
	return null


## Taille physique des valeurs (police × échelle du document × échelle de la
## fenêtre) de chaque document posé : minimum et médiane (D-085).
func _print_measure() -> void:
	var bench: Workbench = _find(get_tree().root, func(n: Node) -> bool: return n is Workbench) as Workbench
	if bench == null:
		print("QA_MEASURE aucun plan de travail")
		return
	var screen: float = get_viewport().get_final_transform().get_scale().x
	print("QA_MEASURE écran %.3f plan %s échelle %.3f piles %s" % [screen, bench.size, bench.fit_scale, bench.is_stacked()])
	for view: DocumentView in bench.views:
		var sizes: Array[float] = []
		var labels: Array[float] = []
		for item: DocFieldView in view.fields:
			var px: float = item.value_font_px() * view.get_global_transform().get_scale().x * screen
			sizes.append(px)
			labels.append(item.label_font_px() * view.get_global_transform().get_scale().x * screen)
		sizes.sort()
		labels.sort()
		if sizes.is_empty():
			continue
		print("QA_MEASURE %-14s %s taille %s valeurs min %.1f px · médiane %.1f px · libellés min %.1f px" % [
			view.get_document_id(), "devant" if bench.is_front(view) else "onglet", view.size, sizes[0],
			sizes[sizes.size() >> 1], labels[0]])


## Première paire discordante du cas courant, comparée comme le ferait le joueur.
func _compare_discordant_pair() -> void:
	var ui: ComparisonUI = _find(get_tree().root, func(n: Node) -> bool: return n is ComparisonUI) as ComparisonUI
	var session: InspectionSession = _find(get_tree().root, func(n: Node) -> bool: return n is InspectionSession) as InspectionSession
	if ui == null or session == null or session.case == null:
		print("QA_DISCORD sans cas")
		return
	var refs: Array[FieldRef] = []
	for view: DocumentView in ui.workbench.views:
		for item: InspectableItem in view.get_items():
			if item.comparable:
				refs.append(item.ref)
	refs.append(FieldRef.today())
	# Paires parlantes d'abord : date du jour, puis même champ d'identité.
	var pairs: Array[Array] = []
	for i: int in refs.size():
		for j: int in range(i + 1, refs.size()):
			var today: bool = refs[i].is_today() or refs[j].is_today()
			var other: FieldRef = refs[j] if refs[i].is_today() else refs[i]
			if today and other.field_id == &"expiry_date":
				pairs.append([0, refs[i], refs[j]])
			elif not today and refs[i].field_id == refs[j].field_id and IDENTITY_FIELDS.has(refs[i].field_id):
				pairs.append([1, refs[i], refs[j]])
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	for pair: Array in pairs:
		var a: FieldRef = pair[1]
		var b: FieldRef = pair[2]
		var result: Discrepancy = DiscrepancyChecker.check(session.case, a, b, session.ctx)
		if result.confirmed:
			ui.set_inspection_active(true)
			ui.pick(a)
			ui.pick(b)
			print("QA_DISCORD %s.%s ≠ %s.%s" % [a.document_id, a.field_id, b.document_id, b.field_id])
			return
	print("QA_DISCORD aucune paire discordante")
