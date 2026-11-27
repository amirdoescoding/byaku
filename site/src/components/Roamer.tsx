import { useEffect } from 'react';
import { Mascot } from './Mascot';

export const DOWNLOAD = 'https://github.com/amirdoescoding/byaku/releases/latest/download/Byaku-arm64.zip';

/**
 * Hero mascot that watches the cursor, roams the gutters, and the docking Download pill.
 * Ported from design/site/motion.html (the approved prototype). Everything is rAF-on-demand: the loop
 * stops when the springs settle and when the tab is hidden.
 */
export default function Roamer() {
  useEffect(() => {
    const $ = <T extends Element = HTMLElement>(s: string) => document.querySelector(s) as T;
    const html = document.documentElement;
    const m = $('#m'), pill = $('#pill'), slot = $('#slot'), dl = $('#dl');
    const pm = pill.querySelector('.mascot') as SVGElement, mm = m.querySelector('.mascot') as SVGElement;
    const gz = mm.querySelector('.gz') as SVGGElement;
    const rmq = matchMedia('(prefers-reduced-motion:reduce)');
    const RM = () => rmq.matches;
    const ss = {
      get: (k: string) => { try { return +(sessionStorage.getItem(k) || 0); } catch { return 0; } },
      set: (k: string, v: number) => { try { sessionStorage.setItem(k, String(v)); } catch { /* private mode */ } },
    };
    const setExpr = (el: SVGElement, n: string) => el.setAttribute('class', `mascot e-${n}`);

    /* spring easing (linear()) for the dock; ~9% overshoot, settles in ~0.8 s */
    const springEase = (k = 220, c = 18, n = 40, T = .85) => {
      let x = 0, v = 0; const p: string[] = [], dt = 1 / 240, per = Math.round(T / dt / n);
      for (let i = 0; i <= n; i++) { p.push(x.toFixed(4)); for (let j = 0; j < per; j++) { v += ((1 - x) * k - v * c) * dt; x += v * dt; } }
      p[n] = '1'; return `linear(${p.join(',')})`;
    };
    const EASE = springEase();

    /* pill dock: IntersectionObserver on the hero button, FLIP with a spring */
    let docked = false;
    const dock = (on: boolean, from: DOMRect) => {
      if (on === docked) return; docked = on; pill.getAnimations().forEach((a) => a.cancel());
      const f = pill.getBoundingClientRect(), dx = from.left + from.width / 2 - (f.left + f.width / 2), dy = from.top + from.height / 2 - (f.top + f.height / 2);
      if (on) pill.classList.add('on');
      if (!RM()) {
        const a = pill.animate(on
          ? [{ transform: `translate(${dx}px,${dy}px)`, opacity: 0 }, { transform: 'none', opacity: 1 }]
          : [{ transform: 'none', opacity: 1 }, { transform: `translate(${dx}px,${dy}px)`, opacity: 0 }],
          { duration: 850, easing: on ? EASE : 'cubic-bezier(.2,.8,.2,1)' });
        if (!on) a.onfinish = () => { if (!docked) pill.classList.remove('on'); };
      } else if (!on) pill.classList.remove('on');
    };
    const io = new IntersectionObserver(([e]) => {
      const r = e.boundingClientRect;
      if (!e.isIntersecting && r.top < 0) dock(true, r); else if (e.isIntersecting && docked) dock(false, r);
    });
    io.observe(dl);

    /* pill emotes: hover happy, press joy */
    const emo = (s: string) => setExpr(pm, s);
    const pe = { enter: () => emo('happy'), leave: () => { emo('idle'); pill.classList.remove('press'); }, up: () => { emo('happy'); pill.classList.remove('press'); },
      down: () => {
        emo('joy'); pill.classList.add('press');
        if (!RM()) pm.animate([{ transform: 'translateY(0) scale(1)' }, { transform: 'translateY(-10px) scale(.92,1.12)', offset: .35 }, { transform: 'translateY(0) scale(1.06,.94)', offset: .7 }, { transform: 'none' }], { duration: 520, easing: 'cubic-bezier(.2,.8,.2,1)' });
      } };
    pill.addEventListener('pointerenter', pe.enter); pill.addEventListener('pointerleave', pe.leave);
    pill.addEventListener('focus', pe.enter); pill.addEventListener('blur', pe.leave);
    pill.addEventListener('pointerdown', pe.down); pill.addEventListener('pointerup', pe.up);

    /* roamer */
    const secs = [...document.querySelectorAll<HTMLElement>('[data-expr]')];
    let idx = 0, bias = ss.get('byakuBias'), ovr: string | null = null, ptr = { x: innerWidth / 2, y: innerHeight / 2 }, vel = 0, lastY = scrollY;
    const st = { x: { p: 0, v: 0 }, y: { p: 0, v: 0 }, s: { p: 240, v: 0 }, gx: { p: 0, v: 0 }, gy: { p: 0, v: 0 } };
    let raf = 0, snap = true, last = 0, shooT = 0;
    const clamp = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v)), sm = (t: number) => t * t * (3 - 2 * t);
    const step = (o: { p: number; v: number }, t: number, dt: number, k = 150, c = 17) => { o.v += ((t - o.p) * k - o.v * c) * dt; o.p += o.v * dt; return Math.abs(t - o.p) + Math.abs(o.v); };
    function targets() {
      const vw = innerWidth, vh = innerHeight, sy = scrollY, gut = (vw - 960) / 2, roam = gut >= 130 && !RM();
      const r = slot.getBoundingClientRect(), hx = r.left + r.width / 2, hy = r.top + r.height / 2, hs = r.width;
      const vm = sy + vh / 2; idx = 0; secs.forEach((s, i) => { if (s.offsetTop <= vm) idx = i; });
      const side = ((idx + bias) % 2) ? 1 : 0, rx = side ? vw - gut / 2 : gut / 2, w = roam ? sm(clamp(sy / (vh * .8), 0, 1)) : 0, wx = roam ? sm(clamp(sy / (vh * .35), 0, 1)) : 0; // sideways first: clear the hero text before dropping
      const ry = vh * .5 + Math.sin(sy / 380) * vh * .16, sway = Math.sin(sy / 260) * gut * .14;
      return { x: hx + (rx + sway - hx) * wx, y: hy + (ry - hy) * w, s: hs + (72 - hs) * wx, roam };
    }
    function frame(t: number) {
      raf = 0; if (document.hidden) return;
      const dt = Math.min(.033, (t - (last || t)) / 1000 || .016); last = t;
      const T = targets(); let err = 0;
      if (snap || !T.roam) { st.x.p = T.x; st.y.p = T.y; st.s.p = T.s; st.x.v = st.y.v = st.s.v = 0; snap = false; }
      else { err += step(st.x, T.x, dt); err += step(st.y, T.y, dt); err += step(st.s, T.s, dt, 200, 22); }
      /* gaze: blades lean toward the pointer (last tap on touch) + scroll velocity */
      const dx = ptr.x - st.x.p, dy = ptr.y - st.y.p, d = Math.hypot(dx, dy) || 1, k = RM() ? 0 : Math.min(1, d / 400) * 2.4;
      vel += (clamp(scrollY - lastY, -60, 60) - vel) * .2; lastY = scrollY;
      err += step(st.gx, dx / d * k, dt, 260, 24); err += step(st.gy, dy / d * k + (RM() ? 0 : clamp(vel / 30, -1, 1) * 1.6), dt, 260, 24);
      m.style.transform = `translate(${st.x.p - 120}px,${st.y.p - 120}px) scale(${st.s.p / 240})`;
      gz.style.transform = `translate(${st.gx.p}px,${st.gy.p}px)`;
      const e = ovr || secs[idx]?.dataset.expr || 'idle';
      if (mm.dataset.e !== e) { mm.dataset.e = e; setExpr(mm, e); }
      if (err > .02 || Math.abs(vel) > .5) raf = requestAnimationFrame(frame);
    }
    const kick = () => { if (!raf && !document.hidden) raf = requestAnimationFrame(frame); };
    const onMove = (e: PointerEvent) => { ptr = { x: e.clientX, y: e.clientY }; if (e.pointerType !== 'touch') kick(); };
    const onDown = (e: PointerEvent) => { ptr = { x: e.clientX, y: e.clientY }; kick(); };
    const onRm = () => { snap = true; kick(); };
    addEventListener('scroll', kick, { passive: true }); addEventListener('resize', kick, { passive: true });
    addEventListener('pointermove', onMove, { passive: true }); addEventListener('pointerdown', onDown, { passive: true });
    document.addEventListener('visibilitychange', kick); rmq.addEventListener('change', onRm);

    /* click to shoo: hop to the other gutter, remembered for the session */
    const onShoo = () => {
      bias ^= 1; ss.set('byakuBias', bias); ovr = 'raised'; clearTimeout(shooT);
      shooT = window.setTimeout(() => { ovr = null; kick(); }, 900);
      if (!RM()) st.y.v -= 1100; kick();
    };
    m.addEventListener('click', onShoo);

    frame(performance.now()); html.classList.add('roam-on');
    document.fonts.ready.then(() => { snap = true; kick(); });
    return () => {
      io.disconnect(); cancelAnimationFrame(raf); clearTimeout(shooT); html.classList.remove('roam-on');
      removeEventListener('scroll', kick); removeEventListener('resize', kick); removeEventListener('pointermove', onMove); removeEventListener('pointerdown', onDown);
      document.removeEventListener('visibilitychange', kick); rmq.removeEventListener('change', onRm); m.removeEventListener('click', onShoo);
      pill.removeEventListener('pointerenter', pe.enter); pill.removeEventListener('pointerleave', pe.leave); pill.removeEventListener('focus', pe.enter);
      pill.removeEventListener('blur', pe.leave); pill.removeEventListener('pointerdown', pe.down); pill.removeEventListener('pointerup', pe.up);
    };
  }, []);

  return (
    <>
      <div id="m" aria-hidden="true"><Mascot expr="idle" /></div>
      <a id="pill" className="pill" href={DOWNLOAD}><Mascot expr="idle" />Download for Mac</a>
    </>
  );
}
