---
description: >
  Run a quality check on all User Stories in the sprint backlog.
  Scores each story across 8 dimensions using a Red/Amber/Green rubric.
  Fetches sprint capacity dynamically from ADO per team.
  Flags stories that aren't ready before sprint planning.

  Usage:
    /refine --project "IRIS" --team "IRIS Team"
    /refine --project "VCS"  --team "VCS team"
    /refine --project "IRIS" --team "IRIS Team" --sprint "Sprint 15"
    /refine --project "IRIS" --team "IRIS Team" --current
    /refine --project "IRIS" --team "IRIS Team" --post
    /refine --project "IRIS" --team "IRIS Team" --dry-run
    /refine --project "IRIS" --team "IRIS Team" --ratio 8

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --sprint    Optional. Target a specific sprint by name
    --current   Optional. Target the active sprint instead of the next one
    --capacity  Optional. Manual override for sprint capacity in story points
    --ratio     Optional. Capacity divisor override (default: 4, AI-adjusted). Example: --ratio 6
    --dry-run   Optional. Preview ADO comments in chat without posting
    --post      Optional. Post quality comments back to each ADO work item

  Team estimation model (hardcoded):
    Sprint length:        10 working days (2 weeks)
    Working hours/day:    8h total · 6h effective (2h overhead for ceremonies/meetings)
    AI assistance:        Claude Code active — ~33% uplift applied (÷4 ratio default)
    Story point scale:
      1pt  = ~2h  (AI-assisted; trivial — single file, obvious change)
      2pt  = ~3h  (AI-assisted; small — 1–2 files, straightforward logic)
      3pt  = ~6h  (AI-assisted; moderate — clear requirements, known patterns)
      5pt  = ~16h (AI-assisted; complex — multiple files, design decisions)
      8pt  = ~30h (AI-assisted; large — cross-cutting, architectural thought)  ← max acceptable
      13pt = must be split before sprint regardless of AI assistance
    Capacity formula:
      Total capacity (hrs) = team members × days available × 6h
      Total capacity (pts) = Total capacity (hrs) ÷ 4  (AI-adjusted; use --ratio 6 to revert to pre-AI baseline)
---

Use the Azure DevOps MCP tools to batch quality-check all User Stories
in the sprint backlog before sprint planning.

---

### Team Estimation Reference (apply throughout)

Always use this model when scoring, calculating capacity, and making recommendations:

| Points | Effort          | Human Hours (AI-assisted) | Scoring note                        |
|--------|-----------------|---------------------------|-------------------------------------|
| 1pt    | ~0.25–0.5 days  | ~2h                       | ✅ Fine                              |
| 2pt    | ~0.5 days       | ~3h                       | ✅ Fine                              |
| 3pt    | ~1 day          | ~6h                       | ✅ Fine                              |
| 5pt    | ~2–3 days       | ~16h                      | ✅ Fine                              |
| 8pt    | ~4–5 days       | ~30h                      | ✅ Acceptable — review size at D8    |
| 13pt   | >1 week         | ~50h+                     | ❌ Exceeds sprint — must be split    |

- Sprint = 10 working days
- Effective hours/day = 6h (8h minus 2h ceremonies overhead)
- **AI assistance: Claude Code active — ~33% uplift applied**
- Default capacity formula: `members × days available × 6h ÷ 4 = pts`
- `--ratio` flag overrides the 4h/pt divisor if needed (use `--ratio 6` for pre-AI baseline)

---

### 1. Parse arguments

Extract the following from `$ARGUMENTS`:

| Flag         | Required | Description                                                        |
|--------------|----------|--------------------------------------------------------------------|
| `--project`  | ✅ Yes   | ADO project name                                                   |
| `--team`     | ✅ Yes   | ADO team name                                                      |
| `--sprint`   | ❌ No    | Target sprint by name. Overrides default sprint resolution.        |
| `--current`  | ❌ No    | Target the active (current) sprint instead of the next one.        |
| `--capacity` | ❌ No    | Manual capacity override in story points.                          |
| `--ratio`    | ❌ No    | Capacity divisor override. Default: 4 (AI-adjusted). Use 6 for pre-AI baseline. |
| `--dry-run`  | ❌ No    | Preview comment content in chat only — do NOT post to ADO.         |
| `--post`     | ❌ No    | Post quality comments back to ADO after confirmation.              |

**Flag rules:**
- `--sprint` and `--current` are mutually exclusive. If both passed, `--sprint` takes priority.
- `--dry-run` and `--post` are mutually exclusive. If both passed, use `--dry-run` and warn:
  ~~~
  ⚠️ Both --dry-run and --post were passed. Running in dry-run mode only.
     Remove --dry-run and re-run to post comments to ADO.
  ~~~
- Default `--ratio` is `4` (AI-adjusted; use `--ratio 6` to revert to pre-AI baseline).

If `--project` or `--team` is missing, stop and respond:

~~~
❌ Missing required arguments.

Usage: /refine --project "ProjectName" --team "TeamName"

Supported projects:
  /refine --project "IRIS" --team "IRIS Team"
  /refine --project "VCS"  --team "VCS team"
~~~

---

### 2. Resolve the target sprint

**Priority order:**
1. `--sprint "[name]"` provided → use that iteration path directly.
2. `--current` provided → use `@CurrentIteration('[--project]\[--team]')`.
3. Default → call `wit_get_iterations`, find iteration with nearest future start date.

If default finds no future sprint, fall back to current and notify:

~~~
⚠️ No upcoming sprint found for [--project] / [--team].
   Falling back to current sprint: [Iteration Name].
   To target a specific sprint: --sprint "Sprint Name"
   To explicitly target current sprint: --current
~~~

---

### 3. Fetch sprint capacity from ADO

Call `wit_get_team_capacity` for the resolved sprint and team.

**Capacity calculation using team model:**

~~~
For each member:
  Available Hours = Days Available × 6h  (effective hours/day)

Team Total Hours = Sum of all members' Available Hours
Sprint Capacity  = Team Total Hours ÷ [--ratio]  (default ratio: 4, AI-adjusted)
~~~

Always display the full breakdown:

~~~
Capacity Breakdown ([--ratio]h per point · 6h effective day · 10-day sprint)
─────────────────────────────────────────────────────────────────────────────
Member          Days Available   Eff. Hours (×6h)   Story Points (÷[ratio])
─────────────────────────────────────────────────────────────────────────────
[Name]          [N]              [N×6]h             [N÷ratio]pt
[Name]          [N]              [N×6]h             [N÷ratio]pt
─────────────────────────────────────────────────────────────────────────────
Team Total      [N] days         [N]h               [N]pt
~~~

**Fallback if ADO capacity returns no data:**
- Use `--capacity` value if provided.
- If neither available, stop and respond:

~~~
⚠️ Could not fetch capacity for [--project] / [--team] / [Sprint Name].
   Your team may not have filled in capacity in ADO for this sprint.

   Options:
   1. Fill in ADO: Sprints → [Sprint Name] → Capacity tab
      (Use 6h effective hours/day — 8h minus 2h overhead)
   2. Pass manually: --capacity [number]

   Example: /refine --project "[--project]" --team "[--team]" --capacity 60
~~~

---

### 4. Query work items in scope

Run `wit_query_work_items` with the following WIQL:

~~~sql
SELECT [System.Id], [System.Title], [System.State],
       [System.AssignedTo], [System.WorkItemType],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Priority],
       [Microsoft.VSTS.Common.Severity],
       [System.Description]
FROM WorkItems
WHERE [System.WorkItemType] IN (
        'User Story', 'Enhancement',
        'Prod Bug', 'Regression Bug', 'UAT Bug', 'Test Bug'
      )
  AND [System.IterationPath] = '[Resolved Iteration Path]'
  AND [System.State] IN ('To Do', 'On Hold', 'Waiting for requirements', 'Blockers', 'Dev Review')
ORDER BY [System.WorkItemType], [Microsoft.VSTS.Common.Priority] ASC
~~~

> **Note:** Replace `[Resolved Iteration Path]` with the iteration path resolved in Step 2.
> Only Proposed-group statuses are checked — items already In Progress have been refined.
> Results are ordered by type first, then priority so critical bugs surface at the top.

If 0 items returned:

~~~
⚠️ No items found in "[Sprint Name]" for [--project] / [--team].
   - Confirm items exist in this iteration in Proposed status:
     To Do · On Hold · Waiting for requirements · Blockers · Dev Review
   - Confirm work item types include: User Story, Enhancement, or any Bug type.
   - Try: /refine --project "[--project]" --team "[--team]" --sprint "Sprint Name"
~~~

---

### 5. Fetch full details per work item type

For each work item returned, call `wit_get_work_item` and fetch fields based on its type:

---

#### 📋 User Story / Enhancement
Fetch the following fields:
- `[System.Description]` — business context / user story narrative
- `[Microsoft.VSTS.Common.AcceptanceCriteria]` — testable AC
- `[Microsoft.VSTS.Scheduling.StoryPoints]` — effort estimate
- `[Microsoft.VSTS.Common.Priority]` — priority (1=Critical, 2=High, 3=Medium, 4=Low)
- `[System.Parent]` — parent Epic or Feature link
- Linked work items (Tasks, Subtasks, Test Cases)
- Tags / comments for dependency notes
- Definition of Ready field or tag

---

#### 🐛 All Bug Types (Prod Bug, Regression Bug, UAT Bug, Test Bug)
Fetch the following fields:
- `[System.Description]` — bug description and context
- `[Microsoft.VSTS.TCM.ReproSteps]` — steps to reproduce
- `[Microsoft.VSTS.TCM.SystemInfo]` or comments — actual results observed
- `[Microsoft.VSTS.Common.AcceptanceCriteria]` — expected results / definition of fixed
- `[Microsoft.VSTS.Common.Priority]` — priority (1=Critical, 2=High, 3=Medium, 4=Low)
- `[Microsoft.VSTS.Common.Severity]` — severity (1=Critical, 2=High, 3=Medium, 4=Low)
- `[System.Parent]` — parent Story, Epic, or Feature link
- Linked work items (Test Cases, related items)
- Tags / comments for dependency notes

> **Note:** For bugs, treat the following as the quality check basis:
> - "Acceptance Criteria" dimension → maps to Expected Results field
> - "Description" dimension → maps to Steps to Reproduce + Actual Results
> - If Steps to Reproduce or Actual/Expected Results are missing → flag as 🔴 Red on those dimensions

---

### 6. Score each story across 8 dimensions

Apply the rubric below. Each dimension gets 🟢 Green, 🟡 Amber, or 🔴 Red.
Use the team estimation model when evaluating Dimensions 2 and 8.

---

#### Dimension 1 — Acceptance Criteria
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | 3+ clear, testable AC in Given/When/Then or equivalent. Covers happy path + at least one edge case. |
| 🟡 Amber  | AC present but vague, untestable, or missing edge cases. |
| 🔴 Red    | No acceptance criteria. |

#### Dimension 2 — Story Points (team scale applied)
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Points assigned and value is 1, 2, 3, 5, or 8 (team scale). |
| 🟡 Amber  | Points assigned but not on team scale (e.g. 4, 6, 7, 10, 11, 12pt) — re-estimation needed. |
| 🔴 Red    | No story points assigned. |

> Team scale is: 1, 2, 3, 5, 8, 13. 2pt is valid for small AI-assisted tasks (~3h). 8pt = max acceptable per sprint.

#### Dimension 3 — Description / Business Context
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Clearly explains "As a / I want / So that" or equivalent business value. |
| 🟡 Amber  | Description exists but lacks business context or the "why". |
| 🔴 Red    | No description, or placeholder text (e.g. "TBD", "See email"). |

#### Dimension 4 — Linked Tasks / Subtasks
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | 2+ child Tasks or Subtasks linked and meaningfully titled. |
| 🟡 Amber  | 1 task linked, or tasks exist but are vaguely titled. |
| 🔴 Red    | No linked tasks or subtasks. |

#### Dimension 5 — Linked Test Cases
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | 1+ Test Cases linked to the story. |
| 🟡 Amber  | No Test Cases but testing approach described in AC or comments. |
| 🔴 Red    | No test cases and no mention of testing approach. |

#### Dimension 6 — Dependencies Noted
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Dependencies explicitly noted (linked items, tags, or description). |
| 🟡 Amber  | Possible dependency implied but not formally noted. |
| 🔴 Red    | No dependency info despite story appearing to have external dependencies. |

> No apparent dependencies → default 🟢 Green.

#### Dimension 7 — Definition of Ready

Score against the team DoR checklist (defined in CLAUDE.md). Criteria vary by project.

**State gate — check first (both projects):**
If state = "Waiting for Requirements" → 🔴 Red immediately. Skip remaining criteria.

**Criterion 1 — PO sign-off (IRIS only):**
Check `Reviewed` field = "Reviewed" AND `Reviewed By` = "Kaydi Garzon".
VCS stories: skip this criterion (not applicable).

**Criterion 2 — Design assets linked (both projects):**
For stories with any UI change: a Figma link or approved mockup must be present in
the description, comments, or attachments.
Backend-only stories (no UI changes): auto-pass.

**Criterion 3 — No open questions (both projects):**
Scan description and AC for: "TBD", "?", "pending", "to be confirmed", "TBC".
Any match → criterion fails.

**Scoring:**

| Rating   | Criteria |
|----------|----------|
| 🟢 Green | State ≠ "Waiting for Requirements" AND all applicable criteria pass. |
| 🟡 Amber | Exactly one criterion (2 or 3) fails. |
| 🔴 Red   | State = "Waiting for Requirements", OR two or more criteria fail. |

#### Dimension 8 — Story Size (team scale applied)
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Story is 1–8pt and deliverable within a 10-day sprint (~30h max at 8pt with AI assistance). |
| 🟡 Amber  | Story is not on team scale (e.g. 10, 11, 12pt) — re-estimate needed. |
| 🔴 Red    | Story is 13pt+ — exceeds full sprint capacity even with AI assistance. Must be split. |

---

### 7. Classify each story

| Classification  | Criteria |
|-----------------|----------|
| ✅ READY         | 7–8 🟢 Green. No 🔴 Red. |
| ⚠️ NEEDS WORK    | 4–6 🟢 Green, or 1–2 🔴 Red. |
| ❌ NOT READY     | 3+ 🔴 Red. |

---

### 8. Over-capacity drop candidates

Compare `Total backlog story points` vs `Sprint Capacity (pts)`.

If backlog pts > sprint capacity:

~~~
📉 Over Capacity
   Backlog: [N]pt  |  Sprint capacity: [N]pt  |  Over by: [N]pt (~[N]h)

Suggested drop candidates (lowest scored first, then highest pts):
  1. Ticket ID [id]  [Xpt ~Xh]  [Title]  — Score: [N]/8  ❌ NOT READY
  2. Ticket ID [id]  [Xpt ~Xh]  [Title]  — Score: [N]/8  ❌ NOT READY
  3. Ticket ID [id]  [Xpt ~Xh]  [Title]  — Score: [N]/8  ⚠️ NEEDS WORK
  ...
  Dropping these would free [N]pt (~[N]h), bringing backlog to [N]pt.
~~~

**Drop selection logic:**
1. NOT READY first → NEEDS WORK → READY
2. Within same classification: lowest score first
3. Within same score: highest story points first (frees most capacity)
4. Stop once dropping listed items brings backlog ≤ capacity

Skip this section if backlog ≤ sprint capacity.

---

### 9. Handle --dry-run and --post

**If `--dry-run`:**

~~~
📋 DRY RUN — Comments NOT posted to ADO
────────────────────────────────────────────────────────────────────
Ticket ID [id] "[Title]" — preview comment:

🔍 Story Quality Check — [Date]
Project: [--project]  |  Team: [--team]  |  Sprint: [Sprint Name]
Estimation model: 1pt=~2h · 2pt=~3h · 3pt=~6h · 5pt=~16h · 8pt=~30h · 13pt=must split (AI-assisted)

Dimension Scores:
  Acceptance Criteria      → [🟢/🟡/🔴]
  Story Points             → [🟢/🟡/🔴]
  Description              → [🟢/🟡/🔴]
  Linked Tasks/Subtasks    → [🟢/🟡/🔴]
  Linked Test Cases        → [🟢/🟡/🔴]
  Dependencies Noted       → [🟢/🟡/🔴]
  Definition of Ready      → [🟢/🟡/🔴]
  Story Size               → [🟢/🟡/🔴]

Classification: [✅ READY / ⚠️ NEEDS WORK / ❌ NOT READY]

Top issues to fix:
  - [Specific actionable feedback per Red/Amber dimension]

Checked by: /refine shortcut via Claude
────────────────────────────────────────────────────────────────────
To post for real: re-run with --post instead of --dry-run.
~~~

**If `--post`:** Show confirmation prompt first:

~~~
📝 Ready to post quality comments on [N] stories in ADO.
   Project: [--project]  |  Team: [--team]  |  Sprint: [Sprint Name]
   Estimation model: 6h effective day · [ratio]h per point

   Confirm? Reply "yes" to proceed or "no" to skip.
~~~

Wait for explicit "yes" before posting anything.

---

### 10. Output the sprint refinement report

~~~
Sprint Refinement Report — [Sprint Name]
Project: [--project]  |  Team: [--team]
Target:  [Next Sprint / Current Sprint / --sprint override]
Generated: [Date]
Estimation model: 1pt=~2h · 2pt=~3h · 3pt=~6h · 5pt=~16h · 8pt=~30h · 13pt=must split (AI-assisted)
────────────────────────────────────────────────────────────────────
Sprint Capacity (from ADO): [N]pt (~[N]h)  · [ratio]h/pt · 6h eff. day
Stories checked: [N]  |  Total backlog: [N]pt (~[N]h)

✅ READY (N stories)
  Ticket ID [id]  [Xpt ~Xh]  [Title]
    🟢🟢🟢🟢🟢🟢🟢🟢  Score: 8/8
  ...

⚠️ NEEDS WORK (N stories — fix before sprint planning)
  Ticket ID [id]  [Xpt ~Xh]  [Title]
    🟢🟢🟡🔴🟢🟢🟡🟢  Score: 5/8
    Top issue: [One-line summary of biggest gap]
  ...

❌ NOT READY (N stories — return to backlog)
  Ticket ID [id]  [Xpt ~Xh]  [Title]
    🔴🔴🟡🔴🟢🟡🔴🟢  Score: 2/8
    Top issue: [One-line summary of biggest gap]
  ...

────────────────────────────────────────────────────────────────────
Sprint Capacity:         [N]pt (~[N]h)
Ready story points:      [N]pt (~[N]h)
At-risk story points:    [N]pt (~[N]h)  (NEEDS WORK + NOT READY)
Backlog vs Capacity:     [Under by Npt / On target / Over by Npt (~Nh)]

Sprint capacity risk:    [🟢 LOW / 🟡 MEDIUM / 🔴 HIGH]
  🟢 LOW    → 80%+ stories READY
  🟡 MEDIUM → 60–79% stories READY
  🔴 HIGH   → fewer than 60% stories READY

Follow-up needed:
  [Assignee Name] → Ticket ID [id], Ticket ID [id]  (stories needing fixes)
  Unassigned      → Ticket ID [id]                  (if any)

Recommendation:
  [One of:]
  "Sprint backlog looks healthy. [N]/[N] stories ready (~[N]h). Capacity: [N]pt. Safe to plan."
  "[N] stories need refinement. At-risk: [N]pt (~[N]h). Schedule refinement before planning."
  "Sprint planning should be delayed — fewer than 60% of stories are ready. At-risk: [N]pt (~[N]h)."
~~~

---

### 11. Follow-up prompt

After the report, show:

> **Next options:**
> - Preview comments: `/refine --project "[--project]" --team "[--team]" --dry-run`
> - Post scores to ADO: `/refine --project "[--project]" --team "[--team]" --post`
> - Check current sprint: `/refine --project "[--project]" --team "[--team]" --current`
> - Other project: `/refine --project "VCS" --team "VCS team"`
> - Deep-dive a story: *"Why is Ticket ID [id] not ready?"*
> - View the full sprint board after refining: `/sprint --project "[--project]" --team "[--team]"`