#!/usr/bin/env node
// proofmark — install the nine design languages and their gate into an agent.
//
//   npx github:TbusOS/proofmark install
//
// Zero dependencies on purpose. The nine skills are markdown and need nothing
// to read; only the gate needs Node, Python and a browser, and paying for that
// download before the tool has printed a single line is a bad trade for the
// person who only wanted the design languages. `install --with-gate` asks for
// the heavy half explicitly.
//
// It will not overwrite a skill it did not install. A directory sitting at
// ~/.claude/skills/anthropic-design might be someone's own work or a link into
// their own library — replacing it silently to save one line of output is how a
// tool gets uninstalled for good.

import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, readlinkSync,
         rmSync, symlinkSync, writeFileSync, cpSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const MANIFEST = '.proofmark-installed.json';

const C = process.stdout.isTTY
  ? { dim: (s) => `\x1b[2m${s}\x1b[0m`, b: (s) => `\x1b[1m${s}\x1b[0m`,
      g: (s) => `\x1b[32m${s}\x1b[0m`, y: (s) => `\x1b[33m${s}\x1b[0m`,
      r: (s) => `\x1b[31m${s}\x1b[0m` }
  : { dim: (s) => s, b: (s) => s, g: (s) => s, y: (s) => s, r: (s) => s };

const HELP = `
${C.b('proofmark')} — nine design languages for coding agents, and a gate that
fails the output that does not match.

  npx github:TbusOS/proofmark <command> [flags]

Commands
  install        Put the skills, agents and commands where the agent looks.
  doctor         Report what is installed, what is missing, what is stale.
  hook           Wire the edit-triggered gate into Claude Code's settings.
  uninstall      Remove exactly what install put there, and nothing else.

Flags
  --with-gate    Also install the checking half (Node deps + Chromium, ~150MB).
  --copy         Copy instead of linking. Default outside a git checkout.
  --link         Link instead of copying. Default inside a git checkout.
  --force        Replace entries that are already there and are not ours.
  --dir=<path>   Agent config directory (default ~/.claude).
  --dry-run      Print what would happen, change nothing.

What gets installed
  12 skills   nine design languages + design-review / design-planner / design-evolve
   6 agents   the critics the review skill dispatches
   2 commands /design-loop and /design-distill
`;

function parseArgs(argv) {
  const out = { cmd: null, flags: {} };
  for (const a of argv) {
    if (a.startsWith('--dir=')) out.flags.dir = a.slice(6);
    else if (a === '--with-gate') out.flags.withGate = true;
    else if (a === '--copy') out.flags.mode = 'copy';
    else if (a === '--link') out.flags.mode = 'link';
    else if (a === '--force') out.flags.force = true;
    else if (a === '--dry-run') out.flags.dry = true;
    else if (a === '-h' || a === '--help') out.flags.help = true;
    else if (a.startsWith('-')) out.flags.bad = a;
    else if (!out.cmd) out.cmd = a;
  }
  return out;
}

// Everything this tool owns, so uninstall can be exact.
function inventory() {
  const skills = existsSync(join(ROOT, 'skills'))
    ? readdirSync(join(ROOT, 'skills')).filter((n) => !n.startsWith('.')).sort() : [];
  const agents = existsSync(join(ROOT, '.claude/agents'))
    ? readdirSync(join(ROOT, '.claude/agents')).filter((n) => n.endsWith('.md')).sort() : [];
  const commands = existsSync(join(ROOT, '.claude/commands'))
    ? readdirSync(join(ROOT, '.claude/commands')).filter((n) => n.endsWith('.md')).sort() : [];
  return [
    ...skills.map((n) => ({ kind: 'skill', name: n, from: join(ROOT, 'skills', n), to: ['skills', n] })),
    ...agents.map((n) => ({ kind: 'agent', name: n, from: join(ROOT, '.claude/agents', n), to: ['agents', n] })),
    ...commands.map((n) => ({ kind: 'command', name: n, from: join(ROOT, '.claude/commands', n), to: ['commands', n] })),
  ];
}

const isGitCheckout = () => existsSync(join(ROOT, '.git'));

function readManifest(dir) {
  const p = join(dir, MANIFEST);
  if (!existsSync(p)) return null;
  try { return JSON.parse(readFileSync(p, 'utf-8')); } catch { return null; }
}

// "Ours" means: this exact path is recorded in the manifest, or it is a symlink
// pointing inside a proofmark checkout. Anything else belongs to someone else.
function ownedBy(target, manifest) {
  if (manifest && (manifest.entries || []).some((e) => e.target === target)) return 'manifest';
  try {
    if (lstatSync(target).isSymbolicLink()) {
      const dest = readlinkSync(target);
      if (/(^|\/)proofmark(\/|$)/.test(dest)) return 'link';
    }
  } catch { /* not there, or unreadable */ }
  return null;
}

function describeExisting(target) {
  try {
    const st = lstatSync(target);
    if (st.isSymbolicLink()) return `link → ${readlinkSync(target).replace(homedir(), '~')}`;
    return st.isDirectory() ? 'a directory' : 'a file';
  } catch { return 'missing'; }
}

function cmdInstall(flags) {
  const dir = resolve(flags.dir || join(homedir(), '.claude'));
  const mode = flags.mode || (isGitCheckout() ? 'link' : 'copy');
  const items = inventory();
  if (!items.length) {
    console.error(C.r('nothing to install — run this from a proofmark checkout or via npx.'));
    process.exit(2);
  }

  console.log(`${C.b('proofmark')} → ${dir.replace(homedir(), '~')}`);
  console.log(C.dim(`  source ${ROOT.replace(homedir(), '~')}  ·  mode ${mode}${flags.dry ? '  ·  dry run' : ''}`));
  console.log('');

  const manifest = readManifest(dir);
  const done = [];
  const blocked = [];
  let replaced = 0;

  for (const it of items) {
    const target = join(dir, ...it.to);
    const owner = existsSync(target) || isDanglingLink(target) ? ownedBy(target, manifest) : 'free';
    if (owner === null && !flags.force) {
      blocked.push({ it, target });
      continue;
    }
    if (flags.dry) { done.push({ it, target, mode }); continue; }
    mkdirSync(dirname(target), { recursive: true });
    if (existsSync(target) || isDanglingLink(target)) { rmSync(target, { recursive: true, force: true }); replaced++; }
    if (mode === 'link') symlinkSync(it.from, target);
    else cpSync(it.from, target, { recursive: true });
    done.push({ it, target, mode });
  }

  const byKind = (k) => done.filter((d) => d.it.kind === k).length;
  console.log(`  ${C.g('✓')} ${byKind('skill')} skills, ${byKind('agent')} agents, ${byKind('command')} commands`);
  if (replaced) console.log(C.dim(`    ${replaced} existing entr${replaced === 1 ? 'y' : 'ies'} replaced`));

  if (blocked.length) {
    console.log('');
    console.log(C.y(`  ${blocked.length} left alone — something is already there and it is not ours:`));
    for (const b of blocked.slice(0, 14)) {
      console.log(`    · ${b.it.to.join('/')}  ${C.dim(`(${describeExisting(b.target)})`)}`);
    }
    if (blocked.length > 14) console.log(C.dim(`    … and ${blocked.length - 14} more`));
    console.log('');
    console.log('    Look at them, then re-run with --force to replace them,');
    console.log('    or with --dir=<other path> to install somewhere else.');
  }

  if (!flags.dry) {
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, MANIFEST), JSON.stringify({
      tool: 'proofmark', version: pkgVersion(), source: ROOT, mode,
      installedAt: new Date().toISOString(),
      entries: done.map((d) => ({ kind: d.it.kind, name: d.it.name, target: d.target })),
    }, null, 2) + '\n');
  }

  if (flags.withGate) installGate(flags);
  else {
    console.log('');
    console.log(C.dim('  The skills are markdown and need nothing else. The checking half'));
    console.log(C.dim('  (Node deps + Chromium, ~150MB) is separate:  proofmark install --with-gate'));
  }
  console.log('');
  console.log(`  ${C.b('Restart your agent')} so it picks up the new skills.`);
}

function isDanglingLink(p) {
  try { lstatSync(p); return true; } catch { return false; }
}

function installGate(flags) {
  console.log('');
  console.log(`  ${C.b('gate')} — installing Node dependencies and Chromium`);
  if (flags.dry) { console.log(C.dim('    [dry run] npm install && npx playwright install chromium')); return; }
  if (!isGitCheckout()) {
    console.log(C.y('    Skipped: the gate runs from a checkout, not from the npx cache,'));
    console.log('    because it writes screenshots and reads baselines next to the pages.');
    console.log('      git clone https://github.com/TbusOS/proofmark.git');
    console.log('      cd proofmark && npm run setup-gate');
    return;
  }
  for (const args of [['install', '--no-audit', '--no-fund'], ['exec', 'playwright', 'install', 'chromium']]) {
    const r = spawnSync('npm', args, { cwd: ROOT, stdio: 'inherit' });
    if (r.status !== 0) { console.error(C.r(`    npm ${args[0]} failed`)); process.exit(1); }
  }
  console.log(`    ${C.g('✓')} gate ready — try:  bin/design-review examples/looks-fine.html`);
}

function cmdDoctor(flags) {
  const dir = resolve(flags.dir || join(homedir(), '.claude'));
  console.log(`${C.b('proofmark doctor')}`);
  console.log(C.dim(`  source ${ROOT.replace(homedir(), '~')}  ·  agent dir ${dir.replace(homedir(), '~')}`));
  console.log('');

  console.log(C.b('  tools'));
  for (const [name, args, why] of [
    ['node', ['--version'], 'required by three of the five checks'],
    ['python3', ['--version'], 'required by verify.py'],
    ['jq', ['--version'], 'only needed to install the edit hook'],
  ]) {
    const r = spawnSync(name, args, { encoding: 'utf-8' });
    const v = r.status === 0 ? (r.stdout || r.stderr || '').trim().split('\n')[0] : null;
    console.log(v ? `    ${C.g('✓')} ${name.padEnd(8)} ${C.dim(v)}`
                  : `    ${C.y('–')} ${name.padEnd(8)} ${C.dim('not found · ' + why)}`);
  }

  console.log('');
  console.log(C.b('  gate dependencies'));
  for (const m of ['playwright', 'axe-core', 'pixelmatch', 'pngjs']) {
    const there = existsSync(join(ROOT, 'node_modules', m));
    console.log(there ? `    ${C.g('✓')} ${m}` : `    ${C.y('–')} ${m} ${C.dim('· npm run setup-gate')}`);
  }
  const cache = join(homedir(), 'Library/Caches/ms-playwright');
  const cacheLinux = join(homedir(), '.cache/ms-playwright');
  const browsers = [cache, cacheLinux].some((p) => existsSync(p) &&
    readdirSync(p).some((n) => n.startsWith('chromium')));
  console.log(browsers ? `    ${C.g('✓')} chromium` : `    ${C.y('–')} chromium ${C.dim('· npx playwright install chromium')}`);

  console.log('');
  console.log(C.b('  installed'));
  const manifest = readManifest(dir);
  const items = inventory();
  let ok = 0, missing = 0, foreign = 0;
  for (const it of items) {
    const target = join(dir, ...it.to);
    if (!existsSync(target) && !isDanglingLink(target)) { missing++; continue; }
    if (ownedBy(target, manifest)) ok++; else foreign++;
  }
  console.log(`    ${ok} ours, ${foreign} someone else's, ${missing} not installed  ${C.dim(`(of ${items.length})`)}`);
  if (manifest) console.log(C.dim(`    manifest: ${manifest.mode} from ${String(manifest.source).replace(homedir(), '~')}`));
  if (foreign) console.log(C.dim('    run `proofmark install` to see which ones and why they were left alone'));

  console.log('');
  console.log(C.b('  edit hook'));
  const settings = join(dir, 'settings.json');
  let wired = false;
  try {
    const raw = readFileSync(settings, 'utf-8');
    wired = /design-gate\/(post-edit|stop)\.sh/.test(raw);
  } catch { /* no settings file */ }
  console.log(wired ? `    ${C.g('✓')} wired into ${settings.replace(homedir(), '~')}`
                    : `    ${C.y('–')} not wired ${C.dim('· proofmark hook')}`);
}

function cmdHook(flags) {
  const script = join(ROOT, 'hooks/design-gate/install.sh');
  if (!existsSync(script)) { console.error(C.r('hooks/design-gate/install.sh is missing')); process.exit(2); }
  const args = flags.dry ? ['--dry-run'] : [];
  const r = spawnSync('bash', [script, ...args], { stdio: 'inherit' });
  process.exit(r.status ?? 1);
}

function cmdUninstall(flags) {
  const dir = resolve(flags.dir || join(homedir(), '.claude'));
  const manifest = readManifest(dir);
  if (!manifest) {
    console.log('nothing to remove — no proofmark manifest in ' + dir.replace(homedir(), '~'));
    console.log(C.dim('  (entries installed by hand are left alone on purpose)'));
    return;
  }
  let n = 0;
  for (const e of manifest.entries || []) {
    if (!existsSync(e.target) && !isDanglingLink(e.target)) continue;
    if (flags.dry) { console.log(C.dim(`  [dry run] rm ${e.target.replace(homedir(), '~')}`)); n++; continue; }
    rmSync(e.target, { recursive: true, force: true });
    n++;
  }
  if (!flags.dry) rmSync(join(dir, MANIFEST), { force: true });
  console.log(`${C.g('✓')} removed ${n} entr${n === 1 ? 'y' : 'ies'}${flags.dry ? ' (dry run)' : ''}`);
  console.log(C.dim('  The edit hook is separate:  hooks/design-gate/install.sh uninstall'));
}

function pkgVersion() {
  try { return JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf-8')).version; } catch { return '0'; }
}

const { cmd, flags } = parseArgs(process.argv.slice(2));
if (flags.bad) { console.error(`unknown flag ${flags.bad}`); process.exit(2); }
if (flags.help || !cmd) { console.log(HELP); process.exit(flags.help ? 0 : 2); }
switch (cmd) {
  case 'install': cmdInstall(flags); break;
  case 'doctor': cmdDoctor(flags); break;
  case 'hook': cmdHook(flags); break;
  case 'uninstall': cmdUninstall(flags); break;
  default:
    console.error(`unknown command: ${cmd}`);
    console.log(HELP);
    process.exit(2);
}
