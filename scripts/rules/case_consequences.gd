## Conséquences narratives d'un cas après le tampon (M7 ; GDD §4.7, §5.5,
## §11.1 ; NARRATIVE §2.3, §4) — pur, statique. Partagé par le
## `DayController` (vrai shift) et le `DaySimulator` (équilibrage).
##
## Sources, dans l'ordre (les deltas d'un même drapeau s'additionnent) :
## 1. cas scénarisé : `sets_flag`, puis `flags_on_approve` / `flags_on_deny` /
##    `flags_on_detain` (repli `flags_on_deny`), puis `extra_effects` ;
## 2. objets glissés : `SlippedItem.effects_for(verdict, décision finale)` ;
## 3. réponse à la phrase de passe (code 4) : `password_answered` et
##    `lucioles_trust +1` la première fois ; `suspicion +1` le jour de l'audit (J9) ;
## 4. passager **généré** porteur d'un code Luciole : approuvé malgré une
##    violation → `lucioles_trust +1` ; détenu → `lucioles_trust −2`,
##    `loyalty +1` (dénonciation, GDD §4.7) ;
## 5. signalement valide d'un porteur du code 1 (`luciole_report`, NARRATIVE
##    §4.9) : `luciole_reported_at_booth`, et `lucioles_trust −2` / `loyalty +1`
##    une seule fois (pas de cumul avec le 4) ; un cas scénarisé qui définit
##    `flags_on_detain` (SC-13) garde ses drapeaux à la place de ces jauges.
## Résultat : valeurs **absolues** `{drapeau: valeur}` à poser dans le
## `GameState` (`true` pour un delta 0, sinon valeur actuelle + deltas).
class_name CaseConsequences
extends RefCounted

const FLAG_LOYALTY: StringName = &"loyalty"
const FLAG_TRUST: StringName = &"lucioles_trust"
const FLAG_SUSPICION: StringName = &"suspicion"
const FLAG_PASSWORD: StringName = &"password_answered"
## Jour de l'audit : répondre à la phrase de passe y est vu par l'Inspecteur.
const AUDIT_DAY: int = 9
## Confiance minimale des Lucioles pour répondre à la phrase de passe (GDD §4.7).
const PASSWORD_TRUST: int = 2
## Signalement valide au guichet (NARRATIVE §4.9).
const FLAG_REPORTED_AT_BOOTH: StringName = &"luciole_reported_at_booth"


static func compute(scripted: ScriptedCaseDef, case: Case, verdict: VerdictKind.Kind, had_violations: bool,
		password_answered: bool, day_number: int, flags: Dictionary[StringName, Variant],
		luciole_report: bool = false) -> Dictionary[StringName, Variant]:
	var changes: Dictionary[StringName, Variant] = {}
	if scripted != null:
		if scripted.sets_flag != &"":
			changes[scripted.sets_flag] = true
		var table: Dictionary[StringName, int] = scripted.flags_on_approve
		if verdict == VerdictKind.Kind.DENY:
			table = scripted.flags_on_deny
		elif verdict == VerdictKind.Kind.DETAIN:
			table = scripted.flags_on_detain if not scripted.flags_on_detain.is_empty() else scripted.flags_on_deny
		add_all(changes, flags, table)
		for effect: CaseEffectDef in scripted.extra_effects:
			if effect != null and effect.applies(verdict, flags):
				add_all(changes, flags, effect.flags)
	if case != null:
		for item: SlippedItem in case.slipped_items:
			add_all(changes, flags, item.effects_for(verdict, item.final_decision()))
		if scripted == null and case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE):
			if verdict == VerdictKind.Kind.APPROVE and had_violations:
				add(changes, flags, FLAG_TRUST, 1)
			elif verdict == VerdictKind.Kind.DETAIN and not luciole_report:
				add(changes, flags, FLAG_TRUST, -2)
				add(changes, flags, FLAG_LOYALTY, 1)
	if luciole_report:
		add(changes, flags, FLAG_REPORTED_AT_BOOTH, 0)
		if scripted == null or scripted.flags_on_detain.is_empty():
			add(changes, flags, FLAG_TRUST, -2)
			add(changes, flags, FLAG_LOYALTY, 1)
	if password_answered:
		if not FlagCondition.is_flag_true(flags, FLAG_PASSWORD) and not changes.has(FLAG_PASSWORD):
			changes[FLAG_PASSWORD] = true
			add(changes, flags, FLAG_TRUST, 1)
		if day_number == AUDIT_DAY:
			add(changes, flags, FLAG_SUSPICION, 1)
	return changes


## Ajoute une table `{drapeau: delta}` (clés `StringName` ou textes).
static func add_all(changes: Dictionary[StringName, Variant], flags: Dictionary[StringName, Variant], table: Dictionary) -> void:
	for key: Variant in table:
		add(changes, flags, StringName(str(key)), SaveService.as_int(table[key]))


## Delta 0 = drapeau mis à vrai ; sinon ajouté à la valeur courante.
static func add(changes: Dictionary[StringName, Variant], flags: Dictionary[StringName, Variant], flag: StringName, delta: int) -> void:
	if delta == 0:
		if not changes.has(flag):
			changes[flag] = true
		return
	var base: int = SaveService.as_int(changes[flag]) if changes.has(flag) and not changes[flag] is bool \
			else SaveService.as_int(flags.get(flag, 0))
	changes[flag] = base + delta


## Applique des valeurs absolues à un dictionnaire de drapeaux (simulateurs).
static func merge_into(flags: Dictionary[StringName, Variant], changes: Dictionary[StringName, Variant]) -> void:
	for flag: StringName in changes:
		flags[flag] = changes[flag]
