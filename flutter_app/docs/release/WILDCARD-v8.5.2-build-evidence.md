# WILDCARD v8.5.2 Build Evidence

## Android artifact

- File: `WILDCARD-v8.5.2-code66-owner-profile-suit-themes.apk`
- Build mode: Flutter profile, owner features enabled.
- Size: `115,533,419` bytes (`110.18 MiB`).
- SHA-256:
  `A810566379D70197B1CE69C707722B6B657C8D344EBB472E4FF859B92B414A01`

## Commands and results

```text
flutter analyze
No issues found.

flutter test <theme/table/Sly/Vault focused suite>
89 tests passed.

flutter build apk --profile --build-name=8.5.2 --build-number=66 \
  --dart-define=WILDCARD_OWNER_BUILD=true
Built app-profile.apk (110.2MB).

adb install -r -t -g WILDCARD-v8.5.2-code66-owner-profile-suit-themes.apk
Success
```

## Device verification

```text
Package: com.nisarg.wildcard
Activity: com.nisarg.wildcard/.MainActivity
versionName: 8.5.2
versionCode: 66
Device: 24095PCADG
Android: 16
Cold launch: successful
```

## Visual evidence

- `docs/release/WILDCARD-v8.5.2-device-home-iron.png`
- `docs/release/WILDCARD-v8.5.2-device-home-crimson.png`
- `docs/release/WILDCARD-v8.5.2-suit-theme-preview.jpg`
