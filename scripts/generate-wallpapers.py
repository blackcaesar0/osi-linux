#!/usr/bin/env python3
"""
OSI Linux — cyber-noir B&W wallpaper generator.

Pure black-and-white (limited grayscale). Glitch / scan-line / grain / ASCII /
circuit motifs only. No color, no logos, no taglines.

Outputs to wallpaper/:
  osi-noir-network.png      — abstract network graph dissolving into glitch
  osi-noir-cat.png          — symbolic figure (cat reading code) silhouette
  osi-noir-terminal.png     — corrupted terminal / ASCII waterfall
"""
from __future__ import annotations

import math
import os
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
OUT = Path(__file__).resolve().parent.parent / "wallpaper"
OUT.mkdir(parents=True, exist_ok=True)


# ── shared effects ──────────────────────────────────────────────────────────
def grain(img: Image.Image, amount: float = 0.06) -> Image.Image:
    arr = np.asarray(img.convert("L"), dtype=np.int16)
    noise = np.random.normal(0, 255 * amount, arr.shape).astype(np.int16)
    arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, mode="L").convert("RGB")


def scanlines(img: Image.Image, period: int = 3, strength: int = 18) -> Image.Image:
    arr = np.asarray(img, dtype=np.int16)
    mask = np.zeros((arr.shape[0], 1, 1), dtype=np.int16)
    mask[::period, 0, 0] = -strength
    arr = np.clip(arr + mask, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def glitch_bands(img: Image.Image, n: int = 14, max_shift: int = 60) -> Image.Image:
    arr = np.asarray(img).copy()
    h = arr.shape[0]
    rng = random.Random(1337)
    for _ in range(n):
        y = rng.randint(0, h - 1)
        band_h = rng.randint(1, 6)
        shift = rng.randint(-max_shift, max_shift)
        y2 = min(y + band_h, h)
        arr[y:y2] = np.roll(arr[y:y2], shift, axis=1)
    return Image.fromarray(arr)


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    d = d / d.max()
    mask = 1 - strength * (d ** 2)
    arr = np.asarray(img, dtype=np.float32) * mask[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def find_mono_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/hack/Hack-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


# ── variant 1: network graph dissolving into glitch ─────────────────────────
def network_graph() -> Image.Image:
    rng = random.Random(7)
    img = Image.new("RGB", (W, H), "#000000")
    draw = ImageDraw.Draw(img, "RGBA")

    # nodes biased to a horizontal "spine" in upper-left, dissolving rightward
    nodes = []
    for _ in range(140):
        x = int(rng.gauss(W * 0.38, W * 0.22))
        y = int(rng.gauss(H * 0.5, H * 0.22))
        if 0 <= x < W and 0 <= y < H:
            nodes.append((x, y))

    # edges: connect each node to a few nearest neighbours
    for i, (x1, y1) in enumerate(nodes):
        dists = sorted(
            (((x1 - x2) ** 2 + (y1 - y2) ** 2), j)
            for j, (x2, y2) in enumerate(nodes)
            if j != i
        )
        for _, j in dists[: rng.randint(1, 3)]:
            x2, y2 = nodes[j]
            # fade by distance from left (right side dissolves)
            falloff = 1 - (x1 / W) * 0.85
            alpha = int(140 * falloff)
            if alpha < 10:
                continue
            draw.line((x1, y1, x2, y2), fill=(200, 200, 200, alpha), width=1)

    for (x, y) in nodes:
        falloff = 1 - (x / W) * 0.7
        r = rng.randint(2, 4)
        c = int(220 * falloff)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(c, c, c, 255))

    # right-side ASCII dissolution
    font = find_mono_font(14)
    chars = "01░▒▓█·∙•—│┤├┬┴┼╳╲╱"
    for _ in range(2400):
        x = int(rng.uniform(W * 0.55, W))
        y = rng.randint(0, H - 1)
        density = (x / W - 0.55) / 0.45
        if rng.random() > density * 0.9:
            continue
        ch = rng.choice(chars)
        v = rng.randint(120, 230)
        draw.text((x, y), ch, font=font, fill=(v, v, v))

    img = glitch_bands(img, n=10, max_shift=40)
    img = scanlines(img, period=3, strength=14)
    img = grain(img, amount=0.05)
    img = vignette(img, strength=0.55)
    return img


# ── variant 2: silhouette of a cat reading papers/code ──────────────────────
def cat_reader() -> Image.Image:
    img = Image.new("RGB", (W, H), "#000000")
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(42)

    # subtle code rain backdrop on the left half
    font_small = find_mono_font(13)
    for _ in range(3500):
        x = rng.randint(0, int(W * 0.6))
        y = rng.randint(0, H - 1)
        v = rng.randint(60, 130)
        ch = rng.choice("01abcdef{}[]()<>;:./*-+=&|^%$#@!?")
        draw.text((x, y), ch, font=font_small, fill=(v, v, v))

    # cat silhouette (right of center, sitting, looking at a glowing page)
    cx, cy = int(W * 0.62), int(H * 0.62)
    body_color = (8, 8, 8)
    outline = (220, 220, 220)

    # body (rounded blob)
    draw.ellipse((cx - 220, cy - 60, cx + 220, cy + 280), fill=body_color, outline=outline, width=2)
    # head
    draw.ellipse((cx - 130, cy - 230, cx + 130, cy - 30), fill=body_color, outline=outline, width=2)
    # ears (triangles)
    draw.polygon([(cx - 125, cy - 200), (cx - 80, cy - 290), (cx - 55, cy - 200)], fill=body_color, outline=outline)
    draw.polygon([(cx + 55, cy - 200), (cx + 80, cy - 290), (cx + 125, cy - 200)], fill=body_color, outline=outline)
    # eyes — small white slits looking down at page
    draw.ellipse((cx - 60, cy - 140, cx - 30, cy - 122), fill=(235, 235, 235))
    draw.ellipse((cx + 30, cy - 140, cx + 60, cy - 122), fill=(235, 235, 235))
    draw.line((cx - 55, cy - 131, cx - 35, cy - 131), fill=(0, 0, 0), width=2)
    draw.line((cx + 35, cy - 131, cx + 55, cy - 131), fill=(0, 0, 0), width=2)
    # nose
    draw.polygon([(cx - 8, cy - 95), (cx + 8, cy - 95), (cx, cy - 82)], fill=(220, 220, 220))
    # whiskers
    for i in (-1, 1):
        for off in (-6, 0, 6):
            draw.line((cx + i * 18, cy - 90 + off, cx + i * 110, cy - 100 + off * 2), fill=(180, 180, 180), width=1)
    # paws holding paper
    draw.ellipse((cx - 90, cy + 80, cx - 30, cy + 140), fill=body_color, outline=outline, width=2)
    draw.ellipse((cx + 30, cy + 80, cx + 90, cy + 140), fill=body_color, outline=outline, width=2)

    # the "papers" — a faintly glowing sheet of code in front
    page_x0, page_y0, page_x1, page_y1 = cx - 180, cy + 110, cx + 180, cy + 290
    draw.rectangle((page_x0, page_y0, page_x1, page_y1), fill=(230, 230, 230))
    draw.rectangle((page_x0, page_y0, page_x1, page_y1), outline=(255, 255, 255), width=2)
    # code lines on page
    line_font = find_mono_font(11)
    sample = [
        "$ ./exploit --target 10.0.0.42",
        "[*] enumerating endpoints...",
        "[+] vuln: CVE-2025-???? confirmed",
        "[*] dropping payload (stage 1)",
        "[+] shell: uid=0(root)",
        "# whoami",
        "root",
        "# cat /etc/shadow",
        "root:$6$........",
    ]
    for i, line in enumerate(sample):
        draw.text((page_x0 + 12, page_y0 + 10 + i * 18), line, font=line_font, fill=(20, 20, 20))

    # soft glow around the page
    glow = Image.new("L", img.size, 0)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.rectangle((page_x0 - 30, page_y0 - 30, page_x1 + 30, page_y1 + 30), fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    glow_rgb = Image.merge("RGB", (glow, glow, glow))
    img = Image.blend(img, ImageChops_screen(img, glow_rgb), 0.6)

    img = scanlines(img, period=3, strength=12)
    img = grain(img, amount=0.05)
    img = vignette(img, strength=0.6)
    return img


def ImageChops_screen(a, b):
    from PIL import ImageChops
    return ImageChops.screen(a, b)


# ── variant 3: corrupted terminal / ASCII waterfall ─────────────────────────
def corrupted_terminal() -> Image.Image:
    img = Image.new("RGB", (W, H), "#000000")
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(99)

    # full-screen ASCII rain, denser at top, sparser at bottom
    font = find_mono_font(15)
    chars = "01░▒▓█·•│┤├┬┴┼╳╲╱<>{}[]()/\\|=+-*&^%$#@!?abcdef"
    cell_w, cell_h = 10, 18
    cols = W // cell_w
    rows = H // cell_h
    for row in range(rows):
        for col in range(cols):
            density = 1 - (row / rows) * 0.6
            if rng.random() > density * 0.5:
                continue
            v = rng.randint(80, 220)
            ch = rng.choice(chars)
            draw.text((col * cell_w, row * cell_h), ch, font=font, fill=(v, v, v))

    # corrupted "terminal window" centered
    win_w, win_h = 1100, 560
    wx, wy = (W - win_w) // 2, (H - win_h) // 2
    # window backdrop
    draw.rectangle((wx, wy, wx + win_w, wy + win_h), fill=(6, 6, 6, 240), outline=(220, 220, 220), width=2)
    # title bar
    draw.rectangle((wx, wy, wx + win_w, wy + 32), fill=(20, 20, 20), outline=(220, 220, 220), width=2)
    title_font = find_mono_font(13)
    draw.text((wx + 12, wy + 8), "tty1 — root@osi:~#", font=title_font, fill=(220, 220, 220))
    # window controls
    for i, ch in enumerate(("_", "□", "x")):
        draw.text((wx + win_w - 60 + i * 18, wy + 8), ch, font=title_font, fill=(220, 220, 220))

    # terminal content
    term_font = find_mono_font(15)
    content = [
        "root@osi:~# uname -a",
        "Linux osi 6.10.0-osi #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux",
        "",
        "root@osi:~# ./recon --target *.example.com",
        "[*] subdomain enumeration ........ 1842 hosts",
        "[*] httpx probe ................... 612 alive",
        "[*] nuclei (cves,exposures) ....... 47 findings",
        "[+] critical: SSRF on api.example.com/v2/fetch",
        "[+] high:     RCE candidate /admin/upload",
        "",
        "root@osi:~# echo 'no signal'",
        "n̸̢̛o̷ ̴s̶i̶g̷n̸a̴l̵̢",
        "root@osi:~# _",
    ]
    for i, line in enumerate(content):
        draw.text((wx + 16, wy + 50 + i * 22), line, font=term_font, fill=(230, 230, 230))

    # corrupt the lower half of the window with a torn/glitch overlay
    img = glitch_bands(img, n=22, max_shift=80)
    img = scanlines(img, period=2, strength=18)
    img = grain(img, amount=0.07)
    img = vignette(img, strength=0.5)
    return img


# ── ASCII grain texture (saved separately so the runtime hook can reuse) ────
def ascii_texture() -> Image.Image:
    rng = random.Random(0)
    img = Image.new("RGB", (W, H), "#000000")
    draw = ImageDraw.Draw(img)
    font = find_mono_font(11)
    chars = "01· "
    for y in range(0, H, 12):
        for x in range(0, W, 8):
            v = rng.randint(40, 90)
            draw.text((x, y), rng.choice(chars), font=font, fill=(v, v, v))
    return img


def main() -> None:
    variants = {
        "osi-noir-network.png": network_graph,
        "osi-noir-cat.png": cat_reader,
        "osi-noir-terminal.png": corrupted_terminal,
        "osi-noir-grain.png": ascii_texture,
    }
    for name, fn in variants.items():
        out = OUT / name
        print(f"  generating {name}...")
        img = fn()
        img.save(out, "PNG", optimize=True)
        print(f"  -> {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
