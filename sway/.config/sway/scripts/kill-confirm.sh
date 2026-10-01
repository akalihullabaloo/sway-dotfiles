#!/usr/bin/env bash
# Super+Shift+Q: cierra la ventana enfocada, pero si es un terminal con
# pestañas (foot-tmux.sh) pide confirmación antes. La opción por defecto es
# NO cerrar, así que Enter o Esc por error no pierden nada.

read -r id app pid < <(swaymsg -t get_tree | jq -r '
    .. | objects | select(.focused == true) | "\(.id) \(.app_id // "-") \(.pid // 0)"')
[ -z "$id" ] && exit 0

if [ "$app" != "foot-tmux" ]; then
    swaymsg -q "[con_id=$id] kill"
    exit 0
fi

# Cuántas pestañas/paneles hay en la sesión tmux de esa ventana
detail=""
cpid=$(pgrep -P "$pid" -f "^tmux" | head -1)
if [ -n "$cpid" ]; then
    sess=$(tmux list-clients -F '#{client_pid} #{session_name}' 2>/dev/null |
           awk -v p="$cpid" '$1 == p {print $2}')
    if [ -n "$sess" ]; then
        w=$(tmux list-windows -t "$sess" 2>/dev/null | wc -l)
        p=$(tmux list-panes -s -t "$sess" 2>/dev/null | wc -l)
        detail=" ($w pestaña$([ "$w" -ne 1 ] && echo s), $p panel$([ "$p" -ne 1 ] && echo es))"
    fi
fi

choice=$(printf '  No, dejarlo abierto\n  Sí, cerrar todo\n' | rofi -dmenu -i -no-custom \
    -p "" -mesg "¿Cerrar el terminal$detail?" -selected-row 0 \
    -theme-str 'window {width: 360px;} listview {lines: 2;} inputbar {enabled: false;}')

[[ $choice == *Sí* ]] && swaymsg -q "[con_id=$id] kill"
exit 0
