---
description: >
  Decompose a BRD into Azure DevOps user stories. Reads a BRD from a file,
  ADO work item, or the current session. Produces right-sized stories with
  acceptance criteria and creates them as work items in ADO linked to the
  parent Feature.

  Usage:
    /stories                  (uses BRD from current session or working directory)
    /stories AB#100           (uses BRD from ADO Feature/Epic AB#100)
    /stories AB#100 --sprint "Sprint 45"   (place stories in a specific sprint)
    /stories AB#100 --dry-run              (preview stories without creating in ADO)

  Flags:
    AB#[id]      Optional. ADO Feature or Epic that owns the BRD.
    --sprint     Optional. Iteration path for created work items (e.g. "Sprint 45").
    --dry-run    Optional. Show story list without creating anything in ADO.

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"
---

Use the ado-brd-to-stories agent to decompose a BRD into user stories.

---

### 1. Parse arguments

Extract from `$ARGUMENTS`:

| Argument    | Required | Description |
|-------------|----------|-------------|
| `AB#[id]`   | No       | ADO Feature or Epic that owns the BRD |
| `--sprint`  | No       | Sprint name to assign created stories (e.g. `"Sprint 45"`) |
| `--dry-run` | No       | Preview story list in chat — do NOT create anything in ADO |

Store as `FEATURE_ID`, `TARGET_SPRINT`, and `DRY_RUN` flag.

---

### 2. Locate the BRD

Find the BRD source in this priority order:

1. **`FEATURE_ID` provided** — call `wit_get_work_item` on that Feature/Epic.
   Look for BRD content in:
   - The work item description
   - Comments containing "BRD", "requirements", or "FR-" references
   - Any attached `.docx` or `.md` files

2. **BRD from current session** — if `/brd` was run earlier in this conversation,
   use the BRD that was produced.

3. **`.docx` file in working directory** — look for any `*brd*.docx` or `*requirements*.docx`
   file and read it.

4. **Nothing found** — stop and ask:

~~~
No BRD found. Please provide one of:
  - An ADO Feature ID:  /stories AB#[id]
  - A file path:        /stories  (then paste the BRD content or drop a file)

To create a BRD first, run: /brd AB#[id]
~~~

---

### 3. Validate the BRD

Before decomposing, confirm the BRD has the minimum required content:

- At least one functional requirement (FR-xxx) or equivalent
- At least one acceptance criterion or testable outcome
- A clear scope (what is in/out)

If critical sections are missing:

~~~
⚠️ This BRD is missing [functional requirements / acceptance criteria / scope].
   Decomposing an incomplete BRD will produce untestable stories.

   Options:
   1. Run /brd AB#[id] to complete the BRD first (recommended)
   2. Continue anyway — I will flag gaps on each story
~~~

Ask the user which option they want before proceeding.

---

### 4. Run the ado-brd-to-stories agent

Hand off to the `ado-brd-to-stories` agent with this context:

- The full BRD content located in Step 2
- `FEATURE_ID` (so stories get linked to the parent Feature)
- `TARGET_SPRINT` (so the agent assigns stories to the right iteration)
- `DRY_RUN` flag

The agent will:
1. Extract all FR/NFR requirements and user journeys from the BRD
2. Decompose into right-sized stories (1–5 pts each, 8 pt max)
3. Apply MoSCoW prioritisation inherited from the BRD
4. Organise stories into delivery phases (Must → Should → Could)
5. **Show the full story list and wait for confirmation** before creating anything
6. Create confirmed stories as ADO work items linked to the parent Feature
7. Post a BRD → Story traceability matrix on the parent Feature work item

---

### 5. Dry-run behaviour

If `--dry-run` is set:

~~~
📋 DRY RUN — No work items will be created in ADO
────────────────────────────────────────────────────────────────────
[Show full story list with titles, points, priority, and AC]
────────────────────────────────────────────────────────────────────
Total: [N] stories  |  [N]pt  |  Estimated sprints: [N]

To create these stories in ADO:
  /stories AB#[FEATURE_ID]   (remove --dry-run)
~~~

---

### 6. Output and next steps

After stories are created, confirm what was produced:

~~~
Stories created in ADO — [PROJECT] / Feature AB#[FEATURE_ID]

Must-have  ([N] stories · [N]pt):  AB#[id], AB#[id], ...
Should-have ([N] stories · [N]pt): AB#[id], AB#[id], ...
Could-have  ([N] stories · [N]pt): AB#[id], AB#[id], ...

Total: [N] stories  |  [N] points  |  ~[N] sprints to complete
Traceability matrix posted on Feature AB#[FEATURE_ID]
~~~

Then suggest:

> **Next steps:**
> `/refine --project "[PROJECT]" --team "[TEAM]"` — batch quality-check all stories before sprint planning
> `/check AB#[id]` — deep-dive quality check on any individual story
> `/implement AB#[id]` — start implementing the highest-priority story

---

### Error handling

**Sprint not found:**

~~~
⚠️ Sprint "[TARGET_SPRINT]" not found for this project/team.
   Stories will be created without a sprint assignment.
   To assign manually: open each story in ADO → Iteration field.
~~~

**Story too large to decompose (13pt+):**

~~~
⚠️ Requirement [FR-xxx] maps to a very large story (~13pt).
   It must be split before entering a sprint.
   I'll propose a split into [N] smaller stories — confirm to proceed.
~~~

**BRD requirement cannot be traced to a story:**

~~~
⚠️ [FR-xxx] could not be mapped to a testable story — the requirement is too vague.
   Flagged as: UNMAPPED — needs BA clarification before development.
~~~
