"""byaku brand, final set: symbol E2 + Rondel 500, pale iris on ink, dusk violet on paper.
Writes ../final/*.svg, ../palette.md, ../brand.html and ../sheet-final.png.
Run from this folder:
  uv run --with fonttools --with brotli --with uharfbuzz --with playwright python final.py"""
import io, re, sys, pathlib, urllib.request
HERE = pathlib.Path(__file__).resolve().parent
BRAND = HERE.parent
FONTS = HERE.parents[2] / "assets" / "fonts"
sys.path.insert(0, str(BRAND / "explore" / "src"))
from gen import C, stroke, blade, contrast  # round-1 geometry + WCAG maths (concept E)
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
import uharfbuzz as hb

# ---- colour ---------------------------------------------------------------------------------------
PAPER, INK, IRIS, DUSK = "#F5F5F7", "#0E0D12", "#C8BFEF", "#6A5DB8"
TH = {"light": dict(bg=PAPER, surface="#FFFFFF", line="#E1E0E6", mute="#66636F", ink=INK, accent=DUSK),
      "dark": dict(bg=INK, surface="#17161C", line="#25232C", mute="#8F8C99", ink="#ECEBF0", accent=IRIS)}

# ---- symbol: thin ring, two blade crescents (long at 8-11 o'clock, short at 2-3) -----------------
def ring(w):
    R = 28 - w / 2
    return f"M{C+R} {C}A{R} {R} 0 1 1 {C-R} {C}A{R} {R} 0 1 1 {C+R} {C}"
def symbol(col, small=False):
    """Main = E2 as picked in round 1. The blades sit above centre on purpose (user kept it over a centred version). Small (<=32 px) thickens the ring and the short blade so 16 px still reads."""
    rw, bw, short = (4.5, 6.5, (-60, 20)) if small else (2.25, 5.85, (-52, 14))
    body = stroke(ring(rw), rw) + blade(17, 138, 252, bw) + blade(17, *short, bw)
    return body.replace("currentColor", col)
def svg(body, vb="0 0 64 64", extra=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"{extra}>{body}</svg>'

# ---- type outlines (shaped with HarfBuzz so kerning matches the browser) ---------------------------
def load(path, wght):
    f = TTFont(path)
    if "fvar" in f: f = instantiateVariableFont(f, {"wght": wght})
    f.flavor = None; b = io.BytesIO(); f.save(b); data = b.getvalue()
    return TTFont(io.BytesIO(data)), hb.Font(hb.Face(data))
def outline(font, text, size, x=0, y=0):
    """Path for `text` at `size` units, baseline at (x, y). Returns (d, (xmin, ymin, xmax, ymax), advance)."""
    f, hbf = font
    buf = hb.Buffer(); buf.add_str(text); buf.guess_segment_properties(); hb.shape(hbf, buf)
    k, order, gs = size / f["head"].unitsPerEm, f.getGlyphOrder(), f.getGlyphSet()
    pen, bp, px = SVGPathPen(gs), BoundsPen(gs), 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        t = (k, 0, 0, -k, x + (px + pos.x_offset) * k, y - pos.y_offset * k)
        gs[order[info.codepoint]].draw(TransformPen(pen, t)); gs[order[info.codepoint]].draw(TransformPen(bp, t))
        px += pos.x_advance
    return pen.getCommands(), bp.bounds, px * k

def kanji_font():
    """Noto Serif JP Light (OFL), subset to 白眼 by Google Fonts. Fetched once and kept in assets/fonts."""
    p = FONTS / "NotoSerifJP" / "noto-serif-jp-300-subset.woff2"
    if not p.exists():
        ua = {"User-Agent": "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/120 Safari/537.36"}
        css = urllib.request.urlopen(urllib.request.Request(
            "https://fonts.googleapis.com/css2?family=Noto+Serif+JP:wght@300&text=%E7%99%BD%E7%9C%BC", headers=ua)).read().decode()
        url = re.search(r"url\((https://[^)]+)\)", css).group(1)
        p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(urllib.request.urlopen(url).read())
    return load(p, 300)

RONDEL = load(FONTS / "Rondel" / "rondel.woff2", 500)
# Lockup proportions reproduce the round-1 sheet the user picked: 44 px symbol, 40 px type, 14 px gaps.
U = 64 / 44                      # px -> symbol units
SIZE, GAP = 40 * U, 14 * U
def word_layout():
    f = RONDEL[0]; hh = f["hhea"]; k = SIZE / f["head"].unitsPerEm
    asc, desc = hh.ascent * k, -hh.descent * k
    base = (1.1 * SIZE - asc - desc) / 2 + asc - (1.1 * SIZE - 64) / 2  # CSS line box (1.1) centred on the 64 box
    return outline(RONDEL, "byaku", SIZE, 64 + GAP, base)
def kanji_layout(x):
    s = 15 * U; parts, xs = [], []
    for i, ch in enumerate("白眼"):
        d, bb, _ = outline(KANJI, ch, s, x, i * 1.2 * s); parts.append(d); xs.append(bb)
    ymin, ymax = min(b[1] for b in xs), max(b[3] for b in xs)
    dy = 32 - (ymin + ymax) / 2
    return "".join(parts), (min(b[0] for b in xs), ymin + dy, max(b[2] for b in xs), ymax + dy), dy

def lockup(theme, kanji=False):
    t = TH[theme]; d, (x0, y0, x1, y1), _ = word_layout()
    body = f'<path fill="{t["ink"]}" d="{d}"/>'
    if kanji:
        kd, kb, dy = kanji_layout(x1 + GAP)
        body += f'<path fill="{t["mute"]}" transform="translate(0 {dy:.3f})" d="{kd}"/>'
        x1, y0, y1 = kb[2], min(y0, kb[1]), max(y1, kb[3])
    top, bot = min(4, y0), max(60, y1)
    return svg(symbol(t["accent"]) + body, f"4 {top:.2f} {x1 - 4:.2f} {bot - top:.2f}")
def wordmark(theme):
    d, (x0, y0, x1, y1), _ = outline(RONDEL, "byaku", 100)
    return svg(f'<path fill="{TH[theme]["ink"]}" d="{d}"/>', f"{x0:.2f} {y0:.2f} {x1 - x0:.2f} {y1 - y0:.2f}")
def app_icon():
    """macOS icon grid: 824 px rounded square inside 1024, ring 560 px across."""
    s = 560 / 56
    return svg(f'<rect x="100" y="100" width="824" height="824" rx="185" fill="{INK}" stroke="#2C2A35" stroke-width="4"/>'
               f'<g transform="translate(512 512) scale({s}) translate(-32 -32)">{symbol(IRIS)}</g>', "0 0 1024 1024")

# ---- palette.md (ratios computed, never typed) ------------------------------------------------------
def palette_md():
    rows = "\n".join(f"| {k} | {TH['light'][k]} | {TH['dark'][k]} |" for k in TH["light"])
    pairs = [("accent on bg", "accent", "bg"), ("accent on surface", "accent", "surface"),
             ("ink on bg", "ink", "bg"), ("mute on bg", "mute", "bg"), ("mute on surface", "mute", "surface")]
    def v(r): return "AA text" if r >= 4.5 else "graphics / large text" if r >= 3 else "fails"
    cr = "\n".join(f"| {n} | {contrast(TH['light'][a], TH['light'][b]):.2f}:1 {v(contrast(TH['light'][a], TH['light'][b]))} "
                   f"| {contrast(TH['dark'][a], TH['dark'][b]):.2f}:1 {v(contrast(TH['dark'][a], TH['dark'][b]))} |"
                   for n, a, b in pairs)
    return f"""# byaku palette

Paper and ink, plus one violet. The accent changes hex between themes, because pale iris is the true colour but
can't be seen on paper ({contrast(IRIS, PAPER):.2f}:1).

- **Pale iris `{IRIS}`**: the accent on ink (dark). It is the Byakugan colour.
- **Dusk violet `{DUSK}`**: the accent on paper (light). Pale iris, darkened until it reads.

The accent appears once per composition and is never a gradient or a glow. In the app, violet means *seen*:
it is reserved for the symbol and for the "someone is looking" state. It is never decoration. Native macOS UI still
uses system colours (DESIGN.md §1). These tokens are for the brand, the README, the site and custom surfaces
such as the banner.

| Token | Light | Dark |
|---|---|---|
{rows}

## WCAG 2.x contrast
| Pair | Light | Dark |
|---|---|---|
{cr}

Generated by `src/final.py`. Edit the values there, not here.
"""

# ---- sheet / page -----------------------------------------------------------------------------------
def inl(s, h=None, w=None):
    a = (f' height="{h}"' if h else "") + (f' width="{w}"' if w else "")
    return s.replace("<svg ", f'<svg{a} aria-hidden="true" ', 1)
def panel(theme):
    t = TH[theme]
    sizes = "".join(f'<figure>{inl(svg(symbol(t["accent"])), n, n)}<figcaption>{n}</figcaption></figure>' for n in (64, 32, 24, 16)) + \
        '<span class="sp"></span>' + \
        "".join(f'<figure>{inl(svg(symbol(t["accent"], True)), n, n)}<figcaption>{n} small</figcaption></figure>' for n in (32, 24, 16))
    tpl = svg(symbol(t["ink"], True), "4 4 56 56")
    bar = (f'<div class="menubar"><span>{inl(tpl, 16, 16)}</span><span class="ghost"></span><span class="ghost"></span>'
           f'<span class="clock">Wed 14:02</span></div>')
    return f"""<div class="panel {theme[0]}">
<p class="cap">byaku · brand · {"paper" if theme == "light" else "ink"}</p>
<div class="hero">{inl(svg(symbol(t["accent"])), 220, 220)}</div>
<div class="row sizes">{sizes}</div>
<div class="row"><figure class="wide">{inl(lockup(theme), 64)}<figcaption>lockup</figcaption></figure></div>
<div class="row"><figure class="wide">{inl(lockup(theme, True), 64)}<figcaption>lockup with 白眼 (README, site, about)</figcaption></figure></div>
<div class="row two"><figure>{inl(wordmark(theme), 40)}<figcaption>wordmark, Rondel 500</figcaption></figure>
<figure>{bar}<figcaption>menu bar, template image at 16 pt</figcaption></figure></div>
<div class="row two"><figure>{inl(app_icon(), 132, 132)}<figcaption>app icon</figcaption></figure>
<div class="sw">{"".join(f'<figure><span style="background:{t[k]}"></span><figcaption>{k}<br><code>{t[k]}</code></figcaption></figure>' for k in t)}</div></div>
</div>"""

CSS = "".join(f".{n[0]}{{" + ";".join(f"--{k}:{v}" for k, v in t.items()) + "}" for n, t in TH.items()) + """
:root{--page:#17161C;--page-ink:#ECEBF0;--page-mute:#8F8C99;--mono:ui-monospace,"SF Mono",Menlo,monospace;color-scheme:dark}
/* layout: the final sheet, paper and ink side by side, stacked when narrow */
body{background:var(--page);color:var(--page-ink);font:14px/1.5 system-ui,sans-serif}
.wrap{max-width:1640px;margin:0 auto;padding-block:40px 72px;
 padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
.intro{margin:0 0 32px;max-width:64ch;color:var(--page-mute)}
.pair{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,640px),1fr))}
.panel{background:var(--bg);color:var(--ink);padding:28px clamp(16px,3vw,48px) 40px;min-width:0}
.cap{font:500 11px/1 var(--mono);letter-spacing:.16em;text-transform:uppercase;color:var(--mute);margin:0;
 padding-bottom:16px;border-bottom:1px solid var(--line)}
.hero{display:grid;place-items:center;padding:56px 0;border-bottom:1px solid var(--line)}
.row{display:flex;flex-wrap:wrap;align-items:flex-end;gap:20px 32px;padding:28px 0;border-bottom:1px solid var(--line)}
.row:last-child{border-bottom:0}
.row.two>*{flex:1 1 260px;min-width:0}
.sp{width:24px}
figure{margin:0}
.wide svg{max-width:100%;height:auto;max-height:64px;width:auto}
figure>svg{display:block}
figcaption{font:400 11px/1.4 var(--mono);letter-spacing:.04em;color:var(--mute);margin-top:12px}
code{font:inherit;color:var(--ink)}
.menubar{display:flex;align-items:center;gap:14px;height:28px;padding:0 14px;border-radius:7px;
 background:color-mix(in srgb,var(--ink) 8%,var(--bg));width:max-content;max-width:100%}
.menubar svg{display:block}
.ghost{width:16px;height:12px;border-radius:3px;background:color-mix(in srgb,var(--ink) 22%,transparent)}
.clock{font:500 12px/1 system-ui;color:var(--ink)}
.sw{display:flex;flex-wrap:wrap;gap:14px}
.sw span{display:block;width:44px;height:44px;border-radius:50%;box-shadow:inset 0 0 0 1px var(--line)}
.sw figcaption{margin-top:6px}
"""
def page():
    return f"""<title>byaku Brand</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>{CSS}</style>
<div class="wrap"><p class="intro">The final set: blade-arc symbol E2, Rondel 500 wordmark, pale iris on ink, dusk violet on paper.
The <i>small</i> symbol is the cut for 32&nbsp;px and below; the menu bar uses it as a black template image.</p>
<div class="pair" id="sheet">{panel("light")}{panel("dark")}</div></div>"""

if __name__ == "__main__":
    KANJI = kanji_font()
    out = BRAND / "final"; out.mkdir(exist_ok=True)
    files = {"symbol-light.svg": svg(symbol(DUSK)), "symbol-dark.svg": svg(symbol(IRIS)),
             "symbol-mono.svg": svg(symbol("currentColor")),
             "symbol-small-light.svg": svg(symbol(DUSK, True)), "symbol-small-dark.svg": svg(symbol(IRIS, True)),
             "menubar-template.svg": svg(symbol("#000", True), "4 4 56 56"),
             "wordmark-light.svg": wordmark("light"), "wordmark-dark.svg": wordmark("dark"),
             "lockup-light.svg": lockup("light"), "lockup-dark.svg": lockup("dark"),
             "lockup-kanji-light.svg": lockup("light", True), "lockup-kanji-dark.svg": lockup("dark", True),
             "app-icon.svg": app_icon()}
    for n, s in files.items(): (out / n).write_text(s)
    (BRAND / "palette.md").write_text(palette_md())
    html = page(); (BRAND / "brand.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1640, "height": 1000}, device_scale_factor=2)
        pg.set_content(f'<!doctype html><html><head><meta charset="utf-8"><style>body{{margin:0}}</style></head><body>{html}</body></html>')
        pg.locator("#sheet").screenshot(path=str(BRAND / "sheet-final.png")); b.close()
    print("wrote", len(files), "svgs, palette.md, brand.html, sheet-final.png")
