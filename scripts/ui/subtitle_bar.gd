## Sous-titres des barks (UI_FLOW §4.8) : en bas de la vitre, sous le visage,
## `[tag] NOM « texte »` sur fond `bg.void` 85 %. Non diégétique : aucun effet.
## Durée = max(1,5 s ; 60 ms × caractères). Désactivables (`Settings.subtitles`).
## M14 : annonces d'ambiance « [Haut-parleur] « … » » (sans locuteur, durée imposée).
class_name SubtitleBar
extends PanelContainer

var enabled: bool = true

var _tag: Label = null
var _speaker: Label = null
var _text: Label = null
var _serial: int = 0


func _ready() -> void:
	theme_type_variation = &"SubtitlePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(row)
	_tag = Label.new()
	_tag.theme_type_variation = &"BodySmall"
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tag)
	_speaker = Label.new()
	_speaker.theme_type_variation = &"DocIssuer"
	_speaker.uppercase = true
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_speaker)
	_text = Label.new()
	_text.theme_type_variation = &"SubtitleText"
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)


## `hold_sec` > 0 : durée imposée (annonces d'ambiance M14 : durée du signal).
func show_line(speaker: String, text: String, tag: String = "", hold_sec: float = 0.0) -> void:
	if not enabled or text.is_empty():
		return
	_serial += 1
	var serial: int = _serial
	_tag.text = tag
	_tag.visible = not tag.is_empty()
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	_text.text = UiText.quoted(text)
	visible = true
	reset_size()
	if is_inside_tree():
		get_tree().create_timer(hold_sec if hold_sec > 0.0 else UiText.subtitle_hold(text)).timeout.connect(_expire.bind(serial))


## Didascalie seule (« [trois tapes sur la vitre] »), sans réplique.
func show_tag(speaker: String, tag: String) -> void:
	if not enabled or tag.is_empty():
		return
	_serial += 1
	var serial: int = _serial
	_tag.text = tag
	_tag.visible = true
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	_text.text = ""
	visible = true
	reset_size()
	if is_inside_tree():
		get_tree().create_timer(DS.SUBTITLE_MIN_HOLD + DS.DUR_DRAMATIC).timeout.connect(_expire.bind(serial))


func get_tag() -> String:
	return _tag.text if visible and _tag.visible else ""


func get_text() -> String:
	return _text.text if visible else ""


func _expire(serial: int) -> void:
	if serial == _serial:
		visible = false
