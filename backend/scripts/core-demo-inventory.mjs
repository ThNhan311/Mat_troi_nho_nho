// Explicit fresh-only contract; the historic inventory still verifies exact published bytes.
import './enrollment-migration-inventory.mjs';
import {readFile} from 'node:fs/promises';import {createHash} from 'node:crypto';import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url),m=JSON.parse(await readFile(new URL('database/core-demo-candidate.json',root),'utf8'));
assert.equal(m.sourceInventory,'database/enrollment-integration-candidate.json');assert.equal(createHash('sha256').update(await readFile(new URL(m.sourceInventory,root))).digest('hex'),m.sourceInventorySha256);
assert.deepEqual(m.versions,[1,2,3,4,5,6,8,9,10,11,12,13]);assert.equal(m.profile,'core-demo');
for(const key of ['legacyV7Included','compatibilityCallbackIncluded','v14Included','targetUpgradeVerified'])assert.equal(m[key],false);
assert.equal(m.entitlementPeriodSource,'membership_paid_periods');console.log('Fresh Core demo pinned: no V7/V14/legacy callbacks; existing-target upgrade not verified');
