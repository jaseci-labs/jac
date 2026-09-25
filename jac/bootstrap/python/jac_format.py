"""Format generated Jac the way `jac fmt` does, so CI's format check and the
generators' own --check agree on the committed text."""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def format_jac(text: str, target: Path) -> str:
    """Format `text` as `jac fmt --lintfix` would format it at `target`: the
    scratch file sits beside the target so the project's jac.toml applies."""
    jac = shutil.which("jac")
    if jac is None:
        sys.exit("jac is not on PATH; generated Jac is formatted with `jac fmt`")
    target.parent.mkdir(parents=True, exist_ok=True)
    handle, name = tempfile.mkstemp(prefix=".gen_", suffix=".jac", dir=target.parent)
    os.close(handle)
    path = Path(name)
    try:
        path.write_text(text)
        # One pass is not always a fixed point (a second adds blank lines).
        for _ in range(3):
            before = path.read_text()
            result = subprocess.run(
                [jac, "fmt", "--lintfix", str(path)], capture_output=True, text=True, env=os.environ
            )
            if result.returncode != 0:
                sys.exit(f"jac fmt failed on generated Jac:\n{result.stdout}{result.stderr}")
            if path.read_text() == before:
                break
        return path.read_text()
    finally:
        path.unlink(missing_ok=True)
