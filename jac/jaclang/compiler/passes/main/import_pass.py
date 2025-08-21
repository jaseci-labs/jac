"""Module Import Resolution Pass for the Jac compiler.

This pass handles the static resolution and loading of imported modules by:

1. Identifying import statements in the source code
2. Resolving module paths (both relative and absolute)
3. Loading and parsing the imported modules
4. Handling both Jac and Python imports with appropriate strategies
5. Managing import dependencies and preventing circular imports
6. Supporting various import styles:
   - Direct imports (import x)
   - From imports (from x import y)
   - Star imports (from x import *)
   - Aliased imports (import x as y)

The pass runs early in the compilation pipeline to ensure all symbols from imported
modules are available for subsequent passes like symbol table building and type checking.
"""

import os

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import Transform, UniPass
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.log import logging


logger = logging.getLogger(__name__)


# TODO: This pass finds imports dependencies, parses them, and adds them to
# JacProgram's table, then table calls again if needed, should rename
class JacImportDepsPass(Transform[uni.Module, uni.Module]):
    """Jac statically imports Jac modules."""

    def pre_transform(self) -> None:
        """Initialize the JacImportPass."""
        super().pre_transform()
        self.last_imported: list[uni.Module] = []

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Run Importer."""
        # Add the current module to last_imported to start the import process
        self.last_imported.append(ir_in)

        # Process imports until no more imported modules to process
        while self.last_imported:
            current_module = self.last_imported.pop(0)
            all_imports = UniPass.get_all_sub_nodes(current_module, uni.ModulePath)
            for i in all_imports:
                self.process_import(i)

        return ir_in

    def process_import(self, i: uni.ModulePath) -> None:
        """Process an import."""
        imp_node = i.parent_of_type(uni.Import)
        if imp_node.is_jac:
            self.import_jac_module(node=i)

    def import_jac_module(self, node: uni.ModulePath) -> None:
        """Import a module."""
        target = node.resolve_relative_path()
        # If the module is a package (dir)
        if os.path.isdir(target):
            self.load_mod(self.import_jac_mod_from_dir(target))
            import_node = node.parent_of_type(uni.Import)
            # And the import is a from import and I am the from module
            if node == import_node.from_loc:
                # Import all from items as modules or packages
                for i in import_node.items:
                    if isinstance(i, uni.ModuleItem):
                        from_mod_target = node.resolve_relative_path(i.name.value)
                        # If package
                        if os.path.isdir(from_mod_target):
                            self.load_mod(self.import_jac_mod_from_dir(from_mod_target))
                        # Else module
                        else:
                            if from_mod_target in self.prog.mod.hub:
                                return
                            self.load_mod(self.prog.compile(file_path=from_mod_target))
        else:
            if target in self.prog.mod.hub:
                return
            self.load_mod(self.prog.compile(file_path=target))

    def load_mod(self, mod: uni.Module) -> None:
        """Attach a module to a node."""
        self.prog.mod.hub[mod.loc.mod_path] = mod
        self.last_imported.append(mod)

    # TODO: Refactor this to a function for impl and function for test

    def import_jac_mod_from_dir(self, target: str) -> uni.Module:
        """Import a module from a directory."""
        jac_init_path = os.path.join(target, "__init__.jac")
        if os.path.exists(jac_init_path):
            if jac_init_path in self.prog.mod.hub:
                return self.prog.mod.hub[jac_init_path]
            return self.prog.compile(file_path=jac_init_path)
        elif os.path.exists(py_init_path := os.path.join(target, "__init__.py")):
            file_source = read_file_with_encoding(py_init_path)
            mod = uni.Module.make_stub(
                inject_name=target.split(os.path.sep)[-1],
                inject_src=uni.Source(file_source, py_init_path),
            )
            self.prog.mod.hub[py_init_path] = mod
            return mod
        else:
            return uni.Module.make_stub(
                inject_name=target.split(os.path.sep)[-1],
                inject_src=uni.Source("", target),
            )
