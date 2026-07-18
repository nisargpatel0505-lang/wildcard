# WILDCARD v6.9.10

## Daily Board connection fix

- Fixed Android's Daily Board appearing unreachable. Capacitor reports its WebView host as `localhost`; the old resolver mistakenly sent `/api/daily` to the local app origin instead of the live Pi API.
- Native builds now use the absolute Daily Board endpoint. Pi hosting remains same-origin, while local browser and file previews remain safely isolated.
- The verifier covers native localhost, desktop localhost/file, Pi-hosted, and external-web routing separately.
- A completed Daily score can now be reopened from the Daily Board, so a failed post can be retried after reconnecting or updating the app.

## Sly's Stake Contract

- Locked contracts now show only **Locked**, with no unlock condition, payout, or mechanic details.
- Unlocked contracts explain the system in three numbered steps.
- Players below the 40-coin minimum see the unlocked contract with a funding message instead of a misleading locked state.

## Mobile navigation

- Secondary-screen Back controls are pinned to the top-left safe area, including display cutouts and status-bar insets.
- Removed the duplicate Start Boost footer Back button.
- The home-screen layout, actions, artwork, and spacing remain unchanged apart from the v6.9.10 label.

## Scoring pacing

- Normal scoring is 4% more deliberate (`1.00` to `1.04`) without restoring the previous lag.
- Fast remains `0.55`; the optimized individual beats and unscaled result transitions are unchanged.
- A representative five-card/two-Joker Heat clear changes from approximately 3.160 seconds to 3.262 seconds and remains about 47% faster than the v6.9.8 regression.
- Win FX remains fully removed from gameplay.

## Android compatibility and save safety

- Version: **6.9.10**
- Google Play release: **version code 29**
- Local developer build: **version code 28**
- Both variants retain the existing signing identity and save schema. The developer build updates the current phone install in place; Play code 29 stays higher so a later Play-delivered build can replace it without an uninstall or data clear.

## Privacy-minimised Pi analytics

- Added three coarse internal-test counters: app open, run start and run end.
- Run events include only mode; run ends add outcome and a broad Heat band. Normal and Endless remain one lifecycle, Gauntlet completion is deduplicated, and replacing a saved run records a termination.
- The phone keeps only a bounded in-memory queue. A sub-kilobyte `fetch` is attempted while idle/backgrounded with `keepalive`, no credentials and no referrer; gameplay never awaits it and offline failures are discarded.
- The Pi validates a strict version/event schema and stores only marginal daily totals in a mode-0600 JSON file. It has no public analytics read endpoint and accepts no name, account/install/session/device ID, cards, Jokers, coins, save data or exact score.
- Added identifier-free request and daily caps, fixed-version dimensions, actual UTC cutoff pruning on successful writes, corruption fail-closed behavior, atomic/fsynced storage, a private SSH report command, matching privacy disclosures and regression tests.
- The Pi update script now verifies candidate Python, backs up code/state, requires a new service PID plus health marker, rolls back on failure, and refuses APK/AAB files whose embedded HTML differs from the canonical source.

## Verification

- Responsive browser check at 390 x 844: one 44 x 44 Back button at x/y 7 px, no horizontal overflow, and the locked contract contains only `Locked`.
- `npm test`: scripts compiled, 147 HTML IDs remained unique, standalone/Android provenance passed, the Pi analytics privacy/retention/cap/corruption tests passed, and the Daily Board, contract, safe-area Back, and pacing assertions passed.
- Release APK and AAB embed the canonical HTML SHA-256 exactly; both contain the analytics client and exclude developer controls. APK v2 signatures and the AAB JAR signature verify under the existing release identity (`c3c281d1…`).
- `npm run test:economy-rewards`: passed.
- `npm run test:native-ads`: passed.
- Full v6.9.10 simulation: 50,000 scoring/Joker cases, 15,000 Cheat comparisons, and 2,600 complete runs with zero data failures, hook errors, invariant failures, or Cheat mismatches.
- Source HTML SHA-256: `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`
- Release APK SHA-256: `e02eb3b5e6e360c8571e121a8376353221a4f15039a46c21656cbf77b6e40782`
- Release AAB SHA-256: `2917dc42f60b9cdd947300f6a204151aad0dbabefb95c7be208b2d83f9d986e8`
- Developer APK SHA-256: `a86fb4104a57593d2d9b562392237d48174ad0eb9bed74f857d6c495dd57748c`
