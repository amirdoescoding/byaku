import { forwardRef } from 'react';
import { Player, type PlayerRef } from '@remotion/player';
import { useCurrentFrame } from 'remotion';
import { DURATION, FPS, HEIGHT, Scene, WIDTH, type SceneProps } from './GuardScene';

function GuardScene(props: SceneProps) {
  return <Scene frame={useCurrentFrame()} {...props} />;
}

/** The Remotion runtime lives only in this chunk; GuardDemo lazy-loads it when the demo scrolls into view. */
export default forwardRef<PlayerRef, SceneProps>(function LivePlayer(props, ref) {
  return (
    <Player ref={ref} component={GuardScene} inputProps={props} durationInFrames={DURATION} fps={FPS}
      compositionWidth={WIDTH} compositionHeight={HEIGHT} autoPlay loop initiallyMuted controls={false} acknowledgeRemotionLicense
      style={{ width: '100%', height: '100%' }} />
  );
});
