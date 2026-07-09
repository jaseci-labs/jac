"""Pytest plugin for collecting and running Jac test files.

This plugin teaches pytest how to discover and execute tests defined with
Jac's native ``test`` keyword.  It supports two naming conventions:

- ``test_*.jac``  -- standalone test files (pytest naming convention)
- ``*.test.jac``  -- annex test files attached to a base module (Jac convention)

In addition, every ``.jac`` file that lives under a declared Jac ``[test]``
root (the ``[test] directory`` from jac.toml or ``-d <dir>``, passed by
``jac test`` via ``--jac-test-dir``) is a test suite regardless of its name --
preserving the native runner's contract that a configured ``[test] directory``
runs the ``test`` blocks of *every* ``.jac`` file beneath it (issue #7151).

When *jaclang* is installed the plugin is automatically registered via the
``pytest11`` entry point so ``pytest`` discovers Jac tests alongside Python
tests with zero configuration.
"""

from __future__ import annotations

import contextlib
import importlib
import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import types
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest import FunctionTestCase

import pytest

# The canonical suffix knowledge lives in the plain-Python extension registry.
# Load it by path so importing this pytest plugin never triggers the heavy
# ``jaclang`` bootstrap when a project has no Jac tests (issue #6858).
_registry: types.ModuleType | None = None


def _ext_registry() -> types.ModuleType:
    """Lazily load and cache the extension registry by file path."""
    global _registry
    if _registry is None:
        path = os.path.join(os.path.dirname(__file__), "jac0core", "ext_registry.py")
        spec = importlib.util.spec_from_file_location("_jac_ext_registry", path)
        if spec is None or spec.loader is None:
            raise ImportError(f"cannot load extension registry from {path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _registry = module
    return _registry


# ---------------------------------------------------------------------------
# Hook -- option registration
# ---------------------------------------------------------------------------


def pytest_addoption(parser: pytest.Parser) -> None:
    """Register ``--jac-test-dir``, used to declare Jac ``[test]`` roots.

    ``jac test`` adds one entry for the declared ``[test]`` root (jac.toml's
    ``[test] directory`` or ``-d <dir>``) so the collector treats every ``.jac``
    file beneath it as a suite (issue #7151). The option is harmless (and
    unused) for plain ``pytest`` invocations.
    """
    group = parser.getgroup("jac", "Jac test collection")
    group.addoption(
        "--jac-test-dir",
        action="append",
        default=[],
        dest="jac_test_dir",
        metavar="DIR",
        help=(
            "Directory whose every .jac file is collected as a Jac test suite "
            "(the [test] directory contract). May be given multiple times."
        ),
    )


# ---------------------------------------------------------------------------
# Hook -- file collection
# ---------------------------------------------------------------------------


def _explicit_targets(config: pytest.Config) -> set[str]:
    """Resolved paths of ``.jac`` files named directly on the command line.

    ``jac test foo.jac`` means "run foo.jac's test blocks" regardless of the
    file's name or location -- matching the native runner. Cached on the config
    since the collect hook fires once per file.
    """
    cache = getattr(config, "_jac_explicit_targets", None)
    if cache is None:
        cache = set()
        for arg in config.invocation_params.args:
            arg = arg.split("::", 1)[0]
            if arg.endswith(".jac"):
                path = Path(arg)
                if path.exists():
                    cache.add(str(path.resolve()))
        config._jac_explicit_targets = cache  # type: ignore[attr-defined]
    return cache


def _test_root_dirs(config: pytest.Config) -> set[str]:
    """Resolved paths of directories declared as Jac ``[test]`` roots.

    ``jac test`` passes ``--jac-test-dir <dir>`` for the declared test root
    (the ``[test] directory`` from jac.toml or an explicit ``-d <dir>``),
    marking every ``.jac`` file beneath it as a test suite -- matching the
    native runner's directory-walk contract (issue #7151). Cached on the
    config since the collect hook fires once per file.
    """
    cache = getattr(config, "_jac_test_root_dirs", None)
    if cache is None:
        cache = set()
        for raw in config.getoption("jac_test_dir", default=[]) or []:
            path = Path(raw)
            if path.is_dir():
                cache.add(str(path.resolve()))
        config._jac_test_root_dirs = cache  # type: ignore[attr-defined]
    return cache


def _under_test_root(file_path: Path, config: pytest.Config) -> bool:
    """True when *file_path* lives inside a declared ``[test]`` root dir."""
    roots = _test_root_dirs(config)
    if not roots:
        return False
    resolved = file_path.resolve()
    return any(resolved.is_relative_to(root) for root in roots)


def pytest_collect_file(
    parent: pytest.Collector, file_path: Path
) -> JacFile | ClJacFile | None:
    """Return a collector for ``.jac`` files that follow test naming rules."""
    name = file_path.name
    reg = _ext_registry()

    # Never collect implementation annexes.
    if reg.is_impl(name):
        return None

    # A file named directly on the command line is always collected -- even a
    # fixtures/ input or a non-`test_` name -- so `jac test <file>` runs it.
    explicit = str(file_path.resolve()) in _explicit_targets(parent.config)

    # Otherwise skip .jac files inside fixtures/ directories: during directory
    # recursion those are test inputs, not test suites.
    if not explicit and any(p.name == "fixtures" for p in file_path.parents):
        return None

    # A .jac file beneath a declared [test] root directory is a test suite
    # regardless of its name: this preserves the native runner's contract that
    # `jac test`/`[test] directory` runs the `test` blocks of every `.jac` file
    # under the directory, not just `test_*`/`*.test` names (issue #7151).
    # Client modules keep their own naming gate below since their `test` blocks
    # run under bun via a separate collector, not this Python one.
    under_test_root = not explicit and _under_test_root(file_path, parent.config)

    # Client (cl) test files run their `test` blocks under bun, not Python.
    # test_*.cl.jac / *.test.cl.jac -> dedicated client collector.
    if reg.is_client_module(name):
        if explicit or name.startswith("test_") or reg.is_client_test(name):
            return ClJacFile.from_parent(parent, path=file_path)
        return None

    # Collect test_*.jac (pytest convention), *.test.jac (Jac convention), and
    # any .jac file under a declared [test] root directory.
    if (
        explicit
        or under_test_root
        or (name.startswith("test_") and reg.is_jac(name))
        or reg.is_test(name)
    ):
        return JacFile.from_parent(parent, path=file_path)

    return None


# ---------------------------------------------------------------------------
# Session-level Jac runtime bootstrap
# ---------------------------------------------------------------------------

_jac_runtime_ready = False


def _ensure_jac_runtime():
    """Verify that the Jac runtime can be imported, once per pytest session.

    Skips the test if jaclang is broken or otherwise unimportable; otherwise
    a no-op (Python's import system already handles real initialization).
    """
    global _jac_runtime_ready
    if _jac_runtime_ready:
        return
    try:
        from jaclang.jac0core.runtime import JacRuntime  # noqa: F401

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
    # stale SQLite data from previous tests). Seed the bootstrap default
    # so any subsequent `ExecutionContext()` without explicit args picks
    # it up. The session-wide exec_ctx is constructed with the seed
    # passed explicitly so its L3 path is locked in at construction.
    fresh_base = tempfile.mkdtemp()
    JacRuntime.set_base_path(fresh_base)
    JacRuntime.set_full_target_path(None)
    JacRuntime.program = JacProgram()
    JacRuntime.pool = ThreadPoolExecutor()
    JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(
        user_root=None, base_path_dir=fresh_base, full_target_path=None
    )


# ---------------------------------------------------------------------------
# Synthetic namespace packages for relative import support
# ---------------------------------------------------------------------------

_test_packages: dict[str, str] = {}
_test_pkg_counter = 0


def _ensure_test_package(base_dir: str) -> str:
    """Create a synthetic namespace package so relative imports work.

    When a ``.jac`` test file uses ``import from .sibling { ... }``, the
    compiled Python code contains ``from .sibling import ...`` which
    requires the module to have a non-empty ``__package__``.  By importing
    the test module as a child of a namespace package whose ``__path__``
    points at the test directory, Python resolves the relative import
    against sibling ``.jac`` files correctly.

    Returns the package name registered in ``sys.modules``.
    """
    global _test_pkg_counter
    real_dir = os.path.realpath(base_dir)

    # Reuse existing package name if we've seen this directory before.
    pkg_name = _test_packages.get(real_dir)
    if pkg_name and pkg_name in sys.modules:
        return pkg_name

    if not pkg_name:
        pkg_name = f"_jac_test_pkg_{_test_pkg_counter}"
        _test_pkg_counter += 1
        _test_packages[real_dir] = pkg_name

    pkg = types.ModuleType(pkg_name)
    pkg.__path__ = [real_dir]
    pkg.__package__ = pkg_name
    pkg.__spec__ = importlib.machinery.ModuleSpec(
        pkg_name, loader=None, is_package=True
    )
    pkg.__spec__.submodule_search_locations = [real_dir]
    sys.modules[pkg_name] = pkg

    return pkg_name


@contextlib.contextmanager
def _scoped_syspath(directory: str):
    """Temporarily prepend *directory* to ``sys.path``.

    This mirrors pytest's own ``--import-mode=prepend`` behaviour: the test
    directory is on ``sys.path`` while the test module is being imported /
    executed so that absolute imports of sibling packages (e.g.
    ``from fixtures import ...``) resolve correctly.  The entry is removed
    afterwards to avoid polluting ``sys.path`` for unrelated test files.
    """
    real_dir = os.path.realpath(directory)
    already_present = real_dir in sys.path
    if not already_present:
        sys.path.insert(0, real_dir)
    try:
        yield
    finally:
        if not already_present:
            with contextlib.suppress(ValueError):
                sys.path.remove(real_dir)


# ---------------------------------------------------------------------------
# Collector
# ---------------------------------------------------------------------------


class JacFile(pytest.File):
    """Collector that imports a ``.jac`` file and yields its ``test`` blocks."""

    def collect(self) -> list[JacTestItem]:  # noqa: C901
        from jaclang.runtimelib.test import JacTestCheck

        reg = _ext_registry()

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
            # Derive the importable module name via the extension registry's
            # canonical longest-suffix matcher: a compound codespace suffix
            # (``foo.na.jac`` / ``foo.sv.jac``) imports as module ``foo``, so a
            # bare ``Path.stem`` would leave the ``.na`` component and the
            # importer would read it as a package path and fail to resolve the
            # file (issue #7150).
            mod_name = reg.base_stem(Path(filepath).name)

            # Import the test module under a synthetic namespace package so
            # that relative imports (``from .sibling import ...``) resolve
            # against sibling .jac files in the same directory.
            pkg_name = _ensure_test_package(base_dir)
            qualified_name = f"{pkg_name}.{mod_name}"

            try:
                with _scoped_syspath(base_dir):
                    importlib.import_module(qualified_name)
            except Exception as exc:
                # A test file that fails to import is not an empty result --
                # swallowing it silently converts a broken test module into a
                # passing run (issue #7150). When the file was named directly on
                # the command line (``jac test foo.na.jac``) surface it as a hard
                # collection error, matching pytest's contract for an
                # unimportable ``test_*.py``, so a broken target can never
                # masquerade as a pass. During directory recursion, where one
                # unrelated broken file should not abort the whole sweep,
                # downgrade to a non-fatal diagnostic on stderr instead.
                explicit = str(self.path.resolve()) in _explicit_targets(self.config)
                # ImportError messages carry the compiler's own diagnostics
                # (e.g. native codegen errors); render them verbatim so the
                # collection error shows the real compile failure instead of
                # a repr with escaped newlines.
                exc_text = (
                    f"{type(exc).__name__}: {exc}"
                    if isinstance(exc, ImportError)
                    else repr(exc)
                )
                if explicit:
                    raise self.CollectError(
                        f"failed to import Jac test module {self.path}: {exc_text}"
                    ) from exc
                sys.stderr.write(
                    f"jac: skipping test file that failed to import: "
                    f"{self.path}: {exc_text}\n"
                )
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
        test_mod_name = reg.base_stem(self.path.name)
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

        The test directory is temporarily added to ``sys.path`` (scoped) so
        that imports inside test functions (e.g. ``from fixtures import ...``)
        resolve against sibling packages without permanently polluting the
        path for other test files.
        """
        _fresh_jac_state(clear_modules=False)
        with _scoped_syspath(str(self.path.parent)):
            self._test_case.runTest()

    def repr_failure(self, excinfo: pytest.ExceptionInfo[BaseException]) -> str:
        # Build a concise traceback showing only test-relevant frames
        # (the test file itself) plus the final error, filtering out
        # pytest/pluggy/venv internals AND jaclang compiler internals.
        import linecache

        lines: list[str] = []
        tb = excinfo.tb
        # Collect frames from the test file and immediate test code only.
        test_entries: list[tuple[str, int, str, str]] = []
        last_entry: tuple[str, int, str, str] | None = None
        while tb is not None:
            frame = tb.tb_frame
            filename = frame.f_code.co_filename
            lineno = frame.f_lineno
            funcname = frame.f_code.co_name
            tb = tb.tb_next
            src_line = ""
            with contextlib.suppress(Exception):
                src_line = linecache.getline(filename, lineno).strip()
            entry = (filename, lineno, funcname, src_line)
            last_entry = entry
            # Skip non-project frames.
            if any(s in filename for s in (".venv/", "site-packages/", "/unittest/")):
                continue
            # Keep frames from test files, skip jaclang internals.
            if "/jaclang/" in filename and "/tests/" not in filename:
                continue
            test_entries.append(entry)

        for filename, lineno, funcname, src_line in test_entries:
            lines.append(f"  {filename}:{lineno} in {funcname}")
            if src_line:
                lines.append(f"    {src_line}")

        # Show where the error actually occurred if it's not already shown.
        if last_entry and (not test_entries or last_entry != test_entries[-1]):
            filename, lineno, funcname, src_line = last_entry
            lines.append(f"  {filename}:{lineno} in {funcname}")
            if src_line:
                lines.append(f"    {src_line}")

        # Append the exception message.
        lines.append(f"E   {excinfo.typename}: {excinfo.value}")
        return "\n".join(lines)

    def reportinfo(self) -> tuple[Path, None, str]:
        return self.path, None, self.name


# ---------------------------------------------------------------------------
# Client (cl) test collection -- runs `test` blocks under bun
# ---------------------------------------------------------------------------


class ClJacFile(pytest.File):
    """Collector for ``*.cl.jac`` test files.

    The file's ``test`` blocks compile to JavaScript and execute under bun via
    :mod:`jaclang.runtimelib.cl_test_runner`.  The whole file is compiled and
    run once at collection time; each result becomes a :class:`ClJacTestItem`.
    """

    def collect(self) -> list[ClJacTestItem]:
        from jaclang.runtimelib.cl_test_runner import run_cl_test_file

        # bun is auto-installed on demand by the runner (jaclang's bun_installer),
        # so these run anywhere pytest collects them -- no toolchain gating needed.
        _ensure_jac_runtime()
        _fresh_jac_state()

        try:
            results = run_cl_test_file(str(self.path))
        except Exception as exc:  # surface compile/bun errors as one failing item
            return [
                ClJacTestItem.from_parent(
                    self,
                    name=f"{self.path.name} (cl runner error)",
                    ok=False,
                    error=str(exc),
                )
            ]

        return [
            ClJacTestItem.from_parent(
                self, name=res.description, ok=res.ok, error=res.error
            )
            for res in results
        ]


class ClJacTestItem(pytest.Item):
    """A single client ``test`` block result produced by bun."""

    def __init__(
        self, name: str, parent: pytest.Collector, ok: bool, error: str | None
    ) -> None:
        super().__init__(name, parent)
        self._ok = ok
        self._error = error

    def runtest(self) -> None:
        if not self._ok:
            raise AssertionError(self._error or "client test failed")

    def repr_failure(self, excinfo: pytest.ExceptionInfo[BaseException]) -> str:
        return self._error or str(excinfo.value)

    def reportinfo(self) -> tuple[Path, None, str]:
        return self.path, None, self.name
