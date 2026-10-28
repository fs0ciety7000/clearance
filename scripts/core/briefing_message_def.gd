## Message conditionnel du briefing (M7, NARRATIVE §3, B11) — données de
## `DayDef.briefing_messages`, lues par `BriefingContent.build`.
##
## `group` : dans un même groupe, seul le premier message dont la condition est
## vraie est retenu (variantes « si … sinon »). `family_slot` : message
## narratif d'Ilan, remplacé par le message d'état du foyer si le foyer ne va
## pas bien (`BriefingContent.family_message_key`), omis si Ilan est mis·e en
## attente. `priority` : au plus `BriefingContent.MAX_MESSAGES` messages,
## les plus petites priorités d'abord (puis l'ordre des données).
class_name BriefingMessageDef
extends Resource

@export var speaker_key: String = ""
@export var text_key: String = ""
## `BriefingContent.Voice` (entier : CONSORTIUM, MENTOR, FAMILY, LUCIOLES, INSPECTION).
@export var voice: int = 0
@export var condition: FlagCondition = null
@export var group: StringName = &""
@export var family_slot: bool = false
@export var priority: int = 0
