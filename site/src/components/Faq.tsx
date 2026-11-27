import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from './ui/accordion';

const FAQ: [string, string][] = [
  ['Is the camera always recording?', 'No. Each frame is checked in memory, then dropped. Nothing is saved or sent.'],
  ['Does it work in the dark?', "It needs enough light for the webcam to see a face. In a dark room it can't see anyone, so it can't warn you."],
  ['How much battery does it use?', "The target is ≤ ~1.5 W extra on Apple silicon while guarding. We'll share measured numbers after launch testing."],
  ["Why does macOS say it can't verify byaku?", "byaku isn't notarized yet, which needs a paid Apple developer account. Open System Settings → Privacy & Security, scroll down and click Open Anyway. You do this once per download. macOS asks for camera access again after each update."],
  ['How do I delete my face data?', 'Choose Delete face data in the byaku menu. It takes one click and has no undo. The next launch asks for a new scan.'],
];

export default function Faq() {
  return (
    <Accordion type="single" collapsible defaultValue="q3">
      {FAQ.map(([q, a], i) => (
        <AccordionItem key={q} value={`q${i}`}>
          <AccordionTrigger>{q}</AccordionTrigger>
          <AccordionContent><p>{a}</p></AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}
