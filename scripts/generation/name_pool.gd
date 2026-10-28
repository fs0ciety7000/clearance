## Réserve de prénoms et de noms d'une origine (ARCHITECTURE §5.2, LORE §5) :
## `res://data/names/namepool_<faction>.tres`, référencée par `FactionDef.name_pool`.
##
## Les prénoms sont répartis en `f`/`m`/`x` (épicènes, tirables pour tous) ;
## `reserved_names` ne sont **jamais** tirés (ex. Okonkwo, le mentor du J1, et
## les noms de famille distinctifs des personnages scénarisés), mais restent
## admis dans un cas scénarisé. `reserved_full_names` (« Prénom Nom » des
## personnages scénarisés et des avis de recherche, QA-002) : la combinaison
## n'est jamais générée — le prénom est remplacé de façon déterministe, **sans
## tirage supplémentaire** (le flux aléatoire, donc l'équilibrage, est inchangé).
## Les deux listes sont calculées par `tools/build_data.gd`.
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
## Noms complets (« Prénom Nom ») jamais générés.
@export var reserved_full_names: PackedStringArray = []


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


func is_reserved_full_name(given: String, family: String) -> bool:
	return reserved_full_names.has("%s %s" % [given, family])


## `given` si « given family » n'est pas réservé ; sinon le prénom suivant de la
## réserve du sexe (ordre de `given_names_for`, circulaire) qui ne l'est pas.
## Déterministe et sans tirage.
func avoid_reserved_full_name(given: String, family: String, sex: StringName) -> String:
	if not is_reserved_full_name(given, family):
		return given
	var pool: PackedStringArray = given_names_for(sex)
	var start: int = maxi(pool.find(given), 0)
	for step: int in range(1, pool.size() + 1):
		var candidate: String = pool[(start + step) % pool.size()]
		if not is_reserved_full_name(candidate, family):
			return candidate
	return given


func _without_reserved(names: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = []
	for name: String in names:
		if not reserved_names.has(name):
			result.append(name)
	return result
