## « Nouvelle partie » (M11 lot C, UI_FLOW §8.5) — deux temps :
## 1. **Emplacement** : trois `SaveSlotCard` ; un emplacement libre se choisit
##    directement, un emplacement occupé demande une confirmation d'écrasement
##    (`ConfirmDialog`, focus sur ANNULER). Focus initial : premier emplacement
##    libre, sinon le premier emplacement.
## 2. **Difficulté** : **Dur** (défaut, focus, l'expérience prévue) ou **Récit**
##    (pas de chrono, pas d'amendes, toutes les fins ; « vous pourrez passer en
##    Dur plus tard, pas l'inverse », D-102).
## Ⓑ / Échap : retour à l'étape précédente, puis au titre (`finished(&"back")`).
## Le titre (`scenes/main/main.gd`) crée la partie sur `start_requested`.
class_name NewGameScreen
extends ScreenBase

signal start_requested(slot: int, difficulty: StringName)

enum Stage { SLOT, DIFFICULTY }

const CHOICE_WIDTH: float = 560.0

var stage: Stage = Stage.SLOT
## Emplacement retenu (étape 2).
var chosen_slot: int = SaveService.NO_SLOT
## Méta des emplacements (`SaveService.list_slots`), injectable (tests).
var slots: Array[Dictionary] = []
var slot_buttons: Array[Button] = []
var hard_button: Button = null
var story_button: Button = null
var back_button: Button = null
var dialog: ConfirmDialog = null

var _stage_label: Label = null
var _title: Label = null
var _body: VBoxContainer = null


func _build() -> void:
	if slots.is_empty():
		slots = SaveService.list_slots()
	var root: VBoxContainer = ScreenBase.vbox(DS.SPACE_6)
	root_box().add_child(root)
	var head: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	root.add_child(head)
	_stage_label = ScreenBase.eyebrow("", DS.ACCENT_YELLOW)
	head.add_child(_stage_label)
	_title = ScreenBase.label(UiText.t("ng_title", "NOUVELLE PARTIE"), &"DisplayLabel", DS.TEXT_PRIMARY)
	head.add_child(_title)
	_body = ScreenBase.vbox(DS.SPACE_4)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	root.add_child(foot)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("ng_back_hint", "retour"), &"CaptionLabel"))
	foot.add_child(keys)
	foot.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("ng_back", "RETOUR"), &"ButtonGhost")
	back_button.name = "Back"
	back_button.pressed.connect(go_back)
	foot.add_child(back_button)
	show_slots()


func default_focus() -> Control:
	if stage == Stage.DIFFICULTY:
		return hard_button
	for i: int in slot_buttons.size():
		if slots[i].is_empty():
			return slot_buttons[i]
	return slot_buttons[0] if not slot_buttons.is_empty() else back_button


func _clear_body() -> void:
	for child: Node in _body.get_children():
		# Masqué puis libéré (jamais orphelin, même pendant le signal du bouton).
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()


## Étape 1 : choix de l'emplacement.
func show_slots() -> void:
	stage = Stage.SLOT
	_clear_body()
	slot_buttons.clear()
	hard_button = null
	story_button = null
	_stage_label.text = UiText.t("ng_step_slot", "ÉTAPE 1 / 2 · EMPLACEMENT")
	_body.add_child(ScreenBase.wrapped(UiText.t("ng_slot_hint",
			"Chaque partie est enregistrée automatiquement chaque soir dans son emplacement."), &"BodyLabel"))
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	_body.add_child(row)
	for i: int in SaveService.SLOT_COUNT:
		var number: int = i + 1
		var meta: Dictionary = slots[i] if i < slots.size() else {}
		var card: SaveSlotCard = SaveSlotCard.make(number, meta)
		row.add_child(card)
		var b: Button
		if card.is_free():
			b = card.add_action(UiText.t("ng_use_slot", "CHOISIR CET EMPLACEMENT"), &"ButtonPrimary")
		else:
			b = card.add_action(UiText.t("ng_overwrite_slot", "ÉCRASER CETTE PARTIE…"), &"ButtonTool")
		b.name = "Choose%d" % number
		b.pressed.connect(choose_slot.bind(number))
		slot_buttons.append(b)
	_refocus()


## Emplacement choisi : libre → étape 2 ; occupé → confirmation d'écrasement.
func choose_slot(slot: int) -> void:
	var meta: Dictionary = slots[slot - 1] if slot - 1 < slots.size() else {}
	if meta.is_empty():
		show_difficulty(slot)
		return
	var day: int = SaveService.as_int(meta.get("current_day", 0))
	dialog = ConfirmDialog.make(UiText.t("ng_overwrite_eyebrow", "EMPLACEMENT OCCUPÉ"),
			UiText.tf("ng_overwrite_title", [slot], "Écraser la partie de l'emplacement %d ?"),
			UiText.tf("ng_overwrite_body", [day], "La partie enregistrée (jour %02d) et tous ses jours passés seront supprimés. Les fins déjà vues restent au profil."),
			UiText.t("ng_overwrite_accept", "ÉCRASER"))
	dialog.name = "OverwriteDialog"
	dialog.confirmed.connect(func() -> void:
		dialog = null
		show_difficulty(slot))
	dialog.cancelled.connect(func() -> void:
		dialog = null
		if slot - 1 < slot_buttons.size() and is_instance_valid(slot_buttons[slot - 1]):
			slot_buttons[slot - 1].grab_focus.call_deferred())
	add_child(dialog)


## Étape 2 : difficulté (Dur par défaut).
func show_difficulty(slot: int) -> void:
	stage = Stage.DIFFICULTY
	chosen_slot = slot
	_clear_body()
	slot_buttons.clear()
	_stage_label.text = UiText.tf("ng_step_difficulty", [slot], "ÉTAPE 2 / 2 · DIFFICULTÉ · EMPLACEMENT %d")
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	_body.add_child(row)
	hard_button = _choice(row, UiIcon.Kind.WARNING, UiText.t("diff_hard", "DUR"),
			UiText.t("diff_hard_tag", "Recommandé · l'expérience prévue"),
			[UiText.t("diff_hard_l1", "Le shift se termine à 18:00, chrono en marche."),
			UiText.t("diff_hard_l2", "Les erreurs coûtent des amendes, retenues sur le salaire."),
			UiText.t("diff_hard_l3", "Chaque crédit compte pour nourrir et soigner le foyer.")],
			UiText.t("diff_hard_play", "JOUER EN DUR"), &"ButtonPrimary")
	hard_button.name = "Hard"
	hard_button.pressed.connect(func() -> void: start_requested.emit(chosen_slot, GameState.DIFFICULTY_HARD))
	story_button = _choice(row, UiIcon.Kind.CHAT, UiText.t("diff_story", "RÉCIT"),
			UiText.t("diff_story_tag", "Pour l'histoire, sans pression"),
			[UiText.t("diff_story_l1", "Pas de chrono : le shift finit quand la file est traitée."),
			UiText.t("diff_story_l2", "Pas d'amendes : les citations restent des avertissements."),
			UiText.t("diff_story_l3", "Toutes les fins restent accessibles.")],
			UiText.t("diff_story_play", "JOUER EN RÉCIT"), &"ButtonTool")
	story_button.name = "Story"
	story_button.pressed.connect(func() -> void: start_requested.emit(chosen_slot, GameState.DIFFICULTY_STORY))
	var note: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	note.add_child(UiIcon.make(UiIcon.Kind.INFO, Palette.TEXT_SECONDARY, DS.ICON_S))
	var one_way: Label = ScreenBase.wrapped(UiText.t("diff_one_way",
			"Vous pourrez passer de Récit à Dur plus tard (Pause › Options), pas l'inverse."), &"BodySmall")
	one_way.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_child(one_way)
	_body.add_child(note)
	_refocus()


func _choice(row: HBoxContainer, icon: UiIcon.Kind, title: String, tag: String, lines: Array[String], play: String,
		variation: StringName) -> Button:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.custom_minimum_size.x = CHOICE_WIDTH
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	card.add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(icon, DS.TEXT_PRIMARY, DS.ICON_M))
	head.add_child(ScreenBase.label(title, &"TitleLabel", DS.TEXT_PRIMARY))
	box.add_child(ScreenBase.eyebrow(tag))
	for line: String in lines:
		var item: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		item.add_child(ScreenBase.label("·", &"BodyLabel", Palette.TEXT_SECONDARY))
		var text: Label = ScreenBase.wrapped(line, &"BodyLabel")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(text)
		box.add_child(item)
	box.add_child(ScreenBase.spacer(false, true))
	var b: Button = ScreenBase.button(play, variation)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(b)
	return b


func _refocus() -> void:
	var target: Control = default_focus()
	if target != null:
		target.grab_focus.call_deferred()


## Ⓑ / RETOUR : étape précédente, puis titre.
func go_back() -> void:
	if dialog != null:
		dialog.cancel()
		return
	if stage == Stage.DIFFICULTY:
		var previous: int = chosen_slot
		show_slots()
		if previous >= 1 and previous - 1 < slot_buttons.size():
			slot_buttons[previous - 1].grab_focus.call_deferred()
		return
	close(&"back")


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree() or dialog != null:
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		go_back()
		get_viewport().set_input_as_handled()
