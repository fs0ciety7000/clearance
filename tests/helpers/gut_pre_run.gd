## Crochet GUT exécuté avant la suite (`.gutconfig.json` → `pre_run_script`).
##
## Isole les préférences (QA-006) : la suite lit et écrit
## `user://test_settings/settings.cfg`, repart des valeurs par défaut à chaque
## exécution et ne touche **jamais** le `user://settings.cfg` du joueur.
extends GutHookScript

const TEST_SETTINGS_PATH: String = "user://test_settings/settings.cfg"


func run() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	Settings.use_storage(TEST_SETTINGS_PATH)
