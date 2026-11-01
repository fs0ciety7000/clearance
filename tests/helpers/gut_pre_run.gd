## Crochet GUT exécuté avant la suite (`.gutconfig.json` → `pre_run_script`).
##
## Isole les préférences (QA-006) : la suite lit et écrit un
## `settings.cfg` de test, repart des valeurs par défaut à chaque exécution et
## ne touche **jamais** le `user://settings.cfg` du joueur.
## M11 : idem pour les sauvegardes et le profil (`SaveService.use_root`) :
## `SaveService.DEFAULT_DIR` est redirigé vers un dossier de test vidé à chaque
## exécution — la vraie scène de jour n'écrit plus dans `user://saves`.
## M12 (lot A2) : dossier **propre au processus** (`user://test_runs/<PID>/`)
## — deux exécutions GUT simultanées ne se vident plus mutuellement leurs
## sauvegardes ; les dossiers des processus terminés sont supprimés au départ.
## M15 : langue fixée au français (valeur de session), quelle que soit la
## langue du système.
extends GutHookScript

const TEST_RUNS_ROOT: String = "user://test_runs"


## Dossier de test de ce processus.
static func run_dir() -> String:
	return TEST_RUNS_ROOT.path_join(str(OS.get_process_id()))


func run() -> void:
	_clear_stale_runs()
	var root: String = run_dir()
	_clear_dir(root)
	DirAccess.make_dir_recursive_absolute(root)
	Settings.use_storage(root.path_join("settings.cfg"))
	# M15 : la suite est écrite contre les textes français ; la langue du
	# système (défaut du réglage `language`) ne doit pas la faire basculer.
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	SaveService.use_root(root.path_join("saves"))


## Supprime les dossiers d'exécutions dont le processus n'existe plus.
static func _clear_stale_runs() -> void:
	var dir: DirAccess = DirAccess.open(TEST_RUNS_ROOT)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub.is_valid_int() and int(sub) != OS.get_process_id() and OS.is_process_running(int(sub)):
			continue
		_clear_dir(TEST_RUNS_ROOT.path_join(sub))


static func _clear_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_clear_dir(path.path_join(sub))
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
