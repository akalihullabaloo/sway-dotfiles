#!/bin/bash
# Modulo waybar de bateria con dos vistas, alternables con clic:
#   icon  -> pila de Nerd Font por niveles + porcentaje (pila con rayo al cargar)
#   meter -> pila + medidor de 5 segmentos + porcentaje
# battery.sh toggle cambia la vista y refresca el modulo (signal 8).

MODE_FILE="$HOME/.cache/waybar-battery-mode"
SIGNAL=8

if [ "$1" = "toggle" ]; then
    [ "$(cat "$MODE_FILE" 2>/dev/null)" = "meter" ] && echo icon > "$MODE_FILE" || echo meter > "$MODE_FILE"
    pkill -RTMIN+$SIGNAL waybar
    exit 0
fi

bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -z "$bat" ] && { echo '{"text":""}'; exit 0; }

cap=$(cat "$bat/capacity")
status=$(cat "$bat/status")
mode=$(cat "$MODE_FILE" 2>/dev/null || echo icon)

# Pila por niveles de 10 % (0..100 -> 11 glifos)
levels=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
pila=${levels[$(( (cap + 5) / 10 ))]}
# Pila con rayo dentro al cargar, mismos niveles
charging=(󰢟 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
pila_carga=${charging[$(( (cap + 5) / 10 ))]}

# Clase CSS: mismos nombres que el modulo battery original
case "$status" in
    Charging)                cls=charging ;;
    Full|"Not charging")     cls=plugged ;;
    *)  if   [ "$cap" -le 15 ]; then cls=critical
        elif [ "$cap" -le 30 ]; then cls=warning
        else cls=discharging; fi ;;
esac

# Tiempo restante (hasta llena o hasta vacia), a partir de charge_* o energy_*
now=$(cat "$bat/charge_now" 2>/dev/null || cat "$bat/energy_now" 2>/dev/null)
full=$(cat "$bat/charge_full" 2>/dev/null || cat "$bat/energy_full" 2>/dev/null)
rate=$(cat "$bat/current_now" 2>/dev/null || cat "$bat/power_now" 2>/dev/null)
timestr=""
if [ -n "$rate" ] && [ "$rate" -gt 0 ]; then
    case "$status" in
        Charging)    mins=$(( (full - now) * 60 / rate )); timestr="$((mins/60)) h $((mins%60)) min hasta llenarse" ;;
        Discharging) mins=$(( now * 60 / rate ));          timestr="$((mins/60)) h $((mins%60)) min restantes" ;;
    esac
fi

if [ "$mode" = "meter" ]; then
    filled=$(( cap / 20 )); [ "$cap" -ge 5 ] && [ "$filled" -lt 1 ] && filled=1
    meter=""
    for i in 1 2 3 4 5; do [ "$i" -le "$filled" ] && meter+="■" || meter+="□"; done
    if [ "$cls" = charging ]; then text="󰂄 $meter $cap%"; else text="$pila $meter $cap%"; fi
else
    icon=$pila
    [ "$cls" = charging ] && icon=$pila_carga
    text="$icon <span size='85%'>$cap%</span>"
fi

case "$status" in
    Charging) st="Cargando" ;; Discharging) st="Descargando" ;; Full) st="Cargada" ;;
    "Not charging") st="Enchufada (sin cargar)" ;; *) st="$status" ;;
esac
tooltip="$cap% · $st${timestr:+$'\n'$timestr}"$'\n'"Clic: cambiar vista"

jq -cn --arg t "$text" --arg tt "$tooltip" --arg c "$cls" --argjson p "$cap" \
    '{text:$t, tooltip:$tt, class:$c, percentage:$p}'
