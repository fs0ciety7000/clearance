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
## M13 (EV-09) : profil tiré parmi `StationEventDef.override_profiles` (−1 =
## aucun : portée des données).
var profile_index: int = -1
## Copies des surcharges à la portée du profil (jamais la Resource partagée).
var _scoped: Array[RuleChangeDef] = []


## Source des changements de règles (`ev_05@j12`, `ev_04@g37`).
func source() -> StringName:
	var where: String = "g%d" % announce_after if garde else "j%d" % day_number
	return StringName("%s@%s" % [event.id if event != null else &"ev", where])


## Changements de règles pendant la fenêtre (Garde : `garde_changes` s'il y en a).
func changes() -> Array[RuleChangeDef]:
	var result: Array[RuleChangeDef] = []
	if event == null:
		return result
	if not _scoped.is_empty():
		return _scoped.duplicate()
	var list: Array[RuleChangeDef] = event.garde_changes if garde and not event.garde_changes.is_empty() else event.changes
	var scope: Dictionary = profile()
	for change: RuleChangeDef in list:
		if change == null:
			continue
		if not scope.is_empty() and change.op == RuleChangeDef.Op.OVERRIDE:
			var scoped: RuleChangeDef = change.duplicate() as RuleChangeDef
			scoped.params = change.params.duplicate()
			scoped.faction_ids = _names(scope.get("faction_ids", []))
			scoped.purposes = _names(scope.get("purposes", []))
			result.append(scoped)
		else:
			result.append(change)
	if not scope.is_empty():
		_scoped = result.duplicate()
	return result


## M13 (EV-09) : tire le profil de l'événement (`override_profiles`) avec
## `rng` ; sans profils, rien n'est tiré (aucun tirage consommé).
func draw_profile(rng: SeededRng) -> void:
	_scoped.clear()
	if event == null or event.override_profiles.is_empty():
		profile_index = -1
		return
	profile_index = rng.randi_range(0, event.override_profiles.size() - 1)


## QA-066 : profil imposé (`CaseBuilder.fit_alert_profile`, avant l'annonce) ;
## les copies de surcharges (`changes()`) sont recalculées.
func set_profile_index(index: int) -> void:
	if index == profile_index:
		return
	_scoped.clear()
	profile_index = index


## Profil tiré (`{faction_ids, purposes, label_key}`), vide sans profil.
func profile() -> Dictionary:
	if event == null or profile_index < 0 or profile_index >= event.override_profiles.size():
		return {}
	return event.override_profiles[profile_index]


## Clé du libellé du profil (`sev_contraband_alert_tyc`…) : argument `%s` de
## l'annonce et de la ligne du Rulebook ; vide sans profil.
func profile_label_key() -> String:
	return str(profile().get("label_key", ""))


static func _names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values:
			result.append(StringName(str(value)))
	return result


## Texte de l'annonce (Garde : `garde_announce_key` s'il y en a).
func announce_key() -> String:
	if event == null:
		return ""
	if garde and not event.garde_announce_key.is_empty():
		return event.garde_announce_key
	return event.announce_key


## Titre du bandeau (Garde : `garde_title_key` s'il y en a ; D-138).
func title_key() -> String:
	if event == null:
		return ""
	if garde and not event.garde_title_key.is_empty():
		return event.garde_title_key
	return event.title_key if not event.title_key.is_empty() else "sev_%s_title" % event.key


## Ligne ambre du Rulebook (Garde : `garde_rulebook_key` s'il y en a ; D-138),
## vide si l'événement n'en a pas. `%d` = `remaining(processed)`.
func rulebook_key() -> String:
	if event == null:
		return ""
	if garde and not event.garde_rulebook_key.is_empty():
		return event.garde_rulebook_key
	return event.rulebook_key


## Fenêtre effective : en Garde, toute fenêtre se compte en passagers
## (`garde_window_passengers`, D-138) — jamais en heure ni en secondes.
func window_kind() -> StationEventDef.WindowKind:
	if garde or event == null:
		return StationEventDef.WindowKind.PASSENGERS
	return event.window_kind


## Vrai si la fenêtre se compte en passagers (bandeau « n PASSAGERS »).
func counts_passengers() -> bool:
	return window_kind() == StationEventDef.WindowKind.PASSENGERS or (window_kind() == StationEventDef.WindowKind.REST_OF_DAY
			and end_index >= 0)


## Vrai si l'index de passager est dans la fenêtre (fenêtres en passagers).
func covers(index: int) -> bool:
	if window_kind() == StationEventDef.WindowKind.CLOCK or window_kind() == StationEventDef.WindowKind.SECONDS:
		return state == State.ACTIVE
	return index >= start_index and (end_index < 0 or index < end_index)


## Passagers restants dans la fenêtre après `processed` passagers traités
## (−1 : jusqu'à la fin du jour, ou fenêtre horaire / en secondes de la
## campagne). En Garde, toujours un nombre de passagers (D-138).
func remaining(processed: int) -> int:
	if end_index < 0 or window_kind() in [StationEventDef.WindowKind.CLOCK, StationEventDef.WindowKind.SECONDS]:
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
