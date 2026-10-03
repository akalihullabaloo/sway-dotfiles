#!/usr/bin/env bash
# Cambia el color de acento de todo el escritorio.
# Uso: theme.sh            -> selector en rofi con muestras de color
#      theme.sh <tema>     -> aplica un tema (p. ej. "06-azul" o "azul")
#      theme.sh --current  -> regenera los colores del tema actual (p. ej. tras clonar)
#
# Los temas son ~/.config/themes/*.theme. Cada programa lee su color de un
# archivo generado aqui (colors.*), que no se sube al repo.

THEMES="$HOME/.config/themes"
STATE="$HOME/.local/state/theme-current"
C="$HOME/.config"

find_theme() {
    local t="$1"
    [ -f "$THEMES/$t.theme" ] && { echo "$THEMES/$t.theme"; return; }
    ls "$THEMES"/*-"$t".theme 2>/dev/null | head -1
}

select_theme() {
    pgrep -xu "$USER" rofi >/dev/null && exit 0
    local files=("$THEMES"/*.theme) cur idx=0 i=0 f
    cur=$(cat "$STATE" 2>/dev/null)
    for f in "${files[@]}"; do [ "$(basename "$f" .theme)" = "$cur" ] && idx=$i; i=$((i + 1)); done
    choice=$(for f in "${files[@]}"; do
                 ( . "$f"; printf "<span color='%s'>██████</span>   %s\n" "$ACCENT" "$NAME" )
             done | rofi -dmenu -i -markup-rows -p "Tema" -format i -selected-row "$idx" \
                         -theme-str 'window {width: 360px;} listview {lines: 10;}')
    [ -z "$choice" ] && exit 0
    basename "${files[$choice]}" .theme
}

case "$1" in
    "")        name=$(select_theme) || exit 0; [ -z "$name" ] && exit 0 ;;
    --current) name=$(cat "$STATE" 2>/dev/null); name=${name:-01-naranja} ;;
    *)         name="$1" ;;
esac

file=$(find_theme "$name")
if [ -z "$file" ]; then
    notify-send -a "Tema" "Tema no encontrado" "$name"
    exit 1
fi
. "$file"
name=$(basename "$file" .theme)
hex=${ACCENT#\#}
rgb="$((16#${hex:0:2}));$((16#${hex:2:2}));$((16#${hex:4:2}))"

# --- Generar colores para cada programa ---
printf 'set $accent %s\n' "$ACCENT" > "$C/sway/colors.conf"

printf '@define-color accent %s;\n' "$ACCENT" > "$C/waybar/colors.css"

cat > "$C/waybar/colors.jsonc" <<EOF
// Generado por theme.sh ($NAME). No editar: se sobrescribe al cambiar de tema.
{
    "clock": {
        "tooltip-format": "<b>{:L%A, %d de %B de %Y</b>\n<span color='#808080'>Semana %V · día %j del año</span>}\n\n<tt>{calendar}</tt>\n\n<span color='$ACCENT'><b>Otras zonas</b></span>\n{tz_list}",
        "calendar": {
            "format": {
                "months":   "<span color='$ACCENT'><b>{}</b></span>",
                "weekdays": "<span color='$ACCENT'>{}</span>",
                "today":    "<span background='$ACCENT' color='#0d0d0d'><b>{}</b></span>"
            }
        }
    }
}
EOF

printf ':root {\n  --accent: %s;\n}\n' "$ACCENT" > "$C/swaync/colors.css"

printf '* {\n    accent:   %s;\n    border-c: %s;\n}\n' "$ACCENT" "$ACCENT" > "$C/rofi/colors.rasi"

printf '$accent: %s;\n' "$ACCENT" > "$C/eww/colors.scss"

printf '[colors-dark]\ncursor=0d0d0d %s\nregular5=%s\nbright5=%s\n' \
    "$hex" "$hex" "${ACCENT_BRIGHT#\#}" > "$C/foot/colors.ini"

printf '38;2;%s\n' "$rgb" > "$C/fastfetch/accent"

# tmux: copia las líneas con el naranja por defecto de tmux.conf cambiando el color
{
    echo "# Generado por theme.sh ($NAME). No editar: se sobrescribe al cambiar de tema."
    grep -i '#df6124' "$C/tmux/tmux.conf" | grep -v '^#' | sed "s/#df6124/$ACCENT/gI"
} > "$C/tmux/colors.conf"

mkdir -p "$C/dunst/dunstrc.d"
printf '[global]\n    frame_color = "%s"\n' "$ACCENT" > "$C/dunst/dunstrc.d/99-theme.conf"

# cava: base (config.base) + degradado de abajo arriba: acento oscuro -> acento -> variante clara
if [ -f "$C/cava/config.base" ]; then
    dark=$(printf '#%02x%02x%02x' $((16#${hex:0:2} * 55 / 100)) $((16#${hex:2:2} * 55 / 100)) $((16#${hex:4:2} * 55 / 100)))
    {
        echo "# Generado por theme.sh ($NAME). No editar: edita config.base."
        cat "$C/cava/config.base"
        printf "\n[color]\nbackground = '#0d0d0d'\ngradient = 1\ngradient_count = 3\n"
        printf "gradient_color_1 = '%s'\ngradient_color_2 = '%s'\ngradient_color_3 = '%s'\n" \
            "$dark" "$ACCENT" "$ACCENT_BRIGHT"
    } > "$C/cava/config"
fi

mkdir -p "$(dirname "$STATE")"
echo "$name" > "$STATE"

# --- Recargar lo que este en marcha ---
[ -n "$SWAYSOCK" ] && swaymsg -q reload
pgrep -xu "$USER" waybar >/dev/null && pkill -SIGUSR2 -xu "$USER" waybar
pgrep -xu "$USER" swaync  >/dev/null && swaync-client -rs >/dev/null 2>&1
if pgrep -xu "$USER" eww >/dev/null; then
    # Tras el reload el widget tarda unos segundos en volver (re-ejecuta sus
    # consultas); si a los 5 s no ha vuelto, se abre a mano.
    eww reload >/dev/null 2>&1
    (
        for _ in $(seq 10); do
            sleep 0.5
            eww active-windows 2>/dev/null | grep -q desktop-info && exit 0
        done
        eww open desktop-info >/dev/null 2>&1
    ) &
fi
tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null
pgrep -xu "$USER" dunst   >/dev/null && dunstctl reload >/dev/null 2>&1
pkill -USR1 -xu "$USER" cava 2>/dev/null   # cava relee su config con SIGUSR1

[ "$1" != "--current" ] && notify-send -a "Tema" -t 2000 \
    -h string:x-canonical-private-synchronous:theme "Tema: $NAME" "Terminales nuevas usarán el color nuevo"
exit 0
