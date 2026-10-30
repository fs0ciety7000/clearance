## Coût en temps des gestes d'interrogatoire et de fouille (M13, D-144, D-145 ;
## ARCHITECTURE §12.4) — sous-ressource d'`EconomyDef.interrogation_timing`.
##
## Horloge réelle : l'horloge du shift tourne pendant le geste ; l'interface
## est rendue au joueur après la durée (signal `inspection_busy`). Les valeurs
## « améliorées » s'appliquent quand le joueur possède l'amélioration
## correspondante (AG-01 Hygiaphone neuf, AG-03 Portique calibré PH-2). Sans
## ressource dans les données, les valeurs par défaut sont celles de M13 §1.10
## et §2.3.
class_name InterrogationTiming
extends Resource

@export_group("Questions")
## Question de base (`purpose`, `stay`, `origin`, `cargo`) ; avec AG-01.
@export var question_sec: float = 3.0
@export var question_sec_upgraded: float = 2.0
## Confrontation `about_*` ; avec AG-01.
@export var confront_sec: float = 4.0
@export var confront_sec_upgraded: float = 3.0
## Question répétée (même réponse, ANGRY), AG-01 sans effet.
@export var repeat_sec: float = 2.0
## Auto-correction (VN-2) : ajoutée à la question.
@export var correction_extra_sec: float = 1.0
## Autres gestes (visière, phrase de passe, enveloppe) : comme une question.
@export var other_sec: float = 3.0
@export var other_sec_upgraded: float = 2.0
## Comparaison A ↔ B (information : le comparateur garde sa propre durée).
@export var compare_sec: float = 0.25

@export_group("Fouille")
## Activation du portique (bras levés, cadre holographique) ; avec AG-03.
@export var search_activation_sec: float = 2.0
@export var search_activation_sec_upgraded: float = 1.0
## Scan d'une zone ; avec AG-03.
@export var search_zone_sec: float = 2.0
@export var search_zone_sec_upgraded: float = 1.0
## « TOUT SCANNER » (5 zones) ; avec AG-03. M13 §2.3 : 10 s → 5 s (fouille
## complète 12 s → 6 s) ; §3.2 annonce 4 s : écart signalé au Game Designer,
## la donnée tranche.
@export var search_all_sec: float = 10.0
@export var search_all_sec_upgraded: float = 5.0


## Durée d'une question de base (`repeated` : déjà posée ; `corrected` :
## réponse avec auto-correction).
func question_cost(hygiaphone: bool, repeated: bool = false, corrected: bool = false) -> float:
	if repeated:
		return repeat_sec
	var cost: float = question_sec_upgraded if hygiaphone else question_sec
	return cost + (correction_extra_sec if corrected else 0.0)


func confront_cost(hygiaphone: bool, repeated: bool = false) -> float:
	if repeated:
		return repeat_sec
	return confront_sec_upgraded if hygiaphone else confront_sec


func other_cost(hygiaphone: bool) -> float:
	return other_sec_upgraded if hygiaphone else other_sec


func activation_cost(calibrated: bool) -> float:
	return search_activation_sec_upgraded if calibrated else search_activation_sec


func zone_cost(calibrated: bool) -> float:
	return search_zone_sec_upgraded if calibrated else search_zone_sec


## Durée par zone pendant « TOUT SCANNER » (`zones` zones restantes sur 5).
func zone_cost_in_full_scan(calibrated: bool) -> float:
	var total: float = search_all_sec_upgraded if calibrated else search_all_sec
	return total / float(SearchLayout.ZONES.size())


## Fouille complète (activation + toutes les zones).
func full_search_cost(calibrated: bool) -> float:
	return activation_cost(calibrated) + (search_all_sec_upgraded if calibrated else search_all_sec)
