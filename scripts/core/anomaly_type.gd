## Types d'anomalies injectables (ARCHITECTURE §5.3, GDD §6).
##
## Les valeurs sont **explicites et figées** : elles sont sérialisées en entier
## dans les `.tres` (`DayDef.anomaly_weights`, `ScriptedCaseDef.forced_anomalies`).
## Règle : on ajoute à la fin, on ne renumérote jamais.
## Les types marqués 🟡 dans le GDD (acceptés par l'Orchestrateur) sont inclus.
## Classe-espace de noms : jamais instanciée.
class_name AnomalyType
extends RefCounted

enum Kind {
	EXPIRED_DOCUMENT = 0,
	MISSING_DOCUMENT = 1,
	PORTRAIT_MISMATCH = 2,
	ID_MISMATCH = 3,
	NAME_MISMATCH = 4,
	ORIGIN_ID_MISMATCH = 5, # 🟡 GDD
	PURPOSE_MISMATCH = 6,
	WRONG_ISSUER = 7,
	BIOSCAN_UNFIT = 8, # 🟡 GDD
	UNDECLARED_IMPLANT = 9, # 🟡 GDD
	BANNED_IMPLANT = 10, # 🟡 GDD
	IMPOSTOR_LOOKALIKE = 11,
	RELATIVE_DOCUMENTS = 12,
	BANNED_FACTION = 13,
	INVALID_SEAL = 14,
	MRZ_MISMATCH = 15, # 🟡 GDD
	WANTED_PERSON = 16, # 🟡 GDD
	# Acte II (docs/ACT2.md §2.2, B18) — ajoutés en fin d'enum (D-033).
	CONTRACT_MISMATCH = 17,
	UNREGISTERED_VESSEL = 18,
	OUTDATED_FIRMWARE = 19,
	REVOKED_ID = 20,
	# Acte III (docs/ACT3.md §2.2, B38) — ajoutés en fin d'enum (D-033).
	SPONSOR_MISMATCH = 21,
	FORGED_SUMMONS = 22,
	SUSPENDED_CONTRACT = 23,
	# M13 (docs/M13.md §1.5, §2.7 ; D-149) — ajoutés en fin d'enum (D-033).
	## Déclaration orale contradictoire (variantes AV-1 → AV-5 en paramètre `topic`).
	STATEMENT_MISMATCH = 24,
	## Objet interdit CB-01 → CB-05 dans une zone de fouille (R45).
	CONTRABAND = 25,
	## Implant de localisation dissimulée non déclaré (R15, trouvé à la fouille).
	CONCEALED_IMPLANT = 26,
	## Arme CB-06 / CB-07 (R46, DÉTENTION).
	CONCEALED_WEAPON = 27,
}


## Nom lisible d'un type (« EXPIRED_DOCUMENT »), pour les messages et les tests.
static func name_of(kind: Kind) -> String:
	var key: Variant = Kind.find_key(kind)
	return str(key) if key != null else "UNKNOWN(%d)" % kind


## Vrai si l'entier correspond à une valeur de l'enum.
static func is_valid(value: int) -> bool:
	return Kind.values().has(value)
