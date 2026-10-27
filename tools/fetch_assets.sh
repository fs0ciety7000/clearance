#!/bin/bash
# Télécharge les packs d'assets sources (tous CC0) dans art_src/downloads/ (ignoré par git).
# Les ressources importées dans le jeu, elles, sont versionnées dans assets/ (voir docs/ASSETS.md §10).
# Usage : bash tools/fetch_assets.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="$ROOT/art_src/downloads"
mkdir -p "$DL"

kenney() {  # $1 = slug de la page kenney.nl/assets/<slug>
  local url
  url=$(curl -sSL "https://kenney.nl/assets/$1" | grep -oE 'https://kenney.nl/media/[^"]+\.zip' | head -1)
  [ -n "$url" ] || { echo "Kenney : lien introuvable pour $1" >&2; return 1; }
  mkdir -p "$DL/$1" && curl -sSfL -o "$DL/$1/pack.zip" "$url"
  (cd "$DL/$1" && unzip -qo pack.zip && rm pack.zip)
  echo "OK  kenney/$1"
}

# Personnages (CC0)
kenney animated-characters-protagonists
kenney animated-characters-survivors
kenney animated-characters-retro
# Audio (CC0)
kenney sci-fi-sounds
kenney interface-sounds
kenney impact-sounds

# Quaternius — Universal Animation Library [Standard] (CC0, itch.io « name your own price », 0 $)
TMP=$(mktemp -d)
GAME=https://quaternius.itch.io/universal-animation-library
curl -sSL -c "$TMP/c" "$GAME" -o "$TMP/p.html"
CSRF=$(grep -oE 'name="csrf_token" value="[^"]+"' "$TMP/p.html" | head -1 | sed 's/.*value="//;s/"$//')
DLPAGE=$(curl -sSL -b "$TMP/c" -c "$TMP/c" -X POST --data-urlencode "csrf_token=$CSRF" "$GAME/download_url" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['url'])")
curl -sSL -b "$TMP/c" -c "$TMP/c" "$DLPAGE" -o "$TMP/d.html"
CSRF2=$(grep -oE 'name="csrf_token" value="[^"]+"' "$TMP/d.html" | head -1 | sed 's/.*value="//;s/"$//')
UPLOAD=$(grep -oE 'data-upload_id="[0-9]+"' "$TMP/d.html" | head -1 | grep -oE '[0-9]+')  # [Standard]
FILE=$(curl -sSL -b "$TMP/c" -X POST --data-urlencode "csrf_token=$CSRF2" \
  "$GAME/file/$UPLOAD?source=game_download&as_props=1&key=" | python3 -c "import sys,json;print(json.load(sys.stdin)['url'])")
mkdir -p "$DL/quaternius-ual" && curl -sSfL -o "$DL/quaternius-ual/ual.zip" "$FILE"
(cd "$DL/quaternius-ual" && unzip -qo ual.zip && rm ual.zip)
rm -rf "$TMP"
echo "OK  quaternius/universal-animation-library"
