#!/bin/sh
# Chuleta de atajos (Super+F1 y botón de waybar): si está abierta la cierra,
# si no, abre un foot flotante con keybinds.py dentro de less.
swaymsg -q '[app_id=keybinds-popup] kill' && exit 0

exec foot --app-id=keybinds-popup --title="Atajos de teclado" \
    -o colors-dark.alpha=1.0 -o pad=14x10 \
    -e env LESSUTFCHARDEF=e000-f8ff:p sh -c 'sleep 0.15; python3 "$HOME/.config/sway/scripts/keybinds.py" |
        less -R -S -c -~ --mouse -P " "'
