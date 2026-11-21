#!/usr/bin/env python3
"""CI gate for the declared bootstrap seed set (jaclang/bootstrap_manifest.py).

Two invariants keep the jac0 tier honest:

1. Every .jac module the manifest covers actually compiles under the jac0
   seed transpiler (with its impl annexes), so the declared seed set is
   the real seed set.
2. No seed module imports a non-seed jaclang module at module scope. The
   full compiler may only be reached from function bodies -- a hoisted
   import deadlocks bootstrap, and nothing else enforces that invariant.

Runs on plain python3 with no jaclang installation: jac0.py and the
manifest are loaded by file path.
"""

from __future__ import annotations

import ast
import importlib.util
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JACLANG = os.path.join(REPO, "jac", "jaclang")

# Pure-Python boot modules a seed module may import at module scope, plus
# the manifest itself and the seed transpiler.
PY_BOOT_MODULES = {
    "jaclang.jac0core.sealed",
    "jaclang.jac0core.cache_paths",
    "jaclang.jac0core.ext_registry",
    "jaclang.jac0core.osp0",
    "jaclang.bootstrap_manifest",
    "jaclang.jac0",
}


_STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
_COMPTIME_RE = re.compile(r"(?<![\w`])comptime\b")


def _comptime_keyword_lines(source: str) -> list[tuple[int, str]]:
    """Lines where `comptime` appears as a keyword, not inside a string.

    Comments and string literals are blanked before matching; a triple-quoted
    block spanning several lines is skipped as a whole.
    """
    hits: list[tuple[int, str]] = []
    in_block = False
    for lineno, line in enumerate(source.splitlines(), start=1):
        if in_block:
            if '"""' in line:
                in_block = False
                line = line.split('"""', 1)[1]
            else:
                continue
        if line.count('"""') % 2 == 1:
            in_block = True
            line = line.split('"""', 1)[0]
        code = _STRING_RE.sub('""', line).split("#", 1)[0]
        if _COMPTIME_RE.search(code):
            hits.append((lineno, line))
    return hits


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _module_to_rel(module: str) -> str:
    """jaclang.a.b -> a/b (package-relative POSIX, no suffix)."""
    return module.partition("jaclang.")[2].replace(".", "/")


def main() -> int:
    if sys.version_info < (3, 12):
        print(
            "check_seed_manifest: needs python >= 3.12 (the generated "
            "python targets the toolchain interpreter)",
            file=sys.stderr,
        )
        return 2
    manifest = _load(
        "bootstrap_manifest", os.path.join(JACLANG, "bootstrap_manifest.py")
    )
    jac0 = _load("jac0", os.path.join(JACLANG, "jac0.py"))

    seed_dirs, seed_files = manifest.seed_abs_entries(JACLANG)
    sources: list[str] = [p for p in sorted(seed_files) if p.endswith(".jac")]
    for d in seed_dirs:
        for root, dirs, files in os.walk(d):
            dirs[:] = [x for x in dirs if not x.startswith(".") and x != "__pycache__"]
            for f in sorted(files):
                if f.endswith(".jac"):
                    sources.append(os.path.join(root, f))

    def in_seed(module: str) -> bool:
        if not (module == "jaclang" or module.startswith("jaclang.")):
            return True  # stdlib / third-party: not this gate's business
        if module in PY_BOOT_MODULES:
            return True
        rel = _module_to_rel(module)
        return manifest.is_seed_source(rel + ".jac") or manifest.is_seed_source(
            rel + "/"
        )

    failures: list[str] = []
    checked = 0
    for src_path in sources:
        if getattr(jac0, "discover_impl_files", None) and any(
            src_path.endswith(sfx) for sfx in (".impl.jac", ".test.jac")
        ):
            continue  # annexes compile with their host module
        if manifest.is_native_only(
            os.path.relpath(src_path, JACLANG).replace(os.sep, "/")
        ):
            continue  # native-only unit: the link plan builds it, jac0 never does
        with open(src_path, encoding="utf-8") as f:
            source = f.read()
        impl_sources = []
        for impl_path in jac0.discover_impl_files(src_path):
            with open(impl_path, encoding="utf-8") as f:
                impl_sources.append((f.read(), impl_path))
        rel = os.path.relpath(src_path, JACLANG).replace(os.sep, "/")
        # The seed tier never learns the comptime dialect: the jac0 transpiler
        # would read the keyword as a plain name and emit wrong Python, so the
        # gate refuses it up front instead of at the first confusing failure.
        for ct_src, ct_path in [(source, src_path)] + impl_sources:
            for lineno, line in _comptime_keyword_lines(ct_src):
                ct_rel = os.path.relpath(ct_path, JACLANG).replace(os.sep, "/")
                failures.append(
                    f"{ct_rel}:{lineno}: 'comptime' is not available in the "
                    "jac0 seed tier; seed modules are compiled without the "
                    "compile-time evaluator"
                )
        try:
            py_source = jac0.compile_jac(
                source, src_path, impl_sources=impl_sources or None
            )
            code_tree = ast.parse(py_source, src_path)
            compile(py_source, src_path, "exec")
        except Exception as exc:  # noqa: BLE001 - report, don't crash the gate
            failures.append(f"{rel}: does not compile under jac0: {exc}")
            continue
        checked += 1
        for node in ast.iter_child_nodes(code_tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    if not in_seed(alias.name):
                        failures.append(
                            f"{rel}:{node.lineno}: module-scope import of "
                            f"non-seed module {alias.name!r} (hoisting this "
                            "deadlocks bootstrap; keep it function-local)"
                        )
            elif isinstance(node, ast.ImportFrom) and node.module:
                if not in_seed(node.module):
                    failures.append(
                        f"{rel}:{node.lineno}: module-scope import from "
                        f"non-seed module {node.module!r} (hoisting this "
                        "deadlocks bootstrap; keep it function-local)"
                    )

    if failures:
        for line in failures:
            print(f"SEED MANIFEST: {line}", file=sys.stderr)
        return 1
    print(f"seed manifest OK: {checked} modules compile under jac0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
