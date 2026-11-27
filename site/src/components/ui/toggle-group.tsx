import * as T from '@radix-ui/react-toggle-group';

type Props = { label: string; value: string; onValue: (v: string) => void; items: string[]; disabled?: boolean };
/** shadcn-style single-select ToggleGroup; ignores the deselect click so one item is always on. */
export function Segmented({ label, value, onValue, items, disabled }: Props) {
  return (
    <T.Root type="single" className="seg" aria-label={label} value={value} disabled={disabled} onValueChange={(v) => v && onValue(v)}>
      {items.map((i) => (
        <T.Item key={i} value={i}>{i}</T.Item>
      ))}
    </T.Root>
  );
}
