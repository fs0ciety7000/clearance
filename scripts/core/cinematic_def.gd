## Séquence cinématique CIN-… (M14 §3.2–§3.4, B91, D-183 ; ARCHITECTURE
## §12 ter.3) — dans `data/cinematics/cinematics.tres` (`CinematicLibraryDef`, lot E).
##
## Sélection (`CinematicService.select`) : `endings` (`EndingService.F*`),
## `ending_variants` (vide = toutes), `acts` (vide = tous) ; séquences du J31 :
## `worlds` (`a` … `d`). Une carte de titre (3,5 s) précède les planches.
class_name CinematicDef
extends Resource

## `cin_f1`, `cin_f5c`, `cin_ea`…
@export var id: StringName = &""
@export var endings: Array[StringName] = []
@export var ending_variants: Array[StringName] = []
@export var acts: PackedInt32Array = PackedInt32Array()
@export var worlds: Array[StringName] = []
## Thème musical (`MusicThemeDef.id`) ; vide = celui de la fin.
@export var theme_id: StringName = &""
## 3 à 5 planches candidates, dans l'ordre ; variantes filtrées par
## `CinematicService.plates_for`.
@export var plates: Array[PlateDef] = []
## Carte de titre (surtitre et titre de la fin, `EndScreen.accent_of`).
@export var title_card: bool = true


func is_epilogue() -> bool:
	return not worlds.is_empty()


func matches_ending(ending: StringName, variant: StringName, act: int) -> bool:
	return endings.has(ending) and (ending_variants.is_empty() or ending_variants.has(variant)) \
			and (acts.is_empty() or acts.has(act))
