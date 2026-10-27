## Vérification de discordance du mode Inspection (ARCHITECTURE §6, GDD §4.1).
##
## Répond comme un agent humain, **à partir de ce qui est visible** : ne
## consulte jamais `CaseKey`. Symétrique : `check(a, b) == check(b, a)`.
## Paires comparables :
## - même champ deux fois → INCOMPARABLE ;
## - deux champs de documents de même `truth_path` (nom, naissance, N° ID…) ;
## - visage du passager ↔ photo, photo ↔ photo (`FaceComparator`) ; visage
##   masqué → INCOMPARABLE (demander le retrait de la visière) ;
## - date d'expiration ↔ date du jour ;
## - champ ↔ règle **active** du Rulebook (`Rule.check_against`), dont
##   « Documents requis » ↔ n'importe quel document du dossier ;
## - tout le reste → INCOMPARABLE (aucune pénalité).
class_name DiscrepancyChecker
extends RefCounted

const EXPIRY_PATH: StringName = &"document.expiry_date"


static func check(case: Case, a: FieldRef, b: FieldRef, ctx: RuleContext) -> Discrepancy:
	var result: Discrepancy = Discrepancy.new(a, b)
	if a == null or b == null or case == null:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)
	if a.equals(b):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_SAME_FIELD)
	if not _is_resolvable(case, a, ctx) or not _is_resolvable(case, b, ctx):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)

	# Règle du Rulebook ↔ champ.
	if a.is_rule() or b.is_rule():
		if a.is_rule() and b.is_rule():
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		var rule_ref: FieldRef = a if a.is_rule() else b
		var other: FieldRef = b if a.is_rule() else a
		var rule: Rule = ctx.find_active_rule(rule_ref.field_id)
		if rule == null:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RULE_INACTIVE)
		var verdict: Discrepancy.Result = rule.check_against(case, other, ctx)
		match verdict:
			Discrepancy.Result.DISCORDANT:
				return result.set_result(verdict, Discrepancy.REASON_RULE_VIOLATED)
			Discrepancy.Result.CONCORDANT:
				return result.set_result(verdict, Discrepancy.REASON_CONCORDANT)
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)

	# Date du jour ↔ date d'expiration.
	if a.is_today() or b.is_today():
		var dated: FieldRef = b if a.is_today() else a
		var field: FieldDef = case.get_field_def(dated)
		if field == null or field.truth_path != EXPIRY_PATH:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		var expiry: int = case.get_value(dated)
		if expiry < ctx.today:
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_EXPIRED)
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)

	# Visages : passager ↔ photo, photo ↔ photo.
	var app_a: PassengerAppearance = null
	var app_b: PassengerAppearance = null
	var is_face_a: bool = a.is_passenger_face() or _is_portrait(case, a)
	var is_face_b: bool = b.is_passenger_face() or _is_portrait(case, b)
	if is_face_a or is_face_b:
		if not (is_face_a and is_face_b):
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		if _is_masked(case, a) or _is_masked(case, b):
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_FACE_MASKED)
		app_a = _appearance_of(case, a)
		app_b = _appearance_of(case, b)
		if app_a == null or app_b == null:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)
		result.differing_traits = FaceComparator.compare(app_a, app_b, ctx.identity_slots)
		if result.differing_traits.is_empty():
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
		return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_FACE_MISMATCH)

	# Deux champs de documents : même donnée (`truth_path`) requise.
	var field_a: FieldDef = case.get_field_def(a)
	var field_b: FieldDef = case.get_field_def(b)
	if field_a.truth_path == &"" or field_a.truth_path != field_b.truth_path:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if FieldValue.equals(case.get_value(a), case.get_value(b)):
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
	return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_MISMATCH)


static func _is_resolvable(case: Case, ref: FieldRef, ctx: RuleContext) -> bool:
	if ref.is_passenger_face():
		return case.passenger_presented != null
	if ref.is_today():
		return ctx != null
	if ref.is_rule():
		return ctx != null
	return case.has_field(ref)


static func _is_portrait(case: Case, ref: FieldRef) -> bool:
	var field: FieldDef = case.get_field_def(ref)
	return field != null and field.kind == FieldDef.FieldKind.PORTRAIT


## Seul le visage réel peut être masqué (la photo d'un document ne l'est jamais).
static func _is_masked(case: Case, ref: FieldRef) -> bool:
	if not ref.is_passenger_face():
		return false
	var app: PassengerAppearance = case.passenger_presented.appearance
	return app != null and app.is_face_covered()


static func _appearance_of(case: Case, ref: FieldRef) -> PassengerAppearance:
	if ref.is_passenger_face():
		return case.passenger_presented.appearance
	var value: Variant = case.get_value(ref)
	if value is PortraitValue:
		var portrait: PortraitValue = value
		return portrait.appearance
	return null
