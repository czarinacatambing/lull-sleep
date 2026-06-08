# Lull Research Data Backend

This backend stores anonymous, granular usage/research data separately from PostHog.

Use PostHog for funnels, retention, cohorts, and quick product questions. Use this Supabase/Postgres path for the durable night-by-night dataset: onboarding answers, routine variables, step attempts, media usage, and morning scores.

## Architecture

```text
Lull iOS app
  -> AnalyticsService
       -> PostHog capture API

Lull iOS app
  -> ResearchDataService
       -> Supabase Edge Function: lull-research-ingest
            -> public.lull_research_events
            -> normalized Postgres tables
```

The app sends only anonymous `installId` values. Do not send names, emails, note text, transcripts, or recordings. Tables live in the default `public` schema with a `lull_` prefix so Supabase does not need custom schema exposure.

## Tables

The migration creates:

- `public.lull_research_events`: immutable-ish raw event envelopes for audit/backfill.
- `public.lull_onboarding_profiles`: latest onboarding profile per anonymous install.
- `public.lull_nightly_sessions`: one row per nightly routine session.
- `public.lull_routine_step_starts`: when a step screen was shown.
- `public.lull_routine_step_attempts`: completed/skipped step outcomes.
- `public.lull_media_sessions`: sleep sounds, boring stories, and brain dump usage.
- `public.lull_morning_checkins`: sleep score and morning metadata tied to `night_id`.
- `public.lull_nightly_outcomes`: convenience view joining nights to morning scores.
- `public.lull_step_completion_summary`: convenience view for completion rates.

RLS is enabled on all tables. The app should never write directly to these tables. It writes only to the Edge Function using a bearer token.

## Deploy

From the repo root:

```bash
supabase login
supabase init
supabase link --project-ref <project-ref>
supabase db push
supabase secrets set LULL_RESEARCH_INGEST_TOKEN=<long-random-token>
supabase functions deploy lull-research-ingest --no-verify-jwt
```

Skip `supabase init` if the repo already has a committed `supabase/config.toml`.

The Edge Function also needs Supabase's default function env vars:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

Supabase provides these in hosted Edge Functions. Keep `SUPABASE_SERVICE_ROLE_KEY` only on the server/function side.

## App Config

Set these values in the app build settings / generated Info.plist:

```text
LullResearchDataEndpoint = https://<project-ref>.functions.supabase.co/lull-research-ingest
LullResearchDataToken = <same long random token>
LullPostHogAPIKey = <posthog project api key>
LullPostHogHost = https://us.i.posthog.com
```

The placeholders are currently defined in `project.yml` and `Lull/Resources/Info.plist`.

## Useful Queries

Nightly outcomes by tested remedy:

```sql
select
  tested_remedy_id,
  count(*) as rated_nights,
  avg(sleep_score) as avg_sleep_score,
  avg(hours_slept) as avg_hours_slept
from public.lull_nightly_outcomes
where sleep_score is not null
group by tested_remedy_id
order by rated_nights desc;
```

Step completion rates:

```sql
select *
from public.lull_step_completion_summary
order by attempt_count desc;
```

Most-used sleep sounds:

```sql
select
  content_id as sound_id,
  count(*) as sessions,
  avg(listened_duration_seconds) as avg_listened_seconds,
  count(*) filter (where completed) as completed_sessions
from public.lull_media_sessions
where media_type = 'sleep_sound'
group by content_id
order by sessions desc;
```

Boring story listening depth:

```sql
select
  content_id,
  count(*) as sessions,
  avg(listened_duration_seconds) as avg_listened_seconds,
  percentile_cont(0.5) within group (order by listened_duration_seconds) as median_listened_seconds
from public.lull_media_sessions
where media_type = 'boring_story'
group by content_id
order by sessions desc;
```

Brain dump usage and next morning score:

```sql
select
  m.has_recording,
  count(*) as sessions,
  avg(o.sleep_score) as avg_sleep_score
from public.lull_media_sessions m
left join public.lull_nightly_outcomes o using (night_id)
where m.media_type = 'brain_dump'
group by m.has_recording;
```

Skipped steps before low-score mornings:

```sql
select
  a.remedy_id,
  a.step_label,
  count(*) as skipped_before_low_score
from public.lull_routine_step_attempts a
join public.lull_morning_checkins m using (night_id)
where a.status = 'skipped'
  and m.sleep_score <= 2
group by a.remedy_id, a.step_label
order by skipped_before_low_score desc;
```

## Privacy Guardrails

Allowed:

- anonymous install ID
- onboarding option IDs
- remedy IDs
- step status and duration
- sleep score
- coarse feature configuration, such as sound ID and timer duration

Avoid:

- names
- emails
- freeform notes
- brain dump audio
- brain dump transcripts
- exact user-entered note text
- raw `PersistedState` snapshots
