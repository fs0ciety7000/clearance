## Rulebook (DS §7.5, UI_FLOW §2.2 zone D) : en-tête (jour, badge NOUVEAU),
## onglets par catégorie, **date du jour** comparable, règles du jour
## (`RulebookEntry`) sélectionnables en Mode Inspection. Rétractable (Tab) :
## replié, il ne reste qu'une languette avec le compteur de nouveautés.
## M7 : seconde rangée « BULLETINS » (`DayDef.rulebook_tabs`) — Origines,
## Implants, Symboles subversifs, Sceaux (`RulebookReference`) et Avis de
## recherche (`WantedCardView`, sélectionnables comme un champ) ; les entrées du
## bulletin des symboles (`SymbolCardView`) le sont aussi (§4.9).
## Acte II : onglets Codes employeurs, Registre des cargos et Révocations
## (`RevokedCardView`, sélectionnables), ligne firmware NX, avis « visages
## seuls » du J20 ; texte de R23 formaté avec le quota du jour (`quota_max`).
## Acte III (ARCHITECTURE §7.3) : onglets Main courante (`LedgerCardView`,
## liste qui s'allonge, dernière entrée surlignée) et Convocations
## (`SummonsCardView`), sélectionnables ; colonne « RÉINTÉGRÉ·E LE » des
## Révocations ; règles retirées barrées un jour (`retired_entries`) ; R23
## « SUSPENDU » quand le quota est levé (`quota_suspended`).
## QA-032 : navigation sur **une seule rangée** défilante (catégories de règles
## puis « BULLETINS »), flèches `[` `]`, menu « n / N ▾ » de tous les onglets
## regroupés par section, et DATE DU JOUR en pied : la liste garde ≥ 60 % de
## la hauteur du panneau même à 16 onglets et au texte 1,5.
## M12 (lot C, ARCHITECTURE §11.2) : **règles mutables en cours de shift**
## (`apply_rules`, `rules_changed`) — règle ajoutée (badge NOUVEAU), retirée
## (barrée, motif), rétablie (puce « RÉTABLIE ») ; `focus_rule` ouvre l'onglet
## Règles sur la règle et la surligne (directive de Garde) ; lignes ambre
## d'**événement de station** en tête (`set_event_notes`, icône + texte) ;
## **listes nommées** (`set_named_list` : onglet « Cartes volées ») ; onglet
## Révocations intitulé selon la liste en vigueur (« Liste du Conseil »).
## M13 (lot C, I37) : onglet **Contrebande** (`ContrabandEntryView`,
## sélectionnables : objet du portique ↔ entrée) ; **note de marge**
## d'Okonkwo (AG-05, `set_margin_note`) au-dessus de la liste quand le Recueil
## annoté ouvre la bonne page (`open_page_for`).
class_name RulebookPanel
extends PanelContainer

signal item_picked(item: InspectableItem)
signal collapse_changed(collapsed: bool)

## Onglet « toutes les règles ».
const TAB_ALL: int = -1
## M7 : onglets de référence (identifiants négatifs, ordre `RulebookReference.ORDER`).
const TAB_REFERENCE_BASE: int = -10
const COLLAPSED_WIDTH: float = 48.0
## Règle du quota respiratoire (R23) : note « SUSPENDU » de l'Acte III.
const RULE_QUOTA: StringName = &"r_air_quota"

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
## Entrées sélectionnables du bulletin des symboles (onglet affiché, §4.9).
var symbol_cards: Array[SymbolCardView] = []
## Acte II : révocations du jour (`revocations_published`) et leurs cartes.
var revoked_entries: Array[RevokedEntry] = []
var revoked_cards: Array[RevokedCardView] = []
## Acte II : maximum du quota du jour (texte de R23 « %d entrées »).
var quota_max: int = 0
## Acte III : Main courante du shift (`ledger_changed`) et convocations du
## jour (`summons_published`), leurs cartes affichées.
var ledger_entries: Array[LedgerEntry] = []
var ledger_cards: Array[LedgerCardView] = []
var summons_entries: Array[SummonsEntry] = []
var summons_cards: Array[SummonsCardView] = []
## M13 : entrées de l'onglet Contrebande affichées.
var contraband_cards: Array[ContrabandEntryView] = []
## M13 (AG-05) : note manuscrite d'Okonkwo affichée (vide sinon).
var margin_note: String = ""
var _margin_note_box: PanelContainer = null
var _margin_note_label: Label = null
## Acte III (M1) : règles retirées ce jour (lignes barrées, en fin de liste).
var retired_entries: Array[RulebookEntry] = []
## Acte III : quota suspendu (climat, Enquête) — note sous R23.
var quota_suspended: bool = false
var reduce_motion: bool = false
## Identifiant de la dernière entrée de la Main courante (surlignée une fois).
var _last_ledger_id: StringName = &""
## M12 : listes nommées du shift (`stolen` → entrées), règles rétablies au
## dernier changement (puce « RÉTABLIE »), lignes d'événement en tête.
var named_lists: Dictionary[StringName, Array] = {}
var restored_ids: Array[StringName] = []
var event_notes: PackedStringArray = []
var _event_box: VBoxContainer = null
## Règle à surligner à sa prochaine apparition (`focus_rule` différé).
var _pending_focus: StringName = &""
## QA-061 : règle à amener à l'écran après la mise en page (dernière demande).
var _scroll_rule: StringName = &""
## Dernière règle surlignée par `focus_rule` et nombre de surlignages (tests, QA).
var last_focused_rule: StringName = &""
var focus_count: int = 0
var portrait_provider: Callable = Callable()
## Marques des cartes masquées par l'onglet courant (clé `FieldRef.key()`).
var _kept_marks: Dictionary[String, Array] = {}

var _content: VBoxContainer = null
var _day_label: Label = null
var _new_badge: PanelContainer = null
var _new_label: Label = null
## Rangée unique d'onglets (défile horizontalement) et séparateur « BULLETINS ».
var _tabs_scroll: ScrollContainer = null
var _tabs_row: HBoxContainer = null
var _ref_caption: Control = null
var _prev_button: Button = null
var _next_button: Button = null
## Menu de tous les onglets (« n / N ▾ ») : remplace le pied « ONGLET n / N ».
var _tabs_menu: MenuButton = null
var _reference_view: Control = null
var _tab_buttons: Array[Button] = []
var _tab_ids: Array[int] = []
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _collapsed_tab: VBoxContainer = null
var _collapsed_count: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_L, DS.SPACE_4))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", DS.SPACE_2)
	add_child(_content)
	_build_header()
	_build_events()
	_build_nav()
	_build_margin_note()
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


## M12 : lignes ambre des événements de station en cours (icône + texte).
func _build_events() -> void:
	_event_box = VBoxContainer.new()
	_event_box.name = "StationEvents"
	_event_box.add_theme_constant_override("separation", DS.SPACE_1)
	_event_box.visible = false
	_content.add_child(_event_box)


## M13 (AG-05) : note de marge d'Okonkwo (icône + guillemets, voix grise).
func _build_margin_note() -> void:
	_margin_note_box = PanelContainer.new()
	_margin_note_box.name = "MarginNote"
	_margin_note_box.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_ELEVATED, Palette.TEXT_SECONDARY))
	_margin_note_box.visible = false
	_content.add_child(_margin_note_box)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_margin_note_box.add_child(row)
	var icon: UiIcon = UiIcon.make(UiIcon.Kind.TOOL, Palette.TEXT_SECONDARY, DS.ICON_S)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column: VBoxContainer = ScreenBase.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(ScreenBase.label(UiText.t("rb_margin_note", "MARGE D'OKONKWO"), &"DocFieldLabel", Palette.TEXT_SECONDARY))
	_margin_note_label = ScreenBase.wrapped("", &"BodySmall", DS.TEXT_PRIMARY)
	_margin_note_label.name = "NoteText"
	column.add_child(_margin_note_label)


## M13 (AG-05) : affiche (ou retire, `text` vide) la note de marge.
func set_margin_note(text: String) -> void:
	margin_note = text
	if _margin_note_box == null:
		return
	_margin_note_label.text = text
	_margin_note_box.visible = not text.is_empty()


## Rangée de navigation (QA-032) : `[` · onglets défilants · `]` · menu · Tab.
func _build_nav() -> void:
	var nav: HBoxContainer = HBoxContainer.new()
	nav.name = "Nav"
	nav.add_theme_constant_override("separation", DS.SPACE_1)
	_content.add_child(nav)
	_prev_button = _keycap_button(&"rulebook_prev", UiText.t("rb_tab_prev", "Onglet précédent"))
	_prev_button.pressed.connect(cycle_tab.bind(-1))
	nav.add_child(_prev_button)
	_tabs_scroll = ScrollContainer.new()
	_tabs_scroll.name = "Tabs"
	_tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tabs_scroll.gui_input.connect(_on_tabs_input)
	_tabs_scroll.get_h_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_nav_hints())
	_tabs_scroll.resized.connect(_update_nav_hints.call_deferred)
	_tabs_scroll.resized.connect(_on_tabs_resized)
	nav.add_child(_tabs_scroll)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 0)
	_tabs_scroll.add_child(_tabs_row)
	_next_button = _keycap_button(&"rulebook_next", UiText.t("rb_tab_next", "Onglet suivant"))
	_next_button.pressed.connect(cycle_tab.bind(1))
	nav.add_child(_next_button)
	_tabs_menu = MenuButton.new()
	_tabs_menu.name = "TabsMenu"
	_tabs_menu.theme_type_variation = &"ButtonGhost"
	_tabs_menu.focus_mode = Control.FOCUS_NONE
	_tabs_menu.flat = true
	_tabs_menu.tooltip_text = UiText.t("rb_tabs_all", "Tous les onglets")
	_tabs_menu.about_to_popup.connect(_fill_tabs_menu)
	_tabs_menu.get_popup().id_pressed.connect(_on_tabs_menu_id)
	nav.add_child(_tabs_menu)
	# « Tab » (replier) en bout de rangée : l'en-tête tient au Steam Deck (QA-009).
	# Glyphe qui suit le périphérique (Tab / R au clavier, Vue à la manette, M11).
	nav.add_child(PromptGlyph.make(&"rulebook_toggle"))


## Bouton à l'allure d'une touche (`[`, `]` ; LB / RB à la manette, M11) :
## cliquable, glyphe qui suit le périphérique.
func _keycap_button(action: StringName, tip: String) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap: PromptGlyph = PromptGlyph.make(action)
	button.add_child(cap)
	var fit: Callable = func() -> void:
		button.custom_minimum_size = cap.get_combined_minimum_size()
	cap.minimum_size_changed.connect(fit)
	fit.call()
	return button


func _build_footer() -> void:
	# DATE DU JOUR en pied (QA-032) : toujours visible, sélectionnable.
	var today_card: PanelContainer = PanelContainer.new()
	today_card.name = "Today"
	var today_box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_ELEVATED, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	today_card.add_theme_stylebox_override(&"panel", today_box)
	_content.add_child(today_card)
	today_item = DocFieldView.new()
	today_item.setup_custom(FieldRef.today(), UiText.t("rb_today", "DATE DU JOUR"), "—")
	today_item.picked.connect(_on_item_picked)
	today_card.add_child(today_item)


func _build_collapsed_tab() -> void:
	_collapsed_tab = VBoxContainer.new()
	_collapsed_tab.visible = false
	_collapsed_tab.alignment = BoxContainer.ALIGNMENT_BEGIN
	_collapsed_tab.add_theme_constant_override("separation", DS.SPACE_3)
	add_child(_collapsed_tab)
	_collapsed_tab.add_child(PromptGlyph.make(&"rulebook_toggle"))
	var label: Label = Label.new()
	label.theme_type_variation = &"DocFieldLabel"
	label.text = "R\nU\nL\nE\nS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapsed_tab.add_child(label)
	_collapsed_count = Label.new()
	_collapsed_count.theme_type_variation = &"DocFieldLabel"
	_collapsed_count.add_theme_color_override(&"font_color", Palette.STATE_AMBER)
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
	revoked_entries.clear()
	ledger_entries.clear()
	summons_entries.clear()
	retired_entries.clear()
	named_lists.clear()
	restored_ids.clear()
	_pending_focus = &""
	_last_ledger_id = &""
	today = p_today
	day_number = p_day_number
	_day_label.text = UiText.tf("rb_day", [p_day_number], "JOUR %02d") if p_day_number > 0 \
			else UiText.t("rb_garde_day", "GARDE DE NUIT")
	today_item.clear_marks()
	_kept_marks.clear()
	today_item.set_value_text(UiText.date(p_today))
	_refresh_new_count()
	_build_tabs()
	_show_tab(TAB_ALL)


## Badge « n NOUVEAU(X) » de l'en-tête et languette repliée.
func _refresh_new_count() -> void:
	var new_count: int = 0
	for entry: RulebookEntry in entries:
		if entry.is_new:
			new_count += 1
	_new_badge.visible = new_count > 0
	_new_label.text = UiText.plural("rb_new_count", new_count, "%d NOUVEAU", "%d NOUVEAUX")
	_collapsed_count.text = "%d\nNEW" % new_count if new_count > 0 else ""


## M12 (B54) : Rulebook après un changement en cours de shift (`rules_changed` :
## `diff.rulebook`, `diff.retired_entries`) ; les listes du jour (avis,
## révocations, Main courante…) sont conservées. `p_restored` : règles
## rétablies (puce « RÉTABLIE ») ; `tabs` : onglets de référence du jour de
## shift (une directive de Garde en ouvre).
func apply_rules(p_entries: Array[RulebookEntry], p_retired: Array[RulebookEntry], p_restored: Array[StringName] = [],
		tabs: PackedStringArray = PackedStringArray()) -> void:
	entries = p_entries.duplicate()
	retired_entries = p_retired.duplicate()
	restored_ids = p_restored.duplicate()
	if not tabs.is_empty():
		reference_tabs = tabs.duplicate()
	_refresh_new_count()
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)
	if _pending_focus != &"":
		var rule_id: StringName = _pending_focus
		_pending_focus = &""
		focus_rule(rule_id)


## Ouvre l'onglet « Règles » sur `rule_id` et la surligne (directive de Garde,
## règle rétablie). `after_change` : le changement est encore en attente du
## passager suivant — la règle sera surlignée à l'arrivée de `rules_changed`
## (de même si elle n'est pas encore au Rulebook).
func focus_rule(rule_id: StringName, after_change: bool = false) -> bool:
	if collapsed:
		set_collapsed(false)
	if current_tab != TAB_ALL:
		_show_tab(TAB_ALL)
	var card: RuleCardView = get_rule_card(rule_id)
	if card == null or after_change:
		_pending_focus = rule_id
		return false
	scroll_to_rule(rule_id)
	card.highlight(reduce_motion)
	last_focused_rule = rule_id
	focus_count += 1
	return true


## QA-061 : amène la carte de `rule_id` à l'écran **après** la mise en page
## (frame suivante) et en la recherchant à ce moment-là : la liste a pu être
## reconstruite entre-temps (`apply_rules`, `_show_tab`) et la carte d'origine
## libérée — `ensure_control_visible` différé sur elle échouait (« Must be an
## ancestor of the control ») et la règle NOUVEAU restait hors de l'écran.
func scroll_to_rule(rule_id: StringName) -> void:
	_scroll_rule = rule_id
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if not tree.process_frame.is_connected(_scroll_to_pending_rule):
		tree.process_frame.connect(_scroll_to_pending_rule, CONNECT_ONE_SHOT)


func _scroll_to_pending_rule() -> void:
	var rule_id: StringName = _scroll_rule
	_scroll_rule = &""
	if rule_id == &"" or not is_inside_tree():
		return
	var card: RuleCardView = get_rule_card(rule_id)
	if card == null or not is_instance_valid(card) or card.is_queued_for_deletion() or not _scroll.is_ancestor_of(card):
		return
	_scroll.ensure_control_visible(card)


## M12 (B58) : lignes ambre des événements en cours, en tête du Rulebook
## (`sev_<id>_rb`, déjà formatées) ; vide = masquées.
func set_event_notes(lines: PackedStringArray) -> void:
	event_notes = lines.duplicate()
	for child: Node in _event_box.get_children():
		child.queue_free()
	for text: String in event_notes:
		var row: PanelContainer = PanelContainer.new()
		row.name = "EventNote"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(Palette.AMBER_12, Palette.STATE_AMBER, DS.BORDER_HAIRLINE,
				DS.CHAMFER_S, DS.SPACE_2))
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", DS.SPACE_2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		line.add_child(UiIcon.make(UiIcon.Kind.WARNING, Palette.STATE_AMBER, DS.ICON_S))
		var label: Label = ScreenBase.wrapped(text, &"DocFieldLabel", Palette.STATE_AMBER)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		_event_box.add_child(row)
	_event_box.visible = not event_notes.is_empty()


## M12 (B58) : liste nommée publiée (`rule_list_published` : `stolen`) ; vide =
## retirée (l'onglet se ferme).
func set_named_list(label: StringName, p_entries: Array[RevokedEntry]) -> void:
	if p_entries.is_empty():
		named_lists.erase(label)
	else:
		named_lists[label] = p_entries.duplicate()
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)


## Entrées d'une liste nommée (vide si absente).
func named_entries(label: StringName) -> Array[RevokedEntry]:
	var result: Array[RevokedEntry] = []
	for entry: Variant in named_lists.get(label, []):
		if entry is RevokedEntry:
			result.append(entry)
	return result


## Intitulé de l'onglet Révocations (« Liste du Conseil » si la règle en
## vigueur lit une liste titrée, M12 R40).
func revoked_tab_title() -> String:
	var ids: Array[StringName] = []
	for entry: RulebookEntry in entries:
		ids.append(entry.rule_id)
	var key: String = RulebookReference.revoked_title_key(ids)
	return UiText.t(key, RulebookReference.tab_title(RulebookReference.TAB_REVOKED)) if not key.is_empty() \
			else RulebookReference.tab_title(RulebookReference.TAB_REVOKED)


## M7 : avis de recherche du jour (`wanted_notices_published`).
func set_wanted(notices: Array[WantedNotice], provider: Callable = Callable()) -> void:
	wanted_notices = notices.duplicate()
	portrait_provider = provider
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)


## Acte II : révocations du jour (`revocations_published`).
func set_revoked(p_entries: Array[RevokedEntry]) -> void:
	revoked_entries = p_entries.duplicate()
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)


## Acte III (M1) : règles retirées du jour, affichées barrées dans « Règles ».
func set_retired(p_entries: Array[RulebookEntry]) -> void:
	retired_entries = p_entries.duplicate()
	refresh_cards()


## Acte III : Main courante du shift (`ledger_changed`) ; la nouvelle dernière
## entrée est surlignée si l'onglet est affiché.
func set_ledger(p_entries: Array[LedgerEntry]) -> void:
	var previous: int = ledger_entries.size()
	ledger_entries = p_entries.duplicate()
	var fresh: StringName = &""
	if ledger_entries.size() > previous:
		var last: LedgerEntry = ledger_entries[ledger_entries.size() - 1]
		fresh = last.id
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)
	if fresh != &"":
		# Surlignée maintenant si l'onglet est affiché, sinon à son ouverture.
		_last_ledger_id = fresh
		var card: LedgerCardView = get_ledger_card(fresh)
		if card != null:
			card.highlight(reduce_motion)
			_last_ledger_id = &""


## Acte III : convocations du jour (`summons_published`).
func set_summons(p_entries: Array[SummonsEntry]) -> void:
	summons_entries = p_entries.duplicate()
	var tab: int = current_tab
	_build_tabs()
	_show_tab(tab if _tab_ids.has(tab) else TAB_ALL)


## Reconstruit l'onglet courant (quota du jour connu après `day_started`).
func refresh_cards() -> void:
	_show_tab(current_tab if _tab_ids.has(current_tab) else TAB_ALL)


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
		if tab == RulebookReference.TAB_STOLEN:
			# M12 : ouvert par la publication de la liste (EV-07), pas par le jour.
			if not named_entries(&"stolen").is_empty():
				tabs.append(tab)
			continue
		if not reference_tabs.has(String(tab)):
			continue
		if tab == RulebookReference.TAB_WANTED and wanted_notices.is_empty():
			continue
		if tab == RulebookReference.TAB_REVOKED and revoked_entries.is_empty():
			continue
		if tab == RulebookReference.TAB_SUMMONS and summons_entries.is_empty():
			continue
		# La Main courante est ouverte même vide (« Aucun répondant admis ») :
		# elle se remplit pendant le shift.
		tabs.append(tab)
	return tabs


func _build_tabs() -> void:
	for button: Button in _tab_buttons:
		button.queue_free()
	_tab_buttons.clear()
	_tab_ids.clear()
	if _ref_caption != null:
		_ref_caption.queue_free()
		_ref_caption = null
	var group: ButtonGroup = ButtonGroup.new()
	var ids: Array[int] = [TAB_ALL]
	for entry: RulebookEntry in entries:
		if not ids.has(entry.category):
			ids.append(entry.category)
	for id: int in ids:
		var news: int = 0
		for entry: RulebookEntry in entries:
			if entry.is_new and (id == TAB_ALL or entry.category == id):
				news += 1
		var text: String = _tab_name(id)
		var suffix: String = ""
		var color: Color = Color.TRANSPARENT
		if news > 0 and id != TAB_ALL:
			suffix = " ·%d" % news
			color = Palette.STATE_AMBER
		_add_tab_button(id, text, color, group, suffix)
	var refs: Array[StringName] = visible_reference_tabs()
	if not refs.is_empty():
		# Séparateur « BULLETINS » dans la rangée : les onglets de référence
		# suivent les catégories de règles (QA-032).
		var caption: HBoxContainer = HBoxContainer.new()
		caption.name = "Bulletins"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_constant_override("separation", DS.SPACE_2)
		var bar: ColorRect = ColorRect.new()
		bar.color = Palette.LINE_SUBTLE
		bar.custom_minimum_size = Vector2(DS.BORDER_HAIRLINE, DS.SPACE_5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_child(bar)
		var ref_caption: Label = Label.new()
		ref_caption.theme_type_variation = &"DocFieldLabel"
		ref_caption.uppercase = true
		ref_caption.text = UiText.t("rb_bulletins", "BULLETINS")
		ref_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ref_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_child(ref_caption)
		_tabs_row.add_child(caption)
		_ref_caption = caption
	for tab: StringName in refs:
		var text: String = RulebookReference.tab_title(tab)
		var suffix: String = ""
		var color: Color = Color.TRANSPARENT
		if tab == RulebookReference.TAB_WANTED:
			suffix = " ·%d" % wanted_notices.size()
			color = Palette.STATE_RED
		elif tab == RulebookReference.TAB_REVOKED:
			text = revoked_tab_title()
			suffix = " ·%d" % revoked_entries.size()
			color = Palette.VOICE_COMMISSION
		elif tab == RulebookReference.TAB_STOLEN:
			suffix = " ·%d" % named_entries(&"stolen").size()
			color = Palette.STATE_RED
		elif tab == RulebookReference.TAB_LEDGER:
			suffix = " ·%d" % ledger_entries.size()
			color = Palette.STATE_GREEN if not ledger_entries.is_empty() else Palette.TEXT_SECONDARY
		elif tab == RulebookReference.TAB_SUMMONS:
			suffix = " ·%d" % summons_entries.size()
			color = Palette.STATE_AMBER
		elif RulebookReference.is_new(tab, day_number):
			suffix = " ·" + UiText.t("rb_tab_new", "NEW")
			color = Palette.STATE_AMBER
		var button: Button = _add_tab_button(reference_tab_id(tab), text, color, group, suffix)
		button.name = "Tab_%s" % tab
	_fit_tab_labels.call_deferred()


## `suffix` : compteur ou repère (« ·3 », « ·NOUV. ») gardé entier quand le
## titre doit être raccourci (QA-071, `_fit_tab_labels`).
func _add_tab_button(id: int, text: String, color: Color, group: ButtonGroup, suffix: String = "") -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ToggleTab"
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.text = text + suffix
	button.tooltip_text = text + suffix
	button.set_meta(&"tab_title", text)
	button.set_meta(&"tab_suffix", suffix)
	if color.a > 0.0:
		button.add_theme_color_override(&"font_color", color)
		button.set_meta(&"tab_color", color)
	button.pressed.connect(_show_tab.bind(id))
	button.pressed.connect(EventBus.rulebook_consulted.emit)
	_tabs_row.add_child(button)
	_tab_buttons.append(button)
	_tab_ids.append(id)
	return button


## Titre complet d'un onglet (menu « n / N ▾ », infobulle), même raccourci.
static func tab_full_text(button: Button) -> String:
	if button == null or not button.has_meta(&"tab_title"):
		return button.text if button != null else ""
	return str(button.get_meta(&"tab_title")) + str(button.get_meta(&"tab_suffix", ""))


## QA-071 : un onglet ne dépasse jamais la largeur de la rangée visible (Deck,
## texte 1,5 : « Contrebande ·NOUV. » était plus large qu'elle et coupé à
## gauche sous « [ »). Le titre est raccourci par une ellipse, le compteur ou
## le repère « NOUV. » restent entiers (jamais la couleur seule) ; le titre
## complet est en infobulle et dans le menu « n / N ▾ ». Rend vrai si un
## libellé a changé (la rangée se replace à l'image suivante).
func _fit_tab_labels() -> bool:
	if _tabs_scroll == null or not is_inside_tree():
		return false
	var width: float = _tabs_scroll.size.x
	if width <= 0.0:
		return false
	var changed: bool = false
	for button: Button in _tab_buttons:
		if not is_instance_valid(button) or not button.has_meta(&"tab_title"):
			continue
		var title: String = button.get_meta(&"tab_title")
		var suffix: String = button.get_meta(&"tab_suffix", "")
		var text: String = title + suffix
		button.text = text
		var cut: int = title.length()
		while button.get_combined_minimum_size().x > width and cut > 1:
			cut -= 1
			text = title.left(cut).strip_edges() + "…" + suffix
			button.text = text
		changed = changed or text != str(button.get_meta(&"tab_shown", title + suffix))
		button.set_meta(&"tab_shown", text)
	return changed


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _tabs_scroll != null:
		_fit_tab_labels.call_deferred()


## Molette sur la rangée d'onglets : défilement horizontal.
func _on_tabs_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	var step: float = 0.0
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			step = -1.0
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			step = 1.0
	if step == 0.0:
		return
	_tabs_scroll.scroll_horizontal += roundi(step * DS.SPACE_16)
	_tabs_scroll.accept_event()


## Rangée redimensionnée (le compteur « n / N ▾ » et la liste changent sa
## largeur) : libellés ajustés, onglet courant replacé à l'image suivante.
func _on_tabs_resized() -> void:
	_fit_tab_labels()
	if is_inside_tree() and not get_tree().process_frame.is_connected(_reveal_current_tab):
		get_tree().process_frame.connect(_reveal_current_tab, CONNECT_ONE_SHOT)


## Onglet courant ramené dans la rangée visible.
func _reveal_current_tab() -> void:
	var index: int = _tab_ids.find(current_tab)
	if index < 0 or not is_inside_tree() or _tabs_scroll == null:
		return
	if _fit_tab_labels():
		# Libellé raccourci : positions recalculées à l'image suivante.
		if not get_tree().process_frame.is_connected(_reveal_current_tab):
			get_tree().process_frame.connect(_reveal_current_tab, CONNECT_ONE_SHOT)
		return
	var button: Button = _tab_buttons[index]
	if not is_instance_valid(button):
		return
	# Onglet courant entier ; le bord gauche de la rangée tombe sur le début
	# d'un onglet (jamais un libellé coupé à gauche).
	var width: float = _tabs_scroll.size.x
	var scroll: float = float(_tabs_scroll.scroll_horizontal)
	var left: float = button.position.x
	var right: float = left + button.size.x
	if left < scroll:
		scroll = left
	elif right > scroll + width:
		scroll = right - width
		for other: Button in _tab_buttons:
			if is_instance_valid(other) and other.position.x >= scroll - 0.5:
				scroll = minf(other.position.x, left)
				break
	if _ref_caption != null and button.name.begins_with("Tab_") and _tab_buttons.find(button) == _first_reference_index() \
			and _ref_caption.position.x + width >= right:
		# Premier bulletin : la légende « BULLETINS » reste visible.
		scroll = minf(scroll, _ref_caption.position.x)
	# Jamais un début de libellé coupé à gauche (QA-071).
	scroll = minf(scroll, left)
	_tabs_scroll.scroll_horizontal = roundi(scroll)
	_update_nav_hints()


func _first_reference_index() -> int:
	for i: int in _tab_ids.size():
		if _tab_ids[i] <= TAB_REFERENCE_BASE:
			return i
	return -1


## Flèches `[` `]` : ambre si un onglet signalé (couleur d'état : nouveautés,
## avis, convocations…) est caché de ce côté de la rangée.
func _update_nav_hints() -> void:
	if _tabs_scroll == null or _prev_button == null:
		return
	var view: Rect2 = _tabs_scroll.get_global_rect().grow(1.0)
	var left: bool = false
	var right: bool = false
	for button: Button in _tab_buttons:
		if not is_instance_valid(button) or not button.has_meta(&"tab_color"):
			continue
		var color: Color = button.get_meta(&"tab_color")
		if color == Palette.TEXT_SECONDARY:
			continue
		# Caché si plus de la moitié de l'onglet est hors de la rangée.
		var center: float = button.get_global_rect().get_center().x
		left = left or center < view.position.x
		right = right or center > view.end.x
	_prev_button.modulate = Palette.STATE_AMBER if left else Color.WHITE
	_next_button.modulate = Palette.STATE_AMBER if right else Color.WHITE


## Menu « n / N ▾ » : tous les onglets, par section, l'onglet courant coché.
func _fill_tabs_menu() -> void:
	var popup: PopupMenu = _tabs_menu.get_popup()
	popup.clear()
	var in_refs: bool = false
	popup.add_separator(UiText.t("rb_tab_all", "Règles").to_upper())
	for i: int in _tab_ids.size():
		var id: int = _tab_ids[i]
		if id <= TAB_REFERENCE_BASE and not in_refs:
			in_refs = true
			popup.add_separator(UiText.t("rb_bulletins", "BULLETINS"))
		popup.add_radio_check_item(tab_full_text(_tab_buttons[i]), i)
		var index: int = popup.get_item_index(i)
		popup.set_item_checked(index, id == current_tab)


func _on_tabs_menu_id(index: int) -> void:
	if index >= 0 and index < _tab_ids.size():
		_show_tab(_tab_ids[index])


func _update_page(id: int) -> void:
	var index: int = _tab_ids.find(id)
	_tabs_menu.text = UiText.tf("rb_tabs_menu", [index + 1, _tab_ids.size()], "%d / %d ▾")
	_tabs_menu.tooltip_text = UiText.tf("rb_page", [index + 1, _tab_ids.size()], "ONGLET %d / %d")
	# Après le placement des onglets recréés (une image).
	if is_inside_tree() and not get_tree().process_frame.is_connected(_reveal_current_tab):
		get_tree().process_frame.connect(_reveal_current_tab, CONNECT_ONE_SHOT)


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
	# Conserver les marques (sélection, discordances) des cartes recréées,
	# y compris au retour d'un détour par un autre onglet.
	var marks: Dictionary[String, Array] = _kept_marks
	for card: InspectableItem in _list_items():
		if card.selected or card.is_flagged():
			marks[card.ref.key()] = [card.selected, card.flag_numbers.duplicate()]
		else:
			marks.erase(card.ref.key())
		card.queue_free()
	cards.clear()
	wanted_cards.clear()
	symbol_cards.clear()
	revoked_cards.clear()
	ledger_cards.clear()
	summons_cards.clear()
	contraband_cards.clear()
	_scroll.tooltip_text = ""
	if _reference_view != null:
		_reference_view.queue_free()
		_reference_view = null
	if id <= TAB_REFERENCE_BASE:
		_show_reference(reference_of(id), marks)
		_update_page(id)
		return
	for i: int in entries.size():
		var entry: RulebookEntry = entries[i]
		if id != TAB_ALL and entry.category != id:
			continue
		var card: RuleCardView = RuleCardView.new()
		var note: String = ""
		var note_icon: int = -1
		if quota_suspended and entry.rule_id == RULE_QUOTA:
			note = UiText.t("rb_suspended_quota", "SUSPENDU PENDANT L'ENQUÊTE")
		elif restored_ids.has(entry.rule_id):
			# M12 : règle rétablie (rotation de la Garde, fin d'événement).
			note = UiText.t("rb_restored", "RÉTABLIE")
			note_icon = UiIcon.Kind.CHECK
		card.setup(entry, i + 1, quota_max, note, note_icon)
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
	# Acte III (M1) : règles retirées, barrées en fin de liste (un jour).
	for entry: RulebookEntry in retired_entries:
		if id != TAB_ALL and entry.category != id:
			continue
		var retired: RuleCardView = RuleCardView.new()
		retired.name = "Retired_%s" % entry.rule_id
		retired.setup(entry, 0, quota_max)
		_list.add_child(retired)
		retired.set_inspection_active(inspection_active)
		cards.append(retired)
	_update_page(id)


func _list_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	for card: RuleCardView in cards:
		items.append(card)
	for card: WantedCardView in wanted_cards:
		items.append(card)
	for card: SymbolCardView in symbol_cards:
		items.append(card)
	for card: RevokedCardView in revoked_cards:
		items.append(card)
	for card: LedgerCardView in ledger_cards:
		items.append(card)
	for card: SummonsCardView in summons_cards:
		items.append(card)
	for card: ContrabandEntryView in contraband_cards:
		items.append(card)
	return items


## Contenu d'un onglet de référence ; avis de recherche = cartes sélectionnables.
func _show_reference(tab: StringName, marks: Dictionary[String, Array]) -> void:
	if tab == RulebookReference.TAB_REVOKED:
		_show_revoked(marks)
		return
	if tab == RulebookReference.TAB_STOLEN:
		_show_revoked(marks, named_entries(&"stolen"), UiText.t("rb_stolen_intro",
				"Bulletin du Bureau · cartes déclarées volées. Mode Inspection : comparez au N° ID de la carte. Porteur : refus."))
		return
	if tab == RulebookReference.TAB_LEDGER:
		_show_ledger(marks)
		return
	if tab == RulebookReference.TAB_SUMMONS:
		_show_summons(marks)
		return
	if tab != RulebookReference.TAB_WANTED:
		var rule_ids: Array[StringName] = []
		for entry: RulebookEntry in entries:
			rule_ids.append(entry.rule_id)
		_reference_view = RulebookReference.build(tab, rule_ids)
		_reference_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(_reference_view)
		for node: Node in _reference_view.find_children("Symbol_*", "", true, false):
			var symbol: SymbolCardView = node as SymbolCardView
			if symbol == null:
				continue
			symbol.picked.connect(_on_item_picked)
			symbol.set_inspection_active(inspection_active)
			_restore_marks(symbol, marks)
			symbol_cards.append(symbol)
		for node: Node in _reference_view.find_children("Contraband_*", "", true, false):
			var entry: ContrabandEntryView = node as ContrabandEntryView
			if entry == null:
				continue
			entry.picked.connect(_on_item_picked)
			entry.set_inspection_active(inspection_active)
			_restore_marks(entry, marks)
			contraband_cards.append(entry)
		return
	# Consigne en infobulle : la place va aux avis (portrait lisible).
	_scroll.tooltip_text = UiText.t("rb_wanted_intro", "Par le nom ou par le visage : mise en attente.")
	if faces_only():
		# J20 : avis sans nom — la comparaison passe par le visage seul.
		var banner: Label = ScreenBase.wrapped(UiText.t("wanted_faces_only", "AVIS DU JOUR · VISAGES SEULS"), &"DocFieldLabel",
				Palette.STATE_RED)
		banner.name = "FacesOnly"
		_reference_view = banner
		_list.add_child(banner)
	for i: int in wanted_notices.size():
		var card: WantedCardView = WantedCardView.new()
		card.name = "Wanted_%s" % wanted_notices[i].id
		card.setup(wanted_notices[i], i + 1, portrait_provider)
		card.picked.connect(_on_item_picked)
		_list.add_child(card)
		card.set_inspection_active(inspection_active)
		_restore_marks(card, marks)
		wanted_cards.append(card)


## Vrai si tous les avis du jour sont « visages seuls » (J20, sans nom).
func faces_only() -> bool:
	if wanted_notices.is_empty():
		return false
	for notice: WantedNotice in wanted_notices:
		if not notice.full_name().strip_edges().is_empty():
			return false
	return true


## Onglet Révocations : une carte sélectionnable par N° ID révoqué. M12 :
## même présentation pour une liste nommée (`list`, « Cartes volées »).
func _show_revoked(marks: Dictionary[String, Array], list: Array[RevokedEntry] = [], intro_text: String = "") -> void:
	var shown: Array[RevokedEntry] = revoked_entries if intro_text.is_empty() else list
	var council: bool = false
	if intro_text.is_empty():
		intro_text = UiText.t("rb_revoked_intro",
				"Commission de Rééquilibrage · N° ID révoqués. Mode Inspection : comparez au N° ID de la carte.")
		if revoked_tab_title() != RulebookReference.tab_title(RulebookReference.TAB_REVOKED):
			council = true
			intro_text = UiText.t("rb_council_intro",
					"Conseil de l'air · N° ID inscrits. Réintégré·es par le Conseil (date en colonne) : admis·es.")
	var intro: Label = ScreenBase.wrapped(intro_text, &"BodySmall")
	intro.name = "RevokedIntro"
	_reference_view = intro
	_list.add_child(intro)
	for i: int in shown.size():
		var card: RevokedCardView = RevokedCardView.new()
		card.name = "Revoked_%s" % shown[i].id
		card.setup(shown[i], i + 1, today, council)
		card.picked.connect(_on_item_picked)
		_list.add_child(card)
		card.set_inspection_active(inspection_active)
		_restore_marks(card, marks)
		revoked_cards.append(card)


## Acte III : Main courante — une carte sélectionnable par répondant admis
## aujourd'hui (consigne en tête, « Aucun répondant admis » tant qu'elle est vide).
func _show_ledger(marks: Dictionary[String, Array]) -> void:
	var head: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	head.name = "LedgerHead"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ScreenBase.wrapped(UiText.t("rb_ledger_hint", "Répondants admissibles admis aujourd'hui à ce guichet."), &"BodySmall"))
	if ledger_entries.is_empty():
		var empty: Label = ScreenBase.wrapped(UiText.t("rb_ledger_empty", "Aucun répondant admis pour l'instant."), &"BodySmall",
				Palette.TEXT_SECONDARY)
		empty.name = "LedgerEmpty"
		head.add_child(empty)
	_reference_view = head
	_list.add_child(head)
	for i: int in ledger_entries.size():
		var card: LedgerCardView = LedgerCardView.new()
		card.name = "Ledger_%s" % ledger_entries[i].id
		card.setup(ledger_entries[i], i + 1)
		card.picked.connect(_on_item_picked)
		_list.add_child(card)
		card.set_inspection_active(inspection_active)
		_restore_marks(card, marks)
		ledger_cards.append(card)
		if card.entry.id == _last_ledger_id:
			card.highlight(reduce_motion)
			_last_ledger_id = &""


## Acte III : Convocations de l'Enquête — une carte sélectionnable par N° ENQ.
func _show_summons(marks: Dictionary[String, Array]) -> void:
	var intro: Label = ScreenBase.wrapped(UiText.t("rb_summons_intro",
			"Enquête de Continuité · convocations du jour. Mode Inspection : comparez au champ Convocation du permis."), &"BodySmall")
	intro.name = "SummonsIntro"
	_reference_view = intro
	_list.add_child(intro)
	for i: int in summons_entries.size():
		var card: SummonsCardView = SummonsCardView.new()
		card.name = "Summons_%s" % summons_entries[i].id
		card.setup(summons_entries[i], i + 1)
		card.picked.connect(_on_item_picked)
		_list.add_child(card)
		card.set_inspection_active(inspection_active)
		_restore_marks(card, marks)
		summons_cards.append(card)


## Carte de la Main courante affichée (null si l'onglet n'est pas ouvert).
func get_ledger_card(entry_id: StringName) -> LedgerCardView:
	for card: LedgerCardView in ledger_cards:
		if card.entry.id == entry_id:
			return card
	return null


## Carte de convocation affichée (null si l'onglet n'est pas ouvert).
func get_summons_card(entry_id: StringName) -> SummonsCardView:
	for card: SummonsCardView in summons_cards:
		if card.entry.id == entry_id:
			return card
	return null


## Carte de règle affichée pour `rule_id` (retirée comprise), null sinon.
func get_rule_card(rule_id: StringName) -> RuleCardView:
	for card: RuleCardView in cards:
		if card.entry.rule_id == rule_id:
			return card
	return null


## Carte de révocation affichée (null si l'onglet n'est pas ouvert).
func get_revoked_card(entry_id: StringName) -> RevokedCardView:
	for card: RevokedCardView in revoked_cards:
		if card.entry.id == entry_id:
			return card
	return null


## Rétablit sélection et discordances d'une carte recréée (changement d'onglet).
static func _restore_marks(card: InspectableItem, marks: Dictionary[String, Array]) -> void:
	var key: String = card.ref.key()
	if not marks.has(key):
		return
	var mark: Array = marks[key]
	var was_selected: bool = mark[0]
	card.set_selected(was_selected)
	for n: int in mark[1]:
		card.add_flag(n)


## Onglet précédent / suivant ([ / ], LB / RB).
## Zone défilante du contenu (défilement au stick droit, M11).
func get_scroll() -> ScrollContainer:
	return _scroll


func cycle_tab(step: int) -> void:
	if _tab_ids.is_empty():
		return
	var index: int = posmod(_tab_ids.find(current_tab) + step, _tab_ids.size())
	_show_tab(_tab_ids[index])
	EventBus.rulebook_consulted.emit()


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
	if reveal and ref.is_revoked():
		var revoked_id: int = reference_tab_id(RulebookReference.TAB_REVOKED)
		for entry: RevokedEntry in named_entries(&"stolen"):
			if entry.id == ref.field_id:
				revoked_id = reference_tab_id(RulebookReference.TAB_STOLEN)
		if _tab_ids.has(revoked_id) and current_tab != revoked_id:
			_show_tab(revoked_id)
			return find_item(ref, false)
		return null
	if reveal and (ref.is_ledger() or ref.is_summons()):
		var tab_id: int = reference_tab_id(RulebookReference.TAB_LEDGER if ref.is_ledger() else RulebookReference.TAB_SUMMONS)
		if _tab_ids.has(tab_id) and current_tab != tab_id:
			_show_tab(tab_id)
			return find_item(ref, false)
		return null
	if reveal and ref.is_contraband_entry():
		var contraband_id: int = reference_tab_id(RulebookReference.TAB_CONTRABAND)
		if _tab_ids.has(contraband_id) and current_tab != contraband_id:
			_show_tab(contraband_id)
			return find_item(ref, false)
		return null
	if reveal and ref.is_symbol():
		var symbols_id: int = reference_tab_id(RulebookReference.TAB_SYMBOLS)
		if _tab_ids.has(symbols_id) and current_tab != symbols_id:
			_show_tab(symbols_id)
			return find_item(ref, false)
		return null
	if reveal and current_tab != TAB_ALL:
		_show_tab(TAB_ALL)
		return find_item(ref, false)
	return null


## Fait défiler la liste jusqu'à la carte de `ref` (cible choisie en Mode
## Inspection dans un onglet défilant : Main courante, Convocations…).
func scroll_to(ref: FieldRef) -> void:
	var item: InspectableItem = find_item(ref, true)
	if item != null and item != today_item and is_inside_tree():
		_scroll.ensure_control_visible.call_deferred(item)


## Affiche un onglet de référence (`origins`, `wanted`…) ; faux s'il est fermé.
func show_reference_tab(tab: StringName) -> bool:
	var id: int = reference_tab_id(tab)
	if not _tab_ids.has(id):
		return false
	_show_tab(id)
	return true


## M13 : entrée de l'onglet Contrebande affichée (null si l'onglet n'est pas ouvert).
func get_contraband_card(category: StringName) -> ContrabandEntryView:
	for card: ContrabandEntryView in contraband_cards:
		if card.category == category:
			return card
	return null


## Entrée du bulletin des symboles affichée (null si l'onglet n'est pas ouvert).
func get_symbol_card(symbol_id: StringName) -> SymbolCardView:
	for card: SymbolCardView in symbol_cards:
		if card.symbol_id == symbol_id:
			return card
	return null


## Carte d'avis de recherche affichée (null si l'onglet n'est pas ouvert).
func get_wanted_card(notice_id: StringName) -> WantedCardView:
	for card: WantedCardView in wanted_cards:
		if card.notice.id == notice_id:
			return card
	return null


## Fin de cas : efface sélection et discordances, cartes masquées comprises.
func clear_item_marks() -> void:
	_kept_marks.clear()
	for item: InspectableItem in get_items():
		item.clear_marks()


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
	if not value:
		EventBus.rulebook_consulted.emit()


func _on_item_picked(item: InspectableItem) -> void:
	item_picked.emit(item)
	EventBus.rulebook_consulted.emit()


func _draw() -> void:
	if inspection_active and not collapsed:
		Workbench.draw_corner_brackets(self, Rect2(Vector2.ZERO, size).grow(DS.SPACE_1), DS.ACCENT_CYAN)
