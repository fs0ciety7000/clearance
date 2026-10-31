## Annonces d'ambiance de la station (M14 §4.4 VH-6, B85, D-189) —
## `res://data/audio/pa_lines.tres` (données : lots E/F, `tools/build_data_m14.gd`).
##
## **Aucune information de jeu** : ni règle, ni seuil, ni document, ni nom de
## passager (contrôlé par `tests/unit/test_m14_data.gd`). Les annonces de jeu
## restent `hall_announced` (`DayDef.announcements`, inchangées).
##
## Chaque ligne est une `HallAnnouncementDef` (clé `pa_*`, `music_action`) dont
## la `condition` porte sur des **pseudo-drapeaux de contexte** construits par
## `context()` : jauges `pa_act` (1–3 en campagne, 0 hors campagne) et `pa_day`
## (1–31, 0 en Garde), drapeaux `pa_event_<ev_xx>` (événement de station actif),
## `pa_world_<a…d>` (J31), `pa_garde`. `after_case` / `at_minute` ne servent pas :
## le moment est tiré par l'ordonnanceur (`PaScheduler`, lot B : graine du jour,
## 90–180 s, ≤ 6 par shift, exclusions). Poids de tirage : `weights` (parallèle
## à `lines`, 1 par défaut).
##
## Contournement réversible (lot F) : le contrat M14 (ARCHITECTURE §12 ter.1)
## ne définit pas encore de `PaLineDef` ; cette table pourra passer dans
## `scripts/core/` sous le nom choisi par l'Architecte sans changer les données
## (mêmes champs).
class_name PaLineTable
extends Resource

const PATH: String = "res://data/audio/pa_lines.tres"
## Pseudo-drapeaux de contexte (jauges entières et drapeaux vrais).
const GAUGE_ACT: StringName = &"pa_act"
const GAUGE_DAY: StringName = &"pa_day"
const FLAG_GARDE: StringName = &"pa_garde"
const FLAG_EVENT_PREFIX: String = "pa_event_"
const FLAG_WORLD_PREFIX: String = "pa_world_"
## Préfixe des clés de texte (`fr.csv`).
const KEY_PREFIX: String = "pa_"
## Longueur maximale d'une ligne sous-titrée (NARRATIVE §7).
const MAX_CHARS: int = 90

@export var version: int = 1
@export var lines: Array[HallAnnouncementDef] = []
## Poids de tirage, même ordre que `lines` (absent → 1).
@export var weights: PackedFloat32Array = PackedFloat32Array()


## Table des données, ou null si absente.
static func load_default() -> PaLineTable:
	if not ResourceLoader.exists(PATH):
		return null
	return load(PATH) as PaLineTable


## Contexte de tirage : `act` 1–3 (campagne) ou 0 (J31, Garde) ; `day` 1–31
## (0 en Garde) ; `events` : ids des événements de station actifs (`ev_06`…) ;
## `world` : monde du J31 (`a` … `d`) ; `garde` : Garde de nuit.
static func context(act: int, day: int, events: Array[StringName] = [], world: StringName = &"",
		garde: bool = false) -> Dictionary[StringName, Variant]:
	var ctx: Dictionary[StringName, Variant] = {GAUGE_ACT: act, GAUGE_DAY: day}
	for event_id: StringName in events:
		ctx[StringName(FLAG_EVENT_PREFIX + String(event_id))] = true
	if world != &"":
		ctx[StringName(FLAG_WORLD_PREFIX + String(world))] = true
	if garde:
		ctx[FLAG_GARDE] = true
	return ctx


## Lignes admissibles dans ce contexte (ordre des données).
func eligible(ctx: Dictionary[StringName, Variant]) -> Array[HallAnnouncementDef]:
	var result: Array[HallAnnouncementDef] = []
	for line: HallAnnouncementDef in lines:
		if line != null and FlagCondition.check(line.condition, ctx):
			result.append(line)
	return result


## Poids de tirage d'une ligne (1 si absent ou non positif).
func weight_of(line: HallAnnouncementDef) -> float:
	var i: int = lines.find(line)
	if i < 0 or i >= weights.size() or weights[i] <= 0.0:
		return 1.0
	return weights[i]


## Toutes les clés de texte (tests de données).
func all_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for line: HallAnnouncementDef in lines:
		if line != null:
			keys.append(line.text_key)
	return keys
