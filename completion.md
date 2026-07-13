# Stone Town Heritage VT-Guide — Completion Plan (Waves)

**Date:** 2026-07-13
**Goal for today:** ship the *main functionality* — audio works end-to-end across all platforms, Settings is fully wired and localized, every visible button in the user + admin paths does what it says.

Each wave is independently shippable. Stop at any wave and the app is still demo-runnable.

Wave ordering principle: **the thing the user notices first comes first.** That means audio (the actual product) → settings (where they configure it) → admin (the panel that keeps content correct) → safety/security (so a deploy today doesn't break tomorrow).

---

## Wave 0 — Read existing audit (0 min)

Everything in this plan assumes the prior audit findings in [finalized.md](finalized.md) are the source of truth. Recent commits already fixed:
- TTS progress reporting (`setProgressHandler`, calibrated chars/sec)
- Android-safe pause/resume (`pauseForRestart` + `resumeFrom`)
- Sentence-aware free-tier preview (`_chunkForDuration`)
- Cosmetic premium trial wording (`FakeBillingProvider`)

This plan picks up from there. Items already resolved are listed for context only.

---

## Wave 1 — Audio correctness (the actual product)  ·  ~2 h

**User-visible: the play button does the right thing on every device, in every language, including after pause/resume and after switching language mid-playback.**

### W1.1 — Make `setLanguage` return an honest fallback signal

**File:** [lib/data/services/tts_service.dart:128-157](lib/data/services/tts_service.dart#L128-L157)

Today the method returns a `String?` whose two non-null meanings ("voice not installed" vs "previous voice already in use") are conflated. The cubit ([site_detail_cubit.dart:131-137](lib/blocs/site_detail/site_detail_cubit.dart#L131-L137)) fires a fallback SnackBar that can lie to the user.

**Concrete change:**
```dart
enum SetLanguageOutcome { ok, requestedUnavailable, unsupportedCode }

Future<SetLanguageOutcome> setLanguage(String languageCode) async {
  final ttsLanguage = _supportedMap[languageCode];
  if (ttsLanguage == null) return SetLanguageOutcome.unsupportedCode;

  final available = (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
  if (!available.contains(ttsLanguage)) return SetLanguageOutcome.requestedUnavailable;

  await _flutterTts.setLanguage(ttsLanguage);
  _currentLanguage = ttsLanguage;
  return SetLanguageOutcome.ok;
}
```

Update the cubit to pattern-match on the enum and emit two distinct SnackBars — one for "voice not installed, kept previous voice" (no fall-back was made) and one for "we don't support that code at all".

### W1.2 — Fix iOS pause/resume baseline

**File:** [lib/blocs/site_detail/site_detail_cubit.dart:202-220](lib/blocs/site_detail/site_detail_cubit.dart#L202-L220)

The iOS branch reinstalls the progress reporter with `baseline: 0`, but the iOS engine resumes mid-utterance so its emitted offsets are into the original chunk, not from zero. The visible bar will jump backwards.

**Concrete change:**
```dart
// iOS branch — derive baseline from last seen position
final resumeOffsetChars =
    (state.audioState.position.inMilliseconds / _ttsService.currentMsPerChar).round();
_reinstallProgressReporter(
  baseline: resumeOffsetChars,
  spokenText: state.audioState.spokenText,
);
```

### W1.3 — Surface TTS engine errors

**File:** [lib/data/services/tts_service.dart:91-93](lib/data/services/tts_service.dart#L91-L93)

The error handler drops the message string. Free-tier users on Android with no network (Google TTS) get a silent dead bar.

**Concrete change:** add `ValueChanged<String>? onError` to the service, route the message through it, and have the cubit forward to a SnackBar. Wire the bar widget to show a small "⚠" indicator when `audioState.errorMessage != null`.

### W1.4 — Replace "00:00 / 00:00" flash on first frame

**File:** [lib/ui/widgets/audio_player_bar.dart:99-113](lib/ui/widgets/audio_player_bar.dart#L99-L113)

The first emit after `playAudio` has `position`/`duration` of zero. Render a `SizedBox(height: 4) + Text("Loading…")` while `audioState.isLoading`, then swap to the progress bar.

**Acceptance for Wave 1:**
- Switching audio language mid-playback shows accurate fallback SnackBar.
- Pause/resume on iOS does not snap the bar backwards.
- Free-tier preview with a missing voice surfaces a clear message.
- No "00:00 / 00:00" flash on play.

---

## Wave 2 — Settings: make every tile do what it says  ·  ~2 h

**User-visible: nothing in Settings is decorative. Every tile either changes state or clearly explains it can't.**

### W2.1 — Localize the remaining hard-coded English labels

**File:** [lib/ui/screens/settings_screen.dart:82, 89, 96-100, 133](lib/ui/screens/settings_screen.dart#L82-L100)

Add to [assets/localization/en.json](assets/localization/) and [sw.json](assets/localization/):
- `map_provider`, `appearance`, `theme`, `theme_light`, `theme_dark`, `theme_system`, `clear_map_cache`, `storage`, `notifications`, `notifications_enabled`

Replace every static English string in the Settings tree with `_tr(locState, '...')`.

### W2.2 — Wire the "Map provider" tile to a real choice

**File:** [lib/ui/screens/settings_screen.dart:390-425](lib/ui/screens/settings_screen.dart#L390-L425)

Create `MapProviderCubit` (or extend `SharedPrefsService`) with `'openstreetmap' | 'google'` plus the active value. The OSM option is always available; Google is disabled with "Add an API key in app_constants.dart" when the constant is null. Tile renders the active provider name and a (greyed) Google option.

### W2.3 — Replace placeholder Privacy/Terms URLs

**File:** [lib/ui/screens/settings_screen.dart:198, 205](lib/ui/screens/settings_screen.dart#L198-L205)

`https://stonetownguide.com/{privacy,terms}` doesn't resolve. Two acceptable choices for today:
- **Quick:** remove the two tiles until real pages exist.
- **Better:** host a one-page GitHub Pages site (`docs/privacy.md` → GitHub Pages) and point at that.

Pick the quick option if there are no real pages yet.

### W2.4 — Add "Clear map cache" tile

The `TileCacheService` exists; expose `getTotalSize()` and `clear()` and surface under Appearance → Storage. This is the single most common "support" request for tourist apps.

### W2.5 — Add "Notifications / arrival alerts" toggle

`ArrivalOverlay` fires when the user enters a site's radius. Add `SharedPrefsService.arrivalAlertsEnabled` (default `true`) and gate `ArrivalOverlay` on it. Tile under a new "Notifications" section.

### W2.6 — Move `['en','sw']` to a single source of truth

**File:** [lib/ui/screens/settings_screen.dart:48](lib/ui/screens/settings_screen.dart#L48)

Replace the literal with `AppConstants.uiLanguages` so adding a UI translation later updates the dropdown in one place.

**Acceptance for Wave 2:**
- Zero hard-coded English in Settings.
- Map-provider tile reflects actual state.
- Privacy/Terms tiles either work or don't exist.
- "Clear map cache" works and reports a size.
- Arrival overlay respects the new toggle.

---

## Wave 3 — Detail screen: every button is functional  ·  ~1 h

**User-visible: no silent buttons. Tapping an enabled control always does the documented thing.**

### W3.1 — Wire `UpgradeBanner.onPressed`

**File:** [lib/ui/screens/detail_screen.dart:468-474](lib/ui/screens/detail_screen.dart#L468-L474)

Currently `onPressed: () {}`. Route to `UpgradeScreen`.

### W3.2 — Wire `AudioPlayerBar.onReplay`

**File:** [lib/ui/screens/detail_screen.dart:620-624](lib/ui/screens/detail_screen.dart#L620-L624)

Currently `onPressed: () {}`. Call `context.read<SiteDetailCubit>().playAudio(audioLang, isPremium: true)`.

### W3.3 — Edit profile dialog persists display name

**File:** [lib/ui/screens/user_profile_screen.dart:218-256](lib/ui/screens/user_profile_screen.dart#L218-L256)

`_showEditProfileDialog` pops without writing. Call `auth.currentUser!.updateDisplayName(newName)` and then `context.read<AuthCubit>().reloadUser()`.

### W3.4 — Change password dialog actually changes the password

**File:** [lib/ui/screens/user_profile_screen.dart:258-321](lib/ui/screens/user_profile_screen.dart#L258-L321)

Use `FirebaseAuth.instance.currentUser!.updatePassword(newPassword)` after re-auth with `EmailAuthProvider.credential(email, currentPassword)`. Surface a success SnackBar and an error SnackBar on failure.

### W3.5 — Analytics admin tile: render or remove

**File:** the admin dashboard quick-action row

Either render a real screen (sites count, premium count, top languages — all from existing Firestore reads) or remove the tile. Don't leave an empty `onPressed`.

**Acceptance for Wave 3:**
- Every visible button in the user flow has a working handler.
- Profile edits persist across logout/login.

---

## Wave 4 — Auth: roles are real  ·  ~2 h

**User-visible: registering `admin@anything.com` no longer grants admin. Roles persist across devices and survive app reinstalls.**

### W4.1 — Stop inferring role from email prefix

**File:** [lib/data/services/auth_service.dart:126-141](lib/data/services/auth_service.dart#L126-L141)

Remove the `email.startsWith('admin')` block. On every login, read `roles/{uid}` from Firestore (default to `free` if the doc is missing). Cache the result in the `AuthCubit` so subsequent reads don't refetch.

### W4.2 — Promote/demote writes the `roles/{uid}` doc

**File:** [lib/blocs/user/user_cubit.dart](lib/blocs/user/user_cubit.dart)

`updateUserRole` currently mutates `state.user` locally; the audit (B-17) flagged this. Make it write to Firestore and let the watch stream pick up the change.

### W4.3 — Update Firestore rules to gate admin reads/writes

**File:** [firestore.rules](firestore.rules)

Replace the date-based blanket rule with role-based rules (the audit §6.3 already contains the right rule set — paste it). Deploy with `firebase deploy --only firestore:rules`.

**Acceptance for Wave 4:**
- A fresh `admin@x.com` registration stays `free` until an existing admin promotes them.
- Role changes survive a cold restart.

---

## Wave 5 — Admin: content tools are complete  ·  ~2 h

**User-visible: an admin can fully manage a site without leaving the app.**

### W5.1 — Add `featured: bool` to `SiteModel`

**File:** [lib/data/models/site_model.dart](lib/data/models/site_model.dart)

Add the field, update `toMap`/`fromMap`, write a one-shot Firestore backfill for existing sites (set the first site in the explore list to `featured: true`, rest `false`). Update [explore_screen.dart:127](lib/ui/screens/explore_screen.dart#L127) to use `sites.firstWhere((s) => s.featured, orElse: () => sites.first)`. Hide the "Best Places" header when the category filter excludes the featured site (B-33).

### W5.2 — Edit-site screen supports multi-image

**File:** [lib/ui/screens/admin/admin_edit_site_screen.dart:60](lib/ui/screens/admin/admin_edit_site_screen.dart#L60)

`_imageUrlController` only loads `cloudinaryImageUrl` (legacy single image). Replicate the multi-image grid from `admin_add_site_screen.dart`. Add a "remove" affordance per image.

### W5.3 — "Copy from English" helper in Add Site form

**File:** [lib/ui/screens/admin/admin_add_site_screen.dart:156-279](lib/ui/screens/admin/admin_add_site_screen.dart#L156-L279)

For each of the 7 language description fields, add a small "↳ copy EN" button. Saves typing the same content six times.

### W5.4 — Location picker refreshes lat/lng inputs

**File:** [lib/ui/screens/admin/admin_add_site_screen.dart:478-509](lib/ui/screens/admin/admin_add_site_screen.dart#L478-L509)

The "My location" handler updates the controller but not the `TextEditingController`s for the lat/lng fields. Wrap in `setState`.

### W5.5 — Onboarding screen: ship or delete

**File:** [lib/ui/screens/onboarding_screen.dart](lib/ui/screens/onboarding_screen.dart)

Either push it from `SplashScreen` when `SharedPrefsService.isFirstLaunch == true` (and add `isFirstLaunch` writes in onboarding completion), or delete the file. Pick one; the audit (B-22) noted it's still undecided.

**Acceptance for Wave 5:**
- The explore "featured" card is stable across launches.
- Edit-site handles the same multi-image model as add-site.
- An admin can complete the entire add-site flow without typing the same description seven times.

---

## Wave 6 — Polish pass  ·  ~1 h

**User-visible: the small things that make the app feel finished.**

### W6.1 — Hard-coded "Stone Town, Zanzibar" everywhere

Replace with `site.address` (add the field to `SiteModel`, backfill, default to `'Stone Town, Zanzibar'` for the seed set). Files:
- [lib/ui/screens/detail_screen.dart:441](lib/ui/screens/detail_screen.dart#L441)
- [lib/ui/screens/favorites_screen.dart:278](lib/ui/screens/favorites_screen.dart#L278)
- [lib/ui/screens/site_map_screen.dart:52](lib/ui/screens/site_map_screen.dart#L52)

### W6.2 — Search input clear button

**File:** [lib/ui/widgets/search_bar_widget.dart](lib/ui/widgets/search_bar_widget.dart) — audit B-37.

Add a suffix "x" that appears only when text is non-empty and clears the controller.

### W6.3 — iOS bundle display name

**File:** [lib/ios/Runner/Info.plist](lib/ios/Runner/Info.plist)

`CFBundleDisplayName` = "Stone Town Heritage VT-Guide" (audit X-07).

### W6.4 — Tooltips on icon-only buttons

Pass `tooltip:` everywhere (back arrow on `SiteMapScreen`, gallery arrows, heart, replay). Audit U-01 / U-02.

### W6.5 — Search debounce

**File:** [lib/blocs/site_list/site_list_cubit.dart](lib/blocs/site_list/site_list_cubit.dart)

200 ms debounce on the search query. Audit U-09.

**Acceptance for Wave 6:**
- No hard-coded city strings.
- Search bar has a clear button.
- Every icon-only button announces itself in TalkBack.

---

## Wave 7 — Final readiness gate  ·  ~30 min

Run before each release cut:

```bash
flutter analyze                          # expect 0 issues
flutter test                             # any new tests for the waves above
flutter build apk --release              # smoke
flutter build ios --release --no-codesign  # smoke (best-effort on Windows)
```

Manual smoke checklist:
- Sign up as free user → play audio in `en` → preview badge appears, bar progresses.
- Switch audio to `fr` while playing → bar continues from new language, fallback SnackBar if voice missing.
- Pause on Android → bar stops → resume → bar picks up where it left, not from 0.
- Pause on iOS (if a Mac is available) → bar stops → resume → bar picks up where it left.
- Settings → switch theme → re-launch → theme persisted.
- Settings → clear map cache → cache size → 0.
- Admin login → add site with 7-language descriptions using "Copy EN" → explore screen shows the new site.
- Free user types `admin@x.com` at signup → lands in the user app, not admin.

---

## Out of scope for today (deferred to next-day waves)

These are real features, not bugs, and need their own planning:

| Item | Why deferred |
|---|---|
| Real billing integration (RevenueCat / Play Billing) | Multi-day SDK integration, store-listing requirements |
| Cloud Functions for trusted role assignment | Requires a separate deployable; needs the `functions/` directory from scratch |
| Multi-region site addresses + backfill | Requires schema migration and admin tooling |
| Offline map regions (MBTiles) | Needs download manager + storage UX |
| Background navigation (foreground service) | Platform-specific (Android FGS, iOS background modes) |
| Featured-site admin UI | Depends on W5.1; needs a new admin tile and a curation flow |

Each will get its own wave document when it's time to start it.

---

## Total time budget

| Wave | Effort | Cumulative |
|---|---|---|
| Wave 1 — Audio correctness | 2 h | 2 h |
| Wave 2 — Settings | 2 h | 4 h |
| Wave 3 — Detail/profile buttons | 1 h | 5 h |
| Wave 4 — Auth roles | 2 h | 7 h |
| Wave 5 — Admin content tools | 2 h | 9 h |
| Wave 6 — Polish | 1 h | 10 h |
| Wave 7 — Readiness gate | 30 min | 10.5 h |

Treat 10.5 h as a single focused day. If we cut Wave 4 (auth roles) we still have a demo-runnable build; if we cut Wave 5 we lose admin polish but not user flow.

**Recommended cut-line if we run out of time:** stop after Wave 3. That's the smallest version of the app that doesn't lie to the user about what its buttons do.