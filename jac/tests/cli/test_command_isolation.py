"""Selected-command import isolation guard.

The lazy-dispatch contract (PLAN.md Priority 0 "Eliminate command-package
fan-out") requires that loading a selected command's handler imports only its
owning command module (plus documented shared helpers) -- not the entire
``jaclang.cli.commands`` registration set.

Historically ``commands/__init__.jac`` imported every registration module, so
importing any one handler (e.g. ``jaclang.cli.commands.execution``) eagerly
pulled in all ~15 siblings. That package-init fan-out is now gone; this test
keeps it gone.

Each command is exercised in a fresh subprocess so ``sys.modules`` caching
cannot mask leakage across cases. We measure modules imported by
``load_handler(name)`` alone (no handler execution), because cross-command
imports inside handlers are intentionally local/deferred and must not fire at
load time.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
JAC_ROOT = REPO / "jac"

# The authoritative core registration modules (must match the
# _CORE_REGISTRATION_MODULES list in jaclang/cli/registry.jac). Loading any
# single command must not import registration modules outside this command's
# owning module.
REGISTRATION_SHORT = {
    "execution",
    "analysis",
    "build",
    "transform",
    "project",
    "guide",
    "eject",
    "tools",
    "config",
    "db",
    "nacompile",
    "ai",
    "code",
    "browse",
}

# Non-registration helper modules that may be shared across commands without
# indicating fan-out.
ALLOWED_SHARED = {"cli_helpers", "eject_targets"}

# Commands representative of every family: core runtime (run), compiler
# analysis (check), config/filesystem (config), pure tool (guide), client
# (build), and a hidden tool command (dot -> tools).
TARGET_COMMANDS = ["run", "check", "config", "guide", "build", "dot"]

_PROBE_SINGLE = (
    "import sys, json\n"
    f"sys.path.insert(0, {str(JAC_ROOT)!r})\n"
    "from jaclang.cli.loader import load_handler\n"
    "load_handler(sys.argv[1])\n"
    "mods = sorted(m for m in sys.modules if m.startswith('jaclang.cli.commands.'))\n"
    "print('PROBE=' + json.dumps(mods))\n"
)


_OWNING_PROBE = (
    "import sys, json\n"
    f"sys.path.insert(0, {str(JAC_ROOT)!r})\n"
    "from jaclang.cli.manifest import get_command_meta\n"
    "names = json.loads(sys.argv[1])\n"
    "out = {}\n"
    "for n in names:\n"
    "    m = get_command_meta(n)\n"
    "    hm = (m.handler_module if m else '') or ''\n"
    "    if hm.startswith('jaclang.cli.commands.'):\n"
    "        out[n] = hm.split('.')[-1]\n"
    "print('OWNING=' + json.dumps(out))\n"
)


def _command_owning_module() -> dict[str, str]:
    # Source of truth is the compact route table in jaclang.cli.manifest; read
    # it in a subprocess so importing jaclang here cannot pollute the isolation
    # probes below.
    proc = subprocess.run(
        [sys.executable, "-c", _OWNING_PROBE, json.dumps(TARGET_COMMANDS)],
        cwd=REPO,
        capture_output=True,
        text=True,
        env={**os.environ, "JAC_BENCH_ROOT": str(JAC_ROOT)},
    )
    assert proc.returncode == 0, (
        f"owning-module probe failed (rc={proc.returncode}):\n{proc.stderr[-1500:]}"
    )
    for line in proc.stdout.splitlines():
        if line.startswith("OWNING="):
            return json.loads(line.split("=", 1)[1])
    raise AssertionError(f"no OWNING= line in stdout:\n{proc.stdout[-1000:]}")


def _parse_probe(stdout: str) -> list[str]:
    for line in stdout.splitlines():
        if line.startswith("PROBE="):
            return json.loads(line.split("=", 1)[1])
    raise AssertionError(f"no PROBE= line in stdout:\n{stdout[-1000:]}")


def test_loading_handler_imports_no_sibling_registration_module() -> None:
    owning = _command_owning_module()
    env = {**os.environ, "JAC_BENCH_ROOT": str(JAC_ROOT)}
    for name in TARGET_COMMANDS:
        assert name in owning, (
            f"{name!r} not found in manifest; update TARGET_COMMANDS or the "
            "manifest handler_module."
        )
        proc = subprocess.run(
            [sys.executable, "-c", _PROBE_SINGLE, name],
            cwd=REPO,
            capture_output=True,
            text=True,
            env=env,
        )
        assert proc.returncode == 0, (
            f"load_handler({name!r}) probe failed (rc={proc.returncode}):\n"
            f"stderr:\n{proc.stderr[-1500:]}"
        )
        imported = _parse_probe(proc.stdout)
        short = {m.split(".")[-1] for m in imported}
        leaked = sorted(short & REGISTRATION_SHORT - {owning[name]})
        # Only the owning registration module may load; no sibling registration
        # module is permitted.
        assert not leaked, (
            f"load_handler({name!r}) (owning={owning[name]!r}) leaked sibling "
            f"registration modules: {leaked}. Imported command modules: {imported}"
        )


if __name__ == "__main__":
    test_loading_handler_imports_no_sibling_registration_module()
    print("command isolation OK")
