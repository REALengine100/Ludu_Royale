
#!/usr/bin/env python3
"""Creates the Android launcher icons (Ludo board + dice).
If an `icon.png` exists in the repo root it is used instead (square, ideally 1024x1024).
Run AFTER `flutter create` (the build workflow does this)."""
import os
from PIL import Image, ImageDraw

RES = "android/app/src/main/res"
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
RED, GREEN, YELLOW, BLUE = (229, 57, 53), (67, 160, 71), (253, 216, 53), (30, 136, 229)


def custom_icon():
    img = Image.open("icon.png").convert("RGBA")
    w, h = img.size
    s = min(w, h)
    img = img.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))
    return img.resize((1024, 1024), Image.LANCZOS)


def draw_icon(S=1024):
    # deep purple vertical gradient background
    bg = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(86 - 40 * t), int(52 - 26 * t), int(160 - 70 * t), 255))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * .22), fill=255)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(img)

    # Ludo board: white square with four coloured home corners
    a, b = int(S * .13), int(S * .87)
    d.rounded_rectangle([a, a, b, b], radius=int(S * .07), fill=(255, 255, 255, 255))
    corner = int(S * .30)
    pad = int(S * .03)
    spots = [
        (a + pad, a + pad, RED),
        (b - pad - corner, a + pad, GREEN),
        (b - pad - corner, b - pad - corner, YELLOW),
        (a + pad, b - pad - corner, BLUE),
    ]
    for x, y, c in spots:
        d.rounded_rectangle([x, y, x + corner, y + corner], radius=int(S * .045), fill=c)
        d.rounded_rectangle([x + corner * .2, y + corner * .2, x + corner * .8, y + corner * .8],
                            radius=int(S * .03), fill=(255, 255, 255, 255))
        d.ellipse([x + corner * .34, y + corner * .34, x + corner * .66, y + corner * .66], fill=c)

    # big dice in the centre (shadow + body + pips)
    ds = int(S * .38)
    cx = cy = S // 2
    x0, y0 = cx - ds // 2, cy - ds // 2
    d.rounded_rectangle([x0 + 10, y0 + 18, x0 + ds + 10, y0 + ds + 18], radius=int(ds * .22), fill=(0, 0, 0, 90))
    d.rounded_rectangle([x0, y0, x0 + ds, y0 + ds], radius=int(ds * .22), fill=(255, 255, 255, 255),
                        outline=(40, 30, 90, 255), width=int(S * .014))
    pr = int(ds * .085)
    for fx, fy in [(.27, .27), (.73, .27), (.5, .5), (.27, .73), (.73, .73)]:
        px, py = x0 + ds * fx, y0 + ds * fy
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(30, 24, 70, 255))
    return img


master = custom_icon() if os.path.exists("icon.png") else draw_icon()
count = 0
for folder, px in SIZES.items():
    out = os.path.join(RES, folder)
    os.makedirs(out, exist_ok=True)
    small = master.resize((px, px), Image.LANCZOS)
    small.save(os.path.join(out, "ic_launcher.png"))
    count += 1
print("Launcher icons written to %d folders." % count)
