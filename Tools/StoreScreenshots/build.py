#!/usr/bin/env python3
"""Composes the App Store screenshot set from the raw captures.

Reads the raw screenshots that `fastlane snapshot` writes to fastlane/screenshots/raw/<locale>,
plus the Apple Watch captures in watch/<locale>/ (capture-watch.sh makes watch.png), lays each slide out as HTML with the copy from captions.json, and renders it with headless Chrome
into fastlane/screenshots/framed/<locale> at 1320x2868 (6.9" iPhone), which deliver uploads.
Ported from the Android app's tools/store-screenshots/build.py so both stores share one design.

Usage: python3 Tools/StoreScreenshots/build.py [locale ...]
Set CHROME to the Chrome binary if it isn't in the default macOS location.
"""
import html
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RAW = ROOT / "fastlane/screenshots/raw"
OUT = ROOT / "fastlane/screenshots/framed"
DEVICE = "iPhone 16 Pro Max"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

WIDTH, HEIGHT = 1320, 2868
SCREEN_W, SCREEN_H = 1320, 2868
WATCH_W, WATCH_H = 416, 496         # Apple Watch Series 11 (46mm) capture
BACKGROUND = "#14324F"
INK = "#FFFFFF"
ACCENT = "#FF8A5C"
SUBLINE = "#D3DDEA"
# Where the devices start on every slide, below the tallest text block, so they line up
# across the set however many lines a headline takes.
DEVICE_TOP = 1080

PAGE = """<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8">
<style>
@font-face {{ font-family: "Jakarta"; src: url("{fonts}/PlusJakartaSans.ttf"); font-weight: 200 800; }}
@font-face {{ font-family: "Manrope"; src: url("{fonts}/Manrope.ttf"); font-weight: 200 800; }}
body {{ margin: 0; }}
.shot {{ position: relative; width: {w}px; height: {h}px; overflow: hidden; background: {bg};
  font-family: "Jakarta", "Manrope", sans-serif; }}
.text {{ position: absolute; left: 118px; top: 150px; width: 1084px; display: flex; flex-direction: column; gap: 42px; }}
h1 {{ margin: 0; font-size: 184px; font-weight: 800; line-height: 1.02; letter-spacing: -5px; color: {ink}; }}
h1 span.line {{ display: block; white-space: nowrap; width: max-content; }}
h1 em {{ font-style: normal; color: {accent}; }}
p {{ margin: 0; max-width: 1000px; font-size: 56px; font-weight: 500; line-height: 1.3; color: {sub}; }}
.device {{ position: absolute; }}
.phone {{ position: relative; background: #0E1013; box-shadow: 0 0 0 4px #3A3E46, 0 100px 200px rgba(0,0,0,.55); }}
.phone img {{ display: block; }}
.island {{ position: absolute; left: 50%; border-radius: 999px; background: #050607; }}
.button {{ position: absolute; width: 8px; border-radius: 4px; background: #3A3E46; }}
</style></head>
<body><div class="shot">{body}</div>
<script>
// Shrink the headline until its widest line fits, and the subline until it fits three lines,
// so long translations keep the same layout as English.
document.fonts.ready.then(() => {{
  const h1 = document.querySelector("h1"), p = document.querySelector("p");
  let size = 184;
  while (size > 86 && Math.max(...[...h1.querySelectorAll(".line")].map(l => l.offsetWidth)) > 1084) {{
    size -= 4; h1.style.fontSize = size + "px"; h1.style.letterSpacing = (-5 * size / 184) + "px";
  }}
  let sub = 56;
  while (sub > 36 && p.offsetHeight > sub * 1.3 * 3 + 2) {{ sub -= 2; p.style.fontSize = sub + "px"; }}
  document.body.dataset.ready = "1";
}});
</script></body></html>"""


def headline(text):
    lines = []
    for line in text.split("|"):
        escaped = html.escape(line)
        escaped = re.sub(r"\{(.*?)\}", r"<em>\1</em>", escaped)
        lines.append(f'<span class="line">{escaped}</span>')
    return "".join(lines)


def phone(src, width, alt):
    pad = round(width * 0.03)
    screen_w = width - 2 * pad
    screen_h = round(screen_w * SCREEN_H / SCREEN_W)
    radius = round(width * 0.15)
    island_w, island_h = round(screen_w * 0.286), round(screen_w * 0.084)
    return (f'<div class="phone" style="padding:{pad}px;border-radius:{radius}px">'
            f'<div class="button" style="right:-10px;top:{round(width * .62)}px;height:{round(width * .24)}px"></div>'
            f'<div class="button" style="left:-10px;top:{round(width * .5)}px;height:{round(width * .16)}px"></div>'
            f'<div class="button" style="left:-10px;top:{round(width * .72)}px;height:{round(width * .16)}px"></div>'
            f'<img src="{src}" alt="{html.escape(alt)}" style="width:{screen_w}px;height:{screen_h}px;border-radius:{radius - pad}px">'
            f'<div class="island" style="top:{pad + round(screen_w * 0.025)}px;width:{island_w}px;height:{island_h}px;margin-left:-{island_w // 2}px"></div>'
            f'</div>')


def apple_watch(src, width, alt):
    bezel = round(width * 0.07)
    screen_w = width - 2 * bezel
    screen_h = round(screen_w * WATCH_H / WATCH_W)
    height = screen_h + 2 * bezel
    radius = round(width * 0.26)
    strap_w, strap_h = round(width * 0.64), round(width * 0.42)
    left = (width - strap_w) // 2
    strap = "linear-gradient(90deg,#1C1F24,#2C3036 50%,#1C1F24)"
    return (f'<div style="position:relative;width:{width}px;height:{height}px">'
            f'<div style="position:absolute;left:{left}px;top:-{strap_h - 20}px;width:{strap_w}px;height:{strap_h}px;border-radius:{strap_w // 3}px {strap_w // 3}px 0 0;background:{strap}"></div>'
            f'<div style="position:absolute;left:{left}px;bottom:-{strap_h - 20}px;width:{strap_w}px;height:{strap_h}px;border-radius:0 0 {strap_w // 3}px {strap_w // 3}px;background:{strap}"></div>'
            # Digital Crown and side button.
            f'<div style="position:absolute;right:-{round(width * .05)}px;top:{round(height * .24)}px;width:{round(width * .07)}px;height:{round(height * .15)}px;border-radius:10px;background:#3A3E46"></div>'
            f'<div style="position:absolute;right:-{round(width * .025)}px;top:{round(height * .5)}px;width:{round(width * .04)}px;height:{round(height * .2)}px;border-radius:8px;background:#3A3E46"></div>'
            f'<div class="frame" style="position:absolute;inset:0;border-radius:{radius}px"></div>'
            f'<img src="{src}" alt="{html.escape(alt)}" style="position:absolute;left:{bezel}px;top:{bezel}px;width:{screen_w}px;height:{screen_h}px;border-radius:{radius - bezel}px">'
            f'</div>')


def placed(content, left, top, rotate):
    return (f'<div class="device" style="left:{left}px;top:{top}px;transform:rotate({rotate}deg)">'
            f'{content}</div>')


def source(locale, screen):
    if screen.startswith("watch:"):
        path = HERE / "watch" / locale / f"{screen.split(':')[1]}.png"
    else:
        path = RAW / locale / f"{DEVICE}-{screen}.png"
    if not path.exists():
        sys.exit(f"Missing capture: {path}")
    return path.as_uri()


def slide_body(locale, slide, head, sub):
    text = f'<div class="text"><h1>{headline(head)}</h1><p>{html.escape(sub)}</p></div>'
    if "watch" in slide:
        devices = (placed(phone(source(locale, slide["main"]), 760, "C2K workout screen"), 30, DEVICE_TOP + 40, -11)
                   + placed(apple_watch(source(locale, slide["watch"]), 600, "Apple Watch showing a C2K interval alert"),
                            650, DEVICE_TOP + 600, 7))
    else:
        devices = (placed(phone(source(locale, slide["back"]), 740, "C2K screen"), 10, DEVICE_TOP + 90, -11)
                   + placed(phone(source(locale, slide["main"]), 830, "C2K screen"), 500, DEVICE_TOP, 7))
    return text + devices


def render(html_path, png_path):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", f"--window-size={WIDTH},{HEIGHT}",
                    "--virtual-time-budget=8000", f"--screenshot={png_path}", html_path.as_uri()],
                   check=True, capture_output=True)


def main():
    captions = json.loads((HERE / "captions.json").read_text(encoding="utf-8"))
    locales = sys.argv[1:] or list(captions["copy"])
    with tempfile.TemporaryDirectory() as tmp:
        for locale in locales:
            copy = captions["copy"][locale]
            out_dir = OUT / locale
            out_dir.mkdir(parents=True, exist_ok=True)
            # deliver uploads every PNG in the folder, so clear the previous set first.
            for old in out_dir.glob("*.png"):
                old.unlink()
            for slide, (head, sub) in zip(captions["slides"], copy):
                page = PAGE.format(lang=locale.split("-")[0], fonts=(HERE / "fonts").as_uri(), w=WIDTH, h=HEIGHT,
                                   bg=BACKGROUND, ink=INK, accent=ACCENT, sub=SUBLINE,
                                   body=slide_body(locale, slide, head, sub))
                html_path = Path(tmp) / f"{locale}_{slide['name']}.html"
                html_path.write_text(page, encoding="utf-8")
                render(html_path, out_dir / f"{DEVICE}-{slide['name']}.png")
            print(f"{locale}: {len(copy)} slides")


if __name__ == "__main__":
    main()
