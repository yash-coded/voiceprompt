# 08 — Stats Dashboard

Status: ready
Type: AFK
Blocked by: 05

## What to build
The Stats sidebar section, computed from the history data: total words dictated, estimated time saved versus typing (state the assumption in the UI: 40 wpm typing baseline vs speaking speed), current daily dictation streak, and a words-per-day chart over recent history.

When history is turned off (or empty), the section shows an explanatory empty state telling the user stats require history to be enabled, rather than zeros or a blank screen.

## Acceptance criteria
- [ ] Total words dictated matches the sum of words in history entries.
- [ ] Time-saved estimate is shown with its 40 wpm assumption visible to the user.
- [ ] Daily streak counts consecutive days with at least one dictation, including today when applicable.
- [ ] Words-per-day chart renders and updates after new dictations.
- [ ] With history off or empty, an explanatory empty state is shown.

## Out of scope
- Per-app or per-mode breakdowns.
- Exporting or sharing stats.
- Goals, notifications, or gamification beyond the streak number.

## Comments
