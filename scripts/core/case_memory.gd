## Mémoire des passagers scénarisés d'un jour à l'autre (M7, NARRATIVE B5) —
## fonctions statiques pures sur des dictionnaires JSON.
##
## Une entrée par cas scénarisé traité (`ScriptedCaseDef.id`) :
## `{day, index, verdict ("approve"…), given_name, family_name, birth_date,
## sex, faction_id, citizen_id, citizen_class, appearance (serialize())}` —
## l'identité **présentée** et le visage réel (ce que le joueur a vu).
## Stockée dans `GameState.case_memory` (sauvegarde v3). Lue par le
## `CaseBuilder` pour `appearance_from_case` / `identity_from_case` (Amara
## J1→J4, Lev J3→J7, Mira J3→J10). Si l'entrée manque (cas non traité, ancienne
## sauvegarde), `recall()` la recalcule de façon déterministe depuis la graine
## de campagne.
class_name CaseMemory
extends RefCounted

## Chemins d'identité recopiés par `identity_from_case`.
const IDENTITY_PATHS: Array[StringName] = [
	&"given_name", &"family_name", &"birth_date", &"sex", &"faction_id", &"citizen_id", &"citizen_class",
]


## Entrée mémorisée pour un cas joué.
static func snapshot(day_number: int, case: Case, verdict: VerdictKind.Kind) -> Dictionary:
	var p: Passenger = case.passenger_presented
	var entry: Dictionary = {
		"day": day_number,
		"index": case.index,
		"verdict": SlippedItem.VERDICT_NAMES[verdict],
	}
	for path: StringName in IDENTITY_PATHS:
		var value: Variant = p.get(path)
		if value is StringName:
			var text: StringName = value
			entry[String(path)] = String(text)
		else:
			entry[String(path)] = value
	# Visage réel, visière relevée (la coiffe couvrante n'est pas l'identité).
	entry["appearance"] = p.appearance.without_visor().serialize() if p.appearance != null else {}
	return entry


## Apparence mémorisée (null si absente).
static func appearance_of(entry: Dictionary) -> PassengerAppearance:
	var raw: Variant = entry.get("appearance", null)
	if not raw is Dictionary:
		return null
	var data: Dictionary = raw
	if data.is_empty():
		return null
	return PassengerAppearance.deserialize(data)


## Surcharges d'identité (`Passenger.TRUTH_PATHS`) tirées d'une entrée.
static func identity_overrides(entry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: StringName in IDENTITY_PATHS:
		if not entry.has(String(path)):
			continue
		var value: Variant = entry[String(path)]
		match path:
			&"birth_date":
				result[path] = SaveService.as_int(value)
			&"sex", &"faction_id", &"citizen_class":
				result[path] = StringName(str(value))
			_:
				result[path] = str(value)
	return result


## Mémoire utile au jour `day` : `memory` complétée des entrées manquantes des
## cas sources (`appearance_from_case`, `identity_from_case`), recalculées.
static func resolve(data: DataCatalog, day: DayDef, campaign_seed: int, memory: Dictionary) -> Dictionary:
	var result: Dictionary = memory.duplicate(true)
	if day == null:
		return result
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted == null:
			continue
		for source: StringName in [scripted.appearance_from_case, scripted.identity_from_case]:
			if source == &"" or result.has(String(source)):
				continue
			var entry: Dictionary = recall(data, campaign_seed, source)
			if not entry.is_empty():
				result[String(source)] = entry
	return result


## Recalcule l'entrée d'un cas scénarisé à partir de la graine de campagne
## (identité et visage du cas propre, sans anomalie ; verdict inconnu).
## Vide si le cas n'existe dans aucun jour des données.
static func recall(data: DataCatalog, campaign_seed: int, scripted_id: StringName) -> Dictionary:
	for day_number: int in data.days:
		var day: DayDef = data.days[day_number]
		for scripted: ScriptedCaseDef in day.scripted_cases:
			if scripted == null or scripted.id != scripted_id:
				continue
			var flags: Array[StringName] = []
			if scripted.requires_flag != &"":
				flags.append(scripted.requires_flag)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign_seed, day_number), flags)
			var generated: GeneratedCase = builder.build_clean(scripted.at_index)
			if generated == null:
				return {}
			var entry: Dictionary = snapshot(day_number, generated.case, VerdictKind.Kind.APPROVE)
			entry["verdict"] = ""
			entry["recalled"] = true
			return entry
	return {}
