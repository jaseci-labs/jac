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
import sys
from collections.abc import Sequence
from types import ModuleType

from jaclang.pycore.log import logging
from jaclang.pycore.module_resolver import (
    get_jac_search_paths,
    get_py_search_paths,
)
from jaclang.pycore.settings import settings

logger = logging.getLogger(__name__)


class _ByllmFallbackClass:
    """A fallback class that can be instantiated and returns None for any attribute."""

    def __init__(self, *args: object, **kwargs: object) -> None:
        """Accept any arguments and store them."""
        pass

    def __getattr__(self, name: str) -> None:
        """Return None for any attribute access."""
        return None

    def __call__(self, *args: object, **kwargs: object) -> _ByllmFallbackClass:
        """Return self when called to allow chaining."""
        # Return a new instance when called as a constructor
        return _ByllmFallbackClass()


class ByllmFallbackLoader(importlib.abc.Loader):
    """Fallback loader for byllm when it's not installed."""

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create a placeholder module."""
        return None  # use default machinery

    def exec_module(self, module: ModuleType) -> None:
        """Populate the module with fallback classes."""
        # Set common attributes
        module.__dict__["__all__"] = []
        module.__file__ = None
        module.__path__ = []

        # Use a custom __getattr__ to return fallback classes for any attribute access
        def _getattr(name: str) -> type[_ByllmFallbackClass]:
            if not name.startswith("_"):
                # Return a fallback class that can be instantiated
                return _ByllmFallbackClass
            raise AttributeError(f"module 'byllm' has no attribute '{name}'")

        module.__getattr__ = _getattr  # type: ignore


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    byllm_found: bool = False

    # Modules that require minimal compilation to avoid circular imports.
    # These are bootstrap-critical modules in runtimelib and compiler.
    MINIMAL_COMPILE_MODULES: frozenset[str] = frozenset(
        {
            "jaclang.runtimelib.builtin",
            "jaclang.runtimelib.utils",
            "jaclang.runtimelib.server",
            "jaclang.runtimelib.client_bundle",
            # Compiler passes converted to Jac must use minimal compilation
            # to avoid circular imports (they're used during compilation itself)
            "jaclang.compiler.passes.main.sem_def_match_pass",
            "jaclang.compiler.passes.main.annex_pass",
            "jaclang.compiler.passes.main.semantic_analysis_pass",
            "jaclang.compiler.passes.main.def_use_pass",
            "jaclang.compiler.passes.main.pyjac_ast_link_pass",
            "jaclang.compiler.passes.main.import_pass",
            "jaclang.compiler.passes.main.type_checker_pass",
            "jaclang.compiler.passes.main.def_impl_match_pass",
            "jaclang.compiler.passes.main.cfg_build_pass",
            "jaclang.compiler.passes.main.pyast_load_pass",
            # ECMAScript codegen modules are used by the full codegen schedule,
            # so compiling them requires a minimal schedule to avoid cycles.
            "jaclang.compiler.passes.ecmascript.estree",
            "jaclang.compiler.passes.ecmascript.es_unparse",
            "jaclang.compiler.passes.ecmascript.esast_gen_pass",
        }
    )

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        """Find the spec for the module."""
        # Handle case where no byllm plugin is installed
        if fullname == "byllm" or fullname.startswith("byllm."):
            # Check if byllm is actually installed by looking for it in sys.path
            # We use importlib.util.find_spec with a custom path to avoid recursion

            for finder in sys.meta_path:
                if finder is self:
                    continue

                if hasattr(finder, "find_spec"):
                    try:
                        spec = finder.find_spec(fullname, path, target)
                        if spec is not None:
                            JacMetaImporter.byllm_found = True
                            break
                    except (ImportError, AttributeError):
                        continue

            if not JacMetaImporter.byllm_found:
                # If byllm is not installed, return a spec for our fallback loader
                print(
                    f"Please install a byllm plugin, but for now patching {fullname} with NonGPT"
                )
                return importlib.machinery.ModuleSpec(
                    fullname,
                    ByllmFallbackLoader(),
                    is_package=fullname == "byllm",
                )

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
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                # For bootstrap modules, prefer .py if it exists alongside .jac
                # This allows Python versions to be used during bootstrap
                if fullname in self.MINIMAL_COMPILE_MODULES:
                    py_file = candidate_path + ".py"
                    if os.path.isfile(py_file):
                        # Let Python's standard import handle the .py file
                        return None
                return importlib.util.spec_from_file_location(
                    fullname, jac_file, loader=self
                )

        # TODO: We can remove it once python modules are fully supported in jac
        if path is None and settings.pyfile_raise:
            paths_to_search = (
                get_jac_search_paths()
                if settings.pyfile_raise_full
                else get_py_search_paths()
            )
            for search_path in paths_to_search:
                candidate_path = os.path.join(search_path, *module_path_parts)
                # Check for directory package
                if os.path.isdir(candidate_path):
                    init_file = os.path.join(candidate_path, "__init__.py")
                    if os.path.isfile(init_file):
                        return importlib.util.spec_from_file_location(
                            fullname,
                            init_file,
                            loader=self,
                            submodule_search_locations=[candidate_path],
                        )
                # Check for .py file
                if os.path.isfile(candidate_path + ".py"):
                    return importlib.util.spec_from_file_location(
                        fullname, candidate_path + ".py", loader=self
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

        # Register module in JacRuntime's tracking
        Jac.load_module(module.__name__, module)

        # Use minimal compilation for bootstrap-critical modules to avoid
        # circular imports (these modules are needed by the compiler itself)
        use_minimal = module.__name__ in self.MINIMAL_COMPILE_MODULES

        # Get and execute bytecode
        codeobj = Jac.program.get_bytecode(full_target=file_path, minimal=use_minimal)
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

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package
            if os.path.isdir(candidate_path):
                init_file = os.path.join(candidate_path, "__init__.jac")
                if os.path.isfile(init_file):
                    use_minimal = fullname in self.MINIMAL_COMPILE_MODULES
                    return Jac.program.get_bytecode(
                        full_target=init_file, minimal=use_minimal
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                use_minimal = fullname in self.MINIMAL_COMPILE_MODULES
                return Jac.program.get_bytecode(
                    full_target=jac_file, minimal=use_minimal
                )

        return None
