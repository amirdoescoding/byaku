"""byaku first-run onboarding mockups (welcome, face, tour, founder video). Reuses the menu-bar + Away helpers.
Writes ../mockups.html and ../sheet-{welcome,face,tour,video}.png. Run from this folder:
  uv run --with playwright python mockups.py"""
import importlib.util, pathlib, re
OUT = pathlib.Path(__file__).resolve().parent.parent
def _load(name, rel):
    s = importlib.util.spec_from_file_location(name, OUT.parent / rel); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
mb = _load("mb", "menubar/src/mockups.py"); aw = _load("aw", "away/src/mockups.py")
TH = mb.TH
FINAL = OUT.parent / "brand/final"

# ---- mascot: the symbol, blades move like eyebrows (rotate about the ring centre + nudge) ------------------------
EXPR = {  # (left blade, right blade) as SVG transforms; the ring never moves
    "idle":   ("", ""),
    "focus":  ("translate(1 3) rotate(10 32 32)", "translate(-1 3) rotate(-10 32 32)"),   # lowered, tops tilt inward
    "raised": ("translate(-1 -4)", "translate(1 -4)"),                                    # lifted
    "frown":  ("translate(-1 4) rotate(-22 32 32)", "translate(1 4) rotate(22 32 32)"),    # drooping, tops tilt outward
    "look":   ("translate(3 -3) rotate(6 32 32)", "translate(3 -3) rotate(6 32 32)"),     # both toward the menu bar (up-right)
}
LB = '<path fill="{c}" d="M19.367 43.375A17 17 0 0 1 26.747 15.832A82.511 82.511 0 0 0 19.367 43.375Z"/>'
RB = '<path fill="{c}" d="M40.500 17.278A17 17 0 0 1 47.975 37.814A100.374 100.374 0 0 0 40.500 17.278Z"/>'
def mascot(c, expr="idle", px=96, sw=4.5, extra=""):
    l, r = EXPR[expr]
    return (f'<svg width="{px}" height="{px}" viewBox="4 4 56 56" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">{mb.RING.format(c=c).replace("4.5", str(sw))}'
            f'<g transform="{l}">{LB.format(c=c)}</g><g transform="{r}">{RB.format(c=c)}</g>{extra}</svg>')

# ---- bits -----------------------------------------------------------------------------------------------------------
def btn(k, label, role):
    if role == "primary":
        return f'<span class="btn" style="background:{k["ink"]};color:{k["bg"]};border-color:{k["ink"]}">{label}</span>'
    return f'<span class="btn" style="color:{k["ink"]};border-color:{k["line"]}">{label}</span>'

def xbtn(k):  # PanelButton .close: 24 pt, no border, mute
    return (f'<span class="xb" style="color:{k["mute"]}"><svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1l-8 8" '
            f'stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg></span>')

def window(k, inner, buttons="", close=True):
    return (f'<div class="win" style="background:{k["surface"]};border-color:{k["line"]}">{xbtn(k) if close else ""}'
            f'<div class="wbody">{inner}</div><div class="wbtn">{buttons}</div></div>')

def fig(k, node, cap, note=""):
    return f'<figure>{node}<figcaption style="color:{k["ink"]}">{cap}<span style="color:{k["mute"]}">{note}</span></figcaption></figure>'

def panel(t, label, body, cls="grid2"):
    k = TH[t]
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · {label}</p><div class="{cls}">{body}</div></div>'

# ---- 1 welcome ------------------------------------------------------------------------------------------------------
def welcome(t):
    k = TH[t]
    inner = (f'<div class="hero">{mascot(k["accent"], "idle", 112)}</div>'
             f'<div class="h1" style="color:{k["ink"]}">byaku watches who’s looking.</div>')
    w = window(k, inner, btn(k, "Start", "primary")).replace('class="wbtn"', 'class="wbtn center"')
    return panel(t, "1 · welcome", fig(k, w, "Welcome", "480 × 360 pt, titlebar hidden, not resizable. Return = Start, Esc/× closes"), "one")

# ---- 2 face ---------------------------------------------------------------------------------------------------------
def facewin(k, expr, title, body, buttons, count=""):
    n = f'<div class="num" style="color:{k["ink"]}">{count}</div>' if count else '<div class="num"></div>'
    inner = (f'<div class="hero sm">{mascot(k["accent"], expr, 96)}</div>{n}'
             f'<div class="tt2" style="color:{k["ink"]}">{title}</div><div class="bd2" style="color:{k["mute"]}">{body}</div>')
    return window(k, inner, buttons)

def face(t):
    k = TH[t]
    cases = [
        (facewin(k, "focus", "Look at the screen", "Be the only person in view. Nothing is saved except a face print.", btn(k, "Cancel", "secondary"), "3"),
         "Counting, 3 s left", "focus: blades lowered. Count 5 → 1 steps once a second; Starting camera… shows the same with no number"),
        (facewin(k, "raised", "Face saved", "Stored on this Mac only. Delete it any time from the menu.", btn(k, "Done", "primary")),
         "Saved", "raised blades. Done goes to the tour (Return)"),
        (facewin(k, "frown", "No face seen", "Face the screen in good light, then try again.", btn(k, "Skip", "secondary") + btn(k, "Try again", "primary")),
         "Failure: No face seen", "frown. Same layout for More than one face and Camera access is off (Open camera settings… replaces Try again)"),
    ]
    return panel(t, "2 · face", "".join(fig(k, *c) for c in cases), "grid2")

# ---- desktop strip (menu bar) for tour screens ----------------------------------------------------------------------
def deskbar(t, w):
    k = TH[t]
    return (f'<div class="dbar" style="background:{k["bar"]};width:{w}px"><span class="sp"></span>{mb.icon("off", k["ink"])}'
            + "".join('<span class="ghost"></span>' for _ in range(3)) + f'<span class="clock" style="color:{k["ink"]}">Wed 14:02</span></div>')

# ---- 3 tour start ---------------------------------------------------------------------------------------------------
def tour_start(t):
    k = TH[t]
    inner = (f'<div class="hero">{mascot(k["accent"], "look", 112)}</div>'
             f'<div class="h1" style="color:{k["ink"]}">Here’s the menu.</div>'
             f'<div class="bd2" style="color:{k["mute"]};text-align:center;margin-top:8px">It lives up here, next to the clock.</div>')
    w = 760
    scene = (f'<div class="desk" style="width:{w}px;height:430px;background:{k["bg"]};border-color:{k["line"]}">{deskbar(t, w)}'
             f'<div style="position:absolute;left:{(w-480)//2}px;top:48px">{window(k, inner, btn(k, "Skip", "secondary") + btn(k, "Show me", "primary"))}</div></div>')
    return panel(t, "3 · tour start", fig(k, scene, "Tour start", "blades look up-right, toward the status item. Show me opens the menu and starts the coach"), "one")

# ---- 4 tour in progress: the real menu (App.swift ~L150-210) ----------------------------------------------------
COPY = {  # coach lines, ≤ 70 chars, for Swift
    "Guard": ("⌘G", "Watches the camera. If someone else looks, you get a heads-up."),
    "Away": ("⌘A", "Stepping away? If anyone looks, the alarm sounds and the Mac locks."),
    "Alarm volume": ("", "How loud the Away alarm is. It never goes fully silent."),
    "Alarm sound": ("", "Pick the sound the alarm plays. Choosing one plays a short preview."),
    "Message…": ("", "Record a short line to speak over the alarm. Up to 8 seconds."),
    "Mode": ("", "What Guard does besides the banner: nothing, violet edges, or a dim."),
    "Banner": ("", "A small notice under the menu bar when someone else looks."),
    "Sound": ("", "Adds a short sound to the Guard alert. Off by default."),
    "Set up face again…": ("⌘E", "Saves a new face print of you, so byaku knows who not to flag."),
    "Delete face data": ("", "Removes your saved face print from this Mac. One click, no undo."),
    "Open at login": ("", "Starts byaku in the menu bar when you log in."),
    "Quit byaku": ("⌘Q", "Stops watching and closes byaku."),
}
assert all(len(v[1]) <= 70 for v in COPY.values()), [k for k, v in COPY.items() if len(v[1]) > 70]
# (label, key, checked, submenu, subtitle, kind); kind: row | sep | vol | status | extra (not part of the tour)
ROWS = [("Guard is off", "", 0, 0, "", "status"), ("", "", 0, 0, "", "sep"),
        ("Guard", "⌘G", 0, 0, "", "row"), ("Away", "⌘A", 0, 0, "", "row"), ("", "", 0, 0, "", "sep"),
        ("Alarm volume", "", 0, 0, "", "vol"), ("Alarm sound", "", 0, 1, "Siren", "row"), ("Message…", "", 0, 0, "Spoken line", "row"),
        ("", "", 0, 0, "", "sep"), ("Mode", "", 0, 1, "", "row"), ("Banner", "", 1, 0, "", "row"), ("Sound", "", 0, 0, "", "row"),
        ("", "", 0, 0, "", "sep"), ("Set up face again…", "⌘E", 0, 0, "", "row"), ("Delete face data", "", 0, 0, "", "row"),
        ("", "", 0, 0, "", "sep"), ("Open at login", "", 1, 0, "", "row"), ("Welcome tour…", "", 0, 0, "", "extra"), ("Quit byaku", "⌘Q", 0, 0, "", "row")]
H = {"row": 22, "status": 22, "extra": 22, "sep": 11, "vol": 59}

STEPS = ["Guard", "Away", "Alarm sound", "Message…", "Mode", "Set up face again…"]  # the core features, in menu order

def coach_card(k, label, last):
    key, line = COPY[label]
    n = STEPS.index(label) + 1
    nxt = btn(k, "Finish" if last else "Next", "primary").replace('class="btn"', 'class="btn s"')
    skip = btn(k, "Skip tour", "secondary").replace('class="btn"', 'class="btn s"')
    return (f'<div class="cc"><div class="bh"><span class="bn" style="color:{k["ink"]}">{label.rstrip("…")}</span>'
            f'<span style="color:{k["mute"]}">{key}</span></div>'
            f'<div class="bd2" style="color:{k["mute"]}">{line}</div>'
            f'<div class="cfoot"><span style="color:{k["mute"]};font-variant-numeric:tabular-nums">{n} of {len(STEPS)}</span>'
            f'<span class="cbtn">{skip}{nxt}</span></div></div><div class="sepr" style="background:{k["sep"]}"></div>')

def tour_menu(t, lit, last=False):
    """The real menu during the guided tour: the coach card is the first item; only the lit row is enabled."""
    k = TH[t]; out = [coach_card(k, lit, last)]
    for label, key, on, sub, small, kind in ROWS:
        if kind == "sep":
            out.append(f'<div class="sepr" style="background:{k["sep"]}"></div>')
        elif kind == "vol":
            out.append(f'<div style="padding:6px 13px 8px 23px;height:59px;opacity:.35"><div style="font:600 13px/13px -apple-system,system-ui;color:{k["ink"]};margin-bottom:8px">Alarm volume</div>'
                       f'{aw.slider(t, 1.0, 226)}</div>')
        else:
            hl = label == lit
            col = k["ink"] if hl else k["dis"]
            w = "font-weight:600;" if hl else ""
            lb = f'{label}<small style="color:{k["mute"] if hl else k["dis"]}">{small}</small>' if small else label
            out.append(f'<div class="mi{" two" if small else ""}" style="color:{col};{w}">'
                       f'<span class="ck">{"✓" if on else ""}</span><span class="lb">{lb}</span>'
                       f'<span class="kc" style="color:{k["mute"] if hl else k["dis"]};font-weight:400">{"›" if sub else key}</span></div>')
    return f'<div class="menu" style="width:300px;margin:0;background:{k["menu"]};border-color:{k["sep"]}">{"".join(out)}</div>'

def tour_scene(t, lit, last=False):
    k = TH[t]
    W, Hh, MW = 1000, 640, 300
    mx, my = W - MW - 12, 28
    dock = f'<div style="position:absolute;left:{mx - 14 - 40}px;top:{my + 14}px">{mascot(k["accent"], "look", 40)}</div>'
    return (f'<div class="desk" style="width:{W}px;height:{Hh}px;background:{k["bg"]};border-color:{k["line"]}">{deskbar(t, W)}'
            f'{dock}<div style="position:absolute;left:{mx}px;top:{my}px">{tour_menu(t, lit, last)}</div></div>')

def tour(t):
    k = TH[t]
    a = fig(k, tour_scene(t, "Guard"), "Step 1 · Guard",
            "the coach card is the menu's first item (a custom view, like the sound rows), so Next keeps the menu open and stays under the pointer. "
            "Only the lit row is enabled (semibold); every other row is disabled, the slider at 35%. Nothing in the menu acts during the tour")
    b = fig(k, tour_scene(t, "Mode"), "Step 5 · Mode",
            "Next flips the lit row live. A click outside closes the menu; it reopens on the same step, so the video never starts by accident. "
            "No Next for 6 s: the docked mascot gets stressed")
    c = fig(k, tour_scene(t, "Set up face again…", last=True), "Last step · Finish",
            "Finish is the only way to the video: the menu closes and the mascot flies into the lockup. Skip tour goes to the video without the rest")
    return panel(t, "4 · guided tour", a + b + c, "one")

# ---- 5 founder video ------------------------------------------------------------------------------------------------
def lockup(t, width=300, reveal=None):
    svg = (FINAL / f"lockup-{t}.svg").read_text()
    svg = svg.replace("<svg ", f'<svg width="{width}" ', 1)
    if reveal is not None:
        return f'<div style="clip-path:inset(0 {100 - reveal}% 0 0)">{svg}</div>'
    return svg

def vframe(k, t, inner, bgc=None):
    sym = mascot(k["ink"], "idle", 28, 4.5)
    return (f'<div class="vcard" style="background:{k["surface"]};border-color:{k["line"]}"><div class="vid" style="background:{bgc or k["line"]};border-color:{k["line"]}">'
            f'<span class="vsym" style="opacity:.55">{sym}</span>{inner}</div></div>')

def video(t):
    k = TH[t]
    ph = f'<span class="vph" style="color:{k["ink"]}">founder video placeholder · 16:9</span>'
    intro = vframe(k, t, f'<div class="vc">{lockup(t, 300, 62)}</div>', k["bg"])
    ctr = (f'<div class="ctl" style="background:{k["surface"]};border-color:{k["line"]};color:{k["ink"]}">'
           f'<svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 1.5h2.5v11H3zM8.5 1.5H11v11H8.5z" fill="currentColor"/></svg>'
           f'<span class="trk" style="background:{k["line"]}"><i style="width:34%;background:{k["ink"]}"></i></span>'
           f'<span style="color:{k["mute"]};font-variant-numeric:tabular-nums">0:14 / 0:42</span><span style="color:{k["mute"]}">Skip</span></div>')
    play = vframe(k, t, ph + ctr)
    outro_in = (f'<div class="vc col">{lockup(t, 220)}<div class="h1" style="color:{k["ink"]};margin-top:20px;font-size:17px">Thanks for trying byaku</div>'
                f'<div class="orow">{btn(k, "Done", "primary")}{btn(k, "Contribute on GitHub", "secondary")}</div>'
                f'<div class="replay" style="color:{k["mute"]}"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M10 6a4 4 0 1 1-1.2-2.85M10 1.5v2.2H7.8" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>Replay</div></div>')
    outro = vframe(k, t, outro_in, k["bg"])
    return panel(t, "5 · founder video", fig(k, intro, "Intro", "lockup draws on, ring first, then blades, then the name (shown ~60% drawn). Symbol sits top-right all the way through; here in ink, so the lockup holds the only violet")
            + fig(k, play, "Playing", "controls: pause, scrubber, time, Skip. Hidden after 2 s of no pointer")
            + fig(k, outro, "Outro", "Done closes onboarding. Contribute opens https://github.com/amirdoescoding/byaku in the browser. Replay restarts from the intro"), "one")

CSS = mb.CSS + """
.mi.two{height:34px}.mi.two .lb{display:flex;flex-direction:column;gap:1px}.mi.two small{font-size:11px}.mi.hl{background:#0A64D8}
.one{display:grid;grid-template-columns:1fr;gap:40px}.one figure{align-items:flex-start}
.grid2{display:grid;grid-template-columns:repeat(2,1fr);gap:40px 32px;align-items:start}
.win{position:relative;width:480px;height:360px;border:1px solid;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.12);display:flex;flex-direction:column}
.wbody{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px 40px}
.wbtn{height:32px;margin:0 24px 24px;display:flex;justify-content:flex-end;gap:8px}.wbtn.center{justify-content:center}
.xb{position:absolute;top:12px;right:12px;width:24px;height:24px;display:flex;align-items:center;justify-content:center}
.hero{display:flex;margin-bottom:24px}.hero.sm{margin-bottom:8px}
.h1{font:600 20px/28px -apple-system,system-ui;text-align:center}
.num{height:36px;font:600 28px/36px -apple-system,system-ui;font-variant-numeric:tabular-nums}
.tt2{font:600 15px/20px -apple-system,system-ui;margin-top:4px}.bd2{font:12px/16px -apple-system,system-ui;text-align:inherit}
.wbody .bd2{text-align:center;margin-top:4px;max-width:340px}
.desk{position:relative;border:1px solid;border-radius:10px;overflow:hidden}
.dbar{position:absolute;top:0;left:0;height:24px;display:flex;align-items:center;justify-content:flex-end;gap:14px;padding:0 12px}
.dbar .sp{display:none}.dbar .ghost{order:-1}
.dot{position:absolute;left:-2px;top:50%;width:4px;height:4px;margin-top:-2px;border-radius:50%}
.coach{position:absolute;padding:16px;border:1px solid;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.12)}
.arrow.up{right:-6px;top:-6px;margin-top:0;transform:none}
.arrow{position:absolute;right:-7px;width:12px;height:12px;border-top:1px solid;border-right:1px solid;transform:rotate(45deg);margin-top:-5px}
.crow{display:flex;gap:12px}.cm{flex:none;margin-top:1px}.ctx{min-height:52px}
.bh{display:flex;gap:8px;align-items:baseline;font:12px/16px -apple-system,system-ui;margin-bottom:4px}.bn{font:600 13px/20px -apple-system,system-ui}
.cfoot{display:flex;justify-content:space-between;align-items:center;margin-top:12px;font:12px/16px -apple-system,system-ui}
.cc{padding:8px 9px 10px 22px}.cc .bd2{margin-top:2px;max-width:250px}.cbtn{display:flex;gap:6px}
.btn.s{height:28px;min-width:0}
.vcard{width:672px;padding:16px;border:1px solid;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.08)}
.vid{position:relative;padding:8px;width:640px;height:360px;border-radius:8px;overflow:hidden;border:1px solid;display:flex;align-items:center;justify-content:center}
.vsym{position:absolute;top:16px;right:16px;display:flex}
.vph{font:12px/16px -apple-system,system-ui}
.vc{display:flex;align-items:center;justify-content:center}.vc.col{flex-direction:column}
.ctl{position:absolute;left:0;right:0;bottom:0;height:40px;border-top:1px solid;display:flex;align-items:center;gap:12px;padding:0 16px;font:12px/16px -apple-system,system-ui}
.trk{flex:1;height:3px;border-radius:2px;display:flex}.trk i{display:block;border-radius:2px}
.orow{display:flex;gap:8px;margin-top:20px}.replay{display:flex;align-items:center;gap:6px;margin-top:14px;font:500 12px/16px -apple-system,system-ui}
figcaption{max-width:640px}
.cap{font-size:12px;letter-spacing:0}
"""

SECTIONS = [("welcome", welcome), ("face", face), ("tour", lambda t: tour_start(t) + tour(t)), ("video", video)]

def copy_table():
    rows = "".join(f'<tr><td>{n}</td><td>{s}</td><td>{c}</td><td>{len(c)}</td></tr>' for n, (s, c) in COPY.items())
    return f'<section id="copy"><h2>Coach copy (Swift)</h2><table><tr><th>Item</th><th>Key</th><th>Line</th><th>chars</th></tr>{rows}</table></section>'

def page():
    sec = lambda sid, f: f'<section id="{sid}" class="pair">{f("light")}{f("dark")}</section>'
    return ('<!doctype html><html><head><meta charset="utf-8"><title>byaku onboarding mockups</title>'
            f'<style>{CSS}table{{font:13px/1.5 -apple-system,system-ui;margin:24px 48px}}td,th{{padding:4px 16px 4px 0;text-align:left}}</style></head><body>'
            + "".join(sec(n, f) for n, f in SECTIONS) + copy_table() + '</body></html>')

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for n, _ in SECTIONS:
            pg.locator(f"#{n}").screenshot(path=str(OUT / f"sheet-{n}.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and", len(SECTIONS), "sheets")
