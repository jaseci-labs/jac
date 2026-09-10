impl TypeEvaluator.get_type_of_module_item(node_: ModuleItem) -> TypeBase {
    binding = node_.binding_name;
    if binding is None {
        return UnknownType();
    }
    if binding.type is not None {
        return binding.type;
    }
    item_name = node_.name.value;
    import from jaclang.compiler.driver.modresolver { is_untyped_third_party_module }
    import_node = node_.parent_of_type(Import);
    assert import_node.from_loc is not None;

    from_path = self._resolve_from_path(import_node.from_loc);
    from_mod_type = self.get_type_of_module(import_node.from_loc);
    from_mod_name = import_node.from_loc.dot_path_str;
    if isinstance(from_mod_type, ModuleType) or from_path.exists() {
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

                    if path.name not in {e.name for e in path.parent.iterdir()} {
                        continue;
                    }
                    path_str = str(path);

                    if (not path_str.endswith((".jac", ".py", ".pyi")))
                        or is_untyped_third_party_module(path_str) {
                        mod_type = ModuleType(
                            mod_name=binding.sym_name,
                            file_uri=path,
                            symbol_table=None,
                            is_external=True,
                        );
                        import from jaclang.compiler.driver.modresolver {
                            sibling_declaration_file
                        }
                        sibling_dts = sibling_declaration_file(path_str);
                        if sibling_dts {
                            if declared
                                := self._ts_declared_type_from_file(
                                    sibling_dts, item_name
                                ) {
                                binding.type = declared;
                                declared_kind = self._ts_declared_kind_from_file(
                                    sibling_dts, item_name
                                )
                                    or BindingKind.VALUE;
                                binding._sym_category = SymbolType.TYPE
                                    if declared_kind.is_type_only()
                                    else SymbolType.VAR;
                                self._apply_import_binding_kind(
                                    node_, binding, declared_kind, from_mod_name
                                );
                                return binding.type;
                            }
                        }
                        binding.type = AnyType(is_foreign=True);
                        binding._sym_category = SymbolType.VAR;
                        self._emit_untyped_external(binding, item_name, from_mod_name);
                        return binding.type;
                    }
                    mod = self._import_module_from_path(
                        path_str,
                        importer_path=self._resolve_importer_path(node_),
                        need_tree=import_node.is_comptime
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
                        if sym := lookup_symtab(mod, item_name, self.builtins_module) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }

                        star_symbol = self._resolve_star_import_symbol(mod, item_name);
                        if star_symbol is not None {
                            return self._set_module_item_symbol_and_type(
                                node_, star_symbol
                            );
                        }
                        continue;
                    }
                    mod_type = ModuleType(
                        mod_name=binding.sym_name, file_uri=path, symbol_table=mod,
                    );

                    binding.type = mod_type;

                    binding._sym_category = SymbolType.MODULE;
                    return mod_type;
                }
            }

            binding.type = UnknownType(is_diagnosed=True);
            self.emit_diag(W1101, binding, name=item_name, module=from_mod_name);
            return binding.type;
        } else {
            if not isinstance(from_mod_type, ModuleType) {
                binding.type = UnknownType(
                    is_diagnosed=isinstance(from_mod_type, UnknownType)
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
                    declared_kind = self._ts_declared_kind(
                        import_node.from_loc, item_name
                    )
                        or BindingKind.VALUE;
                    binding._sym_category = SymbolType.TYPE
                        if declared_kind.is_type_only()
                        else SymbolType.VAR;
                    self._apply_import_binding_kind(
                        node_, binding, declared_kind, from_mod_name
                    );
                    return binding.type;
                }
                binding.type = AnyType(is_foreign=True);
                binding._sym_category = SymbolType.VAR;
                self._emit_untyped_external(binding, item_name, from_mod_name);
                return binding.type;
            }
            if virtual_dts
                := self._jac_virtual_sibling_dts(import_node, from_mod_type) {
                if declared
                    := self._ts_declared_type_from_file(virtual_dts, item_name) {
                    binding.type = declared;
                    declared_kind = self._ts_declared_kind_from_file(
                        virtual_dts, item_name
                    )
                        or BindingKind.VALUE;
                    binding._sym_category = SymbolType.TYPE
                        if declared_kind.is_type_only()
                        else SymbolType.VAR;
                    self._apply_import_binding_kind(
                        node_, binding, declared_kind, from_mod_name
                    );
                    return binding.type;
                }
            }
            if from_mod_type.symbol_table is not None
                and (
                    sym
                    := lookup_symtab(
                        from_mod_type.symbol_table, item_name, self.builtins_module
                    )
                ) {
                return self._set_module_item_symbol_and_type(node_, sym);
            }
            if isinstance(from_mod_type.symbol_table, Module) {
                if sym
                    := self._resolve_star_import_symbol(
                        from_mod_type.symbol_table, item_name
                    ) {
                    return self._set_module_item_symbol_and_type(node_, sym);
                }
            }
            binding.type = UnknownType(is_diagnosed=True);
            self.emit_diag(W1101, binding, name=item_name, module=from_mod_name);
            return binding.type;
        }
    }

    if isinstance(from_mod_type, UnknownType) and from_mod_type.is_diagnosed {
        binding.type = UnknownType(is_diagnosed=True);
        return binding.type;
    }

    if item_name == "*" {
        binding.type = AnyType(is_foreign=True);
        binding._sym_category = SymbolType.VAR;
        return binding.type;
    }
    return UnknownType();
}

impl TypeEvaluator._apply_import_binding_kind(
    node_: ModuleItem,
    binding: Name,
    kind: BindingKind,
    module: str,
    target_decl: (NameAtom | None) = None
) -> None {
    for cand in (binding, node_.alias) {
        if cand is None {
            continue;
        }
        sym = cand.sym;
        if sym is None or not sym.defn or sym.decl is not cand {
            continue;
        }
        sym.binding_kind = kind;
    }
    if node_.from_parent.is_typed {
        return;
    }
    space = CodeContext.CLIENT if is_client_destined(node_) else node_.codespace();
    if kind_has_runtime_binding(kind, target_decl, space) {
        return;
    }
    if kind.is_type_only() {
        scope = "";
        why = f"'{node_.name.value}' names a type and nothing else: a"
        " TypeScript `interface` or `type` alias declares no runtime"
        " export in any codespace.";
    } else {
        scope = " in client code";
        why = f"'{node_.name.value}' is a jac `type` alias. The python backend"
        " lowers an alias to a real runtime binding, so a plain import of"
        " it from server code is correct; the client backend erases the"
        " alias, and this module is client code.";
    }
    anchor = node_.name if isinstance(node_.name, Name) else binding;
    self.emit_diag(
        E1131, anchor, name=node_.name.value, module=module, scope=scope, why=why
    );
}

impl TypeEvaluator._resolve_star_import_symbol(
    mod: Module, name: str, visited: set[int] | None = None
) -> Symbol | None {
    mod_id = id(mod);
    if visited is None {
        visited = set();
    }
    if mod_id in visited {
        return None;
    }
    visited.add(mod_id);
    for imp in mod.get_all_sub_nodes(Import) {
        if not imp.is_absorb or not imp.items {
            continue;
        }

        star_mod_path = imp.items[0];
        if not isinstance(star_mod_path, ModulePath) {
            continue;
        }

        resolved = star_mod_path.resolve_relative_path_list();
        submod: Module | None = None;
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

        if sym := lookup_symtab(submod, name, self.builtins_module) {
            return sym;
        }

        if sym := self._resolve_star_import_symbol(submod, name, visited) {
            return sym;
        }
    }
    return None;
}

impl TypeEvaluator.get_type_of_module(node_: ModulePath) -> TypeBase {
    import from jaclang.compiler.driver.modresolver { is_untyped_third_party_module }
    path_parts = node_.path;
    if path_parts {
        last_type = path_parts[-1].type;

        if last_type
            and not (
                isinstance(last_type, UnknownType) and not last_type.is_diagnosed
            ) {
            return last_type;
        }
        path_list = node_.resolve_relative_path_list();

        offset = 0;
        if len(path_list) > len(path_parts) and node_.level > 0 {
            offset = len(path_list) - len(path_parts);
        }
        for (idx, npath) in enumerate(path_parts) {
            mod_path = path_list[idx + offset];

            if mod_path in self._module_type_cache {
                resolved_for_cache = str(Path(mod_path).resolve());
                if self.program.is_hub_entry_fresh(resolved_for_cache) {
                    npath.type = self._module_type_cache[mod_path];
                    if isinstance(npath, Name) {
                        npath._sym_category = SymbolType.MODULE;
                    }
                    continue;
                }
                self.program.invalidate_module(resolved_for_cache);
            }

            if not Path(mod_path).exists() {
                if isinstance(npath, Name) {
                    npath._sym_category = SymbolType.MODULE;
                }
                if idx < len(path_parts) - 1 {
                    continue;
                }
                if npm_entry := self._resolve_client_npm_module(node_) {
                    mod_type = ModuleType(
                        mod_name=npath.value,
                        file_uri=Path(npm_entry).resolve(),
                        symbol_table=None,
                        is_external=True,
                    );
                    npath.type = mod_type;
                    if isinstance(npath, Name) {
                        npath._sym_category = SymbolType.MODULE;
                    }
                    return npath.type;
                }
                npath.type = UnknownType(is_diagnosed=True);
                if self._relative_import_must_resolve(node_) {
                    self.emit_diag(E1134, npath, module=node_.dot_path_str);
                } else {
                    self.emit_diag(W1100, npath);
                }
                return npath.type;
            }

            if Path(mod_path).is_dir() {
                if isinstance(npath, Name) {
                    npath._sym_category = SymbolType.MODULE;
                }
                pkg_dir = Path(mod_path);
                pkg_sym_tab: (Module | None) = None;
                for ext in (".jac", ".py", ".pyi") {
                    init_file = pkg_dir / f"__init__{ext}";
                    if init_file.exists() {
                        pkg_sym_tab = self._import_module_from_path(
                            str(init_file),
                            importer_path=self._resolve_importer_path(node_)
                        );
                        break;
                    }
                }
                pkg_type = ModuleType(
                    mod_name=npath.value,
                    file_uri=pkg_dir.resolve(),
                    symbol_table=pkg_sym_tab,
                );
                npath.type = pkg_type;
                self._module_type_cache[mod_path] = pkg_type;
                continue;
            }

            if (not mod_path.endswith((".jac", ".py", ".pyi")))
                or is_untyped_third_party_module(mod_path) {
                mod_type = ModuleType(
                    mod_name=npath.value,
                    file_uri=Path(mod_path).resolve(),
                    symbol_table=None,
                    is_external=True,
                );
                npath.type = mod_type;
                if isinstance(npath, Name) {
                    npath._sym_category = SymbolType.MODULE;
                }
                self._module_type_cache[mod_path] = mod_type;
                continue;
            }
            _imp = node_.find_parent_of_type(Import);
            mod: Module = self._import_module_from_path(
                mod_path,
                importer_path=self._resolve_importer_path(node_),
                need_tree=bool(_imp is not None and _imp.is_comptime)
            );
            mod_type = ModuleType(
                mod_name=npath.value,
                file_uri=Path(mod_path).resolve(),
                symbol_table=mod,
            );
            npath.type = mod_type;
            if isinstance(npath, Name) {
                npath._sym_category = SymbolType.MODULE;
            }

            self._module_type_cache[mod_path] = mod_type;
        }
        if node_.alias {
            node_.alias.type = path_parts[-1].type;
            node_.alias._sym_category = SymbolType.MODULE;
        }
        return path_parts[-1].type or UnknownType();
    }
    return UnknownType();
}

impl TypeEvaluator._resolve_submodule_attr(
    base_type: ModuleType, attr_name: str
) -> (ModuleType | None) {
    import from jaclang.compiler.driver.modresolver { is_untyped_third_party_module }
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

            if path.name not in {e.name for e in path.parent.iterdir()} {
                continue;
            }
            path_str = str(path);
            if path_str in self._module_type_cache {
                cached = self._module_type_cache[path_str];
                if isinstance(cached, ModuleType) {
                    return cached;
                }
            }
            if is_untyped_third_party_module(path_str) {
                return ModuleType(
                    mod_name=attr_name,
                    file_uri=path,
                    symbol_table=None,
                    is_external=True,
                );
            }
            mod = self._import_module_from_path(path_str);
            mod_type = ModuleType(mod_name=attr_name, file_uri=path, symbol_table=mod);
            self._module_type_cache[path_str] = mod_type;
            return mod_type;
        }
    }
    return None;
}

impl TypeEvaluator._import_module_from_path(
    path: str, importer_path: (str | None) = None, need_tree: bool = False
) -> Module {
    resolved_path = str(Path(path).resolve());

    if resolved_path in self._modules_in_compile {
        _pending = self.program.find_module(resolved_path);
        if _pending is not None {
            mod = _pending;
        } else {
            return Module.make_stub(inject_name=Path(resolved_path).stem);
        }
    } else {
        self._modules_in_compile.add(resolved_path);
        try {
            mod = self.program.load_dependency_module(
                path, importer_path=importer_path, need_tree=need_tree
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
    import os;
    canon = os.path.realpath(resolved_path);

    stale_paths = [
        key
        for key in self._module_type_cache
        if key == resolved_path or os.path.realpath(key) == canon
    ];
    for key in stale_paths {
        del self._module_type_cache[key];
    }
}

impl TypeEvaluator._resolve_importer_path(ast_node: UniNode) -> (str | None) {
    import from jaclang.compiler.symbol_utils { resolve_importer_path_from_node }
    return resolve_importer_path_from_node(ast_node);
}

impl TypeEvaluator.get_type_of_symbol(symbol: Symbol) -> TypeBase {
    provider = symbol.provider;
    if provider is not None {
        return provider.resolve_type(symbol);
    }
    if self.push_symbol_resolution(symbol) {
        try {
            result = self._get_type_of_symbol(symbol);
            return result;
        } finally {
            self.pop_symbol_resolution(symbol);
        }
    }
    return UnknownType(is_incomplete=True);
}

impl TypeEvaluator.resolve_to_definition_symbol(symbol: Symbol) -> Symbol {
    visited: set[int] = set();
    cur = symbol;
    while id(cur) not in visited {
        visited.add(id(cur));
        origin = cur.imported_from;
        if origin is not None {
            cur = origin;
            continue;
        }
        provider = cur.provider;
        if provider is not None {
            target = provider.definition();
            if target is None or target is cur {
                break;
            }
            cur = target;
            continue;
        }
        if not (cur.imported and cur.decl) {
            break;
        }
        node_ = cur.decl.name_of;
        if not (isinstance(node_, Name) and node_.sym and node_.sym is not cur) {
            break;
        }
        cur = node_.sym;
    }
    return cur;
}


impl TypeEvaluator._relative_import_must_resolve(node_: ModulePath) -> bool {
    if node_.level <= 0 or node_.string_path_value is not None {
        return False;
    }
    imp = node_.find_parent_of_type(Import);
    if imp is None or imp.is_typed or imp.is_comptime {
        return False;
    }
    return not self._import_error_is_handled(imp);
}


impl TypeEvaluator._import_error_is_handled(imp: Import) -> bool {
    caught = {'ImportError', 'ModuleNotFoundError', 'Exception', 'BaseException'};
    prev: UniNode = imp;
    cur: (UniNode | None) = imp.parent;
    while cur is not None {
        if isinstance(cur, TryStmt) and (prev in cur.body) {
            for handler in cur.excepts {
                for nm in handler.ex_type.get_all_sub_nodes(typ=Name) {
                    if nm.value in caught {
                        return True;
                    }
                }
                if isinstance(handler.ex_type, Name)
                    and handler.ex_type.value in caught {
                    return True;
                }
            }
        }
        prev = cur;
        cur = cur.parent;
    }
    return False;
}
