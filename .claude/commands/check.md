---
description: >
  Deep-dive quality check on a single ADO work item before development starts.
  Scores it across 8 dimensions using the same RAG rubric as /refine.
  Works on all work item types: User Story, Enhancement, and all Bug types.
  Generates suggested Acceptance Criteria if AC is missing or Red.
  Posts a quality report as a comment on the ADO work item (with confirmation).

  Usage:
    /check 1234 --project "IRIS" --team "IRIS Team"
    /check 1234 --project "VCS"  --team "VCS team"
    /check 1234 --project "IRIS" --team "IRIS Team" --dry-run

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --dry-run   Optional. Preview the ADO comment in chat without posting it

  Supported work item types:
    User Story · Enhancement · Prod Bug · Regression Bug · UAT Bug · Test Bug

  Scoring model (same as /refine):
    8 dimensions · RAG rating per dimension (🟢 Green / 🟡 Amber / 🔴 Red)
    ✅ READY      → 7–8 🟢 Green · No 🔴 Red
    ⚠️ NEEDS WORK → 4–6 🟢 Green · or 1–2 🔴 Red
    ❌ NOT READY  → 3+ 🔴 Red

  Team estimation model (same as /refine):
    Sprint = 10 working days · 6h effective/day · Claude Code active (~33% AI uplift)
    1pt=~2h · 2pt=~3h · 3pt=~6h · 5pt=~16h · 8pt=~30h · 13pt=must split (AI-assisted)
---

Use the Azure DevOps MCP tools to fetch and score a single work item.

---

### 1. Parse arguments

Extract the work item ID and flags from `$ARGUMENTS`:

| Input       | Required | Description                                          |
|-------------|----------|------------------------------------------------------|
| Ticket ID   | ✅ Yes   | Work item ID (numeric, e.g. 1234 — also accepts AB#1234) |
| `--project` | ✅ Yes   | ADO project name                                     |
| `--team`    | ✅ Yes   | ADO team name                                        |
| `--dry-run` | ❌ No    | Preview ADO comment in chat without posting          |

**Parsing rules:**
- Accept `AB#1234`, `AB# 1234`, or just `1234` as the work item ID.
- Strip the `AB#` prefix and use the numeric ID for ADO API calls.
- Default (no `--dry-run`) → post to ADO after confirmation.
- `--dry-run` → show preview only, never post.

If work item ID is missing, stop and ask:

~~~
❓ Which work item should I check?

Usage: /check [id] --project "ProjectName" --team "TeamName"

Examples:
  /check 1234 --project "IRIS" --team "IRIS Team"
  /check 1234 --project "VCS"  --team "VCS team"
~~~

If `--project` or `--team` is missing:

~~~
❌ Missing required arguments.

Usage: /check [id] --project "ProjectName" --team "TeamName"

Supported projects:
  /check [id] --project "IRIS" --team "IRIS Team"
  /check [id] --project "VCS"  --team "VCS team"
~~~

---

### 2. Fetch the work item

Call `wit_get_work_item` with the parsed ID.
First read `[System.WorkItemType]` to determine which field set to fetch.

---

#### 📋 User Story / Enhancement — fetch:
- `[System.Title]`
- `[System.State]`
- `[System.AssignedTo]`
- `[System.Description]` — business context / user story narrative
- `[Microsoft.VSTS.Common.AcceptanceCriteria]` — testable AC
- `[Microsoft.VSTS.Scheduling.StoryPoints]` — effort estimate
- `[Microsoft.VSTS.Common.Priority]` — 1=Critical · 2=High · 3=Medium · 4=Low
- `[System.Parent]` — parent Epic or Feature (fetch parent title too)
- `[System.IterationPath]` — sprint assignment
- Linked work items — Tasks, Subtasks, Test Cases
- Tags / comments — dependency notes, DoR sign-off

---

#### 🐛 Prod Bug / Regression Bug / UAT Bug / Test Bug — fetch:
- `[System.Title]`
- `[System.State]`
- `[System.AssignedTo]`
- `[System.Description]` — bug description and context
- `[Microsoft.VSTS.TCM.ReproSteps]` — steps to reproduce
- `[Microsoft.VSTS.TCM.SystemInfo]` or comments — actual results observed
- `[Microsoft.VSTS.Common.AcceptanceCriteria]` — expected results / definition of fixed
- `[Microsoft.VSTS.Common.Priority]` — 1=Critical · 2=High · 3=Medium · 4=Low
- `[Microsoft.VSTS.Common.Severity]` — 1=Critical · 2=High · 3=Medium · 4=Low
- `[System.Parent]` — parent Story, Epic, or Feature (fetch parent title too)
- `[System.IterationPath]` — sprint assignment
- Linked work items — Test Cases, related items
- Tags / comments — dependency notes

---

#### ⛔ Unsupported type — stop and respond:

~~~
⚠️ Ticket ID [id] is a [WorkItemType] — /check only supports:
   User Story · Enhancement · Prod Bug · Regression Bug · UAT Bug · Test Bug

   Tasks and Subtasks are scored as part of their parent story.
   Try checking the parent instead:
   /check [parent id] --project "[--project]" --team "[--team]"
~~~

---

### 3. Score across 8 dimensions

Same rubric as /refine. RAG per dimension. Apply type-specific mappings for bugs.

---

#### Dimension 1 — Acceptance Criteria
| Rating    | Story / Enhancement                                                                   | Bug                                             |
|-----------|---------------------------------------------------------------------------------------|-------------------------------------------------|
| 🟢 Green  | 3+ testable AC in Given/When/Then. Covers happy path + at least one edge case.        | Expected results clearly defined and testable.  |
| 🟡 Amber  | AC present but vague, untestable, or missing edge cases.                              | Expected results present but incomplete.        |
| 🔴 Red    | No acceptance criteria.                                                               | No expected results defined.                   |

**→ If 🔴 Red: auto-generate suggested AC in Step 5.**

---

#### Dimension 2 — Story Points (team scale)
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Points assigned: 1, 2, 3, 5, or 8 (team scale). |
| 🟡 Amber  | Points not on team scale (e.g. 4, 6, 7, 10–12pt) — re-estimate needed. |
| 🔴 Red    | No points assigned. |

> Team scale: 1, 2, 3, 5, 8, 13. 2pt valid for small AI-assisted tasks (~3h). 8pt = max acceptable. 13pt = must split.

---

#### Dimension 3 — Description / Business Context
| Rating    | Story / Enhancement                                           | Bug                                                     |
|-----------|---------------------------------------------------------------|---------------------------------------------------------|
| 🟢 Green  | "As a / I want / So that" or clear business value explained.  | Steps to reproduce + actual results both present.       |
| 🟡 Amber  | Description exists but lacks context or the "why".            | Steps present but actual results missing or vague.      |
| 🔴 Red    | No description or placeholder ("TBD", "See email").           | No steps to reproduce and no actual results.            |

---

#### Dimension 4 — Linked Tasks / Subtasks
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | 2+ child Tasks or Subtasks linked and meaningfully titled. |
| 🟡 Amber  | 1 task linked, or tasks are vaguely titled. |
| 🔴 Red    | No linked tasks or subtasks. |

---

#### Dimension 5 — Linked Test Cases
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | 1+ Test Cases linked. |
| 🟡 Amber  | No Test Cases but testing approach described in AC or comments. |
| 🔴 Red    | No test cases and no mention of testing approach. |

---

#### Dimension 6 — Dependencies Noted
| Rating    | Criteria |
|-----------|----------|
| 🟢 Green  | Dependencies explicitly noted (linked items, tags, or description). |
| 🟡 Amber  | Possible dependency implied but not formally noted. |
| 🔴 Red    | No dependency info despite apparent external dependencies. |

> No apparent dependencies → default 🟢 Green.

---

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

---

#### Dimension 8 — Size / Splittability
| Rating    | Story / Enhancement                                                       | Bug                                                       |
|-----------|---------------------------------------------------------------------------|-----------------------------------------------------------|
| 🟢 Green  | 1–8pt — deliverable within a 10-day sprint (~30h max at 8pt with AI).    | Clearly scoped and fixable within a single sprint.        |
| 🟡 Amber  | Not on team scale (10–12pt) — re-estimate needed.                         | Scope unclear — may affect multiple areas.                |
| 🔴 Red    | 13pt+ — exceeds sprint capacity even with AI assistance. Must be split.   | Fix spans multiple sprints or components — split needed.  |

---

### 4. Classify the work item

| Classification  | Criteria                              |
|-----------------|---------------------------------------|
| ✅ READY         | 7–8 🟢 Green · No 🔴 Red              |
| ⚠️ NEEDS WORK    | 4–6 🟢 Green · or 1–2 🔴 Red         |
| ❌ NOT READY     | 3+ 🔴 Red                             |

---

### 5. Generate suggested AC (only if D1 = 🔴 Red)

**For User Story / Enhancement — Given/When/Then:**

~~~
💡 Suggested Acceptance Criteria for Ticket ID [id]:

Given [context or precondition]
When  [action or trigger]
Then  [expected outcome]

Given [context]
When  [action]
Then  [expected outcome]

Given [context]
When  [action]
Then  [expected outcome — edge case or negative path]

Note: AI-generated from title and description. Review with team before accepting.
~~~

**For Bugs — Expected Results format:**

~~~
💡 Suggested Expected Results for Ticket ID [id]:

1. [Expected behaviour when the bug is fixed — specific and testable]
2. [Expected system state or response]
3. [Edge case or boundary condition that should also pass]

Note: AI-generated from bug title and description. Confirm with reporter before accepting.
~~~

**If D3 is also 🔴 Red (no description):**

~~~
⚠️ Cannot generate AC — description is also missing.
   Ask the author to add a description first, then re-run /check.
~~~

---

### 6. Build the quality report

~~~
🔍 Work Item Quality Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ticket ID [id]  [WorkItemType]  |  [--project] / [--team]
"[Title]"
Parent:      [Parent Title]  (Ticket ID [parent id])
Sprint:      [Iteration Name]
Assigned to: [Member Name]
Priority:    [P1 Critical / P2 High / P3 Medium / P4 Low]
[Severity:   [S1/S2/S3/S4]  ← bugs only]
Checked:     [Date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dimension Scores:
  D1  Acceptance Criteria      → [🟢/🟡/🔴]  [one-line reason]
  D2  Story Points             → [🟢/🟡/🔴]  [one-line reason]
  D3  Description              → [🟢/🟡/🔴]  [one-line reason]
  D4  Linked Tasks/Subtasks    → [🟢/🟡/🔴]  [one-line reason]
  D5  Linked Test Cases        → [🟢/🟡/🔴]  [one-line reason]
  D6  Dependencies Noted       → [🟢/🟡/🔴]  [one-line reason]
  D7  Definition of Ready      → [🟢/🟡/🔴]  [one-line reason]
  D8  Story Size               → [🟢/🟡/🔴]  [one-line reason]

RAG Summary:  🟢 [N]  🟡 [N]  🔴 [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Classification: [✅ READY / ⚠️ NEEDS WORK / ❌ NOT READY]

[If NEEDS WORK or NOT READY:]
🔧 Fixes Required:
  🔴 D1 — [Specific fix]
  🔴 D3 — [Specific fix]
  🟡 D4 — [Specific fix]
  [Only Amber and Red dimensions listed]

[If D1 = 🔴 Red — append suggested AC here]

Estimation model: 1pt=~2h · 2pt=~3h · 3pt=~6h · 5pt=~16h · 8pt=~30h · 13pt=must split (AI-assisted)
Checked by: /check shortcut via Claude
~~~

---

### 7. Display report in chat

Always show the full report in chat first — regardless of `--dry-run`.

---

### 8. Handle --dry-run vs default

**If `--dry-run`:**

~~~
📋 DRY RUN — Comment NOT posted to ADO.
   Preview of what would be posted on Ticket ID [id].
   To post for real: /check [id] --project "[--project]" --team "[--team]"
~~~

**Default — confirm before posting:**

~~~
📝 Ready to post this quality report as a comment on Ticket ID [id].
   Project: [--project]  |  Team: [--team]

   Confirm? Reply "yes" to post or "no" to skip.
~~~

Wait for explicit "yes". Only post after confirmation.

---

### 9. Follow-up prompt

**If ✅ READY:**

> **Ticket ID [id] is ready for development.**
> Run `/implement [id] --project "[--project]" --team "[--team]"` to start.

**If ⚠️ NEEDS WORK or ❌ NOT READY:**

> **Ticket ID [id] needs attention before development starts.**
> Share the fixes above with [Assignee Name] and re-check once updated:
> `/check [id] --project "[--project]" --team "[--team]"`
>
> Check another item: `/check [id] --project "[--project]" --team "[--team]"`
> Batch-check the full sprint: `/refine --project "[--project]" --team "[--team]"`