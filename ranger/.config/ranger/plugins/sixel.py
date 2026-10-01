# Método de previsualización "sixel" para ranger 1.9.4 (que no lo trae).
# Convierte la imagen con chafa (o ImageMagick si falla) y la dibuja en la
# columna de preview.
import fcntl
import shutil
import struct
import sys
import termios
from subprocess import DEVNULL, CalledProcessError, check_output

from ranger.core.shared import FileManagerAware
from ranger.ext.img_display import (ImageDisplayer, ImageDisplayError,
                                    move_cur, register_image_displayer)


@register_image_displayer("sixel")
class SixelImageDisplayer(ImageDisplayer, FileManagerAware):
    def __init__(self):
        self.cache = {}

    @staticmethod
    def _cell_size():
        buf = fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
        rows, cols, xpx, ypx = struct.unpack("HHHH", buf)
        if not (rows and cols and xpx and ypx):
            raise ImageDisplayError("el terminal no informa del tamaño en píxeles")
        return xpx // cols, ypx // rows

    def draw(self, path, start_x, start_y, width, height):
        cell_w, cell_h = self._cell_size()
        # Una fila de margen para que el sixel no haga scroll al final
        px_w, px_h = width * cell_w, (height - 1) * cell_h
        geometry = "{}x{}>".format(px_w, px_h)
        key = (path, geometry)
        if key not in self.cache:
            self.cache[key] = self._convert(path, px_w, px_h, geometry)
        out = sys.stdout.buffer
        sys.stdout.flush()
        out.write(b"\x1b7")
        move_cur(start_y, start_x)
        out.write(self.cache[key])
        out.write(b"\x1b8")
        out.flush()

    @staticmethod
    def _convert(path, px_w, px_h, geometry):
        if shutil.which("chafa"):
            # Sin tty, chafa supone celdas de 10x20 px: se le pasa el tamaño
            # en esas unidades para que salga con los píxeles que queremos.
            # En una sesión nueva, sin terminal de control: si no, chafa abre
            # /dev/tty, usa el tamaño real de celda (mayor con escala HiDPI)
            # y la imagen sale más grande que la columna y se corta.
            try:
                return check_output(
                    ["chafa", "-f", "sixels", "--animate=off", "--polite=on",
                     "-w", "1", "-s", "{}x{}".format(px_w // 10, px_h // 20),
                     path], stdin=DEVNULL, stderr=DEVNULL,
                    start_new_session=True).rstrip(b"\n")
            except (CalledProcessError, OSError):
                pass
        try:
            return check_output(
                ["magick",
                 # Decodifica los JPEG ya reducidos: mucho más rápido en 4K
                 "-define", "jpeg:size={}x{}".format(px_w * 2, px_h * 2),
                 path + "[0]", "-auto-orient",
                 "-thumbnail", geometry, "sixel:-"])
        except (CalledProcessError, OSError) as ex:
            raise ImageDisplayError(str(ex))

    def clear(self, start_x, start_y, width, height):
        self.fm.ui.win.redrawwin()
        self.fm.ui.win.refresh()

    def quit(self):
        self.cache.clear()
