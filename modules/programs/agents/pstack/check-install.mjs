import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const source = resolve(process.argv[2]);
const home = mkdtempSync(join(tmpdir(), 'pstack-install-'));
try {
  const link = join(home, 'source');
  symlinkSync(source, link);
  mkdirSync(join(home, '.config/t3-pstack'), {recursive: true});
  symlinkSync(new URL('../shared/pstack-models.md', import.meta.url), join(home, '.config/t3-pstack/models.md'));
  const userdata = join(home, '.t3/userdata');
  mkdirSync(userdata, {recursive: true});
  writeFileSync(join(userdata, 'settings.json'), JSON.stringify({providerInstances: {antigravity: {driver: 'antigravity'}}}));
  const env = {...process.env, HOME: home, XDG_CONFIG_HOME: join(home, '.config'), CODEX_HOME: join(home, '.codex'), CLAUDE_CONFIG_DIR: join(home, '.claude'), T3CODE_HOME: join(home, '.t3')};
  const run = () => JSON.parse(execFileSync(process.execPath, [join(source, 'tools/install.mjs'), 'install', '--source', link, '--json'], {env, encoding: 'utf8', timeout: 180000}));
  const first = run();
  assert.equal(first.failed, 0);
  assert.equal(first.warnings, 0);
  assert.deepEqual(first.homes.map(({harness}) => harness).sort(), ['antigravity', 'claude', 'codex']);
  assert.ok(readFileSync(join(home, '.codex/config.toml'), 'utf8').includes(`source = "${link}"`), 'Codex must retain the stable source link');
  const second = run();
  assert.equal(second.failed, 0);
  assert.equal(second.warnings, 0);
  assert.deepEqual(second.homes.flatMap(({steps}) => steps), []);
  const profile = createHash('sha256').update('antigravity').digest('hex');
  const stale = join(userdata, 'providers/antigravity', profile, 'config/plugins/t3-pstack/stale-file');
  const skill = join(userdata, 'providers/antigravity', profile, 'config/plugins/t3-pstack/skills/poteto-mode/SKILL.md');
  writeFileSync(stale, 'left by an older version');
  rmSync(skill);
  const repaired = run();
  assert.equal(repaired.failed, 0);
  assert.equal(repaired.warnings, 0);
  assert.throws(() => readFileSync(stale), {code: 'ENOENT'});
  assert.equal(readFileSync(skill, 'utf8'), readFileSync(join(source, 'plugins/pstack/skills/poteto-mode/SKILL.md'), 'utf8'));
  console.log('Claude Code, Codex, and Antigravity install checks pass. Repeat install makes no changes. Antigravity repair replaces the old copy.');
} finally {
  rmSync(home, {recursive: true, force: true});
}
