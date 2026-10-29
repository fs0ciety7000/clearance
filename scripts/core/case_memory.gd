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
## M12 (D-130, B59 ; ARCHITECTURE §11.9) : **pseudo-drapeaux de verdict**
## `cm_<cas>_<verdict>` (`cm_sc_03_deny`, `cm_tuto_missing_document_approve`),
## dérivés au matin de la mémoire (`pseudo_flags`, `with_pseudo_flags`),
## jamais sauvegardés ; une entrée recalculée (verdict inconnu) n'en donne
## aucun. `photo_appearance` : visage de la **photo** de la carte quand il
## diffère du visage réel (SC-03 → SC-84b), `photo_appearance_of`.
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
	# M12 (B59) : visage de la photo de la carte s'il n'est pas celui du porteur.
	var photo: PassengerAppearance = _id_photo(case)
	if photo != null and p.appearance != null and not photo.equals(p.appearance.without_visor()) \
			and not photo.equals(p.appearance):
		entry["photo_appearance"] = photo.serialize()
	return entry


## Préfixe des pseudo-drapeaux de verdict.
const PSEUDO_PREFIX: String = "cm_"


## Pseudo-drapeau d'un verdict (`cm_sc_03_deny`).
static func pseudo_flag(scripted_id: String, verdict: String) -> StringName:
	return StringName("%s%s_%s" % [PSEUDO_PREFIX, scripted_id, verdict])


## Pseudo-drapeaux `cm_<cas>_<verdict>` (vrais) de toutes les entrées dont le
## verdict est connu (`approve`, `deny`, `detain`).
static func pseudo_flags(memory: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	for key: Variant in memory:
		var entry: Variant = memory[key]
		if not entry is Dictionary:
			continue
		var verdict: String = str((entry as Dictionary).get("verdict", ""))
		if verdict in SlippedItem.VERDICT_NAMES:
			flags[pseudo_flag(str(key), verdict)] = true
	return flags


## Drapeaux du matin augmentés des pseudo-drapeaux (copie ; un vrai drapeau
## de même nom l'emporte).
static func with_pseudo_flags(flags: Dictionary[StringName, Variant], memory: Dictionary) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = flags.duplicate()
	var pseudo: Dictionary[StringName, Variant] = pseudo_flags(memory)
	for flag: StringName in pseudo:
		if not result.has(flag):
			result[flag] = pseudo[flag]
	return result


## Noms des pseudo-drapeaux vrais (à ajouter aux `true_flags` du générateur).
static func pseudo_flag_names(memory: Dictionary) -> Array[StringName]:
	var names: Array[StringName] = []
	for flag: StringName in pseudo_flags(memory):
		names.append(flag)
	return names


## Visage de la photo mémorisé (null si la photo était le visage du porteur).
static func photo_appearance_of(entry: Dictionary) -> PassengerAppearance:
	var raw: Variant = entry.get("photo_appearance", null)
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return null
	return PassengerAppearance.deserialize(raw)


## Visage de la photo de la carte d'identité présentée (null sans carte).
static func _id_photo(case: Case) -> PassengerAppearance:
	if case == null:
		return null
	for ref: FieldRef in case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT):
		if ref.document_id != &"id_card":
			continue
		var value: Variant = case.get_value(ref)
		if value is PortraitValue and (value as PortraitValue).appearance != null:
			return (value as PortraitValue).appearance
	return null


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
	var sources: Array[StringName] = []
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted != null:
			sources.append(scripted.appearance_from_case)
			sources.append(scripted.identity_from_case)
	# Acte II : avis d'une personne absente de la file (visage mémorisé).
	for notice: WantedNoticeDef in day.wanted_notices:
		if notice != null:
			sources.append(notice.memory_case_id)
	for source: StringName in sources:
		if source == &"" or result.has(String(source)):
			continue
		var entry: Dictionary = recall(data, campaign_seed, source)
		if not entry.is_empty():
			result[String(source)] = entry
	# QA-060 : visage de la photo d'un cas antérieur (SC-84b ← SC-03) absent
	# d'une mémoire 0.11 (champ ajouté en M12) : recalculé de façon
	# déterministe (D-057) si le cas rejoué présente la même identité.
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted == null or scripted.appearance_from_photo == &"":
			continue
		var key: String = String(scripted.appearance_from_photo)
		var remembered: Variant = result.get(key, null)
		if not remembered is Dictionary:
			continue
		var stored: Dictionary = remembered
		if stored.has("photo_appearance"):
			continue
		var photo: Dictionary = recall_photo(data, campaign_seed, scripted.appearance_from_photo, stored)
		if not photo.is_empty():
			stored["photo_appearance"] = photo
	return result


## QA-060 : visage de la photo de la carte présentée par un cas scénarisé
## (`photo_appearance` de `snapshot`), recalculé en rejouant le cas complet
## (anomalies imposées comprises) sur la graine de campagne. Vide si le cas
## n'existe pas, si sa photo est le visage du porteur, ou si l'identité
## rejouée diffère de celle de `entry` (données d'une autre version).
static func recall_photo(data: DataCatalog, campaign_seed: int, scripted_id: StringName, entry: Dictionary = {}) -> Dictionary:
	for day_number: int in data.days:
		var day: DayDef = data.days[day_number]
		for scripted: ScriptedCaseDef in day.scripted_cases:
			if scripted == null or scripted.id != scripted_id:
				continue
			var flags: Array[StringName] = []
			if scripted.requires_flag != &"":
				flags.append(scripted.requires_flag)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign_seed, day_number), flags)
			builder.set(&"_probing", true)
			var generated: GeneratedCase = builder.build(scripted.at_index)
			if generated == null or generated.case == null:
				return {}
			var replayed: Dictionary = snapshot(day_number, generated.case, VerdictKind.Kind.APPROVE)
			for path: String in ["citizen_id", "given_name", "family_name"]:
				if entry.has(path) and str(entry[path]) != str(replayed.get(path, "")):
					return {}
			var photo: Variant = replayed.get("photo_appearance", {})
			return photo if photo is Dictionary else {}
	return {}


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
