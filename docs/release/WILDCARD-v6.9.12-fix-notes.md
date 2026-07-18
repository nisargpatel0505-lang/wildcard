# WILDCARD v6.9.12

## Release intent

v6.9.12 softens Joker feedback, gives Endless a three-Heat modifier cadence, and replaces the old Heat-12 victory beat with a short full-screen Sly cinematic followed by one ad attempt and a clear Continue/End choice.

## Joker feedback

- Removed the moving `TRIGGER` chip, hard cream outline, white-name flash, lift, and scale effect.
- A triggering Joker now receives a short, stationary rarity-coloured glow.
- The floating label shows only the effect, such as `+0.20 Mult`.
- The live status line names the Joker and its effect.
- Normal holds the readable cue for 460 ms and its text for 650 ms; Fast uses 220 ms and 400 ms.
- Reduced-motion mode keeps the text readable and uses a static glow.

## Endless modifiers

- Standard remains unchanged: modifiers at Heats 3, 6 and 9, then THE HOUSE at Heat 12.
- Endless modifiers now appear at Heats 15, 18, 21 and every third Heat after that.
- Gauntlet remains unchanged: a modifier every Heat with its boss at Heat 8.
- Mode-picker and victory copy now explain the three-Heat Endless cadence.

## Heat-12 victory sequence

- Clearing the standard game saves its rewards and a win-complete checkpoint before presentation begins.
- A full-screen 2.4-second, 720×1600 Sly single-tear cinematic plays from `www/assets/video/sly-single-tear.mp4`.
- The video is H.264 Main Profile, Level 4.0, YUV420p, muted, fast-start optimized, and 172,311 bytes.
- The app then attempts exactly one fail-safe interstitial.
- The choice screen presents `Continue → Endless` and `End Run · Bank Score` above the phone fold.
- Video errors, rejected playback, ad unavailability, ad failure, and timeout all fail open to the choice.
- Resuming a completed Heat-12 checkpoint goes directly to the choice without replaying the video or ad.
- Ending the run cannot show a second interstitial.
- Daily uses the cinematic and one ad attempt, then settles directly; it cannot enter Endless or create a standard win checkpoint.
- Gauntlet keeps its separate victory flow.

## Offline and deployment

- The cinematic is embedded byte-for-byte in the standalone work-laptop HTML.
- The service worker serves cached MP4 Range requests with correct `206`, `Content-Range`, and `416` behavior without intercepting unrelated ranged downloads.
- Pi deployment now publishes the video asset alongside the game.
- Pi aggregate analytics accepts v6.9.12 while retaining its identifier-free, aggregate-only contract.

## Verification

- Canonical HTML SHA-256: `6585cb1976fe44bfbaf49a4aca310d512fbca008392dfc83ff89077f7256f75c`
- Cinematic SHA-256: `60bacecf276171a49fe6eacedf2640959cfb4bc008df75eecf11f338a62cb62f`
- 10,000 scoring/Joker cases passed
- 5,000 Cheat comparisons passed with zero mismatches
- 550 complete runs passed with zero data, hook, or invariant failures
- Executable Heat-12 tests passed for ended/error, ad failure/timeout, no-ads, resume, End Run, Continue Endless, and Daily
- Native rewarded/interstitial-ad and Billing callback tests passed
- Service-worker MP4 Range behavior tests passed
- Economy/reward idempotency tests passed
- Pi analytics privacy and aggregation tests passed
- Google/Firebase repository configuration audit passed with no failures or warnings
- Desktop Chromium decoded the final MP4 with `readyState=4`, duration 2.4, and 720×1600 video dimensions
- POCO X7 in-place install passed; Android kept the original first-install timestamp and the saved Best Heat 20/balance loaded after the update

## Android artifacts

- Developer APK: `releases/WILDCARD-v6.9.12-developer.apk` — SHA-256 `df7ece7c6126acd9806bd051092e056f59f1bc45437c1b46d6b0dddfe18960b1` — version code 31
- Release APK: `releases/WILDCARD-v6.9.12.apk` — SHA-256 `7eb6c488441e005c4121d356c76944654f72ad85edb69d2d96ad63c40bcdd5d2` — version code 32
- Release AAB: `releases/WILDCARD-v6.9.12.aab` — SHA-256 `0bd24f97628514680726942acd7c5f1370b303a1ecbe1aa2bd3f016e578bc581` — version code 32
- Release certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`

The release APK/AAB are signed locally. Uploading the AAB to Play Console and deploying the APK/PWA to the Pi remain separate explicit release actions.
