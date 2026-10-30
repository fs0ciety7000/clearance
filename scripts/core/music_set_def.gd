## Ensemble musical MS-01 → MS-07 (M14 §2.2–§2.6, B81, D-176 → D-178 ;
## ARCHITECTURE §12 ter.2) — `assets/audio/music/sets/ms_0N.tres` (lot B), réunis
## dans `MusicLibraryDef`.
##
## Fonctions **pures** de calage : mesure, échantillons par mesure (tempos à
## nombre entier d'échantillons à 32 et 48 kHz), couches actives à un niveau
## selon les masques (exposé, sans mélodie, power down) et les groupes
## sélectionnés, quantification d'une intensité avec hystérésis.
## Le `MusicDirector` (lot B) applique ces décisions **au début de mesure**.
class_name MusicSetDef
extends Resource

const LEVEL_MIN: int = 0
const LEVEL_MAX: int = 4
## Masques de contexte de `active_layers()`.
## Briefing « exposé » : seules les couches `exposed`.
const MASK_EXPOSED: int = 1
## Sans mélodie (Mode Inspection discret, chrono critique) : couches `melodic` coupées.
const MASK_NO_MELODY: int = 2
## Power down (EV-05, grève du J20) : seules les couches `keeps_on_power_down`.
const MASK_POWER_DOWN: int = 4

## `ms_01` … `ms_07` (`MusicLibraryDef.SET_*`).
@export var id: StringName = &""
@export var tempo_bpm: float = 80.0
@export var beats_per_bar: int = 4
## Longueur de la boucle en mesures (16, ou 12 pour MS-06).
@export var bars: int = 16
## Fréquence des couches (32 kHz, D-180).
@export var sample_rate: int = 32000
@export var layers: Array[MusicLayerDef] = []
## Seuils d'intensité de N1, N2, N3, N4 (§2.5).
@export var thresholds: PackedFloat32Array = PackedFloat32Array([0.15, 0.35, 0.60, 0.80])
## Hystérésis de la quantification (±).
@export var hysteresis: float = 0.05
## Plafond de l'ensemble (MS-01, MS-06 : 0 ; Récit et J31 : plafond N2 posé
## par le `MusicDirector`, pas ici).
@export_range(0, 4) var max_level: int = LEVEL_MAX
## Mesures minimales entre deux montées (+1) et deux descentes (−1).
@export var rise_every_bars: int = 2
@export var fall_every_bars: int = 4
## Rampe d'entrée ou de sortie d'une couche, en mesures.
@export var layer_ramp_bars: int = 1
## Fondu croisé quand cet ensemble remplace un autre (§2.6 : 2 mesures).
@export var enter_crossfade_bars: int = 2
## Gain commun « exposé » (premier plan −20 LUFS) ajouté aux couches.
@export var exposed_gain_db: float = 0.0


func seconds_per_beat() -> float:
	return 60.0 / maxf(tempo_bpm, 1.0)


func seconds_per_bar() -> float:
	return seconds_per_beat() * beats_per_bar


func loop_seconds() -> float:
	return seconds_per_bar() * bars


## Échantillons par mesure à `rate` (défaut : `sample_rate`), arrondis.
func samples_per_bar(rate: int = 0) -> int:
	var r: int = rate if rate > 0 else sample_rate
	return roundi(r * 60.0 * beats_per_bar / maxf(tempo_bpm, 1.0))


## Longueur exacte d'une couche en échantillons (M-06).
func loop_samples(rate: int = 0) -> int:
	return samples_per_bar(rate) * bars


## Vrai si un temps tombe sur un nombre entier d'échantillons à `rate` (D-178).
func is_sample_exact(rate: int) -> bool:
	var per_beat: float = rate * 60.0 / maxf(tempo_bpm, 1.0)
	return is_equal_approx(per_beat, roundf(per_beat))


## Mesure en cours à la position de lecture `position_sec` (dans la boucle).
func bar_at(position_sec: float) -> int:
	return posmod(floori(position_sec / seconds_per_bar() + 1e-6), maxi(bars, 1))


## Début de la mesure suivante (secondes, peut dépasser la boucle).
func next_bar_time(position_sec: float) -> float:
	var bar_len: float = seconds_per_bar()
	return (floorf(position_sec / bar_len + 1e-6) + 1.0) * bar_len


func layer_index(layer_id: StringName) -> int:
	for i: int in layers.size():
		if layers[i] != null and layers[i].id == layer_id:
			return i
	return -1


## Index des couches actives au niveau `level` (borné par `max_level`), selon
## `mask` (`MASK_*`) et les groupes sélectionnés.
func active_layers(level: int, mask: int = 0, groups: Array[StringName] = []) -> PackedInt32Array:
	var lvl: int = clampi(level, LEVEL_MIN, max_level)
	var result: PackedInt32Array = []
	for i: int in layers.size():
		var layer: MusicLayerDef = layers[i]
		if layer == null:
			continue
		if layer.group != &"" and not groups.has(layer.group):
			continue
		if mask & MASK_POWER_DOWN:
			if layer.keeps_on_power_down:
				result.append(i)
			continue
		if mask & MASK_EXPOSED:
			if not layer.exposed:
				continue
		elif not layer.is_active_at(lvl):
			continue
		if (mask & MASK_NO_MELODY) and layer.melodic:
			continue
		result.append(i)
	return result


## Niveau d'une intensité `value` ∈ [0, 1] avec hystérésis autour de
## `current` : il faut dépasser un seuil de `hysteresis` pour monter, et
## repasser sous un seuil de `hysteresis` pour descendre. Ne limite pas la
## vitesse (+1 / 2 mesures, −1 / 4 mesures : `MusicIntensity`, lot B).
func level_for(value: float, current: int) -> int:
	var raw: int = 0
	for i: int in thresholds.size():
		if value >= thresholds[i]:
			raw = i + 1
	var lvl: int = clampi(current, LEVEL_MIN, LEVEL_MAX)
	if raw > lvl:
		while lvl < raw and value >= thresholds[lvl] + hysteresis:
			lvl += 1
	elif raw < lvl:
		while lvl > raw and value < thresholds[lvl - 1] - hysteresis:
			lvl -= 1
	return clampi(lvl, LEVEL_MIN, max_level)
