## États du jour (machine à états du DayController, ARCHITECTURE §8).
##
## Vit dans `core/` pour que l'EventBus ne dépende pas de `DayController`.
## Classe-espace de noms : jamais instanciée.
class_name DayPhase
extends RefCounted

enum Kind { INTRO, WAITING_CASE, ARRIVING, INSPECTING, RESOLVING, DEPARTING, SUMMARY }
