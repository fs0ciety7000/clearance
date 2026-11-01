## M15 (lot A, D-215) — **démo** jours 1 à 5 : garde-fous purs, sans scène.
##
## - Active dans un export portant la fonctionnalité personnalisée `demo`
##   (préréglages « … Demo » d'`export_presets.cfg`), ou en debug avec
##   l'argument `--demo` (captures, smoke) ; `force` pour les tests.
## - Campagne bornée au **J5** (`last_day`) : la soirée du J5 validée,
##   `Campaign.close_evening` rend `Campaign.ENDING_DEMO_COMPLETE` ;
##   `DayScene` ouvre alors l'écran « Fin de la démo » (`DemoEndScreen`).
## - Sauvegardes **et** profil séparés : `SaveService.DEFAULT_DIR` est résolu
##   en `user://demo/saves` (`SaveService.resolve_dir`) ; le profil
##   (`profile.json`) vit dans ce même dossier. Les préférences
##   (`user://settings.cfg` : langue, accessibilité) restent partagées avec le
##   jeu complet. `SaveService.use_root` (tests) garde la priorité.
## - Garde de nuit et Dossier de l'agent : **désactivés** au titre (mention
##   « Dans le jeu complet. ») — le plus simple et le plus sûr (la Garde tire
##   ses règles de tous les jours, le Dossier lirait les fins du jeu complet).
## - Contenu au-delà du J5 : présent dans le paquet mais **verrouillé** (les
##   `DayDef` J6–J30 sont référencés par le catalogue, les sauvegardes et les
##   cinématiques : les retirer n'est pas simple, D-215).
class_name DemoMode
extends RefCounted

## Fonctionnalité d'export de la démo (`custom_features="demo"`).
const FEATURE: String = "demo"
## Dernier jour jouable de la démo.
const LAST_DAY: int = 5
## Dossier des données de la démo (sauvegardes + profil).
const ROOT_DIR: String = "user://demo"
const SAVES_DIR: String = "user://demo/saves"
## Page du jeu complet (site du studio, lot S).
const FULL_GAME_URL: String = "https://clearance.cardormedia.com/"

## Tests : -1 suit la plateforme, 0 force le jeu complet, 1 force la démo.
static var force: int = -1


## Vrai dans la démo.
static func is_demo() -> bool:
	if force >= 0:
		return force == 1
	if OS.has_feature(FEATURE):
		return true
	return OS.is_debug_build() and OS.get_cmdline_user_args().has("--demo")


## Dernier jour jouable : `data_last_day` dans le jeu complet, au plus J5 en démo.
static func last_day(data_last_day: int) -> int:
	return mini(data_last_day, LAST_DAY) if is_demo() else data_last_day


## Vrai si le jour `day` est hors de la démo (au-delà du J5).
static func is_locked_day(day: int) -> bool:
	return is_demo() and day > LAST_DAY
