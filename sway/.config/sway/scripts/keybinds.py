#!/usr/bin/env python3
"""Dibuja la chuleta de atajos (~/.config/sway/keybindings.conf) en la terminal.

Teclas como "teclas", secciones con icono en el color de acento del tema
(lo lee de ~/.config/fastfetch/accent, que genera theme.sh) y dos columnas
si caben. Lo lanza keybinds.sh dentro de un foot flotante.
"""
import os
import re
import sys
import unicodedata
from pathlib import Path

HOME = Path.home()
SRC = HOME / ".config/sway/keybindings.conf"
ACCENT_FILE = HOME / ".config/fastfetch/accent"

GUTTER = 5
MIN_COL = 58          # ancho mínimo de cada columna para usar dos

RESET = "\x1b[0m"
BOLD = "\x1b[1m"


def rgb_fg(r, g, b):
    return f"\x1b[38;2;{r};{g};{b}m"


def rgb_bg(r, g, b):
    return f"\x1b[48;2;{r};{g};{b}m"


def accent():
    try:
        parts = ACCENT_FILE.read_text().strip().split(";")
        r, g, b = (int(x) for x in parts[2:5])
        return r, g, b
    except (OSError, ValueError):
        return 0xDF, 0x61, 0x24


ACC = accent()
FG_ACC = rgb_fg(*ACC)
BG_ACC = rgb_bg(*ACC)
FG_DARK = rgb_fg(13, 13, 13)
FG_TEXT = rgb_fg(208, 208, 208)
FG_DIM = rgb_fg(110, 110, 110)
FG_RULE = rgb_fg(55, 55, 55)
CAP = rgb_bg(42, 42, 42) + rgb_fg(235, 235, 235) + BOLD

ICONS = {
    "Básicos": "\uf11c",                       # teclado
    "Notificaciones y sonido": "\uf0f3",       # campana
    "Foco y ventanas": "\uf2d2",               # ventana
    "Espacios de trabajo": "\uf009",           # cuadrícula
    "Distribución": "\uf0db",                  # columnas
    "Capturas": "\uf030",                      # cámara
    "Fondo y tema": "\uf03e",                  # imagen
    "Terminal con pestañas (tmux)": "\uf120",  # terminal
    "Otros": "\uf013",                         # engranaje
}

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def width(s):
    s = ANSI.sub("", s)
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def pad(s, w):
    return s + " " * max(0, w - width(s))


def parse():
    sections = []
    for raw in SRC.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            sections.append((line[1:-1].strip(), []))
        elif "=" in line and sections:
            keys, desc = line.split(" = ", 1)
            sections[-1][1].append((keys.strip(), desc.strip()))
    return sections


def keycaps(keys):
    """'Super+Shift+Q / Super+X' -> teclas dibujadas, alternativas con '/'."""
    alts = []
    for alt in keys.split(" / "):
        alts.append(" ".join(f"{CAP} {k} {RESET}" for k in re.split(r"\+(?=.)", alt)))
    return f" {FG_DIM}/{RESET} ".join(alts)


def describe(desc):
    # El texto entre paréntesis va atenuado
    desc = re.sub(r"(\([^)]*\))", lambda m: f"{FG_DIM}{m.group(1)}{FG_TEXT}", desc)
    return f"{FG_TEXT}{desc}{RESET}"


def wrap(text, w):
    """Parte un texto (con colores) en líneas de ancho visible <= w."""
    lines, cur = [], ""
    for word in text.split(" "):
        cand = f"{cur} {word}" if cur else word
        if width(cand) <= w or not cur:
            cur = cand
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    return lines


def render_section(title, items, colw):
    head = f"{ICONS.get(title, chr(0xf105))}  {title}"
    out = [f"{FG_ACC}{BOLD}{head}{RESET} "
           f"{FG_RULE}{'─' * max(0, colw - width(head) - 1)}{RESET}"]
    caps = [keycaps(k) for k, _ in items]
    # Columna de teclas: la más ancha de la sección, sin pasar del 55 %
    fits = [width(c) for c in caps if width(c) <= colw * 0.45]
    keyw = max(fits) if fits else int(colw * 0.45)
    for cap, (_, desc) in zip(caps, items):
        descw = colw - keyw - 2
        if width(cap) > keyw:            # tecla muy larga: texto debajo
            out.append(cap)
            for l in wrap(describe(desc), colw - 4):
                out.append("    " + FG_TEXT + l)
        else:
            parts = wrap(describe(desc), descw)
            out.append(pad(cap, keyw) + "  " + parts[0])
            for l in parts[1:]:
                out.append(" " * (keyw + 2) + FG_TEXT + l)
    return out


def main():
    # stdout va a less (tubería): el tamaño se mira en stderr/stdin
    cols = 160
    for fd in (2, 0, 1):
        try:
            cols = os.get_terminal_size(fd).columns
            break
        except OSError:
            pass
    sections = parse()
    margin = 2
    usable = cols - 2 * margin
    two = usable >= 2 * MIN_COL + GUTTER
    colw = (usable - GUTTER) // 2 if two else usable

    blocks = [render_section(t, items, colw) for t, items in sections]

    # Cabecera
    title = "  \uf11c  Atajos de teclado"
    hint = "Super = tecla Windows   "
    bar = BG_ACC + FG_DARK + BOLD + title + " " * max(1, cols - width(title) - width(hint)) + hint + RESET
    print(bar)
    print()

    if not two:
        for b in blocks:
            for l in b:
                print(" " * margin + l)
            print()
    else:
        # Reparto en dos columnas lo más igualadas posible, sin partir secciones
        total = sum(len(b) + 1 for b in blocks)
        left, acc = [], 0
        for i, b in enumerate(blocks):
            if acc + (len(b) + 1) / 2 > total / 2 and left:
                break
            left.append(b)
            acc += len(b) + 1
        right = blocks[len(left):]

        def flat(bs):
            lines = []
            for b in bs:
                lines += b + [""]
            return lines[:-1]

        L, R = flat(left), flat(right)
        for i in range(max(len(L), len(R))):
            l = L[i] if i < len(L) else ""
            r = R[i] if i < len(R) else ""
            print(" " * margin + pad(l, colw) + RESET + " " * GUTTER + r + RESET)

    print()
    foot = "q o Super+F1 cerrar  ·  /  buscar  ·  ↑↓ desplazar"
    print(" " * margin + FG_DIM + foot + RESET)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.stderr.close()
