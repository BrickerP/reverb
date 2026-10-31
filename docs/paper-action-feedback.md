# Paper action feedback

The 0.18.1 closeout builds on public `v0.18.0` and retains the current main
front page. It completes presentation along existing authoritative events;
weapons, damage, enemy density, routes, prices and saved-run schema stay under
their existing owners.

## Visual decision

Keep Carbon Copy Purgatory: tired paper bodies, charcoal edges, cream stock,
rubber stamps, fibre, folds, staples and a small muted palette. Reuse the
authored character/weapon atlases. Add contact drawings and local deformation
where motion needs explanation, rather than enlarging every body or adding
bright full-screen effects.

Six material actions organize the existing weapon identities:

| Action | Departure and contact | Result |
| --- | --- | --- |
| Pin | Short punch, dark core and paper rim | Puncture and staple marks |
| Stamp | A weighted press and compact downstroke | Brief compression and ink imprint |
| Cut | Directed cutting edge | Offset fibre strips and a short cut seam |
| Ink | A rounded deposit | An irregular blot with a readable edge |
| Return | A bent launch/retrieval arc | Curled paper and a visible return accent |
| Arc | A branching stitch | A bounded seam joining actual contacts |

Flight uses a bounded, fairly sampled set of six material accents even in dense
and Reduced Effects scenes. Every actual collision head remains in its batch;
accents never replace heads. Cached segment motifs share two bounded multiline
submissions rather than allocating a profile for every projectile.

These are visual accents of the current attack, not additional hitboxes. A
fast shot must not play a delayed safe-looking wind-up after it has dealt
damage. Routine automatic fire moves the actual mounted tool; the locomotion
phase remains driven by distance traveled. Heavy actions and target folds use
bounded, directional poses, and always settle back to a planted body.

## Event and identity rules

`ShotInfo.weapon_slot` identifies the actual equipment slot that fired, in
addition to the stable actor token and weapon ID. A repeated weapon ID does
not identify a slot. Synthetic or delayed events without a known slot use
`-1` and do not guess a mounted weapon. This presentation value does not add
fields to saved projectiles or support bodies.

`PlayerHurtInfo` carries actual HP and shield changes. A completely absorbed
hit has a defensive clamp/arc and shield sound, without the red body-hurt pose
or injury shake. A partially absorbed hit still shows its actual HP loss.

`support_event` supplies immutable source/target values for spawn, attack,
repair, production, retrieval, damage, destruction and expiry. The view and
audio detach these subscriptions when a session is replaced. A removed unit
can leave a short paper remains snapshot; it cannot be revived by a visual.

The existing `world_event` supplies committed interaction results, ability
origins/destinations and signed companion identities. It remains a read-only
notification to presentation. Rejected interactions visibly stop or rebound;
they never advance a machine's working animation or invent a repair.

## Interaction vocabulary

- Repairs place a patch on the actual recipient, close staples and let the
  paper body settle upright. HP, copy condition and support lifetime remain
  separate values.
- Active Echo retirement leaves a brief copy silhouette, then folds, pulls
  fibres or presses it into waste according to its recorded skill. Natural
  exhaustion stays quiet and does not claim a free final attack.
- Machines connect the hand, lever and spring-back. The stopped-state bar and
  successful repair patch are separate overlays, so stopping a repaired press
  cannot hide the repair.
- All six role abilities use finite live-body poses and committed origin/target
  values. Rewind and swap connect actual endpoints; no decorative path changes
  collision, immunity or damage.
- Echo work consumes its stable-UID result directly into the shared machine grip.
  It never guesses a reordered copy, emits a second operation or invents success.
- Rescue carries immutable source and safe positions. A short source-position
  shackle/departure sequence hands off to the real safe worker; presentation
  never creates an additional worker. Recruitment changes the real companion's
  badge after commit.

## Validation contract

Normal-size, normal-speed, muted captures must show who acted, the contact
target and the result. Existing static art is retained, including its palette
and source provenance. Reduced effects keep identity/contact/result while
removing optional travel and debris. Pause freezes visual clocks, and rendering
must preserve simulation state and both RNG streams.

The legal crowded case retains eight Echoes, the existing enemy/projectile
limits and twelve supports. Feedback queues and per-frame drawing stay capped;
presentation must not reduce enemies to make a capture look cleaner.

Regression tests cover slot identity, full/partial shield absorption, event
detach, truthful support targets, repaired-and-stopped overlays, six material
actions, pause/reduced behavior and finite snapshots. Native CI captures are
disclosed scripted fixtures, not human playthroughs or subjective feel/audio
approval. All Godot import, compilation, tests and rendering run remotely in
GitHub Actions, in accordance with the project's development constraint.

Capture dimensions and language are established before the Godot process starts.
Godot4.7.2 starts MovieWriter from ProjectSettings before the probe initializes;
changing the Window later does not change the recorded movie header. The CI-only
ignored `override.cfg` pins native startup dimensions and is removed on exit;
ffprobe checks the delivered video dimensions,60fps and absence of an audio track.
See [the pinned engine startup](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4840-L4855).

Paired pressure runs use the same probe SHA on the candidate and archived public
game. The shared harness changes teardown only: timing, simulation, fixtures and
captures are unchanged. Exit checks retain every engine error, verify weak Main/
Sim references and stop audio after detaching the session. Measurements from a
software renderer describe that controlled diagnostic, not client-device FPS.
