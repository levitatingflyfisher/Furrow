# Documentation

Organized on the [Diátaxis](https://diataxis.fr/) model — four kinds of docs for
four different needs. Find what you need by *what you're trying to do*, not by
guessing a filename.

| I want to… | I need | Go to |
|---|---|---|
| **learn by doing** | a Tutorial | [Tutorials](#tutorials) |
| **accomplish a specific task** | a How-to guide | [How-to guides](#how-to-guides) |
| **look up exact details** | Reference | [Reference](#reference) |
| **understand why** | Explanation | [Explanation](#explanation) |

New here? Start with the [README quickstart](../README.md), then
[Explanation § concepts](concepts.md), then the [Vision](../VISION.md).

---

## Tutorials
*Learning-oriented — take me by the hand through my first success.*

- The **[README quickstart](../README.md#quickstart-development)** — clone,
  generate code, run the app.

*Gap (contributions welcome):* a hand-held "add your first habit and fill a week"
walkthrough with screenshots. If you write one, put it in `docs/tutorials/`.

## How-to guides
*Task-oriented — how do I accomplish X (assumes you know the basics)?*

- **[Build & run](how-to/build-and-run.md)** — get a dev build going on device,
  emulator, or web, including the code-generation step.
- **[Ship the PWA + APK](how-to/ship-pwa-and-apk.md)** — the dual-target release
  flow (gh-pages web deploy + tagged Android release).
- Working *in* the repo (human or agent): **[AGENTS.md](../AGENTS.md)**.

## Reference
*Information-oriented — tell me exactly, precisely, completely.*

- **[Data model](reference/data-model.md)** — the Drift tables, columns, keys,
  and what each cadence stores.
- **[Cadences & awards](reference/cadences-and-awards.md)** — the exact rules for
  progress, completion, streaks, and each of the six award checks.
- **[Feature status](reference/feature-status.md)** — what's shipped vs. deferred,
  at a glance.

## Explanation
*Understanding-oriented — help me understand the ideas and the why.*

- **[Vision](../VISION.md)** — the one idea, the invariants, the honest scorecard.
- **[Architecture overview](architecture/OVERVIEW.md)** — the layers + diagrams.
- **[Architecture Decision Records](adr/)** — why each load-bearing choice was made.
- **[Concepts](concepts.md)** — habits, cadences, marks, virtues, the FurrowRow grid.
- **[Privacy model](privacy-model.md)** — exactly what leaves the device (nothing),
  and how to check.
- **[Limitations](limitations.md)** — read before adopting. What it does *not* do.

---

### The white paper

One long-form document complements this tree:
- **[White paper](whitepaper.md)** — the conceptual case: why a *calm*,
  local-first virtue tracker, the Franklin grid reimagined, and why "no
  streaks-as-dark-patterns" is the whole point.

*(There is no "yellow paper" — Furrow has no formal algorithmic core to specify.
The precise cadence/award rules live in [reference/](reference/) instead.)*
