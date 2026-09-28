#!/bin/bash
# Botones rapidos del panel de swaync.
#   quick.sh <boton> get     -> imprime true/false (update-command)
#   quick.sh <boton> toggle  -> aplica $SWAYNC_TOGGLE_STATE (command)
#   quick.sh <boton>         -> accion simple (botones normales)

export LC_ALL=C
# Lanza un programa grafico desligado de swaync (si no, se cierra con el comando del boton).
detach() { env -u LC_ALL setsid -f "$@" >/dev/null 2>&1 < /dev/null; }
on() { [ "$SWAYNC_TOGGLE_STATE" = "true" ]; }
bool() { "$@" >/dev/null && echo true || echo false; }
pp_get() { busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile | cut -d'"' -f2; }
pp_set() { busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s "$1"; }

case "$1:$2" in
    wifi:get)         bool grep -qx enabled <(nmcli radio wifi) ;;
    wifi:toggle)      on && nmcli radio wifi on || nmcli radio wifi off ;;
    bluetooth:get)    bool grep -q 'Soft blocked: no' <(rfkill list bluetooth) ;;
    bluetooth:toggle) on && rfkill unblock bluetooth || rfkill block bluetooth ;;
    mic:get)          bool grep -q 'Mute: no' <(pactl get-source-mute @DEFAULT_SOURCE@) ;;
    mic:toggle)       pactl set-source-mute @DEFAULT_SOURCE@ "$(on && echo 0 || echo 1)" ;;
    touch:get)        bool grep -q enabled <(swaymsg -t get_inputs | jq -r '.[] | select(.type=="touch") | .libinput.send_events') ;;
    touch:toggle)     swaymsg input type:touch events "$(on && echo enabled || echo disabled)" ;;
    performance:get)  bool grep -qx performance <(pp_get) ;;
    performance:toggle) on && pp_set performance || pp_set balanced ;;
    powersaver:get)   bool grep -qx power-saver <(pp_get) ;;
    powersaver:toggle)  on && pp_set power-saver || pp_set balanced ;;
    aviso:get)        bool jq -e '(.nivel // "verde") != "verde" and (.avisos | length) > 0' ~/.cache/aemet-avisos.json ;;
    aviso:toggle)     swaync-client -cp; detach ~/.config/waybar/scripts/weather-popup-launch.sh ;;
    calendar:)        swaync-client -cp; detach ~/.config/swaync/scripts/calendar-popup.sh ;;
    lock:)            swaync-client -cp; loginctl lock-session ;;
    power:)           swaync-client -cp; detach ~/.config/sway/scripts/power-menu.sh ;;
    *)                echo "uso: $0 <boton> [get|toggle]" >&2; exit 1 ;;
esac
