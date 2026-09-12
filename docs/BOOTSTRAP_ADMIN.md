# Bootstrapping the first admin user

Phase 1 of the Contract System has no user-management UI yet (that's a later
phase — see `docs/Contract_System_TDD_v1.1_EN.md` §12/§44). Until then, the
first user of each environment is created manually:

1. In the Firebase Console for the target project (`quocalc-dev`,
   `quocalc-staging`, or `quocalc-504218` for production) → **Authentication**
   → **Users** → **Add user**, create the account with an email + password.
   Copy the generated **User UID**.

2. In the same project's **Firestore Database**, create a document at
   `users/{that UID}` with:

   ```json
   {
     "email": "the same email as step 1",
     "displayName": "Whatever name",
     "role": "admin",
     "status": "active",
     "permissions": {
       "customer.read": true, "customer.create": true, "property.read": true,
       "contract.create": true, "contract.read": true, "contract.edit_own": true,
       "contract.submit": true, "contract.clone": true, "document.upload": true,
       "document.read": true, "notification.read": true,
       "contract.edit_any": true, "contract.approve": true, "contract.reject": true,
       "contract.finalize": true, "contract.archive": true,
       "template.create": true, "template.edit": true, "template.publish": true,
       "user.read": true, "user.manage": true, "audit.read": true, "dashboard.read": true
     },
     "createdAt": <a Firestore Timestamp, e.g. via the console's "current date" picker>,
     "updatedAt": <same>
   }
   ```

   This mirrors `Permission.defaultsFor(true)` in
   `lib/features/auth/domain/permission.dart` — if that list changes, update
   this doc too.

3. Sign in from the app's "Contract System" entry point (the gavel icon next
   to Settings) with that email/password.

Every **Authentication** sign-in provider is Email/Password. It must be
enabled once per project in the Console (**Authentication** → **Sign-in
method**) — this is a one-time manual step per environment; the Firebase CLI
cannot toggle it.
