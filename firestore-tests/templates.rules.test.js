const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, addDoc, updateDoc, deleteDoc } = require('firebase/firestore');

// Mirrors docs/Contract_System_TDD_v1.1_EN.md §15/§16/§40: template.create
// makes a template's first version, template.publish makes every version
// after that, template.edit changes only template metadata, and a version
// document is immutable once written.

let testEnv;

const CREATOR = 'template-creator'; // template.read + template.create
const PUBLISHER = 'template-publisher'; // template.read + template.publish
const EDITOR = 'template-editor'; // template.read + template.edit
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
    await setDoc(doc(db, 'users', CREATOR), {
      email: 'creator@example.com',
      role: 'admin',
      status: 'active',
      permissions: { 'template.read': true, 'template.create': true },
    });
    await setDoc(doc(db, 'users', PUBLISHER), {
      email: 'publisher@example.com',
      role: 'admin',
      status: 'active',
      permissions: { 'template.read': true, 'template.publish': true },
    });
    await setDoc(doc(db, 'users', EDITOR), {
      email: 'editor@example.com',
      role: 'admin',
      status: 'active',
      permissions: { 'template.read': true, 'template.edit': true },
    });
    await setDoc(doc(db, 'users', NO_ACCESS), {
      email: 'noaccess@example.com',
      role: 'employee',
      status: 'active',
      permissions: {},
    });
    await setDoc(doc(db, 'contractTemplates', 'existing-template'), {
      name: 'Commercial Lease',
      code: 'COMM_LEASE',
      status: 'active',
      currentVersion: 1,
      createdBy: CREATOR,
    });
    await setDoc(doc(db, 'contractTemplateVersions', 'existing-version-1'), {
      templateId: 'existing-template',
      version: 1,
      clauses: [],
      createdBy: CREATOR,
    });
  });
});

describe('contractTemplates/{templateId} rules', () => {
  it('a user with template.read can read a template', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertSucceeds(getDoc(doc(db, 'contractTemplates', 'existing-template')));
  });

  it('a user without template.read cannot read a template', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(getDoc(doc(db, 'contractTemplates', 'existing-template')));
  });

  it('template.create can create a template with currentVersion == 1', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'contractTemplates'), {
        name: 'New Template',
        code: 'NEW',
        status: 'active',
        currentVersion: 1,
        createdBy: CREATOR,
      })
    );
  });

  it('template.create cannot create a template with currentVersion != 1', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertFails(
      addDoc(collection(db, 'contractTemplates'), {
        name: 'New Template',
        code: 'NEW',
        status: 'active',
        currentVersion: 2,
        createdBy: CREATOR,
      })
    );
  });

  it('a user without template.create cannot create a template', async () => {
    const db = testEnv.authenticatedContext(NO_ACCESS).firestore();
    await assertFails(
      addDoc(collection(db, 'contractTemplates'), {
        name: 'New Template',
        code: 'NEW',
        status: 'active',
        currentVersion: 1,
        createdBy: NO_ACCESS,
      })
    );
  });

  it('template.edit can change metadata without touching currentVersion', async () => {
    const db = testEnv.authenticatedContext(EDITOR).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contractTemplates', 'existing-template'), { name: 'Renamed Lease' })
    );
  });

  it('template.edit alone cannot bump currentVersion', async () => {
    const db = testEnv.authenticatedContext(EDITOR).firestore();
    await assertFails(
      updateDoc(doc(db, 'contractTemplates', 'existing-template'), { currentVersion: 2 })
    );
  });

  it('template.publish can bump currentVersion by exactly 1', async () => {
    const db = testEnv.authenticatedContext(PUBLISHER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'contractTemplates', 'existing-template'), { currentVersion: 2 })
    );
  });

  it('template.publish cannot skip a version number', async () => {
    const db = testEnv.authenticatedContext(PUBLISHER).firestore();
    await assertFails(
      updateDoc(doc(db, 'contractTemplates', 'existing-template'), { currentVersion: 3 })
    );
  });

  it('contractTemplates cannot be deleted', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertFails(deleteDoc(doc(db, 'contractTemplates', 'existing-template')));
  });
});

describe('contractTemplateVersions/{versionId} rules', () => {
  it('template.create can write a version == 1 document', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'contractTemplateVersions'), {
        templateId: 'existing-template',
        version: 1,
        clauses: [],
        createdBy: CREATOR,
      })
    );
  });

  it('template.publish alone cannot write a version == 1 document', async () => {
    const db = testEnv.authenticatedContext(PUBLISHER).firestore();
    await assertFails(
      addDoc(collection(db, 'contractTemplateVersions'), {
        templateId: 'existing-template',
        version: 1,
        clauses: [],
        createdBy: PUBLISHER,
      })
    );
  });

  it('template.publish can write a version > 1 document', async () => {
    const db = testEnv.authenticatedContext(PUBLISHER).firestore();
    await assertSucceeds(
      addDoc(collection(db, 'contractTemplateVersions'), {
        templateId: 'existing-template',
        version: 2,
        clauses: [],
        createdBy: PUBLISHER,
      })
    );
  });

  it('template.create alone cannot write a version > 1 document', async () => {
    const db = testEnv.authenticatedContext(CREATOR).firestore();
    await assertFails(
      addDoc(collection(db, 'contractTemplateVersions'), {
        templateId: 'existing-template',
        version: 2,
        clauses: [],
        createdBy: CREATOR,
      })
    );
  });

  it('a version document can never be updated or deleted', async () => {
    const db = testEnv.authenticatedContext(PUBLISHER).firestore();
    await assertFails(
      updateDoc(doc(db, 'contractTemplateVersions', 'existing-version-1'), { clauses: [] })
    );
    await assertFails(deleteDoc(doc(db, 'contractTemplateVersions', 'existing-version-1')));
  });
});
