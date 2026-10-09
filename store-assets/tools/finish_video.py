"""Turn the raw simulator recording into an App Store app preview (iPhone 6.5": 886x1920, 30 fps).

Captions are rendered as PNG strips (brand fonts, gold highlights) and overlaid per scene,
then a short end card. Silent stereo AAC track; H.264 High, ~10 Mbps; 15-30 s.
"""
import pathlib, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SP = pathlib.Path(__file__).parent
V = SP / "build" / "video"
OUT = SP / "build" / "final_video"
OUT.mkdir(parents=True, exist_ok=True)
REPO = pathlib.Path(__file__).resolve().parents[2]
BOLD = str(REPO / "assets/fonts/Poppins-Bold.ttf")
SEMI = str(REPO / "assets/fonts/Poppins-SemiBold.ttf")
ELITE = str(SP / "fonts/SpecialElite-Regular.ttf")
W, H, FPS = 886, 1920, 30
GOLD, WHITE = (255, 215, 0), (255, 255, 255)

CAPTIONS = {
    "home_before": [("Bible trivia, ", WHITE), ("every day", GOLD)],
    "01_daily_question": [("A new question ", WHITE), ("every day", GOLD)],
    "02_daily_streak": [("Keep your ", WHITE), ("streak", GOLD), (" alive", WHITE)],
    "03_home_competition": [("Join the ", WHITE), ("60-Day Competition", GOLD)],
    "04_game_question": [("Push for your ", WHITE), ("best run", GOLD)],
    "06_challenge": [("Challenge your ", WHITE), ("mentor", GOLD)],
    "07_leaderboard": [("See where you ", WHITE), ("rank", GOLD)],
}


def caption_png(parts, path):
    """Caption strip: dark fade + one centered line of mixed-colour text."""
    strip = Image.new("RGBA", (W, 300), (0, 0, 0, 0))
    fade = Image.new("L", (W, 300))
    fd = ImageDraw.Draw(fade)
    for y in range(300):
        fd.line([(0, y), (W, y)], fill=int(235 * min(1, (300 - y) / 140)))
    strip.paste(Image.new("RGBA", (W, 300), (24, 24, 26, 255)), (0, 0), fade)
    font = ImageFont.truetype(BOLD, 58)
    d = ImageDraw.Draw(strip)
    total = sum(d.textlength(t, font=font) for t, _ in parts)
    if total > W - 60:  # shrink to fit
        font = ImageFont.truetype(BOLD, int(58 * (W - 60) / total))
        total = sum(d.textlength(t, font=font) for t, _ in parts)
    x = (W - total) / 2
    for t, c in parts:
        d.text((x, 150), t, font=font, fill=c, anchor="lm")
        x += d.textlength(t, font=font)
    strip.save(path)


def end_card(path):
    im = Image.new("RGB", (W, H), (35, 35, 37))
    glow = Image.new("RGB", (W, H), (35, 35, 37))
    ImageDraw.Draw(glow).ellipse([W / 2 - 420, H * .42 - 420, W / 2 + 420, H * .42 + 420], fill=(80, 70, 20))
    im = Image.blend(im, glow.filter(ImageFilter.GaussianBlur(160)), .6)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(ELITE, 150)
    parts = [("T[", WHITE), ("root", GOLD), ("]H", WHITE)]
    total = sum(d.textlength(t, font=f) for t, _ in parts)
    x = (W - total) / 2
    for t, c in parts:
        d.text((x, H * .42), t, font=f, fill=c, anchor="lm")
        x += d.textlength(t, font=f)
    d.text((W / 2, H * .42 + 150), "BIBLE TRIVIA CHALLENGE", font=ImageFont.truetype(SEMI, 40), fill=GOLD, anchor="mm")
    d.text((W / 2, H * .42 + 230), "Rooted in truth. Growing together.", font=ImageFont.truetype(SEMI, 40),
           fill=(235, 235, 235), anchor="mm")
    im.save(path)


LEAD = 2.2  # measured: a screen appears ~2.2 s before its SCENE marker reaches the host
scenes = [(float(t) - LEAD, n) for t, n in (l.split() for l in (V / "scenes.txt").read_text().splitlines())]
scenes = [(t, n) for t, n in scenes if n != "home_before"]  # open straight on the daily question
start = max(0.0, scenes[0][0] - 0.2)
END_CARD = 2.0
body = scenes[-1][0] + LEAD + 2.2 - start  # through the end of the last scene
body = min(body, 29.5 - END_CARD)  # stay under Apple's 30 s limit

# Caption windows (relative to trimmed body); a scene's caption runs until the next caption starts
cap_scenes = [(t - start, n) for t, n in scenes if n in CAPTIONS]
inputs, filters = [], []
for i, (t, n) in enumerate(cap_scenes):
    png = OUT / f"cap_{i}.png"
    caption_png(CAPTIONS[n], png)
    t_end = cap_scenes[i + 1][0] if i + 1 < len(cap_scenes) else body
    inputs += ["-i", str(png)]
    filters.append((i + 1, max(0, t), t_end))

end_png = OUT / "end_card.png"
end_card(end_png)

fc = f"[0:v]trim=start={start:.2f}:duration={body:.2f},setpts=PTS-STARTPTS,fps={FPS},scale={W}:-2,crop={W}:{H}:0:(ih-{H})/2,format=yuv420p[base];"
last = "base"
for k, (idx, a, b) in enumerate(filters):
    fc += f"[{last}][{idx}:v]overlay=0:H-300:enable='between(t,{a:.2f},{b:.2f})'[v{k}];"
    last = f"v{k}"
end_idx = len(filters) + 1
fc += f"[{end_idx}:v]loop=loop={int(END_CARD*FPS)}:size=1:start=0,setpts=N/{FPS}/TB,fps={FPS},format=yuv420p[end];"
fc += f"[{last}][end]concat=n=2:v=1:a=0[vout]"

out = OUT / "trivia_preview_886x1920.mp4"
cmd = (["ffmpeg", "-y", "-loglevel", "error", "-i", str(V / "raw.mov")] + inputs + ["-i", str(end_png),
       "-f", "lavfi", "-t", f"{body + END_CARD:.2f}", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
       "-filter_complex", fc, "-map", "[vout]", "-map", f"{end_idx + 1}:a",
       "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-b:v", "10M", "-minrate", "9M", "-maxrate", "12M", "-bufsize", "20M", "-x264-params", "nal-hrd=cbr",
       "-pix_fmt", "yuv420p", "-r", str(FPS), "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
       "-shortest", "-movflags", "+faststart", str(out)])
subprocess.run(cmd, check=True)
print(out)
