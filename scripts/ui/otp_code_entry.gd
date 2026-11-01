## Saisie du **code reçu par e-mail** (M16, UI_FLOW §8.10) — `length` cases
## (6 par défaut, ONLINE.md §2), jouable sans clavier : un seul contrôle
## focalisable (anneau cyan sur la case courante).
## - Clavier : chiffres (le curseur avance), Retour arrière, ← →, Ctrl+V
##   (chiffres seulement : espaces et tirets ignorés) ; le dernier chiffre
##   tapé envoie le code (`submitted`).
## - Manette : croix ↑ ↓ change le chiffre de la case, ← → change de case
##   (aux bords, le focus quitte la saisie), Ⓐ envoie si le code est complet.
## Chiffres en mono (`DataTitle`), cases ≥ 48 px (cible ≥ 40 px, D-023).
class_name OtpCodeEntry
extends HBoxContainer

signal changed(code: String)
signal submitted(code: String)

const CELL_SIZE: Vector2 = Vector2(48, 56)

var length: int = OnlineConfig.OTP_LENGTH
var digits: PackedStringArray = []
var cursor: int = 0
var _cells: Array[PanelContainer] = []
var _labels: Array[Label] = []


static func make(p_length: int = OnlineConfig.OTP_LENGTH) -> OtpCodeEntry:
	var entry: OtpCodeEntry = OtpCodeEntry.new()
	entry.length = clampi(p_length, 4, 10)
	return entry


func _ready() -> void:
	name = "CodeEntry" if name.is_empty() or name.begins_with("@") else name
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", DS.SPACE_2)
	digits.resize(length)
	for i: int in length:
		digits[i] = ""
		var cell: PanelContainer = PanelContainer.new()
		cell.custom_minimum_size = CELL_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: Label = ScreenBase.label("", &"DataTitle", DS.TEXT_PRIMARY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		add_child(cell)
		_cells.append(cell)
		_labels.append(l)
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)
	_refresh()


func code() -> String:
	return "".join(digits)


func is_complete() -> bool:
	return code().length() == length


## Remplit la saisie (presse-papiers, tests) : chiffres seulement.
func set_code(text: String) -> void:
	var clean: String = OnlineConfig.clean_code(text).left(length)
	for i: int in length:
		digits[i] = clean[i] if i < clean.length() else ""
	cursor = mini(clean.length(), length - 1)
	_refresh()


func clear() -> void:
	set_code("")
	cursor = 0
	_restyle()


func _refresh() -> void:
	for i: int in _labels.size():
		_labels[i].text = digits[i] if not digits[i].is_empty() else "·"
		_labels[i].add_theme_color_override(&"font_color", DS.TEXT_PRIMARY if not digits[i].is_empty() else DS.TEXT_MUTED)
	_restyle()
	changed.emit(code())


func _restyle() -> void:
	for i: int in _cells.size():
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = DS.BG_PANEL
		var active: bool = has_focus() and i == cursor
		box.border_color = DS.ACCENT_CYAN if active else Palette.LINE_SUBTLE
		box.set_border_width_all(DS.BORDER_STRONG if active else DS.BORDER_DEFAULT)
		_cells[i].add_theme_stylebox_override(&"panel", box)


func _type_digit(d: String) -> void:
	digits[cursor] = d
	var last: bool = cursor == length - 1
	cursor = mini(cursor + 1, length - 1)
	_refresh()
	if last and is_complete():
		submitted.emit(code())


func _step_digit(delta: int) -> void:
	if digits[cursor].is_empty():
		digits[cursor] = "0" if delta > 0 else "9"
	else:
		digits[cursor] = str(posmod(digits[cursor].to_int() + delta, 10))
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		if key.unicode >= 48 and key.unicode <= 57 and not key.ctrl_pressed:
			_type_digit(char(key.unicode))
			accept_event()
			return
		if key.keycode == KEY_BACKSPACE:
			if digits[cursor].is_empty() and cursor > 0:
				cursor -= 1
			digits[cursor] = ""
			_refresh()
			accept_event()
			return
		if key.keycode == KEY_V and (key.ctrl_pressed or key.meta_pressed):
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				set_code(DisplayServer.clipboard_get())
				if is_complete():
					submitted.emit(code())
			accept_event()
			return
	if event.is_action_pressed(&"ui_up", true):
		_step_digit(1)
		accept_event()
	elif event.is_action_pressed(&"ui_down", true):
		_step_digit(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_left", true) and cursor > 0:
		cursor -= 1
		_restyle()
		accept_event()
	elif event.is_action_pressed(&"ui_right", true) and cursor < length - 1:
		cursor += 1
		_restyle()
		accept_event()
	elif event.is_action_pressed(&"ui_accept", false, true):
		if is_complete():
			submitted.emit(code())
		accept_event()
