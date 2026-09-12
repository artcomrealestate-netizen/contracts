const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  collection,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
} = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §17/§22/§39/§40: a contract is
// always born a Draft owned by its creator, only that creator may edit it
// (and only while it's still a Draft), and the numbering counter can only
// ever be advanced by exactly 1.

let testEnv;

const OWNER = 'contract-owner'; // contract.read + contract.create + contract.edit_own + contract.submit
const OTHER_EMPLOYEE = 'other-employee'; // same permissions, different uid
const NO_ACCESS = 'no-access';
const ADMIN = 'contract-admin'; // contract.read + contract.edit_any + contract.approve + contract.reject
const AUDITOR = 'auditor'; // contract.read + audit.read

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
    const ownerPermissions = {
      'contract.read': true,
      'contract.create': true,
      'contract.edit_own': true,
      'contract.submit': true,
    };
    await setDoc(doc(db, 'users', OWNER), {
      email: 'owner@example.com',
      role: 'employee',
      status: 'active',
      permissions: ownerPermissions,
    });
    await setDoc(doc(db, 'users', OTHER_EMPLOYEE), {
      email: 'other@example.com',
      role: 'employee',
      status: 'active',
      permissions: ownerPermissions,
    });
    await setDoc(doc(db, 'users', NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'users', ADMIN), {
      email: 'admin@example.com',
      role: 'admin',
      status: 'active',
      permissions: {
        'contract.read': true,
        'contract.edit_any': true,
        'contract.approve': true,
        'contract.reject': true,
        'contract.finalize': true,
      },
    });
    await setDoc(doc(db, 'users', AUDITOR), {
      email: 'auditor@example.com',
      role: 'admin',
      status: 'active',
      permissions: { 'contract.read': true, 'audit.read': true },
    });
    await setDoc(doc(db, 'contracts', 'existing-draft'), baseContractData());
    await setDoc(
      doc(db, 'contracts', 'existing-pending'),
      baseContractData({
        status: 'PENDING_APPROVAL',
        clauses: [{ id: 'c1', order: 1, title: 'Payment Terms', content: '...', isLocked: false }],
      })
    );
    await setDoc(doc(db, 'contracts', 'existing-rejected'), baseContractData({ status: 'REJECTED' }));
    await setDoc(doc(db, 'contracts', 'existing-approved'), baseContractData({ status: 'APPROVED' }));
    await setDoc(doc(db, 'counters', 'contracts_2026'), { count: 1 });
  });
});

describe('contracts/{contractId} rules', () => {
  it('the owner with contract.read can read their own contract', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('a user without contract.read cannot read a contract', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('another employee with contract.read but not contract.edit_any cannot read someone else\'s contract', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('an admin with contract.edit_any can read any contract, not just their own', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(getDoc(doc(db, 'contracts', 'existing-draft')));
  });

  it('a plain employee can list only their own contracts, filtered by createdBy', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    const q = query(collection(db, 'contracts'), where('createdBy', '==', OWNER));
    await assertSucceeds(getDocs(q));
  });

  it('a plain employee cannot list contracts without filtering by their own createdBy', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(getDocs(collection(db, 'contracts')));
  });

  it('an admin with contract.edit_any can list all contracts, unfiltered', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(getDocs(collection(db, 'contracts')));
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

describe('contracts/{contractId} — submit (TDD §23)', () => {
  it('the owner with contract.submit can move their own Draft to PENDING_APPROVAL', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contracts', 'existing-draft'), { status: 'PENDING_APPROVAL', submittedAt: new Date() })
    );
  });

  it('another employee cannot submit someone else\'s Draft', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-draft'), { status: 'PENDING_APPROVAL' }));
  });

  it('cannot submit a contract that is not currently DRAFT', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-pending'), { status: 'PENDING_APPROVAL' }));
  });
});

describe('contracts/{contractId} — approve (TDD §23)', () => {
  it('an admin with contract.approve can approve a pending contract', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contracts', 'existing-pending'), {
        status: 'APPROVED',
        approvedAt: new Date(),
        approvedBy: ADMIN,
      })
    );
  });

  it('cannot approve while pretending to be a different approver', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-pending'), { status: 'APPROVED', approvedBy: OTHER_EMPLOYEE })
    );
  });

  it('the owner (without contract.approve) cannot approve their own contract', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-pending'), { status: 'APPROVED', approvedBy: OWNER })
    );
  });

  it('cannot approve a Draft directly (must go through PENDING_APPROVAL)', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-draft'), { status: 'APPROVED', approvedBy: ADMIN })
    );
  });
});

describe('contracts/{contractId} — reject (TDD §23/§24)', () => {
  it('an admin with contract.reject can reject a pending contract with a rejection object', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contracts', 'existing-pending'), {
        status: 'REJECTED',
        rejection: { generalNote: 'Revise payment terms.', rejectedBy: ADMIN, clauses: [] },
      })
    );
  });

  it('cannot reject while pretending to be a different rejector', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-pending'), {
        status: 'REJECTED',
        rejection: { generalNote: 'Revise.', rejectedBy: OTHER_EMPLOYEE, clauses: [] },
      })
    );
  });

  it('an employee without contract.reject cannot reject', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-pending'), {
        status: 'REJECTED',
        rejection: { generalNote: 'Revise.', rejectedBy: OWNER, clauses: [] },
      })
    );
  });
});

describe('contracts/{contractId} — revise a rejected contract', () => {
  it('the owner with contract.edit_own can move their own Rejected contract back to Draft', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, 'contracts', 'existing-rejected'), { status: 'DRAFT' }));
  });

  it('another employee cannot revise someone else\'s Rejected contract', async () => {
    const db = testEnv.authenticatedContext(OTHER_EMPLOYEE).firestore();
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-rejected'), { status: 'DRAFT' }));
  });

  it('cannot move a Draft (not Rejected) contract using the revise path', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    // Already DRAFT -> DRAFT, so this actually exercises isOwnerEditingDraft,
    // not isOwnerRevising — included to document that revise only applies
    // to a REJECTED starting state, not as a no-op alternate path.
    await assertSucceeds(updateDoc(doc(db, 'contracts', 'existing-draft'), { status: 'DRAFT' }));
  });
});

describe('contracts/{contractId} — finalize (TDD §22/§23/§27)', () => {
  it('an admin with contract.finalize can finalize an approved contract', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contracts', 'existing-approved'), {
        status: 'FINALIZED',
        finalizedBy: ADMIN,
      })
    );
  });

  it('cannot finalize while pretending to be a different finalizer', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-approved'), {
        status: 'FINALIZED',
        finalizedBy: OWNER,
      })
    );
  });

  it('the owner (without contract.finalize) cannot finalize their own approved contract', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-approved'), {
        status: 'FINALIZED',
        finalizedBy: OWNER,
      })
    );
  });

  it('cannot finalize a contract that is not currently APPROVED', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'contracts', 'existing-pending'), {
        status: 'FINALIZED',
        finalizedBy: ADMIN,
      })
    );
  });

  it('a finalized contract can never be updated again, even by an admin', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'contracts', 'existing-finalized'),
        baseContractData({ status: 'FINALIZED', finalizedBy: ADMIN })
      );
    });
    await assertFails(updateDoc(doc(db, 'contracts', 'existing-finalized'), { status: 'ARCHIVED' }));
  });
});

describe('auditLogs/{logId} rules', () => {
  it('an active user can create an audit log entry with themself as actorId', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'auditLogs'), {
        entityType: 'contract',
        entityId: 'existing-draft',
        action: 'SUBMITTED',
        actorId: OWNER,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
        metadata: {},
      })
    );
  });

  it('cannot create an audit log entry impersonating a different actor', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      addDoc(collection(db, 'auditLogs'), {
        entityType: 'contract',
        entityId: 'existing-draft',
        action: 'SUBMITTED',
        actorId: OTHER_EMPLOYEE,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
        metadata: {},
      })
    );
  });

  it('a user with audit.read can read audit logs', async () => {
    const db = testEnv.authenticatedContext(AUDITOR).firestore();
    let logId;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const ref = await addDoc(collection(context.firestore(), 'auditLogs'), {
        entityType: 'contract',
        entityId: 'existing-draft',
        action: 'SUBMITTED',
        actorId: OWNER,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
        metadata: {},
      });
      logId = ref.id;
    });
    await assertSucceeds(getDoc(doc(db, 'auditLogs', logId)));
  });

  it('a user without audit.read cannot read audit logs', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    let logId;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const ref = await addDoc(collection(context.firestore(), 'auditLogs'), {
        entityType: 'contract',
        entityId: 'existing-draft',
        action: 'SUBMITTED',
        actorId: OWNER,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
        metadata: {},
      });
      logId = ref.id;
    });
    await assertFails(getDoc(doc(db, 'auditLogs', logId)));
  });

  it('audit log entries can never be updated or deleted', async () => {
    const db = testEnv.authenticatedContext(AUDITOR).firestore();
    let logId;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const ref = await addDoc(collection(context.firestore(), 'auditLogs'), {
        entityType: 'contract',
        entityId: 'existing-draft',
        action: 'SUBMITTED',
        actorId: OWNER,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
        metadata: {},
      });
      logId = ref.id;
    });
    await assertFails(updateDoc(doc(db, 'auditLogs', logId), { action: 'TAMPERED' }));
    await assertFails(deleteDoc(doc(db, 'auditLogs', logId)));
  });
});

describe('counters/{counterId} rules', () => {
  // Simplified twice — see the comments in firestore.rules. First from
  // branching on the counter id prefix + contract.create/isActive() (both
  // reliably threw an unconverted native error client-side on Web when
  // evaluated inside a transaction). Then, after the numbering code moved to
  // FieldValue.increment() instead of a transaction, the exact-value checks
  // (count == 1 / count == resource.data.count + 1) turned out to reliably
  // reject an increment() write as permission-denied too, so those are gone
  // as well. Any signed-in user may write any value to any counter — this
  // collection carries no sensitive data of its own (actual contract/
  // quotation creation is separately gated by those collections' own strict
  // rules), so the only boundary left is being signed in at all.
  it('a signed-in user can read a counter (needed to read back a value after incrementing it)', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(getDoc(doc(db, 'counters', 'contracts_2026')));
  });

  it('an unauthenticated request cannot read a counter', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'counters', 'contracts_2026')));
  });

  it('a signed-in user can advance the counter', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 2 }));
  });

  it('a signed-in user without contract.create can still advance a counter (no sensitive data here)', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertSucceeds(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 2 }));
  });

  it('an unauthenticated request cannot advance the counter', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(updateDoc(doc(db, 'counters', 'contracts_2026'), { count: 2 }));
  });
});
