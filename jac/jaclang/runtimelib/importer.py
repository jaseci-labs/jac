"""Special Imports for Jac Code."""

from __future__ import annotations

import importlib
import importlib.util
import os
import sys
import types
from os import getcwd, path
from typing import Optional, Union

from jaclang.runtimelib.machine import JacMachineInterface
from jaclang.runtimelib.utils import sys_path_context
from jaclang.utils.helpers import dump_traceback
from jaclang.utils.log import logging
from jaclang.utils.module_resolver import get_jac_search_paths

logger = logging.getLogger(__name__)


class ImportPathSpec:
    """Import Specification."""

    def __init__(
        self,
        target: str,
        base_path: str,
        absorb: bool,
        mdl_alias: Optional[str],
        override_name: Optional[str],
        lng: Optional[str],
        items: Optional[dict[str, Union[str, Optional[str]]]],
    ) -> None:
        """Initialize the ImportPathSpec object."""
        self.target = target
        self.base_path = base_path
        self.absorb = absorb
        self.mdl_alias = mdl_alias
        self.override_name = override_name
        self.language = lng
        self.items = items
        self.dir_path, self.file_name = path.split(path.join(*(target.split("."))))
        self.module_name = path.splitext(self.file_name)[0]
        self.package_path = self.dir_path.replace(path.sep, ".")
        self.caller_dir = self.get_caller_dir()
        self.full_target = path.abspath(path.join(self.caller_dir, self.file_name))

    def get_caller_dir(self) -> str:
        """Get the directory of the caller."""
        caller_dir = (
            self.base_path
            if path.isdir(self.base_path)
            else path.dirname(self.base_path)
        )
        caller_dir = caller_dir if caller_dir else getcwd()
        chomp_target = self.target
        if chomp_target.startswith("."):
            chomp_target = chomp_target[1:]
            while chomp_target.startswith("."):
                caller_dir = path.dirname(caller_dir)
                chomp_target = chomp_target[1:]
        return path.join(caller_dir, self.dir_path)


class ImportReturn:
    """Import Return Object."""

    def __init__(
        self,
        ret_mod: types.ModuleType,
        ret_items: list[types.ModuleType],
        importer: Importer,
    ) -> None:
        """Initialize the ImportReturn object."""
        self.ret_mod = ret_mod
        self.ret_items = ret_items
        self.importer = importer

    def process_items(
        self,
        module: types.ModuleType,
        items: dict[str, Union[str, Optional[str]]],
        lang: Optional[str],
    ) -> None:
        """Process items within a module by handling renaming and potentially loading missing attributes."""

        def handle_item_loading(
            item: types.ModuleType, alias: Union[str, Optional[str]]
        ) -> None:
            if item:
                self.ret_items.append(item)
                setattr(module, name, item)
                if alias and alias != name and not isinstance(alias, bool):
                    setattr(module, alias, item)

        for name, alias in items.items():
            item = getattr(module, name)
            handle_item_loading(item, alias)

    def load_jac_mod_as_item(
        self,
        module: types.ModuleType,
        name: str,
        jac_file_path: str,
    ) -> Optional[types.ModuleType]:
        """Load a single .jac file into the specified module component."""
        from jaclang.runtimelib.machine import JacMachine

        try:
            package_name = (
                f"{module.__name__}.{name}"
                if hasattr(module, "__path__")
                else module.__name__
            )
            if isinstance(self.importer, JacImporter):
                new_module = JacMachine.loaded_modules.get(
                    package_name,
                    self.importer.create_jac_py_module(
                        self.importer.get_sys_mod_name(jac_file_path),
                        module.__name__,
                        jac_file_path,
                    ),
                )
            codeobj = JacMachine.program.get_bytecode(full_target=jac_file_path)
            if not codeobj:
                raise ImportError(f"No bytecode found for {jac_file_path}")

            exec(codeobj, new_module.__dict__)
            return getattr(new_module, name, new_module)
        except ImportError as e:
            logger.error(dump_traceback(e))
            return None


class Importer:
    """Abstract base class for all importers."""

    def __init__(self) -> None:
        """Initialize the Importer object."""
        self.result: Optional[ImportReturn] = None

    def run_import(self, spec: ImportPathSpec) -> ImportReturn:
        """Run the import process."""
        raise NotImplementedError


class PythonImporter(Importer):
    """Importer for Python modules."""

    def _create_module_from_file(
        self, target_name: str, file_path: str, module_name: str
    ) -> types.ModuleType:
        """Create and execute a module from a file path."""
        imp_spec = importlib.util.spec_from_file_location(target_name, file_path)
        if not imp_spec or not imp_spec.loader:
            raise ImportError(f"Cannot create import spec for {file_path}")

        imported_module = importlib.util.module_from_spec(imp_spec)
        imported_module.__name__ = module_name
        sys.modules[module_name] = imported_module
        imp_spec.loader.exec_module(imported_module)
        return imported_module

    def _handle_relative_import(self, spec: ImportPathSpec) -> types.ModuleType:
        """Handle relative imports (starting with '.')."""
        target = spec.target.lstrip(".")
        if len(target.split(".")) > 1:
            target = target.split(".")[-1]

        full_target = path.normpath(path.join(spec.caller_dir, target))
        return self._create_module_from_file(target, full_target + ".py", target)

    def _handle_absolute_import(self, spec: ImportPathSpec) -> types.ModuleType:
        """Handle absolute imports."""
        local_py_file = spec.full_target + ".py"

        if os.path.exists(local_py_file):
            # Handle local Python file
            module_name = spec.override_name or spec.target
            target_name = "__main__" if spec.override_name == "__main__" else spec.target
            return self._create_module_from_file(target_name, local_py_file, module_name)
        else:
            # Handle standard library or installed package
            return importlib.import_module(name=spec.target)

    def _process_absorb_import(self, imported_module: types.ModuleType) -> None:
        """Process absorb import by copying all public attributes to main module."""
        main_module = __import__("__main__")
        for name in dir(imported_module):
            if not name.startswith("_"):
                setattr(main_module, name, getattr(imported_module, name))

    def _process_selective_import(
        self, imported_module: types.ModuleType, spec: ImportPathSpec
    ) -> list:
        """Process selective import of specific items."""
        main_module = __import__("__main__")
        loaded_items = []

        for name, alias in spec.items.items():
            alias = name if isinstance(alias, bool) else alias

            try:
                item = getattr(imported_module, name)
            except AttributeError:
                if hasattr(imported_module, "__path__"):
                    item = importlib.import_module(f"{spec.target}.{name}")
                else:
                    raise

            if item not in loaded_items:
                setattr(main_module, alias or name, item)
                loaded_items.append(item)

        return loaded_items

    def _process_module_import(self, imported_module: types.ModuleType, spec: ImportPathSpec) -> None:
        """Process regular module import."""
        main_module = __import__("__main__")
        module_alias = spec.mdl_alias or spec.target
        setattr(main_module, module_alias, imported_module)

    def run_import(self, spec: ImportPathSpec) -> ImportReturn:
        """Run the import process for Python modules."""
        try:
            # Determine import type and get module
            if spec.target.startswith("."):
                imported_module = self._handle_relative_import(spec)
            else:
                imported_module = self._handle_absolute_import(spec)

            # Process based on import mode
            if spec.absorb:
                self._process_absorb_import(imported_module)
                loaded_items = []
            elif spec.items:
                loaded_items = self._process_selective_import(imported_module, spec)
            else:
                self._process_module_import(imported_module, spec)
                loaded_items = []

            self.result = ImportReturn(imported_module, loaded_items, self)
            return self.result

        except ImportError as e:
            raise e


class JacImporter(Importer):
    """Importer for Jac modules."""

    def get_sys_mod_name(self, full_target: str) -> str:
        """Generate proper module names from file paths."""
        from jaclang.runtimelib.machine import JacMachine

        full_target = os.path.abspath(full_target)

        # If the file is located within a site-packages directory, strip that prefix.
        sp_index = full_target.find("site-packages")
        if sp_index != -1:
            # Remove the site-packages part and any leading separator.
            rel = full_target[sp_index + len("site-packages") :]
            rel = rel.lstrip(os.sep)
        else:
            rel = path.relpath(full_target, start=JacMachine.base_path_dir)
        rel = os.path.splitext(rel)[0]
        if os.path.basename(rel) == "__init__":
            rel = os.path.dirname(rel)
        mod_name = rel.replace(os.sep, ".").strip(".")
        return mod_name

    def handle_directory(
        self, module_name: str, full_mod_path: str
    ) -> types.ModuleType:
        """Import from a directory that potentially contains multiple Jac modules."""
        module_name = self.get_sys_mod_name(full_mod_path)
        module = types.ModuleType(module_name)
        module.__name__ = module_name
        module.__path__ = [full_mod_path]
        module.__file__ = None

        JacMachineInterface.load_module(module_name, module)

        # If the directory contains an __init__.jac, execute it so that the
        # package namespace is populated immediately (mirrors Python's own
        # package behaviour with __init__.py).
        init_jac = os.path.join(full_mod_path, "__init__.jac")
        if os.path.isfile(init_jac):
            from jaclang.runtimelib.machine import JacMachine

            # Point the package's __file__ to the init file for introspection
            module.__file__ = init_jac

            codeobj = JacMachine.program.get_bytecode(full_target=init_jac)
            if not codeobj:
                # Compilation should have provided bytecode for __init__.jac.
                # Raising ImportError here surfaces compile-time issues clearly.
                raise ImportError(f"No bytecode found for {init_jac}")

            try:
                # Ensure the directory is on sys.path while executing so that
                # relative imports inside __init__.jac resolve correctly.
                with sys_path_context(full_mod_path):
                    exec(codeobj, module.__dict__)
            except Exception as e:
                # Log detailed traceback for easier debugging and re-raise.
                logger.error(e)
                logger.error(dump_traceback(e))
                raise e

        return module

    def create_jac_py_module(
        self,
        module_name: str,
        package_path: str,
        full_target: str,
    ) -> types.ModuleType:
        """Create a module."""
        from jaclang.runtimelib.machine import JacMachine

        module = types.ModuleType(module_name)
        module.__file__ = full_target
        module.__name__ = module_name
        if package_path:
            base_path = full_target.split(package_path.replace(".", path.sep))[0]
            parts = package_path.split(".")
            for i in range(len(parts)):
                package_name = ".".join(parts[: i + 1])
                if package_name not in JacMachine.loaded_modules:
                    full_mod_path = path.join(
                        base_path, package_name.replace(".", path.sep)
                    )
                    self.handle_directory(
                        module_name=package_name,
                        full_mod_path=full_mod_path,
                    )
        JacMachineInterface.load_module(module_name, module)
        return module

    def run_import(
        self, spec: ImportPathSpec, reload: Optional[bool] = False
    ) -> ImportReturn:
        """Run the import process for Jac modules."""
        from jaclang.runtimelib.machine import JacMachine

        unique_loaded_items: list[types.ModuleType] = []
        module = None
        # Gather all possible search paths
        search_paths = get_jac_search_paths(spec.caller_dir)

        found_path = None
        target_path_components = spec.target.split(".")
        for search_path in search_paths:
            candidate = os.path.join(search_path, *target_path_components)
            # Check if the candidate is a directory or a .jac file
            if (os.path.isdir(candidate)) or (os.path.isfile(candidate + ".jac")):
                found_path = candidate
                break

        # If a suitable path was found, update spec.full_target; otherwise, raise an error
        if found_path:
            spec.full_target = os.path.abspath(found_path)
        elif os.path.exists(spec.full_target) or os.path.exists(
            spec.full_target + ".jac"
        ):
            pass
        else:
            raise ImportError(
                f"Unable to locate module '{spec.target}' in {search_paths}"
            )
        if os.path.isfile(spec.full_target + ".jac"):
            module_name = self.get_sys_mod_name(spec.full_target + ".jac")
            module_name = spec.override_name if spec.override_name else module_name
        else:
            module_name = self.get_sys_mod_name(spec.full_target)

        module = JacMachine.loaded_modules.get(module_name)

        if not module or module.__name__ == "__main__" or reload:
            if os.path.isdir(spec.full_target):
                module = self.handle_directory(spec.module_name, spec.full_target)
            else:
                spec.full_target += ".jac" if spec.language == "jac" else ".py"
                module = self.create_jac_py_module(
                    module_name,
                    spec.package_path,
                    spec.full_target,
                )
                codeobj = JacMachine.program.get_bytecode(full_target=spec.full_target)

                # Since this is a compile time error, we can safely raise an exception here.
                if not codeobj:
                    raise ImportError(f"No bytecode found for {spec.full_target}")

                try:
                    with sys_path_context(spec.caller_dir):
                        exec(codeobj, module.__dict__)
                except Exception as e:
                    logger.error(e)
                    logger.error(dump_traceback(e))
                    raise e

        import_return = ImportReturn(module, unique_loaded_items, self)
        if spec.items:
            import_return.process_items(
                module=module, items=spec.items, lang=spec.language
            )
        self.result = import_return
        return self.result