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
## - M7 : visage ↔ « Implants déclarés » (implants visibles), visage ↔ date de
##   naissance (âge apparent), MRZ ↔ N° ID / origine / nom / prénoms de la même
##   carte, entrée de l'avis de recherche ↔ visage ou nom (une correspondance
##   est une DISCORDANCE : la personne est recherchée) ;
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

	# M7 : avis de recherche ↔ visage / nom.
	if a.is_wanted() or b.is_wanted():
		return _check_wanted(case, a if a.is_wanted() else b, b if a.is_wanted() else a, ctx, result)
	# M7 : visage ↔ implants déclarés, visage ↔ date de naissance.
	if a.is_passenger_face() or b.is_passenger_face():
		var other_ref: FieldRef = b if a.is_passenger_face() else a
		var other_field: FieldDef = case.get_field_def(other_ref)
		if other_field != null and other_field.truth_path == &"implants":
			var declared: Variant = FieldValue.normalize(ImplantsDeclaredRule.as_list(case.get_value(other_ref)))
			var visible: Variant = FieldValue.normalize(case.passenger_presented.implants)
			if declared == visible:
				return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_IMPLANT_MISMATCH)
		if other_field != null and other_field.truth_path == &"birth_date":
			if _is_masked(case, a) or _is_masked(case, b):
				return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_FACE_MASKED)
			var birth: Variant = case.get_value(other_ref)
			if not birth is int:
				return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
			var birth_date: int = birth
			if ApparentAgeRule.band_of_birth(birth_date, ctx.today) == case.passenger_presented.appearance.age_band:
				return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_AGE_MISMATCH)
	# M7 : MRZ ↔ champ recopié de la même carte.
	var mrz_result: Discrepancy = _check_mrz(case, a, b, ctx, result)
	if mrz_result != null:
		return mrz_result

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
	if ref.is_wanted():
		return ctx != null and ctx.find_wanted(ref.field_id) != null
	if ref.is_passenger_face():
		return case.passenger_presented != null
	if ref.is_today():
		return ctx != null
	if ref.is_rule():
		return ctx != null
	return case.has_field(ref)


## Entrée de l'avis ↔ visage (masqué : INCOMPARABLE) ou nom / prénoms d'un document.
static func _check_wanted(case: Case, wanted_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	var notice: WantedNotice = ctx.find_wanted(wanted_ref.field_id)
	if other.is_wanted() or other.is_rule() or other.is_today():
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	var matched: bool = false
	if other.is_passenger_face() or _is_portrait(case, other):
		if _is_masked(case, other):
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_FACE_MASKED)
		var app: PassengerAppearance = _appearance_of(case, other)
		if app == null or notice.appearance == null:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)
		matched = FaceComparator.compare(notice.appearance, app, ctx.identity_slots).is_empty()
	else:
		var field: FieldDef = case.get_field_def(other)
		if field == null or (field.truth_path != &"family_name" and field.truth_path != &"given_name"):
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		var expected: String = notice.family_name if field.truth_path == &"family_name" else notice.given_name
		matched = FieldValue.equals(case.get_value(other), expected)
	if matched:
		return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_WANTED_MATCH)
	return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_WANTED_NO_MATCH)


## MRZ ↔ composante de la même carte ; null si la paire ne concerne pas la MRZ.
static func _check_mrz(case: Case, a: FieldRef, b: FieldRef, ctx: RuleContext, result: Discrepancy) -> Discrepancy:
	var field_a: FieldDef = case.get_field_def(a)
	var field_b: FieldDef = case.get_field_def(b)
	if field_a == null or field_b == null:
		return null
	var mrz_on_a: bool = field_a.truth_path == MrzConsistentRule.MRZ_PATH
	var mrz_on_b: bool = field_b.truth_path == MrzConsistentRule.MRZ_PATH
	if mrz_on_a == mrz_on_b:
		return null
	var mrz_ref: FieldRef = a if mrz_on_a else b
	var other: FieldRef = b if mrz_on_a else a
	var other_field: FieldDef = field_b if mrz_on_a else field_a
	if other.document_id != mrz_ref.document_id or not Mrz.COMPONENTS.has(other_field.truth_path):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	var doc: DocumentInstance = case.get_document(mrz_ref.document_id)
	var origin: String = str(case.get_value(other)) if other_field.truth_path == &"faction_id" else ""
	var faction: FactionDef = ctx.get_faction(StringName(origin)) if ctx != null and not origin.is_empty() else null
	var code: String = faction.code if faction != null else origin.to_upper()
	if Mrz.component_matches(doc.mrz, other_field.truth_path, case.get_value(other), code):
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
	return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_MRZ_MISMATCH)


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
