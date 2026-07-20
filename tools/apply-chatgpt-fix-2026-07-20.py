#!/usr/bin/env python3
"""Apply the isolated ChatGPT 5.6 WILDCARD balance patch deterministically.

The branch keeps the production v6.9.14 HTML unchanged in git. CI and local
reviewers apply the compressed, source-controlled patch before tests and APK
packaging. The operation is idempotent and refuses unknown source states.
"""

from __future__ import annotations

import base64
import gzip
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import NoReturn

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "www" / "index.html"
PATCH_B64 = ROOT / "patches" / "chatgpt-5.6-fix-2026-07-20.patch.gz.b64"
BASELINE_SHA256 = "b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b"
PATCHED_SHA256 = "5cf29ef723d0f4e4e5035d46af0515e52bdc196858aa044c19d39b0e15c72835"
PATCH_SHA256 = "4024c3edf4cfcbc685103061469f1e08c1257aecb9e078fda4250b62466ac4d4"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def fail(message: str) -> NoReturn:
    print(f"ChatGPT fix patch error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not SOURCE.is_file():
        fail(f"missing source file: {SOURCE.relative_to(ROOT)}")
    if not PATCH_B64.is_file():
        fail(f"missing patch payload: {PATCH_B64.relative_to(ROOT)}")

    before = sha256(SOURCE)
    if before == PATCHED_SHA256:
        print(f"ChatGPT fix already applied: {PATCHED_SHA256}")
        return
    if before != BASELINE_SHA256:
        fail(
            "unsupported www/index.html state; expected v6.9.14 baseline "
            f"{BASELINE_SHA256}, found {before}"
        )

    try:
        patch = gzip.decompress(base64.b64decode(PATCH_B64.read_text().strip(), validate=True))
    except Exception as exc:
        fail(f"invalid compressed patch payload: {exc}")
    if sha256_bytes(patch) != PATCH_SHA256:
        fail("compressed patch payload hash mismatch")

    with tempfile.NamedTemporaryFile(prefix="wildcard-chatgpt-fix-", suffix=".patch", delete=False) as tmp:
        tmp.write(patch)
        patch_path = Path(tmp.name)
    try:
        check = subprocess.run(
            ["git", "apply", "--check", str(patch_path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if check.returncode != 0:
            fail((check.stderr or check.stdout or "git apply --check failed").strip())

        applied = subprocess.run(
            ["git", "apply", "--whitespace=nowarn", str(patch_path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if applied.returncode != 0:
            fail((applied.stderr or applied.stdout or "git apply failed").strip())
    finally:
        patch_path.unlink(missing_ok=True)

    after = sha256(SOURCE)
    if after != PATCHED_SHA256:
        fail(
            "post-apply source hash mismatch; expected "
            f"{PATCHED_SHA256}, found {after}"
        )
    print(f"Applied ChatGPT 5.6 fix: {after}")


if __name__ == "__main__":
    main()
