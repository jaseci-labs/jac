#!/usr/bin/env bash
set -euo pipefail
# This identity is needed before Jac is built. Reuse the bootstrap input manifest.
exec python3 - "$0" <<'PYTHON'
from __future__ import annotations

import hashlib
import runpy
import subprocess
from pathlib import Path
import sys

manifest = runpy.run_path(
    str(Path(sys.argv[1]).resolve().parents[1] / "jac/jaclang/bootstrap_manifest.py")
)
is_compiler_input = manifest["is_compiler_input"]


def tracked(*paths: str) -> list[bytes]:
    return subprocess.check_output(
        ["git", "ls-tree", "-r", "-z", "HEAD", "--", *paths]
    ).split(b"\0")[:-1]


def fingerprint(records: list[bytes]) -> str:
    return hashlib.sha256(b"\0".join(sorted(records))).hexdigest()


scopes = {
    "binary": ("jac.toml", "jac/examples/jaclang_org", "jac/jaclang", "jac/build.zig",
               "jac/build.zig.zon", "jac/launcher", "jac/bootstrap", "jac/native",
               "jac/sitecustomize.py", "jac/_jac_finder.py"),
    "package": ("jac/jaclang",),
    "python": ("jac/bootstrap", "jac/jaclang", "jac/build.zig", "jac/build.zig.zon", "jac/native"),
    "layers": ("jac/launcher", "jac/bootstrap", "jac/build.zig", "jac/build.zig.zon",
               "jac/native", "jac/jaclang/dist/payload", "jac/jaclang/client/bun_installer.jac",
               "jac/jaclang/compiler/backends/native/wasm_rt"),
}
for name, paths in scopes.items():
    print(f"{name}={fingerprint(tracked(*paths))}")

compiler = [
    record for record in tracked("jac/jaclang")
    if is_compiler_input(record.split(b"\t", 1)[1].decode()[len("jac/jaclang/"):])
]
if not compiler:
    raise SystemExit("Compiler input set is empty")
print(f"compiler={fingerprint(compiler)[:16]}")

PYTHON
