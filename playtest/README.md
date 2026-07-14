# Work-laptop playtest

## Single-file version

Open `WILDCARD-work-laptop-standalone.html` directly in Chrome or Edge. It is
the complete game in one HTML file, including the five new room backgrounds.
No folder structure or local server is required.

The standalone file is generated from the canonical game with:

```text
npm run build:standalone
```

Do not edit the generated standalone file directly; change `www/index.html`
and regenerate it so the two versions cannot silently drift.

## Canonical-source launcher

This launcher always opens the canonical `www/index.html`, so it cannot drift
from the branch being reviewed.

## Fastest option

1. On GitHub, choose **Code > Download ZIP** for this branch.
2. Extract the ZIP.
3. Open `playtest/wildcard-work-laptop.html` in Chrome or Edge.

For consistent browser storage, run a local server with software already
present on most work laptops:

```text
python -m http.server 8080
```

Then open:

```text
http://localhost:8080/playtest/wildcard-work-laptop.html
```

Gameplay, tutorial, Jokers, shops, missions, chests, cosmetics, victory and
Endless Mode are available. Android-only features—Google account chooser,
Firestore native bridge, Play Games, ads, billing, haptics and immersive
system bars—cannot be validated in a desktop browser and intentionally fail
soft or remain hidden.
