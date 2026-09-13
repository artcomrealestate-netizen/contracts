const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs } = require('firebase/firestore');

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

  it('a disabled account can still read its own profile (to see why it is blocked), but cannot update it', async () => {
    const db = testEnv.authenticatedContext(DISABLED_EMPLOYEE).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', DISABLED_EMPLOYEE)));
    await assertFails(updateDoc(doc(db, 'users', DISABLED_EMPLOYEE), { displayName: 'x' }));
  });

  it('a disabled account still cannot read another user\'s profile', async () => {
    const db = testEnv.authenticatedContext(DISABLED_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'users', OTHER_EMPLOYEE)));
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

// Self-signup (allow create on users/{userId}): a newly signed-in user with
// no Firestore profile yet may create exactly one powerless starting
// document for themselves; approving/rejecting it is still an admin-only
// `allow write` (covered above), not a separate rule.
describe('self-signup create rule', () => {
  const NEW_SIGNUP = 'new-signup-uid';

  const pendingProfile = (overrides = {}) => ({
    email: 'new@example.com',
    displayName: 'New User',
    role: 'employee',
    status: 'pending',
    permissions: {},
    ...overrides,
  });

  it('a signed-in user can create their own pending profile with empty permissions', async () => {
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertSucceeds(setDoc(doc(db, 'users', NEW_SIGNUP), pendingProfile()));
  });

  it('an unauthenticated request cannot self-signup', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'users', NEW_SIGNUP), pendingProfile()));
  });

  it('a user cannot create a profile for a different uid', async () => {
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertFails(setDoc(doc(db, 'users', OTHER_EMPLOYEE), pendingProfile()));
  });

  it('self-signup cannot set status to active', async () => {
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertFails(
      setDoc(doc(db, 'users', NEW_SIGNUP), pendingProfile({ status: 'active' }))
    );
  });

  it('self-signup cannot set role to admin', async () => {
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertFails(
      setDoc(doc(db, 'users', NEW_SIGNUP), pendingProfile({ role: 'admin' }))
    );
  });

  it('self-signup cannot pre-grant permissions', async () => {
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertFails(
      setDoc(
        doc(db, 'users', NEW_SIGNUP),
        pendingProfile({ permissions: { 'contract.approve': true } })
      )
    );
  });

  it('a pending account can read its own profile (needed for the "pending approval" message) but cannot update it', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', NEW_SIGNUP)));
    await assertFails(updateDoc(doc(db, 'users', NEW_SIGNUP), { displayName: 'Trying to edit' }));
  });

  it('a pending account still cannot read another user\'s profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(NEW_SIGNUP).firestore();
    await assertFails(getDoc(doc(db, 'users', OTHER_EMPLOYEE)));
  });

  it('a brand-new Auth account with no profile doc at all gets "not found", not permission-denied, on its own read', async () => {
    // Regression check for the bug live-testing caught: isActive()-gating a
    // self-read makes get() error-evaluate (and so deny) for a doc that
    // doesn't exist yet, which AuthController._loadActiveProfile can't tell
    // apart from a real permission error.
    const db = testEnv.authenticatedContext('uid-with-no-profile').firestore();
    const snap = await assertSucceeds(getDoc(doc(db, 'users', 'uid-with-no-profile')));
    if (snap.exists()) {
      throw new Error('expected no profile document to exist');
    }
  });

  it('an admin can approve a pending account', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', NEW_SIGNUP), {
        status: 'active',
        role: 'employee',
        permissions: { 'customer.read': true },
      })
    );
  });

  it('an admin can query the pending-users list (Pending Users screen)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    const snapshot = await assertSucceeds(
      getDocs(query(collection(db, 'users'), where('status', '==', 'pending')))
    );
    const ids = snapshot.docs.map((d) => d.id);
    if (!ids.includes(NEW_SIGNUP)) {
      throw new Error(`expected pending-users query to include ${NEW_SIGNUP}, got: ${ids}`);
    }
  });

  it('a non-admin cannot query the pending-users list', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertFails(getDocs(query(collection(db, 'users'), where('status', '==', 'pending'))));
  });

  it('an admin can reject a pending account by disabling it', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', NEW_SIGNUP), pendingProfile());
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', NEW_SIGNUP), { status: 'disabled' }));
  });
});
