## Indicateur **discret** de l'état en ligne (M16, UI_FLOW §8.10) — écran
## titre, en bas à gauche : icône + texte (jamais la couleur seule, DS §2.5),
## style plat, sans halo. Masqué sans compte (aucune mention d'un service
## que le joueur n'a pas choisi), sauf « SESSION EXPIRÉE ».
## États : EN LIGNE · nom affiché (vert, coche) ; SYNCHRONISATION… (cyan,
## losange) ; CONNEXION… ; HORS LIGNE (ambre, avertissement : tout reste
## local) ; COMPTE : ERREUR (rouge) ; DEUX VERSIONS · VOIR CHARGER (ambre) dès
## qu'un emplacement porte une copie de conflit.
## Se recompose à `state_changed`, `sync_finished`, `account_changed`,
## `save_slots_changed` et au changement de langue.
class_name OnlineStatusBadge
extends HBoxContainer

## Dossier des sauvegardes (copies de conflit ; tests).
var save_dir: String = SaveService.DEFAULT_DIR
var icon: UiIcon = null
var text_label: Label = null


func _ready() -> void:
	name = "OnlineStatus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", DS.SPACE_2)
	icon = UiIcon.make(UiIcon.Kind.CHECK, Palette.STATE_GREEN, DS.ICON_S)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	text_label = ScreenBase.label("", &"CaptionLabel", Palette.TEXT_SECONDARY)
	text_label.name = "Text"
	add_child(text_label)
	OnlineService.state_changed.connect(func(_s: OnlineClient.State) -> void: refresh())
	OnlineService.sync_finished.connect(func(_r: Dictionary) -> void: refresh())
	OnlineService.account_changed.connect(refresh)
	EventBus.save_slots_changed.connect(refresh)
	EventBus.settings_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key == Settings.KEY_LANGUAGE:
			refresh())
	refresh()


## Recompose l'indicateur depuis `OnlineService`.
func refresh() -> void:
	if text_label == null:
		return
	var info: Dictionary = describe(OnlineService.state(), OnlineService.last_error(), OnlineService.is_syncing(),
			not OnlineService.conflict_slots(save_dir).is_empty(), OnlineService.has_account(), OnlineService.display_name())
	visible = info["visible"]
	text_label.text = info["text"]
	text_label.add_theme_color_override(&"font_color", info["color"])
	icon.kind = info["icon"]
	icon.color = info["color"]


## Texte, icône, couleur et visibilité d'un état (pur, testé).
static func describe(state: OnlineClient.State, error: String, syncing: bool, conflict: bool, account: bool,
		name_text: String) -> Dictionary:
	var out: Dictionary = {"visible": account, "text": "", "icon": UiIcon.Kind.CHECK, "color": Palette.STATE_GREEN}
	if not account:
		if error == OnlineClient.ERR_SESSION:
			out["visible"] = true
			return _with(out, UiText.t("online_state_expired", "SESSION EXPIRÉE · OPTIONS › COMPTE"), UiIcon.Kind.WARNING,
					Palette.STATE_AMBER)
		return out
	if conflict:
		return _with(out, UiText.t("online_state_conflict", "DEUX VERSIONS D'UNE PARTIE · VOIR CHARGER"), UiIcon.Kind.WARNING,
				Palette.STATE_AMBER)
	if syncing:
		return _with(out, UiText.t("online_state_syncing", "SYNCHRONISATION…"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
	match state:
		OnlineClient.State.CONNECTING:
			return _with(out, UiText.t("online_state_connecting", "CONNEXION…"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
		OnlineClient.State.OFFLINE:
			return _with(out, UiText.t("online_state_offline", "HORS LIGNE · SAUVEGARDES LOCALES"), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
		OnlineClient.State.ERROR:
			return _with(out, UiText.t("online_state_error", "COMPTE : ERREUR · OPTIONS › COMPTE"), UiIcon.Kind.DENIED, Palette.STATE_RED)
	return _with(out, UiText.tf("online_state_connected", [name_text], "EN LIGNE · %s"), UiIcon.Kind.CHECK, Palette.STATE_GREEN)


static func _with(out: Dictionary, text: String, kind: UiIcon.Kind, color: Color) -> Dictionary:
	out["text"] = text
	out["icon"] = kind
	out["color"] = color
	return out
