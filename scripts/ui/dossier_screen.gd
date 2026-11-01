## **Dossier de l'agent** (M12 lot C, I33 ; M12 §5, D-131) — ouvert depuis le
## titre. En-tête `dos_title` (« DOSSIER DE L'AGENT · HG-1404-AGNT ») et
## compteurs ; cinq onglets navigables à la manette (croix, LB / RB, Ⓑ) :
## - **FINS** : dix cartes F1 → F10 ; vue : titre, surtitre, première fois
##   (date réelle, jour de jeu), nombre de fois, pastilles des variantes vues,
##   première ligne d'épilogue ; non vue : silhouette (barres), indice de
##   niveau 1, niveau 2 seulement après `epilogue_unlocked` ;
## - **PERSONNES** : personnages croisés (`characters.tres`), initiales et
##   couleur d'origine **avec le code d'origine en texte** (pas de portrait,
##   M14), première rencontre, rencontres, présentation ; filtre par acte (actes
##   atteints seulement) ;
## - **DERNIÈRE PARTIE** : fin, jour, date, climat, choix clés (`end_trace_*`) ;
## - **GARDE DE NUIT** : records, graine du jour, graines libres, statistiques,
##   « JOUER LA GRAINE DU JOUR » (`garde_requested`) ;
## - **ÉPILOGUES** (si `epilogue_unlocked`) : quatre mondes, variantes vues avec
##   « JOUER » / « REJOUER » depuis la graine du profil (`epilogue_requested`) ;
##   monde non vu : silhouette « Un autre 11 avril ».
## Aucune donnée hors du profil et de la table (anti-spoiler : `DossierData`).
## Ⓑ / Échap : retour au titre (`finished(&"back")`).
## M14 (lot D, I46 ; M14 §5, D-191) : **portraits** des cartes PERSONNES — le
## visage tel que la vitre l'a montré (`ProfileService.portrait_of` →
## `portrait_appearance`, visière comprise), rendu par un `PortraitService`
## propre au Dossier (`DOSSIER_SIZE` 128×160, créé à la première ouverture de
## l'onglet, libéré avec l'écran ; esquisse immédiate puis rendu sur place),
## cadre chanfreiné à la couleur d'origine, initiales gardées dans le cadre et
## code d'origine en texte ; jamais vu : initiales (« Visage non vu »).
## **REVOIR** sur une fin vue dont la cinématique est au profil
## (`has_seen_cinematic`) et sur un monde d'épilogue vu : `CinematicScreen`
## par-dessus le Dossier, figures en silhouette (aucune mémoire de partie),
## rien d'inscrit ; thème de la fin par `TitleMusic.play_theme_after_fade`,
## puis retour de la musique du titre.
class_name DossierScreen
extends ScreenBase

## D-203 : bibliothèque des cinématiques chargée avant tout script qui nomme `PlateDef`.
const _CINEMATIC_LIBRARY := preload("res://scripts/core/cinematic_library_def.gd")

signal epilogue_requested(key: String)
signal garde_requested(code: String)

const TAB_ENDINGS: StringName = &"endings"
const TAB_PEOPLE: StringName = &"people"
const TAB_LAST: StringName = &"last"
const TAB_GARDE: StringName = &"garde"
const TAB_EPILOGUES: StringName = &"epilogues"
const ENDING_COLUMNS: int = 2
const PEOPLE_COLUMNS: int = 3
## Barres de la silhouette d'une fin non vue (largeurs relatives).
const SILHOUETTE_BARS: Array[float] = [0.55, 0.3, 0.42]

var save_dir: String = SaveService.DEFAULT_DIR
var profile: Dictionary = {}
var table: CharacterTableDef = null
var current_tab: StringName = TAB_ENDINGS
var tabs: Array[StringName] = []
var tab_buttons: Dictionary[StringName, Button] = {}
## Filtre d'acte de l'onglet Personnes (0 = tous).
var act_filter: int = 0
var back_button: Button = null
## Boutons d'action de l'onglet affiché (épilogues : clé → bouton).
var epilogue_buttons: Dictionary[String, Button] = {}
var garde_button: Button = null
var filter_buttons: Dictionary[int, Button] = {}
## M14 : boutons REVOIR (id de cinématique → bouton), cinématique rejouée,
## service de portraits du Dossier et musique du titre (`main.tscn`).
var replay_buttons: Dictionary[String, Button] = {}
var replay: CinematicScreen = null
var portrait_service: PortraitService = null
var title_music: TitleMusic = null
## Drapeaux passés au thème du dernier REVOIR (variante du thème ; tests).
var replay_theme_flags: Dictionary[StringName, Variant] = {}
var _replay_from: String = ""
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null


func _ready() -> void:
	super._ready()
	focus_guard.scroll_target = func() -> ScrollContainer: return _scroll


func _build() -> void:
	if profile.is_empty():
		profile = ProfileService.load_profile(save_dir)
	if table == null:
		table = CharacterTableDef.load_default()
	tabs = [TAB_ENDINGS, TAB_PEOPLE, TAB_LAST, TAB_GARDE]
	if DossierData.totals_visible(profile):
		tabs.append(TAB_EPILOGUES)
	var root: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	root_box().add_child(root)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	root.add_child(head)
	var titles: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(ScreenBase.eyebrow(UiText.t("dos_eyebrow", "CONSORTIUM · BUREAU DU PERSONNEL"), DS.ACCENT_YELLOW))
	titles.add_child(ScreenBase.label(UiText.t("dos_title", "DOSSIER DE L'AGENT · HG-1404-AGNT"), &"DisplayLabel", DS.TEXT_PRIMARY))
	var counters: Label = ScreenBase.label(header_counts(profile), &"DataSmall", Palette.TEXT_SECONDARY)
	counters.name = "Counters"
	counters.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(counters)
	var nav: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	nav.name = "Tabs"
	root.add_child(nav)
	nav.add_child(PromptGlyph.make(&"rulebook_prev"))
	for tab: StringName in tabs:
		var b: Button = ScreenBase.button(UiText.t("dos_tab_%s" % tab, String(tab).to_upper()), &"ButtonGhost")
		b.name = "Tab_%s" % tab
		b.toggle_mode = true
		b.pressed.connect(show_tab.bind(tab))
		nav.add_child(b)
		tab_buttons[tab] = b
	nav.add_child(PromptGlyph.make(&"rulebook_next"))
	_scroll = ScrollContainer.new()
	_scroll.name = "Content"
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	var pad: MarginContainer = MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", DS.SPACE_4)
	_scroll.add_child(pad)
	_body = ScreenBase.vbox(DS.SPACE_4)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_body)
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	root.add_child(foot)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("ng_back_hint", "retour"), &"CaptionLabel"))
	keys.add_child(PromptGlyph.make(&"scroll_down"))
	keys.add_child(ScreenBase.label(UiText.t("dos_scroll_hint", "défiler"), &"CaptionLabel"))
	foot.add_child(keys)
	foot.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("ng_back", "RETOUR"), &"ButtonGhost")
	back_button.name = "Back"
	back_button.pressed.connect(go_back)
	foot.add_child(back_button)
	show_tab(TAB_ENDINGS)


func default_focus() -> Control:
	return tab_buttons.get(current_tab, back_button)


## « 3 fins vues · 12 personnes croisées · 4 gardes » (totaux après
## `epilogue_unlocked` : « 3 / 10 fins »).
static func header_counts(p_profile: Dictionary) -> String:
	var clean: Dictionary = ProfileService.sanitize(p_profile)
	var seen: PackedStringArray = ProfileService.ending_ids(clean)
	var parts: PackedStringArray = []
	var endings_text: String = DossierData.endings_total_text(clean)
	parts.append(endings_text.to_lower() if not endings_text.is_empty()
			else UiText.plural("dos_count_endings", seen.size(), "%d fin vue", "%d fins vues"))
	var stats: Dictionary = clean["garde_stats"]
	parts.append(UiText.plural("dos_count_gardes", SaveService.as_int(stats.get("runs", 0)), "%d garde", "%d gardes"))
	return " · ".join(parts)


## Affiche un onglet (focus sur son bouton).
func show_tab(tab: StringName) -> void:
	if not tabs.has(tab):
		tab = TAB_ENDINGS
	current_tab = tab
	for key: StringName in tab_buttons:
		tab_buttons[key].set_pressed_no_signal(key == tab)
		tab_buttons[key].theme_type_variation = &"ButtonTool" if key == tab else &"ButtonGhost"
	for child: Node in _body.get_children():
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	epilogue_buttons.clear()
	filter_buttons.clear()
	replay_buttons.clear()
	garde_button = null
	match tab:
		TAB_ENDINGS:
			_build_endings()
		TAB_PEOPLE:
			_build_people()
		TAB_LAST:
			_build_last()
		TAB_GARDE:
			_build_garde()
		TAB_EPILOGUES:
			_build_epilogues()
	_scroll.scroll_vertical = 0
	if is_inside_tree() and tab_buttons.has(tab):
		tab_buttons[tab].grab_focus.call_deferred()


func cycle_tab(step: int) -> void:
	var index: int = posmod(tabs.find(current_tab) + step, tabs.size())
	show_tab(tabs[index])


# ---------------------------------------------------------------------------
# Fins
# ---------------------------------------------------------------------------

func _build_endings() -> void:
	var total: String = DossierData.endings_total_text(profile)
	_body.add_child(ScreenBase.section(UiText.t("dos_tab_endings", "FINS"), UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY, total))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Endings"
	grid.columns = ENDING_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.SPACE_4)
	grid.add_theme_constant_override("v_separation", DS.SPACE_4)
	_body.add_child(grid)
	var index: int = 0
	for card: Dictionary in DossierData.ending_cards(profile):
		index += 1
		grid.add_child(_ending_card(card, index))


func _ending_card(card: Dictionary, number: int) -> Control:
	var panel_node: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	panel_node.name = "Ending_%s" % card["short"]
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	panel_node.add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	var seen: bool = card["seen"]
	var accent: Color = EndScreen.accent_of(StringName(card["id"])) if seen else Palette.TEXT_SECONDARY
	head.add_child(ScreenBase.label("F%d" % number, &"DataTitle", accent))
	if not seen:
		head.add_child(ScreenBase.chip(UiText.t("dos_not_seen", "NON VUE"), UiIcon.Kind.LOCK, Palette.TEXT_SECONDARY))
		box.add_child(_silhouette())
		var hint: Label = ScreenBase.wrapped(str(card["hint1"]), &"BodySmall", Palette.TEXT_SECONDARY)
		hint.name = "Hint1"
		box.add_child(hint)
		if not str(card["hint2"]).is_empty():
			var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
			row.name = "Hint2"
			row.add_child(UiIcon.make(UiIcon.Kind.INFO, DS.ACCENT_CYAN, DS.ICON_S))
			var hint2: Label = ScreenBase.wrapped(str(card["hint2"]), &"BodySmall", DS.TEXT_PRIMARY)
			hint2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(hint2)
			box.add_child(row)
		return panel_node
	head.add_child(UiIcon.make(EndScreen.icon_of(StringName(card["id"])), accent, DS.ICON_S))
	if not str(card["eyebrow"]).is_empty():
		var brow: Label = ScreenBase.eyebrow(str(card["eyebrow"]), accent)
		brow.clip_text = true
		brow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(brow)
	var title: Label = ScreenBase.wrapped(str(card["title"]), &"TitleLabel", DS.TEXT_PRIMARY)
	title.name = "Title"
	box.add_child(title)
	box.add_child(ScreenBase.label(UiText.tf("dos_first_seen", [DossierData.short_date(str(card["first_date"])), int(card["day"])],
			"Première fois : %s · J%d") + " · " + UiText.plural("dos_count", int(card["count"]), "Vue %d fois", "Vue %d fois"),
			&"DataSmall", Palette.TEXT_SECONDARY))
	var variants: PackedStringArray = card["variants"]
	if not variants.is_empty():
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Variants"
		flow.add_theme_constant_override("h_separation", DS.SPACE_2)
		box.add_child(flow)
		for text: String in variants:
			flow.add_child(ScreenBase.chip(text, UiIcon.Kind.DIAMOND, accent))
	if not str(card["first_line"]).is_empty():
		box.add_child(ScreenBase.wrapped(UiText.quoted(ComparisonUI.lumika_text(str(card["first_line"]), true)), &"BodySmall", DS.TEXT_PRIMARY))
	var replays: Array[Dictionary] = replays_for(profile, StringName(card["id"]))
	if not replays.is_empty():
		var row: HFlowContainer = HFlowContainer.new()
		row.name = "Replays"
		row.add_theme_constant_override("h_separation", DS.SPACE_2)
		box.add_child(row)
		for entry: Dictionary in replays:
			var text: String = UiText.t("cin_replay", "REVOIR")
			if replays.size() > 1 and not str(entry["variant"]).is_empty():
				text = "%s · %s" % [text, UiText.t("dos_variant_%s" % entry["variant"], str(entry["variant"]).to_upper())]
			var b: Button = ScreenBase.button(text, &"ButtonTool")
			b.name = "Replay_%s" % entry["id"]
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var info: Dictionary = entry.duplicate()
			info["eyebrow"] = str(card["eyebrow"])
			info["title"] = str(card["title"])
			b.pressed.connect(func() -> void: play_replay(info))
			row.add_child(b)
			replay_buttons[str(entry["id"])] = b
	return panel_node


## Cinématiques revoyables d'une fin : une par séquence **vue** (profil), dans
## l'ordre des fins vues ; `{id, ending, variant, act, day, plates, flags}`.
## QA-073 : d'abord les séquences dont le contexte est au profil
## (`cinematic_replays` : planches et drapeaux de la séquence vue) ; sinon
## (profil antérieur) sélection des données (`CinematicService.select`) sur la
## variante et l'acte inscrits au profil, sans drapeaux.
static func replays_for(p_profile: Dictionary, ending: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var clean: Dictionary = ProfileService.sanitize(p_profile)
	var ids: PackedStringArray = []
	var empty: Dictionary[StringName, Variant] = {}
	var stored: Dictionary = clean["cinematic_replays"]
	var stored_ids: Array = stored.keys()
	stored_ids.sort()
	for row: Dictionary in clean["endings_seen"]:
		if str(row["id"]) != String(ending):
			continue
		var variant: StringName = StringName(str(row.get("variant", "")))
		var act: int = clampi(SaveService.as_int(row.get("act", 1)), 1, 3)
		var found: bool = false
		for cin_id: Variant in stored_ids:
			var ctx: Dictionary = stored[cin_id]
			if str(ctx["ending"]) != String(ending) or str(ctx["variant"]) != String(variant):
				continue
			found = true
			if ids.has(str(cin_id)) or not ProfileService.has_seen_cinematic(clean, str(cin_id)):
				continue
			ids.append(str(cin_id))
			out.append({"id": str(cin_id), "ending": String(ending), "variant": String(variant), "act": int(ctx["act"]),
					"day": int(ctx["day"]), "plates": ctx["plates"], "flags": ctx["flags"]})
		if found:
			continue
		var def: CinematicDef = CinematicService.select(ending, variant, empty, act)
		if def == null or ids.has(String(def.id)) or not ProfileService.has_seen_cinematic(clean, String(def.id)):
			continue
		ids.append(String(def.id))
		out.append({"id": String(def.id), "ending": String(ending), "variant": String(variant), "act": act})
	return out


## Drapeaux de contexte d'une séquence à revoir (`info["flags"]`, QA-073),
## typés ; vides si le profil ne les a pas gardés.
static func replay_flags(info: Dictionary) -> Dictionary[StringName, Variant]:
	var out: Dictionary[StringName, Variant] = {}
	var raw: Variant = info.get("flags", {})
	if raw is Dictionary:
		for key: Variant in raw:
			out[StringName(str(key))] = (raw as Dictionary)[key]
	return out


## Planches à revoir : celles de la séquence vue (`info["plates"]`, dans
## l'ordre ; QA-073), sinon la sélection des données sur `ctx`.
static func replay_plates(def: CinematicDef, info: Dictionary, ctx: Dictionary[StringName, Variant], act: int) -> Array[PlateDef]:
	var result: Array[PlateDef] = []
	var raw: Variant = info.get("plates", [])
	if raw is Array:
		for plate_id: Variant in raw:
			for plate: PlateDef in def.plates:
				if plate != null and String(plate.id) == str(plate_id):
					result.append(plate)
					break
	if result.is_empty():
		result = CinematicService.plates_for(def, ctx, act, {})
	return result


## REVOIR : la séquence par-dessus le Dossier, figures en silhouette, rien
## d'inscrit ; `info` = `{id, ending, variant, act, day, plates, flags,
## eyebrow, title}` (fin) ou `{id, world, …}` (épilogue). QA-073 : planches,
## légendes et variante du thème de la séquence vue (contexte du profil).
func play_replay(info: Dictionary) -> CinematicScreen:
	if replay != null and is_instance_valid(replay):
		return replay
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	var def: CinematicDef = lib.get_cinematic(StringName(str(info.get("id", "")))) if lib != null else null
	if def == null:
		return null
	var act: int = int(info.get("act", 3))
	var variant: StringName = StringName(str(info.get("variant", "")))
	var flags: Dictionary[StringName, Variant] = replay_flags(info)
	var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(flags, act, variant, int(info.get("day", 0)))
	var plates: Array[PlateDef] = replay_plates(def, info, ctx, act)
	if plates.is_empty():
		return null
	var ending: StringName = StringName(str(info.get("ending", "")))
	var sequence: CinematicScreen = CinematicScreen.new()
	sequence.setup(def, plates, ctx, {}, ending, variant)
	sequence.set_title(str(info.get("eyebrow", "")), str(info.get("title", "")))
	sequence.record_seen = false
	sequence.already_seen = true
	sequence.save_dir = save_dir
	sequence.name = "Replay"
	sequence.finished.connect(_on_replay_finished, CONNECT_ONE_SHOT)
	_replay_from = str(info.get("id", ""))
	replay = sequence
	if is_inside_tree():
		get_viewport().gui_release_focus()
	add_child(sequence)
	_play_replay_theme(ending, variant, StringName(str(info.get("world", ""))), flags)
	return sequence


## Thème de la fin (ou du monde) sur la musique du titre (`index.json`), avec
## les drapeaux de la séquence vue (variante du thème, QA-073) ; un monde : sans
## drapeaux, comme en jeu.
func _play_replay_theme(ending: StringName, variant: StringName, world: StringName,
		flags: Dictionary[StringName, Variant] = {}) -> void:
	replay_theme_flags = {} if world != &"" else flags
	if title_music == null or not is_instance_valid(title_music):
		return
	var path: String = AudioDirector.theme_path_for_world(world) if world != &"" else AudioDirector.theme_path_for_ending(ending, variant)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var theme: MusicThemeDef = load(path) as MusicThemeDef
	if theme != null:
		title_music.play_theme_after_fade(theme, replay_theme_flags, Settings.fx_intensity < 1.0)


func _on_replay_finished(_skipped: bool) -> void:
	replay = null
	if title_music != null and is_instance_valid(title_music) and is_inside_tree():
		# Retour au Dossier : le thème s'éteint, la musique du titre revient.
		title_music.fade_to(MusicDirector.SILENT_DB, DS.MUSIC_EXIT_FADE, true)
		# Méthode liée (pas de lambda) : déconnectée d'elle-même si le titre est libéré.
		get_tree().create_timer(DS.MUSIC_EXIT_FADE).timeout.connect(title_music.start.bind({}))
	var back: Button = replay_buttons.get(_replay_from, null)
	if back != null and is_instance_valid(back):
		back.grab_focus.call_deferred()
	else:
		default_focus().grab_focus.call_deferred()


## Titre caché : barres pleines (jamais de texte, même partiel).
func _silhouette() -> Control:
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	box.name = "Silhouette"
	for ratio: float in SILHOUETTE_BARS:
		var bar: ColorRect = ColorRect.new()
		bar.color = Palette.LINE_SUBTLE
		bar.custom_minimum_size = Vector2(ratio * 520.0, DS.SPACE_3)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
	return box


# ---------------------------------------------------------------------------
# Personnes
# ---------------------------------------------------------------------------

func _build_people() -> void:
	var total: String = DossierData.people_total_text(profile, table)
	_body.add_child(ScreenBase.section(UiText.t("dos_tab_people", "PERSONNES"), UiIcon.Kind.CHAT, Palette.TEXT_SECONDARY, total))
	var max_day: int = SaveService.as_int(ProfileService.sanitize(profile)["max_day_reached"])
	var reached: int = ProfileService.act_of_day(max_day) if max_day > 0 else 1
	if reached > 1:
		var filters: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		filters.name = "ActFilter"
		_body.add_child(filters)
		for act: int in range(0, reached + 1):
			var text: String = UiText.t("dos_filter_all", "TOUS") if act == 0 else UiText.tf("dos_filter_act", [SaveSlotCard.act_roman(act)], "ACTE %s")
			var b: Button = ScreenBase.button(text, &"ButtonTool" if act == act_filter else &"ButtonGhost")
			b.name = "Act%d" % act
			b.pressed.connect(set_act_filter.bind(act))
			filters.add_child(b)
			filter_buttons[act] = b
	var list: Array[Dictionary] = DossierData.people(profile, table, act_filter)
	if list.is_empty():
		_body.add_child(ScreenBase.wrapped(UiText.t("dos_people_none", "Personne encore. Les visages qui comptent finissent ici."), &"BodySmall"))
		return
	var grid: GridContainer = GridContainer.new()
	grid.name = "People"
	grid.columns = PEOPLE_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_3)
	_body.add_child(grid)
	_ensure_portraits()
	for person: Dictionary in list:
		grid.add_child(person_card(person, portrait_for(str(person["id"]))))


## M14 : `PortraitService` propre au Dossier (vignettes 128×160, LRU 48), créé
## à la première ouverture de l'onglet PERSONNES, libéré avec l'écran.
func _ensure_portraits() -> void:
	if portrait_service != null:
		return
	portrait_service = PortraitService.new()
	portrait_service.name = "DossierPortraits"
	portrait_service.size = PortraitService.DOSSIER_SIZE # avant l'entrée dans l'arbre
	portrait_service.max_entries = DossierData.PORTRAIT_CACHE
	add_child(portrait_service)


## Portrait d'un personnage tel que vu à la vitre, ou null (jamais vu : initiales).
func portrait_for(chr_id: String) -> Texture2D:
	var entry: Dictionary = ProfileService.portrait_of(profile, chr_id)
	var app: PassengerAppearance = ProfileService.portrait_appearance(entry)
	if app == null:
		return null
	_ensure_portraits()
	return portrait_service.get_portrait(app)


func set_act_filter(act: int) -> void:
	act_filter = act
	show_tab(TAB_PEOPLE)
	if filter_buttons.has(act):
		filter_buttons[act].grab_focus.call_deferred()


## Carte d'un personnage : portrait vu à la vitre (M14) ou initiales sur la
## couleur d'origine, code d'origine en texte, nom appris, première rencontre,
## rencontres, présentation.
static func person_card(person: Dictionary, portrait: Texture2D = null) -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "Person_%s" % person["id"]
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 360.0
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	card.add_child(row)
	var color: Color = DossierData.faction_color(str(person["faction"]))
	if portrait != null:
		row.add_child(PortraitFrame.make(portrait, str(person["initials"]), color))
	else:
		var badge: InitialsBadge = InitialsBadge.make(str(person["initials"]), color)
		badge.tooltip_text = UiText.t("dos_portrait_hidden", "Visage non vu")
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(badge)
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label: Label = ScreenBase.wrapped(str(person["name"]), &"BodyStrong", DS.TEXT_PRIMARY)
	name_label.name = "Name"
	col.add_child(name_label)
	var meta: PackedStringArray = [DossierData.faction_code(str(person["faction"]))]
	if int(person["first_day"]) > 0:
		meta.append(UiText.tf("dos_chr_first", [int(person["first_day"])], "J%02d"))
	meta.append(UiText.plural("dos_chr_encounters", int(person["encounters"]), "%d rencontre", "%d rencontres"))
	col.add_child(ScreenBase.label(" · ".join(meta), &"DataSmall", Palette.TEXT_SECONDARY))
	if not str(person["blurb"]).is_empty():
		col.add_child(ScreenBase.wrapped(str(person["blurb"]), &"BodySmall", Palette.TEXT_SECONDARY))
	return card


# ---------------------------------------------------------------------------
# Dernière partie
# ---------------------------------------------------------------------------

func _build_last() -> void:
	_body.add_child(ScreenBase.section(UiText.t("dos_tab_last", "DERNIÈRE PARTIE"), UiIcon.Kind.REGISTER, Palette.TEXT_SECONDARY))
	var last: Dictionary = DossierData.last_campaign(profile)
	if last.is_empty():
		_body.add_child(ScreenBase.wrapped(UiText.t("dos_last_none", "Aucune partie terminée pour l'instant."), &"BodySmall"))
		return
	var title: Label = ScreenBase.label(str(last["title"]), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "LastTitle"
	_body.add_child(title)
	var meta: PackedStringArray = [UiText.tf("dos_last_day", [int(last["day"])], "Dernier jour : J%02d")]
	if not str(last["date"]).is_empty():
		meta.append(str(last["date"]))
	if not str(last["world"]).is_empty():
		meta.append(UiText.tf("dos_last_world", [str(last["world"])], "Épilogue : %s"))
	_body.add_child(ScreenBase.label(" · ".join(meta), &"DataSmall", Palette.TEXT_SECONDARY))
	if not str(last["climate"]).is_empty():
		_body.add_child(ScreenBase.wrapped(str(last["climate"]), &"BodySmall", Palette.TEXT_SECONDARY))
	var traces: PackedStringArray = last["traces"]
	_body.add_child(ScreenBase.section(UiText.t("end_traces", "CE QUE VOUS AVEZ CHOISI"), UiIcon.Kind.DISCORDANCE, Palette.ACCENT_MAGENTA,
			str(traces.size())))
	if traces.is_empty():
		_body.add_child(ScreenBase.wrapped(UiText.t("dos_last_no_trace", "Aucun choix marquant enregistré pour cette partie."), &"BodySmall"))
	for text: String in traces:
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		row.add_child(UiIcon.make(UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY, DS.ICON_S))
		var line: Label = ScreenBase.wrapped(text, &"BodySmall", DS.TEXT_PRIMARY)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		_body.add_child(row)


# ---------------------------------------------------------------------------
# Garde de nuit
# ---------------------------------------------------------------------------

func _build_garde() -> void:
	_body.add_child(ScreenBase.section(UiText.t("dos_tab_garde", "GARDE DE NUIT"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW))
	var clean: Dictionary = ProfileService.sanitize(profile)
	var daily_code: String = GardeService.today_code()
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	_body.add_child(row)
	var daily: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(daily)
	daily.add_child(ScreenBase.eyebrow(UiText.t("garde_daily", "GRAINE DU JOUR")))
	daily.add_child(ScreenBase.label(daily_code, &"DataTitle", DS.TEXT_PRIMARY))
	daily.add_child(ScreenBase.wrapped(GardeScreen.daily_summary(clean, daily_code), &"BodySmall"))
	if GardeService.is_unlocked(clean):
		garde_button = ScreenBase.button(UiText.t("garde_play_daily", "JOUER LA GRAINE DU JOUR"), &"ButtonPrimary")
		garde_button.name = "PlayDaily"
		garde_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		garde_button.pressed.connect(func() -> void: garde_requested.emit(daily_code))
		daily.add_child(garde_button)
	else:
		daily.add_child(ScreenBase.wrapped(UiText.t("garde_locked", "Terminez votre premier jour au Guichet 04."), &"BodySmall",
				Palette.TEXT_SECONDARY))
	var runs: Array = clean["best_runs"]
	if runs.is_empty():
		_body.add_child(ScreenBase.wrapped(UiText.t("garde_records_none", "Aucune garde enregistrée. La première fixe le record."), &"BodySmall"))
		return
	_body.add_child(ScreenBase.section(UiText.t("garde_records", "RECORDS"), UiIcon.Kind.REGISTER, Palette.TEXT_SECONDARY))
	_body.add_child(GardeScreen.run_table(runs, GardeScreen.current_version()))
	var stats: Dictionary = clean["garde_stats"]
	_body.add_child(ScreenBase.label(UiText.tf("garde_stats_line", [SaveService.as_int(stats.get("runs", 0)),
			SaveService.as_int(stats.get("total_correct", 0)), SaveService.as_int(stats.get("longest_run", 0))],
			"%d gardes · %d verdicts justes · plus longue : %d passagers"), &"DataSmall", Palette.TEXT_SECONDARY))
	var seeds: Array = clean["garde_seeds"]
	if not seeds.is_empty():
		_body.add_child(ScreenBase.section(UiText.t("garde_free_seeds", "GRAINES LIBRES"), UiIcon.Kind.DIAMOND, Palette.TEXT_SECONDARY,
				str(seeds.size())))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "FreeSeeds"
		flow.add_theme_constant_override("h_separation", DS.SPACE_4)
		flow.add_theme_constant_override("v_separation", DS.SPACE_1)
		_body.add_child(flow)
		for entry: Variant in seeds:
			if entry is Dictionary:
				flow.add_child(ScreenBase.label("%s · %d" % [str((entry as Dictionary).get("seed_code", "")),
						SaveService.as_int((entry as Dictionary).get("best", 0))], &"DataSmall", DS.TEXT_PRIMARY))


# ---------------------------------------------------------------------------
# Épilogues
# ---------------------------------------------------------------------------

func _build_epilogues() -> void:
	_body.add_child(ScreenBase.section(UiText.t("dos_tab_epilogues", "ÉPILOGUES"), UiIcon.Kind.AWAY, Palette.TEXT_SECONDARY))
	for world: Dictionary in DossierData.epilogue_worlds(profile):
		_body.add_child(_world_block(world))


func _world_block(world: Dictionary) -> Control:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.name = "World_%s" % world["world"]
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	card.add_child(box)
	var seen: bool = world["seen"]
	var tint: Color = EpilogueScreen.world_color(str(world["world"])) if seen else Palette.TEXT_SECONDARY
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(EpilogueScreen.WORLD_ICONS.get(str(world["world"]), UiIcon.Kind.DIAMOND) if seen else UiIcon.Kind.LOCK, tint,
			DS.ICON_M))
	var name_label: Label = ScreenBase.label(str(world["name"]), &"TitleLabel", tint if seen else Palette.TEXT_SECONDARY)
	name_label.name = "WorldName"
	head.add_child(name_label)
	if not seen:
		box.add_child(_silhouette())
		return card
	var def: CinematicDef = CinematicService.select_epilogue(StringName(str(world["world"])))
	if def != null and ProfileService.has_seen_cinematic(profile, String(def.id)):
		var replay_button: Button = ScreenBase.button(UiText.t("cin_replay", "REVOIR"), &"ButtonTool")
		replay_button.name = "Replay_%s" % def.id
		replay_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var info: Dictionary = ProfileService.cinematic_replay(profile, String(def.id))
		info.merge({"id": String(def.id), "world": str(world["world"]), "act": 3, "day": 31}, true)
		replay_button.pressed.connect(func() -> void: play_replay(info))
		head.add_child(ScreenBase.spacer())
		head.add_child(replay_button)
		replay_buttons[String(def.id)] = replay_button
	for variant: Dictionary in world["variants"]:
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
		box.add_child(row)
		var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(ScreenBase.label(str(variant["title"]), &"BodyStrong", DS.TEXT_PRIMARY))
		var count: int = int(variant["count"])
		var meta: String = UiText.t("dos_epi_never", "Pas encore joué") if count == 0 \
				else UiText.tf("dos_epi_played", [str(variant["first_date"]), count], "Première fois : %s · joué %d fois")
		col.add_child(ScreenBase.label(meta, &"DataSmall", Palette.TEXT_SECONDARY))
		if not str(variant["last_line"]).is_empty():
			col.add_child(ScreenBase.wrapped(UiText.quoted(ComparisonUI.lumika_text(str(variant["last_line"]), true)), &"BodySmall"))
		var b: Button = ScreenBase.button(UiText.t("dos_epi_play", "JOUER") if count == 0 else UiText.t("dos_epi_replay", "REJOUER"),
				&"ButtonPrimary" if count == 0 else &"ButtonTool")
		b.name = "Play_%s" % str(variant["key"]).replace(":", "_")
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = str(variant["key"])
		b.pressed.connect(func() -> void: epilogue_requested.emit(key))
		row.add_child(b)
		epilogue_buttons[key] = b
	return card


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func go_back() -> void:
	close(&"back")


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree() or (replay != null and is_instance_valid(replay)):
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		go_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"rulebook_next", false, true):
		cycle_tab(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"rulebook_prev", false, true):
		cycle_tab(-1)
		get_viewport().set_input_as_handled()


## M14 : vignette du visage vu à la vitre (`DOSSIER_PORTRAIT_W` ×
## `DOSSIER_PORTRAIT_H`, ≥ 72 px au Deck), cadre chanfreiné 2 px à la couleur
## d'origine (repère décoratif), initiales gardées sur un voile en bas du cadre.
class PortraitFrame:
	extends PanelContainer

	var texture_rect: TextureRect = null

	static func make(texture: Texture2D, initials: String, color: Color) -> PortraitFrame:
		var frame: PortraitFrame = PortraitFrame.new()
		frame.name = "Portrait"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		frame.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL, color, DS.BORDER_STRONG, DS.CHAMFER_M,
				DS.BORDER_STRONG))
		var stack: Control = Control.new()
		stack.custom_minimum_size = Vector2(DS.DOSSIER_PORTRAIT_W, DS.DOSSIER_PORTRAIT_H)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(stack)
		frame.texture_rect = TextureRect.new()
		frame.texture_rect.name = "Face"
		frame.texture_rect.texture = texture
		frame.texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(frame.texture_rect)
		var tag: PanelContainer = PanelContainer.new()
		tag.name = "InitialsTag"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.SUBTITLE_BG, Color(0, 0, 0, 0), 0, DS.CHAMFER_S, DS.SPACE_1))
		tag.anchor_left = 0.0
		tag.anchor_top = 1.0
		tag.anchor_bottom = 1.0
		tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tag.offset_left = DS.SPACE_1
		tag.offset_bottom = -DS.SPACE_1
		var text: Label = ScreenBase.label(initials, &"DataSmall", DS.TEXT_PRIMARY)
		text.name = "Initials"
		tag.add_child(text)
		stack.add_child(tag)
		return frame


## Initiales sur un carré chanfreiné à la couleur d'origine (repère
## décoratif ; le code d'origine est écrit à côté).
class InitialsBadge:
	extends PanelContainer

	static func make(text: String, color: Color) -> InitialsBadge:
		var badge: InitialsBadge = InitialsBadge.new()
		badge.name = "Initials"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(DS.SPACE_12, DS.SPACE_12)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var fill: Color = color
		fill.a = 0.24
		badge.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(fill, color, DS.BORDER_STRONG, DS.CHAMFER_M, 0))
		var label: Label = ScreenBase.label(text, &"DataTitle", DS.TEXT_PRIMARY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(label)
		return badge
