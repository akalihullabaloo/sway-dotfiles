#!/bin/bash
# Modulo waybar para swaync: reenvia los eventos de swaync-client ocultando el "0"
# y anadiendo un tooltip con la ayuda de los clics.

swaync-client -swb | jq --unbuffered -c '
    if .text == "0" then .text = "" | .tooltip = "Sin notificaciones"
    else .tooltip = "\(.text) notificaciones" end
    | .tooltip += "\nClic: panel | Derecho: No molestar | Central: borrar"
    | if (.class | tostring | test("dnd")) then .tooltip = "[No molestar activado]\n" + .tooltip else . end'
