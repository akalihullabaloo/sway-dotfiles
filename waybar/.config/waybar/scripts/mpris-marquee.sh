#!/bin/bash
# Scrolling "now playing" marquee for waybar, via playerctl.
# Continuous module: prints a new JSON line every tick, no --interval needed.

WIDTH=20
SEP="   *   "

get_icon() {
    case "$1" in
        Playing) printf '' ;;
        Paused)  printf '' ;;
        *)       printf '' ;;
    esac
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

    if [ "$len" -le "$WIDTH" ]; then
        display="$text"
    else
        looped="${text}${SEP}${text}${SEP}"
        looplen=$((len + ${#SEP}))
        pos=$((offset % looplen))
        display="${looped:$pos:$WIDTH}"
        offset=$((offset + 1))
    fi

    class=$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')
    display_esc=$(printf '%s' "$display" | sed 's/\\/\\\\/g; s/"/\\"/g')
    tooltip_esc=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')

    printf '{"text":"%s %s","tooltip":"%s","class":"%s"}\n' "$icon" "$display_esc" "$tooltip_esc" "$class"
    sleep 0.4
done
