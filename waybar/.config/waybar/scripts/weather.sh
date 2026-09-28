#!/bin/bash
# Tiempo actual para waybar custom/weather, via AEMET OpenData (prediccion
# horaria del municipio configurado en aemet-common.sh).
source "$HOME/.config/waybar/scripts/aemet-common.sh"

data=$(aemet_fetch "prediccion/especifica/municipio/horaria/${AEMET_MUNICIPIO}")

if [ -z "$data" ]; then
    echo '{"text":"?","tooltip":"Servicio de tiempo (AEMET) no disponible"}'
    exit 0
fi

curh=$(date +%H)

# Separador de campo no imprimible (0x1f): con IFS=tab, "read" colapsa
# delimitadores consecutivos y desplazaria las columnas si algun campo
# (p.ej. la descripcion del cielo) queda vacio.
SEP=$'\x1f'

# Busca en las horas de hoy la primera igual o posterior a la hora actual
# (la prediccion horaria de AEMET solo incluye horas futuras del dia), y
# junta el resto de variables por el mismo periodo (los arrays no siempre
# estan alineados entre si). vientoAndRachaMax alterna entre un objeto con
# direccion/velocidad (viento medio) y otro solo con "value" (racha maxima).
result=$(echo "$data" | jq -r --arg h "$curh" --arg sep "$SEP" '
  .[0].prediccion.dia[0] as $today
  | ( [$today.estadoCielo[] | select(.periodo >= $h)][0] // $today.estadoCielo[-1] ) as $sky
  | $sky.periodo as $p
  | ( [$today.temperatura[]     | select(.periodo == $p)][0].value
      // [$today.temperatura[]  | select(.periodo >= $p)][0].value
      // $today.temperatura[-1].value ) as $temp
  | ( [$today.sensTermica[]     | select(.periodo == $p)][0].value // $temp ) as $feels
  | ( [$today.humedadRelativa[] | select(.periodo == $p)][0].value
      // $today.humedadRelativa[-1].value ) as $hum
  | ( [$today.vientoAndRachaMax[] | select(.periodo == $p and has("direccion"))][0] ) as $wind
  | ( [$today.vientoAndRachaMax[] | select(.periodo == $p and has("value"))][0].value // "-" ) as $racha
  | ( [$today.precipitacion[] | select(.periodo == $p)][0].value // "0" ) as $precip
  | ( ($today.probPrecipitacion[0].value) // 0 ) as $probprecip
  | [ ($sky.descripcion // "-"), ($sky.value // ""), ($temp|tostring), ($feels|tostring),
      ($hum|tostring), ($wind.direccion[0] // "-"), ($wind.velocidad[0] // "-"),
      ($racha|tostring), ($precip|tostring), ($probprecip|tostring) ] | join($sep)
' 2>/dev/null)

IFS="$SEP" read -r cond code temp feels hum winddir windvel racha precip probprecip <<< "$result"

if [ -z "$code" ] && [ -z "$temp" ]; then
    echo '{"text":"?","tooltip":"Servicio de tiempo (AEMET) no disponible"}'
    exit 0
fi

icon=$(aemet_icon "$code")

tooltip="${cond}, ${temp}°C (sensacion ${feels}°C)"
tooltip+="\\nHumedad: ${hum}%"
tooltip+="\\nViento: ${winddir} ${windvel} km/h (rachas ${racha} km/h)"
tooltip+="\\nPrecipitacion: ${precip} mm (prob. ${probprecip}%)"

# Si hay un aviso activo (nivel > verde), se añade una linea al principio.
# Lo lee de la cache que escribe aemet-avisos.sh; no gasta otra peticion.
if [ -f "$AEMET_AVISOS_CACHE" ]; then
    aviso_linea=$(jq -r '
        if (.nivel // "verde") == "verde" or (.avisos|length)==0 then empty
        else "⚠️ Aviso " + .nivel + ": " + (.avisos[0].evento) + "\\n"
        end
    ' "$AEMET_AVISOS_CACHE" 2>/dev/null)
    tooltip="${aviso_linea}${tooltip}"
fi

tooltip+="\\n\\nClic para ver el pronostico completo\\nDatos: AEMET"

# Mismo dato para el boton del tiempo del panel de swaync (en segundo plano).
[ -x "$HOME/.config/swaync/scripts/weather-button.sh" ] && \
    "$HOME/.config/swaync/scripts/weather-button.sh" "$icon" "$temp" "$cond" >/dev/null 2>&1 &

printf '{"text":"%s %s°","tooltip":"%s"}\n' "$icon" "$temp" "$tooltip"
