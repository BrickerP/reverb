# Human playtest plan

Goal: collect enough real-player evidence to decide whether v0.10.x needs difficulty,
readability or economy changes before a stable release.

## Build

Use the public `v0.10.0-rc.1` build:
<https://github.com/BrickerP/reverb/releases/tag/v0.10.0-rc.1>

Ask each tester to keep `runs.jsonl` and `feedback.jsonl` local and send them back
voluntarily. Do not upload automatically; the game has no network reporting.

## Sample

- **3–5 testers** who have not designed the game.
- Each tester plays **3 runs**, in this order:
  1. Normal / Looper / Ascension 0, until win or loss.
  2. Normal / Soloist / Ascension 0, until win or loss.
  3. One endgame run: Daily if available, otherwise Boss Rush or Endless.
- Fresh saves are preferred; do not grant Ascension levels by hand.
- Record first impressions before explaining any system.

## Session protocol

1. Start from character select; ask what they think each character does.
2. Play without coaching. Note when they ask what an icon, color or number means.
3. After each run, use the end-screen Feedback form:
   - one category, one rating, a one-sentence reason.
4. After all runs, ask five questions:
   - Which death felt fair, and which felt unreadable?
   - Did you understand why a shot/echo was or was not firing?
   - Did you ever buy an item without understanding its set or tradeoff?
   - Was Boss Rush/Daily a mode you would replay? Why?
   - What was the first moment you felt the build “clicked”?

## Decisions

Use only `--source manual` runs and valid feedback.

```bash
python3 tools/runs_report.py runs.jsonl \
  --feedback feedback.jsonl \
  --source manual \
  --out report.md
```

Decision gates:

- **Win-rate gap > 20 points between characters** on the same mode → inspect build
  and death waves before changing numbers.
- **Two or more testers report the same unreadable icon/color** → presentation fix
  before balance.
- **Wave 8–14 deaths cluster with no purchase path** → economy/shop review.
- **Boss Rush / Daily not replayed by most testers** → mode reward/identity issue,
  not a global difficulty issue.
- **No repeated pattern** → do not change balance from a single run.

## Safety

- Do not ask testers to share personal data beyond the local game logs.
- Keep raw logs and feedback out of the public repository unless explicitly permitted.
- Do not treat bot matrices as human evidence.
