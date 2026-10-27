#!/bin/bash
# Génère les assets audio (docs/AUDIO.md §8) de façon reproductible :
#   1. décode les packs Kenney CC0 (art_src/downloads/, cf. tools/fetch_assets.sh) en WAV mono 48 kHz ;
#   2. godot --headless --script res://tools/build_audio.gd (synthèse + traitement, default_bus_layout.tres) ;
#   3. encode les boucles longues (ambiance, musique) en OGG Vorbis 48 kHz stéréo ;
#   4. réimporte le projet.
# Dépendances : godot 4.7, ffmpeg (libvorbis). Usage : bash tools/build_audio.sh [--only=ui,booth,…]
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

mkdir -p "$WORK/loops"
"$GODOT" --headless --path "$ROOT" --script res://tools/build_audio.gd -- --src="$WORK/src" --loops="$WORK/loops" "$@"

for f in "$WORK"/loops/*.wav; do
  [ -f "$f" ] || continue
  name="$(basename "${f%.wav}")"
  case "$name" in
    amb_*) dest="$ROOT/assets/audio/ambience/$name.ogg"; q=4 ;;
    mus_*) dest="$ROOT/assets/audio/music/$name.ogg"; q=5 ;;
    *) continue ;;
  esac
  ffmpeg -loglevel error -y -i "$f" -ar 48000 -c:a libvorbis -q:a "$q" "$dest"
  rm -f "$f"
done

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
# Paramètres d'import des boucles (versionnés dans les .import) puis réimport.
for imp in "$ROOT"/assets/audio/*/*_loop.wav.import "$ROOT"/assets/audio/*/*/*_loop.wav.import; do
  if [ -f "$imp" ]; then sed -i 's/^edit\/loop_mode=.*/edit\/loop_mode=2/' "$imp"; fi
done
for imp in "$ROOT"/assets/audio/ambience/*_loop.ogg.import "$ROOT"/assets/audio/music/*_loop.ogg.import; do
  if [ -f "$imp" ]; then sed -i 's/^loop=.*/loop=true/' "$imp"; fi
done
for imp in "$ROOT"/assets/audio/music/*_loop.ogg.import; do
  if [ -f "$imp" ]; then sed -i 's/^bpm=.*/bpm=80/; s/^beat_count=.*/beat_count=32/' "$imp"; fi
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
echo "OK  assets/audio + default_bus_layout.tres"
