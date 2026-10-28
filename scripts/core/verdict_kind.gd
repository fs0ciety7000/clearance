## Types de verdict (ARCHITECTURE §5.3, GDD §4.5).
##
## `DETAIN` (« mise en attente ») est prévu dès maintenant mais n'est
## disponible en jeu qu'à partir du J7 (post-MVP).
## Classe-espace de noms : jamais instanciée.
class_name VerdictKind
extends RefCounted

enum Kind { APPROVE, DENY, DETAIN }
