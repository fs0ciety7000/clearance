## Onglets de référence du Rulebook (M7, GDD §7 « Onglets Rulebook »,
## `DayDef.rulebook_tabs`, cumulatifs) : Origines (J4 : code, bloc ID,
## secteurs), Implants (J6 : familles, signes visibles, légalité), Symboles
## subversifs (J7 : bulletin de la luciole), Sceaux (J9 : sceau en vigueur par
## document). L'onglet Avis de recherche (J10) est construit par le
## `RulebookPanel` (cartes sélectionnables `WantedCardView`).
## Contenu informatif : non sélectionnable (les règles R10, R15, R16, R20 le
## sont, dans l'onglet « Règles »), sauf les entrées du bulletin des symboles
## (`SymbolCardView`, paire marque ↔ symbole, NARRATIVE §4.9) ; l'onglet
## Origines rappelle la tolérance « 00.00.AAAA » des Dérivants (§4.10, R07).
## Acte II (ARCHITECTURE §7.2) : Codes employeurs (J12, R25 : table
## `ContractConsistentRule.employer_codes`), Registre des cargos (J13, R26 :
## `DriftPassRule.registered_vessels`, cargos retirés), Révocations (J17, R30 :
## cartes `RevokedCardView` construites par le `RulebookPanel`) ; ligne
## « firmware NX » de l'onglet Implants (R27) quand la règle est en vigueur.
## Acte III (ARCHITECTURE §7.3) : Main courante (J24, R34 : `LedgerCardView`,
## répondants admis aujourd'hui, liste qui s'allonge) et Convocations (J26,
## R36 : `SummonsCardView`), construites par le `RulebookPanel`.
## M12 (lot C) : onglet « Cartes volées » (`TAB_STOLEN`, liste nommée `stolen`
## d'EV-07, `rule_list_published`) ; l'onglet Révocations prend l'intitulé de
## la liste lue par la règle en vigueur (`RevokedIdRule.list_title_key` :
## « Liste du Conseil » au J31 du monde B).
## M13 (lot C, I37) : onglet **Contrebande** (`TAB_CONTRABAND`, J8 :
## `ContrabandEntryView` sélectionnables CB-01 → CB-07, renvoi CB-08) ; ligne
## « non visible — fouille » de l'onglet Implants (implants de localisation
## dissimulée, `SearchCatalogDef.implant_zones`) quand R44 est en vigueur ;
## ligne R47 (Ceinturiers, séjour > 7 jours) dans l'onglet Origines.
class_name RulebookReference
extends RefCounted

const TAB_ORIGINS: StringName = &"origins"
const TAB_IMPLANTS: StringName = &"implants"
const TAB_SYMBOLS: StringName = &"symbols"
const TAB_SEALS: StringName = &"seals"
const TAB_WANTED: StringName = &"wanted"
const TAB_EMPLOYERS: StringName = &"employers"
const TAB_VESSELS: StringName = &"vessels"
const TAB_REVOKED: StringName = &"revoked"
const TAB_LEDGER: StringName = &"ledger"
const TAB_SUMMONS: StringName = &"summons"
## M12 : liste nommée « Cartes volées » (EV-07), ouverte tant qu'elle n'est pas vide.
const TAB_STOLEN: StringName = &"stolen"
## M13 : catégories d'objets interdits (R45 / R46), J8+.
const TAB_CONTRABAND: StringName = &"contraband"
const ORDER: Array[StringName] = [TAB_ORIGINS, TAB_IMPLANTS, TAB_SYMBOLS, TAB_SEALS, TAB_WANTED, TAB_EMPLOYERS, TAB_VESSELS,
		TAB_REVOKED, TAB_LEDGER, TAB_SUMMONS, TAB_STOLEN, TAB_CONTRABAND]
## Onglets construits par le `RulebookPanel` (cartes sélectionnables).
const DYNAMIC_TABS: Array[StringName] = [TAB_WANTED, TAB_REVOKED, TAB_LEDGER, TAB_SUMMONS, TAB_STOLEN]
## Règles qui portent les registres de l'Acte II (`data/rules/`).
const RULE_CONTRACT: StringName = &"r_contract_consistent"
const RULE_DRIFT: StringName = &"r_drift_pass"
const RULE_FIRMWARE: StringName = &"r_nx_firmware"
## M13 : portique (R44) et fouille des Ceinturiers (R47).
const RULE_SEARCH_CAUSE: StringName = &"r_search_cause"
const RULE_BELT_SEARCH: StringName = &"r_belt_search"
## Jour d'ouverture de chaque onglet (GDD §7) : pastille ambre « nouveau ».
const INTRO_DAY: Dictionary[StringName, int] = {
	TAB_ORIGINS: 4, TAB_IMPLANTS: 6, TAB_SYMBOLS: 7, TAB_SEALS: 9, TAB_WANTED: 10,
	TAB_EMPLOYERS: 12, TAB_VESSELS: 13, TAB_REVOKED: 17, TAB_LEDGER: 24, TAB_SUMMONS: 26, TAB_CONTRABAND: 8,
}
## Familles d'implants (LORE §8) : [code, légal si déclaré].
const IMPLANT_FAMILIES: Array[Array] = [
	["OPT", true], ["NX", true], ["KIN", true], ["DER", true], ["MIL", false],
]
## Symboles du bulletin (J7+) : identifiants de marque (`DocumentInstance.marks`).
const SYMBOLS: Array[StringName] = [&"luciole"]
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
		TAB_EMPLOYERS:
			return UiText.t("rb_tab_employers", "Codes employeurs")
		TAB_VESSELS:
			return UiText.t("rb_tab_vessels", "Registre des cargos")
		TAB_REVOKED:
			return UiText.t("rb_tab_revoked", "Révocations")
		TAB_LEDGER:
			return UiText.t("rb_tab_ledger", "Main courante")
		TAB_SUMMONS:
			return UiText.t("rb_tab_summons", "Convocations")
		TAB_STOLEN:
			return UiText.t("rb_tab_stolen", "Cartes volées")
		TAB_CONTRABAND:
			return UiText.t("rb_tab_contraband", "Contrebande")
	return String(tab)


## Intitulé de l'onglet Révocations selon les règles en vigueur : celui de la
## liste lue par une `RevokedIdRule` sur l'onglet Révocations (`list_title_key`,
## « Liste du Conseil »), sinon « Révocations ». Vide si aucune.
static func revoked_title_key(rule_ids: Array[StringName]) -> String:
	for rule_id: StringName in rule_ids:
		var listed: RevokedIdRule = catalog_rule(rule_id) as RevokedIdRule
		if listed != null and (listed.list_label == &"" or listed.list_label == &"revoked") and not listed.list_title_key.is_empty():
			return listed.list_title_key
	return ""


static func is_new(tab: StringName, day_number: int) -> bool:
	return INTRO_DAY.get(tab, 0) == day_number


## Données (origines, documents) : catalogue chargé une fois.
static func catalog() -> DataCatalog:
	if _catalog == null:
		_catalog = DataCatalog.load_from()
	return _catalog


## Contenu d'un onglet de référence (hors avis de recherche et révocations) ;
## `rule_ids` : règles en vigueur ce jour (ligne firmware de l'onglet Implants).
static func build(tab: StringName, rule_ids: Array[StringName] = []) -> Control:
	match tab:
		TAB_ORIGINS:
			return _origins(rule_ids.has(RULE_BELT_SEARCH))
		TAB_IMPLANTS:
			return _implants(rule_ids.has(RULE_FIRMWARE), rule_ids.has(RULE_SEARCH_CAUSE))
		TAB_CONTRABAND:
			return _contraband()
		TAB_SYMBOLS:
			return _symbols()
		TAB_SEALS:
			return _seals()
		TAB_EMPLOYERS:
			return _employers()
		TAB_VESSELS:
			return _vessels()
	return ScreenBase.vbox()


## Règle du catalogue (registres de l'Acte II), null si absente.
static func catalog_rule(rule_id: StringName) -> Rule:
	return catalog().rules.get(rule_id, null)


## M15 (lot U) : secteur d'origine `value` (texte des données, en français,
## `FactionDef.origin_sectors` / `Passenger.origin_sector`) dans la langue
## courante, par la clé `FactionDef.sector_key` — la même traduction que
## l'onglet Origines (`faction_<id>_sectors`, cohérence testée). Un texte qui
## n'est pas un secteur connu est rendu tel quel. Aucune logique ne compare ces
## textes : la génération et les cas restent identiques dans les deux langues.
static func sector_text(value: String) -> String:
	if value.is_empty():
		return value
	for faction: FactionDef in catalog().factions.values():
		var index: int = faction.origin_sectors.find(value)
		if index >= 0:
			return UiText.t(faction.sector_key(index), value)
	return value


## Codes employeurs (R25) triés par code : `[code, employeur]`.
static func employer_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var rule: ContractConsistentRule = catalog_rule(RULE_CONTRACT) as ContractConsistentRule
	if rule == null:
		return rows
	for employer: String in rule.employer_codes:
		rows.append(PackedStringArray([rule.employer_codes[employer], employer]))
	rows.sort_custom(func(a: PackedStringArray, b: PackedStringArray) -> bool: return a[0] < b[0])
	return rows


## Nom affiché d'un employeur (QA-028) : clé `rb_emp_<code>` (« KA · Kessler-Ashe
## Orbital »), sans le code déjà porté par la pastille CT-KA ; nom de la
## règle à défaut.
static func employer_name(code: String, fallback: String) -> String:
	var text: String = UiText.t(ContractConsistentRule.label_key(code), fallback)
	var prefix: String = code + " · "
	return text.trim_prefix(prefix) if text.begins_with(prefix) else text


## Cargos inscrits au registre (R26).
static func registered_vessels() -> PackedStringArray:
	var rule: DriftPassRule = catalog_rule(RULE_DRIFT) as DriftPassRule
	return rule.registered_vessels if rule != null else PackedStringArray()


static func _employers() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.name = "Employers"
	box.add_child(_intro(UiText.t("rb_employers_intro",
			"Contrat de travail : le code CT-XX correspond à l'employeur du permis d'entrée.")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_1)
	box.add_child(grid)
	for row: PackedStringArray in employer_rows():
		var cap: PanelContainer = _code("CT-" + row[0], DS.ACCENT_CYAN)
		cap.name = "Code_%s" % row[0]
		grid.add_child(cap)
		var employer: Label = ScreenBase.label(employer_name(row[0], row[1]), &"BodySmall", DS.TEXT_PRIMARY)
		employer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		employer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		employer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		employer.custom_minimum_size.x = 120.0
		grid.add_child(employer)
	return box


static func _vessels() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.name = "Vessels"
	box.add_child(_intro(UiText.t("rb_vessels_intro",
			"Dérivants : le vaisseau du laissez-passer = nom de famille, inscrit au registre.")))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", DS.SPACE_2)
	flow.add_theme_constant_override("v_separation", DS.SPACE_2)
	box.add_child(flow)
	for vessel: String in registered_vessels():
		var cap: PanelContainer = _code(vessel, DS.ACCENT_CYAN)
		cap.name = "Vessel_%s" % vessel.validate_node_name()
		flow.add_child(cap)
	var removed: Label = ScreenBase.wrapped(UiText.t("rb_vessels_removed", "Retirés : SILLAGE (démantelé le 20.03.2187)."),
			&"BodySmall", Palette.STATE_AMBER)
	removed.name = "RemovedNote"
	box.add_child(removed)
	return box


static func _intro(text: String) -> Label:
	var intro: Label = ScreenBase.wrapped(text, &"BodySmall")
	return intro


static func _row(lead: Control, title: String, text: String, side: Control = null, accent: Color = Palette.LINE_SUBTLE) -> PanelContainer:
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


static func _origins(belt_search: bool = false) -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_origins_intro", "Le 1er chiffre du bloc ID (HG-N…) désigne l'origine du titulaire.")))
	if belt_search:
		# M13 (R47, J19) : fouille obligatoire des Ceinturiers, lisible sans défiler.
		var belt: Label = ScreenBase.wrapped(UiText.t("rb_belt_search_line", "CER · séjour > 7 jours : fouille obligatoire (R47)"),
				&"BodySmall", Palette.STATE_AMBER)
		belt.name = "BeltSearchNote"
		box.add_child(belt)
	# §4.10 (D-068) : naissance « 00.00.AAAA » des Dérivants, comparée par
	# année (R07). Sous l'intro : lisible sans défiler.
	var drv_note: Label = ScreenBase.wrapped(UiText.t("rb_origins_drv_birth",
			"DRV · Dérivants : naissance « 00.00.AAAA » tolérée (année seule)."), &"BodySmall", Palette.STATE_AMBER)
	drv_note.name = "DrvBirthNote"
	box.add_child(drv_note)
	var factions: Array[FactionDef] = []
	for faction: FactionDef in catalog().factions.values():
		factions.append(faction)
	factions.sort_custom(func(a: FactionDef, b: FactionDef) -> bool: return a.id_prefix < b.id_prefix)
	for faction: FactionDef in factions:
		var digit: String = faction.id_prefix.right(1)
		var title: String = "%s · %s" % [faction.code, UiText.t(faction.name_key, String(faction.id))]
		# M15 : secteurs d'origine (texte de données, en français) traduisibles
		# par la clé `faction_<id>_sectors` ; repli : le texte des données. Les
		# documents affichent chaque secteur par `sector_text` (mêmes mots).
		var sectors: String = UiText.t("faction_%s_sectors" % faction.id, " · ".join(faction.origin_sectors))
		var side: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		side.add_child(ScreenBase.label(UiText.t("rb_origins_block", "BLOC ID"), &"DocFieldLabel"))
		side.add_child(ScreenBase.label(faction.id_prefix + "XXX-XXXX", &"DocFieldValue", DS.TEXT_PRIMARY))
		box.add_child(_row(_code(digit, DS.ACCENT_CYAN), title, sectors, side))
	return box


static func _implants(firmware: bool = false, hidden: bool = false) -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_implants_intro",
			"Comparez le visage du passager à « Implants déclarés » de sa carte (Mode Inspection).")))
	if firmware:
		# R27 (Acte II) : ligne firmware, lisible sans défiler.
		var note: Label = ScreenBase.wrapped(UiText.t("rb_implants_firmware", "NX- : firmware de moins de 90 jours."),
				&"BodySmall", Palette.STATE_AMBER)
		note.name = "FirmwareNote"
		box.add_child(note)
	for family: Array in IMPLANT_FAMILIES:
		var code: String = family[0]
		var legal: bool = family[1]
		var key: String = code.to_lower()
		var color: Color = DS.ACCENT_CYAN if legal else Palette.STATE_RED
		var status: PanelContainer = ScreenBase.chip(
				UiText.t("rb_implant_%s_status" % key, "LÉGAL SI DÉCLARÉ" if legal else "INTERDIT SANS DÉROGATION"),
				UiIcon.Kind.CHECK if legal else UiIcon.Kind.DENIED, Palette.TEXT_SECONDARY if legal else Palette.STATE_RED)
		var row: PanelContainer = _row(_code(code + "-", color), UiText.t("rb_implant_%s_title" % key, code),
				UiText.t("rb_implant_%s_text" % key, ""), status, color if not legal else Palette.LINE_SUBTLE)
		box.add_child(row)
		if hidden:
			# M13 (§2.5) : implants de localisation dissimulée — jamais comparés au visage.
			var codes: PackedStringArray = hidden_implant_codes(code)
			if not codes.is_empty():
				var note: PanelContainer = ScreenBase.chip("%s · %s" % [" ".join(codes), UiText.t("rb_implant_hidden", "non visible — fouille")],
						UiIcon.Kind.GATE, Palette.TEXT_SECONDARY)
				note.name = "Hidden_%s" % code
				var column: VBoxContainer = row.get_child(0).get_child(row.get_child(0).get_child_count() - 1) as VBoxContainer
				if column != null:
					column.add_child(note)
				else:
					box.add_child(note)
	return box


## M13 : codes d'implants de la famille `family` (`NX`, `KIN`…) dont la
## localisation est dissimulée (catalogue de fouille), triés.
static func hidden_implant_codes(family: String) -> PackedStringArray:
	var codes: PackedStringArray = []
	var search: SearchCatalogDef = catalog().search_catalog
	if search == null:
		return codes
	for implant_code: String in search.implant_zones:
		if implant_code.begins_with(family + "-"):
			codes.append(implant_code)
	codes.sort()
	return codes


## M13 : onglet Contrebande — une entrée sélectionnable par catégorie
## (`ContrabandEntryView`, nommée `Contraband_<catégorie>`, câblée par le
## `RulebookPanel`).
static func _contraband() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.name = "Contraband"
	box.add_child(_intro(UiText.t("rb_contraband_intro",
			"Objets trouvés au portique. Mode Inspection : comparez l'objet à sa catégorie. Scellé, étiquette : lisez la ligne de l'objet.")))
	for i: int in ContrabandEntryView.ENTRIES.size():
		var entry: Array = ContrabandEntryView.ENTRIES[i]
		var view: ContrabandEntryView = ContrabandEntryView.new()
		view.setup(entry[0], entry[1], i + 1)
		box.add_child(view)
	return box


## Bulletin des symboles : une `SymbolCardView` **sélectionnable** par symbole
## (nommée `Symbol_<id>`, câblée par le `RulebookPanel`, NARRATIVE §4.9).
static func _symbols() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	box.add_child(_intro(UiText.t("rb_symbols_intro", "Bulletin du Bureau de Continuité · symboles subversifs relevés aux quais.")))
	for symbol_id: StringName in SYMBOLS:
		var card: SymbolCardView = SymbolCardView.new()
		card.name = "Symbol_%s" % symbol_id
		card.setup(symbol_id)
		box.add_child(card)
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
