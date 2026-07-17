"""Import-budget probe used by scripts/startup_benchmark.py.

Runs the canonical Jac entry (`python -m jaclang` -> jaclang/__main__.py ->
jaclang.jac0core.cli_boot.start_cli, the same function the `jac` launcher
invokes) under an import counter, then prints the set of imported top-level
module names as a single JSON line.

Not intended for direct use: the harness warms the cache first so this probe
reports steady-state imports rather than one-off `.jac` compilation, then
categorizes the module names into command / feature / floor buckets.

Usage (from the harness):
    JAC_BENCH_ROOT=<jac source root> python scripts/_startup_probe.py <args...>
"""

from __future__ import annotations

import json
import os
import runpy
import sys
from collections.abc import Sequence
from types import ModuleType
from typing import Any


def main() -> int:
    root = os.environ.get("JAC_BENCH_ROOT")
    if root:
        sys.path.insert(0, root)
        os.chdir(root)

    # runpy preserves sys.argv[1:]; mirror `python -m jaclang <args>` by giving
    # argv[0] a stable command name and keeping the real args.
    sys.argv = ["jac", *sys.argv[1:]]

    seen: list[str] = []
    real_import = __builtins__.__import__

    def counting_import(
        name: str,
        globals: dict[str, Any] | None = None,
        locals: dict[str, Any] | None = None,
        fromlist: Sequence[str] = (),
        level: int = 0,
    ) -> ModuleType:
        seen.append(name)
        return real_import(name, globals, locals, fromlist, level)

    __builtins__.__import__ = counting_import

    exit_code = 0
    try:
        runpy.run_module("jaclang", run_name="__main__", alter_sys=True)
    except SystemExit as exc:
        exit_code = exc.code if isinstance(exc.code, int) else 1
    except BaseException:
        exit_code = 1

    payload = {"exit_code": exit_code, "modules": sorted(set(seen))}
    print("PROBE_RESULT=" + json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
