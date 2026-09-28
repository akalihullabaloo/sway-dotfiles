#!/bin/bash
# Actualiza el boton del tiempo del panel de swaync (buttons-grid#tiempo).
# Lo llama weather.sh tras cada consulta:  weather-button.sh "<icono>" "<temp>" "<estado>"
# swaync no tiene widgets de texto dinamico: la etiqueta se guarda en cache y
# build-config.sh la mete en config.json (generado, fuera del repo) y recarga.

labels="$HOME/.cache/swaync-labels"
report="$HOME/.cache/aemet-weather-report.txt"
icon=$1 temp=$2 cond=$3

# Municipio y min/max de hoy, sacados de la cache del pronostico completo
# (misma fecha que hoy; si es de otro dia se omite el min/max).
clean=$(sed -E 's/\x1b\[[0-9;]*m//g' "$report" 2>/dev/null)
place=$(sed -nE '1s/.*— ([^(]+).*/\1/p' <<< "$clean" | sed 's/ *$//')
minmax=""
if [ "$(stat -c %Y "$report" 2>/dev/null | xargs -I{} date -d @{} +%F)" = "$(date +%F)" ]; then
    minmax=$(grep -m1 '🌡' <<< "$clean" | grep -oE '[0-9-]+°C / [0-9-]+°C' | head -1 | sed 's/C//g; s| / |/|')
fi

label="$icon ${place:+$place  }${temp}° · $cond${minmax:+ · $minmax}"

mkdir -p "$labels"
[ "$label" = "$(cat "$labels/tiempo" 2>/dev/null)" ] && exit 0
printf '%s' "$label" > "$labels/tiempo"
"$HOME/.config/swaync/scripts/build-config.sh"
