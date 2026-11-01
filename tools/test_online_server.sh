#!/usr/bin/env bash
# CLEARANCE M16 — tests du serveur PocketBase (docs/ONLINE.md).
#
#   tools/test_online_server.sh [--port 8097] [--keep]
#
# Lance un PocketBase local neuf (tools/online_dev_server.sh, mode dev OTP, données
# dans un dossier temporaire) DANS cette même commande, exécute
# server/tests/api_test.mjs (Node ≥ 18) puis arrête le serveur. Code de sortie 0 si
# tout passe. --keep : garde le dossier de données (chemin affiché).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=8097
KEEP=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--port) PORT="$2"; shift 2 ;;
		--keep) KEEP=1; shift ;;
		-h|--help) sed -n '2,10p' "$0"; exit 0 ;;
		*) echo "Option inconnue : $1" >&2; exit 2 ;;
	esac
done

command -v node >/dev/null || { echo "node introuvable (Node ≥ 18 requis)" >&2; exit 1; }
if curl -s -o /dev/null "http://127.0.0.1:$PORT/api/health"; then
	echo "Le port $PORT est déjà occupé" >&2
	exit 1
fi

DATA="$(mktemp -d "${TMPDIR:-/tmp}/clearance_pb_test.XXXXXX")"
LOG="$DATA.log"
SERVER_PID=""
cleanup() {
	if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
		kill "$SERVER_PID" 2>/dev/null || true
		wait "$SERVER_PID" 2>/dev/null || true
	fi
	if [[ "$KEEP" == 1 ]]; then
		echo "Données conservées : $DATA (journal : $LOG)"
	else
		rm -rf "$DATA" "$LOG"
	fi
}
trap cleanup EXIT

# Mot de passe du superadmin local, tiré au hasard pour ce lancement (partagé avec les tests).
export CLEARANCE_DEV_SUPERUSER_PASSWORD="$(openssl rand -hex 12)"

CLEARANCE_ENDINGS_CACHE_S=2 \
CLEARANCE_GARDE_MIN_INTERVAL_S=1 \
CLEARANCE_OTP_PER_10MIN=12 \
	"$ROOT/tools/online_dev_server.sh" --port "$PORT" --data "$DATA/pb_data" --fresh >"$LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 120); do
	if curl -s -o /dev/null "http://127.0.0.1:$PORT/api/health"; then
		break
	fi
	if ! kill -0 "$SERVER_PID" 2>/dev/null; then
		echo "Le serveur s'est arrêté au démarrage :" >&2
		cat "$LOG" >&2
		exit 1
	fi
	sleep 0.5
done

status=0
node "$ROOT/server/tests/api_test.mjs" "http://127.0.0.1:$PORT" || status=$?
if [[ "$status" != 0 ]]; then
	echo "--- journal du serveur (fin) ---" >&2
	tail -n 40 "$LOG" >&2
fi
exit "$status"
