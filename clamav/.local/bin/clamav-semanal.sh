#!/usr/bin/env bash
# Análisis semanal de ~/Descargas con ClamAV (lo lanza clamav-semanal.timer).
# Deja registro en ~/.local/state/clamav-semanal.log y solo avisa si encuentra algo o falla.

dir="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Descargas")"
log="${XDG_STATE_HOME:-$HOME/.local/state}/clamav-semanal.log"
mkdir -p "$(dirname "$log")"

# Icono de la notificación: glifo de Nerd Font dibujado como PNG (se genera una vez)
glifo=$'\ue286'   # nf-fae-biohazard
fuente="$HOME/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf"
icono="${XDG_CACHE_HOME:-$HOME/.cache}/clamav-semanal/icono.png"
if [ ! -f "$icono" ] && [ -f "$fuente" ]; then
    mkdir -p "$(dirname "$icono")"
    magick -background none -fill '#e06c75' -font "$fuente" -pointsize 128 label:"$glifo" \
        -trim +repage -gravity center -extent '%[fx:max(w,h)]x%[fx:max(w,h)]' "$icono"
fi
[ -f "$icono" ] || icono=security-low

out="$(clamscan -r -i "$dir" 2>&1)"
rc=$?

{ echo "=== $(date '+%F %T') · $dir"; echo "$out"; echo; } >> "$log"
# Guarda solo las últimas 1000 líneas
tail -n 1000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"

case $rc in
    0) ;;
    1) notify-send -u critical -a ClamAV -i "$icono" "Amenaza en Descargas" \
           "$(grep 'FOUND$' <<< "$out" | sed "s|^$dir/||")" ;;
    *) notify-send -u normal -a ClamAV -i "$icono" "Error en el análisis semanal" \
           "Revisa $log" ;;
esac
exit 0
