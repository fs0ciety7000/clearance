## Palier de difficulté de la Garde de nuit (M12 §2.5 ; ARCHITECTURE §11.5) :
## valeurs recopiées dans le `DayDef` de shift au premier passager du palier.
class_name GardeTierDef
extends Resource

## Numéro du palier (0 « Prise de garde » … 4 « Rotation »).
@export var index: int = 0
@export var name_key: String = ""
## Premier passager (1-based) du palier.
@export var from_passenger: int = 1
@export var anomaly_count_weights: PackedFloat32Array = PackedFloat32Array([0.45, 0.45, 0.10, 0.0])
@export_range(0.0, 1.0) var subtle_rate: float = 0.0
@export_range(0.0, 1.0) var legit_noise_rate: float = 0.2
@export_range(0.0, 1.0) var visor_down_rate: float = 0.1
## Palier 4 : retraits et rétablissements (mécanique M1) quand le pool est épuisé.
@export var rotation: bool = false
