# Lull — Setup Instructions

## 1. Generate the Xcode project

```bash
brew install xcodegen
cd /Users/czarinacatambing/lull-sleep-app
xcodegen generate
open Lull.xcodeproj
```

## 2. Add fonts (required for brand typography)

Download these from Google Fonts and add the `.ttf` files to `Lull/Resources/Fonts/`:

| Font | URL | File needed |
|---|---|---|
| Fraunces Light | fonts.google.com/specimen/Fraunces | `Fraunces-Light.ttf` |
| Fraunces Light Italic | fonts.google.com/specimen/Fraunces | `Fraunces-LightItalic.ttf` |
| JetBrains Mono | fonts.google.com/specimen/JetBrains+Mono | `JetBrainsMono-Regular.ttf` |

Then in Xcode: select each `.ttf`, check "Target Membership → Lull". The fonts are already declared in `Info.plist` under `UIAppFonts`.

Without these fonts the app uses system serif/monospaced fallbacks — it still runs, just off-brand.

## 3. Set your Development Team

In Xcode → Lull target → Signing & Capabilities → set your Team.

## 4. Screens implemented

| Screen | File |
|---|---|
| Onboarding 1–6 + Routine Ready | `Lull/Onboarding/OnboardingView.swift` |
| Dashboard (Tonight) | `Lull/Home/DashboardView.swift` |
| My Routine (The Lab) | `Lull/Home/MyRoutineView.swift` |
| Nightly walkthrough: Brightness | `Lull/Nightly/NightlyFlowView.swift` |
| Nightly walkthrough: Temperature | same file |
| Nightly walkthrough: Brain Dump | same file |
| Nightly walkthrough: Boring Story | same file |
| Nightly walkthrough: 4-7-8 Breathing | same file |
| Mid-Sleep Mode | `Lull/MidSleep/MidSleepModeView.swift` |
| Get-Up Prompt | `Lull/MidSleep/GetUpPromptView.swift` |
| Morning Check-In | `Lull/Morning/MorningCheckInView.swift` |

## 5. Next build steps (v1 wiring)

- [ ] Wire up AVFoundation for Brain Dump mic recording
- [ ] Wire Claude API for Boring Story generation (`/v1/messages`, stream to TTS)
- [ ] Add RevenueCat + StoreKit for $6.99/month subscription
- [ ] Implement push notifications (bedtime + morning check-in)
- [ ] CoreData persistence for sleep scores and routine history
- [ ] Build lock-screen widget (WidgetKit) for Mid-Sleep one-tap access
