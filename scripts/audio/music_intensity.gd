## Intensité musicale du shift (M14 §2.5, D-177 ; ARCHITECTURE §12 ter.2) —
## objet **pur** (`RefCounted`, aucun nœud, aucun signal), lu et nourri par
## l'`AudioDirector` qui le recalcule à 4 Hz.
##
## Entrées **publiques uniquement** (ce que le joueur voit) : file restante
## (`queue_progressed`), chrono (`day_clock_ticked`), discordances **constatées**
## (`discrepancy_checked`), quota (`quota_changed`), événement de station
## (`StationEventDef.music_weight`), tension et plancher du jour
## (`DayDef.music_tension`, `music_floor`), Garde (palier, erreurs). Aucune ne
## vient de `CaseKey` ni de la vérité d'un cas : la musique ne trahit jamais
## une anomalie non trouvée (analyse de dépendances : `test_music_intensity`).
##
## `I = clamp(0,25·Q + 0,35·T + 0,15·D + 0,15·K + 0,20·E + τ, 0, 1)` ; lissage
## exponentiel (montée τ = 4 s, descente 8 s) ; quantification avec hystérésis
## (`MusicSetDef.level_for`) ; cas particuliers dans l'ordre de M14 §2.5. La
## vitesse (+1 niveau / 2 mesures, −1 / 4 ; +1 / mesure au chrono critique,
## D-211) est tenue par `MusicDirector.next_level` (à la mesure).
class_name MusicIntensity
extends RefCounted

const W_QUEUE: float = 0.25
const W_CLOCK: float = 0.35
const W_DISCREPANCY: float = 0.15
const W_QUOTA: float = 0.15
const W_EVENT: float = 0.20
## Bonus de tension narrative par `DayDef.music_tension` (0 → 3).
const TENSION_BONUS: Array[float] = [0.0, 0.05, 0.10, 0.20]
## Lissage (s) : montée, descente.
const RISE_TAU: float = 4.0
const FALL_TAU: float = 8.0
## Recalcul (Hz) par l'`AudioDirector`.
const UPDATE_HZ: float = 4.0
## Seuils par défaut (sans `MusicSetDef`) et hystérésis.
## (Même précision que `MusicSetDef.thresholds`, un `PackedFloat32Array`.)
const DEFAULT_THRESHOLDS: PackedFloat32Array = [0.15, 0.35, 0.60, 0.80]
const HYSTERESIS: float = 0.05
## Chrono critique (s) : niveau ≥ N4 et mélodie coupée (tic de l'UI).
const CRITICAL_SEC: float = 15.0
## Garde : I = 0,30 + 0,12·palier + 0,10·erreurs du palier.
const GARDE_BASE: float = 0.30
const GARDE_PER_TIER: float = 0.12
const GARDE_PER_ERROR: float = 0.10
## Les discordances retombent à 0 deux mesures après `case_resolved`.
const DISCREPANCY_HOLD_BARS: int = 2
## Annonce `drop` : L0 seule, −6 dB, 4 mesures ; `swell` : +1 niveau 4 mesures.
const ACTION_BARS: int = 4
const DROP_DB: float = -6.0
const LEVEL_MAX: int = 4
const STORY_MAX_LEVEL: int = 2
const STABLE_LEVEL: int = 1

# --- Entrées (publiques) ------------------------------------------------------
## Passagers restants (file + vitre) ; −1 = inconnu ou Garde (P1 ignorée).
var queue_remaining: int = -1
## Temps écoulé / durée du shift (0 → 1) ; `timed` faux (Récit, J31) : P2 = 0.
var elapsed_ratio: float = 0.0
var timed: bool = true
## Secondes restantes au chrono (≤ `CRITICAL_SEC` : cas particulier).
var remaining_sec: float = INF
## Discordances confirmées du cas en cours.
var discrepancies: int = 0
## Quota d'air (P4) ; `quota_max` ≤ 0 : pas de quota.
var quota_used: int = 0
var quota_max: int = 0
## Poids de l'événement de station actif (P5, 0 → 1).
var event_weight: float = 0.0
## Tension et plancher du jour (P6, P7 ; −1 = aucun plancher).
var tension: int = 0
var floor_level: int = -1
## Plafond Récit / J31 (N2).
var capped: bool = false
## « Musique : Stable » : N1 figé pendant le shift (le plancher du jour s'il
## est plus haut, D-211).
var stable: bool = false
## Coupure EV-05, grève du J20 (`lights_out`), annonce `silence`.
var power_down: bool = false
## Mode Inspection avec `music_inspection_reduce`.
var inspection_reduce: bool = false
## Garde de nuit : palier et erreurs du palier.
var garde: bool = false
var garde_tier: int = 0
var garde_errors: int = 0
## Annonce de jeu en cours (`HallAnnouncementDef.music_action`) et mesures restantes.
var action: StringName = &""
var action_bars: int = 0

# --- État ---------------------------------------------------------------------
## Valeur lissée (0 → 1) et niveau quantifié courant.
var smoothed: float = 0.0
var level: int = 0


## P1 : `Q = clamp((restants − 2) / 6, 0, 1)`.
static func queue_term(remaining: int) -> float:
	if remaining < 0:
		return 0.0
	return clampf((remaining - 2) / 6.0, 0.0, 1.0)


## P2 : `T = smoothstep(0,5 ; 1,0 ; écoulé / durée)`.
static func clock_term(ratio: float) -> float:
	return smoothstep(0.5, 1.0, clampf(ratio, 0.0, 1.0))


## P3 : `D = min(n, 2) / 2`.
static func discrepancy_term(count: int) -> float:
	return clampf(mini(maxi(count, 0), 2) / 2.0, 0.0, 1.0)


## P4 : `K = smoothstep(0,6 ; 1,0 ; utilisé / max)` si quota, sinon 0.
static func quota_term(used: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return smoothstep(0.6, 1.0, clampf(float(used) / maximum, 0.0, 1.0))


## P6 : bonus de tension (0 → 0,20).
static func tension_term(value: int) -> float:
	return TENSION_BONUS[clampi(value, 0, TENSION_BONUS.size() - 1)]


## Formule de M14 §2.5 (pure).
static func formula(q: float, t: float, d: float, k: float, e: float, tau: float) -> float:
	return clampf(W_QUEUE * q + W_CLOCK * t + W_DISCREPANCY * d + W_QUOTA * k + W_EVENT * clampf(e, 0.0, 1.0) + tau,
			0.0, 1.0)


## Garde : `0,30 + 0,12·palier + 0,10·erreurs`, borné à [0, 1].
static func garde_value(tier: int, errors: int) -> float:
	return clampf(GARDE_BASE + GARDE_PER_TIER * maxi(tier, 0) + GARDE_PER_ERROR * maxi(errors, 0), 0.0, 1.0)


## Valeur cible instantanée (avant lissage), fonction pure des entrées.
func compute() -> float:
	if garde:
		return garde_value(garde_tier, garde_errors)
	var t: float = clock_term(elapsed_ratio) if timed else 0.0
	return formula(queue_term(queue_remaining), t, discrepancy_term(discrepancies), quota_term(quota_used, quota_max),
			event_weight, tension_term(tension))


## Lissage exponentiel vers `compute()` sur `dt` secondes (montée 4 s, descente 8 s).
func step(dt: float) -> float:
	var target: float = compute()
	var tau: float = RISE_TAU if target > smoothed else FALL_TAU
	smoothed += (target - smoothed) * (1.0 - exp(-maxf(dt, 0.0) / tau))
	return smoothed


## Niveau quantifié d'une valeur avec hystérésis autour de `current` (même
## règle que `MusicSetDef.level_for`, seuils par défaut si `set_def` est nul).
static func quantize(value: float, current: int, set_def: MusicSetDef = null) -> int:
	if set_def != null:
		return set_def.level_for(value, current)
	var raw: int = 0
	for i: int in DEFAULT_THRESHOLDS.size():
		if value >= DEFAULT_THRESHOLDS[i]:
			raw = i + 1
	var lvl: int = clampi(current, 0, LEVEL_MAX)
	if raw > lvl:
		while lvl < raw and value >= DEFAULT_THRESHOLDS[lvl] + HYSTERESIS:
			lvl += 1
	elif raw < lvl:
		while lvl > raw and value < DEFAULT_THRESHOLDS[lvl - 1] - HYSTERESIS:
			lvl -= 1
	return lvl


## Décision complète (niveau visé et masques) sur la valeur lissée courante :
## `{level, mask (MusicSetDef.MASK_*), extra_db, fast_up}`. Cas particuliers
## dans l'ordre de M14 §2.5 : power down, chrono critique, Inspection, Stable,
## Récit / J31, annonce, plancher. D-211 : le plancher du jour vaut aussi en
## Stable et pendant un `drop` (masque et gain seulement, niveau conservé) ;
## chrono critique : N4 visé avec montée d'un niveau par mesure (`fast_up`),
## sauf en Stable (aucune montée liée au chrono, seule L3 coupée).
func decide(set_def: MusicSetDef = null) -> Dictionary:
	level = quantize(smoothed, level, set_def)
	var wanted: int = level
	var mask: int = 0
	var extra_db: float = 0.0
	var fast_up: bool = false
	var is_stable: bool = stable and not garde
	if floor_level >= 0:
		wanted = maxi(wanted, floor_level)
	if action == HallAnnouncementDef.MUSIC_SWELL and action_bars > 0:
		wanted = mini(wanted + 1, LEVEL_MAX)
	if is_stable:
		wanted = maxi(STABLE_LEVEL, floor_level)
	if capped:
		wanted = mini(wanted, STORY_MAX_LEVEL)
	if inspection_reduce:
		mask |= MusicSetDef.MASK_NO_MELODY
	if timed and remaining_sec <= CRITICAL_SEC and remaining_sec > 0.0 and not capped:
		mask |= MusicSetDef.MASK_NO_MELODY
		if not is_stable:
			wanted = LEVEL_MAX
			fast_up = true
	if action == HallAnnouncementDef.MUSIC_DROP and action_bars > 0:
		# L0 seule −6 dB ; niveau conservé (jamais sous le plancher, QA-077).
		mask |= MusicSetDef.MASK_POWER_DOWN
		extra_db += DROP_DB
	if power_down or action == HallAnnouncementDef.MUSIC_SILENCE:
		# Power down : L0 seule, −6 dB (le passe-bas 400 Hz est posé par l'AudioDirector).
		wanted = 0
		mask |= MusicSetDef.MASK_POWER_DOWN
		extra_db = DROP_DB
	if set_def != null:
		wanted = mini(wanted, set_def.max_level)
	return {"level": clampi(wanted, 0, LEVEL_MAX), "mask": mask, "extra_db": extra_db, "fast_up": fast_up}


## Une mesure écoulée : décompte des annonces `drop` / `swell`.
func on_bar() -> void:
	if action_bars > 0:
		action_bars -= 1
		if action_bars == 0 and action != HallAnnouncementDef.MUSIC_SILENCE:
			action = &""


## Annonce de jeu avec effet musical (`silence` dure jusqu'à la fin du shift).
func apply_action(value: StringName) -> void:
	if value == &"" or not HallAnnouncementDef.MUSIC_ACTIONS.has(value):
		return
	action = value
	action_bars = ACTION_BARS
