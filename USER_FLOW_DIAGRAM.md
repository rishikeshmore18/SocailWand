# Social Wand - User Flow Diagram

## Complete App Flow (Pages 1-3)

```
┌─────────────────────────────────────────────────────────────────┐
│                        PAGE 1: ONBOARDING                        │
│                     (OnboardingHeroView)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Logo Animation: Pop & Slide]                                  │
│                                                                  │
│            🎩 Social Wand Logo (Big)                            │
│                                                                  │
│         "Type Anywhere Like a Pro 😎"                           │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │    [3D Flippable Card - Auto-rotates once]           │      │
│  │  Front: How it works                                 │      │
│  │  Back: Benefits                                      │      │
│  │  (Tap/swipe to flip)                                 │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  [Language Selector: EN/ES]                                     │
│                                                                  │
│  By continuing you agree to our policies...                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │        [Get Started for Free] (Purple CTA)           │      │
│  └──────────────────────────────────────────────────────┘      │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ (Tap "Get Started")
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PAGE 2: SOCIAL SKILLS TEST                     │
│                  (TestYourSocialSkillsView)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│            🎩 Social Wand Logo (Small)                          │
│                                                                  │
│           "Test Your Social Skills..."                          │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  Scenario Bubble:                                    │      │
│  │  "I'm not mad at you, I just don't like             │      │
│  │   how our convos have been lately"                   │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  [Your Reply TextField]                              │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ↑ How would you reply to this?                                 │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │           [Rate my reply] (Purple CTA)               │      │
│  └──────────────────────────────────────────────────────┘      │
│                           │                                      │
│                           │ (Tap, user typed reply)              │
│                           ▼                                      │
│                    [⏳ Evaluating...]                            │
│                           │                                      │
│                           ▼                                      │
│  ╔══════════════════════════════════════════════════════╗      │
│  ║        SCORE MODAL (Overlays screen)                 ║      │
│  ║                                                      ║      │
│  ║   "You have poor social skills 😭"                  ║      │
│  ║                                                      ║      │
│  ║                3-5/10                                ║      │
│  ║         (Random each time)                           ║      │
│  ║                                                      ║      │
│  ║   "You scored lower than most people..."            ║      │
│  ║                                                      ║      │
│  ║   ┌────────────────────────────────────────┐        ║      │
│  ║   │    [Help me out 😉] (Green CTA)        │        ║      │
│  ║   └────────────────────────────────────────┘        ║      │
│  ╚══════════════════════════════════════════════════════╝      │
│                           │                                      │
│                           │ (Tap "Help me out")                  │
│                           ▼                                      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │           Wand Reply ⬇ ⬇                             │      │
│  │                                                      │      │
│  │  Alt 1: "I feel the same way. I think it's          │      │
│  │         best we give this a fresh start..."          │      │
│  │                                                      │      │
│  │                   OR                                 │      │
│  │                                                      │      │
│  │  Alt 2: "I've noticed that too. Any ideas           │      │
│  │         on how we can make things better?"           │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │   [Improve my social skills ;)] (Purple CTA)         │      │
│  └──────────────────────────────────────────────────────┘      │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ (Tap "Improve my social skills")
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                PAGE 3: IMPROVEMENT SELECTION                     │
│                 (ImprovementSelectionView)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│            🎩 Social Wand Logo (Medium)                         │
│                                                                  │
│            "Which needs improving?"                             │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  💬  Reply game                          │ Unselected│      │
│  │     Keep convos engaging                             │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  📝  Starting convos                     │ ✓ Selected │      │
│  │     Get to know people                               │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  😔  Reading emotions                    │ Unselected│      │
│  │     Understand people better                         │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │         [Improve these 🙌] (Purple CTA)              │      │
│  │         (Enabled when ≥1 selected)                   │      │
│  └──────────────────────────────────────────────────────┘      │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ (Tap "Improve these")
                            ▼
                       [PAGE 4: TBD]
                   (Next implementation)
```

## State Flow Details

### Page 1 → Page 2 Transition
- **Trigger**: User taps "Get Started for Free" button
- **Implementation**: `ContentView.swift` line ~241-245
- **Method**: `.fullScreenCover(isPresented: $showTestScreen)`
- **State**: `@State private var showTestScreen = false` → `true`

### Page 2 Internal Flow
- **Stages**: `enum TestStage { input, evaluating, showScore, showAlternatives }`
- **Flow**:
  1. `input` → User types reply
  2. `evaluating` → 600ms delay + API call (hardcoded response)
  3. `showScore` → Modal overlay shows score (3-5/10)
  4. `showAlternatives` → Modal dismissed, alternatives shown

### Page 2 → Page 3 Transition
- **Trigger**: User taps "Improve my social skills ;)" button (stage = `.showAlternatives`)
- **Implementation**: `TestYourSocialSkillsView.swift` line 217-219
- **Method**: `NavigationStack` + `.navigationDestination(isPresented: $goToImprove)`
- **State**: `@State private var goToImprove = false` → `true`
- **Navigation**: Push navigation (can swipe back, but back button hidden)

### Page 3 Selection State
- **State**: `@State private var selectedIDs: Set<String> = []`
- **Options**: 3 cards, each with unique `id` ("reply", "starting", "emotions")
- **Multi-select**: User can select 0-3 cards
- **CTA State**: Disabled (opacity 0.45) when `selectedIDs.isEmpty`

### Page 3 → Page 4 Transition (TODO)
- **Trigger**: User taps "Improve these 🙌" button
- **Current**: Calls `onComplete` closure with selected `ImprovementOption[]`
- **Future**: Navigate to Page 4 (tone selection, conversation starter, etc.)

## Navigation Architecture

```
ContentView
  └─ OnboardingHeroView
       │
       └─ .fullScreenCover(isPresented: $showTestScreen)
            │
            └─ TestYourSocialSkillsView (wrapped in NavigationStack)
                 │
                 └─ .navigationDestination(isPresented: $goToImprove)
                      │
                      └─ ImprovementSelectionView
                           │
                           └─ [Future: Page 4]
```

## Key State Variables

### OnboardingHeroView
```swift
@State private var showTestScreen: Bool = false
```

### TestYourSocialSkillsView
```swift
@State private var stage: TestStage = .input
@State private var userReply: String = ""
@State private var ratingResponse: SocialRatingResponse?
@State private var goToImprove: Bool = false
```

### ImprovementSelectionView
```swift
@State private var selectedIDs: Set<String> = []
@State private var showContent: Bool = false
```

## Animation Timeline

### Page 1 (OnboardingHeroView)
- **0ms**: Splash - Logo appears at center, scales 0.9→1.0 (220ms)
- **220ms**: Logo holds (400ms)
- **620ms**: Logo + hero content slide up together
- **650ms**: Content fades in (350ms)
- **1000ms**: Button pops in (spring animation)

### Page 2 (TestYourSocialSkillsView)
- **0ms**: Screen appears
- **0ms**: Logo/title/bubble/field fade+slide up (350ms, staggered)
- **Ongoing**: Arrow bounces up/down (1.4s loop)
- **On tap CTA**: Evaluating spinner (600ms)
- **On score**: Modal springs in (320ms, damping 0.82)
- **On "Help me out"**: Alternatives fade/slide up (350ms, 120ms stagger)

### Page 3 (ImprovementSelectionView)
- **0ms**: NavigationStack push animation (system)
- **100ms**: Content fade+slide up (350ms)
- **On card tap**: Scale 0.98→1.0 (250ms spring)
- **On selection**: Border/shadow change (300ms spring)

## Responsive Behavior

### Page 1
- **Breakpoints**: `veryCompact` (<500pt), `compact` (<760pt), `regular` (≥760pt)
- **Adaptations**: Logo size, font size, spacing, card height

### Page 2
- **Breakpoints**: Same as Page 1
- **Scroll**: `ScrollView` with safe-area inset for CTA

### Page 3
- **Budget Algorithm**: No ScrollView - everything fits
- **Breakpoints**: Continuous scaling based on `safeHeight`
- **Card height**: 56-92pt (dynamically calculated)
- **Gaps**: 10-22pt (dynamically calculated)

## Accessibility Features

### All Pages
- ✅ VoiceOver labels and hints
- ✅ Dynamic Type support (minimumScaleFactor)
- ✅ High contrast text on black
- ✅ Minimum 56pt tap targets
- ✅ Proper accessibility traits

### Page 2 Specific
- ✅ TextField focus management with `@FocusState`
- ✅ Shake animation + haptic on empty input

### Page 3 Specific
- ✅ Selection state announced ("Selected"/"Not selected")
- ✅ CTA hint when disabled ("Select at least one option first")

---

**Last Updated**: November 12, 2025
**Status**: Pages 1-3 Complete ✅
**Next**: Page 4 (Tone/Feature Selection)






