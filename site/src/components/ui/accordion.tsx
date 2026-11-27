import * as A from '@radix-ui/react-accordion';
import { cn } from '../../lib/cn';

export const Accordion = A.Root;
export const AccordionItem = ({ className, ...p }: A.AccordionItemProps) => <A.Item className={cn('acc-item', className)} {...p} />;
export const AccordionTrigger = ({ children, ...p }: A.AccordionTriggerProps) => (
  <A.Header className="m-0">
    <A.Trigger className="acc-trigger" {...p}>
      {children}
      <svg viewBox="0 0 14 14" aria-hidden="true"><path d="M1 7h12" /><path className="v" d="M7 1v12" /></svg>
    </A.Trigger>
  </A.Header>
);
export const AccordionContent = ({ children, ...p }: A.AccordionContentProps) => <A.Content className="acc-content" {...p}>{children}</A.Content>;
