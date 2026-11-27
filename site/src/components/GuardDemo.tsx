import { lazy, Suspense, useEffect, useRef, useState } from 'react';
import type { PlayerRef } from '@remotion/player';
import { HEIGHT, POSTER_FRAME, Scene, WIDTH, type Mode, type Scenario } from '../remotion/GuardScene';
import { Segmented } from './ui/toggle-group';

// The Player chunk loads only once the demo scrolls into view; the controls hydrate early so keyboard users can reach them.
const LivePlayer = lazy(() => import('../remotion/LivePlayer'));

const MODES: [Mode, string, string][] = [
  ['whisper', 'Whisper', 'A banner. Nothing else.'],
  ['iris', 'Iris', 'Violet mist at the screen edges. The default.'],
  ['shade', 'Shade', 'The screen dims.'],
  ['awaken', 'Awaken', 'Dim, plus violet edges.'],
];

/** Static SVG poster on the server and first paint; the Remotion Player takes over once this island hydrates. */
export default function GuardDemo() {
  const [mode, setMode] = useState<Mode>('iris');
  const [scenario, setScenario] = useState<Scenario>('guard');
  const [live, setLive] = useState(false);
  const player = useRef<PlayerRef>(null);
  const box = useRef<HTMLDivElement>(null);
  const away = scenario === 'away';
  const cur = MODES.find((m) => m[0] === mode)!;

  useEffect(() => {
    if (matchMedia('(prefers-reduced-motion:reduce)').matches || !box.current) return; // reduced motion: keep the static poster
    const io = new IntersectionObserver(([e]) => { if (e?.isIntersecting) { setLive(true); io.disconnect(); } }, { rootMargin: '200px' });
    io.observe(box.current);
    return () => io.disconnect();
  }, []);

  /* pause the clock while the demo is off-screen or the tab is hidden */
  useEffect(() => {
    if (!live || !box.current) return;
    let visible = true;
    const sync = () => { const p = player.current; if (!p) return; visible && !document.hidden ? p.play() : p.pause(); };
    const io = new IntersectionObserver(([e]) => { visible = !!e?.isIntersecting; sync(); });
    io.observe(box.current);
    document.addEventListener('visibilitychange', sync);
    return () => { io.disconnect(); document.removeEventListener('visibilitychange', sync); };
  }, [live]);

  return (
    <div className="flex flex-col items-center">
      <div ref={box} className="w-full" style={{ aspectRatio: `${WIDTH} / ${HEIGHT}` }}>
        {live ? (
          <Suspense fallback={<Scene frame={POSTER_FRAME} mode={mode} scenario={scenario} />}>
          <LivePlayer ref={player} mode={mode} scenario={scenario} />
          </Suspense>
        ) : (
          <Scene frame={POSTER_FRAME} mode={mode} scenario={scenario} />
        )}
      </div>
      <div className="mt-9 flex flex-wrap items-center justify-center gap-x-6 gap-y-3">
        <Segmented label="Guard or Away" value={scenario} onValue={(v) => setScenario(v as Scenario)} items={['guard', 'away']} />
        <i className="hidden h-7 w-px bg-line sm:block" />
        <Segmented label="Mode" value={mode} onValue={(v) => setMode(v as Mode)} items={MODES.map((m) => m[0])} disabled={away} />
      </div>
      <p className="mt-5 text-center text-[16px] text-mute" aria-live="polite">
        {away ? "Away: any looker sounds the alarm and locks the Mac. Modes don't apply. This demo is silent." : <><b className="font-medium text-ink">{cur[1]}.</b> {cur[2]}</>}
      </p>
    </div>
  );
}
