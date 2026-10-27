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
## Nature du message (couleur du locuteur, DS §7.10) : Consortium, mentor, famille.
enum Voice { CONSORTIUM, MENTOR, FAMILY }

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
