#!/bin/bash
# Minivisualizador para waybar (custom/cava): cava en modo raw ASCII (20
# barras, niveles 0-7) convertido en 10 caracteres segun el estilo elegido.
#   cava-bars.sh        -> modulo continuo: una linea JSON por fotograma
#                          (texto vacio = modulo oculto en silencio)
#   cava-bars.sh next   -> pasa al siguiente estilo (clic derecho en waybar)
# El estilo se guarda en ~/.cache/waybar-cava-style y el modulo lo relee solo.
# Sensibilidad: noise_reduction (mas bajo = reacciona mas rapido).

STYLES=(puntos braille-doble braille-saltarin huecos cuadros estrellas rombos corazones)
STATE="$HOME/.cache/waybar-cava-style"

if [ "$1" = next ]; then
    cur=$(cat "$STATE" 2>/dev/null)
    for i in "${!STYLES[@]}"; do [ "${STYLES[$i]}" = "$cur" ] && break; done
    [ "${STYLES[$i]}" = "$cur" ] && i=$(( (i + 1) % ${#STYLES[@]} )) || i=0
    echo "${STYLES[$i]}" > "$STATE"
    exit 0
fi

# Nivel 0-7 -> caracter. Los niveles se agrupan para que todos los tamanos
# salgan a menudo (con musica casi todo cae en 3-5).
set_style() {
    style=$1
    case $style in
        braille-saltarin) GLYPHS=(⣀ ⣀ ⣀ ⠤ ⠒ ⠒ ⠉ ⠉) ;;
        huecos)           GLYPHS=(○ ○ ○ ◎ ◎ ● ● ●) ;;
        cuadros)          GLYPHS=(▫ ▫ ▫ ▪ ▪ ■ ■ ■) ;;
        estrellas)        GLYPHS=(· · · ✦ ✦ ★ ★ ★) ;;
        rombos)           GLYPHS=(⋄ ⋄ ⋄ ◇ ◇ ◆ ◆ ◆) ;;
        corazones)        GLYPHS=(· · · ♡ ♡ ♥ ♥ ♥) ;;
        braille-doble)    ;;   # usa la tabla BD
        *)                style=puntos; GLYPHS=(· · · • • ● ● ●) ;;
    esac
}

# braille-doble: cada caracter braille lleva 2 barras (columna izquierda y
# derecha) de 1 a 4 puntos, llenandose desde abajo. BD[izq*8+der].
DOTS=(1 1 1 2 3 3 4 4)          # nivel 0-7 -> puntos encendidos
LBIT=(0x40 0x04 0x02 0x01)      # puntos 7,3,2,1 (abajo -> arriba)
RBIT=(0x80 0x20 0x10 0x08)      # puntos 8,6,5,4
BD=()
for l in {0..7}; do
    for r in {0..7}; do
        code=0x2800
        for ((k = 0; k < DOTS[l]; k++)); do code=$((code | LBIT[k])); done
        for ((k = 0; k < DOTS[r]; k++)); do code=$((code | RBIT[k])); done
        printf -v hex '%04x' "$code"
        printf -v "BD[l*8+r]" "\\u$hex"
    done
done

cfg="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.conf"
cat > "$cfg" <<CONF
[general]
bars = 20
framerate = 30
autosens = 1
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
channels = stereo
[smoothing]
noise_reduction = 60
CONF

# Si waybar se reinicia, que no quede un cava huerfano
trap 'kill 0' EXIT

set_style "$(cat "$STATE" 2>/dev/null)"
prev="" frame=0
cava -p "$cfg" | while IFS=';' read -ra v; do
    # Releer el estilo cada ~0,3 s (cambia con el clic derecho)
    if (( ++frame % 10 == 0 )); then
        s=""; [ -f "$STATE" ] && s=$(<"$STATE")
        [ -n "$s" ] && [ "$s" != "$style" ] && set_style "$s"
    fi

    out=""
    if [[ ${v[*]} =~ [1-7] ]]; then
        for ((i = 0; i < 20; i += 2)); do
            if [ "$style" = braille-doble ]; then
                out+=${BD[v[i] * 8 + v[i + 1]]}
            else
                out+=${GLYPHS[(v[i] + v[i + 1] + 1) / 2]}
            fi
        done
    fi
    [[ $out == "$prev" ]] && continue
    prev=$out
    printf '{"text":"%s","class":"%s","tooltip":"Estilo: %s\\nClic: ventana grande · Clic derecho: cambiar estilo"}\n' \
        "$out" "$style" "$style"
done
