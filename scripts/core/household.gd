## Foyer de l'agent (GDD §5.4, LORE §11) : Ilan, Noa, Dora — état de campagne.
##
## Santé par proche : `WELL` → `SICK` → `GRAVELY_SICK` → `LOST`, plus des
## conditions passagères (`hungry`, `cold` ; Acte II : `breathless`,
## ESSOUFFLÉ·E, ration d'air non payée) qui s'effacent quand le poste est payé.
## Acte II (docs/ACT2.md B32, sauvegarde v4) : un proche peut être **mis·e en
## attente** (`detained` : vivant·e, libérable, distinct de `LOST`) ou
## **absent·e** (`away` : `soute`, `tycho` — vivant·e, aucune dépense, aucune
## dégradation). `alive` = pas `LOST` ; `present` = vivant·e, ni en attente ni
## absent·e (seuls les proches présents mangent, respirent et tombent malades). Les compteurs de privation sont portés ici (soirs consécutifs sans
## nourriture / chauffage, loyers impayés, soirs en dette). Les transitions
## sont calculées par `EveningService` ; cette classe ne fait que porter l'état
## et le (dé)sérialiser en JSON (sauvegarde, ARCHITECTURE §10).
class_name Household
extends RefCounted

enum Health { WELL, SICK, GRAVELY_SICK, LOST }

const ILAN: StringName = &"ilan"
const NOA: StringName = &"noa"
const DORA: StringName = &"dora"
const MEMBER_IDS: Array[StringName] = [ILAN, NOA, DORA]
## Clés JSON de `Health` (stables : jamais l'entier de l'enum dans la sauvegarde).
const HEALTH_CODES: Array[String] = ["well", "sick", "gravely_sick", "lost"]
## Motifs d'absence (Acte II).
const AWAY_SOUTE: StringName = &"soute"
const AWAY_TYCHO: StringName = &"tycho"


## Un proche du foyer.
class Member:
	extends RefCounted
	var id: StringName = &""
	var health: Household.Health = Household.Health.WELL
	var hungry: bool = false
	var cold: bool = false
	## Soirs consécutifs malade sans médicaments.
	var untreated_evenings: int = 0
	## « Mis·e en attente » (Ilan dénoncé·e ou arrêté·e aux vannes). Acte II :
	## vivant·e et libérable (une sauvegarde v3 portait `LOST` + `detained`).
	var detained: bool = false
	## Acte II : ESSOUFFLÉ·E (ration d'air non payée) et soirs consécutifs.
	var breathless: bool = false
	var breathless_streak: int = 0
	## Acte II : absent·e du foyer (`AWAY_SOUTE`, `AWAY_TYCHO`), vide sinon.
	var away: StringName = &""

	func _init(p_id: StringName = &"") -> void:
		id = p_id

	func is_alive() -> bool:
		return health != Household.Health.LOST

	## Vivant·e, ni mis·e en attente ni absent·e : mange, respire, se soigne.
	func is_present() -> bool:
		return is_alive() and not detained and away == &""

	func is_sick() -> bool:
		return health == Household.Health.SICK or health == Household.Health.GRAVELY_SICK

	## Clé d'état affichée, la plus grave d'abord (`hh_state_*`).
	func state_key() -> String:
		if health == Household.Health.LOST:
			return "hh_state_lost"
		if detained:
			return "hh_state_detained"
		if away == Household.AWAY_SOUTE:
			return "hh_state_away_soute"
		if away == Household.AWAY_TYCHO:
			return "hh_state_away_tycho"
		match health:
			Household.Health.GRAVELY_SICK:
				return "hh_state_gravely_sick"
			Household.Health.SICK:
				return "hh_state_sick"
		if breathless:
			return "hh_state_breathless"
		if hungry and cold:
			return "hh_state_hungry_cold"
		if hungry:
			return "hh_state_hungry"
		if cold:
			return "hh_state_cold"
		return "hh_state_well"


var members: Array[Member] = []
var hunger_streak: int = 0
var cold_streak: int = 0
## Manquements cumulés à l'oxygène de Dora.
var oxygen_misses: int = 0
var unpaid_rent_streak: int = 0
var debt_streak: int = 0


func _init() -> void:
	for id: StringName in MEMBER_IDS:
		members.append(Member.new(id))


func get_member(id: StringName) -> Member:
	for member: Member in members:
		if member.id == id:
			return member
	return null


func alive_members() -> Array[Member]:
	var result: Array[Member] = []
	for member: Member in members:
		if member.is_alive():
			result.append(member)
	return result


## Proches présents (vivants, ni mis en attente ni absents).
func present_members() -> Array[Member]:
	var result: Array[Member] = []
	for member: Member in members:
		if member.is_present():
			result.append(member)
	return result


## Proches **présents** malades, les plus graves d'abord (ordre stable du foyer
## sinon) : seuls eux reçoivent des médicaments et s'aggravent.
func sick_members() -> Array[Member]:
	var result: Array[Member] = []
	for health: Health in [Health.GRAVELY_SICK, Health.SICK]:
		for member: Member in members:
			if member.health == health and member.is_present():
				result.append(member)
	return result


## Proches vivants (`alive` des fins : un proche mis·e en attente ou absent·e compte).
func alive_count() -> int:
	return alive_members().size()


## Proches présents (`present` des fins de l'Acte II, F6).
func present_count() -> int:
	return present_members().size()


## Ilan (ou un autre proche) est mis·e en attente : vivant·e, hors du foyer.
func detain_member(id: StringName) -> void:
	var member: Member = get_member(id)
	if member == null or not member.is_alive():
		return
	member.detained = true
	_clear_conditions(member)


## Libéré·e (caution) : rentre au foyer, MALADE (Acte II).
func release_member(id: StringName) -> void:
	var member: Member = get_member(id)
	if member == null or not member.detained or not member.is_alive():
		return
	member.detained = false
	member.away = &""
	if member.health == Health.WELL:
		member.health = Health.SICK
		member.untreated_evenings = 0


## Absent·e du foyer (`AWAY_SOUTE`, `AWAY_TYCHO`) : vivant·e, sans dépense.
func send_away(id: StringName, reason: StringName) -> void:
	var member: Member = get_member(id)
	if member == null or not member.is_alive() or member.detained:
		return
	member.away = reason
	_clear_conditions(member)


## Retour au foyer d'un proche absent ; `sick` : rentre MALADE.
func bring_home(id: StringName, sick: bool = false) -> void:
	var member: Member = get_member(id)
	if member == null or member.away == &"" or not member.is_alive():
		return
	member.away = &""
	if sick and member.health == Health.WELL:
		member.health = Health.SICK
		member.untreated_evenings = 0


static func _clear_conditions(member: Member) -> void:
	member.hungry = false
	member.cold = false
	member.breathless = false
	member.breathless_streak = 0
	member.untreated_evenings = 0


func all_lost() -> bool:
	return alive_members().is_empty()


func duplicate_household() -> Household:
	return Household.from_dict(to_dict())


func to_dict() -> Dictionary:
	var list: Array[Dictionary] = []
	for member: Member in members:
		list.append({
			"id": String(member.id),
			"health": HEALTH_CODES[member.health],
			"hungry": member.hungry,
			"cold": member.cold,
			"untreated_evenings": member.untreated_evenings,
			"detained": member.detained,
			"breathless": member.breathless,
			"breathless_streak": member.breathless_streak,
			"away": String(member.away),
		})
	return {
		"members": list,
		"hunger_streak": hunger_streak,
		"cold_streak": cold_streak,
		"oxygen_misses": oxygen_misses,
		"unpaid_rent_streak": unpaid_rent_streak,
		"debt_streak": debt_streak,
	}


## Reconstruit un foyer depuis `to_dict()` (JSON : les entiers peuvent revenir
## en flottants). Valeurs inconnues ou manquantes → valeurs par défaut.
static func from_dict(data: Dictionary) -> Household:
	var household: Household = Household.new()
	household.hunger_streak = _int(data.get("hunger_streak", 0))
	household.cold_streak = _int(data.get("cold_streak", 0))
	household.oxygen_misses = _int(data.get("oxygen_misses", 0))
	household.unpaid_rent_streak = _int(data.get("unpaid_rent_streak", 0))
	household.debt_streak = _int(data.get("debt_streak", 0))
	var list: Variant = data.get("members", [])
	if list is Array:
		for entry: Variant in list:
			if not entry is Dictionary:
				continue
			var dict: Dictionary = entry
			var member: Member = household.get_member(StringName(str(dict.get("id", ""))))
			if member == null:
				continue
			var code: int = HEALTH_CODES.find(str(dict.get("health", "well")))
			member.health = (code if code >= 0 else Health.WELL) as Health
			member.hungry = dict.get("hungry", false) == true
			member.cold = dict.get("cold", false) == true
			member.untreated_evenings = _int(dict.get("untreated_evenings", 0))
			member.detained = dict.get("detained", false) == true
			member.breathless = dict.get("breathless", false) == true
			member.breathless_streak = _int(dict.get("breathless_streak", 0))
			member.away = StringName(str(dict.get("away", "")))
	return household


static func _int(value: Variant) -> int:
	return SaveService.as_int(value)
