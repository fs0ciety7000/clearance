## Crochet GUT exécuté avant la suite (`.gutconfig.json` → `pre_run_script`).
##
## Isole les préférences (QA-006) : la suite lit et écrit
## `user://test_settings/settings.cfg`, repart des valeurs par défaut à chaque
## exécution et ne touche **jamais** le `user://settings.cfg` du joueur.
## M11 : idem pour les sauvegardes et le profil (`SaveService.use_root`) :
## `SaveService.DEFAULT_DIR` est redirigé vers `user://test_default_saves`, vidé à
## chaque exécution — la vraie scène de jour n'écrit plus dans `user://saves`.
extends GutHookScript

const TEST_SETTINGS_PATH: String = "user://test_settings/settings.cfg"
const TEST_SAVES_DIR: String = "user://test_default_saves"


func run() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	Settings.use_storage(TEST_SETTINGS_PATH)
	_clear_dir(TEST_SAVES_DIR)
	SaveService.use_root(TEST_SAVES_DIR)


static func _clear_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_clear_dir(path.path_join(sub))
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
