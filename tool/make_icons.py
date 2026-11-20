"""Membuat semua ukuran logo Yumusic dari satu definisi geometri.

    python tool/make_icons.py

Logonya huruf Y yang batangnya berakhir di kepala not. Bentuk yang sama juga
ditulis tangan sebagai vektor di assets/logo/logo.svg dan di
android/app/src/main/res/drawable/ic_launcher_foreground.xml; kalau geometri di
sini diubah, ubah dua file itu juga.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ACCENT = (255, 107, 74, 255)
WHITE = (255, 255, 255, 255)

# Geometri pada kanvas 108x108 (ukuran ikon adaptif Android), berpusat di 54,54.
ARM_LEFT = (40, 35)
ARM_RIGHT = (68, 35)
JOIN = (54, 53)
STEM_END = (54, 71)
NOTE_CENTER = (50, 71)
NOTE_RADIUS = 8
STROKE = 8


def draw_logo(size, glyph_scale, background, corner=0.0, glyph=WHITE):
    """Menggambar logo `size` px. `glyph_scale` memperbesar Y dari pusat;
    `corner` adalah jari-jari sudut latar sebagai bagian dari `size`."""
    ss = 4  # digambar 4x lalu diperkecil supaya tepinya halus
    n = size * ss
    image = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if background is not None:
        draw.rounded_rectangle((0, 0, n - 1, n - 1), radius=corner * n, fill=background)

    unit = n / 108

    def point(p):
        return ((p[0] - 54) * glyph_scale + 54) * unit, ((p[1] - 54) * glyph_scale + 54) * unit

    def dot(p, radius):
        x, y = point(p)
        r = radius * glyph_scale * unit
        draw.ellipse((x - r, y - r, x + r, y + r), fill=glyph)

    def stroke(a, b):
        draw.line((point(a), point(b)), fill=glyph, width=round(STROKE * glyph_scale * unit))
        dot(a, STROKE / 2)
        dot(b, STROKE / 2)

    stroke(ARM_LEFT, JOIN)
    stroke(ARM_RIGHT, JOIN)
    stroke(JOIN, STEM_END)
    dot(NOTE_CENTER, NOTE_RADIUS)
    return image.resize((size, size), Image.LANCZOS)


def main():
    logo = ROOT / 'assets' / 'logo'
    logo.mkdir(parents=True, exist_ok=True)

    # Ikon mandiri: kotak bersudut bulat, Y mengisi sekitar setengah lebar.
    def icon(size):
        return draw_logo(size, 1.45, ACCENT, corner=0.22)

    icon(512).save(logo / 'icon-512.png')
    icon(192).save(logo / 'icon-192.png')
    icon(180).save(logo / 'apple-touch-icon.png')
    icon(32).save(logo / 'favicon-32.png')
    icon(256).save(logo / 'favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])

    # Ikon lama Android (dipakai launcher yang tidak mendukung ikon adaptif).
    res = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        icon(size).save(res / f'mipmap-{density}' / 'ic_launcher.png')

    # Pratinjau ikon adaptif seperti di launcher: lingkaran dan kotak bulat.
    full = draw_logo(432, 1.0, ACCENT)
    visible = full.crop((72, 72, 360, 360))  # launcher menampilkan 72 dari 108
    preview = Image.new('RGBA', (288 * 2 + 48, 288), (24, 24, 27, 255))
    for i, radius in enumerate((144, 64)):
        mask = Image.new('L', (288, 288), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, 287, 287), radius=radius, fill=255)
        preview.paste(visible, (i * (288 + 48), 0), mask)
    preview.save(logo / 'preview-android.png')
    print('ok ->', logo)


if __name__ == '__main__':
    main()
