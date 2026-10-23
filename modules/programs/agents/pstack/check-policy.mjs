import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const root = resolve(process.argv[2]);
const {parseSheet, checkSheet} = await import(pathToFileURL(`${root}/plugins/pstack/skills/setup-pstack/scripts/t3-sheet.mjs`));
const {roles, tiers: defaults} = JSON.parse(readFileSync(`${root}/plugins/pstack/models.json`, 'utf8'));
const sheet = parseSheet(readFileSync(new URL('../shared/pstack-models.md', import.meta.url), 'utf8'));
assert.deepEqual(checkSheet(sheet, {roles, defaults}), []);
for (const {role, tier} of roles) {
  const row = sheet.find(({key}) => key === role);
  assert.ok(row, `Missing model policy for ${role}`);
  assert.equal(row.value, tier === 'panel' ? 'inherit-parent, inherit-parent, inherit-parent' : 'inherit-parent');
}
assert.ok(checkSheet(parseSheet('arena runners: codex/gpt-6.1-sol, codex/gpt-6.1-sol'), {roles, defaults}).length > 0);
assert.ok(checkSheet(parseSheet('arena runners: unknown'), {roles, defaults}).length > 0);
console.log('Model policy passes. All roles inherit; malformed and duplicate targets fail.');
