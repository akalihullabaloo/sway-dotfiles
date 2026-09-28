#!/bin/bash
# Reports default microphone (source) mute state for waybar custom/mic.
# Reacts instantly to changes via pactl subscribe (no polling interval).
# LC_ALL=C forces English output from pactl regardless of system locale,
# since this system's locale (es_ES) translates "Mute: yes" -> "Mute: si"
# and the subscribe event text, which would otherwise break the parsing.

print_status() {
    muted=$(LC_ALL=C pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')
    if [ "$muted" = "yes" ]; then
        printf '{"text":"%s","class":"muted","tooltip":"Microfono silenciado"}\n' ""
    else
        printf '{"text":"%s","class":"unmuted","tooltip":"Microfono activo"}\n' ""
    fi
}

print_status

LC_ALL=C pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
        *"on source"*) print_status ;;
    esac
done
