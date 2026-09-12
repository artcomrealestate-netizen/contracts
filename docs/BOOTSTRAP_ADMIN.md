# Bootstrapping the first admin user

There's no user-management UI yet (a later phase — see
`docs/Contract_System_TDD_v1.1_EN.md` §12/§44). Until then, the first user
of each environment is created manually. This is no longer optional: the
**whole app** — including the quotation calculator, not just the Contract
System module — requires a signed-in, active account with a `users/{uid}`
Firestore document before it can be used at all.

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
   and `property.update` aren't in the TDD's own §12 RBAC list — see the
   comments next to those constants for why they're granted anyway.

   There's no in-app way to grant a permission to an *existing* user either —
   if a new permission key is added after an account was already created
   (like `customer.update`/`property.update` were), that account's
   `users/{uid}` document in the Firestore Console needs the new key added to
   its `permissions` map by hand, the same way. The corresponding UI (edit
   button, etc.) simply won't appear for that account until then — it isn't a
   bug, just this doc's list being the only source of truth pre-user-management-UI.

4. Run the app (`flutter run`, defaults to the `dev` Firebase project — see
   `lib/core/config/environment.dart`) and sign in with that email/password
   on the login screen shown at startup. There's no separate "Contract
   System" entry point to find anymore; the whole app is behind this login.

An `employee` account (for testing non-admin permission boundaries) is the
same shape with `"role": "employee"` and `Permission.defaultsFor(false)`'s
narrower set — everything above except `contract.edit_any`,
`contract.approve`, `contract.reject`, `contract.finalize`,
`contract.archive`, `template.*`, `user.*`, `audit.read`, `dashboard.read`.
