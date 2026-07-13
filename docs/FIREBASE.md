# Firebase connection

The Android app `com.nisarg.wildcard` is registered in Firebase project `wildcard-31d50` as app ID `1:420107184674:android:d1249c53cbde7160c2387b`.

The release signing certificate SHA-256 registered with Firebase is:

`C3:C2:81:D1:47:0A:EB:F2:D9:96:56:22:1A:DA:78:15:C6:B8:73:F4:E8:A7:48:D7:28:4F:5F:AE:5D:76:47:17`

`android/app/google-services.json` is installed and the Google Services Gradle task runs during release builds. Firebase describes this file as project/app identifiers rather than an authorization secret.

Firebase AI Logic is deliberately not enabled yet. Before adding any Gemini-powered game feature, complete these controls:

1. Define the exact player-facing feature and its data flow.
2. Configure App Check with Play Integrity for the Android distribution model.
3. Restrict the Firebase API key to only the APIs and Android app that need it.
4. Require authenticated users for AI calls.
5. Configure quotas, spend alerts, monitoring, and Remote Config for model selection.
6. Review prompts, safety behavior, privacy disclosure, and failure fallbacks.

SQL Connect/Data Connect, Firestore, Analytics, Crashlytics, Auth, and Hosting are not enabled merely by registering the app.

