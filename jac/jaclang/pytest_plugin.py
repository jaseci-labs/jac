"""Pytest plugin for collecting and running Jac test files.

This plugin teaches pytest how to discover and execute tests defined with
Jac's native ``test`` keyword.  It supports two naming conventions:

- ``test_*.jac``  -- standalone test files (pytest naming convention)
- ``*.test.jac``  -- annex test files attached to a base module (Jac convention)

When *jaclang* is installed the plugin is automatically registered via the
``pytest11`` entry point so ``pytest`` discovers Jac tests alongside Python
tests with zero configuration.
"""

from __future__ import annotations

import os
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest import FunctionTestCase

import pytest

# ---------------------------------------------------------------------------
# Hook -- file collection
# ---------------------------------------------------------------------------


def pytest_collect_file(parent: pytest.Collector, file_path: Path) -> JacFile | None:
    """Return a collector for ``.jac`` files that follow test naming rules."""
    name = file_path.name

    # Never collect implementation annexes.
    if name.endswith(".impl.jac"):
        return None

    # Skip .jac files inside fixtures/ directories -- those are test inputs,
    # not test suites.
    if any(p.name == "fixtures" for p in file_path.parents):
        return None

    # Collect test_*.jac (pytest convention) and *.test.jac (Jac convention).
    if (name.startswith("test_") and name.endswith(".jac")) or name.endswith(
        ".test.jac"
    ):
        return JacFile.from_parent(parent, path=file_path)

    return None


# ---------------------------------------------------------------------------
# Session-level Jac runtime bootstrap
# ---------------------------------------------------------------------------

_jac_runtime_ready = False


def _ensure_jac_runtime():
    """Initialise the Jac runtime exactly once per pytest session."""
    global _jac_runtime_ready
    if _jac_runtime_ready:
        return
    try:
        from jaclang.jac0core.runtime import JacRuntime

        JacRuntime.setup()
        _jac_runtime_ready = True
    except Exception as exc:
        pytest.skip(f"Jac runtime unavailable: {exc}")


def _fresh_jac_state(*, clear_modules: bool = True):
    """Reset Jac state so each test gets a clean environment.

    When *clear_modules* is True (the default, used at collection time),
    user modules are evicted from ``sys.modules`` so that reimporting
    produces a clean slate.

    When *clear_modules* is False (used between tests within a single
    file), modules stay in ``sys.modules`` so that ``unittest.mock.patch``
    can find the same module objects that test code references via their
    ``__globals__`` dicts.  Without this, patching a module-level name
    has no effect because ``mock.patch`` patches a *new* module object
    while test code still reads from the *old* one.
    """
    from jaclang.jac0core.program import JacProgram
    from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface

    # Close any existing execution context
    if JacRuntime.exec_ctx is not None:
        JacRuntime.exec_ctx.mem.close()

    if clear_modules:
        # Remove previously-loaded user .jac modules from sys.modules.
        for mod in list(JacRuntime.loaded_modules.values()):
            if not mod.__name__.startswith("jaclang.") and mod.__name__ != "__main__":
                sys.modules.pop(mod.__name__, None)
        JacRuntime.loaded_modules.clear()

    # Set up fresh state with isolated storage (temp directory avoids
    # stale SQLite data from previous tests)
    JacRuntime.base_path_dir = tempfile.mkdtemp()
    JacRuntime.program = JacProgram()
    JacRuntime.pool = ThreadPoolExecutor()
    JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(user_root=None)


# ---------------------------------------------------------------------------
# Collector
# ---------------------------------------------------------------------------


class JacFile(pytest.File):
    """Collector that imports a ``.jac`` file and yields its ``test`` blocks."""

    def collect(self) -> list[JacTestItem]:  # noqa: C901
        from jaclang.jac0core.runtime import JacRuntimeInterface
        from jaclang.runtimelib.test import JacTestCheck

        _ensure_jac_runtime()
        _fresh_jac_state()
        JacTestCheck.reset()

        # Snapshot sys.modules so we can clean up Jac-imported modules after
        # collection.  This prevents collisions with .py files that share the
        # same stem (e.g. test_language.py + test_language.jac).
        modules_before = set(sys.modules.keys())

        # Suppress stdout during collection (entry blocks, prints, etc.)
        old_stdout = sys.stdout
        sys.stdout = open(os.devnull, "w")  # noqa: SIM115
        try:
            filepath = str(self.path)

            # For .test.jac annexes, find and import the base module instead.
            if filepath.endswith(".test.jac"):
                try:
                    from jaclang.jac0core.bccache import discover_base_file

                    base = discover_base_file(filepath)
                    if base:
                        filepath = base
                except Exception:
                    pass

            base_dir = str(Path(filepath).parent)
            mod_name = Path(filepath).stem

            try:
                JacRuntimeInterface.jac_import(
                    target=mod_name,
                    base_path=base_dir,
                )
            except Exception:
                # Import failure -- nothing to collect from this file.
                return []
        finally:
            sys.stdout.close()
            sys.stdout = old_stdout

        # Collect test items into a list.
        items: list[JacTestItem] = []
        for _key, tests in JacTestCheck.test_suite_path.items():
            for test_info in tests:
                items.append(
                    JacTestItem.from_parent(
                        self,
                        name=test_info.display_name,
                        callobj=test_info.test_case,
                    )
                )

        # Remove the test module itself from sys.modules to avoid collisions
        # with Python test files that share the same basename (e.g.
        # test_server.py vs test_server.jac).  We intentionally keep other
        # modules (vendored libs, compiler internals) so that class identity
        # (isinstance checks) and forward-reference resolution remain intact.
        test_mod_name = Path(self.path).stem
        for name in list(sys.modules.keys()):
            if name not in modules_before and (
                name == test_mod_name or name.endswith(f".{test_mod_name}")
            ):
                sys.modules.pop(name, None)

        return items


# ---------------------------------------------------------------------------
# Item
# ---------------------------------------------------------------------------


class JacTestItem(pytest.Item):
    """A single ``test`` block inside a ``.jac`` file."""

    def __init__(
        self, name: str, parent: pytest.Collector, callobj: FunctionTestCase
    ) -> None:
        super().__init__(name, parent)
        self._test_case = callobj

    def runtest(self):
        """Reset Jac execution context and execute the test.

        We intentionally keep modules in ``sys.modules`` (clear_modules=False)
        so that ``unittest.mock.patch("pkg.mod.func")`` resolves to the same
        module object whose ``__globals__`` dict is referenced by the code
        under test.  Module-level cleanup happens once at collection time.
        """
        _fresh_jac_state(clear_modules=False)
        self._test_case.runTest()

    def repr_failure(self, excinfo: pytest.ExceptionInfo[BaseException]) -> str:
        return str(excinfo.getrepr())

    def reportinfo(self) -> tuple[Path, None, str]:
        return self.path, None, self.name
