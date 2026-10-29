## Écran **FIN DE GARDE** (M12 lot C, I31 ; M12 §2.8) : titre et raison (trois
## erreurs / garde terminée à votre demande), score en grand, pastilles NOUVEAU
## RECORD / RECORD DU JOUR / PREMIER ESSAI DU JOUR (icône + texte), ligne
## « n directives · palier p · hh:mm · durée », les erreurs (passager, verdict
## rendu → attendu, citation, règle en cause), code partageable.
## Actions : REJOUER CETTE GARDE (focus) · NOUVELLE GRAINE · COPIER LE CODE ·
## RETOUR. Ⓑ / Échap = RETOUR (titre). Choix émis par `finished` :
## `&"replay"`, `&"new_seed"`, `&"title"`.
class_name GardeEndScreen
extends ScreenBase

## Résumé de la garde (`GardeRun.to_record()` + `clock_minute`).
var record: Dictionary = {}
## Pastilles du profil (`Campaign.finish_garde` : `new_record`, `daily_record`,
## `first_try`, `rank`).
var badges: Dictionary = {}
## Titres des règles (`rule_id` → clé de titre) pour la colonne « règle en cause ».
var rule_titles: Dictionary = {}
var replay_button: Button = null
var new_button: Button = null
var copy_button: Button = null
var back_button: Button = null
var toasts: ToastStack = null


func setup(p_record: Dictionary, p_badges: Dictionary = {}, p_rule_titles: Dictionary = {}) -> void:
	record = p_record
	badges = p_badges
	rule_titles = p_rule_titles


func code() -> String:
	return str(record.get("seed_code", ""))


func default_focus() -> Control:
	return replay_button


func _build() -> void:
	var root: VBoxContainer = ScreenBase.vbox(DS.SPACE_5)
	root_box().add_child(root)
	var top: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	root.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, DS.ICON_M))
	top.add_child(ScreenBase.eyebrow(UiText.tf("garde_end_eyebrow", [code()], "GARDE DE NUIT · %s"), DS.ACCENT_YELLOW))
	top.add_child(ScreenBase.spacer())
	if str(record.get("kind", "")) == String(GardeService.KIND_DAILY):
		top.add_child(ScreenBase.chip(UiText.t("garde_daily", "GRAINE DU JOUR"), UiIcon.Kind.LOGO, Palette.TEXT_SECONDARY))
	root.add_child(ScreenBase.rule_line(DS.YELLOW_24))
	var quit: bool = str(record.get("end_reason", "")) == String(GardeRun.END_QUIT)
	var title: Label = ScreenBase.label(UiText.t("garde_end_title", "FIN DE GARDE"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "EndTitle"
	root.add_child(title)
	var reason: Label = ScreenBase.label(UiText.t("garde_end_quit", "Garde terminée à votre demande.") if quit
			else UiText.t("garde_end_reason", "Trois erreurs. La relève arrive."), &"TitleLabel", Palette.TEXT_SECONDARY)
	reason.name = "Reason"
	root.add_child(reason)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Body"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var columns: HBoxContainer = ScreenBase.hbox(DS.SPACE_10)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	columns.add_child(_score_column())
	var errors: Control = _errors_column()
	errors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(errors)
	root.add_child(ScreenBase.rule_line())
	root.add_child(_footer())
	toasts = ToastStack.new()
	toasts.name = "Toasts"
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -(SaveSlotCard.MIN_WIDTH + DS.SPACE_8)
	toasts.offset_right = -DS.SPACE_8
	toasts.offset_top = DS.SPACE_8
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(toasts)
	replay_button.grab_focus.call_deferred()


func _score_column() -> Control:
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	col.custom_minimum_size.x = 520.0
	col.add_child(ScreenBase.eyebrow(UiText.t("garde_score_caption", "SCORE · PASSAGERS JUGÉS JUSTE")))
	var score: Label = ScreenBase.label(str(SaveService.as_int(record.get("score", 0))), &"DisplayLabel", DS.ACCENT_YELLOW)
	score.name = "Score"
	score.add_theme_font_size_override(&"font_size", roundi(DS.FS_DISPLAY_XL * 2 * Settings.text_scale))
	col.add_child(score)
	var chips: HFlowContainer = HFlowContainer.new()
	chips.name = "Badges"
	chips.add_theme_constant_override("h_separation", DS.SPACE_2)
	chips.add_theme_constant_override("v_separation", DS.SPACE_2)
	col.add_child(chips)
	if badges.get("new_record", false):
		chips.add_child(ScreenBase.chip(UiText.t("garde_record_new", "NOUVEAU RECORD"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW))
	if badges.get("daily_record", false) and str(record.get("kind", "")) == String(GardeService.KIND_DAILY):
		chips.add_child(ScreenBase.chip(UiText.t("garde_record_daily", "RECORD DU JOUR"), UiIcon.Kind.APPROVED, Palette.STATE_GREEN))
	if badges.get("first_try", false):
		chips.add_child(ScreenBase.chip(UiText.tf("garde_first_try", [SaveService.as_int(record.get("score", 0))], "PREMIER ESSAI DU JOUR · %d"),
				UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN))
	var line: Label = ScreenBase.wrapped(summary_line(record), &"DataSmall", Palette.TEXT_SECONDARY)
	line.name = "SummaryLine"
	col.add_child(line)
	var share: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	share.name = "Share"
	var share_box: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	share.add_child(share_box)
	share_box.add_child(ScreenBase.eyebrow(UiText.t("garde_share", "CODE À PARTAGER")))
	var code_label: Label = ScreenBase.label(code(), &"DataTitle", DS.TEXT_PRIMARY)
	code_label.name = "Code"
	share_box.add_child(code_label)
	share_box.add_child(ScreenBase.wrapped(UiText.t("garde_share_hint", "Mêmes passagers, mêmes directives : comparez vos scores."), &"CaptionLabel"))
	col.add_child(share)
	return col


## « 9 directives · palier 2 · 03:18 · 37 min ».
static func summary_line(p_record: Dictionary) -> String:
	var parts: PackedStringArray = [
		UiText.plural("garde_end_directives", SaveService.as_int(p_record.get("directives", 0)), "%d directive", "%d directives"),
		UiText.tf("garde_end_tier", [SaveService.as_int(p_record.get("palier", 0))], "palier %d"),
	]
	if p_record.has("clock_minute"):
		parts.append(UiText.clock(posmod(SaveService.as_int(p_record["clock_minute"]), 24 * 60)))
	parts.append(SaveSlotCard.format_play_time(SaveService.as_int(p_record.get("duration_sec", 0))))
	return " · ".join(parts)


func _errors_column() -> Control:
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	col.name = "Errors"
	var errors: Array = record.get("errors", []) if record.get("errors") is Array else []
	col.add_child(ScreenBase.section(UiText.t("garde_end_errors", "LES ERREURS"), UiIcon.Kind.DENIED, Palette.STATE_RED,
			"%d" % errors.size()))
	if errors.is_empty():
		col.add_child(ScreenBase.wrapped(UiText.t("garde_end_no_error", "Aucune erreur."), &"BodySmall"))
	for value: Variant in errors:
		if value is Dictionary:
			col.add_child(error_row(value, rule_titles))
	return col


## Une erreur : passager, verdict rendu → attendu, citation, règle en cause.
static func error_row(error: Dictionary, titles: Dictionary = {}) -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "Error_%d" % SaveService.as_int(error.get("passenger", 0))
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	card.add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.DENIED, Palette.STATE_RED, DS.ICON_S))
	head.add_child(ScreenBase.label(UiText.tf("garde_end_passenger", [SaveService.as_int(error.get("passenger", 0))], "PASSAGER %d"),
			&"DocFieldLabel", Palette.STATE_RED))
	var who: String = str(error.get("label", ""))
	if not who.is_empty():
		head.add_child(ScreenBase.label(who, &"DataSmall", Palette.TEXT_SECONDARY))
	head.add_child(ScreenBase.spacer())
	head.add_child(ScreenBase.label(UiText.tf("garde_end_verdicts", [verdict_text(str(error.get("verdict", ""))),
			verdict_text(str(error.get("expected", "")))], "%s → %s"), &"DataSmall", DS.TEXT_PRIMARY))
	var citation: String = str(error.get("citation", ""))
	box.add_child(ScreenBase.wrapped(UiText.t(citation, citation), &"BodyStrong", DS.TEXT_PRIMARY))
	var rule_id: String = str(error.get("rule_id", ""))
	if not rule_id.is_empty():
		var title_key: String = str(titles.get(rule_id, ""))
		box.add_child(ScreenBase.wrapped(UiText.tf("garde_end_rule", [UiText.t(title_key, rule_id) if not title_key.is_empty() else rule_id],
				"Règle en cause : %s"), &"BodySmall"))
	return card


## « APPROUVÉ », « REFUSÉ », « DÉTENTION » (noms de `SlippedItem.VERDICT_NAMES`).
static func verdict_text(name: String) -> String:
	return UiText.t("stamp_%s" % name, name.to_upper()) if not name.is_empty() else "—"


func _footer() -> Control:
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("garde_end_back_hint", "titre"), &"CaptionLabel"))
	foot.add_child(keys)
	foot.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("garde_back", "RETOUR"), &"ButtonGhost")
	back_button.name = "Back"
	back_button.pressed.connect(close.bind(&"title"))
	foot.add_child(back_button)
	copy_button = ScreenBase.button(UiText.t("garde_copy", "COPIER LE CODE"), &"ButtonTool")
	copy_button.name = "Copy"
	copy_button.pressed.connect(copy_code)
	foot.add_child(copy_button)
	new_button = ScreenBase.button(UiText.t("garde_new", "NOUVELLE GRAINE"), &"ButtonTool")
	new_button.name = "NewSeed"
	new_button.pressed.connect(close.bind(&"new_seed"))
	foot.add_child(new_button)
	replay_button = ScreenBase.button(UiText.t("garde_replay", "REJOUER CETTE GARDE"), &"ButtonPrimary")
	replay_button.name = "Replay"
	replay_button.custom_minimum_size.x = 320.0
	replay_button.pressed.connect(close.bind(&"replay"))
	foot.add_child(replay_button)
	return foot


## Copie le code dans le presse-papiers (si la plateforme en a un) ; toast.
func copy_code() -> bool:
	var copied: bool = DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if copied:
		DisplayServer.clipboard_set(code())
	if toasts != null:
		toasts.push(ToastStack.Kind.INFO, UiText.t("garde_copied", "CODE COPIÉ") if copied else UiText.t("garde_copy_none", "CODE"), code())
	return copied


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		close(&"title")
		get_viewport().set_input_as_handled()
