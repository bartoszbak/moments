# Subscriptions and Lifetime Unlock — Implementation Plan

**Date:** 2026-04-16

## Architecture Recommendation

**Recommendation:** MVVM-style feature slices on top of the existing repository/service architecture  
**Fit:** `fit`

Why this fits the current app:
- The codebase already uses SwiftUI views, `@StateObject`, `@EnvironmentObject`, `@AppStorage`, repositories, and singleton-style services rather than reducers or coordinators.
- Purchases are an app-wide side-effect boundary with a few focused UI surfaces, not a reason to introduce a second architecture.

Closest alternative:
- `Clean Architecture + MVVM` would be the next step if payments, analytics, and experiments grow into a much larger domain area.
- Tradeoff: cleaner long-term layering, but too much ceremony for the current app shape.

Liquid Glass recommendation:
- **Use the existing glass language already in the app** rather than inventing a separate monetization aesthetic.
- Keep Liquid Glass focused on high-value interactive surfaces: paywall cards, offer chips, floating CTA bars, and locked premium affordances.
- Reuse and extend [View+Glass.swift](/Users/bartbak/Repo/Moments/Moments/Extensions/View+Glass.swift:1) so premium UI stays visually consistent with the rest of the app.

Reference files:
- `/Users/bartbak/.agents/skills/swift-architecture-skill/references/selection-guide.md`
- `/Users/bartbak/.agents/skills/swift-architecture-skill/references/mvvm.md`
- `/Users/bartbak/.agents/skills/swiftui-liquid-glass/SKILL.md`

### Installed supporting skills

The following skills are installed and should be treated as supporting references while building this:

- `swift-architecture-skill`
  - primary architecture guidance for state, service boundaries, view models, and dependency flow
- `swiftui-liquid-glass`
  - primary UI guidance for paywall surfaces, premium badges, CTA bars, and iOS 26 glass behavior
- `axiom-apple-docs`
  - use for Apple platform API guidance, especially StoreKit 2 and Apple-native subscription behavior
- `axiom-integration`
  - use for SDK integration structure, third-party setup hygiene, and app-level wiring
- `axiom-swiftui`
  - use for polished SwiftUI composition details and reusable UI patterns
- `revenuecat`
  - use for RevenueCat docs, API understanding, and RevenueCat-specific integration details

Requested but unavailable:
- `axiom-storekit-ref`
  - this skill name was requested, but it is not present in the current `charleswiltgen/axiom` repository
  - use `axiom-apple-docs` for StoreKit 2 reference guidance instead

For this feature, the implementation priority should still be:
1. `swift-architecture-skill`
2. `swiftui-liquid-glass`
3. `axiom-apple-docs`
4. `axiom-integration`
5. `revenuecat`
6. `axiom-swiftui`

## Product Model

Use one entitlement and three App Store products.

### Entitlement

- `premium`

### Products

- `moments_premium_monthly`
- `moments_premium_yearly`
- `moments_premium_lifetime`

### Access rule

`hasPremium == true` when the user has either:
- an active auto-renewable subscription
- the lifetime non-consumable purchase

This keeps the rest of the app simple. Features do not care *how* premium was granted, only whether premium is currently active.

### What every paid plan unlocks

All paid products should unlock the **same** premium feature set:
- monthly subscription
- yearly subscription
- lifetime unlock

Do not create different feature access by plan in V1. The plan choice should only change billing behavior, not app capability. That keeps the paywall easier to understand and keeps entitlement logic much cleaner.

## Goals

1. Add professional Apple-native monetization using `StoreKit 2` and `RevenueCat`.
2. Keep one source of truth for entitlements.
3. Build a premium UX that matches the app’s visual standard.
4. Add gated premium affordances without making the free experience feel broken or hostile.
5. Keep implementation incremental, testable, and reversible.

## Scope Guard

This implementation should **not change anything beyond the subscriptions / premium access scope**.

That means:
- no unrelated visual redesigns
- no refactors outside payment, entitlement, paywall, and premium gating surfaces
- no unrelated data model changes
- no unrelated navigation changes
- no unrelated settings cleanup

Allowed work:
- RevenueCat and StoreKit 2 integration
- premium entitlement state
- paywall and purchase sheet UI
- locked premium affordances
- settings rows directly related to premium access
- minimal supporting infrastructure needed to wire those features cleanly

## Non-Goals for V1

- Multiple premium tiers
- Intro offers and win-back offers on day one
- Server-owned purchase state outside RevenueCat
- Custom payment backend
- Hard-to-maintain custom animation system just for monetization

## RevenueCat and App Store Setup

### App Store Connect

Create:
- one subscription group: `Moments Premium`
- monthly product
- yearly product
- lifetime non-consumable product

Recommended merchandising:
- highlight yearly as the default recommended plan
- keep monthly available but visually secondary
- keep lifetime available but not louder than yearly

### RevenueCat

Configure:
- entitlement: `premium`
- offering: `default`
- package mapping:
  - monthly -> `$rc_monthly`
  - yearly -> `$rc_annual`
  - lifetime -> custom package or mapped non-subscription product

RevenueCat should be the runtime source of truth for:
- `CustomerInfo`
- active entitlement state
- restore results
- offering / package metadata

### Config pattern

Follow the existing config convention already used for OpenRouter in:
- [SharedConfig.xcconfig](/Users/bartbak/Repo/Moments/Moments/SharedConfig.xcconfig:1)
- [Config.xcconfig.example](/Users/bartbak/Repo/Moments/Moments/Config.xcconfig.example:1)

Add:
- `REVENUECAT_API_KEY_IOS`
- `REVENUECAT_ENTITLEMENT_PREMIUM = premium`
- optional product IDs if you want them visible in config rather than hardcoded

Mirror the API key into `Info.plist`, then read it at runtime the same way the app reads OpenRouter config now.

## Recommended Runtime Architecture

### New payment boundary

Create a dedicated monetization service layer instead of letting views talk to RevenueCat directly.

Suggested files:

```text
Moments/
  Services/
    SubscriptionService.swift
    SubscriptionServiceLive.swift
  Features/
    Premium/
      PremiumAccessState.swift
      PremiumFeature.swift
      PremiumPaywallView.swift
      PremiumPaywallViewModel.swift
      PurchaseSheetView.swift
      PurchaseSheetViewModel.swift
      PremiumBadgeView.swift
      LockedFeatureCard.swift
      PremiumSettingsSection.swift
```

If you want to keep the file count tighter, `SubscriptionService.swift` can contain both protocol and live implementation in V1.

### Suggested service surface

```swift
@MainActor
protocol SubscriptionService: AnyObject, ObservableObject {
    var accessState: PremiumAccessState { get }
    var currentOffering: PremiumOfferingState { get }

    func configure() async
    func refreshCustomerInfo() async
    func restorePurchases() async throws
    func purchase(packageID: PremiumPackageID) async throws
    func manageSubscriptions()
}
```

Use one app-wide live object:
- `SubscriptionServiceLive.shared`

That matches the repo’s current service style and avoids over-engineering.

### State model

Avoid loose booleans. Use explicit purchase state.

Suggested types:

```swift
enum PremiumAccessState: Equatable {
    case unknown
    case free
    case premium(source: PremiumAccessSource)
    case loading
    case failed(message: String)
}

enum PremiumAccessSource: Equatable {
    case subscription
    case lifetime
}

enum PremiumPackageID: String, CaseIterable {
    case monthly
    case yearly
    case lifetime
}
```

### View model ownership

- `PremiumPaywallViewModel` owns package selection, purchase loading state, restore action state, and purchase copy decisions.
- `PurchaseSheetViewModel` owns the compact purchase entry flow when launched from a locked feature.
- Feature screens should not run purchase logic directly. They ask the premium service for access state and present the appropriate UI.

## App Integration Points

### App root

Inject the premium service at app launch from [MomentsApp.swift](/Users/bartbak/Repo/Moments/Moments/MomentsApp.swift:1), the same way the app already injects repository and timer services.

Recommended additions:
- `@StateObject private var subscriptionService = SubscriptionServiceLive.shared`
- `.environmentObject(subscriptionService)`
- configure RevenueCat in app launch / first active phase
- refresh entitlement state when the app becomes active

### Feature gating model

Create a small app-level enum:

```swift
enum PremiumFeature: String, Identifiable, CaseIterable {
    case aiReflections
    case unlimitedMoments
    case advancedThemes
    case premiumWidgets
}
```

Then keep one central gate helper:

```swift
func isUnlocked(_ feature: PremiumFeature) -> Bool
```

This prevents lock logic from scattering across unrelated views.

## UI Elements We Need to Build

The core intuition is correct: the minimum professional set is the paywall, a smaller purchase sheet, and locked-state accessories. For V1, the full UI list should be:

### Primary monetization surfaces

1. `PremiumPaywallView`
   - full-screen or large sheet
   - used from settings, onboarding upsell, and deliberate upgrade entry points

2. `PurchaseSheetView`
   - compact sheet launched from a locked feature tap
   - shorter copy, same package list, faster path to buy

### Offer and purchase components

3. `PremiumHeroCard`
   - headline, benefit summary, visual brand treatment

4. `PremiumPlanCard`
   - monthly / yearly / lifetime option cards
   - selected state
   - recommended badge for yearly
   - savings or “best value” label

5. `PurchaseCTAButton`
   - primary purchase CTA
   - dynamic title based on selected package

6. `RestorePurchasesButton`
   - visible on every paywall surface

7. `ManageSubscriptionRow`
   - in Settings for active premium users

8. `LegalFooterView`
   - restore, terms, privacy, billing note

### Locked-state accessories

9. `PremiumBadgeView`
   - small badge for premium-only sections or controls

10. `LockOverlayChip`
   - compact visual lock marker on disabled premium controls

11. `LockedFeatureCard`
   - reusable card with:
   - title
   - one-sentence explanation
   - lock icon
   - “Unlock Premium” CTA

12. `LockedToolbarAction`
   - when a premium action exists in a top bar or floating control

13. `PremiumEmptyState`
   - used when a whole screen section is premium-only

### Settings and account surfaces

14. `PremiumSettingsSection`
   - current access state
   - active plan label
   - restore purchases
   - manage subscription
   - upgrade / compare plans if free

15. `PurchaseStatusBanner`
   - subtle success/error feedback after purchase or restore

### Optional but recommended

16. `PremiumFeatureList`
   - bullet list of what unlocks

17. `TrialOrBillingCaption`
   - keeps plan pricing and renewal behavior explicit

18. `EntitlementLoadingView`
   - protects against flicker while `CustomerInfo` is still loading

## Recommended UX by Surface

### 1. Main paywall

Use when the user intentionally explores upgrade options.

Recommended destinations:
- from Settings
- from a premium promo row in the list screen
- from a premium callout on onboarding / intro flow later

Behavior:
- show all plans
- show fuller benefit copy
- show restore
- show terms/privacy
- keep manage subscription available when already premium

### 2. Compact purchase sheet

Use when the user taps a locked premium capability in context.

Behavior:
- shorter copy
- same package choices
- preselect yearly
- include one sentence about what the tapped feature unlocks
- include a visible dismiss action so it never feels coercive

### 3. Locked accessories

Do not hard-disable the app silently. Premium affordances should remain understandable.

Recommended behavior:
- locked controls remain visible
- tapping them opens the compact purchase sheet
- nearby helper text explains the benefit in plain language

## Professional UI Direction

The monetization UI should feel like part of `Moments`, not a template pasted into it.

### Visual direction

- Continue the existing rounded, soft, editorial aesthetic.
- Use the app’s current typography system for headings and premium benefit copy.
- Avoid “growth-hack” styling: no red urgency banners, no fake countdown timers, no spammy gradients.
- Emphasize calm clarity and confidence.

### Liquid Glass guidance

Use Liquid Glass professionally, not decoratively.

Recommended glass surfaces:
- the hero card at the top of the paywall
- the selected plan card
- the bottom CTA bar
- compact locked chips
- premium settings summary card

Avoid:
- putting glass on every row
- stacking too many nested glass containers
- over-tinting every card with strong colors

### Concrete implementation rules

- Reuse [View+Glass.swift](/Users/bartbak/Repo/Moments/Moments/Extensions/View+Glass.swift:1) helpers for basic surfaces.
- Add a new premium-specific helper only if you need a distinct selected-plan treatment.
- Use `GlassEffectContainer` for grouped plan cards on iOS 26+.
- Apply `.glassEffect()` after sizing and padding.
- Use `.buttonStyle(.glassProminent)` only for the main purchase CTA.
- Keep secondary actions quieter: plain text or `.buttonStyle(.glass)`.

### Motion

- animate plan selection changes
- animate paywall presentation smoothly
- avoid bouncing price labels or exaggerated sales motion
- use matched or materialized glass transitions only where it clearly improves clarity

## Feature Gating Strategy

Implement premium gating in three levels.

### Level 1: soft gate

Feature visible, but uses:
- `PremiumBadgeView`
- explanatory subtitle
- tap opens purchase sheet

Use for:
- AI reflections
- advanced customization

### Level 2: section gate

Entire section is visible but replaced with `LockedFeatureCard`.

Use for:
- premium widget configuration
- premium personalization group

### Level 3: quota gate

Feature works until the user hits a free cap, then shows the compact purchase sheet.

Use for:
- free moment limit, if you introduce one

## Suggested Free vs Premium Shape

Keep the rule set easy to explain.

Example V1:
- Free:
  - core countdowns
  - a small capped number of moments
  - basic themes and symbols
- Premium:
  - unlimited moments
  - AI reflections
  - premium widgets
  - richer themes / visual customization
  - future premium experiments

The exact feature set is product work, but the entitlement architecture above supports it cleanly.

## Recommended Premium Feature Set

If the question is "what should be Pro and available to any paid plan?", this is the cleanest V1 set for `Moments`.

### Premium features I would ship first

1. `Unlimited Moments`
   - Free users get a simple cap, for example `3` or `5` active moments.
   - Premium removes the cap entirely.
   - This is the clearest upgrade value because it connects directly to the core product.

2. `AI Reflections`
   - Reflection generation and regeneration are premium-only.
   - This is a strong paid feature because it has direct cost and feels meaningfully upgraded.

3. `Premium Widget Styles`
   - Advanced widget layouts, richer styling, and premium-only widget presentation options.
   - Keep at least one basic widget experience free so widgets do not feel bait-and-switch.

4. `Advanced Visual Customization`
   - Premium background themes
   - premium color palettes
   - premium tile treatments
   - future icon packs or visual packs

5. `Priority Access to New Premium Features`
   - Any future premium experiments also sit behind the same `premium` entitlement.
   - This avoids adding another billing tier later just to ship more value.

### Features I would keep free

- creating and viewing basic countdowns
- editing titles and dates
- basic symbols
- basic background options
- at least one widget path
- manifestation creation if it is core to the app identity

### Features I would not gate in V1

- notifications
- core settings
- restore access
- basic app usability fixes or accessibility improvements

These should stay outside the premium wall so the app still feels trustworthy.

### Best single premium message

If you want one simple promise for the paywall, use this:

`Premium unlocks unlimited moments, AI reflections, premium widgets, and deeper visual personalization.`

That is short, understandable, and consistent with the feature set above.

## File Plan

### New files

- `Moments/Services/SubscriptionService.swift`
- `Moments/Features/Premium/PremiumAccessState.swift`
- `Moments/Features/Premium/PremiumFeature.swift`
- `Moments/Features/Premium/PremiumPaywallView.swift`
- `Moments/Features/Premium/PremiumPaywallViewModel.swift`
- `Moments/Features/Premium/PurchaseSheetView.swift`
- `Moments/Features/Premium/PurchaseSheetViewModel.swift`
- `Moments/Features/Premium/PremiumBadgeView.swift`
- `Moments/Features/Premium/LockedFeatureCard.swift`
- `Moments/Features/Premium/PremiumSettingsSection.swift`

### Existing files to modify

- [MomentsApp.swift](/Users/bartbak/Repo/Moments/Moments/MomentsApp.swift:1)
  - inject premium service
  - configure and refresh purchase state

- [SettingsView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Settings/SettingsView.swift:1)
  - add premium account / upgrade section

- [CountdownListView.swift](/Users/bartbak/Repo/Moments/Moments/Features/List/CountdownListView.swift:1)
  - add entry point(s) to premium
  - optionally add a premium promo row or CTA hook

- [View+Glass.swift](/Users/bartbak/Repo/Moments/Moments/Extensions/View+Glass.swift:1)
  - extend only if a premium-specific selected state helper is needed

- `Moments/Info.plist`
  - add RevenueCat config keys

- [SharedConfig.xcconfig](/Users/bartbak/Repo/Moments/Moments/SharedConfig.xcconfig:1)
- [Config.xcconfig.example](/Users/bartbak/Repo/Moments/Moments/Config.xcconfig.example:1)
  - add RevenueCat config values

## Implementation Phases

## Phase 1 — Billing foundation

1. Add RevenueCat SDK.
2. Add App Store product IDs and entitlement config.
3. Add RevenueCat API key config to xcconfig + Info.plist.
4. Create `SubscriptionService`.
5. Configure service from app launch.
6. Expose `PremiumAccessState`.

Exit criteria:
- app boots with premium state available
- active premium vs free resolves correctly
- restore works in sandbox

## Phase 2 — Premium UI primitives

1. Build `PremiumBadgeView`
2. Build `LockedFeatureCard`
3. Build plan card and CTA components
4. Add selected / recommended visual states
5. Add Liquid Glass selected-card treatment

Exit criteria:
- all premium UI primitives reusable
- no purchase logic in primitive views

## Phase 3 — Paywall and purchase sheet

1. Build `PremiumPaywallView` + view model
2. Build `PurchaseSheetView` + view model
3. Wire package selection and purchase flows
4. Add restore and manage subscription actions
5. Add success / error feedback

Exit criteria:
- user can purchase from either surface
- user can restore and recover state
- active entitlement dismisses paywall cleanly

## Phase 4 — Settings and app integration

1. Add premium section to settings
2. Add app-wide upgrade entry points
3. Add lock accessories where premium features are shown
4. Add feature gate helpers

Exit criteria:
- premium state visible in settings
- locked features present a consistent upgrade flow

## Phase 5 — Gated features rollout

1. Choose first premium-only features
2. Apply gate helpers
3. Add contextual upgrade copy per locked feature
4. Validate that free users always understand what is locked and why

Exit criteria:
- no hidden feature gates
- no dead-end disabled UI

## Purchase Flow Rules

### On app launch

- configure RevenueCat
- fetch current customer info
- publish `PremiumAccessState`

### On paywall open

- fetch current offering if stale
- preselect yearly

### On purchase

- disable duplicate taps
- execute purchase
- refresh customer info
- dismiss when entitlement becomes active

### On restore

- run restore
- refresh customer info
- show explicit success or “nothing to restore” feedback

### On active subscription tap

- open Apple subscription management

## Error Handling

Handle these states explicitly:
- RevenueCat config missing
- offerings unavailable
- user cancelled purchase
- App Store temporarily unavailable
- restore found nothing
- entitlement refresh failed

Recommended UX:
- user cancellation is not an error banner
- network/store failures use calm inline messaging
- restore results should be explicit and final

## Testing Strategy

### Unit tests

Test:
- mapping from RevenueCat `CustomerInfo` to `PremiumAccessState`
- feature gate helper behavior
- paywall view model selection logic
- success / failure / cancel purchase states

### Integration tests

Test with sandbox:
- fresh free user
- successful monthly purchase
- successful yearly purchase
- successful lifetime purchase
- restore on a new install
- expired subscription fallback to free

### UI tests

Test:
- locked feature tap opens compact purchase sheet
- settings upgrade row opens full paywall
- restore button visible
- paywall dismisses after entitlement activates

## Analytics Hooks

Keep analytics simple and event-based.

Recommended events:
- `paywall_viewed`
- `purchase_sheet_viewed`
- `plan_selected`
- `purchase_started`
- `purchase_completed`
- `purchase_cancelled`
- `restore_started`
- `restore_completed`

Do not block V1 on a full analytics system, but leave obvious hook points in the view models and service.

## Risks and Mitigations

### Risk: purchase logic leaks into views

Mitigation:
- keep RevenueCat calls inside `SubscriptionService`
- keep views bound to view model and published state only

### Risk: entitlement flicker on launch

Mitigation:
- add `unknown` / `loading` state
- avoid showing locked UI until the first access state resolves

### Risk: monetization UI feels bolted on

Mitigation:
- reuse existing typography and glass helpers
- keep copy calm and short
- use only a few strong premium surfaces

### Risk: too many gate patterns

Mitigation:
- standardize on the three gate levels above
- use one reusable locked card and one compact purchase sheet

## Shipping Checklist

- RevenueCat configured in sandbox
- App Store products approved / available for testing
- entitlement state resolves on launch and on resume
- restore works
- manage subscription works
- settings premium section complete
- paywall and purchase sheet both polished
- at least one locked feature integrated end to end
- legal links present
- UI reviewed on iPhone and iPad
- iOS 26 glass and pre-iOS 26 fallbacks both verified

## Recommended Implementation Order

If we execute this in the repo, the clean order is:

1. Billing config + `SubscriptionService`
2. `PremiumAccessState` and feature gates
3. Paywall UI primitives
4. Full paywall
5. Compact purchase sheet
6. Settings premium section
7. Locked accessories across the first premium features
