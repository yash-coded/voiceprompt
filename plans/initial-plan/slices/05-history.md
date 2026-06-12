# 05 — History

Status: ready
Type: AFK
Blocked by: 04

## What to build
Local SQLite-backed dictation history. Every completed dictation stores: timestamp, raw transcript, cleaned text (or null/equal when cleanup was skipped), the target app it was pasted into, and the cleanup mode used. Data is local only — never leaves the machine.

The History sidebar section becomes functional: a reverse-chronological list of dictations with search across raw and cleaned text, per-row actions to copy the raw or cleaned text and to delete the row, and a clear-all action. The retention setting from slice 04 is enforced: "off" records nothing, and the timed options (7d/30d) prune older rows automatically; "forever" never prunes.

## Acceptance criteria
- [ ] Each dictation appears in History with timestamp, raw text, cleaned text, target app, and mode.
- [ ] Search filters the list against both raw and cleaned text.
- [ ] Copy raw, copy cleaned, delete row, and clear all each work.
- [ ] With retention off, no rows are written; switching it off does not silently delete existing rows beyond what retention rules dictate.
- [ ] Rows older than the configured retention window are pruned automatically.
- [ ] History survives app restarts (persisted in SQLite).

## Out of scope
- Stats/aggregations over history (slice 08).
- Export, sync, or any cloud features.
- Re-paste / re-clean actions on history entries.

## Comments
