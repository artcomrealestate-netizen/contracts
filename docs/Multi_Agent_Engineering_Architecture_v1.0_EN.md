# Multi-Agent Engineering Architecture
## AI Development Team for the Contract & Document Management System

**Version:** 1.0 EN  
**Status:** Approved Operating Model  
**Operating Model:** Controlled Multi-Agent Engineering Organization  
**Orchestration:** Central Orchestrator + Dependency Graph + Parallel Workers + Sequential Gates + Human Approval  
**Target Project:** `qouta_calculator`

---

# 1. Purpose

This document defines the operating architecture for an AI engineering team that develops and maintains the contract and document management capability inside `qouta_calculator`.

The goal is not an uncontrolled agent swarm. The target model is a **controlled, auditable, role-based multi-agent engineering organization** in which every agent has:

- A defined role
- A clear mission
- Explicit responsibilities
- Explicit permissions
- Defined inputs and outputs
- Ticket ownership
- Artifact ownership
- Git boundaries
- Quality gates
- Escalation rules

---

# 2. Core Operating Model

```text
Human Product Owner
        ↓
Central Orchestrator
        ↓
Dependency Graph
        ↓
Specialized Agents
        ↓
Tickets / Artifacts / PRs
        ↓
Quality Gates
        ↓
Staging
        ↓
Human Approval
        ↓
Production
```

The agents collaborate through controlled artifacts and tickets rather than uncontrolled peer-to-peer conversation.

---

# 3. Team Structure

Recommended logical team: **9 agents**.

1. Orchestrator / Engineering Manager
2. Product / Business Analyst
3. Solution Architect
4. Flutter Mobile Engineer
5. Firebase / Backend Engineer
6. Security Engineer
7. QA / Test Engineer
8. DevOps / Release Engineer
9. Documentation / Knowledge Engineer

These are logical roles. They do not all need to run simultaneously.

The Orchestrator activates the minimum set of agents needed for each task.

---

# 4. Organization Structure

```text
                         HUMAN PRODUCT OWNER
                                  │
                                  ▼
                        ┌──────────────────┐
                        │   ORCHESTRATOR   │
                        │ Engineering Mgr  │
                        └────────┬─────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
      Product                Architecture               QA
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                ┌────────────────┴────────────────┐
                ▼                                 ▼
        Flutter Engineer                   Firebase Engineer
                │                                 │
                └────────────────┬────────────────┘
                                 ▼
                           Security Agent
                                 │
                                 ▼
                           DevOps Agent
                                 │
                                 ▼
                          Production Release
                                 │
                                 ▼
                         Knowledge / Docs
```

---

# 5. Agent 1 — Orchestrator / Engineering Manager

## Mission

The Orchestrator is the operational manager of the AI engineering team. It owns coordination, dependency management, progress tracking, quality gates, and escalation. It is not required to write the majority of application code.

## Responsibilities

- Read and enforce the TDD
- Read requirements and tickets
- Build the dependency graph
- Identify parallelizable work
- Identify sequential gates
- Assign tasks to specialized agents
- Track ticket state
- Detect conflicts
- Trigger reviews
- Trigger tests
- Block invalid work
- Escalate architectural decisions
- Coordinate releases
- Produce sprint status

## Inputs

```text
TDD
Requirements
User Stories
Tickets
Architecture Decisions
Pull Requests
Test Reports
Security Reports
Deployment Reports
```

## Outputs

```text
Task assignments
Dependency graph
Execution plan
Gate decisions
Escalations
Sprint status
Release recommendation
```

## Restricted Actions

The Orchestrator must not autonomously perform:

- Destructive production data migrations
- Security-rule weakening
- Major architecture changes
- Unreviewed production release

These require explicit human approval.

---

# 6. Agent 2 — Product / Business Analyst

## Mission

Translate business requirements into implementation-ready work.

## Responsibilities

- User stories
- Acceptance criteria
- Business rules
- Edge cases
- Prioritization proposals
- Definition of Ready
- Definition of Done
- Requirement gap analysis
- Product documentation

## Example

```text
As an Employee
I want to submit a completed contract
so that an Admin can review it.
```

Acceptance criteria:

```text
Given status = DRAFT
When Employee submits
Then status becomes PENDING_APPROVAL
And an approval task/notification is created for Admin
```

## Permissions

Read:

- Requirements
- TDD
- Tickets
- Product documentation

Write:

- User stories
- Acceptance criteria
- Business rules
- Product docs

No direct production-code ownership.

---

# 7. Agent 3 — Solution Architect

## Mission

Own architectural integrity and prevent implementation drift.

## Responsibilities

- Data model
- Repository boundaries
- State machine
- Firestore structure
- Security boundaries
- Architectural Decision Records (ADRs)
- Integration contracts inside the app
- Scalability decisions
- Architecture review of PRs that affect design

## Authority

The Architect may reject an implementation that violates the approved architecture.

Example:

```text
Flutter directly changes a FINALIZED contract
```

Expected decision:

```text
REJECT
Reason: violates immutable final-state architecture
```

---

# 8. Agent 4 — Flutter Mobile Engineer

## Mission

Implement the mobile application according to the domain, UX, and architecture contracts.

## Responsibilities

- Flutter screens
- Widgets
- Navigation
- Riverpod state management
- Form handling
- Repository integration
- Error states
- Offline-aware UX
- Notification UI
- Deep links
- Widget tests
- Mobile accessibility basics
- Performance-conscious rendering

## Must Not Own

- Firestore Security Rules policy
- Authorization authority
- Finalization policy
- Audit integrity policy

The agent consumes contracts defined by Product/Architect/Security.

---

# 9. Agent 5 — Firebase / Backend Engineer

## Mission

Implement Firestore-centered application logic within the current client-first architecture.

## Responsibilities

- Firestore collections
- Queries
- Transactions
- Repository implementations
- Firestore Security Rules
- Storage rules
- State transitions
- Snapshot logic
- Numbering
- Data validation
- FCM integration
- Firebase configuration
- Future backend extension points

## Current Architecture Constraint

No mandatory Cloud Functions layer is required for MVP.

When stronger server-side guarantees become necessary, the Backend Engineer may propose a dedicated trusted backend as a separately approved phase.

---

# 10. Agent 6 — Security Engineer

## Mission

Independently challenge the security assumptions made by other agents.

## Responsibilities

- Threat modeling
- Firestore Rules review
- Storage Rules review
- RBAC review
- Authentication review
- Privilege escalation testing
- Cross-user data access tests
- IDOR-style access checks
- Sensitive-field exposure checks
- Dependency security checks
- Secrets scanning recommendations

## Special Authority

The Security Agent can block a release on critical security findings.

Examples:

```text
Employee can approve a contract
Employee can edit finalized contract
User can read another user's restricted records
Client can alter audit actor metadata
```

---

# 11. Agent 7 — QA / Test Engineer

## Mission

Validate the system against requirements, architecture, business rules, and failure scenarios.

## Responsibilities

- Test plans
- Unit tests
- Widget tests
- Integration tests
- End-to-end tests
- Security test scenarios
- Regression suites
- Edge cases
- UAT support
- Release test reports

## Shift-left Principle

QA does not wait for the feature to be finished.

When Backend begins `approveContract`, QA should already create tests such as:

```text
approveContract_when_pending_should_succeed
approveContract_when_draft_should_fail
employee_should_not_approve
second_approval_should_fail
```

---

# 12. Agent 8 — DevOps / Release Engineer

## Mission

Own reproducible builds, environment separation, automated delivery, release traceability, and rollback readiness.

## Responsibilities

- Git strategy
- CI pipelines
- CD pipelines
- DEV / STAGING / PROD
- Build signing
- Secrets handling
- Release tags
- Versioning
- Deployment automation
- Monitoring integration
- Rollback procedures
- Artifact retention

---

# 13. Agent 9 — Documentation / Knowledge Engineer

## Mission

Keep project knowledge synchronized with the actual system.

## Responsibilities

- TDD maintenance
- ADR maintenance
- API/repository documentation
- README
- Change log
- Release notes
- Developer onboarding docs
- Decision records
- Knowledge consistency checks

This role prevents documentation drift after repeated AI-generated changes.

---

# 14. Agent Permission Model

Agents should use least privilege.

Recommended logical permission matrix:

| Capability | Orchestrator | Product | Architect | Flutter | Firebase | Security | QA | DevOps | Docs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Read TDD | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write product docs | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Write architecture docs | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ |
| Edit Flutter app | Controlled | ❌ | Review | ✅ | ❌ | ❌ | Tests | ❌ | ❌ |
| Edit Firebase | Controlled | ❌ | Review | ❌ | ✅ | Review | Tests | ❌ | ❌ |
| Edit Security Rules | Review | ❌ | Review | ❌ | ✅ | ✅ | Tests | ❌ | ❌ |
| Write tests | Review | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Deploy staging | ✅ | ❌ | Review | ❌ | Controlled | Approval | ✅ | ✅ | ❌ |
| Deploy production | Human gated | ❌ | Approval | ❌ | Controlled | Approval | Pass | ✅ | ❌ |

"Controlled" means the Orchestrator coordinates the action but the underlying tool should still enforce scope and environment restrictions.

---

# 15. Git Permissions by Area

Recommended path ownership:

```text
Flutter Agent
    app/**

Firebase Agent
    functions/**      (when introduced)
    firestore/**
    storage/**

QA Agent
    tests/**

DevOps Agent
    .github/**
    deployment/**

Architect
    docs/architecture/**
    docs/adr/**

Product
    docs/product/**

Documentation Agent
    docs/**
    CHANGELOG.md
    README.md
```

A real implementation may use CODEOWNERS to formalize review boundaries.

---

# 16. Ticket Architecture

Every unit of work must be represented as a ticket.

Recommended fields:

```text
Ticket ID
Title
Type
Description
Owner Agent
Priority
Status
Dependencies
Acceptance Criteria
Technical Notes
Artifacts
PR
Tests
Security Review
Environment
Release
```

---

# 17. Ticket Types

```text
EPIC
STORY
TASK
BUG
SPIKE
SECURITY
ARCHITECTURE
DEVOPS
```

Examples:

```text
AUTH-001 — Configure Firebase Authentication
RBAC-002 — Implement Employee/Admin permissions
CTR-015 — Implement contract state machine
CTR-016 — Implement rejection feedback
INV-004 — Link contract to sourceQuotationId
QA-022 — Add approval workflow E2E test
SEC-011 — Validate finalized contract immutability
CI-005 — Add staging deployment workflow
```

---

# 18. Ticket Lifecycle

```text
BACKLOG
  ↓
READY
  ↓
ASSIGNED
  ↓
IN_PROGRESS
  ↓
CODE_REVIEW
  ↓
QA
  ↓
SECURITY_REVIEW (when required)
  ↓
STAGING
  ↓
ACCEPTED
  ↓
DONE
```

Failure states:

```text
BLOCKED
REJECTED
CHANGES_REQUESTED
```

---

# 19. Definition of Ready for Tickets

A ticket may become `READY` only when:

- Business intent is clear
- Acceptance criteria exist
- Technical dependencies are identified
- Required artifacts exist
- Owner role is known
- Security impact is known
- Environment requirements are known

---

# 20. Definition of Done for Tickets

A ticket is `DONE` only when:

```text
Implementation complete
Tests complete
Security requirements satisfied
CI green
PR approved
Staging verified
Documentation updated when required
```

---

# 21. Artifact-Driven Collaboration

Agents should exchange durable artifacts, not vague chat messages.

Examples:

### Product Agent

```text
requirements/
user-stories/
acceptance-criteria/
```

### Architect

```text
architecture/
data-model/
adr/
workflow/
```

### Flutter

```text
app/
```

### Firebase

```text
firestore/
storage/
```

### QA

```text
tests/
test-reports/
```

### DevOps

```text
.github/
deployment/
```

### Docs

```text
docs/
CHANGELOG.md
```

---

# 22. Communication Model

Avoid uncontrolled direct agent-to-agent messaging.

Preferred pattern:

```text
Agent A
   ↓
deliverable artifact
   ↓
Orchestrator
   ↓
Agent B
```

Example:

```text
Architect
   ↓
approval-workflow.md
   ↓
Orchestrator
   ↓
Backend + Flutter + QA
```

This creates traceability and reduces conflicting interpretations.

---

# 23. Shared Project Memory

The primary source of truth should be the repository and ticket system, not conversation history.

The team should persist:

```text
TDD
ADRs
Requirements
Tickets
API/repository contracts
Test reports
PRs
Release notes
```

Agents should reconstruct context from these sources before making significant changes.

---

# 24. Parallel vs Sequential Execution

The system uses a **hybrid orchestration model**.

### Parallel

Use parallel execution when tasks are independent.

Example:

```text
Product requirements
UX exploration
Architecture review
QA test planning
Security threat analysis
```

These can happen in parallel when they do not depend on one another's output.

### Sequential

Use sequential execution when an artifact is a dependency.

Example:

```text
Define contract
    ↓
Approve repository/data contract
    ↓
Backend implementation
    ↓
Flutter integration
    ↓
QA execution
```

---

# 25. Dependency Graph

The Orchestrator builds a graph such as:

```text
TDD
 │
 ├── RBAC
 │
 ├── Data Model
 │      │
 │      └── Firestore
 │
 ├── Repository Contracts
 │      │
 │      ├── Firebase implementation
 │      └── Flutter integration
 │
 ├── State Machine
 │      │
 │      ├── Backend/Firebase rules
 │      │      ├── Flutter state handling
 │      │      └── QA scenarios
 │
 └── CI/CD
```

Each node can be:

```text
READY
BLOCKED
IN_PROGRESS
DONE
FAILED
```

---

# 26. Orchestration Rules

The Orchestrator should decide based on dependencies, not on a fixed always-parallel or always-sequential rule.

### Start parallel work when:

- Inputs are stable
- There is no write conflict
- The task does not depend on another task's artifact

### Start sequential work when:

- A contract/specification must be approved first
- Two agents would modify the same source of truth
- A build depends on a schema/API change
- QA requires an implementation before execution
- Deployment depends on successful validation

---

# 27. Example: Approval Workflow Feature

User request:

```text
Implement contract approval workflow.
```

### Step 1 — Orchestrator

Creates epic/story/task breakdown.

### Step 2 — Parallel discovery

Product Agent:

```text
User stories
Business rules
Acceptance criteria
```

Architect:

```text
State machine
Data changes
Repository contract
```

Security:

```text
Authorization matrix
Threat model
```

QA:

```text
Test cases
```

### Step 3 — Architecture gate

Architect confirms the interfaces and boundaries.

### Step 4 — Parallel implementation

```text
Flutter Agent    → Approval / rejection UI
Firebase Agent   → Firestore structure / transitions / rules
QA Agent         → Automated tests
Docs Agent       → Technical documentation
```

### Step 5 — Security review

Security validates privilege boundaries.

### Step 6 — Staging

DevOps deploys staging.

### Step 7 — E2E

QA executes the complete workflow.

### Step 8 — Release gate

Orchestrator recommends release only if all required gates pass.

### Step 9 — Human approval

Human approves production deployment.

---

# 28. Collaboration Protocol

Each agent task should follow:

```text
RECEIVE
   ↓
UNDERSTAND
   ↓
CHECK DEPENDENCIES
   ↓
IMPLEMENT / ANALYZE
   ↓
TEST
   ↓
PRODUCE ARTIFACT
   ↓
REPORT
```

Agent report should contain:

```text
Completed
Changed files
Tests run
Results
Known risks
Open questions
Next dependency
```

---

# 29. Agent Handover Format

Recommended structured handover:

```yaml
status: completed
result: success
ticket: CTR-015
artifacts:
  - docs/workflow/approval-state-machine.md
  - firestore/rules/contracts.rules
changed_areas:
  - contract workflow
  - security rules
tests:
  - approval_transition_test
  - unauthorized_approval_test
risks:
  - direct-client audit integrity remains MVP limitation
next:
  - QA E2E
```

---

# 30. Human-in-the-Loop Gates

Human approval is mandatory for:

- Major architecture changes
- Security exceptions
- Production release
- Destructive production migration
- Removing or weakening authorization
- Changing immutable-data policy
- Introducing external integrations
- Major schema migrations

The pattern is:

```text
Agent prepares
   ↓
Agent validates
   ↓
Agent proposes
   ↓
Human approves
   ↓
Agent executes
```

---

# 31. Production Safety Model

Agents should have environment-specific permissions.

### Development

Broadest permissions.

### Staging

Controlled deployment permissions.

### Production

Human-gated deployment.

Production credentials must never be placed in agent prompts, source code, or repository text.

---

# 32. Git Workflow

```text
main
 ↑
release/*
 ↑
develop
 ↑
feature/* / bugfix/*
```

Agent flow:

```text
Take Ticket
   ↓
Create branch
   ↓
Implement
   ↓
Test
   ↓
Commit
   ↓
Open PR
   ↓
Review
   ↓
Merge
```

---

# 33. Branch Naming

Examples:

```text
feature/rbac
feature/contract-workflow
feature/template-engine
feature/notifications
feature/contract-clone

bugfix/duplicate-finalization
bugfix/contract-pagination

hotfix/security-rule-issue
```

---

# 34. Commit Convention

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
fix: block editing of finalized contracts
test: add employee approval security tests
ci: add staging deployment pipeline
```

---

# 35. Pull Request Protocol

Every PR should state:

```text
Ticket
Problem
Solution
Files changed
Tests
Security impact
Migration impact
Rollback considerations
```

The PR should not be merged when mandatory CI checks fail.

---

# 36. Review Matrix

### Standard feature

```text
Implementer
→ QA
→ Reviewer
→ Merge
```

### Security-sensitive feature

```text
Implementer
→ Security
→ QA
→ Architect (if architectural)
→ Merge
```

### Production release

```text
CI
→ QA
→ Security (when applicable)
→ DevOps
→ Human approval
→ Production
```

---

# 37. Quality Gates

## Gate 1 — Requirements

Acceptance criteria complete.

## Gate 2 — Architecture

Repository/data/state boundaries approved.

## Gate 3 — Implementation

Code compiles and local tests pass.

## Gate 4 — Security

Required authorization tests pass.

## Gate 5 — QA

Functional and regression tests pass.

## Gate 6 — Staging

UAT scenario passes.

## Gate 7 — Release

Human approval for production.

---

# 38. Multi-Agent QA Example

For `approveContract`:

### Product Agent
Defines expected business behavior.

### Architect
Defines allowed state transition.

### Firebase Agent
Implements Firestore write/rules.

### Flutter Agent
Implements approval UX.

### Security Agent
Attempts unauthorized approval.

### QA Agent
Runs positive, negative, concurrency, and regression tests.

### DevOps Agent
Deploys the validated build to staging.

The Orchestrator coordinates the sequence.

---

# 39. Ticket Dependency Example

```text
RBAC-001
   ↓
CTR-010 Contract Model
   ↓
CTR-015 Approval Workflow Contract
   ├───────────────┐
   ↓               ↓
CTR-016       CTR-017
Flutter UI     Firebase Rules
   └───────┬───────┘
           ↓
       QA-022 E2E
           ↓
       SEC-011 Review
           ↓
       CI / Staging
           ↓
       Release Gate
```

---

# 40. Conflict Resolution

If two agents propose different implementations:

```text
Agent A Proposal
Agent B Proposal
        ↓
Orchestrator identifies conflict
        ↓
Architect evaluates technical impact
        ↓
Product evaluates business impact if needed
        ↓
Security evaluates risk if needed
        ↓
Decision recorded as ADR or ticket decision
```

The agents must not silently diverge.

---

# 41. Change Management

Any change affecting:

- Data model
- Workflow
- Security rules
- Immutable behavior
- Repository contracts
- Environment configuration
- Release process

must be tracked in a ticket.

Major architecture changes require an ADR.

---

# 42. Knowledge Management

The Documentation Agent should update documentation from merged changes, not from speculative work.

Recommended sources:

```text
TDD
ADR
README
CHANGELOG
Release notes
Ticket decisions
```

The goal is that a new agent can reconstruct the system without reading old chat history.

---

# 43. Agent Runtime Strategy

Do not run all agents continuously.

### Architecture phase

```text
Orchestrator
Product
Architect
Security
QA
```

### Implementation phase

```text
Orchestrator
Flutter
Firebase
QA
Security
Docs
```

### Release phase

```text
Orchestrator
QA
Security
DevOps
Docs
```

This reduces cost, context pollution, and unnecessary contention.

---

# 44. Controlled Parallelism

Parallel workers should not modify the same source files or schema definition simultaneously unless explicitly coordinated.

Prefer:

```text
Flutter UI
Firebase rules
QA tests
Documentation
```

in parallel.

Avoid:

```text
Two agents editing the same repository class
Two agents changing the same Firestore schema
Two agents changing the same workflow definition
```

unless a merge plan exists.

---

# 45. Orchestrator State Model

The Orchestrator maintains a project state such as:

```text
Task State:
READY
BLOCKED
IN_PROGRESS
REVIEW
FAILED
DONE

Agent State:
IDLE
WORKING
WAITING
BLOCKED
FAILED
```

Example:

```yaml
ticket: CTR-015
state: IN_PROGRESS
owner: firebase-agent
dependencies:
  - RBAC-002: done
  - CTR-010: done
parallel:
  - flutter-agent
  - qa-agent
next_gate: security_review
```

---

# 46. Orchestrator Decision Rules

The Orchestrator should ask:

1. Is the ticket Ready?
2. What dependencies exist?
3. Which agents can safely work in parallel?
4. Which artifact is the next required contract?
5. Which review gates apply?
6. Does the change require human approval?
7. Is the current environment safe for this action?

---

# 47. Recommended Initial Team Activation

At project start:

### Phase 0 — Architecture

```text
Orchestrator
Product
Architect
Security
QA
DevOps
Docs
```

### Phase 1 — Foundation

```text
Orchestrator
Firebase
Flutter
Security
QA
DevOps
Docs
```

### Phase 2 — Contract Engine

```text
Orchestrator
Architect
Flutter
Firebase
QA
Security
Docs
```

### Phase 3 — Finalization

```text
Orchestrator
Flutter
Firebase
QA
Security
DevOps
Docs
```

---

# 48. Recommended Jira / Linear Structure

```text
EPIC: Foundation & Authentication
EPIC: RBAC & Security
EPIC: Customers & Properties
EPIC: Contract Templates
EPIC: Contract Engine
EPIC: Approval Workflow
EPIC: Internal Quotation/Invoice Linking
EPIC: PDF & Finalization
EPIC: Documents & Archive
EPIC: Notifications & Dashboard
EPIC: QA & Security
EPIC: CI/CD & Production
```

Each Epic is decomposed into Stories, Tasks, Bugs, Spikes, Security reviews, and DevOps work.

---

# 49. Example Detailed Tickets

## AUTH-001 — Firebase Authentication

**Owner:** Firebase + Flutter  
**Priority:** Critical  
**Dependencies:** Architecture baseline

Acceptance criteria:

- Valid user can log in
- Invalid credentials fail cleanly
- Disabled user cannot access the application
- Session restoration works
- Logout clears application state

---

## RBAC-001 — Employee/Admin Model

**Owner:** Firebase  
**Reviewers:** Security, Architect

Acceptance criteria:

- Employee role exists
- Admin role exists
- Permissions are explicit
- Unauthorized actions are rejected by Rules

---

## CTR-010 — Contract Domain Model

**Owner:** Architect + Firebase + Flutter

Acceptance criteria:

- Contract schema documented
- Status enum fixed
- Customer/property/sourceQuotation references defined
- Clause schema defined
- Snapshot model defined

---

## CTR-015 — Approval State Machine

**Owner:** Firebase  
**Reviewers:** Architect, Security, QA

Acceptance criteria:

```text
DRAFT → PENDING_APPROVAL
PENDING_APPROVAL → APPROVED
PENDING_APPROVAL → REJECTED
REJECTED → DRAFT
APPROVED → FINALIZED
```

Illegal transitions fail.

---

## CTR-016 — Approval UI

**Owner:** Flutter

Acceptance criteria:

- Admin sees approval actions
- Employee does not see approval actions
- Status is clearly displayed
- Rejection feedback is visible
- Locked/finalized contract is read-only

---

## CTR-017 — Clause-Level Rejection

**Owner:** Firebase + Flutter  
**Reviewers:** Product, QA

Acceptance criteria:

- Admin can add general note
- Admin can add clause-specific note
- Employee can identify affected clauses
- Resubmission clears/updates review state correctly

---

## INV-004 — Internal Quotation Linking

**Owner:** Flutter + Firebase

Acceptance criteria:

- Contract can reference `sourceQuotationId`
- Quotation is read through repository boundary
- No REST integration is introduced
- Final financial snapshot is preserved

---

## SEC-011 — Finalized Immutability

**Owner:** Security

Acceptance criteria:

- Employee cannot edit finalized contract
- Admin cannot casually edit finalized content
- Financial snapshot cannot be modified
- Final PDF reference cannot be overwritten by unauthorized client writes

---

## QA-022 — Approval Workflow E2E

**Owner:** QA

Flow:

```text
Create Draft
→ Submit
→ Admin Review
→ Reject
→ Revise
→ Resubmit
→ Approve
→ Finalize
```

---

## CI-005 — Staging Pipeline

**Owner:** DevOps

Acceptance criteria:

- PR checks run automatically
- Failed CI blocks merge
- Staging deployment is reproducible
- Version/tag is traceable

---

# 50. Production Release Workflow

```text
Feature branches
      ↓
Pull Requests
      ↓
CI
      ↓
Code Review
      ↓
develop
      ↓
release branch
      ↓
Staging
      ↓
QA / Security
      ↓
UAT
      ↓
Human Approval
      ↓
Production
      ↓
Git Tag
      ↓
Monitoring
```

---

# 51. Release Rollback

The team must be able to:

- Identify the deployed Git tag
- Identify the build number
- Re-deploy the last known-good backend configuration
- Roll back a mobile release where platform capabilities allow it
- Disable an introduced feature with a feature flag where appropriate

Database changes must be backward-compatible before rollout whenever possible.

---

# 52. Observability for Agents

The Orchestrator should maintain:

```text
Ticket throughput
Failed tasks
Blocked dependencies
PR cycle time
Test failure rate
Security finding count
Release success rate
Agent execution cost / usage
```

These metrics help optimize the agent team itself.

---

# 53. Agent Failure Handling

When an agent fails:

```text
Agent Failure
     ↓
Capture logs / result
     ↓
Retry if transient
     ↓
Reassign if capability issue
     ↓
Escalate if dependency issue
     ↓
Human decision if required
```

Do not endlessly retry the same failed operation without changing the context or strategy.

---

# 54. Agent Context Policy

Every task context should include the minimum required set:

```text
Relevant TDD sections
Relevant ADRs
Ticket
Acceptance criteria
Dependencies
Relevant files
Current test status
Security constraints
```

Do not send the entire repository context to every agent unnecessarily.

---

# 55. Agent Output Policy

Every agent should return structured information:

```text
Summary
Files changed
Artifacts produced
Tests executed
Test status
Risks
Assumptions
Recommended next step
```

This makes orchestration deterministic.

---

# 56. No-Swarm Rule

This project should **not** use unrestricted swarm behavior where every agent can:

- Edit any file
- Change architecture
- Deploy anything
- Change security rules
- Modify production data
- Communicate without traceability

The project requires governed collaboration.

---

# 57. Operating Model Summary

The recommended model is:

```text
Controlled Multi-Agent Engineering

                 HUMAN
                   │
                   ▼
             ORCHESTRATOR
                   │
          Dependency Graph
                   │
        ┌──────────┼──────────┐
        │          │          │
      Product   Architect     QA
        │          │          │
        └──────────┼──────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
     Flutter             Firebase
         │                   │
         └─────────┬─────────┘
                   ▼
               Security
                   │
                   ▼
                DevOps
                   │
                   ▼
             Production
```

The actual scheduling model is:

```text
Orchestrator
+
Dependency Graph
+
Parallel Workers
+
Sequential Quality Gates
+
Human Approval
```

---

# 58. Final Principle

The AI team should behave like a small professional engineering organization, not like a collection of chatbots.

Every change must have:

```text
An owner
A ticket
A dependency graph
A defined artifact
A test strategy
A security boundary
A review path
A release path
A traceable Git history
```

The objective is to make the system **repeatable, auditable, recoverable, and scalable** while keeping the human responsible for product decisions and high-risk production actions.
