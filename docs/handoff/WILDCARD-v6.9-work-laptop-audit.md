# WILDCARD work-laptop audit and home handoff

Audit date: 2026-07-14 (Europe/London)

## Scope and safety

This audit used the public GitHub repository and official Google/Firebase
documentation. It did not copy or request a keystore, password, private SSH
key, Firebase secret, Android SDK or local signing configuration. It did not
build, sign, install, upload or phone-test an APK/AAB. No Play Console,
Firebase Console, production release or Raspberry Pi state was changed.

No scoring, economy, chests, missions, rewards, save schema or game balance
was changed.

## Blocking repository mismatch

GitHub `main` is commit `139f5869705d6915a862dbc442cddd7367203bfa`, tagged
`v6.9`. It contains Android `versionName 6.9`, `versionCode 13`, a minimal
`MainActivity.java`, and no v6.9.1 release/phone-validation log.

The handoff describes phone-validated v6.9.1 features that are not present on
any remote branch or tag: immersive system bars, safe-area control alignment,
wider card separation, the 15-second Credential Manager timeout and the
in-game official leaderboard view. Home Codex must push that source before
this branch is treated as a release candidate. The diagnostic/artwork commit
should be rebased or cherry-picked onto the real v6.9.1 base.

## Repository configuration verified

- Android package: `com.nisarg.wildcard` — matches Gradle, Firebase and the
  requested package.
- Firebase/Cloud project: `wildcard-31d50`.
- Project number / Play Games APP_ID: `420107184674` — present in
  `strings.xml` and referenced by the manifest.
- Leaderboard resource: `CgkIotTbgp0MEAIQAQ`.
- Play Games SDK: `com.google.android.gms:play-services-games-v2:21.0.0`.
- `PlayGamesSdk.initialize(this)` runs in `WildcardApplication`.
- Firebase Auth, Firestore and App Check Play Integrity libraries use the
  Firebase BoM.

The committed `google-services.json` has one Android OAuth client for
`com.nisarg.wildcard` with the direct/upload SHA-1
`E0:5C:17:94:91:AC:EE:68:9A:A1:E0:3A:63:D9:79:DE:D9:5B:05:C0`, plus web
OAuth configuration. It does **not** contain an Android OAuth client for the
Google Play app-signing SHA-1
`25:EC:6C:50:C2:81:98:1E:59:A7:9F:29:23:CA:E1:B6:DA:04:34:9D`.

`google-services.json` is Firebase/Google Auth configuration. It does not prove
that either Android OAuth client is linked as a Play Games Services credential.
Google states that creating a Cloud OAuth client alone is insufficient; it
must also be linked to the game as a Play Games credential.

## Most likely Play Games cause

The SDK, manifest APP_ID and leaderboard ID are structurally correct. A Play
Games launch banner proves the SDK started, but does not prove that the
installed package/signature is authorized or the account can access the
unpublished game configuration.

The most likely unresolved cause is Play Console rollout configuration, in
this order:

1. The direct/upload Android OAuth client exists in Firebase/Google Cloud but
   is not linked as a Play Games Services Android credential.
2. The phone's Google account is not individually allowlisted as a Play Games
   tester, and the relevant test track is not enabled for Play Games testing.
3. The leaderboard or recent Play Games configuration remains draft/unpublished
   to testers.
4. The Play app-signing credential is missing, which will affect the later
   Play-delivered build even if the direct-signed APK is fixed.

The exact current states of credentials, tester access, leaderboard publishing
and Play Games publishing are **not verifiable from GitHub**. They require the
owner's authenticated Play Console. No assumptions have been recorded as fact.

## Play Console click-by-click verification

Do not publish a production app release.

1. Open Google Play Console and select **WILDCARD**.
2. Open **Grow users > Play Games Services > Setup and management > Configuration**.
3. Confirm the linked Cloud project is `wildcard-31d50` / `420107184674`.
4. Under **Credentials**, confirm two Android credentials exist for package
   `com.nisarg.wildcard`:
   - direct/upload SHA-1 `E0:5C:17:94:91:AC:EE:68:9A:A1:E0:3A:63:D9:79:DE:D9:5B:05:C0`;
   - Play app-signing SHA-1 `25:EC:6C:50:C2:81:98:1E:59:A7:9F:29:23:CA:E1:B6:DA:04:34:9D`.
5. If either is missing, choose **Add credential > Android**. Create or select
   the Android OAuth client with the exact package and SHA-1, return to Play
   Console, select that client, and save the credential. Do not create a web
   client for the Play Games Android credential.
6. Open **Setup and management > Testers**. On the individual testers tab, add
   the exact Google account used by Play Games on the POCO X7. Allow propagation
   time. On **Release tracks**, add **Internal testing** when that track exists.
7. Open the Play Games **Leaderboards** page and select **WILDCARD High Score**.
   Confirm the resource ID is `CgkIotTbgp0MEAIQAQ` and that the leaderboard is
   available to the test configuration.
8. Use the Play Games Services publishing/review page to publish the saved game
   service changes to testers. This is separate from publishing a production
   app release.
9. In Google Cloud Console for `wildcard-31d50`, confirm the OAuth consent
   screen is published or the phone account is an authorized OAuth tester.

## Firebase click-by-click verification

1. Firebase Console > `wildcard-31d50` > **Project settings > General**.
2. Select Android app `com.nisarg.wildcard`.
3. Confirm both SHA-1 fingerprints are registered. Add the Play app-signing
   SHA-1 if absent, then download a fresh `google-services.json`. Home Codex
   should compare and commit the refreshed file without exposing unrelated
   account data.
4. **Build > Authentication > Sign-in method**: confirm Google is enabled and
   the support email is correct.
5. **Build > Firestore Database > Rules**: confirm the deployed rules match
   `firestore.rules`. The allowed client document remains
   `users/{auth.uid}/saves/main`; collection listing, deletes and other paths
   remain denied.
6. **Build > Firestore Database > Data**: after the owner completes the account
   chooser on the phone, confirm exactly one owner-scoped save document exists
   and contains the expected `uid`, schema/app versions, JSON strings,
   `clientSavedAt` and server `updatedAt`. Do not paste the save into a public PR.
7. **Build > App Check**: confirm the Android app is registered with Play
   Integrity and the required SHA-256 certificates are registered. Keep
   Firestore enforcement **off** until the Play-installed Internal testing
   build succeeds. A direct sideload is not normally `PLAY_RECOGNIZED`.
8. Play Console > **App integrity > Play Integrity API**: confirm the linked
   Cloud project is `wildcard-31d50`.

## Code review and focused repair

### `WildcardCloudPlugin.java`

Firebase sign-in and Firestore ownership are separated correctly from Play
Games sign-in. The cloud save uses the authenticated UID and a fixed document.
The confirmed defect was observability: Play Games exceptions were converted
to free-form generic rejections, losing documented `ApiException` status codes.

The focused repair now returns only safe fields: operation, numeric status,
documented status name, broad category and retryability. It never returns an
ID token, access token, player ID, email, profile data or exception message to
the diagnostics UI.

### `MainActivity.java`

The GitHub v6.9 file only registers the plugin. The immersive/safe-area v6.9.1
implementation described by the phone handoff is absent, so it cannot be
reviewed here. Do not replace the home v6.9.1 file with this older one.

### `www/native-bridge.js`

The bridge passes Cloud plugin promises through without exposing tokens. The
generic error was swallowed later in `www/index.html`, not in this wrapper.
No bridge change was required. Phone Preferences remain the local-save
backstop and native purchasing continues to fail closed.

### Official leaderboard UI

The old catch block displayed the same message for every error. It now retains
the safe `PGS_*` code and maps configuration, tester/licensing, consent,
network and service failures to useful player/developer guidance. The Settings
row displays the last non-OK code. This does not change scoring or submissions.

## Cloud merge and Rules review

- Guest/local play does not depend on Firebase.
- Sign-in reads the cloud document before any write.
- A cache miss while offline does not trigger a blind overwrite.
- First-link reconciliation uses maxima/unions for earned progress and keeps
  phone preferences; it does not sum currencies and create duplication.
- Repeat sync for the same UID chooses the newer complete checkpoints.
- The current run remains phone-backed through localStorage and Android
  Preferences; signing out retains it.
- Firestore Rules enforce authenticated ownership, fixed document ID, strict
  fields/types/sizes, server timestamp, no deletes and recursive deny.
- App Check is initialized but enforcement must remain off through sideload
  testing to keep guest play and the existing phone save safe.

## Artwork and browser playtest

Five 900 x 1600 WebP backgrounds are wired into presentation-only screen
states: the default-theme main menu, THE HOUSE, default-theme shop, Royal
Vault and victory/Endless. Existing purchased theme backgrounds continue to
take precedence. Each file is under 300 KB. Three additional Sly/Joker concept sheets are committed under
`artwork/concepts/`; they require background removal and sprite cropping before
runtime use.

The work-laptop launcher is `playtest/wildcard-work-laptop.html`. It loads the
canonical source rather than duplicating it. Gameplay features work in a
desktop browser; Android-only sign-in, Play Games, ads, billing, haptics and
immersive mode cannot be tested there.

## Verification run on this laptop

- `npm test`: passed; two game scripts compiled, 140 unique HTML IDs checked,
  cloud/rules/chest/mission/artwork assertions passed, zero failures.
- `npm run audit:google`: passed all repository-verifiable identifier checks;
  reported the missing Play app-signing SHA-1 in `google-services.json` and the
  v6.9 versus v6.9.1 source mismatch as warnings.
- Full `node tools/deep-sim-v57.js`: 50,000 scoring cases, 15,000 Cheat cases
  and 2,600 complete runs; zero data failures, hook exceptions, invariant
  failures or Cheat mismatches. The generated report is committed under
  `docs/release/`.
- `git diff --check`: passed.
- Firestore emulator tests were not rerun because Firebase CLI and installed
  Node dependencies are not available on this work environment. The existing
  repository report says 19 passed, but this audit does not present that as a
  fresh run.

No Android compile, APK/AAB build, emulator, browser screenshot or phone test
was performed.

## Exact remaining steps for home Codex

1. Push or recover the phone-validated v6.9.1 source and logs; preserve the
   exported save state (5,042 coins, best score 1,500, best Heat 6, 13 Jokers,
   31 cosmetics, 14 achievements, no active run).
2. Rebase or cherry-pick the focused work-laptop commit onto v6.9.1 and resolve
   only genuine overlap in `www/index.html`/`WildcardCloudPlugin.java`.
3. Run the repository verification, scoring/Cheat/full-run simulations,
   Firestore Rules tests and 375 px layout audit again.
4. Sync Android assets, confirm canonical/embedded HTML SHA-256 equality, then
   rebuild and sign a new AAB at home. The work-laptop audit is not build proof.
5. Upload to **Internal testing**, not production, and enable that track in
   Play Games Services Testers.
6. On the phone, complete the Firebase Google account chooser and confirm the
   local save does not reset.
7. Verify `users/{uid}/saves/main` in Firestore before relying on cloud restore.
8. Verify Play Games authentication and daily, weekly and all-time views; use
   the new `PGS_*` code if any step fails.
9. Only after the exported save and/or Firestore backup is verified should the
   owner consider uninstalling the direct-signed APK to move to the differently
   signed Play build.

Owner blockers: authenticated Play/Firebase Console inspection, the missing
v6.9.1 source/logs, home signing/build tools, the phone account chooser, and
physical ranking validation.
