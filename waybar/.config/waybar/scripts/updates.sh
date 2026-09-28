#!/bin/bash
# Reports available dnf updates count for waybar. Only shows when count > 0.
# Uses --cacheonly (fast, relies on dnf5-makecache.timer keeping cache fresh).

output=$(LC_ALL=C dnf check-update --quiet --cacheonly 2>/dev/null)
count=$(printf '%s\n' "$output" | grep -cE '^\S+\.\S+\s+\S+\s+\S+$')

if [ "$count" -gt 0 ]; then
    printf '{"text":"󰞦 %s","tooltip":"%s actualizaciones disponibles (dnf)","class":"has-updates"}\n' "$count" "$count"
else
    printf '{"text":""}\n'
fi
