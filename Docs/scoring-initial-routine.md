You are an expert Swift developer building the core intelligence for **Lull**, a sleep coaching app.

### Overall Philosophy
- "Gentle Reset" on night 1: respect existing habits, start small, be encouraging.
- The app should feel like a smart personal sleep scientist.
- Screen 4 (current bedtime habits) has **2x weight** because it's the strongest signal.
- each onboarding question has associated remedies with them, and @/Users/czarinacatambing/lull-sleep-app/Docs/sleep-remedies-onboarding.csv shows what remedies (in comma separated list) are mapped to each onboarding question
can y
### PART 1: Initial Routine Generation (after onboarding)

Use this exact logic:

1. **Scoring Remedies**
   - For every selected onboarding answer, add +1 to its associated remedies (from the mapping table).
   - If the answer is from **Screen 4**, add **+2** instead.
   - Give **"Dim the lights"** an extra permanent +3 boost.
   - For up to 2 kept existing habits (from Screen 4), give them +2 boost each.

2. **Build the Routine**
   - Keep up to 2 of the user's existing habits.
   - Add the highest-scoring remedies.
   - Always include: Brightness Check + Temperature Log as the first two steps of Wind Down.
   - Separate into two sections:
     - **Bedtime Prep** (passive / >45 min before bed)
     - **Wind Down Ritual** (interactive / sequential)
   - Limit Wind Down Ritual to max 4 steps total.
   - Within each section, sort from **Easiest to Hardest** to adopt.

3. **Output**
   - A `Routine` object with `bedtimePrep: [RoutineStep]` and `windDown: [RoutineStep]`
   - A friendly `explanation` string for the success screen (e.g. "We kept your warm shower, added Brain Dump because your mind races...")


#### **Scoring Example**

**User selects:**
- Screen 1: “My brain races or overthinks”
- Screen 2: “High-stress job”
- Screen 4: “Use my phone or scroll” (2x weight)

**Point Calculation:**

| Remedy              | Screen 1 | Screen 2 | Screen 4 (2x) | Dim Boost | Kept Habit | **Total** |
|---------------------|----------|----------|---------------|-----------|------------|-----------|
| Dim the lights      | +1       | +1       | +2            | +3        | -          | **7**     |
| Brain Dump          | +1       | +1       | +2            | -         | -          | **4**     |
| No screens          | +1       | -        | +2            | -         | -          | **3**     |
| 4-7-8 Breathing     | +1       | +1       | -             | -         | -          | **2**     |

→ Top remedies chosen: **Dim the lights** + **Brain Dump**



### PART 2: Next Variable Suggestion (after 5-night experiments)

Use this logic:

1. **Calculate total score for every possible remedy**:
   - **Historical Performance** (70% weight): Use the average sleep score improvement when that remedy was previously tested.
   - **Onboarding Match** (20% weight): Same scoring as initial routine (Screen 4 = 2x).
   - **Smart Adjustments**:
     - Boost "Dim the lights" and "Cold room prep"
     - Heavy penalty (-10) for remedies already in Core Routine or currently being tested
     - Bonus for Bedtime Prep remedies in the first ~15 nights

2. Pick the remedy with the **highest total score** as the next suggestion.

3. Show it with:
   - Clear recommendation
   - Short reason ("Users like you saw strong improvement...")
   - Buttons: "Try this for 5 nights" + "Pick something else"

---

Please implement this as clean, well-commented Swift code with proper models (`OnboardingAnswers`, `Routine`, `RoutineStep`, `ImprovementEngine`, etc.).

Include:
- The remedy mapping table as a data structure
- Example outputs for 2-3 different user profiles
- The `generateStartingRoutine()` and `suggestNextVariable()` functions

Start by defining the models and mapping, then implement the logic.

Let's build this.

