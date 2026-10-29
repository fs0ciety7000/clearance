## « Charger » (M11 lot C, UI_FLOW §8.5) : trois `SaveSlotCard` (jour, acte,
## crédits, foyer, difficulté, date, temps de jeu ; partie terminée = nom de la
## fin). Actions par emplacement :
## - **REPRENDRE** (partie active) → `resume_requested(slot)` ;
## - **UN JOUR PASSÉ…** → liste des matins disponibles (`list_snapshots`),
##   avertissement « les jours suivants seront remplacés », confirmation
##   (`ConfirmDialog`, focus ANNULER) pour un jour antérieur au dernier →
##   `resume_day_requested(slot, day)` ;
## - **SUPPRIMER** en deux temps (premier appui : « CONFIRMER LA SUPPRESSION »,
##   rouge ; quitter le bouton désarme).
## M11 correctifs : la grille ne propose que des matins **lisibles**
## (`loadable_days`, QA-045) ; un chargement qui échoue malgré tout affiche un
## toast (`show_load_failed`) au lieu de ne rien faire ; un emplacement
## endommagé (QA-043) garde REPRENDRE visible mais désactivé.
## Focus initial : REPRENDRE de la partie active la plus récente, sinon la
## première action. Ⓑ / Échap : ferme la liste des jours, sinon retour au
## titre (`finished(&"back")`).
## M12 (lot C, I29) : partie terminée par une fin de l'Acte III (puce
## ÉPILOGUE de la carte, `SaveService.has_epilogue`) → action « JOUER « UN AN
## PLUS TARD » » en premier (sans confirmation : rien n'est écrasé) →
## `epilogue_requested(slot)`.
class_name LoadScreen
extends ScreenBase

signal resume_requested(slot: int)
signal resume_day_requested(slot: int, day: int)
signal epilogue_requested(slot: int)

## Colonnes de la grille des jours.
const DAY_COLUMNS: int = 6
const DAY_BUTTON_WIDTH: float = 200.0

## Dossier des sauvegardes (tests : dossier isolé).
var save_dir: String = SaveService.DEFAULT_DIR
var cards: Array[SaveSlotCard] = []
var resume_buttons: Dictionary[int, Button] = {}
var day_buttons: Dictionary[int, Button] = {}
var delete_buttons: Dictionary[int, Button] = {}
## M12 : « JOUER « UN AN PLUS TARD » » par emplacement terminé de l'Acte III.
var epilogue_buttons: Dictionary[int, Button] = {}
var back_button: Button = null
## Emplacement dont la liste des jours est ouverte (`NO_SLOT` sinon).
var picker_slot: int = SaveService.NO_SLOT
## Boutons de jour de la liste ouverte (jour → bouton).
var picker_buttons: Dictionary[int, Button] = {}
var dialog: ConfirmDialog = null
## Toasts de l'écran (chargement impossible).
var toasts: ToastStack = null

var _armed_delete: int = SaveService.NO_SLOT
var _cards_row: HBoxContainer = null
var _cards_area: VBoxContainer = null
var _picker: VBoxContainer = null
var _empty_note: Label = null


func _build() -> void:
	var root: VBoxContainer = ScreenBase.vbox(DS.SPACE_6)
	root_box().add_child(root)
	var head: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	root.add_child(head)
	head.add_child(ScreenBase.eyebrow(UiText.t("load_eyebrow", "PARTIES ENREGISTRÉES"), DS.ACCENT_YELLOW))
	head.add_child(ScreenBase.label(UiText.t("load_title", "CHARGER"), &"DisplayLabel", DS.TEXT_PRIMARY))
	# Cartes à la hauteur de leur contenu, en haut de la zone (pas étirées).
	_cards_area = ScreenBase.vbox(0)
	_cards_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards_area)
	_cards_row = ScreenBase.hbox(DS.SPACE_4)
	_cards_row.name = "Cards"
	_cards_area.add_child(_cards_row)
	_picker = ScreenBase.vbox(DS.SPACE_4)
	_picker.name = "DayPicker"
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.visible = false
	root.add_child(_picker)
	_empty_note = ScreenBase.wrapped(UiText.t("load_empty", "Aucune partie enregistrée. Commencez une nouvelle partie depuis le titre."), &"BodyLabel")
	_empty_note.visible = false
	root.add_child(_empty_note)
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	root.add_child(foot)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("ng_back_hint", "retour"), &"CaptionLabel"))
	foot.add_child(keys)
	foot.add_child(ScreenBase.label(UiText.t("load_autosave_hint", "Sauvegarde automatique chaque soir, après la soirée."), &"CaptionLabel"))
	foot.add_child(ScreenBase.spacer())
	back_button = ScreenBase.button(UiText.t("ng_back", "RETOUR"), &"ButtonGhost")
	back_button.name = "Back"
	back_button.pressed.connect(go_back)
	foot.add_child(back_button)
	toasts = ToastStack.new()
	toasts.name = "Toasts"
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -(SaveSlotCard.MIN_WIDTH + DS.SPACE_8)
	toasts.offset_right = -DS.SPACE_8
	toasts.offset_top = DS.SPACE_8
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(toasts)
	refresh()


## Relit les emplacements et reconstruit les cartes.
func refresh() -> void:
	for child: Node in _cards_row.get_children():
		# Masqué puis libéré (jamais orphelin, même pendant le signal du bouton).
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	cards.clear()
	resume_buttons.clear()
	day_buttons.clear()
	delete_buttons.clear()
	epilogue_buttons.clear()
	_armed_delete = SaveService.NO_SLOT
	var used: int = 0
	var metas: Array[Dictionary] = SaveService.list_slots(save_dir)
	for i: int in SaveService.SLOT_COUNT:
		var number: int = i + 1
		var meta: Dictionary = metas[i] if i < metas.size() else {}
		var card: SaveSlotCard = SaveSlotCard.make(number, meta)
		_cards_row.add_child(card)
		cards.append(card)
		if card.is_free():
			continue
		used += 1
		if card.is_damaged():
			# QA-043 : visible mais désactivé (et sauté par la croix).
			var dead: Button = card.add_action(UiText.t("load_resume", "REPRENDRE"), &"ButtonTool")
			dead.name = "Resume%d" % number
			dead.disabled = true
			dead.focus_mode = Control.FOCUS_NONE
		elif card.is_ended() and SaveService.has_epilogue(number, save_dir):
			var epi: Button = card.add_action(UiText.t("load_play_epilogue", "JOUER « UN AN PLUS TARD »"), &"ButtonPrimary")
			epi.name = "Epilogue%d" % number
			epi.pressed.connect(func() -> void: epilogue_requested.emit(number))
			epilogue_buttons[number] = epi
		elif not card.is_ended():
			var resume: Button = card.add_action(UiText.t("load_resume", "REPRENDRE"), &"ButtonPrimary")
			resume.name = "Resume%d" % number
			resume.pressed.connect(func() -> void: resume_requested.emit(number))
			resume_buttons[number] = resume
		var days: Button = card.add_action(UiText.t("load_past_day", "REPRENDRE UN JOUR PASSÉ…"))
		days.name = "Days%d" % number
		days.disabled = loadable_days(number).is_empty()
		days.focus_mode = Control.FOCUS_NONE if days.disabled else Control.FOCUS_ALL
		days.pressed.connect(open_day_picker.bind(number))
		day_buttons[number] = days
		var delete: Button = card.add_action(UiText.t("load_delete", "SUPPRIMER"), &"ButtonGhost")
		delete.name = "Delete%d" % number
		delete.pressed.connect(press_delete.bind(number))
		delete.focus_exited.connect(_disarm_delete.bind(number))
		delete_buttons[number] = delete
	_empty_note.visible = used == 0
	_refocus()


func default_focus() -> Control:
	if picker_slot != SaveService.NO_SLOT:
		var days: PackedInt32Array = PackedInt32Array(picker_buttons.keys())
		days.sort()
		if not days.is_empty():
			return picker_buttons[days[days.size() - 1]]
		return back_button
	var latest: int = SaveSlotCard.continue_slot(save_dir)
	if resume_buttons.has(latest):
		return resume_buttons[latest]
	for card: SaveSlotCard in cards:
		var first: Control = FocusGuard.first_focusable(card)
		if first != null:
			return first
	return back_button


func _refocus() -> void:
	var target: Control = default_focus()
	if target != null:
		target.grab_focus.call_deferred()


# ---------------------------------------------------------------------------
# Suppression en deux temps
# ---------------------------------------------------------------------------

## Premier appui : arme (« CONFIRMER LA SUPPRESSION ») ; second : supprime.
func press_delete(slot: int) -> void:
	var b: Button = delete_buttons.get(slot, null)
	if b == null:
		return
	if _armed_delete != slot:
		_disarm_delete(_armed_delete)
		_armed_delete = slot
		b.text = UiText.t("load_delete_confirm", "CONFIRMER LA SUPPRESSION")
		b.theme_type_variation = &"ButtonDanger"
		return
	_armed_delete = SaveService.NO_SLOT
	SaveService.delete_slot(slot, save_dir)
	EventBus.save_slots_changed.emit()
	refresh()


func is_delete_armed(slot: int) -> bool:
	return _armed_delete == slot


func _disarm_delete(slot: int) -> void:
	if slot == SaveService.NO_SLOT or _armed_delete != slot:
		return
	_armed_delete = SaveService.NO_SLOT
	var b: Button = delete_buttons.get(slot, null)
	if b != null and is_instance_valid(b):
		b.text = UiText.t("load_delete", "SUPPRIMER")
		b.theme_type_variation = &"ButtonGhost"


# ---------------------------------------------------------------------------
# Reprendre un jour passé
# ---------------------------------------------------------------------------

## Matins de l'emplacement réellement chargeables (QA-045) : instantanés
## listés **et** lisibles (un `.tmp` orphelin ou un fichier tronqué n'est
## jamais proposé, même si `list_snapshots` le compte).
func loadable_days(slot: int) -> PackedInt32Array:
	var result: PackedInt32Array = []
	for day: int in SaveService.list_snapshots(slot, save_dir):
		if not SaveService.load_snapshot(slot, day, save_dir).is_empty():
			result.append(day)
	return result


## Chargement impossible malgré tout (fichier abîmé entre-temps) : toast
## d'erreur (icône + texte) et écran relu, au lieu de ne rien faire.
func show_load_failed(slot: int, day: int = 0) -> void:
	var message: String = UiText.tf("load_failed_day", [day], "Le matin du jour %02d est illisible. Choisissez un autre jour.") if day > 0 \
			else UiText.tf("load_failed_slot", [slot], "La sauvegarde de l'emplacement %d est illisible.")
	toasts.push(ToastStack.Kind.ERROR, UiText.t("load_failed_title", "CHARGEMENT IMPOSSIBLE"), message)
	if picker_slot != SaveService.NO_SLOT and picker_slot == slot:
		var remaining: PackedInt32Array = loadable_days(slot)
		refresh()
		if remaining.is_empty():
			close_day_picker()
		else:
			open_day_picker(slot)
	else:
		refresh()


## Ouvre la liste des matins disponibles de l'emplacement.
func open_day_picker(slot: int) -> void:
	var days: PackedInt32Array = loadable_days(slot)
	if days.is_empty():
		return
	picker_slot = slot
	picker_buttons.clear()
	for child: Node in _picker.get_children():
		# Masqué puis libéré (jamais orphelin, même pendant le signal du bouton).
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	var meta: Dictionary = SaveService.load_meta(slot, save_dir)
	var last: int = days[days.size() - 1]
	_picker.add_child(ScreenBase.section(UiText.tf("load_days_title", [slot], "REPRENDRE UN JOUR PASSÉ · EMPLACEMENT %d"),
			UiIcon.Kind.REGISTER, Palette.TEXT_SECONDARY, UiText.plural("load_days_count", days.size(), "%d matin", "%d matins")))
	var warn: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	warn.name = "Warning"
	warn.add_child(UiIcon.make(UiIcon.Kind.WARNING, Palette.STATE_AMBER, DS.ICON_M))
	var warn_text: Label = ScreenBase.wrapped(UiText.t("load_days_warning",
			"Vous reprenez au matin du jour choisi. Les jours suivants de cet emplacement seront remplacés à la prochaine soirée."),
			&"BodyStrong", Palette.STATE_AMBER)
	warn_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn.add_child(warn_text)
	_picker.add_child(warn)
	if str(meta.get("status", "")) == SaveService.STATUS_ENDED:
		_picker.add_child(ScreenBase.wrapped(UiText.t("load_days_ended", "Partie terminée : reprendre un jour la rouvre."), &"BodySmall"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "DaysScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.add_child(scroll)
	var pad: MarginContainer = MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", DS.SPACE_4)
	scroll.add_child(pad)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Days"
	grid.columns = DAY_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_3)
	pad.add_child(grid)
	for day: int in days:
		var text: String = UiText.tf("load_day_button", [day], "MATIN DU JOUR %02d")
		if day == last:
			text = UiText.tf("load_day_button_last", [day], "JOUR %02d · DERNIER")
		var b: Button = ScreenBase.button(text, &"ButtonPrimary" if day == last else &"ButtonTool")
		b.name = "Day%d" % day
		b.custom_minimum_size.x = DAY_BUTTON_WIDTH
		b.pressed.connect(choose_day.bind(day))
		grid.add_child(b)
		picker_buttons[day] = b
	_cards_area.visible = false
	_picker.visible = true
	_refocus()


func close_day_picker() -> void:
	var slot: int = picker_slot
	picker_slot = SaveService.NO_SLOT
	picker_buttons.clear()
	_picker.visible = false
	_cards_area.visible = true
	if day_buttons.has(slot):
		day_buttons[slot].grab_focus.call_deferred()
	else:
		_refocus()


## Jour choisi : le dernier se reprend directement ; un jour antérieur demande
## confirmation (les jours suivants seront remplacés).
func choose_day(day: int) -> void:
	var slot: int = picker_slot
	if slot == SaveService.NO_SLOT:
		return
	var days: PackedInt32Array = loadable_days(slot)
	var last: int = days[days.size() - 1] if not days.is_empty() else day
	if day >= last:
		resume_day_requested.emit(slot, day)
		return
	dialog = ConfirmDialog.make(UiText.t("load_day_confirm_eyebrow", "LIGNE DE TEMPS"),
			UiText.tf("load_day_confirm_title", [day], "Reprendre au matin du jour %02d ?"),
			UiText.tf("load_day_confirm_body", [day + 1, last], "Les jours %02d à %02d de cet emplacement seront remplacés dès la prochaine soirée."),
			UiText.t("load_day_confirm_accept", "REPRENDRE CE JOUR"))
	dialog.name = "DayDialog"
	dialog.confirmed.connect(func() -> void:
		dialog = null
		resume_day_requested.emit(slot, day))
	dialog.cancelled.connect(func() -> void:
		dialog = null
		if picker_buttons.has(day):
			picker_buttons[day].grab_focus.call_deferred())
	add_child(dialog)


## Ⓑ / RETOUR : ferme la liste des jours, sinon retour au titre.
func go_back() -> void:
	if dialog != null:
		dialog.cancel()
		return
	if picker_slot != SaveService.NO_SLOT:
		close_day_picker()
		return
	close(&"back")


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree() or dialog != null:
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		go_back()
		get_viewport().set_input_as_handled()
