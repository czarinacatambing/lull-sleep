# Future Work

Features parked until the core experiment loop is validated with 5+ testers completing 14 nights.

---

## Near-Term Release Follow-Ups

These are not new feature bets. They are the short list of release hardening tasks now that PostHog and the Supabase research backend are wired up.

### Analytics and research data QA

- Run a real-device end-to-end analytics pass: install a fresh build, complete onboarding, start a nightly routine, start/skip/continue multiple routine steps, use at least one media step, complete the night, and submit the morning check-in.
- Verify the same tester journey appears in PostHog for product analytics and in Supabase under `public.lull_*` tables for durable research data.
- Confirm event timestamps, anonymous install ID continuity, app version/build fields, routine step IDs, variable names, sleep scores, and media durations are present where expected.
- Check the offline path by completing a short routine without network, reopening with network restored, and confirming queued research events flush.

### Dashboard and query validation

- Build the first PostHog views for activation, nightly routine completion, step drop-off, morning check-in completion, and retention by install cohort.
- Build the first Supabase queries for nightly outcomes, skipped-vs-continued step rates, variable tested per night, media usage, and sleep-score changes by routine pattern.
- After the first small cohort, compare PostHog counts against Supabase rows for the same date range so we know no major instrumentation path is silently dropping data.

### Privacy and release compliance

- Update App Store privacy labels to reflect analytics/research collection before release.
- Audit public website and marketing copy for analytics claims. In particular, any "no third-party analytics" language needs to be removed or rewritten now that PostHog is used.
- Keep the current privacy guardrails intact: do not send raw brain-dump text, voice recordings, transcripts, camera images, or full local app state to analytics or research systems.
- Re-check the privacy policy after final event names settle so it accurately describes the categories collected.

### Backend hardening

- Treat the current Supabase ingest token as a soft gate because it is embedded in the app bundle.
- Add a stronger anti-abuse layer before broader launch, such as App Attest or per-install signed ingest tokens issued by a server.
- Add simple monitoring for Edge Function failures and unexpected event volume spikes.
- Decide whether old raw research events should be retained indefinitely, archived, or periodically compacted after normalized tables are backfilled.

### Retire the beta export path

- Keep Google Sheets export as debug-only during beta if it remains useful for manual review.
- Remove the Google Sheets path entirely once Supabase dashboards and queries cover the release workflow.
- Make sure no production foreground path attempts to write to Google Sheets.

---

## Live Activities (Dynamic Island + Lock Screen)

**What:** Persistent activity card that appears on the Lock Screen and Dynamic Island (iPhone 14 Pro+) — the kind of card that shows up next to the time in the screenshot of competitor apps showing water-bottle and fire-icon Live Activities.

### Highest-leverage use case: bedtime prep checklist (interactive)

Show the night's prep checklist as a Live Activity starting ~90 min before bedtime. Each item has a "Done" button the user can tap directly from the Lock Screen — no need to unlock or open the app. The activity ends when all items are checked or when the wind-down flow starts.

```
🌙 Bedtime prep · 2 of 4 done

✓ No screens                  9:00 PM
✓ Dim the lights              9:15 PM
○ Cold room prep              9:30 PM  [Done]
○ Brain dump                  9:45 PM  [Done]
```

**Why this beats the original get-up-timer pick:**
- **Frequency** — touches every tester every night, vs. only when someone wakes mid-sleep
- **Interactivity** — actual actions to perform, not just a passive countdown. This is what Apple added interactive buttons (iOS 17) to Live Activities for.
- **Friction kill** — opening the app to check off "No screens" is exactly the kind of step testers skip; tapping Done from the Lock Screen removes the friction.

### Secondary use cases (after prep checklist)

- 20-minute mid-sleep get-up timer (the original v1 pick)
- Boring story playback (current chapter + elapsed time)
- 4-7-8 breathing cycle counter
- Nightly flow current step + step number

### Technical scope

- New Widget Extension target in `Lull.xcodeproj`
- `ActivityAttributes` struct for the prep checklist (array of items + completion state per item)
- `ActivityConfiguration` widget bundle with 4 size states: compact leading, compact trailing, expanded, Lock Screen
- App Group entitlement so main app and extension share state
- `AppIntent` for the "Done" button — calls back into the app to mark items done and update activity state
- `Activity.request / update / end` calls wired into `scheduleBedtimePrepNotifications()` and `togglePrepDone()`
- `NSSupportsLiveActivities = YES` in Info.plist
- iOS 17+ for interactive buttons (Lull is already iOS 17, fine)
- Testing requires real device (simulator support is partial)

**Effort estimate:** ~1.5–2 days for the prep checklist (more complex than a single timer because of multi-item state + interactive buttons). Subsequent activities ~half a day each because the extension scaffold is reused.

### Why deferred

Live Activities are polish, not core. Won't move retention before the loop is proven. Premium feel is only valuable when there's a working experiment loop underneath.

### Trigger to revisit

Look at exported tester data after the first cohort runs ~5 nights:
- **If <50% of testers complete prep items consistently** → friction is real; Live Activities is the highest-leverage build. Pull forward.
- **If >80% complete prep** → friction isn't the issue, keep deferred.
- **Or** if 5+ testers complete full 14-night cycles → core loop validated, build for polish.
