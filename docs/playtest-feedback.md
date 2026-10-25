# Local playtest feedback

Take Stack records finished runs and optional post-run feedback **only on the local
computer**. The game does not upload feedback, call a web API, send email, or
automatically contact the developers. Use the result-screen **Open log folder**
action to find the exact directory used by the current build.

## Player flow

1. Finish a run by winning or losing. A run record must be saved successfully
   before feedback becomes available.
2. On the result screen, choose **Feedback / 提交本局反馈**.
3. Pick one category: builds, shop, combat, echoes, performance, or other.
4. Pick a feeling: good, mixed, or frustrating.
5. Optionally add a note of at most 500 characters, then choose
   **Save feedback / 保存反馈**.
6. Use **Open folder / 打开文件夹** to find `runs.jsonl` and `feedback.jsonl`.
   The current user's local files may be read by later authorized checks; players
   on other devices may voluntarily provide their files.

Feedback is one entry per run. After it is saved, reopening the form is read-only
and duplicate submission is rejected. Cancel closes the form without writing.

## Record contracts

`runs.jsonl` schema 2 stores one JSON object per completed run. Each new record has:

- a Crypto-generated `run_id`, UTC start/record timestamps, seed and version;
- `source`: `manual`, `fixture`, `bot`, or `unknown`;
- `build_commit`, taken from the immutable build stamp or explicit environment;
- character, wave, win/loss, duration, kills, weapons, items, echoes, merge count,
  earnings, interest, death cause and best echo summary;
- mode fields `endless`, `boss_rush`, `daily_modifier` and `ascension`;
- chosen `boons` in order, `echo_refreshes`, and `contracts_accepted/completed/failed`.

Old schema-1 rows remain readable. Because they cannot prove source or build, the
report classifies them as `unknown` / `unavailable` even if similarly named fields
were added by hand.

`feedback.jsonl` schema 1 stores the selected category, rating, optional note and
submission time. It also copies the run ID, version, build, seed, character, wave,
result and source. Feedback is joined only when the run ID is unique and provenance
does not contradict the matching run. Malformed, orphan, duplicate or mismatched
rows are counted and ignored rather than silently attributed.

Source classification is evidence, not a guarantee of who was at the keyboard:

- `manual`: the supplied launcher marks an intended ordinary play session; this is
  provenance, not player identity authentication;
- `fixture`: deterministic UI/test fixture, never counted as human feedback;
- `bot`: automated gameplay, never counted as human feedback;
- `unknown`: legacy or unproven origin, never silently counted as human feedback.

No verified human feedback has been received at this delivery checkpoint. The current
public RC is v0.10.0-rc.1; its release notes list the unverified balance and readability
areas.

## Build a local report

```bash
python3 tools/runs_report.py runs.jsonl \
  --feedback feedback.jsonl \
  --out report.md
```

Use `--source manual` when you intentionally want only records marked for manual
play. The report groups runs by source and build, separates Normal / Daily / Endless /
Boss Rush, shows Daily-anomaly and boon performance, reports echo refreshes and contract
outcomes, joins valid feedback, keeps Conductor labels, and lists every
malformed/orphan/duplicate/provenance mismatch.

## Developer and QA boundaries

- Fixture probes must set `REVERB_RUN_SOURCE=fixture`; bots use `bot`.
- The playtest launcher defaults to `manual` and stamps source commit `a470464`.
- Build stamping is applied only to the isolated export overlay; source
  `project.godot` is not mutated during export.
- Run IDs are independent of simulation RNG, so logging cannot change gameplay.
- Local writes report failure honestly; feedback is not enabled for an unsaved run.
- CI wraps Godot commands with engine-error scanning. Exact-head run
  [39998713766](https://github.com/BrickerP/reverb/actions/runs/39998713766)
  passes Linux, Windows and macOS tests plus native Linux/Windows 60-frame exported
  launches. Baseline run
  [39967093104](https://github.com/BrickerP/reverb/actions/runs/39967093104)
  is retained for comparison.
