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
##   est une DISCORDANCE : la personne est recherchée) ; marque au coin d'un
##   document ↔ entrée du bulletin « Symboles subversifs » (onglet ouvert ce
##   jour, J7+) : DISCORDANCE si la marque est celle du symbole (§4.9) ;
## - Acte II : entrée de l'onglet Révocations ↔ N° ID (DISCORDANCE si égal) ;
##   compteur QUOTA ↔ R23 (règle de contexte) ; Firmware NX ↔ date du jour
##   (DISCORDANCE à partir de 90 jours, R27) ; un document d'un tiers (SC-27)
##   n'est jamais comparé à ceux du porteur ;
## - M13 (docs/M13.md §1.8, §2.2) : puce du journal ↔ champ de document de même
##   donnée (R43 : palier et sujet actifs ; vague, provenance, prose libre ou
##   puce non obtenue → INCOMPARABLE) ; objet révélé par la fouille ↔ R45 / R46
##   (règle), ↔ entrée de l'onglet Contrebande, ↔ « Implants déclarés » (implant
##   trouvé), imprimé ↔ bulletin des symboles ; un implant déclaré « non
##   visible — fouille » n'est jamais comparé au visage (J8+) ;
## - tout le reste → INCOMPARABLE (aucune pénalité).
class_name DiscrepancyChecker
extends RefCounted

const EXPIRY_PATH: StringName = &"document.expiry_date"
## Acte II (R27) : date de mise à jour d'un shunt `NX-` (carte d'identité).
const FIRMWARE_PATH: StringName = &"firmware_date"


static func check(case: Case, a: FieldRef, b: FieldRef, ctx: RuleContext) -> Discrepancy:
	var result: Discrepancy = Discrepancy.new(a, b)
	if a == null or b == null or case == null:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)
	if a.equals(b):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_SAME_FIELD)
	# M7 : bulletin « Symboles subversifs » ↔ marque d'un document.
	if a.is_symbol() or b.is_symbol():
		return _check_symbol(case, a if a.is_symbol() else b, b if a.is_symbol() else a, ctx, result)
	# M13 : puce du journal de dialogue ↔ champ de document.
	if a.is_statement() or b.is_statement():
		return _check_statement(case, a if a.is_statement() else b, b if a.is_statement() else a, ctx, result)
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
		if verdict == Discrepancy.Result.DISCORDANT and rule.is_exempted(case, ctx):
			# Acte III (R36) : convocation authentique, la règle est levée.
			verdict = Discrepancy.Result.CONCORDANT
		match verdict:
			Discrepancy.Result.DISCORDANT:
				return result.set_result(verdict, Discrepancy.REASON_RULE_VIOLATED)
			Discrepancy.Result.CONCORDANT:
				return result.set_result(verdict, Discrepancy.REASON_CONCORDANT)
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)

	# M13 : objet révélé par la fouille ↔ onglet Contrebande / implants déclarés.
	if a.is_scan() or b.is_scan():
		if a.is_scan() and b.is_scan():
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		return _check_scan(case, a if a.is_scan() else b, b if a.is_scan() else a, ctx, result)
	if a.is_contraband_entry() or b.is_contraband_entry():
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)

	# Date du jour ↔ date d'expiration.
	if a.is_today() or b.is_today():
		var dated: FieldRef = b if a.is_today() else a
		var field: FieldDef = case.get_field_def(dated)
		if field != null and field.truth_path == FIRMWARE_PATH:
			return _check_firmware(case, dated, ctx, result)
		if field == null or field.truth_path != EXPIRY_PATH:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		var expiry: int = case.get_value(dated)
		if case.get_document(dated.document_id).retired:
			# Acte III (M1) : document retiré, plus contrôlé.
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RETIRED)
		if ctx.is_prorogated(expiry):
			# Acte III (R32) : expiré dans la fenêtre de prorogation, valide.
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_PROROGATED)
		if expiry < ctx.today:
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_EXPIRED)
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)

	# Acte III : Main courante ↔ Répondant, Convocations ↔ Convocation.
	if a.is_ledger() or b.is_ledger():
		return _check_ledger(case, a if a.is_ledger() else b, b if a.is_ledger() else a, ctx, result)
	if a.is_summons() or b.is_summons():
		return _check_summons(case, a if a.is_summons() else b, b if a.is_summons() else a, ctx, result)
	# Acte II : onglet Révocations ↔ N° ID.
	if a.is_revoked() or b.is_revoked():
		return _check_revoked(case, a if a.is_revoked() else b, b if a.is_revoked() else a, ctx, result)
	if a.is_quota_counter() or b.is_quota_counter():
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	# M7 : avis de recherche ↔ visage / nom.
	if a.is_wanted() or b.is_wanted():
		return _check_wanted(case, a if a.is_wanted() else b, b if a.is_wanted() else a, ctx, result)
	# M7 : visage ↔ implants déclarés, visage ↔ date de naissance.
	if a.is_passenger_face() or b.is_passenger_face():
		var other_ref: FieldRef = b if a.is_passenger_face() else a
		var other_field: FieldDef = case.get_field_def(other_ref)
		if other_field != null and other_field.truth_path == &"implants":
			var declared: PackedStringArray = FieldValue.normalize(ImplantsDeclaredRule.as_list(case.get_value(other_ref)))
			var visible: PackedStringArray = FieldValue.normalize(case.passenger_presented.implants)
			# M13 (J8+) : un implant déclaré « non visible — fouille » n'est pas comparé au visage.
			var implants_rule: ImplantsDeclaredRule = _implants_rule(ctx)
			if implants_rule != null:
				declared = implants_rule.face_declared(declared, visible, ctx)
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
			if ApparentAgeRule.birth_matches_band(birth_date, ctx.today, case.passenger_presented.appearance.age_band):
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
	if case.get_document(a.document_id).is_foreign() or case.get_document(b.document_id).is_foreign():
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if FieldValue.equals(case.get_value(a), case.get_value(b)):
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
	return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_MISMATCH)


## Onglet du Rulebook portant le bulletin des symboles (`DayDef.rulebook_tabs`).
const SYMBOLS_TAB: String = "symbols"
## M13 (CB-08) : symbole des imprimés trouvés à la fouille.
const PRINT_SYMBOL: StringName = &"luciole"


## M13 (§1.8) : puce ↔ autre référence. Seuls les champs de documents font foi.
static func _check_statement(case: Case, statement_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	var statement: Statement = case.get_statement_by_ref(statement_ref)
	if statement == null:
		# Cas scénarisé sans `statements` : réponse en prose, aucune puce.
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_STATEMENT_FREE)
	if not statement.given:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_STATEMENT_NOT_GIVEN)
	if not other.is_document_field() or not case.has_field(other):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if statement.vague:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_STATEMENT_VAGUE)
	if statement.id == Statement.ID_PROVENANCE:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_PROVENANCE)
	var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(ctx.rule_set if ctx != null else null)
	if rule == null or not rule.checks_topic(statement.id):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RULE_INACTIVE)
	match rule.compare(case, statement, other):
		Discrepancy.Result.DISCORDANT:
			if is_document_at_fault(case, statement, other, rule):
				# QA-064 : la parole concorde avec son document de référence ;
				# c'est cet autre document qui est faux (Code du contrat, R25) :
				# discordance documentaire, jamais « déclaration contradictoire ».
				return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_MISMATCH)
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_STATEMENT_MISMATCH)
		Discrepancy.Result.CONCORDANT:
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
	return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)


## QA-064 (M13 §1.6 : un honnête ne produit jamais de puce discordante) :
## une puce discordante avec un champ qui **n'est pas** son champ de référence
## (`StatementsConsistentRule.primary_ref` : Permis, Carte ou laissez-passer)
## alors qu'elle ne contredit pas cette référence (concordante, ou référence
## absente) accuse le document, pas la parole. La paire reste DISCORDANTE et
## documente la violation de ce document (elle partage son champ).
static func is_document_at_fault(case: Case, statement: Statement, other: FieldRef,
		rule: StatementsConsistentRule) -> bool:
	var primary: FieldRef = rule.primary_ref(case, statement)
	if primary != null and primary.equals(other):
		return false
	return primary == null or rule.compare(case, statement, primary) != Discrepancy.Result.DISCORDANT


## M13 (§2.5) : objet révélé ↔ entrée de l'onglet Contrebande (même catégorie,
## objet interdit : DISCORDANT ; objet autorisé : CONCORDANT) ou ↔ « Implants
## déclarés » (implant trouvé absent de la liste : DISCORDANT).
static func _check_scan(case: Case, scan_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	var item: SearchItem = case.get_scan_item(scan_ref)
	if other.is_contraband_entry():
		if item.is_forbidden() and item.category == other.field_id:
			var reason: String = Discrepancy.REASON_WEAPON if item.kind == SearchItem.Kind.WEAPON \
					else Discrepancy.REASON_CONTRABAND
			return result.set_result(Discrepancy.Result.DISCORDANT, reason)
		if item.kind == SearchItem.Kind.LEGIT:
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_ITEM_ALLOWED)
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	var field: FieldDef = case.get_field_def(other)
	if item.is_implant() and field != null and field.truth_path == &"implants":
		if item.unreadable and item.implant_code.is_empty():
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_SCAN_UNREADABLE)
		var listed: PackedStringArray = FieldValue.normalize(ImplantsDeclaredRule.as_list(case.get_value(other)))
		var code: String = FieldValue.normalize(PackedStringArray([item.implant_code]))[0]
		if listed.has(code):
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
		return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_IMPLANT_MISMATCH)
	return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)


## Symbole ↔ marque : DISCORDANCE si le document porte la marque du symbole et
## que le bulletin est ouvert ce jour ; sinon INCOMPARABLE.
static func _check_symbol(case: Case, symbol_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	if other.is_scan():
		# M13 (CB-08) : imprimé à la luciole trouvé à la fouille ↔ bulletin.
		var item: SearchItem = case.get_scan_item(other)
		if item == null or not item.revealed or item.kind != SearchItem.Kind.SUBVERSIVE:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		if ctx == null or ctx.day_def == null or not ctx.day_def.rulebook_tabs.has(SYMBOLS_TAB):
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RULE_INACTIVE)
		if symbol_ref.field_id != PRINT_SYMBOL:
			return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
		return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_SYMBOL_MATCH)
	if other.is_symbol() or not other.is_mark():
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if ctx == null or ctx.day_def == null or not ctx.day_def.rulebook_tabs.has(SYMBOLS_TAB):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RULE_INACTIVE)
	var doc: DocumentInstance = case.get_document(other.document_id)
	if doc == null or not doc.marks.has(other.get_mark_id()):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_UNKNOWN_FIELD)
	if other.get_mark_id() != symbol_ref.field_id:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_SYMBOL_MATCH)


static func _is_resolvable(case: Case, ref: FieldRef, ctx: RuleContext) -> bool:
	if ref.is_scan():
		return case.is_scan_item_revealed(ref)
	if ref.is_contraband_entry():
		for rule: ContrabandRule in ContrabandRule.active_in(ctx.rule_set if ctx != null else null):
			if rule.categories.has(ref.field_id):
				return true
		return false
	if ref.is_revoked():
		return RevokedIdRule.find_any_entry(ctx, ref.field_id) != null
	if ref.is_quota_counter():
		return ctx != null
	if ref.is_ledger():
		return ctx != null and ctx.find_ledger(ref.field_id) != null
	if ref.is_summons():
		return ctx != null and ctx.find_summons(ref.field_id) != null
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


## Acte II : entrée de l'onglet Révocations ↔ N° ID d'un document.
static func _check_revoked(case: Case, revoked_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	# M12 : onglet Révocations ou liste nommée active (cartes volées, EV-07).
	var entry: RevokedEntry = RevokedIdRule.find_any_entry(ctx, revoked_ref.field_id)
	var field: FieldDef = case.get_field_def(other)
	if entry == null or field == null or field.truth_path != &"citizen_id":
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if FieldValue.equals(case.get_value(other), entry.citizen_id):
		if RevokedIdRule.reinstatements_honored(ctx) and entry.is_reinstated(ctx.today):
			# Acte III (R33) : révoqué·e puis réintégré·e, valide (M12 : R40 aussi).
			return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_REINSTATED)
		return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_REVOKED_MATCH)
	return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_REVOKED_NO_MATCH)


## Acte III (R34) : entrée de la Main courante ↔ Répondant du permis — même
## N° ID : CONCORDANT (le répondant a été admis) ; autre N° : INCOMPARABLE.
static func _check_ledger(case: Case, ledger_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	var entry: LedgerEntry = ctx.find_ledger(ledger_ref.field_id)
	var field: FieldDef = case.get_field_def(other)
	if entry == null or field == null or field.truth_path != SponsorRule.SPONSOR_PATH:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if FieldValue.equals(case.get_value(other), entry.citizen_id):
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_SPONSOR_MATCH)
	return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)


## Acte III (R36) : entrée de l'onglet Convocations ↔ Convocation du permis —
## même N° et même nom : CONCORDANT ; même N°, autre nom (carte) : DISCORDANT ;
## autre N° : INCOMPARABLE.
static func _check_summons(case: Case, summons_ref: FieldRef, other: FieldRef, ctx: RuleContext,
		result: Discrepancy) -> Discrepancy:
	var entry: SummonsEntry = ctx.find_summons(summons_ref.field_id)
	var field: FieldDef = case.get_field_def(other)
	if entry == null or field == null or field.truth_path != SummonsRule.SUMMONS_PATH:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if not FieldValue.equals(case.get_value(other), entry.number):
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	if SummonsRule.name_matches(case, entry):
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_SUMMONS_MATCH)
	return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_SUMMONS_NAME)


## Acte II (R27) : Firmware NX ↔ date du jour, discordant si la règle active
## d'ancienneté du firmware le juge périmé ; champ vide ou règle inactive :
## INCOMPARABLE.
static func _check_firmware(case: Case, dated: FieldRef, ctx: RuleContext, result: Discrepancy) -> Discrepancy:
	var value: Variant = case.get_value(dated)
	if not value is int or ctx == null or ctx.rule_set == null:
		return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	for rule: Rule in ctx.rule_set.rules:
		var age_rule: DocumentNotExpiredRule = rule as DocumentNotExpiredRule
		if age_rule == null or age_rule.field_path != FIRMWARE_PATH or age_rule.document_id != dated.document_id:
			continue
		if age_rule.is_expired(case.get_document(dated.document_id), ctx.today, ctx, case):
			return result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_EXPIRED)
		return result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_CONCORDANT)
	return result.set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_RULE_INACTIVE)


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


static func _implants_rule(ctx: RuleContext) -> ImplantsDeclaredRule:
	if ctx == null or ctx.rule_set == null:
		return null
	for rule: Rule in ctx.rule_set.rules:
		if rule is ImplantsDeclaredRule:
			return rule
	return null


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
