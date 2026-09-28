# dotfiles · aKali

Mi escritorio **Sway** en Fedora: barra waybar con tiempo de AEMET, notificaciones con swaync,
widget de escritorio con eww, selector de fondos con miniaturas en rofi y terminal foot con
cabecera de fastfetch. Paleta oscura con **color de acento intercambiable** (10 temas, naranja por defecto).

![Escritorio](capturas/escritorio.jpg)

## Capturas

Selector de temas de color (`Super+Alt+T`) y algunos de los 10 temas. El color de acento cambia a la vez
en sway, waybar, swaync, rofi, eww, foot y fastfetch:

![Selector de temas](capturas/selector-temas.jpg)
![Ejemplos de temas](capturas/temas.jpg)

| Panel de swaync (`Super+N`) | Notificaciones emergentes |
|---|---|
| ![Panel de swaync](capturas/panel-swaync.jpg) | ![Notificaciones](capturas/notificaciones.jpg) |

Selector de fondos con miniaturas (`Super+Alt+W`) y dos ejemplos de fondo con otro tema:

![Selector de fondos](capturas/selector-fondos.jpg)
![Ejemplos de fondos](capturas/fondos.jpg)

## Módulos

Cada carpeta es un paquete de [GNU Stow](https://www.gnu.org/software/stow/) y se puede instalar por separado.

| Módulo | Qué contiene |
|---|---|
| `sway` | Config de Sway, atajos, bloqueo/idle, menú de energía y script de fondos (`scripts/wallpaper.sh`) |
| `waybar` | Barra con módulos propios (tiempo y avisos AEMET, red, batería, micro, webcam, actualizaciones) y la chuleta de atajos |
| `swaync` | Centro de notificaciones con botones rápidos, tiempo y calendario |
| `eww` | Widget de información en el escritorio |
| `rofi` | Lanzador de aplicaciones y selector de fondos con miniaturas (`wallpaper.rasi`) |
| `foot` | Terminal |
| `fastfetch` | Cabecera del terminal (logo ASCII del conejo) |
| `zsh` | `.zshrc` y tema Powerlevel10k (`.p10k.zsh`) |
| `gtklock` | Pantalla de bloqueo |
| `thunar` | Atajos y acciones personalizadas del gestor de archivos |
| `dunst` | Notificaciones (alternativa a swaync) |
| `themes` | Temas de color: un archivo `.theme` por color de acento |
| `systemd` | Complemento del servicio de swaync que genera su `config.json` al arrancar |

## Atajos destacados

| Atajo | Acción |
|---|---|
| `Super+F1` | Chuleta con todos los atajos |
| `Super+Alt+T` | Cambiar tema de color |
| `Super+Alt+W` | Selector de fondos con miniaturas |
| `Super+Alt+←/→` | Fondo anterior / siguiente |
| `Super+Alt+R` | Fondo al azar |
| `Super+N` | Panel de notificaciones |
| `Ctrl+Alt+Supr` | Menú de energía |

## Instalación

```bash
# Dependencias (Fedora)
sudo dnf install sway swaybg swayidle waybar rofi swaync foot fastfetch gtklock thunar \
    stow jq curl libxml2 ImageMagick playerctl brightnessctl pulseaudio-utils \
    grim slurp satty wl-mirror wl-clipboard libnotify pavucontrol zsh \
    jetbrains-mono-fonts fontawesome-6-free-fonts papirus-icon-theme
# eww no está en los repos de Fedora: ver https://github.com/elkowar/eww
# Powerlevel10k: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k
# Fuente de iconos: JetBrainsMono Nerd Font (https://www.nerdfonts.com)

git clone https://github.com/akalihullabaloo/sway-dotfiles.git ~/dotfiles
cd ~/dotfiles
stow sway waybar swaync eww rofi foot fastfetch zsh gtklock thunar themes   # o solo los que quieras
stow --no-folding systemd   # systemd no admite carpetas de complementos enlazadas
systemctl --user daemon-reload

# Generar los colores del tema (imprescindible la primera vez)
~/.config/sway/scripts/theme.sh --current
```

Si ya existe alguno de esos archivos, `stow` avisa y no toca nada: muévelo antes a otro sitio.

### Temas de color

`Super+Alt+T` abre un selector con muestras de color. El script `sway/.config/sway/scripts/theme.sh`
genera un archivo de colores para cada programa (`colors.conf`, `colors.css`, `colors.rasi`…, que no
se suben al repo) y recarga sway, waybar, swaync y eww. Las terminales nuevas usan el color nuevo.

Temas incluidos: Naranja, Ámbar, Rojo, Rosa, Morado, Azul, Cian, Menta, Verde Matrix y Monocromo.
Para crear uno, copia un archivo de `themes/.config/themes/` y cambia sus valores:

```bash
NAME="Mi color"
ACCENT="#rrggbb"          # color principal
ACCENT_BRIGHT="#rrggbb"   # variante clara (terminal)
```

### Panel de swaync

swaync no admite texto dinámico, así que los botones del tiempo y del calendario se escriben en su
configuración. Para no ensuciar el repo, la configuración editable es `swaync/.config/swaync/config.base.json`;
`config.json` lo genera `scripts/build-config.sh` (plantilla + textos guardados en `~/.cache/swaync-labels/`).
Tras editar `config.base.json`, ejecuta `~/.config/swaync/scripts/build-config.sh`.

### Fondos de pantalla

Los fondos no van en el repo. El script usa `~/Imágenes/Fondos/` (png, jpg, jpeg, webp).

### Tiempo de AEMET

Los módulos del tiempo necesitan una API key gratuita de
[AEMET OpenData](https://opendata.aemet.es/centrodedescargas/altaUsuario):

```bash
echo "TU_API_KEY" > ~/.config/waybar/aemet_api_key
chmod 600 ~/.config/waybar/aemet_api_key
```

Por defecto usa **Madrid capital como ejemplo**. Para tu ubicación, crea
`~/.config/waybar/aemet_location` (tampoco se sube al repo):

```bash
AEMET_MUNICIPIO="28079"   # código INE de tu municipio
AEMET_AREA="72"           # zona de avisos AEMET de tu comunidad
```

## Notas

- Pensado para un portátil (salida `eDP-1`, batería `BAT0`); ajústalo si tu equipo es distinto.
