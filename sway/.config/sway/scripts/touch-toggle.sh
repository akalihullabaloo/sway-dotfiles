#!/bin/sh
# Super+Shift+T: activa/desactiva la pantalla táctil (por defecto desactivada,
# ver "input type:touch" en la config de sway) y avisa del estado.
swaymsg -q input type:touch events toggle
s=$(swaymsg -t get_inputs | jq -r '[.[] | select(.type == "touch")][0].libinput.send_events')
[ "$s" = enabled ] && msg=Activada || msg=Desactivada
notify-send -a "Pantalla táctil" -t 2000 "Pantalla táctil" "$msg"
