#!/bin/sh
# foot con pestañas y divisiones (tmux). Cada ventana es su propia sesión y
# se cierra con ella, como un terminal normal. Atajos: ~/.config/tmux/tmux.conf
# app-id foot-tmux: kill-confirm.sh pide confirmación antes de cerrarla.
# alpha 0.95, casi sólido (foot normal 0.80, más transparente).
exec foot --app-id=foot-tmux -o colors-dark.alpha=0.95 -e tmux new-session \; set-option destroy-unattached on
