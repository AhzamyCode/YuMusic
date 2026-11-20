"""Membuat gambar README dari screenshot HP.

    python tool/make_readme_assets.py <folder-screenshot>

Folder berisi home.png, home2.png, search.png, nowplaying.png, stats.png dan
library.png (screenshot penuh 1208x2644 dari `adb exec-out screencap -p`).
Status bar dipotong supaya notifikasi pribadi tidak ikut tampil.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '.github' / 'assets'
STATUS_BAR = 0.05  # bagian atas layar yang dipotong
SHOTS = ['home', 'home2', 'search', 'nowplaying', 'stats', 'library']
BG_TOP = (14, 14, 16)
BG_BOTTOM = (40, 18, 14)
ACCENT = (255, 107, 74)


def phone(path, width):
    """Screenshot tanpa status bar, diperkecil, dengan sudut bulat."""
    image = Image.open(path).convert('RGB')
    top = round(image.height * STATUS_BAR)
    image = image.crop((0, top, image.width, image.height))
    height = round(image.height * width / image.width)
    image = image.resize((width, height), Image.LANCZOS)
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=width // 11, fill=255,
    )
    framed = Image.new('RGBA', image.size, (0, 0, 0, 0))
    framed.paste(image, (0, 0), mask)
    return framed


def font(size, bold=False):
    names = ['segoeuib.ttf', 'arialbd.ttf'] if bold else ['segoeui.ttf', 'arial.ttf']
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def gradient(size):
    w, h = size
    image = Image.new('RGB', size)
    draw = ImageDraw.Draw(image)
    for y in range(h):
        t = y / (h - 1)
        draw.line(
            [(0, y), (w, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)),
        )
    return image


def banner(shots):
    w, h = 1600, 760
    image = gradient((w, h)).convert('RGBA')
    draw = ImageDraw.Draw(image)

    icon = Image.open(ROOT / 'assets' / 'logo' / 'icon-512.png').resize((112, 112))
    image.alpha_composite(icon, (90, 210))
    draw.text((90, 345), 'Yumusic', font=font(84, bold=True), fill='white')
    draw.text(
        (92, 450),
        'Dengar musik tanpa iklan.',
        font=font(36),
        fill=(230, 230, 235),
    )
    draw.text(
        (92, 500),
        'Tanpa akun, tanpa tracking.',
        font=font(36),
        fill=(230, 230, 235),
    )
    draw.rounded_rectangle((92, 580, 390, 632), radius=26, fill=ACCENT)
    draw.text(
        (241, 606),
        'Gratis · Open source',
        font=font(26, bold=True),
        fill='white',
        anchor='mm',
    )

    # Tiga ponsel, yang tengah sedikit lebih tinggi.
    width = 270
    for i, (name, dy) in enumerate([('search', 120), ('home', 60), ('nowplaying', 120)]):
        p = phone(shots / f'{name}.png', width)
        image.alpha_composite(p, (640 + i * (width + 36), dy))
    return image.convert('RGB')


def main():
    shots = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for name in SHOTS:
        p = phone(shots / f'{name}.png', 540)
        background = Image.new('RGB', p.size, (14, 14, 16))
        background.paste(p, (0, 0), p)
        background.save(OUT / f'{name}.jpg', quality=88)
    banner(shots).save(OUT / 'banner.jpg', quality=90)
    print('ok ->', OUT)


if __name__ == '__main__':
    main()
