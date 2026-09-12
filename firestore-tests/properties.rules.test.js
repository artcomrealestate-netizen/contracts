const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §14/§40, same shape as the
// customers rules: property.read gates reads, property.create gates writes
// (property.create isn't in the TDD's §12 RBAC list, but properties have to
// be created by someone — see lib/features/auth/domain/permission.dart).
// property.update (also not in §12) is not creator-restricted, but createdBy
// itself can never change on update.

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
      permissions: { 'property.read': true, 'property.create': true, 'property.update': true },
    });
    await setDoc(doc(db, 'users', EMPLOYEE_NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'properties', 'existing-property'), {
      propertyCode: 'P-001',
      name: 'Marina Tower',
      propertyType: 'Apartment',
      area: 1200,
      location: { emirate: 'Dubai' },
      status: 'active',
      createdBy: EMPLOYEE_WITH_ACCESS,
    });
  });
});

describe('properties/{propertyId} rules', () => {
  it('a user with property.read can read a property', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(getDoc(doc(db, 'properties', 'existing-property')));
  });

  it('a user without property.read cannot read a property', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'properties', 'existing-property')));
  });

  it('an unauthenticated request is denied', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'properties', 'existing-property')));
  });

  it('a user with property.create can create a property with themself as createdBy', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'properties'), {
        propertyCode: 'P-002',
        name: 'New Property',
        propertyType: 'Villa',
        area: 2000,
        location: {},
        status: 'active',
        createdBy: EMPLOYEE_WITH_ACCESS,
      })
    );
  });

  it('a user without property.create cannot create a property', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'properties'), {
        propertyCode: 'P-002',
        name: 'New Property',
        propertyType: 'Villa',
        area: 2000,
        location: {},
        status: 'active',
        createdBy: EMPLOYEE_NO_ACCESS,
      })
    );
  });

  it('a user cannot create a property with someone else as createdBy', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'properties'), {
        propertyCode: 'P-002',
        name: 'New Property',
        propertyType: 'Villa',
        area: 2000,
        location: {},
        status: 'active',
        createdBy: EMPLOYEE_NO_ACCESS,
      })
    );
  });

  it('a user with property.update can edit a property record, even one they did not create', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertSucceeds(updateDoc(doc(db, 'properties', 'existing-property'), { name: 'Renamed' }));
  });

  it('a user without property.update cannot edit a property record', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_NO_ACCESS).firestore();
    await assertFails(updateDoc(doc(db, 'properties', 'existing-property'), { name: 'Renamed' }));
  });

  it('createdBy cannot change on update', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(updateDoc(doc(db, 'properties', 'existing-property'), { createdBy: EMPLOYEE_NO_ACCESS }));
  });

  it('property documents can never be deleted', async () => {
    const db = testEnv.authenticatedContext(EMPLOYEE_WITH_ACCESS).firestore();
    await assertFails(deleteDoc(doc(db, 'properties', 'existing-property')));
  });
});
