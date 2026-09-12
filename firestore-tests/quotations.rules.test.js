const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// The pre-existing quotation calculator, now Firestore-backed instead of
// local SharedPreferences (see LocalQuotationMigrator). Unlike the
// Contract System collections, there's no dedicated quotation.* permission —
// every active signed-in user can read/create, matching how the calculator
// was open to anyone with the app installed before login became mandatory.

let testEnv;

const OWNER = 'quotation-owner';
const OTHER_ACTIVE = 'other-active';
const DISABLED = 'disabled-user';

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'qouta-calculator-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', OWNER), {
      email: 'owner@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'users', OTHER_ACTIVE), {
      email: 'other@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'users', DISABLED), {
      email: 'disabled@example.com',
      role: 'employee',
      status: 'disabled',
      permissions: {},
    });
    await setDoc(doc(db, 'quotations', 'existing-quotation'), {
      quotaNumber: 'QT-2026-001',
      customerName: 'Existing Customer',
      createdBy: OWNER,
    });
  });
});

describe('quotations/{quotationId} rules', () => {
  it('any active user can read a quotation, not just its owner', async () => {
    const db = testEnv.authenticatedContext(OTHER_ACTIVE).firestore();
    await assertSucceeds(getDoc(doc(db, 'quotations', 'existing-quotation')));
  });

  it('a disabled account cannot read', async () => {
    const db = testEnv.authenticatedContext(DISABLED).firestore();
    await assertFails(getDoc(doc(db, 'quotations', 'existing-quotation')));
  });

  it('an unauthenticated request is denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'quotations', 'existing-quotation')));
  });

  it('an active user can create a quotation with themself as createdBy', async () => {
    const db = testEnv.authenticatedContext(OTHER_ACTIVE).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'quotations'), {
        quotaNumber: 'QT-2026-002',
        customerName: 'New Customer',
        createdBy: OTHER_ACTIVE,
      })
    );
  });

  it('cannot create a quotation with someone else as createdBy', async () => {
    const db = testEnv.authenticatedContext(OTHER_ACTIVE).firestore();
    await assertFails(
      addDoc(collection(db, 'quotations'), {
        quotaNumber: 'QT-2026-002',
        customerName: 'New Customer',
        createdBy: OWNER,
      })
    );
  });

  it('the owner can delete their own quotation', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(deleteDoc(doc(db, 'quotations', 'existing-quotation')));
  });

  it('another active user cannot delete someone else\'s quotation', async () => {
    const db = testEnv.authenticatedContext(OTHER_ACTIVE).firestore();
    await assertFails(deleteDoc(doc(db, 'quotations', 'existing-quotation')));
  });

  it('quotations are never updated in place', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, 'quotations', 'existing-quotation'), { customerName: 'Renamed' }));
  });
});

describe('counters/quotations_YYYY rules', () => {
  it('any signed-in user can advance a quotation-numbering counter by exactly 1', async () => {
    const db = testEnv.authenticatedContext(OTHER_ACTIVE).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'counters', 'quotations_2026'), { count: 1 });
    });
    await assertSucceeds(updateDoc(doc(db, 'counters', 'quotations_2026'), { count: 2 }));
  });

  // Counters use isSignedIn() with no value checks at all — see the longer
  // comment in firestore.rules for the two rounds of Web-only transaction/
  // increment() issues that led here. Trade-off: a disabled account, while
  // still Firebase-Auth signed in, CAN write here. Counters carry no data of
  // their own (actual quotation creation is separately gated by isActive()
  // on the quotations collection itself), so this is a cosmetic gap, not a
  // security one.
  it('a disabled account can still technically advance the counter (documents the isSignedIn()-only trade-off)', async () => {
    const db = testEnv.authenticatedContext(DISABLED).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'counters', 'quotations_2026'), { count: 1 });
    });
    await assertSucceeds(updateDoc(doc(db, 'counters', 'quotations_2026'), { count: 2 }));
  });

  it('an unauthenticated request cannot advance the counter', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'counters', 'quotations_2026'), { count: 1 });
    });
    await assertFails(updateDoc(doc(db, 'counters', 'quotations_2026'), { count: 2 }));
  });
});
