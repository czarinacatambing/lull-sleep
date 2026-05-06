# Routine Output Examples

Traces the exact output of `generateStartingRoutine()` for different onboarding answer combinations. Use this to verify the scoring engine is working correctly.

---

## Rules quick-reference

### Scoring (`scoreRemedies`)
| Source | Weight |
|--------|--------|
| Screen 1 (sleep problems) selection | +1 per mapped remedy |
| Screen 2 (waking factors / situation) selection | +1 per mapped remedy |
| Screen 5 (pre-bed activities) selection | +2 per mapped remedy |
| "Dim the lights" — universal boost | always +3 |
| Positive kept habits: book (idx 2), dim lights (idx 4), shower (idx 5) | +2 per habit, max 2 habits |

### Bedtime Prep (`buildInitialPrepSteps`)
1. "Dim the lights" is always in slot 1 (it always scores ≥ 3).
2. Find the single highest-scoring item from the remaining Bedtime Prep remedies, excluding App Blocking entirely.
3. Sort by lead time descending so the earliest reminder shows first.

**Result: max 2 Bedtime Prep items. App Blocking never appears in the initial routine.**

### Wind Down (`buildInitialWindDownSteps`)
1. Always start: Brightness check + Temperature check.
2. `windDownKeptHabits` = kept habit labels that are also in `allWindDownRemedies`. Only **Reading (physical book)** qualifies — Warm shower and Dim the lights are Bedtime Prep remedies, not Wind Down.
3. Add `windDownKeptHabits` as existing-habit steps (up to 2).
4. **If** `windDownKeptHabits` is empty **AND** at least one Wind Down remedy scored > 0 → add exactly **one** new method (highest score; easiest difficulty on a tie).
5. A new method is **never** added when the user already has a Wind Down habit.

**Result: 2–4 steps total. At most 1 new method.**

### Wind Down difficulty rank (used for tie-breaking, lower = easier = preferred)
| Method | Rank |
|--------|------|
| Boring story | 1 |
| Reading (physical book) | 2 |
| Gratitude journal | 3 |
| Brain dump | 4 |
| Gentle stretching | 5 |
| 4-7-8 Breathing | 6 |
| Progressive Muscle Relaxation | 7 |

---

## Profile 1 — The Anxious Founder

**Situation:** Mind races at night from work stress. Scrolls phone before bed.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Brain races (index 1) |
| Screen 2 | Founder / high-stress (index 2) |
| Screen 5 | Phone / scroll (index 0) |

### Scoring

| Remedy | S1 idx 1 | S2 idx 2 | S5 idx 0 | Always | Kept habit | **Total** |
|--------|----------|----------|----------|--------|------------|-----------|
| Dim the lights | +1 | +1 | +2 | +3 | — | **7** |
| Brain dump | +1 | +1 | +2 | — | — | **4** |
| No screens | +1 | +1 | +2 | — | — | **4** |
| App blocking | — | — | +2 | — | — | **2** |
| 4-7-8 breathing | +1 | +1 | — | — | — | **2** |
| PMR | +1 | +1 | — | — | — | **2** |
| Gratitude journal | +1 | — | — | — | — | **1** |
| Boring story | +1 | — | — | — | — | **1** |

S5 index 0 (phone/scroll) is not in `keptHabitMap` → `keptHabitLabels = []`

### Generated routine

**Bedtime Prep**

| Step | Lead time | Why selected |
|------|-----------|-------------|
| Dim the lights | 75 min before bed | Always included |
| No screens | 75 min before bed | Score 4 — highest additional scorer |

App Blocking scored 2 but is excluded from the initial routine.

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Brain dump | New method — score 4, highest Wind Down candidate |

No kept habits → new method slot opens. Brain dump (4) beats 4-7-8 (2) by score; beats PMR (also 2) by difficulty rank.

**Explanation:**
> We kept things super simple for your first few nights. We added one thing: a quick Brain Dump. Two minutes to empty your head before you close your eyes. Dim the lights 75 min before bed — it tells your brain the day is ending. Put screens away 75 min before bed. Blue light delays melatonin by up to 30 minutes. Once this feels easy, we'll layer in more.

---

## Profile 2 — The New Parent

**Situation:** Exhausted new parent who struggles to fall asleep. Snacks before bed.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Struggle to fall asleep (index 0) |
| Screen 2 | New parent (index 0) |
| Screen 5 | Eat / snack (index 7) |

### Scoring

| Remedy | S1 idx 0 | S2 idx 0 | S5 idx 7 | Always | Kept habit | **Total** |
|--------|----------|----------|----------|--------|------------|-----------|
| Dim the lights | +1 | +1 | — | +3 | — | **5** |
| Herbal tea | — | +1 | +2 | — | — | **3** |
| Brain dump | +1 | +1 | — | — | — | **2** |
| 4-7-8 breathing | +1 | +1 | — | — | — | **2** |
| Warm shower | +1 | +1 | — | — | — | **2** |
| No heavy snacks | — | — | +2 | — | — | **2** |
| Gentle stretching | — | +1 | — | — | — | **1** |
| No screens | +1 | — | — | — | — | **1** |
| Boring story | +1 | — | — | — | — | **1** |

S5 index 7 (eating) is not in `keptHabitMap` → `keptHabitLabels = []`

### Generated routine

**Bedtime Prep**

| Step | Lead time | Why selected |
|------|-----------|-------------|
| Dim the lights | 75 min before bed | Always included |
| Herbal tea | 45 min before bed | Score 3 — highest additional scorer |

No heavy snacks (score 2) and Warm shower (score 2) were both outscored by Herbal tea (score 3).

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Brain dump | New method — score 2, wins tie-break over 4-7-8 (rank 4 < rank 6) |

**Explanation:**
> We kept things super simple for your first few nights. We added one thing: a quick Brain Dump. Two minutes to empty your head before you close your eyes. Dim the lights 75 min before bed — it tells your brain the day is ending. Herbal tea 45 min before bed — the ritual and mild calming effects both help signal wind-down. Once this feels easy, we'll layer in more.

---

## Profile 3 — The Shift Worker

**Situation:** Works irregular hours, wakes at night and unrefreshed. Watches TV and eats late before bed.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Wakes at night (index 2), Wakes unrefreshed (index 3) |
| Screen 2 | Shift work (index 1) |
| Screen 5 | Watch TV / screens (index 1), Eat / snack (index 7) |

### Scoring

| Remedy | S1 idx 2 | S1 idx 3 | S2 idx 1 | S5 idx 1 | S5 idx 7 | Always | Kept habit | **Total** |
|--------|----------|----------|----------|----------|----------|--------|------------|-----------|
| Dim the lights | — | — | +1 | +2 | — | +3 | — | **6** |
| Cold room prep | +1 | +1 | +1 | — | — | — | — | **3** |
| Herbal tea | +1 | — | — | — | +2 | — | — | **3** |
| Boring story | — | — | +1 | +2 | — | — | — | **3** |
| No screens | — | — | — | +2 | — | — | — | **2** |
| Reading (physical book) | — | — | — | +2 | — | — | — | **2** |
| App blocking | — | — | — | +2 | — | — | — | **2** |
| No heavy snacks | — | — | — | — | +2 | — | — | **2** |
| Weighted blanket | +1 | +1 | — | — | — | — | — | **2** |
| Magnesium glycinate | — | +1 | +1 | — | — | — | — | **2** |
| 4-7-8 breathing | +1 | — | — | — | — | — | — | **1** |
| Brain dump | +1 | — | — | — | — | — | — | **1** |
| No caffeine | — | — | +1 | — | — | — | — | **1** |
| Warm shower | — | +1 | — | — | — | — | — | **1** |

S5 indices 1 and 7 are not in `keptHabitMap` (only 2, 4, 5 are) → `keptHabitLabels = []`

### Generated routine

**Bedtime Prep**

| Step | Lead time | Why selected |
|------|-----------|-------------|
| Cold room prep | 90 min before bed | Score 3 — highest additional scorer (tied with Herbal tea at score 3; result is implementation-dependent) |
| Dim the lights | 75 min before bed | Always included |

Cold room prep and Herbal tea both score 3. The tie is broken by `Array(remedyLeadTimes.keys)` order which is non-deterministic in Swift. Either could appear here. The important constraint — only 2 total Bedtime Prep items — is always respected.

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Boring story | New method — score 3, wins outright (Reading book scores 2) |

10 Bedtime Prep remedies scored for this user. Only 2 are shown. Everything else is saved for experiments.

**Explanation:**
> We kept things super simple for your first few nights. We added one thing: a Boring Story. It gives your mind something mild to follow instead of looping on the day. Cool your room 90 min before bed — a drop in core temperature is a key trigger for sleep onset. Dim the lights 75 min before bed — it tells your brain the day is ending. Once this feels easy, we'll layer in more.

---

## Profile 4 — Physical Discomfort + Evening Exercise

**Situation:** Body aches keep sleep quality low. Exercises in the evening and showers before bed — a positive existing habit.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Wakes unrefreshed (index 3) |
| Screen 2 | Physical discomfort (index 5) |
| Screen 5 | Shower or bath (index 5), Evening exercise (index 6) |

### Scoring

| Remedy | S1 idx 3 | S2 idx 5 | S5 idx 5 | S5 idx 6 | Always | Kept habit | **Total** |
|--------|----------|----------|----------|----------|--------|------------|-----------|
| Warm shower | +1 | +1 | +2 | — | — | +2 | **6** |
| Dim the lights | — | — | — | — | +3 | — | **3** |
| Cold room prep | +1 | +1 | — | — | — | — | **2** |
| Weighted blanket | +1 | +1 | — | — | — | — | **2** |
| Finish workouts | — | — | — | +2 | — | — | **2** |
| Magnesium glycinate | +1 | — | — | — | — | — | **1** |
| Gentle stretching | — | +1 | — | — | — | — | **1** |
| PMR | — | +1 | — | — | — | — | **1** |

S5 index 5 (shower) → `keptHabitMap[5] = warmShower` → `keptHabitLabels = [warmShower]` → kept habit bonus: warmShower +2.
S5 index 6 (exercise) is not in `keptHabitMap` → no extra points.

### Generated routine

**Bedtime Prep**

| Step | Lead time | Why selected |
|------|-----------|-------------|
| Warm shower | 90 min before bed | Score 6 — highest additional scorer by a wide margin |
| Dim the lights | 75 min before bed | Always included |

Warm shower also appears in `keptHabitLabels`, so the explanation acknowledges it as an existing habit AND as a timed reminder.

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Gentle stretching | New method — score 1, wins tie-break over PMR (rank 5 < rank 7) |

`windDownKeptHabits` is **empty**: Warm shower is a Bedtime Prep remedy, not in `allWindDownRemedies`, so it does not qualify as a Wind Down kept habit. The new-method rule applies. Gentle stretching beats PMR on difficulty rank.

**Explanation:**
> We kept things super simple for your first few nights. You already shower before bed — the temperature drop afterward is a genuine sleep trigger. We added one thing: a short stretch. A few minutes to release physical tension before you lie down. Warm shower 90 min before bed — the post-shower temperature drop helps trigger sleep. Dim the lights 75 min before bed — it tells your brain the day is ending. Once this feels easy, we'll layer in more.

*Note: The shower appears twice in the explanation — once as an acknowledged positive habit, once as a timed Bedtime Prep reminder — because it is in both `keptHabitLabels` and `prepSteps`.*

---

## Profile 5 — The Good-Habit Sleeper

**Situation:** Already reads a physical book and dims the lights before bed. Occasionally struggles to fall asleep.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Struggle to fall asleep (index 0) |
| Screen 2 | *(none)* |
| Screen 5 | Read physical book (index 2), Dim the lights (index 4) |

### Scoring

| Remedy | S1 idx 0 | S5 idx 2 | S5 idx 4 | Always | Kept habit | **Total** |
|--------|----------|----------|----------|--------|------------|-----------|
| Dim the lights | +1 | — | +2 | +3 | +2 | **8** |
| Reading (physical book) | — | +2 | — | — | +2 | **4** |
| Brain dump | +1 | — | — | — | — | **1** |
| 4-7-8 breathing | +1 | — | — | — | — | **1** |
| Boring story | +1 | — | — | — | — | **1** |
| No screens | +1 | — | — | — | — | **1** |
| Warm shower | +1 | — | — | — | — | **1** |

S5 indices sorted: [2, 4] → `keptHabitMap[2] = readingBook`, `keptHabitMap[4] = dimTheLights` → `keptHabitLabels = [readingBook, dimTheLights]`.
Kept habit bonuses: readingBook +2, dimTheLights +2.

### Generated routine

**Bedtime Prep**

| Step | Lead time | Why selected |
|------|-----------|-------------|
| Warm shower | 90 min before bed | Score 1 — ties with No screens (1), but warm shower has longer lead time (90 vs 75 min). Result is implementation-dependent on a true score tie. |
| Dim the lights | 75 min before bed | Always included |

*No screens (score 1, 75 min) is also a candidate. On a score tie, `max(by:)` is non-deterministic based on dictionary key order. Either could appear here.*

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Reading (physical book) | Existing kept habit — score 4 |

`windDownKeptHabits = [readingBook]` — Reading is the only item in both `keptHabitLabels` and `allWindDownRemedies`. Dim the lights is in `keptHabitLabels` but not in `allWindDownRemedies`, so it doesn't add a Wind Down step. Since `windDownKeptHabits` is non-empty, no new method is added.

**Explanation:**
> We kept things super simple for your first few nights. You already read before bed — that's one of the best things you can do, so we kept it in. You already dim the lights before bed. That's already working for you. Warm shower 90 min before bed — the post-shower temperature drop helps trigger sleep. Dim the lights 75 min before bed — it tells your brain the day is ending. Once this feels easy, we'll layer in more.

---

## Edge Case — "I don't really have a routine" (Nothing Specific)

**Situation:** Struggles to fall asleep. Doesn't really have a pre-bed routine.

| Screen | Selections |
|--------|-----------|
| Screen 1 | Struggle to fall asleep (index 0) |
| Screen 2 | *(none)* |
| Screen 5 | Nothing specific (index 8) |

### Scoring

| Remedy | S1 idx 0 | S5 idx 8 | Always | **Total** |
|--------|----------|----------|--------|-----------|
| Dim the lights | +1 | +2 | +3 | **6** |
| Brain dump | +1 | +2 | — | **3** |
| 4-7-8 breathing | +1 | +2 | — | **3** |
| Boring story | +1 | +2 | — | **3** |
| No screens | +1 | — | — | **1** |
| Warm shower | +1 | — | — | **1** |

S5 index 8 is not in `keptHabitMap` → `keptHabitLabels = []`

### Generated routine

**Bedtime Prep**

| Step | Lead time |
|------|-----------|
| Warm shower | 90 min before bed (ties with No screens at score 1; warm shower wins on lead time) |
| Dim the lights | 75 min before bed |

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |
| Boring story | New method — score 3, wins on difficulty rank (rank 1) over Brain dump (rank 4) and 4-7-8 (rank 6) |

All three Wind Down candidates tie at score 3. Boring story wins as the easiest option — a good choice for someone with no existing routine.

**Explanation:**
> We kept things super simple for your first few nights. We added one thing: a Boring Story. It gives your mind something mild to follow instead of looping on the day. Warm shower 90 min before bed — the post-shower temperature drop helps trigger sleep. Dim the lights 75 min before bed — it tells your brain the day is ending. Once this feels easy, we'll layer in more.

---

## Edge Case — Minimal / Unscorable Answers

**Situation:** User answers every screen but selects only "Talk or socialize" on Screen 5 — which has no remedy mapping.

| Screen | Selections |
|--------|-----------|
| Screen 1 | *(none)* |
| Screen 2 | *(none)* |
| Screen 5 | Talk or socialize (index 3) |

### Scoring

| Remedy | Always | **Total** |
|--------|--------|-----------|
| Dim the lights | +3 | **3** |

Index 3 on Screen 5 has no CSV mapping. Nothing else scores.

### Generated routine

**Bedtime Prep**

| Step | Lead time |
|------|-----------|
| Dim the lights | 75 min before bed |

*(No second item — nothing else scored.)*

**Wind Down**

| Step | Type |
|------|------|
| Brightness check | Fixed |
| Temperature check | Fixed |

`hasSignal = false` (no Wind Down remedy scored) → no new method added.

This is the shortest possible initial routine. The user will be offered an experiment variable immediately from the Bedtime Prep pool, so they still have something to test from night 1.
