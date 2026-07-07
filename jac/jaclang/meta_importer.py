"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

from __future__ import annotations

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
        # parallel xdist workers) can't read a half-written cache file.
        tmp_file = cache_file.with_suffix(cache_file.suffix + f".{os.getpid()}.tmp")
        try:
            tmp_file.write_bytes(marshal.dumps(code))
            os.replace(tmp_file, cache_file)
        finally:
            tmp_file.unlink(missing_ok=True)
    except OSError:
        pass

    return code


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

        return None

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
        codeobj = compiler.get_bytecode(
            full_target=file_path,
            target_program=program,
        )
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
            raise ImportError(f"No bytecode found for {file_path}")

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

        # Auto-install native wrappers if native engine is available
        if native_engine is not None:
            layout = compiler.get_native_layout(file_path, program)
            if layout is not None:
                try:
                    from jaclang.jac0core.native_marshal import (
                        install_native_wrappers,
                    )

                    count = install_native_wrappers(module, native_engine, layout)
                    if count > 0:
                        import logging

                        logging.getLogger(__name__).debug(
                            f"Installed {count} native wrappers for {file_path}"
                        )
                except Exception as e:
                    import logging

                    logging.getLogger(__name__).debug(
                        f"Native wrapper install failed for {file_path}: {e}"
                    )

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
