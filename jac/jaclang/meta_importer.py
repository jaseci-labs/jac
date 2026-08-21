"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

from __future__ import annotations

import atexit
import hashlib
import importlib.abc
import importlib.machinery
import importlib.util
import logging
import marshal
import os
import sys
import types
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType

# Cache jac0 transpiler hash for bootstrap cache invalidation
import jaclang.jac0 as _jac0_mod
from jaclang.jac0 import compile_jac as _jac0_compile  # noqa: E402
from jaclang.jac0 import discover_impl_files as _jac0_discover_impls  # noqa: E402
from jaclang.jac0core import ext_registry  # noqa: E402
from jaclang.jac0core import sealed as _sealed  # noqa: E402
from jaclang.jac0core.cache_paths import get_bootstrap_cache_dir  # noqa: E402

_jac0_source_path = getattr(_jac0_mod, "__file__", "")
_jac0_hash = (
    hashlib.sha256(Path(_jac0_source_path).read_bytes()).digest()
    if _jac0_source_path and os.path.isfile(_jac0_source_path)
    else b""
)

# Inline logging config (previously in jaclang.jac0core.log)
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")


# ---------------------------------------------------------------------------
# Bootstrap bytecode cache
#
# jac0core .jac files are transpiled by jac0 on every invocation.  Caching
# the resulting bytecode avoids ~200 ms of repeated work when the sources
# haven't changed.  The cache lives at ~/.cache/jac/jir/bootstrap/ as plain
# marshalled code objects: the cache *filename* already encodes a digest over
# the Python version, the jac0 transpiler, and all source/impl contents, so no
# in-file header or validation is needed.  The directory is resolved by the
# pure-Python `jaclang.jac0core.cache_paths` (importable here, before the JIR
# Jac modules are bootstrapped), so it shares one platform-resolution rule with
# `jaclang.jac0core.jir`; the cache *key*, however, stays independent of that
# module's `compute_module_key` since it must work before jac0core compiles.
# ---------------------------------------------------------------------------


def _bootstrap_compile(
    file_path: str,
    jac_source: str,
    impl_sources: list[tuple[str, str]] | None = None,
) -> types.CodeType:
    """Compile a bootstrap .jac file, using a marshalled bytecode disk cache."""
    # Build the hash key from all source inputs + Python version + transpiler.
    h = hashlib.sha256()
    h.update(sys.version.encode())
    h.update(_jac0_hash)
    h.update(jac_source.encode())
    if impl_sources:
        for src, path in impl_sources:
            h.update(path.encode())
            h.update(src.encode())
    digest = h.hexdigest()[:16]

    base_name = os.path.splitext(os.path.basename(file_path))[0]
    cache_file = get_bootstrap_cache_dir() / f"{base_name}.{digest}.jbc"

    if cache_file.is_file():
        try:
            return marshal.loads(cache_file.read_bytes())  # noqa: S302
        except Exception:
            cache_file.unlink(missing_ok=True)

    # Cache miss — transpile with jac0, compile, and cache (best-effort).
    py_source = _jac0_compile(jac_source, file_path, impl_sources=impl_sources)
    code = compile(py_source, file_path, "exec")
    try:
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        # Process-unique temp + atomic replace so concurrent bootstraps (e.g.
        # parallel test workers) can't read a half-written cache file.
        tmp_file = cache_file.with_suffix(cache_file.suffix + f".{os.getpid()}.tmp")
        try:
            tmp_file.write_bytes(marshal.dumps(code))
            os.replace(tmp_file, cache_file)
        finally:
            tmp_file.unlink(missing_ok=True)
    except OSError:
        pass

    return code


class JacSourceCompileError(ImportError):
    """A .jac module was found on disk but its source failed to compile.

    Distinct from a module that is simply absent (``ModuleNotFoundError``) or
    only partially initialized mid-bootstrap (``cannot import name ...``): the
    file resolved, so this is a defect in that file, never a condition to
    degrade around silently. It subclasses ``ImportError`` so existing handlers
    keep their behavior; callers that must not degrade -- the compiler's own
    pass-schedule builders -- opt in by inspecting ``jac_source_path``.
    """

    def __init__(self, message: str, jac_source_path: str) -> None:
        """Record the .jac file whose compile produced this failure."""
        super().__init__(message)
        self.jac_source_path = jac_source_path


def _retained_failure_details(file_path: str) -> str:
    """Recover diagnostics the internal compile closure already evicted."""
    try:
        from jaclang.jac0core.compiler import compiler_source_failure_details

        return compiler_source_failure_details(file_path) or ""
    except Exception:
        return ""


def _module_scoped_alerts(program: object, file_path: str) -> list:
    """Collect compile alerts recorded against file_path (or its annexes).

    `foo.jac` -> prefix `foo.` also matches annex paths such as
    `foo.impl.jac` and `foo.impl/bar.jac`, so errors reported against
    an impl file count as the module's own.
    """
    norm = os.path.normpath(file_path)
    stem = norm[:-4] if norm.endswith(".jac") else norm
    prefix = stem + "."
    alerts = []
    for alert in getattr(program, "errors_had", []):
        try:
            alert_path = os.path.normpath(alert.loc.mod_path)
        except Exception:
            continue
        if alert_path == norm or alert_path.startswith(prefix):
            alerts.append(alert)
    return alerts


# Bootstrap modresolver.jac before JacMetaImporter is registered. This module
# must be available for find_spec()/get_code(), but normal .jac imports are not
# yet operational at this point. In a sealed image its code object is served
# frozen from the manifest; a missing/corrupt JIR falls back to the retained
# source, which jac0 transpiles live.
_jac0core_dir = os.path.join(os.path.dirname(__file__), "jac0core")
_modresolver_jac = os.path.join(_jac0core_dir, "modresolver.jac")
_modresolver_code = None
_modresolver_origin = _modresolver_jac
_frozen_modresolver = _sealed.find_module("jaclang.jac0core.modresolver")
if _frozen_modresolver is not None and _frozen_modresolver[1].get("bootstrap"):
    _mr_image = _frozen_modresolver[0]
    _modresolver_code = _mr_image.bootstrap_code("jaclang.jac0core.modresolver")
    if _modresolver_code is not None:
        _modresolver_origin = _mr_image.virtual_origin(_frozen_modresolver[2])
if _modresolver_code is None:
    with open(_modresolver_jac, encoding="utf-8") as _f:
        _modresolver_code = _bootstrap_compile(_modresolver_jac, _f.read())
_modresolver = types.ModuleType("jaclang.jac0core.modresolver")
_modresolver.__file__ = _modresolver_origin
_modresolver.__package__ = "jaclang.jac0core"
exec(_modresolver_code, _modresolver.__dict__)  # noqa: S102
sys.modules["jaclang.jac0core.modresolver"] = _modresolver
get_jac_search_paths = _modresolver.get_jac_search_paths


def _graphmend_claims(fullname: str, path: str) -> bool:
    """True if GraphMend claims this .py file.

    A module claims itself when it seeds GraphMend; the claim then follows its
    eager imports, bounded by its top-level package. torch, jaclang and the
    standard library are never claimed, and claiming imported code at all is a
    separate consent from transforming authored modules: it requires the
    ``[run] graphmend_claim_imports`` opt-in, off by default. With nothing
    claimed yet and torch absent, the gate answers from membership tests
    alone, before any syscall.
    """
    try:
        from jaclang.jac0core.runtime import JacRuntime as Jac

        program = Jac.get_program()
        claimed = getattr(program, "graphmend_claimed", None) or ()
    except Exception:
        return False
    top = fullname.split(".")[0]
    if top in ("torch", "jaclang") or top in sys.stdlib_module_names:
        return False
    if not claimed and "torch" not in sys.modules:
        return False
    try:
        from jaclang.jac0core.compile_options import (
            resolved_graphmend_claim_imports_setting,
            resolved_graphmend_setting,
        )

        if resolved_graphmend_setting() is False:
            return False
        if not resolved_graphmend_claim_imports_setting():
            return False
    except Exception:
        return False
    if not os.path.isfile(path):
        return False
    if os.path.realpath(path) in claimed:
        return True
    if "torch" not in sys.modules:
        return False
    try:
        from jaclang.compiler.passes.main.graphmend.auto_detect import (
            file_imports_torch,
        )

        if not file_imports_torch(path):
            return False
        from jaclang.compiler.passes.main.graphmend.scope_facts import claim_path

        return bool(claim_path(program, path))
    except Exception:
        return False


def _report_abandoned_claim(path: str, reason: str) -> None:
    """Record that a granted claim on a .py file was abandoned.

    The import still succeeds through the stock loader, so a divergence
    between the Jac and CPython front ends would otherwise be an invisible
    behavior difference. A warning on the program surfaces it under
    ``--diagnostics all``, naming the file and the reason. Best-effort: the
    reporter itself must never break the import it is reporting on.
    """
    try:
        from jaclang.jac0core.codeinfo import CodeLocInfo
        from jaclang.jac0core.diagnostics import W1107
        from jaclang.jac0core.passes.transform import Alert, Transform
        from jaclang.jac0core.runtime import JacRuntime as Jac
        from jaclang.jac0core.unitree import Source, Token

        tok = Token(
            orig_src=Source("", path),
            name="WARNING",
            value="",
            line=1,
            end_line=1,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0,
        )
        Jac.get_program().warnings_had.append(
            Alert(
                W1107.format_message(path=path, reason=reason),
                CodeLocInfo(tok, tok),
                Transform,
                code=W1107,
            )
        )
    except Exception:
        pass


# Holds the live hook wrapper (under "wrapper") and whether the teardown
# restore is armed (under "atexit"), so uninstall can tell our patch apart
# from anyone else's and installs arm the restore exactly once.
_graphmend_hook_state: dict = {}


def install_graphmend_loader_hook() -> None:
    """Route claimed .py files through GraphMend when the import bypasses us.

    A spec built straight from a file location never consults a meta-path
    finder, but it still goes through ``SourceFileLoader.get_code``. Compiling
    from source there also sidesteps ``__pycache__``, so a ``.pyc`` from a
    non-GraphMend run is never served to a GraphMend run. Idempotent; patching
    a stdlib class is only warranted once GraphMend can claim something, so
    callers install on the first claim or as torch enters the process. The
    patch does not outlive the claiming region: the first install arms an
    ``atexit`` restore, and ``uninstall_graphmend_loader_hook`` gives the
    class its inherited ``get_code`` back at teardown.
    """
    loader = importlib.machinery.SourceFileLoader
    if getattr(loader, "_jac_graphmend_hooked", False):
        return
    original = loader.get_code

    def get_code(self: object, fullname: str) -> object:
        path = getattr(self, "path", "") or ""
        if path.endswith(".py") and _graphmend_claims(fullname, path):
            try:
                from jaclang.jac0core.runtime import JacRuntime as Jac

                program = Jac.get_program()
                codeobj = Jac.get_compiler().get_bytecode(
                    full_target=path, target_program=program
                )
                if codeobj is not None:
                    return codeobj
                _report_abandoned_claim(
                    path, "the Jac front end produced no bytecode for it"
                )
            except Exception as exc:
                # Never break an import because GraphMend could not transform it;
                # fall through to the stock loader and run untransformed.
                _report_abandoned_claim(
                    path, f"the Jac front end failed with {exc!r}"
                )
        return original(self, fullname)

    if not _graphmend_hook_state.get("atexit"):
        atexit.register(uninstall_graphmend_loader_hook)
        _graphmend_hook_state["atexit"] = True
    if not _graphmend_hook_state.get("finalizer"):
        # The claims the hook answers live on the installing program, so the
        # patch's lifetime follows that program: when it is collected, the
        # stdlib class gets its method back. A later program that claims again
        # reinstalls through the same entry points. atexit stays as the
        # backstop for interpreters that exit before collection runs.
        try:
            import weakref

            from jaclang.jac0core.runtime import JacRuntime as Jac

            weakref.finalize(
                Jac.get_program(), uninstall_graphmend_loader_hook
            )
            _graphmend_hook_state["finalizer"] = True
        except Exception:
            pass
    _graphmend_hook_state["wrapper"] = get_code
    loader.get_code = get_code  # type: ignore[method-assign]
    loader._jac_graphmend_hooked = True  # type: ignore[attr-defined]


def uninstall_graphmend_loader_hook() -> None:
    """Give ``SourceFileLoader`` its inherited ``get_code`` back.

    The hook is a class attribute shadowing the method ``SourceFileLoader``
    inherits, so removal is deletion, restoring the exact stdlib behavior.
    Only our own wrapper is removed: if someone else has patched over it,
    their patch is left in place (it still delegates through to the stock
    method). Idempotent, and registered with ``atexit`` at install time so
    the stdlib class is restored when the program tears down even where no
    explicit teardown runs.
    """
    loader = importlib.machinery.SourceFileLoader
    wrapper = _graphmend_hook_state.pop("wrapper", None)
    if wrapper is not None and loader.__dict__.get("get_code") is wrapper:
        del loader.get_code
    if "_jac_graphmend_hooked" in loader.__dict__:
        del loader._jac_graphmend_hooked


def install_graphmend_loader_hook_for_torch() -> None:
    """Install the loader hook as torch enters the process, unless off.

    Nothing is claimable before torch: a claim needs it in ``sys.modules``, or
    a path registered by a compile of a module that imports torch itself. And
    claiming imported code is its own consent: without the
    ``[run] graphmend_claim_imports`` opt-in nothing can ever be claimed, so
    the stdlib class is left untouched.
    """
    if getattr(
        importlib.machinery.SourceFileLoader, "_jac_graphmend_hooked", False
    ):
        return
    try:
        from jaclang.jac0core.compile_options import (
            resolved_graphmend_claim_imports_setting,
            resolved_graphmend_setting,
        )

        if resolved_graphmend_setting() is False:
            return
        if not resolved_graphmend_claim_imports_setting():
            return
    except Exception:
        return
    install_graphmend_loader_hook()


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    # Directory containing the jaclang package (for bootstrap detection)
    _jaclang_dir: str = str(Path(__file__).parent)

    # Directory containing bootstrap .jac files (jac0core infrastructure)
    _bootstrap_dir: str = str(Path(__file__).parent / "jac0core")

    def _is_bootstrap_jac(self, file_path: str) -> bool:
        """Check if a .jac file should be compiled with jac0 (bootstrap).

        Only .jac files inside jaclang/jac0core/ are bootstrap files — they
        are part of the compiler infrastructure and must be compiled with the
        lightweight jac0 transpiler rather than the full Jac compiler (which
        depends on them). Files in jaclang/compiler/ use full Jac syntax
        and must go through the full compiler.
        """
        return file_path.startswith(self._bootstrap_dir)

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        """Find the spec for the module."""
        # Submodules import their parent first, so the bare name is the only
        # case to watch.
        if fullname == "torch":
            install_graphmend_loader_hook_for_torch()

        # Sealed image is authoritative: a sealed binary resolves its modules
        # from the manifest by name, with no filesystem probing for .jac. This
        # is the primary path (not a fallback) so a sealed runtime never touches
        # the disk for its own code. In an unsealed dev tree no image is loaded,
        # so this is a no-op and resolution falls through to the source search.
        sealed_spec = self._sealed_spec(fullname)
        if sealed_spec is not None:
            return sealed_spec

        if path is None:
            # Top-level import
            paths_to_search = get_jac_search_paths()
            module_path_parts = fullname.split(".")
        else:
            # Submodule import
            paths_to_search = [*path]
            module_path_parts = fullname.split(".")[-1:]

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package (canonical __init__ variants and
            # precedence come from the shared extension registry).
            if os.path.isdir(candidate_path):
                for init_name in ext_registry.INIT_FILES:
                    init_file = os.path.join(candidate_path, init_name)
                    if os.path.isfile(init_file):
                        return importlib.util.spec_from_file_location(
                            fullname,
                            init_file,
                            loader=self,
                            submodule_search_locations=[candidate_path],
                        )
                # No __init__.jac found — treat as an implicit Jac namespace
                # package when a .jac source lives anywhere in its subtree (and
                # it is not a regular Python package). Without this, Python's
                # PathFinder must create the namespace package, which only works
                # when the parent directory happens to be on sys.path at that
                # moment. The subtree check (not just direct .jac files) is what
                # lets per-component import descend through an *intermediate*
                # namespace package like ``engine/`` in ``engine.math.vec3``
                # (issue #7211).
                if ext_registry.is_jac_namespace_package(candidate_path):
                    spec = importlib.machinery.ModuleSpec(
                        fullname, loader=None, is_package=True
                    )
                    spec.submodule_search_locations = [candidate_path]
                    return spec
            # Check for a module file in codespace precedence order.
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return importlib.util.spec_from_file_location(
                        fullname, module_file, loader=self
                    )
            # Migration guard: the .na.jac marker was retired in 0.35. A
            # leftover file must fail loudly with the rename, not as a bare
            # module-not-found.
            retired = candidate_path + ext_registry.RETIRED_NATIVE_SUFFIX
            if os.path.isfile(retired):
                raise ImportError(
                    f"{retired}: the .na.jac marker was retired in 0.35 -- "
                    "rename the file to .jac; native placement is inferred "
                    "(or forced by 'jac nacompile' / 'jac build --as native')."
                )
            # GraphMend: claim .py modules that seed a compiled region, plus
            # what those seeds import inside their own package.
            py_file = candidate_path + ".py"
            if self._graphmend_claimed_py(fullname, py_file):
                # A live claim means claimed code can also arrive through a
                # spec built from a file location, which never reaches us.
                install_graphmend_loader_hook()
                return importlib.util.spec_from_file_location(
                    fullname, py_file, loader=self
                )

        return None

    def _graphmend_claimed_py(self, fullname: str, py_file: str) -> bool:
        """True if GraphMend should claim this .py import; see the module-level
        twin ``_graphmend_claims`` for the rule."""
        return _graphmend_claims(fullname, py_file)

    def _exec_py_source_fallback(self, module: ModuleType, file_path: str) -> bool:
        """Run a .py module from its original source via CPython's compiler.

        Used when GraphMend interception claimed a .py file but the Jac
        compiler could not produce bytecode for it. Keeps the import working
        (untransformed) instead of failing. Returns True on success.
        """
        try:
            with open(file_path, encoding="utf-8") as fh:
                code = compile(fh.read(), file_path, "exec")
            exec(code, module.__dict__)  # noqa: S102
            return True
        except Exception:
            return False

    def _sealed_spec(self, fullname: str) -> importlib.machinery.ModuleSpec | None:
        found = _sealed.find_module(fullname)
        if found is None:
            return None
        image, entry, src_rel = found
        origin = image.virtual_origin(src_rel)
        is_pkg = entry.get("package", False)
        spec = importlib.machinery.ModuleSpec(
            fullname, self, origin=origin, is_package=is_pkg
        )
        # Populate __file__ from the (virtual) origin so tracebacks and code
        # that inspects __file__ behave as if the source were on disk.
        spec._set_fileattr = True
        if is_pkg:
            spec.submodule_search_locations = [os.path.dirname(origin)]
        return spec

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None  # use default machinery

    def _exec_bootstrap(self, module: ModuleType, file_path: str) -> None:
        """Execute a bootstrap .jac module using jac0 with bytecode caching.

        Bootstrap modules are part of the jaclang compiler infrastructure.
        They are compiled with the lightweight jac0 transpiler rather than
        the full Jac compiler, which depends on them.
        """
        # Sealed image: the bootstrap code object is frozen in the manifest;
        # there is no .jac source to transpile.
        frozen = _sealed.find_module(module.__name__)
        if frozen is not None and frozen[1].get("bootstrap"):
            code = frozen[0].bootstrap_code(module.__name__)
            if code is not None:
                exec(code, module.__dict__)  # noqa: S102
                return

        with open(file_path, encoding="utf-8") as f:
            jac_source = f.read()

        impl_sources: list[tuple[str, str]] = []
        for impl_path in _jac0_discover_impls(file_path):
            with open(impl_path, encoding="utf-8") as f:
                impl_sources.append((f.read(), impl_path))

        code = _bootstrap_compile(file_path, jac_source, impl_sources or None)
        exec(code, module.__dict__)

    def exec_module(self, module: ModuleType) -> None:
        """Execute the module by loading and executing its bytecode.

        This method implements PEP 451's exec_module() protocol, which separates
        module creation from execution. It handles both package (__init__.jac) and
        regular module (.jac/.py) execution.
        """
        if not module.__spec__ or not module.__spec__.origin:
            raise ImportError(
                f"Cannot find spec or origin for module {module.__name__}"
            )

        file_path = module.__spec__.origin

        # Bootstrap tier: a sealed module the manifest flags as bootstrap, or (in
        # an unsealed tree) a .jac under jaclang/jac0core/. Either way it is
        # compiled/loaded via jac0, never the full compiler.
        sealed = _sealed.find_module(module.__name__)
        if (
            sealed is not None and sealed[1].get("bootstrap")
        ) or self._is_bootstrap_jac(file_path):
            self._exec_bootstrap(module, file_path)
            return

        from jaclang.jac0core.runtime import JacRuntime as Jac

        is_pkg = module.__spec__.submodule_search_locations is not None

        # Register module in JacRuntime's tracking (skip internal jaclang modules)
        if not module.__name__.startswith("jaclang."):
            Jac.load_module(module.__name__, module)

        # Get and execute bytecode using the compiler singleton
        compiler = Jac.get_compiler()
        program = Jac.get_program()
        is_py = file_path.endswith(".py")
        try:
            codeobj = compiler.get_bytecode(
                full_target=file_path,
                target_program=program,
            )
        except Exception as exc:
            # GraphMend-claimed .py that jac can't compile: never break the
            # import -- fall back to running the original Python source. Worst
            # case is "not transformed", not a crash.
            if is_py and self._exec_py_source_fallback(module, file_path):
                _report_abandoned_claim(
                    file_path, f"the Jac front end failed with {exc!r}"
                )
                return
            raise
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
            # A GraphMend-claimed .py that produced no bytecode still has usable
            # original source; run it untransformed rather than failing the
            # import. Tried before the diagnostic raise below.
            if is_py and self._exec_py_source_fallback(module, file_path):
                _report_abandoned_claim(
                    file_path, "the Jac front end produced no bytecode for it"
                )
                return
            alerts = _module_scoped_alerts(program, file_path)
            if not alerts:
                # Files under the jaclang tree compile into the compiler's
                # internal program, so their diagnostics live there rather
                # than in the runtime program handed to us.
                internal = getattr(compiler, "internal_program", None)
                if internal is not None:
                    alerts = _module_scoped_alerts(internal, file_path)
            details = "\n".join(a.pretty_print() for a in alerts)
            if not details:
                details = _retained_failure_details(file_path)
            if details:
                raise JacSourceCompileError(
                    f"{file_path} failed to compile:\n{details}", file_path
                )
            raise JacSourceCompileError(
                f"No bytecode found for {file_path}", file_path
            )

        # MTIR is written keyed by file stem but byllm looks up by func.__module__;
        # re-key to the fullname so submodule imports resolve. __main__ is already
        # resolved back to its stem at lookup time.
        fullname = module.__name__
        stem = os.path.splitext(os.path.basename(file_path))[0]
        for suffix in ext_registry.STEM_REKEY_SUFFIXES:
            if stem.endswith(suffix):
                stem = stem[: -len(suffix)]
                break
        if fullname and stem and fullname != stem and fullname != "__main__":
            prefix = stem + "."
            renamed = {
                fullname + "." + key[len(prefix) :]: program.mtir_map.pop(key)
                for key in list(program.mtir_map)
                if key.startswith(prefix)
            }
            program.mtir_map.update(renamed)

        # Inject native interop infrastructure if needed (sv↔na interop)
        native_engine, interop_py_funcs = compiler.get_native_interop_setup(
            file_path, program
        )
        if native_engine is not None:
            module.__dict__["__jac_native_engine__"] = native_engine
        # Always inject interop_py_funcs if it's the actual dict from compilation
        # (not None). The dict may be empty initially but will be populated when
        # bytecode executes. Late-binding callbacks reference this same dict.
        if interop_py_funcs is not None:
            module.__dict__["__jac_interop_py_funcs__"] = interop_py_funcs

        # Execute the bytecode directly in the module's namespace
        exec(codeobj, module.__dict__)

        # An inferred-native module keeps its plain python side for python
        # callers (the preference must not route sv-side calls through the
        # marshal bridge); sv->na calls go through the interop stubs the
        # manifest generates. Sealed compiler-native modules bind through
        # the AOT artifact instead (see _exec_bootstrap).

    def get_source(self, fullname: str) -> str | None:
        """Return module source text when available.

        For sealed modules the ``.jac`` file is absent, but a ``--debug-src``
        image embeds the source in the JIR; ``linecache`` calls this to render
        source lines in tracebacks. Returns None when no debug source exists
        (release images), which leaves tracebacks with file:line but no echo.
        """
        return _sealed.source_for(fullname)

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.jac0core.runtime import JacRuntime as Jac

        # Sealed image is authoritative (see find_spec): resolve a sealed module
        # by name from the manifest, no filesystem probing. One lookup: the
        # bootstrap tier loads via bootstrap_code, the rest via get_bytecode at
        # the virtual origin.
        found = _sealed.find_module(fullname)
        if found is not None:
            image, entry, src_rel = found
            if entry.get("bootstrap"):
                return image.bootstrap_code(fullname)
            return Jac.get_compiler().get_bytecode(
                full_target=image.virtual_origin(src_rel),
                target_program=Jac.get_program(),
            )

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        compiler = Jac.get_compiler()
        program = Jac.get_program()

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package (shared __init__ precedence).
            if os.path.isdir(candidate_path):
                for init_name in ext_registry.INIT_FILES:
                    init_file = os.path.join(candidate_path, init_name)
                    if os.path.isfile(init_file):
                        return compiler.get_bytecode(
                            full_target=init_file,
                            target_program=program,
                        )
            # Check for a module file in codespace precedence order.
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return compiler.get_bytecode(
                        full_target=module_file,
                        target_program=program,
                    )

        return None
