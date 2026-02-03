"""Return the effective type of the module item."""
impl TypeEvaluator.get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase {
    # Module item can be both a module or a member of a module.
    # import from .. { mod }   # <-- Here mod is not a member but a module itself.
    # import from mod { item } # <-- Here item is not a module but a member of mod.
    if node_.name.type is not None {
        return node_.name.type;
    }
    import_node = node_.parent_of_type(uni.Import);
    assert import_node.from_loc is not None;
    if isinstance(self.get_type_of_module(import_node.from_loc), types.ModuleType) {
        from_path = Path(import_node.from_loc.resolve_relative_path());
        is_dir = from_path.is_dir() or (from_path.stem == "__init__");
        # import from .. { mod }
        # import from package.subpackage { item}
        #                     ^^^^^^^^^^^
        # subpackage can be a module or a package (dir with __init__.jac)
        if is_dir {
            mod_dir = from_path.parent if not from_path.is_dir() else from_path;
            # FIXME: Implement module resolution properly.
            for ext in (".jac", ".py", ".pyi", ".js", ".ts", ".jsx", ".tsx") {
                # Try resolving both "__init__" module and direct module file.
                candidate_paths = [
                    (mod_dir / f"__init__{ext}").resolve(),
                    (mod_dir / f"{node_.name.value}{ext}").resolve(),

                ];
                for path in candidate_paths {
                    if not path.exists() {
                        continue;
                    }

                    mod = self._import_module_from_path(str(path));

                    # Case 1: Look for symbol inside __init__.ext module
                    if path.name.startswith("__init__") {
                        if sym := type_utils.lookup_symtab(
                            mod, node_.name.value, self.builtins_module
                        ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }
                        continue;  # Try next candidate
                    }

                    # Case 2: The module itself (mod_name.ext)
                    mod_type = types.ModuleType(
                        mod_name=node_.name.sym_name, file_uri=path, symbol_table=mod,
                    );
                    # Cache the type.
                    node_.name.type = mod_type;

                    # FIXME: goto definition works on imported symbol by checking if it's a MODULE
                    # type and in that case it'll call resolve_relative_path on the parent node of
                    # the symbol's definition node (a module path), So the goto definition to work
                    # properly the category should be module on a module path, If we set like this
                    # below should work but because of the above assumption (should be a mod path)
                    # it won't, This needs to be discussed.
                    #
                    node_.name._sym_category = SymbolType.MODULE;
                    return mod_type;
                }
            }
        } else {
            mod_type = self.get_type_of_module(import_node.from_loc);
            if not isinstance(mod_type, types.ModuleType) {
                node_.name.type = types.UnknownType();
                # TODO: Add diagnostic that from_loc is not accessible.
                # Eg: 'Import "scipy" could not be resolved'
                return node_.name.type;
            }
            if sym := type_utils.lookup_symtab(
                mod_type.symbol_table, node_.name.value, self.builtins_module
            ) {
                return self._set_module_item_symbol_and_type(node_, sym);
            }
        }
    }
    return types.UnknownType();
}

"""Return the effective type of the module."""
impl TypeEvaluator.get_type_of_module(node_: uni.ModulePath) -> types.TypeBase {
    if node_.path {
        # If the type is already computed, return it.
        if node_.path[-1].type {
            return node_.path[-1].type;
        }
        # Compute path list once before the loop.
        path_list = node_.resolve_relative_path_list();
        for (idx, npath) in enumerate(node_.path) {
            mod_path = path_list[idx];

            # Check module type cache first.
            if mod_path in self._module_type_cache {
                npath.type = self._module_type_cache[mod_path];
                npath._sym_category = SymbolType.MODULE;
                continue;
            }

            # If the path doesn't exist, return unknown type.
            # eg: import from ..mod { item }  # <-- Here ..mod might not exist.
            if not Path(mod_path).exists() {
                npath.type = types.UnknownType();
                npath._sym_category = SymbolType.MODULE;
                self.add_diagnostic(npath, 'Module not found', warning=True);
                return npath.type;
            }

            if Path(mod_path).is_dir() {
                continue;
            }

            mod: uni.Module = self._import_module_from_path(mod_path);
            mod_type = types.ModuleType(
                mod_name=npath.value,
                file_uri=Path(mod_path).resolve(),
                symbol_table=mod
            );
            npath.type = mod_type;
            npath._sym_category = SymbolType.MODULE;
            # Cache the module type for future lookups.
            self._module_type_cache[mod_path] = mod_type;
        }
        if node_.alias {
            node_.alias.type = node_.path[-1].type;
            node_.alias._sym_category = SymbolType.MODULE;
        }
        return node_.path[-1].type;
    }
    return types.UnknownType();
}

"""Import a module from the given path."""
impl TypeEvaluator._import_module_from_path(path: str) -> uni.Module {
    # -----------------------------------------------------------------------
    # TODO: Implement stub file resolution properly, this is a ad-hoc mess.
    # FIXME: This is ad-hoc way to override the typeing.py with typeing.pyi file
    # implemented to make it work for now, please revisit this and implement it properly.
    if path.endswith("typing.py") {
        path = self._TYPING_STUB_FILE_PATH;
    }
    if path.endswith("abc.py") {
        path = self._TYPING_STUB_FILE_PATH;
    }
    # -----------------------------------------------------------------------

    # Get the module, if it's not loaded yet, compile and get it.
    #
    # TODO:
    # We're not typechecking inside the module itself however we
    # need to check if the module path is site-package or not and
    # do typecheck inside as well.
    mod: uni.Module;
    if path in self.program.mod.hub {
        mod = self.program.mod.hub[path];
    } else {
        # Use symtab_ir_only=True to skip semantic analysis and CFG passes.
        mod = self.program.compile(
            path, no_cgen=True, type_check=False, symtab_ir_only=True
        );
        # FIXME: Inherit from builtin symbol table logic is currently implemented
        # here and checker pass, however it should be in one location, since we're
        # doing type_check=False, it doesn't set parent_scope to builtins, this
        # needs to be done properly. The way jaclang handles symbol table is different
        # than pyright, so we cannot strictly follow them, however as long as a new
        # module has a parent scope as builtin scope, we're aligned with pyright.
        if mod.parent_scope is None and mod is not self.builtins_module {
            mod.parent_scope = self.builtins_module;
        }
    }
    return mod;
}

"""Return the effective type of the symbol."""
impl TypeEvaluator.get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    if self.push_symbol_resolution(symbol) {
        try {
            return self._get_type_of_symbol(symbol);
        } finally {
            self.pop_symbol_resolution(symbol);
        }
    }
    # If we reached here that means we have a cyclic symbolic reference.
    return types.UnknownType();
}
