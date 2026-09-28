#!/bin/bash
# Popup del calendario anual con festivos de Madrid, con la ventana del
# tamaño justo del contenido (igual que weather-popup-launch.sh).

tmpfile=$(mktemp /tmp/calendario-XXXXXX.txt)
~/.local/bin/festivos year > "$tmpfile"

cols=$(sed -E 's/\x1b\[[0-9;]*m//g' "$tmpfile" | awk '{ print length }' | sort -rn | head -1)
lines=$(wc -l < "$tmpfile")

foot --app-id=calendar-popup --title='Calendario' \
    --window-size-chars="$((cols + 2))x$((lines + 1))" \
    -e sh -c "sleep 0.15; less -R -Ps'q\: cerrar' '$tmpfile'; rm -f '$tmpfile'"
