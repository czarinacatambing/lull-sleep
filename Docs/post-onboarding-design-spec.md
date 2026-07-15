# TenThirty Post-Onboarding Design Spec

## Product Premise

TenThirty is a sleep contract app for people whose phone steals their sleep.

The app should no longer feel like a routine browser. It should feel like a daily enforcement system:

> Clear the tasks you committed to finishing before bedtime.

The app has three tabs:

- `Today`: the current action queue and enforcement state. Clearing tasks on this screen should feel like getting to inbox zero like how Superhuman email app does. 
- `Rules`: the sleep contract editor
- `Trends`: proof that the contract protected the user

The bottom navigation should be:

```text
Today   Rules   Trends
```

Do not use:

```text
Today   Routine   Trends
```

The word `Routine` pulls the product back toward the old positioning. The new product is about rules, enforcement, and proof.

## Core Behavior

1. The user sets their sleep window and sleep rules during onboarding.
2. After onboarding, `Today` shows all the rules the user committed to. 
  1. top 1/4 of the screen shows whether and which apps are blocked/on cooldown. let's call this app blocking status card.
  2. 3/4 of remaining screen shows cards with each card representing a task user committed to. let's call these rule cards.
  3. The user confirms completion of each rule at each  with an explicit press-and-hold gesture. User holds the glowing rule card for 3 seconds → the fill sweeps across → the rule card *eases off to the side* → and the rule card below *rise up* to close the gap, with the next rule card inheriting the glow and its full due/grace details as it's promoted. 
    1. If user confirms completion of rule on time or within grace period:
      1. selected apps to block: apps do not get blocked and the next rule checkpoints proceeds as expected
      2. app blocking status card: just shows the apps selected to be blocked if rule is missed
      3. rule cards:  rule card that was confirmed goes away and rule card below *rise up* to close the gap, with the next rule card inheriting the glow and its full due/grace details as it's promoted. 
    2. If the user misses the rule and grace period:
      1. selected apps to block: apps are blocked. if user goes to the locked apps, it says that TenThirty locked the app and they first need to confirm in the app that they have completed [name of task to complete]
      2. app blocking status card: shows that the apps are locked
      3. rule cards:  rule card representing rule that is overdue should show the time to slowly flicker. if next checkpoint is reached and user still has not finished the last checkpoint, user can press and hold both missed rule card and current rule card that is due. 
    3. If the user confirms late:
      1. selected apps to block: a 10-minute cooldown starts, where user can't access locked distracting apps for 10 minutes. After the cooldown, apps unlock until the next rule or sleep window.
      2. app blocking status card: shows that the apps in cool down with a 10 minute timer counting down
      3. rule cards:  rule card that was confirmed goes away and rule card below *rise up* to close the gap, with the next rule card inheriting the glow and its full due/grace details as it's promoted. 
  4. Clear all tasks and the screen transitions to fully complete state. When this happens, 1 firefly flies from below and zooms close to screen and flies around the meadow randomly. the app blocking status card still shows up. if it's not yet the sleep window, then it still just shows the app to be blocked. if it's sleep window, then it says that the apps are locked. 
  5. During the sleep window, apps stay locked until wake time.
3. `Rule` screen shows (old screen showing screen to edit routine should be removed):
  1. user's sleep window
  2. an app blocking edit card, which shows all the blocked apps, and allows users to manage apps to be blocked
  3. all the possible rules the user can toggle on/off
4. `Trends` screen shows stats and the user's current usage trends. specifically it shows:
  1. a toggle between weekly and monthly, so if weekly is toggled then it should only show weekly stats and a grid calendar of just a week. if monthly, should show the average monthly stats and a full calendar month of grid
  2. cards that tell how many nights protected, how many days have user cleared fully, how many times a user opened an app during sleep window, how many times user confirmed late. 



## Important Activation Rule

Past rules from before onboarding should not trigger immediate app blocking.

Example:

If the user onboards at 3:50 PM and has a caffeine cutoff rule at 2:00 PM:

- Do not lock apps immediately.
- Mark the caffeine rule as `Starts tomorrow`.
- Enforce only remaining checkpoints for the rest of the day.

Suggested copy:

```text
Caffeine cutoff starts tomorrow
You joined after this checkpoint today.
```



## Tab 1: Today

`Today` is the main screen. It should behave like an action queue, not a dashboard.

The screen should always answer:

- What do I need to do next?
- When is it due?
- What apps get locked if I miss it?
- Are my apps currently locked?
- If locked, why?
- If locked, how do I unlock them?
- If cooling down, how many minutes remain?



### Default State

When no rule is currently overdue:

```text
Today
3:53 PM

Unlocked

Next rule
Warm shower or bath
Due 6:30 PM
Grace until 6:40 PM

If missed, these apps lock:
TikTok  Instagram  YouTube  Reddit

[ Hold 2 sec to confirm ]
```

The CTA must make the gesture explicit. Do not rely on hidden press-and-hold behavior.

Acceptable CTA labels:

- `Hold to confirm`
- `Hold if done`
- `Hold 2 sec to confirm`
- `Slide to confirm`

Preference: use press-and-hold unless slide is already a stronger native pattern in the app.

### Completion Interaction

When the user confirms a task:

1. The task card completes.
2. The card animates away.
3. The next task slides up.
4. The top status updates.
5. The completed task disappears from the main queue.

This should feel like clearing an inbox.

### Locked State

If the user misses a rule and the grace period expires:

```text
Apps are locked

Warm shower or bath was missed.

Locked apps:
TikTok  Instagram  YouTube  Reddit

Hold to confirm late.
After confirming, apps unlock in 10 minutes.

[ Hold to confirm late ]
```

The user should always understand:

- The apps are locked.
- Which rule caused the lock.
- Which apps are locked.
- What action starts recovery.
- The cooldown duration.



### Cooldown State

After late confirmation:

```text
Cooling down

Apps unlock in 7:42

You confirmed Warm shower or bath late.
Next rule: Dim lights at 9:15 PM
```

The blocked apps remain locked during cooldown.

After cooldown ends, apps unlock until the next rule or the sleep window.

### Sleep Window State

During the sleep window:

```text
Sleep window active

Scroll apps are locked until 4:20 AM.

No 1 AM scroll tonight.

[ Swipe up for sleep tools ]
```

During the sleep window, apps stay locked until wake time. This is different from rule-based lockouts.

### All Clear State

When all pre-sleep rules are complete:

```text
All clear

Your rules are done.
Scroll-lock starts at 8:00 PM.

[ Swipe up for sleep tools ]
```

At this point:

- A firefly appears.
- The firefly zooms in.
- The firefly flies into the meadow.

The firefly is not a large reward economy. It is a completion moment. It means:

> You cleared today’s sleep inbox.



## Swipe-Up Sleep Tools

Sleep tools should not be a normal content shelf on the main Today screen.

They should be hidden below Today and revealed intentionally by swiping up.

The user can access sleep tools when any of the following are true:

- all rules are complete,
- the sleep window is active,
- apps are locked,
- or the user intentionally swipes up.

Tools to show here are all tools found in the existing Mid-sleep mode screen.

These tools are replacement actions, not the main product.

Do not show a permanent `Useful now` shelf while a rule is pending. The current rule should own the screen.

## Tab 2: Rules

`Rules` replaces `Routine`.

This tab is where the user edits the sleep contract. user can edit rule time,
edit grace period, enable/disable a rule, edit blocked apps, edit sleep and wake time.

It should feel simple, direct, and operational. The old components related to editing the routine or adding a sleep tactic should be shelved or gone. 

Example structure:

```text
Rules

Sleep window
8:00 PM - 4:20 AM
Apps always lock during this window.
[ Edit ]

Blocked apps
TikTok, Instagram, YouTube, Reddit
[ Edit apps ]

Daily rules

Caffeine cutoff
2:00 PM
Confirm you are done with caffeine for the day.
Grace: 15 min

Workout cutoff
5:00 PM
Confirm you are done with workouts for the day.
Grace: 30 min

Warm shower or bath
6:30 PM
Grace: 10 min

Dim lights
9:15 PM
Grace: 10 min

Phone away
10:15 PM
Grace: 5 min

Gratitude journal
10:20 PM
Grace: 10 min

Tomorrow’s plan
10:25 PM
Grace: 10 min
```

Rules tab should allow users to:

- edit sleep window,
- edit wake time,
- edit blocked apps,
- edit each rule time,
- edit each rule grace period,
- enable or disable a rule.

Include a plain explanation of enforcement:

```text
How enforcement works

Miss a rule -> apps lock.
Confirm late -> 10-minute cooldown.
Sleep window -> apps stay locked until wake time.
```

Avoid browsing-style content, stories, rewards, or editorial sleep education in this tab.

## Tab 3: Trends

`Trends` is the proof loop.

It should prove that TenThirty protected the user from bedtime scrolling and helped them follow their contract. 

structure:

```text
Trends

This week

5 nights protected
3 all-clear days
14 late-night opens blocked
2 late confirmations
```

then below it should show the existing alendar view and fireflies flying into the calendar cells should remain in this screen

Rule-level insights:

```text
Best rule
Dim lights
Completed on time 5 of 7 days

Needs work
Tomorrow's plan
Missed 3 times

Sleep window
No scroll apps opened during sleep window
5 of 7 nights
```

Use `all-clear days` instead of `perfect days`. 

Avoid copy that creates shame or moral failure. The product already has consequence through locking.

## Fireflies

Keep fireflies, but do not make them the main reward system.

Do not build a large points economy.

Recommended firefly meaning:

```text
Firefly earned
You cleared today’s sleep inbox.
```

In Trends:

```text
Fireflies
2 earned this week

Earn 1 when you clear all rules before sleep and do not open blocked apps during your sleep window.
```

Fireflies should create a quiet sense of completion and warmth. The main enforcement mechanism is still app blocking.

## Tone

The product should feel:

- firm,
- calm,
- clear,
- non-shaming,
- protective,
- minimal.

Avoid:

- cute gamification as the main product,
- hidden gestures,
- vague wellness copy,
- moralizing language,
- large content shelves,
- routine-first framing,
- punishment imagery.

Use language like:

- `All clear`
- `Apps are locked`
- `Cooling down`
- `Next rule`
- `Hold to confirm`
- `Sleep window active`
- `No 1 AM scroll tonight`

Avoid language like:

- `Perfect day`
- `You failed`
- `Punishment`
- `Customize my routine`
- `Maybe later`
- `Skip`



## Product Summary

The post-onboarding app should feel like this:

1. Open Today.
2. See the rules to complete
3. See the apps that will lock if the rule is missed.
4. Hold to confirm rule when done.
5. Watch the task clear and the next task slide up.
6. If all tasks are cleared, see the firefly completion moment.
7. Swipe up only when the user wants sleep tools.
8. Use Rules to edit the contract.
9. Use Trends to prove whether the contract worked.

The main job of the interface is to make sleep enforcement understandable, recoverable, and hard to ignore.