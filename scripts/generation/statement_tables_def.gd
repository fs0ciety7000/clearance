## Tables des déclarations orales (M13, docs/M13.md §1.3–§1.6, §1.11 ; B65) —
## `data/statements/statements.tres`, produit par `tools/build_data_m13.gd`.
##
## Données seulement : formules de durée et leurs intervalles, fragments de
## motif, alias d'employeurs, relations de la personne visitée, cadres par
## origine, motifs plausibles d'AV-1, taux du bruit légitime (VN-1 → VN-6). Lu
## par `StatementGenerator` (déclarations honnêtes) et par l'injecteur
## `STATEMENT_MISMATCH` (AV-1 → AV-5). Les textes sont des clés de `fr.csv`.
class_name StatementTablesDef
extends Resource

## Identifiants de déclaration (`Statement.id`).
const ID_PURPOSE: StringName = &"purpose"
const ID_STAY: StringName = &"stay"
const ID_EMPLOYER: StringName = &"employer"
const ID_ORIGIN: StringName = &"origin"
const ID_PROVENANCE: StringName = &"provenance"
const ID_HOST: StringName = &"host"
## Sujets d'AV (`topic` de l'injecteur, `DayDef.statement_topic_weights`).
const TOPICS: Array[StringName] = [ID_PURPOSE, ID_STAY, ID_EMPLOYER, ID_ORIGIN, ID_HOST]

@export_group("Durées")
## Formules de durée à intervalle (`stmt_dur_w1` → [6–8]…), dans l'ordre des
## intervalles croissants ; `duration_ranges[i]` = (min, max) en jours.
@export var duration_keys: PackedStringArray = []
@export var duration_ranges: Array[Vector2i] = []
## Durées dites exactement (« Cinq jours ») : n → clé ; au-delà, `exact_key` (`%d jours`).
@export var exact_duration_keys: Dictionary[int, String] = {}
@export var exact_key: String = "stmt_dur_n"
## Plus longue durée dite exactement (repli de VN-6).
@export var exact_max: int = 60
## Au-delà de ce nombre de jours, une durée passe **toujours** par une formule à intervalle (VN-6).
@export var interval_above: int = 10
## Formules vagues (VN-1) : puce INCOMPARABLE.
@export var vague_keys: PackedStringArray = []

@export_group("Fragments")
## Motif (`Passenger.PURPOSE_*`) → clés de fragment (`stmt_purpose_work_1`…).
@export var purpose_keys: Dictionary[StringName, PackedStringArray] = {}
## Origine (`FactionDef.id`) → clé « Je suis de… » (`stmt_origin_drv` : `%s` = vaisseau).
@export var origin_keys: Dictionary[StringName, String] = {}
@export var employer_key: String = "stmt_employer"
## Relation de la personne visitée → clé (`stmt_host_son` : « mon fils, %s »).
@export var host_keys: Dictionary[StringName, String] = {}
## Relations « de famille » (même nom de famille que le passager, AV-5).
@export var family_relations: PackedStringArray = []
## Provenance (« j'arrive de… ») : jamais comparée (VN-3, VN-4).
@export var provenance_shuttle_key: String = "stmt_prov_shuttle"
@export var provenance_place_key: String = "stmt_prov_place"
@export var provenance_tessar_key: String = "stmt_prov_tessar"
## Lieux de provenance (clés `stmt_place_*`).
@export var provenance_places: PackedStringArray = []

@export_group("Employeurs")
## Alias reconnu → nom canonique (VN-5 : « Kessler-Ashe » → « Kessler-Ashe Orbital »).
@export var employer_aliases: Dictionary[String, String] = {}
## Employeurs vagues (« les serres », « la station ») : jamais une puce comparable.
@export var vague_employers: PackedStringArray = []
## Corporations du LORE (§6) tirables par AV-3 (noms canoniques).
@export var lore_employers: PackedStringArray = []

@export_group("Cadres")
## Cadres « motif + durée » par origine (`tyc`…) ; `gen` = cadres génériques.
@export var frames: Dictionary[StringName, PackedStringArray] = {}
## Cadres spécialisés : motif TRAVAIL avec employeur, VISITE FAMILIALE avec
## personne visitée, auto-correction (VN-2), « Combien de temps ? », origine.
@export var work_frames: PackedStringArray = []
@export var visit_frames: PackedStringArray = []
@export var correction_frames: PackedStringArray = []
@export var stay_frames: PackedStringArray = []
## Cadres d'origine **avec** provenance (`{origine}` et `{provenance}`) et sans.
@export var origin_frames: PackedStringArray = []
@export var origin_frames_plain: PackedStringArray = []
## Cadres d'origine des Dérivants (`{origine}` = « Je suis du {vaisseau} »).
@export var origin_frames_drv: PackedStringArray = []
## Cadre « provenance seule » (réponse en Tessar, VN-4).
@export var origin_frames_tessar: PackedStringArray = []
## Part des cadres d'une origine tirés dans `frames[gen]` plutôt que dans ceux de l'origine.
@export_range(0.0, 1.0) var generic_frame_rate: float = 0.5

## Longueur des textes FR des cadres et des fragments (sans leurs arguments),
## sans ses emplacements pour un cadre, calculée par `build_data_m13` : un cadre n'est choisi que si la réplique
## remplie tient en `max_line_length` caractères (sous-titre, NARRATIVE §7).
@export var text_lengths: Dictionary[String, int] = {}
## Emplacements de chaque cadre (`motif`, `duree`, `duree_barree`…), dans l'ordre.
@export var frame_tokens: Dictionary[String, PackedStringArray] = {}
@export var max_line_length: int = 90

@export_group("AV-1")
## Motifs plausibles d'un menteur, par origine (AV-1) : jamais le motif du permis.
@export var lie_purposes: Dictionary[StringName, PackedStringArray] = {}

@export_group("Taux (passagers générés)")
## VN-1 : durée vague (jamais chez un menteur AV-2).
@export_range(0.0, 1.0) var vague_rate: float = 0.12
## VN-2 : auto-correction (menteurs et honnêtes au même taux).
@export_range(0.0, 1.0) var correction_rate: float = 0.08
## VN-3 : provenance ≠ origine dite en plus de l'origine.
@export_range(0.0, 1.0) var provenance_rate: float = 0.15
## VN-4 : réponse d'origine en Tessar (provenance seule), par origine.
@export var tessar_rates: Dictionary[StringName, float] = {}
## VN-5 : part des puces employeur dites par un alias.
@export_range(0.0, 1.0) var alias_rate: float = 0.5
## Hésitation (« Euh… ») : indépendante du mensonge.
@export_range(0.0, 1.0) var hesitation_rate: float = 0.25

@export_group("Écarts (AV-2)")
## Écart minimal d'une durée mensongère : max(`lie_gap_min` j ; `lie_gap_ratio` × durée).
@export var lie_gap_min: int = 4
@export_range(0.0, 1.0) var lie_gap_ratio: float = 0.40
## Écart minimal en version subtile (Garde, palier 2+).
@export var lie_gap_subtle: int = 2


## Nom canonique d'un employeur dit (alias résolu), vide s'il est vague ou inconnu.
func canonical_employer(said: String) -> String:
	var text: String = said.strip_edges()
	for vague: String in vague_employers:
		if text.to_lower() == vague.to_lower():
			return ""
	if employer_aliases.has(text):
		return employer_aliases[text]
	for alias: String in employer_aliases:
		if alias.to_lower() == text.to_lower():
			return employer_aliases[alias]
	for canonical: String in lore_employers:
		if canonical.to_lower() == text.to_lower():
			return canonical
	return text


## Alias reconnus d'un employeur canonique (ordre des données).
func aliases_of(canonical: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for alias: String in employer_aliases:
		if employer_aliases[alias] == canonical and alias != canonical:
			result.append(alias)
	return result


## Formules à intervalle qui contiennent `days` (VN-6), dans l'ordre des données.
func interval_keys_for(days: int) -> PackedStringArray:
	var result: PackedStringArray = []
	for i: int in duration_keys.size():
		var span: Vector2i = duration_ranges[i]
		if days >= span.x and days <= span.y:
			result.append(duration_keys[i])
	return result


## Intervalle (min, max) d'une formule de durée ; (n, n) pour une durée exacte ;
## (-1, -1) si la clé est vague ou inconnue.
func range_of(key: String, exact_days: int = -1) -> Vector2i:
	var i: int = duration_keys.find(key)
	if i >= 0:
		return duration_ranges[i]
	for n: int in exact_duration_keys:
		if exact_duration_keys[n] == key:
			return Vector2i(n, n)
	if key == exact_key and exact_days > 0:
		return Vector2i(exact_days, exact_days)
	return Vector2i(-1, -1)


## Vrai si la clé est une formule vague (VN-1).
func is_vague_key(key: String) -> bool:
	return vague_keys.has(key)


## Longueur estimée d'une réplique : cadre sans ses emplacements, plus le
## fragment rempli de chaque emplacement présent (`frame_tokens`).
func filled_length(frame_key: String, statements: Array[Statement]) -> int:
	var total: int = text_lengths.get(frame_key, 0)
	for token: String in frame_tokens.get(frame_key, PackedStringArray()):
		if token == Statement.PLACEHOLDER_STRUCK:
			var stay: Statement = Statement.find_in(statements, Statement.ID_STAY)
			if stay != null:
				total += fragment_length(stay.corrected_from, stay.corrected_args)
			continue
		var statement: Statement = Statement.find_in(statements, Statement.PLACEHOLDERS.get(token, &""))
		if statement != null:
			total += fragment_length(statement.phrase_key, statement.args)
	return total


## Longueur d'un fragment rempli (`%s`, `%d` ou `{…}` remplacés par les arguments).
func fragment_length(key: String, args: Array) -> int:
	if key.is_empty():
		return 0
	var total: int = text_lengths.get(key, 0)
	for arg: Variant in args:
		total += str(arg).length() - 2
	return total
