#!/bin/bash
# Funciones y config compartidas para los scripts de tiempo con datos AEMET.

AEMET_API_KEY_FILE="$HOME/.config/waybar/aemet_api_key"
# Ubicacion de EJEMPLO (Madrid capital). Para usar la tuya, crea
# ~/.config/waybar/aemet_location (no se sube al repo) con:
#   AEMET_MUNICIPIO="xxxxx"   # codigo INE del municipio
#   AEMET_AREA="xx"           # zona de avisos AEMET
AEMET_MUNICIPIO="28079"  # Madrid capital
AEMET_AREA="72"          # Zona de avisos AEMET para la Comunidad de Madrid
AEMET_LOCATION_FILE="$HOME/.config/waybar/aemet_location"
[ -r "$AEMET_LOCATION_FILE" ] && . "$AEMET_LOCATION_FILE"
AEMET_AVISOS_CACHE="$HOME/.cache/aemet-avisos.json"

# Hace la peticion en dos pasos que exige la API de AEMET: primero pide el
# endpoint, que devuelve una URL temporal (de un solo uso) con los datos
# reales, y luego la descarga. Los ficheros de AEMET vienen en ISO-8859-15.
aemet_fetch() {
    local path="$1"
    local key
    key=$(cat "$AEMET_API_KEY_FILE" 2>/dev/null)
    if [ -z "$key" ]; then
        echo "ERROR: no se encontro la API key de AEMET en $AEMET_API_KEY_FILE" >&2
        return 1
    fi

    local step1
    step1=$(curl -s --max-time 10 "https://opendata.aemet.es/opendata/api/${path}?api_key=${key}")

    local estado
    estado=$(echo "$step1" | jq -r '.estado // empty' 2>/dev/null)
    if [ "$estado" != "200" ]; then
        local desc
        desc=$(echo "$step1" | jq -r '.descripcion // "Error desconocido de AEMET"' 2>/dev/null)
        echo "ERROR: ${desc:-sin respuesta de AEMET}" >&2
        return 1
    fi

    local url
    url=$(echo "$step1" | jq -r '.datos')
    curl -s --max-time 10 "$url" | iconv -f ISO-8859-15 -t UTF-8 2>/dev/null
}

# Traduce un codigo de estadoCielo de AEMET (p.ej. "11", "45", "12n") a un
# emoji. El sufijo "n" indica variante nocturna.
aemet_icon() {
    local code="$1"
    local base="${code%n}"
    local night=false
    [[ "$code" == *n ]] && night=true

    case "$base" in
        11) $night && echo "🌙" || echo "☀️" ;;
        12) $night && echo "🌙" || echo "🌤️" ;;
        13) $night && echo "☁️" || echo "⛅" ;;
        14|15|16) echo "☁️" ;;
        17) $night && echo "🌙" || echo "🌥️" ;;
        43|44|45|46) echo "🌦️" ;;          # lluvia escasa
        23|24|25|26) echo "🌧️" ;;          # lluvia
        71|72|73|74) echo "🌨️" ;;          # nieve escasa
        33|34|35|36) echo "❄️" ;;           # nieve
        51|52|53|54|61|62|63|64) echo "⛈️" ;; # tormenta
        81|82|83) echo "🌫️" ;;              # niebla/bruma/calima
        "") echo "❓" ;;
        *) echo "🌡️" ;;
    esac
}

# Colorea un valor de temperatura (°C) segun rango, para terminal ANSI.
aemet_color_temp() {
    local v="$1"
    local code
    if   [ "$v" -le 5 ];  then code="1;34"
    elif [ "$v" -le 15 ]; then code="36"
    elif [ "$v" -le 24 ]; then code="32"
    elif [ "$v" -le 32 ]; then code="33"
    elif [ "$v" -le 38 ]; then code="38;5;208"
    else                       code="1;31"
    fi
    printf '\033[%sm%s°C\033[0m' "$code" "$v"
}

# Colorea la probabilidad de precipitacion (%) segun la escala habitual.
aemet_color_rain() {
    local v="$1"
    local code
    if   [ "$v" -le 20 ]; then code="90"
    elif [ "$v" -le 50 ]; then code="36"
    elif [ "$v" -le 75 ]; then code="34"
    else                       code="1;34"
    fi
    printf '\033[%sm%s%%\033[0m' "$code" "$v"
}

# Colorea el indice UV segun la escala oficial (OMS): bajo/moderado/alto/
# muy alto/extremo.
aemet_color_uv() {
    local v="$1"
    [[ "$v" =~ ^[0-9]+$ ]] || { printf -- '-'; return; }
    local code label
    if   [ "$v" -le 2 ];  then code="32";        label="bajo"
    elif [ "$v" -le 5 ];  then code="33";        label="moderado"
    elif [ "$v" -le 7 ];  then code="38;5;208";  label="alto"
    elif [ "$v" -le 10 ]; then code="1;31";      label="muy alto"
    else                       code="1;35";      label="extremo"
    fi
    printf '\033[%sm%s (%s)\033[0m' "$code" "$v" "$label"
}

# Barra horizontal de rango min-max de temperatura de un dia, posicionada
# sobre una escala compartida (gmin-gmax, la de toda la semana) para poder
# comparar dias de un vistazo. $1=tmin $2=tmax $3=gmin $4=gmax $5=ancho
aemet_temp_bar() {
    awk -v tmin="$1" -v tmax="$2" -v gmin="$3" -v gmax="$4" -v width="${5:-30}" '
    BEGIN {
        range = gmax - gmin
        if (range <= 0) range = 1
        start = int((tmin - gmin) / range * width)
        end   = int((tmax - gmin) / range * width)
        if (start < 0) start = 0
        if (end >= width) end = width - 1
        if (end < start) end = start
        bar = ""
        for (i = 0; i < width; i++) {
            if (i >= start && i <= end) bar = bar "▓"
            else bar = bar "·"
        }
        print bar
    }'
}
