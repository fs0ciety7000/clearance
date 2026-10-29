## HUD de la Garde de nuit (M12 lot C, I31 ; M12 §2.2, D-126 ; ARCHITECTURE
## §11.5) — contrôleur posé par `DayScene` au-dessus du guichet en session
## Garde. Écoute l'EventBus (`garde_scored`, `garde_error`,
## `garde_tier_changed`, `garde_directive`, `case_presented`) et tient à jour :
## - la barre d'état (`TopBar.set_garde` : SCORE, ERREURS n / 3, PROCHAINE
##   DIRECTIVE · n, palier ; `set_garde_clock` : horloge cosmétique modulo 24 h
##   de `GardeRun.clock_minute()`) ;
## - la **carte de directive** (`GardeDirectiveCard`, « DIRECTIVE DE GARDE N° n »,
##   au plus `DS.DIRECTIVE_HOLD`, passable) et la mise en évidence de la règle
##   au Rulebook à son arrivée (`RulebookPanel.focus_rule`) : ajoutée (NOUVEAU),
##   retirée (barrée, « REPRIS PAR LES QUAIS »), rétablie (« RÉTABLIE ») ;
## - les annonces de palier et de l'aube (`garde_dawn`, passager 80).
## Aucune logique de jeu : le score et les erreurs viennent du `GardeRun`.
class_name GardeHud
extends Node

var ui: ComparisonUI = null
var run: GardeRun = null
## Carte de directive affichée (null sinon).
var card: GardeDirectiveCard = null
## Dernière directive annoncée (`{number, unit_id, action}`), vide sinon.
var last_directive: Dictionary = {}
var _dawn_shown: bool = false


static func attach(p_ui: ComparisonUI, p_run: GardeRun) -> GardeHud:
	var hud: GardeHud = GardeHud.new()
	hud.name = "GardeHud"
	hud.ui = p_ui
	hud.run = p_run
	return hud


func _ready() -> void:
	EventBus.garde_scored.connect(func(_score: int, _points: int) -> void: refresh())
	EventBus.garde_error.connect(func(_case_id: StringName, _citation: String, _errors: int) -> void: refresh())
	EventBus.garde_tier_changed.connect(_on_tier_changed)
	EventBus.garde_directive.connect(_on_directive)
	EventBus.case_presented.connect(func(_case: Case) -> void: dismiss_card())
	EventBus.day_started.connect(func(_day: DayDef, _rb: Array[RulebookEntry]) -> void: refresh.call_deferred())
	if ui != null:
		ui.top_bar.set_garde_mode(true, run.code if run != null else "")
	refresh()


## Passagers avant la prochaine directive (1 → `directive_every`).
func next_directive_in() -> int:
	if run == null or run.def == null:
		return 0
	var every: int = maxi(run.def.directive_every, 1)
	return every - posmod(run.passengers, every)


func refresh() -> void:
	if ui == null or run == null or run.def == null:
		return
	var tier: GardeTierDef = run.def.tier_for(run.passengers + 1)
	var tier_key: String = tier.name_key if tier != null and not tier.name_key.is_empty() else "garde_tier_%d" % run.tier_index
	ui.top_bar.set_garde(run.score, run.errors.size(), run.def.max_errors, next_directive_in(), run.tier_index, tier_key)
	ui.top_bar.set_garde_clock(run.clock_minute())
	if run.is_dawn() and not _dawn_shown:
		_dawn_shown = true
		ui.show_announcement(UiText.t("garde_dawn", "06:00. L'aube. La relève ne vient pas."))


func _on_tier_changed(tier_index: int) -> void:
	refresh()
	if ui == null or run == null:
		return
	var tier: GardeTierDef = run.def.tier_for(run.passengers + 1)
	var key: String = tier.name_key if tier != null and not tier.name_key.is_empty() else "garde_tier_%d" % tier_index
	ui.toasts.push(ToastStack.Kind.INFO, UiText.tf("garde_tier_toast", [tier_index], "PALIER %d").to_upper(), UiText.t(key, ""))


## Directive tirée après le passager en cours : carte, puis règle surlignée au
## Rulebook quand le changement s'applique (passager suivant).
func _on_directive(number: int, unit_id: StringName, action: StringName) -> void:
	last_directive = {"number": number, "unit_id": unit_id, "action": action}
	refresh()
	if ui == null or run == null:
		return
	var unit: GardeUnitDef = run.def.get_unit(unit_id)
	show_card(number, unit, action)
	if unit != null:
		var ids: Array[StringName] = unit.rule_ids()
		if not ids.is_empty():
			ui.rulebook.focus_rule(ids[0], true)


func show_card(number: int, unit: GardeUnitDef, action: StringName) -> GardeDirectiveCard:
	dismiss_card()
	card = GardeDirectiveCard.make(number, unit, action)
	card.dismissed.connect(_on_card_dismissed)
	ui.add_child(card)
	return card


func dismiss_card() -> void:
	if card != null and is_instance_valid(card):
		card.dismiss()


func _on_card_dismissed() -> void:
	card = null
	if ui != null and is_instance_valid(ui) and ui.is_inside_tree():
		ui.focus_default.call_deferred()
