## Onglets de référence du Rulebook (M7, GDD §7 « Onglets Rulebook »,
## `DayDef.rulebook_tabs`, cumulatifs) : Origines (J4 : code, bloc ID,
## secteurs), Implants (J6 : familles, signes visibles, légalité), Symboles
## subversifs (J7 : bulletin de la luciole), Sceaux (J9 : sceau en vigueur par
## document). L'onglet Avis de recherche (J10) est construit par le
## `RulebookPanel` (cartes sélectionnables `WantedCardView`).
## Contenu informatif : non sélectionnable (les règles R10, R15, R16, R20 le
## sont, dans l'onglet « Règles »).
class_name RulebookReference
extends RefCounted

const TAB_ORIGINS: StringName = &"origins"
const TAB_IMPLANTS: StringName = &"implants"
const TAB_SYMBOLS: StringName = &"symbols"
const TAB_SEALS: StringName = &"seals"
const TAB_WANTED: StringName = &"wanted"
const ORDER: Array[StringName] = [TAB_ORIGINS, TAB_IMPLANTS, TAB_SYMBOLS, TAB_SEALS, TAB_WANTED]
## Jour d'ouverture de chaque onglet (GDD §7) : pastille ambre « nouveau ».
const INTRO_DAY: Dictionary[StringName, int] = {
	TAB_ORIGINS: 4, TAB_IMPLANTS: 6, TAB_SYMBOLS: 7, TAB_SEALS: 9, TAB_WANTED: 10,
}
## Familles d'implants (LORE §8) : [code, légal si déclaré].
const IMPLANT_FAMILIES: Array[Array] = [
	["OPT", true], ["NX", true], ["KIN", true], ["DER", true], ["MIL", false],
]
## Documents et sceau en vigueur (ordre d'affichage).
const SEAL_DOCUMENTS: Array[StringName] = [&"id_card", &"entry_permit", &"bioscan", &"mil_waiver"]

static var _catalog: DataCatalog = null


static func tab_title(tab: StringName) -> String:
	match tab:
		TAB_ORIGINS:
			return UiText.t("rb_tab_origins", "Codes d'origine")
		TAB_IMPLANTS:
			return UiText.t("rb_tab_implants", "Implants")
		TAB_SYMBOLS:
			return UiText.t("rb_tab_symbols", "Symboles subversifs")
		TAB_SEALS:
			return UiText.t("rb_tab_seals", "Sceaux")
		TAB_WANTED:
			return UiText.t("rb_tab_wanted", "AVIS DE RECHERCHE")
	return String(tab)


static func is_new(tab: StringName, day_number: int) -> bool:
	return INTRO_DAY.get(tab, 0) == day_number


## Données (origines, documents) : catalogue chargé une fois.
static func catalog() -> DataCatalog:
	if _catalog == null:
		_catalog = DataCatalog.load_from()
	return _catalog


## Contenu d'un onglet de référence (hors avis de recherche).
static func build(tab: StringName) -> Control:
	match tab:
		TAB_ORIGINS:
			return _origins()
		TAB_IMPLANTS:
			return _implants()
		TAB_SYMBOLS:
			return _symbols()
		TAB_SEALS:
			return _seals()
	return ScreenBase.vbox()


static func _intro(text: String) -> Label:
	var intro: Label = ScreenBase.wrapped(text, &"BodySmall")
	return intro


static func _row(lead: Control, title: String, text: String, side: Control = null, accent: Color = DS.LINE_SUBTLE) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_ELEVATED, accent))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	card.add_child(row)
	if lead != null:
		lead.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(lead)
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title_label: Label = ScreenBase.label(title, &"BodyStrong", DS.TEXT_PRIMARY)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = 120.0
	column.add_child(title_label)
	if not text.is_empty():
		column.add_child(ScreenBase.wrapped(text, &"BodySmall"))
	if side != null:
		column.add_child(side)
	return card


## Code mono dans une puce (« TYC », « HG-4 »).
static func _code(text: String, color: Color = DS.ACCENT_CYAN) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(Color(color, 0.12), Color(color, 0.6), DS.BORDER_HAIRLINE,
			DS.CHAMFER_S, DS.SPACE_1))
	cap.custom_minimum_size.x = 64.0
	var l: Label = ScreenBase.label(text, &"DataTitle", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


static func _origins() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_origins_intro", "Le 1er chiffre du bloc ID (HG-N…) désigne l'origine du titulaire.")))
	var factions: Array[FactionDef] = []
	for faction: FactionDef in catalog().factions.values():
		factions.append(faction)
	factions.sort_custom(func(a: FactionDef, b: FactionDef) -> bool: return a.id_prefix < b.id_prefix)
	for faction: FactionDef in factions:
		var digit: String = faction.id_prefix.right(1)
		var title: String = "%s · %s" % [faction.code, UiText.t(faction.name_key, String(faction.id))]
		var sectors: String = " · ".join(faction.origin_sectors)
		var side: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		side.add_child(ScreenBase.label(UiText.t("rb_origins_block", "BLOC ID"), &"DocFieldLabel"))
		side.add_child(ScreenBase.label(faction.id_prefix + "XXX-XXXX", &"DocFieldValue", DS.TEXT_PRIMARY))
		box.add_child(_row(_code(digit, DS.ACCENT_CYAN), title, sectors, side))
	return box


static func _implants() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_implants_intro",
			"Comparez le visage du passager à « Implants déclarés » de sa carte (Mode Inspection).")))
	for family: Array in IMPLANT_FAMILIES:
		var code: String = family[0]
		var legal: bool = family[1]
		var key: String = code.to_lower()
		var color: Color = DS.ACCENT_CYAN if legal else DS.STATE_RED
		var status: PanelContainer = ScreenBase.chip(
				UiText.t("rb_implant_%s_status" % key, "LÉGAL SI DÉCLARÉ" if legal else "INTERDIT SANS DÉROGATION"),
				UiIcon.Kind.CHECK if legal else UiIcon.Kind.DENIED, DS.TEXT_SECONDARY if legal else DS.STATE_RED)
		box.add_child(_row(_code(code + "-", color), UiText.t("rb_implant_%s_title" % key, code),
				UiText.t("rb_implant_%s_text" % key, ""), status, color if not legal else DS.LINE_SUBTLE))
	return box


static func _symbols() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_symbols_intro", "Bulletin du Bureau de Continuité · symboles subversifs relevés aux quais.")))
	var glyph: Control = Control.new()
	glyph.custom_minimum_size = Vector2(64, 64)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func() -> void:
		glyph.draw_rect(Rect2(Vector2.ZERO, glyph.size), DS.BG_PANEL)
		glyph.draw_rect(Rect2(Vector2.ZERO, glyph.size), DS.MAGENTA_24, false, 1.0)
		SlippedItemView.draw_luciole(glyph, glyph.size * 0.5 + Vector2(0, 4), DS.SPACE_4, DS.ACCENT_MAGENTA))
	var side: PanelContainer = ScreenBase.chip(UiText.t("rb_symbol_luciole_action", "À SIGNALER · MISE EN ATTENTE DOCUMENTÉE"),
			UiIcon.Kind.WARNING, DS.STATE_AMBER)
	box.add_child(_row(glyph, UiText.t("rb_symbol_luciole_title", "Luciole (encre magenta)"),
			UiText.t("rb_symbol_luciole_text", "Dessin d'insecte lumineux au coin d'un document, visible à la loupe. Marque du réseau des Lucioles."),
			side, DS.ACCENT_MAGENTA))
	return box


static func _seals() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_seals_intro", "Sceaux en vigueur au 21.03.2187. Tout ancien modèle est refusé.")))
	for doc_id: StringName in SEAL_DOCUMENTS:
		var def: DocumentTypeDef = catalog().documents.get(doc_id, null)
		if def == null:
			continue
		var icon: UiIcon = UiIcon.make(UiIcon.seal_kind(def.seal_id), DocumentView.token_color(def.holo_tint_token), DS.ICON_L + DS.SPACE_2)
		var seal_name: String = UiText.t("val_" + String(def.seal_id), String(def.seal_id))
		box.add_child(_row(icon, UiText.document_title(def), seal_name, null, DocumentView.token_color(def.holo_tint_token)))
	return box
