# Planning & Execution Process

This repo is built across many agent sessions. Each session has zero memory of
the previous one — these files are the only shared state. When creating a new
plan, always follow this process.

## Folder layout

```
plans/
  PROCESS.md                  ← this file (read it first, every session)
  <plan-slug>/
    DESIGN.md                 ← locked design decisions from the grilling session
    progress.txt              ← APPEND-ONLY execution log (see format below)
    slices/
      NN-<slug>.md            ← one tracer-bullet slice per file, numbered in
                                dependency order (blockers first)
```

## Lifecycle

1. **Plan session** — grill the user (`/grill-me`) until every design branch is
   resolved. Write `DESIGN.md`, then break it into slices (rules below).
2. **Execute session(s)** — pick the lowest-numbered slice whose `Status:` is
   `ready` and whose blockers are all `done`. Set it `in-progress`, implement,
   verify every acceptance criterion, commit, set it `done`, append to
   progress.txt. Do ONE slice per session unless the user says otherwise.
3. **Review session** — review the slice's diff on two independent axes, never
   merged: **Standards** (repo conventions, CLAUDE.md, idioms) and **Spec**
   (the slice file's acceptance criteria). Code can pass one and fail the
   other. Append findings to progress.txt; reopen the slice if it fails.
4. Repeat 2–3 until all slices are done.

## Slice rules (tracer bullets)

- Each slice is a **thin vertical slice** that cuts through ALL layers
  end-to-end — never a horizontal slice of one layer. A completed slice is
  demoable or verifiable on its own.
- Prefer many thin slices over few thick ones. Slice 01 is the tracer bullet:
  the narrowest possible path that proves the whole pipeline works.
- Write slices to be **durable**: describe behavior and interfaces, not
  procedure. Do NOT reference file paths or line numbers — they go stale.
  Exception: a code snippet that encodes a decision more precisely than prose
  (a type shape, schema, state machine) may be inlined.
- Mark each slice **AFK** (an agent can implement and finish it with no human
  input) or **HITL** (needs a human decision/review mid-slice). Prefer AFK.
- State what is **out of scope** to prevent gold-plating.

## Slice file template

```markdown
# NN — <Title>

Status: ready | in-progress | done | blocked
Type: AFK | HITL
Blocked by: <slice numbers, or "None — can start immediately">

## What to build
End-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria
- [ ] Each independently verifiable.

## Out of scope
- Things adjacent to this slice that must NOT be built here.

## Comments
(append-only; agents add dated notes here as they work)
```

## progress.txt format

Append-only — never edit or delete existing lines. One line per event:

```
2026-06-11 | plan | Initial plan created with N slices
2026-06-12 | slice-01 | started
2026-06-12 | slice-01 | done — all criteria pass, commit abc1234
2026-06-13 | review-01 | PASS standards / FAIL spec: <one-line reason> — reopened
```

## Rules for executing agents

- Read PROCESS.md, the plan's DESIGN.md, progress.txt, and your slice file
  before writing any code. Explore the codebase fresh; the slice describes
  WHAT, you decide HOW.
- Never start a slice whose blockers aren't done. Never modify other slices'
  scope. If a slice turns out to be wrong or too big, append a comment, set
  Status: blocked, log it in progress.txt, and stop — don't improvise.
- Update slice Status and progress.txt in the SAME commit as the work.
- Rejected ideas go to `plans/<plan-slug>/out-of-scope.md` with the reason, so
  future sessions don't re-litigate them.
```
