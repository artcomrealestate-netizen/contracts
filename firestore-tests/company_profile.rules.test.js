const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

// companyProfile/main: shared lessor legal-signatory info + logo used by
// every teammate's contract PDF export (see lib/features/company/). Any
// active user needs read; only an admin may write.

let testEnv;

const ACTIVE_EMPLOYEE = 'employee-active';
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

describe('companyProfile/main rules', () => {
  it('an active user can read the company profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'companyProfile', 'main'), { ownerName: 'Louai Dahhan' });
    });
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertSucceeds(getDoc(doc(db, 'companyProfile', 'main')));
  });

  it('a disabled account cannot read the company profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'companyProfile', 'main'), { ownerName: 'Louai Dahhan' });
    });
    const db = testEnv.authenticatedContext(DISABLED_EMPLOYEE).firestore();
    await assertFails(getDoc(doc(db, 'companyProfile', 'main')));
  });

  it('an unauthenticated request cannot read the company profile', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'companyProfile', 'main')));
  });

  it('a non-admin cannot write the company profile', async () => {
    const db = testEnv.authenticatedContext(ACTIVE_EMPLOYEE).firestore();
    await assertFails(setDoc(doc(db, 'companyProfile', 'main'), { ownerName: 'Someone Else' }));
  });

  it('an admin can write the company profile', async () => {
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'companyProfile', 'main'), { ownerName: 'Louai Dahhan', ownerEmiratesId: '784-1969-6357109-4' })
    );
  });
});
