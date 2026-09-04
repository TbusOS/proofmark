# proofmark

[中文](README_zh.md)

**Nine design languages a coding agent can write in, and a gate that fails the output that does not match.**

Every design skill for a coding agent ships a prompt. This one ships the prompt and the thing that checks the prompt was obeyed.

Here is a page that passes the structural check, passes the rendered visual audit, and looks entirely normal in a browser:

```console
$ bin/design-review examples/looks-fine.html

━━ [1/4] verify.py (structural)
design-review verify: OK — 1 file(s) passed (auto-detected skill)

━━ [2/4] visual-audit.mjs (rendered + brand + italic + smell)
visual-audit: OK  (examples/looks-fine.html)

━━ [3/4] axe-audit.mjs (accessibility · axe-core)
axe-audit: 1 rule(s), 34 element(s)
  [error] color-contrast (serious) ×34 — Elements must meet minimum color contrast ratio thresholds
      .anth-hero > .anth-container > p > .lang-en
         Element has insufficient color contrast of 2.31 (foreground #a8a69c,
         background #faf9f5, font size 14.3pt, weight normal). Expected 4.5:1
      … and 33 more

✗ axe-audit found blocking violations — fix before continuing
$ echo $?
1
```

The only edit separating that file from a canonical reference page is two colour values, nudged until they stop clearing 4.5:1. Nothing about it looks wrong. That is the case a prompt cannot catch and a person reviewing at speed will wave through.

## The nine

Each is a complete design language: typography scale, colour tokens, layout rhythm, motion, diagram conventions, and a reference library of finished pages the generator is measured against.

| Skill | Voice | Canonical pages |
|---|---|---|
| `anthropic-design` | Warm editorial. Cream ground, serif body, orange accent | 10 |
| `apple-design` | Product-marketing minimalism. White, SF, statistics as headlines | 10 |
| `ember-design` | Handcraft warmth. Cream, chocolate, gold | 10 |
| `sage-design` | Nordic quiet. Cream, sage green, deep indigo | 10 |
| `atelier-design` | Warm-glass product UI. The one skill that draws an application, and it clicks | 6 |
| `glass-design` | Aurora glassmorphism. Deep navy, frosted panels, dual theme | 4 |
| `eclat-design` | Launch keynote on a matte cinematic stage | 3 |
| `lectern-design` | Boardroom briefing. Paper white, serif, data forward | 3 |
| `primer-design` | Technical explainer. Diagrams carry the argument | 3 |

Fifty-nine reference specimens in all, under `skills/*/references/canonical/`. They render standalone, and all 59 pass the gate, so a generator can be measured against them directly.

## The gate

`bin/design-review <page.html>` runs four checks in order and stops at the first failure.

| | What it decides |
|---|---|
| `verify.py` | Structure: placeholders, missing viewport, undefined classes, BEM modifiers without their base, unbalanced SVG, hero container width, hardcoded colours that already have a token |
| `visual-audit.mjs` | The rendered page: contrast, brand presence, diagram label sizes, orphan cards, SVG text legibility, and colour borrowed from another skill's palette |
| `axe-audit.mjs` | Accessibility, via axe-core. Four rules block: `color-contrast`, `link-name`, `aria-prohibited-attr`, `svg-img-alt` |
| `screenshot.mjs` | Full-page PNG, for the part a person still has to look at |

`--pixel` adds a fifth: rendered pixels against a committed baseline. It is opt-in because it fails on intentional change as readily as on regression.

Taste is judged separately. `design-critic` reviews a page as one reviewer; four specialists (composition, copy, illustration, brand) can review in parallel, weighted 25/25/20/30.

## What it refuses to judge

The gate answers one question: does this page obey the design language it claims to be written in. It says nothing about whether the page is any good, whether the content is correct, or whether a reader will follow the argument. Clearing every check is compatible with the page being worth throwing away.

Contrast ratios, class definitions and label sizes have numeric answers. Whether a layout earns its whitespace does not, and the attempts to mechanise it in earlier rounds produced false positives at a rate that made the check useless.

## How it stops repeating mistakes

`skills/design-review/references/known-bugs.md` holds 93 entries. Each one is a defect a reviewer caught once. `design-learner` turns a catch into a row in that file, plus a new check in `visual-audit.mjs` wherever the defect is mechanically detectable. Of the 93, the ones with a matching check no longer reach a reviewer.

## Install

```bash
git clone https://github.com/TbusOS/proofmark.git
cd proofmark
npm install          # playwright, axe-core, pixelmatch, pngjs
bin/design-review examples/looks-fine.html   # should exit 1
```

To use the skills with Claude Code, symlink them:

```bash
ln -s "$PWD/skills/anthropic-design" ~/.claude/skills/
ln -s "$PWD/skills/design-review"    ~/.claude/skills/
ln -s "$PWD/.claude/agents/design-critic.md" ~/.claude/agents/
```

The skills are plain markdown with no runtime dependency. The gate needs Node and Python 3.

## Upstream

These skills also live in [sky-skills](https://github.com/TbusOS/sky-skills) alongside kernel and document tooling. That copy is the source; this repository carries the design half on its own so it can be installed without the rest. `bin/sync-from-upstream.sh --check` reports any drift between the two.

MIT.
