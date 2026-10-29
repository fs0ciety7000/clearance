## Carte d'un emplacement de sauvegarde (M11 lot C, UI_FLOW §8.5) : partagée
## par « Nouvelle partie » et « Charger ». Lit la méta de
## `SaveService.list_slots()` (ARCHITECTURE §10.1) : emplacement, difficulté
## (puce texte + icône), jour et acte (ou « PARTIE TERMINÉE » + nom de la fin),
## crédits, foyer (vivants / malades / absents), date de sauvegarde, temps de
## jeu. Emplacement libre : « EMPLACEMENT LIBRE ». Les boutons d'action sont
## ajoutés par l'écran dans `actions`.
## QA-043 (UI) : emplacement marqué endommagé par `list_slots()` (clé
## booléenne `damaged`, lue de façon défensive) → puce « SAUVEGARDE
## ENDOMMAGÉE » (icône + texte) ; l'écran désactive REPRENDRE, garde SUPPRIMER,
## et « Continuer » l'ignore (`continue_slot`).
## M12 (lot C, I29) : partie terminée dont la fin ouvre l'épilogue (méta
## `epilogue_available`) → puce « ÉPILOGUE » (icône + texte), « · JOUÉ » si
## `epilogue_done` ; l'écran Charger ajoute l'action « JOUER « UN AN PLUS TARD » ».
class_name SaveSlotCard
extends PanelContainer

## Largeur minimale d'une carte (trois côte à côte en 1920 logiques).
const MIN_WIDTH: float = 440.0

var slot: int = 0
var meta: Dictionary = {}
## Rangée (colonne) des boutons d'action de l'écran.
var actions: VBoxContainer = null


static func make(p_slot: int, p_meta: Dictionary) -> SaveSlotCard:
	var card: SaveSlotCard = SaveSlotCard.new()
	card.slot = p_slot
	card.meta = p_meta
	card.name = "Slot%d" % p_slot
	card._build()
	return card


func is_free() -> bool:
	return meta.is_empty()


func is_ended() -> bool:
	return not is_free() and not is_damaged() and str(meta.get("status", SaveService.STATUS_ACTIVE)) == SaveService.STATUS_ENDED


func is_damaged() -> bool:
	return is_meta_damaged(meta)


## M12 : partie terminée avec épilogue J31 disponible (méta `epilogue_available`).
func has_epilogue() -> bool:
	return is_ended() and _meta_true(meta.get(SaveService.KEY_EPILOGUE_AVAILABLE, false))


## M12 : épilogue déjà joué depuis cet emplacement (méta `epilogue_done`).
func epilogue_done() -> bool:
	return _meta_true(meta.get(SaveService.KEY_EPILOGUE_DONE, false))


static func _meta_true(value: Variant) -> bool:
	return (value is bool and value) or ((value is int or value is float) and SaveService.as_int(value) != 0)


## Méta d'emplacement marquée endommagée (`damaged` vrai ; lecture défensive :
## booléen, ou entier non nul d'un JSON).
static func is_meta_damaged(p_meta: Dictionary) -> bool:
	var value: Variant = p_meta.get("damaged", false)
	return (value is bool and value) or ((value is int or value is float) and SaveService.as_int(value) != 0)


## Emplacement de « Continuer » côté interface : `SaveService.latest_slot`,
## mais jamais un emplacement endommagé (partie active suivante la plus
## récente, même ordre que `latest_slot` : `saved_at`, `saved_unix_ms`,
## `save_serial`), sinon `NO_SLOT`.
static func continue_slot(dir: String = SaveService.DEFAULT_DIR) -> int:
	var latest: int = SaveService.latest_slot(dir)
	if latest == SaveService.NO_SLOT:
		return latest
	var metas: Array[Dictionary] = SaveService.list_slots(dir)
	if latest - 1 < metas.size() and not is_meta_damaged(metas[latest - 1]):
		return latest
	var best: int = SaveService.NO_SLOT
	var best_key: String = ""
	for m: Dictionary in metas:
		if m.is_empty() or is_meta_damaged(m) or str(m.get("status", SaveService.STATUS_ACTIVE)) != SaveService.STATUS_ACTIVE:
			continue
		var key: String = "%s|%015d|%09d" % [str(m.get("saved_at", "")), SaveService.as_int(m.get("saved_unix_ms", 0)),
				SaveService.as_int(m.get("save_serial", 0))]
		if best == SaveService.NO_SLOT or key > best_key:
			best = SaveService.as_int(m.get("slot", SaveService.NO_SLOT))
			best_key = key
	return best


func _build() -> void:
	theme_type_variation = &"ElevatedCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = MIN_WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(ScreenBase.eyebrow(UiText.tf("slot_title", [slot], "EMPLACEMENT %d"), Palette.TEXT_SECONDARY))
	head.add_child(ScreenBase.spacer())
	if is_free():
		box.add_child(ScreenBase.label(UiText.t("slot_free", "EMPLACEMENT LIBRE"), &"TitleLabel", Palette.TEXT_SECONDARY))
		box.add_child(ScreenBase.wrapped(UiText.t("slot_free_hint", "Aucune partie enregistrée ici."), &"BodySmall"))
	elif is_damaged():
		if meta.has("difficulty"):
			head.add_child(difficulty_chip(str(meta.get("difficulty", SaveService.DIFFICULTY_HARD))))
		_build_damaged(box)
	else:
		head.add_child(difficulty_chip(str(meta.get("difficulty", SaveService.DIFFICULTY_HARD))))
		_build_summary(box)
	box.add_child(ScreenBase.spacer(false, true))
	actions = ScreenBase.vbox(DS.SPACE_2)
	actions.name = "Actions"
	box.add_child(actions)


func _build_summary(box: VBoxContainer) -> void:
	var day: int = SaveService.as_int(meta.get("current_day", 0))
	var act: int = clampi(SaveService.as_int(meta.get("act", 1), 1), 1, 3)
	if is_ended():
		var chips: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		box.add_child(chips)
		chips.add_child(ScreenBase.chip(UiText.t("slot_ended", "PARTIE TERMINÉE"), UiIcon.Kind.STRIKE, Palette.TEXT_SECONDARY))
		if has_epilogue():
			var text: String = UiText.t("load_badge_epilogue", "ÉPILOGUE")
			if epilogue_done():
				text = UiText.tf("load_badge_epilogue_done", [text], "%s · JOUÉ")
			var epi_chip: PanelContainer = ScreenBase.chip(text, UiIcon.Kind.AWAY, DS.ACCENT_CYAN)
			epi_chip.name = "EpilogueChip"
			chips.add_child(epi_chip)
		var ending: Label = ScreenBase.wrapped(UiText.tf("slot_ending", [ending_name(str(meta.get("ending_id", "")), act)], "Fin : %s"),
				&"BodyStrong", DS.TEXT_PRIMARY)
		ending.name = "Ending"
		box.add_child(ending)
		box.add_child(ScreenBase.label(UiText.tf("slot_day_act_last", [day, act_roman(act)], "Dernier jour : %02d · Acte %s"),
				&"DataSmall", Palette.TEXT_SECONDARY))
	else:
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
		box.add_child(row)
		var day_label: Label = ScreenBase.label(UiText.tf("slot_day", [day], "JOUR %02d"), &"TitleLabel", DS.TEXT_PRIMARY)
		day_label.name = "Day"
		row.add_child(day_label)
		var act_label: Label = ScreenBase.label(UiText.tf("slot_act", [act_roman(act)], "ACTE %s"), &"DocFieldLabel", Palette.TEXT_SECONDARY)
		act_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(act_label)
	box.add_child(ScreenBase.rule_line())
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_1)
	box.add_child(grid)
	_pair(grid, UiText.t("slot_credits", "CRÉDITS"), "₵ %d" % SaveService.as_int(meta.get("credits", 0)))
	_pair(grid, UiText.t("slot_household", "FOYER"), household_text(meta.get("household_summary", {})))
	_pair(grid, UiText.t("slot_saved_at", "ENREGISTRÉ"), format_saved_at(str(meta.get("saved_at", ""))))
	_pair(grid, UiText.t("slot_play_time", "TEMPS DE JEU"), format_play_time(SaveService.as_int(meta.get("play_time_sec", 0))))


## Emplacement endommagé : puce rouge (icône + texte, jamais la couleur seule),
## explication, dernier jour connu si la méta le donne.
func _build_damaged(box: VBoxContainer) -> void:
	var chip: PanelContainer = ScreenBase.chip(UiText.t("slot_damaged", "SAUVEGARDE ENDOMMAGÉE"), UiIcon.Kind.WARNING, Palette.STATE_RED)
	chip.name = "Damaged"
	box.add_child(chip)
	var day: int = SaveService.as_int(meta.get("current_day", 0))
	if day > 0:
		box.add_child(ScreenBase.label(UiText.tf("slot_damaged_day", [day], "Dernier jour connu : %02d"), &"DataSmall", Palette.TEXT_SECONDARY))
	box.add_child(ScreenBase.wrapped(UiText.t("slot_damaged_hint",
			"Le fichier de cette partie est illisible. Reprenez un jour passé s'il en reste, ou supprimez l'emplacement."), &"BodySmall"))
	if meta.has("saved_at"):
		box.add_child(ScreenBase.rule_line())
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", DS.SPACE_3)
		grid.add_theme_constant_override("v_separation", DS.SPACE_1)
		box.add_child(grid)
		_pair(grid, UiText.t("slot_saved_at", "ENREGISTRÉ"), format_saved_at(str(meta.get("saved_at", ""))))


func _pair(grid: GridContainer, caption: String, value: String) -> void:
	grid.add_child(ScreenBase.eyebrow(caption))
	var v: Label = ScreenBase.wrapped(value, &"DataSmall", DS.TEXT_PRIMARY)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)


## Bouton d'action ajouté à la carte (focus manette, cible ≥ 40 px).
func add_action(text: String, variation: StringName = &"ButtonTool") -> Button:
	var b: Button = ScreenBase.button(text, variation)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(b)
	return b


# ---------------------------------------------------------------------------
# Textes (statiques, testables)
# ---------------------------------------------------------------------------

## Puce de difficulté : texte + icône (jamais la couleur seule, DS §2.5).
static func difficulty_chip(difficulty: String) -> PanelContainer:
	if difficulty == SaveService.DIFFICULTY_STORY:
		return ScreenBase.chip(UiText.t("diff_story_short", "RÉCIT"), UiIcon.Kind.CHAT, Palette.TEXT_SECONDARY)
	return ScreenBase.chip(UiText.t("diff_hard_short", "DUR"), UiIcon.Kind.WARNING, Palette.TEXT_SECONDARY)


static func act_roman(act: int) -> String:
	return ["I", "II", "III"][clampi(act, 1, 3) - 1]


## « 4 vivants · 1 malade · 1 absent·e ».
static func household_text(summary: Variant) -> String:
	var data: Dictionary = summary if summary is Dictionary else {}
	var alive: int = SaveService.as_int(data.get("alive", 0))
	var parts: PackedStringArray = [UiText.plural("slot_alive", alive, "%d vivant", "%d vivants")]
	var sick: int = SaveService.as_int(data.get("sick", 0))
	if sick > 0:
		parts.append(UiText.plural("slot_sick", sick, "%d malade", "%d malades"))
	var absent: int = SaveService.as_int(data.get("absent", 0))
	if absent > 0:
		parts.append(UiText.plural("slot_absent", absent, "%d absent·e", "%d absent·es"))
	return " · ".join(parts)


## Horodatage UTC de `saved_at` en heure locale : « 29.10.2026 · 14:32 ».
static func format_saved_at(saved_at: String) -> String:
	if saved_at.is_empty():
		return "—"
	var unix: int = Time.get_unix_time_from_datetime_string(saved_at)
	if unix <= 0:
		return saved_at
	unix += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	return "%02d.%02d.%04d · %02d:%02d" % [int(d["day"]), int(d["month"]), int(d["year"]), int(d["hour"]), int(d["minute"])]


## « 2 h 05 », « 14 min », « < 1 min ».
static func format_play_time(seconds: int) -> String:
	var minutes: int = maxi(seconds, 0) / 60
	if minutes < 1:
		return UiText.t("slot_time_none", "< 1 min")
	if minutes < 60:
		return UiText.tf("slot_time_min", [minutes], "%d min")
	return UiText.tf("slot_time_h", [minutes / 60, minutes % 60], "%d h %02d")


## Nom de la fin archivée, d'après l'acte où elle survient (titres d'épilogue
## `end3_` / `end2_` / `end_`), sinon l'identifiant.
static func ending_name(ending_id: String, act: int = 1) -> String:
	if ending_id.is_empty():
		return "—"
	var short: String = ending_id.get_slice("_", 0)
	var keys: PackedStringArray = []
	if act >= 3:
		keys.append("end3_%s_title" % short)
	if act >= 2:
		keys.append("end2_%s_title" % short)
	keys.append("end_%s_title" % short)
	keys.append("end_title_%s" % ending_id)
	for key: String in keys:
		if UiText.has(key):
			return UiText.t(key, ending_id)
	return ending_id.to_upper()
