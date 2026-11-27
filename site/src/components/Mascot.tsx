/** The symbol (design/brand/final/symbol-*.svg). Blades are the eyebrows; expressions are CSS transforms in global.css. */
export const RING = 'M58.875 32A26.875 26.875 0 1 1 5.125 32A26.875 26.875 0 1 1 58.875 32';
export const BLADE_L = 'M19.367 43.375A17 17 0 0 1 26.747 15.832A54.689 54.689 0 0 0 19.367 43.375Z';
export const BLADE_R = 'M42.466 18.604A17 17 0 0 1 48.495 36.113A104.397 104.397 0 0 0 42.466 18.604Z';

export function Mascot({ expr = 'idle', className = '' }: { expr?: string; className?: string }) {
  return (
    <svg className={`mascot e-${expr} ${className}`} viewBox="0 0 64 64" aria-hidden="true">
      <path d={RING} fill="none" stroke="currentColor" strokeWidth="2.25" />
      <g className="gz">
        <path className="b l" fill="currentColor" d={BLADE_L} />
        <path className="b r" fill="currentColor" d={BLADE_R} />
      </g>
    </svg>
  );
}
