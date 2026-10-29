## Accueil de la **Garde de nuit** (M12 lot C, I31 ; M12 §2.2, §2.6, §2.7 ;
## D-121, D-126 → D-128) — ouvert depuis le titre.
## - **Graine du jour** `NUIT-AAAA-MM-JJ` (date **UTC**, mention discrète) :
##   record du jour, premier essai, essais ; « JOUER LA GRAINE DU JOUR » (focus).
## - **Graine libre** : saisie d'un code de 6 caractères de l'alphabet des N° ID
##   (casse et tiret indifférents ; O, I, 0, 1 refusés avec le message
##   `garde_seed_invalid`), validation en direct (icône + texte), « JOUER CE
##   CODE » actif seulement si le code est valide ; « TIRER AU HASARD ».
## - **Records** (profil) : meilleur score, 10 meilleures gardes (« ancienne
##   garde » si `garde_version` diffère), statistiques.
## Ⓑ / Échap : retour au titre (`finished(&"back")`). `start_requested(code)` :
## le titre lance la garde (`Campaign.start_garde`).
class_name GardeScreen
extends ScreenBase

signal start_requested(code: String)

## Le titre ouvre cet écran à son arrivée (« NOUVELLE GRAINE » depuis la fin de garde).
static var open_on_title: bool = false

const RECORDS_WIDTH: float = 600.0

## Dossier du profil (tests : dossier isolé).
var save_dir: String = SaveService.DEFAULT_DIR
## Profil lu à l'ouverture (injectable).
var profile: Dictionary = {}
## Code de la graine du jour (injectable : tests autour de minuit UTC).
var daily_code: String = ""
var daily_button: Button = null
var code_input: LineEdit = null
var play_code_button: Button = null
var random_button: Button = null
var back_button: Button = null
## Code libre canonique saisi (vide si invalide).
var free_code: String = ""
var _status_label: Label = null
var _status_icon: UiIcon = null


func _build() -> void:
	if profile.is_empty():
		profile = ProfileService.load_profile(save_dir)
	if daily_code.is_empty():
		daily_code = GardeService.today_code()
	var root: VBoxContainer = ScreenBase.vbox(DS.SPACE_6)
	root_box().add_child(root)
	var head: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	root.add_child(head)
	head.add_child(ScreenBase.eyebrow(UiText.t("garde_eyebrow", "HALCYON GATE · ROTATIONS DE NUIT"), DS.ACCENT_YELLOW))
	head.add_child(ScreenBase.label(UiText.t("garde_title", "GARDE DE NUIT"), &"DisplayLabel", DS.TEXT_PRIMARY))
	head.add_child(ScreenBase.wrapped(UiText.t("garde_tagline", "Une directive toutes les cinq personnes. Trois erreurs, et la relève arrive."),
			&"BodyLabel", Palette.TEXT_SECONDARY))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Body"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var columns: HBoxContainer = ScreenBase.hbox(DS.SPACE_8)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	var left: VBoxContainer = ScreenBase.vbox(DS.SPACE_5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_daily_card())
	left.add_child(_free_card())
	var right: VBoxContainer = _records()
	right.custom_minimum_size.x = RECORDS_WIDTH
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	root.add_child(foot)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("ng_back_hint", "retour"), &"CaptionLabel"))
	foot.add_child(keys)
	foot.add_child(ScreenBase.label(UiText.t("garde_no_save", "Pas de sauvegarde en cours de garde : le score est enregistré à la fin."),
			&"CaptionLabel"))
	foot.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("ng_back", "RETOUR"), &"ButtonGhost")
	back_button.name = "Back"
	back_button.pressed.connect(go_back)
	foot.add_child(back_button)
	_validate("")
	daily_button.grab_focus.call_deferred()


func default_focus() -> Control:
	return daily_button


# ---------------------------------------------------------------------------
# Graine du jour
# ---------------------------------------------------------------------------

func _daily_card() -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "Daily"
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	card.add_child(box)
	box.add_child(ScreenBase.section(UiText.t("garde_daily", "GRAINE DU JOUR"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	box.add_child(row)
	var code: Label = ScreenBase.label(daily_code, &"DataTitle", DS.TEXT_PRIMARY)
	code.name = "DailyCode"
	row.add_child(code)
	var utc: Label = ScreenBase.label(UiText.t("garde_daily_utc", "UTC · la même pour tout le monde"), &"CaptionLabel")
	utc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(utc)
	var info: Label = ScreenBase.wrapped(daily_summary(profile, daily_code), &"BodySmall", Palette.TEXT_SECONDARY)
	info.name = "DailyRecord"
	box.add_child(info)
	daily_button = ScreenBase.button(UiText.t("garde_play_daily", "JOUER LA GRAINE DU JOUR"), &"ButtonPrimary")
	daily_button.name = "PlayDaily"
	daily_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	daily_button.custom_minimum_size.x = 360.0
	daily_button.pressed.connect(func() -> void: start(daily_code))
	box.add_child(daily_button)
	return card


## « Record du jour : 14 · premier essai : 9 · 3 essais » (version courante),
## sinon « Pas encore jouée aujourd'hui. ».
static func daily_summary(p_profile: Dictionary, code: String) -> String:
	var date: String = GardeService.daily_date(code)
	var daily: Dictionary = p_profile.get("garde_daily", {}) if p_profile.get("garde_daily") is Dictionary else {}
	var entry: Dictionary = daily.get(date, {}) if daily.get(date) is Dictionary else {}
	if entry.is_empty() or SaveService.as_int(entry.get("garde_version", 1), 1) != current_version():
		return UiText.t("garde_daily_none", "Pas encore jouée aujourd'hui.")
	return UiText.tf("garde_daily_record", [SaveService.as_int(entry.get("best", 0)), SaveService.as_int(entry.get("first_try", 0)),
			SaveService.as_int(entry.get("attempts", 0))], "Record du jour : %d · premier essai : %d · %d essai(s)")


## `garde_version` des données (1 sans données).
static func current_version() -> int:
	var def: GardeDef = GardeService.load_def()
	return def.version if def != null else 1


# ---------------------------------------------------------------------------
# Graine libre
# ---------------------------------------------------------------------------

func _free_card() -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "Free"
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	card.add_child(box)
	box.add_child(ScreenBase.section(UiText.t("garde_free", "GRAINE LIBRE"), UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY))
	box.add_child(ScreenBase.label(UiText.t("garde_seed_input", "Code de garde (6 caractères)"), &"BodySmall"))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	box.add_child(row)
	code_input = LineEdit.new()
	code_input.name = "CodeInput"
	code_input.placeholder_text = UiText.t("garde_seed_placeholder", "K2Q-9TX")
	code_input.max_length = 15
	code_input.custom_minimum_size = Vector2(240.0, DS.HIT_TARGET_MIN)
	code_input.focus_mode = Control.FOCUS_ALL
	code_input.text_changed.connect(_validate)
	code_input.text_submitted.connect(func(_text: String) -> void: play_free())
	row.add_child(code_input)
	play_code_button = ScreenBase.button(UiText.t("garde_play_code", "JOUER CE CODE"), &"ButtonTool")
	play_code_button.name = "PlayCode"
	play_code_button.pressed.connect(play_free)
	row.add_child(play_code_button)
	random_button = ScreenBase.button(UiText.t("garde_random", "TIRER AU HASARD"), &"ButtonGhost")
	random_button.name = "Random"
	random_button.pressed.connect(func() -> void: fill_random())
	row.add_child(random_button)
	var status: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	status.name = "Status"
	box.add_child(status)
	_status_icon = UiIcon.make(UiIcon.Kind.INFO, Palette.TEXT_SECONDARY, DS.ICON_S)
	status.add_child(_status_icon)
	_status_label = ScreenBase.wrapped("", &"BodySmall", Palette.TEXT_SECONDARY)
	_status_label.name = "StatusText"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_status_label)
	return card


## Clé du message d'erreur d'un code refusé (QA-055) : la raison renvoyée par
## `GardeService.normalize_code` (`error_key` : caractère interdit, caractère
## hors alphabet, date `NUIT-…` impossible) ; l'erreur de longueur
## (`ERROR_BAD_LENGTH`, clé de l'intitulé du champ) devient `garde_seed_length`.
static func seed_error_key(service_key: String) -> String:
	if service_key.is_empty() or service_key == GardeService.ERROR_BAD_LENGTH:
		return "garde_seed_length"
	return service_key


## Texte d'une clé de `seed_error_key` (repli : la clé de longueur).
static func seed_error_text(key: String) -> String:
	match key:
		GardeService.ERROR_INVALID_CHARS:
			return UiText.t(key, "Les codes n'utilisent ni O, ni I, ni 0, ni 1.")
		GardeService.ERROR_BAD_DATE:
			return UiText.t(key, "Date invalide : NUIT-AAAA-MM-JJ, une vraie date du calendrier.")
		GardeService.ERROR_BAD_CHAR:
			return UiText.t(key, "Caractère non admis : lettres A–Z et chiffres 2–9 seulement.")
		"garde_seed_length":
			return UiText.t(key, "Il faut 6 caractères (le tiret ne compte pas).")
	if UiText.has(key):
		return UiText.t(key)
	return UiText.t("garde_seed_length", "Il faut 6 caractères (le tiret ne compte pas).")


## Validation en direct de la saisie : code canonique (`free_code`), message
## (aide, erreur `garde_seed_invalid` / longueur, ou code reconnu) et état de
## « JOUER CE CODE ».
func _validate(text: String) -> void:
	var raw: String = text.strip_edges()
	var result: Dictionary = GardeService.normalize_code(raw) if not raw.is_empty() else {"ok": false, "error_key": ""}
	free_code = str(result.get("code", "")) if result.get("ok", false) else ""
	var kind: UiIcon.Kind = UiIcon.Kind.INFO
	var color: Color = Palette.TEXT_SECONDARY
	var message: String = UiText.t("garde_seed_help", "6 caractères : A–Z et 2–9, sans O, I, 0 ni 1. Tiret et casse indifférents.")
	if not free_code.is_empty():
		kind = UiIcon.Kind.APPROVED
		color = Palette.STATE_GREEN
		message = UiText.tf("garde_seed_ok", [free_code], "Code reconnu : %s")
	elif not raw.is_empty():
		var key: String = seed_error_key(str(result.get("error_key", "")))
		if key == "garde_seed_length":
			kind = UiIcon.Kind.WARNING
			color = Palette.STATE_AMBER
		else:
			kind = UiIcon.Kind.DENIED
			color = Palette.STATE_RED
		message = seed_error_text(key)
	if _status_icon != null:
		_status_icon.kind = kind
		_status_icon.color = color
		_status_label.text = message
		_status_label.add_theme_color_override(&"font_color", color)
	if play_code_button != null:
		play_code_button.disabled = free_code.is_empty()
		play_code_button.theme_type_variation = &"ButtonPrimary" if not free_code.is_empty() else &"ButtonTool"


## Message de validation affiché (tests).
func status_text() -> String:
	return _status_label.text if _status_label != null else ""


## Saisie d'un code (tests, presse-papiers) ; validée comme au clavier.
func set_code_text(text: String) -> void:
	code_input.text = text
	_validate(text)


## Code libre au hasard dans la saisie (`entropy` ≠ 0 : reproductible).
func fill_random(entropy: int = 0) -> String:
	var code: String = GardeService.random_code(entropy)
	set_code_text(code)
	play_code_button.grab_focus.call_deferred()
	return code


func play_free() -> void:
	if free_code.is_empty():
		_validate(code_input.text)
		return
	start(free_code)


func start(code: String) -> void:
	if is_closing():
		return
	start_requested.emit(code)


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

func _records() -> VBoxContainer:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	box.name = "Records"
	var runs: Array = profile.get("best_runs", []) if profile.get("best_runs") is Array else []
	var version: int = current_version()
	var best: int = -1
	for row: Variant in runs:
		if row is Dictionary and SaveService.as_int((row as Dictionary).get("garde_version", 1), 1) == version:
			best = maxi(best, SaveService.as_int((row as Dictionary).get("score", 0)))
	box.add_child(ScreenBase.section(UiText.t("garde_records", "RECORDS"), UiIcon.Kind.REGISTER, Palette.TEXT_SECONDARY))
	if runs.is_empty():
		box.add_child(ScreenBase.wrapped(UiText.t("garde_records_none", "Aucune garde enregistrée. La première fixe le record."), &"BodySmall"))
		return box
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	box.add_child(head)
	head.add_child(ScreenBase.stat_tile(UiText.t("garde_best", "MEILLEUR SCORE"), str(maxi(best, 0)),
			UiText.t("garde_best_detail", "passagers jugés juste"), DS.ACCENT_YELLOW, UiIcon.Kind.LOGO))
	var stats: Dictionary = profile.get("garde_stats", {}) if profile.get("garde_stats") is Dictionary else {}
	head.add_child(ScreenBase.stat_tile(UiText.t("garde_stats", "GARDES"), str(SaveService.as_int(stats.get("runs", 0))),
			UiText.tf("garde_stats_detail", [SaveService.as_int(stats.get("total_correct", 0)), SaveService.as_int(stats.get("longest_run", 0))],
			"%d verdicts justes · plus longue : %d passagers"), DS.TEXT_PRIMARY, UiIcon.Kind.DIAMOND))
	box.add_child(run_table(runs, version))
	return box


## Tableau des 10 meilleures gardes : rang, score, code, date, palier,
## directives ; « ancienne garde » (icône + texte) si la version diffère.
static func run_table(runs: Array, version: int) -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "BestRuns"
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", DS.SPACE_4)
	grid.add_theme_constant_override("v_separation", DS.SPACE_1)
	card.add_child(grid)
	for key: String in ["garde_col_rank", "garde_col_score", "garde_col_code", "garde_col_date", "garde_col_tier"]:
		grid.add_child(ScreenBase.eyebrow(UiText.t(key, key.trim_prefix("garde_col_"))))
	var rank: int = 0
	for value: Variant in runs:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		rank += 1
		var old: bool = SaveService.as_int(row.get("garde_version", 1), 1) != version
		grid.add_child(ScreenBase.label("%02d" % rank, &"DataSmall", Palette.TEXT_SECONDARY))
		grid.add_child(ScreenBase.label(str(SaveService.as_int(row.get("score", 0))), &"DataSmall",
				DS.TEXT_MUTED if old else DS.ACCENT_YELLOW))
		var code_box: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
		code_box.add_child(ScreenBase.label(str(row.get("seed_code", "—")), &"DataSmall", DS.TEXT_PRIMARY))
		if old:
			var chip: PanelContainer = ScreenBase.chip(UiText.t("garde_old_version", "ancienne garde"), UiIcon.Kind.STRIKE, Palette.TEXT_SECONDARY)
			chip.name = "OldVersion"
			code_box.add_child(chip)
		grid.add_child(code_box)
		grid.add_child(ScreenBase.label(str(row.get("date", "")), &"DataSmall", Palette.TEXT_SECONDARY))
		grid.add_child(ScreenBase.label(UiText.tf("garde_row_tier", [SaveService.as_int(row.get("palier", 0)),
				SaveService.as_int(row.get("directives", 0))], "P%d · %d dir."), &"DataSmall", Palette.TEXT_SECONDARY))
	return card


# ---------------------------------------------------------------------------
# Retour
# ---------------------------------------------------------------------------

func go_back() -> void:
	close(&"back")


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		go_back()
		get_viewport().set_input_as_handled()
