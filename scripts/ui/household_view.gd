## Affichage du foyer (Ilan, Noa, Dora — GDD §5.4, LORE §11) : nom, rôle,
## état (icône + couleur + texte, jamais la couleur seule — UI_FLOW §6).
## Fonctions statiques partagées par le briefing, la soirée et l'écran de fin.
## Acte II (ARCHITECTURE §7.2) : ESSOUFFLÉ·E (ambre, souffle), DANS LA SOUTE /
## PARTIE À TYCHO (absent·e : gris secondaire, porte), MIS·E EN ATTENTE
## (jaune Consortium, tampon DÉTENTION) — distinct de PERDU·E (muet, cadenas).
class_name HouseholdView
extends RefCounted


static func member_name(id: StringName) -> String:
	return UiText.t("hh_name_%s" % id, String(id).capitalize())


## Rôle d'un proche au jour `day` (par défaut le jour en cours) : la variante
## `hh_role_<id>_from_j<N>` la plus récente avec N ≤ jour l'emporte (Noa a
## 9 ans à partir du J4, QA-014), sinon `hh_role_<id>`.
static func member_role(id: StringName, day: int = -1) -> String:
	var current: int = day if day >= 0 else GameState.current_day
	for n: int in range(current, 0, -1):
		var key: String = "hh_role_%s_from_j%d" % [id, n]
		if UiText.has(key):
			return UiText.t(key)
	return UiText.t("hh_role_%s" % id, "")


## Note d'un proche selon son état (`hh_note_<id>_<état>`, sinon `hh_note_<id>`).
static func member_note(member: Household.Member) -> String:
	var state: String = member.state_key().trim_prefix("hh_state_")
	return UiText.t("hh_note_%s_%s" % [member.id, state], UiText.t("hh_note_%s" % member.id, ""))


static func state_text(member: Household.Member) -> String:
	return UiText.t(member.state_key(), member.state_key())


static func state_color(member: Household.Member) -> Color:
	if member.health == Household.Health.LOST:
		return DS.TEXT_MUTED
	if member.detained:
		return DS.ACCENT_YELLOW
	if member.away != &"":
		return Palette.TEXT_SECONDARY
	match member.health:
		Household.Health.GRAVELY_SICK, Household.Health.SICK:
			return Palette.STATE_RED
	if member.breathless or member.hungry or member.cold:
		return Palette.STATE_AMBER
	return DS.ACCENT_CYAN


static func state_icon(member: Household.Member) -> UiIcon.Kind:
	if member.health == Household.Health.LOST:
		return UiIcon.Kind.LOCK
	if member.detained:
		return UiIcon.Kind.DETAIN
	if member.away != &"":
		return UiIcon.Kind.AWAY
	match member.health:
		Household.Health.GRAVELY_SICK, Household.Health.SICK:
			return UiIcon.Kind.DENIED
	if member.breathless:
		return UiIcon.Kind.BREATH
	if member.hungry or member.cold:
		return UiIcon.Kind.WARNING
	return UiIcon.Kind.CHECK


## Carte d'un proche : nom, rôle, puce d'état, note optionnelle.
static func member_card(member: Household.Member, note: String = "", compact: bool = false) -> PanelContainer:
	var card: PanelContainer = ScreenBase.panel(&"ElevatedCard")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_2)
	card.add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	var names: VBoxContainer = ScreenBase.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(ScreenBase.label(member_name(member.id), &"BodyStrong"))
	if not compact:
		names.add_child(ScreenBase.wrapped(member_role(member.id), &"CaptionLabel"))
	var chip: PanelContainer = ScreenBase.chip(state_text(member), state_icon(member), state_color(member))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	if not note.is_empty():
		box.add_child(ScreenBase.wrapped(note, &"BodySmall"))
	return card
