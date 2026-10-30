## Sélection et résolution **pures** des cinématiques de fin (M14 §3.2–§3.5,
## B91, D-183, D-185 ; ARCHITECTURE §12 ter.3). Aucune dépendance à l'UI : le
## `CinematicScreen` (lot D) et le `PlateFigureService` (lot C) l'appellent.
##
## - `select(ending, variant, flags, act, day)` : la `CinematicDef` de la fin,
##   ou null (fins des actes I–II de F4/F5/F7/F8/F9 en simulation, démo,
##   données absentes) → écran de fin direct ;
## - `select_epilogue(world)` : séquence CIN-EA → CIN-ED du J31 ;
## - `plates_for(def, flags, act, memory)` : planches retenues (acte,
##   condition, PL-E-FIG omise sans visage) ;
## - `figure_appearance(slot, memory, flags)` : visage **tel que vu** à la
##   vitre (`CaseMemory.seen_appearance` : visière remise si jamais relevée),
##   null → silhouette (REVOIR depuis le Dossier, headless, tests).
class_name CinematicService
extends RefCounted

## Pseudo-drapeaux de contexte (conditions des planches et des légendes).
const FLAG_ACT_PREFIX: String = "cin_act_"
const FLAG_VARIANT_PREFIX: String = "cin_variant_"
const FLAG_DAY_PREFIX: String = "cin_day_"
## Bornes d'une séquence (D-183).
const MIN_PLATES: int = 3
const MAX_PLATES: int = 5


## Cinématique d'une fin (première qui nomme la variante, sinon une sans
## variante), ou null.
static func select(ending: StringName, variant: StringName, flags: Dictionary[StringName, Variant], act: int,
		day: int = 0, library: CinematicLibraryDef = null) -> CinematicDef:
	if not EndingService.ALL_ENDINGS.has(ending):
		return null
	var lib: CinematicLibraryDef = library if library != null else CinematicLibraryDef.load_default()
	if lib == null:
		return null
	var generic: CinematicDef = null
	for c: CinematicDef in lib.cinematics:
		if c == null or c.is_epilogue() or not c.matches_ending(ending, variant, act):
			continue
		if not plates_for(c, context_flags(flags, act, variant, day), act).is_empty():
			if not c.ending_variants.is_empty():
				return c
			if generic == null:
				generic = c
	return generic


## Cinématique de la conclusion du J31 d'un monde (`a` … `d`), ou null.
static func select_epilogue(world: StringName, library: CinematicLibraryDef = null) -> CinematicDef:
	var lib: CinematicLibraryDef = library if library != null else CinematicLibraryDef.load_default()
	if lib == null:
		return null
	for c: CinematicDef in lib.cinematics:
		if c != null and c.worlds.has(world):
			return c
	return null


## Drapeaux augmentés des pseudo-drapeaux `cin_act_<n>`, `cin_variant_<v>`,
## `cin_day_<n>` (copie ; un vrai drapeau de même nom l'emporte).
static func context_flags(flags: Dictionary[StringName, Variant], act: int, variant: StringName = &"",
		day: int = 0) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = flags.duplicate()
	var extra: Array[StringName] = [StringName(FLAG_ACT_PREFIX + str(act))]
	if variant != &"":
		extra.append(StringName(FLAG_VARIANT_PREFIX + String(variant)))
	if day > 0:
		extra.append(StringName(FLAG_DAY_PREFIX + str(day)))
	for flag: StringName in extra:
		if not result.has(flag):
			result[flag] = true
	return result


## Planches retenues, dans l'ordre : acte, condition (sur `flags`, qui doivent
## déjà porter les pseudo-drapeaux de `context_flags`), et planches dont une
## figure `omit_plate_if_missing` n'a pas de visage dans `memory`.
static func plates_for(def: CinematicDef, flags: Dictionary[StringName, Variant], act: int,
		memory: Dictionary = {}) -> Array[PlateDef]:
	var result: Array[PlateDef] = []
	if def == null:
		return result
	for plate: PlateDef in def.plates:
		if plate == null or not plate.is_eligible(act, flags):
			continue
		var omitted: bool = false
		for slot: FigureSlotDef in plate.figures:
			if slot != null and slot.omit_plate_if_missing and figure_appearance(slot, memory, flags) == null:
				omitted = true
		if not omitted:
			result.append(plate)
	return result


## Visage d'une figure nommée tel que vu pendant la partie, ou null (silhouette).
static func figure_appearance(slot: FigureSlotDef, memory: Dictionary, flags: Dictionary[StringName, Variant]) -> PassengerAppearance:
	if slot == null or memory.is_empty():
		return null
	for candidate: ConditionalKey in slot.memory_cases:
		if candidate == null or not FlagCondition.check(candidate.condition, flags):
			continue
		var entry: Variant = memory.get(candidate.key, null)
		if not entry is Dictionary or (entry as Dictionary).get("recalled", false):
			continue
		var app: PassengerAppearance = CaseMemory.seen_appearance(entry)
		if app != null:
			return app
	return null


## Clé de la légende d'une planche.
static func caption_key(plate: PlateDef, flags: Dictionary[StringName, Variant]) -> String:
	return plate.caption_for(flags) if plate != null else ""
