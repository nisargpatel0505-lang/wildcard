#!/usr/bin/env python3
"""Apply the isolated 20 July 2026 WILDCARD balance hotfix.

The patch is intentionally branch-local. It modifies only www/index.html and is
idempotent so test/build commands can call it safely.
"""
from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "www" / "index.html"
PATCH = ROOT / "patches" / "chatgpt-5.6-fix-2026-07-20.patch"
BASE_SHA256 = "b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b"
PATCHED_SHA256 = "fb10cbc090e35296ece6de3c84d94100538de80fb7782f1ef54e67da1284944a"
MARKER = "const CHATGPT_FIX_2026_07_20 = true;"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if not HTML.is_file():
        raise SystemExit(f"Missing canonical game source: {HTML}")
    if not PATCH.is_file():
        raise SystemExit(f"Missing hotfix patch: {PATCH}")

    text = HTML.read_text(encoding="utf-8")
    current = sha256(HTML)
    if MARKER in text:
        if current != PATCHED_SHA256:
            raise SystemExit(
                "Hotfix marker exists but the canonical source hash is unexpected: "
                f"{current}"
            )
        print(f"ChatGPT 5.6 hotfix already applied: {current}")
        return

    if current != BASE_SHA256:
        raise SystemExit(
            "Refusing to patch an unknown www/index.html. "
            f"Expected {BASE_SHA256}, got {current}."
        )

    subprocess.run(
        ["git", "apply", "--check", str(PATCH)],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(
        ["git", "apply", str(PATCH)],
        cwd=ROOT,
        check=True,
    )

    final = sha256(HTML)
    if final != PATCHED_SHA256 or MARKER not in HTML.read_text(encoding="utf-8"):
        raise SystemExit(
            "Patch completed but verification failed. "
            f"Expected {PATCHED_SHA256}, got {final}."
        )
    print(f"Applied ChatGPT 5.6 balance hotfix: {final}")


if __name__ == "__main__":
    main()
