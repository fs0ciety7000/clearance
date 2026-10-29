## Barrière de mixage audio (QA-030, docs/ARCHITECTURE.md §13) — autoload sans
## état ni signal.
##
## Contournement d'une course de Godot 4.7.2 : quand le volume d'une lecture
## change (`AudioStreamPlayer3D` à chaque mixage tant qu'il joue, fondus de
## `volume_db`), `AudioServer` remplace ses `bus_details` et met l'ancien bloc
## au « cimetière » ; il le libère sur le thread principal deux
## `AudioServer.update()` plus tard (fin d'image), en supposant qu'aucun mixage
## ne dure plus d'une image. Le thread de mixage, lui, lit le pointeur puis
## **copie** le bloc (`AudioServer::_mix_step`, copie de `StringName`) : s'il
## est retardé plus d'une image entre les deux (processeur chargé, images très
## courtes en headless ou juste après un rechargement de scène), il copie de la
## mémoire libérée → `signal 11` sur le thread audio (d'où l'erreur
## « /root: The caller thread can't call … propagate_notification() » émise par
## le gestionnaire de plantage hors du thread principal).
##
## Prendre et rendre le verrou du pilote audio une fois par image (`_process`,
## toujours avant `AudioServer.update()` dans `Main::iteration`) attend la fin du
## mixage en cours : tout mixage qui a pu lire un ancien bloc est terminé avant
## que ce bloc ne soit libéré. Coût : au plus un pas de mixage d'attente.
##
## `quit_after_silence()` (QA-025) : quitter en plein son laisse des lectures
## dans la liste de l'`AudioServer` (retirées seulement par ses `update()`
## suivants, qui n'ont plus lieu) — « ObjectDB instances leaked » et
## « resources still in use » à la sortie. On arrête tous les lecteurs, on
## laisse passer quelques images de mixage, puis on quitte.
## QA-039 : arrêter les lecteurs ne suffisait pas — la scène restait vivante
## pendant ces images et pouvait relancer un son (musique de l'écran de fin
## posée juste après son apparition, pas, annonces, barks du shift) : lecture
## active à la sortie. La scène courante est donc d'abord **déchargée**
## (`AudioDirector._exit_tree` : plus aucun son, lecteurs vidés, caches
## d'`AudioCueBank` et de barks libérés), les lecteurs restants arrêtés, puis
## une seconde passe juste avant `quit()`.
extends Node

## Images et délai réel laissés au mixage pour retirer les lectures arrêtées.
const QUIT_FRAMES: int = 8
const QUIT_DELAY_SEC: float = 0.25

## Vrai dès le premier appel de `quit_after_silence()` (appels suivants ignorés).
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	sync_with_mixer()


## Arrête tous les lecteurs audio de l'arbre, attend que l'`AudioServer` les
## ait retirés, puis quitte avec `exit_code`.
func quit_after_silence(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		tree.unload_current_scene()
	_stop_players(tree.root)
	for i: int in QUIT_FRAMES:
		await tree.process_frame
	await tree.create_timer(QUIT_DELAY_SEC, true, false, true).timeout
	# Un son relancé pendant l'attente (nœud hors scène) : arrêté et retiré.
	_stop_players(tree.root)
	for i: int in QUIT_FRAMES:
		await tree.process_frame
	tree.quit(exit_code)


static func _stop_players(node: Node) -> void:
	for child: Node in node.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
		elif child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
		elif child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).stop()
		_stop_players(child)


## Attend la fin du pas de mixage en cours (s'il y en a un).
static func sync_with_mixer() -> void:
	AudioServer.lock()
	AudioServer.unlock()
