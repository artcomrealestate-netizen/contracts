# Technical Design Document (TDD)
## Contract & Document Management System

**Version:** 1.1 EN  
**Status:** Approved Baseline for Development  
**Project:** `qouta_calculator`  
**Client:** Flutter Mobile App  
**Backend Platform:** Firebase  
**Database:** Cloud Firestore  
**File Storage:** Firebase Cloud Storage  
**Authentication:** Firebase Authentication  
**Notifications:** Firebase Cloud Messaging  
**Integration Model:** Internal repository-level integration inside the same Flutter project and Firestore database  
**CI/CD:** GitHub Actions or Bitbucket Pipelines  
**Version Control:** Git  
**Environments:** Development / Staging / Production

---

## 1. Purpose

This document is the technical baseline for implementing the contract and document management capability inside the existing `qouta_calculator` Flutter application.

The contract capability is **not a separate system** and does not integrate with a separate REST API, ERP, accounting platform, or external invoice service. Quotations/invoices and contracts live in the same Flutter codebase and the same Firebase/Firestore project.

The primary lifecycle is:

```text
Quotation / Invoice
       ↓
Create Contract
       ↓
DRAFT
       ↓
PENDING_APPROVAL
       ├── REJECTED → DRAFT → Resubmit
       ↓
APPROVED
       ↓
FINALIZED
       ↓
ARCHIVED
```

---

## 2. Architectural Decisions

### ADR-001 — Internal Integration Model

The following decisions are approved:

1. There is no external invoice system.
2. `qouta_calculator` is the same project for quotations/invoices and contracts.
3. Flutter is the shared client.
4. Firestore is the shared data source.
5. Repository interfaces are the internal integration boundaries.
6. No REST API is required for MVP.
7. No Cloud Functions layer is mandatory for MVP.
8. Firestore Security Rules are the primary authorization boundary for direct client writes.
9. Firestore transactions are used for atomic operations permitted to the client.
10. Domain and repository boundaries must remain clean so a trusted backend can be introduced later without rewriting the domain layer.

### ADR-002 — Invoice/Contract Relationship

The contract references the existing quotation/invoice through:

```text
sourceQuotationId
```

The contract may also store a final `invoiceId` where the existing data model provides one. The authoritative relationship remains an internal Firestore relationship, not an HTTP integration.

---

## 3. Scope

### In Scope

- Authentication
- User management
- RBAC
- Customers
- Properties
- Existing quotation/invoice access
- Contract templates
- Template versions
- Dynamic clauses
- Locked clauses
- Contract drafts
- Approval workflow
- Clause-level rejection feedback
- Contract versioning
- Audit trail
- Invoice/quotation linking
- Financial snapshots
- Customer/property snapshots
- PDF generation
- Document attachments
- Archive
- Dashboard
- Search and filtering
- Pagination
- Contract cloning
- Push notifications
- Offline read access
- Firestore Security Rules
- Automated testing
- CI/CD
- Release management

### Out of Scope for MVP

- External ERP/accounting integration
- Payment gateway
- Third-party e-signature
- External CRM
- Customer portal
- AI contract analysis
- Mandatory server-side backend
- Webhooks
- Scheduled server jobs

These items remain future extension points.

---

## 4. High-Level Architecture

```text
                         Flutter Mobile App
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
        ▼                       ▼                        ▼
 Quotation Feature       Contract Feature       Template Feature
        │                       │                        │
        ▼                       ▼                        ▼
QuotationRepository     ContractRepository      TemplateRepository
        │                       │                        │
        └───────────────────────┼────────────────────────┘
                                ▼
                         Firestore SDK
                                │
                         Firestore Rules
                                │
                 ┌──────────────┼──────────────┐
                 ▼              ▼              ▼
             Firestore       Storage          FCM
```

---

## 5. Core Architectural Principles

### 5.1 Client-First Firebase Architecture

Flutter uses Firebase SDKs directly for data access.

### 5.2 Client Is Not Trusted

Any client request can be manipulated. Security must not depend on Flutter UI behavior.

### 5.3 UI Is Not Security

Hiding an `Approve` button is only a UX measure. Firestore Security Rules must enforce access restrictions.

### 5.4 Repository Boundaries

Features access Firebase through repository abstractions rather than coupling UI directly to Firestore implementation details.

### 5.5 Immutable Final Documents

Once a contract becomes `FINALIZED`, its content is read-only.

### 5.6 Historical Snapshots

Finalized contracts retain the historical financial, customer, property, template, and clause data that formed the final document.

### 5.7 Auditability

Business-significant operations must be traceable.

---

## 6. Environments

Maintain three isolated Firebase environments:

```text
Development
Staging
Production
```

Each environment has its own:

- Firebase project
- Authentication users
- Firestore database
- Storage bucket
- Security Rules
- Indexes
- Functions/configuration when introduced

Production data must never be used as a development dataset.

---

## 7. Flutter Architecture

Use a feature-first, layered architecture.

```text
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── router/
│   ├── services/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── customers/
│   ├── properties/
│   ├── quotations/
│   ├── contracts/
│   ├── templates/
│   ├── documents/
│   └── notifications/
│
└── app.dart
```

Each feature follows:

```text
feature/
├── data/
├── domain/
└── presentation/
```

---

## 8. Layer Responsibilities

### Presentation

Responsible for screens, widgets, navigation, user interaction, and UI state.

### Domain

Responsible for entities, use cases, business interfaces, and rules independent from Firebase.

### Data

Responsible for repository implementations, Firestore mapping, storage access, DTOs, and Firebase calls.

---

## 9. State Management

Use a single project-wide state management approach. The recommended choice is **Riverpod**.

Example:

```text
ContractScreen
      ↓
ContractNotifier
      ↓
SubmitContractUseCase
      ↓
ContractRepository
      ↓
Firestore
```

Business rules must not be embedded inside widgets.

---

## 10. Authentication

Use Firebase Authentication.

Required flows:

- Login
- Logout
- Session restore
- Password reset
- Optional email verification
- Account deactivation
- Disabled-account handling

After login:

```text
Firebase Auth User
      ↓
Load User Profile
      ↓
Resolve Role / Permissions
      ↓
Initialize Application
```

---

## 11. Users Collection

```text
users/{userId}
```

Example:

```json
{
  "id": "uid",
  "email": "user@example.com",
  "displayName": "User Name",
  "role": "employee",
  "status": "active",
  "permissions": {
    "contract.create": true,
    "contract.edit": true,
    "contract.submit": true,
    "contract.approve": false,
    "contract.reject": false
  },
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "lastLoginAt": "Timestamp"
}
```

Supported roles:

```text
employee
admin
```

Supported account status:

```text
active
suspended
disabled
```

---

## 12. RBAC Model

Do not build authorization around role checks alone. Roles should map to explicit permissions.

### Employee

```text
customer.read
customer.create
property.read
contract.create
contract.read
contract.edit_own
contract.submit
contract.clone
document.upload
document.read
notification.read
```

### Admin

Includes employee permissions plus:

```text
contract.edit_any
contract.approve
contract.reject
contract.finalize
contract.archive

template.create
template.edit
template.publish

user.read
user.manage

audit.read
dashboard.read
```

---

## 13. Customer Model

```text
customers/{customerId}
```

Example:

```json
{
  "customerType": "individual",
  "individual": {
    "fullName": "string",
    "emiratesId": "string",
    "passportNumber": "string"
  },
  "company": null,
  "contact": {
    "phone": "string",
    "email": "string"
  },
  "address": "string",
  "status": "active",
  "createdBy": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Company customers can use:

```json
{
  "customerType": "company",
  "company": {
    "legalName": "string",
    "tradeLicenseNumber": "string",
    "licensingAuthority": "string"
  }
}
```

---

## 14. Property Model

```text
properties/{propertyId}
```

```json
{
  "propertyCode": "string",
  "name": "string",
  "propertyType": "string",
  "unitNumber": "string",
  "area": 0,
  "location": {
    "emirate": "string",
    "city": "string",
    "district": "string"
  },
  "status": "active",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## 15. Contract Template Model

```text
contractTemplates/{templateId}
```

```json
{
  "name": "Commercial Lease",
  "code": "COMM_LEASE",
  "status": "active",
  "currentVersion": 3,
  "createdBy": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Template versions are immutable after publication.

---

## 16. Contract Template Version

```text
contractTemplateVersions/{versionId}
```

```json
{
  "templateId": "templateId",
  "version": 3,
  "clauses": [
    {
      "id": "clause-1",
      "order": 1,
      "title": "Payment Terms",
      "content": "...",
      "isLocked": true
    }
  ],
  "createdBy": "uid",
  "createdAt": "Timestamp"
}
```

A new template version is created instead of modifying a published version.

---

## 17. Contract Model

```text
contracts/{contractId}
```

Example:

```json
{
  "contractNumber": "CTR-2026-000001",
  "status": "DRAFT",
  "version": 1,

  "customerId": "customerId",
  "propertyId": "propertyId",
  "sourceQuotationId": "quotationId",
  "invoiceId": "invoiceId",

  "templateId": "templateId",
  "templateVersion": 3,

  "customerSnapshot": null,
  "propertySnapshot": null,
  "financialSnapshot": null,

  "clauses": [],

  "createdBy": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",

  "submittedAt": null,
  "approvedAt": null,
  "finalizedAt": null,

  "approvedBy": null,
  "finalizedBy": null,

  "finalPdfUrl": null,
  "fileHash": null
}
```

---

## 18. Clause Model

```json
{
  "id": "clause-123",
  "order": 4,
  "title": "Termination",
  "content": "Clause content",
  "isLocked": true,
  "reviewStatus": "PENDING",
  "rejectionNote": null
}
```

Review statuses:

```text
PENDING
APPROVED
NEEDS_REVISION
```

---

## 19. Invoice / Quotation Integration

There is no REST integration layer for the existing invoice capability.

The contract references the same Firestore data through `QuotationRepository` and related internal repositories.

Example interface:

```dart
abstract class QuotationRepository {
  Future<Quotation?> getQuotation(String id);
}
```

The contract holds:

```text
sourceQuotationId
```

and optionally:

```text
invoiceId
```

The existing quotation/invoice records remain the operational source of truth while the contract is in Draft.

---

## 20. Financial Snapshot

A finalized contract must store the financial state used to produce the final document.

```json
{
  "sourceQuotationId": "Q-1001",
  "invoiceId": "INV-1001",
  "invoiceNumber": "INV-2026-00125",
  "currency": "AED",
  "subtotal": 100000,
  "discount": 0,
  "tax": 5000,
  "total": 105000,
  "capturedAt": "Timestamp"
}
```

Once the contract is finalized, the snapshot is not automatically updated.

---

## 21. Snapshot Strategy

Finalized contracts should retain:

```text
Customer Snapshot
Property Snapshot
Financial Snapshot
Clause Snapshot
Template Snapshot / Version Reference
```

This guarantees historical consistency even if the live customer, property, quotation, or template data later changes.

---

## 22. Contract State Machine

Supported states:

```text
DRAFT
PENDING_APPROVAL
REJECTED
APPROVED
FINALIZED
ARCHIVED
CANCELLED
```

Valid transitions:

```text
DRAFT
  → PENDING_APPROVAL
```

```text
PENDING_APPROVAL
  → APPROVED
```

```text
PENDING_APPROVAL
  → REJECTED
```

```text
REJECTED
  → DRAFT
```

```text
APPROVED
  → FINALIZED
```

```text
FINALIZED
  → ARCHIVED
```

Illegal transitions must be blocked by Rules and application validation.

---

## 23. Workflow Rules

### Submit

Employee may submit only an owned/authorized Draft.

Validation must check:

- Customer exists
- Property exists
- Required quotation/invoice reference exists when required
- Required clauses exist
- Locked clauses remain valid
- Required contract fields are complete

### Approve

Only an authorized Admin can approve:

```text
PENDING_APPROVAL → APPROVED
```

### Reject

Only an authorized Admin can reject:

```text
PENDING_APPROVAL → REJECTED
```

Rejection must include a general reason and may include clause-level feedback.

### Finalize

Only an authorized user can finalize an `APPROVED` contract.

---

## 24. Rejection Model

```json
{
  "generalNote": "Please revise payment terms.",
  "rejectedBy": "adminUid",
  "rejectedAt": "Timestamp",
  "clauses": [
    {
      "clauseId": "clause-4",
      "note": "Please revise the termination condition."
    }
  ]
}
```

Clause feedback must identify exactly which clause requires revision.

---

## 25. Versioning

Approved/finalized content must never be overwritten.

Example:

```text
Contract C-100

Version 1 → Rejected
Version 2 → Rejected
Version 3 → Approved
```

Version record:

```json
{
  "contractId": "contractId",
  "versionNumber": 3,
  "previousVersionId": "version2",
  "createdBy": "uid",
  "createdAt": "Timestamp",
  "changeReason": "Updated payment clause"
}
```

---

## 26. Clone Rules

Cloning creates a new Draft.

The clone must receive:

```text
New contractId
New contractNumber
status = DRAFT
version = 1
new audit trail
createdBy = current user
```

The clone must not inherit:

```text
Approval history
Final PDF
Finalized timestamps
ApprovedBy
Original audit logs
```

---

## 27. Immutability

When a contract becomes `FINALIZED`, the following become immutable:

- Clauses
- Customer snapshot
- Property snapshot
- Financial snapshot
- Template version reference
- Approval metadata
- Final PDF reference
- File hash

The UI becomes read-only.

---

## 28. PDF Generation

Recommended flow:

```text
Final Contract Data
       ↓
Template Renderer
       ↓
PDF Generator
       ↓
SHA-256 Hash
       ↓
Firebase Storage
       ↓
Immutable Final Document
```

The final document must record:

```text
finalPdfUrl
fileHash
generatedAt
generatedBy
```

---

## 29. Storage Structure

```text
contracts/{contractId}/
    versions/{version}/
        draft/
        final/
        attachments/
```

Firestore stores metadata; files live in Firebase Storage.

---

## 30. Documents Collection

```text
documents/{documentId}
```

Example:

```json
{
  "entityType": "contract",
  "entityId": "contractId",
  "contractVersion": 3,
  "fileName": "contract.pdf",
  "fileType": "application/pdf",
  "storagePath": "...",
  "uploadedBy": "uid",
  "uploadedAt": "Timestamp",
  "hash": "sha256..."
}
```

---

## 31. Audit Trail

Collection:

```text
auditLogs/{logId}
```

Example:

```json
{
  "entityType": "contract",
  "entityId": "contractId",
  "action": "CONTRACT_APPROVED",
  "actorId": "uid",
  "actorRole": "admin",
  "fromStatus": "PENDING_APPROVAL",
  "toStatus": "APPROVED",
  "metadata": {},
  "timestamp": "Timestamp"
}
```

Typical actions:

```text
CREATED
UPDATED
SUBMITTED
REJECTED
APPROVED
FINALIZED
ARCHIVED
CLONED
DOCUMENT_UPLOADED
PDF_GENERATED
```

In the client-first MVP, audit writes must be tightly constrained by Security Rules. Audit data must not be freely editable by end users.

---

## 32. Notifications

Collection:

```text
notifications/{notificationId}
```

```json
{
  "userId": "uid",
  "type": "CONTRACT_REJECTED",
  "title": "Contract Rejected",
  "body": "Contract CTR-2026-001 was rejected",
  "entityType": "contract",
  "entityId": "contractId",
  "isRead": false,
  "createdAt": "Timestamp"
}
```

FCM is used for push notifications.

---

## 33. Notification Events

At minimum:

```text
Contract Submitted
Contract Approved
Contract Rejected
Contract Finalized
Action Required
```

Deep links should take the user directly to the relevant contract/action.

---

## 34. Dashboard

### Admin

- Pending approvals
- Rejected contracts
- Approved this month
- Finalized this month
- Total contract value
- Outstanding invoices where data is available
- Overdue invoice indicators where data is available

### Employee

- My drafts
- Pending approval
- Rejected contracts
- Approved contracts
- Recent contracts

Dashboard data must be query-efficient and should not read the entire collection.

---

## 35. Search and Filtering

Support:

- Contract number
- Invoice number
- Customer
- Property
- Employee
- Status
- Date range
- Value range where needed

Use Firestore indexes and pagination.

If true full-text search becomes necessary, add a dedicated search service later rather than distorting the primary data model.

---

## 36. Pagination

Use cursor-based Firestore pagination:

```text
limit()
startAfter()
```

Never load thousands of documents into the mobile client at once.

---

## 37. Offline Strategy

Offline persistence is appropriate for read-heavy use cases.

Allowed offline use:

```text
Read recent contracts
Read cached quotations
Read cached customers
Read archive
```

Operations that should require an online connection:

```text
Approve
Reject
Finalize
Archive
```

Submission may be restricted to online mode if business risk requires strict consistency.

---

## 38. Concurrency

Transactions or atomic precondition checks must protect sensitive transitions.

Example:

```text
Current status == PENDING_APPROVAL
        ↓
perform approval
        ↓
APPROVED
```

If another admin has already changed the state, the second operation must fail with a conflict/invalid-state response.

---

## 39. Numbering

Recommended logical counters:

```text
counters/contracts_2026
counters/quotations_2026
```

The generated number must be server-independent from a logical design perspective and must never be manually entered by the user.

For MVP, client-side Firestore transactions may manage the counter under strict Rules. The architecture must leave room for trusted server-side numbering later if stronger guarantees are required.

---

## 40. Firestore Security Rules

Rules must enforce:

- Authentication
- Active user status
- Role/permission checks
- Ownership or access checks
- Allowed state transitions
- Finalized immutability
- Protected audit logs
- Protected counters
- Field-level restrictions where necessary

A rule such as `request.auth != null` alone is insufficient.

---

## 41. Storage Security Rules

Validate:

- Authentication
- Resource ownership/access
- Allowed path
- Allowed file type
- Allowed size

Users must not be able to upload arbitrary files into unrestricted paths.

---

## 42. Repository Interfaces

Example:

```dart
abstract class ContractRepository {
  Future<Contract> createContract(CreateContractInput input);

  Future<Contract?> getContract(String id);

  Future<void> submitContract(String id);

  Future<void> approveContract(String id);

  Future<void> rejectContract(
    String id,
    RejectionInput input,
  );

  Future<void> finalizeContract(String id);

  Future<Contract> cloneContract(String id);
}
```

The repository implementation may use Firestore SDK directly.

---

## 43. Domain Use Cases

At minimum:

```text
CreateContract
SubmitContract
ApproveContract
RejectContract
FinalizeContract
ArchiveContract
CloneContract
```

Use cases should be independently testable.

---

## 44. Recommended Screens

### Authentication

```text
Splash
Login
Reset Password
```

### Employee

```text
Dashboard
Contracts List
Contract Details
Create Contract
Edit Contract
Rejection Review
Notifications
Profile
```

### Admin

```text
Dashboard
Approval Queue
Contract Review
Templates
Users
Audit
Notifications
Profile
```

---

## 45. Contract Creation UX

Recommended step-based flow:

```text
1. Customer
2. Property
3. Quotation / Invoice
4. Template
5. Clauses
6. Review
7. Submit
```

---

## 46. Contract Review UX

Review page should expose:

- Contract header
- Customer
- Property
- Quotation/invoice summary
- Financial summary
- Clauses
- Attachments
- Version
- Status
- Relevant audit information

Admin actions:

```text
Approve
Reject
```

Employee actions depend on state:

```text
Edit
Submit
Clone
```

---

## 47. Error Model

Standard application error codes:

```text
AUTH_REQUIRED
PERMISSION_DENIED
VALIDATION_ERROR
RESOURCE_NOT_FOUND
INVALID_STATE
CONFLICT
INVOICE_ERROR
STORAGE_ERROR
INTERNAL_ERROR
```

Flutter maps technical error codes to user-friendly messages.

---

## 48. Validation

Validation occurs at three levels:

```text
UI Validation
Backend/Domain Validation
Firestore Security Constraints
```

Never assume that client validation is enough.

---

## 49. Performance Requirements

The application should:

- Load only required records
- Use pagination
- Avoid N+1 Firestore reads
- Use cached data where appropriate
- Keep documents reasonably small
- Compress images before upload
- Avoid unnecessary rebuilds in Flutter
- Use indexed queries

---

## 50. Reliability Requirements

The system must handle:

- Network interruption
- Firebase timeout
- Duplicate button presses
- Concurrent updates
- Expired sessions
- Missing quotation/invoice records
- Permission changes
- Storage failures

Critical operations should be idempotent where practical.

---

## 51. Privacy Requirements

Sensitive information may include:

- Emirates ID
- Passport details
- Trade licence details
- Financial data

Access must be limited to authorized users. Do not expose unnecessary fields to clients.

---

## 52. Monitoring

Recommended production monitoring:

### Mobile

- Firebase Crashlytics
- Firebase Performance Monitoring

### Firebase

- Firestore error monitoring
- Storage failures
- Authentication failures
- FCM delivery/processing failures

When server-side functions are introduced, also use Cloud Logging and function monitoring.

---

## 53. CI/CD

Pipeline:

```text
Developer Push
      ↓
Pull Request
      ↓
Format
      ↓
Static Analysis / Lint
      ↓
Unit Tests
      ↓
Widget Tests
      ↓
Security Rules Tests
      ↓
Build
      ↓
Code Review
      ↓
Staging
      ↓
QA / UAT
      ↓
Human Approval
      ↓
Production
```

---

## 54. Flutter CI Checks

Example pipeline commands:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build appbundle
```

Run iOS builds in the release pipeline where the runner supports Apple tooling.

---

## 55. Security CI

Automated tests must include:

```text
Unauthenticated read
Unauthorized write
Employee approval attempt
Finalized contract modification
Audit-log tampering
Unauthorized Storage access
Cross-user access
```

---

## 56. Git Strategy

Recommended branches:

```text
main
develop
feature/*
bugfix/*
release/*
hotfix/*
```

Rules:

```text
main     = Production

develop  = Integration

feature/* = Feature implementation

release/* = Release candidate

hotfix/*  = Production fix
```

---

## 57. Commit Convention

Use:

```text
feat:
fix:
refactor:
test:
docs:
chore:
build:
ci:
```

Examples:

```text
feat: add contract approval workflow
fix: prevent duplicate finalization
test: add RBAC security tests
ci: add staging deployment workflow
```

---

## 58. Pull Request Policy

No direct merge to `main`.

A PR should require:

- CI green
- Code review
- Relevant tests
- Security checks
- No unresolved critical issues
- Documentation update when behavior changes

---

## 59. Semantic Versioning

Use:

```text
MAJOR.MINOR.PATCH
```

Examples:

```text
1.0.0
1.1.0
1.1.1
2.0.0
```

Use a separate build number for mobile packaging.

---

## 60. Release Tagging

Production releases must be tagged:

```text
v1.0.0
v1.1.0
v1.1.1
```

The deployed production build must be traceable to a Git commit and tag.

---

## 61. Feature Flags

Use feature flags where staged rollout is useful:

```text
notificationsEnabled
cloneEnabled
newApprovalUI
```

Avoid hiding unfinished functionality through ad-hoc conditionals scattered throughout the codebase.

---

## 62. Migration Strategy

Any schema change must have an explicit migration strategy.

```text
Schema V1
   ↓
Migration
   ↓
Schema V2
```

Production data must not be mutated randomly from the Flutter UI.

---

## 63. Backup and Recovery

Define and test:

- Firestore backup
- Storage backup
- Recovery procedure
- Data export
- Accidental deletion recovery

Define target RPO and RTO before production launch.

---

## 64. Testing Strategy

### Unit Tests

- State transitions
- Validation
- Permissions
- Snapshot logic
- Clone logic

### Widget Tests

- Forms
- Approval screens
- Rejection UI
- Loading/error states

### Integration Tests

```text
Login
→ Create Contract
→ Submit
→ Admin Review
→ Approve
→ Finalize
```

### Security Tests

Test rules and authorization independently from UI visibility.

---

## 65. Definition of Ready

A ticket is Ready only when:

- Requirement is understood
- UX flow is available where needed
- Data impact is identified
- Security impact is identified
- Acceptance criteria exist
- Dependencies are known

---

## 66. Definition of Done

A feature is Done only when:

- UI implemented
- Domain logic implemented
- Data access implemented
- Validation implemented
- Authorization implemented
- Tests added
- CI passed
- Code reviewed
- Staging verified
- Documentation updated where applicable

---

## 67. Recommended Jira Epics

```text
EPIC-01 Foundation & Authentication
EPIC-02 RBAC & Security
EPIC-03 Customers & Properties
EPIC-04 Contract Templates
EPIC-05 Contract Engine
EPIC-06 Approval Workflow
EPIC-07 Internal Quotation/Invoice Integration
EPIC-08 PDF & Finalization
EPIC-09 Documents & Archive
EPIC-10 Notifications & Dashboard
EPIC-11 QA & Security
EPIC-12 CI/CD & Production
```

---

## 68. Implementation Order

```text
0. Architecture
        ↓
1. Firebase / Environments
        ↓
2. Auth / Users / RBAC
        ↓
3. Customers / Properties
        ↓
4. Template Engine
        ↓
5. Contracts / Draft
        ↓
6. Approval Workflow
        ↓
7. Internal Quotation/Invoice Linking
        ↓
8. Finalization / PDF
        ↓
9. Notifications
        ↓
10. Dashboard / Search
        ↓
11. QA / Security
        ↓
12. Production
```

---

## 69. First Sprint Technical Baseline

Sprint 1 should establish the foundation rather than build every screen.

Deliverables:

```text
DEV Firebase project
STAGING Firebase project
PRODUCTION Firebase project

Flutter base architecture
Authentication
User model
RBAC model
Firestore Rules skeleton
Repository interfaces
CI pipeline
Basic unit testing
Basic security tests
```

---

## 70. Final Architecture Principle

```text
Flutter
│
├── UI / UX
├── State Management
├── Local Validation
└── Repository Calls
        │
        ▼
Firestore SDK / Firebase Services
        │
        ├── Firestore
        ├── Storage
        ├── Auth
        └── FCM
        │
        ▼
Firestore Security Rules
```

**Critical rule:** anything involving authorization, approval integrity, immutable final state, protected fields, numbering, or legally significant historical data must not rely on UI code alone.

---

## 71. Future Trusted Backend Extension

No trusted backend is mandatory in the current MVP architecture.

However, the boundaries must allow a future addition for:

- Guaranteed centralized numbering
- Server-side PDF generation
- Webhooks
- Scheduled jobs
- External integrations
- Stronger audit guarantees
- Sensitive business logic

Introducing such a backend later must not require rewriting the domain layer.

---

## 72. Final System Flow

```text
Customer
   ↓
Property
   ↓
Existing Quotation / Invoice
   ↓
Contract
   ↓
DRAFT
   ↓
PENDING_APPROVAL
   ↓
REJECTED ↔ DRAFT   (revision loop)
   ↓
APPROVED
   ↓
Final Snapshots
   ↓
PDF
   ↓
FINALIZED
   ↓
ARCHIVED
```

The final contract must always answer:

```text
Who created it?
Who modified it?
Who rejected it?
Why was it rejected?
Who approved it?
When was it finalized?
Which quotation/invoice produced the financial snapshot?
Which exact version was finalized?
```
