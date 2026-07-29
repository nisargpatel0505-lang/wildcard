# WILDCARD v8.5.1 build evidence

Build: `8.5.1+65`

Package: `com.nisarg.wildcard`

## Public Google Play bundle

- File: `WILDCARD-v8.5.1-code65-closed-alpha.aab`
- Size: `81,602,527` bytes
- SHA-256:
  `806e71e6dbbd04b8bfdb7e9c36bf4d26e0fa95d23b1bab1717e4a18eb727b7fe`
- Build command:
  `flutter build appbundle --release --build-name=8.5.1 --build-number=65`
- Target SDK: `36`
- AdMob application ID:
  `ca-app-pub-3855192091371080~7622357185` (production)
- The owner build flag was not supplied. DEV ×20 and developer-only runtime
  access are excluded from this artifact.

## Owner phone APK

- File: `WILDCARD-v8.5.1-code65-owner-profile.apk`
- Size: `107,969,086` bytes
- SHA-256:
  `adf175c6b0a44bd111c208aba07b3e8f6b35fdd5e2a3e85ada65ad19d85f7d26`
- Build command:
  `flutter build apk --profile --build-name=8.5.1 --build-number=65
  --dart-define=WILDCARD_OWNER_BUILD=true`
- AdMob application ID:
  `ca-app-pub-3940256099942544~3347511713` (Google test ads)
- DEV ×20 is compiled into this owner-only profile artifact.
- The APK is signed by the existing WILDCARD release certificate:
  `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.

## Verification

- `flutter analyze`: no issues.
- Focused release suite: `127` tests passed.
- Owner build-gate test with `WILDCARD_OWNER_BUILD=true`: passed.
- Royal Vault visual goldens: `10` captures passed.
- APK package/version inspection: `com.nisarg.wildcard`, `8.5.1`, code `65`.
- APK Signature Scheme v2 verification: passed.
- Release AAB JAR signature verification: passed.
- Release manifest inspection confirmed version code `65`, target SDK `36`
  and the production AdMob application ID.

The phone was not visible to Windows ADB at build time. The owner APK is ready
for an in-place `adb install -r -t` as soon as the device reconnects; uninstalling
is not required and would risk the local save.
