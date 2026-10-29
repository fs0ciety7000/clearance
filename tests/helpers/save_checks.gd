## Vérifications de sauvegarde partagées (M11, D-101) : une fin n'efface plus
## la partie, elle l'archive (`meta.status = ended`, `ending_id`) et retire
## l'emplacement de « Continuer » ; la fin est inscrite au profil global.
extends RefCounted


## Après une fin `ending` : plus de « Continuer » dans `dir` ; l'emplacement
## `slot`, s'il avait déjà une sauvegarde, est archivé avec cette fin ; une fin
## F1–F10 est dans `profile.json`.
static func assert_archived(t: GutTest, slot: int, dir: String, ending: StringName, context: String = "") -> void:
	t.assert_eq(SaveService.latest_slot(dir), SaveService.NO_SLOT, "%s : plus de « Continuer » après la fin" % context)
	if SaveService.has_save(slot, dir):
		var meta: Dictionary = SaveService.load_meta(slot, dir)
		t.assert_eq(str(meta.get("status", "")), SaveService.STATUS_ENDED, "%s : partie archivée (D-101)" % context)
		t.assert_eq(str(meta.get("ending_id", "")), String(ending), "%s : fin archivée" % context)
		t.assert_false(SaveService.load_current(slot, dir).is_empty(), "%s : état gardé" % context)
	if EndingService.ALL_ENDINGS.has(ending):
		t.assert_true(ProfileService.has_seen_ending(ProfileService.load_profile(dir), String(ending)),
				"%s : fin %s inscrite au profil" % [context, ending])
