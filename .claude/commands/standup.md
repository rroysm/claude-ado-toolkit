---
description: >
  Generate daily standup prep notes (before) and a formatted Teams summary (after).
  Pulls per-person updates from ADO state changes as the base.
  Supports optional SM notes on top of ADO data.
  Can auto-post the summary to a Teams channel or generate it for manual copy.

  Usage:
    /standup --project "IRIS" --team "IRIS Team"
    /standup --project "VCS"  --team "VCS team"
    /standup --project "IRIS" --team "IRIS Team" --notes "Alice is on leave today"
    /standup --project "IRIS" --team "IRIS Team" --post
    /standup --project "IRIS" --team "IRIS Team" --summary

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"

  Flags:
    --project   Required. ADO project name
    --team      Required. ADO team name
    --notes     Optional. SM notes to overlay on top of ADO data (quoted string)
    --post      Optional. Auto-post the Teams summary to the configured channel
    --summary   Optional. Generate Teams summary only (skip prep notes — use after standup)

  Two modes:
    Default          → Prep notes for SM before standup (ADO base + optional --notes)
    --summary/--post → Teams summary to share after standup
---

Use the Azure DevOps MCP tools to pull per-person sprint activity and
generate standup prep notes and/or a Teams summary.

---

### 1. Parse arguments

Extract the following from `$ARGUMENTS`:

| Flag        | Required | Description                                                          |
|-------------|----------|----------------------------------------------------------------------|
| `--project` | ✅ Yes   | ADO project name                                                     |
| `--team`    | ✅ Yes   | ADO team name                                                        |
| `--notes`   | ❌ No    | SM notes to overlay (e.g. "Alice is on leave, Bob joining late")     |
| `--post`    | ❌ No    | Auto-post Teams summary after confirmation                           |
| `--summary` | ❌ No    | Generate Teams summary only — skip prep notes                        |

**Flag rules:**
- `--post` implies `--summary` — if `--post` is passed, generate the Teams summary and offer to post it.
- `--notes` applies to both modes — overlay SM notes on prep AND on the Teams summary.
- If neither `--summary` nor `--post` is passed → default to prep notes mode.

If `--project` or `--team` is missing, stop and respond:

~~~
❌ Missing required arguments.

Usage: /standup --project "ProjectName" --team "TeamName"

Supported projects:
  /standup --project "IRIS" --team "IRIS Team"
  /standup --project "VCS"  --team "VCS team"
~~~

---

### 2. Fetch current sprint metadata

Call `wit_get_iterations` to get the active sprint for the project/team.

Extract:
- `Iteration Name`
- `Start Date` / `End Date`
- `Days Remaining` (working days, exclude weekends)

---

### 3. Fetch per-person ADO activity

Run two WIQL queries:

**Query A — Items with state changes since yesterday:**

~~~sql
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType],
       [System.AssignedTo], [Microsoft.VSTS.Scheduling.StoryPoints],
       [System.ChangedDate]
FROM WorkItems
WHERE [System.IterationPath] = @CurrentIteration('[--project]\[--team]')
  AND [System.ChangedDate] >= @Today - 1
  AND [System.AssignedTo] <> ''
ORDER BY [System.AssignedTo], [System.ChangedDate] DESC
~~~

**Query B — All open sprint items (for "today" context):**

~~~sql
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType],
       [System.AssignedTo], [Microsoft.VSTS.Scheduling.StoryPoints],
       [System.ChangedDate]
FROM WorkItems
WHERE [System.IterationPath] = @CurrentIteration('[--project]\[--team]')
  AND [System.State] <> 'Done'
  AND [System.AssignedTo] <> ''
ORDER BY [System.AssignedTo], [System.State]
~~~

**Build per-person update from query results:**

For each team member, combine both queries to produce:

- **Yesterday** → items whose `[System.ChangedDate]` is within the last working day
  - Show what changed: state transition with exact status names
  - Examples: `To Do → In Progress`, `In Progress → In Code Review`, `Deployed to QA → Deployed to UAT`
  - If no changes detected → show `No ADO activity recorded`

- **Today** → items currently in any In Progress status assigned to this person:
  `In Progress · In Code Review · Deployed to Dev · Deployed to QA · Deployed to UAT · Deployed to STG · Ready for Test`
  - These are what they are likely working on today

- **Attention needed** → flag these automatically:
  - Items in `Blockers` status → 🚨 immediate flag
  - Items in `On Hold` status → 🔴 flag
  - Items in `Waiting for requirements` status → 🟠 flag (Stories/ENH only)
  - Items in any In Progress status with `[System.ChangedDate]` 3+ working days ago → ⏸️ stale flag

---

### 4. Overlay SM notes (if --notes provided)

If `--notes` is present, parse the free-text value and apply it as annotations:

- Match names mentioned in the notes to team members.
- Append the note under the relevant person's section.
- If the note is general (no name match), add it as a standalone `📌 SM Note` at the top of the output.

Examples:
- `--notes "Alice is on leave today"` → adds `🏖️ On leave today` under Alice's section, clears her Today items
- `--notes "Bob joining standup late"` → adds `⏰ Joining late` under Bob's section
- `--notes "Dependency on external API still unresolved"` → adds as `📌 SM Note` at top

---

### 5. MODE A — Standup Prep Notes (default, before standup)

Display per-person prep notes in this format:

~~~
📋 Standup Prep — [Sprint Name]  |  [--project] / [--team]
[Date]  ·  Day [N] of 10  ·  [N] days remaining
────────────────────────────────────────────────────────────────────
[📌 SM Note: ... ]  ← only if --notes has a general note

👤 [Member Name]
  Yesterday:
    ✅ Ticket ID [id]  [Type]  [Xpt]  "[Title]"  → moved to [New State]
    — No ADO activity recorded  ← if no changes
  Today (In Progress):
    🔵 Ticket ID [id]  [Type]  [Xpt]  "[Title]"  (In Progress)
    🔵 Ticket ID [id]  [Type]  [Xpt]  "[Title]"  (In Code Review)
    🟢 Ticket ID [id]  [Type]  [Xpt]  "[Title]"  (Deployed to QA)
  Attention:
    🚨 Ticket ID [id]  "[Title]"  — status: Blockers
    🔴 Ticket ID [id]  "[Title]"  — status: On Hold
    🟠 Ticket ID [id]  "[Title]"  — status: Waiting for requirements
    ⏸️ Ticket ID [id]  "[Title]"  — In Progress for [N] days with no update
    — None  ← if no attention items

👤 [Member Name]
  ...

────────────────────────────────────────────────────────────────────
Sprint health snapshot:
  🔵 In Progress group:    [N] items  across [N] members
     In Progress([N]) · In Code Review([N]) · Deployed to Dev([N])
     Deployed to QA([N]) · Deployed to UAT([N]) · Deployed to STG([N]) · Ready for Test([N])
  ⚪ Proposed group:       [N] items
     To Do([N]) · Dev Review([N]) · Waiting for requirements([N])
  🚨 Blockers status:      [N] items  ← always shown even if 0
  🔴 On Hold:              [N] items
  ✅ Done today:           [N] items
  📅 Days remaining:       [N] of 10
~~~

**Display rules:**
- Order members alphabetically.
- If a member has no items in the sprint → show `⚪ No sprint items assigned`.
- State change emoji guide (use exact status names from ADO):
  - Any move into In Progress group → 🔵
  - Any move into Deployed to Dev/QA/UAT/STG or Ready for Test → 🟢
  - Move to Done → ✅
  - Move to On Hold → 🔴
  - Move to Blockers → 🚨
  - Move to Waiting for requirements → 🟠
  - Any regression (e.g. Deployed to QA → In Progress) → ⚠️
- Stale threshold: any item in In Progress group with no `[System.ChangedDate]` update in 3+ working days.

After prep notes, show:

> **Standup ready.** After standup, run:
> `/standup --project "[--project]" --team "[--team]" --summary`
> to generate the Teams summary. Add `--notes "..."` to include any outcomes or decisions.

---

### 6. MODE B — Teams Summary (--summary or --post, after standup)

Generate a clean Teams-formatted summary in this format:

~~~
📋 **Daily Standup Summary**
**[--project] — [--team]**
📅 [Full Date]  |  🏃 [Sprint Name]  |  Day [N] of 10  ([N] days remaining)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[📌 **SM Note:** ...]  ← only if --notes has a general note

👤 **[Member Name]**
▸ Done yesterday: [Short summary of state changes or "No updates"]
▸ Working today:  [Short summary of In Progress items]
▸ Attention:      [Blockers/On Hold/Stale items or "None"]

👤 **[Member Name]**
▸ Done yesterday: ...
▸ Working today:  ...
▸ Attention:      ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔢 Sprint Snapshot
  ✅ Done:                    [N] items
  🟢 Deployed (Dev/QA/UAT/STG/Ready for Test): [N] items
  🔵 In Progress/Code Review: [N] items
  ⚪ Proposed (To Do/Dev Review): [N] items
  🟠 Waiting for requirements: [N] items
  🔴 On Hold:                 [N] items
  🚨 Blockers status:         [N] items
  📅 Days remaining:          [N] of 10

[If Blockers/On Hold/Stale items exist:]
🚨 **Attention Needed**
  • Ticket ID [id] "[Title]" → [Member] — status: Blockers. Immediate follow-up needed.
  • Ticket ID [id] "[Title]" → [Member] — On Hold for [N] days.
  • Ticket ID [id] "[Title]" → [Member] — In Progress for [N] days with no update.

_Posted by Scrum Master via Claude · [--project] · [Date]_
~~~

**Formatting rules for Teams:**
- Use `**bold**` for names and section headers (Teams markdown).
- Keep per-person summaries to 1 line each — concise, scannable.
- Translate ADO item titles to plain English where possible (strip ticket prefixes).
- Never paste raw WIQL or technical ADO field names into the Teams message.

---

### 7. Handle --post (auto-post to Teams)

If `--post` is present, before sending to Teams display:

~~~
📨 Ready to post standup summary to Microsoft Teams.
   Project: [--project]  |  Team: [--team]
   Channel: [Configured Teams channel — see note below]

   Preview shown above. Confirm? Reply "yes" to post or "no" to skip.
~~~

Wait for explicit "yes" before posting.

Use the Microsoft Teams MCP tool to post the message to the team's standup channel.

> **Channel configuration:** The Teams channel to post to should match the team:
> - IRIS Team  → post to the IRIS project standup channel
> - VCS team   → post to the VCS project standup channel
>
> If the channel is not found or the Teams MCP tool is unavailable, fall back to
> displaying the message for manual copy with a note:
> ~~~
> ⚠️ Could not auto-post to Teams. Copy the message above and paste it manually.
> ~~~

---

### 8. Handle empty ADO results

If Query A returns no state changes AND Query B returns no active items:

~~~
⚠️ No sprint activity found for [--project] / [--team] today.
   - Confirm the sprint is active and team members have items assigned.
   - It's possible no ADO updates were made since yesterday.

   You can still generate a Teams summary manually using:
   /standup --project "[--project]" --team "[--team]" --summary --notes "Brief update here"
~~~

---

### 9. Follow-up prompt

After output (either mode), show:

> **Next options:**
> - Generate Teams summary: `/standup --project "[--project]" --team "[--team]" --summary`
> - Auto-post to Teams: `/standup --project "[--project]" --team "[--team]" --post`
> - Add SM notes: append `--notes "your notes here"` to any command above
> - Check full sprint board: `/sprint --project "[--project]" --team "[--team]"`
> - Other project: `/standup --project "VCS" --team "VCS team"`