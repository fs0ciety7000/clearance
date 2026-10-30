## Table des injecteurs disponibles par type d'anomalie : les 21 types de
## `AnomalyType.Kind` (M3 : 9 types ; M7 : `PURPOSE_MISMATCH`, implants,
## `RELATIVE_DOCUMENTS`, `BANNED_FACTION`, `INVALID_SEAL`, `MRZ_MISMATCH`,
## `WANTED_PERSON` — ce dernier n'est jamais tiré au hasard).
class_name InjectorRegistry
extends RefCounted


static func create_all() -> Dictionary[AnomalyType.Kind, AnomalyInjector]:
	var injectors: Array[AnomalyInjector] = [
		ExpiredDocumentInjector.new(),
		MissingDocumentInjector.new(),
		PortraitMismatchInjector.new(),
		IdMismatchInjector.new(),
		NameMismatchInjector.new(),
		OriginIdMismatchInjector.new(),
		WrongIssuerInjector.new(),
		BioscanUnfitInjector.new(),
		ImpostorLookalikeInjector.new(),
		PurposeMismatchInjector.new(),
		UndeclaredImplantInjector.new(),
		BannedImplantInjector.new(),
		RelativeDocumentsInjector.new(),
		BannedFactionInjector.new(),
		InvalidSealInjector.new(),
		MrzMismatchInjector.new(),
		WantedPersonInjector.new(),
		# Acte II (docs/ACT2.md B18).
		ContractMismatchInjector.new(),
		UnregisteredVesselInjector.new(),
		OutdatedFirmwareInjector.new(),
		RevokedIdInjector.new(),
		# Acte III (docs/ACT3.md B38).
		SponsorMismatchInjector.new(),
		ForgedSummonsInjector.new(),
		SuspendedContractInjector.new(),
		# M13 (docs/M13.md §1.5, §2.7 ; B67, B73).
		StatementMismatchInjector.new(),
		ContrabandInjector.new(),
		ConcealedImplantInjector.new(),
		ConcealedWeaponInjector.new(),
	]
	var result: Dictionary[AnomalyType.Kind, AnomalyInjector] = {}
	for injector: AnomalyInjector in injectors:
		result[injector.get_kind()] = injector
	return result


static func supported_kinds() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	kinds.assign(create_all().keys())
	return kinds
