## QA (docs/QA.md §3) — mise en page des écrans plein cadre aux deux
## définitions cibles (1920×1080 ; Steam Deck 1280×800, D-023, soit un canevas
## logique de 1920×1200 à l'échelle 2/3 avec `stretch canvas_items` + `aspect
## expand`) : le
## bouton principal de chaque écran doit rester visible. Les écrans sont
## construits dans un `SubViewport` de la taille logique ; au Deck, on leur
## applique le thème avec le plancher de texte (`ThemeBuilder.min_px_for`,
## échelle 800 / 1080) comme le fait `ScreenBase` en jeu. Bugs ouverts : `pending`.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1920, 1200)]
## Échelle d'affichage du Steam Deck (1280 / 1920 : la largeur limite).
const DECK_SCALE: float = 1280.0 / 1920.0

var data: DataCatalog = null
var _reduce_before: bool = false


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_reduce_before = Settings.reduce_motion
	Settings.set_value(Settings.KEY_REDUCE_MOTION, true, false)


func after_each() -> void:
	Settings.set_value(Settings.KEY_REDUCE_MOTION, _reduce_before, false)


## Ajoute `screen` dans un SubViewport `size` ; renvoie le viewport.
func _host(screen: Control, size: Vector2i) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	add_child_autofree(vp)
	vp.add_child(screen)
	if size.y > 1080:
		screen.theme = ThemeBuilder.build(Settings.text_scale, ThemeBuilder.min_px_for(DECK_SCALE))
	return vp


func _visible_in(button: Control, vp: SubViewport) -> bool:
	var rect: Rect2 = button.get_global_rect()
	return Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(rect)


## QA-001 : le briefing n'a pas de défilement ; dès le J4 (10 règles) la liste
## des règles pousse « PRENDRE SON POSTE » hors de l'écran (en bas), en 1080p
## comme au Deck ; au Deck, dès le J1, la colonne de droite et le bouton
## sortent aussi par la droite (libellés sur une ligne, plancher de texte).
func test_briefing_start_button_is_on_screen_every_day() -> void:
	var failures: PackedStringArray = []
	for size: Vector2i in SIZES:
		for n: int in range(1, data.get_last_day_number() + 1):
			var day: DayDef = data.get_day(n)
			var screen: BriefingScreen = BriefingScreen.new()
			var content: BriefingContent = BriefingContent.build(day, {}, Household.new(), 20 if n == 1 else 0)
			screen.setup(content, Household.new(), 20, day)
			var vp: SubViewport = _host(screen, size)
			await wait_process_frames(3)
			if not _visible_in(screen.start_button, vp):
				var end: Vector2 = screen.start_button.get_global_rect().end
				failures.append("J%d %dx%d (coin du bouton %d,%d)" % [n, size.x, size.y, roundi(end.x), roundi(end.y)])
			vp.queue_free()
	if not failures.is_empty():
		pending("QA-001 : « PRENDRE SON POSTE » hors écran : %s" % ", ".join(failures))
		return
	assert_true(true)


func test_summary_and_evening_buttons_are_on_screen() -> void:
	for size: Vector2i in SIZES:
		for n: int in [1, 7, 9]:
			var day: DayDef = data.get_day(n)
			var summary: DaySummary = DaySimulator.simulate(data, n, 99,
					func(_c: Case, key: CaseKey, _i: int) -> VerdictKind.Kind: return key.expected_verdict)
			var sum_screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
			sum_screen.setup(summary, day)
			var vp: SubViewport = _host(sum_screen, size)
			await wait_process_frames(3)
			assert_true(_visible_in(sum_screen.continue_button, vp), "bilan J%d %s" % [n, size])
			vp.queue_free()


## QA-004 : l'écran titre (`scenes/main/main.gd`) construit son thème sans le
## plancher de texte Steam Deck (`ThemeBuilder.min_px_for`) : au Deck, les
## légendes tombent à ~8 px physiques (DS : 12 px minimum).
func test_title_screen_applies_the_steam_deck_text_floor() -> void:
	var main: Control = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)
	var scale: float = get_viewport().get_final_transform().get_scale().x
	var floor_px: int = ThemeBuilder.min_px_for(scale)
	if floor_px == 0:
		pass_test("échelle %.2f ≥ 1 : pas de plancher à vérifier" % scale)
		return
	var expected: int = ThemeBuilder.build(Settings.text_scale, floor_px).get_font_size(&"font_size", &"CaptionLabel")
	var caption: int = main.theme.get_font_size(&"font_size", &"CaptionLabel")
	if caption < expected:
		pending("QA-004 : titre sans plancher Steam Deck (légende %d px, plancher attendu %d px à l'échelle %.2f ; %d px au Deck)" % [
				caption, expected, scale, ThemeBuilder.min_px_for(DECK_SCALE)])
		return
	assert_gte(caption, expected)


## Garde de mise en page (pas de bug constaté) : « RETOUR AU TITRE » visible pour
## les sept fins, en 1080p et au Deck (colonne d'épilogue de 820 px + récapitulatif).
func test_end_screen_buttons_are_on_screen_for_every_ending() -> void:
	var history: Array[Dictionary] = []
	for n: int in range(1, 11):
		history.append({"day": n, "processed": 14, "planned": 14, "correct": 12, "citations": 2, "wage": 60,
				"fines": 5, "spent": 46, "balance": 40 + n})
	var flags: Dictionary[StringName, Variant] = {&"met_mira": true, &"sc02_mercy": true, &"ilan_supported": true,
			&"okonkwo_warned": true, &"final_passed": true, &"lucioles_trust": 5}
	var failures: PackedStringArray = []
	for size: Vector2i in SIZES:
		for ending: StringName in EndingService.ALL_ENDINGS:
			var end: EndScreen = EndScreen.new()
			end.epilogue = EndingService.epilogue(ending, flags, Household.new())
			end.setup(ending, history, Household.new(), 120, flags, 0.86)
			var vp: SubViewport = _host(end, size)
			await wait_process_frames(3)
			end.reveal_all()
			await wait_process_frames(2)
			if not _visible_in(end.title_button, vp):
				var corner: Vector2 = end.title_button.get_global_rect().end
				failures.append("%s %dx%d (coin %d,%d)" % [ending, size.x, size.y, roundi(corner.x), roundi(corner.y)])
			vp.queue_free()
	if not failures.is_empty():
		fail_test("« RETOUR AU TITRE » hors écran : %s" % ", ".join(failures))
		return
	assert_true(true)


## QA-011 : au Deck, la barre d'outils déborde sous l'écran quand le bouton
## « SUIVANT » est affiché (guichet en attente), et davantage dès le J7 (trois
## tampons) : boutons Inspection / Interroger / Suivant et tampons coupés.
## Tolérance 2 px (les boutons sont posés au ras du bord, DS). Le conteneur
## de la barre dépasse toujours de 17 px sous l'écran (sans effet visible).
func test_toolbar_fits_on_screen() -> void:
	var saved: Dictionary = GameState.to_save_dict()
	var failures: PackedStringArray = []
	for day_number: int in [1, 7]:
		GameState.new_campaign(20_871_315)
		GameState.current_day = day_number
		for size: Vector2i in SIZES:
			var vp: SubViewport = SubViewport.new()
			vp.size = size
			add_child_autofree(vp)
			var scene: DayScene = (load("res://scenes/main/day.tscn") as PackedScene).instantiate()
			vp.add_child(scene)
			await wait_process_frames(2)
			scene.briefing.close()
			var ui: ComparisonUI = scene.ui as ComparisonUI
			if size.y > 1080:
				ui.theme = ThemeBuilder.build(Settings.text_scale, ThemeBuilder.min_px_for(DECK_SCALE))
				ui.tool_bar.refresh_fonts()
			await wait_process_frames(4)
			var bar: Rect2 = ui.tool_bar.get_global_rect()
			var limit: float = size.y + 2.0
			var outside: Array[String] = []
			for child: Control in ui.tool_bar.find_children("*", "Button", true, false):
				var r: Rect2 = child.get_global_rect()
				if child.is_visible_in_tree() and (r.end.y > limit or r.end.x > size.x + 2.0):
					outside.append("bouton à x=%d bas=%d" % [roundi(r.position.x), roundi(r.end.y)])
			if not outside.is_empty():
				failures.append("J%d %dx%d : barre %d→%d %s" % [day_number, size.x, size.y, roundi(bar.position.y), roundi(bar.end.y),
						", ".join(outside)])
			vp.queue_free()
			await wait_process_frames(1)
	GameState.apply_save_dict(saved)
	if not failures.is_empty():
		pending("QA-011 : barre d'outils hors écran : %s" % " | ".join(failures))
		return
	assert_true(true)
