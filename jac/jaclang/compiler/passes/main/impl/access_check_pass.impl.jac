impl AccessCheckPass.postinit -> None {
    super.postinit();
}

impl AccessCheckPass.transform(ir_in: Module) -> Module {
    self._enforce = ir_in.access_enforced;

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

impl AccessCheckPass._check_use(use_node: AstSymbolNode, sym: Symbol) -> None {
    if (sym.access == SymbolAccess.PUBLIC) {
        return;
    }
    decl = sym.decl;
    def_mod = decl.loc.mod_path if decl else "";

    if (not def_mod) or (not def_mod.endswith(".jac")) {
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
    use_mod = use_node.loc.mod_path;
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
