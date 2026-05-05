---
description: >
  Show velocity trends across multiple sprints for a project/team.
  Covers: committed vs completed points, completion rate %, bug count, and carry-over trends.
  Outputs a clean chat report with optional PPT or PDF export.

  Usage:
    /velocity --project "IRIS" --team "IRIS Team"
    /velocity --project "VCS"  --team "VCS team"
    /velocity --project "IRIS" --team "IRIS Team" --sprints 10
    /velocity --project "IRIS" --team "IRIS Team" --export ppt
    /velocity --project "IRIS" --team "IRIS Team" --export pdf

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --sprints   Optional. Number of sprints to look back. Default: 6.
    --export    Optional. Export format: "ppt" or "pdf". If omitted, chat output only.
---

Use the Azure DevOps MCP tools to fetch multi-sprint data and produce
a velocity trend report for the Scrum Master.

---

### 1. Parse arguments

Extract the following from `$ARGUMENTS`:

| Flag        | Required | Description                                              |
|-------------|----------|----------------------------------------------------------|
| `--project` | ✅ Yes   | ADO project name                                         |
| `--team`    | ✅ Yes   | ADO team name                                            |
| `--sprints` | ❌ No    | Number of completed sprints to analyse. Default: 6.      |
| `--export`  | ❌ No    | Export format: `ppt` or `pdf`. Omit for chat only.       |

**Flag rules:**
- `--sprints` must be a positive integer between 1 and 20. If out of range, clamp and notify.
- `--export ppt` → generate a PowerPoint file after chat output.
- `--export pdf` → generate a PDF report after chat output.
- If `--export` omitted → chat output only, then offer export at the end.

If `--project` or `--team` is missing, stop and respond:

~~~
❌ Missing required arguments.

Usage: /velocity --project "ProjectName" --team "TeamName"

Supported projects:
  /velocity --project "IRIS" --team "IRIS Team"
  /velocity --project "VCS"  --team "VCS team"
~~~

---

### 2. Fetch sprint iterations

Call `wit_get_iterations` for the project/team.

- Filter to completed iterations only (end date in the past).
- Sort by end date descending.
- Take the most recent `[--sprints]` iterations (default 6).
- Re-order oldest → newest for charting left to right.

If fewer completed sprints exist than requested:

~~~
⚠️ Only [N] completed sprints found for [--project] / [--team].
   Showing all [N] available instead of [--sprints] requested.
~~~

---

### 3. Fetch data for each sprint

For each sprint in the list run:

**3a. Committed story points:**
~~~sql
SELECT [System.Id], [Microsoft.VSTS.Scheduling.StoryPoints], [System.WorkItemType]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case', 'Test Bug')
  AND [System.State] <> 'Removed'
~~~
→ Sum = `committed`

**3b. Completed story points (velocity):**
~~~sql
SELECT [System.Id], [Microsoft.VSTS.Scheduling.StoryPoints], [System.WorkItemType]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.State] = 'Done'
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case', 'Test Bug')
~~~
→ Sum = `completed`
→ `completionRate = round(completed ÷ committed × 100)%`

**3c. Carry-over items:**
~~~sql
SELECT [System.Id], [Microsoft.VSTS.Scheduling.StoryPoints], [System.WorkItemType]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.State] IN (
    'To Do', 'On Hold', 'Waiting for requirements', 'Blockers', 'Dev Review',
    'In Progress', 'In Code Review', 'Deployed to Dev', 'Deployed to QA',
    'Deployed to UAT', 'Deployed to STG', 'Ready for Test'
  )
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case')
~~~
→ Count = `carryOverCount`
→ Sum = `carryOverPts`

**3d. Bugs raised:**
~~~sql
SELECT [System.Id], [System.WorkItemType], [System.State]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.WorkItemType] IN ('Prod Bug', 'Regression Bug', 'UAT Bug', 'Test Bug')
~~~
→ Count total = `bugsTotal`
→ Count resolved (Done) = `bugsResolved`
→ `bugsOpen = bugsTotal - bugsResolved`

Build `SprintMetrics[]` array ordered oldest → newest.

---

### 4. Calculate summary statistics

~~~
avgVelocity       = average completed pts across all sprints
avgCompletionRate = average completionRate %
avgBugs           = average bugsTotal
avgCarryOver      = average carryOverCount

velocityTrend:
  last3Avg  = average completed of last 3 sprints
  first3Avg = average completed of first 3 sprints
  "📈 Improving" if last3Avg > first3Avg × 1.10
  "📉 Declining" if last3Avg < first3Avg × 0.90
  "➡️ Stable"    otherwise

predictedNext = weighted avg of last 3 sprints:
  (mostRecent × 3 + middle × 2 + oldest × 1) ÷ 6

bestSprint     = highest completed pts
worstSprint    = lowest completionRate %
mostBugs       = highest bugsTotal
cleanestSprint = lowest carryOverCount (0 preferred)
~~~

---

### 5. Display velocity report in chat

~~~
Velocity Report — [--project]  |  [--team]
Sprints analysed: [N]  ([oldest sprint] → [newest sprint])
Generated: [Date]
────────────────────────────────────────────────────────────────────

📊 TREND SUMMARY
  Average velocity:       [N]pt / sprint
  Average completion:     [N]%
  Average bugs/sprint:    [N]
  Average carry-over:     [N] items/sprint
  Velocity trend:         [📈 Improving / 📉 Declining / ➡️ Stable]
  Predicted next sprint:  ~[N]pt  (weighted avg of last 3 sprints)

────────────────────────────────────────────────────────────────────

📋 SPRINT-BY-SPRINT BREAKDOWN

Sprint            Committed  Completed  Rate      Carry-over  Bugs
────────────────────────────────────────────────────────────────────
[Sprint Name]     [N]pt      [N]pt      ✅ [N]%   ✅ [N]      [N]
[Sprint Name]     [N]pt      [N]pt      ⚠️ [N]%   ⚠️ [N]      [N]
[Sprint Name]     [N]pt      [N]pt      🔴 [N]%   🔴 [N]      [N]
────────────────────────────────────────────────────────────────────
Average           [N]pt      [N]pt      [N]%      [N] items   [N]

Rate indicators:  ✅ ≥ 80%   ⚠️ 60–79%   🔴 < 60%
Carry-over:       ✅ = 0     ⚠️ 1–2      🔴 3+
Bugs:             ✅ ≤ avg   ⚠️ avg+1–3  🔴 avg+4+

────────────────────────────────────────────────────────────────────

📈 VELOCITY TREND  (committed vs completed)

[Sprint 1]  ████████████████░░░░  [completed]pt / [committed]pt  ([N]%)
[Sprint 2]  ██████████████████░░  [completed]pt / [committed]pt  ([N]%)
[Sprint 3]  ████████████████████  [completed]pt / [committed]pt  ([N]%)
...
Legend: █ completed   ░ committed but not completed
Scale:  20 chars = [maxCommitted]pt

────────────────────────────────────────────────────────────────────

🐛 BUG TREND

[Sprint 1]  🔴🔴🔴🔴🔴  [N] total  ([N] resolved · [N] open)
[Sprint 2]  🔴🔴🔴       [N] total  ([N] resolved · [N] open)
[Sprint 3]  🔴🔴         [N] total  ([N] resolved · [N] open)
...
(1 🔴 per bug · max 10 shown · "+N more" if over 10)

────────────────────────────────────────────────────────────────────

📦 CARRY-OVER TREND

[Sprint 1]  ⬜⬜⬜⬜  [N] items  ([N]pt)
[Sprint 2]  ⬜⬜      [N] items  ([N]pt)
[Sprint 3]  ✅        0 items   (clean sprint!)
...
(1 ⬜ per item · max 8 shown)

────────────────────────────────────────────────────────────────────

🏆 HIGHLIGHTS
  Best sprint:      [Sprint Name]  — [N]pt completed  ([N]% rate)
  Worst rate:       [Sprint Name]  — [N]% completion
  Most bugs:        [Sprint Name]  — [N] bugs raised
  Cleanest sprint:  [Sprint Name]  — [N] carry-over items

⚡ SM INSIGHTS
  [Generate 2–4 contextual insights from data. Examples:]
  • "Velocity improved [N]pt over last 3 sprints — momentum is positive."
  • "Completion rate dropped below 80% in [N] of [N] sprints — review estimation."
  • "Bug count trending up — consider a mid-sprint triage ceremony."
  • "Carry-over consistent at ~[N] items — stories may need better splitting."
  • "Predicted next sprint: ~[N]pt based on weighted recent trend."
~~~

**Bar chart rendering:**
- Scale to max 20 chars. `barWidth = round((value ÷ maxValue) × 20)`
- `█` = completed portion · `░` = committed gap

---

### 6. Handle --export ppt

3-slide PowerPoint (dark navy/charcoal, matching /retro palette):

**Slide 1 — Overview**
~~~
Background: navy (1E2761)
Title:      "Velocity Report — [--project] / [--team]"  — white, 36pt, Trebuchet MS bold
Subtitle:   "[oldest] → [newest]  ·  [N] sprints"  — teal, 18pt
4 stat cards: Avg Velocity · Avg Completion % · Avg Bugs · Avg Carry-over
              mint if trending positive · coral if trending negative
~~~

**Slide 2 — Velocity & Completion Rate**
~~~
Background: charcoal (2E4057)
Left:  Grouped COLUMN — Committed (charcoal) vs Completed (teal) per sprint
Right: LINE — Completion rate % per sprint (teal line)
       Dashed coral horizontal line at 80% threshold labelled "Target"
~~~

**Slide 3 — Bugs, Carry-over & Insights**
~~~
Background: navy (1E2761)
Left:   Stacked COLUMN — Bugs resolved (mint) + open (coral) per sprint
Right:  COLUMN — Carry-over items per sprint (amber bars)
Bottom: SM Insights bullet list — white text, 13pt
~~~

Save as: `velocity-[project]-[team]-[YYYY-MM-DD].pptx`

---

### 7. Handle --export pdf

Single-page PDF:

~~~
Header:    "Velocity Report — [--project] / [--team]  ·  [Date]"
Section 1: Trend Summary (4 key metrics)
Section 2: Sprint-by-sprint table
Section 3: SM Insights bullet list
Section 4: ASCII bar charts (velocity + bugs + carry-over)
Footer:    "Generated by /velocity shortcut via Claude  ·  [--project] / [--team]"
~~~

Save as: `velocity-[project]-[team]-[YYYY-MM-DD].pdf`

---

### 8. Handle insufficient data

If fewer than 2 completed sprints exist:

~~~
⚠️ Not enough data for [--project] / [--team].
   Velocity trends require at least 2 completed sprints.
   Found: [N] completed sprint(s).

   Check the current sprint instead:
   /sprint --project "[--project]" --team "[--team]"
~~~

---

### 9. Follow-up prompt

After the report, show:

> **Next options:**
> - Export as PowerPoint: `/velocity --project "[--project]" --team "[--team]" --sprints [N] --export ppt`
> - Export as PDF:        `/velocity --project "[--project]" --team "[--team]" --sprints [N] --export pdf`
> - Widen the range:      `/velocity --project "[--project]" --team "[--team]" --sprints 10`
> - Other project:        `/velocity --project "VCS" --team "VCS team"`
> - Run retro:            `/retro --project "[--project]" --team "[--team]"`
> - Check current sprint: `/sprint --project "[--project]" --team "[--team]"`