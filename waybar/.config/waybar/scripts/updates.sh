#!/bin/bash
# Reports available dnf updates count for waybar. Only shows when count > 0.
# Sin --cacheonly: dnf renueva la caché del usuario cuando caduca (updates 6h,
# resto 7d). El timer dnf-makecache solo refresca la de root, no esta.
# Sin red o si tarda demasiado, no muestra nada.

output=$(LC_ALL=C timeout 120 dnf check-update --quiet 2>/dev/null)
count=$(printf '%s\n' "$output" | grep -cE '^\S+\.\S+\s+\S+\s+\S+$')

if [ "$count" -gt 0 ]; then
    printf '{"text":"󰓦 %s","tooltip":"%s actualizaciones disponibles (dnf)","class":"has-updates"}\n' "$count" "$count"
else
    printf '{"text":""}\n'
fi
