## M15 (lot A, D-213) — bascule de langue **à chaud** sur les vrais écrans :
## guichet en plein shift (documents posés, Rulebook, journal, sous-titres,
## annonce, bandeau d'état), menu titre + Options, écran plein cadre. Après la
## bascule, aucun texte visible ne doit rester égal à un texte français de
## `fr.csv` dont la traduction anglaise diffère ; retour au français ensuite.
## Lit le vrai `en.csv` (lot B) : un texte sans traduction anglaise n'est pas
## compté (repli FR voulu).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

## Texte français → clé, pour les seules clés dont l'anglais diffère.
static var _french: Dictionary = {}

var ui: ComparisonUI = null
var session: InspectionSession = null
var ctx: RuleContext = null


func before_all() -> void:
	if not _french.is_empty():
		return
	var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
	var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
	for key: String in fr:
		var text: String = str(fr[key]).strip_edges()
		# Textes courts ou à format : seuls les textes complets et assez longs
		# pour être sans ambiguïté sont comptés.
		if text.length() < 4 or text.contains("%") or not en.has(key) or str(en[key]).strip_edges() == text:
			continue
		_french[text] = key
		_french[text.to_upper()] = key


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)


func after_each() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


## Textes visibles sous `root` encore en français (pièces comprises).
static func french_leftovers(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect(root, out)
	return out


static func _collect(node: Node, out: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	var texts: PackedStringArray = []
	if node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label or node is Button:
		texts.append(str(node.get(&"text")))
	if node is Control and not (node as Control).tooltip_text.is_empty():
		texts.append((node as Control).tooltip_text)
	for text: String in texts:
		for piece: String in _pieces(text):
			if _french.has(piece):
				out.append("%s: « %s » (%s)" % [node.name, piece, _french[piece]])
	for child: Node in node.get_children():
		_collect(child, out)


static func _pieces(text: String) -> PackedStringArray:
	var pieces: PackedStringArray = [text.strip_edges()]
	for line: String in text.split("\n", false):
		pieces.append(line.strip_edges())
		for sep: String in [" · ", " — "]:
			for part: String in line.split(sep, false):
				pieces.append(part.strip_edges())
	return pieces


func _shift_ui() -> void:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	session = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	var day: DayDef = CaseFactory.catalog().get_day(8)
	ctx = CaseFactory.context(day.rule_set.make_shift_copy())
	ui.rule_context_provider = func() -> RuleContext: return ctx
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	await wait_process_frames(2)
	var c: Case = CaseFactory.valid_case()
	c.index = 0
	session.begin(c, ctx)
	session.configure(InterrogationTiming.new(), {} as Dictionary[StringName, Variant])
	EventBus.case_presented.emit(c)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, c.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, c.case_id)
	EventBus.documents_presented.emit(c.case_id)
	await wait_process_frames(2)


func test_booth_mid_shift_switches_to_english_and_back() -> void:
	await _shift_ui()
	ui.say_intercom(UiText.t("speaker_okonkwo", "OKONKWO"), UiText.t("tuto_l1", "Bienvenue au Guichet 04."))
	ui.show_announcement(UiText.t("pa_generic_1", "Annonce"))
	await wait_process_frames(1)
	var before: PackedStringArray = french_leftovers(ui)
	assert_gt(before.size(), 50, "témoin : en français, le détecteur voit bien les textes français")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	await wait_process_frames(2)
	var left: PackedStringArray = french_leftovers(ui)
	assert_eq(left.size(), 0, "textes restés en français après la bascule :\n%s" % "\n".join(left.slice(0, 40)))
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	await wait_process_frames(2)
	assert_eq(french_leftovers(ui).size(), before.size(), "retour au français : les mêmes textes qu'avant")


func test_title_menu_and_options_switch_hot() -> void:
	var title: Control = TITLE_SCENE.instantiate()
	title.set(&"change_scene", false)
	add_child_autofree(title)
	await wait_process_frames(2)
	title.call(&"_show_options")
	await wait_process_frames(1)
	var options: OptionsPanel = title.get(&"options") as OptionsPanel
	options.language_buttons["en"].button_pressed = true
	await wait_process_frames(2)
	assert_eq(Settings.language, "en")
	var left: PackedStringArray = french_leftovers(title)
	assert_eq(left.size(), 0, "titre / Options :\n%s" % "\n".join(left.slice(0, 40)))
	assert_eq(options.back_button.text, UiText.t("opt_back"))
	assert_eq(options.back_button.text, "BACK")
	options.language_buttons["fr"].button_pressed = true
	assert_eq(options.back_button.text, "RETOUR")
	Settings.set_value(Settings.KEY_LANGUAGE, "fr", false)


func test_full_screen_screens_switch_hot() -> void:
	for make: Callable in [
		func() -> ScreenBase: return NewGameScreen.new(),
		func() -> ScreenBase: return LoadScreen.new(),
	]:
		Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
		var screen: ScreenBase = make.call()
		add_child_autofree(screen)
		await wait_process_frames(2)
		Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
		await wait_process_frames(1)
		var left: PackedStringArray = french_leftovers(screen)
		assert_eq(left.size(), 0, "%s :\n%s" % [screen.get_class(), "\n".join(left.slice(0, 40))])
		screen.queue_free()
		await wait_process_frames(1)
