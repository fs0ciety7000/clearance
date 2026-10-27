## Foyer de l'agent (GDD §5.4, LORE §11) : Ilan, Noa, Dora — état de campagne.
##
## Santé par proche : `WELL` → `SICK` → `GRAVELY_SICK` → `LOST`, plus deux
## conditions passagères (`hungry`, `cold`) qui s'effacent quand le poste est
## payé. Les compteurs de privation sont portés ici (soirs consécutifs sans
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


## Un proche du foyer.
class Member:
	extends RefCounted
	var id: StringName = &""
	var health: Household.Health = Household.Health.WELL
	var hungry: bool = false
	var cold: bool = false
	## Soirs consécutifs malade sans médicaments.
	var untreated_evenings: int = 0

	func _init(p_id: StringName = &"") -> void:
		id = p_id

	func is_alive() -> bool:
		return health != Household.Health.LOST

	func is_sick() -> bool:
		return health == Household.Health.SICK or health == Household.Health.GRAVELY_SICK

	## Clé d'état affichée, la plus grave d'abord (`hh_state_*`).
	func state_key() -> String:
		match health:
			Household.Health.LOST:
				return "hh_state_lost"
			Household.Health.GRAVELY_SICK:
				return "hh_state_gravely_sick"
			Household.Health.SICK:
				return "hh_state_sick"
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


## Proches malades, les plus graves d'abord (ordre stable du foyer sinon).
func sick_members() -> Array[Member]:
	var result: Array[Member] = []
	for health: Health in [Health.GRAVELY_SICK, Health.SICK]:
		for member: Member in members:
			if member.health == health:
				result.append(member)
	return result


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
	return household


static func _int(value: Variant) -> int:
	return SaveService.as_int(value)
