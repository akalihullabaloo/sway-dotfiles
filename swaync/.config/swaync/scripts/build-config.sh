#!/bin/bash
# Genera ~/.config/swaync/config.json (lo que lee swaync) a partir de la
# plantilla config.base.json + las etiquetas dinamicas guardadas en cache
# por weather-button.sh y calendar-button.sh.
# config.json no se sube al repo: cambia solo con el tiempo y la fecha.
#
# Uso: build-config.sh              -> genera y recarga swaync si ha cambiado
#      build-config.sh --no-reload  -> solo genera (antes de arrancar swaync)
# Tras editar config.base.json, ejecutalo para aplicar los cambios.

dir="$HOME/.config/swaync"
base="$dir/config.base.json"
cfg="$dir/config.json"
labels="$HOME/.cache/swaync-labels"

read_label() { [ -f "$labels/$1" ] && cat "$labels/$1"; }

tiempo=$(read_label tiempo)
cal_head=$(read_label cal-head)
cal_grid=$(read_label cal-grid)

tmp=$(mktemp "$cfg.XXXXXX") || exit 1
if ! jq --arg t "$tiempo" --arg h "$cal_head" --arg g "$cal_grid" '
        (if $t != "" then ."widget-config"."buttons-grid#tiempo".actions[0].label = $t else . end)
      | (if $h != "" then ."widget-config"."menubar#cal"."menu#cal".label = $h else . end)
      | (if $g != "" then ."widget-config"."menubar#cal"."menu#cal".actions[0].label = $g else . end)
    ' "$base" > "$tmp"; then
    rm -f "$tmp"
    exit 1
fi

# Solo reemplazar y recargar si ha cambiado algo, para no parpadear
if cmp -s "$tmp" "$cfg"; then
    rm -f "$tmp"
    exit 0
fi
chmod 644 "$tmp"
mv "$tmp" "$cfg"
[ "$1" = "--no-reload" ] || swaync-client -R -sw >/dev/null 2>&1
exit 0
