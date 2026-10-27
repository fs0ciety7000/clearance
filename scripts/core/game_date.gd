## Date de jeu : entier « jours depuis l'epoch de la station » (ARCHITECTURE §5.3).
##
## Jamais `Time`/OS : pas de fuseau horaire, comparaisons et expirations
## triviales (`expiry < today`). Calendrier grégorien proleptique
## (années bissextiles : divisibles par 4, sauf siècles non divisibles par 400).
## Jour 0 = 01.01.2100. Les dates antérieures sont des entiers négatifs.
## Classe utilitaire : uniquement des fonctions statiques.
class_name GameDate
extends RefCounted

const EPOCH_YEAR: int = 2100
## Jours entre 1970-01-01 et 2100-01-01 (décalage interne de l'algorithme).
const _EPOCH_UNIX_DAYS: int = 47482
## Valeur renvoyée par `parse()` pour une entrée invalide.
const INVALID: int = -999_999_999
## Format d'affichage par défaut (19.03.2187).
const DEFAULT_PATTERN: String = "DD.MM.YYYY"


## Division entière arrondie vers −∞.
static func _floor_div(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	var q: int = a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


static func days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if is_leap_year(year) else 28
	return 0


static func is_valid_ymd(year: int, month: int, day: int) -> bool:
	return month >= 1 and month <= 12 and day >= 1 and day <= days_in_month(year, month)


## Jour de jeu à partir d'une date civile. Erreur + `INVALID` si la date n'existe pas.
## (Algorithme « days_from_civil » de H. Hinnant.)
static func from_ymd(year: int, month: int, day: int) -> int:
	if not is_valid_ymd(year, month, day):
		push_error("GameDate.from_ymd: date invalide %04d-%02d-%02d" % [year, month, day])
		return INVALID
	var y: int = year - (1 if month <= 2 else 0)
	var era: int = _floor_div(y, 400)
	var yoe: int = y - era * 400
	var mp: int = (month + 9) % 12
	var doy: int = _floor_div(153 * mp + 2, 5) + day - 1
	var doe: int = yoe * 365 + _floor_div(yoe, 4) - _floor_div(yoe, 100) + doy
	return era * 146097 + doe - 719468 - _EPOCH_UNIX_DAYS


## Date civile d'un jour de jeu : `Vector3i(année, mois, jour)`.
static func to_ymd(days: int) -> Vector3i:
	var z: int = days + _EPOCH_UNIX_DAYS + 719468
	var era: int = _floor_div(z, 146097)
	var doe: int = z - era * 146097
	var yoe: int = _floor_div(doe - _floor_div(doe, 1460) + _floor_div(doe, 36524) - _floor_div(doe, 146096), 365)
	var doy: int = doe - (365 * yoe + _floor_div(yoe, 4) - _floor_div(yoe, 100))
	var mp: int = _floor_div(5 * doy + 2, 153)
	var d: int = doy - _floor_div(153 * mp + 2, 5) + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	var y: int = yoe + era * 400 + (1 if m <= 2 else 0)
	return Vector3i(y, m, d)


static func year_of(days: int) -> int:
	return to_ymd(days).x


static func month_of(days: int) -> int:
	return to_ymd(days).y


static func day_of(days: int) -> int:
	return to_ymd(days).z


## Formate selon un motif contenant `YYYY`, `MM`, `DD` (ex. "YYYY.MM.DD").
static func format_pattern(days: int, pattern: String) -> String:
	var ymd: Vector3i = to_ymd(days)
	return pattern.replace("YYYY", "%04d" % ymd.x).replace("MM", "%02d" % ymd.y).replace("DD", "%02d" % ymd.z)


## Formate au format par défaut « 19.03.2187 ».
static func format(days: int) -> String:
	return format_pattern(days, DEFAULT_PATTERN)


static func _is_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if c < 48 or c > 57: # '0'..'9'
			return false
	return true


## Lit « JJ.MM.AAAA » (jour et mois sur 1 ou 2 chiffres, année sur 4).
## Renvoie `INVALID` (sans erreur) si le texte n'est pas une date valide.
static func parse(text: String) -> int:
	var parts: PackedStringArray = text.strip_edges().split(".")
	if parts.size() != 3:
		return INVALID
	var d_text: String = parts[0]
	var m_text: String = parts[1]
	var y_text: String = parts[2]
	if d_text.length() > 2 or m_text.length() > 2 or y_text.length() != 4:
		return INVALID
	if not (_is_digits(d_text) and _is_digits(m_text) and _is_digits(y_text)):
		return INVALID
	var year: int = y_text.to_int()
	var month: int = m_text.to_int()
	var day: int = d_text.to_int()
	if not is_valid_ymd(year, month, day):
		return INVALID
	return from_ymd(year, month, day)


static func is_valid(days: int) -> bool:
	return days != INVALID


static func add_days(days: int, count: int) -> int:
	return days + count


## Ajoute des années civiles ; le 29 février devient le 28 si besoin.
static func add_years(days: int, count: int) -> int:
	var ymd: Vector3i = to_ymd(days)
	var year: int = ymd.x + count
	var day: int = mini(ymd.z, days_in_month(year, ymd.y))
	return from_ymd(year, ymd.y, day)


## Nombre de jours de `from_days` à `to_days` (négatif si antérieur).
static func days_between(from_days: int, to_days: int) -> int:
	return to_days - from_days


## −1, 0 ou 1.
static func compare(a: int, b: int) -> int:
	return signi(a - b)


static func is_before(a: int, b: int) -> bool:
	return a < b


static func is_after(a: int, b: int) -> bool:
	return a > b


## Âge révolu en années à la date `on_days` pour une naissance `birth_days`.
static func age_on(birth_days: int, on_days: int) -> int:
	var b: Vector3i = to_ymd(birth_days)
	var t: Vector3i = to_ymd(on_days)
	var age: int = t.x - b.x
	if t.y < b.y or (t.y == b.y and t.z < b.z):
		age -= 1
	return age
