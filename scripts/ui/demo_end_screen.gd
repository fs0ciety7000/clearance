## M15 (lot A, D-215) — écran « Fin de la démo » : après la soirée du J5 dans
## la démo (`DemoMode`), à la place de l'`EndScreen` de la fin
## `Campaign.ENDING_DEMO_COMPLETE`. Remerciement, bilan (solde, conformité,
## foyer), ce qui attend dans le jeu complet, puis deux actions :
## **VOIR LE JEU COMPLET** (CTA, ouvre `DemoMode.FULL_GAME_URL` dans le
## navigateur ; focus par défaut) et **RETOUR AU TITRE**.
## Manette et clavier : focus initial sur le CTA, croix ↕ / Tab entre les deux
## boutons (`FocusGuard` de `ScreenBase`), Ⓑ / Échap = retour au titre.
## Accessibilité : texte du thème DS (taille 90–150 %, plancher Deck), pas
## d'animation au-delà de l'apparition commune (réduite si « Réduire les
## animations »), contenu dans un défilement (texte 150 % au Deck).
## Textes : clés `demo_end_*` (repli français dans le code, M15 §4 : clés à
## ajouter à `fr.csv` / `en.csv` à l'intégration).
class_name DemoEndScreen
extends ScreenBase

## Choix émis par `finished` : `&"title"` (retour au titre).
const CHOICE_TITLE: StringName = &"title"
## Largeur maximale du contenu (lisibilité, DS §4).
const CONTENT_MAX_WIDTH: float = 1100.0

var final_credits: int = 0
var compliance: float = 0.0
var household: Household = null
var store_button: Button = null
var title_button: Button = null
## Tests : URL ouverte par le CTA (vide = `DemoMode.FULL_GAME_URL`), et
## faux pour ne pas lancer le navigateur.
var open_url: bool = true
var opened_urls: PackedStringArray = []


func setup(p_credits: int, p_compliance: float, p_household: Household) -> void:
	final_credits = p_credits
	compliance = p_compliance
	household = p_household


func default_focus() -> Control:
	return store_button


func _build() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root_box().add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box: VBoxContainer = vbox(DS.SPACE_6)
	box.name = "Content"
	box.custom_minimum_size.x = CONTENT_MAX_WIDTH
	center.add_child(box)
	box.add_child(eyebrow(UiText.tf("demo_end_eyebrow", [DemoMode.LAST_DAY], "CLEARANCE · DÉMO · JOURS 1 À %d"), DS.ACCENT_YELLOW))
	var title: Label = label(UiText.t("end_title_demo_complete", "FIN DE LA DÉMO"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var thanks: Label = wrapped(UiText.t("demo_end_thanks",
			"Merci d'avoir tenu le Guichet 04 pendant cinq jours. La file, elle, ne s'arrête pas."), &"BodyLabel")
	thanks.name = "Thanks"
	box.add_child(thanks)
	box.add_child(rule_line())
	var stats: HBoxContainer = hbox(DS.SPACE_4)
	stats.name = "Stats"
	box.add_child(stats)
	stats.add_child(stat_tile(UiText.t("end_balance", "SOLDE FINAL"), ScreenBase.credits(final_credits),
			UiText.t("end_balance_detail", "Banque Aurel"), DS.ACCENT_YELLOW))
	stats.add_child(stat_tile(UiText.t("end_compliance", "INDICE DE CONFORMITÉ"), percent(roundi(compliance * 100.0)),
			"", DS.TEXT_PRIMARY))
	if household != null:
		var alive: int = 0
		for member: Household.Member in household.members:
			if member.is_alive():
				alive += 1
		stats.add_child(stat_tile(UiText.t("end_family", "LE FOYER"), "%d / %d" % [alive, household.members.size()],
				"", DS.TEXT_PRIMARY))
	box.add_child(section(UiText.t("demo_end_full_title", "DANS LE JEU COMPLET"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW))
	var full: Label = wrapped(UiText.t("demo_end_full_text",
			"Trente jours en trois actes, dix fins, la Garde de nuit et le Dossier de l'agent. Votre foyer, vos choix et la file continuent là où la démo s'arrête."))
	full.name = "FullGame"
	box.add_child(full)
	var hint: Label = wrapped(UiText.t("demo_end_saves_hint",
			"La partie de démo reste dans ses propres sauvegardes ; le jeu complet commence au jour 1."), &"CaptionLabel")
	box.add_child(hint)
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override("h_separation", DS.SPACE_3)
	row.add_theme_constant_override("v_separation", DS.SPACE_2)
	box.add_child(row)
	store_button = button(UiText.t("demo_end_store", "VOIR LE JEU COMPLET"), &"ButtonPrimary")
	store_button.name = "Store"
	store_button.pressed.connect(open_full_game)
	row.add_child(store_button)
	title_button = button(UiText.t("end_to_title", "RETOUR AU TITRE"), &"ButtonTool")
	title_button.name = "Title"
	title_button.pressed.connect(close.bind(CHOICE_TITLE))
	row.add_child(title_button)
	store_button.focus_neighbor_right = store_button.get_path_to(title_button)
	title_button.focus_neighbor_left = title_button.get_path_to(store_button)
	store_button.grab_focus.call_deferred()


## Page du jeu complet dans le navigateur (ou consignée, tests).
func open_full_game() -> void:
	opened_urls.append(DemoMode.FULL_GAME_URL)
	if open_url:
		OS.shell_open(DemoMode.FULL_GAME_URL)


func _unhandled_input(event: InputEvent) -> void:
	if is_closing():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		close(CHOICE_TITLE)
		get_viewport().set_input_as_handled()
