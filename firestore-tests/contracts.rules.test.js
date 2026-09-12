const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §17/§22/§39/§40: a contract is
// always born a Draft owned by its creator, only that creator may edit it
// (and only while it's still a Draft), and the numbering counter can only
// ever be advanced by exactly 1.

let testEnv;

const OWNER = 'contract-owner'; // contract.read + contract.create + contract.edit_own
const OTHER_EMPLOYEE = 'other-employee'; // same permissions, different uid
const NO_ACCESS = 'no-access';

const baseContractData = (overrides = {}) => ({
  contractNumber: 'CTR-2026-000001',
  status: 'DRAFT',
  version: 1,
  customerId: 'cust1',
  propertyId: 'prop1',
  sourceQuotationId: null,
  templateId: 'tmpl1',
  templateVersion: 1,
  clauses: [],
  createdBy: OWNER,
  ...overrides,
});

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
    const permissions = { 'contract.read': true, 'contract.create': true, 'contract.edit_own': true };
    await setDoc(doc(db, 'users', OWNER), {
      email: 'owner@example.com',
      role: 'employee',
      status: 'active',
      permissions,
    });
    await setDoc(doc(db, 'users', OTHER_EMPLOYEE), {
      email: 'other@example.com',
      role: 'employee',
      status: 'active',
      permissions,
    });
    await setDoc(doc(db, 'users', NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'contracts', 'existing-draft'), baseContractData());
    await setDoc(doc(db, 'counters', 'contracts_2026'), { count: 1 });
  });
});

describe('contracts/{contractId} rules', () => {
  it('a user with contract.read can read a contract', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('a user without contract.read cannot read a contract', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('contract.create can create a DRAFT with themself as createdBy', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(addDoc(collection(db, 'contracts'), baseContractData()));
  });

  it('cannot create a contract that is not already DRAFT', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(addDoc(collection(db, 'contracts'), baseContractData({ status: 'APPROVED' })));
  });

  it('cannot create a contract at a version other than 1', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(addDoc(collection(db, 'contracts'), baseContractData({ version: 2 })));
  });

  it('a user without contract.create cannot create a contract', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(addDoc(collection(db, 'contracts'), baseContractData({ createdBy: NO_ACCESS })));
  });

  it('the owner can edit their own Draft', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contracts', 'existing-draft'), { clauses: [{ id: 'c1', order: 1, title: 'T', content: 'C', isLocked: false }] })
    );
  });

  it('another employee cannot edit someone else\'s Draft', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { customerId: 'cust2' }));
  });

  it('the owner cannot change contractNumber, createdBy, or version on update', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { contractNumber: 'CTR-2026-999999' }));
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { createdBy: OTHER_EMPLOYEE }));
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { version: 2 }));
  });

  it('the owner cannot move status off DRAFT via a plain edit', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { status: 'PENDING_APPROVAL' }));
  });

  it('contracts cannot be deleted', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(deleteDoc(doc(db, 'contracts', 'existing-draft')));
  });
});

describe('counters/{counterId} rules', () => {
  it('cannot be read directly by a client', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(getDoc(doc(db, 'counters', 'contracts_2026')));
  });

  it('contract.create can advance the counter by exactly 1', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 2 }));
  });

  it('cannot jump the counter by more than 1', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 5 }));
  });

  it('a brand-new year counter can only be created starting at 1', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(doc(db, 'counters', 'contracts_2027'), { count: 1 }));
  });

  it('a user without contract.create cannot advance the counter', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 2 }));
  });
});
