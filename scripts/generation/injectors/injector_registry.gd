## Table des injecteurs disponibles (M3) par type d'anomalie.
##
## Types non encore injectables (pas de règle ou de document en M3) :
## `PURPOSE_MISMATCH` (R09), `RELATIVE_DOCUMENTS` (reporté, GDD §13),
## `UNDECLARED_IMPLANT`/`BANNED_IMPLANT`, `BANNED_FACTION`, `INVALID_SEAL`,
## `MRZ_MISMATCH`, `WANTED_PERSON`.
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
	]
	var result: Dictionary[AnomalyType.Kind, AnomalyInjector] = {}
	for injector: AnomalyInjector in injectors:
		result[injector.get_kind()] = injector
	return result


static func supported_kinds() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	kinds.assign(create_all().keys())
	return kinds
