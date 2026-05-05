---
description: >
  Implement an Azure DevOps work item end-to-end.
  Fetches the work item, runs a quality gate, shows an implementation plan,
  writes code and tests, updates ADO state, and opens a PR linked to the work item.

  Usage:
    /implement 1234 --project "IRIS" --team "IRIS Team"
    /implement 1234 --project "VCS"  --team "VCS team"
    /implement 1234 --project "IRIS" --team "IRIS Team" --branch "feature/my-custom-branch"
    /implement 1234 --project "IRIS" --team "IRIS Team" --skip-check

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Supported work item types:
    User Story · Enhancement · Business Requirement
    Prod Bug · Regression Bug · UAT Bug · Test Bug

  Flags:
    --project      Required. ADO project name
    --team         Required. ADO team name
    --branch       Optional. Custom branch name override
    --skip-check   Optional. Skip the /check quality gate (use with caution)

  Tech stack:
    Frontend:  React
    Backend:   Node.js on Azure PaaS
    Pipelines: Azure DevOps
    Tests:     Jest (frontend + backend)

  Branch naming defaults:
    Stories / Enhancements / BRs: feature/[id]-[short-title]
    All Bug types:                 bugfix/[id]-[short-title]
    Short title = first 5 words of work item title, lowercased, hyphenated

  Quality gate:
    Runs /check scoring before starting. Blocks if NOT READY (3+ Red dimensions).
    NEEDS WORK → warns but allows developer to proceed with confirmation.
    READY      → proceeds automatically.
---

Use the Azure DevOps MCP tools and codebase tools to implement a single work item
end-to-end, following the team's React / Node.js / Azure PaaS stack.

---

### 1. Parse arguments

Extract from `$ARGUMENTS`:

| Input          | Required | Description                                              |
|----------------|----------|----------------------------------------------------------|
| Ticket ID      | ✅ Yes   | Work item ID (numeric, e.g. 1234 — also accepts AB#1234)  |
| `--project`    | ✅ Yes   | ADO project name                                         |
| `--team`       | ✅ Yes   | ADO team name                                            |
| `--branch`     | ❌ No    | Custom branch name. Overrides default naming convention. |
| `--skip-check` | ❌ No    | Skip quality gate. Proceed directly to planning.         |

If work item ID is missing:

~~~
❓ Which work item should I implement?

Usage: /implement [id] --project "ProjectName" --team "TeamName"

Examples:
  /implement 1234 --project "IRIS" --team "IRIS Team"
  /implement 1234 --project "VCS"  --team "VCS team"
~~~

If `--project` or `--team` is missing:

~~~
❌ Missing required arguments.

Usage: /implement [id] --project "ProjectName" --team "TeamName"

Supported projects:
  /implement [id] --project "IRIS" --team "IRIS Team"
  /implement [id] --project "VCS"  --team "VCS team"
~~~

---

### 2. Fetch the work item

Call `wit_get_work_item` with the parsed ID.
First read `[System.WorkItemType]` to determine type and field set.

---

#### 📋 User Story / Enhancement / Business Requirement — fetch:
- `[System.Title]`
- `[System.State]`
- `[System.AssignedTo]`
- `[System.Description]`
- `[Microsoft.VSTS.Common.AcceptanceCriteria]`
- `[Microsoft.VSTS.Scheduling.StoryPoints]`
- `[Microsoft.VSTS.Common.Priority]`
- `[System.Parent]` + parent title
- `[System.IterationPath]`
- Linked Tasks, Subtasks, Test Cases
- Tags / comments

---

#### 🐛 Prod Bug / Regression Bug / UAT Bug / Test Bug — fetch:
- `[System.Title]`
- `[System.State]`
- `[System.AssignedTo]`
- `[System.Description]`
- `[Microsoft.VSTS.TCM.ReproSteps]`
- `[Microsoft.VSTS.TCM.SystemInfo]` or comments — actual results
- `[Microsoft.VSTS.Common.AcceptanceCriteria]` — expected results
- `[Microsoft.VSTS.Common.Priority]`
- `[Microsoft.VSTS.Common.Severity]`
- `[System.Parent]` + parent title
- `[System.IterationPath]`
- Linked Test Cases, related items

---

#### ⛔ Unsupported type — stop:

~~~
⚠️ Ticket ID [id] is a [WorkItemType] — /implement only supports:
   User Story · Enhancement · Business Requirement
   Prod Bug · Regression Bug · UAT Bug · Test Bug

   Tasks are implemented as part of their parent story.
   Try: /implement [parent id] --project "[--project]" --team "[--team]"
~~~

---

### 2b. Dependency check

After fetching the work item, inspect its linked items for blocking dependencies.

Look for links with relationship types:

- `System.LinkTypes.Dependency-Reverse` (Predecessor / Blocked By)
- Any linked item tagged or titled with "blocks", "predecessor", or "depends on"

For each linked predecessor, call `wit_get_work_item` to fetch its current state.

**If any predecessor is in a pre-completion state** (To Do, On Hold, Waiting for Requirements, Blockers, In Progress, In Code Review):

~~~
⚠️ Dependency Warning — Ticket ID [id] has unresolved dependencies:

  Ticket ID [dep-id]  "[Title]"  →  State: [State]
  Ticket ID [dep-id]  "[Title]"  →  State: [State]

These items must be completed before this story can safely be implemented.

Options:
  1. Reply "proceed anyway" — I'll continue but flag this risk in the PR description.
  2. Reply "stop" — implement the dependency first, then return to this story.
~~~

Wait for explicit reply before continuing.

**If "proceed anyway":** add a risk note to the PR description: "⚠️ Implemented ahead of dependency: Ticket ID [dep-id] ([State]) — verify integration once dependency is complete."

**If no blocking dependencies found:** continue silently to the quality gate.

---

### 3. Quality gate (unless --skip-check)

Run the /check scoring rubric (same 8 dimensions as /refine and /check).

~~~
✅ READY      → proceed automatically
⚠️ NEEDS WORK → show score + warn + ask confirmation to proceed
❌ NOT READY  → show score + block + do not proceed
~~~

**NEEDS WORK — ask confirmation:**

~~~
⚠️ Ticket ID [id] scored NEEDS WORK ([N] Amber · [N] Red dimensions).
   Proceeding may lead to rework if requirements change.

   Issues found:
     🟡 D4 — No linked tasks
     🟡 D5 — No linked test cases

   Do you want to proceed anyway? Reply "yes" to continue or "no" to fix first.
~~~

**NOT READY — block:**

~~~
❌ Ticket ID [id] is NOT READY for implementation ([N] Red dimensions).
   Development cannot start until these are resolved:
     🔴 D1 — No acceptance criteria
     🔴 D3 — No description
     🔴 D7 — No DoR sign-off

   Fix these first, then re-run /check:
   /check [id] --project "[--project]" --team "[--team]"
~~~

**If --skip-check:**

~~~
⚠️ Quality gate skipped (--skip-check used).
   Run /check [id] --project "[--project]" --team "[--team]" separately if needed.
~~~

---

### 4. Inspect the codebase

Before planning, inspect the codebase for patterns, structure, and conventions.

**React frontend:**
- Component folder structure (`src/components/`, `src/pages/` etc.)
- State management pattern (Redux, Context API, Zustand etc.)
- Styling approach (CSS modules, Tailwind, styled-components etc.)
- Component naming conventions
- Test file location pattern and Jest + React Testing Library setup
- Relevant existing components for the feature area

**Node.js backend:**
- Project structure (`src/routes/`, `src/controllers/`, `src/services/` etc.)
- API pattern (REST, Express middleware structure)
- Error handling conventions
- Async pattern (async/await vs Promise chains)
- Azure PaaS config (App Service, Functions, environment variables)
- Test file location and Jest configuration

**Both:**
- `package.json` test script (`npm test` or `npx jest`)
- ESLint / Prettier config for code style
- `.env.example` for environment variable patterns
- `azure-pipelines.yml` for CI/CD pipeline awareness

Store findings as `codebaseContext` to inform plan and implementation.

---

### 5. Build and show implementation plan

Show the plan and wait for confirmation before writing any code.

~~~
📋 Implementation Plan — Ticket ID [id]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[WorkItemType]: "[Title]"
Project: [--project]  |  Sprint: [Iteration Name]
Parent:  [Parent Title]  (Ticket ID [parent id])
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Approach:
  [2–3 sentence summary of how the feature/fix will be implemented,
   referencing existing patterns found in Step 4]

Branch:
  [feature/[id]-short-title  OR  bugfix/[id]-short-title]
  [or --branch override value if provided]

Files to create or modify:
  ✏️  [file path]  — [new component / update route / add service etc.]
  ✏️  [file path]  — [reason]
  ✏️  [file path]  — [reason]

Tests to write:
  🧪  [test file path]  — [what will be tested]
  🧪  [test file path]  — [what will be tested]

Acceptance criteria coverage:
  AC 1: "[AC text]"  → covered by [test file / component]
  AC 2: "[AC text]"  → covered by [test file / component]
  AC 3: "[AC text]"  → covered by [test file / component]

Documentation updates:
  📝  [file]  — [what will be updated]
  — None required  ← if no docs needed

Estimated effort: [X]pt (~[X]h)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Confirm? Reply "yes" to start or "no" to adjust the plan.
~~~

Wait for explicit "yes" before writing any code.

---

### 6. Set work item to In Progress, then create the feature branch

#### 6a — Set In Progress before writing any code

Immediately after plan confirmation, call `wit_update_work_item` for the story:

- `[System.State]` = `In Progress`

Then fetch any child Tasks or Subtasks linked via `System.LinkTypes.Hierarchy.Forward`:

- Call `wit_update_work_item` for each child: `[System.State]` = `In Progress`

~~~
▶️ Ticket ID [id] → In Progress
   Child items: [N] Tasks / Subtasks → In Progress
   (or "No child items linked")
~~~

If the state transition is rejected (e.g. the item is already Closed or not a valid transition), stop and tell the user — do not silently continue.

#### 6b — Create the feature branch

**Default naming:**
~~~
Stories / Enhancements / BRs:  feature/[id]-[short-title]
All Bug types:                  bugfix/[id]-[short-title]

Short title rules:
  - First 5 words of work item title
  - Lowercase, hyphen-separated
  - Strip special characters

Examples:
  "Add login page for admin users"  →  feature/1234-add-login-page-for-admin
  "Fix null pointer on checkout"    →  bugfix/5678-fix-null-pointer-on-checkout
~~~

If `--branch` is provided → use that value exactly.
Create from `main` (or `develop` if that is the default branch).

~~~
🌿 Branch created: [branch-name]  (from main)
~~~

---

### 7. Write the implementation

Follow codebaseContext patterns from Step 4.

**React standards:**
- Functional components with hooks only — no class components
- Follow existing folder, file, and export naming conventions
- Use existing state management pattern — do not introduce new ones
- Follow existing styling approach exactly
- Add PropTypes or TypeScript types if existing code uses them
- No inline styles unless already present in codebase

**Node.js standards:**
- Follow existing route / controller / service separation
- Use existing error handling middleware — no new patterns
- Follow existing async/await pattern throughout
- Use environment variables for all Azure PaaS config — never hardcode
- Follow existing logging approach

**Both:**
- Match ESLint / Prettier formatting exactly
- Follow existing import order
- Write self-documenting code — comments only for non-obvious logic
- No TODO or placeholder comments in committed code

---

### 8. Write and verify tests

**React (Jest + React Testing Library):**
- Component renders without errors
- All AC interactions tested
- Edge cases: empty state, error state, loading state
- User interactions: clicks, form inputs, navigation
- Use `screen.getByRole`, `userEvent` — avoid `getByTestId` unless already in codebase
- Follow existing test file location pattern

**Node.js (Jest):**
- All new routes/endpoints: happy path + error cases
- Service layer logic: unit tests
- Mock external Azure services and DB calls
- Follow existing mock pattern
- All AC scenarios that are backend-driven

**Execute the test suite using Bash — this is mandatory, not optional:**

~~~bash
npm test -- --watchAll=false --coverage
~~~

Use `--watchAll=false` so Jest exits instead of entering watch mode.
If no `npm test` script exists, fall back to: `npx jest --watchAll=false --coverage`

**Interpret the output:**

All passing:
~~~
✅ [N] tests passing · 0 failing
   Coverage: Statements X% · Branches X% · Functions X% · Lines X%
~~~
→ Capture the coverage summary — it goes into the PR description. Proceed to Step 9.

Any failures:
~~~
🔴 [N] tests failing — fixing before proceeding.
   Failing: [list of test file names / test names]
~~~
→ Fix the implementation (never rewrite tests to mask a bug). Re-run. Repeat until green.
**Do not open a PR with failing tests. This rule has no exceptions.**

Test environment broken (missing env var, missing module, config error):
~~~
⚠️ Test suite could not run: [error message]
   Likely cause: [missing dependency / env var not set]
   Please resolve, then I will re-run before continuing.
~~~
→ Stop and ask the user. Do not proceed to PR.

Zero tests collected (no test files found):
~~~
⚠️ No tests found — writing tests for new code now before proceeding.
~~~
→ Write the tests, re-run, confirm green before moving on.

**Regression gate:** every test that was passing before this implementation must still pass. A regression anywhere in the suite is a blocker, not just failures in the new test files.

---

### 9. Update documentation

Update only if relevant:
- `README.md` — new setup step, env var, or major feature
- API docs / Swagger — new or changed endpoint
- Inline JSDoc — new utility functions or complex logic
- `CHANGELOG.md` — if project uses one

If nothing needed → "No documentation updates required."

---

### 10. Update ADO work item state to In Code Review

Call `wit_update_work_item` for the story:

- `[System.State]` = `In Code Review`

Then update every linked child Task or Subtask:

- Call `wit_update_work_item` for each child: `[System.State]` = `In Code Review`

~~~
📋 Ticket ID [id] state updated: In Progress → In Code Review
   Child items: [N] Tasks / Subtasks → In Code Review
   (or "No child items linked")
~~~

---

### 11. Open the Pull Request

~~~
Title:
  [WorkItemType] Ticket ID [id]: [Work item title]
  Examples:
    "User Story Ticket ID 1234: Add login page for admin users"
    "Bug Fix Ticket ID 5678: Fix null pointer on checkout page"

Description:

## Summary
[2–3 sentences: what was implemented and why]

## Work Item
Closes Ticket ID [id] — [Title]
Parent: [Parent Title] (Ticket ID [parent id])
Sprint: [Iteration Name]

## Changes Made
- [File/component]: [what changed and why]
- [File/component]: [what changed and why]

## Acceptance Criteria Coverage
- [x] AC 1: [text] — covered by [test file]
- [x] AC 2: [text] — covered by [test file]
- [x] AC 3: [text] — covered by [test file]

## Tests
- Unit tests: [N] added · [N] passing
- Test command: `npm test -- --coverage`
- Coverage: [N]% (if available)

## Screenshots
[Add before/after screenshots for any React UI changes]

## Checklist
- [x] Code follows existing codebase patterns
- [x] All acceptance criteria covered by tests
- [x] No hardcoded secrets or config values
- [x] Documentation updated (or not required)
- [x] ADO work item updated to In Code Review

Target branch: main
Linked: Ticket ID [id]
~~~

~~~
🔀 Pull Request created: "[PR Title]"
   Branch: [branch-name] → main
   Linked: Ticket ID [id]
   URL:    [PR URL if available]
~~~

---

### 12. Final summary

~~~
✅ Implementation Complete — Ticket ID [id]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"[Title]"
[WorkItemType]  |  [--project] / [--team]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Branch:     [branch-name]
PR:         "[PR Title]"  → [URL if available]
Tests:      [N] passing · 0 failing
ADO state:  In Progress → In Code Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
~~~

---

### 13. Follow-up prompt

> **Next steps:**
> - Ask a reviewer to approve the PR and link it back to Ticket ID [id]
> - Once merged, update Ticket ID [id] state to Done in ADO
> - Check the sprint board: `/sprint --project "[--project]" --team "[--team]"`
> - Implement another item: `/implement [id] --project "[--project]" --team "[--team]"`