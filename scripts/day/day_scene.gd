## Scène de jour (`res://scenes/main/day.tscn`, ARCHITECTURE §3, §8 ; GDD §3.2).
##
## Assemble la bande 3D (`SubViewportContainer` y 56→432, UI_FLOW §2), les
## services logiques (`DayController`, `DayClock`, `InspectionSession`,
## `PortraitService`), l'UI 2D `res://scenes/ui/comparison_ui.tscn` (instanciée
## dans `UISlot`, **au-dessus** de la bande 3D ; sa bande B est transparente et
## `MOUSE_FILTER_IGNORE`, les clics atteignent le booth).
## M5 — boucle de jour complète : briefing (`BriefingScreen`, ferme l'INTRO
## → `close_intro()`) → shift (tutoriel d'Okonkwo au J1) → sirène → bilan
## (`ShiftSummaryScreen`) → soirée (`EveningScreen`, `Campaign` : débit, foyer,
## sauvegarde) → jour suivant (rechargement de la scène) ou écran de fin
## (`EndScreen`) ; menu pause (`PauseMenu`) au-dessus de tout.
## L'UI reçoit `portrait_provider` (PortraitService) et `face_rect_provider`
## (projection du visage de l'acteur au guichet en coordonnées globales).
## Arguments utilisateur (après `--`) : `--day=N`, `--seed=N`, `--no-booth`,
## `--no-ui`, `--autoplay` (bot de démonstration, captures), `--reduce-motion`,
## `--debug-keys` (raccourcis N/V/X/R/C/I, en conflit avec l'UI : debug
## seulement). Captures M5 : `--screen=briefing|citation|summary|evening|end|pause|options`,
## `--start-case=N` (premier passager appelé), `--approve-all` (bot qui
## approuve tout), `--household=demo` (foyer malade / froid), `--ending=…`.
## M7 : `--screen=shift` (briefing fermé, premier passager appelé),
## `--screen=detain` (idem puis tampon DÉTENTION : escorte de la Garde),
## `--rulebook-tab=wanted|origins|implants|symbols|seals` (+ `--inspect` : Mode
## Inspection, premier avis sélectionné ; `symbols` : paire marque luciole ↔
## bulletin comparée si le passager porte la marque), `--flags=a,b:2` (drapeaux / jauges de
## démonstration), `--item=keep|return|report` (décision sur l'objet glissé),
## `--zoom-doc=<id>` (loupe sur un document).
## M8 (Acte II) : `--screen=chapter2` (interstitiel « CHAPITRE II »),
## `--lights-out` (avec `--screen=shift` : annonce de la grève du J20, lumières
## coupées), `--confirm-scan` (premier lien suggéré du scanner confirmé),
## `--rulebook-tab=employers|vessels|revoked` ; `--choose` passe par
## `EveningScreen.request_choice` (confirmation d'« Embarquer »).
## Tous ces arguments passent par `DebugArgs` : ignorés dans un export
## *release*, et ceux qui modifient la partie (`--seed`, `--day`, `--screen`…)
## ne s'appliquent qu'à la première scène du processus (QA-017).
## M8 (Acte II, ARCHITECTURE §7.2) : revenus du soir passés à la soirée
## (`EveningScreen.set_income`) ; interstitiel « CHAPITRE II » après la soirée
## pivot du J10 quand la campagne continue (`ChapterScreen`) ; annonce qui
## termine le shift (`HallAnnouncementDef.ends_shift`, grève du J20) : les
## lumières du guichet s'éteignent (`BoothDirector.lights_out`), voile noir qui
## s'épaissit, puis fondu au noir complet avant le bilan.
## M9 (Acte III, ARCHITECTURE §7.3) : soirée pivot du J20 ouverte par la carte
## « FIN DE L'ACTE II » (`EveningScreen`), verdict de la Déposition recalculé
## avec le choix du joueur (`EveningScreen.audit_preview` →
## `Campaign.preview_evening`), interstitiel « CHAPITRE III · TÉMOINS » avant
## le J21. Captures : `--screen=chapter3`, `--hold-card` (la carte reste
## affichée), `--rulebook-tab=ledger|summons` (+ `--inspect` : Répondant ↔
## Main courante, Convocation ↔ onglet ; la Main courante est préremplie des
## passagers en règle qui précèdent `--start-case`).
## M11 (lot C) : mode Récit — « FERMER LE GUICHET » proposé quand
## `DayController.can_close_booth()` (réévalué sur `quota_changed`,
## `day_phase_changed`, `difficulty_changed`) ; tutoriel interactif du J1
## (`TutorialOverlay`, demandé par l'écran titre via `TutorialOverlay.pending`)
## posé à la fermeture du briefing, sous les écrans plein cadre. Captures :
## `--story` (partie en Récit), `--close-booth` (bouton forcé, capture),
## `--tutorial` (+ `--tutorial-step=N`).
class_name DayScene
extends Control

const COMPARISON_UI_PATH: String = "res://scenes/ui/comparison_ui.tscn"
const TITLE_SCENE_PATH: String = "res://scenes/main/main.tscn"
## Propriétés que l'UI expose pour recevoir les fournisseurs.
const PORTRAIT_PROVIDER_PROPERTY: StringName = &"portrait_provider"
const FACE_RECT_PROVIDER_PROPERTY: StringName = &"face_rect_provider"
## Autoplay : le briefing se ferme seul.
const AUTOPLAY_BRIEFING_SEC: float = 1.5
## Délai entre la sirène (`day_ended`) et l'écran de bilan.
const SIREN_DELAY_SEC: float = 1.2
## `--household=demo` : solde du matin (captures de la soirée).
const DEMO_MORNING_CREDITS: int = 14
## Grève du J20 : extinction des lumières, voile sur le guichet, fondu final.
const LIGHTS_OUT_SEC: float = DS.DUR_DRAMATIC * 4.0
const LIGHTS_OUT_VEIL: float = 0.62
const BLACKOUT_SEC: float = DS.DUR_DRAMATIC * 2.5

@onready var booth_container: SubViewportContainer = %BoothContainer
@onready var booth_viewport: SubViewport = %BoothViewport
@onready var booth: BoothDirector = %Booth
@onready var day_controller: DayController = %DayController
@onready var day_clock: DayClock = %DayClock
@onready var inspection: InspectionSession = %InspectionSession
@onready var portrait_service: PortraitService = %PortraitService
@onready var ui_slot: Control = %UISlot

var ui: Control = null
var briefing: BriefingScreen = null
## Écran plein cadre courant (bilan, soirée, fin), null pendant le shift.
var screen: ScreenBase = null
var pause_menu: PauseMenu = null
var intercom: OkonkwoIntercom = null
var data: DataCatalog = null
var debug_keys: bool = false
var last_summary: DaySummary = null
## Écrans enchaînés dans l'ordre (diagnostic, tests).
var screen_history: Array[StringName] = []
var _autoplay: DemoAutoplay = null
var _args: Dictionary = {}
var _overlay: Control = null
## Acte II : lumières coupées (grève du J20) et voile noir correspondant.
var lights_out_active: bool = false
var blackout: ColorRect = null
## M11 lot C : tutoriel du J1 (null hors tutoriel) et sa demande.
var tutorial: TutorialOverlay = null
var _tutorial_requested: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	_args = DebugArgs.for_scene()
	debug_keys = _args.has("debug-keys")
	if _args.has("no-booth"):
		_replace_booth_with_null()
	if _args.has("reduce-motion"):
		Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true) # jamais persisté (QA-006)
	data = DataCatalog.load_from()
	if GameState.current_day <= 0 or _args.has("seed"):
		var seed_text: String = _args.get("seed", "0")
		Campaign.new_game(data, seed_text.to_int(), SaveService.DEFAULT_SLOT,
				GameState.DIFFICULTY_STORY if _args.has("story") else GameState.DIFFICULTY_HARD)
	elif _args.has("story"):
		GameState.difficulty = GameState.DIFFICULTY_STORY
	if _args.has("day"):
		var day_text: String = _args["day"]
		GameState.current_day = day_text.to_int()
	if _args.get("household", "") == "demo":
		_demo_household()
	if _args.has("flags"):
		_demo_flags(_arg("flags"))
	if _args.has("credits"):
		GameState.add_credits(_arg("credits").to_int())
	if not _args.has("no-ui"):
		_load_ui()
	blackout = ColorRect.new()
	blackout.name = "Blackout"
	blackout.color = Color(DS.BG_VOID, 0.0)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout.visible = false
	add_child(blackout)
	_overlay = Control.new()
	_overlay.name = "Screens"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.quit_to_title_requested.connect(go_to_title)
	add_child(pause_menu)
	intercom = OkonkwoIntercom.new()
	intercom.name = "OkonkwoIntercom"
	intercom.spoke.connect(_on_intercom)
	add_child(intercom)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.hall_announced.connect(_on_hall_announced)
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		comparison.close_booth_requested.connect(request_close_booth)
		EventBus.quota_changed.connect(func(_u: int, _m: int) -> void: refresh_close_booth.call_deferred())
		EventBus.day_phase_changed.connect(func(_p: DayPhase.Kind, _c: StringName) -> void: refresh_close_booth.call_deferred())
		EventBus.difficulty_changed.connect(func(_d: StringName) -> void: refresh_close_booth.call_deferred())
	# Tutoriel du J1 : demandé par le titre (nouvelle partie / reprise au J1), ou `--tutorial`.
	_tutorial_requested = (TutorialOverlay.pending or _args.has("tutorial")) and GameState.current_day == 1 and comparison != null
	TutorialOverlay.pending = false
	if not day_controller.start_day(data, GameState.current_day, GameState.get_day_seed(), GameState.get_true_flags(),
			Campaign.memory_for_day(data)):
		return
	if _args.has("start-case"):
		var start_text: String = _args["start-case"]
		day_controller.next_index = clampi(start_text.to_int(), 0, day_controller.day.passenger_count - 1)
	portrait_service.clear_cache()
	_show_briefing(_args.has("autoplay"))
	if _args.has("autoplay"):
		_autoplay = DemoAutoplay.new()
		_autoplay.name = "DemoAutoplay"
		_autoplay.controller = day_controller
		_autoplay.ui = ui as ComparisonUI
		_autoplay.approve_all = _args.has("approve-all")
		add_child(_autoplay)
	_debug_screen(_arg("screen"))


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


## Fournisseur de portraits pour l'UI (`Callable(PassengerAppearance) -> Texture2D`).
func get_portrait_provider() -> Callable:
	return portrait_service.get_portrait


## Rectangle global (canvas de la fenêtre) du visage de l'acteur au guichet :
## projection caméra dans le SubViewport, mise à l'échelle et décalée par le
## `SubViewportContainer`.
func get_face_rect() -> Rect2:
	if booth == null or booth_viewport.size.x <= 0 or booth_viewport.size.y <= 0:
		return Rect2()
	var r: Rect2 = booth.get_face_viewport_rect()
	var scale_factor: Vector2 = booth_container.size / Vector2(booth_viewport.size)
	var xform: Transform2D = booth_container.get_global_transform()
	var rect: Rect2 = Rect2(xform * (r.position * scale_factor), r.size * scale_factor * xform.get_scale())
	# Le cadre « VISAGE » reste dans la bande B (jamais sur la barre du haut).
	return rect.intersection(booth_container.get_global_rect())


func _load_ui() -> void:
	if not ResourceLoader.exists(COMPARISON_UI_PATH):
		return
	var scene: PackedScene = load(COMPARISON_UI_PATH)
	if scene == null:
		push_error("DayScene: %s illisible" % COMPARISON_UI_PATH)
		return
	ui = scene.instantiate()
	if PORTRAIT_PROVIDER_PROPERTY in ui:
		ui.set(PORTRAIT_PROVIDER_PROPERTY, get_portrait_provider())
	if FACE_RECT_PROVIDER_PROPERTY in ui and booth != null:
		ui.set(FACE_RECT_PROVIDER_PROPERTY, get_face_rect)
	ui_slot.add_child(ui)


# ---------------------------------------------------------------------------
# Enchaînement des écrans (GDD §3.2)
# ---------------------------------------------------------------------------

## Briefing du jour : ferme l'INTRO au clic sur « PRENDRE SON POSTE ».
func _show_briefing(auto_close: bool) -> void:
	briefing = BriefingScreen.new()
	briefing.name = "BriefingScreen"
	var content: BriefingContent = BriefingContent.build(day_controller.day, GameState.narrative_flags, GameState.household,
			consortium_advance())
	briefing.setup(content, GameState.household, GameState.credits, day_controller.day)
	briefing.closed.connect(_on_briefing_closed)
	_open(briefing, &"briefing")
	if auto_close:
		get_tree().create_timer(AUTOPLAY_BRIEFING_SEC).timeout.connect(briefing.close)


## Avance du Consortium (D-047) versée à la prise de poste : comptée au J1
## seulement (briefing, détail du solde de la soirée).
func consortium_advance() -> int:
	if data == null or day_controller.day == null or day_controller.day.day_number != 1:
		return 0
	return data.get_economy().starting_credits


func _on_briefing_closed() -> void:
	briefing = null
	screen = null
	_set_ui_active(true)
	day_controller.close_intro()
	if _tutorial_requested:
		_tutorial_requested = false
		start_tutorial()


## Pose le tutoriel interactif du J1 (sous les écrans plein cadre et la pause).
func start_tutorial() -> TutorialOverlay:
	if tutorial != null and is_instance_valid(tutorial):
		return tutorial
	tutorial = TutorialOverlay.new()
	tutorial.ui = ui as ComparisonUI
	tutorial.tree_exited.connect(func() -> void: tutorial = null)
	add_child(tutorial)
	move_child(tutorial, _overlay.get_index())
	if _args.has("tutorial-step"):
		tutorial.begin()
		for i: int in clampi(_arg("tutorial-step").to_int() - 1, 0, TutorialOverlay.STEPS.size() - 1):
			tutorial.skip_step()
	return tutorial


## Mode Récit : « FERMER LE GUICHET » proposé une fois le quota atteint.
func refresh_close_booth() -> void:
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison == null or not is_inside_tree():
		return
	var available: bool = day_controller.can_close_booth() and not day_controller.booth_closed
	if _args.has("close-booth") and GameState.is_story_mode() and day_controller.phase != DayPhase.Kind.SUMMARY:
		available = true # capture : bouton forcé
	comparison.set_close_booth_available(available)


## « FERMER LE GUICHET » : bilan tout de suite entre deux passagers, sinon
## après le passager en cours (`DayController.close_booth`).
func request_close_booth() -> bool:
	if not day_controller.close_booth():
		return false
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		comparison.set_close_booth_available(false)
		if day_controller.phase != DayPhase.Kind.SUMMARY:
			comparison.toasts.push(ToastStack.Kind.INFO, UiText.t("close_booth_toast_title", "GUICHET FERMÉ"),
					UiText.t("close_booth_toast", "Le bilan suit le passager en cours."))
	return true


func _on_day_ended(summary: DaySummary) -> void:
	last_summary = summary
	if _args.has("autoplay") and _autoplay != null:
		_autoplay.queue_free()
		_autoplay = null
	if lights_out_active:
		# Grève : plus de sirène, le Hall s'éteint jusqu'au noir complet.
		blackout.visible = true
		var tween: Tween = blackout.create_tween()
		tween.tween_property(blackout, "color:a", 1.0, DS.DUR_FAST if Settings.reduce_motion else BLACKOUT_SEC)
		tween.tween_callback(show_summary.bind(summary))
		return
	get_tree().create_timer(SIREN_DELAY_SEC).timeout.connect(show_summary.bind(summary))


# ---------------------------------------------------------------------------
# Acte II : lumières coupées (grève du J20)
# ---------------------------------------------------------------------------

func _on_hall_announced(text_key: String) -> void:
	if ends_shift_announcement(text_key):
		lights_out()


## Vrai si l'annonce `text_key` du jour courant termine le shift (grève du J20).
func ends_shift_announcement(text_key: String) -> bool:
	if day_controller == null or day_controller.day == null:
		return false
	for def: HallAnnouncementDef in day_controller.day.announcements:
		if def != null and def.ends_shift and def.text_key == text_key:
			return true
	return false


## Les vitres s'éteignent : lampes du guichet coupées, voile noir sur l'écran
## (l'annonce reste lisible au-dessus du voile partiel).
func lights_out() -> void:
	if lights_out_active:
		return
	lights_out_active = true
	var duration: float = DS.DUR_FAST if Settings.reduce_motion else LIGHTS_OUT_SEC
	if booth != null:
		booth.lights_out(duration)
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		comparison.set_lights_out(duration)
		return
	blackout.visible = true
	blackout.create_tween().tween_property(blackout, "color:a", LIGHTS_OUT_VEIL, duration)


func show_summary(summary: DaySummary) -> void:
	if screen != null and screen is ShiftSummaryScreen:
		return
	var summary_screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	summary_screen.name = "ShiftSummaryScreen"
	summary_screen.setup(summary, day_controller.day)
	summary_screen.finished.connect(func(_choice: StringName) -> void:
		if Campaign.has_evening(data):
			show_evening(summary)
		else:
			show_final(summary))
	_open(summary_screen, &"summary")


func show_evening(summary: DaySummary) -> void:
	var evening: EveningScreen = EveningScreen.new()
	evening.name = "EveningScreen"
	# M7 : événements du soir présentés par l'écran (choix du joueur) ; les
	# choix non faits reçoivent le choix par défaut (D-058).
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	evening.setup(day_controller.day, GameState.credits, summary.get_total_income() if summary != null else 0, lines,
			GameState.household, Campaign.luciole_note_pending(), consortium_advance())
	evening.set_events(events)
	evening.set_income(EveningService.income_lines(data.get_economy(), GameState.current_day, GameState.household,
			Campaign.evening_flags()))
	# Acte III : verdict de la Déposition recalculé avec le choix du joueur.
	evening.audit_preview = func(choices: Dictionary[StringName, StringName]) -> void:
		Campaign.preview_evening(data, lines, events, choices)
	evening.act_card_auto_close = not _args.has("hold-card")
	evening.luciole_decided.connect(Campaign.decide_luciole_note)
	evening.confirmed.connect(func(confirmed_lines: Array[ExpenseLine]) -> void:
		var report: EveningReport = Campaign.preview_evening(data, confirmed_lines, events, evening.get_choices())
		var ending: StringName = Campaign.close_evening(data, summary, report)
		evening.show_report(report, ending))
	evening.finished.connect(_after_evening)
	_open(evening, &"evening")


func _after_evening(choice: StringName) -> void:
	if choice == &"next":
		if chapter_two_pending():
			show_chapter_two()
			return
		if chapter_three_pending():
			show_chapter_three()
			return
		get_tree().reload_current_scene()
		return
	show_end(choice)


## Vrai juste après la soirée pivot du J10 si l'Acte II commence.
func chapter_two_pending() -> bool:
	return data != null and Campaign.is_act2() and GameState.current_day == data.get_economy().pivot_day + 1


## Interstitiel « CHAPITRE II » puis le J11 (rechargement de la scène).
func show_chapter_two() -> void:
	var chapter: ChapterScreen = ChapterScreen.new()
	chapter.name = "ChapterScreen"
	chapter.setup(GameState.narrative_flags)
	chapter.finished.connect(func(_choice: StringName) -> void: get_tree().reload_current_scene())
	_open(chapter, &"chapter2")


## Vrai juste après la soirée pivot du J20 si l'Acte III commence.
func chapter_three_pending() -> bool:
	return data != null and Campaign.is_act3() and GameState.current_day == data.get_economy().act3_pivot_day + 1


## Interstitiel « CHAPITRE III · TÉMOINS » puis le J21 (rechargement).
func show_chapter_three() -> void:
	var chapter: ChapterScreen = ChapterScreen.new()
	chapter.name = "ChapterScreen"
	chapter.setup(GameState.narrative_flags, 3)
	chapter.finished.connect(func(_choice: StringName) -> void: get_tree().reload_current_scene())
	_open(chapter, &"chapter3")


## Dernier jour sans soirée (J30 depuis D-086) → évaluation de la fin.
func show_final(summary: DaySummary) -> void:
	show_end(Campaign.close_final_day(data, summary))


func show_end(ending: StringName) -> void:
	# Toute fin archive la partie et l'inscrit au profil (D-101) — idempotent.
	GameState.end_campaign(ending)
	var end: EndScreen = EndScreen.new()
	end.name = "EndScreen"
	end.epilogue = Campaign.epilogue(ending)
	end.setup(ending, GameState.day_history, GameState.household, GameState.credits, GameState.narrative_flags,
			Campaign.compliance())
	end.finished.connect(func(_choice: StringName) -> void: go_to_title())
	_open(end, &"end")


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _open(p_screen: ScreenBase, id: StringName) -> void:
	if screen != null and is_instance_valid(screen) and not screen.is_closing():
		screen.queue_free()
	screen = p_screen
	screen_history.append(id)
	_set_ui_active(false)
	_overlay.add_child(p_screen)


## L'UI du guichet ne reçoit plus d'entrées sous un écran plein cadre.
func _set_ui_active(active: bool) -> void:
	if ui != null:
		ui.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_intercom(speaker_key: String, text_key: String) -> void:
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		comparison.say_intercom(UiText.t(speaker_key, speaker_key), UiText.t(text_key, text_key))


# ---------------------------------------------------------------------------
# Debug / captures
# ---------------------------------------------------------------------------

func _debug_screen(which: String) -> void:
	match which:
		"summary", "evening", "end":
			var summary: DaySummary = _simulated_summary()
			GameState.add_credits(summary.get_net())
			if briefing != null:
				briefing.closed.disconnect(_on_briefing_closed)
				briefing.queue_free()
				briefing = null
			if which == "summary":
				show_summary(summary)
			elif which == "evening":
				show_evening(summary)
				_debug_evening.call_deferred()
			else:
				_simulated_history()
				show_end(StringName(_arg("ending", "demo_complete")))
		"chapter2":
			if briefing != null:
				briefing.closed.disconnect(_on_briefing_closed)
				briefing.queue_free()
				briefing = null
			GameState.set_flag(EndingService.FLAG_ACT2, true)
			show_chapter_two()
		"chapter3":
			if briefing != null:
				briefing.closed.disconnect(_on_briefing_closed)
				briefing.queue_free()
				briefing = null
			GameState.set_flag(EndingService.FLAG_ACT2, true)
			GameState.set_flag(EndingService.FLAG_ACT3, true)
			show_chapter_three()
		"shift", "detain":
			# M7 : premier passager appelé (objets glissés, onglets, avis, escorte).
			if briefing != null:
				briefing.close()
			if _arg("rulebook-tab") == "ledger":
				_debug_prefill_ledger()
			EventBus.documents_presented.connect(_debug_shift.bind(which), CONNECT_ONE_SHOT)
			EventBus.next_case_requested.emit.call_deferred()
		"citation":
			# Ticket d'infraction imprimé pendant l'inspection d'un cas (DS §7.9).
			if briefing != null:
				briefing.close()
			EventBus.documents_presented.connect(_debug_citation, CONNECT_ONE_SHOT)
			EventBus.next_case_requested.emit.call_deferred()
		"pause", "options":
			if briefing != null:
				briefing.close()
			pause_menu.open.call_deferred()
			if which == "options":
				pause_menu.show_options.call_deferred()


## Mise en scène de capture M7 (après l'arrivée des documents).
func _debug_shift(_case_id: StringName, which: String) -> void:
	var comparison: ComparisonUI = ui as ComparisonUI
	await get_tree().create_timer(0.9).timeout
	if comparison == null:
		return
	var tab: String = _arg("rulebook-tab")
	if not tab.is_empty():
		comparison.rulebook.show_reference_tab(StringName(tab))
	var zoom_id: String = _arg("zoom-doc")
	if not zoom_id.is_empty():
		var view: DocumentView = comparison.workbench.get_view(StringName(zoom_id))
		if view != null:
			comparison.workbench.zoom_view(view, 1)
	var decision: String = _arg("item")
	if not decision.is_empty() and day_controller.current_case != null:
		var kinds: Dictionary[String, SlippedItem.Decision] = {"keep": SlippedItem.Decision.KEEP,
				"return": SlippedItem.Decision.RETURN, "report": SlippedItem.Decision.REPORT}
		var wanted_decision: SlippedItem.Decision = kinds.get(decision, SlippedItem.Decision.RETURN)
		for item: SlippedItem in day_controller.current_case.slipped_items:
			comparison.request_item_decision(item.id, wanted_decision)
	if _args.has("inspect"):
		comparison.set_inspection_active(true)
		if not comparison.wanted_notices.is_empty() and tab == "wanted":
			comparison.pick(comparison.wanted_notices[0].get_ref())
		elif tab == "revoked" and not comparison.revocations.is_empty():
			# Acte II : révocation du passager (sinon la première) ↔ son N° ID.
			var entry: RevokedEntry = comparison.revocations[0]
			for candidate: RevokedEntry in comparison.revocations:
				if day_controller.current_case != null and candidate.case_index == day_controller.current_case.index:
					entry = candidate
			comparison.pick(entry.get_ref())
			if day_controller.current_case != null:
				var ids: Array[FieldRef] = day_controller.current_case.find_refs_by_truth_path(&"citizen_id")
				if not ids.is_empty():
					comparison.pick(ids[0])
		elif (tab == "ledger" or tab == "summons") and day_controller.current_case != null:
			# Acte III : Répondant (permis) ↔ Main courante, Convocation ↔ onglet.
			var path: StringName = SponsorRule.SPONSOR_PATH if tab == "ledger" else SummonsRule.SUMMONS_PATH
			var refs: Array[FieldRef] = day_controller.current_case.find_refs_by_truth_path(path)
			var target: FieldRef = null
			var value: Variant = day_controller.current_case.get_value(refs[0]) if not refs.is_empty() else null
			if tab == "ledger":
				for entry: LedgerEntry in comparison.ledger:
					if value != null and FieldValue.equals(value, entry.citizen_id):
						target = entry.get_ref()
			else:
				for entry: SummonsEntry in comparison.summons:
					if value != null and FieldValue.equals(value, entry.number):
						target = entry.get_ref()
			if not refs.is_empty() and target != null:
				comparison.pick(refs[0])
				comparison.pick(target)
		elif tab == "symbols":
			# §4.9 : marque luciole (A) ↔ bulletin des symboles (B), vraie comparaison.
			for view: DocumentView in comparison.workbench.views:
				var mark: DocMarkView = view.get_mark_item(DocumentView.MARK_LUCIOLE)
				if mark != null:
					comparison.pick(mark.ref)
					comparison.pick(FieldRef.symbol(DocumentView.MARK_LUCIOLE))
					break
	if _args.has("confirm-scan"):
		comparison.confirm_suggestion()
	if _args.has("lights-out"):
		var strike: String = "hall_j20_strike"
		for def: HallAnnouncementDef in day_controller.day.announcements:
			if def != null and def.ends_shift:
				strike = def.text_key
		EventBus.hall_announced.emit(strike)
	if _args.has("ask"):
		comparison.open_question_menu()
	if which == "detain":
		await get_tree().create_timer(0.6).timeout
		comparison.get_stamp_button(VerdictKind.Kind.DETAIN).begin_hold()


## Capture de la Main courante : les passagers en règle qui précèdent
## `--start-case` sont inscrits comme s'ils avaient été approuvés (R34).
func _debug_prefill_ledger() -> void:
	var builder: CaseBuilder = day_controller.builder
	if builder == null:
		return
	for index: int in day_controller.next_index:
		var generated: GeneratedCase = builder.build(index)
		if generated != null and generated.key.expected_verdict == VerdictKind.Kind.APPROVE:
			builder.record_verdict(generated.case, VerdictKind.Kind.APPROVE)
	EventBus.ledger_changed.emit(builder.get_ledger())


func _debug_citation(_case_id: StringName) -> void:
	await get_tree().create_timer(0.8).timeout
	var result: CaseResult = CaseResult.new(day_controller.current_case_id())
	result.citation_reason_key = ScoringService.CIT_IRREGULAR_ENTRY
	result.citation_rule_id = &"r_id_card_valid"
	ScoringService.apply_citation(result, _arg("citation-number", "3").to_int(), day_controller.day)
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		comparison.show_citation(result)


## Jour simulé « réaliste » pour les captures : quelques erreurs variées.
func _simulated_summary() -> DaySummary:
	var policy: Callable = func(_case: Case, key: CaseKey, index: int) -> VerdictKind.Kind:
		if index == 1 or index == 6:
			return VerdictKind.Kind.APPROVE # supplication écoutée, fraude manquée
		return key.expected_verdict
	var limit: int = maxi(day_controller.day.passenger_count - 1, 1)
	var undocumented: Array[int] = [4]
	return DaySimulator.simulate(data, GameState.current_day, GameState.get_day_seed(), policy, true, true, limit, undocumented)


func _simulated_history() -> void:
	var balance: int = GameState.credits
	for n: int in range(1, maxi(GameState.current_day, 10) + 1):
		var s: DaySummary = DaySimulator.simulate(data, n, SeededRng.day_seed(GameState.campaign_seed, n),
				func(_c: Case, k: CaseKey, i: int) -> VerdictKind.Kind: return k.expected_verdict if i % 5 != 4 else VerdictKind.Kind.APPROVE)
		var spent: int = (38 if n % 2 == 1 else 48) if n <= 10 else maxi(s.get_net() - 3, 20)
		balance += s.get_net() - spent
		GameState.day_history.append({"day": n, "processed": s.get_processed_count(), "planned": s.planned_cases,
				"correct": s.get_correct_count(), "citations": s.get_citation_count(), "wage": s.get_wage_total(),
				"fines": s.get_fine_total(), "spent": spent, "balance": balance})
	GameState.credits = balance
	GameState.set_flag(&"sc02_mercy", true)
	GameState.set_flag(&"met_mira", true)
	GameState.set_flag(&"lucioles_note_burned", true)


## Captures de la soirée : `--choose=event:option,…` puis `--step=N`.
func _debug_evening() -> void:
	var evening: EveningScreen = screen as EveningScreen
	if evening == null:
		return
	for pair: String in _arg("choose").split(",", false):
		var parts: PackedStringArray = pair.split(":")
		if parts.size() == 2:
			evening.request_choice(StringName(parts[0]), StringName(parts[1]))
	if _args.has("step"):
		evening.show_step(_arg("step").to_int())


## `--flags=lumika_learned,lucioles_trust:3` : drapeaux (vrai) ou jauges.
func _demo_flags(spec: String) -> void:
	for part: String in spec.split(",", false):
		var pieces: PackedStringArray = part.split(":")
		if pieces.size() > 1:
			GameState.set_flag(StringName(pieces[0]), pieces[1].to_int())
		else:
			GameState.set_flag(StringName(pieces[0]), true)


func _demo_household() -> void:
	var home: Household = GameState.household
	home.get_member(Household.NOA).health = Household.Health.SICK
	for member: Household.Member in home.members:
		member.cold = true
	home.get_member(Household.ILAN).hungry = false
	home.cold_streak = 1
	GameState.add_credits(DEMO_MORNING_CREDITS)
	GameState.set_flag(Campaign.FLAG_LUCIOLES_CONTACT, true)


func _replace_booth_with_null() -> void:
	booth_container.visible = false
	booth.queue_free()
	booth = null
	var null_booth: NullBooth = NullBooth.new()
	null_booth.name = "NullBooth"
	add_child(null_booth)


## Argument utilisateur `--key=valeur` (texte), `fallback` s'il est absent.
func _arg(key: String, fallback: String = "") -> String:
	var value: Variant = _args.get(key, fallback)
	return value if value is String else fallback


## Raccourcis de debug (`--debug-keys` seulement : l'UI porte les vraies actions).
func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_keys:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_N:
			EventBus.next_case_requested.emit()
		KEY_V:
			EventBus.verdict_stamped.emit(Verdict.new(day_controller.current_case_id(), VerdictKind.Kind.APPROVE))
		KEY_X:
			EventBus.verdict_stamped.emit(Verdict.new(day_controller.current_case_id(), VerdictKind.Kind.DENY))
		KEY_R:
			EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
		KEY_C:
			EventBus.interrogation_requested.emit(InspectionSession.TOPIC_CONFRONT)
		KEY_I:
			EventBus.inspection_mode_changed.emit(not inspection.inspection_mode)
