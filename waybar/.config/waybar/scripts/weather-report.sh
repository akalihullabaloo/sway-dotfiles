#!/bin/bash
# Genera el texto del pronostico completo (7 dias, AEMET) en stdout, en
# formato "tarjeta" por dia con icono, colores y barra de temperatura.
# No abre ninguna ventana: lo usa weather-popup-launch.sh para medir el
# contenido antes de lanzar el terminal flotante del tamano justo.
source "$HOME/.config/waybar/scripts/aemet-common.sh"

REPORT_CACHE="$HOME/.cache/aemet-weather-report.txt"
mkdir -p "$(dirname "$REPORT_CACHE")"

data=$(aemet_fetch "prediccion/especifica/municipio/diaria/${AEMET_MUNICIPIO}")

# Si AEMET no responde ahora mismo (limite de ~1 peticion/minuto), se
# muestra la ultima consulta buena en vez de un error seco. La cache la
# rellena tanto esta misma ejecucion (al tener exito) como el refresco
# periodico en segundo plano (aemet-report-refresh.sh).
if [ -z "$data" ]; then
    if [ -s "$REPORT_CACHE" ]; then
        edad_min=$(( ( $(date +%s) - $(stat -c %Y "$REPORT_CACHE") ) / 60 ))
        printf '\033[2;33m⚠ AEMET no respondio ahora mismo (limite de peticiones); mostrando la ultima consulta, de hace %s min\033[0m\n\n' "$edad_min"
        cat "$REPORT_CACHE"
    else
        echo "No se ha podido contactar con el servicio de tiempo de AEMET."
        echo "(Puede ser el limite de peticiones de AEMET; espera un minuto y vuelve a intentarlo)"
    fi
    exit 0
fi

nombre=$(echo "$data" | jq -r '.[0].nombre')
provincia=$(echo "$data" | jq -r '.[0].provincia')
elaborado=$(echo "$data" | jq -r '.[0].elaborado' | tr 'T' ' ')

SEP=$'\x1f'
LINEA="──────────────────────────────────────────────────────────────────────────────"
BARW=32

gmin=$(echo "$data" | jq '[.[0].prediccion.dia[].temperatura.minima] | min')
gmax=$(echo "$data" | jq '[.[0].prediccion.dia[].temperatura.maxima] | max')

{
printf '\033[1;32m☁  Pronostico AEMET — %s (%s)\033[0m\n' "$nombre" "$provincia"
printf '\033[2mElaborado: %s\033[0m\n\n' "$elaborado"

# Avisos activos, leidos de la cache que mantiene aemet-avisos.sh (no gasta
# otra peticion contra AEMET).
if [ -f "$AEMET_AVISOS_CACHE" ]; then
    jq -r '
      if (.nivel // "verde") == "verde" or (.avisos|length)==0 then
        "[1;32m✓ Sin avisos activos[0m"
      else
        "[1;31m⚠ Avisos activos (" + .nivel + "):[0m\n" +
        ([ .avisos[] | "   • \(.evento) (hasta \(.expira))" ] | join("\n"))
      end
    ' "$AEMET_AVISOS_CACHE"
    echo
fi
echo "$LINEA"

echo "$data" | jq -r --arg sep "$SEP" '
  .[0].prediccion.dia[] | [
    .fecha[0:10],
    ( [.estadoCielo[] | select(.periodo=="00-24" and .descripcion != "")][0].descripcion
      // ([.estadoCielo[] | select(.descripcion != "")] | last).descripcion
      // "-" ),
    ( [.estadoCielo[] | select(.periodo=="00-24" and .value != "")][0].value
      // ([.estadoCielo[] | select(.value != "")] | last).value
      // "" ),
    (.temperatura.minima|tostring),
    (.temperatura.maxima|tostring),
    (.sensTermica.minima|tostring),
    (.sensTermica.maxima|tostring),
    ( ([.probPrecipitacion[] | select(.periodo=="00-24")][0].value) // 0 | tostring ),
    ( ([.viento[] | select(.periodo=="00-24")][0].direccion) // "-" ),
    ( ([.viento[] | select(.periodo=="00-24")][0].velocidad) // 0 | tostring ),
    ( ([.rachaMax[] | select(.periodo=="00-24")][0].value) // "-" | tostring ),
    ( (.uvMax // "-") | tostring )
  ] | join($sep)
' | while IFS="$SEP" read -r fecha desc code tmin tmax stmin stmax pprec winddir windvel racha uv; do
    icon=$(aemet_icon "$code")
    dianombre=$(date -d "$fecha" +'%A %-d de %B' 2>/dev/null)
    dianombre="${dianombre^}"

    printf '\033[1m%s  %s\033[0m\n' "$icon" "$dianombre"
    printf '   %s\n' "$desc"
    printf '   🌡  %s / %s   (sensación %s / %s)\n' \
        "$(aemet_color_temp "$tmin")" "$(aemet_color_temp "$tmax")" \
        "$(aemet_color_temp "$stmin")" "$(aemet_color_temp "$stmax")"
    printf '   💧 %-16s 💨 %s %s km/h (rachas %s km/h)   ☀ UV %s\n' \
        "$(aemet_color_rain "$pprec")" "$winddir" "$windvel" "$racha" \
        "$(aemet_color_uv "$uv")"
    printf '   %3s°C \033[38;5;208m%s\033[0m %3s°C\n' \
        "$tmin" "$(aemet_temp_bar "$tmin" "$tmax" "$gmin" "$gmax" "$BARW")" "$tmax"
    echo "$LINEA"
done

echo
echo "Fuente: Agencia Estatal de Meteorologia (AEMET) - https://www.aemet.es"
} | tee "$REPORT_CACHE"
