## Bandeau ÉVÉNEMENT (M12 lot C, I32 ; M12 §3.1 règle 2, D-129) : événement
## de station en cours, en haut de la vitre sous la barre d'état — icône propre
## à l'événement + surtitre « ÉVÉNEMENT » + titre (`sev_<id>_title`) + durée
## restante (« 3 PASSAGERS », « JUSQU'À 14:00 », « JUSQU'À LA FIN DU SHIFT »).
## Jamais la couleur seule : forme de l'icône et texte (D-107). Liseré et fond
## ambre (`Palette`), voile ≥ 85 % derrière le texte (DS §5 règle 5).
## Piloté par `ComparisonUI` (`set_events(plans, processed)`), qui écoute
## `station_event_started` / `station_event_ended` et compte les passagers.
class_name StationEventBanner
extends PanelContainer

## Icône par événement (`StationEventDef.key`) : formes distinctes.
const ICONS: Dictionary[StringName, UiIcon.Kind] = {
	&"mrz_reader": UiIcon.Kind.SCANNER,
	&"comparator": UiIcon.Kind.EQUAL,
	&"quarantine": UiIcon.Kind.WARNING,
	&"inspection": UiIcon.Kind.SCALES,
	&"blackout": UiIcon.Kind.LOCK,
	&"crowd": UiIcon.Kind.BREATH,
	&"stolen_ids": UiIcon.Kind.REGISTER,
	&"exemption": UiIcon.Kind.CHECK,
}

var plans: Array[StationEventPlan] = []
var processed: int = 0
var _rows: VBoxContainer = null


func _init() -> void:
	name = "StationEventBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.PANEL_VEIL, Palette.STATE_AMBER, DS.BORDER_DEFAULT, DS.CHAMFER_S, DS.SPACE_2)
	box.content_margin_left = DS.SPACE_3
	box.content_margin_right = DS.SPACE_3
	box.border_width_left = DS.BORDER_STRONG + 1
	add_theme_stylebox_override(&"panel", box)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", DS.SPACE_1)
	add_child(_rows)
	_rebuild()


## Événements en cours et passagers déjà traités ce shift.
func set_events(p_plans: Array[StationEventPlan], p_processed: int) -> void:
	plans = p_plans.duplicate()
	processed = p_processed
	_rebuild()


static func icon_for(plan: StationEventPlan) -> UiIcon.Kind:
	if plan == null or plan.event == null:
		return UiIcon.Kind.WARNING
	return ICONS.get(plan.event.key, UiIcon.Kind.WARNING)


## Titre du bandeau (`sev_<key>_title`).
static func title_for(plan: StationEventPlan) -> String:
	if plan == null or plan.event == null:
		return ""
	var key: String = plan.event.title_key if not plan.event.title_key.is_empty() else "sev_%s_title" % plan.event.key
	return UiText.t(key, String(plan.event.key).to_upper())


## Durée restante : passagers, heure de fin ou fin du shift.
static func remaining_text(plan: StationEventPlan, p_processed: int) -> String:
	if plan == null or plan.event == null:
		return ""
	match plan.event.window_kind:
		StationEventDef.WindowKind.CLOCK:
			if plan.clock_to >= 0:
				return UiText.tf("sev_ui_until", [UiText.clock(plan.clock_to)], "JUSQU'À %s")
		StationEventDef.WindowKind.SECONDS:
			return UiText.t("sev_ui_now", "EN COURS")
	var left: int = plan.remaining(p_processed)
	if left < 0:
		return UiText.t("sev_ui_rest_of_day", "JUSQU'À LA FIN DU SHIFT")
	return UiText.plural("sev_ui_remaining", left, "%d PASSAGER", "%d PASSAGERS")


## Ligne ambre du Rulebook (`sev_<key>_rb`), `%d` = passagers restants ; vide
## si l'événement n'en a pas.
static func rulebook_line(plan: StationEventPlan, p_processed: int) -> String:
	if plan == null or plan.event == null or plan.event.rulebook_key.is_empty():
		return ""
	var text: String = UiText.t(plan.event.rulebook_key, "")
	if not text.contains("%d"):
		return text
	var left: int = plan.remaining(p_processed)
	if left >= 0:
		return text.replace("%d", str(left))
	var cleaned: RegEx = RegEx.create_from_string("\\s*\\(%d[^)]*\\)")
	return cleaned.sub(text, "", true).replace("%d", "—")


func _rebuild() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		child.queue_free()
	for plan: StationEventPlan in plans:
		if plan == null or plan.event == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Event_%s" % plan.event.id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", DS.SPACE_3)
		_rows.add_child(row)
		row.add_child(UiIcon.make(icon_for(plan), Palette.STATE_AMBER, DS.ICON_M))
		var eyebrow: Label = ScreenBase.label(UiText.t("sev_ui_eyebrow", "ÉVÉNEMENT"), &"DocFieldLabel", Palette.STATE_AMBER)
		eyebrow.uppercase = true
		eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(eyebrow)
		var title: Label = ScreenBase.label(title_for(plan), &"BodyStrong", DS.TEXT_PRIMARY)
		title.name = "Title"
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var left: Label = ScreenBase.label(remaining_text(plan, processed), &"DataSmall", Palette.STATE_AMBER)
		left.name = "Remaining"
		left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(left)
	visible = _rows.get_child_count() > 0 and not plans.is_empty()


## Texte du bandeau (tests) : titres et restes, séparés par « · ».
func get_text() -> String:
	var parts: PackedStringArray = []
	for plan: StationEventPlan in plans:
		parts.append("%s · %s" % [title_for(plan), remaining_text(plan, processed)])
	return " | ".join(parts)
