## Thème de fin ou de monde (M14 §2.7, B81, B84, D-182 ; ARCHITECTURE §12 ter.2) —
## `assets/audio/music/themes/th_*.tres` (lot B), réunis dans `MusicLibraryDef`.
##
## Sélection : `endings` (identifiants `EndingService.F*`) et
## `ending_variants` (`EpilogueService.variant_of` : `c`, `s`, `b`, `t`, `d`,
## `j10`, `j20`…, vide = toutes) ; thèmes de monde : `worlds` (`a` … `d`).
## Structure : ouverture → A → B dans `stream`, puis `tail_stream` bouclé.
## TH-F7 réutilise les couches de MS-02 au niveau N1 (`reuse_set_id`, `reuse_level`).
class_name MusicThemeDef
extends Resource

## `th_f1` … `th_f10`, `th_f5c`, `th_f6t`, `th_ea` … `th_ed`.
@export var id: StringName = &""
@export var tempo_bpm: float = 60.0
@export var beats_per_bar: int = 4
## Fréquence des thèmes (48 kHz, D-180).
@export var sample_rate: int = 48000
@export var endings: Array[StringName] = []
@export var ending_variants: Array[StringName] = []
@export var worlds: Array[StringName] = []
## Ouverture → A → B (non bouclé).
@export var stream: AudioStream = null
## Queue bouclable (8 mesures) sous l'écran de fin.
@export var tail_stream: AudioStream = null
## Variante « Effets visuels réduits » (§2.11 : coup grave −6 dB, sans
## réduction de bits) ; null = `stream`.
@export var reduced_fx_stream: AudioStream = null
@export var sections: Array[MusicSectionDef] = []
@export var variants: Array[MusicThemeVariantDef] = []
## TH-F7 : ensemble rejoué (`ms_02`) au niveau `reuse_level` avant la sortie.
@export var reuse_set_id: StringName = &""
@export_range(0, 4) var reuse_level: int = 1


func seconds_per_bar() -> float:
	return 60.0 / maxf(tempo_bpm, 1.0) * beats_per_bar


func section(section_id: StringName) -> MusicSectionDef:
	for s: MusicSectionDef in sections:
		if s != null and s.id == section_id:
			return s
	return null


## Mesures de l'ouverture à la fin de B (durée de `stream`).
func main_bars() -> int:
	var total: int = 0
	for s: MusicSectionDef in sections:
		if s != null and s.id != MusicSectionDef.TAIL:
			total = maxi(total, s.start_bar + s.bars)
	return total


## Première variante dont la condition est vraie (null : thème de base).
func variant_for(flags: Dictionary[StringName, Variant]) -> MusicThemeVariantDef:
	for v: MusicThemeVariantDef in variants:
		if v != null and FlagCondition.check(v.condition, flags):
			return v
	return null


## Flux principal à jouer (variante, puis `reduced_fx_stream` si demandé).
func main_stream(flags: Dictionary[StringName, Variant], reduced_fx: bool = false) -> AudioStream:
	var v: MusicThemeVariantDef = variant_for(flags)
	if v != null and v.stream != null:
		return v.stream
	if reduced_fx and reduced_fx_stream != null:
		return reduced_fx_stream
	return stream


func tail_for(flags: Dictionary[StringName, Variant]) -> AudioStream:
	var v: MusicThemeVariantDef = variant_for(flags)
	return v.tail_stream if v != null and v.tail_stream != null else tail_stream


## Vrai si le thème sert la fin `ending` de variante `variant`.
func matches_ending(ending: StringName, variant: StringName) -> bool:
	return endings.has(ending) and (ending_variants.is_empty() or ending_variants.has(variant))
