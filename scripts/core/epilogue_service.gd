## Épilogue « Un an plus tard » (J31) — M12 §1, D-122 → D-125, B52 ;
## ARCHITECTURE §11.4. Service statique pur.
##
## - **Éligibilité** (D-122) : toute fin F1–F10 jugée après le pivot du J20
##   (drapeau `act3_started`) ; jamais les fins des actes I et II.
## - **Variante** (`variant_of`) et **clé** (`ending_key`, 13 clés) ; **monde**
##   (`world_of`, D-124) : A `f1 f3 f4 f7 f5b`, B `f5c f5s f9`, C `f8 f10`,
##   D `f2 f6t f6d`.
## - **Graine d'épilogue** (`make_seed`, D-125) : dictionnaire minimal sans
##   dépendance à l'emplacement (fin, variante, monde, jour, graine de
##   campagne, drapeaux de la liste blanche `EpilogueDef.read_flags`, foyer,
##   entrées `CaseMemory` utiles) ; stockée dans le profil et en
##   `slot_N/day_31.json`. Le J31 rejoue depuis la graine seule : la partie
##   terminée n'est jamais modifiée.
## - **J31** : `day_for` (DayDef du monde), `morning_flags`, `household_of`,
##   `memory_of`, `intro_key` ; **conclusion** composée (`conclusion`).
class_name EpilogueService
extends RefCounted

const DEF_PATH: String = "res://data/epilogue/epilogue.tres"
const EPILOGUE_DAY: int = 31
## Version du format de la graine.
const SEED_VERSION: int = 1
const WORLD_A: StringName = &"a"
const WORLD_B: StringName = &"b"
const WORLD_C: StringName = &"c"
const WORLD_D: StringName = &"d"

# Variantes (`variant_of`).
const VARIANT_AUDIT: StringName = &"audit"
const VARIANT_REVIEW: StringName = &"review"
const VARIANT_DEPOSITION: StringName = &"deposition"
const VARIANT_DOUBLE: StringName = &"double"
const VARIANT_CHARTER: StringName = &"c"
const VARIANT_SECOND_VALVE: StringName = &"s"
const VARIANT_BURNERS: StringName = &"b"
const VARIANT_J10: StringName = &"j10"
const VARIANT_J20: StringName = &"j20"
const VARIANT_TYCHO: StringName = &"t"
const VARIANT_DRIFT: StringName = &"d"

## Clé de variante → monde (D-124). Repli si les données n'en disent rien.
const WORLD_OF_KEY: Dictionary[StringName, StringName] = {
	&"f1": WORLD_A, &"f3": WORLD_A, &"f4": WORLD_A, &"f7": WORLD_A, &"f5b": WORLD_A,
	&"f5c": WORLD_B, &"f5s": WORLD_B, &"f9": WORLD_B,
	&"f8": WORLD_C, &"f10": WORLD_C,
	&"f2": WORLD_D, &"f6t": WORLD_D, &"f6d": WORLD_D,
}

static var _def_cache: EpilogueDef = null


## Données de l'épilogue (`data/epilogue/epilogue.tres`), ou null si absentes.
static func load_def() -> EpilogueDef:
	if _def_cache == null and ResourceLoader.exists(DEF_PATH):
		_def_cache = load(DEF_PATH) as EpilogueDef
	return _def_cache


## Acte d'une partie d'après ses drapeaux (1, 2 ou 3).
static func act_of(flags: Dictionary[StringName, Variant]) -> int:
	if FlagCondition.is_flag_true(flags, EndingService.FLAG_ACT3):
		return 3
	if FlagCondition.is_flag_true(flags, EndingService.FLAG_ACT2):
		return 2
	return 1


## Variante d'une fin (D-132, Dossier) : F1 `audit` / `review` / `deposition`
## / `double` ; F5 `b` (Brûlants, tous actes), `c` (Charte) / `s` (Seconde
## Vanne) à l'Acte III ; F6 `j10` / `j20` / `t` (Tycho) / `d` (Dérive) ; vide sinon.
static func variant_of(ending: StringName, flags: Dictionary[StringName, Variant]) -> StringName:
	var act: int = act_of(flags)
	match ending:
		EndingService.F1_ARRESTED:
			if FlagCondition.is_flag_true(flags, EndingService.FLAG_AUDIT_ARRESTED):
				return VARIANT_AUDIT
			if FlagCondition.is_flag_true(flags, EndingService.FLAG_REVIEW_ARRESTED):
				return VARIANT_REVIEW
			if FlagCondition.is_flag_true(flags, EndingService.FLAG_DEPOSITION_ARRESTED):
				return VARIANT_DEPOSITION
			return VARIANT_DOUBLE
		EndingService.F5_AIR:
			var burners: bool
			match act:
				3:
					burners = EndingService.is_burners_variant3(flags)
				2:
					burners = EndingService.is_burners_variant2(flags)
				_:
					burners = EndingService.is_burners_variant(flags)
			if burners:
				return VARIANT_BURNERS
			if act == 3:
				return VARIANT_CHARTER if FlagCondition.is_flag_true(flags, &"climate_vanne") else VARIANT_SECOND_VALVE
			return &""
		EndingService.F6_DRIFT:
			if FlagCondition.is_flag_true(flags, &"exit3_drift"):
				return VARIANT_DRIFT
			if act == 3:
				return VARIANT_TYCHO
			return VARIANT_J20 if act == 2 else VARIANT_J10
	return &""


## Clé d'épilogue d'une fin et de sa variante (`f1`, `f5b`, `f6t`…), vide si
## la variante n'a pas d'épilogue (F6 des J10 / J20, fins inconnues).
static func ending_key(ending: StringName, variant: StringName) -> StringName:
	if not EndingService.ALL_ENDINGS.has(ending):
		return &""
	var base: String = String(ending).get_slice("_", 0)
	match ending:
		EndingService.F5_AIR:
			return StringName(base + String(variant)) if variant in [VARIANT_BURNERS, VARIANT_CHARTER, VARIANT_SECOND_VALVE] else &""
		EndingService.F6_DRIFT:
			return StringName(base + String(variant)) if variant in [VARIANT_TYCHO, VARIANT_DRIFT] else &""
	return StringName(base)


## Vrai si la fin ouvre le J31 (D-122) : fin F1–F10 de l'Acte III.
static func is_eligible(ending: StringName, flags: Dictionary[StringName, Variant]) -> bool:
	if not EndingService.ALL_ENDINGS.has(ending) or act_of(flags) != 3:
		return false
	return ending_key(ending, variant_of(ending, flags)) != &""


## Monde du J31 (`a`…`d`), vide si la fin n'ouvre pas l'épilogue. Les données
## (`EpilogueEndingDef.world`) l'emportent sur la table `WORLD_OF_KEY`.
static func world_of(ending: StringName, flags: Dictionary[StringName, Variant], def: EpilogueDef = null) -> StringName:
	if not is_eligible(ending, flags):
		return &""
	return world_of_key(ending_key(ending, variant_of(ending, flags)), def)


static func world_of_key(key: StringName, def: EpilogueDef = null) -> StringName:
	var source: EpilogueDef = def if def != null else load_def()
	if source != null:
		var ending_def: EpilogueEndingDef = source.get_ending(key)
		if ending_def != null and ending_def.world != &"":
			return ending_def.world
	return WORLD_OF_KEY.get(key, &"")


## Clé du profil d'une variante de fin (`<fin>:<variante>`).
static func profile_key_of(ending: StringName, variant: StringName) -> String:
	return "%s:%s" % [ending, variant]


static func profile_key(epi: Dictionary) -> String:
	return profile_key_of(StringName(str(epi.get("ending", ""))), StringName(str(epi.get("variant", ""))))


## Graine d'épilogue (D-125) ; vide si la fin n'ouvre pas le J31. `memory` :
## `GameState.case_memory` ; `day` : dernier jour joué.
static func make_seed(ending: StringName, flags: Dictionary[StringName, Variant], household: Household,
		memory: Dictionary, campaign_seed: int, day: int, def: EpilogueDef = null) -> Dictionary:
	if not is_eligible(ending, flags):
		return {}
	var source: EpilogueDef = def if def != null else load_def()
	var variant: StringName = variant_of(ending, flags)
	var key: StringName = ending_key(ending, variant)
	var kept: Dictionary = {}
	var whitelist: Array[StringName] = []
	if source != null:
		whitelist = source.read_flags
	for flag: StringName in flags:
		if whitelist.is_empty() or whitelist.has(flag) or flag == EndingService.FLAG_ACT3:
			kept[String(flag)] = flags[flag]
	var remembered: Dictionary = {}
	var memory_ids: Array[StringName] = [&"tuto_concordant", &"sc_04", &"sc_82a", &"sc_82b"]
	if source != null:
		memory_ids = source.memory_case_ids
	for case_id: StringName in memory_ids:
		if memory.has(String(case_id)):
			remembered[String(case_id)] = (memory[String(case_id)] as Dictionary).duplicate(true)
	return {
		"epilogue_version": SEED_VERSION,
		"ending": String(ending),
		"variant": String(variant),
		"ending_key": String(key),
		"world": String(world_of_key(key, source)),
		"day": day,
		"campaign_seed": campaign_seed,
		"flags": kept,
		"household": household.to_dict() if household != null else Household.new().to_dict(),
		"memory": remembered,
	}


## Graine lisible (types JSON tolérés) ou vide si invalide.
static func sanitize_seed(raw: Dictionary) -> Dictionary:
	if raw.is_empty() or str(raw.get("ending", "")).is_empty() or str(raw.get("world", "")).is_empty():
		return {}
	var epi: Dictionary = raw.duplicate(true)
	epi["epilogue_version"] = SaveService.as_int(raw.get("epilogue_version", SEED_VERSION), SEED_VERSION)
	epi["day"] = SaveService.as_int(raw.get("day", 30), 30)
	epi["campaign_seed"] = SaveService.as_int(raw.get("campaign_seed", 0))
	for key: String in ["flags", "household", "memory"]:
		if not epi.get(key) is Dictionary:
			epi[key] = {}
	return epi


## Préfixe du pseudo-drapeau de la fin du J31 (`epi_ending_f1`, `epi_ending_f10`…).
const ENDING_FLAG_PREFIX: String = "epi_ending_"


## Drapeaux du matin du J31 (graine) : `act3_started` toujours vrai, plus les
## pseudo-drapeaux recalculés (jamais dans la graine, D-125) — fin
## `epi_ending_<clé>` (`ending_flag`) et foyer `hh_*`
## (`EveningService.context_flags` sur `household_of`). Un vrai drapeau de
## même nom l'emporte.
static func morning_flags(epi: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	var raw: Variant = epi.get("flags", {})
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key: Variant in dict:
			flags[StringName(str(key))] = json_value(dict[key])
	flags[EndingService.FLAG_ACT3] = true
	var pseudo: Dictionary[StringName, Variant] = pseudo_flags(epi)
	for flag: StringName in pseudo:
		if not flags.has(flag):
			flags[flag] = pseudo[flag]
	return flags


## Pseudo-drapeaux du J31 : `epi_ending_<clé>` (vrai) et foyer `hh_*`
## (`hh_<proche>_present|alive|held|away|sick`, `hh_any_sick`, jauges
## `hh_alive`, `hh_present`).
static func pseudo_flags(epi: Dictionary) -> Dictionary[StringName, Variant]:
	var empty: Dictionary[StringName, Variant] = {}
	var result: Dictionary[StringName, Variant] = EveningService.context_flags(empty, household_of(epi))
	var flag: StringName = ending_flag(StringName(str(epi.get("ending_key", ""))))
	if flag != &"":
		result[flag] = true
	return result


## `epi_ending_<clé>` (`f1`, `f5c`, `f10`…) ; vide sans clé.
static func ending_flag(key: StringName) -> StringName:
	return StringName(ENDING_FLAG_PREFIX + String(key)) if key != &"" else &""


static func household_of(epi: Dictionary) -> Household:
	var raw: Variant = epi.get("household", {})
	return Household.from_dict(raw if raw is Dictionary else {})


static func memory_of(epi: Dictionary) -> Dictionary:
	var raw: Variant = epi.get("memory", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## `DayDef` du monde de la graine (ressource partagée : le `DayController` en
## fait une copie de shift), ou null si les données manquent.
static func day_for(epi: Dictionary, def: EpilogueDef = null) -> DayDef:
	var source: EpilogueDef = def if def != null else load_def()
	if source == null:
		return null
	var world: EpilogueWorldDef = source.get_world(StringName(str(epi.get("world", ""))))
	return world.day_def if world != null else null


## Graine du jour J31 (générateur) : même graine de campagne, jour 31.
static func day_seed(epi: Dictionary) -> int:
	return SeededRng.day_seed(SaveService.as_int(epi.get("campaign_seed", 0)), EPILOGUE_DAY)


## Briefing propre à la variante (`day31_d_intro_f6t`), vide sinon.
static func intro_key(epi: Dictionary, def: EpilogueDef = null) -> String:
	var source: EpilogueDef = def if def != null else load_def()
	if source == null:
		return ""
	var ending_def: EpilogueEndingDef = source.get_ending(StringName(str(epi.get("ending_key", ""))))
	return ending_def.intro_key if ending_def != null else ""


## Carte de conclusion (M12 §1.9) : `{title_key, eyebrow_key, name_key,
## tally_key, tally_args, lines, args, farewell_key, world, ending, variant,
## ending_key, profile_key}`. Ordre des lignes : ouverture propre à la fin →
## ligne de SC-90 → lignes de monde (un groupe par cas, première vraie) →
## ligne du foyer → clôture ; au plus `max_lines` (les dernières lignes de
## monde sautent d'abord). `flags` : drapeaux de la graine + ceux du J31.
static func conclusion(epi: Dictionary, flags: Dictionary[StringName, Variant], warnings: int,
		def: EpilogueDef = null) -> Dictionary:
	var source: EpilogueDef = def if def != null else load_def()
	var world_id: StringName = StringName(str(epi.get("world", "")))
	var key: StringName = StringName(str(epi.get("ending_key", "")))
	var result: Dictionary = {
		"title_key": source.title_key if source != null else "epi_title",
		"eyebrow_key": "epi_eyebrow_%s" % world_id,
		"name_key": "dos_world_%s" % world_id,
		"tally_key": source.tally_key if source != null else "epi_tally",
		"tally_args": [warnings],
		"lines": PackedStringArray(),
		"args": {},
		"farewell_key": "",
		"world": String(world_id),
		"ending": str(epi.get("ending", "")),
		"variant": str(epi.get("variant", "")),
		"ending_key": String(key),
		"profile_key": profile_key(epi),
	}
	if source == null:
		return result
	var world: EpilogueWorldDef = source.get_world(world_id)
	var ending_def: EpilogueEndingDef = source.get_ending(key)
	var args: Dictionary = {}
	var opening: String = ending_def.open_key if ending_def != null else ""
	if ending_def != null and ending_def.open_gauge != &"" and not opening.is_empty():
		args[opening] = [FlagCondition.gauge_value(flags, ending_def.open_gauge)]
	var middle: PackedStringArray = []
	var first: String = ConditionalKey.first_match(source.first_lines, flags, "")
	if not first.is_empty():
		middle.append(first)
	var world_lines: PackedStringArray = []
	if world != null:
		if not world.eyebrow_key.is_empty():
			result["eyebrow_key"] = world.eyebrow_key
		if not world.name_key.is_empty():
			result["name_key"] = world.name_key
		for group: EpilogueLineGroupDef in world.line_groups:
			if group == null:
				continue
			var line: String = group.pick(flags)
			if not line.is_empty():
				world_lines.append(line)
		result["farewell_key"] = ConditionalKey.first_match(world.farewell_lines, flags, "")
	var home: String = ""
	if ending_def == null or not ending_def.no_home_line:
		var home_lines: Array[ConditionalKey] = source.home_lines
		if ending_def != null and not ending_def.home_lines.is_empty():
			home_lines = ending_def.home_lines
		home = ConditionalKey.first_match(home_lines, flags, "")
	var closing: String = ending_def.close_key if ending_def != null else ""
	var fixed: int = middle.size() + (1 if not opening.is_empty() else 0) + (1 if not home.is_empty() else 0) \
			+ (1 if not closing.is_empty() else 0)
	while world_lines.size() > 0 and fixed + world_lines.size() > source.max_lines:
		world_lines.remove_at(world_lines.size() - 1)
	var lines: PackedStringArray = []
	if not opening.is_empty():
		lines.append(opening)
	lines.append_array(middle)
	lines.append_array(world_lines)
	if not home.is_empty():
		lines.append(home)
	if not closing.is_empty():
		lines.append(closing)
	result["lines"] = lines
	result["args"] = args
	return result


## JSON ne connaît que les flottants : un nombre entier redevient `int`.
static func json_value(value: Variant) -> Variant:
	if value is float:
		var f: float = value
		if is_equal_approx(f, roundf(f)):
			return roundi(f)
	return value
