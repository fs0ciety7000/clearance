#!/bin/sh
# CLEARANCE — démarrage de PocketBase dans le conteneur (server/README.md).
# Variables : CLEARANCE_ORIGINS (CORS), PB_ENCRYPTION_KEY (facultative, 32 caractères :
# chiffre les réglages, dont le mot de passe SMTP, dans pb_data), PB_HOME (défaut /pb).
set -eu
PB_HOME="${PB_HOME:-/pb}"
ORIGINS="${CLEARANCE_ORIGINS:-https://clearance.cardormedia.com,https://www.clearance.cardormedia.com}"
set -- serve \
	--http=0.0.0.0:8090 \
	--dir="$PB_HOME/pb_data" \
	--hooksDir="$PB_HOME/pb_hooks" \
	--migrationsDir="$PB_HOME/pb_migrations" \
	--automigrate=false \
	--hooksWatch=false \
	--dev=false \
	--origins="$ORIGINS"
if [ -n "${PB_ENCRYPTION_KEY:-}" ]; then
	set -- "$@" --encryptionEnv=PB_ENCRYPTION_KEY
fi
exec "$PB_HOME/pocketbase" "$@"
