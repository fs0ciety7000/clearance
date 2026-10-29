## Tutoriel interactif du Jour 1 (M11 lot C, UI_FLOW §7.1) — surimpression non
## diégétique (DS §1.5 : panneau plat `SystemPanel`) posée sur la file
## d'attente (colonne de droite de la bande B), jamais sur le visage, les
## documents ni les outils.
##
## Carte d'accueil (COMMENCER, focus / PASSER LE TUTORIEL), puis six étapes
## courtes ; chacune **attend l'action réelle du joueur** sur un signal
## `EventBus` existant et montre l'invite du dernier périphérique
## (`PromptGlyph`, clavier ou manette) :
## 1. Regarder le passager — appeler (SUIVANT), attendre ses papiers (`documents_presented`) ;
## 2. Mode Inspection (`inspection_mode_changed(true)`) ;
## 3. Rulebook (`rulebook_consulted`, M11) ;
## 4. Relier deux champs A → B (`discrepancy_check_requested`) ;
## 5. Interroger (`interrogation_requested`) ;
## 6. Tamponner (`verdict_stamped`).
## Chaque étape peut être passée ; le tutoriel entier aussi. Terminé ou passé,
## `Settings.tutorial_j1` repasse à faux (réactivable dans Options). Ne touche
## jamais à la logique du jour (lecture seule des signaux).
## Manette (QA-042, UI_FLOW §9.5) : la carte gère elle-même sa navigation
## (elle n'est pas dans la racine du guichet, dont le `FocusGuard` reprendrait
## toute direction) — accueil : focus piégé entre COMMENCER et PASSER LE
## TUTORIEL ; étapes : ← → entre QUITTER et PASSER L'ÉTAPE, ↓ rend le focus au
## guichet ; croix ↑ depuis SUIVANT (sans FERMER LE GUICHET au-dessus) ou depuis
## le haut du Rulebook entre dans la carte ; **VUE maintenue** `SKIP_HOLD_SEC`
## passe l'étape (appui court : Rulebook, inchangé).
## `pending` : posé par l'écran titre quand une partie démarre au J1 et que le
## réglage est actif ; consommé par `DayScene` (scènes de debug et tests : non).
class_name TutorialOverlay
extends Control

signal step_changed(index: int)
## `completed` : toutes les étapes faites (vrai) ou tutoriel passé (faux).
signal finished(completed: bool)

enum Step { LOOK, INSPECT, RULEBOOK, LINK, INTERROGATE, STAMP }

## Étapes : identifiant, actions dont on montre l'invite, clés de texte.
const STEPS: Array[Dictionary] = [
	{"step": Step.LOOK, "actions": [&"next_case"], "title": ["tut_look_title", "REGARDEZ LE PASSAGER"],
		"text": ["tut_look_text", "Appelez le passager suivant. Pendant qu'il approche, observez son visage : il fait partie du dossier."]},
	{"step": Step.INSPECT, "actions": [&"inspect_toggle"], "title": ["tut_inspect_title", "OUVREZ L'INSPECTION"],
		"text": ["tut_inspect_text", "Le Mode Inspection rend chaque champ des documents sélectionnable."]},
	{"step": Step.RULEBOOK, "actions": [&"rulebook_prev", &"rulebook_next"], "title": ["tut_rulebook_title", "CONSULTEZ LE RULEBOOK"],
		"text": ["tut_rulebook_text", "À droite, les règles du jour. Changez d'onglet ou sélectionnez une règle."]},
	{"step": Step.LINK, "actions": [&"ui_accept"], "title": ["tut_link_title", "RELIEZ DEUX CHAMPS"],
		"text": ["tut_link_text", "Sélectionnez un champ A, puis un champ B (ou une règle) : la comparaison dit CONCORDANT ou DISCORDANCE."]},
	{"step": Step.INTERROGATE, "actions": [&"interrogate"], "title": ["tut_interrogate_title", "INTERROGEZ"],
		"text": ["tut_interrogate_text", "Posez une question au passager. Une discordance débloque des questions."]},
	{"step": Step.STAMP, "actions": [&"stamp_approve", &"stamp_deny"], "title": ["tut_stamp_title", "TAMPONNEZ"],
		"text": ["tut_stamp_text", "Maintenez APPROUVÉ ou REFUSÉ. Un refus doit s'appuyer sur une discordance épinglée."]},
]
## Largeur de la carte : celle de la file d'attente qu'elle recouvre.
const CARD_WIDTH: float = 440.0
## Fin : la carte « Tutoriel terminé » reste ce temps avant de disparaître.
const DONE_HOLD_SEC: float = DS.TOAST_HOLD

## Maintien de VUE (manette, `rulebook_toggle`) qui passe l'étape (QA-042).
const SKIP_HOLD_SEC: float = DS.SKIP_HOLD

## Demande d'affichage au prochain J1 (titre → `DayScene`).
static var pending: bool = false

## -1 : carte d'accueil ; 0..5 : étape ; `STEPS.size()` : terminé.
var step_index: int = -1
var active: bool = false
## Vue de comparaison (lecture d'état : papiers déjà posés, Mode Inspection).
var ui: ComparisonUI = null
var start_button: Button = null
var skip_all_button: Button = null
var skip_step_button: Button = null

var _card: PanelContainer = null
var _box: VBoxContainer = null
var _ended: bool = false
## Maintien de VUE en cours : étape visée (-1 : aucun), durée, Rulebook replié
## avant l'appui (rétabli si l'appui devient « passer l'étape »).
var _hold_step: int = -1
var _hold_time: float = 0.0
var _hold_rulebook_collapsed: bool = false
var _skip_hint: HBoxContainer = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "TutorialOverlay"


func _ready() -> void:
	_apply_theme()
	EventBus.settings_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key == Settings.KEY_TEXT_SCALE or key == Settings.KEY_COLOR_VISION:
			_apply_theme())
	get_viewport().size_changed.connect(_apply_theme)
	InputPrompts.ensure(get_tree())
	_card = PanelContainer.new()
	_card.name = "TutorialCard"
	_card.theme_type_variation = &"SystemPanel"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_left = -(CARD_WIDTH + DS.SPACE_8)
	_card.offset_right = -DS.SPACE_8
	_card.offset_top = ComparisonUI.BAND_TOP + DS.SPACE_6
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_card)
	_box = ScreenBase.vbox(DS.SPACE_2)
	_card.add_child(_box)
	# Le joueur appelle un passager sans répondre à l'accueil : le tutoriel commence.
	EventBus.next_case_requested.connect(func() -> void:
		if step_index < 0 and not active and not _ended:
			begin())
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)
	EventBus.rulebook_consulted.connect(_on_signal.bind(Step.RULEBOOK))
	EventBus.discrepancy_check_requested.connect(func(_a: FieldRef, _b: FieldRef) -> void: _on_signal(Step.LINK))
	EventBus.interrogation_requested.connect(func(_t: StringName) -> void: _on_signal(Step.INTERROGATE))
	EventBus.verdict_stamped.connect(func(_v: Verdict) -> void: _on_signal(Step.STAMP))
	EventBus.day_ended.connect(func(_s: DaySummary) -> void: _end_quietly())
	InputPrompts.ensure(get_tree()).device_changed.connect(func(_d: InputPrompts.Device) -> void: _refresh_skip_hint())
	_show_intro()


## Thème DS propre (la scène de jour n'en porte pas), plancher de texte Deck.
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	theme = ThemeBuilder.build(Settings.text_scale, ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x))


## Étape courante (`Step`), -1 hors étape.
func current_step() -> int:
	if step_index < 0 or step_index >= STEPS.size():
		return -1
	return int(STEPS[step_index]["step"])


## Vrai si le focus est sur un contrôle de la carte.
func has_focus_inside() -> bool:
	if _card == null or not is_inside_tree():
		return false
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	return owner_control != null and _card.is_ancestor_of(owner_control)


func _clear() -> void:
	_skip_hint = null
	for child: Node in _box.get_children():
		# Masqué puis libéré (jamais orphelin, même pendant le signal du bouton).
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	start_button = null
	skip_all_button = null
	skip_step_button = null


func _header(text: String) -> void:
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.INFO, DS.ACCENT_CYAN, DS.ICON_S))
	var eyebrow: Label = ScreenBase.eyebrow(text, Palette.TEXT_SECONDARY)
	eyebrow.name = "Eyebrow"
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(eyebrow)


func _show_intro() -> void:
	_clear()
	step_index = -1
	_header(UiText.t("tut_eyebrow", "TUTORIEL · JOUR 1"))
	_box.add_child(ScreenBase.label(UiText.t("tut_intro_title", "PREMIER SHIFT"), &"TitleLabel", DS.TEXT_PRIMARY))
	_box.add_child(ScreenBase.wrapped(UiText.tf("tut_intro_text", [STEPS.size()],
			"%d gestes courts, faits pour de vrai sur les premiers passagers. Passez-les quand vous voulez."), &"BodySmall"))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_box.add_child(row)
	skip_all_button = ScreenBase.button(UiText.t("tut_skip_all", "PASSER LE TUTORIEL"), &"ButtonGhost")
	skip_all_button.name = "SkipAll"
	skip_all_button.pressed.connect(skip_all)
	row.add_child(skip_all_button)
	row.add_child(ScreenBase.spacer())
	start_button = ScreenBase.button(UiText.t("tut_start", "COMMENCER"), &"ButtonPrimary")
	start_button.name = "Start"
	start_button.pressed.connect(begin)
	row.add_child(start_button)
	start_button.grab_focus.call_deferred()


## Première étape.
func begin() -> void:
	var from_card: bool = has_focus_inside()
	active = true
	_go_to(0)
	# COMMENCER ne fait que commencer (QA-041) : le focus va au guichet (SUIVANT),
	# l'étape 1 demande d'appeler le passager.
	if from_card and is_inside_tree():
		_focus_booth.call_deferred()


func _go_to(index: int) -> void:
	step_index = index
	if step_index >= STEPS.size():
		_complete()
		return
	_render_step()
	step_changed.emit(step_index)
	# Action déjà faite (papiers déjà posés, Mode Inspection déjà ouvert) : on avance.
	if ui != null:
		if current_step() == Step.LOOK and ui.documents_shown:
			_advance_deferred()
		elif current_step() == Step.INSPECT and ui.inspection_active:
			_advance_deferred()


func _advance_deferred() -> void:
	var expected: int = step_index
	(func() -> void:
		if step_index == expected and active:
			_go_to(step_index + 1)).call_deferred()


func _render_step() -> void:
	_clear()
	var entry: Dictionary = STEPS[step_index]
	_header(UiText.tf("tut_step_of", [step_index + 1, STEPS.size()], "TUTORIEL · ÉTAPE %d / %d"))
	_box.add_child(_pips())
	var title: Array = entry["title"]
	var title_label: Label = ScreenBase.wrapped(UiText.t(title[0], title[1]), &"PanelTitle", DS.TEXT_PRIMARY)
	title_label.name = "StepTitle"
	_box.add_child(title_label)
	var text: Array = entry["text"]
	_box.add_child(ScreenBase.wrapped(UiText.t(text[0], text[1]), &"BodySmall"))
	var prompts: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	prompts.name = "Prompts"
	var actions: Array = entry["actions"]
	for action: StringName in actions:
		prompts.add_child(PromptGlyph.make(action, DS.TEXT_PRIMARY))
	prompts.add_child(ScreenBase.label(UiText.t("tut_waiting", "à vous"), &"CaptionLabel"))
	_box.add_child(prompts)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_box.add_child(row)
	skip_all_button = ScreenBase.button(UiText.t("tut_quit", "QUITTER"), &"ButtonGhost")
	skip_all_button.name = "SkipAll"
	skip_all_button.pressed.connect(skip_all)
	row.add_child(skip_all_button)
	row.add_child(ScreenBase.spacer())
	skip_step_button = ScreenBase.button(UiText.t("tut_skip_step", "PASSER L'ÉTAPE"), &"ButtonTool")
	skip_step_button.name = "SkipStep"
	skip_step_button.pressed.connect(skip_step)
	row.add_child(skip_step_button)
	# Raccourci manette (QA-042) : invite visible seulement à la manette.
	_skip_hint = ScreenBase.hbox(DS.SPACE_2)
	_skip_hint.name = "SkipHold"
	_skip_hint.add_child(ScreenBase.spacer())
	_skip_hint.add_child(ScreenBase.label(UiText.t("tut_skip_hold", "maintenir"), &"CaptionLabel"))
	_skip_hint.add_child(PromptGlyph.make(&"rulebook_toggle"))
	_skip_hint.add_child(ScreenBase.label(UiText.t("tut_skip_hold_tail", ": passer l'étape"), &"CaptionLabel"))
	_box.add_child(_skip_hint)
	_refresh_skip_hint()


func _refresh_skip_hint() -> void:
	if _skip_hint != null and is_instance_valid(_skip_hint):
		_skip_hint.visible = InputPrompts.is_gamepad()


## Pastilles d'avancement : pleine = faite, contour = à venir (forme, pas la couleur seule).
func _pips() -> HBoxContainer:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	row.name = "Pips"
	for i: int in STEPS.size():
		var kind: UiIcon.Kind = UiIcon.Kind.CHECK if i < step_index else UiIcon.Kind.DIAMOND
		var color: Color = DS.ACCENT_CYAN if i == step_index else Palette.TEXT_SECONDARY
		row.add_child(UiIcon.make(kind, color, DS.ICON_S))
	return row


func _on_documents_presented(_case_id: StringName) -> void:
	_on_signal(Step.LOOK)


func _on_inspection_mode_changed(enabled: bool) -> void:
	if enabled:
		_on_signal(Step.INSPECT)


## Signal reçu : avance si c'est l'action de l'étape courante.
func _on_signal(step: Step) -> void:
	if not active or _ended or current_step() != step:
		return
	_go_to(step_index + 1)


func skip_step() -> void:
	if not active or _ended:
		return
	var from_card: bool = has_focus_inside()
	_go_to(step_index + 1)
	if not from_card or not is_inside_tree():
		return
	# Focus gardé sur PASSER L'ÉTAPE (passer plusieurs étapes d'affilée), sinon au guichet.
	if skip_step_button != null:
		skip_step_button.grab_focus.call_deferred()
	else:
		_focus_booth.call_deferred()


## Passe tout le tutoriel (réglage désactivé : il ne sera plus proposé).
func skip_all() -> void:
	if _ended:
		return
	if has_focus_inside():
		_focus_booth()
	_finish(false)


## Rend le focus au contrôle par défaut du guichet (SUIVANT en attente).
func _focus_booth() -> void:
	if ui != null and is_instance_valid(ui) and ui.is_inside_tree():
		ui.focus_default()


func _complete() -> void:
	if has_focus_inside():
		_focus_booth()
	_clear()
	_header(UiText.t("tut_eyebrow", "TUTORIEL · JOUR 1"))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	row.add_child(UiIcon.make(UiIcon.Kind.APPROVED, Palette.STATE_GREEN, DS.ICON_M))
	row.add_child(ScreenBase.label(UiText.t("tut_done_title", "TUTORIEL TERMINÉ"), &"PanelTitle", DS.TEXT_PRIMARY))
	_box.add_child(row)
	_box.add_child(ScreenBase.wrapped(UiText.t("tut_done_text", "Le reste du shift est à vous. Okonkwo veille à l'intercom."), &"BodySmall"))
	_finish(true)
	if is_inside_tree():
		get_tree().create_timer(DONE_HOLD_SEC).timeout.connect(queue_free)


func _finish(completed: bool) -> void:
	_ended = true
	active = false
	Settings.set_value(Settings.KEY_TUTORIAL, false)
	finished.emit(completed)
	if not completed:
		queue_free()


## Fin du shift avant la fin du tutoriel : la carte disparaît, le réglage reste
## (le tutoriel sera reproposé au prochain J1).
func _end_quietly() -> void:
	if _ended:
		return
	_ended = true
	active = false
	queue_free()


# ---------------------------------------------------------------------------
# Manette et clavier (QA-042)
# ---------------------------------------------------------------------------

## La carte est sœur du guichet et passe avant lui (`_input` en ordre inverse
## de l'arbre) : elle traite sa navigation et le maintien de VUE avant le
## `FocusGuard` du guichet.
func _input(event: InputEvent) -> void:
	if _ended or _card == null or not is_visible_in_tree() or event is InputEventMouseMotion:
		return
	_track_skip_hold(event)
	if not event.is_pressed():
		return
	var dir: StringName = _direction_of(event)
	if dir == &"":
		return
	if has_focus_inside():
		_navigate_inside(dir)
		get_viewport().set_input_as_handled()
	elif dir == &"ui_up" and _enters_card_from_booth():
		var target: Control = start_button if step_index < 0 else skip_step_button
		if target != null and target.is_visible_in_tree():
			target.grab_focus()
			get_viewport().set_input_as_handled()


func _direction_of(event: InputEvent) -> StringName:
	for action: StringName in FocusGuard.DIRECTIONS:
		if event.is_action_pressed(action, true, true):
			return action
	return &""


## Accueil : focus piégé entre COMMENCER et PASSER LE TUTORIEL. Étapes :
## ← → / Tab entre QUITTER et PASSER L'ÉTAPE, ↑ reste, ↓ revient au guichet.
func _navigate_inside(dir: StringName) -> void:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	var first: Control = start_button if step_index < 0 else skip_all_button
	var second: Control = skip_all_button if step_index < 0 else skip_step_button
	if first == null or second == null:
		return
	if step_index >= 0 and dir == &"ui_down":
		_focus_booth()
		return
	if step_index >= 0 and dir == &"ui_up":
		return
	if step_index >= 0:
		# Gauche : QUITTER ; droite : PASSER L'ÉTAPE (ordre visuel de la rangée).
		if dir == &"ui_left":
			first.grab_focus()
			return
		if dir == &"ui_right":
			second.grab_focus()
			return
	(second if owner_control == first else first).grab_focus()


## Croix ↑ qui sort du haut du guichet vers la carte : depuis SUIVANT quand rien
## n'est configuré au-dessus (FERMER LE GUICHET a priorité), ou depuis un
## contrôle du Rulebook sans voisin au-dessus dans le Rulebook.
func _enters_card_from_booth() -> bool:
	if ui == null or not is_instance_valid(ui) or not ui.is_visible_in_tree():
		return false
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	if owner_control == null or not owner_control.is_visible_in_tree():
		return false
	if owner_control == ui.tool_bar.next_button:
		return owner_control.focus_neighbor_top.is_empty()
	if ui.rulebook != null and ui.rulebook.is_ancestor_of(owner_control):
		var above: Control = owner_control.find_valid_focus_neighbor(SIDE_TOP)
		return above == null or above == owner_control or not ui.rulebook.is_ancestor_of(above)
	return false


## VUE (bouton de manette de `rulebook_toggle`) maintenue `SKIP_HOLD_SEC` :
## passe l'étape. L'appui court garde son rôle (Rulebook replié / déplié) ; un
## maintien qui aboutit rétablit l'état du Rulebook d'avant l'appui.
func _track_skip_hold(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton) or not event.is_action(&"rulebook_toggle", true):
		return
	if event.is_pressed() and not event.is_echo():
		if active and step_index >= 0 and step_index < STEPS.size():
			_hold_step = step_index
			_hold_time = 0.0
			_hold_rulebook_collapsed = ui.rulebook.collapsed if ui != null and is_instance_valid(ui) and ui.rulebook != null else false
	elif not event.is_pressed():
		_hold_step = -1


func _process(delta: float) -> void:
	if _hold_step < 0:
		return
	_hold_time += delta
	if _hold_time < SKIP_HOLD_SEC:
		return
	var target: int = _hold_step
	_hold_step = -1
	if ui != null and is_instance_valid(ui) and ui.rulebook != null:
		ui.rulebook.set_collapsed(_hold_rulebook_collapsed)
	# L'appui court a pu valider l'étape Rulebook : on ne saute qu'une étape.
	if active and not _ended and step_index == target:
		skip_step()
