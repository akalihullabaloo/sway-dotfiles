#!/bin/bash
# Refresca en segundo plano la cache del pronostico completo
# (~/.cache/aemet-weather-report.txt), para que al hacer clic en el modulo
# del tiempo casi siempre haya un pronostico reciente disponible al
# instante, incluso si esa peticion en concreto topa con el limite de
# AEMET. No se muestra nada en la barra (modulo invisible), solo usa el
# "interval" de waybar como planificador.
"$HOME/.config/waybar/scripts/weather-report.sh" > /dev/null
echo '{"text":""}'
