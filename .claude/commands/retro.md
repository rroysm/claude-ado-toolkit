---
description: >
  Generate a Sprint Retrospective PowerPoint deck using the DROP / ADD / KEEP / IMPROVE format.
  Pulls sprint data from ADO: velocity, bugs, incomplete items, and team morale indicators.
  Compares current sprint against the previous sprint.
  Produces a dark-themed (navy/charcoal) professional .pptx file ready to present.

  Usage:
    /retro --project "IRIS" --team "IRIS Team"
    /retro --project "VCS"  --team "VCS team"
    /retro --project "IRIS" --team "IRIS Team" --sprint "Sprint 14"
    /retro --project "IRIS" --team "IRIS Team" --notes "Team felt overloaded this sprint"

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --sprint    Optional. Target a specific completed sprint by name. Defaults to current/last sprint.
    --notes     Optional. SM observations to include as seed points in the retro slides.

  Output:
    A .pptx file downloaded to your device.
    Slide deck covers: sprint summary, velocity comparison, bugs, incomplete items,
    DROP / ADD / KEEP / IMPROVE boards, action items, and team morale.

  Design:
    Dark theme — navy/charcoal palette, professional finish.
    Font pairing: Trebuchet MS (headers) + Calibri (body).
    Color palette:
      Primary:    1E2761 (navy)
      Secondary:  2E4057 (charcoal blue)
      Accent:     00B4D8 (bright teal)
      Light:      CAF0F8 (ice blue)
      White:      FFFFFF
      Warning:    F96167 (coral red — for bugs/risks)
      Success:    02C39A (mint green — for completed items)
---

When this shortcut is triggered, use the Azure DevOps MCP tools to fetch sprint data,
then generate a complete retrospective PowerPoint deck using PptxGenJS.

---

### 1. Parse arguments

Extract the following from `$ARGUMENTS`:

| Flag        | Required | Description                                               |
|-------------|----------|-----------------------------------------------------------|
| `--project` | ✅ Yes   | ADO project name                                          |
| `--team`    | ✅ Yes   | ADO team name                                             |
| `--sprint`  | ❌ No    | Target sprint name. Defaults to most recently completed.  |
| `--notes`   | ❌ No    | SM observations to seed the retro slides.                 |

If `--project` or `--team` is missing, stop and respond:

~~~
❌ Missing required arguments.

Usage: /retro --project "ProjectName" --team "TeamName"

Supported projects:
  /retro --project "IRIS" --team "IRIS Team"
  /retro --project "VCS"  --team "VCS team"
~~~

---

### 2. Resolve target sprint and previous sprint

Call `wit_get_iterations` to fetch all iterations with start/end dates.

- If `--sprint` is provided → use that iteration as the **current sprint**.
- If not → identify the most recently **completed** iteration (end date in the past).
- Identify the iteration immediately before it as the **previous sprint**.

Store:
- `currentSprint.name`, `currentSprint.startDate`, `currentSprint.endDate`
- `previousSprint.name`, `previousSprint.startDate`, `previousSprint.endDate`

---

### 3. Fetch ADO data for both sprints

Run the following queries for BOTH current and previous sprint:

**3a. Completed items (velocity):**
~~~sql
SELECT [System.Id], [System.Title], [System.WorkItemType],
       [Microsoft.VSTS.Scheduling.StoryPoints], [System.AssignedTo]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.State] = 'Done'
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case', 'Test Bug')
~~~
→ Sum story points = **Velocity**
→ Count items = **Completed count**

**3b. Incomplete / carried-over items:**
~~~sql
SELECT [System.Id], [System.Title], [System.WorkItemType],
       [Microsoft.VSTS.Scheduling.StoryPoints], [System.AssignedTo], [System.State]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.State] IN (
    'To Do', 'On Hold', 'Waiting for requirements', 'Blockers', 'Dev Review',
    'In Progress', 'In Code Review', 'Deployed to Dev', 'Deployed to QA',
    'Deployed to UAT', 'Deployed to STG', 'Ready for Test'
  )
  AND [System.WorkItemType] NOT IN ('Task', 'Subtask', 'Test Case')
~~~
→ List of items not completed = **Carry-over**
→ Sum story points = **At-risk points**
→ Group carry-over by status category:
  - Proposed (To Do, On Hold, Waiting for requirements, Blockers, Dev Review)
  - In Progress (In Progress, In Code Review, Deployed to Dev/QA/UAT/STG, Ready for Test)

**3c. Bugs raised during sprint:**
~~~sql
SELECT [System.Id], [System.Title], [System.WorkItemType],
       [Microsoft.VSTS.Common.Priority], [Microsoft.VSTS.Common.Severity],
       [System.AssignedTo], [System.State], [System.CreatedDate]
FROM WorkItems
WHERE [System.IterationPath] = '[Sprint Path]'
  AND [System.WorkItemType] IN ('Prod Bug', 'Regression Bug', 'UAT Bug', 'Test Bug')
ORDER BY [Microsoft.VSTS.Common.Priority] ASC
~~~
→ Total bugs raised, bugs by type, bugs resolved vs open = **Bug summary**

**3d. Team capacity (for commitment vs completed comparison):**
- Call `wit_get_team_capacity` for the sprint.
- Calculate committed pts = total story points pulled into sprint.
- Completed pts = velocity from 3a.
- Completion rate = `(completed ÷ committed) × 100`%

---

### 4. Build retro data structure

~~~
RetroData {
  currentSprint:  { name, dates, velocity, committed, completionRate, completedItems[], carryOver[], bugs[] }
  previousSprint: { name, dates, velocity, committed, completionRate, completedItems[], carryOver[], bugs[] }
  delta: {
    velocityChange:       currentVelocity - previousVelocity  (+ or -)
    completionRateChange: currentRate - previousRate
    bugCountChange:       currentBugs - previousBugs
    carryOverChange:      currentCarryOver - previousCarryOver
  }
  smNotes: [parsed from --notes if provided]
}
~~~

---

### 5. Generate the PowerPoint deck

Generate using PptxGenJS (already installed in package.json — do NOT run npm install):

**Color palette (use throughout):**
~~~javascript
const COLORS = {
  navy:    "1E2761",
  charcoal:"2E4057",
  teal:    "00B4D8",
  ice:     "CAF0F8",
  white:   "FFFFFF",
  coral:   "F96167",
  mint:    "02C39A",
  amber:   "F9C74F",
  muted:   "8899AA",
};
~~~

**Font pairing:** Trebuchet MS (headers, bold) + Calibri (body)

---

#### SLIDE 1 — Title Slide

~~~
Background: navy (1E2761)
Title:      "Sprint Retrospective"         — white, 44pt, Trebuchet MS bold, centered
Subtitle:   "[Sprint Name] · [Start] – [End Date]"  — teal, 22pt, centered
Team:       "[--project]  |  [--team]"     — muted, 16pt, centered
Date:       "[Today's Date]"               — muted, 12pt, bottom right
Visual:     Large semi-transparent teal circle behind title (30% opacity, decorative)
~~~

---

#### SLIDE 2 — Sprint at a Glance

**2×2 stat card grid, charcoal background:**

~~~
Card 1 — Velocity
  Big number: [N]pt       mint if ≥ previous, coral if 
  Label:      "Story Points Completed"
  Sub:        "vs [N]pt last sprint  (Δ[+/-N]pt)"

Card 2 — Completion Rate
  Big number: [N]%        mint if ≥ 80%, coral if < 80%
  Label:      "Sprint Completion Rate"
  Sub:        "Committed: [N]pt  ·  Completed: [N]pt"

Card 3 — Bugs Raised
  Big number: [N]         mint if ≤ previous, coral if >
  Label:      "Bugs Raised This Sprint"
  Sub:        "vs [N] last sprint  ·  [N] resolved  ·  [N] open"

Card 4 — Carry-over
  Big number: [N]         mint if 0, coral if > 0
  Label:      "Items Carried Over"
  Sub:        "[N]pt not completed  ·  vs [N] last sprint"

Each card: charcoal bg (2E4057), rounded rectangle, shadow,
           big number 60pt white, label 14pt teal, sub 11pt muted
~~~

---

#### SLIDE 3 — Velocity Trend

~~~
Chart type:   Grouped COLUMN (vertical bar)
Series 1:     Previous Sprint — charcoal bars
Series 2:     Current Sprint  — teal bars
Categories:   ["Committed", "Completed", "Carry-over pts", "Bugs raised"]
Chart title:  "[previousSprint.name]  vs  [currentSprint.name]"
Background:   navy slide, white chart area
Data labels:  on bars
~~~

---

#### SLIDE 4 — Completed Items

~~~
Background: charcoal (2E4057)
Header:     "✅  What We Shipped"  — white, 28pt

Left col:   "Stories & Enhancements ([N])"
            Ticket ID [id]  [Xpt]  [Title]  — [Assignee]
            mint bullet · white text · 13pt

Right col:  "Bugs Fixed ([N])"
            Ticket ID [id]  [Type]  [Title]  — [Assignee]
            coral bullet · white text · 13pt

Footer:     "Total: [N]pt delivered  ·  [N] items"  — teal, italic

Note: If 10+ items → show top 8 by story points + "+ [N] more delivered"
~~~

---

#### SLIDE 5 — Carry-over & Open Bugs

~~~
Background: navy (1E2761)
Header:     "⚠️  What Didn't Make It"  — white, 28pt

Left col:   "Carried Over ([N] items · [N]pt)"
            Ticket ID [id]  [Xpt]  [Title]  — [Assignee]  [State]
            coral bullet · white text · 13pt
            Note: "Action: re-prioritise or descope before next sprint planning"

Right col:  "Open Bugs ([N])"
            Ticket ID [id]  [P1/P2/P3]  [Type]  [Title]
            P1 = coral · P2 = amber · P3 = white
            Note: "Action: assign owners before next sprint"
~~~

---

#### SLIDE 6 — DROP

~~~
Background: navy (1E2761)
Header:     "🗑️  DROP"                — coral, 32pt, Trebuchet MS bold
Subheader:  "What should we stop doing that is slowing us down?"  — white, 18pt

3 seed cards (auto-generated from ADO data):
  Each card: charcoal bg, coral left border (0.08" thick), rounded rectangle
             Label "Suggested" in muted above card · white text 14pt italic

Seed logic:
  - carry-over > 3     → "Stories entering sprint without meeting Definition of Ready"
  - bugs > prev sprint → "Insufficient testing before marking stories done"
  - overloaded members → "Uneven workload distribution across the team"
  - --notes keywords (slow/blocker/delay) → surface as seed card
  - Always 2–3 seeds max

Bottom: Large empty charcoal area — dashed coral border
        Label: "Team adds items here during session"  — muted, italic
~~~

---

#### SLIDE 7 — ADD

~~~
Background: navy (1E2761)
Header:     "➕  ADD"                 — mint (02C39A), 32pt, Trebuchet MS bold
Subheader:  "What new practices should we introduce?"  — white, 18pt

3 seed cards (mint left border):
  - carry-over high    → "Definition of Ready checklist before sprint planning"
  - bugs high          → "Bug triage session at sprint mid-point"
  - --notes or blank   → "Team to add..."

Bottom: Empty area — dashed mint border
~~~

---

#### SLIDE 8 — KEEP

~~~
Background: charcoal (2E4057)
Header:     "✅  KEEP"                — teal (00B4D8), 32pt, Trebuchet MS bold
Subheader:  "What are we doing well that we should continue?"  — white, 18pt

3 seed cards (teal left border):
  - velocity improved  → "Strong delivery — [N]pt vs [N]pt last sprint"
  - bugs reduced       → "Quality improving — bugs down from [N] to [N]"
  - --notes or blank   → "Team to add..."

Bottom: Empty area — dashed teal border
~~~

---

#### SLIDE 9 — IMPROVE

~~~
Background: navy (1E2761)
Header:     "🔧  IMPROVE"             — amber (F9C74F), 32pt, Trebuchet MS bold
Subheader:  "What are we doing that we could do better?"  — white, 18pt

3 seed cards (amber left border):
  - completion < 80%   → "Estimation accuracy — completion rate [N]%"
  - carry-over > 0     → "Story splitting — [N] items carried over this sprint"
  - --notes or blank   → "Team to add..."

Bottom: Empty area — dashed amber border
~~~

---

#### SLIDE 10 — Action Items

~~~
Background: charcoal (2E4057)
Header:     "📋  Action Items"  — white, 32pt

Table (10 rows):
  Columns:    #  |  Action  |  Owner  |  Due  |  Status
  Header row: navy bg · teal text · bold
  Body rows:  alternating charcoal/navy · white text · 0.5" row height
  Pre-filled: 3 dotted placeholder rows — "To be completed during session"

Footer: "Actions reviewed at Sprint Planning  ·  [--project] / [--team]"  — muted
~~~

---

#### SLIDE 11 — Team Pulse

~~~
Background: navy (1E2761)
Header:     "💬  Team Pulse"  — white, 32pt
Subheader:  "How did the team feel this sprint?"  — muted, 16pt

Morale scale (5 circles, equally spaced, horizontally centered):
  😫     😕     😐     🙂     😄
   1      2      3      4      5
  "Burned out"              "Energised"
  Each: charcoal circle (teal border), emoji 28pt, number 12pt below

ADO signals (below scale):
  overloaded members → "⚠️ [N] members flagged overloaded this sprint"  — coral
  high carry-over    → "⚠️ High carry-over may indicate capacity or clarity issues"  — coral
  velocity up        → "✅ Velocity improved — team momentum positive"  — mint
  --notes morale     → Show SM note  — ice blue

Bottom: Large empty charcoal area for team comments during session
~~~

---

#### SLIDE 12 — Close & Next Sprint

~~~
Background: navy (1E2761) with large semi-transparent teal circle (decorative)
Header:     "Thank You 🚀"            — white, 40pt, centered
Sub 1:      "Next Sprint: [name]  ·  [Start] – [End]"  — teal, 20pt, centered
Sub 2:      "Sprint Planning: [nextSprint.startDate]"   — muted, 16pt, centered

Reminder box (charcoal rounded rect, bottom left):
  "📋 Actions agreed today will be reviewed at Sprint Planning"  — white 13pt

Footer: "[--project]  |  [--team]  ·  Retro facilitated by Scrum Master"  — muted, 12pt
~~~

---

### 6. QA the deck

~~~bash
python scripts/office/soffice.py --headless --convert-to pdf retro-[sprint].pptx
rm -f slide-*.jpg
pdftoppm -jpeg -r 150 retro-[sprint].pdf slide
ls -1 "$PWD"/slide-*.jpg
~~~

Inspect each slide for:
- Text overflow or cutoff on dark backgrounds
- Overlapping elements
- Low contrast text
- Chart data rendering correctly
- Consistent 0.5" margins throughout
- No placeholder text left unfilled where data should appear

Fix issues found, re-export, re-verify.

---

### 7. Save and deliver

~~~
Filename: retro-[project]-[sprint-name]-[YYYY-MM-DD].pptx
Example:  retro-IRIS-Sprint14-2024-04-16.pptx
~~~

Copy to `/mnt/user-data/outputs/` and present to user.

---

### 8. Offer to create ADO tasks from action items

After delivering the deck, ask:

~~~
📋 Your retro deck is ready: [filename]

Would you like to create ADO tasks for any action items agreed in the session?

Reply with the action items (one per line) and I'll create them as Tasks in ADO
linked to the next sprint ([nextSprint.name]).

Example:
  "Define Definition of Ready checklist — Owner: Rahul"
  "Add mid-sprint bug triage to sprint ceremonies — Owner: Ram Kumar"

Or reply "skip" to continue without creating tasks.
~~~

Wait for the user's reply.

**If user provides action items:**

For each action item:

- Call `wit_create_work_item` with:
  - **Type:** Task
  - **Title:** The action item text (strip owner name from title)
  - **Assigned To:** The owner name if provided (match against team roster in CLAUDE.md)
  - **Iteration Path:** Next sprint (`nextSprint.name`)
  - **Description:** "Retro action item from [currentSprint.name]. Created by /retro."
  - **Tags:** `retro-action`, `claude-generated`

After creating all tasks, output a summary:

~~~
✅ [N] retro action items created in ADO for [nextSprint.name]:

  Task [id]  [Title]  → [Assignee]
  Task [id]  [Title]  → [Assignee]

These will appear on the sprint board at the next planning session.
~~~

**If user replies "skip":** proceed to the follow-up prompt.

---

### 9. Follow-up prompt

After delivering the file, show:

> **Your retro deck is ready.**
> - Slides 6–9 (DROP/ADD/KEEP/IMPROVE) have ADO-seeded cards pre-filled — team adds more during the session.
> - Slide 10 (Action Items) has a blank table — fill it live during the session.
> - Slide 11 (Team Pulse) — each member votes, you record the average.
>
> **Next options:**
> - Check the next sprint board: `/sprint --project "[--project]" --team "[--team]"`
> - Refine next sprint backlog: `/refine --project "[--project]" --team "[--team]"`
> - View velocity trends: `/velocity --project "[--project]" --team "[--team]"`