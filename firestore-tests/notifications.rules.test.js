const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §32/§33: in-app notifications
// only (no FCM push in this phase — see AppNotification's doc comment).
// Exactly one of userId/audiencePermission is set per document: userId for
// one specific recipient (e.g. the contract owner on Approved/Rejected/
// Finalized), audiencePermission for a role broadcast (e.g. contract.approve
// on Submitted, since the owner submitting has no user.read to look up
// individual approvers).

let testEnv;

const RECIPIENT = 'recipient';
const APPROVER = 'approver'; // has contract.approve, qualifies for audiencePermission broadcasts
const OTHER_EMPLOYEE = 'other-employee'; // has notification.read but no contract.approve
const NO_ACCESS = 'no-access';

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
    await setDoc(doc(db, 'users', RECIPIENT), {
      email: 'recipient@example.com',
      role: 'employee',
      status: 'active',
      permissions: { 'notification.read': true },
    });
    await setDoc(doc(db, 'users', APPROVER), {
      email: 'approver@example.com',
      role: 'admin',
      status: 'active',
      permissions: { 'notification.read': true, 'contract.approve': true },
    });
    await setDoc(doc(db, 'users', OTHER_EMPLOYEE), {
      email: 'other@example.com',
      role: 'employee',
      status: 'active',
      permissions: { 'notification.read': true },
    });
    await setDoc(doc(db, 'users', NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'notifications', 'personal-notification'), {
      userId: RECIPIENT,
      audiencePermission: null,
      type: 'CONTRACT_APPROVED',
      title: 'Contract Approved',
      body: 'Contract CTR-2026-000001 was approved.',
      entityType: 'contract',
      entityId: 'contract1',
      isRead: false,
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'notifications', 'broadcast-notification'), {
      userId: null,
      audiencePermission: 'contract.approve',
      type: 'CONTRACT_SUBMITTED',
      title: 'Contract Submitted',
      body: 'Contract CTR-2026-000001 is awaiting your approval.',
      entityType: 'contract',
      entityId: 'contract1',
      isRead: false,
      createdAt: new Date(),
    });
  });
});

describe('notifications/{notificationId} — read', () => {
  it('the addressed recipient can read their own personal notification', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertSucceeds(getDoc(doc(db, 'notifications', 'personal-notification')));
  });

  it('another user cannot read someone else\'s personal notification', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'notifications', 'personal-notification')));
  });

  it('a user whose permissions qualify can read a broadcast notification', async () => {
    const db = testEnv.authenticatedContext(APPROVER).firestore();
    await assertSucceeds(getDoc(doc(db, 'notifications', 'broadcast-notification')));
  });

  it('a user without the qualifying permission cannot read a broadcast notification', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'notifications', 'broadcast-notification')));
  });

  it('a user without notification.read cannot read any notification', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'notifications', 'personal-notification')));
  });

  it('an unauthenticated request is denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'notifications', 'personal-notification')));
  });
});

describe('notifications/{notificationId} — create', () => {
  it('an active user can create a personal notification for someone else', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'notifications'), {
        userId: OTHER_EMPLOYEE,
        audiencePermission: null,
        type: 'CONTRACT_FINALIZED',
        title: 'Contract Finalized',
        body: 'Contract CTR-2026-000002 was finalized.',
        entityType: 'contract',
        entityId: 'contract2',
        isRead: false,
        createdAt: new Date(),
      })
    );
  });

  it('an active user can create a broadcast notification', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'notifications'), {
        userId: null,
        audiencePermission: 'contract.approve',
        type: 'CONTRACT_SUBMITTED',
        title: 'Contract Submitted',
        body: 'Contract CTR-2026-000002 is awaiting your approval.',
        entityType: 'contract',
        entityId: 'contract2',
        isRead: false,
        createdAt: new Date(),
      })
    );
  });

  it('cannot create a notification with both userId and audiencePermission set', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertFails(
      addDoc(collection(db, 'notifications'), {
        userId: OTHER_EMPLOYEE,
        audiencePermission: 'contract.approve',
        type: 'CONTRACT_SUBMITTED',
        title: 'Contract Submitted',
        body: '...',
        entityType: 'contract',
        entityId: 'contract2',
        isRead: false,
        createdAt: new Date(),
      })
    );
  });

  it('cannot create a notification with neither userId nor audiencePermission set', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertFails(
      addDoc(collection(db, 'notifications'), {
        userId: null,
        audiencePermission: null,
        type: 'CONTRACT_SUBMITTED',
        title: 'Contract Submitted',
        body: '...',
        entityType: 'contract',
        entityId: 'contract2',
        isRead: false,
        createdAt: new Date(),
      })
    );
  });

  it('a user without notification.read cannot create a notification', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'notifications'), {
        userId: RECIPIENT,
        audiencePermission: null,
        type: 'CONTRACT_APPROVED',
        title: 'Contract Approved',
        body: '...',
        entityType: 'contract',
        entityId: 'contract2',
        isRead: false,
        createdAt: new Date(),
      })
    );
  });
});

describe('notifications/{notificationId} — update/delete', () => {
  it('the addressed recipient can mark their own personal notification read', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertSucceeds(updateDoc(doc(db, 'notifications', 'personal-notification'), { isRead: true }));
  });

  it('another user cannot mark someone else\'s personal notification read', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(updateDoc(doc(db, 'notifications', 'personal-notification'), { isRead: true }));
  });

  it('the recipient cannot change fields other than isRead', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertFails(updateDoc(doc(db, 'notifications', 'personal-notification'), { title: 'Tampered' }));
  });

  it('a broadcast notification can never be marked read by anyone, even a qualifying user', async () => {
    const db = testEnv.authenticatedContext(APPROVER).firestore();
    await assertFails(updateDoc(doc(db, 'notifications', 'broadcast-notification'), { isRead: true }));
  });

  it('notifications can never be deleted', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT).firestore();
    await assertFails(deleteDoc(doc(db, 'notifications', 'personal-notification')));
  });
});
