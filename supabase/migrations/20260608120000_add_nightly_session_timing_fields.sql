alter table public.lull_nightly_sessions
    add column if not exists current_bedtime timestamptz,
    add column if not exists target_bedtime timestamptz,
    add column if not exists expected_ritual_start_at timestamptz,
    add column if not exists actual_ritual_start_at timestamptz;

create or replace view public.lull_nightly_outcomes as
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
from public.lull_nightly_sessions n
left join public.lull_morning_checkins m using (night_id);
