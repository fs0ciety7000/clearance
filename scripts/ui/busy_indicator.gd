## Indicateur d'attente (M13 lot C ; ARCHITECTURE §12.4, `inspection_busy`) :
## pendant qu'une question coûte son temps (le passager répond) ou que le
## portique s'active / scanne une zone, l'interrogatoire et le portique sont
## suspendus ; l'indicateur dit pourquoi et combien de temps (icône + texte +
## barre, jamais la couleur seule).
## « Réduire les animations » / effets à 0 : la barre avance par quarts
## (`DS.BUSY_REDUCED_STEP`), sans balayage lumineux.
class_name BusyIndicator
extends HBoxContainer

## L'attente est terminée (l'interface est rendue).
signal finished()

var duration: float = 0.0
var elapsed: float = 0.0
var action: StringName = &""
var reduce_motion: bool = false

var _icon: UiIcon = null
var _label: Label = null
var _bar: Control = null
var _text: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", DS.SPACE_2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UiIcon.make(UiIcon.Kind.CHAT, DS.ACCENT_CYAN, DS.ICON_S)
	add_child(_icon)
	_label = ScreenBase.label("", &"DocFieldLabel", DS.ACCENT_CYAN)
	_label.name = "BusyText"
	_label.uppercase = true
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(DS.SPACE_16, DS.SPACE_1)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	visible = false
	set_process(false)


## Démarre (ou prolonge) l'attente : `text` est la raison affichée.
func start(p_duration: float, p_action: StringName, text: String) -> void:
	if p_duration <= 0.0:
		return
	if is_busy() and duration - elapsed > p_duration:
		return
	duration = p_duration
	elapsed = 0.0
	action = p_action
	_text = text
	_icon.kind = UiIcon.Kind.GATE if String(p_action).begins_with("search") else UiIcon.Kind.CHAT
	visible = true
	set_process(true)
	_refresh()


func stop() -> void:
	var was: bool = duration > 0.0
	duration = 0.0
	elapsed = 0.0
	action = &""
	visible = false
	set_process(false)
	if was:
		finished.emit()


func is_busy() -> bool:
	return duration > 0.0 and elapsed < duration


## Avancement 0 → 1 (affiché par quarts quand les animations sont réduites).
func progress() -> float:
	if duration <= 0.0:
		return 0.0
	var value: float = clampf(elapsed / duration, 0.0, 1.0)
	if reduce_motion:
		value = floorf(value / DS.BUSY_REDUCED_STEP) * DS.BUSY_REDUCED_STEP
	return value


func remaining() -> float:
	return maxf(duration - elapsed, 0.0)


func get_text() -> String:
	return _label.text if _label != null else ""


func _process(delta: float) -> void:
	advance(delta)


## Avance l'attente de `delta` secondes (tests : temps piloté).
func advance(delta: float) -> void:
	if not is_busy():
		return
	elapsed += delta
	if elapsed >= duration:
		stop()
		return
	_refresh()


func _refresh() -> void:
	_label.text = "%s · %d s" % [_text, ceili(remaining())]
	_bar.queue_redraw()


func _draw_bar() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(rect, Palette.LINE_SUBTLE)
	var filled: Rect2 = Rect2(rect.position, Vector2(rect.size.x * progress(), rect.size.y))
	_bar.draw_rect(filled, DS.CYAN_60 if not reduce_motion else DS.CYAN_40)
