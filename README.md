# proofmark

[中文](README_zh.md) · **[Live site and worked pages →](https://doc.tbusos.com/proofmark/)**

**Nine design languages a coding agent can write in, and a gate that fails the output that does not match.**

Every design skill for a coding agent ships a prompt. This one ships the prompt and the thing that checks the prompt was obeyed.

Here is a page that passes the structural check, passes the rendered visual audit, and looks entirely normal in a browser:

```console
$ bin/design-review examples/looks-fine.html

━━ [1/5] verify.py (structural)
design-review verify: OK — 1 file(s) passed (auto-detected skill)

━━ [2/5] visual-audit.mjs (rendered + brand + italic + smell)
visual-audit: OK  (examples/looks-fine.html)

━━ [3/5] axe-audit.mjs (accessibility · axe-core)
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

## Worked pages

Twenty-six pages built with these skills and shipped through the gate, under `demos/`.

| | |
|---|---|
| 9 diagram galleries | One per design language. Architecture, flow, hierarchy, timing waveforms, register bitfields, SoC blocks, call graphs, packet encapsulation. Every figure has a Copy SVG button. |
| 6 long-form articles | [How one bit is held](https://doc.tbusos.com/proofmark/demos/anthropic-design/one-bit.html), [How a chip is assembled](https://doc.tbusos.com/proofmark/demos/anthropic-design/packaging.html), [How a picture reaches a screen](https://doc.tbusos.com/proofmark/demos/anthropic-design/hardware.html), and three more. Figures carry the argument rather than decorate it. |
| 10 technical explainers | Short primer-design pages, one mechanism each: address maps, interconnects, protocol layers, register decoding, scheduler timing. |

## The gate

`bin/design-review <page.html>` runs five checks in order and stops at the first failure.

| | What it decides |
|---|---|
| `verify.py` | Structure: placeholders, missing viewport, undefined classes, BEM modifiers without their base, unbalanced SVG, hero container width, hardcoded colours that already have a token |
| `visual-audit.mjs` | The rendered page: contrast, brand presence, diagram label sizes, orphan cards, SVG text legibility, and colour borrowed from another skill's palette |
| `axe-audit.mjs` | Accessibility, via axe-core. Four rules block: `color-contrast`, `link-name`, `aria-prohibited-attr`, `svg-img-alt` |
| `interaction-audit.mjs` | The states a click reaches: console errors, axe violations that appear only after a click, dead controls, broken in-page anchors, content revealed onto other content. Every other check judges the first painted frame |
| `screenshot.mjs` | Full-page PNG, for the part a person still has to look at |

`--pixel` adds a sixth: rendered pixels against a committed baseline. It is opt-in because it fails on intentional change as readily as on regression.

Taste is judged separately. `design-critic` reviews a page as one reviewer; four specialists (composition, copy, illustration, brand) can review in parallel, weighted 25/25/20/30.

## Running it without remembering to

The full chain costs 17-25 seconds a page, because three of its five checks
drive a browser. Nobody pays that on every edit, so in practice it gets run just
before publishing, which is the worst moment to find a structural problem.

`verify.py` needs no browser and takes 0.05 seconds, so `hooks/design-gate/`
runs it on every HTML write and sends the findings straight back. It also
records the file's content hash; `bin/design-review` records the same hash when
all five checks pass, and at the end of a turn the hook names the files whose
current hash has no passing run. Editing a file changes its hash, so a receipt
expires on its own.

```bash
hooks/design-gate/install.sh --dry-run   # see what it would change
hooks/design-gate/install.sh             # write it into ~/.claude/settings.json
hooks/design-gate/selftest.sh            # 15 assertions
```

It blocks once and then clears. A hook that keeps refusing until a condition is
met refuses forever when that condition is unreachable, and the transcript
becomes the hook and the model repeating themselves.

## What it refuses to judge

The gate answers one question: does this page obey the design language it claims to be written in. It says nothing about whether the page is any good, whether the content is correct, or whether a reader will follow the argument. Clearing every check is compatible with the page being worth throwing away.

Contrast ratios, class definitions and label sizes have numeric answers. Whether a layout earns its whitespace does not, and the attempts to mechanise it in earlier rounds produced false positives at a rate that made the check useless.

## How it stops repeating mistakes

`skills/design-review/references/known-bugs.md` holds 93 entries. Each one is a defect a reviewer caught once. `design-learner` turns a catch into a row in that file, plus a new check in `visual-audit.mjs` wherever the defect is mechanically detectable. Of the 93, the ones with a matching check no longer reach a reviewer.

## Install

```bash
npx github:TbusOS/proofmark install
```

That puts the twelve skills, six critic agents and two commands where Claude
Code looks for them. It downloads no browser and installs no dependencies,
because the design languages are markdown and reading them needs nothing. About
13 seconds.

It will not replace anything it did not install. If a skill of the same name is
already there — your own work, or a link into your own library — it says so and
leaves it alone. `--force` overrides that, `--dir=<path>` installs elsewhere,
`--dry-run` shows what would happen.

```bash
npx github:TbusOS/proofmark doctor      # what is installed, what is missing
npx github:TbusOS/proofmark hook        # wire the edit-triggered gate
npx github:TbusOS/proofmark uninstall   # remove exactly what install put there
```

The checking half is a separate, heavier step: it needs Node, Python 3, and a
Chromium download of roughly 150MB, and it runs from a checkout because it
writes screenshots and reads baselines next to the pages.

```bash
git clone https://github.com/TbusOS/proofmark.git
cd proofmark && npm run setup-gate
bin/design-review examples/looks-fine.html   # exits 1, as it should
```

npm's `proofmark` name belongs to an unrelated package, so this ships as
`proofmark-design` if it is ever published. The `npx github:` form above needs
no publish and always runs `main`.

## Upstream

These skills also live in [sky-skills](https://github.com/TbusOS/sky-skills) alongside kernel and document tooling. That copy is the source; this repository carries the design half on its own so it can be installed without the rest. `bin/sync-from-upstream.sh --check` reports any drift between the two.

MIT.
