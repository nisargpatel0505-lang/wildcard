# WILDCARD working rules

- Treat `www/index.html` as the canonical game source. Do not edit the generated copy under `android/app/src/main/assets/public/`.
- The shipped APK must embed a byte-identical copy of `www/index.html`; verify both SHA-256 hashes before publishing.
- Run the v6.8 deterministic simulation after scoring, joker, mission, save, chest, or reward changes.
- Test at a 375px mobile viewport and on a physical Android phone. Any horizontal overflow is a release blocker.
- Run `npm run sync:android` before every Android build.
- Increment Android `versionCode` for every installable update. Keep `versionName` aligned with the public release label.
- Never commit `wildcard-release.keystore`, `keystore-password.txt`, `android/local.properties`, build output, or local logs.
- Firebase AI Logic must not be enabled without App Check, authenticated-user controls, budgets/quotas, and a specific reviewed game feature.
- Deploy the Pi with `deploy/update-pi.sh`; do not overwrite its analytics injection by copying directly to the webroot.

