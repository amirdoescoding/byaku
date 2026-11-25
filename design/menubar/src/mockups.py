"""byaku menu-bar mockups from docs/designs/menubar.md (build 1). Pale Watch rules: design/brand/philosophy.md.
Writes ../mockups.html and ../sheet-{icons,menu,panel}.png. Run from this folder:
  uv run --with playwright python mockups.py"""
import math, pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent

TH = {"light": dict(bg="#F5F5F7", surface="#FFFFFF", line="#E1E0E6", mute="#66636F", ink="#0E0D12", accent="#6A5DB8",
                    bar="#E8E7EC", menu="rgba(246,246,248,.96)", hi="#0A64D8", sep="rgba(0,0,0,.1)", dis="rgba(0,0,0,.28)"),
      "dark": dict(bg="#0E0D12", surface="#17161C", line="#25232C", mute="#8F8C99", ink="#ECEBF0", accent="#C8BFEF",
                   bar="#1E1D23", menu="rgba(40,39,45,.96)", hi="#0A64D8", sep="rgba(255,255,255,.12)", dis="rgba(255,255,255,.3)")}

# ---- status icon: menubar-template.svg geometry (viewBox 4 4 56 56) + per-state shape change --------------
RING = '<path d="M57.75 32A25.75 25.75 0 1 1 6.25 32A25.75 25.75 0 1 1 57.75 32" fill="none" stroke="{c}" stroke-width="4.5"/>'
BLADES = ('<path fill="{c}" d="M19.367 43.375A17 17 0 0 1 26.747 15.832A82.511 82.511 0 0 0 19.367 43.375Z"/>'
          '<path fill="{c}" d="M40.500 17.278A17 17 0 0 1 47.975 37.814A100.374 100.374 0 0 0 40.500 17.278Z"/>')
# Error slash on x+y=64, clipped to the ring's outer edge (r 28): endpoints at 32 ± 28/√2.
S = 28 / math.sqrt(2)
SLASH = f"M{32 - S:.3f} {32 + S:.3f}L{32 + S:.3f} {32 - S:.3f}"

def icon(state, c, px=16):
    mark = RING.format(c=c) + ("" if state == "off" else BLADES.format(c=c))
    extra = ""
    if state == "alert":
        mark += f'<circle cx="32" cy="32" r="6" fill="{c}"/>'
    if state == "error":  # knock out 1.5 units either side of the slash, then draw it
        mid = f"m{state}{px}{c[1:]}"
        extra = (f'<mask id="{mid}"><rect x="0" y="0" width="64" height="64" fill="#fff"/>'
                 f'<path d="{SLASH}" stroke="#000" stroke-width="7.5"/></mask>')
        mark = f'<g mask="url(#{mid})">{mark}</g><path d="{SLASH}" stroke="{c}" stroke-width="4.5"/>'
    return (f'<svg width="{px}" height="{px}" viewBox="4 4 56 56" xmlns="http://www.w3.org/2000/svg" '
            f'aria-hidden="true">{extra}{mark}</svg>')

STATES = [("off", "Off", "empty ring"), ("guarding", "Guarding", "ring + crescents"),
          ("alert", "Alert", "+ centre dot, violet"), ("error", "Error", "+ diagonal cut")]

def icon_color(state, t):
    return TH[t]["accent"] if state == "alert" else TH[t]["ink"]

def bar(state, t):
    k = TH[t]
    ghosts = "".join('<span class="ghost"></span>' for _ in range(3))
    return (f'<div class="bar" style="background:{k["bar"]}"><span class="sp"></span>'
            f'{icon(state, icon_color(state, t))}{ghosts}<span class="clock" style="color:{k["ink"]}">Wed 14:02</span></div>')

def icons_sheet(t):
    k = TH[t]
    cells = "".join(
        f'<figure><div class="big">{icon(s, icon_color(s, t), 96)}</div>{bar(s, t)}'
        f'<figcaption style="color:{k["ink"]}">{name}<span style="color:{k["mute"]}">{note}</span></figcaption></figure>'
        for s, name, note in STATES)
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t}</p><div class="row4">{cells}</div></div>'

# ---- NSMenu ---------------------------------------------------------------------------------------------
def menu(t, status, items, state):
    k = TH[t]
    rows = []
    for it in items:
        if it == "-":
            rows.append(f'<div class="sepr" style="background:{k["sep"]}"></div>'); continue
        label, key, on, enabled = it
        col = k["ink"] if enabled else k["dis"]
        check = "✓" if on else ""
        rows.append(f'<div class="mi" style="color:{col}"><span class="ck">{check}</span><span class="lb">{label}</span>'
                    f'<span class="kc" style="color:{k["dis"] if not enabled else k["mute"]}">{key}</span></div>')
    return (f'<div class="mwrap">{bar(state, t)}<div class="menu" style="background:{k["menu"]};border-color:{k["sep"]}">'
            f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">{status}</span></div>'
            f'{"".join(rows)}</div></div>')

def menus_sheet(t):
    k = TH[t]
    q = ("Quit byaku", "⌘Q", False, True)
    cases = [
        ("not enrolled", "Set up your face to turn on Guard", "off",
         ["-", ("Guard", "⌘G", False, False), "-", ("Set up face…", "⌘E", False, True), ("Delete face data", "", False, False), "-", q]),
        ("guarding", "Guarding. Camera is on", "guarding",
         ["-", ("Guard", "⌘G", True, True), "-", ("Set up face again…", "⌘E", False, True), ("Delete face data", "", False, True), "-", q]),
        ("error", "Not guarding: camera access denied", "error",
         [("Open camera settings…", "", False, True), "-", ("Guard", "⌘G", True, True), "-",
          ("Set up face again…", "⌘E", False, True), ("Delete face data", "", False, True), "-", q]),
    ]
    cells = "".join(f'<figure>{menu(t, st, items, s)}<figcaption style="color:{k["mute"]}">{name}</figcaption></figure>'
                    for name, st, s, items in cases)
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t}</p><div class="row3">{cells}</div></div>'

# ---- enrollment panel ------------------------------------------------------------------------------------
CIRC = 2 * math.pi * 22
def ring48(t, phase, frac=0.0, n=""):
    k = TH[t]
    track = f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["line"]}" stroke-width="4"/>'
    if phase == "capture":
        body = track + (f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["ink"]}" stroke-width="4" '
                        f'stroke-dasharray="{frac * CIRC:.2f} {CIRC:.2f}" transform="rotate(-90 24 24)"/>')
        body += (f'<text x="24" y="24" dy=".36em" text-anchor="middle" fill="{k["ink"]}" '
                 f'style="font:600 20px -apple-system,system-ui;font-variant-numeric:tabular-nums">{n}</text>')
    elif phase == "ok":
        body = (f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["ink"]}" stroke-width="4"/>'
                f'<polyline points="15,25 21,31 33,18" fill="none" stroke="{k["ink"]}" stroke-width="3"/>')
    else:  # seam: 30° gap centred at 12 o'clock
        dash = CIRC * 330 / 360
        body = (f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["mute"]}" stroke-width="4" '
                f'stroke-dasharray="{dash:.2f} {CIRC:.2f}" transform="rotate(-75 24 24)"/>')
    return f'<svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">{body}</svg>'

def card(t, ring, title, body, buttons):
    k = TH[t]
    btns = "".join(
        f'<span class="btn" style="background:{k["ink"]};color:{k["bg"]};border-color:{k["ink"]}">{b[1:]}</span>' if b.startswith("*")
        else f'<span class="btn" style="color:{k["ink"]};border-color:{k["line"]}">{b}</span>' for b in buttons)
    return (f'<div class="card" style="background:{k["surface"]};border-color:{k["line"]}">'
            f'<div class="r1">{ring}<div class="tx"><div class="tt" style="color:{k["ink"]}">{title}</div>'
            f'<div class="bd" style="color:{k["mute"]}">{body}</div></div></div><div class="r2">{btns}</div></div>')

def panels_sheet(t):
    k = TH[t]
    cases = [
        ("capturing, 2 s in", ring48(t, "capture", 0.4, "3"), "Look at the screen",
         "Be the only person in view. Nothing is saved except a face print.", ["Cancel"]),
        ("success", ring48(t, "ok"), "Face saved", "Stored on this Mac only. Delete it any time from the menu.", ["*Done"]),
        ("failure", ring48(t, "seam"), "No face seen", "Face the screen in good light, then try again.", ["Cancel", "*Try again"]),
    ]
    cells = "".join(f'<figure>{card(t, r, a, b, c)}<figcaption style="color:{k["mute"]}">{n}</figcaption></figure>'
                    for n, r, a, b, c in cases)
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t}</p><div class="row3">{cells}</div></div>'

CSS = """
*{box-sizing:border-box}body{margin:0;font:13px/1.4 -apple-system,system-ui,sans-serif}
.pair{display:grid;grid-template-columns:1fr;gap:0;width:1200px}
.panel{padding:40px 48px 48px}
.cap{margin:0 0 32px;font:500 11px/1 -apple-system,system-ui;letter-spacing:.12em;text-transform:lowercase}
.row4{display:grid;grid-template-columns:repeat(4,1fr);gap:32px}.row3{display:grid;grid-template-columns:repeat(3,1fr);gap:32px;align-items:start}
figure{margin:0;display:flex;flex-direction:column;gap:16px}
figcaption{font:500 12px/1.4 -apple-system,system-ui;display:flex;flex-direction:column;gap:2px}
.big{height:128px;display:flex;align-items:center;justify-content:center}
.bar{display:flex;align-items:center;gap:14px;height:24px;padding:0 12px;border-radius:6px;width:max-content}
.bar .sp{width:6px}.ghost{width:16px;height:12px;border-radius:3px;background:currentColor;opacity:.18;color:#888}
.clock{font:500 13px/1 -apple-system,system-ui}
.mwrap{display:flex;flex-direction:column;gap:2px}
.menu{width:286px;margin-left:8px;padding:5px;border-radius:9px;border:1px solid;box-shadow:0 2px 8px rgba(0,0,0,.18)}
.mi{display:flex;align-items:center;height:22px;padding:0 9px 0 4px;font:13px/1 -apple-system,system-ui;border-radius:4px}
.ck{width:18px;text-align:center;font-size:12px}.lb{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.kc{font-size:13px}
.sepr{height:1px;margin:5px 9px}
.card{width:320px;height:160px;padding:24px;border:1px solid;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.08);display:flex;flex-direction:column;justify-content:space-between}
.r1{display:flex;gap:16px;align-items:center;height:56px}.tx{width:208px}
.tt{font:600 13px/20px -apple-system,system-ui}.bd{font:12px/16px -apple-system,system-ui;margin-top:4px}
.r2{display:flex;justify-content:flex-end;gap:8px}
.btn{height:32px;min-width:80px;padding:0 14px;display:inline-flex;align-items:center;justify-content:center;border:1px solid;border-radius:6px;font:500 13px/1 -apple-system,system-ui}
"""

def page():
    sec = lambda sid, f: f'<section id="{sid}" class="pair">{f("light")}{f("dark")}</section>'
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>byaku menu-bar mockups</title><style>{CSS}</style></head><body>'
            + sec("icons", icons_sheet) + sec("menu", menus_sheet) + sec("panel", panels_sheet) + "</body></html>")

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for s in ("icons", "menu", "panel"):
            pg.locator(f"#{s}").screenshot(path=str(OUT / f"sheet-{s}.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and 3 sheets")
