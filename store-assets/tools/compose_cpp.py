"""Compose connected App Store screenshots for the Bible Trivia Challenge custom product page.

One shared background (gold roots + a continuous gold thread) spans all panels; each
panel is rendered as a window onto it, so the art flows seamlessly across screenshots.
usage: python3 compose_cpp.py iphone|ipad
"""
import math, random, subprocess, sys, pathlib
from PIL import Image

SP = pathlib.Path(__file__).parent
device = sys.argv[1]
CAP = SP / "build" / device
OUT = SP / "build" / f"final_{device}"
OUT.mkdir(parents=True, exist_ok=True)
REPO = pathlib.Path(__file__).resolve().parents[2]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SPECIAL_ELITE = (SP / "fonts" / "SpecialElite-Regular.ttf").as_uri()
POPPINS = {w: (REPO / f"assets/fonts/Poppins-{n}.ttf").as_uri()
           for w, n in [(500, "Medium"), (600, "SemiBold"), (700, "Bold")]}
GOLD, CHARCOAL = "#FFD700", "#232325"

W, H = (1206, 2622) if device == "iphone" else (2064, 2752)
S = W / 1206 if device == "iphone" else 1.25          # type scale
SHOT_W = 0.80 if device == "iphone" else 0.74          # screenshot width as share of panel

PANELS = [  # (screenshot, caption, gold word)
    ("01_daily_question", "A new Bible question <b>every day</b>", None),
    ("02_daily_streak", "Build your <b>daily streak</b>", None),
    ("03_home_competition", "Join the <b>60&#8209;Day Competition</b>", None),
    ("05_game_correct", "Push for your <b>best run</b>", None),
    ("06_challenge", "Challenge your <b>mentor</b>", None),
    ("07_leaderboard", "See where you <b>rank</b>", None),
]
N = len(PANELS)
TOTAL = W * N


def roots(seed=5):
    """Low roots running the whole width, with branches rising into each panel."""
    rnd = random.Random(seed)
    paths = []

    def grow(x, y, ang, length, width, depth):
        if width < 1.3 * S or depth > 7:
            return
        pts = [(x, y)]
        a = ang
        steps = rnd.randint(4, 7)
        for _ in range(steps):
            a += rnd.uniform(-0.25, 0.25)
            x += math.cos(a) * length / steps
            y += math.sin(a) * length / steps
            pts.append((x, y))
        d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f} " + " ".join(
            f"Q{pts[i][0]:.1f},{pts[i][1]:.1f} {(pts[i][0]+pts[i+1][0])/2:.1f},{(pts[i][1]+pts[i+1][1])/2:.1f}"
            for i in range(1, len(pts) - 1)) + f" L{pts[-1][0]:.1f},{pts[-1][1]:.1f}"
        paths.append(f'<path d="{d}" stroke-width="{width:.1f}" stroke-opacity="{min(.5, .1 + width / (24 * S)):.2f}"/>')
        for k in range(rnd.choice([2, 2, 3])):
            grow(x, y, a + rnd.uniform(.25, .6) * (1 if k % 2 else -1), length * rnd.uniform(.6, .8),
                 width * rnd.uniform(.58, .72), depth + 1)

    # A main root crawling along the bottom across all panels, sprouting as it goes
    y0 = H * 0.93
    for i in range(N * 3 + 1):
        x = i * W / 3 + rnd.uniform(-60, 60) * S
        up = math.radians(-90 + rnd.uniform(-35, 35))
        grow(x, y0 + rnd.uniform(-40, 40) * S, up, 260 * S, 9 * S, 1)
        grow(x, y0, math.radians(rnd.choice([170, 10]) + rnd.uniform(-15, 15)), 380 * S, 11 * S, 0)
    return "".join(paths)


def thread():
    """A continuous gold thread weaving through every caption band."""
    pts = []
    for i in range(N * 4 + 1):
        x = i * W / 4
        y = H * (0.236 + 0.007 * math.sin(i * 1.3))
        pts.append((x, y))
    d = f"M{pts[0][0]},{pts[0][1]} " + " ".join(
        f"Q{pts[i][0]:.1f},{pts[i][1]:.1f} {(pts[i][0]+pts[i+1][0])/2:.1f},{(pts[i][1]+pts[i+1][1])/2:.1f}"
        for i in range(1, len(pts) - 1))
    return f'<path d="{d}" fill="none" stroke="{GOLD}" stroke-width="{5*S:.1f}" stroke-opacity=".55" stroke-linecap="round"/>'


ROOTS = roots()
THREAD = thread()


def panel_html(i, shot, caption):
    faces = "".join(f"@font-face{{font-family:Poppins;font-weight:{w};src:url('{u}')}}" for w, u in POPPINS.items())
    sw = int(W * SHOT_W)
    top = int(H * 0.262)
    hero = (f'<div class="mark" style="font-size:{int(118*S)}px">T[<b>root</b>]H</div>'
            f'<div class="kicker" style="font-size:{int(46*S)}px">BIBLE TRIVIA CHALLENGE</div>') if i == 0 else ""
    cap_top = int(H * (0.045 if i == 0 else 0.075))
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:'Special Elite';src:url('{SPECIAL_ELITE}')}}
{faces}
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:{CHARCOAL}}}
.world{{position:absolute;top:0;left:{-i*W}px;width:{TOTAL}px;height:{H}px;
  background:radial-gradient(ellipse 60% 70% at 50% 40%, #2c2c2f 0%, {CHARCOAL} 55%, #171718 100%)}}
.world svg{{position:absolute;inset:0}}
.cap{{position:absolute;top:{cap_top}px;left:{int(70*S)}px;right:{int(70*S)}px;text-align:center}}
.cap h1{{margin:0;font-family:Poppins;font-weight:700;color:#fff;font-size:{int(92*S)}px;line-height:1.12;
  text-shadow:0 4px 40px rgba(0,0,0,.7)}}
.cap h1 b{{color:{GOLD}}}
.mark{{font-family:'Special Elite';color:#fff;line-height:1;margin-bottom:{int(18*S)}px}}
.mark b{{font-weight:normal;color:{GOLD}}}
.kicker{{font-family:Poppins;font-weight:600;letter-spacing:.18em;color:{GOLD};margin-bottom:{int(40*S)}px}}
.shot{{position:absolute;left:{(W-sw)//2}px;top:{top}px;width:{sw}px;border-radius:{int(64*S)}px;
  border:{int(5*S)}px solid rgba(255,215,0,.55);box-shadow:0 {int(30*S)}px {int(120*S)}px rgba(0,0,0,.75),
  0 0 {int(90*S)}px rgba(255,215,0,.12)}}
</style></head><body>
<div class="world"><svg width="{TOTAL}" height="{H}" viewBox="0 0 {TOTAL} {H}">
<g fill="none" stroke="{GOLD}" stroke-linecap="round">{ROOTS}</g>{THREAD}</svg></div>
<div class="cap">{hero}<h1>{caption}</h1></div>
<img class="shot" src="{(CAP / (shot + '.png')).as_uri()}">
</body></html>"""


for i, (shot, caption, _) in enumerate(PANELS):
    src = OUT / f"_panel{i}.html"
    src.write_text(panel_html(i, shot, caption))
    raw = OUT / f"_raw{i}.png"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--force-device-scale-factor=1", f"--window-size={W},{H}", "--virtual-time-budget=3000",
                    f"--screenshot={raw}", src.as_uri()], check=True, capture_output=True)
    img = Image.open(raw).convert("RGB")
    assert img.size == (W, H), img.size
    img.save(OUT / f"{i+1:02d}_{shot}.png", optimize=True)
    raw.unlink()

# Panorama preview (review only): all panels side by side, as they'll scroll in the store
ims = [Image.open(p) for p in sorted(OUT.glob("[0-9]*.png"))]
pano = Image.new("RGB", (W * N, H))
for i, im in enumerate(ims):
    pano.paste(im, (i * W, 0))
pano.thumbnail((3000, 3000))
pano.save(SP / "build" / f"panorama_{device}.png")
print(device, [p.name for p in sorted(OUT.glob('[0-9]*.png'))], (W, H))
