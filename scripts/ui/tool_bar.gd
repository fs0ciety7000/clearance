## Barre d'outils (UI_FLOW §2.2 zone E) : Mode Inspection (bascule), Interroger
## (+ badge des questions débloquées), « Suivant » (intercom), ligne d'état,
## tiroir à tampons APPROUVÉ / REFUSÉ / (DÉTENTION). Raccourcis clavier et
## manette affichés en permanence.
class_name ToolBar
extends PanelContainer

signal inspection_toggled(enabled: bool)
signal interrogate_pressed()
signal next_pressed()
signal stamped(kind: VerdictKind.Kind)

const HEIGHT: float = 96.0
## Largeur minimale de la ligne d'état : en dessous, elle se replie en colonne
## et fait grandir la barre (QA-011).
const STATUS_MIN_W: float = 360.0
## Niveaux de compaction (Steam Deck, J7+ : « SUIVANT » + trois tampons) :
## 1 sans légende du tiroir, 2 tampons sans ligne d'aide, 3 sans touches sur
## Inspection / Interroger, 4 sans ligne d'état.
const MAX_COMPACT_LEVEL: int = 4

var inspect_button: Button = null
var interrogate_button: Button = null
var next_button: Button = null
var stamps: Dictionary[VerdictKind.Kind, StampButton] = {}

var _status: RichTextLabel = null
var _stamps_caption: Label = null
var _badge: PanelContainer = null
var _badge_label: Label = null
var _next_label: Label = null
var _next_keys: Control = null
var _row: HBoxContainer = null
var _caption_box: VBoxContainer = null
var _key_rows: Array[Control] = []
## Niveau de compaction en vigueur (0 = barre complète).
var compact_level: int = 0
var _compaction_queued: bool = false


func _ready() -> void:
	theme_type_variation = &"ToolbarPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DS.SPACE_6)
	margin.add_theme_constant_override("margin_right", DS.SPACE_6)
	margin.add_theme_constant_override("margin_top", DS.SPACE_4)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_4)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_4)
	margin.add_child(row)
	_row = row

	inspect_button = _tool_button(UiIcon.Kind.DIAMOND, UiText.t("tb_inspection", "INSPECTION"), [&"inspect_toggle"])
	inspect_button.toggle_mode = true
	inspect_button.toggled.connect(_on_inspect_toggled)
	row.add_child(inspect_button)

	interrogate_button = _tool_button(UiIcon.Kind.CHAT, UiText.t("tb_interrogate", "INTERROGER"), [&"interrogate"])
	interrogate_button.pressed.connect(interrogate_pressed.emit)
	row.add_child(interrogate_button)
	_badge = PanelContainer.new()
	_badge.theme_type_variation = &"BadgeMagenta"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.custom_minimum_size = Vector2(DS.SPACE_5, 0)
	_badge_label = Label.new()
	_badge_label.theme_type_variation = &"BadgeLabel"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_child(_badge_label)
	var inner: HBoxContainer = interrogate_button.get_child(0) as HBoxContainer
	inner.add_child(_badge)
	inner.move_child(_badge, 2)

	next_button = _tool_button(UiIcon.Kind.CHAT, "", [&"next_case"])
	next_button.theme_type_variation = &"ButtonPrimary"
	next_button.pressed.connect(next_pressed.emit)
	var next_inner: HBoxContainer = next_button.get_child(0) as HBoxContainer
	_next_label = next_inner.get_child(1) as Label
	_next_keys = next_inner.get_child(2) as Control
	next_inner.get_child(0).queue_free()
	row.add_child(next_button)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_color_override(&"default_color", Palette.TEXT_SECONDARY)
	refresh_fonts()
	row.add_child(_status)

	var drawer: PanelContainer = PanelContainer.new()
	drawer.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_2))
	row.add_child(drawer)
	var drawer_row: HBoxContainer = HBoxContainer.new()
	drawer_row.add_theme_constant_override("separation", DS.SPACE_3)
	drawer.add_child(drawer_row)
	var caption_box: VBoxContainer = VBoxContainer.new()
	_caption_box = caption_box
	caption_box.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_box.add_theme_constant_override("separation", DS.SPACE_1)
	drawer_row.add_child(caption_box)
	_stamps_caption = Label.new()
	_stamps_caption.theme_type_variation = &"DocFieldLabel"
	_stamps_caption.uppercase = true
	caption_box.add_child(_stamps_caption)
	var hold: Label = Label.new()
	hold.theme_type_variation = &"CaptionLabel"
	hold.text = UiText.tf("tb_hold", [DS.STAMP_HOLD], "maintien %.1f s")
	caption_box.add_child(hold)
	for kind: VerdictKind.Kind in [VerdictKind.Kind.APPROVE, VerdictKind.Kind.DENY, VerdictKind.Kind.DETAIN]:
		var button: StampButton = StampButton.new()
		button.setup(kind, stamp_hint(kind), UiText.t("tb_locked_hint", "aucun document"))
		button.stamped.connect(_on_stamped)
		drawer_row.add_child(button)
		stamps[kind] = button
	_key_rows = [(inspect_button.get_child(0) as HBoxContainer).get_child(2) as Control,
			(interrogate_button.get_child(0) as HBoxContainer).get_child(3) as Control]
	set_detain_available(false)
	set_stamps_locked(true)
	set_unlocked_count(0)


## Action de `project.godot` d'un tampon.
const STAMP_ACTIONS: Dictionary[VerdictKind.Kind, StringName] = {
	VerdictKind.Kind.APPROVE: &"stamp_approve",
	VerdictKind.Kind.DENY: &"stamp_deny",
	VerdictKind.Kind.DETAIN: &"stamp_detain",
}


## « maintenir V » / « maintenir RT »… selon le dernier périphérique (M11).
static func stamp_hint(kind: VerdictKind.Kind) -> String:
	return UiText.tf("tb_hint_hold", [InputPrompts.text_for(STAMP_ACTIONS[kind])], "maintenir %s")


## Invites réécrites quand le joueur change de périphérique (les glyphes des
## outils se mettent à jour d'eux-mêmes).
func refresh_prompts() -> void:
	for kind: VerdictKind.Kind in stamps:
		stamps[kind].set_hint(stamp_hint(kind))
	queue_compaction()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_compaction()


## Recalcule (en différé) le niveau de compaction pour que la barre tienne
## dans la largeur de son parent.
func queue_compaction() -> void:
	if _compaction_queued or _row == null:
		return
	_compaction_queued = true
	update_compaction.call_deferred()


func update_compaction() -> void:
	_compaction_queued = false
	if _row == null or not is_inside_tree():
		return
	var available: float = get_parent_area_size().x
	if available <= 0.0:
		return
	var level: int = 0
	while level <= MAX_COMPACT_LEVEL:
		_apply_compact_level(level)
		if required_width() <= available:
			break
		level += 1
	compact_level = mini(level, MAX_COMPACT_LEVEL)


func _apply_compact_level(level: int) -> void:
	_caption_box.visible = level < 1
	for kind: VerdictKind.Kind in stamps:
		stamps[kind].compact = level >= 2
	for keys: Control in _key_rows:
		keys.visible = level < 3
	_status.visible = level < 4
	for button: Button in [inspect_button, interrogate_button, next_button]:
		_fit_button(button, button.get_child(0) as HBoxContainer)


## Largeur nécessaire à la barre au niveau de compaction appliqué.
func required_width() -> float:
	var total: float = DS.SPACE_6 * 2.0
	var count: int = 0
	for child: Node in _row.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		count += 1
		if control == _status:
			total += status_min_width()
		else:
			total += control.get_combined_minimum_size().x
	total += _row.get_theme_constant(&"separation") * maxi(count - 1, 0)
	var panel: StyleBox = get_theme_stylebox(&"panel")
	if panel != null:
		total += panel.get_minimum_size().x
	return total


## Largeur minimale de la ligne d'état à la taille de texte en vigueur : elle
## tient sur deux lignes dans la barre (texte 1,5, plancher du Steam Deck :
## QA-031) ; sinon la barre abandonne un palier de plus.
func status_min_width() -> float:
	var font_size: int = get_theme_font_size(&"font_size", &"BodySmall")
	return STATUS_MIN_W * maxf(float(font_size) / DS.FS_BODY_S, 1.0)


## Recopie les polices du thème (BodySmall / BodyStrong) dans la ligne d'état
## (RichTextLabel) ; rappelé quand le thème est reconstruit.
func refresh_fonts() -> void:
	_status.add_theme_font_size_override(&"normal_font_size", get_theme_font_size(&"font_size", &"BodySmall"))
	_status.add_theme_font_size_override(&"bold_font_size", get_theme_font_size(&"font_size", &"BodySmall"))
	_status.add_theme_font_override(&"normal_font", get_theme_font(&"font", &"BodySmall"))
	_status.add_theme_font_override(&"bold_font", get_theme_font(&"font", &"BodyStrong"))
	queue_compaction()


## Bouton d'outil : icône + libellé + glyphes des actions (clavier ou
## manette selon le dernier périphérique, M11), dans un `ButtonTool`.
func _tool_button(icon: UiIcon.Kind, text: String, actions: Array[StringName]) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ButtonTool"
	button.focus_mode = Control.FOCUS_ALL
	var inner: HBoxContainer = HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", DS.SPACE_3)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = DS.SPACE_5
	inner.offset_right = -DS.SPACE_4
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(inner)
	var icon_node: UiIcon = UiIcon.make(icon, DS.ACCENT_CYAN, DS.ICON_M)
	inner.add_child(icon_node)
	var label: Label = Label.new()
	label.theme_type_variation = &"BodyStrong"
	label.uppercase = true
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(label)
	var key_row: HBoxContainer = HBoxContainer.new()
	key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_row.add_theme_constant_override("separation", DS.SPACE_1)
	for action: StringName in actions:
		var glyph: PromptGlyph = PromptGlyph.make(action)
		glyph.minimum_size_changed.connect(queue_compaction)
		key_row.add_child(glyph)
	inner.add_child(key_row)
	inner.minimum_size_changed.connect(_fit_button.bind(button, inner))
	_fit_button.call_deferred(button, inner)
	button.custom_minimum_size = Vector2(0, HEIGHT - DS.SPACE_8)
	return button


func _fit_button(button: Button, inner: HBoxContainer) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size.x = inner.get_combined_minimum_size().x + DS.SPACE_5 + DS.SPACE_4


func _on_inspect_toggled(enabled: bool) -> void:
	_refresh_inspect_colors(enabled)
	inspection_toggled.emit(enabled)


func _refresh_inspect_colors(enabled: bool) -> void:
	var label: Label = (inspect_button.get_child(0) as HBoxContainer).get_child(1) as Label
	if enabled:
		label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		label.remove_theme_color_override(&"font_color")


func set_inspection_pressed(enabled: bool) -> void:
	inspect_button.set_pressed_no_signal(enabled)
	_refresh_inspect_colors(enabled)


func set_inspection_available(available: bool) -> void:
	inspect_button.disabled = not available
	_set_inner_dim(inspect_button, not available)


func set_interrogate_available(available: bool) -> void:
	interrogate_button.disabled = not available
	_set_inner_dim(interrogate_button, not available)


func _set_inner_dim(button: Button, dim: bool) -> void:
	var inner: HBoxContainer = button.get_child(0) as HBoxContainer
	inner.modulate = Color(1, 1, 1, 0.45) if dim else Color.WHITE


func set_unlocked_count(count: int) -> void:
	_badge.visible = count > 0
	_badge_label.text = str(count)
	queue_compaction()


## « Suivant » : `mode` = &"ready" (CTA jaune), &"approaching", &"departing", &"hidden".
func set_next_mode(mode: StringName) -> void:
	next_button.visible = mode != &"hidden"
	match mode:
		&"ready":
			next_button.disabled = false
			next_button.theme_type_variation = &"ButtonPrimary"
			_next_label.text = UiText.t("tb_next", "SUIVANT")
			_next_label.add_theme_color_override(&"font_color", DS.TEXT_ON_ACCENT)
			_next_keys.visible = true
		&"approaching", &"departing":
			next_button.disabled = true
			next_button.theme_type_variation = &"ButtonTool"
			var key: String = "tb_next_approaching" if mode == &"approaching" else "tb_next_departing"
			_next_label.text = UiText.t(key, "SUIVANT · EN APPROCHE" if mode == &"approaching" else "SUIVANT · DÉPART")
			_next_label.add_theme_color_override(&"font_color", Palette.STATE_AMBER)
			_next_keys.visible = false
			next_button.add_theme_stylebox_override(&"disabled", ThemeBuilder.chamfer_box(DS.BG_PANEL, Palette.STATE_AMBER, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0))
	queue_compaction()


func set_status(bbcode: String) -> void:
	_status.text = bbcode


func get_status_text() -> String:
	return _status.get_parsed_text()


func set_stamps_locked(locked: bool) -> void:
	for kind: VerdictKind.Kind in stamps:
		stamps[kind].locked = locked
	_stamps_caption.text = UiText.t("tb_stamps_locked", "TAMPONS VERROUILLÉS") if locked else UiText.t("tb_stamps", "TAMPONS OFFICIELS")
	_stamps_caption.add_theme_color_override(&"font_color", Palette.TEXT_SECONDARY if locked else DS.ACCENT_YELLOW)
	queue_compaction()


func set_detain_available(available: bool) -> void:
	stamps[VerdictKind.Kind.DETAIN].visible = available
	queue_compaction()


func set_fx_intensity(value: float) -> void:
	for kind: VerdictKind.Kind in stamps:
		stamps[kind].fx_intensity = value


func _on_stamped(kind: VerdictKind.Kind) -> void:
	stamped.emit(kind)
