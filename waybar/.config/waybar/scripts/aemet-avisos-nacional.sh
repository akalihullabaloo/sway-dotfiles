#!/bin/bash
# Avisos meteorologicos naranja/rojo de AEMET para toda España: lanza una
# notificacion de escritorio cuando aparece uno nuevo (compara contra la
# ultima ejecucion). No se muestra nada en la barra de waybar -- es un
# modulo "invisible" (texto vacio) que solo aprovecha el "interval" de
# waybar como planificador, igual que el resto de scripts de tiempo de
# este setup (sin systemd timers aparte).
#
# El nivel amarillo se ignora a proposito: en España casi siempre hay
# alguna provincia en amarillo por algo, y notificar por cada uno saturaria
# el escritorio sin aportar nada util.
source "$HOME/.config/waybar/scripts/aemet-common.sh"

SEEN_FILE="$HOME/.cache/aemet-avisos-nacional-seen.txt"
mkdir -p "$(dirname "$SEEN_FILE")"

key=$(cat "$AEMET_API_KEY_FILE" 2>/dev/null)
[ -n "$key" ] || { echo '{"text":""}'; exit 0; }

step1=$(curl -s --max-time 10 "https://opendata.aemet.es/opendata/api/avisos_cap/ultimoelaborado/area/esp?api_key=${key}")
estado=$(echo "$step1" | jq -r '.estado // empty' 2>/dev/null)
[ "$estado" = "200" ] || { echo '{"text":""}'; exit 0; }

url=$(echo "$step1" | jq -r '.datos')
tmpdir=$(mktemp -d)
curl -s --max-time 30 "$url" -o "$tmpdir/avisos.tar"
tar xf "$tmpdir/avisos.tar" -C "$tmpdir" 2>/dev/null

# Primera vez que se ejecuta (no hay estado previo): se establece la base
# de avisos ya activos sin notificar, para no soltar de golpe todos los
# que ya estuvieran activos en ese momento.
first_run=true
[ -f "$SEEN_FILE" ] && first_run=false

current_ids_file=$(mktemp)
new_alerts=""
has_rojo=false

for f in "$tmpdir"/*.xml; do
    [ -f "$f" ] || continue
    nivel=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="parameter"][*[local-name()="valueName"][text()="AEMET-Meteoalerta nivel"]]/*[local-name()="value"])' "$f" 2>/dev/null)
    case "$nivel" in
        naranja|rojo) ;;
        *) continue ;;
    esac

    id=$(xmllint --xpath 'string(//*[local-name()="identifier"])' "$f" 2>/dev/null)
    [ -n "$id" ] || continue
    echo "$id" >> "$current_ids_file"

    if [ "$first_run" = false ] && ! grep -qxF "$id" "$SEEN_FILE" 2>/dev/null; then
        evento=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="event"])' "$f" 2>/dev/null)
        area=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="area"][1]/*[local-name()="areaDesc"])' "$f" 2>/dev/null)
        nzonas=$(xmllint --xpath 'count(//*[local-name()="info"][1]/*[local-name()="area"])' "$f" 2>/dev/null)
        expira=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="expires"])' "$f" 2>/dev/null | cut -dT -f1)
        [ "$nzonas" -gt 1 ] 2>/dev/null && area="${area} y ${nzonas} zonas mas"
        [ "$nivel" = "rojo" ] && has_rojo=true
        new_alerts+="[${nivel}] ${area}: ${evento} (hasta ${expira})"$'\n'
    fi
done

mv "$current_ids_file" "$SEEN_FILE"
rm -rf "$tmpdir"

if [ -n "$new_alerts" ]; then
    urgency="normal"
    $has_rojo && urgency="critical"
    notify-send -u "$urgency" -a "AEMET" -i weather-severe-alert \
        "Nuevo aviso meteorologico en España" "$new_alerts"
fi

echo '{"text":""}'
