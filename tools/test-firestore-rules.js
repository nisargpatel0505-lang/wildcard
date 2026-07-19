const fs = require('fs');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp
} = require('firebase/firestore');

const projectId = 'wildcard-31d50';
const rules = fs.readFileSync('firestore.rules', 'utf8');

function save(uid, overrides = {}) {
  return {
    uid,
    schemaVersion: 1,
    appVersion: '6.9',
    accountJson: '{"coins":25}',
    runJson: '',
    clientSavedAt: Date.now(),
    updatedAt: serverTimestamp(),
    ...overrides
  };
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules }
  });
  let passed = 0;
  async function allowed(label, promise) {
    await assertSucceeds(promise); passed++; console.log('ALLOW', label);
  }
  async function denied(label, promise) {
    await assertFails(promise); passed++; console.log('DENY ', label);
  }

  try {
    const anon = env.unauthenticatedContext().firestore();
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const aliceSave = doc(alice, 'users/alice/saves/main');

    await denied('unauthenticated create', setDoc(doc(anon, 'users/alice/saves/main'), save('alice')));
    await denied('owner direct create (callable only)', setDoc(aliceSave, save('alice')));
    await denied('owner direct read (callable only)', getDoc(aliceSave));
    await denied('unauthenticated read', getDoc(doc(anon, 'users/alice/saves/main')));
    await denied('cross-user read', getDoc(doc(bob, 'users/alice/saves/main')));
    await denied('cross-user overwrite', setDoc(doc(bob, 'users/alice/saves/main'), save('bob')));
    await denied('embedded UID mismatch', setDoc(doc(alice, 'users/alice/saves/main'), save('mallory')));
    await denied('non-main save ID', setDoc(doc(alice, 'users/alice/saves/backup'), save('alice')));
    await denied('unspecified path', setDoc(doc(alice, 'public/test'), { ok: true }));
    await denied('unexpected field', setDoc(aliceSave, save('alice', { admin: true })));
    await denied('missing required field', setDoc(aliceSave, (() => { const d=save('alice'); delete d.runJson; return d; })()));
    await denied('wrong schema version', setDoc(aliceSave, save('alice', { schemaVersion: 2 })));
    await denied('wrong field type', setDoc(aliceSave, save('alice', { accountJson: { coins: 25 } })));
    await denied('oversized account JSON', setDoc(aliceSave, save('alice', { accountJson: 'x'.repeat(150001) })));
    await denied('negative client timestamp', setDoc(aliceSave, save('alice', { clientSavedAt: -1 })));
    await denied('client-authored updatedAt', setDoc(aliceSave, save('alice', { updatedAt: Timestamp.fromMillis(1) })));
    await denied('collection enumeration', getDocs(collection(alice, 'users/alice/saves')));
    await denied('owner direct update (callable only)', setDoc(aliceSave, save('alice', { accountJson: '{"coins":30}' })));
    await denied('owner direct delete (callable only)', deleteDoc(aliceSave));
    await denied('owner direct recreate (callable only)', setDoc(aliceSave, save('alice')));
    await denied('cross-user delete', deleteDoc(doc(bob, 'users/alice/saves/main')));
    await denied('direct daily score write', setDoc(doc(alice, 'dailyScores/2026-07-19/entries/alice'), { uid: 'alice', score: 999 }));
    await denied('direct board-name claim', setDoc(doc(alice, 'boardNames/ALICE'), { uid: 'alice' }));
    await denied('direct rate-ledger write', setDoc(doc(alice, 'dailyScoreRate/alice'), { count: 0 }));
    await denied('direct board-deletion queue write', setDoc(doc(alice, 'boardDeletionQueue/hash'), { pending: true }));
    await denied('direct billing-ledger read', getDoc(doc(alice, 'billingPurchases/tokenhash')));
    await denied('direct billing-ledger write', setDoc(doc(alice, 'billingPurchases/tokenhash'), { uid: 'alice', status: 'delivered' }));
    await denied('direct billing-account read', getDoc(doc(alice, 'billingAccounts/alice')));
    await denied('direct billing-adjustment write', setDoc(doc(alice, 'billingAdjustments/tokenhash'), { uid: 'alice', amount: 250 }));

    console.log(JSON.stringify({ tests: passed, failures: 0 }, null, 2));
  } finally {
    await env.cleanup();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
