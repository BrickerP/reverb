# Bureau rituals 0.17 contract

This batch turns the approved Cursor concepts into playable systems. Godot2D, existing shortcut navigation, clean combat centre, current money/Echo wear/caps and actual model-derived outcomes remain authoritative. Artwork is rebuilt for readable transparent assets; concept JPGs remain references. No speculative extra weapons/currencies or a mandatory walking hub.

## Scope and shared model

Implement the archive room/family wall, inherited-copy vending presentation, merge/staple and Undo/unstaple ceremonies; an optional timed stamp-delivery event; optional confession-copy choices with explicit next-encounter inspection; and bounded retirement/night-cleanup narrative. The reference anchors are ideas06/07/10/20/21/05/16/27/19/24/28. Off-theme concept11/14 are excluded.

Add one closed `sim.expedition["bureau"]` dictionary, initialised/validated by `BureauEvents`, using keys `delivery`, `confessions`, `retired`, `work`. Delivery is a bounded current-encounter dictionary. Confessions max3 rows (one choice per act), retired max6 rows, work counters max16 rows. No Nodes/Callables or localized text in state; finite canonical values and bounded arrays only. Persistent archive-room history is optional `Meta.bureau_reports` (max12 run reports, each max6 retirements), a current decoder field preserving existing permanent profiles. Runtime Snapshotv4 is a clean current-run path; older suspended runs remain available only in their original build. Preserve unlocks/settings/permanent Echoes.

## Authoritative event module APIs

`BureauEvents.initialize(sim)`, `begin_wave(sim)`, `step(sim,dt)`, `finish_wave(sim,success)`, `validate_state(sim)->bool`, `profile(sim)->Dictionary` (pure), `record_retirement(sim,info)`, `note_work(sim,info)`. Add hooks in Expedition/Sim/EchoSystem/EchoWork; all actual consequences stay in model. `Expedition.interaction/interact` expose the new valid targets through existing E/X. `Sim.world_event` supplies value snapshots to draw/audio, never a new mutation bus.

`BureauConfession.options(sim)->Array[Dictionary]` rows follow existing id/name_key/description_key/available/reason_key/cost shape. `apply(sim,choice)->bool` is only called via `ShopResult.CONFESS` quote/apply. It must be pure to query and fully undoable before next departure. A pending signature holds reroll until undone; buying/refitting/departing remain usable. Protect its canonical pre-sign Undo anchor at the existing32-state limit. Explain this stock hold before signing. `begin_wave/step/finish_wave/validate` own confession records/inspection, called by BureauEvents. Declining/closing is free and no choice is mandatory.

## Optional stamp delivery

Provide one event on campaign encounters2/6/10, clearly forecast before departure. Pickup, switch and inbox positions must be body-clear reachable in existing2400x1200 arena; no actor/UI shrinking and no new permanent geometry. Carry one document, reach the inbox through a repeated stamp warning/impact/recovery corridor. All roles can independently time/cross it. Echo can replay a recorded switch to grant a safe interval; use canonical target `bureau_dispatch_switch` and work kind `press` in the existing bounded work pipeline. Repaired or permanently stopped existing machines never restart because of the event. The new stamp is an independent declared apparatus.

Use identical warning/hit geometry for players, enemies and supports; safe reset/gate interval is authoritative. Delivery pays a fixed small one-time reward (8materials), no time-limit surprise tax. Failure leaves an explicit missed record. Large dt, pause, save/restore and rewind cannot duplicate work/reward. Ambient event is independent of held order and cannot block departure/finish. No endless accumulation.

## Confession desk

One optional signed choice per upcoming act in Shop; both choices show exact outcomes before committing. `truth`: automatically restore12 condition to the most-worn eligible Echo (lowest UID breaks ties), or6HP when no eligible Echo exists; expose actual original-story testimony at departure. `polish`: grant12 materials now; next encounter adds an announced inspection terminal. Registering triggers a clearly warned localized hazard; skipping leaves a visible unverified record in the signed receipt and bounded act history, never hidden debt/tax. Neither alters objective history or classifies credit as morality. Story clue commitment happens at departure so Shop Undo cannot farm irreversible Meta clues. No extra player/Echo resource or permanent stat growth.

## History, archive and UI

Meta stages/upserts a bounded report by Main's persisted run_id before ordinary run/endless persistence; no duplicate reports from Endless continuation. Reports store actual canonical character/outcome/rescue/repair facts and actual retired-copy summaries; UI distinguishes still-retained, archived, staff and retired identities. Use short coldly comic speaker copy, not fabricated achievements. Keep one permanent live archive per eligible character and same normalization60condition/grade0/openingbudget.

Family-wall selection controls the existing candidate/role preview; paper/portrait state derives actual profile. Archive cabinet can visually open to show crew/witnesses. Vending is the existing inheritance choice made visible: print only the actual inherited take, no free extra body/reset, use a short skippable or nonblocking beat. Merge and Undo ceremonies react to real ShopResult before/after snapshots; skip changes only presentation and never applies transaction twice. Show one final body after merge. Main Shop Undo remains canonical.

All interfaces support EN/ZH, mouse/keyboard/gamepad, native1280x720 and960x540, reduced effects, focus return and no off-screen primary controls. Optional transitions cannot slow repeated shopping. All new labels remain live localized strings, never baked into art.

## Visual implementation and verification

Generated production art: two new transparent atlases under `assets/presentation/bureau/`: facility components and binding ceremony poses. Existing actors/portraits plus native ink geometry supply archive frames and procedural stamp geometry. Metadata records references/prompts/alpha/hash; original generated pixels preserved. UI may use the user-provided concept illustrations only in declared noninteractive story surfaces; do not package all concept boards as runtime assets.

World rendering reads BureauEvents.profile and committed world facts. Edge/cabinet cleanup and retirement receipts are bounded, keep hazards readable, freeze on pause, and do not thin late-wave enemies. Physical stamp shadow/warning is separate from decorative paper texture.

Every new behavior has a happy and a boundary/failure test, strict Snapshot roundtrip/atomic Undo, and real Main input entry. Native probes cover all new surfaces and gameplay including Solo/Echo help, failed inspection, save on either side of a stamp/work event, reduced effects and known old release regressions. Independent four-pass review, fixed-cap pressure check, immutable3platform exports, valid Mac signature/startup, public checksums and fixed GitHub Latest URLs are delivery gates. No promise of human fun, physical-controller testing, notarization or universal60FPS.
