## Rulebook (DS §7.5, UI_FLOW §2.2 zone D) : en-tête (jour, badge NOUVEAU),
## onglets par catégorie, **date du jour** comparable, règles du jour
## (`RulebookEntry`) sélectionnables en Mode Inspection. Rétractable (Tab) :
## replié, il ne reste qu'une languette avec le compteur de nouveautés.
## M7 : seconde rangée « BULLETINS » (`DayDef.rulebook_tabs`) — Origines,
## Implants, Symboles subversifs, Sceaux (`RulebookReference`) et Avis de
## recherche (`WantedCardView`, sélectionnables comme un champ).
class_name RulebookPanel
extends PanelContainer

signal item_picked(item: InspectableItem)
signal collapse_changed(collapsed: bool)

## Onglet « toutes les règles ».
const TAB_ALL: int = -1
## M7 : onglets de référence (identifiants négatifs, ordre `RulebookReference.ORDER`).
const TAB_REFERENCE_BASE: int = -10
const COLLAPSED_WIDTH: float = 48.0

var entries: Array[RulebookEntry] = []
var today: int = 0
var day_number: int = 0
var inspection_active: bool = false
var collapsed: bool = false
var current_tab: int = TAB_ALL

var today_item: DocFieldView = null
var cards: Array[RuleCardView] = []
## M7 : onglets de référence ouverts ce jour et avis de recherche.
var reference_tabs: PackedStringArray = []
var wanted_notices: Array[WantedNotice] = []
var wanted_cards: Array[WantedCardView] = []
var portrait_provider: Callable = Callable()

var _content: VBoxContainer = null
var _day_label: Label = null
var _new_badge: PanelContainer = null
var _new_label: Label = null
var _tabs_row: HFlowContainer = null
var _ref_box: VBoxContainer = null
var _ref_row: HFlowContainer = null
var _reference_view: Control = null
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
	_tabs_row = HFlowContainer.new()
	_tabs_row.add_theme_constant_override("h_separation", 0)
	_tabs_row.add_theme_constant_override("v_separation", 0)
	_content.add_child(_tabs_row)
	_ref_box = VBoxContainer.new()
	_ref_box.add_theme_constant_override("separation", DS.SPACE_1)
	_ref_box.visible = false
	_content.add_child(_ref_box)
	var ref_caption: Label = Label.new()
	ref_caption.theme_type_variation = &"DocFieldLabel"
	ref_caption.uppercase = true
	ref_caption.text = UiText.t("rb_bulletins", "BULLETINS")
	_ref_box.add_child(ref_caption)
	_ref_row = HFlowContainer.new()
	_ref_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ref_row.add_theme_constant_override("h_separation", 0)
	_ref_row.add_theme_constant_override("v_separation", 0)
	_ref_box.add_child(_ref_row)
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


func _build_footer() -> void:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", DS.SPACE_2)
	_content.add_child(footer)
	_page_label = Label.new()
	_page_label.theme_type_variation = &"DataSmall"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_page_label)
	# « Tab » (replier) rejoint « [ » « ] » en pied : l'en-tête tient dans la
	# largeur du panneau avec le plancher de texte du Steam Deck (QA-009).
	footer.add_child(make_keycap("Tab"))
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


## Rulebook du jour (`day_started`) ; `tabs` : onglets de référence (M7).
func set_rulebook(p_entries: Array[RulebookEntry], p_today: int, p_day_number: int,
		tabs: PackedStringArray = PackedStringArray()) -> void:
	entries = p_entries.duplicate()
	reference_tabs = tabs.duplicate()
	wanted_notices.clear()
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
	_new_label.text = UiText.plural("rb_new_count", new_count, "%d NOUVEAU", "%d NOUVEAUX")
	_collapsed_count.text = "%d\nNEW" % new_count if new_count > 0 else ""
	_build_tabs()
	_show_tab(TAB_ALL)


## M7 : avis de recherche du jour (`wanted_notices_published`).
func set_wanted(notices: Array[WantedNotice], provider: Callable = Callable()) -> void:
	wanted_notices = notices.duplicate()
	portrait_provider = provider
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)


## Identifiant d'onglet d'une référence (`origins` → −10…).
static func reference_tab_id(tab: StringName) -> int:
	return TAB_REFERENCE_BASE - RulebookReference.ORDER.find(tab)


static func reference_of(id: int) -> StringName:
	var index: int = TAB_REFERENCE_BASE - id
	return RulebookReference.ORDER[index] if index >= 0 and index < RulebookReference.ORDER.size() else &""


## Onglets de référence affichés (dans l'ordre), l'avis seulement s'il existe.
func visible_reference_tabs() -> Array[StringName]:
	var tabs: Array[StringName] = []
	for tab: StringName in RulebookReference.ORDER:
		if not reference_tabs.has(String(tab)):
			continue
		if tab == RulebookReference.TAB_WANTED and wanted_notices.is_empty():
			continue
		tabs.append(tab)
	return tabs


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
	var refs: Array[StringName] = visible_reference_tabs()
	_ref_box.visible = not refs.is_empty()
	for tab: StringName in refs:
		var id: int = reference_tab_id(tab)
		var button: Button = Button.new()
		button.theme_type_variation = &"ToggleTab"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.text = RulebookReference.tab_title(tab)
		button.name = "Tab_%s" % tab
		if tab == RulebookReference.TAB_WANTED:
			button.text += " ·%d" % wanted_notices.size()
			button.add_theme_color_override(&"font_color", DS.STATE_RED)
		elif RulebookReference.is_new(tab, day_number):
			button.text += " ·" + UiText.t("rb_tab_new", "NEW")
			button.add_theme_color_override(&"font_color", DS.STATE_AMBER)
		button.pressed.connect(_show_tab.bind(id))
		_ref_row.add_child(button)
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
	for card: InspectableItem in _list_items():
		marks[card.ref.key()] = [card.selected, card.flag_numbers.duplicate()]
		card.queue_free()
	cards.clear()
	wanted_cards.clear()
	if _reference_view != null:
		_reference_view.queue_free()
		_reference_view = null
	if id <= TAB_REFERENCE_BASE:
		_show_reference(reference_of(id), marks)
		var ref_index: int = _tab_ids.find(id)
		_page_label.text = UiText.tf("rb_page", [ref_index + 1, _tab_ids.size()], "ONGLET %d / %d")
		return
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


func _list_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	for card: RuleCardView in cards:
		items.append(card)
	for card: WantedCardView in wanted_cards:
		items.append(card)
	return items


## Contenu d'un onglet de référence ; avis de recherche = cartes sélectionnables.
func _show_reference(tab: StringName, marks: Dictionary[String, Array]) -> void:
	if tab != RulebookReference.TAB_WANTED:
		_reference_view = RulebookReference.build(tab)
		_reference_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(_reference_view)
		return
	# Consigne en infobulle : la place va aux avis (portrait lisible).
	_scroll.tooltip_text = UiText.t("rb_wanted_intro", "Par le nom ou par le visage : mise en attente.")
	for i: int in wanted_notices.size():
		var card: WantedCardView = WantedCardView.new()
		card.name = "Wanted_%s" % wanted_notices[i].id
		card.setup(wanted_notices[i], i + 1, portrait_provider)
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
		wanted_cards.append(card)


## Onglet précédent / suivant ([ / ], LB / RB).
func cycle_tab(step: int) -> void:
	if _tab_ids.is_empty():
		return
	var index: int = posmod(_tab_ids.find(current_tab) + step, _tab_ids.size())
	_show_tab(_tab_ids[index])


func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = [today_item]
	items.append_array(_list_items())
	return items


## Élément affiché pour `ref` ; bascule sur l'onglet « Règles » si la règle
## est masquée par l'onglet courant.
func find_item(ref: FieldRef, reveal: bool = false) -> InspectableItem:
	if ref.is_today():
		return today_item
	for card: InspectableItem in _list_items():
		if card.ref.equals(ref):
			return card
	if reveal and ref.is_wanted():
		var wanted_id: int = reference_tab_id(RulebookReference.TAB_WANTED)
		if _tab_ids.has(wanted_id) and current_tab != wanted_id:
			_show_tab(wanted_id)
			return find_item(ref, false)
		return null
	if reveal and current_tab != TAB_ALL:
		_show_tab(TAB_ALL)
		return find_item(ref, false)
	return null


## Affiche un onglet de référence (`origins`, `wanted`…) ; faux s'il est fermé.
func show_reference_tab(tab: StringName) -> bool:
	var id: int = reference_tab_id(tab)
	if not _tab_ids.has(id):
		return false
	_show_tab(id)
	return true


## Carte d'avis de recherche affichée (null si l'onglet n'est pas ouvert).
func get_wanted_card(notice_id: StringName) -> WantedCardView:
	for card: WantedCardView in wanted_cards:
		if card.notice.id == notice_id:
			return card
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
