## Barre d'état (UI_FLOW §2.2 zone A, DS §7.6) : marque Consortium, lieu /
## guichet / jour / date, horloge de shift (heure + progression + fin),
## passagers traités, crédits. Seuils : ambre « FIN DE SHIFT PROCHE » à 30 min
## in-game de la fin ; rouge à `DS.TIMER_CRITICAL_SECONDS` réelles.
class_name TopBar
extends PanelContainer

enum ClockState { NORMAL, WARNING, CRITICAL }

const HEIGHT: float = 56.0
const PROGRESS_WIDTH: float = 216.0

var clock_state: ClockState = ClockState.NORMAL
var progress: float = 0.0

var _location: Label = null
var _date: Label = null
var _clock: Label = null
var _clock_icon: UiIcon = null
var _end_label: Label = null
var _progress_bar: Control = null
var _processed: Label = null
var _credits: Label = null


func _ready() -> void:
	theme_type_variation = &"BarPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DS.SPACE_6)
	margin.add_theme_constant_override("margin_right", DS.SPACE_6)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_4)
	margin.add_child(row)
	# Marque.
	row.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, DS.ICON_L))
	var brand: Label = Label.new()
	brand.theme_type_variation = &"BrandLabel"
	brand.text = UiText.t("bar_brand", "CLEARANCE")
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(brand)
	row.add_child(_vline())
	var org: Label = Label.new()
	org.theme_type_variation = &"DocIssuer"
	org.add_theme_color_override(&"font_color", DS.ACCENT_YELLOW)
	org.uppercase = true
	org.text = UiText.t("bar_org", "CONSORTIUM · CONTRÔLE D'ENTRÉE")
	org.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(org)
	row.add_child(_spacer())
	# Lieu, jour, date.
	_location = Label.new()
	_location.theme_type_variation = &"PanelTitle"
	_location.text = UiText.t("bar_location", "HALCYON GATE — GUICHET 04")
	_location.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_location)
	_date = Label.new()
	_date.theme_type_variation = &"DataSmall"
	_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_date)
	row.add_child(_spacer())
	# Horloge.
	var shift: Label = Label.new()
	shift.theme_type_variation = &"DocFieldLabel"
	shift.text = UiText.t("bar_shift", "SHIFT")
	shift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shift)
	_clock_icon = UiIcon.make(UiIcon.Kind.WARNING, DS.STATE_AMBER, DS.ICON_M)
	_clock_icon.visible = false
	row.add_child(_clock_icon)
	_clock = Label.new()
	_clock.theme_type_variation = &"TimerCompact"
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock)
	_progress_bar = Control.new()
	_progress_bar.custom_minimum_size = Vector2(PROGRESS_WIDTH, DS.SPACE_2)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.draw.connect(_draw_progress)
	row.add_child(_progress_bar)
	_end_label = Label.new()
	_end_label.theme_type_variation = &"DataSmall"
	_end_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_end_label)
	row.add_child(_vline())
	_processed = _stat(row, UiText.t("bar_processed", "TRAITÉS"), DS.TEXT_PRIMARY)
	row.add_child(_vline())
	_credits = _stat(row, UiText.t("bar_credits", "CRÉDITS"), DS.ACCENT_YELLOW)
	set_clock(1.0, 1.0)
	set_processed(0)
	set_credits(0)


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _vline() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = DS.LINE_SUBTLE
	line.custom_minimum_size = Vector2(1, DS.SPACE_8)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


func _stat(row: HBoxContainer, caption: String, color: Color) -> Label:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	var label: Label = Label.new()
	label.theme_type_variation = &"DocFieldLabel"
	label.text = caption
	column.add_child(label)
	var value: Label = Label.new()
	value.theme_type_variation = &"DocFieldValue"
	value.add_theme_color_override(&"font_color", color)
	column.add_child(value)
	return value


func set_day(day_number: int, date_days: int) -> void:
	_date.text = "%s · %s" % [UiText.tf("bar_day", [day_number], "JOUR %02d"), UiText.date_with_weekday(date_days)]


## Horloge à partir du temps réel restant et de la durée du jour.
func set_clock(remaining_sec: float, duration_sec: float) -> void:
	var minutes: int = UiText.shift_minutes(remaining_sec, duration_sec)
	_clock.text = UiText.clock(minutes)
	progress = float(minutes - UiText.SHIFT_START_MIN) / float(UiText.SHIFT_END_MIN - UiText.SHIFT_START_MIN)
	var state: ClockState = ClockState.NORMAL
	if remaining_sec <= DS.TIMER_CRITICAL_SECONDS and duration_sec > 0.0:
		state = ClockState.CRITICAL
	elif UiText.SHIFT_END_MIN - minutes <= UiText.SHIFT_WARN_MIN:
		state = ClockState.WARNING
	clock_state = state
	var color: Color = DS.TEXT_PRIMARY
	match state:
		ClockState.WARNING:
			color = DS.STATE_AMBER
			_end_label.text = UiText.t("bar_shift_ending", "FIN DE SHIFT PROCHE")
		ClockState.CRITICAL:
			color = DS.STATE_RED
			_end_label.text = UiText.t("bar_shift_ending", "FIN DE SHIFT PROCHE")
		_:
			_end_label.text = UiText.tf("bar_shift_end", [UiText.clock(UiText.SHIFT_END_MIN)], "FIN %s")
	_clock.add_theme_color_override(&"font_color", color)
	_end_label.add_theme_color_override(&"font_color", color if state != ClockState.NORMAL else DS.TEXT_SECONDARY)
	_clock_icon.visible = state != ClockState.NORMAL
	_clock_icon.kind = UiIcon.Kind.DENIED if state == ClockState.CRITICAL else UiIcon.Kind.WARNING
	_clock_icon.color = color
	_progress_bar.queue_redraw()


func get_clock_text() -> String:
	return _clock.text


func set_processed(count: int) -> void:
	_processed.text = "%02d" % count


func set_credits(credits: int) -> void:
	_credits.text = "₵ %d" % credits


func _draw_progress() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _progress_bar.size)
	_progress_bar.draw_rect(rect, DS.LINE_SUBTLE)
	var color: Color = DS.ACCENT_CYAN
	match clock_state:
		ClockState.WARNING:
			color = DS.STATE_AMBER
		ClockState.CRITICAL:
			color = DS.STATE_RED
	_progress_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(progress, 0.0, 1.0), rect.size.y)), color)
	# Graduations horaires (1 par heure de shift).
	var hours: int = roundi((UiText.SHIFT_END_MIN - UiText.SHIFT_START_MIN) / 60.0)
	for i: int in range(1, hours):
		var x: float = rect.size.x * i / hours
		_progress_bar.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), DS.BG_PANEL, 2.0)
