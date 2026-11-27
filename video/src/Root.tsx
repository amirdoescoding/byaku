import { Composition } from 'remotion';
import { DURATION, Film, FPS } from './Film';

const S = { durationInFrames: Math.round(DURATION * FPS), fps: FPS, width: 1920, height: 1080 };
export const Root = () => (
  <>
    <Composition id="LaunchFilmDark" component={Film} defaultProps={{ theme: 'dark' as const }} {...S} />
    <Composition id="LaunchFilm" component={Film} defaultProps={{ theme: 'light' as const }} {...S} />
  </>
);
