#!/usr/bin/env bash
# Menu de energia (Ctrl+Alt+Supr): el conejo de la cabecera cambia segun
# la opcion resaltada. Implementado como rofi-script mode (man 5 rofi-script).

ICON_LOCK='⚿'
ICON_POWER='⏻'
ICON_RESTART='⟲'
ICON_SLEEP='⏾'

labels=("Bloquear" "Apagar" "Reiniciar" "Hibernar")
icons=("$ICON_LOCK" "$ICON_POWER" "$ICON_RESTART" "$ICON_SLEEP")

NL=$' '  # el protocolo de rofi-script es line-based; un \n real
              # cortaria el mensaje, asi que usamos el separador Unicode
              # de linea, que Pango si renderiza como salto visual.

rabbit_for() {
    case "$1" in
        Bloquear)  printf ' (\\(\\%s ( -_-)%s o_(")(")' "$NL" "$NL" ;;
        Apagar)    printf ' (\\(\\%s ( x_x)%s o_(")(")' "$NL" "$NL" ;;
        Reiniciar) printf ' (\\(\\%s ( o_O)%s o_(")(")' "$NL" "$NL" ;;
        Hibernar)  printf ' (\\(\\%s ( -.-) zzZ%s o_(")(")' "$NL" "$NL" ;;
    esac
}

# -mesg / message se interpreta como marcado Pango: escapar & < >
# (en bash, "&" en el reemplazo de ${var//pat/rep} significa "lo encontrado";
# hay que escaparlo con \&)
escape_pango() {
    local s="$1"
    s="${s//&/\&amp;}"
    s="${s//</\&lt;}"
    s="${s//>/\&gt;}"
    printf '%s' "$s"
}

find_index() {
    local text="$1"
    for i in "${!labels[@]}"; do
        [[ "$text" == *"${labels[$i]}"* ]] && { echo "$i"; return; }
    done
    echo 0
}

print_entries() {
    local sel="$1"
    for i in "${!labels[@]}"; do
        echo "${icons[$i]} ${labels[$i]}"
    done
    echo -en "\0message\x1f$(escape_pango "$(rabbit_for "${labels[$sel]}")")\n"
    echo -en "\0keep-selection\x1ftrue\n"
    echo -en "\0new-selection\x1f$sel\n"
}

if [ -z "$ROFI_RETV" ]; then
    # Lanzamiento inicial (desde el atajo de teclado): arrancar rofi en modo script
    exec rofi -modi "energia:$0" -show energia \
        -kb-row-down '' -kb-row-up '' \
        -kb-custom-1 'Down' -kb-custom-2 'Up' \
        -theme-str 'window {width: 300px;} listview {columns: 1; lines: 4;} inputbar {enabled: false;} textbox {text-color: #25e712;} element-text {horizontal-align: 0.5;}'
fi

case "$ROFI_RETV" in
    0)
        # Primera llamada del modo script: activar hotkeys y pintar conejo inicial
        echo -en "\0use-hot-keys\x1ftrue\n"
        echo -en "\0no-custom\x1ftrue\n"
        print_entries 0
        ;;
    1)
        # Entrada seleccionada (Enter)
        case "$1" in
            *Bloquear) coproc ( loginctl lock-session >/dev/null 2>&1 ) ;;
            *Apagar) coproc ( systemctl poweroff >/dev/null 2>&1 ) ;;
            *Reiniciar) coproc ( systemctl reboot >/dev/null 2>&1 ) ;;
            *Hibernar) coproc ( systemctl hibernate >/dev/null 2>&1 ) ;;
        esac
        ;;
    10)
        # kb-custom-1 -> Down
        cur=$(find_index "$1")
        next=$(( (cur + 1) % 4 ))
        print_entries "$next"
        ;;
    11)
        # kb-custom-2 -> Up
        cur=$(find_index "$1")
        prev=$(( (cur - 1 + 4) % 4 ))
        print_entries "$prev"
        ;;
esac
