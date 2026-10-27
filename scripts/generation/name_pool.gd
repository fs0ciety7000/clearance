## Réserve de prénoms et de noms d'une origine (ARCHITECTURE §5.2, LORE §5) :
## `res://data/names/namepool_<faction>.tres`, référencée par `FactionDef.name_pool`.
##
## Les prénoms sont répartis en `f`/`m`/`x` (épicènes, tirables pour tous) ;
## `reserved_names` ne sont **jamais** tirés (ex. Okonkwo, le mentor du J1),
## mais restent admis dans un cas scénarisé.
class_name NamePool
extends Resource

@export var id: StringName = &""
@export var given_names_f: PackedStringArray = []
@export var given_names_m: PackedStringArray = []
## Prénoms épicènes : tirables quel que soit le sexe.
@export var given_names_x: PackedStringArray = []
@export var family_names: PackedStringArray = []
## Noms (prénoms ou noms de famille) jamais générés.
@export var reserved_names: PackedStringArray = []


## Prénoms tirables pour un sexe (`Passenger.SEX_*`), sans les noms réservés.
func given_names_for(sex: StringName) -> PackedStringArray:
	var pool: PackedStringArray = given_names_x.duplicate()
	if sex != Passenger.SEX_M:
		pool.append_array(given_names_f)
	if sex != Passenger.SEX_F:
		pool.append_array(given_names_m)
	return _without_reserved(pool)


## Noms de famille tirables, sans les noms réservés.
func get_family_names() -> PackedStringArray:
	return _without_reserved(family_names)


## Tous les prénoms de la réserve (tous sexes confondus).
func all_given_names() -> PackedStringArray:
	var pool: PackedStringArray = given_names_f.duplicate()
	pool.append_array(given_names_m)
	pool.append_array(given_names_x)
	return pool


func pick_given_name(rng: SeededRng, sex: StringName) -> String:
	var pool: PackedStringArray = given_names_for(sex)
	if pool.is_empty():
		push_error("NamePool « %s » : aucun prénom pour le sexe %s" % [id, sex])
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func pick_family_name(rng: SeededRng) -> String:
	var pool: PackedStringArray = get_family_names()
	if pool.is_empty():
		push_error("NamePool « %s » : aucun nom de famille" % id)
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func is_reserved(name: String) -> bool:
	return reserved_names.has(name)


func _without_reserved(names: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = []
	for name: String in names:
		if not reserved_names.has(name):
			result.append(name)
	return result
