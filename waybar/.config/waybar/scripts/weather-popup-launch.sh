#!/bin/bash
# Genera el pronostico, mide cuanto ocupa (sin contar codigos ANSI) y abre
# el terminal flotante con el tamano justo para el contenido, en vez de un
# tamano fijo con espacio sobrante.

tmpfile=$(mktemp /tmp/weather-report-XXXXXX.txt)
"$HOME/.config/waybar/scripts/weather-report.sh" > "$tmpfile"

cols=$(sed -E 's/\x1b\[[0-9;]*m//g' "$tmpfile" | awk '{ print length }' | sort -rn | head -1)
lines=$(wc -l < "$tmpfile")

# Margen para que el texto no toque los bordes, y limites para no acabar
# con una ventana minuscula o gigante segun el contenido del dia.
cols=$(( cols + 2 ))
lines=$(( lines + 1 ))
[ "$cols" -lt 50 ]  && cols=50
[ "$cols" -gt 130 ] && cols=130
[ "$lines" -lt 10 ] && lines=10
[ "$lines" -gt 55 ] && lines=55

foot --app-id=weather-popup --title='Pronostico del tiempo' \
    --window-size-chars="${cols}x${lines}" \
    -e sh -c "sleep 0.15; less -R '$tmpfile'; rm -f '$tmpfile'"
