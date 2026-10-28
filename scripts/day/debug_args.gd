## Arguments de debug de la scène de jour (ARCHITECTURE §13 R18, §16.4) :
## `--day`, `--seed`, `--screen`, `--debug-keys`, `--autoplay`, `--ending`…
##
## - **Garde** : lus seulement dans un build de debug (`OS.is_debug_build()` :
##   éditeur, `godot` en ligne de commande, export *debug*) ou un export portant
##   la fonctionnalité personnalisée `debug_args` (flag explicite du preset).
##   Dans un export *release*, `for_scene()` renvoie un dictionnaire vide.
## - **Une seule application** (QA-017) : les arguments qui **modifient la
##   partie** (`ONE_SHOT` : graine, jour, foyer, drapeaux, crédits, écran de
##   capture…) ne valent que pour la première `DayScene` du processus ; les
##   rechargements (`reload_current_scene`, jour suivant) ne les voient plus, la
##   campagne progresse. Les modes (`--no-booth`, `--autoplay`, `--reduce-motion`,
##   `--debug-keys`…) restent actifs à chaque jour.
class_name DebugArgs
extends RefCounted

## Fonctionnalité d'export qui active les arguments dans un build *release*.
const FEATURE: String = "debug_args"
## Arguments appliqués une seule fois par processus.
const ONE_SHOT: PackedStringArray = ["seed", "day", "household", "flags", "credits", "start-case", "screen",
		"ending", "step", "item", "rulebook-tab", "inspect", "ask", "zoom-doc", "lights-out", "confirm-scan", "choose"]
## Marqueur (métadonnée d'`Engine`, durée du processus) : arguments consommés.
const CONSUMED_META: StringName = &"clearance_debug_args_consumed"


## Vrai si les arguments de debug sont acceptés par ce build.
static func enabled() -> bool:
	return OS.is_debug_build() or OS.has_feature(FEATURE)


## `--clé=valeur` → `{clé: valeur}` (`"true"` sans valeur). Pure.
static func parse(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg: String in args:
		var clean: String = arg.trim_prefix("--")
		var parts: PackedStringArray = clean.split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result


## Retire les arguments `ONE_SHOT` si `consumed`. Pure.
static func filter(args: Dictionary, consumed: bool) -> Dictionary:
	var result: Dictionary = args.duplicate()
	if consumed:
		for key: String in ONE_SHOT:
			result.erase(key)
	return result


## Arguments pour une `DayScene` qui démarre : vide en *release* ; sans les
## `ONE_SHOT` après la première scène du processus.
static func for_scene() -> Dictionary:
	if not enabled():
		return {}
	var consumed: bool = Engine.has_meta(CONSUMED_META)
	Engine.set_meta(CONSUMED_META, true)
	return filter(parse(OS.get_cmdline_user_args()), consumed)
