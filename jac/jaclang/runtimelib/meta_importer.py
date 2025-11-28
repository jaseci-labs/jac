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

from jaclang.runtimelib.runtime import JacRuntime as Jac
from jaclang.runtimelib.runtime import JacRuntimeInterface
from jaclang.settings import settings
from jaclang.utils.log import logging
from jaclang.utils.module_resolver import get_jac_search_paths, get_py_search_paths

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
            if os.path.isfile(candidate_path + ".jac"):
                return importlib.util.spec_from_file_location(
                    fullname, candidate_path + ".jac", loader=self
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
        if not module.__spec__ or not module.__spec__.origin:
            raise ImportError(
                f"Cannot find spec or origin for module {module.__name__}"
            )

        file_path = module.__spec__.origin
        is_pkg = module.__spec__.submodule_search_locations is not None

        # Register module in JacRuntime's tracking
        JacRuntimeInterface.load_module(module.__name__, module)

        # Get and execute bytecode
        codeobj = Jac.program.get_bytecode(full_target=file_path)
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
            raise ImportError(f"No bytecode found for {file_path}")
        # Execute the bytecode directly in the module's namespace
        exec(codeobj, module.__dict__)
