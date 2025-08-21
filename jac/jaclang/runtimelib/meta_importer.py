"""Jac meta path importer."""

import importlib.abc
import importlib.machinery
import importlib.util
import os
from types import ModuleType
from typing import Optional, Sequence

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.runtimelib.machine import JacMachineInterface
from jaclang.utils.module_resolver import get_jac_search_paths


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    def find_spec(
        self,
        fullname: str,
        path: Optional[Sequence[str]] = None,
        target: Optional[ModuleType] = None,
    ) -> Optional[importlib.machinery.ModuleSpec]:
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
            # Check for .jac file
            if os.path.isfile(candidate_path + ".jac"):
                return importlib.util.spec_from_file_location(
                    fullname, candidate_path + ".jac", loader=self
                )
        return None

    def create_module(
        self, spec: importlib.machinery.ModuleSpec
    ) -> Optional[ModuleType]:
        """Create the module."""
        return None  # use default machinery

    def exec_module(self, module: ModuleType) -> None:
        """Execute the module."""
        if not module.__spec__ or not module.__spec__.origin:
            raise ImportError(
                f"Cannot find spec or origin for module {module.__name__}"
            )
        file_path = module.__spec__.origin
        is_pkg = module.__spec__.submodule_search_locations is not None

        if is_pkg:
            codeobj = Jac.program.get_bytecode(full_target=file_path)
            if codeobj:
                exec(codeobj, module.__dict__)
            JacMachineInterface.load_module(module.__name__, module)
            return

        base_path = os.path.dirname(file_path)
        target = os.path.splitext(os.path.basename(file_path))[0]
        ret = JacMachineInterface.jac_import(
            target=target,
            base_path=base_path,
            override_name=module.__name__,
        )
        if ret:
            loaded_module = ret[0]
            module.__dict__.update(loaded_module.__dict__)
        else:
            raise ImportError(f"Unable to import {module.__name__}")
