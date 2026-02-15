"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import importlib.util
import logging
import os
import shutil
import sys
import types
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType


def _handle_early_purge() -> None:
    """Handle 'jac purge -f' before any Jac initialization.

    This allows cache cleanup even when cache is corrupted.
    Requires -f flag to prevent accidental triggering.
    """
    if not (
        len(sys.argv) >= 3
        and os.path.basename(sys.argv[0]) == "jac"
        and sys.argv[1] == "purge"
        and sys.argv[2] == "-f"
    ):
        return

    def _get_cache_dir() -> Path:
        if sys.platform == "win32":
            base = Path(
                os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")
            )
            return base / "jac" / "cache" / "bytecode"
        elif sys.platform == "darwin":
            return Path.home() / "Library" / "Caches" / "jac" / "bytecode"
        else:
            xdg = os.environ.get("XDG_CACHE_HOME")
            base = Path(xdg) if xdg else (Path.home() / ".cache")
            return base / "jac" / "bytecode"

    cache_dir = _get_cache_dir()
    if not cache_dir.exists():
        print(f"Cache directory does not exist: {cache_dir}")  # noqa: T201
        sys.stdout.flush()
        os._exit(0)

    file_count = sum(1 for f in cache_dir.iterdir() if f.is_file())
    total_size = sum(f.stat().st_size for f in cache_dir.iterdir() if f.is_file())

    try:
        shutil.rmtree(cache_dir)
        print(f"Purged {file_count} cached files ({total_size / 1024:.1f} KB)")  # noqa: T201
        print(f"Removed: {cache_dir}")  # noqa: T201
        sys.stdout.flush()
        os._exit(0)
    except OSError as e:
        print(f"Error purging cache: {e}", file=sys.stderr)  # noqa: T201
        sys.stderr.flush()
        os._exit(1)


_handle_early_purge()

from jaclang.jac0 import compile_jac as _jac0_compile  # noqa: E402

# Inline logging config (previously in jaclang.jac0core.log)
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")

# Bootstrap modresolver.jac with jac0 before JacMetaImporter is registered.
# This module must be available for find_spec()/get_code(), but normal
# .jac imports are not yet operational at this point.
_jac0core_dir = os.path.join(os.path.dirname(__file__), "jac0core")
_modresolver_jac = os.path.join(_jac0core_dir, "modresolver.jac")
with open(_modresolver_jac, encoding="utf-8") as _f:
    _py_src = _jac0_compile(_f.read(), _modresolver_jac)
_modresolver = types.ModuleType("jaclang.jac0core.modresolver")
_modresolver.__file__ = _modresolver_jac
_modresolver.__package__ = "jaclang.jac0core"
exec(compile(_py_src, _modresolver_jac, "exec"), _modresolver.__dict__)  # noqa: S102
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
            # Check for directory package
            if os.path.isdir(candidate_path):
                init_file = os.path.join(candidate_path, "__init__.jac")
                if os.path.isfile(init_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
                init_sv_file = os.path.join(candidate_path, "__init__.sv.jac")
                if os.path.isfile(init_sv_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_sv_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_cl_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, jac_file, loader=self
                )
            # Check for .sv.jac file (server-side explicit)
            sv_jac_file = candidate_path + ".sv.jac"
            if os.path.isfile(sv_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, sv_jac_file, loader=self
                )
            # Check for .cl.jac file (client-side)
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, cl_jac_file, loader=self
                )
            # Check for .na.jac file (native)
            na_jac_file = candidate_path + ".na.jac"
            if os.path.isfile(na_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, na_jac_file, loader=self
                )

        return None

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None  # use default machinery

    def _exec_bootstrap(self, module: ModuleType, file_path: str) -> None:
        """Execute a bootstrap .jac module using jac0 (in-memory, no disk I/O).

        Bootstrap modules are part of the jaclang compiler infrastructure.
        They are compiled with the lightweight jac0 transpiler rather than
        the full Jac compiler, which depends on them.
        """
        from jaclang.jac0 import compile_jac, discover_impl_files

        with open(file_path, encoding="utf-8") as f:
            jac_source = f.read()

        impl_sources: list[tuple[str, str]] = []
        for impl_path in discover_impl_files(file_path):
            with open(impl_path, encoding="utf-8") as f:
                impl_sources.append((f.read(), impl_path))

        py_source = compile_jac(jac_source, file_path, impl_sources=impl_sources)
        code = compile(py_source, file_path, "exec")
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

        # Bootstrap path: .jac files inside jaclang/ are compiled with jac0
        if self._is_bootstrap_jac(file_path):
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

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.jac0core.runtime import JacRuntime as Jac

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        compiler = Jac.get_compiler()
        program = Jac.get_program()

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package
            if os.path.isdir(candidate_path):
                init_file = os.path.join(candidate_path, "__init__.jac")
                if os.path.isfile(init_file):
                    return compiler.get_bytecode(
                        full_target=init_file,
                        target_program=program,
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return compiler.get_bytecode(
                        full_target=init_cl_file,
                        target_program=program,
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return compiler.get_bytecode(
                    full_target=jac_file,
                    target_program=program,
                )
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return compiler.get_bytecode(
                    full_target=cl_jac_file,
                    target_program=program,
                )

        return None
