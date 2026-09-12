# Bootstrapping the first admin user

**This manual process is needed only for the very first admin account in a
new environment.** Every other account is created by the person themselves,
from the app's **Sign Up** screen (`lib/features/auth/presentation/
signup_screen.dart`) — that writes `users/{uid}` with `status: 'pending'`,
`role: 'employee'`, and `permissions: {}` (see
`AuthController.signUp` / `FirestoreUserRepository.createPendingUser`, and
the self-signup `allow create` rule in `firestore.rules`). An admin then
approves or rejects it from the **Pending Users** screen
(`lib/features/auth/presentation/pending_users_screen.dart`, gated on
`Permission.userManage`), which sets `status: 'active'` plus a role and
permissions (defaulting to `Permission.defaultsFor(false)` for a regular
employee) — or `status: 'disabled'` to reject it.

Manual bootstrap is still required for that first admin because approving a
signup requires an *already-active admin* — a chicken-and-egg the app can't
resolve by itself in a brand-new environment. The whole app — including the
quotation calculator, not just the Contract System module — requires a
signed-in, active account with a `users/{uid}` Firestore document before it
can be used at all, so this first account has to be created outside the app.

1. In the Firebase Console for the target project (`quocalc-dev`,
   `quocalc-staging`, or `quocalc-504218` for production) → **Authentication**
   → **Sign-in method**, enable **Email/Password** (and **Google**, if you
   want Google Sign-In available — see `lib/features/auth/data/firebase_auth_repository.dart`).
   This is a one-time manual step per environment; the Firebase CLI cannot
   toggle it (`firebase auth:export` fails with `CONFIGURATION_NOT_FOUND`
   until at least one provider is enabled).

2. Still in **Authentication** → **Users** → **Add user**, create the account
   with an email + password. Copy the generated **User UID**.

3. In the same project's **Firestore Database**, create a document at
   `users/{that UID}` with:

   ```json
   {
     "email": "the same email as step 2",
     "displayName": "Whatever name",
     "role": "admin",
     "status": "active",
     "permissions": {
       "customer.read": true, "customer.create": true, "customer.update": true,
       "property.read": true, "property.create": true, "property.update": true,
       "contract.create": true, "contract.read": true, "contract.edit_own": true,
       "contract.submit": true, "contract.clone": true, "document.upload": true,
       "document.read": true, "notification.read": true,
       "contract.edit_any": true, "contract.approve": true, "contract.reject": true,
       "contract.finalize": true, "contract.archive": true,
       "template.read": true, "template.create": true, "template.edit": true, "template.publish": true,
       "user.read": true, "user.manage": true, "audit.read": true, "dashboard.read": true
     },
     "createdAt": <a Firestore Timestamp, e.g. via the console's "current date" picker>,
     "updatedAt": <same>
   }
   ```

   This mirrors `Permission.defaultsFor(true)` in
   `lib/features/auth/domain/permission.dart` — if that list changes, update
   this doc too. Note `property.create`, `template.read`, `customer.update`,
   `property.update`, and (for employee accounts) `dashboard.read` aren't in
   the TDD's own §12 RBAC list — see the comments next to those constants for
   why they're granted anyway.

   There's still no in-app way to grant a *new* permission key to an
   *already-approved* user — the Pending Users screen only sets permissions
   once, at approval time. If a new permission key is added after an account
   was already approved (like `customer.update`/`property.update` were),
   that account's `users/{uid}` document in the Firestore Console needs the
   new key added to its `permissions` map by hand, the same way. The
   corresponding UI (edit button, etc.) simply won't appear for that account
   until then — it isn't a bug, just this doc's list being the only source of
   truth for permission keys added after the fact.

4. Run the app (`flutter run`, defaults to the `dev` Firebase project — see
   `lib/core/config/environment.dart`) and sign in with that email/password
   on the login screen shown at startup. There's no separate "Contract
   System" entry point to find anymore; the whole app is behind this login.

An `employee` account (for testing non-admin permission boundaries) is the
same shape with `"role": "employee"` and `Permission.defaultsFor(false)`'s
narrower set — everything above except `contract.edit_any`,
`contract.approve`, `contract.reject`, `contract.finalize`,
`contract.archive`, `template.*`, `user.*`, `audit.read`. (`dashboard.read`
*is* included for employees — see the note above.)
