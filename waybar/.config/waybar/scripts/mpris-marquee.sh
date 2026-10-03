#!/bin/bash
# Scrolling "now playing" marquee for waybar, via playerctl.
# Continuous module: prints a new JSON line every tick, no --interval needed.

# Ancho fijo del modulo, en caracteres: los titulos cortos se rellenan con
# espacios y los largos se desplazan. Es lo unico que decide el tamano.
WIDTH=20
SEP="   *   "

get_icon() {
    case "$1" in
        Playing) printf '' ;;
        Paused)  printf '' ;;
        *)       printf '' ;;
    esac
}

# Caracteres anchos (japones, chino, coreano, emoji...) ocupan 2 columnas.
# wide <caracter>: exito si es ancho (rangos East Asian Wide/Fullwidth principales)
wide() {
    local n; printf -v n '%d' "'$1"
    (( (n >= 0x1100 && n <= 0x115F) || (n >= 0x2E80 && n <= 0xA4CF) ||
       (n >= 0xAC00 && n <= 0xD7A3) || (n >= 0xF900 && n <= 0xFAFF) ||
       (n >= 0xFE30 && n <= 0xFE4F) || (n >= 0xFF00 && n <= 0xFF60) ||
       (n >= 0xFFE0 && n <= 0xFFE6) || (n >= 0x1F300 && n <= 0x1FAFF) ))
}

# cols <texto>: cuantas columnas ocupa
cols() {
    local t="$1" n=${#1} i
    for ((i = 0; i < ${#t}; i++)); do wide "${t:i:1}" && n=$((n + 1)); done
    echo "$n"
}

# fit <texto>: corta a WIDTH columnas y rellena con espacios hasta WIDTH
fit() {
    local t="$1" out="" c w cols=0 i
    for ((i = 0; i < ${#t}; i++)); do
        c=${t:i:1}; w=1
        wide "$c" && w=2
        (( cols + w > WIDTH )) && break
        out+=$c; cols=$((cols + w))
    done
    while (( cols < WIDTH )); do out+=" "; cols=$((cols + 1)); done
    printf '%s' "$out"
}

offset=0
prev_text=""

while true; do
    status=$(playerctl status 2>/dev/null)
    if [ -z "$status" ]; then
        printf '{"text":"","tooltip":"","class":"stopped"}\n'
        offset=0
        prev_text=""
        sleep 1
        continue
    fi

    title=$(playerctl metadata title 2>/dev/null)
    artist=$(playerctl metadata artist 2>/dev/null)
    if [ -n "$artist" ]; then
        text="$title - $artist"
    else
        text="$title"
    fi

    if [ "$text" != "$prev_text" ]; then
        offset=0
        prev_text="$text"
    fi

    icon=$(get_icon "$status")
    len=${#text}

    if [ "$(cols "$text")" -le "$WIDTH" ]; then
        display=$(fit "$text")   # cabe entero: solo se rellena
    else
        looped="${text}${SEP}${text}${SEP}"
        looplen=$((len + ${#SEP}))
        pos=$((offset % looplen))
        display=$(fit "${looped:$pos}")
        offset=$((offset + 1))
    fi

    class=$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')
    display_esc=$(printf '%s' "$display" | sed 's/\\/\\\\/g; s/"/\\"/g')
    tooltip_esc=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')

    printf '{"text":"%s %s","tooltip":"%s","class":"%s"}\n' "$icon" "$display_esc" "$tooltip_esc" "$class"
    sleep 0.4
done
