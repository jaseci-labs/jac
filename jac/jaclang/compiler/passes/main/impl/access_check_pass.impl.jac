impl AccessCheckPass.postinit -> None {
    super.postinit();
}

impl AccessCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    self._enforce = self._read_enforce();

    checked: set[int] = set();
    for tr in ir_in.get_all_sub_nodes(typ=uni.AtomTrailer) {
        if (tr.is_attr and isinstance(tr.right, uni.Name) and tr.right.sym) {
            checked.add(id(tr.right));
            self._check_use(tr.right, tr.right.sym);
        }
    }

    for nm in ir_in.get_all_sub_nodes(typ=uni.Name) {
        if (id(nm) in checked) or (nm.sym is None) {
            continue;
        }
        self._check_use(nm, nm.sym);
    }
    return ir_in;
}

impl AccessCheckPass._read_enforce -> bool {
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if (config and config.check) {
            return config.check.enforce_access;
        }
    } except Exception {
        return False;
    }
    return False;
}

impl AccessCheckPass._check_use(use_node: uni.AstSymbolNode, sym: uni.Symbol) -> None {
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

    if not isinstance(sym.parent_tab, uni.Module) {
        return;
    }
    use_mod = use_node.loc.mod_path;
    if (def_mod == use_mod) {
        return;
    }
    if (sym.access == SymbolAccess.PRIVATE) {
        self._emit_pair(
            W2037, E2037, use_node, name=sym.sym_name, module=os.path.basename(def_mod)
        );
    } else {
        def_proj = find_jac_project_root(def_mod);
        use_proj = find_jac_project_root(use_mod);
        if (def_proj != use_proj) {
            project_name = os.path.basename(def_proj) if def_proj else "?";
            self._emit_pair(
                W2038, E2038, use_node, name=sym.sym_name, project=project_name
            );
        }
    }
}

impl AccessCheckPass._check_member(
    use_node: uni.AstSymbolNode, sym: uni.Symbol, owner: uni.Archetype
) -> None {
    user = use_node.find_parent_of_type(uni.Archetype);
    if (sym.access == SymbolAccess.PRIVATE) {
        if (user is not owner) {
            self._emit_pair(
                W2034, E2034, use_node, name=sym.sym_name, owner=owner.name.value
            );
        }
    } else {
        ok = (user is not None)
        and ((user is owner) or self._is_subclass_of(user, owner));
        if not ok {
            self._emit_pair(
                W2035, E2035, use_node, name=sym.sym_name, owner=owner.name.value
            );
        }
    }
}

impl AccessCheckPass._emit_pair(
    warn: DiagnosticInfo, err: DiagnosticInfo, at_node: uni.UniNode, **kwargs: any
) -> None {
    self.emit(err if self._enforce else warn, node_override=at_node, **kwargs);
}

impl AccessCheckPass._declaring_archetype(sym: uni.Symbol) -> (uni.Archetype | None) {
    return sym.parent_tab if isinstance(sym.parent_tab, uni.Archetype) else None;
}

impl AccessCheckPass._base_archetype(expr: uni.UniNode) -> (uni.Archetype | None) {
    base_name: uni.UniNode = expr;
    if (isinstance(expr, uni.AtomTrailer) and isinstance(expr.right, uni.Name)) {
        base_name = expr.right;
    }
    if (isinstance(base_name, uni.AstSymbolNode) and base_name.sym) {
        base_decl = base_name.sym.decl;
        if base_decl {
            return base_decl.find_parent_of_type(uni.Archetype);
        }
    }
    return None;
}

impl AccessCheckPass._is_subclass_of(
    child: uni.Archetype, ancestor: uni.Archetype
) -> bool {
    visited: set[int] = set();
    queue: list[uni.Archetype] = [child];
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
