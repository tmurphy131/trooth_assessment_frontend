// Run from the repo root:
//   firebase emulators:exec --only firestore --project demo-trooth "npm test --prefix test/firestore_rules"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;
const profile = (role) => ({ name: 'A', email: 'a@example.com', role, onboarded: true });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-trooth',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8085 },
  });
});
beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

const as = (uid) => env.authenticatedContext(uid).firestore();
const seed = (uid, data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', uid), data));

test('owner can create their profile as mentor or apprentice', async () => {
  await assertSucceeds(setDoc(doc(as('u1'), 'users/u1'), profile('mentor')));
  await assertSucceeds(setDoc(doc(as('u2'), 'users/u2'), profile('apprentice')));
});

test('create rejects other roles and missing role', async () => {
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), profile('admin')));
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), { name: 'A' }));
});

test('nobody can write or read another user’s profile', async () => {
  await seed('u2', profile('apprentice'));
  await assertFails(setDoc(doc(as('u1'), 'users/u2'), profile('mentor')));
  await assertFails(getDoc(doc(as('u1'), 'users/u2')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/u2')));
});

test('owner can read and update their profile but not change role', async () => {
  await seed('u1', profile('apprentice'));
  await assertSucceeds(getDoc(doc(as('u1'), 'users/u1')));
  await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { name: 'B' }));
  await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'mentor' }));
  // set() over an existing doc is an update too (signup re-run)
  await assertSucceeds(setDoc(doc(as('u1'), 'users/u1'), profile('apprentice')));
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), profile('mentor')));
});

test('legacy profile without a role may set one once', async () => {
  await seed('u1', { name: 'Legacy' });
  await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'admin' }));
  await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { role: 'mentor' }));
  await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'apprentice' }));
});

test('clients cannot delete profiles (backend handles deletion)', async () => {
  await seed('u1', profile('mentor'));
  await assertFails(deleteDoc(doc(as('u1'), 'users/u1')));
});

test('other collections stay closed', async () => {
  await assertFails(setDoc(doc(as('u1'), 'notes/x'), { a: 1 }));
});
