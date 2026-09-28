#!/bin/bash
# Reports connection type (wifi/ethernet/disconnected) as icon,
# with private + public IP in the tooltip, for waybar custom/network.

WIFI_ICON=$''
ETH_ICON=$''
DISC_ICON=$''

iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')

if [ -z "$iface" ]; then
    printf '{"text":"%s","tooltip":"Sin conexion","class":"disconnected"}\n' "$DISC_ICON"
    exit 0
fi

case "$iface" in
    wl*)
        icon="$WIFI_ICON"
        class="wifi"
        ;;
    *)
        icon="$ETH_ICON"
        class="ethernet"
        ;;
esac

priv_ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
[ -z "$priv_ip" ] && priv_ip="(sin IP)"

pub_ip=$(curl -s --max-time 3 https://icanhazip.com 2>/dev/null | tr -d '[:space:]')
[ -z "$pub_ip" ] && pub_ip="(no disponible)"

tooltip="Interfaz: ${iface}\\nIP privada: ${priv_ip}\\nIP publica: ${pub_ip}"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tooltip" "$class"
