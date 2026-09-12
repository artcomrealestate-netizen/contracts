const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §13/§40: customer.read gates
// reads, customer.create gates writes, and a client can never write itself
// in as the createdBy of someone else's customer record. customer.update
// (not in TDD §12 — see permission.dart) is not creator-restricted, since a
// customer record is a shared company record, not personal to whoever first
// entered it — but createdBy itself can never change on update.

let testEnv;

const EMPLOYEE_WITH_ACCESS = 'employee-with-access';
const EMPLOYEE_NO_ACCESS = 'employee-no-access';

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
    await setDoc(doc(db, 'users', EMPLOYEE_WITH_ACCESS), {
      email: 'access@example.com',
      role: 'employee',
      status: 'active',
      permissions: { 'customer.read': true, 'customer.create': true, 'customer.update': true },
    });
    await setDoc(doc(db, 'users', EMPLOYEE_NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'customers', 'existing-customer'), {
      customerType: 'individual',
      individual: { fullName: 'Jane Doe' },
      contact: { phone: '0500000000' },
      status: 'active',
      createdBy: EMPLOYEE_WITH_ACCESS,
    });
  });
});

describe('customers/{customerId} rules', () => {
  it('a user with customer.read can read a customer', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(getDoc(doc(db, 'customers', 'existing-customer')));
  });

  it('a user without customer.read cannot read a customer', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'customers', 'existing-customer')));
  });

  it('an unauthenticated request is denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'customers', 'existing-customer')));
  });

  it('a user with customer.create can create a customer with themself as createdBy', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'customers'), {
        customerType: 'individual',
        individual: { fullName: 'New Customer' },
        contact: {},
        status: 'active',
        createdBy: EMPLOYEE_WITH_ACCESS,
      })
    );
  });

  it('a user without customer.create cannot create a customer', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'customers'), {
        customerType: 'individual',
        individual: { fullName: 'New Customer' },
        contact: {},
        status: 'active',
        createdBy: EMPLOYEE_NO_ACCESS,
      })
    );
  });

  it('a user cannot create a customer with someone else as createdBy', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'customers'), {
        customerType: 'individual',
        individual: { fullName: 'New Customer' },
        contact: {},
        status: 'active',
        createdBy: EMPLOYEE_NO_ACCESS,
      })
    );
  });

  it('a user with customer.update can edit a customer record, even one they did not create', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(updateDoc(doc(db, 'customers', 'existing-customer'), { address: 'New address' }));
  });

  it('a user without customer.update cannot edit a customer record', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(updateDoc(doc(db, 'customers', 'existing-customer'), { address: 'New address' }));
  });

  it('createdBy cannot change on update', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(updateDoc(doc(db, 'customers', 'existing-customer'), { createdBy: EMPLOYEE_NO_ACCESS }));
  });

  it('customer documents can never be deleted', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(deleteDoc(doc(db, 'customers', 'existing-customer')));
  });
});
