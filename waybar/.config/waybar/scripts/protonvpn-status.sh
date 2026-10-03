#!/bin/bash
# Reports Proton VPN state for waybar custom/protonvpn.
# The Proton app brings up a NetworkManager WireGuard connection named
# "ProtonVPN <server>" on iface proton0. Disconnected prints empty text so the
# module hides itself (its tray icon stays in the group/extras drawer).

icon=$'󰖂'

conn=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
    | awk -F: '$2 == "wireguard" && $1 ~ /^ProtonVPN / {print $1; exit}')

if [[ -n $conn ]]; then
    server=${conn#ProtonVPN }

    # Bandera del país de salida: "ES#268" -> ES, gratis "NL-FREE#3" -> NL,
    # estados "US-NY#5" -> US; Secure Core entra por CH/IS/SE: "CH-ES#1" -> ES.
    # Proton usa UK, pero la bandera es GB.
    read -r cc cc2 _ <<<"$(tr '#-' '  ' <<<"$server")"
    [[ $cc =~ ^(CH|IS|SE)$ && $cc2 =~ ^[A-Z]{2}$ ]] && cc=$cc2
    [[ $cc =~ ^[A-Z]{2}$ ]] || cc=
    [[ $cc == UK ]] && cc=GB
    flag=
    for ((i = 0; i < ${#cc}; i++)); do
        printf -v ord '%d' "'${cc:i:1}"
        printf -v ch "\\U$(printf '%08X' $((0x1F1E6 + ord - 65)))"
        flag+=$ch
    done
    [[ -n $flag ]] && icon="$icon $flag"
    killswitch=no
    nmcli -t -f NAME connection show --active 2>/dev/null | grep -q '^pvpn-killswitch' && killswitch=sí
    printf '{"text":"%s %s","class":"connected","tooltip":"Proton VPN conectada\\nServidor: %s\\nKill switch: %s"}\n' \
        "$icon" "$server" "$server" "$killswitch"
else
    printf '{"text":"","class":"disconnected"}\n'
fi
