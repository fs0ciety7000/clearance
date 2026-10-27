## Contenu du briefing du jour (UI_FLOW §7, §8 ; LORE §3 « délégation
## progressive des quais », §4 slogans, §11 vie de l'agent ; GDD §3.2, §12).
##
## Assemble des **clés** de texte (`fr.csv`) selon le jour, les drapeaux
## narratifs (échos des dilemmes de la veille) et l'état du foyer : bulletin
## du Bureau de Continuité (directive de délégation, slogan), règles du jour
## (badge NOUVEAU), messages personnels (Okonkwo au J1, Ilan, brèves du hall) ;
## au J1, avis de versement de la Trésorerie : avance du Consortium (D-047,
## `starting_credits`, carte dédiée du briefing).
## Pur : aucune dépendance aux autoloads (les données sont passées).
class_name BriefingContent
extends RefCounted

const SPEAKER_OKONKWO: String = "spk_okonkwo"
const SPEAKER_ILAN: String = "spk_ilan"
const SPEAKER_HALL: String = "spk_hall"
const SPEAKER_TREASURY: String = "spk_treasury"
const MSG_ADVANCE: String = "msg_consortium_advance"
## Nature du message (couleur du locuteur, DS §7.10) : Consortium, mentor,
## famille ; M7 : Lucioles (magenta), Inspection (jaune). On n'ajoute qu'à la fin.
enum Voice { CONSORTIUM, MENTOR, FAMILY, LUCIOLES, INSPECTION }
## Au plus 4 messages par briefing (NARRATIVE §3).
const MAX_MESSAGES: int = 4

var day_number: int = 1
var game_date: int = 0
## « DIRECTIVE DE DÉLÉGATION N° 03 — Permis d'entrée ».
var directive_title_key: String = ""
## Texte de la directive (`DayDef.intro_text_key`).
var directive_key: String = ""
var slogan_key: String = ""
var rulebook: Array[RulebookEntry] = []
## `{speaker: String (clé), text: String (clé), voice: Voice, args: Array}`
## dans l'ordre (`args` : valeurs du gabarit `%s`, souvent vide).
var messages: Array[Dictionary] = []
## Avance du Consortium versée à la prise de poste (J1 seulement, 0 sinon).
var advance_credits: int = 0


## `advance` : avance du Consortium du barème (`EconomyDef.starting_credits`),
## annoncée au J1 seulement.
static func build(day: DayDef, flags: Dictionary[StringName, Variant], household: Household, advance: int = 0) -> BriefingContent:
	var content: BriefingContent = BriefingContent.new()
	if day == null:
		return content
	var n: int = day.day_number
	content.day_number = n
	content.game_date = day.game_date
	content.directive_title_key = "day%02d_directive_title" % n
	content.directive_key = day.intro_text_key
	content.slogan_key = "day%02d_slogan" % n
	content.rulebook = day.rule_set.build_rulebook() if day.rule_set != null else []
	if n == 1 and advance > 0:
		content.advance_credits = advance
	# M7 (J4+) : table de messages conditionnels des données (NARRATIVE §3, B11).
	if not day.briefing_messages.is_empty():
		content._add_from_table(day.briefing_messages, flags, household, n)
		return content
	# Échos des choix de la veille (GDD §11.1 : « écho parfois dans le bulletin »).
	if n == 2:
		if _is_true(flags, &"sc02_mercy"):
			content.add(SPEAKER_OKONKWO, "msg_echo_sc02_mercy", Voice.MENTOR)
		elif _is_true(flags, &"sc02_turned_away"):
			content.add(SPEAKER_HALL, "msg_echo_sc02_turned_away", Voice.CONSORTIUM)
	if n == 3 and _is_true(flags, &"sc03_passed"):
		content.add(SPEAKER_HALL, "msg_echo_sc03_passed", Voice.CONSORTIUM)
	# Mentor : tutoriel diégétique court au J1, conseil du jour ensuite.
	content.add(SPEAKER_OKONKWO, "msg_okonkwo_day%02d" % n, Voice.MENTOR)
	content.add(SPEAKER_ILAN, family_message_key(n, household), Voice.FAMILY)
	return content


## Messages conditionnels : premier vrai de chaque groupe, emplacement « Ilan »
## remplacé par l'état du foyer s'il ne va pas bien (omis si Ilan est mis·e en
## attente), au plus `MAX_MESSAGES` (plus petites priorités), ordre des données.
func _add_from_table(defs: Array[BriefingMessageDef], flags: Dictionary[StringName, Variant], household: Household,
		on_day: int) -> void:
	var picked: Array[Array] = [] # [ordre, priorité, speaker, texte, voix]
	var used_groups: Array[StringName] = []
	var family_key: String = family_message_key(on_day, household)
	var ilan: Household.Member = household.get_member(Household.ILAN) if household != null else null
	var ilan_away: bool = ilan != null and ilan.detained
	var family_index: int = -1
	var family_picked: bool = false
	for i: int in defs.size():
		var def: BriefingMessageDef = defs[i]
		if def == null or (def.group != &"" and used_groups.has(def.group)):
			continue
		if def.family_slot:
			if family_index < 0:
				family_index = i
			if ilan_away:
				continue
			if family_key != "msg_family_ok":
				family_picked = true
				if def.group != &"":
					used_groups.append(def.group)
				picked.append([i, def.priority, def.speaker_key, family_key, Voice.FAMILY])
				continue
		if not FlagCondition.check(def.condition, flags):
			continue
		if def.group != &"":
			used_groups.append(def.group)
		family_picked = family_picked or def.family_slot
		picked.append([i, def.priority, def.speaker_key, def.text_key, def.voice])
	# Pas de message narratif d'Ilan ce jour : l'état du foyer (« tout va bien »).
	if family_index >= 0 and not family_picked and not ilan_away:
		picked.append([family_index, 0, SPEAKER_ILAN, family_key, Voice.FAMILY])
	var ranked: Array[Array] = picked.duplicate()
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	ranked = ranked.slice(0, MAX_MESSAGES)
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in ranked:
		var voice: Voice = entry[4]
		var speaker: String = entry[2]
		var text: String = entry[3]
		add(speaker, text, voice)


func add(speaker_key: String, text_key: String, voice: Voice, args: Array = []) -> void:
	messages.append({"speaker": speaker_key, "text": text_key, "voice": voice, "args": args})


func get_new_entries() -> Array[RulebookEntry]:
	var list: Array[RulebookEntry] = []
	for entry: RulebookEntry in rulebook:
		if entry.is_new:
			list.append(entry)
	return list


## Message d'Ilan selon l'état le plus grave du foyer.
static func family_message_key(on_day: int, household: Household) -> String:
	if on_day <= 1 or household == null:
		return "msg_family_day01"
	var lost: bool = false
	var grave: bool = false
	var noa_sick: bool = false
	var sick: bool = false
	var hungry: bool = false
	var cold: bool = false
	for member: Household.Member in household.members:
		lost = lost or member.health == Household.Health.LOST
		grave = grave or member.health == Household.Health.GRAVELY_SICK
		sick = sick or member.health == Household.Health.SICK
		noa_sick = noa_sick or (member.id == Household.NOA and member.health == Household.Health.SICK)
		hungry = hungry or member.hungry
		cold = cold or member.cold
	if lost:
		return "msg_family_lost"
	if grave:
		return "msg_family_grave"
	if noa_sick:
		return "msg_family_noa_sick"
	if sick:
		return "msg_family_sick"
	if hungry:
		return "msg_family_hungry"
	if cold:
		return "msg_family_cold"
	return "msg_family_ok"


static func _is_true(flags: Dictionary[StringName, Variant], flag: StringName) -> bool:
	var value: Variant = flags.get(flag, false)
	return (value is bool and value) or SaveService.as_int(value) != 0
