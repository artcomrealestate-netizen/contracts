const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §40: rules must enforce
// authentication, active status, and role — "request.auth != null" alone is
// not enough. Only the `users` collection exists in this phase.

let testEnv;

const ACTIVE_EMPLOYEE = 'employee-active';
const OTHER_EMPLOYEE = 'employee-other';
const DISABLED_EMPLOYEE = 'employee-disabled';
const ADMIN = 'admin-active';

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
    await setDoc(doc(db, 'users', ACTIVE_EMPLOYEE), {
      email: 'active@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'users', OTHER_EMPLOYEE), {
      email: 'other@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'users', DISABLED_EMPLOYEE), {
      email: 'disabled@example.com',
      role: 'employee',
      status: 'disabled',
      permissions: {},
    });
    await setDoc(doc(db, 'users', ADMIN), {
      email: 'admin@example.com',
      role: 'admin',
      status: 'active',
      permissions: {},
    });
  });
});

describe('users/{userId} rules', () => {
  it('an active user can read their own profile', async () => {
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', ACTIVE_EMPLOYEE)));
  });

  it('an employee cannot read another user\'s profile', async () => {
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'users', OTHER_EMPLOYEE)));
  });

  it('a disabled account cannot read even its own profile', async () => {
    const db = testEnv.authenticatedContext(DISABLED_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'users', DISABLED_EMPLOYEE)));
  });

  it('an unauthenticated request is denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users', ACTIVE_EMPLOYEE)));
  });

  it('an active admin can read any user profile', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', OTHER_EMPLOYEE)));
  });

  it('a user cannot grant themselves a role/status/permission change', async () => {
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ACTIVE_EMPLOYEE), { role: 'admin' })
    );
    await assertFails(
      updateDoc(doc(db, 'users', ACTIVE_EMPLOYEE), { status: 'active', permissions: { 'contract.approve': true } })
    );
  });

  it('a user can update their own non-privileged profile fields', async () => {
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', ACTIVE_EMPLOYEE), { displayName: 'New Name' })
    );
  });

  it('an admin can change another user\'s role/status/permissions', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', OTHER_EMPLOYEE), { status: 'suspended' })
    );
  });
});
