from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 2048
OUT = 1024
BASE = (6, 10, 18)

# ---------- helpers ----------

def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return img


def diagonal_gradient(size, colors):
    """Three-stop diagonal gradient, rendered small and upscaled."""
    small = 512
    img = Image.new("RGB", (small, small))
    draw = ImageDraw.Draw(img)
    stops = colors
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            if t <= 0.5:
                local = t * 2
                a, b = stops[0], stops[1]
            else:
                local = (t - 0.5) * 2
                a, b = stops[1], stops[2]
            color = tuple(int(a[i] + (b[i] - a[i]) * local) for i in range(3))
            draw.point((x, y), fill=color)
    return img.resize((size, size), Image.LANCZOS)


def add_glow(base, center, radius, color, blur, alpha):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        fill=(*color, alpha),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(base.convert("RGBA"), layer)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask

# ---------- background ----------

canvas = vertical_gradient(SIZE, (13, 20, 33), BASE).convert("RGBA")

canvas = add_glow(canvas, (230, 300), 760, (13, 148, 136), 280, 145)
canvas = add_glow(canvas, (1850, 1750), 850, (109, 40, 217), 320, 130)
canvas = add_glow(canvas, (1650, 180), 700, (29, 78, 216), 300, 95)
canvas = add_glow(canvas, (1024, 1024), 610, (20, 184, 166), 220, 60)

# vignette
vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
vd = ImageDraw.Draw(vignette)
for i in range(16):
    inset = int(i * 42)
    alpha = int(10 + i * 2.5)
    vd.rounded_rectangle(
        [inset, inset, SIZE - inset, SIZE - inset],
        radius=280,
        outline=(0, 0, 0, alpha),
        width=60,
    )
vignette = vignette.filter(ImageFilter.GaussianBlur(90))
canvas = Image.alpha_composite(canvas, vignette)

# ---------- orb ----------

orb_diameter = 980
orb = diagonal_gradient(orb_diameter, [(45, 212, 191), (59, 130, 246), (139, 92, 246)])
orb = orb.convert("RGBA")
orb.putalpha(rounded_mask(orb_diameter, orb_diameter // 2))

# soft glow behind the orb
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse(
    [SIZE // 2 - 540, SIZE // 2 - 540, SIZE // 2 + 540, SIZE // 2 + 540],
    fill=(45, 212, 191, 95),
)
glow = glow.filter(ImageFilter.GaussianBlur(130))
canvas = Image.alpha_composite(canvas, glow)

# drop shadow
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.ellipse(
    [SIZE // 2 - 520, SIZE // 2 - 430, SIZE // 2 + 520, SIZE // 2 + 610],
    fill=(0, 0, 0, 160),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(120))
canvas = Image.alpha_composite(canvas, shadow)

orb_pos = (SIZE // 2 - orb_diameter // 2, SIZE // 2 - orb_diameter // 2)
canvas.alpha_composite(orb, dest=orb_pos)

# glossy highlight
highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hd = ImageDraw.Draw(highlight)
hd.ellipse(
    [SIZE // 2 - 360, SIZE // 2 - 430, SIZE // 2 + 120, SIZE // 2 + 30],
    fill=(255, 255, 255, 55),
)
highlight = highlight.filter(ImageFilter.GaussianBlur(95))
orb_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(orb_mask).ellipse(
    [orb_pos[0], orb_pos[1], orb_pos[0] + orb_diameter, orb_pos[1] + orb_diameter],
    fill=255,
)
highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", (SIZE, SIZE), 0), orb_mask))
canvas = Image.alpha_composite(canvas, highlight)

# white "O" ring
ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
rd = ImageDraw.Draw(ring)
ring_diameter = 520
ring_box = [
    SIZE // 2 - ring_diameter // 2,
    SIZE // 2 - ring_diameter // 2,
    SIZE // 2 + ring_diameter // 2,
    SIZE // 2 + ring_diameter // 2,
]
rd.ellipse(ring_box, outline=(255, 255, 255, 240), width=34)
ring = ring.filter(ImageFilter.GaussianBlur(0.6))
canvas = Image.alpha_composite(canvas, ring)

# sparkle dot
spark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
spd = ImageDraw.Draw(spark)
dot_radius = 58
dot_center = (SIZE // 2 + 290, SIZE // 2 - 290)
spd.ellipse(
    [
        dot_center[0] - dot_radius,
        dot_center[1] - dot_radius,
        dot_center[0] + dot_radius,
        dot_center[1] + dot_radius,
    ],
    fill=(255, 255, 255, 255),
)
spark = spark.filter(ImageFilter.GaussianBlur(1.2))
canvas = Image.alpha_composite(canvas, spark)

# subtle star flare
flare = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fd = ImageDraw.Draw(flare)
fd.ellipse(
    [
        dot_center[0] - 130,
        dot_center[1] - 130,
        dot_center[0] + 130,
        dot_center[1] + 130,
    ],
    fill=(255, 255, 255, 22),
)
flare = flare.filter(ImageFilter.GaussianBlur(30))
canvas = Image.alpha_composite(canvas, flare)

# ---------- finish ----------

final = canvas.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
final.save(
    r"C:\Users\Ozo\Downloads\OZOAI\OZOAI\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png",
    "PNG",
    optimize=True,
)
print("Wrote AppIcon.png", final.size)
