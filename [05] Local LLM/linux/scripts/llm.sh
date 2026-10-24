#!/usr/bin/env bash
# Menu for the local AI folder. Lives in ~/llm next to start-llm.sh, close-llm.sh and gen-image.sh.
# Two things it can start: the text model (llama-server) and the image model (stable-diffusion.cpp).
# Each choice first prints what will run, the memory it needs, and the commands you can paste
# into another terminal to use it. Nothing starts until you say so.
set -uo pipefail

ROOT="$HOME/llm"
TEXT_SH="$ROOT/start-llm.sh"
CLOSE_SH="$ROOT/close-llm.sh"
IMAGE_SH="$ROOT/gen-image.sh"
SD_BIN="$ROOT/src/stable-diffusion.cpp/build/bin/sd-cli"
PORT=18080

# ---------------------------------------------------------------- helpers
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }
line()  { printf '%s\n' "----------------------------------------------------------------------"; }
pause() { printf '\n'; read -r -p "Enter to go back " _; }

vram_mib() {
    local v; v=$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | sort -n | tail -1)
    [ -n "${v:-}" ] && echo $(( v / 1048576 )) || echo "?"
}
gib() { [ -f "$1" ] && awk -v b="$(stat -c %s "$1")" 'BEGIN{printf "%.1f GiB", b/1073741824}' || echo "missing"; }
var_from() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | sed -E "s/^$2=//; s/#.*//; s/[\"']//g; s/^ *//; s/ *$//" | sed "s#\$HOME#$HOME#; s#\$ROOT#$ROOT#; s#\$IMG#$ROOT/models/image#"; }
flag_from() { grep -oE -- "$2 [^ \\\\]+" "$1" 2>/dev/null | head -1 | awk '{print $2}'; }
text_running() { ss -ltn "sport = :$PORT" 2>/dev/null | grep -q LISTEN; }

# ---------------------------------------------------------------- text
TEXT_MODEL=$(var_from "$TEXT_SH" MODEL)
TEXT_DEVICE=$(var_from "$TEXT_SH" DEVICE)
TEXT_CTX=$(flag_from "$TEXT_SH" -c)

show_text() {
    clear; bold "TEXT: llama-server"; line
    printf '%-14s %s\n' "model"   "$(basename "$TEXT_MODEL")  ($(gib "$TEXT_MODEL"))"
    printf '%-14s %s\n' "device"  "$TEXT_DEVICE"
    printf '%-14s %s\n' "context" "${TEXT_CTX:-?} tokens, q8_0 KV cache, draft head on"
    printf '%-14s %s\n' "needs"   "VRAM depends on model and context; close GPU-heavy apps and the image model first"
    printf '%-14s %s\n' "serves"  "http://127.0.0.1:$PORT  (web UI in a browser, OpenAI-style API for Cline, Zed, curl)"
    printf '%-14s %s\n' "LAN default" "http://<PC-LAN-IP>:$PORT  (no API key; trusted home network)"
    printf '%-14s %s\n' "state"   "$(text_running && echo running || echo stopped), VRAM in use now: $(vram_mib) MiB"
    printf '\n'; bold "Commands to paste in another terminal once it says 'listening':"; line
    cat <<EOF
# is it up
curl -s http://127.0.0.1:$PORT/health

# one question, answer only
curl -s http://127.0.0.1:$PORT/v1/chat/completions -H 'Content-Type: application/json' \\
  -d '{"messages":[{"role":"user","content":"Explain btrfs subvolumes in three sentences."}],"max_tokens":200}' \\
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["choices"][0]["message"]["content"]); print(d["timings"]["predicted_per_second"], "tok/s")'

# the same with a file as context
curl -s http://127.0.0.1:$PORT/v1/chat/completions -H 'Content-Type: application/json' \\
  -d "\$(python3 -c 'import json,sys; print(json.dumps({"messages":[{"role":"user","content":"Review this file:\\n"+open(sys.argv[1]).read()}],"max_tokens":800}))' ~/llm/start-llm.sh)" \\
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])'

# VRAM while it runs (MiB)
echo \$(( \$(cat /sys/class/drm/card*/device/mem_info_vram_used | sort -n | tail -1) / 1048576 ))

# benchmark the flags (server must be stopped)
~/llm/scripts/bench.sh "$TEXT_MODEL" $TEXT_DEVICE 512,2048 0,16384 512,1024

# stop it
~/llm/close-llm.sh
EOF
    printf '\n'
    if text_running; then
        read -r -p "It is already running. [s]top it, or Enter to go back: " a
        [ "${a:-}" = s ] && "$CLOSE_SH"
    else
        read -r -p "Start it here now? It stays in this window; Ctrl+C stops it. [y/N] " a
        [ "${a:-}" = y ] && "$TEXT_SH"
    fi
}

# ---------------------------------------------------------------- image
IMG_PRESET=${PRESET:-qwen}
preset_var() {  # the value of $2 inside the "$1)" case block of gen-image.sh
    awk -v p="$1)" -v k="$2" '$1==p{f=1;next} f&&/;;/{f=0} f&&$0~"^ *"k"="{sub("^ *"k"=","");sub(/ *#.*/,"");gsub(/"/,"");print;exit}' "$IMAGE_SH" \
      | sed "s#\$IMG#$ROOT/models/image#"
}
IMG_MODEL=$(preset_var "$IMG_PRESET" MODEL)
IMG_LLM=$(preset_var "$IMG_PRESET" LLM)
IMG_VAE=$(preset_var "$IMG_PRESET" VAE)
IMG_MMPROJ=$(preset_var "$IMG_PRESET" MMPROJ)

show_image() {
    clear; bold "IMAGE: stable-diffusion.cpp, preset $IMG_PRESET"; line
    printf '%-14s %s\n' "generator" "$(basename "$IMG_MODEL")  ($(gib "$IMG_MODEL"))"
    printf '%-14s %s\n' "text encoder" "$(basename "$IMG_LLM")  ($(gib "$IMG_LLM"))"
    printf '%-14s %s\n' "vae"       "$(basename "$IMG_VAE")  ($(gib "$IMG_VAE"))"
    printf '%-14s %s\n' "vision"    "$([ -n "$IMG_MMPROJ" ] && echo "$(basename "$IMG_MMPROJ")  ($(gib "$IMG_MMPROJ")), only for editing a picture" || echo "none: this preset cannot edit")"
    printf '%-14s %s\n' "presets"   "qwen (default), zimage, flux3: PRESET=zimage ~/llm/llm.sh  or  ~/llm/scripts/get-models.sh to download one"
    printf '%-14s %s\n' "binary"    "$([ -x "$SD_BIN" ] && echo "$SD_BIN" || echo "MISSING: run ~/llm/scripts/build-sdcpp.sh")"
    printf '%-14s %s\n' "needs"     "about 15 GiB VRAM at 1024x1024 with the Q8 generator; the text server must be stopped"
    printf '%-14s %s\n' "settings"  "euler, cfg 6.0, 20 steps, sizes divisible by 32, seed -1 = random"
    printf '%-14s %s\n' "state"     "text server $(text_running && echo RUNNING, stop it first || echo stopped); VRAM in use now: $(vram_mib) MiB"
    printf '\n'; bold "Commands to paste in a terminal:"; line
    cat <<EOF
# one image: prompt, output file, size, steps, seed (all but the prompt optional)
~/llm/gen-image.sh "a lovely cat holding a sign that says 'hello'"
~/llm/gen-image.sh "a lovely cat holding a sign that says 'hello'" ~/llm/images/cat.png 1024x1024 20 42

# bigger, slower (about 4x the time of 1024)
~/llm/gen-image.sh "a rainy street in Kolkata at night, film photo" ~/llm/images/street.png 2048x2048

# edit an existing picture instead of starting from noise
REF=~/llm/images/cat.png ~/llm/gen-image.sh "change the sign to say 'bye'" ~/llm/images/cat-edit.png

# if it runs out of VRAM: keep the extra weights in RAM (slower, same result)
OFFLOAD=1 ~/llm/gen-image.sh "..."

# another model set, once downloaded with ~/llm/scripts/get-models.sh <set>
PRESET=zimage ~/llm/gen-image.sh "..."      # 8 steps, fastest
PRESET=flux3  ~/llm/gen-image.sh "..."      # 16 steps, edits with up to 10 references

# the raw command the wrapper runs, to change anything it does not expose
$SD_BIN \\
  --diffusion-model "$IMG_MODEL" \\
  --llm "$IMG_LLM" \\
  --vae "$IMG_VAE" \\
  -p "a lovely cat holding a sign that says 'hello'" \\
  --cfg-scale 6.0 --steps 20 --sampling-method euler -W 1024 -H 1024 --seed 42 -v \\
  -o ~/llm/images/first.png

# the prompt is stored inside the PNG; strip it before sharing a picture
mogrify -strip ~/llm/images/cat.png      # package: imagemagick
EOF
    printf '\n'
    read -r -p "Generate one now? [y/N] " a
    [ "${a:-}" = y ] || return
    read -r -p "prompt: " p; [ -n "${p:-}" ] || return
    read -r -p "size [1024x1024]: " s; s=${s:-1024x1024}
    read -r -p "steps [preset default]: " n
    local out="$ROOT/images/$(date +%Y%m%d-%H%M%S).png"
    PRESET="$IMG_PRESET" "$IMAGE_SH" "$p" "$out" "$s" ${n:+"$n"} && printf '\nwrote %s\n' "$out"
    pause
}

# ---------------------------------------------------------------- status
show_status() {
    clear; bold "STATUS"; line
    printf '%-14s %s\n' "text server" "$(text_running && echo "running on :$PORT" || echo stopped)"
    printf '%-14s %s MiB\n' "VRAM used" "$(vram_mib)"
    printf '%-14s %s\n' "GPU" "$(grep -m1 -oE 'RX [0-9]+[A-Z ]*' /sys/class/drm/card*/device/product_name 2>/dev/null || llama-server --list-devices 2>/dev/null | grep -m1 -oE 'AMD Radeon [^(]*')"
    printf '%-14s %s\n' "text models" "$(ls "$ROOT/models"/*.gguf 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    printf '%-14s %s\n' "image models" "$(ls "$ROOT/models/image" 2>/dev/null | tr '\n' ' ')"
    printf '%-14s %s\n' "images made" "$(ls "$ROOT/images" 2>/dev/null | wc -l) in $ROOT/images"
    printf '%-14s %s\n' "last log" "$ROOT/logs/server.log"
    pause
}

# ---------------------------------------------------------------- menu
while true; do
    clear; bold "~/llm"; line
    printf ' 1) text   %s on %s, %s\n' "$(basename "${TEXT_MODEL%.gguf}")" "$TEXT_DEVICE" "$(text_running && echo running || echo stopped)"
    printf ' 2) image  %s\n' "$(basename "${IMG_MODEL%.gguf}")"
    printf ' 3) status\n q) quit\n\n'
    read -r -p "> " c
    case "${c:-}" in
        1) show_text ;;
        2) show_image ;;
        3) show_status ;;
        q|Q) exit 0 ;;
    esac
done
