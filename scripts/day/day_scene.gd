## Scène de jour (`res://scenes/main/day.tscn`, ARCHITECTURE §3, §8).
##
## Assemble la bande 3D (`SubViewportContainer` y 56→432, UI_FLOW §2), les
## services logiques (`DayController`, `DayClock`, `InspectionSession`,
## `PortraitService`) et l'UI 2D : `res://scenes/ui/comparison_ui.tscn` est
## instanciée dans `UISlot` si elle existe, et reçoit `portrait_provider`.
## Sans UI (M4, avant intégration), des raccourcis de debug pilotent le cas ;
## arguments utilisateur (après `--`) : `--day=N`, `--seed=N`, `--no-booth`,
## `--autoplay` (bot de démonstration pour les captures), `--reduce-motion`,
## `--no-ui` (bande 3D seule).
class_name DayScene
extends Control

const COMPARISON_UI_PATH: String = "res://scenes/ui/comparison_ui.tscn"
## Propriété que l'UI expose pour recevoir le fournisseur de portraits.
const PORTRAIT_PROVIDER_PROPERTY: StringName = &"portrait_provider"

@onready var booth_container: SubViewportContainer = %BoothContainer
@onready var booth_viewport: SubViewport = %BoothViewport
@onready var booth: BoothDirector = %Booth
@onready var day_controller: DayController = %DayController
@onready var day_clock: DayClock = %DayClock
@onready var inspection: InspectionSession = %InspectionSession
@onready var portrait_service: PortraitService = %PortraitService
@onready var ui_slot: Control = %UISlot

var ui: Node = null
var data: DataCatalog = null
var _autoplay: DemoAutoplay = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	var args: Dictionary = _parse_args()
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
	# TODO(M5): l'écran d'intro du jour (UI) appellera close_intro().
	day_controller.close_intro()
	if args.has("autoplay") and ui == null:
		_autoplay = DemoAutoplay.new()
		_autoplay.name = "DemoAutoplay"
		_autoplay.controller = day_controller
		add_child(_autoplay)


## Fournisseur de portraits pour l'UI (`Callable(PassengerAppearance) -> Texture2D`).
func get_portrait_provider() -> Callable:
	return portrait_service.get_portrait


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
	ui_slot.add_child(ui)


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


## Raccourcis de debug tant que l'UI n'est pas intégrée (M4) : N suivant,
## V approuver, X refuser, R visière, C confronter, I mode Inspection.
func _unhandled_key_input(event: InputEvent) -> void:
	if ui != null:
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
