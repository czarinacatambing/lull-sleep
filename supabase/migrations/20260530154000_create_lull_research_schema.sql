create schema if not exists lull_research;

create extension if not exists pgcrypto;

create table if not exists lull_research.research_events (
    id uuid primary key,
    event_name text not null,
    install_id uuid not null,
    occurred_at timestamptz not null,
    app_version text not null,
    app_build text not null,
    schema_version integer not null,
    payload jsonb not null default '{}'::jsonb,
    received_at timestamptz not null default now()
);

create index if not exists research_events_install_occurred_idx
    on lull_research.research_events (install_id, occurred_at desc);

create index if not exists research_events_event_occurred_idx
    on lull_research.research_events (event_name, occurred_at desc);

create table if not exists lull_research.onboarding_profiles (
    install_id uuid primary key,
    recorded_at timestamptz not null,
    app_version text not null,
    app_build text not null,
    completion_route text,
    selected_sleep_problem_ids integer[] not null default '{}',
    selected_wake_factor_ids integer[] not null default '{}',
    selected_pre_bed_activity_ids integer[] not null default '{}',
    selected_tried_thing_ids integer[] not null default '{}',
    sleep_window_minutes integer,
    chronotype text,
    bottleneck text,
    baseline_score integer,
    generated_routine_step_count integer,
    tested_remedy_id text,
    raw_payload jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now()
);

create table if not exists lull_research.nightly_sessions (
    night_id uuid primary key,
    install_id uuid not null,
    routine_id text,
    started_at timestamptz,
    current_bedtime timestamptz,
    target_bedtime timestamptz,
    expected_ritual_start_at timestamptz,
    actual_ritual_start_at timestamptz,
    completed_at timestamptz,
    completed_nightly_flow boolean,
    tested_remedy_id text,
    tested_remedy_label text,
    routine_step_count integer,
    routine_step_attempt_count integer,
    routine_day_number integer,
    chronotype text,
    bottleneck text,
    user_tier text,
    app_version text not null,
    app_build text not null,
    raw_payload jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now()
);

create index if not exists nightly_sessions_install_started_idx
    on lull_research.nightly_sessions (install_id, started_at desc);

create index if not exists nightly_sessions_tested_remedy_idx
    on lull_research.nightly_sessions (tested_remedy_id);

create table if not exists lull_research.routine_step_starts (
    id uuid primary key default gen_random_uuid(),
    night_id uuid,
    install_id uuid not null,
    started_at timestamptz not null,
    step_index integer,
    step_label text,
    remedy_id text,
    step_mode text,
    tested_remedy_id text,
    chronotype text,
    bottleneck text,
    app_version text not null,
    app_build text not null,
    raw_payload jsonb not null default '{}'::jsonb
);

create index if not exists routine_step_starts_night_idx
    on lull_research.routine_step_starts (night_id, step_index);

create table if not exists lull_research.routine_step_attempts (
    id uuid primary key,
    night_id uuid,
    install_id uuid not null,
    recorded_at timestamptz not null,
    step_index integer,
    step_label text,
    remedy_id text,
    step_mode text,
    status text not null check (status in ('completed', 'skipped')),
    duration_seconds integer,
    tested_remedy_id text,
    chronotype text,
    bottleneck text,
    app_version text not null,
    app_build text not null,
    raw_payload jsonb not null default '{}'::jsonb
);

create index if not exists routine_step_attempts_night_idx
    on lull_research.routine_step_attempts (night_id, step_index);

create index if not exists routine_step_attempts_remedy_status_idx
    on lull_research.routine_step_attempts (remedy_id, status);

create table if not exists lull_research.media_sessions (
    id uuid primary key default gen_random_uuid(),
    night_id uuid,
    install_id uuid not null,
    recorded_at timestamptz not null,
    media_type text not null,
    content_id text,
    configured_duration_seconds integer,
    listened_duration_seconds integer,
    completed boolean,
    tested_remedy_id text,
    infinite boolean,
    fade_out boolean,
    has_recording boolean,
    chronotype text,
    bottleneck text,
    app_version text not null,
    app_build text not null,
    raw_payload jsonb not null default '{}'::jsonb
);

create index if not exists media_sessions_night_idx
    on lull_research.media_sessions (night_id, media_type);

create index if not exists media_sessions_type_content_idx
    on lull_research.media_sessions (media_type, content_id);

create table if not exists lull_research.morning_checkins (
    night_id uuid primary key,
    install_id uuid not null,
    recorded_at timestamptz not null,
    sleep_score integer check (sleep_score between 1 and 5),
    hours_slept numeric,
    tested_remedy_id text,
    tested_remedy_label text,
    has_note boolean,
    has_voice_note boolean,
    completed_nightly_flow boolean,
    routine_step_attempt_count integer,
    lights_level integer,
    lights_level_source text,
    perceived_temp integer,
    chronotype text,
    bottleneck text,
    app_version text not null,
    app_build text not null,
    raw_payload jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now()
);

create index if not exists morning_checkins_install_recorded_idx
    on lull_research.morning_checkins (install_id, recorded_at desc);

create or replace view lull_research.nightly_outcomes as
select
    n.install_id,
    n.night_id,
    n.started_at,
    n.current_bedtime,
    n.target_bedtime,
    n.expected_ritual_start_at,
    n.actual_ritual_start_at,
    n.completed_at,
    n.tested_remedy_id,
    n.tested_remedy_label,
    n.routine_step_count,
    n.routine_step_attempt_count,
    m.sleep_score,
    m.hours_slept,
    m.has_note,
    m.has_voice_note,
    n.chronotype,
    n.bottleneck,
    n.user_tier
from lull_research.nightly_sessions n
left join lull_research.morning_checkins m using (night_id);

create or replace view lull_research.step_completion_summary as
select
    remedy_id,
    step_label,
    count(*) filter (where status = 'completed') as completed_count,
    count(*) filter (where status = 'skipped') as skipped_count,
    count(*) as attempt_count,
    round(
        count(*) filter (where status = 'completed')::numeric
        / nullif(count(*), 0),
        4
    ) as completion_rate
from lull_research.routine_step_attempts
group by remedy_id, step_label;

alter table lull_research.research_events enable row level security;
alter table lull_research.onboarding_profiles enable row level security;
alter table lull_research.nightly_sessions enable row level security;
alter table lull_research.routine_step_starts enable row level security;
alter table lull_research.routine_step_attempts enable row level security;
alter table lull_research.media_sessions enable row level security;
alter table lull_research.morning_checkins enable row level security;
