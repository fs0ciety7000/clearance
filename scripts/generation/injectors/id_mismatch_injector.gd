## `ID_MISMATCH` (GDD §6) : 1–2 caractères du N° ID altérés sur un document,
## sans jamais produire `O I 0 1` (LORE §5) et sans toucher le chiffre
## d'origine (le format reste valide ; seule la concordance casse).
## Détecté par R07. Paramètre : `char_count`.
class_name IdMismatchInjector
extends FieldMismatchInjector

const PATHS: Array[StringName] = [&"citizen_id"]
## Positions modifiables de `HG-#NNN-XXXX` : `NNN` et `XXXX`.
const DIGIT_POSITIONS: Array[int] = [4, 5, 6]
const CHAR_POSITIONS: Array[int] = [8, 9, 10, 11]
const SAFE_DIGITS: String = "23456789"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.ID_MISMATCH


func get_paths() -> Array[StringName]:
	return PATHS


func alter(state: InjectionState, _path: StringName, value: Variant) -> Variant:
	var text: String = str(value)
	if not PassengerGenerator.is_valid_citizen_id_format(text):
		return null
	var count: int = clampi(state.param_int(&"char_count", state.rng.randi_range(1, 2)), 1, 2)
	var positions: Array = DIGIT_POSITIONS + CHAR_POSITIONS
	positions = state.rng.shuffled(positions)
	for i: int in count:
		var index: int = positions[i]
		var pool: String = SAFE_DIGITS if DIGIT_POSITIONS.has(index) else PassengerGenerator.ID_SAFE_CHARS
		pool = pool.replace(text[index], "")
		text = text.substr(0, index) + pool[state.rng.randi_range(0, pool.length() - 1)] + text.substr(index + 1)
	return text
