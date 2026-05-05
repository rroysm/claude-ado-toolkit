# Claude Code ADO Toolkit

**Repo:** `Claude-ADO-Toolkit` · [dev.azure.com/NowOpticsIT/Claude-Test/_git/Claude-ADO-Toolkit](https://dev.azure.com/NowOpticsIT/Claude-Test/_git/Claude-ADO-Toolkit)

A portable Claude Code setup that brings a complete AI-assisted Scrum workflow to any Azure DevOps project. Copy these files into your repo, run one setup script, and your whole team gets 9 slash commands and 6 specialist agents — covering every stage of the sprint from BRD creation to merged code.

> **This is the toolkit source.** It contains no application code — only agents, slash commands, configuration, and the setup script. Add it to any ADO repo in under 10 minutes.

---

## What's included

| Type | Count | What they do |
|------|-------|-------------|
| Slash commands | 9 | `/brd`, `/stories`, `/check`, `/refine`, `/implement`, `/sprint`, `/standup`, `/velocity`, `/retro` |
| Specialist agents | 6 | BRD writer, BRD-to-stories, PR reviewer, pipeline doctor, story developer, story quality checker |
| Setup wizard | 1 | `scripts/init.ps1` — generates `CLAUDE.md` for any ADO project in ~2 min |
| CI pipeline | 1 | `azure-pipelines-claude-review.yml` — auto Claude PR review on every PR |
| VS Code config | 1 | `.vscode/mcp.json` — ADO MCP server loads automatically when you open VS Code |

---

## Commands at a glance

| Stage | Command | What Claude does |
|-------|---------|-----------------|
| Requirements | `/brd` | Interactive BRD via Q&A or uploaded docs. Analyses Figma designs. Produces `.docx` + posts to ADO Feature. |
| Story creation | `/stories AB#1234` | Decomposes BRD into right-sized user stories with AC, MoSCoW priority, and traceability matrix. |
| Quality gate | `/check 1234` | Scores a work item across 8 dimensions (RAG rubric). Enforces DoR. Auto-generates AC if missing. |
| Sprint planning | `/refine` | Batch quality check on all sprint backlog stories. Flags over-capacity. Posts scores to ADO. |
| Sprint board | `/sprint` | Scrum Master view — items by status and assignee. Flags blockers, stale items, overloaded members. |
| Standup | `/standup` | Prep notes before standup. Teams-formatted summary after. |
| Implementation | `/implement 1234` | Fetches story → quality gate → plan → code + tests → state transitions → PR linked to work item. |
| Velocity | `/velocity` | Multi-sprint trend report. Optional `.pptx` or `.pdf` export. |
| Retrospective | `/retro` | Sprint retrospective PowerPoint (DROP/ADD/KEEP/IMPROVE). Creates ADO tasks from action items. |

---

## End-to-End Delivery Pipeline

Every feature follows this 6-phase path. Claude enforces phase gates and always tells you what to run next — you never have to guess.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
  BRD       Stories     Refine      Implement   PR Review   Merge & Close
 /brd      /stories    /refine      /implement  AI + Human    Human
 SM + PO     SM        SM + Leads   Developer   Tech Lead    Dev / Lead
```

### Phase 1 — BRD Creation (`/brd`)
SM and PO run `/brd` against an Epic. Claude conducts interactive Q&A, analyses Figma designs if provided, and produces a `.docx` BRD posted to the ADO Epic.

**Gate:** PO must approve the BRD before stories are created. Claude will not run `/stories` until you confirm.

### Phase 2 — Story Decomposition (`/stories`)
SM runs `/stories AB#[epic]`. Claude reads the BRD, decomposes into 1–8pt stories with MoSCoW priority, creates them in ADO linked to the Epic, and posts a traceability matrix.

**Gate:** Stories must be assigned to a sprint before refinement.

### Phase 3 — Refinement & Quality Gate (`/refine` + `/check`)
SM and tech leads run `/refine` to batch-score all sprint stories, then `/check AB#[id]` on each 🟡 Amber or 🔴 Red story until every story is 🟢 Green.

**Gate:** No story moves to implementation until it scores 🟢 Green on all 8 dimensions.

### Phase 4 — Implementation (`/implement`)
Developer runs `/implement AB#[id]`. Claude fetches the story, inspects the codebase, plans, writes code and tests, creates a branch, and opens a PR. Updates ADO state: To Do → In Progress → In Code Review.

**Gate:** Story must score 🟢 on `/check`. Claude blocks on 🔴 Red unless `--skip-check` is used with a documented reason (hotfix or recorded external blocker only).

### Phase 5 — Code Review (AI + Human)
`azure-pipelines-claude-review.yml` triggers the `ado-pr-reviewer` agent automatically on every PR. Claude posts inline comments. A human tech lead reviews and approves.

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

## Adding this toolkit to your repo

This is the recommended way to use the toolkit — copy the files into your existing ADO repo so every developer on the team gets the commands automatically when they clone.

### Prerequisites

- [Node.js ≥ 18](https://nodejs.org/)
- [Claude Code CLI](https://claude.ai/code) — `npm install -g @anthropic/claude-code`
- Access to your Azure DevOps organisation

### Step 1 — Clone the toolkit

```bash
git clone https://NowOpticsIT@dev.azure.com/NowOpticsIT/Claude-Test/_git/Claude-ADO-Toolkit
cd Claude-ADO-Toolkit
```

### Step 2 — Copy toolkit files into your target repo

```powershell
$target = "C:\path\to\your\project-repo"

# Agents and slash commands
Copy-Item -Path ".\.claude\agents"        -Destination "$target\.claude\agents"   -Recurse -Force
Copy-Item -Path ".\.claude\commands"      -Destination "$target\.claude\commands" -Recurse -Force
Copy-Item -Path ".\.claude\settings.json" -Destination "$target\.claude\settings.json" -Force
Copy-Item -Path ".\.claude\project-config.example.json" -Destination "$target\.claude\project-config.example.json" -Force

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

### Step 3 — Run the setup wizard

```powershell
cd $target
PowerShell -ExecutionPolicy Bypass -File .\scripts\init.ps1
```

The wizard asks eight questions and generates `CLAUDE.md` — the project brain that controls all slash command behaviour:

| Question | Example answer |
|----------|---------------|
| ADO organisation name | `NowOpticsIT` |
| Project name | `IRIS` |
| Team name | `IRIS Team` |
| Repo name | `Iris` |
| Add a second project? | `Y` / `N` |
| Application name | `IRIS` |
| Tech stack | `React frontend, Node.js backend` |
| Main branch name | `main` |

Answers are saved to `.claude/project-config.json` — press Enter next time to keep them.

### Step 4 — Add required npm packages

Check if your repo's `package.json` already has these. If not, add them to `dependencies`:

```json
"docx": "^9.6.1",
"pptxgenjs": "^3.12.0"
```

Then run `npm install` once.

### Step 5 — Fill in your team

Open `CLAUDE.md` → **Team structure** section. Add every team member's name, role, and sub-team. Claude uses this for standup reports, capacity calculations, reviewer assignment, and retro action items.

### Step 6 — Configure your Definition of Ready

Open `CLAUDE.md` → **Definition of Ready** section. Update:
1. Your PO's name and the ADO field used for sign-off (per project)
2. Any additional DoR criteria your team uses

### Step 7 — Wire up the CI pipeline

In your ADO project: **Pipelines → New pipeline** → select the repo → choose `azure-pipelines-claude-review.yml` → name it `Claude PR Review` → save. Triggers automatically on every PR.

### Step 8 — Register the ADO MCP server (once per developer machine)

Each team member runs this **once**:

```bash
claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG_NAME
```

Authentication uses their Microsoft Entra (Azure AD) account — same login as `dev.azure.com`. No PAT needed.

### Step 9 — Commit and push

```bash
git add .claude/ .vscode/ scripts/ CLAUDE.md CLAUDE.template.md azure-pipelines-claude-review.yml
git commit -m "chore: Add Claude Code AI toolkit — slash commands, agents, CLAUDE.md"
git push
```

From this point on, every developer who clones the repo gets all 9 slash commands and 6 agents automatically — no per-machine setup beyond the one-time MCP registration.

---

## What each team member needs (one-time setup)

| Step | Command | Time |
|------|---------|------|
| Install Claude Code CLI | `npm install -g @anthropic/claude-code` | 2 min |
| Register ADO MCP server | `claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG` | 30 sec |
| Open repo in Claude Code | `cd your-repo && claude` | instant |
| VS Code (optional) | Open repo → Copilot Agent mode → enable ADO tools | 2 min |

---

## Slash commands — full reference

All commands require `--project "ProjectName" --team "TeamName"` flags.

### `/brd` — Create a Business Requirements Document

```
/brd
/brd AB#1234
```

- Gathers requirements via interactive Q&A or from uploaded docs (meeting notes, emails, specs)
- Always asks for Figma designs — accepts a Figma link or screenshots
- Extracts screen names, UI components, field labels, navigation flows, and error states
- Produces a `.docx` BRD with 12 sections (FR/NFR numbered, Given/When/Then AC, user journeys)
- Posts a summary comment to the ADO Feature work item
- **Next step:** `/stories AB#[epic]` after PO approves scope

### `/stories` — Decompose BRD into user stories

```
/stories
/stories AB#1234
/stories AB#1234 --sprint "Sprint 45"
/stories AB#1234 --dry-run
```

- Loads BRD from file, ADO work item, or current session
- Maps Figma screens to BRD requirements — adds `UI reference:` lines to stories, flags gaps
- Decomposes into right-sized stories (1–8pt, INVEST principles), MoSCoW prioritisation
- Shows full story list for confirmation before creating anything in ADO
- Creates work items linked to parent Feature, posts a traceability matrix (FR-ID → Story ID)
- **Next step:** `/refine` after stories are assigned to a sprint

### `/check` — Quality-gate a single work item

```
/check 1234 --project "MyProject" --team "My Team"
/check 1234 --project "MyProject" --team "My Team" --dry-run
```

Scores the story across 8 dimensions:

| # | Dimension | Green criteria |
|---|-----------|---------------|
| D1 | Acceptance criteria | 3+ testable Given/When/Then statements |
| D2 | Story points | On team scale (1, 2, 3, 5, 8) |
| D3 | Description | Clear "As a / I want / So that" format |
| D4 | Linked tasks | 2+ child tasks meaningfully titled |
| D5 | Linked test cases | 1+ test cases linked |
| D6 | Dependencies noted | External dependencies explicit |
| D7 | Definition of Ready | All DoR criteria met (configured in CLAUDE.md) |
| D8 | Story size | 1–8pt, deliverable in one sprint |

**READY** (7–8 green, no red) · **NEEDS WORK** (4–6 green or 1–2 red) · **NOT READY** (3+ red)

Auto-generates suggested AC in Given/When/Then format when D1 = Red. Posts report as ADO comment.

**Next step:** `/implement AB#[id]` when 🟢 Green

### `/refine` — Batch sprint quality check

```
/refine --project "MyProject" --team "My Team"
/refine --project "MyProject" --team "My Team" --sprint "Sprint 15"
/refine --project "MyProject" --team "My Team" --post
/refine --project "MyProject" --team "My Team" --dry-run
/refine --project "MyProject" --team "My Team" --ratio 6
```

Scores all User Stories, Enhancements, and Bugs in the sprint backlog. Fetches team capacity from ADO. Flags over-capacity with suggested drop candidates. Use `--post` to write scores as ADO comments. Use `--ratio 6` to revert to the pre-AI capacity baseline.

**Next step:** `/check AB#[id]` for each 🟡 Amber or 🔴 Red story

### `/implement` — Full story implementation

```
/implement 1234 --project "MyProject" --team "My Team"
/implement 1234 --project "MyProject" --team "My Team" --branch "feature/my-branch"
/implement 1234 --project "MyProject" --team "My Team" --skip-check
```

Full pipeline in order:

1. Fetch work item from ADO (User Story, Bug, Enhancement — not Tasks)
2. **Dependency check** — warns and pauses if a blocking story is not yet complete
3. **Quality gate** — blocks if NOT READY, warns if NEEDS WORK
4. Inspect codebase patterns (folder structure, naming, test setup, linting)
5. Show implementation plan — waits for your confirmation before writing any code
6. **Set story + child tasks → In Progress**
7. Create `feature/[id]-title` or `bugfix/[id]-title` branch from main
8. Write code following standards in `CLAUDE.md`
9. **Run tests** — `npm test -- --watchAll=false --coverage`. Blocks PR on any failure or regression
10. Update documentation if needed
11. **Set story + child tasks → In Code Review**
12. Open PR in ADO linked to the work item

**Next step:** Assign Tech Lead as reviewer. Say "merged" after approval and merge.

### `/sprint` — Scrum Master board

```
/sprint --project "MyProject" --team "My Team"
/sprint --project "MyProject" --team "My Team" --all
```

All sprint items grouped by status then assignee. Flags: blockers, stale items (3+ days), unassigned items, overloaded members, oversized stories.

### `/standup` — Daily standup

```
/standup --project "MyProject" --team "My Team"
/standup --project "MyProject" --team "My Team" --summary
/standup --project "MyProject" --team "My Team" --post
/standup --project "MyProject" --team "My Team" --notes "Alice is on leave today"
```

Default: per-person prep notes before standup (yesterday / today / blockers).  
`--summary` / `--post`: Teams-formatted summary after standup. Messages are never sent without `--post`.

### `/velocity` — Sprint velocity trends

```
/velocity --project "MyProject" --team "My Team"
/velocity --project "MyProject" --team "My Team" --sprints 10
/velocity --project "MyProject" --team "My Team" --export ppt
/velocity --project "MyProject" --team "My Team" --export pdf
```

Committed vs completed, completion rate %, bug trend, carry-over trend across last 6 (or N) sprints.

### `/retro` — Sprint retrospective deck

```
/retro --project "MyProject" --team "My Team"
/retro --project "MyProject" --team "My Team" --sprint "Sprint 14"
/retro --project "MyProject" --team "My Team" --notes "Team felt overloaded"
```

Generates a PowerPoint (DROP/ADD/KEEP/IMPROVE) seeded from ADO data. After delivery, offers to create ADO Tasks from agreed action items linked to the next sprint.

---

## Post-PR lifecycle

After a PR is raised (Phase 4), Claude tracks the review-to-merge cycle.

### Reviewer assignment

Claude suggests the reviewer immediately after raising the PR:

| PR type | Default reviewer |
|---------|-----------------|
| Frontend (React, CSS, HTML) | Frontend Lead (configure in CLAUDE.md) |
| Backend (Node.js, routes, services) | Backend Lead (configure in CLAUDE.md) |
| Full-stack / cross-cutting | Scrum Master |
| QA / test-only | QA Lead |

### Merge conditions

| Condition | Who verifies |
|-----------|-------------|
| CI pipeline green (build + tests) | ADO pipeline / automated |
| Claude PR review passed (no 🔴 blockers) | `ado-pr-reviewer` agent |
| ≥ 1 human approval | Tech Lead |
| No unresolved comment threads | Reviewer + Author |
| PR references `AB#[id]` in title or description | Author |

### Post-merge sequence

Tell Claude **"merged"** in chat after the human merges:

1. **AC verification** — confirms every acceptance criterion is covered before closing
2. **Story + children → Done** — story and all linked Tasks/Subtasks set to Done
3. **Sibling check** — if all sibling stories under the Epic are Done, asks *"Shall I close the Epic?"*
4. **Regression reminder** — prompts you to run the full test suite on `main`
5. **Next story** — suggests the next highest-priority story in the sprint

---

## Specialist agents (auto-invoked)

Claude invokes these automatically — you never call them directly.

| Agent | Auto-triggers when... |
|-------|----------------------|
| `ado-pr-reviewer` | Asked to review a PR or check code changes. Triages by risk: security/auth first, generated files skipped. |
| `ado-pipeline-doctor` | A pipeline fails or CI error needs diagnosing. Outputs a paste-ready fix. |
| `ado-story-developer` | Implementing a user story end-to-end. Same test gate and state transitions as `/implement`. |
| `ado-story-quality-checker` | Checking story quality before development. Same 8-dimension rubric as `/check`. |
| `ado-brd-writer` | Creating or drafting a BRD. Runs the Figma check as part of requirements elicitation. |
| `ado-brd-to-stories` | Decomposing a BRD into ADO user stories. |

---

## Quality enforcement

### Test gate in `/implement`

Claude runs `npm test -- --watchAll=false --coverage` and **blocks PR creation** if:

- Any test fails (fix the implementation — never rewrite tests to mask a bug)
- Test environment is broken (missing env vars, missing modules) — stops and asks you to fix it
- Zero tests are found (writes tests first, then re-runs before continuing)
- Any previously-passing test now fails (regression anywhere = blocker, not just new test files)

### ADO state transitions

`/implement` handles every state transition — you never need to update ADO manually:

| Event | Story state | Child task states |
|-------|-------------|------------------|
| Plan confirmed, coding starts | In Progress | In Progress |
| PR opened | In Code Review | In Code Review |
| "merged" + ACs verified | Done | Done |

### Blocked story handling

When a story depends on an unresolved external item:

1. Claude documents the blocker: `⚠️ BLOCKED — [OI-xxx]: [description]. Owner: [name].`
2. Story state is set to **On Hold**
3. During `/refine`, blocked stories are flagged and excluded from capacity calculations
4. Claude will not run `/implement` on a blocked story until you confirm the blocker is resolved

---

## Figma design integration

Both `/brd` and `/stories` ask upfront: *"Is there a Figma design for this feature?"*

| Input | What Claude does |
|-------|----------------|
| Figma link | Fetches and analyses the design (requires public link or auth) |
| Screenshots | Analyses each screen visually |
| No design | Notes "UI/UX design: Not yet created" and continues |

Claude extracts: screen names, component labels, field validation, navigation flows, empty/error states, developer annotations. These feed directly into BRD requirements and story acceptance criteria. Gaps between screens and requirements are flagged before stories are created.

---

## Story point scale (AI-assisted)

Estimates reflect **human effort** — not raw coding time. Claude Code handles approximately one-third of coding effort:

| Points | Human hours | When to use |
|--------|-------------|-------------|
| 1pt | ~2h | Trivial — single file, obvious change |
| 2pt | ~3h | Small — 1–2 files, straightforward logic |
| 3pt | ~6h | Moderate — clear requirements, known patterns |
| 5pt | ~16h | Complex — multiple files, design decisions |
| 8pt | ~30h | Large — cross-cutting, architectural thought (max per sprint) |
| 13pt | must split | Exceeds sprint capacity even with AI |

**Capacity formula:** `team members × days available × 6h ÷ 4 = sprint capacity (pts)`

Use `--ratio 6` on `/refine` or `/check` to revert to the pre-AI baseline.

---

## File structure

```
claude-ado-toolkit/
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
│   ├── settings.json                     # MCP tool permissions
│   └── project-config.example.json      # Config schema — copy to project-config.json
├── .vscode/
│   └── mcp.json                          # ADO MCP server — auto-loads in VS Code
├── scripts/
│   └── init.ps1                          # Setup wizard — generates CLAUDE.md
├── azure-pipelines-claude-review.yml     # CI pipeline — auto Claude PR review on every PR
├── CLAUDE.template.md                    # Project config template — source for init.ps1
├── package.json                          # Required packages: docx, pptxgenjs
├── .gitignore
└── README.md

# Not in this repo — generated in your project repo by init.ps1:
# CLAUDE.md                               # Project brain (gitignored here, lives in your repo)
```

---

## Customising after setup

All slash command behaviour is controlled by `CLAUDE.md` in your project repo. Key sections to update:

| Section | What to update |
|---------|---------------|
| **End-to-End Delivery Pipeline** | Phase owners, entry conditions, gate criteria |
| **Team structure** | Full roster with names, roles, sub-teams |
| **Definition of Ready** | PO sign-off field and person, additional criteria |
| **Azure DevOps context** | Org URL, project names, repo remote URLs |
| **Coding standards** | Tech stack, naming conventions, PR size limits |
| **Story point estimation model** | Adjust capacity ratio if your AI uplift differs |

To change defaults for **all future projects**, edit `CLAUDE.template.md` in this toolkit repo and re-run `scripts/init.ps1`.

---

## Authentication

### VS Code (recommended)

`.vscode/mcp.json` loads the ADO MCP server automatically when you open the repo. On first use it prompts for your org name and authenticates via Microsoft Entra (Azure AD) — same login as `dev.azure.com`.

### Claude Code CLI — Personal Access Token

```bash
export ADO_MCP_AUTH_TOKEN="your-personal-access-token"
claude mcp add azure-devops -- npx -y @azure-devops/mcp YOUR_ORG --authentication envvar
```

Generate a PAT at `https://dev.azure.com/YOUR_ORG/_usersSettings/tokens`

Required scopes: **Code** (Read & Write) · **Work Items** (Read & Write) · **Build** (Read)

---

## What Claude will not do

Hard guardrails — these cannot be overridden by any instruction:

- **Never commit directly to `main` or `release/*`** — always creates a branch and PR
- **Never merge or approve a PR** — human approval is always required
- **Never close an Epic** without your explicit confirmation, even if all child stories are Done
- **Never mark a story Done** without you saying "merged" and AC verification passing
- **Never run `/implement` on a 🔴 Red story** without `--skip-check` and a documented reason
- **Never skip CI failures silently** — always surfaces the failure and stops
- **Never send standup or Teams messages** without the explicit `--post` flag
- **Never store secrets or tokens in code** — environment variables only

---

## First commands after setup

```bash
# Check the current sprint board
/sprint --project "YourProject" --team "Your Team"

# Batch quality-check all sprint backlog stories
/refine --project "YourProject" --team "Your Team"

# Deep-dive quality check on a single story
/check 1234 --project "YourProject" --team "Your Team"

# Implement a story end-to-end
/implement 1234 --project "YourProject" --team "Your Team"

# Create a BRD for an Epic
/brd AB#1234 --project "YourProject" --team "Your Team"
```
