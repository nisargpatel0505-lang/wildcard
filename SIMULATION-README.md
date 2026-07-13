# WILDCARD v5.9 Source and Simulation Bundle

This is a source-analysis bundle, not an APK. It is intended for reviewing the
game with Claude, ChatGPT, Codex, or another coding assistant and for rerunning
the automated simulations.

## Important files

- `www/index.html`: main game UI, rules, Jokers, scoring, shops, and persistence.
- `www/native-bridge.js`: Android bridge for ads, billing, preferences, and haptics.
- `tools/deep-sim-v57.js`: scoring and full-run simulation harness. The filename is
  retained for compatibility; it detects the current game version automatically.
- `reports/`: the latest v5.9 machine-readable results and Markdown report.
- `android-source/`: selected Android wrapper source and configuration. Signing
  keys, passwords, local SDK paths, generated builds, and dependencies are omitted.

## Run the simulations

Install a current Node.js release, open a terminal in this folder, then run:

### Quick audit

PowerShell:

```powershell
$env:SIM_QUICK='1'
node tools/deep-sim-v57.js
```

macOS or Linux:

```bash
SIM_QUICK=1 node tools/deep-sim-v57.js
```

### Full audit

```bash
node tools/deep-sim-v57.js
```

The harness checks randomized scoring, Joker hooks, The Cheat's six-card subset
selection, Frostbite behavior, deck and currency invariants, and complete-run
cohorts. It writes a JSON result and Markdown report to the user's Downloads
folder.

## Safety

This bundle intentionally contains no Android signing key, keystore password,
Wi-Fi credentials, email credentials, or private build output.
