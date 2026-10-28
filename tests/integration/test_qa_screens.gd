## QA (docs/QA.md §4) — écrans de soirée et de fin : cohérence de ce qui est affiché
## avec l'état de la campagne. Bugs ouverts : `pending`.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()


func after_each() -> void:
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


## QA-008 : « SIGNALER AU CONSORTIUM +10 ₵ » (mot des Lucioles, soir du J3)
## crédite tout de suite `GameState.credits`, mais le solde de l'écran
## (`EveningScreen.balance`) n'est pas mis à jour : la prime n'est pas
## disponible pour payer les postes de ce soir et l'écran affiche un « solde
## après la soirée » inférieur au solde réel du rapport de nuit.
func test_reporting_the_note_updates_the_evening_balance() -> void:
	Campaign.new_game(data, 77)
	GameState.current_day = 3
	GameState.credits = 9
	GameState.set_flag(Campaign.FLAG_LUCIOLES_CONTACT, true)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data)
	var evening: EveningScreen = EveningScreen.new()
	evening.setup(data.get_day(3), GameState.credits, 0, lines, GameState.household, Campaign.luciole_note_pending())
	evening.luciole_decided.connect(Campaign.decide_luciole_note)
	add_child_autofree(evening)
	await wait_process_frames(2)
	assert_true(evening.luciole_pending, "mot en attente")
	evening.call(&"_decide_luciole", true)
	assert_eq(GameState.credits, 9 + data.get_economy().report_bonus, "prime créditée")
	if evening.effective_balance() != GameState.credits:
		pending("QA-008 : solde de la soirée %d ₵ après signalement, compte %d ₵" % [evening.effective_balance(), GameState.credits])
		return
	assert_eq(evening.effective_balance(), GameState.credits)


## Textes visibles d'un arbre de contrôles.
func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


## QA-010 : l'écran de fin affiche toujours « JEUDI 22.03.2187 » (clé
## `end_date`), même pour une fin anticipée (F2 au soir du J4, F3 au J6, F1 à
## l'audit du J9).
func test_early_ending_shows_the_date_of_the_last_day_played() -> void:
	var history: Array[Dictionary] = []
	for n: int in range(1, 5):
		history.append({"day": n, "processed": 10, "planned": 12, "correct": 6, "citations": 4, "wage": 30,
				"fines": 10, "spent": 5, "balance": -20})
	var end: EndScreen = EndScreen.new()
	end.epilogue = EndingService.epilogue(EndingService.F2_REASSIGNED, {}, Household.new())
	end.setup(EndingService.F2_REASSIGNED, history, Household.new(), -20, {}, 0.6)
	add_child_autofree(end)
	await wait_process_frames(2)
	var last_day: String = UiText.date(data.get_day(4).game_date)
	var texts: String = " | ".join(_texts(end))
	if texts.contains("22.03.2187") and not texts.contains(last_day):
		pending("QA-010 : fin anticipée au J4 datée du 22.03.2187 (J10) au lieu du %s" % last_day)
		return
	assert_true(texts.contains(last_day), "date du dernier jour joué")
