## `NAME_MISMATCH` (GDD §6) : nom, prénom ou date de naissance altéré sur un
## document — 1 lettre, une partie d'un nom composé, ou inversion jour/mois
## (sinon un chiffre de l'année). Détecté par R07. Date « année seule »
## (`00.00.AAAA`, Dérivants) : toujours l'année (jamais d'inversion, NARRATIVE
## §4.10), sans tirage supplémentaire.
class_name NameMismatchInjector
extends FieldMismatchInjector

const PATHS: Array[StringName] = [&"family_name", &"given_name", &"birth_date"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.NAME_MISMATCH


func get_paths() -> Array[StringName]:
	return PATHS


func alter(state: InjectionState, path: StringName, value: Variant) -> Variant:
	if path == &"birth_date":
		var date: int = value
		return _alter_date(state.rng, date)
	var text: String = str(value)
	if path == &"family_name" and text.contains("-") and state.rng.chance(0.5):
		var parts: PackedStringArray = text.split("-", false)
		return parts[state.rng.randi_range(0, parts.size() - 1)]
	return FieldMismatchInjector.substitute_letter(state.rng, text)


static func _alter_date(rng: SeededRng, date: int) -> int:
	var ymd: Vector3i = GameDate.to_ymd(date)
	# Année seule : `(AAAA, 0, 0)`, la condition est fausse sans tirer `chance`.
	if not GameDate.is_year_only(date) and ymd.z <= 12 and ymd.z != ymd.y and rng.chance(0.7):
		return GameDate.from_ymd(ymd.x, ymd.z, ymd.y)
	var shift: int = rng.randi_range(1, 9) * (1 if rng.chance(0.5) else -1)
	return GameDate.add_years(date, shift)
