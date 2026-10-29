## Changement de règles en cours de shift (M12, B54 ; ARCHITECTURE §11.3).
##
## Une opération sur le RuleSet **de shift** (copie propre au shift, jamais le
## `.tres` partagé) : directive de Garde (ajout), rotation du palier 4
## (retrait, oubli, rétablissement), événement de station (suspension d'une
## règle, surcharge d'un paramètre, modificateur du shift). Données (`.tres`
## de lot B dans `StationEventDef.changes`) ou construit à la volée
## (`GardeService`). Appliqué par `RuleContext.apply_changes` /
## `apply_pending` (au passager **suivant**, D-077), défait par source
## (`RuleSet.revert_source`).
##
## Opérations :
## - `ADD` : `rule` entre dans les règles actives (badge NOUVEAU si `mark_new`) ;
## - `RETIRE` : `rule_id` sort des règles actives et reste au Rulebook en ligne
##   barrée (`note_key` : `sev_mrz_reader_rb`, `rb_retired_quais`…) ;
## - `FORGET` : la ligne barrée de `rule_id` disparaît du Rulebook ;
## - `RESTORE` : `rule_id` (retirée ou oubliée) redevient active, à sa place ;
## - `OVERRIDE` : surcharge de paramètres (`params`) de `rule_id`, lue par les
##   familles de règles via `RuleContext.param()` ; portée facultative par
##   origine (`faction_ids`), motif (`purposes`) et heure de présentation
##   (`from_minute` inclus → `to_minute` exclu, minutes depuis minuit) ;
## - `MODIFIER` : modificateur entier du shift (`modifier`, `amount`), additif
##   par source, lu par `RuleContext.modifier()` (catalogue en §11.3).
class_name RuleChangeDef
extends Resource

enum Op { ADD = 0, RETIRE = 1, FORGET = 2, RESTORE = 3, OVERRIDE = 4, MODIFIER = 5 }

# Modificateurs connus (`MODIFIER`). Les effets marqués « DayController » sont
# appliqués par le contrôleur du jour ; les autres sont lus par les règles,
# le scoring ou le générateur (lot B).
## +n avertissements gratuits ce jour (compensation des événements de classe B).
const MOD_FREE_CITATIONS: StringName = &"free_citations"
## Avertissements gratuits suspendus (EV-04 : toute citation coûte).
const MOD_NO_FREE_CITATIONS: StringName = &"no_free_citations"
## Prime en ₵ par verdict juste (EV-04 : 2 ₵) — DayController.
const MOD_CORRECT_BONUS: StringName = &"correct_bonus"
## Garde : points par verdict juste (EV-04 en Garde : 2) — DayController.
const MOD_SCORE_PER_CORRECT: StringName = &"score_per_correct"
## REFUS NON MOTIVÉ suspendu (EV-02, comparateur en panne) — DayController.
const MOD_COMPARATOR_DOWN: StringName = &"comparator_down"
## Plafond d'anomalies injectées par passager (classe B : 1) — générateur.
const MOD_MAX_ANOMALIES: StringName = &"max_anomalies"
## Aucune anomalie subtile (classe B) — générateur.
const MOD_NO_SUBTLE: StringName = &"no_subtle"
## Horloge du shift gelée (EV-05) — DayController.
const MOD_CLOCK_FROZEN: StringName = &"clock_frozen"
## Passagers ajoutés à la file (EV-06 : +3) — DayController, une fois.
const MOD_EXTRA_PASSENGERS: StringName = &"extra_passengers"
## Secondes ajoutées au shift (EV-06 : +120) — DayController, une fois.
const MOD_EXTRA_SECONDS: StringName = &"extra_seconds"

@export var op: Op = Op.ADD
## `ADD` : règle ajoutée (ressource partagée, jamais mutée).
@export var rule: Rule = null
## `RETIRE`, `FORGET`, `RESTORE`, `OVERRIDE` : règle visée.
@export var rule_id: StringName = &""
## `RETIRE` : motif de la ligne barrée au Rulebook.
@export var note_key: String = ""
## `ADD` : badge « NOUVEAU » (remplace les badges précédents).
@export var mark_new: bool = true
## `OVERRIDE` : paramètre → valeur (`max_age_days`, `exempt_purposes`…).
@export var params: Dictionary[StringName, Variant] = {}
## `OVERRIDE` : portée (vide = tous).
@export var faction_ids: Array[StringName] = []
@export var purposes: Array[StringName] = []
@export var from_minute: int = -1
@export var to_minute: int = -1
## `MODIFIER`.
@export var modifier: StringName = &""
@export var amount: int = 0


static func add(p_rule: Rule, p_mark_new: bool = true) -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.ADD
	change.rule = p_rule
	change.rule_id = p_rule.id if p_rule != null else &""
	change.mark_new = p_mark_new
	return change


static func retire(p_rule_id: StringName, p_note_key: String = "") -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.RETIRE
	change.rule_id = p_rule_id
	change.note_key = p_note_key
	return change


static func forget(p_rule_id: StringName) -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.FORGET
	change.rule_id = p_rule_id
	return change


static func restore(p_rule_id: StringName) -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.RESTORE
	change.rule_id = p_rule_id
	return change


static func override(p_rule_id: StringName, p_params: Dictionary[StringName, Variant],
		p_faction_ids: Array[StringName] = [], p_purposes: Array[StringName] = [],
		p_from_minute: int = -1, p_to_minute: int = -1) -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.OVERRIDE
	change.rule_id = p_rule_id
	change.params = p_params.duplicate()
	change.faction_ids = p_faction_ids.duplicate()
	change.purposes = p_purposes.duplicate()
	change.from_minute = p_from_minute
	change.to_minute = p_to_minute
	return change


static func modify(p_modifier: StringName, p_amount: int) -> RuleChangeDef:
	var change: RuleChangeDef = RuleChangeDef.new()
	change.op = Op.MODIFIER
	change.modifier = p_modifier
	change.amount = p_amount
	return change


## Vrai si la surcharge (`OVERRIDE`) s'applique à ce passager et à cette heure
## (`minute` < 0 : heure inconnue, une surcharge horaire ne s'applique pas).
func applies_to(faction_id: StringName, purpose: StringName, minute: int) -> bool:
	if not faction_ids.is_empty() and not faction_ids.has(faction_id):
		return false
	if not purposes.is_empty() and not purposes.has(purpose):
		return false
	if from_minute >= 0 and (minute < 0 or minute < from_minute):
		return false
	if to_minute >= 0 and (minute < 0 or minute >= to_minute):
		return false
	return true
