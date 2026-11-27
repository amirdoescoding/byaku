// byaku launch film: the mascot tells you about itself. Every value is a pure function of t (seconds).
import React, { createContext, useContext } from 'react';
import { AbsoluteFill, Audio, continueRender, delayRender, interpolate, Sequence, spring, staticFile, useCurrentFrame } from 'remotion';
import { BLADE_L, BLADE_R, RING } from '../../site/src/components/Mascot';
import { Scene } from '../../site/src/remotion/GuardScene';

// ---------- fonts (same files as the site) ----------
const fontsReady = delayRender('fonts');
Promise.all([
  new FontFace('Rondel', `url(${staticFile('fonts/rondel.woff2')})`, { weight: '100 900' }),
  new FontFace('Beacon', `url(${staticFile('fonts/beacon.woff2')})`, { weight: '100 900' }),
].map((f) => f.load().then((l) => document.fonts.add(l)))).then(() => continueRender(fontsReady));

// Both palettes from design/brand/palette.md; GuardScene reads them as CSS variables.
export const PALETTES = {
  dark: { bg: '#0E0D12', surface: '#17161C', line: '#25232C', mute: '#8F8C99', ink: '#ECEBF0', accent: '#C8BFEF' },
  light: { bg: '#F5F5F7', surface: '#FFFFFF', line: '#E1E0E6', mute: '#66636F', ink: '#0E0D12', accent: '#6A5DB8' },
};
type Pal = (typeof PALETTES)['dark'];
const PalCtx = createContext<Pal>(PALETTES.dark);
const usePal = () => useContext(PalCtx);

// ---------- time helpers ----------
export const FPS = 30;
// "EZ4U (Instrumental Version)", Jae Young Woo (Epidemic Sound), 32 s edit bd570b1a. librosa: 82.7 BPM; quiet groove
// until the kick drops at 13.13 s, then it drives to a clean end at ~32 s. The film plays the track 1:1 from 0.
// Story time: the timeline is authored with the drop at 13.0 s; post-drop events are placed in beats with B(k).
export const TRACK_IN = 0;
const FILM_DROP = 13.13;
const BPM = 82.7, BEAT = 60 / BPM, DROP = 13.0;
/** Beat grid anchored on the bar downbeat just before the drop (film 12.77 s); the kick drop is the "and" of beat 0 (B(0.5)).
 *  Later downbeats: B(4) 15.67, B(8) 18.58, B(12) 21.49, B(16) 24.40, B(20) 27.32, B(24) 30.23 (film seconds). */
const BAR0 = 12.77 - (13.13 - DROP), OFFSET = BAR0 % BEAT;
const B = (k: number) => BAR0 + k * BEAT;
/** The stare before the drop: anime hard cuts on the beat — byaku close-up, "peeks" + screen close-up, then the whole frame. */
const STARE = 10.0, CUT1 = B(-3), CUT2 = B(-2);
/** After the text close-up, the camera pulls out smoothly to the whole frame, clear before the drop. */
const ZOUT_START = CUT2 + 0.45, ZOUT_END = B(-0.6);
/** Mad mode: byaku charges from B(5), then on the B(8) downbeat rockets up through "Step away, and I lock it." (SMASH). */
const CHARGE = B(5), SMASH = B(8) + 0.1;
/** Where byaku rests while shoving the two lines: left of "Nothing leaves your Mac.", right of "Free and open source.". */
const PUSH_L = { x: 440, y: 575 }, PUSH_R = { x: 1550, y: 575 };
/** Resting spots: byaku + its line sit centred as one group (the line is shoved ~135 px past centre). */
const REST_L = 575, REST_R = 1415;
/** The push run: roll off left (B11) → shove "Nothing leaves" in (B11.8) → shove it out right (B14.4) → shove "Free" in from the right (B15.6). */
const ROLL_AWAY = B(11), PUSH_IN = B(11.8), PUSH_OUT = B(14.4), PUSH_FREE = B(15.6);
/** Byaku pops in on the track's first hit (film 0.41 s); "byaku." slams on the bass entry at film 1.50 s. */
const POP = 0.41 - (13.13 - DROP), HOOK_HIT = 1.5 - (13.13 - DROP);
/** "peeks" holds half-risen until here (inside the screen close-up). */
const PEEK_FULL = CUT2 + 0.3;
const story = (tf: number) => tf - (FILM_DROP - DROP);
export const DURATION = 32.2; // film seconds; the track ends at ~32.2 s
const ease = (x: number) => x * x * (3 - 2 * x);
const sp = (t: number, at: number, damping = 14, stiffness = 170) =>
  t < at ? 0 : spring({ frame: (t - at) * FPS, fps: FPS, config: { damping, stiffness } });
const ramp = (t: number, a: number, b: number) => interpolate(t, [a, b], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
const lerp = (p: number, a: number, b: number) => a + (b - a) * p;
const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));

/** Animate keys through [{at, to}] with springs; each move starts from where the last one is. */
function track<V extends Record<string, number>>(t: number, start: V, moves: { at: number; to: Partial<V>; d?: number; k?: number }[]): V {
  const v = { ...start };
  for (const m of moves) {
    const p = sp(t, m.at, m.d ?? 16, m.k ?? 150);
    if (p === 0) break;
    for (const key in m.to) (v as Record<string, number>)[key] = lerp(p, v[key], m.to[key] as number);
  }
  return v;
}

// ---------- the mascot ----------
type Pose = { lx: number; ly: number; lr: number; rx: number; ry: number; rr: number };
const P = (l: [number, number, number], r: [number, number, number]): Pose => ({ lx: l[0], ly: l[1], lr: l[2], rx: r[0], ry: r[1], rr: r[2] });
// Same values as the CSS expressions in site/src/styles/global.css, plus two film-only ones.
const E = {
  idle: P([0, 0, 0], [0, 0, 0]),
  raised: P([-1, -4, -3], [1, -4, 3]),
  focus: P([1, 3, 10], [-1, 3, -10]),
  frown: P([-1, 4, -20], [1, 4, 20]),
  look: P([3, -3, 6], [3, -3, 6]),
  calm: P([0, 2, -6], [0, 2, 6]),
  happy: P([-2, -4, -8], [2, -4, 8]),
  joy: P([-3, -5, -14], [3, -5, 14]),
  sideEye: P([2, 1, 4], [2, 4, 22]),
  wink: P([-2, -5, -12], [0, 4, 16]),
  mad: P([-1, 7, -30], [1, 7, 30]),
};

/** Mascot in the frame: centre (x, y), size in px. squash > 0 flattens from the base, < 0 stretches. */
function Mascot({ x, y, size, pose, squash = 0, tilt = 0, color }: { x: number; y: number; size: number; pose: Pose; squash?: number; tilt?: number; color: string }) {
  const sy = 1 - squash, sx = 1 / Math.sqrt(Math.max(sy, 0.3));
  return (
    <svg viewBox="0 0 64 64" width={size} height={size} style={{ position: 'absolute', left: x - size / 2, top: y - size / 2, overflow: 'visible' }}>
      <g transform={`translate(32 61) scale(${sx} ${sy}) rotate(${tilt}) translate(-32 -61)`}>
        <path d={RING} fill="none" stroke={color} strokeWidth="2.25" />
        <path d={BLADE_L} fill={color} transform={`translate(${pose.lx} ${pose.ly}) rotate(${pose.lr} 32 32)`} />
        <path d={BLADE_R} fill={color} transform={`translate(${pose.rx} ${pose.ry}) rotate(${pose.rr} 32 32)`} />
      </g>
    </svg>
  );
}

/** Expression timeline: springs from each pose to the next, with brows a beat behind the body (overlapping action). */
function poseAt(t: number, keys: [number, keyof typeof E][]): Pose {
  let cur = E[keys[0][1]];
  for (const [at, e] of keys.slice(1)) {
    const p = sp(t, at + 0.04, 12, 220);
    if (p === 0) break;
    const nxt = E[e];
    cur = Object.fromEntries(Object.keys(cur).map((k) => [k, lerp(p, cur[k as keyof Pose], nxt[k as keyof Pose])])) as Pose;
  }
  return cur;
}

/** A quick brow blink: drops 3 px and back over ~5 frames. */
const blink = (t: number, at: number[]) => at.reduce((a, b) => a + (t > b && t < b + 0.18 ? Math.sin(((t - b) / 0.18) * Math.PI) * 3.5 : 0), 0);

/** The head-bob: a squash on every beat that decays, only while `on`. */
const bob = (t: number, on: number) => {
  const ph = ((t - OFFSET) % BEAT) / BEAT;
  return on * 0.09 * Math.exp(-ph * 7) * Math.cos(ph * Math.PI * 2.2);
};

// ---------- kinetic type, lettered like a manga panel ----------
// A line is rows of words. Each row has its own size and tilt. The *starred* word is the hit: it lands last,
// slams in from 2.4× with an impact burst and a camera kick. Text carries a paper outline (manga lettering), so it
// survives speed lines and UI behind it.
type Row = { text: string; size: number; rot?: number };
/** How a line arrives. Only `slam` lines kick the camera and burst, so the big hit stays rare. */
type Fx = 'slam' | 'slide' | 'drop' | 'peek' | 'shake' | 'soft' | 'carried';
/** `hide`: [from, to] blanks the line (it is off-frame during the close-up cuts). */
/** `shatter`: the time byaku smashes through the line; its letters burst apart. `carried` lines have no entrance of their own:
 *  byaku moves them (Film passes the offset). */
type Line = { at: number; out: number; y: number; rows: Row[]; inline?: boolean; fx?: Fx; hide?: [number, number]; shatter?: number; id?: string };
const STAGGER = 0.1, HIT_DELAY = 0.16;

/** Start time of each word, in reading order; the hit word waits a beat longer. */
function wordTimes(l: Line) {
  let n = 0;
  return l.rows.map((r) => r.text.split(' ').map((w) => (w.includes('*') ? l.at + n++ * STAGGER + HIT_DELAY : l.at + n++ * STAGGER)));
}
export const hitTimes = (lines: Line[]) => lines.filter((l) => l.fx === 'slam').flatMap((l) => {
  const ts = wordTimes(l);
  return l.rows.flatMap((r, ri) => r.text.split(' ').flatMap((w, wi) => (w.includes('*') ? [ts[ri][wi]] : [])));
});

/** Short radial strokes that burst out of a hit word and vanish (a manga impact). */
function Burst({ t, at, size, color }: { t: number; at: number; size: number; color: string }) {
  const p = ramp(t, at + 0.03, at + 0.4);
  if (p <= 0 || p >= 1) return null;
  const e = 1 - (1 - p) ** 3;
  return (
    <svg viewBox="-100 -100 200 200" width={size * 3.2} height={size * 3.2} style={{ position: 'absolute', left: '50%', top: '50%', translate: '-50% -50%', overflow: 'visible', pointerEvents: 'none' }}>
      {Array.from({ length: 14 }, (_, i) => {
        const a = (i / 14) * Math.PI * 2 + 0.2, r1 = 42 + e * 28, r2 = r1 + 14 * (1 - p) + 4;
        return <line key={i} x1={Math.cos(a) * r1 * 1.5} y1={Math.sin(a) * r1 * 0.75} x2={Math.cos(a) * r2 * 1.5} y2={Math.sin(a) * r2 * 0.75} stroke={color} strokeWidth={3.2 * (1 - p) + 0.6} strokeLinecap="round" />;
      })}
    </svg>
  );
}

function Words({ t, l, off = [0, 0] }: { t: number; l: Line; off?: [number, number] }) {
  const C = usePal();
  if (t < l.at - 0.05 || t > l.out + 0.7) return null;
  if (l.hide && t >= l.hide[0] && t < l.hide[1]) return null;
  const fx = l.fx ?? 'soft';
  const ts = wordTimes(l);
  const push = 1 + ramp(t, l.at, l.out) * 0.04;
  let n = 0;
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: l.y, display: 'flex', flexDirection: l.inline ? 'row' : 'column', alignItems: l.inline ? 'baseline' : 'center', justifyContent: 'center', columnGap: 24, scale: `${push}`, translate: `${off[0]}px ${off[1]}px` }}>
      {l.rows.map((r, ri) => (
        <div key={ri} style={{ display: 'flex', alignItems: 'baseline', columnGap: r.size * 0.24, rotate: `${r.rot ?? 0}deg`, marginTop: ri && !l.inline ? -r.size * 0.04 : 0 }}>
          {r.text.split(' ').map((raw, wi) => {
            const hot = raw.includes('*'), w = raw.replaceAll('*', ''), at = ts[ri][wi], idx = n++;
            const x = clamp(ramp(t, l.out + idx * 0.04, l.out + idx * 0.04 + 0.28)), xe = x * x;
            const side = idx % 2 ? 1 : -1;
            // entry: [progress, dx, dy, rotation, scale-from, scaleX-from, blur] per effect
            let k = sp(t, at, 12, 230), dx = 0, dy = r.size * 0.5, rot = side * 3, from = 1.15, sx = 1, blur = 9;
            if (fx === 'slam' && hot) { k = sp(t, at, 9, 320); dy = 0; rot = side * 4; from = 2.4; blur = 4; }
            if (fx === 'slide') { k = sp(t, at - idx * 0.05, 16, 210); dx = (ri % 2 ? -1 : 1) * 700; dy = 0; rot = 0; from = 1; sx = 1.8; blur = 6; }
            if (fx === 'carried') { k = 1; blur = 0; }
            if (fx === 'drop') { k = sp(t, at, 8, 260); dy = -r.size * 1.4; rot = side * 10; from = 1; blur = 3; }
            let peekY = 0, jitter = 0;
            if (fx === 'peek' && hot) { // rises halfway, hesitates well into the silence, then comes all the way up
              k = 1; blur = 0;
              peekY = r.size * lerp(sp(t, at, 14, 160), 1.05, 0.55) - r.size * 0.55 * sp(t, PEEK_FULL, 12, 220);
            }
            if (fx === 'shake' && hot && t > at + 0.3) jitter = Math.sin(t * 83 + idx) * 3 + Math.sin(t * 131) * 2;
            if (l.shatter !== undefined && t >= l.shatter) {
              // smashed: every letter flies up and out from the impact, spinning, under gravity
              const dt = t - l.shatter, mid = 2.5;
              return (
                <span key={wi} style={{ display: 'inline-block', whiteSpace: 'pre', fontFamily: 'Rondel', fontWeight: hot ? 600 : 500, letterSpacing: '-0.025em', fontSize: r.size, lineHeight: 1.05, color: C.ink, WebkitTextStroke: `${Math.max(6, r.size * 0.13)}px ${C.bg}`, paintOrder: 'stroke fill' }}>
                  {w.split('').map((ch, ci) => {
                    const h = Math.sin((idx * 31 + ci * 7.3) * 12.9898) * 43758.5453, rnd = h - Math.floor(h);
                    const vx = (idx - mid) * 260 + (ci - w.length / 2) * 90 + (rnd - 0.5) * 300, vy = -(700 + rnd * 700);
                    return <span key={ci} style={{ display: 'inline-block', translate: `${vx * dt}px ${vy * dt + 2600 * dt * dt}px`, rotate: `${(rnd - 0.5) * 900 * dt}deg`, opacity: 1 - ramp(dt, 0.35, 0.8) }}>{ch}</span>;
                  })}
                </span>
              );
            }
            const word = (
              <span style={{
                position: 'relative', fontFamily: 'Rondel', fontWeight: hot ? 600 : 500, letterSpacing: '-0.025em', fontSize: r.size, lineHeight: 1.05,
                color: C.ink, display: 'inline-block', WebkitTextStroke: `${Math.max(6, r.size * 0.13)}px ${C.bg}`, paintOrder: 'stroke fill',
                opacity: (fx === 'peek' && hot ? 1 : clamp(k * 2)) * (1 - xe),
                translate: `${(1 - k) * dx + xe * side * 40 + jitter}px ${(1 - k) * dy + peekY - xe * r.size * 0.8 + jitter * 0.6}px`,
                rotate: `${(1 - k) * rot - xe * side * 12}deg`,
                scale: `${lerp(clamp(k), sx, 1) * lerp(clamp(k), from, 1) - xe * 0.2} ${lerp(clamp(k), from, 1) - xe * 0.2}`,
                filter: `blur(${(1 - clamp(k)) * blur + xe * 12}px)`,
              }}>
                {fx === 'slam' && hot && <Burst t={t} at={at} size={r.size} color={C.ink} />}
                {w}
              </span>
            );
            // peek: the word comes up from behind an invisible edge (clipped at its baseline)
            return fx === 'peek' && hot
              ? <span key={wi} style={{ display: 'inline-block', overflow: 'hidden', paddingInline: 12, marginInline: -12, paddingTop: 20, marginTop: -20 }}>{word}</span>
              : <React.Fragment key={wi}>{word}</React.Fragment>;
          })}
        </div>
      ))}
    </div>
  );
}

/** Manga sound effects in katakana, vertical, outlined, trembling. Hiragino Sans is the macOS system face. */
function Sfx({ t, at, out, text, x, y, size, rot = 0, shake = 0 }: { t: number; at: number; out: number; text: string; x: number; y: number; size: number; rot?: number; shake?: number }) {
  const C = usePal();
  if (t < at || t > out + 0.3) return null;
  const k = sp(t, at, 10, 260), o = ramp(t, out, out + 0.25);
  const j = shake * (Math.sin(t * 97 + x) + Math.sin(t * 61 + y) * 0.6);
  return (
    <div style={{ position: 'absolute', left: x, top: y, writingMode: 'vertical-rl', fontFamily: 'Hiragino Sans', fontWeight: 800, fontSize: size, lineHeight: 1, letterSpacing: '-0.08em',
      color: C.ink, WebkitTextStroke: `${size * 0.16}px ${C.bg}`, paintOrder: 'stroke fill', rotate: `${rot}deg`, translate: `${j}px ${j * 0.7}px`,
      scale: `${lerp(k, 1.8, 1) * (1 - o * 0.3)}`, opacity: clamp(k * 2) * (1 - o) }}>{text}</div>
  );
}

/** A four-point sparkle (the manga "kira") for the wink. */
function Sparkle({ t, at, x, y, size, color }: { t: number; at: number; x: number; y: number; size: number; color: string }) {
  const k = sp(t, at, 8, 300) * (1 - ramp(t, at + 0.7, at + 1.0));
  if (k <= 0.01) return null;
  return (
    <svg viewBox="-10 -10 20 20" width={size} height={size} style={{ position: 'absolute', left: x - size / 2, top: y - size / 2, scale: `${k}`, rotate: `${(t - at) * 90}deg` }}>
      <path d="M0-10Q1.2-1.2 10 0Q1.2 1.2 0 10Q-1.2 1.2-10 0Q-1.2-1.2 0-10Z" fill={color} />
    </svg>
  );
}

// ---------- script ----------
// Hook → menu bar → the catch (Iris) → Away (mad mode) → on-device → end card with a wink.
const LINES: Line[] = [
  { at: HOOK_HIT - 0.26, out: 2.55, y: 650, fx: 'slam', rows: [{ text: "Hi, I'm", size: 64, rot: -3 }, { text: '*byaku.*', size: 210, rot: -3 }] },
  { at: 3.1, out: 6.15, y: 440, fx: 'slide', id: 'menubar', rows: [{ text: 'I live in your', size: 64, rot: 2 }, { text: 'menu *bar.*', size: 150, rot: 2 }] },
  { at: 6.6, out: 8.6, y: 600, fx: 'drop', rows: [{ text: 'I watch', size: 70, rot: -2 }, { text: 'your *back.*', size: 160, rot: -4 }] },
  { at: 9.1, out: 12.35, y: 70, inline: true, fx: 'peek', hide: [CUT1, CUT2], rows: [{ text: 'Someone', size: 64, rot: -2 }, { text: '*peeks*', size: 124, rot: -6 }, { text: 'at your screen?', size: 64, rot: 1 }] },
  { at: DROP - 3 * 0.1 - 0.16 - 1 / FPS, out: B(3.5), y: 62, inline: true, fx: 'slam', rows: [{ text: 'I let you', size: 64, rot: 2 }, { text: '*know.*', size: 140, rot: -3 }] },
  { at: B(4), out: 99, y: 50, inline: true, fx: 'shake', shatter: SMASH, rows: [{ text: 'Step away,', size: 64, rot: -2 }, { text: 'and I', size: 64 }, { text: '*lock* it.', size: 140, rot: 4 }] },
  { at: PUSH_IN, out: 99, y: 410, fx: 'carried', id: 'nothing', hide: [PUSH_FREE, 99], rows: [{ text: 'Nothing leaves', size: 72, rot: 2 }, { text: 'your *Mac.*', size: 170, rot: -2 }] },
  { at: PUSH_FREE, out: B(19.3), y: 410, fx: 'carried', id: 'free', rows: [{ text: 'Free and', size: 72, rot: -2 }, { text: 'open *source.*', size: 160, rot: 2 }] },
  { at: B(20) - 0.1, out: 99, y: 560, fx: 'drop', rows: [{ text: "Know who's", size: 90, rot: -2 }, { text: '*looking.*', size: 190, rot: -2 }] },
];

// The flat Mac (the site's Guard demo), 8.8–16.8 s; its own clock is driven from film time.
// Cropped to the screen (the scene's x 0–880), so the demo's "someone behind you" figure stays out of frame.
const MAC = { x: 1300, top: 320, w: 1000 }; // screen on the right; byaku sits big on the left
function Mac({ t }: { t: number }) {
  if (t < 8.7 || t > B(3.7)) return null;
  const inn = sp(t, 8.8, 20, 140), out = ramp(t, B(3.1), B(3.6));
    // Iris starts exactly on the drop and is full after its real 280 ms edge-in (scene frames 55 → 63)
  const frame = interpolate(t, [8.8, 9.3, DROP - 0.04, DROP - 1 / FPS, DROP + 0.24, 16.8], [0, 15, 54, 55, 63, 120], { extrapolateRight: 'clamp' });
  const k = MAC.w / 880;
  return (
    <div style={{ position: 'absolute', left: MAC.x - MAC.w / 2, top: MAC.top, width: MAC.w, height: 550 * k, overflow: 'hidden', borderRadius: 16 * k, opacity: clamp(inn * 1.4) * (1 - out), scale: `${lerp(inn, 0.92, 1) * lerp(out, 1, 0.96)}`, filter: `blur(${out * 8}px)`, translate: `0 ${(1 - inn) * 60}px` }}>
      <div style={{ width: 1080 * k, height: 550 * k }}><Scene frame={frame} mode="iris" scenario="guard" /></div>
    </div>
  );
}

/** Mad mode: manga focus lines rushing at the mascot, redrawn on twos so they flicker like hand-drawn ones. */
function FocusLines({ t, on, color }: { t: number; on: number; color: string }) {
  if (on <= 0) return null;
  const seed = Math.floor(t * 15); // new set every 2 frames
  const rnd = (i: number) => { const x = Math.sin(i * 127.1 + seed * 311.7) * 43758.5453; return x - Math.floor(x); };
  const N = 110, cx = 960, cy = 630;
  return (
    <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0, opacity: on }}>
      {Array.from({ length: N }, (_, i) => {
        const a = (i / N) * Math.PI * 2 + rnd(i) * 0.05;
        const r0 = lerp(on, 1400, 420 + rnd(i + 99) * 160), w = 2 + rnd(i + 7) * 9;
        const ux = Math.cos(a), uy = Math.sin(a), px = -uy * w, py = ux * w;
        return <path key={i} d={`M${cx + ux * r0} ${cy + uy * r0}L${cx + ux * 1500 + px} ${cy + uy * 1500 + py}L${cx + ux * 1500 - px} ${cy + uy * 1500 - py}Z`} fill={color} opacity={0.55 + rnd(i + 3) * 0.45} />;
      })}
    </svg>
  );
}

/** The anime anger vein (four bulging arcs) that pops beside the mascot and throbs. */
function Vein({ x, y, size, p, t, color }: { x: number; y: number; size: number; p: number; t: number; color: string }) {
  if (p <= 0.01) return null;
  const throb = 1 + 0.12 * Math.max(0, Math.sin(t * 18));
  const arc = 'M3 9Q9 9 9 3';
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} style={{ position: 'absolute', left: x - size / 2, top: y - size / 2, scale: `${p * throb}`, overflow: 'visible' }}>
      {[0, 90, 180, 270].map((r) => <path key={r} d={arc} transform={`rotate(${r} 12 12)`} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" />)}
    </svg>
  );
}

// A full-width menu bar that the mascot docks into (3.2–8.8 s).
function MenuBar({ t }: { t: number }) {
  const C = usePal();
  const inn = sp(t, 2.85, 22, 170), out = ramp(t, 8.5, 8.8);
  if (t < 2.75 || t > 8.9) return null;
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: 64, background: C.surface, borderBottom: `1px solid ${C.line}`, translate: `0 ${(1 - inn) * -70 - out * 70}px`, display: 'flex', alignItems: 'center', padding: '0 36px', fontFamily: 'Beacon', fontSize: 26, color: C.mute, gap: 40 }}>
      <span style={{ color: C.ink, fontWeight: 600 }}>Finder</span><span>File</span><span>Edit</span><span>View</span><span>Window</span>
      <span style={{ marginLeft: 'auto', color: C.ink }}>Thu 14:07</span>
      {t > MB.click && t < MB.close && <span style={{ position: 'absolute', left: 1640 - 36, top: 7, width: 72, height: 50, borderRadius: 10, background: C.line }} />}
    </div>
  );
}

/** Where the "peeks" word sits in the frame (the text close-up frames it). */
const PEEKS_AT = { x: 882, y: 160 };
const shot = (z: number, fx: number, fy: number, tx: number, ty: number) => `translate(${tx - fx * z}px, ${ty - fy * z}px) scale(${z})`;

/** The stare: a hard cut to byaku's close-up, a hard cut to the "peeks" close-up, then one smooth pull-out to the whole frame. */
function camera(t: number, m: { x: number; y: number }) {
  if (t >= CUT1 && t < CUT2) return shot(2.5 + 0.12 * ramp(t, CUT1, CUT2), m.x, m.y - 10, 820, 560); // slow push while held
  return textCamera(t);
}
/** The text close-up and its pull-out apply to the type and the picture alike, so the frame opens up as one image. */
function textCamera(t: number) {
  if (t < CUT2 || t >= ZOUT_END) return 'none';
  const e = ease(ramp(t, ZOUT_START, ZOUT_END));
  const z = lerp(e, 2.6 + 0.08 * ramp(t, CUT2, ZOUT_START), 1);
  return shot(z, PEEKS_AT.x, PEEKS_AT.y, lerp(e, 960, PEEKS_AT.x), lerp(e, 560, PEEKS_AT.y));
}
/** Vignette strength: full in both close-ups, gone by the end of the pull-out. */
const vignette = (t: number) => (t >= CUT1 && t < ZOUT_END ? 1 - ease(ramp(t, ZOUT_START, ZOUT_END)) : 0);

/** The menu-bar beat: a cursor clicks byaku's icon, its real menu (Sources/Byaku/App.swift) drops open, the cursor hovers down it. */
const MB = { click: 4.05, close: 5.85 };
const MENU = { x: 1380, y: 70, w: 520, row: 50, sep: 18 };
type MenuRow = { t: string; key?: string; on?: boolean; sub?: string; dim?: boolean } | null; // null = separator
const MENU_ROWS: MenuRow[] = [
  { t: 'Guarding. Camera is on', dim: true }, null,
  { t: 'Guard', key: '⌘G', on: true }, { t: 'Away', key: '⌘A' }, null,
  { t: 'Alarm sound', sub: 'Siren' }, null,
  { t: 'Mode', sub: 'Iris' }, { t: 'Banner', on: true }, { t: 'Sound', on: true }, null,
  { t: 'Set up face again…', key: '⌘E' }, { t: 'Delete face data' }, null,
  { t: 'Quit byaku', key: '⌘Q' },
];
/** y (top) of each row inside the menu. */
const MENU_Y = MENU_ROWS.reduce<number[]>((a, r, i) => [...a, (a[i - 1] ?? 8) + (i ? (MENU_ROWS[i - 1] ? MENU.row : MENU.sep) : 0)], []);
const rowMid = (i: number) => MENU.y + MENU_Y[i] + MENU.row / 2;
/** Cursor stops: [time, x, y]. It glides up to the icon, parks, clicks, then hovers down Guard → Away → Mode. */
const CURSOR: [number, number, number][] = [[3.3, 1980, 760], [3.85, 1648, 40], [MB.click + 0.15, 1648, 40], [4.65, 1560, rowMid(2)], [5.05, 1580, rowMid(3)], [5.45, 1600, rowMid(7)], [6.1, 1990, 820]];

function cursorAt(t: number) {
  let [, x, y] = CURSOR[0];
  for (let i = 1; i < CURSOR.length; i++) {
    const [t1, x1, y1] = CURSOR[i], t0 = CURSOR[i - 1][0];
    const p = clamp((t - t0) / (t1 - t0) * 1.6); // land early, then park: entries decelerate
    const e = 1 - (1 - p) ** 3;
    x = lerp(e, x, x1); y = lerp(e, y, y1);
  }
  return { x, y };
}

function Cursor({ t }: { t: number }) {
  if (t < CURSOR[0][0] || t > CURSOR[CURSOR.length - 1][0]) return null;
  const { x, y } = cursorAt(t);
  const press = t > MB.click - 0.04 && t < MB.click + 0.08 ? 0.86 : 1; // the press squashes 2-3 frames
  return (
    <svg viewBox="0 0 24 24" width={44} height={44} style={{ position: 'absolute', left: x - 6, top: y - 3, scale: `${press}`, transformOrigin: '6px 3px', overflow: 'visible' }}>
      <path d="M5 2.5v17.2l4.3-4.1 2.8 6.4 3-1.3-2.8-6.3h6z" fill="#0E0D12" stroke="#FFFFFF" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}

function ByakuMenu({ t }: { t: number }) {
  const C = usePal();
  if (t < MB.click || t > MB.close + 0.2) return null;
  const k = sp(t, MB.click + 0.02, 22, 320), o = ramp(t, MB.close, MB.close + 0.18);
  const cur = cursorAt(t);
  const h = MENU_Y[MENU_Y.length - 1] + MENU.row + 8;
  return (
    <div style={{ position: 'absolute', left: MENU.x, top: MENU.y, width: MENU.w, height: h, borderRadius: 14, background: C.surface, border: `1px solid ${C.line}`,
      boxShadow: '0 18px 50px rgba(14,13,18,0.16)', opacity: clamp(k * 2) * (1 - o), scale: `${lerp(k, 0.96, 1)}`, transformOrigin: '260px 0', fontFamily: 'Beacon', fontSize: 25, color: C.ink }}>
      {MENU_ROWS.map((r, i) => {
        const y = MENU_Y[i];
        if (!r) return <div key={i} style={{ position: 'absolute', left: 16, right: 16, top: y + MENU.sep / 2, height: 1, background: C.line }} />;
        const inn = sp(t, MB.click + 0.05 + i * 0.025, 20, 260); // rows cascade in
        const hover = !r.dim && cur.y > MENU.y + y && cur.y < MENU.y + y + MENU.row && cur.x > MENU.x;
        return (
          <div key={i} style={{ position: 'absolute', left: 8, right: 8, top: y, height: MENU.row, borderRadius: 8, display: 'flex', alignItems: 'center', padding: '0 18px 0 44px',
            background: hover ? C.accent : 'transparent', color: hover ? '#FFFFFF' : r.dim ? C.mute : C.ink, opacity: clamp(inn * 1.5), translate: `0 ${(1 - inn) * -8}px` }}>
            {r.on && <span style={{ position: 'absolute', left: 16, fontSize: 22 }}>✓</span>}
            <span>{r.t}</span>
            <span style={{ marginLeft: 'auto', color: hover ? '#FFFFFF' : C.mute }}>{r.key ?? (r.sub ? `${r.sub}  ›` : '')}</span>
          </div>
        );
      })}
    </div>
  );
}

/** Charging aura: short streaks rising around byaku, redrawn on twos, denser as the charge builds. */
function Aura({ t, on, x, y, r, color }: { t: number; on: number; x: number; y: number; r: number; color: string }) {
  if (on <= 0) return null;
  const seed = Math.floor(t * 15);
  const rnd = (i: number) => { const h = Math.sin(i * 91.7 + seed * 47.3) * 43758.5453; return h - Math.floor(h); };
  const n = Math.round(8 + on * 18);
  return (
    <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0 }}>
      {Array.from({ length: n }, (_, i) => {
        const a = rnd(i) * Math.PI * 2, d = r * (1.1 + rnd(i + 5) * 0.5);
        const px = x + Math.cos(a) * d, py = y + Math.sin(a) * d * 0.9, len = 30 + rnd(i + 9) * 70 * on;
        return <line key={i} x1={px} y1={py} x2={px} y2={py - len} stroke={color} strokeWidth={2 + rnd(i + 2) * 3} strokeLinecap="round" opacity={0.35 + on * 0.6} />;
      })}
    </svg>
  );
}

const HITS = hitTimes(LINES);
/** Synthesized SFX (video/scripts/sfx.py): [file, film seconds, volume]. */
const SFX: [string, number, number][] = [
  ['click', MB.click, 0.6], ...HITS.map((h): [string, number, number] => ['slam', h, 0.55]), ['rumble', B(5.6), 0.45],
  ['crash', SMASH, 0.7], ['whoosh', ROLL_AWAY, 0.5], ['ting', B(24), 0.35],
];

export function Film({ theme = 'dark' }: { theme?: keyof typeof PALETTES }) {
  const C = PALETTES[theme];
  const VARS = { '--bg': C.bg, '--surface': C.surface, '--line': C.line, '--mute': C.mute, '--ink': C.ink, '--accent': C.accent } as React.CSSProperties;
  const t = story(useCurrentFrame() / FPS);
  // camera kick: a short decaying jolt on every hit word
  const kick = HITS.reduce((a, h) => a + (t > h && t < h + 0.25 ? Math.sin((t - h) * 90) * 9 * (1 - (t - h) / 0.25) : 0), 0);
  // Mascot path: pop in on the bass → dock in the menu bar → come down to watch → big on the left → centre → end card.
  const m = track(t, { x: 960, y: 1300, s: 340 }, [
    { at: POP - 0.2, to: { y: 420 }, d: 11, k: 160 },
    { at: 2.85, to: { x: 1640, y: 32, s: 46 }, d: 18, k: 140 },
    { at: 6.35, to: { x: 960, y: 420, s: 300 }, d: 13, k: 150 },
    { at: 8.85, to: { x: 430, y: 620, s: 400 }, d: 15, k: 150 },
    { at: B(3.5), to: { x: 960, y: 630, s: 260 }, d: 14, k: 150 }, // steps to the middle of the doorway
    { at: B(8), to: { y: 250, s: 600 }, d: 12, k: 320 }, // BLOWS UP and rockets up through the line, on the downbeat
    { at: B(8.6), to: { y: 580 }, d: 14, k: 160 }, // drops back to rage in the middle
    { at: ROLL_AWAY, to: { x: -1000, y: PUSH_L.y, s: 260 }, d: 18, k: 120 }, // deflates and rolls off to the left…
    { at: PUSH_IN, to: { x: REST_L }, d: 20, k: 120 }, // …shoves "Nothing leaves your Mac." in…
    { at: PUSH_OUT, to: { x: 3100 }, d: 22, k: 90 }, // …holds, then shoves it out to the right…
    { at: PUSH_FREE, to: { x: REST_R }, d: 20, k: 120 }, // …and comes straight back, shoving "Free and open source." in from the right
    { at: B(19.6), to: { x: 960, y: 380, s: 250 }, d: 16, k: 150 },
  ]);
  const pose = poseAt(t, [
    [0, 'idle'], [POP, 'happy'], [HOOK_HIT, 'joy'], [2.9, 'raised'], [MB.click, 'joy'], [MB.click + 0.5, 'happy'], [6.4, 'focus'],
    [9.5, 'look'], [STARE + 0.15, 'sideEye'], [DROP, 'frown'], [B(1.5), 'happy'], [B(3.5), 'calm'], [CHARGE, 'focus'], [B(6.5), 'frown'], [B(7.95), 'mad'],
    [B(11), 'calm'], [B(13.5), 'happy'], [B(16), 'joy'], [B(17.5), 'happy'], [B(19.6), 'idle'], [B(24), 'wink'], [B(25.3), 'happy'],
  ]);
  const b = blink(t, [2.3, 5.6, 7.6, B(14), B(21.5)]);
  pose.ly += b; pose.ry += b;
  // squash: land on arrival, bob on the beat while vibing; the puff-up grows it uniformly (never stretched)
  const land = (at: number, amt: number) => (t > at ? amt * Math.exp(-(t - at) * 9) * Math.cos((t - at) * 22) : 0);
  const vibe = clamp(ramp(t, POP + 0.3, POP + 0.6) - ramp(t, 2.7, 2.8)) + clamp(ramp(t, B(12), B(12.3)) - ramp(t, B(19.4), B(19.6))) + ramp(t, B(25.3), B(25.6));
  const puff = sp(t, DROP, 9, 260) * (1 - sp(t, B(2.4), 20, 160)) + sp(t, B(8), 9, 260) * (1 - sp(t, B(11), 20, 160));
  // side-eye: the whole ring leans toward the screen; the wink tilts it the other way
  const tilt = lerp(ease(ramp(t, STARE, CUT1)) * (t < DROP ? 1 : 0), 0, 14) + lerp(sp(t, B(24), 12, 200) * (1 - sp(t, B(25.3), 16, 160)), 0, -8);
  // rolling like a wheel; the reference switches only while byaku is off-screen, so it always comes to rest upright
  const rollRef = t < ROLL_AWAY || t >= B(19.6) ? null : t < PUSH_IN ? 960 : t < PUSH_FREE ? REST_L : REST_R;
  const roll = rollRef === null ? 0 : ((m.x - rollRef) / (m.s / 2)) * (180 / Math.PI);
  // mad mode: a gathering breath, then it blows up on the B(8) downbeat, trembles with rage, and deflates at B(11)
  const mad = ramp(t, B(7.95), B(8.15)) * (1 - ramp(t, B(10.6), B(11)));
  // charging: crouches lower and trembles harder and faster until the blow-up
  const charge = t >= CHARGE && t < B(8) ? ramp(t, CHARGE, B(8)) : 0;
  const shake = mad * (Math.sin(t * 83) * 7 + Math.sin(t * 131) * 4) + charge * (Math.sin(t * (60 + 60 * charge)) * 6 + Math.sin(t * 149) * 3) * charge;
  const breath = -0.14 * charge * charge; // crouch: squash down before the blow-up
  const squash = land(POP, 0.28) + land(6.75, 0.22) + land(9.2, 0.2) + land(B(3.9), 0.22) + land(MB.click, 0.25) + land(PUSH_IN + 0.55, 0.12) + land(PUSH_FREE + 0.55, 0.12) + bob(t, vibe) - breath;
  const vig = vignette(t);
  return (
    <PalCtx.Provider value={C}>
    <AbsoluteFill style={{ background: C.bg, ...VARS }}>
    <Audio src={staticFile('audio/ez4u.mp3')} startFrom={Math.round(TRACK_IN * FPS)} volume={(f) => 1 - ramp(f / FPS, DURATION - 0.25, DURATION)} />
    {SFX.map(([f, at, v], i) => (
      <Sequence key={i} from={Math.round(at * FPS)} layout="none"><Audio src={staticFile(`audio/sfx/${f}.wav`)} volume={v} /></Sequence>
    ))}
    <AbsoluteFill style={{ translate: `${kick * 0.6}px ${kick}px` }}>
    {/* camera layer: the close-up zooms this, the type stays in screen space */}
    <AbsoluteFill style={{ transformOrigin: '0 0', transform: camera(t, m) }}>
      <Mac t={t} />
      <FocusLines t={t} on={mad} color={C.ink} />
      <Aura t={t} on={charge} x={m.x} y={m.y} r={m.s / 2} color={C.ink} />
      <MenuBar t={t} />
      <Mascot x={m.x + shake} y={m.y + shake * 0.4} size={m.s * (1 + puff * 0.18)} pose={pose} squash={squash} tilt={tilt + roll} color={t > 2.95 && t < 6.4 ? C.ink : C.accent} />
      <ByakuMenu t={t} />
      <Cursor t={t} />
      <Vein x={m.x + m.s * 0.42 + shake} y={m.y - m.s * 0.5} size={m.s * 0.2} p={sp(t, B(8.3), 8, 320) * (1 - ramp(t, B(10.4), B(10.8)))} t={t} color={C.accent} />
    </AbsoluteFill>
      <AbsoluteFill style={{ transformOrigin: '0 0', transform: textCamera(t) }}>
        {LINES.map((l, i) => <Words key={i} t={t} l={l} off={l.id === 'menubar' ? [-330, 0] : l.id === 'nothing' ? [m.x - PUSH_L.x, 0] : l.id === 'free' ? [m.x - PUSH_R.x, 0] : [0, 0]} />)}
      </AbsoluteFill>
      {vig > 0 && <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 50% 50%, transparent 45%, rgba(14,13,18,0.42) 100%)', opacity: vig }} />}
      {t > B(22) && (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 885, textAlign: 'center', fontFamily: 'Beacon', fontSize: 38, color: C.mute, opacity: ramp(t, B(22), B(22.4)), translate: `0 ${(1 - sp(t, B(22), 20, 180)) * 20}px` }}>
          <span style={{ fontFamily: 'Rondel', fontWeight: 500, color: C.ink, marginRight: 22 }}>byaku</span>for your Mac
        </div>
      )}
      <Sfx t={t} at={HOOK_HIT} out={2.5} text="ドン" x={1440} y={610} size={110} rot={10} />
      <Sfx t={t} at={CUT1 + 0.05} out={CUT2 - 0.27} text="じー" x={1330} y={230} size={150} rot={-6} />
      <Sfx t={t} at={B(5.6)} out={B(10.7)} text="ゴゴゴ" x={190} y={250} size={130} rot={-6} shake={4} />
      <Sfx t={t} at={B(6.2)} out={B(10.7)} text="ゴゴゴ" x={1600} y={330} size={130} rot={6} shake={4} />
      <Sparkle t={t} at={B(24.05)} x={m.x + m.s * 0.5} y={m.y - m.s * 0.42} size={m.s * 0.28} color={C.accent} />
    </AbsoluteFill>
    </AbsoluteFill>
    </PalCtx.Provider>
  );
}
