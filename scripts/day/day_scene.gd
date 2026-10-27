## Scène de jour (`res://scenes/main/day.tscn`, ARCHITECTURE §3, §8).
##
## Assemble la bande 3D (`SubViewportContainer` y 56→432, UI_FLOW §2), les
## services logiques (`DayController`, `DayClock`, `InspectionSession`,
## `PortraitService`), l'UI 2D `res://scenes/ui/comparison_ui.tscn` (instanciée
## dans `UISlot`, **au-dessus** de la bande 3D ; sa bande B est transparente et
## `MOUSE_FILTER_IGNORE`, les clics atteignent le booth) et le briefing du jour
## (`DayBriefing`, ferme l'INTRO → `close_intro()`).
## L'UI reçoit `portrait_provider` (PortraitService) et `face_rect_provider`
## (projection du visage de l'acteur au guichet en coordonnées globales).
## Arguments utilisateur (après `--`) : `--day=N`, `--seed=N`, `--no-booth`,
## `--no-ui`, `--autoplay` (bot de démonstration, captures), `--reduce-motion`,
## `--debug-keys` (raccourcis N/V/X/R/C/I, en conflit avec l'UI : debug seulement).
class_name DayScene
extends Control

const COMPARISON_UI_PATH: String = "res://scenes/ui/comparison_ui.tscn"
## Propriétés que l'UI expose pour recevoir les fournisseurs.
const PORTRAIT_PROVIDER_PROPERTY: StringName = &"portrait_provider"
const FACE_RECT_PROVIDER_PROPERTY: StringName = &"face_rect_provider"
## Autoplay : le briefing se ferme seul.
const AUTOPLAY_BRIEFING_SEC: float = 1.5

@onready var booth_container: SubViewportContainer = %BoothContainer
@onready var booth_viewport: SubViewport = %BoothViewport
@onready var booth: BoothDirector = %Booth
@onready var day_controller: DayController = %DayController
@onready var day_clock: DayClock = %DayClock
@onready var inspection: InspectionSession = %InspectionSession
@onready var portrait_service: PortraitService = %PortraitService
@onready var ui_slot: Control = %UISlot

var ui: Control = null
var briefing: DayBriefing = null
var data: DataCatalog = null
var debug_keys: bool = false
var _autoplay: DemoAutoplay = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	var args: Dictionary = _parse_args()
	debug_keys = args.has("debug-keys")
	if args.has("no-booth"):
		_replace_booth_with_null()
	if args.has("reduce-motion"):
		Settings.set_value(Settings.KEY_REDUCE_MOTION, true, false)
	if GameState.current_day <= 0 or args.has("seed"):
		var seed_text: String = args.get("seed", "0")
		GameState.new_campaign(seed_text.to_int())
	if args.has("day"):
		var day_text: String = args["day"]
		GameState.current_day = day_text.to_int()
	data = DataCatalog.load_from()
	if not args.has("no-ui"):
		_load_ui()
	var flags: Array[StringName] = []
	for flag: StringName in GameState.narrative_flags:
		if GameState.narrative_flags[flag]:
			flags.append(flag)
	if not day_controller.start_day(data, GameState.current_day, GameState.get_day_seed(), flags):
		return
	portrait_service.clear_cache()
	_show_briefing(args.has("autoplay"))
	if args.has("autoplay"):
		_autoplay = DemoAutoplay.new()
		_autoplay.name = "DemoAutoplay"
		_autoplay.controller = day_controller
		_autoplay.ui = ui as ComparisonUI
		add_child(_autoplay)


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


## Briefing « JOUR N — directive du jour » : ferme l'INTRO au clic / à la touche.
func _show_briefing(auto_close: bool) -> void:
	briefing = DayBriefing.new()
	briefing.name = "DayBriefing"
	add_child(briefing)
	briefing.setup(day_controller.day)
	briefing.closed.connect(day_controller.close_intro)
	if auto_close:
		get_tree().create_timer(AUTOPLAY_BRIEFING_SEC).timeout.connect(briefing.close)


func _replace_booth_with_null() -> void:
	booth_container.visible = false
	booth.queue_free()
	booth = null
	var null_booth: NullBooth = NullBooth.new()
	null_booth.name = "NullBooth"
	add_child(null_booth)


func _parse_args() -> Dictionary:
	var result: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var clean: String = arg.trim_prefix("--")
		var parts: PackedStringArray = clean.split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result


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
