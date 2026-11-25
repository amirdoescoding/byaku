"""byaku Guard-actions mockups from docs/designs/guard-actions.md. Reuses the menu-bar mockup helpers (same tokens, icon, menu).
Writes ../mockups.html and ../sheet-{names,banner,ladder,edges,motion}.png. Run from this folder:
  uv run --with playwright python mockups.py"""
import importlib.util, pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("mb", OUT.parent / "menubar/src/mockups.py")
mb = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(mb)
TH, icon, bar = mb.TH, mb.icon, mb.bar

# ---- name sets: submenu title + 4 levels (banner only → edges → dim → edges + dim) -------------------------
NAMES = [("Mode", "Mode", ["Whisper", "Iris", "Shade", "Awaken"])]  # approved 2026-11-26
SUBS = ["banner only", "violet edges", "light dim", "edges + dim"]  # NSMenuItem.subtitle (macOS 14+)

def guard_menu(t, title, levels, pick=1):
    k = TH[t]
    q = lambda label, key="", on=False, en=True, sub=False: (
        f'<div class="mi" style="color:{k["ink"] if en else k["dis"]}"><span class="ck">{"✓" if on else ""}</span>'
        f'<span class="lb">{label}</span><span class="kc" style="color:{k["mute"]}">{"›" if sub else key}</span></div>')
    sep = f'<div class="sepr" style="background:{k["sep"]}"></div>'
    main = (f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">Guarding. Camera is on</span></div>'
            + sep + q("Guard", "⌘G", True) + f'<div class="mi hl"><span class="ck"></span><span class="lb">{title}</span><span class="kc">›</span></div>'
            + q("Banner", on=True) + q("Sound") + sep + q("Set up face again…", "⌘E") + q("Delete face data") + sep + q("Quit byaku", "⌘Q"))
    subrows = "".join(
        f'<div class="mi two" style="color:{k["ink"]}"><span class="ck">{"●" if i == pick else ""}</span>'
        f'<span class="lb">{n}<small style="color:{k["mute"]}">{SUBS[i]}</small></span></div>' for i, n in enumerate(levels))
    box = lambda inner, w: f'<div class="menu" style="width:{w}px;background:{k["menu"]};border-color:{k["sep"]}">{inner}</div>'
    return f'<div class="mwrap">{bar("guarding", t)}<div class="mrow">{box(main, 250)}{box(subrows, 168)}</div></div>'

def names_sheet(t):
    k = TH[t]
    cells = "".join(f'<figure>{guard_menu(t, title, lv)}<figcaption style="color:{k["ink"]}">{cap}'
                    f'<span style="color:{k["mute"]}">{" · ".join(lv)}</span></figcaption></figure>' for cap, title, lv in NAMES)
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t}</p><div class="grid2">{cells}</div></div>'

# ---- banner: 300 x 64 under the icon ------------------------------------------------------------------------
PHRASES = ["Mind your screen.", "Eyes on your screen.", "Be aware.", "Not your face."]  # one per alert, in turn

def banner(t, title="Someone else is looking", body=PHRASES[0]):
    k = TH[t]
    x = (f'<span class="x" style="color:{k["mute"]}" aria-label="Close"><svg width="10" height="10" viewBox="0 0 10 10">'
         f'<path d="M1 1L9 9M9 1L1 9" stroke="currentColor" stroke-width="1.5"/></svg></span>')
    return (f'<div class="ban" style="background:{k["surface"]};border-color:{k["line"]}">{icon("alert", k["accent"], 20)}'
            f'<div class="btx"><div class="tt" style="color:{k["ink"]}">{title}</div><div class="bd" style="color:{k["mute"]}">{body}</div></div>{x}</div>')

def banner_sheet(t):
    k = TH[t]
    cells = (f'<figure><div class="mwrap">{bar("alert", t)}<div style="margin-left:4px">{banner(t)}</div></div>'
             f'<figcaption style="color:{k["ink"]}">Alert, banner on<span style="color:{k["mute"]}">grows from the icon · × hides it until the next alert</span></figcaption></figure>'
             f'<figure><div class="mwrap">{bar("alert", t)}<div class="menu" style="width:250px;margin-left:8px;background:{k["menu"]};border-color:{k["sep"]}">'
             f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">Someone else is looking</span></div>'
             f'<div class="mi" style="color:{k["ink"]}"><span class="ck"></span><span class="lb">Lift for now</span><span class="kc" style="color:{k["mute"]}">⌘L</span></div>'
             f'<div class="sepr" style="background:{k["sep"]}"></div><div class="mi" style="color:{k["ink"]}"><span class="ck">✓</span><span class="lb">Guard</span><span class="kc" style="color:{k["mute"]}">⌘G</span></div></div></div>'
             f'<figcaption style="color:{k["ink"]}">Menu during an alert<span style="color:{k["mute"]}">"Lift for now" clears banner, edges and dim until the next alert (DESIGN §5)</span></figcaption></figure>')
    rot = "".join(f'<div style="margin-bottom:8px">{banner(t, body=ph)}</div>' for ph in PHRASES[1:])
    cells += (f'<figure>{rot}<figcaption style="color:{k["ink"]}">Next alerts<span style="color:{k["mute"]}">body line rotates once per alert, never while one is showing</span></figcaption></figure>')
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t}</p><div class="grid2">{cells}</div></div>'

# ---- a believable desktop: two windows of text, menu bar on top ---------------------------------------------
def desktop(t, level, edge="soft", w=540, h=338, cls=""):
    k = TH[t]
    lines = "".join(f'<i style="width:{x}%;background:{k["ink"]}"></i>' for x in (92, 84, 96, 70, 88, 94, 60, 90, 82, 74))
    win = lambda l, tp, ww, hh, z: (f'<div class="win" style="left:{l}px;top:{tp}px;width:{ww}px;height:{hh}px;z-index:{z};background:{k["surface"]};border-color:{k["line"]}">'
                                    f'<div class="tb" style="border-color:{k["line"]}"><b></b><b></b><b></b></div><div class="txt">{lines}</div></div>')
    wall = "linear-gradient(160deg,#C9C6D6,#8E8AA3)" if t == "light" else "linear-gradient(160deg,#2B2935,#121117)"
    mbar = (f'<div class="dbar" style="background:{k["bar"]}"><span style="color:{k["ink"]}">●</span><span class="sp"></span>'
            f'{icon("alert" if level is not None else "guarding", k["accent"], 12)}<span class="clk" style="color:{k["ink"]}">14:02</span></div>')
    fx = overlay(t, level, edge) if level is not None else ""
    ban = f'<div class="dban">{banner(t)}</div>' if level is not None else ""
    return (f'<div class="desk {cls}" style="width:{w}px;height:{h}px;background:{wall}">{mbar}'
            f'{win(28, 40, 300, 210, 1)}{win(210, 96, 300, 220, 2)}{fx}{ban}</div>')

def overlay(t, level, edge):
    """level 0 banner only, 1 edges, 2 dim, 3 edges + dim. Overlay sits below the menu bar (menu bar stays usable)."""
    a = TH[t]["accent"]
    parts = []
    if level in (2, 3):
        parts.append('<div class="fx" style="background:rgba(0,0,0,.40)"></div>')
    if level in (1, 3):
        if edge == "soft":  # A: violet shadow from every edge (the user's sketch)
            parts.append(f'<div class="fx" style="box-shadow:inset 0 0 90px 30px {a}b3"></div>')
        else:  # B: ink shadow from every edge + one crisp violet hairline (Pale Watch: violet as a line, never a glow)
            parts.append('<div class="fx" style="box-shadow:inset 0 0 90px 34px rgba(8,7,12,.72)"></div>'
                         f'<div class="fx" style="inset:6px;border:2px solid {a};border-radius:10px"></div>')
    return "".join(parts)

LEVELS = ["Whisper", "Iris", "Shade", "Awaken"]

def ladder_sheet(t):
    k = TH[t]
    cells = "".join(f'<figure>{f'<div class="shrink">{desktop(t, i)}</div>'}<figcaption style="color:{k["ink"]}">{i}. {n}</figcaption></figure>'
                    for i, n in enumerate(LEVELS))
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · Mode levels (edge style A)</p><div class="row4">{cells}</div></div>'

def edges_sheet(t):
    k = TH[t]
    cells = (f'<figure>{desktop(t, 1, "soft")}<figcaption style="color:{k["ink"]}">A · soft violet shadow'
             f'<span style="color:{k["mute"]}">your sketch: violet bleeds in from every edge. Breaks "violet is never a glow".</span></figcaption></figure>'
             f'<figure>{desktop(t, 1, "rim")}<figcaption style="color:{k["ink"]}">B · ink shadow + violet rim'
             f'<span style="color:{k["mute"]}">dark shadow closes in; one 2 pt violet line marks "seen". Keeps the brand rule.</span></figcaption></figure>')
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · calm level</p><div class="grid2">{cells}</div></div>'

# ---- motion prototype: click the desktop to raise / clear an alert at each level -----------------------------
DEMO_JS = ("""
document.querySelectorAll('[data-live]').forEach(d => {
  const desk = d.querySelector('.desk'); let lvl = 3;
  d.querySelectorAll('[data-l]').forEach(b => b.onclick = () => { lvl = +b.dataset.l; desk.dataset.level = lvl;
    d.querySelectorAll('[data-l]').forEach(x => x.setAttribute('aria-pressed', x === b)); });
  const P = %s; let n = 0, body = d.querySelector('.dban .bd');
  d.querySelector('.go').onclick = () => { if (!desk.classList.contains('on')) body.textContent = P[n++ %% P.length]; desk.classList.toggle('on'); };
});
""" % __import__("json").dumps(PHRASES))

def live(t):
    k = TH[t]
    btns = "".join(f'<button class="lv" data-l="{i}" aria-pressed="{i == 3}" style="color:{k["ink"]};border-color:{k["line"]}">{n}</button>'
                   for i, n in enumerate(LEVELS))
    return (f'<div class="panel" data-live style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · click "Looker" to raise and clear</p>'
            f'<div class="ctl">{btns}<button class="lv go" style="color:{k["bg"]};background:{k["ink"]};border-color:{k["ink"]}">Looker</button></div>'
            f'<div class="desk live" data-level="3" style="width:720px;height:450px;background:{"linear-gradient(160deg,#C9C6D6,#8E8AA3)" if t == "light" else "linear-gradient(160deg,#2B2935,#121117)"}">'
            + desktop(t, None, w=720, h=450).split('">', 1)[1].rsplit("</div>", 1)[0]
            + f'<div class="fx dim"></div><div class="fx sh" style="--a:{k["accent"]}b3"></div>'
            f'<div class="dban lb2">{banner(t)}</div></div></div>')

CSS = mb.CSS + """
.grid2{display:grid;grid-template-columns:repeat(2,1fr);gap:40px 32px;align-items:start}
.mrow{display:flex;align-items:flex-start}.mrow .menu+.menu{margin-left:-6px;margin-top:44px}
.mi.hl{background:#0A64D8;color:#fff}.mi.hl .kc{color:#fff}
.mi.two{height:34px}.mi.two .lb{display:flex;flex-direction:column;gap:1px}.mi.two small{font-size:11px}
.ban{width:320px;height:64px;padding:0 12px 0 16px;border:1px solid;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.08);
  display:flex;align-items:center;gap:12px}.btx{flex:1}.ban .bd{margin-top:0}
.x{width:24px;height:24px;display:flex;align-items:center;justify-content:center;border-radius:6px;align-self:flex-start;margin-top:8px}
.desk{position:relative;overflow:hidden;border-radius:10px}
.dbar{position:absolute;top:0;left:0;right:0;height:18px;display:flex;align-items:center;gap:8px;padding:0 10px;font:600 10px/1 -apple-system;z-index:20}
.dbar .sp{flex:1}.clk{font:500 10px/1 -apple-system}
.win{position:absolute;border:1px solid;border-radius:8px;box-shadow:0 8px 24px rgba(0,0,0,.25);overflow:hidden}
.tb{height:20px;border-bottom:1px solid;display:flex;gap:5px;align-items:center;padding:0 8px}.tb b{width:7px;height:7px;border-radius:50%;background:#bbb}
.txt{padding:12px 14px;display:flex;flex-direction:column;gap:9px}.txt i{display:block;height:5px;border-radius:2px;opacity:.55}
.fx{position:absolute;inset:18px 0 0 0;pointer-events:none;z-index:10}
.dban{position:absolute;top:22px;right:36px;z-index:21;transform-origin:85% 0}
.shrink{width:259px;height:162px}.shrink>.desk{transform:scale(.48);transform-origin:0 0}
.ctl{display:flex;gap:8px;margin-bottom:16px}
.lv{height:32px;padding:0 14px;border:1px solid;border-radius:6px;background:transparent;font:500 13px/1 -apple-system,system-ui,sans-serif}
.lv[aria-pressed=true]{outline:2px solid currentColor;outline-offset:-2px}
/* live: edges grow inward 280 ms, dim fades 200 ms, banner scales from the icon 200 ms; all exit 150 ms; ease-out only */
.live .fx{opacity:0;transition:opacity 150ms cubic-bezier(.23,1,.32,1),box-shadow 150ms cubic-bezier(.23,1,.32,1)}
.live .dim{background:rgba(0,0,0,.40)}
.live .sh{box-shadow:inset 0 0 0 0 rgba(8,7,12,0)}
.live .rim{inset:24px 6px 6px 6px;border:2px solid;border-radius:10px;transform:scale(1.01)}
.live .dban{opacity:0;transform:scale(.96);transition:opacity 150ms cubic-bezier(.23,1,.32,1),transform 150ms cubic-bezier(.23,1,.32,1)}
.live.on .dban{opacity:1;transform:none;transition-duration:200ms}
.live.on[data-level="2"] .dim,.live.on[data-level="3"] .dim{opacity:1;transition-duration:200ms}
.live.on[data-level="1"] .sh,.live.on[data-level="3"] .sh{opacity:1;box-shadow:inset 0 0 120px 40px var(--a);transition-duration:280ms}
.live.on[data-level="1"] .rim,.live.on[data-level="3"] .rim{opacity:1;transform:none;transition:opacity 280ms cubic-bezier(.23,1,.32,1),transform 280ms cubic-bezier(.23,1,.32,1)}
@media (prefers-reduced-motion:reduce){.live .rim,.live .dban,.live.on .dban{transform:none}.live .sh{transition-property:opacity}}
"""

def page():
    sec = lambda sid, f: f'<section id="{sid}" class="pair">{f("light")}{f("dark")}</section>'
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>byaku Guard mockups</title><style>{CSS}</style></head><body>'
            + sec("names", names_sheet) + sec("banner", banner_sheet) + sec("edges", edges_sheet) + sec("ladder", ladder_sheet)
            + sec("motion", live) + f'<script>{DEMO_JS}</script></body></html>')

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for s in ("names", "banner", "edges", "ladder"):
            pg.locator(f"#{s}").screenshot(path=str(OUT / f"sheet-{s}.png"))
        for go in pg.locator(".go").all(): go.click()
        pg.wait_for_timeout(600)
        pg.locator("#motion").screenshot(path=str(OUT / "sheet-motion.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and 5 sheets")
