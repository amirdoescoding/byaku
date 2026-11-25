"""byaku brand exploration, round 1.
Writes ../explore.html (self-contained page, fonts inlined) and ../sheet-{symbols,type,palette}.png.
Run from this folder:  uv run --with playwright python gen.py"""
import base64, math, pathlib

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent
FONTS = HERE.parents[3] / "assets" / "fonts"

# ---- geometry: 64-unit grid, centre 32, outer edge r=28 ------------------------------------------
C = 32
def P(r, a):
    t = math.radians(a); return C + r * math.cos(t), C + r * math.sin(t)
def arc(r, a0, a1):
    """Clockwise arc from a0 to a1 (degrees, SVG: 0 = 3 o'clock, 90 = 6 o'clock)."""
    (x0, y0), (x1, y1) = P(r, a0), P(r, a1)
    big = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{x0:.3f} {y0:.3f}A{r:.3f} {r:.3f} 0 {big} 1 {x1:.3f} {y1:.3f}"
def stroke(d, w, col="currentColor"):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w:.2f}"/>'
def blade(r, a0, a1, w):
    """Crescent on circle r between a0..a1 (<180 deg): pointed tips, thickest (w) at the middle."""
    h = r * math.sin(math.radians((a1 - a0) / 2)); s = r - math.sqrt(r * r - h * h)
    w = min(w, s * 0.85); s2 = s - w; R2 = (h * h + s2 * s2) / (2 * s2)
    (x0, y0), (x1, y1) = P(r, a0), P(r, a1)
    return (f'<path fill="currentColor" d="M{x0:.3f} {y0:.3f}A{r} {r} 0 0 1 {x1:.3f} {y1:.3f}'
            f'A{R2:.3f} {R2:.3f} 0 0 0 {x0:.3f} {y0:.3f}Z"/>')

# The reference: a ring, and inside it two unequal arcs, a long one at 8-11 o'clock and a short one at 2-3.
INNER = ((140, 250), (-55, 15))
_uid = [0]
def A(w):  # cleaned reference
    R = 28 - w / 2
    return stroke(f"M{C+R} {C}A{R} {R} 0 1 1 {C-R} {C}A{R} {R} 0 1 1 {C+R} {C}", w) + \
        "".join(stroke(arc(11, *a), max(1.6, w * 0.85)) for a in INNER)
def B(w):  # negative cut: solid disc, arcs cut out
    _uid[0] += 1; m = f"m{_uid[0]}"
    cuts = "".join(stroke(arc(12, *a), max(1.8, w * 0.9), "#000") for a in INNER)
    return (f'<mask id="{m}"><rect width="64" height="64" fill="#fff"/>{cuts}</mask>'
            f'<circle cx="32" cy="32" r="28" fill="currentColor" mask="url(#{m})"/>')
def Cc(w):  # split ring: the ring itself is the two unequal arcs
    R = 28 - w / 2
    return stroke(arc(R, 212, 322), w) + stroke(arc(R, 338, 196 + 360), w)
def D(w):  # side glance: quiet ring, one heavy short arc looking right
    R = 28 - max(1.4, w * 0.45) / 2
    return stroke(f"M{C+R} {C}A{R} {R} 0 1 1 {C-R} {C}A{R} {R} 0 1 1 {C+R} {C}", max(1.4, w * 0.45)) + \
        stroke(arc(15, -32, 32), max(3, w * 1.5))
def E(w):  # blade arcs: the reference arcs become two crescents
    R = 28 - max(1.4, w * 0.5) / 2
    return stroke(f"M{C+R} {C}A{R} {R} 0 1 1 {C-R} {C}A{R} {R} 0 1 1 {C+R} {C}", max(1.4, w * 0.5)) + \
        blade(17, 138, 252, w * 1.3) + blade(17, -52, 14, w * 1.3)
def F(w):  # single seam: one off-axis slit
    R = 28 - w / 2
    return stroke(arc(R, -48, 300), w)

CONCEPTS = [("A", "Cleaned reference", A), ("B", "Negative cut", B), ("C", "Split ring", Cc),
            ("D", "Side glance", D), ("E", "Blade arcs", E), ("F", "Single seam", F)]
WEIGHTS = [(1, "hairline", 2.0), (2, "medium", 4.5), (3, "bold", 7.0)]
def svg(body, px, label=""):
    aria = f' role="img" aria-label="{label}"' if label else ' aria-hidden="true"'
    return f'<svg viewBox="0 0 64 64" width="{px}" height="{px}"{aria}>{body}</svg>'

# ---- colour ---------------------------------------------------------------------------------------
PAPER, INK = "#F5F5F7", "#0E0D12"
LIGHT = dict(bg=PAPER, ink=INK, mute="#66636F", line="#E1E0E6")
DARK = dict(bg=INK, ink="#ECEBF0", mute="#8F8C99", line="#25232C")
ACCENTS = [("P1", "Pale iris", "#C8BFEF", "closest to the reference"),
           ("P2", "Lavender", "#9B8FD9", "readable on both grounds"),
           ("P3", "Dusk violet", "#6A5DB8", "ink-like, strongest on paper"),
           ("P4", "Moon lilac", "#E3DDFB", "almost white, a night colour")]
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + 0.05) / (lb + 0.05)
assert abs(contrast("#000000", "#FFFFFF") - 21) < 0.01

# ---- type -----------------------------------------------------------------------------------------
FACES = [("Beacon", "Beacon/variable/Beacon[wght].ttf", "legible, tailed l: calm and open"),
         ("Gravure", "Gravure/gravure.woff2", "engraver's gothic: wide, hairline spurs"),
         ("Aurelia", "Aurelia/aurelia.woff2", "flared stems: carved, sharp-edged"),
         ("Rondel", "Rondel/rondel.woff2", "geometric: its o echoes the ring"),
         ("Halden", "Halden/halden.woff2", "neo-grotesque: the neutral control")]
def face_css(name, rel):
    b64 = base64.b64encode((FONTS / rel).read_bytes()).decode()
    fmt, mime = ("woff2", "font/woff2") if rel.endswith("woff2") else ("truetype", "font/ttf")
    return (f'@font-face{{font-family:"{name}";src:url(data:{mime};base64,{b64}) format("{fmt}");'
            f'font-weight:100 900;font-display:block}}')

# ---- page -----------------------------------------------------------------------------------------
def panel(theme, inner, title):
    return f'<div class="panel {theme}"><p class="cap">{title} · {"paper" if theme == "l" else "ink"}</p>{inner}</div>'
def pair(fn, title):
    return f'<div class="pair">{panel("l", fn(), title)}{panel("d", fn(), title)}</div>'

def symbols():
    rows = []
    for k, name, f in CONCEPTS:
        cells = "".join(
            f'<figure class="cell">{svg(f(w), 104, f"{k}{n} {name}, {wn}")}'
            f'<div class="small">{svg(f(w), 32)}{svg(f(w), 16)}<span class="bar">{svg(f(w), 16)}</span></div>'
            f'<figcaption><b>{k}{n}</b> {wn}</figcaption></figure>' for n, wn, w in WEIGHTS)
        rows.append(f'<div class="row"><p class="rowlab"><b>{k}</b>{name}</p><div class="cells">{cells}</div></div>')
    return "".join(rows)

def type_():
    rows = []
    for name, _, note in FACES:
        f = f"font-family:'{name}',system-ui,sans-serif"
        rows.append(
            f'<div class="trow"><p class="rowlab"><b>{name}</b>{note}</p><div class="words">'
            + "".join(f'<figure><span class="w" style="{f};font-weight:{wt}">byaku</span>'
                      f'<figcaption>{wt}</figcaption></figure>' for wt in (300, 500, 700))
            + f'<figure><span class="w caps" style="{f};font-weight:400">BYAKU</span><figcaption>400 tracked</figcaption></figure>'
            + "</div></div>")
    locks = "".join(
        f'<figure class="lock">{svg(E(4.5), 44)}<span class="w" style="font-family:\'{n}\',system-ui;font-weight:{wt}">byaku</span>'
        f'<span class="kanji">白眼</span><figcaption>{n} {wt} + E2</figcaption></figure>'
        for n, wt in (("Gravure", 400), ("Beacon", 300), ("Rondel", 500)))
    return "".join(rows) + f'<div class="trow"><p class="rowlab"><b>Lockup</b>with 白眼 as a quiet second voice</p><div class="words">{locks}</div></div>'

def palette(theme):
    bg = LIGHT["bg"] if theme == "l" else DARK["bg"]
    out = []
    for k, name, hx, note in ACCENTS:
        cr = contrast(hx, bg)
        verdict = "text" if cr >= 4.5 else "graphics" if cr >= 3 else "too faint"
        out.append(
            f'<figure class="acc" style="--a:{hx}"><div class="accsym">{svg(A(4.5), 72)}{svg(B(4.5), 72)}'
            f'<span class="bar">{svg(E(4.5), 16)}</span></div>'
            f'<figcaption><b>{k}</b> {name} <code>{hx}</code><br><span>{cr:.2f}:1 · {verdict}</span>'
            f'<br><i>{note}</i></figcaption></figure>')
    return '<div class="accs">' + "".join(out) + "</div>"

def css():
    t = lambda d: ";".join(f"--{k}:{v}" for k, v in d.items())
    return f"""
:root{{--page:#17161C;--page-ink:#ECEBF0;--page-mute:#8F8C99;
 --mono:ui-monospace,"SF Mono",Menlo,monospace;color-scheme:dark}}
/* layout: one long sheet; every study is a paper/ink pair, side by side, stacked when narrow */
body{{background:var(--page);color:var(--page-ink);font:14px/1.5 system-ui,sans-serif}}
.wrap{{max-width:1640px;margin:0 auto;padding-block:48px 80px;
 padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}}
header{{display:flex;flex-wrap:wrap;gap:24px 48px;align-items:end;margin-bottom:40px}}
h1{{font:300 40px/1 "Gravure",system-ui;letter-spacing:.02em;margin:0}}
header p{{margin:0;max-width:62ch;color:var(--page-mute)}}
header code{{color:var(--page-ink)}}
section{{margin-top:56px}}
h2{{font:500 12px/1 var(--mono);letter-spacing:.16em;text-transform:uppercase;color:var(--page-mute);margin:0 0 16px}}
.pair{{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,640px),1fr))}}
.panel{{background:var(--bg);color:var(--ink);padding:28px clamp(16px,3vw,40px) 36px;min-width:0}}
.l{{{t(LIGHT)}}} .d{{{t(DARK)}}}
.cap{{font:500 11px/1 var(--mono);letter-spacing:.16em;text-transform:uppercase;color:var(--mute);
 margin:0 0 20px;padding-bottom:16px;border-bottom:1px solid var(--line)}}
.row,.trow{{display:grid;grid-template-columns:140px 1fr;gap:16px 24px;padding:18px 0;border-bottom:1px solid var(--line)}}
.row:last-child,.trow:last-child{{border-bottom:0}}
@media (max-width:700px){{.row,.trow{{grid-template-columns:1fr}}}}
.rowlab{{margin:0;font:400 12px/1.4 var(--mono);color:var(--mute)}}
.rowlab b{{display:block;font-size:20px;font-weight:500;color:var(--ink);margin-bottom:4px;font-family:system-ui}}
.cells,.words{{display:flex;flex-wrap:wrap;gap:20px 36px;min-width:0}}
figure{{margin:0}}
figcaption{{font:400 11px/1.4 var(--mono);letter-spacing:.06em;color:var(--mute);margin-top:10px}}
figcaption b{{color:var(--ink);font-weight:600}}
.cell svg{{display:block}}
.small{{display:flex;align-items:center;gap:14px;margin-top:14px}}
.bar{{display:inline-flex;align-items:center;height:24px;padding:0 10px;border-radius:5px;
 background:color-mix(in srgb,var(--ink) 7%,var(--bg))}}
.w{{display:block;font-size:56px;line-height:1.1}}
.caps{{font-size:34px;letter-spacing:.24em;line-height:1.85}}
.lock{{display:flex;flex-wrap:wrap;align-items:center;gap:6px 14px}}
.lock .w{{font-size:40px}}
.lock figcaption{{flex-basis:100%}}
.kanji{{font:300 15px/1 "Noto Serif JP","Hiragino Mincho ProN",serif;color:var(--mute);letter-spacing:.2em;
 writing-mode:vertical-rl}}
.accs{{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:28px}}
.acc svg{{color:var(--a)}}
.accsym{{display:flex;align-items:center;gap:16px}}
.acc code{{font:inherit;color:var(--ink)}}
.acc i{{font-style:normal}}
"""

def page():
    fonts = "".join(face_css(n, r) for n, r, _ in FACES)
    return f"""<title>byaku Brand Studies</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+JP:wght@300&display=swap">
<style>{fonts}{css()}</style>
<div class="wrap">
<header><h1>byaku</h1><p>Round 1 of the brand. Six symbol ideas in three weights, five typefaces, four violets.
Every study shows paper and ink side by side, and the small icons in the grey pill are the 16&nbsp;px menu-bar size.
Reply with codes, for example <code>E2, Gravure 300, P3</code>, plus anything you'd push further.</p></header>
<section id="symbols"><h2>Symbol</h2>{pair(symbols, "symbol")}</section>
<section id="type"><h2>Wordmark</h2>{pair(type_, "wordmark")}</section>
<section id="palette"><h2>Accent</h2><div class="pair">{panel("l", palette("l"), "accent")}{panel("d", palette("d"), "accent")}</div></section>
</div>"""

if __name__ == "__main__":
    html = page()
    (OUT / "explore.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1640, "height": 1000}, device_scale_factor=2)
        pg.set_content(f'<!doctype html><html><head><meta charset="utf-8"><style>body{{margin:0}}</style></head><body>{html}</body></html>',
                       wait_until="networkidle")
        pg.evaluate("document.fonts.ready")
        for s in ("symbols", "type", "palette"):
            pg.locator(f"#{s} .pair").screenshot(path=str(OUT / f"sheet-{s}.png"))
        b.close()
    print("wrote", OUT / "explore.html", "and 3 sheets")
