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
## M12 (lot C, ARCHITECTURE §11.4–§11.6) : trois sessions (`GameState.session_mode`).
## - **Épilogue J31** : carte « UN AN PLUS TARD » (`EpilogueScreen`), briefing
##   du monde (`EpilogueService.intro_key`, titres `day31_<monde>_*`),
##   `DayController.start_epilogue` ; barre sans chrono ni crédits, lieu du
##   monde ; à `day_ended` : `Campaign.close_epilogue` (pas de bilan ni de
##   soirée) puis carte de conclusion ; retour au titre par
##   `GameState.end_session()`. Depuis l'écran de fin d'une fin de l'Acte III :
##   « UN AN PLUS TARD » (graine de l'emplacement, sinon de la partie).
## - **Garde de nuit** : `pending_garde_run` (titre), `GardeHud` (barre, carte
##   de directive, Rulebook), `DayController.start_garde`, « TERMINER LA
##   GARDE » (barre d'état ou pause, confirmé) → `request_end_garde` ; à
##   `day_ended` : `Campaign.finish_garde` puis `GardeEndScreen` (rejouer,
##   nouvelle graine, copier le code, retour).
## - **Campagne** : inchangée ; bandeau ÉVÉNEMENT et comparateur en panne par
##   `ComparisonUI` (`rule_context_provider`).
## Captures : `--garde[=CODE]`, `--epilogue=<fin>` (+ `--flags`),
## `--skip-cases=N` (N passagers jugés juste d'un coup), `--wrong-cases=N`
## (les N derniers jugés faux), `--undocumented-denials` (refus justes sans
## discordance épinglée : erreurs de procédure), `--station-event=<clé>`
## (bandeau seul, sans effet de règle).
## M13 (lot C, ARCHITECTURE §12.10) : **cartes d'aide** au premier jour où R43
## (déclarations) ou R44 (portique) est en vigueur (`Settings.m13_tutorials_due`
## avec `DayController.statements_active()` / `search_available()`), posées à
## la fermeture du briefing (`HelpCard`, passables, manette) ; la boîte « AUCUN
## MOTIF ÉTABLI » et le portique vivent dans `ComparisonUI`. Captures :
## `--m13-help` (carte due même si le réglage est à faux, rien n'est écrit) ;
## avec `--screen=shift`, `--m13=journal|search|unwarranted|contraband` choisit
## un passager du jour qui convient (déclaration contradictoire, indice et
## contrebande, aucun motif) et joue le geste (question puis puce ↔ permis ;
## portique et zones ; boîte « AUCUN MOTIF ÉTABLI » ; objet ↔ onglet
## Contrebande) ; `--shop=<ag0N>` coche une offre de l'Économat (soirée).
## M14 (lot D, ARCHITECTURE §12 ter.3, I42 / I43) : **cinématiques de fin** —
## `show_end(ending)` joue d'abord la `CinematicScreen` de la fin
## (`CinematicService.select`), puis l'`EndScreen` inchangé à `finished` ; J31 :
## `select_epilogue(monde)` avant la carte de conclusion. Aucune séquence
## (démo, fins simulées des actes I–II) : écran suivant direct. Bande 3D en
## pause de rendu pendant la séquence (`set_rendering_paused`) ; la musique de
## la fin est lancée par l'`AudioDirector` (il lit `screen`). Fondu de sortie
## de la musique (`AudioDirector.fade_out_music`, 1,5 s, voile noir, arbre en
## pause) avant chaque rechargement ou retour au titre. Captures :
## `--screen=cinematic --cinematic=cin_f9 [--plate=N] [--plate-t=s]` (`--flags`).
class_name DayScene
extends Control

## D-203 : bibliothèque des cinématiques chargée avant tout script qui nomme
## `PlateDef` (fuite de scripts à la sortie de Godot 4.7.2 sinon).
const _CINEMATIC_LIBRARY := preload("res://scripts/core/cinematic_library_def.gd")
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
## M12 : garde préparée par le titre (`Campaign.start_garde`), jouée à l'ouverture.
static var pending_garde_run: GardeRun = null
## Tests (GUT) : guichet sans 3D (`NullBooth`), comme `--no-booth` — pour
## enchaîner des passagers plus vite que les marches du booth.
static var force_null_booth: bool = false

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
## M12 : session de la scène (campagne, épilogue, Garde) et état propre.
var session: StringName = GameState.SESSION_CAMPAIGN
var garde_run: GardeRun = null
var garde_hud: GardeHud = null
var garde_badges: Dictionary = {}
## Confirmation « Terminer la garde » ouverte (null sinon).
var end_garde_dialog: ConfirmDialog = null
## Carte de conclusion du J31 (`Campaign.close_epilogue`), vide avant.
var epilogue_card: Dictionary = {}
## M13 : carte d'aide (déclarations, portique) affichée, null sinon.
var help_card: HelpCard = null
## M14 : cinématique en cours (null sinon) et départ de la scène en cours
## (fondu de sortie de la musique : un seul à la fois).
var cinematic: CinematicScreen = null
var leaving: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	_args = DebugArgs.for_scene() # `--garde`, `--epilogue`… : `DebugArgs.ONE_SHOT`
	debug_keys = _args.has("debug-keys")
	if _args.has("no-booth") or force_null_booth:
		_replace_booth_with_null()
	if _args.has("reduce-motion"):
		Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true) # jamais persisté (QA-006)
	data = DataCatalog.load_from()
	_debug_session()
	session = GameState.session_mode
	if session != GameState.SESSION_CAMPAIGN:
		pass
	elif GameState.current_day <= 0 or _args.has("seed"):
		var seed_text: String = _args.get("seed", "0")
		Campaign.new_game(data, seed_text.to_int(), SaveService.DEFAULT_SLOT,
				GameState.DIFFICULTY_STORY if _args.has("story") else GameState.DIFFICULTY_HARD)
	elif _args.has("story"):
		GameState.difficulty = GameState.DIFFICULTY_STORY
	if session == GameState.SESSION_CAMPAIGN:
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
	pause_menu.end_garde_requested.connect(func() -> void:
		day_controller.request_end_garde()
		refresh_close_booth())
	pause_menu.garde_mode = session == GameState.SESSION_GARDE
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
		comparison.rule_context_provider = day_controller.get_rule_context
	# Tutoriel du J1 : demandé par le titre (nouvelle partie / reprise au J1), ou `--tutorial`.
	_tutorial_requested = (TutorialOverlay.pending or _args.has("tutorial")) and GameState.current_day == 1 and comparison != null \
			and session == GameState.SESSION_CAMPAIGN
	TutorialOverlay.pending = false
	if session == GameState.SESSION_GARDE:
		_begin_garde()
		return
	if session == GameState.SESSION_EPILOGUE:
		_begin_epilogue()
		return
	if not day_controller.start_day(data, GameState.current_day, GameState.get_day_seed(), GameState.get_true_flags(),
			Campaign.memory_for_day(data)):
		return
	if _args.has("start-case"):
		var start_text: String = _args["start-case"]
		day_controller.next_index = clampi(start_text.to_int(), 0, day_controller.day.passenger_count - 1)
	portrait_service.clear_cache()
	_show_briefing(_args.has("autoplay"))
	_start_autoplay()
	_debug_screen(_arg("screen"))
	_debug_skip_cases()


func _start_autoplay() -> void:
	if not _args.has("autoplay"):
		return
	_autoplay = DemoAutoplay.new()
	_autoplay.name = "DemoAutoplay"
	_autoplay.controller = day_controller
	_autoplay.ui = ui as ComparisonUI
	_autoplay.approve_all = _args.has("approve-all")
	add_child(_autoplay)


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
## M12 : J31 — titres et slogan du monde, paragraphe propre à la fin.
func _show_briefing(auto_close: bool) -> void:
	briefing = BriefingScreen.new()
	briefing.name = "BriefingScreen"
	var content: BriefingContent = BriefingContent.build(day_controller.day, GameState.narrative_flags, GameState.household,
			consortium_advance())
	if session == GameState.SESSION_EPILOGUE:
		var world: String = str(GameState.epilogue_seed.get("world", ""))
		content.directive_title_key = "day31_%s_directive_title" % world
		content.slogan_key = "day31_%s_slogan" % world
		briefing.epilogue_world = world
		briefing.directive_extra_key = EpilogueService.intro_key(GameState.epilogue_seed)
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
		return
	start_m13_help()


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


## M13 : cartes d'aide dues ce jour (déclarations J4, portique J8), en campagne
## seulement. Null s'il n'y en a pas.
func start_m13_help() -> HelpCard:
	if help_card != null and is_instance_valid(help_card):
		return help_card
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison == null or session != GameState.SESSION_CAMPAIGN or _args.has("autoplay"):
		return null
	if _args.has("screen") and not _args.has("m13-help"):
		return null # captures d'autres écrans : pas de carte par-dessus
	var due: Array[StringName] = Settings.m13_tutorials_due(day_controller.statements_active(), day_controller.search_available())
	if _args.has("m13-help") and due.is_empty():
		# Capture : la carte du jour, même déjà lue (le réglage n'est pas réécrit).
		if day_controller.statements_active():
			due.append(Settings.KEY_TUTORIAL_M13_STATEMENTS)
		if day_controller.search_available():
			due.append(Settings.KEY_TUTORIAL_M13_SEARCH)
	if due.is_empty():
		return null
	help_card = HelpCard.make(due)
	help_card.persist = not _args.has("m13-help")
	help_card.theme = comparison.theme
	help_card.finished.connect(func() -> void:
		help_card = null
		if is_instance_valid(comparison):
			comparison.focus_default.call_deferred())
	add_child(help_card)
	move_child(help_card, _overlay.get_index())
	return help_card


## Mode Récit : « FERMER LE GUICHET » proposé une fois le quota atteint.
## Garde (M12) : « TERMINER LA GARDE » tant que la garde n'est pas finie.
func refresh_close_booth() -> void:
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison == null or not is_inside_tree():
		return
	if session == GameState.SESSION_GARDE:
		comparison.set_close_booth_available(day_controller.phase != DayPhase.Kind.SUMMARY and not day_controller.garde_over)
		return
	var available: bool = day_controller.can_close_booth() and not day_controller.booth_closed
	if _args.has("close-booth") and GameState.is_story_mode() and day_controller.phase != DayPhase.Kind.SUMMARY:
		available = true # capture : bouton forcé
	comparison.set_close_booth_available(available)


## « FERMER LE GUICHET » : bilan tout de suite entre deux passagers, sinon
## après le passager en cours (`DayController.close_booth`).
func request_close_booth() -> bool:
	if session == GameState.SESSION_GARDE:
		request_end_garde()
		return true
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
	if session == GameState.SESSION_GARDE:
		if end_garde_dialog != null and is_instance_valid(end_garde_dialog):
			end_garde_dialog.cancel()
		get_tree().create_timer(SIREN_DELAY_SEC).timeout.connect(show_garde_end)
		return
	if session == GameState.SESSION_EPILOGUE:
		# J31 (D-123) : ni bilan ni soirée — conclusion composée.
		epilogue_card = Campaign.close_epilogue(summary)
		get_tree().create_timer(SIREN_DELAY_SEC).timeout.connect(show_epilogue_ending.bind(epilogue_card))
		return
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
		reload_after_music_fade()
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
	chapter.finished.connect(func(_choice: StringName) -> void: reload_after_music_fade())
	_open(chapter, &"chapter2")


## Vrai juste après la soirée pivot du J20 si l'Acte III commence.
func chapter_three_pending() -> bool:
	return data != null and Campaign.is_act3() and GameState.current_day == data.get_economy().act3_pivot_day + 1


## Interstitiel « CHAPITRE III · TÉMOINS » puis le J21 (rechargement).
func show_chapter_three() -> void:
	var chapter: ChapterScreen = ChapterScreen.new()
	chapter.name = "ChapterScreen"
	chapter.setup(GameState.narrative_flags, 3)
	chapter.finished.connect(func(_choice: StringName) -> void: reload_after_music_fade())
	_open(chapter, &"chapter3")


## Dernier jour sans soirée (J30 depuis D-086) → évaluation de la fin.
func show_final(summary: DaySummary) -> void:
	show_end(Campaign.close_final_day(data, summary))


func show_end(ending: StringName) -> void:
	# Toute fin archive la partie et l'inscrit au profil (D-101) — idempotent.
	GameState.end_campaign(ending)
	# M14 : la cinématique de la fin d'abord (null : écran de fin direct).
	var sequence: CinematicScreen = make_end_cinematic(ending)
	if sequence != null:
		play_cinematic(sequence, &"cinematic", func(_skipped: bool) -> void: open_end_screen(ending))
		return
	open_end_screen(ending)


## Cinématique d'une fin (M14 §3.2, ARCHITECTURE §12 ter.3) : sélection pure
## sur les drapeaux de la partie, planches retenues, figures depuis la mémoire
## des cas ; carte de titre = surtitre et titre de l'écran de fin. Null si la
## fin n'en a pas (démo, fins des actes I–II de F4/F5/F7/F8/F9).
func make_end_cinematic(ending: StringName) -> CinematicScreen:
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	var variant: StringName = EpilogueService.variant_of(ending, flags)
	var act: int = EpilogueService.act_of(flags)
	var day: int = GameState.current_day
	var def: CinematicDef = CinematicService.select(ending, variant, flags, act, day)
	if def == null:
		return null
	var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(flags, act, variant, day)
	var plates: Array[PlateDef] = CinematicService.plates_for(def, ctx, act, GameState.case_memory)
	if plates.is_empty():
		return null
	var sequence: CinematicScreen = CinematicScreen.new()
	sequence.setup(def, plates, ctx, GameState.case_memory, ending, variant)
	var epi: Dictionary = Campaign.epilogue(ending)
	var eyebrow_key: String = str(epi.get("eyebrow_key", "end_eyebrow_%s" % ending))
	var title_key: String = str(epi.get("title_key", "end_title_%s" % ending))
	sequence.set_title(UiText.t(eyebrow_key, "") if UiText.has(eyebrow_key) else "",
			UiText.t(title_key, "") if UiText.has(title_key) else "")
	return sequence


## Cinématique de la conclusion du J31 (monde de la graine d'épilogue), ou null.
func make_epilogue_cinematic() -> CinematicScreen:
	var world: StringName = StringName(str(GameState.epilogue_seed.get("world", "")))
	var def: CinematicDef = CinematicService.select_epilogue(world)
	if def == null:
		return null
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(flags, 3, &"", 31)
	var plates: Array[PlateDef] = CinematicService.plates_for(def, ctx, 3, GameState.case_memory)
	if plates.is_empty():
		return null
	var sequence: CinematicScreen = CinematicScreen.new()
	sequence.setup(def, plates, ctx, GameState.case_memory)
	return sequence


## Joue une cinématique plein cadre : bande 3D en pause de rendu pendant la
## séquence, puis `then(skipped)`.
func play_cinematic(sequence: CinematicScreen, id: StringName, then: Callable) -> CinematicScreen:
	cinematic = sequence
	if booth != null:
		booth.set_rendering_paused(true)
	sequence.finished.connect(func(skipped: bool) -> void:
		cinematic = null
		if booth != null and is_instance_valid(booth):
			booth.set_rendering_paused(false)
		then.call(skipped), CONNECT_ONE_SHOT)
	_open(sequence, id)
	return sequence


## Écran de fin (inchangé depuis M12) : épilogue lu, traces, tableau.
func open_end_screen(ending: StringName) -> EndScreen:
	var end: EndScreen = EndScreen.new()
	end.name = "EndScreen"
	end.epilogue = Campaign.epilogue(ending)
	end.setup(ending, GameState.day_history, GameState.household, GameState.credits, GameState.narrative_flags,
			Campaign.compliance())
	end.finished.connect(func(choice: StringName) -> void:
		if choice == &"epilogue" and play_epilogue_after_end(ending):
			return
		go_to_title())
	_open(end, &"end")
	return end


func go_to_title() -> void:
	get_tree().paused = false
	# M12 : une session épilogue ou Garde ne laisse aucune campagne chargée.
	GameState.end_session()
	if is_inside_tree():
		_leave_after_music_fade(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE_PATH))


## Jour suivant, chapitre, épilogue, Garde rejouée : rechargement de la scène
## après le fondu de sortie de la musique.
func reload_after_music_fade() -> void:
	_leave_after_music_fade(func() -> void: get_tree().reload_current_scene())


## M14 (docs/AUDIO.md §13.15) : la musique s'éteint par l'effet `Fade`
## (`AudioDirector.fade_out_music`, 1,5 s) avant de quitter la scène ; voile
## noir et arbre en pause pendant le fondu (plus rien ne bouge ni ne répond).
## Sans musique : tout de suite. Un seul départ à la fois.
func _leave_after_music_fade(action: Callable) -> void:
	if leaving:
		return
	leaving = true
	var audio: AudioDirector = get_node_or_null(^"%AudioDirector") as AudioDirector
	var wait: float = audio.fade_out_music(DS.MUSIC_EXIT_FADE) if audio != null and is_instance_valid(audio) else 0.0
	if wait <= 0.0 or not is_inside_tree():
		action.call()
		return
	get_tree().paused = true
	blackout.visible = true
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	move_child(blackout, get_child_count() - 1)
	var veil: Tween = blackout.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	veil.tween_property(blackout, "color:a", 1.0, DS.DUR_FAST if Settings.reduce_motion else wait)
	await get_tree().create_timer(wait, true).timeout
	if not is_inside_tree():
		return
	get_tree().paused = false
	action.call()


# ---------------------------------------------------------------------------
# M12 : épilogue J31
# ---------------------------------------------------------------------------

## « UN AN PLUS TARD » depuis l'écran de fin : graine de l'emplacement
## (`day_31.json`), sinon calculée depuis la partie qui vient de finir.
func play_epilogue_after_end(ending: StringName) -> bool:
	var slot: int = GameState.active_slot
	var epi: Dictionary = Campaign.epilogue_seed_for_slot(slot)
	if epi.is_empty():
		epi = EpilogueService.make_seed(ending, GameState.narrative_flags, GameState.household, GameState.case_memory,
				GameState.campaign_seed, GameState.current_day)
	if Campaign.start_epilogue(epi, slot) == null:
		return false
	get_tree().paused = false
	reload_after_music_fade()
	return true


## Session épilogue : J31 du monde de la graine, carte d'ouverture puis briefing.
func _begin_epilogue() -> void:
	var epi: Dictionary = GameState.epilogue_seed
	var world_day: DayDef = EpilogueService.day_for(epi)
	if world_day == null:
		push_error("DayScene: épilogue sans DayDef (monde « %s »)" % epi.get("world", ""))
		go_to_title.call_deferred()
		return
	var memory: Dictionary = CaseMemory.resolve(data, world_day, GameState.campaign_seed, GameState.case_memory)
	if not day_controller.start_epilogue(data, world_day, EpilogueService.day_seed(epi), GameState.get_true_flags(), memory):
		go_to_title.call_deferred()
		return
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		var world: String = str(epi.get("world", ""))
		comparison.top_bar.set_untimed(true)
		comparison.top_bar.set_credits_visible(false)
		comparison.top_bar.set_location(UiText.t("epi_eyebrow_%s" % world, comparison.top_bar.get_location_text()))
	portrait_service.clear_cache()
	if _args.has("skip-cases") or _args.has("autoplay"):
		_show_briefing(true)
	else:
		show_epilogue_intro()
	_start_autoplay()
	_debug_skip_cases()


## Carte « UN AN PLUS TARD · 11.04.2188 », puis briefing du J31.
func show_epilogue_intro() -> EpilogueScreen:
	var card: EpilogueScreen = EpilogueScreen.new()
	card.name = "EpilogueIntro"
	card.setup_intro(GameState.epilogue_seed)
	card.finished.connect(func(choice: StringName) -> void:
		if choice == &"title":
			go_to_title()
		else:
			_show_briefing(false))
	_open(card, &"epilogue_intro")
	return card


## M14 : fin du J31 — la cinématique du monde (CIN-EA → CIN-ED), puis la
## carte de conclusion (inchangée) ; sans séquence, la carte directement.
func show_epilogue_ending(card: Dictionary) -> void:
	if (screen != null and is_instance_valid(screen) and screen.name == "EpilogueConclusion") or cinematic != null:
		return
	var sequence: CinematicScreen = make_epilogue_cinematic()
	if sequence != null:
		play_cinematic(sequence, &"epilogue_cinematic", func(_skipped: bool) -> void: show_epilogue_conclusion(card))
		return
	show_epilogue_conclusion(card)


## Carte de conclusion du J31 ; « RETOUR AU TITRE » termine la session.
func show_epilogue_conclusion(card: Dictionary) -> EpilogueScreen:
	var screen_node: EpilogueScreen = EpilogueScreen.new()
	screen_node.name = "EpilogueConclusion"
	screen_node.setup_conclusion(card)
	screen_node.finished.connect(func(_choice: StringName) -> void: go_to_title())
	_open(screen_node, &"epilogue_conclusion")
	return screen_node


# ---------------------------------------------------------------------------
# M12 : Garde de nuit
# ---------------------------------------------------------------------------

func _begin_garde() -> void:
	garde_run = pending_garde_run
	pending_garde_run = null
	if garde_run == null:
		garde_run = GardeService.new_run(GardeService.today_code())
	if garde_run == null:
		push_error("DayScene: garde sans données")
		go_to_title.call_deferred()
		return
	var comparison: ComparisonUI = ui as ComparisonUI
	if comparison != null:
		garde_hud = GardeHud.attach(comparison, garde_run)
		add_child(garde_hud)
	if not day_controller.start_garde(data, garde_run):
		go_to_title.call_deferred()
		return
	portrait_service.clear_cache()
	if comparison != null:
		comparison.set_story_mode(false) # la Garde n'a pas de mode Récit (M12 §2.9)
	_set_ui_active(true)
	day_controller.close_intro()
	if garde_hud != null:
		garde_hud.refresh()
	refresh_close_booth()
	_start_autoplay()
	_debug_skip_cases()


## « TERMINER LA GARDE » : confirmation (focus ANNULER), le score compte.
func request_end_garde() -> ConfirmDialog:
	if end_garde_dialog != null or session != GameState.SESSION_GARDE or day_controller.garde_over:
		return end_garde_dialog
	var score: int = garde_run.score if garde_run != null else 0
	end_garde_dialog = ConfirmDialog.make(UiText.t("garde_title", "GARDE DE NUIT"),
			UiText.t("garde_end_confirm_title", "Terminer la garde ?"),
			UiText.tf("garde_end_confirm_body", [score], "Le score de %d est enregistré. Le passager au guichet est jugé d'abord."),
			UiText.t("garde_end_button", "TERMINER LA GARDE"))
	end_garde_dialog.name = "EndGardeDialog"
	# Hors de `ComparisonUI` : même thème (texte à l'échelle, cartes Holo).
	var themed: Control = ui as Control
	if themed != null and themed.theme != null:
		end_garde_dialog.theme = themed.theme
	end_garde_dialog.confirmed.connect(func() -> void:
		end_garde_dialog = null
		day_controller.request_end_garde()
		refresh_close_booth())
	end_garde_dialog.cancelled.connect(func() -> void:
		end_garde_dialog = null
		var comparison: ComparisonUI = ui as ComparisonUI
		if comparison != null and is_instance_valid(comparison):
			comparison.focus_default.call_deferred())
	add_child(end_garde_dialog)
	return end_garde_dialog


## Fin de garde : records au profil (une fois), puis l'écran FIN DE GARDE.
func show_garde_end() -> GardeEndScreen:
	if screen != null and is_instance_valid(screen) and screen is GardeEndScreen:
		return screen as GardeEndScreen
	if garde_run != null and garde_badges.is_empty():
		garde_badges = Campaign.finish_garde(garde_run)
	var record: Dictionary = garde_run.to_record() if garde_run != null else {}
	if garde_run != null:
		record["clock_minute"] = garde_run.clock_minute()
	var end: GardeEndScreen = GardeEndScreen.new()
	end.name = "GardeEndScreen"
	end.setup(record, garde_badges, garde_rule_titles())
	end.finished.connect(_after_garde_end)
	_open(end, &"garde_end")
	return end


## Titres des règles de la garde (`rule_id` → clé), pour « règle en cause ».
func garde_rule_titles() -> Dictionary:
	var titles: Dictionary = {}
	if garde_run != null and garde_run.def != null:
		for unit: GardeUnitDef in garde_run.def.units:
			if unit == null:
				continue
			for rule: Rule in unit.rules:
				if rule != null:
					titles[String(rule.id)] = rule.title_key
	if day_controller.day != null and day_controller.day.rule_set != null:
		for rule: Rule in day_controller.day.rule_set.rules:
			if rule != null:
				titles[String(rule.id)] = rule.title_key
	return titles


func _after_garde_end(choice: StringName) -> void:
	match choice:
		&"replay":
			var run: GardeRun = Campaign.start_garde(garde_run.code if garde_run != null else GardeService.today_code())
			if run != null:
				pending_garde_run = run
				get_tree().paused = false
				reload_after_music_fade()
				return
		&"new_seed":
			GardeScreen.open_on_title = true
	go_to_title()


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
				if _args.has("end-to-title"):
					_debug_end_to_title.call_deferred()
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
			if _args.has("m13"):
				_debug_m13_pick_case(_arg("m13"))
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
		"cinematic":
			if briefing != null:
				briefing.closed.disconnect(_on_briefing_closed)
				briefing.queue_free()
				briefing = null
			_debug_cinematic.call_deferred(StringName(_arg("cinematic", "cin_f9")))


## Capture M14 : `--cinematic=<id>` (fin de la séquence : son ending ; actes
## et variante selon `--flags`), `--plate=N` (1…) et `--plate-t=s` (instant
## dans la planche ; PL-F9-1 : vitres éteintes une à une). Rien n'est inscrit
## au profil.
func _debug_cinematic(id: StringName) -> void:
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	var def: CinematicDef = lib.get_cinematic(id) if lib != null else null
	if def == null:
		push_warning("DayScene: --cinematic=%s inconnue" % id)
		return
	var sequence: CinematicScreen = null
	if def.is_epilogue():
		GameState.epilogue_seed = {"world": String(def.worlds[0])}
		sequence = make_epilogue_cinematic()
	else:
		var ending: StringName = def.endings[0]
		if not def.acts.is_empty():
			for act: int in def.acts:
				GameState.set_flag(EndingService.FLAG_ACT2, act >= 2)
				GameState.set_flag(EndingService.FLAG_ACT3, act >= 3)
		if not def.ending_variants.is_empty():
			ctx_variant_flags(ending, def.ending_variants[0])
		sequence = make_end_cinematic(ending)
	if sequence == null:
		push_warning("DayScene: --cinematic=%s sans planche" % id)
		return
	sequence.record_seen = false
	play_cinematic(sequence, &"cinematic", func(_skipped: bool) -> void: pass)
	var plate_n: int = clampi(_arg("plate", "0").to_int(), 0, sequence.plates.size())
	if plate_n > 0:
		await get_tree().process_frame
		sequence.jump_to(plate_n - 1, _arg("plate-t", "1.5").to_float())
	if _args.has("plate-hold"):
		sequence.set_process(false) # planche figée pour la capture (shaders vivants)


## Smoke des exports (`tools/smoke_export.sh`) : `--screen=end --ending=<fin>
## --end-to-title` — la cinématique de la fin (exigée) est vue 1 s puis
## passée, l'écran de fin s'ouvre, RETOUR AU TITRE, fondu de sortie, puis
## `main.tscn` (qui quitte en l'annonçant, voir `main.gd`).
func _debug_end_to_title() -> void:
	var sequence: CinematicScreen = cinematic
	if sequence == null:
		push_error("DayScene: --end-to-title sans cinématique de fin")
		return
	var id: StringName = sequence.def.id
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(sequence):
		sequence.skip_all()
	await get_tree().create_timer(1.0).timeout
	var end: EndScreen = screen as EndScreen
	if end == null or not is_instance_valid(end) or end.title_button == null:
		push_error("DayScene: --end-to-title : écran de fin absent après la cinématique")
		return
	print("DayScene: --end-to-title : cinématique %s passée, RETOUR AU TITRE" % id)
	end.title_button.pressed.emit()


## Capture : drapeaux qui donnent la variante voulue d'une fin (`--cinematic`),
## à l'acte déjà posé par les drapeaux d'acte (QA-080 : F5 Charte, Brûlants ;
## F6 Dérive). Les variantes « par défaut » (F1 double, F5 seconde vanne,
## F6 Tycho, J10 / J20) n'ont besoin d'aucun drapeau.
static func ctx_variant_flags(ending: StringName, wanted: StringName) -> void:
	match [ending, wanted]:
		[EndingService.F1_ARRESTED, EpilogueService.VARIANT_AUDIT]:
			GameState.set_flag(EndingService.FLAG_AUDIT_ARRESTED, true)
		[EndingService.F1_ARRESTED, EpilogueService.VARIANT_REVIEW]:
			GameState.set_flag(EndingService.FLAG_REVIEW_ARRESTED, true)
		[EndingService.F1_ARRESTED, EpilogueService.VARIANT_DEPOSITION]:
			GameState.set_flag(EndingService.FLAG_DEPOSITION_ARRESTED, true)
		[EndingService.F5_AIR, EpilogueService.VARIANT_CHARTER]:
			GameState.set_flag(&"climate_vanne", true)
		[EndingService.F5_AIR, EpilogueService.VARIANT_BURNERS]:
			match EpilogueService.act_of(GameState.narrative_flags):
				3:
					GameState.set_flag(EndingService.FLAG_BRULANTS2, true)
				2:
					GameState.set_flag(&"sc47_kasimir_passed", true)
				_:
					GameState.set_flag(&"brulants_package", true)
		[EndingService.F6_DRIFT, EpilogueService.VARIANT_DRIFT]:
			GameState.set_flag(&"exit3_drift", true)


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
	if _args.has("m13"):
		_debug_m13(comparison, _arg("m13"))
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
	if _args.has("shop") and evening.shop != null:
		evening.set_line_paid(StringName(EveningService.UPGRADE_PREFIX + _arg("shop")), true)
		if evening._lines_scroll != null:
			evening._lines_scroll.ensure_control_visible.call_deferred(evening.shop)


## Capture M13 : premier passager du jour qui convient au geste montré.
func _debug_m13_pick_case(scenario: String) -> void:
	var builder: CaseBuilder = day_controller.builder
	if builder == null or day_controller.day == null:
		return
	for index: int in day_controller.day.passenger_count:
		var generated: GeneratedCase = builder.build(index)
		if generated == null or generated.scripted_id != &"":
			continue
		var kinds: Array[AnomalyType.Kind] = []
		for anomaly: Anomaly in generated.key.anomalies:
			kinds.append(anomaly.type)
		var c: Case = generated.case
		var ok: bool = false
		match scenario:
			"journal":
				ok = kinds.has(AnomalyType.Kind.STATEMENT_MISMATCH) and c.statements.size() >= 2
			"search", "contraband":
				# Fouille : un indice suffit (motif MF-2) ; Contrebande : un objet interdit.
				ok = not c.search_cues.is_empty() and (scenario == "search" or kinds.has(AnomalyType.Kind.CONTRABAND))
			"unwarranted":
				ok = c.search_cues.is_empty() and c.cargo_reply != Case.CARGO_EVASIVE \
						and generated.key.expected_verdict == VerdictKind.Kind.APPROVE and c.search_layout != null
		if ok:
			day_controller.next_index = index
			print("QA_M13 %s : passager %d" % [scenario, index + 1])
			return
	print("QA_M13 %s : aucun passager du jour ne convient" % scenario)


## Capture M13 : le geste, joué par l'interface comme le ferait le joueur.
func _debug_m13(comparison: ComparisonUI, scenario: String) -> void:
	var c: Case = day_controller.current_case
	if c == null:
		return
	match scenario:
		"journal":
			comparison.ask(InterrogationTopics.PURPOSE)
			await get_tree().create_timer(3.4).timeout
			comparison.set_inspection_active(true)
			for chip: StatementChipView in comparison.passenger_panel.journal.chips():
				if chip.struck:
					continue
				for view: DocumentView in comparison.workbench.views:
					for item: InspectableItem in view.get_items():
						if not item.comparable:
							continue
						var result: Discrepancy = DiscrepancyChecker.check(c, chip.ref, item.ref, inspection.ctx)
						if result.result == Discrepancy.Result.DISCORDANT:
							comparison.pick(chip.ref)
							await get_tree().create_timer(0.5).timeout
							comparison.pick(item.ref)
							print("QA_M13 puce %s ↔ %s" % [chip.ref.key(), item.ref.key()])
							return
		"search", "contraband":
			comparison.ask(InterrogationTopics.SEARCH)
			await get_tree().create_timer(0.3).timeout
			if comparison.search_dialog != null:
				comparison.search_dialog.accept()
			await get_tree().create_timer(2.4).timeout
			var zone: StringName = SearchLayout.zone_of_cue(c.search_cues[0]) if not c.search_cues.is_empty() else SearchLayout.ZONE_LUGGAGE
			for item: SearchItem in c.search_layout.items if c.search_layout != null else [] as Array[SearchItem]:
				if item.is_forbidden():
					zone = item.zone
			comparison.search_panel.request_zone(zone)
			await get_tree().create_timer(2.4).timeout
			if scenario == "search":
				# Fouille en cours : les zones restantes en file (TOUT SCANNER).
				comparison.search_panel.request_all()
				return
			comparison.set_inspection_active(true)
			for view: SearchItemView in comparison.search_panel.item_views:
				if view.item.is_forbidden():
					comparison.rulebook.show_reference_tab(RulebookReference.TAB_CONTRABAND)
					comparison.pick(view.ref)
					await get_tree().create_timer(0.5).timeout
					comparison.pick(FieldRef.contraband_entry(view.item.category))
					return
		"unwarranted":
			comparison.ask(InterrogationTopics.SEARCH)


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


## Captures M12 : `--garde[=CODE]` (session Garde), `--epilogue=<fin>` (J31
## depuis une graine synthétique ; `--flags` = drapeaux de la fin).
func _debug_session() -> void:
	if _args.has("garde"):
		var code: String = _arg("garde")
		if code.is_empty() or code == "true":
			code = GardeService.today_code()
		pending_garde_run = Campaign.start_garde(code)
	elif _args.has("epilogue"):
		var ending: StringName = StringName(_arg("epilogue", String(EndingService.F10_PONT)))
		var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT2: true, EndingService.FLAG_ACT3: true}
		for part: String in _arg("flags").split(",", false):
			var pieces: PackedStringArray = part.split(":")
			flags[StringName(pieces[0])] = pieces[1].to_int() if pieces.size() > 1 else true
		var seed_text: String = _arg("seed", "4242")
		var epi: Dictionary = EpilogueService.make_seed(ending, flags, Household.new(), {}, seed_text.to_int(), 30)
		if Campaign.start_epilogue(epi) == null:
			push_warning("DayScene: --epilogue=%s sans épilogue" % ending)


## Captures M12 : `--skip-cases=N` juge N passagers d'un coup (verdict attendu ;
## `--wrong-cases=K` : les K derniers faux), `--station-event=<clé>` affiche
## le bandeau d'un événement (sans effet de règle).
func _debug_skip_cases() -> void:
	if _args.has("skip-cases"):
		_skip_cases.call_deferred(_arg("skip-cases").to_int(), _arg("wrong-cases", "0").to_int())
	if _args.has("station-event"):
		_show_station_event.call_deferred(StringName(_arg("station-event")))


func _skip_cases(count: int, wrong: int) -> void:
	if briefing != null and is_instance_valid(briefing):
		briefing.close()
	for i: int in count:
		if day_controller.phase != DayPhase.Kind.WAITING_CASE or not day_controller.has_remaining_cases():
			break
		EventBus.next_case_requested.emit()
		var case: Case = day_controller.current_case
		if case == null:
			break
		EventBus.passenger_arrived.emit(case.case_id)
		var expected: VerdictKind.Kind = day_controller.current_key.expected_verdict
		var kind: VerdictKind.Kind = expected
		if i >= count - wrong:
			kind = VerdictKind.Kind.DENY if expected == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE
		# Verdict documenté (discordances épinglées, question posée) : jugé juste.
		# `--undocumented-denials` (captures QA-054) : refus justes sans
		# discordance épinglée — erreurs de procédure « refus non motivé ».
		var verdict: Verdict = Verdict.new(case.case_id, kind)
		var undocumented: bool = _args.has("undocumented-denials") and kind == VerdictKind.Kind.DENY and kind == expected
		var pins: Array[Violation] = []
		if not undocumented:
			pins = day_controller.current_key.expected_violations
		for violation: Violation in pins:
			if not violation.refs.is_empty():
				var pinned: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[violation.refs.size() - 1])
				pinned.confirmed = true
				verdict.flagged.append(pinned)
		verdict.questions_asked = [InspectionSession.TOPIC_PURPOSE]
		EventBus.verdict_stamped.emit(verdict)
		EventBus.passenger_departed.emit(case.case_id)
	if _args.has("hold-card") and garde_hud != null and garde_hud.card != null and is_instance_valid(garde_hud.card):
		garde_hud.card.hold()
	if _args.has("call-next"):
		EventBus.next_case_requested.emit()


func _show_station_event(key: StringName) -> void:
	var events: StationEventsDef = StationEventService.load_def()
	if events == null:
		return
	for event: StationEventDef in events.events:
		if event != null and (event.key == key or event.id == key):
			var processed: int = day_controller.summary.results.size() if day_controller.summary != null else 0
			var plan: StationEventPlan = StationEventService.garde_plan(event, processed)
			plan.state = StationEventPlan.State.ACTIVE
			EventBus.hall_announced.emit(plan.announce_key())
			EventBus.station_event_started.emit(plan)
			return


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
