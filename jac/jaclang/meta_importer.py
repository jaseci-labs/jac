"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import importlib.util
import os
from collections.abc import Sequence
from functools import cache
from pathlib import Path
from types import ModuleType

from jaclang.pycore.log import logging
from jaclang.pycore.modresolver import (
    get_jac_search_paths,
)

logger = logging.getLogger(__name__)


@cache
def _discover_minimal_compile_modules() -> frozenset[str]:
    """Auto-discover .jac compiler passes that need minimal compilation."""
    jaclang_dir = Path(__file__).parent
    passes_dir = jaclang_dir / "compiler" / "passes"
    modules = set()

    for subdir in ["main", "ecmascript", "native"]:
        for jac_file in (passes_dir / subdir).rglob("*.jac"):
            if jac_file.name.endswith(".impl.jac"):
                continue
            module_path = jac_file.relative_to(jaclang_dir).with_suffix("")
            modules.add(f"jaclang.{module_path.as_posix().replace('/', '.')}")

    return frozenset(modules)


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    @property
    def MINIMAL_COMPILE_MODULES(self) -> frozenset[str]:  # noqa: N802
        """Compiler passes written in Jac that need minimal compilation."""
        return _discover_minimal_compile_modules()

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

        return None

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None  # use default machinery

    def exec_module(self, module: ModuleType) -> None:
        """Execute the module by loading and executing its bytecode.

        This method implements PEP 451's exec_module() protocol, which separates
        module creation from execution. It handles both package (__init__.jac) and
        regular module (.jac/.py) execution.
        """
        from jaclang.pycore.runtime import JacRuntime as Jac

        if not module.__spec__ or not module.__spec__.origin:
            raise ImportError(
                f"Cannot find spec or origin for module {module.__name__}"
            )

        file_path = module.__spec__.origin
        is_pkg = module.__spec__.submodule_search_locations is not None

        # Register module in JacRuntime's tracking (skip internal jaclang modules)
        if not module.__name__.startswith("jaclang."):
            Jac.load_module(module.__name__, module)

        # Use minimal compilation for compiler passes to avoid circular imports
        use_minimal = module.__name__ in self.MINIMAL_COMPILE_MODULES

        # Get and execute bytecode using the compiler singleton
        codeobj = Jac.get_compiler().get_bytecode(
            full_target=file_path,
            target_program=Jac.get_program(),
            minimal=use_minimal,
        )
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
            raise ImportError(f"No bytecode found for {file_path}")
        # Execute the bytecode directly in the module's namespace
        exec(codeobj, module.__dict__)

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.pycore.runtime import JacRuntime as Jac

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        # Use minimal compilation for compiler passes to avoid circular imports
        use_minimal = fullname in self.MINIMAL_COMPILE_MODULES

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
                        minimal=use_minimal,
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return compiler.get_bytecode(
                        full_target=init_cl_file,
                        target_program=program,
                        minimal=use_minimal,
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return compiler.get_bytecode(
                    full_target=jac_file,
                    target_program=program,
                    minimal=use_minimal,
                )
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return compiler.get_bytecode(
                    full_target=cl_jac_file,
                    target_program=program,
                    minimal=use_minimal,
                )

        return None
