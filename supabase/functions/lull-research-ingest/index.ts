import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type JsonRecord = Record<string, unknown>;

type ResearchEnvelope = {
  id: string;
  eventName: string;
  installId: string;
  occurredAt: string;
  appVersion: string;
  appBuild: string;
  schemaVersion: number;
  payload: JsonRecord;
};

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ingestToken = Deno.env.get("LULL_RESEARCH_INGEST_TOKEN") ?? "";

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  if (!isAuthorized(request)) {
    return json({ error: "unauthorized" }, 401);
  }

  let event: ResearchEnvelope;
  try {
    event = await request.json();
    validateEnvelope(event);
  } catch (error) {
    return json({ error: "invalid_payload", detail: String(error) }, 400);
  }

  try {
    await insertRawEvent(event);
    await normalizeEvent(event);
  } catch (error) {
    console.error("research ingest failed", error);
    return json({ error: "ingest_failed" }, 500);
  }

  return json({ ok: true }, 200);
});

function isAuthorized(request: Request): boolean {
  if (!ingestToken) return false;
  const header = request.headers.get("authorization") ?? "";
  return header === `Bearer ${ingestToken}`;
}

function validateEnvelope(event: ResearchEnvelope): void {
  if (!event || typeof event !== "object") throw new Error("missing event");
  requireString(event.id, "id");
  requireString(event.eventName, "eventName");
  requireUuid(event.installId, "installId");
  requireString(event.occurredAt, "occurredAt");
  requireString(event.appVersion, "appVersion");
  requireString(event.appBuild, "appBuild");
  if (!Number.isInteger(event.schemaVersion)) throw new Error("schemaVersion must be integer");
  if (!event.payload || typeof event.payload !== "object") throw new Error("payload must be object");
}

function requireString(value: unknown, name: string): void {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${name} must be non-empty string`);
  }
}

function requireUuid(value: unknown, name: string): void {
  requireString(value, name);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new Error(`${name} must be uuid`);
  }
}

async function insertRawEvent(event: ResearchEnvelope): Promise<void> {
  const { error } = await supabase
    .from(tableName("research_events"))
    .upsert({
      id: event.id,
      event_name: event.eventName,
      install_id: event.installId,
      occurred_at: event.occurredAt,
      app_version: event.appVersion,
      app_build: event.appBuild,
      schema_version: event.schemaVersion,
      payload: event.payload,
    }, { onConflict: "id" });

  if (error) throw error;
}

async function normalizeEvent(event: ResearchEnvelope): Promise<void> {
  switch (event.eventName) {
    case "onboarding_profile_recorded":
      await upsertOnboardingProfile(event);
      return;
    case "nightly_session_started":
      await upsertNightlySessionStarted(event);
      return;
    case "nightly_session_completed":
      await upsertNightlySessionCompleted(event);
      return;
    case "routine_step_started":
      await insertRoutineStepStarted(event);
      return;
    case "routine_step_attempt_recorded":
      await insertRoutineStepAttempt(event);
      return;
    case "media_session_recorded":
      await insertMediaSession(event);
      return;
    case "morning_checkin_recorded":
      await upsertMorningCheckin(event);
      return;
    default:
      return;
  }
}

async function upsertOnboardingProfile(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedUpsert("onboarding_profiles", {
    install_id: event.installId,
    recorded_at: event.occurredAt,
    app_version: event.appVersion,
    app_build: event.appBuild,
    completion_route: str(p.completion_route),
    selected_sleep_problem_ids: intArray(p.selected_sleep_problem_ids),
    selected_wake_factor_ids: intArray(p.selected_wake_factor_ids),
    selected_pre_bed_activity_ids: intArray(p.selected_pre_bed_activity_ids),
    selected_tried_thing_ids: intArray(p.selected_tried_thing_ids),
    sleep_window_minutes: int(p.sleep_window_minutes),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    baseline_score: int(p.baseline_score),
    generated_routine_step_count: int(p.generated_routine_step_count),
    tested_remedy_id: str(p.tested_remedy_id),
    raw_payload: p,
    updated_at: new Date().toISOString(),
  }, "install_id");
}

async function upsertNightlySessionStarted(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedUpsert("nightly_sessions", {
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    routine_id: str(p.routine_id),
    started_at: event.occurredAt,
    current_bedtime: str(p.current_bedtime),
    target_bedtime: str(p.target_bedtime),
    expected_ritual_start_at: str(p.expected_ritual_start_at),
    actual_ritual_start_at: str(p.actual_ritual_start_at),
    tested_remedy_id: str(p.tested_remedy_id),
    tested_remedy_label: str(p.tested_remedy_label),
    routine_step_count: int(p.routine_step_count),
    routine_day_number: int(p.routine_day_number),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    user_tier: str(p.user_tier),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
    updated_at: new Date().toISOString(),
  }, "night_id");
}

async function upsertNightlySessionCompleted(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedUpsert("nightly_sessions", {
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    completed_at: event.occurredAt,
    completed_nightly_flow: bool(p.completed_nightly_flow),
    routine_step_attempt_count: int(p.routine_step_attempt_count),
    current_bedtime: str(p.current_bedtime),
    target_bedtime: str(p.target_bedtime),
    expected_ritual_start_at: str(p.expected_ritual_start_at),
    actual_ritual_start_at: str(p.actual_ritual_start_at),
    tested_remedy_id: str(p.tested_remedy_id),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    user_tier: str(p.user_tier),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
    updated_at: new Date().toISOString(),
  }, "night_id");
}

async function insertRoutineStepStarted(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedInsert("routine_step_starts", {
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    started_at: event.occurredAt,
    step_index: int(p.step_index),
    step_label: str(p.step_label),
    remedy_id: str(p.remedy_id),
    step_mode: str(p.step_mode),
    tested_remedy_id: str(p.tested_remedy_id),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
  });
}

async function insertRoutineStepAttempt(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedUpsert("routine_step_attempts", {
    id: uuidOrNull(p.step_attempt_id) ?? event.id,
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    recorded_at: event.occurredAt,
    step_index: int(p.step_index),
    step_label: str(p.step_label),
    remedy_id: str(p.remedy_id),
    step_mode: str(p.step_mode),
    status: str(p.status),
    duration_seconds: int(p.duration_seconds),
    tested_remedy_id: str(p.tested_remedy_id),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
  }, "id");
}

async function insertMediaSession(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedInsert("media_sessions", {
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    recorded_at: event.occurredAt,
    media_type: str(p.media_type),
    content_id: str(p.content_id),
    configured_duration_seconds: int(p.configured_duration_seconds),
    listened_duration_seconds: int(p.listened_duration_seconds),
    completed: bool(p.completed),
    tested_remedy_id: str(p.tested_remedy_id),
    infinite: bool(p.infinite),
    fade_out: bool(p.fade_out),
    has_recording: bool(p.has_recording),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
  });
}

async function upsertMorningCheckin(event: ResearchEnvelope): Promise<void> {
  const p = event.payload;
  await checkedUpsert("morning_checkins", {
    night_id: uuidOrNull(p.night_id),
    install_id: event.installId,
    recorded_at: event.occurredAt,
    sleep_score: int(p.sleep_score),
    hours_slept: num(p.hours_slept),
    tested_remedy_id: str(p.tested_remedy_id),
    tested_remedy_label: str(p.tested_remedy_label),
    has_note: bool(p.has_note),
    has_voice_note: bool(p.has_voice_note),
    completed_nightly_flow: bool(p.completed_nightly_flow),
    routine_step_attempt_count: int(p.routine_step_attempt_count),
    lights_level: int(p.lights_level),
    lights_level_source: str(p.lights_level_source),
    perceived_temp: int(p.perceived_temp),
    chronotype: str(p.chronotype),
    bottleneck: str(p.bottleneck),
    app_version: event.appVersion,
    app_build: event.appBuild,
    raw_payload: p,
    updated_at: new Date().toISOString(),
  }, "night_id");
}

async function checkedInsert(table: string, row: JsonRecord): Promise<void> {
  const { error } = await supabase.from(tableName(table)).insert(row);
  if (error) throw error;
}

async function checkedUpsert(table: string, row: JsonRecord, onConflict: string): Promise<void> {
  const { error } = await supabase.from(tableName(table)).upsert(row, { onConflict });
  if (error) throw error;
}

function tableName(name: string): string {
  return name === "research_events" ? "lull_research_events" : `lull_${name}`;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function int(value: unknown): number | null {
  return Number.isInteger(value) ? value as number : null;
}

function num(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function bool(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function intArray(value: unknown): number[] {
  return Array.isArray(value) ? value.filter(Number.isInteger) as number[] : [];
}

function uuidOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null;
}

function json(body: JsonRecord, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
