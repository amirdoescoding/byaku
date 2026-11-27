import { interpolate, useCurrentFrame, Easing } from 'remotion';
import { BLADE_L, BLADE_R, RING } from '../components/Mascot';

export type Mode = 'whisper' | 'iris' | 'shade' | 'awaken';
export type Scenario = 'guard' | 'away';
export type SceneProps = { mode: Mode; scenario: Scenario };

export const FPS = 30;
export const DURATION = 180;
export const WIDTH = 1080;
export const HEIGHT = 550;
/** Frame shown as the static poster and under reduced motion: the stranger has been seen and the answer is up. */
export const POSTER_FRAME = 120;

const BANNER_LINES = ['Mind your screen.', 'Eyes on your screen.', 'Be aware.', 'Not your face.'];
const ease = Easing.out(Easing.cubic);
const ramp = (f: number, a: number, b: number, from = 0, to = 1) => interpolate(f, [a, b], [from, to], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease });

const Mark = ({ x, y, size, color }: { x: number; y: number; size: number; color: string }) => (
  <svg x={x} y={y} width={size} height={size} viewBox="0 0 64 64">
    <path d={RING} fill="none" stroke={color} strokeWidth="2.25" /><path d={BLADE_L} fill={color} /><path d={BLADE_R} fill={color} />
  </svg>
);

/**
 * Flat 2D Mac screen (sheet-demo.png) as a pure function of the frame. Colours come from the site tokens so it
 * follows light/dark; the lock screen is always dark, as on macOS.
 * Timeline (30 fps): 15-35 stranger arrives, 55 "seen", 150-170 answer and stranger leave.
 * Guard shows the mode's layers. Away adds siren rings at 55, then the lock screen at 95.
 */
export function Scene({ frame, mode, scenario }: SceneProps & { frame: number }) {
  const away = scenario === 'away';
  const f = frame % DURATION;
  const arrive = ramp(f, 15, 35) * (1 - ramp(f, 150, 168));
  const seen = ramp(f, 55, 63) * (1 - ramp(f, 150, 162)); // 280 ms edgeIn
  const lock = away ? ramp(f, 95, 107) * (1 - ramp(f, 160, 172)) : 0;
  const mist = !away && (mode === 'iris' || mode === 'awaken') ? seen : 0;
  const dim = !away && (mode === 'shade' || mode === 'awaken') ? seen * 0.4 : 0;
  const bannerOn = !away ? seen : 0;
  const line = BANNER_LINES[0];
  const font = 'Beacon, system-ui, sans-serif';
  const bScale = 0.96 + 0.04 * bannerOn;
  const grad = { t: [0, 0, 0, 1], b: [0, 1, 0, 0], l: [0, 0, 1, 0], r: [1, 0, 0, 0] } as const;
  const rect = { t: [0, 26, 880, 28], b: [0, 522, 880, 28], l: [0, 26, 44, 524], r: [836, 26, 44, 524] } as const;

  return (
    <svg width={WIDTH} height={HEIGHT} viewBox={`0 0 ${WIDTH} ${HEIGHT}`} style={{ display: 'block', width: '100%', height: '100%', overflow: 'visible' }} role="img"
      aria-label={away ? 'A Mac screen. Someone looks, the screen pulses, then the Mac locks.' : 'A Mac screen. When someone behind you looks, byaku answers on screen.'}>
      <defs>
        <clipPath id="demo-clip"><rect x="1" y="1" width="878" height="548" rx="15" /></clipPath>
        {(['t', 'b', 'l', 'r'] as const).map((k) => (
          <linearGradient key={k} id={`mist-${k}`} x1={grad[k][0]} y1={grad[k][1]} x2={grad[k][2]} y2={grad[k][3]}>
            <stop offset="0" stopColor="var(--accent)" stopOpacity=".75" /><stop offset="1" stopColor="var(--accent)" stopOpacity="0" />
          </linearGradient>
        ))}
      </defs>
      <g clipPath="url(#demo-clip)">
        <rect width="880" height="550" fill="var(--bg)" />
        <rect x="120" y="86" width="640" height="400" rx="10" fill="var(--surface)" stroke="var(--line)" />
        <line x1="120" x2="760" y1="126" y2="126" stroke="var(--line)" />
        <rect x="156" y="150" width="220" height="14" rx="7" fill="var(--ink)" opacity=".85" />
        {[[190, 520], [216, 470], [242, 500], [268, 360], [320, 510], [346, 440], [372, 300]].map(([y, w]) => (
          <rect key={y} x="156" y={y} width={w} height="10" rx="5" fill="var(--mute)" opacity=".28" />
        ))}
        {/* Iris mist, then Shade dim (dim sits below the menu bar) */}
        {(['t', 'b', 'l', 'r'] as const).map((k) => (
          <rect key={k} x={rect[k][0]} y={rect[k][1]} width={rect[k][2]} height={rect[k][3]} fill={`url(#mist-${k})`} opacity={mist} />
        ))}
        <rect x="0" y="26" width="880" height="524" fill="#000" opacity={dim} />
        <rect width="880" height="26" fill="var(--surface)" /><line x1="0" x2="880" y1="26" y2="26" stroke="var(--line)" />
        <text x="16" y="17.5" fontFamily={font} fontSize="12" fill="var(--mute)">Finder   File   Edit   View</text>
        <text x="864" y="17.5" textAnchor="end" fontFamily={font} fontSize="12" fill="var(--mute)">9:41</text>
        <Mark x={770} y={5} size={16} color="var(--ink)" />
        {/* banner: scales 0.96 -> 1 from the menu-bar icon */}
        <g opacity={bannerOn} transform={`translate(778 26) scale(${bScale}) translate(-778 -26)`}>
          <rect x="564" y="38" width="300" height="64" rx="12" fill="var(--surface)" stroke="var(--line)" />
          <Mark x={582} y={58} size={24} color="var(--accent)" />
          <text x="620" y="66" fontFamily={font} fontSize="14" fontWeight="600" fill="var(--ink)">Someone else is looking</text>
          <text x="620" y="86" fontFamily={font} fontSize="13" fill="var(--mute)">{line}</text>
        </g>
        {/* Away: siren pulse on the desktop, then the lock screen */}
        {away && (
          <g>
            {[0, 1, 2].map((i) => {
              const t = ((f - 55 - i * 10) / 30) % 1;
              const on = f >= 55 + i * 10 && f < 172;
              return <circle key={i} cx="440" cy="275" r={60 + 260 * Math.max(0, t)} fill="none" stroke="var(--accent)" strokeWidth="2" opacity={on ? (1 - Math.max(0, t)) * 0.8 * (1 - lock) : 0} />;
            })}
          </g>
        )}
        <g opacity={lock}>
          <rect width="880" height="550" fill="#0E0D12" />
          {[[60, 1], [98, 0.6], [136, 0.3]].map(([r, o]) => (
            <circle key={r} cx="440" cy="190" r={(r ?? 0) + 4 * Math.sin((f / 15) * Math.PI)} fill="none" stroke="#C8BFEF" strokeWidth="2" opacity={o} />
          ))}
          <rect x="418" y="187" width="44" height="34" rx="6" fill="#0E0D12" stroke="#ECEBF0" strokeWidth="2.5" />
          <path d="M426 187v-12a14 14 0 0 1 28 0v12" fill="none" stroke="#ECEBF0" strokeWidth="2.5" />
          <text x="440" y="372" textAnchor="middle" fontFamily={font} fontSize="56" fontWeight="300" fill="#ECEBF0">9:41</text>
          <text x="440" y="404" textAnchor="middle" fontFamily={font} fontSize="16" fill="#8F8C99">Locked. Someone else looked.</text>
          <rect x="350" y="440" width="180" height="36" rx="18" fill="none" stroke="#8F8C99" />
          <text x="440" y="463" textAnchor="middle" fontFamily={font} fontSize="14" fill="#8F8C99">Enter Password</text>
        </g>
      </g>
      <rect x=".5" y=".5" width="879" height="549" rx="16" fill="none" stroke="var(--line)" />
      {/* the stranger behind you */}
      <g fill="none" stroke="var(--mute)" strokeWidth="2" opacity={0.35 + 0.65 * arrive}>
        <circle cx="1000" cy="300" r="30" /><path d="M944 430a56 56 0 0 1 112 0" />
        <path d="M966 300H894" strokeDasharray="3 7" strokeLinecap="round" opacity={arrive} />
      </g>
      <text x="1000" y="456" textAnchor="middle" fontFamily={font} fontSize="13" fill="var(--mute)">Someone behind you</text>
    </svg>
  );
}

/** Remotion composition: same scene, driven by the Player's clock. */
export function GuardScene(props: SceneProps) {
  return <Scene frame={useCurrentFrame()} {...props} />;
}
