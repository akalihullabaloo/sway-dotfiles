#!/bin/bash
# Avisos meteorologicos activos de AEMET (zona 72 = Comunidad de Madrid),
# para waybar custom/aemet-avisos.
#
# Se ejecuta con poca frecuencia (ver "interval" en config.jsonc) porque la
# API de AEMET limita a ~1 peticion/minuto y este endpoint solo cambia un
# par de veces al dia. El resultado se cachea en $AEMET_AVISOS_CACHE para
# que weather.sh y weather-detail.sh puedan mostrarlo sin gastar otra
# peticion contra AEMET.
source "$HOME/.config/waybar/scripts/aemet-common.sh"

mkdir -p "$(dirname "$AEMET_AVISOS_CACHE")"

key=$(cat "$AEMET_API_KEY_FILE" 2>/dev/null)

estado=""
if [ -n "$key" ]; then
    step1=$(curl -s --max-time 10 "https://opendata.aemet.es/opendata/api/avisos_cap/ultimoelaborado/area/${AEMET_AREA}?api_key=${key}")
    estado=$(echo "$step1" | jq -r '.estado // empty' 2>/dev/null)
fi

if [ "$estado" = "200" ]; then
    url=$(echo "$step1" | jq -r '.datos')
    tmpdir=$(mktemp -d)
    curl -s --max-time 20 "$url" -o "$tmpdir/avisos.tar"
    tar xf "$tmpdir/avisos.tar" -C "$tmpdir" 2>/dev/null

    avisos_json="[]"
    max_rank=0
    max_nivel="verde"

    for f in "$tmpdir"/*.xml; do
        [ -f "$f" ] || continue
        evento=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="event"])' "$f" 2>/dev/null)
        nivel_i=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="parameter"][*[local-name()="valueName"][text()="AEMET-Meteoalerta nivel"]]/*[local-name()="value"])' "$f" 2>/dev/null)
        expira=$(xmllint --xpath 'string(//*[local-name()="info"][1]/*[local-name()="expires"])' "$f" 2>/dev/null)

        case "$nivel_i" in
            rojo) rank=3 ;;
            naranja) rank=2 ;;
            amarillo) rank=1 ;;
            *) rank=0 ;;
        esac

        if [ "$rank" -gt 0 ]; then
            avisos_json=$(jq -c --arg e "$evento" --arg n "$nivel_i" --arg x "$expira" \
                '. + [{"evento":$e,"nivel":$n,"expira":$x}]' <<< "$avisos_json")
        fi
        if [ "$rank" -gt "$max_rank" ]; then
            max_rank=$rank
            max_nivel="$nivel_i"
        fi
    done
    rm -rf "$tmpdir"

    jq -n --arg nivel "$max_nivel" --arg checked "$(date -Iseconds)" --argjson avisos "$avisos_json" \
        '{nivel: $nivel, checked: $checked, avisos: $avisos}' > "$AEMET_AVISOS_CACHE"
elif [ ! -f "$AEMET_AVISOS_CACHE" ]; then
    # Primera ejecucion y la peticion ha fallado (limite de peticiones o sin
    # red): dejamos constancia de que aun no se ha podido comprobar, en vez
    # de asumir "sin avisos".
    jq -n --arg checked "$(date -Iseconds)" '{nivel: "desconocido", checked: $checked, avisos: []}' \
        > "$AEMET_AVISOS_CACHE"
fi
# Si la peticion falla pero ya habia una cache previa, se deja tal cual
# (mejor mostrar el ultimo estado conocido que borrarlo).

jq -c '
  {verde: "", amarillo: "🟨", naranja: "🟧", rojo: "🟥", desconocido: ""} as $icons
  | ($icons[.nivel] // "") as $icon
  | {
      text: $icon,
      class: .nivel,
      tooltip: (
        if (.avisos | length) == 0 then
          "AEMET: sin avisos activos en Madrid"
        else
          "Avisos AEMET activos en Madrid:\n" +
          ([ .avisos[] | "- \(.evento) (hasta \(.expira))" ] | join("\n"))
        end
      )
    }
' "$AEMET_AVISOS_CACHE"
