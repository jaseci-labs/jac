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
7. Supporting cross-language imports:
   - JavaScript (.js) and TypeScript (.ts, .tsx, .jsx) files

The pass runs early in the compilation pipeline to ensure all symbols from imported
modules are available for subsequent passes like symbol table building and type checking.
"""
import os;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { Transform, UniPass }
import from jaclang.pycore.log { logging }

with entry {
    logger = logging.getLogger(__name__);
}

"""Jac statically imports Jac modules."""
class JacImportDepsPass(Transform[(uni.Module, uni.Module)]) {
    """Initialize the JacImportPass."""
    def pre_transform(self: JacImportDepsPass) -> None {
        super.pre_transform();
        self.last_imported: list[uni.Module] = [];
    }

    """Run Importer."""
    def transform(self: JacImportDepsPass, ir_in: uni.Module) -> uni.Module {
        self.last_imported.append(ir_in);
        while self.last_imported {
            current_module = self.last_imported.pop(0);
            all_imports = UniPass.get_all_sub_nodes(current_module, uni.ModulePath);
            for i in all_imports {
                self.process_import(i);
            }
        }
        return ir_in;
    }

    """Process an import."""
    def process_import(self: JacImportDepsPass, i: uni.ModulePath) -> None {
        imp_node = i.parent_of_type(uni.Import);
        if imp_node.is_jac {
            self.import_jac_module(<>node=i);
        }
        target = i.resolve_relative_path();
        if target.endswith(('.js', '.ts', '.jsx', '.tsx')) {
            self.import_ts_module(<>node=i);
        }
    }

    """Import a module."""
    def import_jac_module(self: JacImportDepsPass, <>node: uni.ModulePath) -> None {
        target = <>node.resolve_relative_path();
        if os.path.isdir(target) {
            self.load_mod(self.import_jac_mod_from_dir(target));
            import_node = <>node.parent_of_type(uni.Import);
            if (<>node == import_node.from_loc) {
                for i in import_node.items {
                    if isinstance(i, uni.ModuleItem) {
                        from_mod_target = <>node.resolve_relative_path(i.name.value);
                        if os.path.isdir(from_mod_target) {
                            self.load_mod(
                                self.import_jac_mod_from_dir(from_mod_target)
                            );
                        } else {
                            if (from_mod_target in self.prog.mod.hub) {
                                return;
                            }
                            self.load_mod(self.prog.compile(file_path=from_mod_target));
                        }
                    }
                }
            }
        } else {
            if (target in self.prog.mod.hub) {
                return;
            }
            self.load_mod(self.prog.compile(file_path=target));
        }
    }

    """Attach a module to a node."""
    def load_mod(self: JacImportDepsPass, mod: uni.Module) -> None {
        self.prog.mod.hub[mod.loc.mod_path] = mod;
        self.last_imported.append(mod);
    }

    """Import a module from a directory."""
    def import_jac_mod_from_dir(self: JacImportDepsPass, target: str) -> uni.Module {
        jac_init_path = os.path.join(target, '__init__.jac');
        if os.path.exists(jac_init_path) {
            if (jac_init_path in self.prog.mod.hub) {
                return self.prog.mod.hub[jac_init_path];
            }
            return self.prog.compile(file_path=jac_init_path);
        } elif os.path.exists((py_init_path := os.path.join(target, '__init__.py'))) {
            import from jaclang.pycore.helpers { read_file_with_encoding }
            file_source = read_file_with_encoding(py_init_path);
            mod = uni.Module.make_stub(
                inject_name=target.split(os.path.sep)[-1],
                inject_src=uni.Source(file_source, py_init_path)
            );
            self.prog.mod.hub[py_init_path] = mod;
            return mod;
        } else {
            return uni.Module.make_stub(
                inject_name=target.split(os.path.sep)[-1],
                inject_src=uni.Source('', target)
            );
        }
    }

    """Import a TypeScript/JavaScript module for type checking."""
    def import_ts_module(self: JacImportDepsPass, <>node: uni.ModulePath) -> None {
        target = <>node.resolve_relative_path();
        if (target in self.prog.mod.hub) {
            return;
        }
        if not os.path.exists(target) {
            logger.debug(f"TypeScript/JavaScript module not found: {target}");
            return;
        }
        mod = self.prog.compile(file_path=target, no_cgen=True);
        self.load_mod(mod);
    }
}
