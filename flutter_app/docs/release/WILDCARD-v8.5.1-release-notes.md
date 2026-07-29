# WILDCARD v8.5.1 release notes

Version: `8.5.1+65`

## Player-facing changes

- Improved readability of modifier-disabled card badges (`0` and `OFF`).
- Increased the smallest Royal Vault reward labels for a clearer chest reveal.
- Improved small labels across the shop, deck view, Joker collection, Vault,
  Cabinet, home menu, run table and loading screen.
- Removed the unfinished Arcade mode and retained Normal, Daily and Gauntlet.

## Release safety

- The Play Store bundle remains a production release build with developer tools
  excluded.
- The owner's sideloaded profile APK keeps local developer access, restores the
  owner-only DEV ×20 card through a compile-time flag, and uses Google test ads.
- The Play AAB is built without the owner flag; the DEV ×20 card is absent from
  the public catalogue, chest odds, shops, saves and runtime selection.
- The package identity remains `com.nisarg.wildcard`.
- The release AdMob application and ad-unit IDs remain the production IDs.

## Google Play release text

Improved small-text readability throughout WILDCARD, made modifier-disabled
cards clearer, polished Royal Vault reward labels, and removed the unfinished
Arcade mode.
