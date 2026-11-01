#!/usr/bin/env bash
# CLEARANCE M16 — PocketBase local pour le développement et les tests (docs/ONLINE.md §10).
#
#   tools/online_dev_server.sh [--port 8090] [--data DIR] [--fresh] [--verbose]
#
# - Binaire PocketBase (version figée ci-dessous, sha256 vérifié) téléchargé dans
#   build/pocketbase/ (ignoré par git) ; jamais versionné.
# - Migrations (server/pb_migrations) et crochets (server/pb_hooks) du dépôt, plus
#   le crochet de dev server/dev_hooks/dev_otp.pb.js (mode dev OTP : aucun e-mail,
#   code lisible par GET /api/clearance/dev/otp?otpId=…).
# - SMTP désactivé ; superadmin de test dev@clearance.local, mot de passe aléatoire
#   (ou CLEARANCE_DEV_SUPERUSER_PASSWORD), copié dans <data>/.dev_superuser
#   (console http://127.0.0.1:<port>/_/) — LOCAL UNIQUEMENT.
# - Tourne au premier plan (Ctrl+C pour arrêter). Les variables d'environnement
#   CLEARANCE_* sont transmises (ex. CLEARANCE_ENDINGS_CACHE_S=2).
set -euo pipefail

PB_VERSION="0.40.6"
PB_SHA256_linux_amd64="0e1f609158ed945f809f8a02ae012aa0427129c66ebb63c1aee76f2c0309373f"
PB_SHA256_linux_arm64="d22c66ceb67ca92b7d767f36d826e848a276bcfa3c197ead20bf87c42208984f"
PB_SHA256_darwin_amd64=""
PB_SHA256_darwin_arm64=""

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PB_HOME="${PB_HOME:-$ROOT/build/pocketbase}"
PORT=8090
DATA=""
FRESH=0
VERBOSE=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--port) PORT="$2"; shift 2 ;;
		--data) DATA="$2"; shift 2 ;;
		--fresh) FRESH=1; shift ;;
		--verbose) VERBOSE=1; shift ;;
		-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
		*) echo "Option inconnue : $1" >&2; exit 2 ;;
	esac
done
DATA="${DATA:-$PB_HOME/pb_data_dev}"

# --- Binaire --------------------------------------------------------------------------------
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
	x86_64|amd64) arch=amd64 ;;
	aarch64|arm64) arch=arm64 ;;
	*) echo "Architecture non prise en charge : $(uname -m)" >&2; exit 1 ;;
esac
BIN_DIR="$PB_HOME/$PB_VERSION-$os-$arch"
BIN="$BIN_DIR/pocketbase"
if [[ ! -x "$BIN" ]]; then
	mkdir -p "$BIN_DIR"
	zip="$BIN_DIR/pocketbase.zip"
	url="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_${os}_${arch}.zip"
	echo "[online_dev_server] téléchargement de PocketBase $PB_VERSION ($os/$arch)…" >&2
	curl -fsSL --retry 3 -o "$zip" "$url"
	expected_var="PB_SHA256_${os}_${arch}"
	expected="${!expected_var:-}"
	if [[ -n "$expected" ]]; then
		actual="$( (sha256sum "$zip" 2>/dev/null || shasum -a 256 "$zip") | cut -d' ' -f1)"
		if [[ "$actual" != "$expected" ]]; then
			echo "Somme sha256 inattendue pour $url : $actual" >&2
			rm -f "$zip"
			exit 1
		fi
	else
		echo "[online_dev_server] attention : pas de somme connue pour $os/$arch (vérifier checksums.txt de la release)" >&2
	fi
	unzip -o -q "$zip" pocketbase -d "$BIN_DIR"
	rm -f "$zip"
	chmod +x "$BIN"
fi

# --- Crochets : dépôt + crochet de dev ---------------------------------------------------------
HOOKS="$PB_HOME/hooks_dev_$PORT"
rm -rf "$HOOKS"
mkdir -p "$HOOKS"
cp "$ROOT"/server/pb_hooks/*.js "$HOOKS"/
cp "$ROOT"/server/dev_hooks/*.js "$HOOKS"/

if [[ "$FRESH" == 1 ]]; then
	rm -rf "$DATA"
fi
mkdir -p "$DATA"

export CLEARANCE_DEV_OTP=1
export SMTP_HOST=""
export CLEARANCE_APP_URL="http://127.0.0.1:$PORT"
export CLEARANCE_HIDE_CONTROLS="${CLEARANCE_HIDE_CONTROLS:-0}"
export CLEARANCE_TRUSTED_PROXY_HEADERS="${CLEARANCE_TRUSTED_PROXY_HEADERS:-X-Forwarded-For}"
export CLEARANCE_BACKUP_CRON="${CLEARANCE_BACKUP_CRON:-off}"
ORIGINS="${CLEARANCE_ORIGINS:-https://clearance.cardormedia.com,https://www.clearance.cardormedia.com,http://localhost:8060,http://127.0.0.1:8060}"

common=(--dir "$DATA" --migrationsDir "$ROOT/server/pb_migrations" --hooksDir "$HOOKS" --automigrate=false)
# Mot de passe du superadmin local : CLEARANCE_DEV_SUPERUSER_PASSWORD s'il est fourni,
# sinon tiré au hasard à chaque lancement et écrit dans $DATA/.dev_superuser (jamais versionné).
DEV_PW="${CLEARANCE_DEV_SUPERUSER_PASSWORD:-$(openssl rand -hex 12)}"
printf '%s\n' "$DEV_PW" > "$DATA/.dev_superuser"; chmod 600 "$DATA/.dev_superuser"
"$BIN" superuser upsert dev@clearance.local "$DEV_PW" "${common[@]}" --dev=false >/dev/null

echo "[online_dev_server] PocketBase $PB_VERSION sur http://127.0.0.1:$PORT (données : $DATA, mode dev OTP)" >&2
dev_flag="--dev=false"
[[ "$VERBOSE" == 1 ]] && dev_flag="--dev=true"
exec "$BIN" serve --http "127.0.0.1:$PORT" --origins "$ORIGINS" --hooksWatch=false "$dev_flag" "${common[@]}"
