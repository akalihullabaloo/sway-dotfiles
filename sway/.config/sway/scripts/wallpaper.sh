#!/usr/bin/env bash
# Cambia el fondo de pantalla (swaybg) recorriendo ~/Imágenes/Fondos.
# Uso: wallpaper.sh next | prev | random | select | restore
#   select  -> cuadricula de miniaturas en rofi para elegir el fondo
#   restore -> se usa al arrancar Sway; pone el ultimo fondo elegido.
#              Si Azote guardo un fondo despues (~/.azotebg mas reciente), respeta ese.

DIR="${WALLPAPER_DIR:-$HOME/Imágenes/Fondos}"   # otra carpeta: WALLPAPER_DIR=/ruta
STATE="$HOME/.local/state/wallpaper-current"
AZOTE="$HOME/.azotebg"
FALLBACK="$HOME/.local/share/azote/sample/azote-wallpaper2.png"
THUMBS="$HOME/.cache/wallpaper-thumbs"

mkdir -p "$(dirname "$STATE")"

mapfile -t WALLS < <(find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)

apply() {
    local img="$1"
    local old
    old=$(pgrep -xu "$USER" swaybg)
    # Lanzar el nuevo antes de matar el viejo para evitar parpadeo
    swaybg -o '*' -i "$img" -m fill >/dev/null 2>&1 &
    disown
    sleep 0.3
    [ -n "$old" ] && kill $old 2>/dev/null
    printf '%s\n' "$img" > "$STATE"
}

notify() {
    local n="$1" total="$2" img="$3"
    notify-send -a "Fondo" -t 2000 -i "$img" \
        -h string:x-canonical-private-synchronous:wallpaper \
        "Fondo $n/$total" "$(basename "$img")"
}

current=$(cat "$STATE" 2>/dev/null)

case "$1" in
    restore)
        if [ -x "$AZOTE" ] && { [ ! -f "$STATE" ] || [ "$AZOTE" -nt "$STATE" ]; }; then
            exec "$AZOTE"
        fi
        [ -f "$current" ] || current="${WALLS[0]:-$FALLBACK}"
        apply "$current"
        exit 0
        ;;
    next|prev|random|select) ;;
    *) echo "Uso: $0 next|prev|random|select|restore" >&2; exit 1 ;;
esac

total=${#WALLS[@]}
if [ "$total" -eq 0 ]; then
    notify-send -a "Fondo" "Sin fondos" "No hay imagenes en $DIR"
    exit 1
fi

# Posicion del fondo actual en la lista (-1 si no esta)
idx=-1
for i in "${!WALLS[@]}"; do
    [ "${WALLS[$i]}" = "$current" ] && { idx=$i; break; }
done

case "$1" in
    next)   idx=$(( (idx + 1) % total )) ;;
    prev)   [ "$idx" -lt 0 ] && idx=0; idx=$(( (idx - 1 + total) % total )) ;;
    select)
        # Si rofi ya esta abierto, no abrir otro
        pgrep -xu "$USER" rofi >/dev/null && exit 0
        mkdir -p "$THUMBS"
        for w in "${WALLS[@]}"; do
            t="$THUMBS/$(basename "$w").png"
            if [ ! -f "$t" ] || [ "$w" -nt "$t" ]; then
                magick "$w[0]" -thumbnail 480x270^ -gravity center -extent 480x270 "$t" 2>/dev/null
            fi
        done
        [ "$idx" -lt 0 ] && idx=0
        choice=$(for w in "${WALLS[@]}"; do
                     n=$(basename "$w")
                     printf '%s\0icon\x1f%s\n' "${n%.*}" "$THUMBS/$n.png"
                 done | rofi -dmenu -i -p "Fondo" -format i -selected-row "$idx" \
                             -show-icons -theme "$HOME/.config/rofi/wallpaper.rasi")
        [ -z "$choice" ] && exit 0
        idx=$choice
        ;;
    random)
        new=$idx
        if [ "$total" -gt 1 ]; then
            while [ "$new" -eq "$idx" ]; do new=$(( RANDOM % total )); done
        else
            new=0
        fi
        idx=$new
        ;;
esac

apply "${WALLS[$idx]}"
notify $((idx + 1)) "$total" "${WALLS[$idx]}"
