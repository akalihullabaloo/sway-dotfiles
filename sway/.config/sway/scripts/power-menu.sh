#!/usr/bin/env bash
# Menu de energia (Ctrl+Alt+Supr): el conejo de la cabecera cambia segun
# la opcion resaltada. Implementado como rofi-script mode (man 5 rofi-script).
#
# Teclas: ↑/↓ mueven (y cambian la cara), Enter elige, 1-6 eligen directo,
# Esc cierra. Apagar, Reiniciar y Cerrar sesion piden confirmacion: el conejo
# pregunta y hay que volver a elegir la misma opcion.

# Ordenadas de menos a mas drastica
labels=("Bloquear" "Suspender" "Hibernar" "Cerrar sesión" "Reiniciar" "Apagar")
# Iconos Nerd Font (Material Design), todos del mismo juego para que midan igual
icons=($'\U000f033e' $'\U000f0904' $'\U000f04b2' $'\U000f0343' $'\U000f0709' $'\U000f0425')
N=${#labels[@]}

NL=$' '  # el protocolo de rofi-script es line-based; un \n real
              # cortaria el mensaje, asi que usamos el separador Unicode
              # de linea, que Pango si renderiza como salto visual.

# Cara del conejo para cada opcion (y para la pregunta de confirmacion)
face_for() {
    case "$1" in
        Bloquear)        printf '( -_-)' ;;
        Suspender)       printf '( -.-) z' ;;
        Hibernar)        printf '( -.-) zzZ' ;;
        "Cerrar sesión") printf '( ^_^)/' ;;
        Reiniciar)       printf '( o_O)' ;;
        Apagar)          printf '( x_x)' ;;
        confirmar)       printf '( O_O) ¿seguro?' ;;
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

# Pango centra cada linea por separado: se rellenan las tres lineas del
# conejo al mismo ancho (con espacio duro, que Pango no recorta) para que el
# dibujo se centre como bloque sin deformarse.
rabbit() {
    local lines=(' (\(\' " $(face_for "$1")" ' o_(")(")') w=0 l out=""
    for l in "${lines[@]}"; do (( ${#l} > w )) && w=${#l}; done
    for l in "${lines[@]}"; do
        while (( ${#l} < w )); do l+=$' '; done
        out+="$(escape_pango "$l")$NL"
    done
    printf '%s' "${out%"$NL"}"
}

# Linea gris bajo el conejo: tiempo encendido, o la pista para confirmar
hint() {
    local txt
    if [ -n "$1" ]; then
        txt="Enter otra vez para ${1,,}"
    else
        local s; s=$(cut -d. -f1 /proc/uptime)
        if (( s >= 86400 )); then txt="encendido $((s / 86400)) d $((s % 86400 / 3600)) h"
        else txt="encendido $((s / 3600)) h $((s % 3600 / 60)) min"; fi
    fi
    printf "<span size='small' foreground='#808080'>%s</span>" "$(escape_pango "$txt")"
}

find_index() {
    local text="$1"
    for i in "${!labels[@]}"; do
        [[ "$text" == *"${labels[$i]}" ]] && { echo "$i"; return; }
    done
    echo 0
}

# print_entries <indice resaltado> [opcion pendiente de confirmar]
print_entries() {
    local sel="$1" pending="$2" face="${labels[$1]}"
    [ -n "$pending" ] && face=confirmar
    for i in "${!labels[@]}"; do
        echo "${icons[$i]}  ${labels[$i]}"
    done
    echo -en "\0message\x1f$(rabbit "$face")$NL$(hint "$pending")\n"
    echo -en "\0data\x1f${pending:-none}\n"
    echo -en "\0keep-selection\x1ftrue\n"
    echo -en "\0new-selection\x1f$sel\n"
}

run() {
    case "$1" in
        Bloquear)        coproc ( loginctl lock-session >/dev/null 2>&1 ) ;;
        Suspender)       coproc ( systemctl suspend >/dev/null 2>&1 ) ;;   # swayidle bloquea antes (before-sleep)
        Hibernar)        coproc ( systemctl hibernate >/dev/null 2>&1 ) ;;
        "Cerrar sesión") coproc ( swaymsg exit >/dev/null 2>&1 ) ;;
        Reiniciar)       coproc ( systemctl reboot >/dev/null 2>&1 ) ;;
        Apagar)          coproc ( systemctl poweroff >/dev/null 2>&1 ) ;;
    esac
}

if [ -z "$ROFI_RETV" ]; then
    # Lanzamiento inicial (desde el atajo de teclado): arrancar rofi en modo script
    exec rofi -modi "energia:$0" -show energia \
        -kb-row-down '' -kb-row-up '' \
        -kb-custom-1 'Down' -kb-custom-2 'Up' \
        -kb-select-1 '1' -kb-select-2 '2' -kb-select-3 '3' \
        -kb-select-4 '4' -kb-select-5 '5' -kb-select-6 '6' \
        -theme-str "window {width: 320px; background-color: #0d0d0d;} listview {columns: 1; lines: $N; border: 0px;} inputbar {enabled: false;} message {border: 0px;} textbox {text-color: #25e712; horizontal-align: 0.5;} element {padding: 6px 8px 6px 82px;} element-text {horizontal-align: 0;}"
fi

case "$ROFI_RETV" in
    0)
        # Primera llamada del modo script: activar hotkeys y pintar conejo inicial
        echo -en "\0use-hot-keys\x1ftrue\n"
        echo -en "\0no-custom\x1ftrue\n"
        print_entries 0
        ;;
    1)
        # Entrada elegida (Enter, clic o 1-6)
        i=$(find_index "$1"); opt=${labels[$i]}
        case "$opt" in
            Apagar|Reiniciar|"Cerrar sesión")
                # Primera vez: el conejo pregunta. Segunda vez seguida: se ejecuta.
                if [ "$ROFI_DATA" = "$opt" ]; then run "$opt"
                else print_entries "$i" "$opt"; fi ;;
            *) run "$opt" ;;
        esac
        ;;
    10)
        # kb-custom-1 -> Down (moverse cancela la confirmacion pendiente)
        cur=$(find_index "$1")
        print_entries $(( (cur + 1) % N ))
        ;;
    11)
        # kb-custom-2 -> Up
        cur=$(find_index "$1")
        print_entries $(( (cur - 1 + N) % N ))
        ;;
esac
