"""byaku menu-bar mockups from docs/designs/menubar.md (build 1). Pale Watch rules: design/brand/philosophy.md.
Writes ../mockups.html and ../sheet-{icons,menu,panel,motion}.png. Run from this folder:
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
    mark = RING.format(c=c) + BLADES.format(c=c)  # every state keeps the full mark
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

STATES = [("off", "Off", "full mark, ink (template)"), ("guarding", "Guarding", "full mark, violet"),
          ("alert", "Alert", "+ centre dot, violet"), ("error", "Error", "+ diagonal cut, ink")]

def icon_color(state, t):
    return TH[t]["accent"] if state in ("guarding", "alert") else TH[t]["ink"]

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


# ---- live motion prototype: open mockups.html in a browser and click the icon ----------------------------
# Motion tokens (docs/designs/menubar.md §5): ease-out only, everything under 300 ms, origin = the trigger.
DEMO_CSS = """
.demo{--surface:#FFFFFF;--line:#E1E0E6;--ink:#0E0D12;--mute:#66636F;--bg:#F5F5F7;--accent:#6A5DB8;--bar:#E8E7EC;
  --out:cubic-bezier(.23,1,.32,1);--enter:200ms;--exit:150ms;--press:100ms;--hover:120ms;
  position:relative;height:330px;padding:24px 48px;background:var(--bg)}
.demo.dark{--surface:#17161C;--line:#25232C;--ink:#ECEBF0;--mute:#8F8C99;--bg:#0E0D12;--accent:#C8BFEF;--bar:#1E1D23}
.demo .bar{background:var(--bar)}.demo .clock{color:var(--ink)}
.trig{all:unset;display:flex;cursor:default;border-radius:4px;padding:2px 3px;transition:background var(--hover) var(--out)}
.trig:hover,.trig[aria-expanded=true]{background:color-mix(in srgb,var(--ink) 12%,transparent)}
.dpanel{position:absolute;top:64px;left:40px;opacity:0;transform:scale(.96);pointer-events:none;
  transition:opacity var(--exit) var(--out),transform var(--exit) var(--out)}
.dpanel.open{opacity:1;transform:none;pointer-events:auto;transition-duration:var(--enter)}
.dpanel .card{background:var(--surface);border-color:var(--line)}.dpanel .tt{color:var(--ink)}.dpanel .bd{color:var(--mute)}
.abtn{height:32px;min-width:80px;padding:0 14px;border:1px solid var(--line);border-radius:6px;background:transparent;color:var(--ink);
  font:500 13px/1 -apple-system,system-ui;cursor:default;
  transition:background var(--hover) var(--out),border-color var(--hover) var(--out),transform 160ms var(--out)}
.abtn:hover{background:color-mix(in srgb,var(--ink) 6%,transparent);border-color:color-mix(in srgb,var(--ink) 22%,var(--line))}
.abtn:active{transform:scale(.97);transition-duration:var(--press)}
.abtn.primary{background:var(--ink);border-color:var(--ink);color:var(--bg)}
.abtn.primary:hover{background:color-mix(in srgb,var(--ink) 86%,var(--bg))}
.abtn:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.spin{transform-origin:24px 24px;animation:spin 600ms linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
.prog{transition:stroke-dashoffset 1000ms linear}
.chk{stroke-dasharray:30;stroke-dashoffset:30;transition:stroke-dashoffset 240ms var(--out)}.ok .chk{stroke-dashoffset:0}
@media (prefers-reduced-motion:reduce){.dpanel,.dpanel.open{transform:none}.abtn:active{transform:none}
  .spin{animation:none}.chk{transition:none}}
"""

def demo(t):
    cls = "demo dark" if t == "dark" else "demo"
    k = TH[t]
    ghosts = "".join('<span class="ghost"></span>' for _ in range(3))
    return f"""<div class="{cls}" data-demo>
<div class="bar"><span class="sp"></span><button class="trig" aria-label="byaku, Guard off" aria-expanded="false">{icon("guarding", k["accent"])}</button>{ghosts}<span class="clock">Wed 14:02</span></div>
<div class="dpanel" role="dialog" aria-label="Set up face"><div class="card">
<div class="r1"><svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
<circle cx="24" cy="24" r="22" fill="none" stroke="var(--line)" stroke-width="4"/>
<path class="spin" d="M24 2A22 22 0 0 1 46 24" fill="none" stroke="var(--ink)" stroke-width="4"/>
<circle class="prog" cx="24" cy="24" r="22" fill="none" stroke="var(--ink)" stroke-width="4" stroke-dasharray="{CIRC:.2f}" stroke-dashoffset="{CIRC:.2f}" transform="rotate(-90 24 24)" visibility="hidden"/>
<text class="num" x="24" y="24" dy=".36em" text-anchor="middle" fill="var(--ink)" style="font:600 20px -apple-system,system-ui;font-variant-numeric:tabular-nums"></text>
<polyline class="chk" points="15,25 21,31 33,18" fill="none" stroke="var(--ink)" stroke-width="3"/></svg>
<div class="tx"><div class="tt">Starting camera…</div><div class="bd"></div></div></div>
<div class="r2"><button class="abtn sec">Cancel</button><button class="abtn primary" hidden>Done</button></div></div></div></div>"""

DEMO_JS = """
document.querySelectorAll('[data-demo]').forEach(d => {
  const trig = d.querySelector('.trig'), pan = d.querySelector('.dpanel'), card = pan.querySelector('.card');
  const spin = d.querySelector('.spin'), prog = d.querySelector('.prog'), num = d.querySelector('.num');
  const tt = d.querySelector('.tt'), bd = d.querySelector('.bd'), sec = d.querySelector('.sec'), pri = d.querySelector('.primary');
  const C = prog.getAttribute('stroke-dasharray'); let timers = [];
  const later = (ms, f) => timers.push(setTimeout(f, ms));
  function origin() {  // grow from the icon, not from the panel's centre
    const a = trig.getBoundingClientRect(), b = pan.getBoundingClientRect();
    pan.style.transformOrigin = `${a.left + a.width / 2 - b.left}px ${a.bottom - b.top}px`;
  }
  function reset() {
    timers.forEach(clearTimeout); timers = []; card.classList.remove('ok');
    spin.style.display = ''; prog.setAttribute('visibility', 'hidden'); prog.style.strokeDashoffset = C; num.textContent = '';
    tt.textContent = 'Starting camera…'; bd.textContent = ''; sec.hidden = false; pri.hidden = true;
  }
  function run() {
    reset();
    later(900, () => { spin.style.display = 'none'; prog.setAttribute('visibility', 'visible');
      tt.textContent = 'Look at the screen'; bd.textContent = 'Be the only person in view. Nothing is saved except a face print.';
      for (let i = 0; i <= 5; i++) later(i * 1000, () => { num.textContent = i < 5 ? 5 - i : '';
        prog.style.strokeDashoffset = C * (1 - Math.min(i + 1, 5) / 5); });
      later(5000, () => { card.classList.add('ok'); tt.textContent = 'Face saved';
        bd.textContent = 'Stored on this Mac only. Delete it any time from the menu.'; sec.hidden = true; pri.hidden = false; pri.focus(); });
    });
  }
  const open = v => { origin(); pan.classList.toggle('open', v); trig.setAttribute('aria-expanded', v); v ? run() : reset(); };
  trig.onclick = () => open(!pan.classList.contains('open'));
  sec.onclick = pri.onclick = () => open(false);
  d.addEventListener('keydown', e => { if (e.key === 'Escape') open(false); });
});
"""

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
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>byaku menu-bar mockups</title><style>{CSS}{DEMO_CSS}</style></head><body>'
            + sec("icons", icons_sheet) + sec("menu", menus_sheet) + sec("panel", panels_sheet)
            + f'<section id="motion" class="pair">{demo("light")}{demo("dark")}</section><script>{DEMO_JS}</script></body></html>')

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for s in ("icons", "menu", "panel"):
            pg.locator(f"#{s}").screenshot(path=str(OUT / f"sheet-{s}.png"))
        for trig in pg.locator(".trig").all(): trig.click()
        pg.wait_for_timeout(3200)  # both panels mid-countdown
        pg.locator("#motion").screenshot(path=str(OUT / "sheet-motion.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and 3 sheets")
