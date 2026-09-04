---
skill: anthropic
waivers:
  - check: interaction:broken-anchor
    reason: the canonical pages link to sections a real product site would have, and a reference specimen has no product behind it
---

# Design decisions for proofmark

The canonical page in each skill is the yardstick for voice. This is the
yardstick for purpose.

## Who reads this

Someone deciding whether to hand a design language to a coding agent. They have
seen prompts that promise a house style and produce something else, so the
question they arrive with is not "is this pretty" but "what stops it drifting".

## What we will not do

Claim the gate judges quality. It judges whether a page obeys the language it
says it is written in. A page can clear every check and be worth throwing away,
and the pages here say so rather than implying otherwise.

Ship a number we have not measured. Every count on these pages is checked
against disk by `facts.mjs`, and a stale one fails the run.

## Where we deliberately differ from the skill

The landing page opens on a full-bleed orange edge rather than carrying the
signature colour in a hero illustration. The brand-presence check measures the
top 1440×500 band, and the CTA does not count toward it: `--anth-cta` is a
darker shade than `--anth-orange`, far enough away that the matcher misses it.
