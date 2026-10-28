## Réactions d'un passager (ARCHITECTURE §5.3, D-014).
##
## GDScript n'a pas d'enum global : le type exposé est `PassengerReaction.Kind`.
## `RELIEVED` n'a pas de clip au MVP (expression + voix seulement).
## Classe-espace de noms : jamais instanciée.
class_name PassengerReaction
extends RefCounted

enum Kind { NERVOUS, ANGRY, SHRUG, RELIEVED }
