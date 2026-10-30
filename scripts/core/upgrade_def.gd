## Amélioration du guichet vendue le soir à l'Économat du Hall (M13, D-141,
## D-150 ; ARCHITECTURE §12.6) — `data/upgrades/ag_0N.tres` (lot B), listées
## dans `EconomyDef.upgrades`.
##
## Possession = **drapeau** booléen `upg_<id>` (delta 0, D-045) dans le
## dictionnaire de drapeaux déjà sauvegardé : sauvegarde v6 inchangée.
## Permanente pour la partie ; seule AG-04 peut être perdue (confisquée à un
## audit : `upg_ag04_found`, lot B). Un achat par soir au plus, sans
## découvert (`EveningService.shop_lines()`, lot B) ; effet dès le shift
## suivant (le `DayController` lit les drapeaux au début du shift).
class_name UpgradeDef
extends Resource

## Préfixe du drapeau de possession (`upg_ag01`).
const FLAG_PREFIX: String = "upg_"
# Identifiants (M13 §3.2).
const ID_HYGIAPHONE: StringName = &"ag01"
const ID_WOOD_LAMP: StringName = &"ag02"
const ID_CALIBRATED_GATE: StringName = &"ag03"
const ID_DOUBLE_DRAWER: StringName = &"ag04"
const ID_ANNOTATED_BOOK: StringName = &"ag05"
const ID_QUEUE_MONITOR: StringName = &"ag06"
## AG-04 trouvé par Ravel à un audit (tiroir confisqué, effet perdu).
const FLAG_DRAWER_FOUND: StringName = &"upg_ag04_found"
## Jauge des fouilles sans motif (texte seulement : Okonkwo J9, Revue J17).
const FLAG_SEARCH_ABUSE: StringName = &"fouille_abus"

## `ag01` … `ag06`.
@export var id: StringName = &""
## Textes : `upg_<id>_name`, `_desc` (une ligne d'effet), `_note` (prix narratif, facultatif).
@export var name_key: String = ""
@export var desc_key: String = ""
@export var note_key: String = ""
## Prix en crédits (10 à 35 ₵) et ligne de dépense (`exp_upgrade_<id>`).
@export var price: int = 0
@export var expense_key: String = ""
## Soirs de disponibilité, bornes incluses (numéro du jour qui s'achève).
@export var first_evening: int = 5
@export var last_evening: int = 29
## Condition supplémentaire (AG-04 : `bribe_seen` ; AG-05 : Okonkwo présent).
@export var condition: FlagCondition = null
## Offre hors catalogue (AG-04, AG-05) : arrive par un message du soir
## (`offer_message_key`) et s'affiche sous « HORS CATALOGUE ».
@export var off_catalog: bool = false
@export var offer_message_key: String = ""
## Drapeaux posés à l'achat (`{drapeau: delta}`, AG-06 : `loyalty +1`).
@export var purchase_flags: Dictionary[StringName, int] = {}
## Effets paramétrés lus par les systèmes (lot B / C) : clés `EFFECT_*`.
@export var effects: Dictionary[StringName, Variant] = {}

# Clés d'effets (documentation du contrat ; valeurs en données).
## AG-04 : une enveloppe gardée sur `n` ne laisse pas de trace (1ʳᵉ, 3ᵉ… : `2`).
const EFFECT_ENVELOPE_TRACE_EVERY: StringName = &"envelope_trace_every"
## AG-03 : `suspicion` ajoutée à l'approbation après une trouvaille interdite.
const EFFECT_SUSPICION_ON_FOUND: StringName = &"suspicion_on_found"
## AG-04 : score ajouté à l'audit quand le tiroir est trouvé.
const EFFECT_AUDIT_PENALTY: StringName = &"audit_penalty"


## Drapeau de possession (`upg_ag01`).
func owned_flag() -> StringName:
	return flag_of(id)


static func flag_of(upgrade_id: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(upgrade_id))


## Vrai si les drapeaux portent la possession de `upgrade_id` (et, pour AG-04,
## si le tiroir n'a pas été confisqué).
static func owns(flags: Dictionary[StringName, Variant], upgrade_id: StringName) -> bool:
	if not FlagCondition.is_flag_true(flags, flag_of(upgrade_id)):
		return false
	return upgrade_id != ID_DOUBLE_DRAWER or not FlagCondition.is_flag_true(flags, FLAG_DRAWER_FOUND)


func is_owned(flags: Dictionary[StringName, Variant]) -> bool:
	return owns(flags, id)


## En vente le soir du jour `evening_day` (fenêtre, condition, pas encore possédée).
func is_offered(evening_day: int, flags: Dictionary[StringName, Variant]) -> bool:
	if evening_day < first_evening or evening_day > last_evening:
		return false
	if FlagCondition.is_flag_true(flags, owned_flag()):
		return false
	return FlagCondition.check(condition, flags)


## Premier soir de disponibilité (badge NOUVEAU).
func is_new(evening_day: int) -> bool:
	return evening_day == first_evening


## Achetable : offerte et solde suffisant (l'Économat ne fait pas crédit).
func can_buy(evening_day: int, flags: Dictionary[StringName, Variant], balance_after_expenses: int) -> bool:
	return is_offered(evening_day, flags) and balance_after_expenses >= price


func get_effect(key: StringName, default: Variant = null) -> Variant:
	return effects.get(key, default)
