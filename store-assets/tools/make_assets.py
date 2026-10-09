"""Generate App Store creative assets (product page header + search results) as HTML,
render with headless Chrome at exact pixel size, then flatten to RGB (no alpha)."""
import math, random, subprocess, sys, pathlib
from PIL import Image

SP = pathlib.Path(__file__).parent
OUT = SP / "build" / "header_search"
OUT.mkdir(parents=True, exist_ok=True)
REPO = pathlib.Path(__file__).resolve().parents[2]
SPECIAL_ELITE = (SP / "fonts" / "SpecialElite-Regular.ttf").as_uri()
POPPINS = {w: (REPO / f"assets/fonts/Poppins-{n}.ttf").as_uri()
           for w, n in [(400, "Regular"), (500, "Medium"), (600, "SemiBold"), (700, "Bold")]}
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

GOLD = "#FFD700"
CHARCOAL = "#232325"


def roots_svg(w, h, ox, oy, scale, seed, trunk_angles):
    """Organic gold roots spreading from (ox, oy)."""
    rnd = random.Random(seed)
    paths = []

    def grow(x, y, ang, length, width, depth):
        if width < 1.4 or depth > 8:
            return
        pts = [(x, y)]
        steps = rnd.randint(4, 7)
        a = ang
        seg = length / steps
        for _ in range(steps):
            a += rnd.uniform(-0.22, 0.22)
            x += math.cos(a) * seg
            y += math.sin(a) * seg
            pts.append((x, y))
        d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f} " + " ".join(
            f"Q{pts[i][0]:.1f},{pts[i][1]:.1f} {(pts[i][0]+pts[i+1][0])/2:.1f},{(pts[i][1]+pts[i+1][1])/2:.1f}"
            for i in range(1, len(pts) - 1)) + f" L{pts[-1][0]:.1f},{pts[-1][1]:.1f}"
        op = min(0.55, 0.12 + width / 22)
        paths.append(f'<path d="{d}" stroke-width="{width:.1f}" stroke-opacity="{op:.2f}"/>')
        kids = rnd.choice([2, 2, 3])
        for k in range(kids):
            spread = rnd.uniform(0.25, 0.6) * (1 if k % 2 else -1)
            grow(x, y, a + spread, length * rnd.uniform(0.62, 0.8), width * rnd.uniform(0.58, 0.72), depth + 1)

    for deg in trunk_angles:
        grow(ox, oy, math.radians(deg + rnd.uniform(-4, 4)), 420 * scale, 13 * scale, 0)
    return (f'<svg class="roots" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<g fill="none" stroke="{GOLD}" stroke-linecap="round" stroke-linejoin="round">'
            + "".join(paths) + "</g></svg>")


def page(w, h, body, roots, glow_x, glow_y, glow_r, quiet):
    """quiet = (cx, cy, rx, ry): ellipse where roots fade out behind the text."""
    qx, qy, qrx, qry = quiet
    faces = "".join(
        f"@font-face{{font-family:Poppins;font-weight:{wt};src:url('{u}')}}" for wt, u in POPPINS.items())
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:'Special Elite';src:url('{SPECIAL_ELITE}')}}
{faces}
html,body{{margin:0;width:{w}px;height:{h}px;overflow:hidden;background:{CHARCOAL}}}
.bg{{position:absolute;inset:0;background:
  radial-gradient(circle {glow_r}px at {glow_x}px {glow_y}px, rgba(255,215,0,.13), rgba(255,215,0,0) 70%),
  radial-gradient(ellipse at 50% 42%, #2e2e31 0%, {CHARCOAL} 45%, #161617 100%)}}
.roots{{position:absolute;inset:0;
  -webkit-mask-image:radial-gradient(ellipse {qrx}px {qry}px at {qx}px {qy}px, rgba(0,0,0,.05) 0%, rgba(0,0,0,.12) 62%, #000 100%);}}
.stack{{position:absolute;left:0;right:0;display:flex;flex-direction:column;align-items:center;text-align:center}}
.mark{{font-family:'Special Elite';color:#fff;white-space:nowrap;line-height:1;
  text-shadow:0 0 60px rgba(0,0,0,.6)}}
.mark b{{font-weight:normal;color:{GOLD}}}
.sub{{font-family:'Special Elite';color:{GOLD};line-height:1}}
.tag{{font-family:Poppins;font-weight:500;color:rgba(255,255,255,.92);line-height:1.2;text-shadow:0 2px 30px rgba(0,0,0,.8)}}
.head{{font-family:Poppins;font-weight:600;color:#fff;line-height:1.15;text-shadow:0 2px 40px rgba(0,0,0,.8)}}
.chips{{display:flex;gap:28px;justify-content:center}}
.chip{{font-family:Poppins;font-weight:500;color:#fff;border:3px solid rgba(255,215,0,.65);
  background:rgba(35,35,37,.75);border-radius:999px;white-space:nowrap}}
</style></head><body><div class="bg"></div>{roots}{body}</body></html>"""


def render(name, html, w, h):
    src = OUT / f"{name}.html"
    src.write_text(html)
    shot = OUT / f"{name}_raw.png"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", f"--window-size={w},{h}",
                    "--virtual-time-budget=3000", f"--screenshot={shot}", src.as_uri()],
                   check=True, capture_output=True)
    img = Image.open(shot).convert("RGB")  # no alpha channel
    assert img.size == (w, h), img.size
    final = OUT / f"{name}.png"
    img.save(final, "PNG", optimize=True)
    shot.unlink()
    return final


def overlay(path, safe, out):
    """Preview with Apple's Art Safe Area outlined (for review only, not for upload)."""
    from PIL import ImageDraw
    im = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle(safe, outline=(0, 255, 0), width=8)
    im.thumbnail((1600, 1600))
    im.save(out)


# ---------- Product page header: 3840 x 1646, safe 1097,493 → 2743,1154 ----------
HW, HH = 3840, 1646
header_body = """
<div class="stack" style="top:560px">
  <div class="mark" style="font-size:300px">T[<b>root</b>]H</div>
  <div class="tag" style="font-size:70px;margin-top:70px;letter-spacing:1px">Rooted in truth. Growing together.</div>
</div>"""
header = render("header_3840x1646",
                page(HW, HH, header_body,
                     roots_svg(HW, HH, 1920, 1150, 1.2, 7, [185, 165, 140, 115, 92, 68, 40, 15, -5]),
                     1920, 760, 950, (1920, 820, 1000, 420)),
                HW, HH)
overlay(header, (1097, 493, 2743, 1154), OUT / "preview_header_safearea.png")

# ---------- Search results: 3840 x 2560, safe 836,765 → 3004,1795 ----------
SW, SH = 3840, 2560
search_body = """
<div class="stack" style="top:850px">
  <div class="mark" style="font-size:230px">T[<b>root</b>]H</div>
  <div class="head" style="font-size:150px;margin-top:55px">Discipleship for<br>mentors &amp; apprentices</div>
  <div class="chips" style="margin-top:60px;gap:32px">
    <div class="chip" style="font-size:78px;padding:20px 52px">Assessments</div>
    <div class="chip" style="font-size:78px;padding:20px 52px">Prayer journal</div>
    <div class="chip" style="font-size:78px;padding:20px 52px">Bible trivia</div>
  </div>
</div>"""
search = render("search_results_3840x2560",
                page(SW, SH, search_body,
                     roots_svg(SW, SH, 1920, 1880, 1.35, 11, [180, 155, 128, 105, 90, 75, 52, 25, 0]),
                     1920, 1250, 1250, (1920, 1280, 1500, 650)),
                SW, SH)
overlay(search, (836, 765, 3004, 1795), OUT / "preview_search_safearea.png")

for p in (header, search):
    im = Image.open(p)
    print(p.name, im.size, im.mode, f"{p.stat().st_size/1e6:.1f} MB")
