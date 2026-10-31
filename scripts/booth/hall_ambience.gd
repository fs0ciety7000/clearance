## Hall par acte (M14 §4.3, §4.5 ; VH-4 → VH-8 ; B87, B88 ; D-188, D-190).
##
## Table **pure** (aucun nœud, aucune donnée de jeu) : à partir du jour, du
## mode (`campaign`, `garde`, `epilogue`) et du monde du J31, donne le
## calendrier des Gardes, la lumière du Hall, l'état du graffiti luciole, la
## bannière holographique et l'état de l'écran des départs. Appliquée par
## `BoothDirector.apply_act_ambience(day)` par **uniformes de shader et
## énergies de lumière** (0 draw), sauf la bannière (+1 draw).
## Rien ici ne dépend d'un cas, d'une règle ni d'un verdict.
class_name HallAmbience
extends RefCounted

## Graffiti luciole (`booth_emissive.gdshader`, uniforme `graffiti_state`) — seul
## magenta du décor (D-073).
const GRAFFITI_VISIBLE: int = 0
const GRAFFITI_COVERED: int = 1
const GRAFFITI_BIG: int = 2
const GRAFFITI_BIG_PLUS: int = 3
const GRAFFITI_GLASS: int = 4
## Écran des départs (uniforme `departures_status`) : ligne TRANSIT·7.
const DEPARTURES_ON_TIME: int = 0
const DEPARTURES_DELAYED: int = 1
const DEPARTURES_LAST_ROTATION: int = 2
const DEPARTURES_OFF: int = 3
## Bannières (maillages `booth_banner_<id>.res`, TextMesh cuits comme le décor).
const BANNER_NONE: StringName = &""
const BANNER_QUOTA: StringName = &"quota"
const BANNER_ENQUETE: StringName = &"enquete"
const BANNER_CONTINUITE: StringName = &"continuite"
const BANNER_DATE: StringName = &"date"
const BANNERS: Array[StringName] = [BANNER_QUOTA, BANNER_ENQUETE, BANNER_CONTINUITE, BANNER_DATE]
## Mode du civil posté (monde D : un mineur du comité, ni Garde ni brassard).
const POST_GUARD: int = 1
const POST_CIVIL: int = 3
## J16 → : −15 % de lumière du Hall après 16:00 de jeu (couvre-feu).
const CURFEW_FROM_DAY: int = 16
const CURFEW_MINUTE: int = 16 * 60
const CURFEW_SCALE: float = 0.85


## Acte d'un jour de campagne (1 : J1–J10, 2 : J11–J20, 3 : J21–J30).
static func act_of_day(day: int) -> int:
	if day <= 10:
		return 1
	return 2 if day <= 20 else 3


## Réglages du Hall pour un jour. `mode` : `DayDef.MODE_*` ; `world` : `a`…`d` (J31).
## Clés : `act`, `posts`, `post_mode`, `patrol`, `interval` (Vector2, s),
## `light_scale`, `light_tint`, `curfew`, `graffiti`, `banner`, `departures`, `arbiter`.
static func for_day(day: int, mode: StringName = &"campaign", world: StringName = &"") -> Dictionary:
	var out: Dictionary = {
		"act": act_of_day(day), "posts": 0, "post_mode": POST_GUARD, "patrol": 1, "interval": Vector2(150, 210),
		"light_scale": 1.0, "light_tint": Color.WHITE, "curfew": false, "graffiti": GRAFFITI_VISIBLE,
		"banner": BANNER_NONE, "departures": DEPARTURES_ON_TIME, "arbiter": false,
	}
	if mode == &"garde":
		out["act"] = 1
		out["posts"] = 1
		return out
	if mode == &"epilogue" or day >= 31:
		out["act"] = 3
		out["patrol"] = 0
		match world:
			&"a":
				out["posts"] = 1
				out["light_tint"] = Color(1.0, 0.93, 0.62) # jaune des bornes
				out["graffiti"] = GRAFFITI_COVERED
				out["banner"] = BANNER_CONTINUITE
			&"b":
				out["light_tint"] = Color(1.0, 0.86, 0.7) # chaude
				out["light_scale"] = 1.05
				out["departures"] = DEPARTURES_OFF
			&"c":
				out["posts"] = 1
				out["graffiti"] = GRAFFITI_GLASS
				out["banner"] = BANNER_DATE
			&"d":
				out["posts"] = 1
				out["post_mode"] = POST_CIVIL
				out["light_tint"] = Color(1.0, 0.78, 0.5) # ambre de mine
				out["light_scale"] = 0.92
		return out
	if day <= 7:
		pass
	elif day <= 10:
		out["posts"] = 1
		out["interval"] = Vector2(120, 180)
	elif day <= 20:
		out["posts"] = 2 if day >= CURFEW_FROM_DAY else 1
		out["patrol"] = 2
		out["interval"] = Vector2(90, 150)
		out["light_scale"] = 0.9
		out["curfew"] = day >= CURFEW_FROM_DAY
		out["graffiti"] = GRAFFITI_COVERED
		out["banner"] = BANNER_QUOTA
	elif day <= 29:
		out["posts"] = 2
		out["interval"] = Vector2(120, 180)
		out["light_scale"] = 0.9
		out["light_tint"] = Color(0.9, 0.95, 1.0) # blanc plus froid (+400 K)
		out["graffiti"] = GRAFFITI_BIG
		out["banner"] = BANNER_ENQUETE
		out["arbiter"] = day == 27
		if day >= 28:
			out["departures"] = DEPARTURES_LAST_ROTATION
	else:
		out["posts"] = 3
		out["patrol"] = 0
		out["light_scale"] = 0.9
		out["light_tint"] = Color(0.9, 0.95, 1.0)
		out["graffiti"] = GRAFFITI_BIG_PLUS
		out["banner"] = BANNER_ENQUETE
		out["departures"] = DEPARTURES_LAST_ROTATION
	return out


## Facteur de lumière du Hall à une minute de jeu (couvre-feu de J16 → après 16:00).
static func light_scale_at(settings: Dictionary, minute: int) -> float:
	var scale: float = float(settings.get("light_scale", 1.0))
	if bool(settings.get("curfew", false)) and minute >= CURFEW_MINUTE:
		scale *= CURFEW_SCALE / 0.9
	return scale


## Écran des départs un jour d'événement (EV-06 « Foule nerveuse » : RETARD,
## sauf la dernière rotation qui l'emporte).
static func departures_with_event(settings: Dictionary, event_id: StringName) -> int:
	var status: int = int(settings.get("departures", DEPARTURES_ON_TIME))
	if event_id == &"ev_06" and status == DEPARTURES_ON_TIME:
		return DEPARTURES_DELAYED
	return status
