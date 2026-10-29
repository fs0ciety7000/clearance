## Interstitiel « CHAPITRE II » (Acte II, ARCHITECTURE §7.2, ACT2 §1.2) :
## après la soirée pivot du J10 quand la campagne continue, avant le briefing
## du J11. Plein cadre noir, chiffre romain monumental, titre « RÉÉQUILIBRAGE »,
## dates de l'acte, rappel de ce qui a changé cette nuit (vannes, quota) ; la
## sauvegarde automatique a déjà eu lieu (`Campaign.close_evening`).
## Révélation lente (fondu, `DS.DUR_DRAMATIC`), *skippable* : « CONTINUER »,
## Entrée, clic. Émet `finished(&"next")`.
## Acte III (ARCHITECTURE §7.3) : « CHAPITRE III · TÉMOINS » (`setup(flags, 3)`)
## après la soirée pivot du J20, avant le J21 — chiffre « Ⅲ », ambre de
## l'Enquête (voix INSPECTION, D-061), balance, rappel `chapter3_recall` et
## climat d'entrée (`chapter3_climate_*`).
class_name ChapterScreen
extends ScreenBase

## Chiffre romain : hauteur des fûts (px @1080p).
const NUMERAL_HEIGHT: float = 176.0
## Durée minimale avant que « CONTINUER » prenne le focus (lecture).
const HOLD_SEC: float = DS.DUR_DRAMATIC * 2.0

## Lignes de rappel (clés), selon les drapeaux de la Nuit des vannes.
var recap_keys: PackedStringArray = []
## Acte annoncé (2 : Rééquilibrage, 3 : Témoins).
var act: int = 2
var continue_button: Button = null

var _parts: Array[Control] = []


## Rappel de la nuit (une ligne : vannes ouvertes / avortées / échouées) + quota.
## Acte III : rappel du 1ᵉʳ avril puis le climat d'entrée (un seul).
func setup(flags: Dictionary[StringName, Variant], p_act: int = 2) -> void:
	recap_keys.clear()
	act = p_act
	if act == 3:
		recap_keys.append("chapter3_recall")
		for ending: StringName in EndingService.CLIMATE_FLAGS:
			var flag: StringName = EndingService.CLIMATE_FLAGS[ending]
			if FlagCondition.is_flag_true(flags, flag):
				var climate: String = String(flag).trim_prefix("climate_")
				if climate == "vanne" and FlagCondition.is_flag_true(flags, EndingService.FLAG_BRULANTS2):
					climate = "brulants"
				recap_keys.append("chapter3_climate_%s" % climate)
				break
		return
	if FlagCondition.is_flag_true(flags, &"vannes_opened"):
		recap_keys.append("chapter2_recap_opened")
	elif FlagCondition.is_flag_true(flags, &"vannes_failed"):
		recap_keys.append("chapter2_recap_failed")
	else:
		recap_keys.append("chapter2_recap_aborted")
	recap_keys.append("chapter2_recap_quota")


## Couleur de l'acte : bleu de registre (II, Commission), ambre (III, Enquête).
func accent() -> Color:
	return Palette.STATE_AMBER if act == 3 else Palette.VOICE_COMMISSION


## Clé de texte de l'acte (`chapter2_title`, `chapter3_title`…).
func text_key(suffix: String) -> String:
	return "chapter%d_%s" % [act, suffix]


## Manette / clavier (M11) : « CONTINUER » par défaut.
func default_focus() -> Control:
	return continue_button


func _build() -> void:
	var tint: Color = accent()
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box().add_child(center)
	var box: VBoxContainer = vbox(DS.SPACE_5)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.x = 960.0
	center.add_child(box)
	var eyebrow_row: HBoxContainer = hbox(DS.SPACE_3)
	eyebrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	eyebrow_row.add_child(UiIcon.make(UiIcon.Kind.SCALES if act == 3 else UiIcon.Kind.REGISTER, tint, DS.ICON_M))
	eyebrow_row.add_child(eyebrow(UiText.t(text_key("eyebrow"), "HALCYON GATE · GUICHET 04"), tint))
	box.add_child(eyebrow_row)
	_parts.append(eyebrow_row)
	# « Ⅱ » romain dessiné (fûts + barres d'empattement) : deux barres seules
	# se liraient comme l'icône « pause ».
	var numeral: RomanTwo = RomanTwo.new()
	numeral.name = "Numeral"
	numeral.stems = act
	numeral.accent = tint
	numeral.tooltip_text = UiText.t(text_key("numeral"), "II" if act == 2 else "III")
	numeral.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(numeral)
	_parts.append(numeral)
	var title: Label = label(UiText.t(text_key("title"), "RÉÉQUILIBRAGE" if act == 2 else "TÉMOINS"), &"DisplayLabel", tint)
	title.name = "ChapterTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_parts.append(title)
	var dates: Label = label(UiText.t(text_key("sub"), ""), &"DataTitle", Palette.TEXT_SECONDARY)
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dates)
	_parts.append(dates)
	var line: ColorRect = rule_line(Color(tint, 0.4))
	line.custom_minimum_size = Vector2(480.0, DS.BORDER_HAIRLINE)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	_parts.append(line)
	for key: String in recap_keys:
		var recap: Label = wrapped(UiText.t(key, ""), &"TitleLabel", DS.TEXT_PRIMARY)
		recap.name = "Recap_%s" % key
		recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(recap)
		_parts.append(recap)
	var row: VBoxContainer = vbox(DS.SPACE_2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	continue_button = button(UiText.t(text_key("continue"), "PRENDRE SON POSTE"), &"ButtonPrimary")
	continue_button.custom_minimum_size.x = 360.0
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(close.bind(&"next"))
	row.add_child(continue_button)
	var saved: Label = label(UiText.t("chapter2_saved", "Partie sauvegardée"), &"CaptionLabel")
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(saved)
	_parts.append(row)
	_reveal()


## Apparition échelonnée (chaque bloc après le précédent) ; immédiate si
## « réduire les animations ».
func _reveal() -> void:
	if Settings.reduce_motion or Settings.fx_intensity <= 0.0:
		continue_button.grab_focus.call_deferred()
		return
	for i: int in _parts.size():
		var part: Control = _parts[i]
		part.modulate.a = 0.0
		var tween: Tween = part.create_tween()
		tween.tween_interval(DS.DUR_SLOW + DS.DUR_BASE * i)
		tween.tween_property(part, "modulate:a", 1.0, DS.DUR_DRAMATIC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(HOLD_SEC).timeout.connect(_focus_continue)


func _focus_continue() -> void:
	if is_instance_valid(continue_button) and continue_button.is_inside_tree():
		continue_button.grab_focus()


## Tout afficher d'un coup (clic, Entrée pendant la révélation).
func reveal_all() -> void:
	for part: Control in _parts:
		part.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		reveal_all()
		get_viewport().set_input_as_handled()


## Chiffre romain « Ⅱ » / « Ⅲ » : `stems` fûts, barres d'empattement haute
## et basse, liseré de la couleur de l'acte sous la barre basse.
class RomanTwo:
	extends Control

	const STEM: float = 26.0
	const GAP: float = 46.0
	const BAR: float = 12.0
	const OVERHANG: float = 22.0

	var stems: int = 2:
		set(value):
			stems = maxi(value, 1)
			custom_minimum_size = Vector2(STEM * stems + GAP * (stems - 1) + OVERHANG * 2.0, ChapterScreen.NUMERAL_HEIGHT + DS.SPACE_8)
			queue_redraw()
	var accent: Color = Palette.VOICE_COMMISSION:
		set(value):
			accent = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stems = 2

	func _draw() -> void:
		var w: float = size.x
		var h: float = ChapterScreen.NUMERAL_HEIGHT
		var body: float = STEM * stems + GAP * (stems - 1)
		var left: float = (w - body) * 0.5
		draw_rect(Rect2(0.0, 0.0, w, BAR), DS.TEXT_PRIMARY)
		draw_rect(Rect2(0.0, h - BAR, w, BAR), DS.TEXT_PRIMARY)
		for i: int in stems:
			draw_rect(Rect2(left + (STEM + GAP) * i, 0.0, STEM, h), DS.TEXT_PRIMARY)
		draw_rect(Rect2(0.0, h + DS.SPACE_3, w, DS.BORDER_STRONG), accent)
