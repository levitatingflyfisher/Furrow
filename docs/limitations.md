# Limitations

An honest list of what Furrow does not do, cannot do today, or does imperfectly.
Read this before adopting — the goal is to save you an afternoon of discovery.
For the shape of what's built vs. aspirational, see the
[Vision scorecard](../VISION.md#honest-scorecard--built-vs-aspirational).

## No sync, no server-side backup, no multi-device

- **Local-only.** There is no cloud, no sync, and no server-side backup by design
  ([ADR-0004](adr/0004-local-first-ghost-mode.md)). Settings → Encrypted Backup
  can export an encrypted `.ohbk` copy of your habits, marks, and awards under
  a recovery phrase you generate and keep yourself
  ([ADR-0008](adr/0008-encrypted-backup-seed-phrase.md)) — but nothing moves
  automatically. If you lose or wipe the device without having made a backup
  (PDF or `.ohbk`) first, the data is gone. There is no "log in on your new
  phone and it's all there" — restoring means finding your own backup file
  and, for an encrypted one, your recovery phrase. Lose the phrase and the
  encrypted backup is unreadable; there is no reset.
- **Single-user.** There are no profiles. A shared family device shares one ghost
  profile; Furrow can't tell family members apart.
- **Token / Named tiers are stubs.** `GhostAuthRepository` is the only
  implementation; `upgradeToToken` / `upgradeToNamed` throw `UnimplementedError`.

## Schedules and streaks

- **`weeklyCount` is schema-only.** A habit you do "N times a week" is not yet
  expressible in the UI — v1 treats `weeklyCount` as "any day". The columns exist;
  the week-grained UI and week streak do not.
- **Streaks are schedule-naive.** The streak counts consecutive completed
  *calendar* days, not scheduled days. A habit scheduled Mon/Wed/Fri does not get
  a streak that understands the gaps — this is a deliberate v1 simplification.
- **Streaks reset silently and are never shown in red.** That's a feature
  ([ADR-0007](adr/0007-no-dark-patterns.md)), but if you *want* an alarming
  streak, Furrow will not give you one.

## Awards are hardcoded

- There are exactly **six** awards, and their unlock checks are hand-written in
  `AwardService` — there is **no general award-criterion engine**. Adding an award
  means writing code, not data. A general engine is deferred.

## Editing and history

- **Past editing is partial.** Long-press fixes a past *tick* (binary) inline. A
  past *count* or *duration* edit still goes through the detail screen — inline
  past-editing for those cadences is deferred (it needs a day-parameterised
  sheet).
- **Habit deletion vs. archive.** Habits are archived (hidden, kept) rather than
  hard-deleted in the normal flow, to preserve history.

## Other deferred pieces

- **Per-virtue precept editing.** The `UserPrefs` override key exists; there is no
  editor UI yet, so precepts are effectively the Franklin defaults.
- **Home-screen widget depth.** A widget exists but its metric rework is deferred.
- **No reminders.** By design, there are no habit reminders or nudges
  ([ADR-0007](adr/0007-no-dark-patterns.md)); the only notification is the
  transient one that keeps a running duration timer alive.

## Platform notes

- **Golden tests are environment-sensitive.** Font rasterisation differs across
  machines, so the golden suite under `test/visual/` is **tagged and excluded from
  CI**; regenerate locally with `flutter test --update-goldens test/visual/` when
  you deliberately change the grid's look.
- **Web storage is evictable.** Browser storage can be reclaimed under pressure;
  the PWA calls `navigator.storage.persist()` to resist this, but a browser may
  still clear an un-granted origin. The installed APK does not have this caveat.
- **iOS / desktop are not built.** Flutter could target them; Furrow ships Android
  + web today ([ADR-0005](adr/0005-pwa-and-apk.md)).

If any of the above is a hard requirement for you, Furrow may not fit yet — and
that's the point of listing it here.
