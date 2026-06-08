# Body Scan — Voice-Over Script & Cue Sheet

Narration script and animation cues for the static body-scan guided-relaxation
audio, structured to mirror the existing **4·7·8 breathing** track
(`478-breathing-revised.mp3`).

> **Cues below are derived from a Whisper word-level transcription of the actual
> recording** (`body-scan-[AudioTrimmer.com].mp3`, 289.3s) — same method as
> `BreathCue.all`. They are real timestamps, not planned targets. The recorded
> read matches the script text verbatim.

## Audio facts

- **Total runtime: 289.3s (≈4:49)** — set `totalDuration = 289` in the view.
- Settling intro runs to ~1:11 before the first body region (breathing track's intro runs to ~1:32).
- 6 body regions, foot-to-head, each an `arrive → soften → release → rest` arc
  (parallel to the breathing `inhale → hold → exhale → rest`), then a whole-body
  release and a "let go" wind-down at ~4:31.

## Target delivery (for any future re-record)

- Slow bedtime narration, ~75–90 wpm (same as the boring-story pack).
- Warm, low, unhurried. No music swells or escalation; a soft ambient bed is fine.
- Gentle pause at every `…`, longer hold at each `[pause Ns]`.
- Export as `m4a` or `mp3`.

---

## Cue sheet (Swift-ready)

Phase enum parallel to `AudioBreathPhase`:

```swift
private enum AudioBodyScanPhase: Equatable {
    case intro, arrive, soften, release, rest, windDown

    var label: String {
        switch self {
        case .intro:    return "Listen and settle"
        case .arrive:   return "Notice this part"
        case .soften:   return "Soften"
        case .release:  return "Let it sink"
        case .rest:     return "Rest"
        case .windDown: return "Let go"
        }
    }
}
```

Cue array — same shape as `BreathCue.all`. `region` is 0 between regions /
during intro & wind-down:

```swift
private struct BodyScanCue {
    let time: Double
    let phase: AudioBodyScanPhase
    let region: Int

    // Derived from Whisper word-level transcription of body-scan recording (289.3s).
    static let all: [BodyScanCue] = [
        // Intro — settling, no region (0:00–1:11)
        .init(time:   0.0,  phase: .intro,    region: 0),
        // Region 1 — feet & legs
        .init(time:  71.0,  phase: .arrive,   region: 1),
        .init(time:  80.1,  phase: .soften,   region: 1),
        .init(time:  90.0,  phase: .release,  region: 1),
        .init(time: 107.2,  phase: .rest,     region: 0),
        // Region 2 — hips & belly
        .init(time: 108.2,  phase: .arrive,   region: 2),
        .init(time: 118.0,  phase: .soften,   region: 2),
        .init(time: 125.2,  phase: .release,  region: 2),
        .init(time: 136.7,  phase: .rest,     region: 0),
        // Region 3 — back
        .init(time: 138.2,  phase: .arrive,   region: 3),
        .init(time: 149.5,  phase: .soften,   region: 3),
        .init(time: 154.7,  phase: .release,  region: 3),
        .init(time: 162.9,  phase: .rest,     region: 0),
        // Region 4 — hands & arms
        .init(time: 165.0,  phase: .arrive,   region: 4),
        .init(time: 171.7,  phase: .soften,   region: 4),
        .init(time: 178.6,  phase: .release,  region: 4),
        .init(time: 191.3,  phase: .rest,     region: 0),
        // Region 5 — shoulders & neck
        .init(time: 193.2,  phase: .arrive,   region: 5),
        .init(time: 198.9,  phase: .soften,   region: 5),
        .init(time: 204.5,  phase: .release,  region: 5),
        .init(time: 212.1,  phase: .rest,     region: 0),
        // Region 6 — face & head
        .init(time: 215.0,  phase: .arrive,   region: 6),
        .init(time: 219.7,  phase: .soften,   region: 6),
        .init(time: 230.2,  phase: .release,  region: 6),
        .init(time: 242.8,  phase: .rest,     region: 0),
        // Whole-body release + wind-down
        .init(time: 244.6,  phase: .release,  region: 0),
        .init(time: 270.8,  phase: .windDown, region: 0),
    ]
}
```

> **Orb animation:** the breathing view scales an amber orb with the breath
> (`orbTarget` 1.18 inhale / 0.82 exhale). A body scan isn't breath-paced, so the
> orb mapping is a design decision, not dictated by the audio. A gentle "settling"
> feel: `arrive` ≈ 1.05, `soften` ≈ 0.95, `release` ≈ 0.85 (sinking), `rest`/
> `intro`/`windDown` ≈ 1.0. Tune to taste.

---

## Spoken script (timestamps match the recording)

### Intro · settling (0:00 → 1:11)

**[0:00]** Welcome… there's nothing to do here but listen.

**[0:05]** Let your body settle into whatever it's resting on… the bed taking your
full weight. You don't have to hold yourself up anymore. [pause 2s]

**[0:17]** If your eyes are still open, let them close now… and let your breathing
fall into its own slow rhythm. Nothing forced. Just the breath that's already there.

**[0:33]** In a moment we'll move slowly through the body, one part at a time…
simply noticing each place, and letting it grow a little heavier as we go.

**[0:46]** There's no right way to feel this. Wherever your attention drifts, that's
fine — you'll just gently bring it back to the sound of my voice.

**[0:59]** Take one slow breath in through the nose… and let it go with a soft sigh.
Good. We'll begin at the feet.

---

### Region 1 · feet & legs (1:11 → 1:48)

**[1:11 · arrive]** Bring your attention all the way down to your feet… the soles,
the heels, the spaces between your toes.

**[1:20 · soften]** Notice any holding there, any small tension… and let it soften.
There's nothing for your feet to do now.

**[1:30 · release]** Let that heaviness rise up through your ankles… into your
calves… your knees… and the long muscles of your thighs. The whole of both legs
growing warm and heavy…

**[1:47 · rest]** …and rest.

---

### Region 2 · hips & belly (1:48 → 2:18)

**[1:48 · arrive]** Let your attention float up to your hips… and the base of your
spine where it meets the bed.

**[1:58 · soften]** Feel that part of you settle and spread, a little wider, a little
looser…

**[2:05 · release]** …and let your belly soften completely… rising and falling on
its own, with no effort from you at all.

**[2:17 · rest]** Rest here.

---

### Region 3 · back (2:18 → 2:45)

**[2:18 · arrive]** Now, bring a gentle awareness to your back… from the base of your
spine, all the way up between the shoulder blades.

**[2:30 · soften]** Let it lengthen and release into the surface beneath you.

**[2:35 · release]** Each small muscle along the spine, letting go… one by one…
nothing left to carry…

**[2:43 · rest]** …and rest. Rest.

---

### Region 4 · hands & arms (2:45 → 3:13)

**[2:45 · arrive]** Bring your attention out to your hands… your fingers, your palms.

**[2:52 · soften]** Let the fingers uncurl, just slightly, and grow soft and warm.

**[2:59 · release]** Feel that release travel up through your wrists… your forearms…
your upper arms… the whole length of both arms, heavy and still.

**[3:11 · rest]** Rest.

---

### Region 5 · shoulders & neck (3:13 → 3:35)

**[3:13 · arrive]** Now your shoulders — the place we carry so much without noticing.

**[3:19 · soften]** Let them drop, away from your ears, down toward the bed.

**[3:25 · release]** And let the back of your neck go soft and long… releasing every
last bit of holding there…

**[3:32 · rest]** …and rest.

---

### Region 6 · face & head (3:35 → 4:05)

**[3:35 · arrive]** Finally, bring a soft awareness to your face.

**[3:40 · soften]** Let your jaw unclench… your lips part, just a little… the space
between your eyebrows smooth out.

**[3:50 · release]** Let your whole face grow still and heavy… the small muscles
around your eyes letting go… your scalp softening across the top of your head.

**[4:03 · rest]** Rest here.

---

### Whole-body release + wind-down (4:05 → 4:49)

**[4:05 · release]** And now, just for a moment, sense the whole body at once… feet,
legs, hips, back, arms, shoulders, face… all of it heavy, all of it held by the bed
beneath you.

**[4:25]** There's nothing left to do, nowhere to be. You've arrived at the end of
the day.

**[4:31 · wind-down]** From here, you can simply let the voice fade… and let yourself
drift. Let each breath carry you a little further down… softer… and slower.

**[4:48]** Good night. [audio ends ~4:49]
