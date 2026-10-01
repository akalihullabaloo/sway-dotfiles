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

# Modo prueba: AEMET_NOTIFY_ALL=1 notifica todos los avisos activos sin
# tocar el fichero de vistos (para ver como queda la notificacion).
test_mode=false
[ "${AEMET_NOTIFY_ALL:-0}" = 1 ] && { test_mode=true; first_run=false; : > "$tmpdir/empty"; SEEN_CMP="$tmpdir/empty"; }
SEEN_CMP="${SEEN_CMP:-$SEEN_FILE}"

xp() { xmllint --xpath "$1" "$2" 2>/dev/null; }
I='//*[local-name()="info"][1]'

current_ids_file=$(mktemp)
# Un aviso por linea: nivel<TAB>fenomeno<TAB>zona<TAB>inicio<TAB>fin
new_tsv=$(mktemp)

for f in "$tmpdir"/*.xml; do
    [ -f "$f" ] || continue
    nivel=$(xp "string($I/*[local-name()=\"parameter\"][*[local-name()=\"valueName\"][text()=\"AEMET-Meteoalerta nivel\"]]/*[local-name()=\"value\"])" "$f")
    case "$nivel" in
        naranja|rojo) ;;
        *) continue ;;
    esac

    id=$(xp 'string(//*[local-name()="identifier"])' "$f")
    [ -n "$id" ] || continue
    echo "$id" >> "$current_ids_file"

    if [ "$first_run" = false ] && ! grep -qxF "$id" "$SEEN_CMP" 2>/dev/null; then
        # "Aviso de lluvias de nivel naranja" -> "Lluvias"
        fen=$(xp "string($I/*[local-name()=\"event\"])" "$f" | sed -E 's/^Aviso de //; s/ de nivel .*//')
        fen="${fen^}"
        onset=$(xp "string($I/*[local-name()=\"onset\"])" "$f")
        expira=$(xp "string($I/*[local-name()=\"expires\"])" "$f")
        nzonas=$(xp "count($I/*[local-name()=\"area\"])" "$f")
        for ((i = 1; i <= ${nzonas:-0}; i++)); do
            zona=$(xp "string($I/*[local-name()=\"area\"][$i]/*[local-name()=\"areaDesc\"])" "$f")
            printf '%s\t%s\t%s\t%s\t%s\n' "$nivel" "$fen" "$zona" "$onset" "$expira" >> "$new_tsv"
        done
    fi
done

$test_mode || mv "$current_ids_file" "$SEEN_FILE"
rm -f "$current_ids_file"
rm -rf "$tmpdir"

# AEMET emite un aviso por zona y franja horaria, asi que en un episodio
# fuerte salen decenas de lineas. La notificacion se resume agrupando por
# nivel y fenomeno, con unas pocas zonas de muestra; el listado completo
# queda en DETAIL_FILE y se abre con la accion "Ver todos".
DETAIL_FILE="$HOME/.cache/aemet-avisos-nacional-ultimo.txt"
MAX_GRUPOS=5   # lineas de grupo en la notificacion
MAX_ZONAS=3    # zonas nombradas por grupo

if [ -s "$new_tsv" ]; then
    # Hora legible: "2026-10-01T18:00:00+02:00" -> "mié 18:00"
    fmt_tsv=$(mktemp)
    while IFS=$'\t' read -r nivel fen zona onset expira; do
        o=$(date -d "$onset" '+%a %H:%M' 2>/dev/null || echo "$onset")
        e=$(date -d "$expira" '+%a %H:%M' 2>/dev/null || echo "$expira")
        printf '%s\t%s\t%s\t%s\t%s\n' "$nivel" "$fen" "$zona" "$o" "$e"
    done < <(awk -F'\t' '{print ($1=="rojo"?0:1) "\t" $0}' "$new_tsv" \
                 | sort -u -t$'\t' -k1,1n -k3,3 -k4,4 -k5,5 -k6,6 | cut -f2-) > "$fmt_tsv"

    # Ya viene ordenado: rojo antes que naranja, luego fenomeno, zona y hora
    sorted=$(cat "$fmt_tsv")

    n_rojo=$(awk -F'\t' '$1=="rojo"{print $3}' <<< "$sorted" | sort -u | wc -l)
    n_naranja=$(awk -F'\t' '$1=="naranja"{print $3}' <<< "$sorted" | sort -u | wc -l)

    summary="AEMET: nuevos avisos"
    parts=()
    [ "$n_rojo" -gt 0 ] && parts+=("🟥 $n_rojo $([ "$n_rojo" = 1 ] && echo zona || echo zonas) en rojo")
    [ "$n_naranja" -gt 0 ] && parts+=("🟧 $n_naranja en naranja")
    [ ${#parts[@]} -gt 0 ] && summary="AEMET: $(IFS='·'; echo "${parts[*]}" | sed 's/·/ · /g')"

    body=$(awk -F'\t' -v maxg="$MAX_GRUPOS" -v maxz="$MAX_ZONAS" '
        function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
        {
            k = $1 "\t" $2
            if (!(k in seen)) { seen[k] = 1; order[++ng] = k }
            if (!((k, $3) in z)) { z[k, $3] = 1; nz[k]++; if (nz[k] <= maxz) names[k] = names[k] (nz[k] > 1 ? ", " : "") esc($3) }
        }
        END {
            for (i = 1; i <= ng && i <= maxg; i++) {
                k = order[i]; split(k, a, "\t")
                icon = (a[1] == "rojo") ? "🟥" : "🟧"
                line = icon " <b>" esc(a[2]) "</b>: " names[k]
                if (nz[k] > maxz) line = line " <i>(+" nz[k] - maxz ")</i>"
                print line
            }
            if (ng > maxg) print "<i>… y " ng - maxg " tipos de aviso más</i>"
        }' <<< "$sorted")

    {
        echo "Nuevos avisos AEMET naranja/rojo  ($(date '+%a %d/%m %H:%M'))"
        echo
        awk -F'\t' '
            { k = toupper($1) " · " $2; if (k != last) { if (NR > 1) print ""; print k; last = k } ;
              printf "  %-34s %s → %s\n", $3, $4, $5 }' <<< "$sorted"
        echo
        echo "Más información: https://www.aemet.es/es/eltiempo/prediccion/avisos"
    } > "$DETAIL_FILE"
    rm -f "$fmt_tsv"

    urgency="normal"
    [ "$n_rojo" -gt 0 ] && urgency="critical"

    # notify-send --action espera a que se cierre la notificacion, asi que
    # va desacoplado de waybar (setsid + sin heredar stdout).
    setsid -f bash -c '
        act=$(notify-send -u "$1" -a "AEMET" -i weather-severe-alert \
            -A "ver=Ver todos" "$2" "$3")
        [ "$act" = ver ] && foot --app-id=weather-popup --title="Avisos AEMET" \
            --window-size-chars=90x35 -e sh -c "sleep 0.15; less \"$4\""
    ' _ "$urgency" "$summary" "$body" "$DETAIL_FILE" >/dev/null 2>&1 </dev/null
fi
rm -f "$new_tsv"

echo '{"text":""}'
