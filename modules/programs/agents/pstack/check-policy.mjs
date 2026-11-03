import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const root = resolve(process.argv[2]);
const {parseSheet, checkSheet} = await import(pathToFileURL(`${root}/plugins/pstack/skills/setup-pstack/scripts/t3-sheet.mjs`));
const {roles, tiers: defaults} = JSON.parse(readFileSync(`${root}/plugins/pstack/models.json`, 'utf8'));
const sheet = parseSheet(readFileSync(new URL('../shared/pstack-models.md', import.meta.url), 'utf8'));
assert.deepEqual(checkSheet(sheet, {roles, defaults}), []);
for (const {role} of roles) assert.ok(sheet.some(({key}) => key === role), `Missing model policy for ${role}`);
assert.ok(checkSheet(parseSheet('arena runners: codex/gpt-6.1-sol, codex/gpt-6.1-sol'), {roles, defaults}).length > 0);
assert.ok(checkSheet(parseSheet('arena runners: unknown'), {roles, defaults}).length > 0);
console.log('Model policy passes. Every role has a line; malformed and duplicate targets fail.');
