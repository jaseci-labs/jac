impl TypeEvaluator.get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase {
    binding = node_.binding_name;
    if binding is None {
        return types.UnknownType();
    }
    if binding.type is not None {
        return binding.type;
    }
    item_name = node_.name.value;
    import from jaclang.jac0core.modresolver { is_untyped_third_party_module }
    import_node = node_.parent_of_type(uni.Import);
    assert import_node.from_loc is not None;

    from_path = self._resolve_from_path(import_node.from_loc);
    from_mod_type = self.get_type_of_module(import_node.from_loc);
    from_mod_name = import_node.from_loc.dot_path_str;
    if isinstance(from_mod_type, types.ModuleType) or from_path.exists() {
        is_dir = from_path.is_dir() or (from_path.stem == "__init__");
        if is_dir {
            mod_dir = from_path.parent if not from_path.is_dir() else from_path;
            for ext in (".jac", ".py", ".pyi", ".js", ".ts", ".jsx", ".tsx") {
                candidate_paths = [
                    (mod_dir / f"{item_name}{ext}").resolve(),
                    (mod_dir / item_name / f"__init__{ext}").resolve(),
                    (mod_dir / f"__init__{ext}").resolve(),

                ];

                for path in candidate_paths {
                    if not path.exists() {
                        continue;
                    }
                    path_str = str(path);

                    if (not path_str.endswith((".jac", ".py", ".pyi")))
                        or is_untyped_third_party_module(path_str) {
                        mod_type = types.ModuleType(
                            mod_name=binding.sym_name,
                            file_uri=path,
                            symbol_table=None,
                            is_external=True,
                        );
                        import from jaclang.jac0core.modresolver {
                            sibling_declaration_file
                        }
                        sibling_dts = sibling_declaration_file(path_str);
                        if sibling_dts {
                            if declared
                                := self._ts_declared_type_from_file(
                                    sibling_dts, item_name
                                ) {
                                binding.type = declared;
                                binding._sym_category = SymbolType.VAR;
                                return binding.type;
                            }
                        }
                        binding.type = types.AnyType(is_foreign=True);
                        binding._sym_category = SymbolType.VAR;
                        self._emit_untyped_external(binding, item_name, from_mod_name);
                        return binding.type;
                    }
                    mod = self._import_module_from_path(
                        path_str, importer_path=self._resolve_importer_path(node_)
                    );

                    is_subpackage_init = (
                        path.name.startswith("__init__")
                        and path.parent.name == item_name
                    );
                    is_parent_init = (
                        path.name.startswith("__init__")
                        and path.parent.name != item_name
                    );

                    if is_parent_init {
                        if sym
                            := type_utils.lookup_symtab(
                                mod, item_name, self.builtins_module
                            ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }

                        if sym := self._resolve_star_import_symbol(mod, item_name) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }
                        continue;
                    }
                    mod_type = types.ModuleType(
                        mod_name=binding.sym_name, file_uri=path, symbol_table=mod,
                    );

                    binding.type = mod_type;

                    binding._sym_category = SymbolType.MODULE;
                    return mod_type;
                }
            }

            binding.type = types.UnknownType(is_diagnosed=True);
            self.emit_diag(W1101, binding, name=item_name, module=from_mod_name);
            return binding.type;
        } else {
            if not isinstance(from_mod_type, types.ModuleType) {
                binding.type = types.UnknownType(
                    is_diagnosed=isinstance(from_mod_type, types.UnknownType)
                        and from_mod_type.is_diagnosed
                );
                return binding.type;
            }
            if from_mod_type.is_external {
                if declared
                    := self._get_ts_declared_item_type(
                        import_node.from_loc, item_name
                    ) {
                    binding.type = declared;
                    binding._sym_category = SymbolType.VAR;
                    return binding.type;
                }
                binding.type = types.AnyType(is_foreign=True);
                binding._sym_category = SymbolType.VAR;
                self._emit_untyped_external(binding, item_name, from_mod_name);
                return binding.type;
            }
            if sym
                := type_utils.lookup_symtab(
                    from_mod_type.symbol_table, item_name, self.builtins_module
                ) {
                return self._set_module_item_symbol_and_type(node_, sym);
            }
            if isinstance(from_mod_type.symbol_table, uni.Module) {
                if sym
                    := self._resolve_star_import_symbol(
                        from_mod_type.symbol_table, item_name
                    ) {
                    return self._set_module_item_symbol_and_type(node_, sym);
                }
            }
            binding.type = types.UnknownType(is_diagnosed=True);
            self.emit_diag(W1101, binding, name=item_name, module=from_mod_name);
            return binding.type;
        }
    }

    if isinstance(from_mod_type, types.UnknownType) and from_mod_type.is_diagnosed {
        binding.type = types.UnknownType(is_diagnosed=True);
        return binding.type;
    }
    return types.UnknownType();
}

impl TypeEvaluator._resolve_star_import_symbol(
    mod: uni.Module, name: str, visited: set[int] | None = None
) -> uni.Symbol | None {
    mod_id = id(mod);
    if visited is None {
        visited = set();
    }
    if mod_id in visited {
        return None;
    }
    visited.add(mod_id);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if not imp.is_absorb or not imp.items {
            continue;
        }

        star_mod_path = imp.items[0];
        if not isinstance(star_mod_path, uni.ModulePath) {
            continue;
        }

        resolved = star_mod_path.resolve_relative_path_list();
        submod: uni.Module | None = None;
        if resolved {
            candidate = resolved[-1];
            if candidate and Path(candidate).exists() {
                submod = self._import_module_from_path(
                    candidate, importer_path=self._resolve_importer_path(mod)
                );
            }
        }
        if submod is None {
            continue;
        }

        if sym := type_utils.lookup_symtab(submod, name, self.builtins_module) {
            return sym;
        }

        if sym := self._resolve_star_import_symbol(submod, name, visited) {
            return sym;
        }
    }
    return None;
}

impl TypeEvaluator.get_type_of_module(node_: uni.ModulePath) -> types.TypeBase {
    import from jaclang.jac0core.modresolver { is_untyped_third_party_module }
    if node_.path {
        last_type = node_.path[-1].type;

        if last_type
            and not (
                isinstance(last_type, types.UnknownType) and not last_type.is_diagnosed
            ) {
            return last_type;
        }
        path_list = node_.resolve_relative_path_list();

        offset = 0;
        if node_.path and len(path_list) > len(node_.path) and node_.level > 0 {
            offset = len(path_list) - len(node_.path);
        }
        for (idx, npath) in enumerate(node_.path) {
            mod_path = path_list[idx + offset];

            if mod_path in self._module_type_cache {
                resolved_for_cache = str(Path(mod_path).resolve());
                if self.program.is_hub_entry_fresh(resolved_for_cache) {
                    npath.type = self._module_type_cache[mod_path];
                    npath._sym_category = SymbolType.MODULE;
                    continue;
                }
                self.program.invalidate_module(resolved_for_cache);
            }

            if not Path(mod_path).exists() {
                npath._sym_category = SymbolType.MODULE;
                if idx < len(node_.path) - 1 {
                    continue;
                }
                if npm_entry := self._resolve_client_npm_module(node_) {
                    mod_type = types.ModuleType(
                        mod_name=npath.value,
                        file_uri=Path(npm_entry).resolve(),
                        symbol_table=None,
                        is_external=True,
                    );
                    npath.type = mod_type;
                    npath._sym_category = SymbolType.MODULE;
                    return npath.type;
                }
                npath.type = types.UnknownType(is_diagnosed=True);
                self.emit_diag(W1100, npath);
                return npath.type;
            }

            if Path(mod_path).is_dir() {
                npath._sym_category = SymbolType.MODULE;
                continue;
            }

            if (not mod_path.endswith((".jac", ".py", ".pyi")))
                or is_untyped_third_party_module(mod_path) {
                mod_type = types.ModuleType(
                    mod_name=npath.value,
                    file_uri=Path(mod_path).resolve(),
                    symbol_table=None,
                    is_external=True,
                );
                npath.type = mod_type;
                npath._sym_category = SymbolType.MODULE;
                self._module_type_cache[mod_path] = mod_type;
                continue;
            }
            mod: uni.Module = self._import_module_from_path(
                mod_path, importer_path=self._resolve_importer_path(node_)
            );
            mod_type = types.ModuleType(
                mod_name=npath.value,
                file_uri=Path(mod_path).resolve(),
                symbol_table=mod,
            );
            npath.type = mod_type;
            npath._sym_category = SymbolType.MODULE;

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

impl TypeEvaluator._resolve_submodule_attr(
    base_type: types.ModuleType, attr_name: str
) -> (types.ModuleType | None) {
    import from jaclang.jac0core.modresolver { is_untyped_third_party_module }
    if base_type.file_uri is None {
        return None;
    }
    base_path = Path(base_type.file_uri);
    is_pkg_dir = base_path.is_dir();
    if not is_pkg_dir and base_path.stem != "__init__" {
        return None;
    }
    mod_dir = base_path if is_pkg_dir else base_path.parent;
    for ext in (".jac", ".py", ".pyi") {
        candidates = [
            (mod_dir / f"{attr_name}{ext}").resolve(),
            (mod_dir / attr_name / f"__init__{ext}").resolve(),

        ];
        for path in candidates {
            if not path.exists() {
                continue;
            }
            path_str = str(path);
            if path_str in self._module_type_cache {
                cached = self._module_type_cache[path_str];
                if isinstance(cached, types.ModuleType) {
                    return cached;
                }
            }
            if is_untyped_third_party_module(path_str) {
                return types.ModuleType(
                    mod_name=attr_name,
                    file_uri=path,
                    symbol_table=None,
                    is_external=True,
                );
            }
            mod = self._import_module_from_path(path_str);
            mod_type = types.ModuleType(
                mod_name=attr_name, file_uri=path, symbol_table=mod
            );
            self._module_type_cache[path_str] = mod_type;
            return mod_type;
        }
    }
    return None;
}

impl TypeEvaluator._import_module_from_path(
    path: str, importer_path: (str | None) = None
) -> uni.Module {
    resolved_path = str(Path(path).resolve());

    if resolved_path in self._modules_in_compile {
        _pending = self.program.find_module(resolved_path);
        if _pending is not None {
            mod = _pending;
        } else {
            return uni.Module.make_stub(inject_name=Path(resolved_path).stem);
        }
    } else {
        self._modules_in_compile.add(resolved_path);
        try {
            mod = self.program.load_dependency_module(
                path, importer_path=importer_path
            );
        } finally {
            self._modules_in_compile.discard(resolved_path);
        }
    }

    if mod.parent_scope is None and mod is not self.builtins_module {
        mod.parent_scope = self.builtins_module;
    }
    return mod;
}

impl TypeEvaluator.forget_module(resolved_path: str) -> None {
    if resolved_path in self._module_type_cache {
        del (self._module_type_cache[resolved_path], );
    }
}

impl TypeEvaluator._resolve_importer_path(ast_node: uni.UniNode) -> (str | None) {
    import from jaclang.compiler.symbol_utils { resolve_importer_path_from_node }
    return resolve_importer_path_from_node(ast_node);
}

impl TypeEvaluator.get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    if self.push_symbol_resolution(symbol) {
        try {
            result = self._get_type_of_symbol(symbol);
            return result;
        } finally {
            self.pop_symbol_resolution(symbol);
        }
    }
    return types.UnknownType(is_incomplete=True);
}

impl TypeEvaluator.resolve_to_definition_symbol(symbol: uni.Symbol) -> uni.Symbol {
    visited: set[int] = set();
    cur = symbol;
    while id(cur) not in visited {
        visited.add(id(cur));
        if not (cur.imported and cur.decl) {
            break;
        }
        node_ = cur.decl.name_of;
        if not (isinstance(node_, uni.Name) and node_.sym and node_.sym is not cur) {
            break;
        }
        cur = node_.sym;
    }
    return cur;
}
