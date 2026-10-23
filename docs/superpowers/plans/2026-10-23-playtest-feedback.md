# Playtest feedback and native validation

**Goal:** Make the approved next phase usable: native Windows/Linux execution evidence and local, attributable post-run feedback.

**Approved direction:** The user requested continuing the previous recommendation: human short runs, evidence for DeepSeek, and target-platform verification. No balance change is justified by synthetic feedback.

**Architecture:** Extend the existing RunLog/EndUi flow. Feedback is a separate local JSONL ledger joined by run_id. Main owns lifecycle and optional context; neither ledger nor UI changes Sim. Existing CI provides native OS runners; reuse checked.sh to fail on engine errors.

**Constraints:** Work only on codex/presentation. DeepSeek checkout is read-only. No main/tag/Release actions, new dependencies or network telemetry. Keep old run rows readable. Test data must never be labelled as verified human evidence. Root alone runs Godot and integration verification.

## 1. Local records

- [ ] Add `RunLog.new_context(source: String = "unknown") -> Dictionary` with a Crypto-generated run_id, UTC timestamp, source (`manual`, `fixture`, `bot`, `unknown`) and build_commit from a build stamp/environment, falling back explicitly to `unavailable`.
- [ ] Extend `append(sim, character_id, seconds, context = {}) -> Dictionary`; preserve existing metrics, return the saved record or `{}` on failure, never claim a successful write when FileAccess fails.
- [ ] Add `FeedbackLog(path)` with `submit(run_record, category, rating, note) -> Dictionary` and `has_feedback(run_id)`. One entry per run, fixed categories `builds/shop/combat/echoes/performance/other`, ratings `good/mixed/frustrating`, optional trimmed note <=500 characters. Validate identifiers; preserve provenance from the run. Only local writes.
- [ ] Test JSONL roundtrip, legacy compatibility, unique IDs without Sim RNG mutation, duplicate rejection, invalid inputs, escaped text, and write failure.

## 2. Post-run UI

- [ ] Add a localized EndUi feedback action and FeedbackUi modal. Show category, feeling, optional short note, local-only notice and success/error state. Reuse UiTheme and UiFocus; restore EndUi focus on close.
- [ ] Main creates context at new_run, stores only successfully recorded run data, and submits through FeedbackLog. Feedback is unavailable until a finished run is saved. Clear context/modal when leaving/restarting; no pause feedback in this slice.
- [ ] Update existing focus-count expectations and add actual-window EN/ZH feedback probe: form input, cancel, save, duplicate guard, reopen, reset, geometry/focus. Mark the probe `fixture`.

## 3. Report and build provenance

- [ ] Extend runs_report.py with optional feedback input joined by run_id, Conductor labels, source/build grouping, malformed-record accounting and validation. Old rows stay `unknown`; automated/unknown samples are not silently called human.
- [ ] Add Python unittest coverage for mixed/legacy/malformed data, feedback joins and source filtering.
- [ ] Stamp the immutable source commit into the existing isolated export overlay. Keep source project.godot unchanged by export.

## 4. Delivery and gates

- [ ] Save baseline native CI evidence for 09375a4 (run39967093104); verify actual exported Windows/Linux steps and logs, not only green status.
- [ ] Route CI import/tests/smoke/exported launch through existing engine-error scanning and run Python report tests. Set fixture provenance in CI.
- [ ] Root runs import, targeted/full tests, smoke, native feedback UI probe, independent code/architecture review; commit and push the fixed branch without tags/releases. Verify exact-head native CI.
- [ ] Export a new immutable local playtest build and launcher with `REVERB_RUN_SOURCE=manual`; preserve the previous frozen build. Deliver a short 5–10 minute playtest guide and evidence report. Human feedback remains pending until actually supplied.
