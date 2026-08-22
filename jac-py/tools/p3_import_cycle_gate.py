#!/usr/bin/env python3
"""P3 import-cycle gate (PLAN.md §4 module-boundary constraint).

Static checks on ``jac-py/jacpython/*.jac`` import graph:
  - Full graph must be acyclic (Jac rejects import cycles).
  - ``objects.jac`` is na-clean leaf: no ceval/pyc_first/bootstrap imports.
  - ``ceval.jac`` may import objects + *object.jac helpers, not pyc_first.
  - ``pyc_first.jac`` may import ceval + objects (top bootstrap driver).
  - Object helper modules (*object.jac except objects) must not import ceval/pyc_first.

Run from repo root:
    python3 jac-py/tools/p3_import_cycle_gate.py
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

IMPORT_FROM = re.compile(r"^\s*import\s+from\s+(\w+)\s*\{", re.MULTILINE)
IMPORT_MODULE = re.compile(r"^\s*import\s+(?!from\b)(\w+)", re.MULTILINE)

BOOTSTRAP_MODULES = frozenset(
    {
        "layer0_replay",
        "layer0_replay_harness",
        "layer0_replay_p3_gate",
        "layer2_unittest",
        "layer3_import",
        "host_oracle",
        "layer4_compile",
    }
)

EXEC_MODULES = frozenset({"ceval", "pyc_first"})
FORBIDDEN_OBJECTS_IMPORTS = EXEC_MODULES | BOOTSTRAP_MODULES


def _repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def _jac_modules(jac_dir: Path) -> set[str]:
    return {path.stem for path in jac_dir.glob("*.jac") if path.is_file()}


def _parse_imports(text: str, jac_modules: set[str]) -> set[str]:
    deps = set(IMPORT_FROM.findall(text))
    deps.update(IMPORT_MODULE.findall(text))
    return {dep for dep in deps if dep in jac_modules}


def _build_graph(jac_dir: Path) -> dict[str, set[str]]:
    jac_modules = _jac_modules(jac_dir)
    graph = {name: set() for name in jac_modules}
    for path in jac_dir.glob("*.jac"):
        if not path.is_file():
            continue
        graph[path.stem] = _parse_imports(path.read_text(), jac_modules)
    return graph


def _find_cycles(graph: dict[str, set[str]]) -> list[list[str]]:
    white, gray, black = 0, 1, 2
    color = {node: white for node in graph}
    cycles: list[list[str]] = []

    def dfs(node: str, stack: list[str]) -> None:
        color[node] = gray
        stack.append(node)
        for neighbor in sorted(graph[node]):
            if color[neighbor] == gray:
                start = stack.index(neighbor)
                cycles.append(stack[start:] + [neighbor])
            elif color[neighbor] == white:
                dfs(neighbor, stack)
        stack.pop()
        color[node] = black

    for node in sorted(graph):
        if color[node] == white:
            dfs(node, [])
    return cycles


def _is_object_helper(name: str) -> bool:
    return name.endswith("object") and name != "objects"


def _check_invariants(graph: dict[str, set[str]]) -> list[str]:
    errors: list[str] = []

    objects_deps = graph.get("objects", set())
    for dep in sorted(objects_deps & FORBIDDEN_OBJECTS_IMPORTS):
        errors.append(f"objects.jac must not import {dep}.jac (na-clean leaf)")

    if "ceval" in graph:
        for dep in sorted(graph["ceval"] & {"pyc_first"}):
            errors.append(f"ceval.jac must not import {dep}.jac")

    if "pyc_first" in graph:
        illegal = graph["pyc_first"] & BOOTSTRAP_MODULES
        for dep in sorted(illegal):
            errors.append(f"pyc_first.jac must not import bootstrap module {dep}.jac")

    for name in sorted(graph):
        if not _is_object_helper(name):
            continue
        for dep in sorted(graph[name] & EXEC_MODULES):
            errors.append(f"{name}.jac must not import {dep}.jac")

    return errors


def main() -> int:
    root = _repo_root()
    jac_dir = root / "jac-py" / "jacpython"
    graph = _build_graph(jac_dir)
    fail_msgs: list[str] = []

    for cycle in _find_cycles(graph):
        fail_msgs.append(f"import cycle: {' -> '.join(cycle)}")

    fail_msgs.extend(_check_invariants(graph))

    if fail_msgs:
        for msg in fail_msgs:
            print(f"FAIL: {msg}")
        return 1
    print("PASS: P3 import cycle gate")
    return 0


if __name__ == "__main__":
    sys.exit(main())
