impl AccessCheckPass.postinit -> None {
    super.postinit();
}

impl AccessCheckPass._run_impl(ir_in: Module) -> Module {
    self._enforce = ir_in.access_enforced;
    self._collect_bridged_imports(ir_in);

    checked: set[int] = set();
    for tr in ir_in.get_all_sub_nodes(typ=AtomTrailer) {
        if (tr.is_attr and isinstance(tr.right, Name) and tr.right.sym) {
            checked.add(id(tr.right));
            self._check_use(tr.right, tr.right.sym);
        }
    }

    for nm in ir_in.get_all_sub_nodes(typ=Name) {
        if (id(nm) in checked) or (nm.sym is None) {
            continue;
        }
        self._check_use(nm, nm.sym);
    }
    return ir_in;
}

impl AccessCheckPass._collect_bridged_imports(ir_in: Module) -> None {
    self._bridged_syms = set();
    self._bridged_mods = set();

    def note_path(path: (str | None)) {
        if path {
            self._bridged_mods.add(os.path.normpath(path));
        }
    }

    def resolved_path(nd: (ModulePath | ModuleItem)) -> (str | None) {
        if nd.abs_path {
            return nd.abs_path;
        }
        try {
            found = nd.resolve_relative_path();
        } except Exception {
            return None;
        }
        return found if isinstance(found, str) else None;
    }

    import from jaclang.compiler.driver.boundary_classify { classify_cross_app_import }
    for imp in ir_in.get_all_sub_nodes(typ=Import) {
        facts = imp.boundary_facts;
        if facts is not None {
            kind = facts.cross_app_kind;
        } else {
            kind = classify_cross_app_import(imp, None).value;
        }
        if kind == 'local' {
            continue;
        }
        if imp.from_loc is not None {
            note_path(resolved_path(imp.from_loc));
        }
        for item in imp.items {
            if isinstance(item, ModuleItem) {
                if isinstance(item.name, Name) and item.name.sym is not None {
                    self._bridged_syms.add(id(item.name.sym));
                }
                note_path(resolved_path(item));
            } elif isinstance(item, ModulePath) {
                note_path(resolved_path(item));
            }
        }
    }
}

impl AccessCheckPass._check_use(use_node: AstSymbolNode, sym: Symbol) -> None {
    decl = sym.decl;
    def_mod = decl.loc.mod_path if decl else "";

    if (not def_mod) or (not def_mod.endswith(".jac")) {
        return;
    }
    use_mod = use_node.loc.mod_path;
    if def_mod != use_mod {
        def_module = self._declaring_module(sym);
        if (
            def_module is not None
            and not self._check_app_laws(use_node, sym, def_module)
        ) {
            return;
        }
    }
    if (sym.access == SymbolAccess.PUBLIC) {
        return;
    }

    owner = self._declaring_archetype(sym);
    if (owner is not None) {
        self._check_member(use_node, sym, owner);
        return;
    }

    def_tab = sym.parent_tab;
    if not isinstance(def_tab, Module) {
        return;
    }
    if (def_mod == use_mod) {
        return;
    }
    if (sym.access == SymbolAccess.PRIVATE) {
        self.emit(
            E2037 if self._enforce else W2037,
            node_override=use_node,
            name=sym.sym_name,
            module=os.path.basename(def_mod)
        );
    } else {
        def_proj = def_tab.jac_project_root;
        use_proj = self.ir_in.jac_project_root;
        if (def_proj != use_proj) {
            project_name = os.path.basename(def_proj) if def_proj else "?";
            self.emit(
                E2038 if self._enforce else W2038,
                node_override=use_node,
                name=sym.sym_name,
                project=project_name
            );
        }
    }
}

impl AccessCheckPass._module_app_facts(
    mod: Module
) -> tuple[(str | None), (str | None)] {
    if not mod.stub_only or mod.app is not None {
        return (mod.app, mod.jac_project_root);
    }
    mod_path = mod.loc.mod_path if mod.loc else '';
    if not mod_path {
        return (None, mod.jac_project_root);
    }
    import from jaclang.compiler.driver.modresolver { find_jac_project_root }
    import from jaclang.compiler.placement.workspace { app_for_path }
    app = app_for_path(mod_path);
    return (
        app.name if app is not None else None,
        mod.jac_project_root or find_jac_project_root(mod_path)
    );
}

impl AccessCheckPass._check_app_laws(
    use_node: AstSymbolNode, sym: Symbol, def_module: Module
) -> bool {
    (def_app, def_root) = self._module_app_facts(def_module);
    if def_app is None or def_module is self.ir_in {
        return True;
    }
    if def_root != self.ir_in.jac_project_root {
        return True;
    }
    use_app = self.ir_in.app;
    if def_app == use_app {
        return True;
    }
    if id(sym) in self._bridged_syms {
        return True;
    }
    def_path = def_module.loc.mod_path if def_module.loc else '';
    if def_path and os.path.normpath(def_path) in self._bridged_mods {
        return True;
    }
    if use_app is None {
        use_path = self.ir_in.loc.mod_path if self.ir_in.loc else '';
        self.emit(
            E2040 if self._enforce else W2040,
            node_override=use_node,
            module=os.path.basename(use_path),
            name=sym.sym_name,
            app=def_app
        );
        return False;
    }
    self.emit(
        E2039 if self._enforce else W2039,
        node_override=use_node,
        name=sym.sym_name,
        app=def_app,
        user_app=use_app
    );
    return False;
}

impl AccessCheckPass._check_member(
    use_node: AstSymbolNode, sym: Symbol, owner: Archetype
) -> None {
    user = use_node.find_parent_of_type(Archetype);
    if (sym.access == SymbolAccess.PRIVATE) {
        if (user is not owner) {
            self.emit(
                E2034 if self._enforce else W2034,
                node_override=use_node,
                name=sym.sym_name,
                owner=owner.name.value
            );
        }
    } else {
        ok = (user is not None)
            and ((user is owner) or self._is_subclass_of(user, owner));
        if not ok {
            self.emit(
                E2035 if self._enforce else W2035,
                node_override=use_node,
                name=sym.sym_name,
                owner=owner.name.value
            );
        }
    }
}

impl AccessCheckPass._declaring_archetype(sym: Symbol) -> (Archetype | None) {
    return sym.parent_tab if isinstance(sym.parent_tab, Archetype) else None;
}

impl AccessCheckPass._declaring_module(sym: Symbol) -> (Module | None) {
    if isinstance(sym.parent_tab, Module) {
        return sym.parent_tab;
    }
    decl = sym.decl;
    return decl.find_parent_of_type(Module) if decl is not None else None;
}

impl AccessCheckPass._base_archetype(expr: UniNode) -> (Archetype | None) {
    base_name: UniNode = expr;
    if (isinstance(expr, AtomTrailer) and isinstance(expr.right, Name)) {
        base_name = expr.right;
    }
    if (isinstance(base_name, AstSymbolNode) and base_name.sym) {
        base_decl = base_name.sym.decl;
        if base_decl {
            return base_decl.find_parent_of_type(Archetype);
        }
    }
    return None;
}

impl AccessCheckPass._is_subclass_of(child: Archetype, ancestor: Archetype) -> bool {
    visited: set[int] = set();
    queue: list[Archetype] = [child];
    while queue {
        cur = queue.pop();
        if id(cur) in visited {
            continue;
        }
        visited.add(id(cur));
        if cur.base_classes {
            for base in cur.base_classes {
                base_arch = self._base_archetype(base);
                if base_arch is None {
                    continue;
                }
                if base_arch is ancestor {
                    return True;
                }
                queue.append(base_arch);
            }
        }
    }
    return False;
}

impl AccessCheckPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl AccessCheckPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}
