## Réplique d'intercom pilotée par les données (M13, B68 ; ARCHITECTURE §12.7)
## — `DayDef.intercom_lines` (lot B) : Okonkwo (J4, J8), Sato (J12)…
##
## `OkonkwoIntercom` émet `spoke(speaker_key, text_key)` la **première** fois
## que le déclencheur se produit pendant le shift (une fois par shift si
## `once`), si la condition sur les drapeaux est vraie. Le tutoriel du J1 reste
## codé (`OkonkwoIntercom.ACTIVE_DAY`).
class_name IntercomLineDef
extends Resource

# Déclencheurs (`trigger`) et leur argument facultatif (`trigger_arg`).
## Au premier passager du shift (`WAITING_CASE`).
const TRIGGER_SHIFT_OPEN: StringName = &"shift_open"
## Puce émise (`statement_given`) ; argument : id de déclaration (`employer`), vide = toute puce.
const TRIGGER_STATEMENT_GIVEN: StringName = &"statement_given"
## Discordance confirmée sur une puce (déclaration contradictoire épinglée).
const TRIGGER_STATEMENT_PINNED: StringName = &"statement_pinned"
## Comparaison d'une puce vague (`disc_statement_vague`).
const TRIGGER_STATEMENT_VAGUE: StringName = &"statement_vague"
## Fouille engagée (`search_opened`) ; argument : motif (`none` = sans motif), vide = toute fouille.
const TRIGGER_SEARCH_OPENED: StringName = &"search_opened"
## Fouille refermée sans trouvaille interdite (au moins une zone scannée).
const TRIGGER_SEARCH_CLEAN: StringName = &"search_clean"
## Fouille refermée avec une trouvaille interdite.
const TRIGGER_SEARCH_FOUND: StringName = &"search_found"
## Cas résolu ; argument : `<scripted_id>` ou `<scripted_id>:<approve|deny|detain>`.
const TRIGGER_CASE_RESOLVED: StringName = &"case_resolved"
## Citation émise ; argument : clé `cit_*`, vide = toute citation.
const TRIGGER_CITATION: StringName = &"citation"
const TRIGGERS: Array[StringName] = [TRIGGER_SHIFT_OPEN, TRIGGER_STATEMENT_GIVEN, TRIGGER_STATEMENT_PINNED,
		TRIGGER_STATEMENT_VAGUE, TRIGGER_SEARCH_OPENED, TRIGGER_SEARCH_CLEAN, TRIGGER_SEARCH_FOUND,
		TRIGGER_CASE_RESOLVED, TRIGGER_CITATION]
## Argument de `search_opened` pour une fouille sans motif.
const ARG_NO_MOTIVE: StringName = &"none"

## Locuteur (`spk_okonkwo`, `spk_sato`).
@export var speaker_key: String = "spk_okonkwo"
@export var text_key: String = ""
@export var trigger: StringName = &""
@export var trigger_arg: StringName = &""
## Condition sur les drapeaux du matin (null = toujours).
@export var condition: FlagCondition = null
## Dite une seule fois par shift.
@export var once: bool = true


static func make(p_text_key: String, p_trigger: StringName, p_arg: StringName = &"",
		p_speaker: String = "spk_okonkwo") -> IntercomLineDef:
	var line: IntercomLineDef = IntercomLineDef.new()
	line.text_key = p_text_key
	line.trigger = p_trigger
	line.trigger_arg = p_arg
	line.speaker_key = p_speaker
	return line


## Vrai si l'événement `p_trigger` d'argument `arg` déclenche la réplique
## (argument vide dans les données = tout argument).
func matches(p_trigger: StringName, arg: StringName = &"") -> bool:
	if p_trigger != trigger:
		return false
	if trigger_arg == &"":
		return true
	if trigger == TRIGGER_CASE_RESOLVED and not String(trigger_arg).contains(":"):
		return String(arg).get_slice(":", 0) == String(trigger_arg)
	return arg == trigger_arg
