## Économat du Hall (M13 lot C, I38 ; M13 §3.3, §3.5 ; D-150) : section de la
## soirée, sous les dépenses du foyer, à partir du soir du J5.
##
## - Offres du soir (`EveningService.shop_lines` : `ExpenseLine.upgrade_id`),
##   catalogue puis **HORS CATALOGUE** ; chaque ligne dit le **nom**, l'**effet**
##   (une ligne), le **prix narratif** s'il y en a un (icône + texte ambre), le
##   prix ; badge **NOUVEAU** au premier soir de disponibilité.
## - **Jamais présélectionnée** ; **un achat par soir** (une seule case cochable,
##   les autres disent « Un achat par soir ») ; **pas de crédit** (« Fonds
##   insuffisants » si le solde après les postes du foyer ne suffit pas) — la
##   règle est celle d'`EveningService.can_toggle_on`, lue par l'écran.
## - **Solde après achat** recalculé en direct ; les besoins du foyer restent
##   au-dessus (postes, rations) et à droite (état des proches).
## - Améliorations **ACQUISES** rappelées (pastilles), effet dès le shift suivant.
class_name ShopView
extends VBoxContainer

## Case cochée / décochée par le joueur (l'écran valide ou refuse).
signal line_toggled(line: ExpenseLine, pressed: bool)

const ROW_H: float = 52.0
const PRICE_W: float = 80.0

var lines: Array[ExpenseLine] = []
var economy: EconomyDef = null
var flags: Dictionary[StringName, Variant] = {}
var day_number: int = 0
var rows: Array[Button] = []

var _after_label: Label = null
var _owned_row: HFlowContainer = null


## `p_lines` : postes d'achat du soir (`upgrade_id` non vide).
func setup(p_lines: Array[ExpenseLine], p_economy: EconomyDef, p_flags: Dictionary[StringName, Variant], p_day: int) -> void:
	lines = p_lines.duplicate()
	economy = p_economy
	flags = p_flags
	day_number = p_day


## Vrai si la soirée affiche l'Économat (offres ou améliorations acquises).
static func has_content(p_lines: Array[ExpenseLine], p_economy: EconomyDef, p_flags: Dictionary[StringName, Variant], p_day: int) -> bool:
	if p_economy == null or p_day < p_economy.shop_open_evening:
		return false
	for line: ExpenseLine in p_lines:
		if line.upgrade_id != &"":
			return true
	return not owned_ids(p_economy, p_flags).is_empty()


static func owned_ids(p_economy: EconomyDef, p_flags: Dictionary[StringName, Variant]) -> Array[StringName]:
	var ids: Array[StringName] = []
	if p_economy == null:
		return ids
	for upgrade: UpgradeDef in p_economy.upgrades:
		if upgrade != null and UpgradeDef.owns(p_flags, upgrade.id):
			ids.append(upgrade.id)
	return ids


func _ready() -> void:
	name = "Shop"
	add_theme_constant_override("separation", DS.SPACE_2)
	add_child(ScreenBase.section(UiText.t("shop_title", "ÉCONOMAT DU HALL"), UiIcon.Kind.TOOL, DS.ACCENT_YELLOW,
			UiText.t("shop_one_per_evening", "Un achat par soir. L'Économat ne fait pas crédit.")))
	if economy != null and day_number == economy.shop_open_evening:
		# Premier soir (J5) : Okonkwo présente l'Économat (voix grise).
		var intro: PanelContainer = PanelContainer.new()
		intro.name = "Intro"
		intro.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_PANEL, Palette.TEXT_SECONDARY))
		var intro_box: VBoxContainer = ScreenBase.vbox(0)
		intro.add_child(intro_box)
		intro_box.add_child(ScreenBase.label(UiText.t("spk_okonkwo", "OKONKWO"), &"DocFieldLabel", Palette.TEXT_SECONDARY))
		intro_box.add_child(ScreenBase.wrapped(UiText.quoted(UiText.t("shop_intro", "")), &"BodySmall", DS.TEXT_PRIMARY))
		add_child(intro)
	var catalog: Array[ExpenseLine] = []
	var off: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		var upgrade: UpgradeDef = _upgrade(line)
		if upgrade != null and upgrade.off_catalog:
			off.append(line)
		else:
			catalog.append(line)
	if catalog.is_empty() and off.is_empty():
		add_child(ScreenBase.wrapped(UiText.t("shop_empty", "Rien de nouveau ce soir à l'Économat."), &"CaptionLabel"))
	for line: ExpenseLine in catalog:
		_add_row(line)
	if not off.is_empty():
		var head: Label = ScreenBase.eyebrow(UiText.t("shop_offcatalog", "HORS CATALOGUE"), Palette.STATE_AMBER)
		head.name = "OffCatalog"
		add_child(head)
		for line: ExpenseLine in off:
			_add_row(line)
	var after_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	after_row.name = "AfterPurchase"
	add_child(after_row)
	var caption: Label = ScreenBase.label(UiText.t("shop_after", "Solde après achat"), &"BodySmall")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after_row.add_child(caption)
	_after_label = ScreenBase.label("", &"DocFieldValue", DS.ACCENT_YELLOW)
	after_row.add_child(_after_label)
	var owned: Array[StringName] = owned_ids(economy, flags)
	if not owned.is_empty():
		_owned_row = HFlowContainer.new()
		_owned_row.name = "Owned"
		_owned_row.add_theme_constant_override("h_separation", DS.SPACE_2)
		_owned_row.add_theme_constant_override("v_separation", DS.SPACE_1)
		add_child(_owned_row)
		_owned_row.add_child(ScreenBase.label(UiText.t("shop_owned", "ACQUIS"), &"DocFieldLabel", Palette.TEXT_SECONDARY))
		for upgrade_id: StringName in owned:
			var upgrade: UpgradeDef = economy.get_upgrade(upgrade_id)
			var chip: PanelContainer = ScreenBase.chip(UiText.t(upgrade.name_key, String(upgrade_id)) if upgrade != null else String(upgrade_id),
					UiIcon.Kind.CHECK, Palette.TEXT_SECONDARY)
			chip.name = "Owned_%s" % upgrade_id
			_owned_row.add_child(chip)


func _upgrade(line: ExpenseLine) -> UpgradeDef:
	return economy.get_upgrade(line.upgrade_id) if economy != null else null


func _add_row(line: ExpenseLine) -> void:
	var upgrade: UpgradeDef = _upgrade(line)
	var row: Button = Button.new()
	row.name = "Upgrade_%s" % line.upgrade_id
	row.toggle_mode = true
	row.theme_type_variation = &"ButtonQuestion"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.button_pressed = line.paid
	row.set_meta(&"line", line)
	row.add_theme_stylebox_override(&"pressed", ThemeBuilder.chamfer_box(DS.BG_ELEVATED.blend(DS.CYAN_08), DS.CYAN_40,
			DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_4)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_1)
	row.add_child(margin)
	margin.minimum_size_changed.connect(func() -> void:
		row.custom_minimum_size.y = maxf(ROW_H, margin.get_combined_minimum_size().y))
	var content: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	margin.add_child(content)
	var check: EveningScreen.CheckMark = EveningScreen.CheckMark.new()
	check.name = "Check"
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(check)
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(texts)
	var title_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	texts.add_child(title_row)
	title_row.add_child(ScreenBase.label(UiText.t(upgrade.name_key if upgrade != null else line.label_key, String(line.upgrade_id)),
			&"BodyStrong"))
	if upgrade != null and upgrade.is_new(day_number):
		var badge: PanelContainer = ScreenBase.chip(UiText.t("shop_new", "NOUVEAU"), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
		badge.name = "New"
		title_row.add_child(badge)
	var effect: Label = ScreenBase.wrapped(UiText.t(upgrade.desc_key if upgrade != null else line.note_key, ""), &"CaptionLabel")
	effect.name = "Effect"
	texts.add_child(effect)
	if upgrade != null and not upgrade.note_key.is_empty():
		var price_note: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
		price_note.name = "NarrativePrice"
		texts.add_child(price_note)
		price_note.add_child(UiIcon.make(UiIcon.Kind.WARNING, Palette.STATE_AMBER, DS.ICON_S))
		var note: Label = ScreenBase.wrapped(UiText.tf("shop_price_note", [UiText.t(upgrade.note_key, "")], "Prix : %s"),
				&"CaptionLabel", Palette.STATE_AMBER)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_note.add_child(note)
	var reason: Label = ScreenBase.label("", &"CaptionLabel", Palette.STATE_AMBER)
	reason.name = "Reason"
	reason.visible = false
	texts.add_child(reason)
	var cost: Label = ScreenBase.label(ScreenBase.credits(line.cost), &"DataTitle")
	cost.name = "Cost"
	cost.custom_minimum_size.x = PRICE_W
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(cost)
	row.toggled.connect(func(pressed: bool) -> void: line_toggled.emit(line, pressed))
	add_child(row)
	rows.append(row)


## État des cases : cochée, achetable, raison du refus (fonds, un achat par
## soir) ; `can_toggle` : `func(line) -> bool` (règle de l'écran) ;
## `after` : solde après la soirée, achat compris.
func refresh(can_toggle: Callable, after: int) -> void:
	var selected: bool = false
	for line: ExpenseLine in lines:
		selected = selected or line.paid
	for row: Button in rows:
		var line: ExpenseLine = row.get_meta(&"line")
		row.set_pressed_no_signal(line.paid)
		var check: EveningScreen.CheckMark = row.find_child("Check", true, false)
		check.checked = line.paid
		var affordable: bool = line.paid or bool(can_toggle.call(line))
		var reason: Label = row.find_child("Reason", true, false)
		reason.visible = not affordable
		if not affordable:
			reason.text = UiText.t("shop_one_only", "Un achat par soir : décochez l'autre d'abord.") if selected \
					else UiText.t("ev_insufficient", "Fonds insuffisants")
		var cost: Label = row.find_child("Cost", true, false)
		cost.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY if line.paid else (Palette.TEXT_SECONDARY if affordable else DS.TEXT_MUTED))
	if _after_label != null:
		_after_label.text = ScreenBase.credits(after)
		_after_label.add_theme_color_override(&"font_color", Palette.STATE_RED if after < 0 else DS.ACCENT_YELLOW)


func get_row(upgrade_id: StringName) -> Button:
	for row: Button in rows:
		var line: ExpenseLine = row.get_meta(&"line")
		if line.upgrade_id == upgrade_id:
			return row
	return null
