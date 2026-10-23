import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const source = resolve(process.argv[2]);
const home = mkdtempSync(join(tmpdir(), 'pstack-install-'));
try {
  const link = join(home, 'source');
  symlinkSync(source, link);
  mkdirSync(join(home, '.config/t3-pstack'), {recursive: true});
  copyFileSync(new URL('../shared/pstack-models.md', import.meta.url), join(home, '.config/t3-pstack/models.md'));
  const env = {...process.env, HOME: home, XDG_CONFIG_HOME: join(home, '.config'), CODEX_HOME: join(home, '.codex'), CLAUDE_CONFIG_DIR: join(home, '.claude'), T3CODE_HOME: join(home, '.t3')};
  const run = () => JSON.parse(execFileSync(process.execPath, [join(source, 'tools/install.mjs'), 'install', '--source', link, '--json'], {env, encoding: 'utf8', timeout: 180000}));
  const first = run();
  assert.equal(first.failed, 0);
  assert.equal(first.warnings, 0);
  assert.equal(first.homes.length, 2);
  assert.ok(readFileSync(join(home, '.codex/config.toml'), 'utf8').includes(`source = "${link}"`), 'Codex must retain the stable source link');
  const second = run();
  assert.equal(second.failed, 0);
  assert.equal(second.warnings, 0);
  assert.deepEqual(second.homes.flatMap(({steps}) => steps), []);
  console.log('Fresh Claude and Codex installs pass; source link is stable; repeat install makes no changes.');
} finally {
  rmSync(home, {recursive: true, force: true});
}
