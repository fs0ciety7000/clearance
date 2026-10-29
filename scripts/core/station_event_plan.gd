## Événement de station planifié pour un shift (M12 §3, D-129 ; ARCHITECTURE
## §11.6) — runtime, calculé par `StationEventService` (campagne) ou
## `GardeRun` (Garde), jamais sauvegardé (recalculé depuis la graine).
##
## Index de passager 0-based : l'annonce tombe après le `announce_after`-ième
## passager traité, l'effet couvre les index `start_index` (inclus) →
## `end_index` (exclu ; −1 = fin du jour). Fenêtre horaire (`CLOCK`) : annonce
## à `announce_minute`, effet de `clock_from` à `clock_to` (surcharges
## horaires). Fenêtre en secondes (`SECONDS`) : durée réelle `seconds`.
class_name StationEventPlan
extends RefCounted

enum State { PENDING = 0, ACTIVE = 1, ENDED = 2 }

var event: StationEventDef = null
## Jour de campagne (0 en Garde).
var day_number: int = 0
var garde: bool = false
var announce_after: int = 0
var start_index: int = 0
var end_index: int = -1
## Fenêtre horaire (EV-08) : annonce à cette heure (minutes), effet de
## `clock_from` à `clock_to`.
var announce_minute: int = -1
var clock_from: int = -1
var clock_to: int = -1
var seconds: float = 0.0
## Avertissements gratuits ajoutés ce jour (classe B, compensation D-129).
var free_citations_bonus: int = 0
## Liste nommée publiée pendant la fenêtre (EV-07 : `stolen`) et taille.
var list_label: StringName = &""
var list_size: int = 0
var state: State = State.PENDING
## Secondes réelles restantes (fenêtre `SECONDS`, tenu par le `DayController`).
var seconds_left: float = 0.0


## Source des changements de règles (`ev_05@j12`, `ev_04@g37`).
func source() -> StringName:
	var where: String = "g%d" % announce_after if garde else "j%d" % day_number
	return StringName("%s@%s" % [event.id if event != null else &"ev", where])


## Changements de règles pendant la fenêtre (Garde : `garde_changes` s'il y en a).
func changes() -> Array[RuleChangeDef]:
	var result: Array[RuleChangeDef] = []
	if event == null:
		return result
	var list: Array[RuleChangeDef] = event.garde_changes if garde and not event.garde_changes.is_empty() else event.changes
	for change: RuleChangeDef in list:
		if change != null:
			result.append(change)
	return result


## Texte de l'annonce (Garde : `garde_announce_key` s'il y en a).
func announce_key() -> String:
	if event == null:
		return ""
	if garde and not event.garde_announce_key.is_empty():
		return event.garde_announce_key
	return event.announce_key


## Vrai si l'index de passager est dans la fenêtre (fenêtres en passagers).
func covers(index: int) -> bool:
	if event != null and (event.window_kind == StationEventDef.WindowKind.CLOCK or event.window_kind == StationEventDef.WindowKind.SECONDS):
		return state == State.ACTIVE
	return index >= start_index and (end_index < 0 or index < end_index)


## Passagers restants dans la fenêtre après `processed` passagers traités
## (−1 : jusqu'à la fin du jour, ou fenêtre horaire / en secondes).
func remaining(processed: int) -> int:
	if end_index < 0 or (event != null and event.window_kind in [StationEventDef.WindowKind.CLOCK, StationEventDef.WindowKind.SECONDS]):
		return -1
	return maxi(end_index - maxi(processed, start_index), 0)


## L'événement touche-t-il aux règles actives (ajout, retrait) ? Il est alors
## clos avant un cas scénarisé (D-129, règle 3).
func is_structural() -> bool:
	for change: RuleChangeDef in changes():
		if change.op in [RuleChangeDef.Op.ADD, RuleChangeDef.Op.RETIRE, RuleChangeDef.Op.RESTORE, RuleChangeDef.Op.FORGET]:
			return true
	return false


## Modificateur de la fenêtre (somme), 0 sinon.
func modifier(name: StringName) -> int:
	var total: int = 0
	for change: RuleChangeDef in changes():
		if change.op == RuleChangeDef.Op.MODIFIER and change.modifier == name:
			total += change.amount
	return total
