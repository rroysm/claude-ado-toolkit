---
description: >
  Show all open sprint items for the entire team, grouped by status then by team member. Scrum Master view.
  Shows days remaining, last sprint velocity, and flags blockers.

  Usage:
    /sprint --project "IRIS" --team "IRIS Team"
    /sprint --project "VCS"  --team "VCS team"
    /sprint --project "IRIS" --team "IRIS Team" --all

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --all       Optional. Includes Done items in the output

  Team estimation model (hardcoded):
    Sprint length:        10 working days (2 weeks)
    Working hours/day:    8h total · 6h effective (2h overhead for ceremonies/meetings)
    AI assistance:        Claude Code active — ~33% uplift applied (÷4 ratio default)
    Story point scale:
      1pt  = ~2h  (AI-assisted; trivial)
      2pt  = ~3h  (AI-assisted; small)
      3pt  = ~6h  (AI-assisted; moderate)
      5pt  = ~16h (AI-assisted; complex)
      8pt  = ~30h (AI-assisted; large)  ← max acceptable per story
      13pt = must be split before sprint regardless of AI assistance

  Status lists (type-aware):
    User Story / Enhancement — Proposed:
      To Do · On Hold · Waiting for requirements · Blockers · Dev Review
    User Story / Enhancement — In Progress:
      In Progress · In Code Review · Deployed to Dev · Deployed to QA ·
      Deployed to UAT · Deployed to STG · Ready for Test
    User Story / Enhancement — Completed:
      Done

    All Bug Types — Proposed:
      To Do · On Hold · Blockers · Dev Review
    All Bug Types — In Progress:
      In Progress · In Code Review · Deployed to Dev · Deployed to QA ·
      Deployed to UAT · Deployed to STG · Ready for Test
    All Bug Types — Completed:
      Done
---

Use the Azure DevOps MCP tools to fetch the full sprint board for all team members.

---

### Team Estimation Reference (apply throughout)

| Points | Effort          | Human Hours (AI-assisted) | Notes                               |
|--------|-----------------|---------------------------|-------------------------------------|
| 1pt    | ~0.25–0.5 days  | ~2h                       |                                     |
| 2pt    | ~0.5 days       | ~3h                       |                                     |
| 3pt    | ~1 day          | ~6h                       |                                     |
| 5pt    | ~2–3 days       | ~16h                      |                                     |
| 8pt    | ~4–5 days       | ~30h                      | Max acceptable — review size        |
| 13pt   | >1 week         | ~50h+                     | ❌ Must be split before sprint       |

- Sprint = 10 working days · Effective hours/day = 6h (8h minus 2h overhead)
- **AI assistance: Claude Code active — ~33% uplift applied**
- Sprint capacity = `team members × days available × 6h ÷ 4`

---

### Status Reference (apply throughout)

#### User Story / Enhancement
| Category    | Status                   | Emoji |
|-------------|--------------------------|-------|
| Proposed    | To Do                    | ⚪    |
| Proposed    | On Hold                  | 🔴    |
| Proposed    | Waiting for requirements | 🟠    |
| Proposed    | Blockers                 | 🚨    |
| Proposed    | Dev Review               | 🟡    |
| In Progress | In Progress              | 🔵    |
| In Progress | In Code Review           | 🔵    |
| In Progress | Deployed to Dev          | 🟢    |
| In Progress | Deployed to QA           | 🟢    |
| In Progress | Deployed to UAT          | 🟢    |
| In Progress | Deployed to STG          | 🟢    |
| In Progress | Ready for Test           | 🟢    |
| Completed   | Done                     | ✅    |

#### All Bug Types
| Category    | Status         | Emoji |
|-------------|----------------|-------|
| Proposed    | To Do          | ⚪    |
| Proposed    | On Hold        | 🔴    |
| Proposed    | Blockers       | 🚨    |
| Proposed    | Dev Review     | 🟡    |
| In Progress | In Progress    | 🔵    |
| In Progress | In Code Review | 🔵    |
| In Progress | Deployed to Dev| 🟢    |
| In Progress | Deployed to QA | 🟢    |
| In Progress | Deployed to UAT| 🟢    |
| In Progress | Deployed to STG| 🟢    |
| In Progress | Ready for Test | 🟢    |
| Completed   | Done           | ✅    |

---

### 1. Parse arguments

| Flag        | Required | Description                          |
|-------------|----------|--------------------------------------|
| `--project` | ✅ Yes   | ADO project name                     |
| `--team`    | ✅ Yes   | ADO team name                        |
| `--all`     | ❌ No    | Include Done items in the output     |

If `--project` or `--team` is missing, stop and respond:

~~~
❌ Missing required arguments.

Usage: /sprint --project "ProjectName" --team "TeamName"

Supported projects:
  /sprint --project "IRIS" --team "IRIS Team"
  /sprint --project "VCS"  --team "VCS team"
~~~

---

### 2. Fetch sprint metadata

Call `wit_get_iterations` for the project/team to fetch the current active iteration.

Extract and store: `Iteration Name`, `Start Date`, `End Date`

**Calculate days remaining:**
- `Days Elapsed   = Today's date − Start Date` (working days only, exclude weekends)
- `Total Days     = 10` (fixed sprint length)
- `Days Remaining = 10 − Days Elapsed`
- If a public holiday falls within the sprint window, subtract it and note:
  ~~~
  ⚠️ Note: [Holiday Name] on [Date] reduces effective sprint days to [N].
  ~~~

**Effective hours remaining per member:**
- `Hours Remaining = Days Remaining × 6h`

**Fetch last sprint velocity:**
- Identify the immediately previous iteration.
- Run WIQL for that iteration:

~~~sql
SELECT [System.Id], [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.IterationPath] = '[Previous Iteration Path]'
  AND [System.State] = 'Done'
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case')
~~~

- Sum story points → `Last Sprint Velocity`.
- If no data → display `Last sprint: No data`.

---

### 3. Query all sprint work items

~~~sql
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType],
       [System.AssignedTo], [Microsoft.VSTS.Scheduling.StoryPoints],
       [System.ChangedDate]
FROM WorkItems
WHERE [System.IterationPath] = @CurrentIteration('[--project]\[--team]')
  AND [System.State] <> 'Done'
ORDER BY [System.State], [System.AssignedTo], [System.WorkItemType]
~~~

If `--all` is present, remove the `[System.State] <> 'Done'` filter.

`[System.ChangedDate]` is used to detect stale/blocked items.

---

### 4. Handle empty results

~~~
⚠️ No items found for project "[--project]" / team "[--team]".
   - Check that the project and team names are correct.
   - Try: /sprint --project "[--project]" --team "[--team]" --all
~~~

---

### 5. Display results — each status as its own section

Show every status that has at least 1 item as its own section.
Within each section, group by team member.
Order sections as listed in the Status Reference above (Proposed first, then In Progress, then Done).
Skip empty status sections entirely — do not show sections with 0 items.

Use this format:

~~~
Project: [--project]  |  Team: [--team]
Sprint:  [Iteration Name]    [Start Date] → [End Date]
         Day [N] of 10  ·  [N] days remaining  ·  [N×6]h effective remaining/member
         Last sprint: [N]pt completed  (velocity reference)
────────────────────────────────────────────────────────────────────

— PROPOSED ——————————————————————————————————————————————————————————

⚪ To Do (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago
  👤 Unassigned (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🔴 On Hold (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟠 Waiting for requirements (N items · Xpts · ~Xh)   ← Stories/ENH only
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🚨 Blockers (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟡 Dev Review (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

— IN PROGRESS ———————————————————————————————————————————————————————

🔵 In Progress (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🔵 In Code Review (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟢 Deployed to Dev (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟢 Deployed to QA (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟢 Deployed to UAT (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟢 Deployed to STG (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

🟢 Ready for Test (N items · Xpts · ~Xh)
  👤 [Member Name] (N · Xpts · ~Xh)
    [Type]  Ticket ID [id]  [Xpt ~Xh]  [Title]  · updated [N]d ago

— COMPLETED ————————————————————————————————————————————————————————

✅ Done (N items · Xpts)  ← only shown with --all
  👤 [Member Name] (N · Xpts)
    [Type]  Ticket ID [id]  [Xpt]  [Title]

────────────────────────────────────────────────────────────────────
Team Total:    [N] items  |  [X]pts committed  |  ~[X]h total effort
               [X]pts done  |  [X]pts remaining
Last sprint:   [N]pts completed  (velocity reference)
Members:       [N] on sprint  |  Unassigned items: [N]

Status breakdown:
  Proposed:    To Do([N]) · On Hold([N]) · Waiting([N]) · Blockers([N]) · Dev Review([N])
  In Progress: In Progress([N]) · In Code Review([N]) · Dev([N]) · QA([N]) · UAT([N]) · STG([N]) · Ready for Test([N])
  Completed:   Done([N])
~~~

**Effort display:**
- 1pt → ~3h · 3pt → ~9h · 5pt → ~24h · 8pt → ~45h · 13pt → ~65h
- Show `~Xh` next to story points for every item and member subtotal.
- No points → display `[—pt]`

**Work item type prefixes:**
- `[BR]`    → Business Requirement
- `[DF]`    → Datafix
- `[ENH]`   → Enhancement
- `[Epic]`  → Epic
- `[PB]`    → Prod Bug
- `[RB]`    → Regression Bug
- `[Sub]`   → Subtask
- `[Task]`  → Task
- `[TB]`    → Test Bug
- `[TC]`    → Test Case
- `[UAT]`   → UAT Bug
- `[Story]` → User Story
- Use raw type name for anything not listed above

**Last updated:** `· updated [N]d ago` from `[System.ChangedDate]`. Show `today` if updated today.

**Member name:** Display name only (strip email). Empty → `Unassigned` at bottom of section.

**Type-aware status note:**
- `Waiting for requirements` only applies to User Story and Enhancement.
- If a Bug appears in a status that doesn't exist in its type's list, flag it:
  ~~~
  ⚠️ Ticket ID [id] [Bug Type] is in state "[State]" which is not valid for this type — flag for SM.
  ~~~

---

### 6. Scrum Master risk flags

After the board, scan and call out:

~~~
⚠️  Risk Flags
────────────────────────────────────────────────────────────────────
[!] [Member Name] has [N] items in Proposed (To Do/Dev Review) — not yet started
[!] [Member Name] has [N] items On Hold — needs follow-up
[!] [Member Name] has [N] items Waiting for requirements — blocked on BA/PO
[!] [N] items in Blockers status — immediate SM attention needed
[!] [Member Name] has [N] Active items with no story points estimated
[!] [N] unassigned items in sprint — needs owner assignment
[!] [Member Name] appears overloaded: [X]pts (~[X]h active) vs [N] days remaining (~[X]h available)
[!] [Member Name] has [N] open bugs (PB/RB/UAT/TB) in Proposed — not yet started
[!] STALE: Ticket ID [id] "[Title]" ([Xpt ~Xh]) in "[Status]" for [N] days with no update — [Member Name]
[!] OVERSIZE: Ticket ID [id] "[Title]" is 13pt (~65h) — exceeds sprint length, must be split
~~~

Only show flags that apply. Skip entirely if no risks.

**Thresholds:**
- "Not yet started" → member has 2+ items in any Proposed status (To Do, Dev Review)
- "On Hold" → any item in On Hold status → always flag individually
- "Waiting for requirements" → any item in this status → always flag individually
- "Blockers status" → any item with state = `Blockers` → 🚨 immediate flag regardless of count
- "No story points" → any In Progress item missing points (skip Task, Sub, DF types)
- "Overloaded" → member's In Progress effort (~h) exceeds remaining capacity (`days remaining × 6h`)
- "Unassigned" → any item where AssignedTo is empty
- "Open bugs" → member has 2+ bug items in any Proposed status
- "Stale" → any item in In Progress group where `[System.ChangedDate]` is 3+ working days ago
- "Oversize" → any item estimated at 13pt

**Overload calculation:**
~~~
Member remaining capacity = Days Remaining × 6h
Member active effort      = Sum of ~h for all items in In Progress group
Overloaded if: active effort > remaining capacity
~~~

Example: 4 days remaining = 24h available. Member has 5pt + 8pt In Progress = ~24h + ~45h = ~69h → overloaded by ~45h.

---

### 7. Follow-up prompt

After the board and risk flags, show:

> **Next:** Type `/implement Ticket ID [id]` to start working on any item, or ask me to summarise blockers, capacity, or risk for the sprint.
>
> To view a different project: `/sprint --project "VCS" --team "VCS team"`
>
> If you see Proposed items that haven't been refined yet, run:
> `/refine --project "[--project]" --team "[--team]" --current`