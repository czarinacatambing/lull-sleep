import Foundation

// Stable enum identity for every remedy — survives display-string renames.
// The raw String value is the JSON key; never change a case's raw value.
enum RemedyID: String, Codable, CaseIterable {
    // Bedtime Prep
    case dimTheLights
    case noScreens
    // Legacy decode support only. New generated routines use noScreens with
    // RoutineStep.enforcementMode instead of a standalone appBlocking remedy.
    case appBlocking
    case finishWorkouts
    case noHeavySnacks
    case noAlcohol
    case noCaffeine
    case coldRoomPrep
    case warmShower
    case magnesium
    case herbalTea
    case weightedBlanket
    case blackoutCurtains

    // Wind Down interactive
    case brainDump
    case boringStory
    case sleepSounds
    case breathing478
    case gratitudeJournal
    case gentleStretching
    case progressiveMuscleRelaxation
    case bodyScan
    case readingBook

    // Maps an R-constant display label to a stable RemedyID.
    // Returns nil for labels with no canonical ID (e.g. "Brightness check").
    static func fromLabel(_ label: String) -> RemedyID? {
        switch label {
        case R.dimTheLights:     return .dimTheLights
        case R.noScreens:        return .noScreens
        case R.appBlocking:      return .appBlocking
        case R.finishWorkouts:   return .finishWorkouts
        case R.noHeavySnacks:    return .noHeavySnacks
        case R.noAlcohol:        return .noAlcohol
        case R.noCaffeine:       return .noCaffeine
        case R.coldRoomPrep:     return .coldRoomPrep
        case R.warmShower:       return .warmShower
        case R.magnesium:        return .magnesium
        case R.herbalTea:        return .herbalTea
        case R.weightedBlanket:  return .weightedBlanket
        case R.blackoutCurtains: return .blackoutCurtains
        case R.brainDump:        return .brainDump
        case R.boringStory:      return .boringStory
        case R.sleepSounds:      return .sleepSounds
        case R.breathing478:     return .breathing478
        case R.gratitudeJournal: return .gratitudeJournal
        case R.gentleStretching: return .gentleStretching
        case R.pmr:              return .progressiveMuscleRelaxation
        case R.bodyScan:         return .bodyScan
        case R.readingBook:      return .readingBook
        default:                 return nil
        }
    }
}

// MARK: - Per-remedy impact & science data

struct RemedyImpact {
    let prefix: String      // "Users like you fell asleep "
    let highlight: String   // "−11 min"
    let suffix: String      // " faster."
    let science: String     // 2–3 sentence explanation
}

extension RemedyID {
    static var allCases: [RemedyID] {
        [
            .dimTheLights,
            .noScreens,
            .finishWorkouts,
            .noHeavySnacks,
            .noAlcohol,
            .noCaffeine,
            .coldRoomPrep,
            .warmShower,
            .magnesium,
            .herbalTea,
            .weightedBlanket,
            .blackoutCurtains,
            .brainDump,
            .boringStory,
            .sleepSounds,
            .breathing478,
            .gratitudeJournal,
            .gentleStretching,
            .progressiveMuscleRelaxation,
            .bodyScan,
            .readingBook,
        ]
    }

    var routineCategory: RoutineCategory {
        switch self {
        case .dimTheLights,
             .noScreens,
             .appBlocking,
             .finishWorkouts,
             .noHeavySnacks,
             .noAlcohol,
             .noCaffeine,
             .coldRoomPrep,
             .warmShower,
             .magnesium,
             .herbalTea,
             .weightedBlanket,
             .blackoutCurtains:
            return .bedtimePrep
        case .brainDump,
             .boringStory,
             .sleepSounds,
             .breathing478,
             .gratitudeJournal,
             .gentleStretching,
             .progressiveMuscleRelaxation,
             .bodyScan,
             .readingBook:
            return .windDown
        }
    }

    var impact: RemedyImpact {
        switch self {
        case .dimTheLights:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−10 min",
                suffix: " faster.",
                science: "Bright light suppresses melatonin. Dimming lights 60–90 min before bed triggers earlier melatonin onset, helping your brain recognize it's time to wind down."
            )
        case .noScreens:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−12 min",
                suffix: " faster.",
                science: "Blue light from screens delays melatonin release by up to 3 hours and raises alertness. Cutting screens 30–60 min before bed measurably accelerates sleep onset."
            )
        case .appBlocking:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−9 min",
                suffix: " faster.",
                science: "Variable-reward apps keep the brain in an alert, dopamine-seeking state. Blocking them removes the cognitive arousal that delays the transition to sleep."
            )
        case .finishWorkouts:
            return RemedyImpact(
                prefix: "Sleep quality improved ",
                highlight: "+8%",
                suffix: " on average.",
                science: "Vigorous exercise raises core body temperature and cortisol, both of which inhibit sleep. Finishing workouts 3+ hours before bed gives your body time to cool down and normalize."
            )
        case .noHeavySnacks:
            return RemedyImpact(
                prefix: "Users like you woke up ",
                highlight: "1.4× less",
                suffix: " often.",
                science: "Large meals activate the digestive system and raise core body temperature, disrupting sleep architecture. A lighter stomach supports deeper, more consolidated sleep."
            )
        case .noAlcohol:
            return RemedyImpact(
                prefix: "Sleep quality improved ",
                highlight: "+15%",
                suffix: " on average.",
                science: "Alcohol fragments sleep in the second half of the night by suppressing REM and increasing awakenings. Even moderate amounts measurably degrade sleep architecture."
            )
        case .noCaffeine:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−14 min",
                suffix: " faster.",
                science: "Caffeine blocks adenosine receptors — the brain's sleep-pressure signal — with a half-life of 5–7 hours. Cutting off 6+ hours before bed prevents it from delaying sleep onset."
            )
        case .coldRoomPrep:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−9 min",
                suffix: " faster.",
                science: "A drop in core body temperature is one of the primary triggers for sleep onset. A room around 65–68°F (18–20°C) helps your body thermoregulate into sleep more quickly."
            )
        case .warmShower:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−10 min",
                suffix: " faster.",
                science: "A warm shower 1–2 hours before bed draws blood to the skin's surface. As you step out, rapid heat loss accelerates the core temperature drop that signals sleep onset."
            )
        case .magnesium:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−13 min",
                suffix: " faster.",
                science: "Magnesium glycinate supports GABA — your brain's primary inhibitory neurotransmitter — and helps regulate melatonin. Multiple trials show it reduces sleep onset time and improves sleep quality."
            )
        case .herbalTea:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−8 min",
                suffix: " faster.",
                science: "Chamomile contains apigenin, which binds GABA receptors and has mild sedative effects. Valerian root is linked to reduced sleep onset in several trials. The ritual itself also reinforces wind-down."
            )
        case .weightedBlanket:
            return RemedyImpact(
                prefix: "Sleep quality improved ",
                highlight: "+10%",
                suffix: " on average.",
                science: "Deep pressure stimulation activates the parasympathetic nervous system, reducing cortisol and boosting serotonin. Studies show it lowers physiological arousal and subjective anxiety before sleep."
            )
        case .blackoutCurtains:
            return RemedyImpact(
                prefix: "Users like you woke up ",
                highlight: "less often",
                suffix: " from light.",
                science: "Reducing overnight and early-morning light helps protect melatonin and keeps the sleep environment stable. Blackout curtains are a low-effort environmental support for people sensitive to light."
            )
        case .brainDump:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−9 min",
                suffix: " faster.",
                science: "Pre-sleep rumination — replaying the day or worrying about tomorrow — is a top cause of delayed sleep onset. Writing tasks and concerns down offloads them from working memory, measurably reducing bedtime overthinking."
            )
        case .boringStory:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−11 min",
                suffix: " faster.",
                science: "Gentle narrative occupies the language-processing parts of the brain just enough to prevent intrusive thoughts, without triggering the reward circuits that keep you alert. A cognitive decoy for sleep."
            )
        case .sleepSounds:
            return RemedyImpact(
                prefix: "Users like you woke up ",
                highlight: "less often",
                suffix: " from noise.",
                science: "Steady ambient sound can mask small changes in the room that pull attention back online. Keep it quiet enough to fade into the background."
            )
        case .breathing478:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−8 min",
                suffix: " faster.",
                science: "The 4-7-8 pattern activates the vagus nerve through extended exhalation, shifting the nervous system from sympathetic (alert) to parasympathetic (rest). Heart rate slows within minutes."
            )
        case .gratitudeJournal:
            return RemedyImpact(
                prefix: "Sleep quality improved ",
                highlight: "+10%",
                suffix: " on average.",
                science: "Gratitude practice shifts pre-sleep cognition from threat-monitoring to positive reflection. Studies show it reduces worry-based arousal before bed and improves both sleep duration and quality."
            )
        case .gentleStretching:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−7 min",
                suffix: " faster.",
                science: "Light stretching releases accumulated muscle tension and activates the parasympathetic nervous system. It also slightly lowers core body temperature — both reliable precursors to sleep onset."
            )
        case .progressiveMuscleRelaxation:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−12 min",
                suffix: " faster.",
                science: "PMR is a core component of CBT-I, the gold-standard sleep therapy, with decades of clinical evidence. Systematically tensing and releasing muscle groups breaks the feedback loop between physical tension and mental arousal."
            )
        case .readingBook:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−9 min",
                suffix: " faster.",
                science: "Reading a physical book reduces cognitive stress by up to 68% within 6 minutes (University of Sussex study). It engages just enough attention to quiet rumination without the alerting effects of screens."
            )
        case .bodyScan:
            return RemedyImpact(
                prefix: "Users like you fell asleep ",
                highlight: "−10 min",
                suffix: " faster.",
                science: "A guided body scan moves attention slowly through the body, interrupting pre-sleep rumination and cueing each muscle group to release. Shifting focus to physical sensation lowers cognitive and physiological arousal, two of the main drivers of delayed sleep onset."
            )
        }
    }

    var routineRevealBenefit: String {
        switch self {
        case .dimTheLights:
            return "Signals melatonin sooner by lowering bright light before bed."
        case .noScreens:
            return "Removes blue-light and scroll stimulation so your brain can power down."
        case .appBlocking:
            return "Locks the apps most likely to restart scrolling during wind-down."
        case .finishWorkouts:
            return "Gives your body time to cool down after exercise before sleep."
        case .noHeavySnacks:
            return "Keeps digestion quieter so your body can stay asleep."
        case .noAlcohol:
            return "Protects REM and reduces second-half-of-night wakeups."
        case .noCaffeine:
            return "Lets sleep pressure build without caffeine blocking the signal."
        case .coldRoomPrep:
            return "Helps trigger the core temperature drop that cues sleep onset."
        case .warmShower:
            return "Uses a post-shower temperature drop to make sleep onset easier."
        case .magnesium:
            return "Supports GABA and melatonin systems involved in winding down."
        case .herbalTea:
            return "Adds a calming ritual with gentle, sleep-supporting ingredients."
        case .weightedBlanket:
            return "Uses deep pressure to reduce arousal and make the bed feel safer."
        case .blackoutCurtains:
            return "Keeps stray light from nudging your brain back toward morning."
        case .brainDump:
            return "Gets tomorrow's loops out of working memory before lights-out."
        case .boringStory:
            return "Gives your mind a low-stakes track to follow instead of replaying the day."
        case .sleepSounds:
            return "Masks small room noises so fewer sounds pull you back online."
        case .breathing478:
            return "Lengthens the exhale to slow your heart rate and downshift arousal."
        case .gratitudeJournal:
            return "Steers bedtime attention away from threat-scanning and toward safety."
        case .gentleStretching:
            return "Releases muscle tension without raising your heart rate."
        case .progressiveMuscleRelaxation:
            return "Breaks the loop between tense muscles and a tense mind."
        case .bodyScan:
            return "Moves attention into body sensation so rumination has less room."
        case .readingBook:
            return "Gives your mind a quiet anchor without screen stimulation."
        }
    }
}

// MARK: - Supporting types for per-night data

enum LightsLevelSource: String, Codable {
    case sensor       // camera EV reading
    case selfReported // user selected a swatch
}

enum StepStatus: String, Codable {
    case completed
    case skipped
}

struct StepAttempt: Codable {
    var remedyId: RemedyID?
    var labelSnapshot: String
    var status: StepStatus
    var durationSeconds: Int?
}
