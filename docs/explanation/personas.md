# Personas

Agents drive the real Furrow build as these people, per the fleet testing rule.
Each scenario names a start state, plain steps, what success looks like, and
what to check. "Standard checks" means: text scale 1.3 at 360 dp width, dark
mode, airplane mode, and any error read aloud in plain words. Scenarios aim at
the weak spots found by the September 2026 lens audit.

## Primary: Amara, a parent keeping a few habits between bedtimes

Amara is 41, raising two kids with their partner, and wants three habits to
stick: water, twenty minutes of reading, and a daily walk. They open Furrow
once at night on the sofa, phone in one hand, often with a child asleep on the
other arm.

- **Goal:** mark today in under a minute and fix yesterday if they forgot.
- **Context:** one-handed, tired, dim room, dark mode on, text scale 1.3.
- **Would quit if:** a tap does nothing and nothing says why, or a habit's
  history vanishes with no way back.

**A1. Plant a habit, the empty-form trap.** Start: fresh install, onboarding
done with a blank field. Steps: open the new-habit form, tap Plant with the
name empty; then type "Water", pick a count of 8, tap Plant. Success: the empty
tap either is visibly disabled or says what is missing; the filled form lands
on Today. Check: standard checks; the commit button is reachable by thumb.

**A2. Mark today on each cadence.** Start: one tick, one count (8), one timer
(20 min) habit. Steps: on Today, tap today's cell for each; tap a past day's
cell. Success: each tap gives visible feedback; a count shows "1 of 8" in
words; a past-day tap does something or explains itself. Check: today's column
is distinguishable; weekday letters readable; cell accessible names state the
cadence.

**A3. Take back a mis-tap.** Start: count habit at 3 of 8. Steps: tap once too
many, then try to undo it without knowing about long-press; then use the log
sheet's +5 chip and try to reverse it. Success: a visible decrement or Undo
exists. Check: record whether long-press was the only way.

**A4. Delete a mark, clear history.** Start: a habit with a month of marks.
Steps: from habit detail, delete one mark with the ×; then Clear history.
Success: each offers Undo, or states plainly it cannot be undone and how many
marks go. Check: undo after delete; dates read "Fri 4 Sep", not "2026-09-04".

## Secondary: Dev, a retired teacher trying the Franklin thirteen

Dev is 68, lives with their spouse, reads with large text and has mild low
vision. They chose Furrow for Franklin's virtues and read every precept.

- **Goal:** pick a virtue of the week, understand each award, and keep the
  household's encrypted backup.
- **Context:** text scale 1.3 or higher, sits at a table, reads slowly.
- **Would quit if:** words are cut off mid-sentence or labels need guessing.

**D1. Seed and choose a focus.** Start: fresh install. Steps: choose the
Franklin thirteen in onboarding; open the focus-virtue picker; read each
precept. Success: every precept is shown whole; the "suggested" chip on the
onboarding chooser is not clipped. Check: standard checks; count rows visible
above the fold on Today.

**D2. Read the award shelf.** Start: a week of marks on two habits, one
scheduled Mon/Wed/Fri. Steps: open Stats; try to learn each award's criterion
by tapping. Success: criteria readable without a long-press; the Mon/Wed/Fri
streak is not stuck at 1. Check: earned vs unearned distinct in more than
opacity; dark mode contrast.

**D3. Seed twice.** Start: Franklin seeded, one virtue rested. Steps: tap the
Settings option to plant the thirteen again. Success: no duplicate virtue; the
message says what actually happened. Check: standard checks.

**D4. Recovery phrase re-entry.** Start: habits exist, no backup. Steps: in
Settings, start a backup; at re-entry type 11 words, tap Confirm; then 12
with one wrong word. Success: a live word count; the dialog stays open, keeps
the text, and names the wrong position. Check: the error wraps at 1.3.
