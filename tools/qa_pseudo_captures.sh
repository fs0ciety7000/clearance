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
#             (défaut : tous)
#   --lang=en : vrai anglais au lieu de la pseudo-loc (captures m15_en_*), lot U.
# Variables : GODOT (binaire), QA_WAIT (s, défaut 14).
# Données utilisateur isolées (XDG_DATA_HOME jetable) : jamais le vrai user://.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/mockups"
MODE="--pseudo-loc --lang=en" # pseudo-loc appliquée à l'anglais (langue la plus longue)
PREFIX="m15_pseudo"
SCREENS=()
for arg in "$@"; do
	case "$arg" in
		--lang=*) MODE="$arg"; PREFIX="m15_${arg#--lang=}" ;;
		*/*) OUT="$arg" ;;
		*) SCREENS+=("$arg") ;;
	esac
done
[[ ${#SCREENS[@]} -gt 0 ]] || SCREENS=(title options new load briefing shift rulebook summary evening pause demo_end)
WAIT="${QA_WAIT:-14}"
mkdir -p "$OUT"
XDG="$(mktemp -d)"
trap 'rm -rf "$XDG"' EXIT
export XDG_DATA_HOME="$XDG"
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
		*) return 1 ;;
	esac
}

for screen in "${SCREENS[@]}"; do
	scene_args="$(args_of "$screen")" || { echo "écran inconnu : $screen" >&2; exit 2; }
	for config in 1080p deck deck_text150; do
		size="1920x1080"; set_arg=""
		case "$config" in
			deck) size="1280x800" ;;
			deck_text150) size="1280x800"; set_arg="--qa-set=text_scale:1.5" ;;
		esac
		png="$OUT/${PREFIX}_${screen}_${config}.png"
		# shellcheck disable=SC2086
		xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --path "$ROOT" --rendering-driver opengl3 \
			--script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size="$size" \
			--qa-wait="$WAIT" --qa-out="$png" $MODE --reduce-motion $set_arg $scene_args >"$XDG/log.txt" 2>&1 || true
		if [[ -s "$png" ]]; then echo "  $png"; else echo "  ÉCHEC $screen/$config" >&2; tail -5 "$XDG/log.txt" >&2; fi
	done
done
