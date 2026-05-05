---
description: >
  Create a Business Requirements Document (BRD) via interactive Q&A or from
  uploaded documents. Produces a structured BRD and optionally posts a summary
  to an Azure DevOps Feature work item.

  Usage:
    /brd
    /brd AB#100   (link BRD to an existing ADO Feature or Epic)

  Flags:
    AB#[id]   Optional. ADO Feature or Epic work item to link the BRD to.

  Supported projects:
    --project "IRIS"  --team "IRIS Team"
    --project "VCS"   --team "VCS team"
---

Use the ado-brd-writer agent to create a Business Requirements Document.

---

### 1. Parse arguments

Check `$ARGUMENTS` for an ADO work item ID (e.g. `AB#100`).

- If found → store as `FEATURE_ID`. This Feature or Epic will anchor the BRD.
- If not found → `FEATURE_ID` is empty. The BRD will be standalone.

---

### 2. Pre-flight: load any existing context

Check for input material in this order:

1. **ADO Feature/Epic** — if `FEATURE_ID` is set, call `wit_get_work_item` to fetch:
   - Title, description, acceptance criteria, parent Epic (if applicable)
   - Any existing comments mentioning "BRD" or requirements
   - Linked child stories (to understand scope already defined)

2. **Uploaded documents** — check the conversation for any attached files (meeting notes,
   emails, Slack exports, feature specs). Read them all and extract:
   - Stated requirements (explicit asks)
   - Implied requirements (assumed but not stated)
   - Constraints (budget, timeline, technology, compliance)
   - Open questions (ambiguities, contradictions, missing detail)

3. **Conversation context** — if the user described what they need in their message,
   use that as the starting point.

If none of these exist, proceed to interactive Q&A in Step 3.

---

### 3. Run the ado-brd-writer agent

Hand off to the `ado-brd-writer` agent with the following context:

- Any pre-loaded Feature/Epic content from Step 2
- Any extracted requirements from uploaded documents
- The `FEATURE_ID` (so the agent knows where to post the summary)

The agent will:
1. Run an interactive requirements elicitation session (batches of 3–5 questions)
2. Draft the full BRD (12 sections: Executive Summary → Sign-off)
3. Generate a professional `.docx` file with NowOptics branding
4. Post a summary comment on the ADO work item if `FEATURE_ID` was provided

---

### 4. Output and next steps

After the BRD is complete, confirm what was produced:

~~~
BRD complete.

Document:     [filename].docx  (saved to working directory)
Sections:     12  (Executive Summary through Sign-off)
Requirements: [N] functional  |  [N] non-functional
Must-have:    [N]  |  Should: [N]  |  Could: [N]  |  Won't: [N]
Open issues:  [N] questions needing stakeholder input

ADO:          [Posted to AB#FEATURE_ID / No work item linked]
~~~

Then suggest:

> **Next step:** Once stakeholders have reviewed and approved the BRD, run:
> `/stories AB#[FEATURE_ID]` to decompose it into sprint-ready user stories.

---

### Error handling

**Missing Feature/Epic (AB# not found):**
~~~
⚠️ Work item AB#[id] not found in ADO.
   Proceeding with a standalone BRD (not linked to any Feature).
   To link later, post the BRD summary manually on the work item,
   or re-run: /brd AB#[correct-id]
~~~

**Incomplete input material:**
If uploaded documents are missing critical information (no functional requirements,
no clear business objective), do NOT guess. Tell the user:
~~~
⚠️ The provided material doesn't have enough detail to write a complete BRD.
   I'll start the Q&A to fill the gaps — answer what you can and flag anything
   still under discussion.
~~~

**BRD exceeds 30 functional requirements:**
~~~
⚠️ This BRD has [N] functional requirements — more than one sprint release can handle.
   Consider splitting into Release 1 (Must-have) and Release 2 (Should/Could).
   Proceed with the full BRD, or ask me to split it first?
~~~
