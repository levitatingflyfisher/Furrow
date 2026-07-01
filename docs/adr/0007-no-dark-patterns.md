# ADR-0007: No streaks-as-dark-patterns

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

Habit trackers converge on the same engagement machinery: a streak that turns red
and "breaks," a push notification when you slip, a completion percentage that
frames a normal life as failure, celebratory sounds that condition the tap. These
demonstrably increase retention — and they do it by manufacturing guilt. Furrow's
whole thesis (see [VISION.md](../VISION.md) and the [white paper](../whitepaper.md))
is that a tool meant to help you become who you want to be should not manipulate
you to keep you opening it. This is the decision most likely to be re-litigated by
a well-meaning "let's boost engagement" change, so it is written down.

## Decision

**Refuse the standard engagement dark patterns, as a product invariant:**

- Streaks **never turn red** and **reset silently** — a broken chain is not an
  alarm; `bestChainDays` is kept as a calm record, shown only on Habit Detail.
- **No punitive or nagging notifications.** The *only* notification Furrow posts
  is the transient Android foreground-service notice that keeps a **running
  duration timer** alive — never a "you broke your streak" nudge.
- **Stats are raw counts, not percentages.** No "you completed 43%" framing.
- **Awards are calm:** earned once and kept, celebrated with a slow confetti and a
  quiet fact line — no "Achievement Unlocked", no sound.
- Progress colour is **never red**; "behind" is amber, "on pace" is a soft green.

## Consequences

- **Buys:** the app is trustworthy — it can sit on a phone for months without
  becoming a source of shame, which is the point of a *domestic* virtue tracker.
- **Costs:** measured retention will be lower than a guilt-driven competitor's,
  and there is a real open problem (see VISION § Horizons): a tracker that never
  nags is a tracker easy to forget. We accept that cost rather than solve it with
  a dark pattern.
- **Forecloses:** engagement-maximizing features — streak-freeze upsells, loss-
  aversion reminders, leaderboards. A change that raises engagement by inducing
  guilt is out of scope by construction.

## Alternatives considered

- **Opt-in reminders:** deferred, not rejected outright — a *gentle,
  non-manipulative* presence is a stated Far-horizon problem, but no
  implementation yet respects the person rather than farming them, so we ship
  none.
- **Percentage stats / streak alarms as a toggle:** rejected — shipping a dark
  pattern behind a default-off switch still normalizes it and complicates the calm
  design for no benefit we endorse.
