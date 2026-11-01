## **Classement en ligne** d'une graine de Garde (M16, D-233 ; UI_FLOW §8.10)
## — accueil de la Garde (graine du jour) et écran FIN DE GARDE.
## - Sans compte : une ligne (« Classement en ligne : Options › Compte »),
##   aucune requête (les records locaux restent à côté).
## - Connecté·e : top 10 (`OnlineConfig.LEADERBOARD_LIMIT`) — rang, agent
##   (pseudo, sinon « Agent·e #tag »), score, erreurs — la ligne du joueur
##   marquée (losange + cyan + « VOUS »), puis « Votre rang : n / total » même
##   hors du top 10. Lu depuis le cache local tout de suite, puis relu
##   (`OnlineService.fetch_leaderboard`, `leaderboard_updated`).
## - Hors ligne : dernier classement connu (mention « hors ligne ») ou
##   « Hors ligne : records locaux seulement. ».
## Une garde envoyée (`garde_submitted`) relance la lecture.
class_name LeaderboardView
extends VBoxContainer

## Largeur minimale de la colonne AGENT (px @1080p ; pseudo de 20 caractères tronqué « … »).
const NAME_COLUMN_WIDTH: float = 180.0

var seed_code: String = ""
var version: int = 1
## Titre de la section (vide : « CLASSEMENT EN LIGNE »).
var title_text: String = ""
var _rows: VBoxContainer = null
var _note: Label = null
var _data: Dictionary = {}
var _offline: bool = false


static func make(p_seed: String, p_version: int, p_title: String = "") -> LeaderboardView:
	var view: LeaderboardView = LeaderboardView.new()
	view.seed_code = p_seed
	view.version = p_version
	view.title_text = p_title
	return view


func _ready() -> void:
	name = "Leaderboard"
	add_theme_constant_override("separation", DS.SPACE_2)
	var title: String = title_text if not title_text.is_empty() else UiText.t("lb_title", "CLASSEMENT EN LIGNE")
	add_child(ScreenBase.section(title, UiIcon.Kind.SCALES, DS.ACCENT_CYAN, seed_code))
	_rows = ScreenBase.vbox(DS.SPACE_1)
	_rows.name = "Rows"
	add_child(_rows)
	_note = ScreenBase.wrapped("", &"CaptionLabel", Palette.TEXT_SECONDARY)
	_note.name = "Note"
	add_child(_note)
	OnlineService.leaderboard_updated.connect(_on_updated)
	OnlineService.leaderboard_failed.connect(_on_failed)
	OnlineService.garde_submitted.connect(func(_key: String, _result: Dictionary) -> void: refresh())
	OnlineService.account_changed.connect(refresh)
	_data = (OnlineService.cached_leaderboard(seed_code, version).get("data", {}) as Dictionary).duplicate(true)
	_render()
	refresh()


## Relit le classement (compte seulement ; jamais pendant un shift).
func refresh() -> void:
	if not is_inside_tree():
		return
	if not OnlineService.has_account():
		_render()
		return
	OnlineService.request_leaderboard(seed_code, version)


func _on_updated(key: String, data: Dictionary) -> void:
	if key == OnlineClient.board_key(seed_code, version) and is_inside_tree():
		_data = data.duplicate(true)
		_offline = false
		_render()


func _on_failed(key: String) -> void:
	if key == OnlineClient.board_key(seed_code, version) and is_inside_tree():
		_offline = true
		_render()


## Lignes affichées (tests) : `[{rank, name, score, errors, is_me}]`.
func shown_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entries: Array = _data.get("entries", []) if _data.get("entries") is Array else []
	for value: Variant in entries:
		if value is Dictionary:
			var entry: Dictionary = value
			out.append({"rank": SaveService.as_int(entry.get("rank", 0)), "name": OnlineText.board_name(entry),
					"score": SaveService.as_int(entry.get("score", 0)), "errors": SaveService.as_int(entry.get("errors", 0)),
					"is_me": entry.get("is_me", false) == true})
	return out


func note_text() -> String:
	return _note.text if _note != null else ""


func _render() -> void:
	for child: Node in _rows.get_children():
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	if not OnlineService.has_account():
		_note.text = UiText.t("lb_no_account", "Classement en ligne : connectez-vous dans Options › Compte. Vos records locaux restent ici.")
		return
	var entries: Array[Dictionary] = shown_entries()
	if _data.is_empty():
		_note.text = UiText.t("lb_offline_none", "Hors ligne : records locaux seulement.") if _offline \
				else UiText.t("lb_loading", "Lecture du classement…")
		return
	if entries.is_empty():
		_note.text = UiText.t("lb_empty", "Personne n'a encore joué cette graine. Le premier score fixe le classement.")
		return
	var grid: GridContainer = GridContainer.new()
	grid.name = "Table"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", DS.SPACE_4)
	grid.add_theme_constant_override("v_separation", DS.SPACE_1)
	_rows.add_child(grid)
	for key: String in ["lb_col_rank", "lb_col_agent", "lb_col_score", "lb_col_errors"]:
		grid.add_child(ScreenBase.eyebrow(UiText.t(key, {"lb_col_rank": "RANG", "lb_col_agent": "AGENT", "lb_col_score": "SCORE",
				"lb_col_errors": "ERREURS"}[key])))
	for entry: Dictionary in entries:
		var me: bool = entry["is_me"]
		var color: Color = DS.ACCENT_CYAN if me else DS.TEXT_PRIMARY
		grid.add_child(ScreenBase.label("%02d" % int(entry["rank"]), &"DataSmall", color if me else Palette.TEXT_SECONDARY))
		var who: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
		if me:
			who.add_child(UiIcon.make(UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN, DS.ICON_S))
		var name_label: Label = ScreenBase.label(str(entry["name"]), &"DataSmall", color)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = NAME_COLUMN_WIDTH
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.add_child(name_label)
		if me:
			who.add_child(ScreenBase.label(UiText.t("lb_you", "VOUS"), &"CaptionLabel", DS.ACCENT_CYAN))
		grid.add_child(who)
		grid.add_child(ScreenBase.label(str(entry["score"]), &"DataSmall", DS.ACCENT_YELLOW if not me else DS.ACCENT_CYAN))
		grid.add_child(ScreenBase.label(str(entry["errors"]), &"DataSmall", Palette.TEXT_SECONDARY))
	var me_entry: Variant = _data.get("me", null)
	var total: int = SaveService.as_int(_data.get("total", 0))
	var parts: PackedStringArray = []
	if me_entry is Dictionary:
		parts.append(UiText.tf("lb_my_rank", [SaveService.as_int((me_entry as Dictionary).get("rank", 0)), total], "Votre rang : %d / %d"))
	else:
		parts.append(UiText.plural("lb_total", total, "%d agent classé", "%d agents classés"))
	if _offline:
		parts.append(UiText.t("lb_offline_cached", "hors ligne : dernier classement connu"))
	_note.text = " · ".join(parts)
