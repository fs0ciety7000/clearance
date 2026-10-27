## Rulebook (DS §7.5, UI_FLOW §2.2 zone D) : en-tête (jour, badge NOUVEAU),
## onglets par catégorie, **date du jour** comparable, règles du jour
## (`RulebookEntry`) sélectionnables en Mode Inspection. Rétractable (Tab) :
## replié, il ne reste qu'une languette avec le compteur de nouveautés.
class_name RulebookPanel
extends PanelContainer

signal item_picked(item: InspectableItem)
signal collapse_changed(collapsed: bool)

## Onglet « toutes les règles ».
const TAB_ALL: int = -1
const COLLAPSED_WIDTH: float = 48.0

var entries: Array[RulebookEntry] = []
var today: int = 0
var day_number: int = 0
var inspection_active: bool = false
var collapsed: bool = false
var current_tab: int = TAB_ALL

var today_item: DocFieldView = null
var cards: Array[RuleCardView] = []

var _content: VBoxContainer = null
var _day_label: Label = null
var _new_badge: PanelContainer = null
var _new_label: Label = null
var _tabs_row: HBoxContainer = null
var _tab_buttons: Array[Button] = []
var _tab_ids: Array[int] = []
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _page_label: Label = null
var _collapsed_tab: VBoxContainer = null
var _collapsed_count: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_L, DS.SPACE_5))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(_content)
	_build_header()
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 0)
	_content.add_child(_tabs_row)
	var today_card: PanelContainer = PanelContainer.new()
	var today_box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_ELEVATED, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	today_card.add_theme_stylebox_override(&"panel", today_box)
	_content.add_child(today_card)
	today_item = DocFieldView.new()
	today_item.setup_custom(FieldRef.today(), UiText.t("rb_today", "DATE DU JOUR"), "—")
	today_item.picked.connect(_on_item_picked)
	today_card.add_child(today_item)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", DS.SPACE_1)
	_scroll.add_child(_list)
	_build_footer()
	_build_collapsed_tab()


func _build_header() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", DS.SPACE_3)
	_content.add_child(header)
	var title: Label = Label.new()
	title.theme_type_variation = &"PanelTitle"
	title.text = UiText.t("rb_title", "RULEBOOK")
	title.uppercase = true
	header.add_child(title)
	_day_label = Label.new()
	_day_label.theme_type_variation = &"DataSmall"
	_day_label.add_theme_color_override(&"font_color", DS.ACCENT_YELLOW)
	_day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_day_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_new_badge = RuleCardView.make_new_badge("")
	_new_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_new_label = _new_badge.find_children("", "Label", true, false)[0] as Label
	header.add_child(_new_badge)
	header.add_child(make_keycap("Tab"))


func _build_footer() -> void:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", DS.SPACE_2)
	_content.add_child(footer)
	_page_label = Label.new()
	_page_label.theme_type_variation = &"DataSmall"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_page_label)
	footer.add_child(make_keycap("["))
	footer.add_child(make_keycap("]"))


func _build_collapsed_tab() -> void:
	_collapsed_tab = VBoxContainer.new()
	_collapsed_tab.visible = false
	_collapsed_tab.alignment = BoxContainer.ALIGNMENT_BEGIN
	_collapsed_tab.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(_collapsed_tab)
	_collapsed_tab.add_child(make_keycap("Tab"))
	var label: Label = Label.new()
	label.theme_type_variation = &"DocFieldLabel"
	label.text = "R\nU\nL\nE\nS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapsed_tab.add_child(label)
	_collapsed_count = Label.new()
	_collapsed_count.theme_type_variation = &"DocFieldLabel"
	_collapsed_count.add_theme_color_override(&"font_color", DS.STATE_AMBER)
	_collapsed_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapsed_tab.add_child(_collapsed_count)


## Touche affichée (« Tab », « Q », « LT »).
static func make_keycap(text: String) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	cap.theme_type_variation = &"KeyCap"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label: Label = Label.new()
	label.theme_type_variation = &"KeyCapLabel"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(label)
	return cap


## Rulebook du jour (`day_started`).
func set_rulebook(p_entries: Array[RulebookEntry], p_today: int, p_day_number: int) -> void:
	entries = p_entries.duplicate()
	today = p_today
	day_number = p_day_number
	_day_label.text = UiText.tf("rb_day", [p_day_number], "JOUR %02d")
	today_item.clear_marks()
	today_item.set_value_text(UiText.date(p_today))
	var new_count: int = 0
	for entry: RulebookEntry in entries:
		if entry.is_new:
			new_count += 1
	_new_badge.visible = new_count > 0
	_new_label.text = UiText.tf("rb_new_count", [new_count], "%d NOUVEAU")
	_collapsed_count.text = "%d\nNEW" % new_count if new_count > 0 else ""
	_build_tabs()
	_show_tab(TAB_ALL)


func _build_tabs() -> void:
	for button: Button in _tab_buttons:
		button.queue_free()
	_tab_buttons.clear()
	_tab_ids.clear()
	var group: ButtonGroup = ButtonGroup.new()
	var ids: Array[int] = [TAB_ALL]
	for entry: RulebookEntry in entries:
		if not ids.has(entry.category):
			ids.append(entry.category)
	for id: int in ids:
		var button: Button = Button.new()
		button.theme_type_variation = &"ToggleTab"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		var news: int = 0
		for entry: RulebookEntry in entries:
			if entry.is_new and (id == TAB_ALL or entry.category == id):
				news += 1
		button.text = _tab_name(id)
		if news > 0 and id != TAB_ALL:
			button.text += " ·%d" % news
			button.add_theme_color_override(&"font_color", DS.STATE_AMBER)
		button.pressed.connect(_show_tab.bind(id))
		_tabs_row.add_child(button)
		_tab_buttons.append(button)
		_tab_ids.append(id)


static func _tab_name(id: int) -> String:
	match id:
		Rule.RuleCategory.DOCUMENTS:
			return UiText.t("rb_tab_documents", "Documents")
		Rule.RuleCategory.IDENTITY:
			return UiText.t("rb_tab_identity", "Identité")
		Rule.RuleCategory.FACTION:
			return UiText.t("rb_tab_faction", "Origines")
		Rule.RuleCategory.PURPOSE:
			return UiText.t("rb_tab_purpose", "Motifs")
		Rule.RuleCategory.SPECIAL:
			return UiText.t("rb_tab_special", "Procédures")
	return UiText.t("rb_tab_all", "Règles")


func _show_tab(id: int) -> void:
	current_tab = id
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(_tab_ids[i] == id)
	# Conserver les marques (sélection, discordances) des cartes recréées.
	var marks: Dictionary[String, Array] = {}
	for card: RuleCardView in cards:
		marks[card.ref.key()] = [card.selected, card.flag_numbers.duplicate()]
		card.queue_free()
	cards.clear()
	for i: int in entries.size():
		var entry: RulebookEntry = entries[i]
		if id != TAB_ALL and entry.category != id:
			continue
		var card: RuleCardView = RuleCardView.new()
		card.setup(entry, i + 1)
		card.picked.connect(_on_item_picked)
		_list.add_child(card)
		card.set_inspection_active(inspection_active)
		var key: String = card.ref.key()
		if marks.has(key):
			var mark: Array = marks[key]
			var was_selected: bool = mark[0]
			card.set_selected(was_selected)
			for n: int in mark[1]:
				card.add_flag(n)
		cards.append(card)
	var index: int = _tab_ids.find(id)
	_page_label.text = UiText.tf("rb_page", [index + 1, _tab_ids.size()], "ONGLET %d / %d")


## Onglet précédent / suivant ([ / ], LB / RB).
func cycle_tab(step: int) -> void:
	if _tab_ids.is_empty():
		return
	var index: int = posmod(_tab_ids.find(current_tab) + step, _tab_ids.size())
	_show_tab(_tab_ids[index])


func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = [today_item]
	for card: RuleCardView in cards:
		items.append(card)
	return items


## Élément affiché pour `ref` ; bascule sur l'onglet « Règles » si la règle
## est masquée par l'onglet courant.
func find_item(ref: FieldRef, reveal: bool = false) -> InspectableItem:
	if ref.is_today():
		return today_item
	for card: RuleCardView in cards:
		if card.ref.equals(ref):
			return card
	if reveal and current_tab != TAB_ALL:
		_show_tab(TAB_ALL)
		return find_item(ref, false)
	return null


func set_inspection_active(enabled: bool) -> void:
	inspection_active = enabled
	for item: InspectableItem in get_items():
		item.set_inspection_active(enabled)
	queue_redraw()


func set_collapsed(value: bool) -> void:
	if collapsed == value:
		return
	collapsed = value
	_content.visible = not value
	_collapsed_tab.visible = value
	collapse_changed.emit(value)


func _on_item_picked(item: InspectableItem) -> void:
	item_picked.emit(item)


func _draw() -> void:
	if inspection_active and not collapsed:
		Workbench.draw_corner_brackets(self, Rect2(Vector2.ZERO, size).grow(DS.SPACE_1), DS.ACCENT_CYAN)
