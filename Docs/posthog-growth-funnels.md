# TenThirty PostHog growth funnels

Build these after the app version containing the new analytics events is live and has generated at least one test session. PostHog only offers events that it has received.

## One-time RevenueCat setup

The app now sends its PostHog `distinct_id` to RevenueCat as `$posthogUserId`. This lets RevenueCat's server-side subscription events join the same user journey as the in-app events.

In RevenueCat:

1. Open **Project settings → Integrations → PostHog**.
2. Paste the PostHog **Project API key** (not a personal API key).
3. Select the region matching the app's PostHog host. The current default app host is US.
4. Keep the default `rc_*` event names.
5. Add both production and sandbox keys so test purchases do not pollute production.
6. Make one sandbox purchase with a fresh install. In RevenueCat Customer History, confirm the PostHog integration event says it was delivered. Then confirm `rc_trial_started_event` appears in PostHog **Data management → Events**.

Use RevenueCat events as the source of truth for trial conversion, renewal, cancellation, expiration, and revenue. Those lifecycle events can happen while TenThirty is closed. The app's own `trial_started` event is useful for immediate paywall-flow debugging, but should not be the authoritative revenue metric.

## Funnel 1: New install to trial

In PostHog, open **Product Analytics → New insight → Funnel**.

Settings:

- Name: `Growth — New install to trial`
- Date range: `Last 30 days`
- Conversion window: `24 hours`
- Order: `Sequential`
- Counting: `Unique users`
- Conversion display: `Relative to previous step`
- Hide incomplete periods: `On` when using Historical trends

Steps:

1. `first_open`
2. `onboarding_started`
3. `paywall_viewed` with `context = onboarding`
4. `paywall_primary_tapped`
5. `purchase_started`
6. `rc_trial_started_event` OR `rc_initial_purchase_event` as one inline-combined step

Do not add app-blocking permission as a required step here: the user is allowed to skip it, so requiring it would distort the core conversion rate. Do not add `onboarding_completed` after purchase either; purchase is the business outcome.

Start with no breakdown. Once there are at least 100 installs in the selected period, duplicate the insight and add one breakdown at a time:

- `test_cohort`, attribution `First touchpoint`
- `app_version`, attribution `First touchpoint`
- `product_id`, attribution `Specific step` on the purchase step

Read this funnel from the lowest relative conversion step. That is the next screen or action to fix. Click the dropped-off count to inspect users and session replays.

## Funnel 2: Screen Time permission diagnostic

Settings:

- Name: `Activation — App blocking permission`
- Conversion window: `1 hour`
- Order: `Sequential`
- Counting: `Unique users`
- Conversion display: `Relative to previous step`

Steps:

1. `onboarding_screen_app_blocking_commitment`
2. `hard_app_blocking_permission_requested`
3. `hard_app_blocking_permission_result` with `granted = true`
4. `app_blocking_configured` with `enabled = true`
5. `paywall_viewed` with `context = onboarding`

Create a separate Trend for `app_blocking_skipped`, not an exclusion in this funnel. Exclusions remove those people from the whole calculation and can make permission conversion look artificially strong.

## Funnel 3: Trial activation

This answers whether buyers reach TenThirty's actual value moment, rather than merely starting a trial.

Settings:

- Name: `Activation — Trial to first all-clear night`
- Conversion window: `7 days`
- Order: `Sequential`
- Counting: `Unique users`
- Conversion display: `Relative to previous step`

Steps:

1. `rc_trial_started_event` OR `rc_initial_purchase_event`
2. `sleep_rule_completed_on_time` OR `sleep_rule_completed_late`
3. `contract_all_clear`

Break down by `product_id` only after volume is large enough to avoid reading noise as a pattern.

## Funnel 4: Trial to paid

Settings:

- Name: `Revenue — Trial to paid`
- Conversion window: `10 days`
- Order: `Sequential`
- Counting: `Unique users`
- Conversion display: both Overall and Relative when reviewing

Steps:

1. `rc_trial_started_event`
2. `rc_trial_converted_event`

Do not exclude `rc_trial_cancelled_event`; doing so would inflate the trial-to-paid rate. Track it beside the funnel as a Trend:

- Numerator event: `rc_trial_cancelled_event`
- Compare against: `rc_trial_started_event`
- Display: weekly unique users

Also create weekly Trends for `rc_renewal_event`, `rc_cancellation_event`, `rc_expiration_event`, and RevenueCat revenue.

## Event QA checklist

For one clean sandbox session, verify this order in PostHog Live Events:

1. `first_open`
2. `onboarding_started`
3. onboarding screen events
4. `hard_app_blocking_permission_requested`
5. `hard_app_blocking_permission_result`
6. `app_blocking_configured` or `app_blocking_skipped`
7. `paywall_viewed`
8. `paywall_primary_tapped`
9. `purchase_started`
10. `purchase_succeeded`
11. `trial_started` or `subscription_started`
12. matching RevenueCat `rc_trial_started_event` or `rc_initial_purchase_event` on the same PostHog person

If step 12 creates a second person, check that the RevenueCat customer has a `$posthogUserId` subscriber attribute and that it exactly matches the app event `distinct_id`.
