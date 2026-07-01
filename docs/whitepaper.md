# Furrow — White Paper

*A quiet, local-first virtue practice: the Franklin grid, reimagined, with no
streaks-as-dark-patterns.*

**Status:** conceptual/strategic overview. For the invariants see
[VISION.md](../VISION.md); for the mechanics,
[architecture/OVERVIEW.md](architecture/OVERVIEW.md); for the exact rules,
[reference/](reference/). This document is honest about the line between what is
built and what is aspirational — see §6.

---

## Abstract

Most habit trackers are engagement products wearing a self-improvement costume.
They increase retention with streaks that "break" and turn red, notifications
that arrive when you slip, and completion percentages that render an ordinary
life as failure. It works — and it works by manufacturing guilt. Furrow takes the
opposite position: a tool meant to help you become who you want to be should be
*calm*, should run entirely on your own device, and should never manipulate you to
keep you opening it. It is Benjamin Franklin's thirteen-virtues book of days,
reimagined for a phone: one habit per row, seven inked cells per week, the furrow
deepening with each pass — and nothing else to chase.

## 1. The problem

A habit or virtue log is intimate data — a record of who you are trying to be and
how you are doing at it. The mainstream tools handle that intimacy in two ways
that both fail the household:

- **They monetize attention.** Streak alarms, loss-aversion reminders, and
  celebratory jingles are conversion mechanics. The product's incentive (keep you
  engaged) is quietly opposed to yours (build a calm practice).
- **They monetize the data.** An account is required, everything syncs to a
  backend, and the private graph of your intentions becomes someone's asset. The
  price of tracking your virtues is surrendering them.

Both are avoidable. Neither is avoided by default in this category.

## 2. The idea

**Separate the practice from the pressure, and keep the data on the device.**

- *Calm by construction.* Streaks never turn red and reset silently. Stats are raw
  counts, not percentages. Awards are earned once and celebrated gently. There are
  no punitive notifications. This isn't a settings toggle you can turn off — it is
  the design, recorded as an invariant ([ADR-0007](adr/0007-no-dark-patterns.md)).
- *Local-first, ghost-mode.* All data lives in on-device SQLite. There is no
  account, no server, and no network layer at all — the shipped Android build
  carries no `INTERNET` permission ([ADR-0004](adr/0004-local-first-ghost-mode.md),
  [privacy model](privacy-model.md)). The privacy claim is *checkable*, not
  promised.

The interface *is* the metaphor: a **furrow**, a plough-line deepened by each
repeated pass. Marking today blooms the cell upward, proportional to progress, so
a single +1 or logged minute is acknowledged at once. Accumulation is the reward.

## 3. The lineage: Franklin's book of days

The idea is not new; it is 250 years old, brought to a phone. Franklin carried a
small book with a grid of thirteen virtues, marking each evening where he fell
short, and giving one virtue his attention each week. The genius of it was
gentleness at scale: a durable, private, self-administered practice with no
audience and no scorekeeper. Furrow ships his thirteen — in his own order, each
with its precept — as an optional seed, with a quiet virtue-of-the-week rotation.
The novelty is not the virtues; it is refusing to bolt the modern engagement
casino onto them.

## 4. Three cadences, one grid

Real domestic habits come in three shapes, and Furrow keeps all three on one
uniform surface ([ADR-0006](adr/0006-three-cadences-one-table.md)):

- a **tick** — done or not (meditate today);
- a **count** — reach N per day (8 glasses of water);
- a **timer** — accumulate time (30 minutes reading), stored as many sessions per
  day and completed when the sum meets the target.

One `Habits` table with a cadence discriminator, one `HabitMarks` table with a
surrogate key, one set of pure domain functions. The grid reads the same for all
three; the storage stays faithful to each.

## 5. Positioning: a household tool, not a growth product

The gravity in this category pulls every app toward the engagement funnel and the
cloud account. Furrow deliberately doesn't go there:

- **vs. the cloud incumbents** (streak-driven, account-required trackers) — they
  own your data and optimize your guilt. Furrow owns neither: no account, no
  server, calm by invariant. The trade is explicit and honest — you give up
  cross-device sync and cloud backup (§6) to get a tool that can't track you and
  won't shame you.
- **vs. a paper journal** — Furrow keeps the paper journal's privacy and calm
  while adding the one thing paper can't: automatic, faithful accumulation across
  three cadences, and a grid that shows the groove deepening.

The defensible position is not a feature; it is a *stance* — the household's data
stays with the household, and the tool serves the person rather than farming them.

## 6. What is built, and what is not

A white paper that overclaims is marketing. Honestly, as of v0.1.0:

**Built, tested, load-bearing:** the full loop — create a habit, mark it on the
Today grid across all three cadences, watch the cell bloom, earn a calm award —
works end-to-end and persists locally in Drift. The signature FurrowRow grid with
partial-bloom cells is pinned by golden tests; the streak/completion/clean-week
logic is pure and unit-tested; the Franklin seed and virtue-of-the-week ship; the
app runs fully offline on Android (APK) and web (PWA), fonts bundled, with no
network egress.

**Aspirational — documented, not shipped:** there is no sync, no multi-device, no
cloud backup, and no multi-user — all by design. An encrypted, seed-phrase-backed
`.ohbk` export/restore now exists (see [ADR-0008](adr/0008-encrypted-backup-seed-phrase.md)),
but it is a manual backup you carry yourself, not sync — lose the device without
having made one (PDF or `.ohbk`), or lose the recovery phrase for an `.ohbk` you
did make, and the data is gone. `weeklyCount` schedules and
week-grained streaks are schema-ready but UI-deferred; awards are six hardcoded
checks, not a general engine; the auth token/named tiers are `UnimplementedError`
stubs. See [limitations](limitations.md) and the
[Vision scorecard](../VISION.md#honest-scorecard--built-vs-aspirational).

The honest boundary matters: Furrow's calm is also its hardest open problem — a
tracker that never nags is a tracker easy to forget, and we would rather ship
nothing than ship a manipulative reminder to fix it.

## 7. Why it's worth doing

Because the alternative — an attention-farming, account-gated log of your private
intentions — is the category default, and it doesn't deserve a household's trust.
The contribution is not a new algorithm. It is the demonstration that a genuinely
useful daily-virtue and habit practice can be **calm, local-first, and
account-free** without feeling like a compromise — Franklin's book of days,
reimagined, kept honestly on your own device.

---

## References

- Franklin, B. *The Autobiography of Benjamin Franklin* — the thirteen virtues and
  the "book of days" grid this app reimagines.
- Diátaxis (Procida, D.) — the documentation framework this project's
  [docs](README.md) follow.

*The code and comments referenced here were authored by an AI assistant and
describe what currently exists — take them with gratitude and a grain of salt, and
verify before relying.*
