#!/usr/bin/env python3
"""Host compile+marshal bridge for jac-python oracle tests.

Invoked as a subprocess so host_oracle does not rely on the fused jac
interpreter's embedded CPython (which can lag the pinned 3.14.6 oracle).
"""

from __future__ import annotations

import marshal
import os
import shutil
import subprocess
import sys
from pathlib import Path

CPYTHON_PIN = "3.14.6"
CPYTHON_MINOR = "3.14"


def _python_version(exe: Path) -> str:
    proc = subprocess.run(
        [
            str(exe),
            "-c",
            "import sys; print('.'.join(str(x) for x in sys.version_info[:3]))",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


def resolve_cpython() -> Path:
    env_override = os.environ.get("JACPYTHON_CPYTHON")
    if env_override:
        candidate = Path(env_override)
        if candidate.is_file() and _python_version(candidate) == CPYTHON_PIN:
            return candidate
        raise RuntimeError(
            f"JACPYTHON_CPYTHON={env_override!r} is not CPython {CPYTHON_PIN}"
        )

    candidates: list[Path] = []
    exe = Path(sys.executable)
    if exe.name.startswith("python"):
        candidates.append(exe)
    which_minor = shutil.which(f"python{CPYTHON_MINOR}")
    if which_minor:
        candidates.append(Path(which_minor))
    which_py3 = shutil.which("python3")
    if which_py3:
        candidates.append(Path(which_py3))

    roots: list[Path] = [Path.cwd()]
    walk = Path.cwd()
    for _ in range(6):
        if walk not in roots:
            roots.append(walk)
        if walk.parent == walk:
            break
        walk = walk.parent

    for root in roots:
        candidates.append(root / ".venv" / "bin" / f"python{CPYTHON_MINOR}")
        candidates.append(
            root / "jac" / ".pbs-build" / "install" / "bin" / f"python{CPYTHON_MINOR}"
        )

    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen or not candidate.is_file():
            continue
        seen.add(candidate)
        if _python_version(candidate) == CPYTHON_PIN:
            return candidate

    raise RuntimeError(
        f"pinned CPython {CPYTHON_PIN} not found for host oracle "
        f"(set JACPYTHON_CPYTHON or install .venv/bin/python{CPYTHON_MINOR})"
    )


def compile_marshal(source: str, filename: str, mode: str, optimize: int = 0) -> bytes:
    py = resolve_cpython()
    script = (
        "import marshal, sys\n"
        "source = sys.stdin.read()\n"
        "filename = sys.argv[1]\n"
        "mode = sys.argv[2]\n"
        "optimize = int(sys.argv[3])\n"
        "sys.stdout.buffer.write(\n"
        "    marshal.dumps(compile(source, filename, mode, optimize=optimize))\n"
        ")\n"
    )
    payload = source.encode("utf-8")
    proc = subprocess.run(
        [str(py), "-c", script, filename, mode, str(optimize)],
        input=payload,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: host_compile_marshal_bridge.py <filename> <mode> <optimize>")
    filename, mode, optimize_s = sys.argv[1:4]
    sys.stdout.buffer.write(
        compile_marshal(sys.stdin.read(), filename, mode, int(optimize_s))
    )


if __name__ == "__main__":
    main()
