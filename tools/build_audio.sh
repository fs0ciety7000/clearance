#!/bin/bash
# Génère les assets audio (docs/AUDIO.md §8) de façon reproductible :
#   1. décode les packs Kenney CC0 (art_src/downloads/, cf. tools/fetch_assets.sh) en WAV mono 48 kHz ;
#   2. godot --headless --script res://tools/build_audio.gd (synthèse + traitement, default_bus_layout.tres) ;
#   3. encode les boucles longues (ambiance, musique) en OGG Vorbis 48 kHz stéréo,
#      de façon déterministe (M14, D-180 : bitexact, métadonnées retirées,
#      serial OGG fixe = CRC du nom) : deux builds donnent les mêmes octets ;
#   4. réimporte le projet ;
#   5. musique M14 (docs/AUDIO.md §13.4) : tools/build_music.gd (partitions
#      art_src/music/*.json, rendu incrémental, manifest.json), import, puis
#      --defs (MusicSetDef / MusicThemeDef / music_library.tres).
# Dépendances : godot 4.7, ffmpeg (libvorbis). Usage :
#   bash tools/build_audio.sh [--only=ui,booth,…]      (« beds » : lits d'ambiance par acte ; « music » : musique M14)
#   bash tools/build_audio.sh --only=music:ms02        (une partition M14 seulement ; « music:all » : toutes)
#   options transmises à build_music : --force (tout rendre), --demos (démos docs/mockups/)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="$ROOT/art_src/downloads"
WORK="$DL/_audio_build"   # ignoré par git (sous art_src/downloads/)
GODOT="${GODOT:-godot}"

for pack in sci-fi-sounds interface-sounds impact-sounds; do
  [ -d "$DL/$pack/Audio" ] || { echo "Pack Kenney manquant : $pack (lancer bash tools/fetch_assets.sh)" >&2; exit 1; }
  mkdir -p "$WORK/src/$pack"
  for f in "$DL/$pack"/Audio/*.ogg; do
    out="$WORK/src/$pack/$(basename "${f%.ogg}").wav"
    [ -f "$out" ] || ffmpeg -loglevel error -y -i "$f" -ac 1 -ar 48000 -sample_fmt s16 "$out"
  done
done

# Arguments : --only=… (groupes de build_audio.gd ; music:<id> → build_music seul),
# --force / --demos → build_music.
ONLY=""; MUSIC_IDS=""; MUSIC_OPTS=(); LEGACY=1; MUSIC=0
for a in "$@"; do
  case "$a" in
    --only=*) ONLY="${a#--only=}" ;;
    --force|--demos) MUSIC_OPTS+=("$a") ;;
  esac
done
if [ -z "$ONLY" ]; then MUSIC=1; fi
if [ -n "$ONLY" ]; then
  groups=()
  IFS=',' read -ra parts <<< "$ONLY"
  for p in "${parts[@]}"; do
    case "$p" in
      music:all) MUSIC=1 ;;
      music:*) MUSIC=1; MUSIC_IDS="${MUSIC_IDS:+$MUSIC_IDS,}${p#music:}" ;;
      music) MUSIC=1 ;;
      *) groups+=("$p") ;;
    esac
  done
  if [ ${#groups[@]} -eq 0 ]; then LEGACY=0; fi
  ONLY="$(IFS=','; echo "${groups[*]}")"
fi

if [ "$LEGACY" = 1 ]; then
mkdir -p "$WORK/loops"
"$GODOT" --headless --path "$ROOT" --script res://tools/build_audio.gd -- --src="$WORK/src" --loops="$WORK/loops" ${ONLY:+--only=$ONLY}

for f in "$WORK"/loops/*.wav; do
  [ -f "$f" ] || continue
  name="$(basename "${f%.wav}")"
  case "$name" in
    amb_*) dest="$ROOT/assets/audio/ambience/$name.ogg"; q=4 ;;
    *) continue ;;
  esac
  serial=$(( $(printf '%s' "$name" | cksum | cut -d' ' -f1) % 2147483647 ))
  ffmpeg -loglevel error -y -i "$f" -ar 48000 -map_metadata -1 -c:a libvorbis -q:a "$q" \
    -fflags +bitexact -flags:a +bitexact -serial_offset "$serial" "$dest"
  rm -f "$f"
done
fi

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
# Paramètres d'import des boucles (versionnés dans les .import) puis réimport.
for imp in "$ROOT"/assets/audio/*/*_loop.wav.import "$ROOT"/assets/audio/*/*/*_loop.wav.import; do
  if [ -f "$imp" ]; then sed -i 's/^edit\/loop_mode=.*/edit\/loop_mode=2/' "$imp"; fi
done
for imp in "$ROOT"/assets/audio/ambience/*_loop.ogg.import; do
  if [ -f "$imp" ]; then sed -i 's/^loop=.*/loop=true/' "$imp"; fi
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

if [ "$MUSIC" = 1 ]; then
  "$GODOT" --headless --path "$ROOT" --script res://tools/build_music.gd -- ${MUSIC_IDS:+--only=$MUSIC_IDS} "${MUSIC_OPTS[@]}"
  "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
  "$GODOT" --headless --path "$ROOT" --script res://tools/build_music.gd -- --defs
  "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
fi
echo "OK  assets/audio + default_bus_layout.tres"
