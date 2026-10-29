## Barre d'état (UI_FLOW §2.2 zone A, DS §7.6) : marque Consortium, lieu /
## guichet / jour / date, horloge de shift (heure + progression + fin),
## passagers traités, crédits. Acte II : compteur du quota respiratoire
## (`QuotaCounterView`, sélectionnable en Mode Inspection, masqué sans quota). Seuils : ambre « FIN DE SHIFT PROCHE » à 30 min
## in-game de la fin ; rouge à `DS.TIMER_CRITICAL_SECONDS` réelles.
## Barre adaptative (QA-031, même logique que la barre d'outils QA-011) :
## quand la largeur manque (Steam Deck, texte 1,5, compteur QUOTA), les
## éléments secondaires sont abandonnés par paliers, jamais tronqués ; QUOTA,
## TRAITÉS, CRÉDITS et l'horloge restent toujours à l'écran.
class_name TopBar
extends PanelContainer

enum ClockState { NORMAL, WARNING, CRITICAL }

const HEIGHT: float = 56.0
const PROGRESS_WIDTH: float = 216.0
## Paliers d'abandon (QA-031) : 1 sans sur-titre « CONSORTIUM · … », 2 sans
## « FIN 18:00 », 3 jauge de shift réduite, 4 sans lieu, 5 sans jauge ni
## « SHIFT », 6 sans marque « CLEARANCE » (logo gardé), 7 date réduite au
## jour, 8 compteurs sans légende (QUOTA compact « QUOTA n/max »).
const MAX_COMPACT_LEVEL: int = 8

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
## Acte II : compteur « QUOTA n/max » (R23).
var quota_view: QuotaCounterView = null
var _quota_line: ColorRect = null
## Palier d'abandon en vigueur (0 = barre complète).
var compact_level: int = 0
var _compaction_queued: bool = false
var _margin: MarginContainer = null
var _brand: Label = null
var _org: Label = null
var _shift_caption: Label = null
var _captions: Array[Label] = []
## Compteurs sur une ligne (légende à côté de la valeur) : la pile ne tient pas
## dans la hauteur de la barre (texte 1,5).
var _one_line: bool = false
var _day_number: int = 0
var _date_days: int = 0


func _ready() -> void:
	theme_type_variation = &"BarPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DS.SPACE_6)
	margin.add_theme_constant_override("margin_right", DS.SPACE_6)
	add_child(margin)
	_margin = margin
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
	_brand = brand
	row.add_child(_vline())
	var org: Label = Label.new()
	org.theme_type_variation = &"DocIssuer"
	org.add_theme_color_override(&"font_color", DS.ACCENT_YELLOW)
	org.uppercase = true
	org.text = UiText.t("bar_org", "CONSORTIUM · CONTRÔLE D'ENTRÉE")
	org.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Libellé secondaire : affiché en entier ou abandonné (palier 1), jamais
	# tronqué en « CONSORT… » (QA-029).
	row.add_child(org)
	_org = org
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
	_shift_caption = shift
	_clock_icon = UiIcon.make(UiIcon.Kind.WARNING, Palette.STATE_AMBER, DS.ICON_M)
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
	_quota_line = _vline()
	_quota_line.visible = false
	row.add_child(_quota_line)
	quota_view = QuotaCounterView.new()
	quota_view.name = "QuotaCounter"
	quota_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(quota_view)
	row.add_child(_vline())
	_credits = _stat(row, UiText.t("bar_credits", "CRÉDITS"), DS.ACCENT_YELLOW)
	quota_view.visibility_changed.connect(queue_compaction)
	set_clock(1.0, 1.0)
	set_processed(0)
	set_credits(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_compaction()


## Recalcule (en différé) le palier d'abandon pour que la barre tienne dans
## sa largeur (QA-031).
func queue_compaction() -> void:
	if _compaction_queued or _margin == null:
		return
	_compaction_queued = true
	update_compaction.call_deferred()


func update_compaction() -> void:
	_compaction_queued = false
	if _margin == null or not is_inside_tree():
		return
	# Largeur du parent (l'écran), pas la nôtre : une barre trop large pour
	# son contenu s'élargit au-delà du bord droit.
	var available: float = get_parent_area_size().x
	if available <= 0.0:
		return
	# Hauteur d'abord : légende + valeur empilées plus hautes que la barre
	# (texte 1,5 en 1080p) → légende à côté de la valeur, sur une ligne.
	_one_line = false
	_apply_compact_level(0)
	_one_line = stacked_height() > HEIGHT - _panel_margins().y
	var level: int = 0
	while level <= MAX_COMPACT_LEVEL:
		_apply_compact_level(level)
		if required_width() <= available:
			break
		level += 1
	compact_level = mini(level, MAX_COMPACT_LEVEL)


## Hauteur des compteurs empilés (légende + valeur) au palier 0.
func stacked_height() -> float:
	var height: float = 0.0
	for caption: Label in _captions:
		var column: Control = caption.get_parent() as Control
		height = maxf(height, column.get_combined_minimum_size().y)
	return height


func _panel_margins() -> Vector2:
	var panel: StyleBox = get_theme_stylebox(&"panel")
	return panel.get_minimum_size() if panel != null else Vector2.ZERO


func _apply_compact_level(level: int) -> void:
	_set_secondary(level)
	for caption: Label in _captions:
		var column: BoxContainer = caption.get_parent() as BoxContainer
		column.vertical = not _one_line
		column.add_theme_constant_override("separation", DS.SPACE_2 if _one_line else 0)
		caption.visible = level < 8
	quota_view.compact = level >= 8 or _one_line


func _set_secondary(level: int) -> void:
	_org.visible = level < 1
	_end_label.visible = level < 2
	_progress_bar.custom_minimum_size.x = PROGRESS_WIDTH if level < 3 else PROGRESS_WIDTH * 0.5
	_location.visible = level < 4
	_progress_bar.visible = level < 5
	_shift_caption.visible = level < 5
	_brand.visible = level < 6
	_refresh_date(level >= 7)


## Largeur nécessaire à la barre au palier appliqué.
func required_width() -> float:
	var total: float = _margin.get_combined_minimum_size().x
	var panel: StyleBox = get_theme_stylebox(&"panel")
	if panel != null:
		total += panel.get_minimum_size().x
	return total


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _vline() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Palette.LINE_SUBTLE
	line.custom_minimum_size = Vector2(1, DS.SPACE_8)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


func _stat(row: HBoxContainer, caption: String, color: Color) -> Label:
	var column: BoxContainer = BoxContainer.new()
	column.vertical = true
	column.add_theme_constant_override("separation", 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	var label: Label = Label.new()
	label.theme_type_variation = &"DocFieldLabel"
	label.text = caption
	column.add_child(label)
	_captions.append(label)
	var value: Label = Label.new()
	value.theme_type_variation = &"DocFieldValue"
	value.add_theme_color_override(&"font_color", color)
	column.add_child(value)
	return value


func set_day(day_number: int, date_days: int) -> void:
	_day_number = day_number
	_date_days = date_days
	_refresh_date(compact_level >= 7)
	queue_compaction()


func _refresh_date(short: bool) -> void:
	var day_text: String = UiText.tf("bar_day", [_day_number], "JOUR %02d")
	_date.text = day_text if short else "%s · %s" % [day_text, UiText.date_with_weekday(_date_days)]


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
	var changed: bool = state != clock_state
	clock_state = state
	var color: Color = DS.TEXT_PRIMARY
	match state:
		ClockState.WARNING:
			color = Palette.STATE_AMBER
			_end_label.text = UiText.t("bar_shift_ending", "FIN DE SHIFT PROCHE")
		ClockState.CRITICAL:
			color = Palette.STATE_RED
			# Critique ≠ avertissement par le texte et l'icône, pas la couleur seule (M11).
			_end_label.text = UiText.t("bar_shift_critical", "FIN DE SHIFT IMMINENTE")
		_:
			_end_label.text = UiText.tf("bar_shift_end", [UiText.clock(UiText.SHIFT_END_MIN)], "FIN %s")
	if changed:
		queue_compaction()
	_clock.add_theme_color_override(&"font_color", color)
	_end_label.add_theme_color_override(&"font_color", color if state != ClockState.NORMAL else Palette.TEXT_SECONDARY)
	_clock_icon.visible = state != ClockState.NORMAL
	_clock_icon.kind = UiIcon.Kind.DENIED if state == ClockState.CRITICAL else UiIcon.Kind.WARNING
	_clock_icon.color = color
	_progress_bar.queue_redraw()


func get_clock_text() -> String:
	return _clock.text


func set_processed(count: int) -> void:
	_processed.text = "%02d" % count


## Acte II : compteur du quota (`quota_changed`) ; `maximum` 0 le masque.
func set_quota(used: int, maximum: int) -> void:
	quota_view.set_quota(used, maximum)
	_quota_line.visible = quota_view.visible


## Acte III : quota suspendu ce jour (« QUOTA SUSPENDU » gris, M1).
func set_quota_suspended(value: bool) -> void:
	quota_view.set_suspended(value)
	_quota_line.visible = quota_view.visible


func set_credits(credits: int) -> void:
	var text: String = "₵ %d" % credits
	if text.length() != _credits.text.length():
		queue_compaction()
	_credits.text = text


func _draw_progress() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _progress_bar.size)
	_progress_bar.draw_rect(rect, Palette.LINE_SUBTLE)
	var color: Color = DS.ACCENT_CYAN
	match clock_state:
		ClockState.WARNING:
			color = Palette.STATE_AMBER
		ClockState.CRITICAL:
			color = Palette.STATE_RED
	_progress_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(progress, 0.0, 1.0), rect.size.y)), color)
	# Graduations horaires (1 par heure de shift).
	var hours: int = roundi((UiText.SHIFT_END_MIN - UiText.SHIFT_START_MIN) / 60.0)
	for i: int in range(1, hours):
		var x: float = rect.size.x * i / hours
		_progress_bar.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), DS.BG_PANEL, 2.0)
