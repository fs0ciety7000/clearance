## Bulle passager / intercom (DS §7.10, UI_FLOW §2.2 zone B gauche, §4.2) :
## locuteur, dernière réplique, LED d'intercom (équivalent visuel de la voix),
## questions débloquées et menu « Interroger » numéroté (1–5).
## Posée sur la vitre : voile ≥ 85 % derrière le texte (DS §5).
class_name PassengerPanel
extends PanelContainer

signal question_chosen(topic: StringName)

const MAX_QUESTIONS: int = 5

var speaker: String = ""
var speaking: bool = false:
	set(value):
		speaking = value
		if _led != null:
			_led.queue_redraw()

var _speaker_label: Label = null
var _led: Control = null
var _intercom_label: Label = null
var _line: Label = null
var _hint: Label = null
var _questions: VBoxContainer = null
var _speak_timer: SceneTreeTimer = null
## Acte II : accent de la figure finale du J20 (liseré gauche + locuteur),
## transparent sinon.
var accent: Color = Color.TRANSPARENT


func _ready() -> void:
	theme_type_variation = &"VeilPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", DS.SPACE_2)
	box.add_child(header)
	_speaker_label = Label.new()
	_speaker_label.theme_type_variation = &"DocIssuer"
	_speaker_label.uppercase = true
	_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Nom composé au Deck (« D. LINDQVIST-REY ») : repli sur deux lignes plutôt
	# qu'un nom tronqué contre « INTERCOM » (QA-040).
	_speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_speaker_label)
	_led = Control.new()
	_led.custom_minimum_size = Vector2(DS.SPACE_2, DS.SPACE_2)
	_led.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_led.draw.connect(_draw_led)
	header.add_child(_led)
	_intercom_label = Label.new()
	_intercom_label.theme_type_variation = &"DocFieldLabel"
	_intercom_label.uppercase = true
	_intercom_label.text = UiText.t("pp_intercom", "INTERCOM")
	header.add_child(_intercom_label)
	_line = Label.new()
	_line.theme_type_variation = &"SubtitleText"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_hint = Label.new()
	_hint.theme_type_variation = &"BodySmall"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	_questions = VBoxContainer.new()
	_questions.add_theme_constant_override("separation", DS.SPACE_2)
	box.add_child(_questions)


func set_speaker(text: String, identified: bool) -> void:
	speaker = text
	_speaker_label.text = text
	var color: Color = accent if accent.a > 0.0 and identified else DS.ACCENT_CYAN
	_speaker_label.add_theme_color_override(&"font_color", color)


## Acte II : quelqu'un que l'agent·e connaît est à la vitre (SC-50).
func set_accent(color: Color) -> void:
	accent = color
	queue_redraw()


func _draw() -> void:
	if accent.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), accent)


## Dernière réplique (entre guillemets) ; allume la LED le temps de la lecture.
func set_line(text: String, quoted: bool = true) -> void:
	_line.text = ("« %s »" % text) if quoted and not text.is_empty() else text
	_line.visible = not text.is_empty()
	speaking = not text.is_empty()
	if speaking and is_inside_tree():
		_speak_timer = get_tree().create_timer(UiText.subtitle_hold(text))
		_speak_timer.timeout.connect(_on_speak_timeout.bind(_speak_timer))


func get_line() -> String:
	return _line.text


func get_hint() -> String:
	return _hint.text


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = not text.is_empty()


func _on_speak_timeout(timer: SceneTreeTimer) -> void:
	if timer == _speak_timer:
		speaking = false


func _draw_led() -> void:
	var color: Color = DS.ACCENT_CYAN if speaking else DS.TEXT_MUTED
	_led.draw_circle(_led.size * 0.5, _led.size.x * 0.5, color)


## Cartes « question débloquée » (aperçu, menu fermé).
func show_unlocked(cards: Array[Dictionary]) -> void:
	_clear_questions()
	for card: Dictionary in cards:
		_questions.add_child(_make_unlocked_card(card))


## Menu d'interrogatoire : `items` = [{topic, text, unlocked, asked}].
func show_menu(items: Array[Dictionary]) -> void:
	_clear_questions()
	_hint.visible = false
	var title: Label = Label.new()
	title.theme_type_variation = &"DocFieldLabel"
	title.uppercase = true
	title.text = UiText.t("pp_menu_title", "INTERROGER · CHOISISSEZ UNE QUESTION")
	_questions.add_child(title)
	var count: int = mini(items.size(), MAX_QUESTIONS)
	for i: int in count:
		var item: Dictionary = items[i]
		var button: Button = Button.new()
		button.theme_type_variation = &"ButtonQuestion"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var text: String = item.get("text", "")
		button.text = "%d   %s" % [i + 1, text]
		var unlocked: bool = item.get("unlocked", false)
		var asked: bool = item.get("asked", false)
		var luciole: bool = item.get("luciole", false)
		if luciole:
			# Réponse à la phrase de passe (code 4) : voix des Lucioles, magenta.
			button.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
			button.text = "%d   ◆ %s" % [i + 1, text]
		elif unlocked:
			button.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
		elif asked:
			button.add_theme_color_override(&"font_color", DS.TEXT_SECONDARY)
		var topic: StringName = item.get("topic", &"")
		button.pressed.connect(_on_question_pressed.bind(topic))
		button.custom_minimum_size.y = DS.HIT_TARGET_MIN - DS.SPACE_1
		_questions.add_child(button)
	if count > 0:
		var first: Button = _questions.get_child(1) as Button
		first.grab_focus.call_deferred()


func close_menu() -> void:
	_clear_questions()


## Index de la question `n` (1-based) du menu ouvert, ou vide.
func topic_at(n: int, items: Array[Dictionary]) -> StringName:
	if n < 1 or n > mini(items.size(), MAX_QUESTIONS):
		return &""
	return items[n - 1].get("topic", &"")


func _clear_questions() -> void:
	for child: Node in _questions.get_children():
		_questions.remove_child(child)
		child.queue_free()


func _on_question_pressed(topic: StringName) -> void:
	question_chosen.emit(topic)


func _make_unlocked_card(card: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"DialogueQuestion"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_3)
	panel.add_child(row)
	row.add_child(UiIcon.make(UiIcon.Kind.WARNING, DS.ACCENT_MAGENTA, DS.ICON_M))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DS.SPACE_1)
	row.add_child(column)
	var title: Label = Label.new()
	title.theme_type_variation = &"DocFieldLabel"
	title.uppercase = true
	title.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
	var number: int = card.get("number", 0)
	title.text = UiText.tf("pp_unlocked", [number], "QUESTION DÉBLOQUÉE · DISCORDANCE %d")
	column.add_child(title)
	var text: Label = Label.new()
	text.theme_type_variation = &"BodyLabel"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "« %s »" % str(card.get("text", ""))
	column.add_child(text)
	var keys: HBoxContainer = HBoxContainer.new()
	keys.add_theme_constant_override("separation", DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(RulebookPanel.make_keycap("Q"))
	keys.add_child(RulebookPanel.make_keycap("Y"))
	row.add_child(keys)
	return panel
