## Journal de dialogue épinglable (M13 lot C, I35 ; M13 §1.7, §2.2 point 7 ;
## ARCHITECTURE §12.2) : les répliques du passager **du cas courant** (au plus
## `DS.JOURNAL_MAX_LINES`, défilables), dans la bulle de la vitre.
##
## - Réplique composée (cadre `line_stmt_frame_*`) : découpée par
##   `Statement.segments()`, chaque emplacement devient une **puce**
##   (`StatementChipView`, sélectionnable en Mode Inspection) ; la valeur
##   barrée d'une auto-correction reste barrée.
## - Réplique scénarisée en prose : texte tel quel, puis une **rangée de puces à
##   part** (« DÉCLARÉ : … ») pour les déclarations du cas (M13 §1.12).
## - Didascalies (indices IV-1 → IV-5) : lignes entre crochets, lisibles même
##   sous-titres coupés (D-107) — le journal est une pièce du dossier.
## - Une réplique dont une puce est épinglée sur une DISCORDANCE est **figée**
##   (repère FIGÉE, jamais retirée par le défilement) jusqu'au verdict.
## - Onglet **FOUILLE** : objets révélés par le portique (`SearchItemView`),
##   gardés jusqu'au verdict (comparables quand la silhouette est refermée).
## Manette : les puces sont des nœuds du graphe de focus en Mode Inspection
## (croix ↑ depuis le haut du plan de travail, ↓ pour y revenir, Ⓐ choisit) ;
## le défilement suit le focus.
class_name DialogueJournal
extends VBoxContainer

## Clic / Ⓐ sur une puce ou un objet de l'onglet FOUILLE (Mode Inspection).
signal item_picked(item: InspectableItem)
## Onglet affiché (`TAB_DIALOGUE` / `TAB_SEARCH`).
signal tab_changed(tab: StringName)

const TAB_DIALOGUE: StringName = &"dialogue"
const TAB_SEARCH: StringName = &"search"
## Style du texte des répliques (même taille pour la phrase et ses puces).
const LINE_VARIATION: StringName = &"BodyLabel"

## Entrées : {node, frozen, chips: Array[StatementChipView], words: Array[Label], tag}.
var entries: Array[Dictionary] = []
var inspection_active: bool = false
var current_tab: StringName = TAB_DIALOGUE
## Hauteur visible maximale (px @1080p) ; le contenu défile au-delà.
var max_height: float = DS.JOURNAL_VIEW_H
var search_views: Array[SearchItemView] = []
## Masqué le temps du menu d'interrogatoire (la bulle reste dans la bande B).
var suppressed: bool = false

var _tabs: HBoxContainer = null
var _dialogue_tab: Button = null
var _search_tab: Button = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _search_list: VBoxContainer = null
var _search_items: Array[SearchItem] = []
var _search_zones: Array[StringName] = []


func _ready() -> void:
	add_theme_constant_override("separation", DS.SPACE_1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs = ScreenBase.hbox(DS.SPACE_2)
	_tabs.name = "Tabs"
	_tabs.visible = false
	add_child(_tabs)
	var group: ButtonGroup = ButtonGroup.new()
	_dialogue_tab = _tab_button(UiText.t("jr_tab_dialogue", "DIALOGUE"), group, TAB_DIALOGUE)
	_search_tab = _tab_button(UiText.t("jr_tab_search", "FOUILLE"), group, TAB_SEARCH)
	_dialogue_tab.button_pressed = true
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	var stack: VBoxContainer = ScreenBase.vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(stack)
	_list = ScreenBase.vbox(DS.SPACE_2)
	_list.name = "Lines"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_list)
	_search_list = ScreenBase.vbox(DS.SPACE_1)
	_search_list.name = "SearchItems"
	_search_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_list.visible = false
	stack.add_child(_search_list)
	stack.minimum_size_changed.connect(_fit_height)
	_fit_height()


func _tab_button(text: String, group: ButtonGroup, tab: StringName) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ToggleTab"
	button.toggle_mode = true
	button.button_group = group
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = DS.HIT_TARGET_MIN - DS.SPACE_2
	button.pressed.connect(show_tab.bind(tab))
	_tabs.add_child(button)
	return button


## Zone défilante (stick droit / Pg↑ Pg↓ quand le focus y est).
func get_scroll() -> ScrollContainer:
	return _scroll


func is_empty() -> bool:
	return entries.is_empty() and _search_items.is_empty()


## Oublie le cas (nouveau passager, guichet vide).
func clear() -> void:
	for entry: Dictionary in entries:
		var node: Control = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
	entries.clear()
	_clear_search()
	_search_zones.clear()
	_tabs.visible = false
	show_tab(TAB_DIALOGUE)
	_fit_height()


# ---------------------------------------------------------------------------
# Répliques
# ---------------------------------------------------------------------------

## Réplique simple (bark, réaction, réponse sans déclaration). `caption` :
## question qui l'a appelée (petite ligne au-dessus) ; `tag` : didascalie.
func add_line(text: String, caption: String = "", tag: bool = false) -> Dictionary:
	if text.strip_edges().is_empty():
		return {}
	var box: VBoxContainer = _entry_box(caption)
	var flow: HFlowContainer = _flow()
	box.add_child(flow)
	var words: Array[Label] = _add_words(flow, text)
	return _push({"node": box, "frozen": false, "chips": [] as Array[StatementChipView], "words": words, "tag": tag})


## Réplique composée : `frame_text` (cadre traduit, emplacements `{motif}`…)
## et les déclarations du cas ; une puce par emplacement renseigné.
func add_statement_line(frame_text: String, statements: Array[Statement], caption: String = "") -> Dictionary:
	var box: VBoxContainer = _entry_box(caption)
	var flow: HFlowContainer = _flow()
	box.add_child(flow)
	var words: Array[Label] = []
	var chips: Array[StatementChipView] = []
	for segment: Dictionary in Statement.segments(frame_text):
		if segment.has("text"):
			words.append_array(_add_words(flow, ComparisonUI.passenger_text(str(segment["text"]))))
			continue
		var statement: Statement = Statement.find_in(statements, StringName(str(segment["statement"])))
		if statement == null:
			continue
		var struck: bool = segment["struck"]
		if struck and statement.struck_text(func(key: String) -> String: return UiText.t(key, key)).is_empty():
			continue
		chips.append(_add_chip(flow, statement, struck))
	return _push({"node": box, "frozen": false, "chips": chips, "words": words, "tag": false})


## Réplique scénarisée en prose (non épinglable, D-154) suivie d'une rangée de
## puces à part pour les déclarations du cas (`statements` non vide).
func add_scripted_line(text: String, statements: Array[Statement], caption: String = "") -> Dictionary:
	var entry: Dictionary = add_line(text, caption)
	if entry.is_empty():
		return entry
	attach_chip_row(entry, statements)
	return entry


## Ajoute à une entrée existante la rangée « DÉCLARÉ : » (puces à part).
func attach_chip_row(entry: Dictionary, statements: Array[Statement]) -> void:
	if entry.is_empty() or statements.is_empty():
		return
	var box: VBoxContainer = entry["node"]
	var row: HFlowContainer = _flow()
	row.name = "ChipRow"
	box.add_child(row)
	row.add_theme_constant_override("h_separation", DS.SPACE_2)
	var caption: Label = ScreenBase.label(UiText.t("jr_declared", "DÉCLARÉ :"), &"DocFieldLabel", Palette.TEXT_SECONDARY)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var chips: Array[StatementChipView] = entry["chips"]
	for statement: Statement in statements:
		if statement == null:
			continue
		if statement.is_corrected():
			chips.append(_add_chip(row, statement, true))
		chips.append(_add_chip(row, statement, false))
	_restyle()


## Dernière entrée (vide s'il n'y en a pas).
func last_entry() -> Dictionary:
	return entries.back() if not entries.is_empty() else {}


## Remplace la dernière entrée (réponse affichée en texte brut, puis reçue en
## puces par `statement_given`).
func replace_last(entry: Dictionary) -> void:
	if entries.size() < 2 or entry.is_empty():
		return
	var old: Dictionary = entries[entries.size() - 2]
	if old.get("frozen", false):
		return
	entries.remove_at(entries.size() - 2)
	var node: Control = old["node"]
	if is_instance_valid(node):
		node.queue_free()
	_restyle()


func _entry_box(caption: String) -> VBoxContainer:
	var box: VBoxContainer = ScreenBase.vbox(0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not caption.is_empty():
		var head: Label = ScreenBase.label(caption, &"CaptionLabel", Palette.TEXT_SECONDARY)
		head.name = "Caption"
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(head)
	return box


func _flow() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 0)
	flow.add_theme_constant_override("v_separation", 0)
	return flow


## Un `Label` par mot, espace compris (le flux replie la phrase autour des
## puces ; une ponctuation collée à une puce le reste : « jours, » et non
## « jours , »).
func _add_words(flow: HFlowContainer, text: String) -> Array[Label]:
	var labels: Array[Label] = []
	if text.begins_with(" ") and flow.get_child_count() > 0:
		labels.append(_word(flow, " "))
	var words: PackedStringArray = text.split(" ", false)
	for i: int in words.size():
		var trailing: bool = i < words.size() - 1 or text.ends_with(" ")
		labels.append(_word(flow, words[i] + (" " if trailing else "")))
	return labels


func _word(flow: HFlowContainer, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = LINE_VARIATION
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text = text
	flow.add_child(label)
	return label


func _add_chip(parent: Control, statement: Statement, struck: bool) -> StatementChipView:
	var chip: StatementChipView = StatementChipView.new()
	chip.setup(statement, struck, LINE_VARIATION)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(chip)
	chip.set_inspection_active(inspection_active)
	chip.picked.connect(func(item: InspectableItem) -> void: item_picked.emit(item))
	return chip


func _push(entry: Dictionary) -> Dictionary:
	_list.add_child(entry["node"])
	entries.append(entry)
	# Au plus `JOURNAL_MAX_LINES` répliques : la plus ancienne non figée part.
	while entries.size() > DS.JOURNAL_MAX_LINES:
		var index: int = -1
		for i: int in entries.size():
			if not entries[i].get("frozen", false):
				index = i
				break
		if index < 0:
			break
		var old: Control = entries[index]["node"]
		entries.remove_at(index)
		if is_instance_valid(old):
			old.queue_free()
	_restyle()
	if current_tab == TAB_DIALOGUE:
		_scroll_to_end.call_deferred()
	if is_inside_tree() and not get_tree().process_frame.is_connected(_refit_parent):
		get_tree().process_frame.connect(_refit_parent, CONNECT_ONE_SHOT)
	return entry


## La dernière réplique en texte principal, les précédentes en secondaire ; les
## puces gardent leur couleur (ce sont des valeurs). Repère des répliques figées.
func _restyle() -> void:
	for i: int in entries.size():
		var entry: Dictionary = entries[i]
		var latest: bool = i == entries.size() - 1
		var tag: bool = entry.get("tag", false)
		for label: Label in entry["words"]:
			if is_instance_valid(label):
				label.add_theme_color_override(&"font_color",
						Palette.TEXT_SECONDARY if tag or not latest else DS.TEXT_PRIMARY)
		var box: VBoxContainer = entry["node"]
		if not is_instance_valid(box):
			continue
		var pin: Node = box.get_node_or_null("Frozen")
		if entry.get("frozen", false) and pin == null:
			var chip: PanelContainer = ScreenBase.chip(UiText.t("jr_frozen", "FIGÉE · DISCORDANCE"), UiIcon.Kind.DISCORDANCE,
					Palette.ACCENT_MAGENTA)
			chip.name = "Frozen"
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			box.add_child(chip)
			box.move_child(chip, 0)


func _scroll_to_end() -> void:
	if not is_inside_tree() or _scroll == null:
		return
	# Une image plus tard (mise en page faite) ; jamais rappelé sur un journal libéré.
	if not get_tree().process_frame.is_connected(_apply_scroll_end):
		get_tree().process_frame.connect(_apply_scroll_end, CONNECT_ONE_SHOT)


func _apply_scroll_end() -> void:
	if is_instance_valid(_scroll) and _scroll.is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _fit_height() -> void:
	if _scroll == null:
		return
	var content: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y if _scroll.get_child_count() > 0 else 0.0
	_scroll.custom_minimum_size.y = minf(content, max_height)
	visible = not is_empty() and not suppressed
	if current_tab == TAB_DIALOGUE and content > max_height:
		_scroll_to_end()


func set_max_height(value: float) -> void:
	max_height = maxf(value, DS.HIT_TARGET_MIN * 2.0)
	_fit_height()
	if is_inside_tree() and not get_tree().process_frame.is_connected(_refit_parent):
		get_tree().process_frame.connect(_refit_parent, CONNECT_ONE_SHOT)


## Nouvelle réplique : la bulle vérifie qu'elle tient toujours dans la bande B.
func _refit_parent() -> void:
	var panel: PassengerPanel = null
	var node: Node = get_parent()
	while node != null and panel == null:
		panel = node as PassengerPanel
		node = node.get_parent()
	if panel != null:
		panel._fit_to_band()


# ---------------------------------------------------------------------------
# Puces (Mode Inspection)
# ---------------------------------------------------------------------------

func chips() -> Array[StatementChipView]:
	var result: Array[StatementChipView] = []
	for entry: Dictionary in entries:
		for chip: StatementChipView in entry["chips"]:
			if is_instance_valid(chip):
				result.append(chip)
	return result


## Puce de `ref` la plus récente (non barrée), null sinon.
func find_chip(ref: FieldRef) -> StatementChipView:
	var found: StatementChipView = null
	for chip: StatementChipView in chips():
		if not chip.struck and chip.ref.equals(ref):
			found = chip
	return found


## Fige la réplique qui porte la puce `ref` (discordance épinglée).
func freeze(ref: FieldRef) -> void:
	for entry: Dictionary in entries:
		for chip: StatementChipView in entry["chips"]:
			if is_instance_valid(chip) and not chip.struck and chip.ref.equals(ref):
				entry["frozen"] = true
	_restyle()


func is_frozen(ref: FieldRef) -> bool:
	for entry: Dictionary in entries:
		if not entry.get("frozen", false):
			continue
		for chip: StatementChipView in entry["chips"]:
			if is_instance_valid(chip) and chip.ref.equals(ref):
				return true
	return false


## Éléments sélectionnables affichés (puces, objets de l'onglet FOUILLE).
func get_items() -> Array[InspectableItem]:
	var items: Array[InspectableItem] = []
	for chip: StatementChipView in chips():
		items.append(chip)
	for view: SearchItemView in search_views:
		if is_instance_valid(view):
			items.append(view)
	return items


func set_inspection_active(enabled: bool) -> void:
	inspection_active = enabled
	for item: InspectableItem in get_items():
		item.set_inspection_active(enabled)


## Dernière puce sélectionnable (cible de la croix ↑ depuis le plan de travail).
func last_focusable() -> Control:
	var candidates: Array[InspectableItem] = get_items() if current_tab == TAB_SEARCH else [] as Array[InspectableItem]
	if current_tab == TAB_DIALOGUE:
		for chip: StatementChipView in chips():
			candidates.append(chip)
	for i: int in range(candidates.size() - 1, -1, -1):
		var item: InspectableItem = candidates[i]
		if item.focus_mode != Control.FOCUS_NONE and item.is_visible_in_tree():
			return item
	return null


# ---------------------------------------------------------------------------
# Onglet FOUILLE
# ---------------------------------------------------------------------------

## Objets révélés (toutes zones scannées) : l'onglet FOUILLE apparaît.
func set_search_results(items: Array[SearchItem], scanned_zones: Array[StringName]) -> void:
	_search_items = items.duplicate()
	_search_zones = scanned_zones.duplicate()
	_tabs.visible = not _search_zones.is_empty()
	_search_tab.text = UiText.tf("jr_tab_search_count", [_search_items.size()], "FOUILLE · %d")
	if current_tab == TAB_SEARCH:
		_build_search_views()
	_fit_height()


func search_items() -> Array[SearchItem]:
	return _search_items.duplicate()


func show_tab(tab: StringName) -> void:
	current_tab = tab
	if _dialogue_tab != null:
		_dialogue_tab.set_pressed_no_signal(tab == TAB_DIALOGUE)
		_search_tab.set_pressed_no_signal(tab == TAB_SEARCH)
	if _list == null:
		return
	_list.visible = tab == TAB_DIALOGUE
	_search_list.visible = tab == TAB_SEARCH
	if tab == TAB_SEARCH:
		_build_search_views()
	else:
		_clear_search_views()
	tab_changed.emit(tab)
	_fit_height()


func _build_search_views() -> void:
	_clear_search_views()
	for zone: StringName in SearchLayout.ZONES:
		if not _search_zones.has(zone):
			continue
		var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		head.name = "Zone_%s" % zone
		_search_list.add_child(head)
		head.add_child(ScreenBase.label(UiText.t("zone_%s" % zone, String(zone)), &"DocFieldLabel", Palette.TEXT_SECONDARY))
		var found: int = 0
		for item: SearchItem in _search_items:
			if item.zone != zone:
				continue
			found += 1
			var view: SearchItemView = SearchItemView.new()
			view.setup(item)
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_search_list.add_child(view)
			view.set_inspection_active(inspection_active)
			view.picked.connect(func(picked: InspectableItem) -> void: item_picked.emit(picked))
			search_views.append(view)
		if found == 0:
			head.add_child(ScreenBase.chip(UiText.t("srch_nothing", "RAS"), UiIcon.Kind.CHECK, Palette.TEXT_SECONDARY))


func _clear_search_views() -> void:
	for child: Node in _search_list.get_children():
		_search_list.remove_child(child)
		child.queue_free()
	search_views.clear()


func _clear_search() -> void:
	_search_items.clear()
	_clear_search_views()
