"""byaku Away-mode mockups from docs/designs/away-mode.md. Reuses the menu-bar mockup helpers (same tokens, icon, menu).
Writes ../mockups.html and ../sheet-{icons,menu}.png. Run from this folder:
  uv run --with playwright python mockups.py"""
import importlib.util, pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("mb", OUT.parent / "menubar/src/mockups.py")
mb = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(mb)
TH = mb.TH

# ---- Away icon candidates: the shape must differ from Guarding (DESIGN §6), not only the colour ----------------
def away_icon(variant, c, px=16):
    if variant == "A":  # solid iris: the ring fills in, blades knocked out (eye wide open)
        body = (f'<mask id="ka{px}{c[1:]}"><rect x="0" y="0" width="64" height="64" fill="#fff"/>'
                + mb.BLADES.format(c="#000") + '</mask>'
                f'<circle cx="32" cy="32" r="28" fill="{c}" mask="url(#ka{px}{c[1:]})"/>')
    elif variant == "B":  # heavy ring: stroke 4.5 → 9 (same mark, louder)
        body = (f'<path d="M53.5 32A21.5 21.5 0 1 1 10.5 32A21.5 21.5 0 1 1 53.5 32" fill="none" stroke="{c}" stroke-width="9"/>'
                + mb.BLADES.format(c=c))
    else:  # C: the mark + a bar under the blades (a "lid": standing watch)
        body = mb.RING.format(c=c) + mb.BLADES.format(c=c) + f'<rect x="20" y="48" width="24" height="4.5" fill="{c}"/>'
    return (f'<svg width="{px}" height="{px}" viewBox="4 4 56 56" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">{body}</svg>')

VARIANTS = [("A", "A · solid iris", "ring fills in, blades cut out. Loudest; reads at 16 pt"),
            ("B", "B · heavy ring", "same mark, ring twice as thick. Subtle next to Guarding"),
            ("C", "C · lid bar", "mark + a bar inside the ring. Busy at 16 pt")]

def abar(variant, t):
    k = TH[t]
    ghosts = "".join('<span class="ghost"></span>' for _ in range(3))
    return (f'<div class="bar" style="background:{k["bar"]}"><span class="sp"></span>{away_icon(variant, k["accent"])}'
            f'{ghosts}<span class="clock" style="color:{k["ink"]}">Wed 14:02</span></div>')

def icons_sheet(t):
    k = TH[t]
    ref = (f'<figure><div class="big">{mb.icon("guarding", k["accent"], 96)}</div>{mb.bar("guarding", t)}'
           f'<figcaption style="color:{k["ink"]}">Guarding (today)<span style="color:{k["mute"]}">for comparison</span></figcaption></figure>')
    cells = ref + "".join(
        f'<figure><div class="big">{away_icon(v, k["accent"], 96)}</div>{abar(v, t)}'
        f'<figcaption style="color:{k["ink"]}">{name}<span style="color:{k["mute"]}">{note}</span></figcaption></figure>'
        for v, name, note in VARIANTS)
    return (f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · Away armed icon. '
            f'Alarm reuses the Alert icon (the screen is locked, nobody sees the bar)</p><div class="row4">{cells}</div></div>')

# ---- menu: Away is row 5 (reserved in menubar.md §2) ------------------------------------------------------------
def amenu(t, status, away_on, guard_on, guard_en=True, extra=None):
    k = TH[t]
    q = lambda label, key="", on=False, en=True, sub=False: (
        f'<div class="mi" style="color:{k["ink"] if en else k["dis"]}"><span class="ck">{"✓" if on else ""}</span>'
        f'<span class="lb">{label}</span><span class="kc" style="color:{k["mute"] if en else k["dis"]}">{"›" if sub else key}</span></div>')
    sep = f'<div class="sepr" style="background:{k["sep"]}"></div>'
    rows = (f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">{status}</span></div>' + (extra or "") + sep
            + q("Guard", "⌘G", guard_on, guard_en) + q("Away", "⌘A", away_on) + q("Mode", sub=True, en=guard_en) + q("Banner", on=True, en=guard_en)
            + q("Sound", en=guard_en) + sep + q("Set up face again…", "⌘E", en=not away_on) + q("Delete face data", en=not away_on) + sep + q("Quit byaku", "⌘Q"))
    icon_bar = abar("A", t) if away_on else mb.bar("guarding" if guard_on else "off", t)
    return f'<div class="mwrap">{icon_bar}<div class="menu" style="width:270px;background:{k["menu"]};border-color:{k["sep"]}">{rows}</div></div>'

def menu_sheet(t):
    k = TH[t]
    cells = [
        (amenu(t, "Guard is off", False, False), "Not armed", "Away sits under Guard. Needs a face, like Guard"),
        (amenu(t, "Away in 5 s. Step away", True, True, guard_en=False), "Arming (5 s)",
         "counts down in the status line. Guard paused: checked but greyed, resumes on disarm"),
        (amenu(t, "Away. Locks if anyone looks", True, True, guard_en=False), "Armed",
         "your face is ignored; anyone else looking locks the Mac and sounds the alarm. Face setup/delete greyed"),
        (amenu(t, "Away. Camera unavailable, locking", True, False, guard_en=False), "Error while armed",
         "fails closed: the Mac locks at once, then Away turns off"),
    ]
    html = "".join(f'<figure>{m}<figcaption style="color:{k["ink"]}">{c}<span style="color:{k["mute"]}">{n}</span></figcaption></figure>'
                   for m, c, n in cells)
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · menu</p><div class="grid2">{html}</div></div>'

# ---- alarm volume: native submenu (no custom views in NSMenu, menubar.md §2) ------------------------------------
LEVELS = [("Full", "100%"), ("Loud", "75%"), ("Medium", "50%"), ("Quiet", "25%")]

def vol_menu(t, with_test):
    k = TH[t]
    q = lambda label, key="", on=False, en=True, sub=False, hl=False: (
        f'<div class="mi{" hl" if hl else ""}" style="color:{"#fff" if hl else (k["ink"] if en else k["dis"])}"><span class="ck">{"✓" if on else ""}</span>'
        f'<span class="lb">{label}</span><span class="kc" style="color:{"#fff" if hl else k["mute"]}">{"›" if sub else key}</span></div>')
    sep = f'<div class="sepr" style="background:{k["sep"]}"></div>'
    main = (f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">Guard is off</span></div>' + sep
            + q("Guard", "⌘G") + q("Away", "⌘A") + q("Alarm volume", sub=True, hl=True) + q("Mode", sub=True) + q("Banner", on=True) + q("Sound")
            + sep + q("Set up face again…", "⌘E") + q("Delete face data") + sep + q("Quit byaku", "⌘Q"))
    sub = "".join(f'<div class="mi two" style="color:{k["ink"]}"><span class="ck">{"●" if i == 0 else ""}</span>'
                  f'<span class="lb">{n}<small style="color:{k["mute"]}">{pct} of system volume</small></span></div>' for i, (n, pct) in enumerate(LEVELS))
    if with_test:
        sub += sep + q("Play test (3 s)")
    box = lambda inner, w: f'<div class="menu" style="width:{w}px;background:{k["menu"]};border-color:{k["sep"]}">{inner}</div>'
    return f'<div class="mwrap">{mb.bar("off", t)}<div class="mrow">{box(main, 250)}{box(sub, 190)}</div></div>'

SPK = {"lo": '<path d="M3 6h3l4-3v10l-4-3H3z" fill="currentColor"/><path d="M12 6.2a2.5 2.5 0 0 1 0 3.6" stroke="currentColor" stroke-width="1.4" fill="none" stroke-linecap="round"/>',
       "hi": '<path d="M3 6h3l4-3v10l-4-3H3z" fill="currentColor"/><path d="M12 6.2a2.5 2.5 0 0 1 0 3.6M13.8 4.4a5 5 0 0 1 0 7.2" stroke="currentColor" stroke-width="1.4" fill="none" stroke-linecap="round"/>'}

def slider(t, frac, w=226):
    """Control Center Sound style: a thick pill track, white fill up to the knob, white round knob with the speaker glyph."""
    k = TH[t]
    track = "rgba(0,0,0,.18)" if t == "light" else "rgba(255,255,255,.14)"
    knob, h = 24, 24
    x = round(frac * (w - knob))
    glyph = SPK["hi" if frac > .5 else "lo"]
    return (f'<div style="position:relative;width:{w}px;height:{h}px;border-radius:{h/2}px;background:{track}">'
            f'<div style="position:absolute;left:0;top:0;bottom:0;width:{x + knob}px;border-radius:{h/2}px;background:#fff;opacity:.92"></div>'
            f'<div style="position:absolute;left:{x}px;top:0;width:{knob}px;height:{knob}px;border-radius:50%;background:#fff;'
            f'box-shadow:0 1px 3px rgba(0,0,0,.3);display:flex;align-items:center;justify-content:center;color:#1d1d1f">'
            f'<svg width="14" height="14" viewBox="0 0 16 16">{glyph}</svg></div></div>')

def slider_menu(t, frac, caption_state="Guard is off"):
    k = TH[t]
    q = lambda label, key="", on=False, en=True, sub=False: (
        f'<div class="mi" style="color:{k["ink"] if en else k["dis"]}"><span class="ck">{"✓" if on else ""}</span>'
        f'<span class="lb">{label}</span><span class="kc" style="color:{k["mute"]}">{"›" if sub else key}</span></div>')
    sep = f'<div class="sepr" style="background:{k["sep"]}"></div>'
    vol = (f'<div style="padding:6px 13px 8px 23px"><div style="font:600 13px/1 -apple-system,system-ui,sans-serif;color:{k["ink"]};margin-bottom:8px">Alarm volume</div>'
           f'{slider(t, frac)}</div>')
    rows = (f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">{caption_state}</span></div>' + sep
            + q("Guard", "⌘G") + q("Away", "⌘A") + sep + vol + q("Play test (3 s)") + sep + q("Mode", sub=True) + q("Banner", on=True) + q("Sound")
            + sep + q("Set up face again…", "⌘E") + q("Delete face data") + sep + q("Quit byaku", "⌘Q"))
    return f'<div class="mwrap">{mb.bar("off", t)}<div class="menu" style="width:282px;background:{k["menu"]};border-color:{k["sep"]}">{rows}</div></div>'

def slider_sheet(t):
    k = TH[t]
    cells = (f'<figure>{slider_menu(t, 1.0)}<figcaption style="color:{k["ink"]}">C · slider, Full (default)'
             f'<span style="color:{k["mute"]}">Control Center style. Drag to set; letting go plays a 1 s blip at that level</span></figcaption></figure>'
             f'<figure>{slider_menu(t, 0.0)}<figcaption style="color:{k["ink"]}">C · slider at its lowest'
             f'<span style="color:{k["mute"]}">floor is 25%, never silent: the knob stops here, glyph never shows mute</span></figcaption></figure>')
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · alarm volume slider</p><div class="grid2">{cells}</div></div>'

def volume_sheet(t):
    k = TH[t]
    cells = (f'<figure>{vol_menu(t, False)}<figcaption style="color:{k["ink"]}">A · four levels'
             f'<span style="color:{k["mute"]}">pick a level; always unmuted while the alarm plays. Default Full</span></figcaption></figure>'
             f'<figure>{vol_menu(t, True)}<figcaption style="color:{k["ink"]}">B · four levels + Play test'
             f'<span style="color:{k["mute"]}">same, plus a 3 s preview at the chosen level so you hear what a looker hears</span></figcaption></figure>')
    return f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · alarm volume</p><div class="grid2">{cells}</div></div>'

# ---- PR11: alarm sound picker + recorded message (docs/designs/away-mode.md §Sound, §Message) ------------------
SOUNDS = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

def sound_menu(t, msg_sub, open_sub, armed=False):
    k = TH[t]
    def q(label, key="", on=False, en=True, sub=False, hl=False, small=None):
        col = "#fff" if hl else (k["ink"] if en else k["dis"])
        lb = f'{label}<small style="color:{"rgba(255,255,255,.8)" if hl else k["mute"]}">{small}</small>' if small else label
        return (f'<div class="mi{" hl" if hl else ""}{" two" if small else ""}" style="color:{col}"><span class="ck">{"✓" if on else ""}</span>'
                f'<span class="lb">{lb}</span><span class="kc" style="color:{"#fff" if hl else k["mute"]}">{"›" if sub else key}</span></div>')
    sep = f'<div class="sepr" style="background:{k["sep"]}"></div>'
    vol = (f'<div style="padding:6px 13px 8px 23px"><div style="font:600 13px/1 -apple-system,system-ui,sans-serif;color:{k["ink"]};margin-bottom:8px">Alarm volume</div>'
           f'{slider(t, 1.0)}</div>')
    status = "Away. Locks if anyone looks" if armed else "Guard is off"
    main = (f'<div class="mi" style="color:{k["dis"]}"><span class="ck"></span><span class="lb">{status}</span></div>' + sep
            + q("Guard", "⌘G", en=not armed) + q("Away", "⌘A", on=armed) + sep + vol
            + q("Alarm sound", sub=True, hl=open_sub, en=not armed, small="Siren")
            + q("Message…", en=not armed, small=msg_sub) + q("Play test (3 s)") + sep
            + q("Mode", sub=True, en=not armed) + q("Banner", on=True, en=not armed) + q("Sound", en=not armed)
            + sep + q("Quit byaku", "⌘Q"))
    box = lambda inner, w, extra="": f'<div class="menu" style="width:{w}px;background:{k["menu"]};border-color:{k["sep"]};{extra}">{inner}</div>'
    if not open_sub:
        return f'<div class="mwrap">{abar("A", t) if armed else mb.bar("off", t)}{box(main, 282)}</div>'
    subm = q("Siren", on=True) + sep + "".join(q(n) for n in SOUNDS)
    return f'<div class="mwrap">{mb.bar("off", t)}<div class="mrow">{box(main, 282)}{box(subm, 150, "margin-top:150px")}</div></div>'

MIC = ('<svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true"><g fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round">'
       '<rect x="18" y="8" width="12" height="22" rx="6"/><path d="M12 24a12 12 0 0 0 24 0M24 36v5"/></g></svg>')

def message_sheet(t):
    k = TH[t]
    r = lambda *a: mb.ring48(t, *a)
    spin = ('<svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">'
            f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["line"]}" stroke-width="4"/>'
            f'<circle cx="24" cy="24" r="22" fill="none" stroke="{k["ink"]}" stroke-width="4" stroke-dasharray="34 200" transform="rotate(-90 24 24)"/></svg>')
    cases = [
        ("idle · no message yet", MIC.format(c=k["ink"]), "Record a message", "Plays instead of the spoken line. Up to 8 s.", ["Cancel", "*Record"]),
        ("waiting for permission (first time only)", spin, "Waiting for microphone…", "Choose Allow in the system prompt.", ["Cancel"]),
        ("recording, 3 s in", r("capture", 3 / 8, "5"), "Recording…", "Speak now. Stops by itself at 8 s.", ["*Stop"]),
        ("recorded · Delete is one click, no confirm", r("ok"), "Message saved", "6 s. Stored on this Mac only.", ["Delete", "Record again", "*Play"]),
        ("playing back", r("capture", 2 / 6, "4"), "Playing…", "At the alarm volume.", ["*Stop"]),
        ("mic denied", r("seam"), "Microphone access is off", "Allow byaku in System Settings, then try again.", ["Cancel", "*Open microphone settings…"]),
        ("failed (no mic, too short)", r("seam"), "Couldn’t record", "Too short. Try again.", ["Cancel", "*Try again"]),
    ]
    cells = "".join(f'<figure>{mb.card(t, ri, a, b, c).replace('class="card"', 'class="card w336"')}'
                    f'<figcaption style="color:{k["mute"]}">{n}</figcaption></figure>' for n, ri, a, b, c in cases)
    menus = (f'<figure>{sound_menu(t, "Spoken line", True)}<figcaption style="color:{k["ink"]}">Alarm sound ▸'
             f'<span style="color:{k["mute"]}">Siren first, then every macOS sound A–Z. Picking only sets it; Play test previews. Slider release no longer blips</span></figcaption></figure>'
             f'<figure>{sound_menu(t, "Recorded · 6 s", False)}<figcaption style="color:{k["ink"]}">Message…'
             f'<span style="color:{k["mute"]}">subtitle shows what plays after the tone: “Spoken line” or “Recorded · N s”. Opens the panel below</span></figcaption></figure>'
             f'<figure>{sound_menu(t, "Recorded · 6 s", False, armed=True)}<figcaption style="color:{k["ink"]}">Armed'
             f'<span style="color:{k["mute"]}">Alarm sound and Message greyed; volume and Play test stay live</span></figcaption></figure>')
    return (f'<div class="panel" style="background:{k["bg"]}"><p class="cap" style="color:{k["mute"]}">{t} · alarm sound + message</p>'
            f'<div class="grid2">{menus}</div><div style="height:48px"></div><div class="grid2">{cells}</div></div>')

CSS = mb.CSS + """
.mrow{display:flex;align-items:flex-start}.mrow .menu+.menu{margin-left:-6px;margin-top:66px}
.mi.hl{background:#0A64D8}.mi.two{height:34px}.card.w336{width:336px}.card.w336 .btn{white-space:nowrap}.card.w336 .tx{width:224px}.mi.two .lb{display:flex;flex-direction:column;gap:1px}.mi.two small{font-size:11px}
""" + ".grid2{display:grid;grid-template-columns:repeat(2,1fr);gap:40px 32px;align-items:start}"

def page():
    sec = lambda sid, f: f'<section id="{sid}" class="pair">{f("light")}{f("dark")}</section>'
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>byaku Away mockups</title><style>{CSS}</style></head><body>'
            + sec("icons", icons_sheet) + sec("menu", menu_sheet) + sec("volume", volume_sheet) + sec("slider", slider_sheet) + sec("sounds", message_sheet) + '</body></html>')

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for s in ("icons", "menu", "volume", "slider", "sounds"):
            pg.locator(f"#{s}").screenshot(path=str(OUT / f"sheet-{s}.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and 2 sheets")
