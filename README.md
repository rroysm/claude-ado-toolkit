# Claude Code ADO — AI-Powered Azure DevOps Toolkit

A portable Claude Code setup that brings a complete AI-assisted Scrum workflow to any Azure DevOps project. Run one setup script and your team gets slash commands for every stage of the sprint — from BRD creation to retrospective deck — all wired into your ADO org via MCP.

---

## What this gives your team

| Stage | Command | What Claude does |
|-------|---------|-----------------|
| Requirements | `/brd` | Interactive BRD via Q&A or uploaded docs. Asks for Figma designs and extracts UI requirements. Produces `.docx` + posts to ADO Feature. |
| Story creation | `/stories AB#1234` | Decomposes BRD into right-sized user stories with AC, MoSCoW priority, and traceability matrix. Checks Figma for per-screen AC. |
| Quality gate | `/check 1234` | Scores a single work item across 8 dimensions (RAG rubric). Enforces DoR checklist. Auto-generates AC if missing. |
| Sprint planning | `/refine` | Batch quality check on all sprint backlog stories. Flags over-capacity. Posts scores to ADO. |
| Sprint board | `/sprint` | Scrum Master view — all items grouped by status and assignee. Flags blockers, stale items, overloaded members. |
| Standup | `/standup` | Prep notes before standup. Teams-formatted summary after. |
| Implementation | `/implement 1234` | Fetches story → quality gate → implementation plan → code + tests → state transitions → PR linked to work item. |
| Velocity | `/velocity` | Multi-sprint trend report. Optional `.pptx` or `.pdf` export. |
| Retrospective | `/retro` | Sprint retrospective PowerPoint (DROP/ADD/KEEP/IMPROVE). Offers to create ADO tasks from agreed action items. |

---

## End-to-End Delivery Pipeline

Every feature follows this canonical 6-phase path. Claude enforces phase gates and always tells you what to run next.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
  BRD       Stories     Refine      Implement   PR Review   Merge & Close
 /brd      /stories    /refine      /implement  AI + Human    Human
 SM + PO     SM        SM + Leads   Developer   Tech Lead    Dev / Lead
```

### Phase 1 — BRD Creation (`/brd`)
SM and PO run `/brd` against an Epic. Claude conducts interactive Q&A, analyses any Figma designs, and produces a `.docx` BRD posted to the ADO Epic.

**Gate:** PO must verbally or in writing approve the BRD before stories can be created. Claude will not run `/stories` until you confirm.

### Phase 2 — Story Decomposition (`/stories`)
SM runs `/stories AB#[epic]`. Claude reads the BRD, decomposes into 1–8pt stories with MoSCoW priority, creates them in ADO linked to the Epic, and posts a traceability matrix.

**Gate:** Stories must be assigned to a sprint before refinement.

### Phase 3 — Refinement & Quality Gate (`/refine` + `/check`)
SM and tech leads run `/refine` to batch-score all sprint stories, then `/check AB#[id]` on each 🟡 Amber or 🔴 Red story until every story is 🟢 Green across all 8 dimensions.

**Gate:** No story moves to implementation until it scores 🟢 Green. IRIS stories require PO sign-off (Kaydi Garzon). VCS stories require BA review (Partha Sarathi Das for EHR features).

### Phase 4 — Implementation (`/implement`)
Developer runs `/implement AB#[id]`. Claude fetches the story, inspects the codebase, plans, writes code and tests, creates a branch, and opens a PR. Updates ADO state: To Do → In Progress → In Code Review.

**Gate:** Story must score 🟢 on `/check`. Claude blocks on 🔴 Red unless `--skip-check` is used with a documented reason (hotfix or recorded OI-xxx blocker only).

### Phase 5 — Code Review (AI + Human)
`azure-pipelines-claude-review.yml` triggers the `ado-pr-reviewer` agent automatically on every PR. Claude posts inline comments on the diff. A human tech lead reviews and approves.

**Gate:** ≥ 1 human approval required. Claude's review alone is never sufficient to merge.

### Phase 6 — Merge & Close (Human)
Human merges the PR in ADO, then tells Claude **"merged"** in chat. Claude verifies every AC is covered, closes the story and child tasks, checks sibling stories, and asks before closing the Epic.

### Phase gate summary

| Gate | Condition required | What Claude says if not met |
|------|-------------------|-----------------------------|
| Phase 1 → 2 | PO has approved BRD scope | "Has [PO] approved this BRD? Reply 'yes' to run /stories." |
| Phase 3 → 4 | Story scores 🟢 on `/check` | "AB#[id] is ⚠️/❌. Fix flagged issues first, or use `--skip-check`." |
| Phase 4 → 6 | ≥ 1 human approved the PR | Claude will not mark story Done until user says "merged". |
| Any phase | Story state = Waiting for Requirements | "AB#[id] is blocked. Resolve the blocker before proceeding." |

---

## Quick start

### Prerequisites

- [Node.js ≥ 18](https://nodejs.org/)
- [Claude Code CLI](https://claude.ai/code) — `npm install -g @anthropic/claude-code`
- Access to your Azure DevOps organisation

### Step 1 — Get the toolkit

Clone or copy this repo into your project:

```bash
git clone <this-repo-url> .
```

> The essential files are `.claude/`, `CLAUDE.template.md`, `scripts/init.ps1`, `.vscode/mcp.json`, and `azure-pipelines-claude-review.yml`. You can copy these manually into an existing repo if preferred — see [Deploying to another ADO repo](#deploying-to-another-ado-repo) below.

### Step 2 — Run the setup script

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\init.ps1
```

The script asks eight questions and generates a ready-to-use `CLAUDE.md`:

| Question | Example |
|----------|---------|
| ADO organisation name | `NowOpticsIT` |
| Primary project name | `IRIS` |
| Primary team name | `IRIS Team` |
| Primary repo name | `Iris` |
| Add a second project? | `Y` / `N` |
| Application name | `IRIS` |
| Tech stack | `React frontend, Node.js backend` |
| Main branch name | `main` |

It also optionally sets `git remote origin` to your ADO repo and saves answers to `.claude/project-config.json` for re-use.

### Step 3 — Register the ADO MCP server

Run **once per developer machine**:

```bash
claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG_NAME
```

### Step 4 — Fill in your team

Open `CLAUDE.md` → **Team structure** section. Add every team member's name, role, and sub-team. Claude uses this for standup reports, capacity calculations, reviewer assignment, and retrospective action items.

### Step 5 — Configure your Definition of Ready

Open `CLAUDE.md` → **Definition of Ready** section. The defaults are:

1. **PO sign-off** — `Reviewed` field = "Reviewed" and `Reviewed By` set to your PO's name *(configure per project)*
2. **Design assets linked** — Figma link or mockup required for UI stories (backend stories exempt)
3. **No open questions** — blocks on "TBD", "?", or "pending" in description or AC
4. **State gate** — "Waiting for Requirements" state = automatically Not Ready

Update criterion 1 with your PO's name and the correct ADO field for your team.

### Step 6 — Wire up the CI pipeline

In your ADO project: **Pipelines → New pipeline** → point at `azure-pipelines-claude-review.yml`. Name it `Claude PR Review`. It triggers automatically on every PR — no further config needed.

### Step 7 — Open in VS Code and push

```bash
# VS Code loads .vscode/mcp.json automatically — prompts for org name on first use
code .

# Push to your ADO repo
git push -u origin main
```

---

## Deploying to another ADO repo

To bring this toolkit to your IRIS, VCS, or any other ADO repo, copy the AI tooling files and regenerate `CLAUDE.md` for that project. Your application code in `src/` is untouched.

### Step 1 — Copy the AI tooling files

```powershell
$target = "C:\path\to\your\iris-or-vcs-repo"

# Agent definitions and slash commands
Copy-Item -Path ".\.claude\agents"        -Destination "$target\.claude\agents"   -Recurse -Force
Copy-Item -Path ".\.claude\commands"      -Destination "$target\.claude\commands" -Recurse -Force
Copy-Item -Path ".\.claude\settings.json" -Destination "$target\.claude\settings.json" -Force

# VS Code MCP config
New-Item -ItemType Directory -Force "$target\.vscode" | Out-Null
Copy-Item -Path ".\.vscode\mcp.json" -Destination "$target\.vscode\mcp.json" -Force

# Setup script and template
New-Item -ItemType Directory -Force "$target\scripts" | Out-Null
Copy-Item -Path ".\scripts\init.ps1"   -Destination "$target\scripts\init.ps1" -Force
Copy-Item -Path ".\CLAUDE.template.md" -Destination "$target\CLAUDE.template.md" -Force

# CI pipeline
Copy-Item -Path ".\azure-pipelines-claude-review.yml" -Destination "$target\azure-pipelines-claude-review.yml" -Force
```

### Step 2 — Generate CLAUDE.md for the target project

```powershell
cd $target
PowerShell -ExecutionPolicy Bypass -File .\scripts\init.ps1
```

Enter the target project's ADO org, project name, team name, and repo name. The wizard pre-fills from `project-config.json` if it finds one.

### Step 3 — Add required npm packages

Check if the target repo's `package.json` already includes these. If not, add them:

```json
"docx": "^8.5.0",
"pptxgenjs": "^3.12.0"
```

Then run `npm install` once.

### Step 4 — Register MCP server (once per developer machine)

```bash
claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG_NAME
```

Each developer runs this once. Authentication uses their Microsoft Entra (Azure AD) account — the same login as `dev.azure.com`.

### Step 5 — Create the CI pipeline in the target ADO project

**Pipelines → New pipeline** → select the repo → choose `azure-pipelines-claude-review.yml` → name it `Claude PR Review` → save. Triggers automatically on every PR.

### Step 6 — Commit and push

```bash
git add .claude/ .vscode/mcp.json scripts/ CLAUDE.md CLAUDE.template.md azure-pipelines-claude-review.yml
git commit -m "chore: Add Claude Code AI tooling — slash commands, agents, CLAUDE.md"
git push
```

### What each team member needs (one-time)

| What | Command | Time |
|------|---------|------|
| Install Claude Code CLI | `npm install -g @anthropic/claude-code` | 2 min |
| Register ADO MCP server | `claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG` | 30 sec |
| Open repo in Claude Code | `cd <repo> && claude` | instant |

Once the files are committed, every developer who clones the repo gets all slash commands and agents automatically — no per-machine file copying.

---

## Slash commands — full reference

All commands require `--project "ProjectName" --team "TeamName"` flags.

### `/brd` — Create a Business Requirements Document

```text
/brd
/brd AB#1234   ← link BRD to an existing ADO Feature or Epic
```

- Gathers requirements via interactive Q&A or from uploaded docs (meeting notes, emails, specs)
- **Always asks for Figma designs** — accepts a Figma link or screenshots. Extracts screen names, UI components, field labels, navigation flows, and error states.
- Produces a `.docx` BRD with 12 sections (FR/NFR numbered, Given/When/Then AC, user journeys)
- Posts a summary comment to the ADO Feature work item
- **Next step:** `/stories AB#[epic]` after PO approves scope

### `/stories` — Decompose BRD into user stories

```text
/stories
/stories AB#1234
/stories AB#1234 --sprint "Sprint 45"
/stories AB#1234 --dry-run
```

- Loads BRD from file, ADO work item, or current session
- **Checks for Figma designs** — maps screens to BRD requirements, adds `UI reference:` lines to stories, flags gaps
- Decomposes into right-sized stories (1–8pt, INVEST principles)
- Shows full story list for review before creating anything in ADO
- Creates work items tagged `claude-generated`, `brd-derived`, linked to parent Feature
- Posts a traceability matrix (FR-ID → Story ID) as a comment on the Feature
- **Next step:** `/refine` after stories are assigned to a sprint

### `/check` — Quality-gate a single work item

```text
/check 1234 --project "MyProject" --team "My Team"
/check 1234 --project "MyProject" --team "My Team" --dry-run
```

Scores the story across 8 dimensions:

| # | Dimension | Green criteria |
|---|-----------|---------------|
| D1 | Acceptance criteria | 3+ testable Given/When/Then |
| D2 | Story points | On team scale (1, 2, 3, 5, 8) |
| D3 | Description | Clear "As a / I want / So that" |
| D4 | Linked tasks | 2+ child tasks meaningfully titled |
| D5 | Linked test cases | 1+ test cases linked |
| D6 | Dependencies noted | External dependencies explicit |
| D7 | Definition of Ready | All DoR criteria met (see CLAUDE.md) |
| D8 | Story size | 1–8pt, deliverable in one sprint |

**Classification:** READY (7–8 green, no red) · NEEDS WORK (4–6 green or 1–2 red) · NOT READY (3+ red)

Auto-generates suggested AC in Given/When/Then format if D1 = Red. Posts report as ADO comment.

**Next step:** `/implement AB#[id]` when 🟢 Green

### `/refine` — Batch sprint quality check

```text
/refine --project "MyProject" --team "My Team"
/refine --project "MyProject" --team "My Team" --sprint "Sprint 15"
/refine --project "MyProject" --team "My Team" --current
/refine --project "MyProject" --team "My Team" --post
/refine --project "MyProject" --team "My Team" --dry-run
/refine --project "MyProject" --team "My Team" --ratio 6   ← pre-AI baseline
```

Checks all User Stories, Enhancements, and Bugs in the sprint backlog. Fetches team capacity from ADO. Flags over-capacity with drop candidates. Posts per-story scores to ADO with `--post`.

**Next step:** `/check AB#[id]` for each 🟡 Amber or 🔴 Red story

### `/implement` — Full story implementation

```text
/implement 1234 --project "MyProject" --team "My Team"
/implement 1234 --project "MyProject" --team "My Team" --branch "feature/custom-name"
/implement 1234 --project "MyProject" --team "My Team" --skip-check
```

Full pipeline, in order:

1. Fetch work item from ADO (User Story, Bug, Enhancement — not Tasks)
2. **Dependency check** — inspects predecessor links; warns and pauses if a blocking story is not yet complete
3. **Quality gate** — runs `/check` rubric; blocks if NOT READY, warns if NEEDS WORK
4. Inspect codebase patterns (folder structure, naming, test setup, ESLint)
5. Show implementation plan — waits for your confirmation
6. **Set story + child tasks → In Progress** before any code is written
7. Create `feature/[id]-short-title` or `bugfix/[id]-short-title` branch from `main`
8. Write code following standards in `CLAUDE.md`
9. **Run tests** — `npm test -- --watchAll=false --coverage`. Blocks PR if tests fail, regressions exist, or zero tests are found
10. Update documentation if needed
11. **Set story + child tasks → In Code Review**
12. Open PR in ADO linked to work item

**Next step:** Assign Tech Lead as reviewer. Say "merged" after approval and merge.

### `/sprint` — Scrum Master board

```text
/sprint --project "MyProject" --team "My Team"
/sprint --project "MyProject" --team "My Team" --all
```

All sprint items grouped by status then by assignee. Flags: blockers, stale items (3+ days no update), unassigned items, overloaded members, oversized stories.

### `/standup` — Daily standup

```text
/standup --project "MyProject" --team "My Team"
/standup --project "MyProject" --team "My Team" --summary
/standup --project "MyProject" --team "My Team" --post
/standup --project "MyProject" --team "My Team" --notes "Alice is on leave today"
```

Default: prep notes before standup (per-person yesterday/today/blockers). `--summary` / `--post`: Teams-formatted summary after standup.

### `/velocity` — Sprint velocity trends

```text
/velocity --project "MyProject" --team "My Team"
/velocity --project "MyProject" --team "My Team" --sprints 10
/velocity --project "MyProject" --team "My Team" --export ppt
/velocity --project "MyProject" --team "My Team" --export pdf
```

Committed vs completed, completion rate %, bug trend, carry-over trend across last 6 (or N) sprints.

### `/retro` — Sprint retrospective deck

```text
/retro --project "MyProject" --team "My Team"
/retro --project "MyProject" --team "My Team" --sprint "Sprint 14"
/retro --project "MyProject" --team "My Team" --notes "Team felt overloaded"
```

Generates a PowerPoint (DROP/ADD/KEEP/IMPROVE) seeded from ADO data. After delivery, offers to create ADO Tasks from agreed action items linked to the next sprint.

---

## Post-PR lifecycle

After a PR is raised, Claude tracks the review-to-merge cycle.

### Reviewer assignment (default rules)

Claude suggests the reviewer immediately after raising the PR:

| PR type | Default reviewer |
|---------|-----------------|
| Frontend (React, CSS, HTML) | Frontend Lead |
| Backend (Node.js, routes, services) | Backend Lead |
| Full-stack / cross-cutting | Scrum Master |
| QA / test-only | QA Lead |

### Merge conditions

All of the following must be true before merging:

| Condition | Who verifies |
|-----------|-------------|
| CI pipeline green (build + tests) | ADO pipeline / automated |
| Claude PR review passed (no 🔴 blockers) | `ado-pr-reviewer` agent |
| ≥ 1 human approval | Tech Lead |
| No unresolved comment threads | Reviewer + Author |
| PR references `AB#[id]` in title or description | Author |

### Post-merge sequence

Tell Claude **"merged"** in chat after the human merges the PR:

1. **AC verification** — Claude re-reads every acceptance criterion and confirms coverage. Raises any uncovered AC before closing.
2. **Story + children → Done** — Story and all linked Tasks/Subtasks set to Done.
3. **Sibling check** — If all sibling stories under the parent Epic are now Done, Claude asks: *"Shall I close the Epic?"* and waits for your explicit yes.
4. **Regression reminder** — Prompts you to run the full test suite on `main`.
5. **Next story** — Suggests the next highest-priority story in the sprint.

---

## Specialist agents (auto-invoked)

You don't call these directly — Claude invokes them automatically when the task matches.

| Agent | Auto-triggers when... |
|-------|----------------------|
| `ado-pr-reviewer` | Asked to review a PR or check code changes. Handles large diffs by triaging risk tiers — security/auth reviewed first, generated files skipped. |
| `ado-pipeline-doctor` | A pipeline fails or CI error needs diagnosing. Classifies failure type and outputs a paste-ready fix. |
| `ado-story-developer` | Implementing a user story end-to-end. Runs the same test gate and state transitions as `/implement`. |
| `ado-story-quality-checker` | Checking story quality before development. Same 8-dimension rubric as `/check`. |
| `ado-brd-writer` | Creating or drafting a BRD. Runs the Figma check as part of requirements elicitation. |
| `ado-brd-to-stories` | Decomposing a BRD into ADO user stories. |

---

## Quality enforcement built in

### Definition of Ready (D7 in `/check` and `/refine`)

D7 enforces your team's actual DoR defined in `CLAUDE.md` — not just a tag:

- **PO sign-off** — configurable per project (ADO `Reviewed` field + `Reviewed By` field)
- **Design assets linked** — Figma link or mockup required for UI stories
- **No open questions** — blocks on "TBD", "?", "pending" in description or AC
- **State gate** — "Waiting for Requirements" state = Red, regardless of other criteria

### Test gate in `/implement`

Claude runs `npm test -- --watchAll=false --coverage` and **blocks PR creation** if:

- Any test fails (fix the implementation — never rewrite tests to mask a bug)
- Test environment is broken (missing env vars, missing modules) — stops and asks you to fix
- Zero tests are found (writes tests first, then re-runs before continuing)
- Any previously-passing test now fails (regression anywhere = blocker)

### ADO state transitions

`/implement` handles state transitions automatically:

| Event | Story state | Child task states |
|-------|-------------|------------------|
| Plan confirmed → coding starts | In Progress | In Progress |
| PR opened | In Code Review | In Code Review |
| "merged" confirmed + ACs verified | Done | Done |

### Blocked story handling (OI-xxx pattern)

When a story depends on an unresolved external item:

1. Claude documents the blocker in the work item: `⚠️ BLOCKED — [OI-xxx]: [description]. Owner: [name].`
2. Story state is set to **On Hold** — not In Progress, not Waiting for Requirements.
3. During `/refine`, blocked stories are flagged and excluded from capacity calculations.
4. Claude will not run `/implement` on a blocked story until you explicitly confirm the blocker is resolved.

---

## Direct work item editing

Update any ADO field from chat — no need to go to the web UI:

> "Update the acceptance criteria on ticket 1234"
> "Change the story points on AB#5678 to 5"
> "Assign ticket 1234 to [team member name]"

Claude shows the before/after and asks for confirmation before writing.

---

## Figma design integration

Both `/brd` and `/stories` ask upfront:

> "Is there a Figma design for this feature?"

- **Figma link provided** — Claude fetches and analyses the design. Note: most Figma links require authentication; if the fetch fails, export screens as PNG/JPG instead.
- **Screenshots provided** — Claude analyses each screen visually.
- **No design** — noted as "UI/UX design: Not yet created" and the workflow continues.

What Claude extracts: screen names, UI components, field labels, navigation flows, empty/error states, developer annotations. These feed directly into BRD functional requirements and story acceptance criteria.

---

## Story point scale (AI-assisted)

Estimates reflect **human effort** (review, guidance, validation) — not raw coding time:

| Points | Human hours | When to use |
|--------|-------------|-------------|
| 1pt | ~2h | Trivial — single file, obvious change |
| 2pt | ~3h | Small — 1–2 files, straightforward logic |
| 3pt | ~6h | Moderate — clear requirements, known patterns |
| 5pt | ~16h | Complex — multiple files, design decisions |
| 8pt | ~30h | Large — cross-cutting, architectural thought (max per sprint) |
| 13pt | must split | Exceeds sprint capacity even with AI — split first |

**Capacity formula:** `team members × days available × 6h ÷ 4 = sprint capacity (pts)`

Use `--ratio 6` on `/refine` or `/check` to revert to the pre-AI baseline.

---

## File structure

```text
.
├── .claude/
│   ├── agents/
│   │   ├── ado-brd-writer.md             # BRD creation agent
│   │   ├── ado-brd-to-stories.md         # BRD decomposition agent
│   │   ├── ado-pipeline-doctor.md        # Pipeline failure diagnosis agent
│   │   ├── ado-pr-reviewer.md            # PR code review agent
│   │   ├── ado-story-developer.md        # Story implementation agent
│   │   └── ado-story-quality-checker.md  # Story quality check agent
│   ├── commands/
│   │   ├── brd.md                        # /brd command
│   │   ├── check.md                      # /check command
│   │   ├── implement.md                  # /implement command
│   │   ├── refine.md                     # /refine command
│   │   ├── retro.md                      # /retro command
│   │   ├── sprint.md                     # /sprint command
│   │   ├── standup.md                    # /standup command
│   │   ├── stories.md                    # /stories command
│   │   └── velocity.md                   # /velocity command
│   ├── settings.json                     # Project-level MCP tool permissions
│   └── project-config.example.json      # Config schema reference
├── .vscode/
│   └── mcp.json                          # ADO MCP server config (auto-loads in VS Code)
├── scripts/
│   └── init.ps1                          # Setup wizard — generates CLAUDE.md
├── azure-pipelines-claude-review.yml     # CI pipeline — triggers Claude PR review on every PR
├── CLAUDE.md                             # Generated project config (edit to customise)
└── CLAUDE.template.md                    # Template source — edit here, then re-run init.ps1
```

---

## Customising for your team

All behaviour is controlled by `CLAUDE.md`. Key sections to update:

| Section | What to update |
|---------|---------------|
| **End-to-End Delivery Pipeline** | Adjust phase owners and entry conditions for your process |
| **Project overview** | Your project names, PO and SM names |
| **Azure DevOps context** | Your org URL, project names, repo remote URLs |
| **Team structure** | Full roster with names, roles, sub-teams |
| **Definition of Ready** | PO sign-off field and person (per project), any additional criteria |
| **Coding standards** | Tech stack, naming conventions, PR rules |
| **Story point estimation model** | Adjust if your AI uplift ratio differs |

To update defaults across **all future projects**, edit `CLAUDE.template.md` and re-run `scripts/init.ps1`.

---

## Authentication

### VS Code (recommended)

`.vscode/mcp.json` loads the ADO MCP server automatically. On first use it prompts for your org name and authenticates via Microsoft Entra (Azure AD) — the same login as `dev.azure.com`. No per-machine config needed for teammates.

### Claude Code CLI — Personal Access Token

```bash
# Set before running claude
export ADO_MCP_AUTH_TOKEN="your-personal-access-token"

# Register with PAT auth
claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG --authentication envvar
```

Generate a PAT at: `https://dev.azure.com/YOUR_ORG/_usersSettings/tokens`

Required scopes: **Code** (Read & Write) · **Work Items** (Read & Write) · **Build** (Read)

---

## What Claude will not do

These are hard guardrails that cannot be overridden:

- **Never commit directly to `main` or `release/*`** — always creates a branch and PR
- **Never merge or approve a PR** — human approval always required
- **Never close an Epic** without your explicit confirmation — even if all child stories are Done
- **Never mark a story Done** without you saying "merged" and AC verification passing
- **Never run `/implement` on a 🔴 Red story** unless `--skip-check` is used with a documented reason
- **Never skip CI failures silently** — always surfaces the failure and stops
- **Never send standup messages or Teams posts** without explicit `--post` flag
- **Never store secrets or tokens in code** — environment variables only

---

## First commands after setup

```bash
# Check the current sprint board
/sprint --project "MyProject" --team "My Team"

# Batch quality-check all sprint backlog stories
/refine --project "MyProject" --team "My Team"

# Deep-dive quality check on a single story
/check 1234 --project "MyProject" --team "My Team"

# Implement a story end-to-end
/implement 1234 --project "MyProject" --team "My Team"

# Create a BRD for an Epic
/brd AB#1234 --project "MyProject" --team "My Team"
```
