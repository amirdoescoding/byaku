"""byaku landing-page mockups. Writes ../mockups.html and ../sheet-*.png.  Run: python3 build.py  (stdlib + the headless shell only)"""
import pathlib, re, subprocess
OUT = pathlib.Path(__file__).resolve().parent.parent
FINAL = OUT.parent / "brand/final"
SHELL = pathlib.Path.home() / "Library/Caches/ms-playwright/chromium_headless_shell-1255/chrome-headless-shell-mac-arm64/chrome-headless-shell"

# ---- real geometry --------------------------------------------------------------------------------------------------
sym = (FINAL / "symbol-dark.svg").read_text()
RING = re.search(r'<path d="[^"]*" fill="none"[^>]*/>', sym).group(0).replace('stroke="#C8BFEF"', 'stroke="currentColor"')
BL = re.findall(r'<path fill="#C8BFEF" d="([^"]+)"/>', sym)
def mascot(expr="idle", style=""):
    return (f'<svg class="mascot e-{expr}" style="{style}" viewBox="0 0 64 64" aria-hidden="true">{RING}'
            f'<path class="b l" fill="currentColor" d="{BL[0]}"/><path class="b r" fill="currentColor" d="{BL[1]}"/></svg>')
WORD = re.sub(r' fill="#ECEBF0"', '', (FINAL / "wordmark-dark.svg").read_text()).replace("<svg ", '<svg role="img" aria-label="byaku" ', 1)

# ---- copy (stop-slop pass: short, concrete, no filler) ----------------------------------------------------------------
HEADS = ["Know who's looking.", "Look who's looking.", "Eyes off my screen.", "Only you look."]
SUB = "byaku watches your webcam for faces that aren't yours. It warns you, or locks the screen when you're away. Nothing leaves your Mac."
ARROW = '<svg viewBox="0 0 12 12"><path d="M6 1v10M1.5 6.5L6 11l4.5-4.5"/></svg>'
CUE = f'<div class="cue tag">See it happen {ARROW}</div>'
T = lambda t: "ink" if t == "dark" else "paper"
def nav(): return f'<div class="bar">{WORD}<a href="#">GitHub</a></div>'
def pillhtml(state="", cls=""):
    e = {"": "idle", "hover": "happy", "press": "joy"}[state]
    return f'<a class="pill {state} {cls}" href="#">{mascot(e)}Download for Mac</a>'
def hero(theme, size, head=HEADS[0]):
    w, h = (1440, 900) if size == "d" else (375, 812)
    return (f'<div class="f {size} {T(theme)}" style="width:{w}px;height:{h}px">{nav()}<div class="hero">{mascot("idle")}<h1>{head}</h1>'
            f'<p class="sub">{SUB}</p><a class="btn" href="#">Download for Mac</a><p class="cap">Apple silicon · macOS 14+</p></div>{CUE}</div>')
def fig(cap, node, note=""):
    return f'<figure><figcaption>{cap}<span>{note}</span></figcaption>{node}</figure>'

# ---- headline strip -------------------------------------------------------------------------------------------------
def small(theme, head):
    return (f'<div class="f {T(theme)}" style="width:520px;height:420px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">'
            f'{mascot("idle", "width:112px;height:112px;margin-bottom:28px")}<h1 style="font-size:52px;padding:0 16px">{head}</h1>'
            f'<a class="btn" style="margin-top:32px;height:46px;font-size:16px" href="#">Download for Mac</a></div>')
def headlines():
    notes = ["lead · 19 chars", "19 · plays on the lead", "19 · says it to the looker", "14 · a claim, not a verb"]
    return "".join(fig(f"{i+1}. {h}", small(t, h), notes[i]) for t in ("dark", "light") for i, h in enumerate(HEADS))

# ---- pill -----------------------------------------------------------------------------------------------------------
STATES = [("", "rest", "brows idle"), ("hover", "hover", "happy: brows lift, mark rises 2 px"), ("press", "press", "joy: brows high and out, mark squashes, pill scales .96")]
def tile(theme, state, mobile=False):
    lines = "".join(f'<i style="width:{p}%"></i>' for p in (62, 88, 74, 40))
    return (f'<div class="f {"m" if mobile else "d"} {T(theme)} tile" style="width:{375 if mobile else 520}px;height:240px"><div class="ln">{lines}</div>'
            f'<div class="dock">{pillhtml(state, "dk")}</div></div>')
def pills():
    g = "".join(fig(f"{t} · {n}", tile(t, s), d) for t in ("dark", "light") for s, n, d in STATES)
    mob = fig("375 dark · rest", tile("dark", "", True), "full width minus 16 px each side") + fig("375 light · press", tile("light", "press", True), "same, pressed")
    return f'<div class="grid3">{g}</div><div class="row" style="margin-top:32px">{mob}</div>'

# ---- demo -----------------------------------------------------------------------------------------------------------
MODES = [("Whisper", "A banner. Nothing else."), ("Iris", "Violet mist at the screen edges. The default."), ("Shade", "The screen dims."), ("Awaken", "Dim, plus violet edges.")]
def sp(c): return f'<path d="{BL[0]}" fill="{c}"/><path d="{BL[1]}" fill="{c}"/>' + RING.replace("currentColor", c)
def screen(theme, away):
    """Flat 2D Mac screen, 880 x 550, real size. The lock screen is always dark, as on macOS."""
    k = {"dark": dict(s="#17161C", bg="#0E0D12", line="#25232C", mute="#8F8C99", ink="#ECEBF0", acc="#C8BFEF"),
         "light": dict(s="#FFFFFF", bg="#F5F5F7", line="#E1E0E6", mute="#66636F", ink="#0E0D12", acc="#6A5DB8")}[theme]
    font = 'font-family="Beacon,system-ui,sans-serif"'
    uid = f"{theme}{int(away)}"
    if away:
        rings = "".join(f'<circle cx="440" cy="190" r="{r}" fill="none" stroke="#C8BFEF" stroke-width="2" opacity="{o}"/>' for r, o in ((60, 1), (98, .6), (136, .3)))
        inner = (f'<rect width="880" height="550" fill="#0E0D12"/>{rings}'
                 f'<rect x="418" y="187" width="44" height="34" rx="6" fill="#0E0D12" stroke="#ECEBF0" stroke-width="2.5"/><path d="M426 187v-12a14 14 0 0 1 28 0v12" fill="none" stroke="#ECEBF0" stroke-width="2.5"/>'
                 f'<text x="440" y="372" text-anchor="middle" {font} font-size="56" font-weight="300" fill="#ECEBF0">9:41</text>'
                 f'<text x="440" y="404" text-anchor="middle" {font} font-size="16" fill="#8F8C99">Locked. Someone else looked.</text>'
                 f'<rect x="350" y="440" width="180" height="36" rx="18" fill="none" stroke="#8F8C99"/><text x="440" y="463" text-anchor="middle" {font} font-size="14" fill="#8F8C99">Enter Password</text>')
    else:
        bars = "".join(f'<rect x="156" y="{y}" width="{w}" height="10" rx="5" fill="{k["mute"]}" opacity=".28"/>' for y, w in ((190, 520), (216, 470), (242, 500), (268, 360), (320, 510), (346, 440), (372, 300)))
        dirs = {"t": 'x1="0" y1="0" x2="0" y2="1"', "b": 'x1="0" y1="1" x2="0" y2="0"', "l": 'x1="0" y1="0" x2="1" y2="0"', "r": 'x1="1" y1="0" x2="0" y2="0"'}
        mist = "".join(f'<linearGradient id="{i}{uid}" {a}><stop offset="0" stop-color="{k["acc"]}" stop-opacity=".75"/><stop offset="1" stop-color="{k["acc"]}" stop-opacity="0"/></linearGradient>' for i, a in dirs.items())
        rects = {"t": 'x="0" y="26" width="880" height="28"', "b": 'x="0" y="522" width="880" height="28"', "l": 'x="0" y="26" width="44" height="524"', "r": 'x="836" y="26" width="44" height="524"'}
        strips = "".join(f'<rect {r} fill="url(#{i}{uid})"/>' for i, r in rects.items())
        inner = (f'<defs>{mist}</defs><rect width="880" height="550" fill="{k["bg"]}"/>'
                 f'<rect x="120" y="86" width="640" height="400" rx="10" fill="{k["s"]}" stroke="{k["line"]}"/><line x1="120" x2="760" y1="126" y2="126" stroke="{k["line"]}"/>'
                 f'<rect x="156" y="150" width="220" height="14" rx="7" fill="{k["ink"]}" opacity=".85"/>{bars}{strips}'
                 f'<rect width="880" height="26" fill="{k["s"]}"/><line x1="0" x2="880" y1="26" y2="26" stroke="{k["line"]}"/>'
                 f'<text x="16" y="17.5" {font} font-size="12" fill="{k["mute"]}">Finder   File   Edit   View</text>'
                 f'<text x="864" y="17.5" text-anchor="end" {font} font-size="12" fill="{k["mute"]}">9:41</text>'
                 f'<svg x="770" y="5" width="16" height="16" viewBox="0 0 64 64">{sp(k["ink"])}</svg>'
                 f'<rect x="564" y="38" width="300" height="64" rx="12" fill="{k["s"]}" stroke="{k["line"]}"/>'
                 f'<svg x="582" y="58" width="24" height="24" viewBox="0 0 64 64">{sp(k["acc"])}</svg>'
                 f'<text x="620" y="66" {font} font-size="14" font-weight="600" fill="{k["ink"]}">Someone else is looking</text>'
                 f'<text x="620" y="86" {font} font-size="13" fill="{k["mute"]}">Mind your screen.</text>')
    st = (f'<g fill="none" stroke="{k["mute"]}" stroke-width="2"><circle cx="1000" cy="300" r="30"/><path d="M944 430a56 56 0 0 1 112 0"/>'
          f'<path d="M966 300H894" stroke-dasharray="3 7" stroke-linecap="round"/></g>'
          f'<text x="1000" y="456" text-anchor="middle" {font} font-size="13" fill="{k["mute"]}">Someone behind you</text>')
    label = "The Mac is locked and pulses." if away else "A violet mist and a banner show a stranger is looking."
    return (f'<svg width="1080" height="550" viewBox="0 0 1080 550" role="img" aria-label="A Mac screen. {label}"><clipPath id="c{uid}"><rect x="1" y="1" width="878" height="548" rx="15"/></clipPath>'
            f'<g clip-path="url(#c{uid})">{inner}</g><rect x=".5" y=".5" width="879" height="549" rx="16" fill="none" stroke="{k["line"]}"/>{st}</svg>')
def seg(items, on, label, off=False):
    b = "".join(f'<button type="button" aria-pressed="{str(n == on).lower()}"{" disabled" if off else ""}>{n}</button>' for n in items)
    return f'<div class="seg{" off" if off else ""}" role="group" aria-label="{label}">{b}</div>'
def demo(theme, away, mode="Iris"):
    line = ("Away: any looker sounds the alarm and locks the Mac. Modes don't apply. This demo is silent." if away else f"<b>{mode}.</b> {dict(MODES)[mode]}")
    return (f'<div class="f d {T(theme)}" style="width:1440px;height:1000px"><div class="demo"><p class="tag">Demo</p><h2>See it happen.</h2>'
            f'<p class="sub" style="margin:14px 0 36px">Pick a mode. Someone looks. byaku answers.</p>{screen(theme, away)}'
            f'<div class="ctl">{seg(["Guard", "Away"], "Away" if away else "Guard", "Guard or Away")}<i class="vr"></i>{seg([m for m, _ in MODES], mode, "Mode", away)}</div>'
            f'<p class="dline">{line}</p></div></div>')

# ---- privacy --------------------------------------------------------------------------------------------------------
STATS = [("0", "frames saved", "Each frame is checked once, then dropped. Nothing is written to disk, logged or sent."),
         ("0", "network calls", "The app never goes online. The models ship inside it."),
         ("1", "click to delete your face", "Your face template stays on your Mac. One click removes it.")]
FOOT = "This site counts visits, with no cookies. byaku counts nothing."
def privacy(size):
    if size == "d":
        cols = "".join(f'<div class="st"><div class="n">{n}</div><h3>{t}</h3><p>{b}</p></div>' for n, t, b in STATS)
        return (f'<div class="f d ink" style="width:1440px;height:700px"><div class="col"><p class="tag">Privacy</p><h2 style="font-size:84px;margin-top:10px">Nothing leaves<br>your Mac.</h2>'
                f'<div class="stats">{cols}</div><p class="foot">{FOOT}</p></div>'
                f'{mascot("calm", "position:absolute;left:132px;top:300px;width:72px;height:72px")}'
                f'<span class="gut" style="left:0;width:240px"></span><span class="gut" style="right:0;width:240px"></span></div>')
    rows = "".join(f'<div class="st"><div class="n">{n}</div><div><h3>{t}</h3><p>{b}</p></div></div>' for n, t, b in STATS)
    return (f'<div class="f m paper" style="width:375px;height:700px"><div class="col"><p class="tag">Privacy</p><h2 style="font-size:46px;margin-top:10px">Nothing leaves<br>your Mac.</h2>'
            f'<div class="stats">{rows}</div><p class="foot">{FOOT}</p></div></div>')

# ---- faq ------------------------------------------------------------------------------------------------------------
FAQ = [("Is the camera always recording?", "No. byaku reads each frame, checks for faces and drops it. Nothing is saved or sent. macOS shows its camera indicator whenever the camera is on."),
       ("Does it work in the dark?", "Less well. A webcam needs enough light to see a face, and in a very dark room it can miss someone."),
       ("How much battery does it use?", "The target is under 1.5 W extra on Apple silicon, measured on battery with the camera on."),
       ("Why does macOS say it can't verify byaku?", "byaku isn't notarized yet. That needs a paid Apple developer account. Open System Settings, then Privacy & Security, scroll down and choose Open Anyway. You do this once per download."),
       ("How do I delete my face data?", "Choose Delete face in the byaku menu. The template is removed at once.")]
def faq(theme, open_i=3):
    items = "".join(f'<div class="q{" open" if i == open_i else ""}"><button type="button" aria-expanded="{str(i == open_i).lower()}">{q}<svg viewBox="0 0 14 14"><path d="M1 7h12"/><path class="v" d="M7 1v12"/></svg></button>'
                    + (f'<p>{a}</p>' if i == open_i else '') + '</div>' for i, (q, a) in enumerate(FAQ))
    return (f'<div class="f m {T(theme)}" style="width:375px;height:780px"><div class="col"><p class="tag">FAQ</p><h2 style="font-size:46px;margin-top:10px">Questions.</h2><div class="acc">{items}</div></div>'
            f'<div class="dock">{pillhtml("", "dk")}</div></div>')

# ---- mascot chart ---------------------------------------------------------------------------------------------------
EXPRS = [("idle", "hero, resting"), ("raised", "modes: curious"), ("focus", "demo: watching"), ("calm", "privacy: relaxed"), ("look", "FAQ: side-eye"),
         ("frown", "Away, alarm"), ("happy", "pill hover"), ("joy", "pill press")]
def chart(theme):
    return "".join(f'<figure class="ex {T(theme)}">{mascot(e, "width:112px;height:112px")}<figcaption>{e}<span>{n}</span></figcaption></figure>' for e, n in EXPRS)

# ---- contrast -------------------------------------------------------------------------------------------------------
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= .03928 else ((x + .055) / 1.055) ** 2.4 for x in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]
def cr(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True); return (x + .05) / (y + .05)
P = {"light": dict(bg="#F5F5F7", surface="#FFFFFF", mute="#66636F", ink="#0E0D12", accent="#6A5DB8"),
     "dark": dict(bg="#0E0D12", surface="#17161C", mute="#8F8C99", ink="#ECEBF0", accent="#C8BFEF")}
PAIRS = [("ink", "bg", "headline, body, FAQ question", 4.5), ("mute", "bg", "sub, caption, tags, inactive toggle, FAQ answer", 4.5), ("mute", "surface", "banner body line", 4.5),
         ("ink", "surface", "banner title", 4.5), ("bg", "ink", "button, pill and active toggle label", 4.5), ("accent", "bg", "mascot, focus ring (non-text)", 3), ("accent", "surface", "banner mark (non-text)", 3)]
LOCK = [("#ECEBF0", "#0E0D12", "lock clock, glyph", 4.5), ("#8F8C99", "#0E0D12", "lock caption, field", 4.5), ("#C8BFEF", "#0E0D12", "siren rings (non-text)", 3)]
def contrast():
    rows = [(t, f"{a} on {b}", u, cr(P[t][a], P[t][b]), n) for t in ("light", "dark") for a, b, u, n in PAIRS]
    rows += [("both", f"{a} on {b}", u, cr(a, b), n) for a, b, u, n in LOCK]
    bad = [r[:2] for r in rows if r[3] < r[4]]
    body = "".join(f'<tr><td>{t}</td><td>{p}</td><td>{u}</td><td>{r:.2f}:1</td><td>{"pass" if r >= n else "FAIL"} ({n})</td></tr>' for t, p, u, r, n in rows)
    return f'<table><tr><th>Theme</th><th>Pair</th><th>Used for</th><th>Ratio</th><th>Needs</th></tr>{body}</table>', bad

# ---- page -----------------------------------------------------------------------------------------------------------
CSS = """
body{font:14px/1.4 Beacon,system-ui;background:#2B2A31;color:#ECEBF0}
main>section{padding:48px}
figure{display:flex;flex-direction:column;gap:10px}
figcaption{font:500 14px Beacon,system-ui;color:#ECEBF0}figcaption span{display:block;font-weight:400;color:#B4B1BE;margin-top:2px}
.row{display:flex;gap:48px;align-items:flex-start}
.grid3{display:grid;grid-template-columns:repeat(3,520px);gap:32px}
.hd{display:grid;grid-template-columns:repeat(4,520px);gap:32px}
.ex{align-items:center;padding:24px 8px 16px;width:160px;border-radius:12px;background:var(--bg)}.ex figcaption{color:var(--ink);text-align:center}.ex figcaption span{color:var(--mute)}
.exr{display:flex;gap:12px;margin-bottom:24px}
h2{font-size:64px;line-height:1.04}
.demo{display:flex;flex-direction:column;align-items:center;padding-top:48px}
.demo h2{margin:10px 0 0}.demo svg{overflow:visible}
.ctl{display:flex;align-items:center;gap:24px;margin-top:36px}.vr{width:1px;height:28px;background:var(--line)}
.seg{display:inline-flex;gap:2px;padding:4px;border:1px solid var(--line);border-radius:999px}
.seg button{font:500 15px Beacon,system-ui;height:36px;padding:0 20px;border:0;border-radius:999px;background:none;color:var(--mute);cursor:pointer}
.seg button[aria-pressed=true]{background:var(--ink);color:var(--bg)}
.seg.off button{opacity:.45}.seg.off button[aria-pressed=true]{background:none;color:var(--mute)}
.dline{margin-top:22px;font-size:16px;color:var(--mute)}.dline b{color:var(--ink);font-weight:500}
.col{max-width:960px;margin:0 auto;padding:96px 0 0}.f.m .col{padding:56px 20px 0}
.f.d .stats{display:grid;grid-template-columns:repeat(3,1fr);gap:48px;margin-top:56px;border-top:1px solid var(--line);padding-top:40px}
.n{font:500 120px/1 Rondel;letter-spacing:-.03em}.f.m .n{font-size:64px;min-width:56px}
.st h3{font:500 18px Beacon;margin-top:16px}.f.m .st h3{margin-top:0}.st p{font-size:15px;color:var(--mute);margin-top:8px;max-width:30ch}
.f.m .st{display:flex;gap:20px;align-items:flex-start;border-top:1px solid var(--line);padding:24px 0}.f.m .stats{margin-top:36px}
.foot{font-size:14px;color:var(--mute);margin-top:48px}.f.m .foot{margin-top:8px}
.gut{position:absolute;top:0;bottom:0;border:1px dashed var(--line);border-width:0 1px}
.acc{margin-top:28px}.q{border-top:1px solid var(--line)}.q:last-child{border-bottom:1px solid var(--line)}
.q button{display:flex;justify-content:space-between;align-items:center;gap:16px;width:100%;min-height:64px;padding:16px 0;background:none;border:0;color:var(--ink);font:500 17px/1.3 Beacon,system-ui;text-align:left;cursor:pointer}
.q svg{flex:none;width:14px;height:14px;stroke:var(--ink);fill:none;stroke-width:1.6}.q.open .v{display:none}
.q p{font-size:16px;color:var(--mute);padding:0 32px 22px 0}
.tile .ln{padding:28px 32px;display:flex;flex-direction:column;gap:12px}.tile .ln i{display:block;height:10px;border-radius:5px;background:var(--line)}
.dock{position:absolute;left:0;right:0;bottom:24px;display:flex;justify-content:center}
.f.m .dock{left:16px;right:16px;bottom:16px}.f.m .dock .pill{width:100%;justify-content:center;padding-left:0}
table{border-collapse:collapse;font-size:13px}td,th{padding:5px 20px 5px 0;text-align:left;border-bottom:1px solid #45434E}
.sh{font:600 13px Beacon;letter-spacing:.12em;text-transform:uppercase;color:#B4B1BE;margin-bottom:20px}
"""
SECTIONS = {  # id: (title, html, window w, h, scale)
 "hero": ("Hero 1440", f'<div class="row">{fig("1440 dark", hero("dark","d"), "Rondel 500 104/106, mascot 240")}{fig("1440 light", hero("light","d"), "accent flips to dusk violet")}</div>', 3024, 1060, 1),
 "hero-mobile": ("Hero 375", f'<div class="row">{fig("375 dark", hero("dark","m"))}{fig("375 light", hero("light","m"))}</div>', 894, 960, 1),
 "headlines": ("Headline options", f'<div class="hd">{headlines()}</div>', 2296, 1060, 1),
 "pill": ("Pill docked", pills(), 1752, 1140, 2),
 "demo": ("Demo", f'<div class="row">{fig("Guard · Iris · dark site", demo("dark", False))}{fig("Away · locked · light site, the lock screen is always dark", demo("light", True))}</div>', 3024, 1180, 1),
 "privacy": ("Privacy", f'<div class="row">{fig("1440 dark", privacy("d"), "dashed = the 240 px gutters the roaming mascot may use")}{fig("375 light", privacy("m"))}</div>', 1980, 900, 1),
 "faq": ("FAQ", f'<div class="row">{fig("375 dark · accordion open", faq("dark"))}{fig("375 light", faq("light"))}</div>', 894, 900, 1),
 "mascot": ("Mascot expressions", f'<div class="exr">{chart("dark")}</div><div class="exr">{chart("light")}</div>', 1400, 540, 2),
}
def page():
    tbl, bad = contrast()
    sec = "".join(f'<section id="{k}"><h1 class="sh" style="font-family:Beacon;letter-spacing:.12em">{v[0]}</h1>{v[1]}</section>' for k, v in SECTIONS.items())
    return ('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>byaku site mockups</title><link rel="stylesheet" href="site.css"><style>' + CSS +
            f'</style></head><body><main>{sec}<section id="contrast"><p class="sh">WCAG contrast</p>{tbl}</section></main>'
            '<script>const h=location.hash.slice(1);if(h)document.querySelectorAll("main>section").forEach(s=>s.hidden=s.id!=h)</script></body></html>'), bad

if __name__ == "__main__":
    html, bad = page()
    (OUT / "mockups.html").write_text(html)
    print("contrast failures:", bad or "none")
    for k, (_, _, w, h, sc) in SECTIONS.items():
        subprocess.run([str(SHELL), "--allow-file-access-from-files", "--hide-scrollbars", f"--force-device-scale-factor={sc}", f"--window-size={w},{h}",
                        "--virtual-time-budget=4000", f"--screenshot={OUT}/sheet-{k}.png", f"file://{OUT}/mockups.html#{k}"], capture_output=True)
        print("sheet", k)
