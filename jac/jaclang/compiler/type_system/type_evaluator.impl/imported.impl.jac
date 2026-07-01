impl TypeEvaluator.get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase {
    if isinstance(node_.name, uni.Name) and node_.name.type is not None {
        return node_.name.type;
    }

    if isinstance(node_.name, uni.Name) { } else {
        return types.UnknownType();
    }
    import_node = node_.parent_of_type(uni.Import);
    assert import_node.from_loc is not None;

    from_path = self._resolve_from_path(import_node.from_loc);
    from_mod_type = self.get_type_of_module(import_node.from_loc);
    from_mod_name = import_node.from_loc.dot_path_str;
    if isinstance(from_mod_type, types.ModuleType) or from_path.exists() {
        is_dir = from_path.is_dir() or (from_path.stem == "__init__");
        if is_dir {
            mod_dir = from_path.parent if not from_path.is_dir() else from_path;
            for ext in (
                ".jac",
                ".cl.jac",
                ".sv.jac",
                ".na.jac",
                ".py",
                ".pyi",
                ".js",
                ".ts",
                ".jsx",
                ".tsx"
            ) {
                candidate_paths = [
                    (mod_dir / f"{node_.name.value}{ext}").resolve(),
                    (mod_dir / node_.name.value / f"__init__{ext}").resolve(),
                    (mod_dir / f"__init__{ext}").resolve(),

                ];

                for path in candidate_paths {
                    if not path.exists() {
                        continue;
                    }
                    path_str = str(path);

                    if not path_str.endswith((".jac", ".py", ".pyi")) {
                        mod_type = types.ModuleType(
                            mod_name=node_.name.sym_name,
                            file_uri=path,
                            symbol_table=None,
                            is_external=True,
                        );
                        node_.name.type = types.AnyType();
                        node_.name._sym_category = SymbolType.VAR;
                        self.emit_diag(
                            W1102,
                            node_.name,
                            name=node_.name.value,
                            module=from_mod_name
                        );
                        return node_.name.type;
                    }
                    mod = self._import_module_from_path(
                        path_str, importer_path=self._resolve_importer_path(node_)
                    );

                    is_subpackage_init = (
                        path.name.startswith("__init__")
                        and path.parent.name == node_.name.value
                    );
                    is_parent_init = (
                        path.name.startswith("__init__")
                        and path.parent.name != node_.name.value
                    );

                    if is_parent_init {
                        if sym := type_utils.lookup_symtab(
                            mod, node_.name.value, self.builtins_module
                        ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }

                        if sym := self._resolve_star_import_symbol(
                            mod, node_.name.value
                        ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }
                        continue;
                    }

                    flags = type_utils.compute_module_source_flags(str(path));
                    mod_type = types.ModuleType(
                        mod_name=node_.name.sym_name,
                        file_uri=path,
                        symbol_table=mod,
                        is_stub_file=flags.is_stub_file,
                        is_stdlib_stub=flags.is_stdlib_stub,
                        is_typing_stub=flags.is_typing_stub,
                        is_builtin_stub=flags.is_builtin_stub,
                    );

                    node_.name.type = mod_type;

                    node_.name._sym_category = SymbolType.MODULE;
                    return mod_type;
                }
            }

            node_.name.type = types.UnknownType();
            self.emit_diag(
                W1101, node_.name, name=node_.name.value, module=from_mod_name
            );
            return node_.name.type;
        } else {
            if not isinstance(from_mod_type, types.ModuleType) {
                node_.name.type = types.UnknownType();
                return node_.name.type;
            }
            if from_mod_type.is_external {
                node_.name.type = types.AnyType();
                node_.name._sym_category = SymbolType.VAR;
                self.emit_diag(
                    W1102, node_.name, name=node_.name.value, module=from_mod_name
                );
                return node_.name.type;
            }
            if sym := type_utils.lookup_symtab(
                from_mod_type.symbol_table, node_.name.value, self.builtins_module
            ) {
                return self._set_module_item_symbol_and_type(node_, sym);
            }
            if isinstance(from_mod_type.symbol_table, uni.Module) {
                if sym := self._resolve_star_import_symbol(
                    from_mod_type.symbol_table, node_.name.value
                ) {
                    return self._set_module_item_symbol_and_type(node_, sym);
                }
            }
            node_.name.type = types.UnknownType();
            self.emit_diag(
                W1101, node_.name, name=node_.name.value, module=from_mod_name
            );
            return node_.name.type;
        }
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
    if node_.path {
        if node_.path[-1].type {
            return node_.path[-1].type;
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
                npath.type = types.UnknownType();
                self.emit_diag(W1100, npath);
                return npath.type;
            }

            if Path(mod_path).is_dir() {
                npath._sym_category = SymbolType.MODULE;
                continue;
            }

            if not mod_path.endswith((".jac", ".py", ".pyi")) {
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
            flags = type_utils.compute_module_source_flags(mod_path);
            mod_type = types.ModuleType(
                mod_name=npath.value,
                file_uri=Path(mod_path).resolve(),
                symbol_table=mod,
                is_stub_file=flags.is_stub_file,
                is_stdlib_stub=flags.is_stdlib_stub,
                is_typing_stub=flags.is_typing_stub,
                is_builtin_stub=flags.is_builtin_stub,
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

impl TypeEvaluator._import_module_from_path(
    path: str, importer_path: (str | None) = None
) -> uni.Module {
    resolved_path = str(Path(path).resolve());

    compiler = self.program._get_compiler();
    target_program = compiler._resolve_program(resolved_path, self.program);
    target_hub = target_program.mod.hub;

    if (
        resolved_path in self.program.mod.hub
        and not self.program.is_hub_entry_fresh(resolved_path)
    ) {
        self.program.invalidate_module(resolved_path);
    }
    if (
        resolved_path in target_hub
        and target_program is not self.program
        and not target_program.is_hub_entry_fresh(resolved_path)
    ) {
        target_program.invalidate_module(resolved_path);
    }

    mod: uni.Module;
    if resolved_path in self.program.mod.hub {
        mod = self.program.mod.hub[resolved_path];
    } elif resolved_path in target_hub {
        mod = target_hub[resolved_path];
    } else {
        jir_mod: (uni.Module | None) = None;
        if resolved_path.endswith('.jac') and not resolved_path.endswith('.na.jac') {
            jir_mod = self._try_read_jir_cache(resolved_path);
        }
        if jir_mod is not None {
            mod = jir_mod;
            if mod.parent_scope is None and mod is not self.builtins_module {
                mod.parent_scope = self.builtins_module;
            }
            target_hub[resolved_path] = mod;
            target_program.hub_cache_stamp(resolved_path);
        } else {
            mod = self.program.compile(
                path, no_cgen=True, type_check=False, symtab_ir_only=True
            );
            if mod.parent_scope is None and mod is not self.builtins_module {
                mod.parent_scope = self.builtins_module;
            }
            target_hub[resolved_path] = mod;
            target_program.hub_cache_stamp(resolved_path);
            if resolved_path.endswith('.jac')
            and not resolved_path.endswith('.na.jac') {
                try {
                    import from jaclang.jac0core.jir {
                        get_module_cache_path,
                        is_module_cache_valid,
                        compute_module_key,
                        SEC_BYTECODE,
                        SEC_MODKEY
                    }
                    import from jaclang.jac0core.jir_passes { JirWriter }
                    cache_path = get_module_cache_path(resolved_path);
                    if not is_module_cache_valid(resolved_path, cache_path) {
                        cache_path.parent.mkdir(parents=True, exist_ok=True);
                        writer = JirWriter();

                        sections: dict[int, bytes] = {
                            SEC_MODKEY: compute_module_key(resolved_path).encode(
                                'utf-8'
                            )
                        };
                        bc = mod.gen?.py_bytecode;
                        if bc is not None {
                            sections[SEC_BYTECODE] = bc;
                        }
                        jir_bytes = writer.write_module(mod, sections=sections);

                        import os as _os;
                        tmp_path = cache_path.with_suffix(f'.{_os.getpid()}.tmp');
                        try {
                            tmp_path.write_bytes(jir_bytes);
                            tmp_path.rename(cache_path);
                        } finally {
                            tmp_path.unlink(missing_ok=True);
                        }
                    }
                } except Exception {
                    ;
                }
            }
        }
    }

    if importer_path is not None {
        self.program.record_dependency(importer_path, resolved_path);
    }
    return mod;
}

impl TypeEvaluator.forget_module(resolved_path: str) -> None {
    if resolved_path in self._module_type_cache {
        del (self._module_type_cache[resolved_path], );
    }
}

impl TypeEvaluator._resolve_importer_path(ast_node: uni.UniNode) -> (str | None) {
    mod = ast_node.find_parent_of_type(uni.Module);
    if mod is None or mod.source is None {
        return None;
    }
    file_path = mod.source.file_path;
    if not file_path {
        return None;
    }
    try {
        return str(Path(file_path).resolve());
    } except OSError {
        return None;
    }
}

impl TypeEvaluator._try_read_jir_cache(resolved_path: str) -> (uni.Module | None) {
    import from jaclang.jac0core.jir { get_module_cache_path, is_module_cache_valid }
    import from jaclang.jac0core.jir_passes { JirReader }
    import os;
    import traceback;
    try {
        cache_path = get_module_cache_path(resolved_path);
        if not is_module_cache_valid(resolved_path, cache_path) {
            return None;
        }
        data = cache_path.read_bytes();
        reader = JirReader(_source_path=resolved_path);
        mod = reader.read_module(data);

        return mod;
    } except Exception {
        if os.environ.get("JAC_JIR_DEBUG") {
            traceback.print_exc();
        }

        try {
            get_module_cache_path(resolved_path).unlink(missing_ok=True);
        } except Exception {
            ;
        }
        return None;
    }
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
    return types.UnknownType();
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
