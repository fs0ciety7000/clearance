## Horloge du shift (ARCHITECTURE §7, §8 bis.7) — service de jour.
##
## Décompte `DayDef.duration_sec` en temps réel tant qu'elle tourne (elle
## continue pendant la marche du passager, D-019). Émet `day_clock_ticked`
## à chaque avance et `day_time_expired` une seule fois.
## Accessibilité « Temps » (`Settings.clock_slow_accessibility`) : ×0,5.
## Testable sans attente : `set_process(false)` puis `advance(delta)`.
class_name DayClock
extends Node

const SLOW_FACTOR: float = 0.5
## Heure du shift (UI_FLOW §1) : 10:00 → 18:00, en minutes depuis minuit
## (constantes pures dans `DayDef`, lues aussi par les simulateurs).
const SHIFT_START_MIN: int = DayDef.SHIFT_START_MIN
const SHIFT_LENGTH_MIN: int = DayDef.SHIFT_LENGTH_MIN

var duration_sec: float = 0.0
var remaining_sec: float = 0.0
var running: bool = false
var expired: bool = false


## Réarme l'horloge (arrêtée) pour une durée de shift.
func setup(p_duration_sec: float) -> void:
	duration_sec = maxf(p_duration_sec, 0.0)
	remaining_sec = duration_sec
	running = false
	expired = false


func start() -> void:
	if not expired:
		running = true


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	advance(delta)


## Avance l'horloge de `delta` secondes réelles (sans effet si arrêtée).
func advance(delta: float) -> void:
	if not running or expired:
		return
	remaining_sec = maxf(remaining_sec - delta * _time_scale(), 0.0)
	EventBus.day_clock_ticked.emit(remaining_sec)
	if remaining_sec <= 0.0:
		expired = true
		running = false
		EventBus.day_time_expired.emit()


## Heure du shift (minutes depuis minuit) : 10:00 au début, 18:00 à la fin.
func current_minute() -> int:
	return minute_at(duration_sec, remaining_sec)


## Heure du shift pour une durée et un temps restant donnés.
static func minute_at(p_duration_sec: float, p_remaining_sec: float) -> int:
	return DayDef.minute_at(p_duration_sec, p_remaining_sec)


func _time_scale() -> float:
	return SLOW_FACTOR if Settings.clock_slow_accessibility else 1.0
