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

CSS = mb.CSS + ".grid2{display:grid;grid-template-columns:repeat(2,1fr);gap:40px 32px;align-items:start}"

def page():
    sec = lambda sid, f: f'<section id="{sid}" class="pair">{f("light")}{f("dark")}</section>'
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>byaku Away mockups</title><style>{CSS}</style></head><body>'
            + sec("icons", icons_sheet) + sec("menu", menu_sheet) + '</body></html>')

if __name__ == "__main__":
    html = page()
    (OUT / "mockups.html").write_text(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1200, "height": 1000}, device_scale_factor=2)
        pg.set_content(html, wait_until="networkidle")
        for s in ("icons", "menu"):
            pg.locator(f"#{s}").screenshot(path=str(OUT / f"sheet-{s}.png"))
        b.close()
    print("wrote", OUT / "mockups.html", "and 2 sheets")
