#!/bin/bash
# Actualiza el calendario desplegable del panel de swaync (menubar#cal):
#   boton del menu -> "Hoy: <fecha>"      (contraido)
#   accion interna -> cuadricula del mes  (desplegado; clic abre el año)
# El label de swaync no admite marcado: hoy y festivos van con simbolos. Lo lanza cada dia a las 00:00 (y al iniciar sesion)
# swaync-calendar.timer.

# Los textos se guardan en cache; build-config.sh los mete en config.json
# (generado, fuera del repo) y recarga swaync.
labels="$HOME/.cache/swaync-labels"

hoy=$(date +'%A, %-d de %B')
head=$(printf '  Hoy: %s' "${hoy^}")
# Cuadricula propia con hoy y festivos de Madrid marcados (~/.local/bin/festivos)
grid=$(~/.local/bin/festivos grid)
[ "$(~/.local/bin/festivos waybar | jq -r '.class // ""')" = hoy ] && head+="  · festivo"

mkdir -p "$labels"
[ "$head" = "$(cat "$labels/cal-head" 2>/dev/null)" ] && \
    [ "$grid" = "$(cat "$labels/cal-grid" 2>/dev/null)" ] && exit 0
printf '%s' "$head" > "$labels/cal-head"
printf '%s' "$grid" > "$labels/cal-grid"
"$HOME/.config/swaync/scripts/build-config.sh"
