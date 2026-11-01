#!/usr/bin/env bash
# M15 (lot A, D-214) — captures des écrans principaux en pseudo-localisation
# `en-XA` (+35 %, accents, bornes ¡ … !) pour repérer les débordements, en
# trois configurations : 1080p (1920×1080), Steam Deck (1280×800), Deck avec
# texte 150 %. Un texte resté sans accents est un texte brut (hors `UiText`) ;
# une borne `!` absente ou coupée signale une troncature.
#
# Usage : bash tools/qa_pseudo_captures.sh [dossier] [écran…]
#   dossier : sortie (défaut docs/mockups) → m15_pseudo_<écran>_<config>.png
#   écrans  : title options new load briefing shift rulebook summary evening pause demo_end
#             (défaut : ceux-là) ; lot U, en plus : difficulty garde_home dossier
#             dossier_people dossier_garde dossier_epilogues dossier_last rb_<onglet>
#             (rules stolen wanted origins implants symbols seals employers vessels revoked ledger
#             summons contraband) journal search contraband ask shop
#             end cinematic epilogue epilogue_end garde garde_end chapter2 chapter3
#             help tutorial ; `all` = tous.
#   --lang=en : vrai anglais au lieu de la pseudo-loc (captures m15_en_*), lot U.
#   --config=1080p|deck|deck_text150 : une seule configuration (répétable).
# Variables : GODOT (binaire), QA_WAIT (s, défaut 14), QA_JOBS (captures en
# parallèle, défaut 1 ; chacune avec son propre XDG_DATA_HOME jetable).
# Données utilisateur isolées (XDG_DATA_HOME jetable) : jamais le vrai user://.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/mockups"
MODE="--pseudo-loc --lang=en" # pseudo-loc appliquée à l'anglais (langue la plus longue)
PREFIX="m15_pseudo"
SCREENS=()
CONFIGS=()
BASE=(title options new load briefing shift rulebook summary evening pause demo_end)
EXTRA=(difficulty garde_home dossier dossier_people dossier_garde dossier_epilogues dossier_last
	rb_rules rb_stolen rb_wanted rb_implants rb_symbols rb_seals rb_employers rb_vessels rb_revoked rb_ledger
	rb_summons rb_contraband journal search contraband ask shop end cinematic
	epilogue epilogue_end garde garde_end chapter2 chapter3 help tutorial)
for arg in "$@"; do
	case "$arg" in
		--lang=*) MODE="$arg"; PREFIX="m15_${arg#--lang=}" ;;
		--config=*) CONFIGS+=("${arg#--config=}") ;;
		all) SCREENS+=("${BASE[@]}" "${EXTRA[@]}") ;;
		*/*) OUT="$arg" ;;
		*) SCREENS+=("$arg") ;;
	esac
done
[[ ${#SCREENS[@]} -gt 0 ]] || SCREENS=("${BASE[@]}")
[[ ${#CONFIGS[@]} -gt 0 ]] || CONFIGS=(1080p deck deck_text150)
WAIT="${QA_WAIT:-14}"
JOBS="${QA_JOBS:-1}"
mkdir -p "$OUT"
XDG_ROOT="$(mktemp -d)"
trap 'rm -rf "$XDG_ROOT"' EXIT
TITLE="res://scenes/main/main.tscn"

args_of() { # écran → arguments de scène
	case "$1" in
		title) echo "--qa-scene=$TITLE --demo-saves" ;;
		options) echo "--qa-scene=$TITLE --title=options-m14 --opt-row=music" ;;
		new) echo "--qa-scene=$TITLE --demo-saves --title=new" ;;
		load) echo "--qa-scene=$TITLE --demo-saves --title=load" ;;
		briefing) echo "--day=8 --screen=briefing --no-booth" ;;
		shift) echo "--day=8 --screen=shift --no-booth --start-case=2" ;;
		rulebook) echo "--day=12 --screen=shift --no-booth --rulebook-tab=origins" ;;
		summary) echo "--day=8 --screen=summary --no-booth" ;;
		evening) echo "--day=8 --screen=evening --no-booth --household=demo" ;;
		pause) echo "--day=8 --screen=options --no-booth" ;;
		demo_end) echo "--day=5 --screen=end --ending=demo_complete --demo --no-booth" ;;
		# Lot U (vrai anglais, écran par écran).
		difficulty) echo "--qa-scene=$TITLE --demo-saves --title=difficulty" ;;
		garde_home) echo "--qa-scene=$TITLE --demo-saves --demo-profile --title=garde" ;;
		dossier) echo "--qa-scene=$TITLE --demo-saves --demo-profile --title=dossier" ;;
		dossier_*) echo "--qa-scene=$TITLE --demo-saves --demo-profile --title=dossier-${1#dossier_}" ;;
		rb_ledger) echo "--day=24 --screen=shift --no-booth --start-case=4 --rulebook-tab=ledger" ;;
		rb_summons) echo "--day=24 --screen=shift --no-booth --rulebook-tab=summons" ;;
		rb_contraband) echo "--day=14 --screen=shift --no-booth --rulebook-tab=contraband" ;;
		rb_*) echo "--day=19 --screen=shift --no-booth --rulebook-tab=${1#rb_}" ;;
		journal) echo "--day=13 --seed=3 --screen=shift --no-booth --m13=journal" ;;
		search|contraband) echo "--day=8 --seed=3 --screen=shift --no-booth --m13=$1" ;;
		ask) echo "--day=13 --seed=3 --screen=shift --no-booth --ask" ;;
		shop) echo "--day=11 --screen=evening --no-booth --household=demo --shop=ag01" ;;
		end) echo "--day=30 --seed=3 --screen=end --ending=f4_glory --no-booth" ;; # fin simulée : sans cinématique
		cinematic) echo "--day=30 --screen=cinematic --cinematic=cin_f9 --plate=2 --plate-t=3 --plate-hold --no-booth" ;;
		epilogue) echo "--epilogue=f10_pont --no-booth" ;;
		epilogue_end) echo "--epilogue=f10_pont --skip-cases=7 --no-booth" ;;
		garde) echo "--garde=K2Q-9TX --skip-cases=3 --no-booth" ;;
		garde_end) echo "--garde=K2Q-9TX --skip-cases=9 --wrong-cases=3 --no-booth" ;;
		chapter2) echo "--day=10 --screen=chapter2 --no-booth --hold-card" ;;
		chapter3) echo "--day=20 --screen=chapter3 --no-booth --hold-card" ;;
		help) echo "--day=8 --m13-help --qa-close-briefing --no-booth" ;;
		tutorial) echo "--day=1 --tutorial --tutorial-step=2 --qa-close-briefing --no-booth" ;;
		*) return 1 ;;
	esac
}

wait_of() { # écran → délai de capture (s)
	case "$1" in
		epilogue_end) echo $((WAIT + 70)) ;; # cinématique d'épilogue jouée avant la conclusion
		garde_end) echo $((WAIT + 10)) ;;
		*) echo "$WAIT" ;;
	esac
}

capture() { # écran config
	local screen="$1" config="$2" scene_args size="1920x1080" set_arg="" png xdg
	scene_args="$(args_of "$screen")" || { echo "écran inconnu : $screen" >&2; return 2; }
	case "$config" in
		deck) size="1280x800" ;;
		deck_text150) size="1280x800"; set_arg="--qa-set=text_scale:1.5" ;;
	esac
	png="$OUT/${PREFIX}_${screen}_${config}.png"
	xdg="$(mktemp -d "$XDG_ROOT/x.XXXXXX")"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$xdg" xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --path "$ROOT" --rendering-driver opengl3 \
		--script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size="$size" \
		--qa-wait="$(wait_of "$screen")" --qa-out="$png" $MODE --reduce-motion $set_arg $scene_args >"$xdg/log.txt" 2>&1 || true
	if [[ -s "$png" ]]; then echo "  $png"; else echo "  ÉCHEC $screen/$config" >&2; tail -5 "$xdg/log.txt" >&2; fi
	rm -rf "$xdg"
}

for screen in "${SCREENS[@]}"; do
	args_of "$screen" >/dev/null || { echo "écran inconnu : $screen" >&2; exit 2; }
	for config in "${CONFIGS[@]}"; do
		while [[ "$(jobs -rp | wc -l)" -ge "$JOBS" ]]; do wait -n || true; done
		capture "$screen" "$config" &
	done
done
wait
