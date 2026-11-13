impl LoopLinks.of(tree: UniNode) -> LoopLinks {
    links = LoopLinks();
    closures: list[UniNode] = [];
    closures.extend(tree.get_all_sub_nodes(LambdaExpr));
    closures.extend(tree.get_all_sub_nodes(Ability));
    for closure in closures {
        links._link_closure(closure);
    }
    return links;
}

impl LoopLinks.of_loop(loop: UniNode) -> list[PassLink] {
    return self.by_loop.get(loop, []);
}

impl LoopLinks.of_closure(closure: UniNode) -> list[PassLink] {
    return self.by_closure.get(closure, []);
}

impl LoopLinks.of_name(name: UniNode) -> (PassLink | None) {
    return self.by_name.get(name);
}

impl LoopLinks.of_symbol(sym: Symbol) -> list[PassLink] {
    return self.by_symbol.get(sym, []);
}

impl LoopLinks.rebinds_of(closure: UniNode) -> list[Symbol] {
    return self.by_rebind.get(closure, []);
}

impl LoopLinks.linked_within(scope: UniNode) -> set[Symbol] {
    linked: set[Symbol] = set();
    cur: (UniNode | None) = scope;
    while cur is not None {
        for link in self.by_closure.get(cur, []) {
            linked.add(link.sym);
        }
        cur = cur.decl_parent;
    }
    return linked;
}

impl LoopLinks._link_closure(closure: UniNode) -> None {
    if isinstance(closure, Ability) and closure.is_method {
        return;
    }
    loops = enclosing_pass_loops(closure);
    if not loops and not made_in_comprehension(closure) {
        return;
    }
    for nm in closure.element_sub_nodes(Name) {
        if is_identifier_slot(nm) or nm in self.by_name {
            continue;
        }
        sym = nm.sym;
        if sym is None or not is_plain_variable(sym) or owned_within(sym, closure) {
            continue;
        }
        if made_per_element(sym, closure) {
            rebinds = self.by_rebind.setdefault(closure, []);
            if sym not in rebinds {
                rebinds.append(sym);
            }
            continue;
        }
        for loop in loops {
            if self._is_local(sym, loop) {
                self.by_name[nm] = self._link(loop, sym, closure);
                break;
            }
        }
    }
}

impl LoopLinks._link(loop: LoopStmt, sym: Symbol, closure: UniNode) -> PassLink {
    made = self.by_loop.setdefault(loop, []);
    link: (PassLink | None) = None;
    for existing in made {
        if existing.sym is sym {
            link = existing;
            break;
        }
    }
    if link is None {
        link = PassLink(loop=loop, sym=sym, index=self._made);
        self._made += 1;
        made.append(link);
        self.by_symbol.setdefault(sym, []).append(link);
    }
    received = self.by_closure.setdefault(closure, []);
    if link not in received {
        received.append(link);
    }
    return link;
}

impl LoopLinks._is_local(sym: Symbol, loop: LoopStmt) -> bool {
    known = self._local.setdefault(loop, {});
    if sym not in known {
        local = True;
        for site in binding_sites(sym) {
            if not site.is_within(loop) {
                local = False;
                break;
            }
        }
        known[sym] = local;
    }
    return known[sym];
}

impl enclosing_pass_loops(closure: UniNode) -> list[LoopStmt] {
    loops: list[LoopStmt] = [];
    child = closure;
    cur = closure.decl_parent;
    while cur is not None and not is_frame(cur) {
        if isinstance(cur, (Archetype, Enum)) {
            return [];
        }
        if isinstance(cur, (InForStmt, IterForStmt, WhileStmt, ForeverStmt))
            and child in cur.body {
            loops.append(cur);
        }
        child = cur;
        cur = cur.decl_parent;
    }
    return loops;
}

impl made_in_comprehension(closure: UniNode) -> bool {
    cur = closure.decl_parent;
    while cur is not None and not is_frame(cur) {
        if isinstance(cur, (ListCompr, DictCompr, InnerCompr)) {
            return True;
        }
        cur = cur.decl_parent;
    }
    return False;
}

impl made_per_element(sym: Symbol, closure: UniNode) -> bool {
    owner = sym.parent_tab;
    if not isinstance(owner, (ListCompr, DictCompr, InnerCompr)) {
        return False;
    }
    cur = closure.parent;
    while cur is not None and cur is not owner {
        if isinstance(cur, (Ability, LambdaExpr)) {
            return False;
        }
        cur = cur.parent;
    }
    return cur is owner;
}

impl in_loop_else(nd: UniNode, at: UniNode) -> bool {
    return isinstance(at, (InForStmt, IterForStmt, WhileStmt))
        and at.else_body is not None
        and nd.is_within(at.else_body);
}

impl enclosing_loop(ctrl: CtrlStmt) -> (LoopStmt | None) {
    cur = ctrl.decl_parent;
    while cur is not None and not is_frame(cur) {
        if isinstance(cur, (InForStmt, IterForStmt, WhileStmt, ForeverStmt))
            and not in_loop_else(ctrl, cur) {
            return cur;
        }
        cur = cur.decl_parent;
    }
    return None;
}

impl confined_to(sym: Symbol, loop: LoopStmt) -> bool {
    for site in list(sym.defn) + list(sym.uses) {
        if not site.is_within(loop) {
            return False;
        }
    }
    return True;
}

impl binds_target(sym: Symbol, loop: LoopStmt) -> bool {
    if not isinstance(loop, InForStmt) {
        return False;
    }
    for site in sym.defn {
        if site.is_within(loop.target) {
            return True;
        }
    }
    return False;
}

impl assigned_on_entry(sym: Symbol, loop: LoopStmt) -> bool {
    for stmt in loop.body {
        mentions = [
            nm
            for nm in stmt.get_all_sub_nodes(Name)
            if nm.sym is sym
        ];
        if not mentions {
            continue;
        }
        if not isinstance(stmt, Assignment)
            or stmt.value is None
            or stmt.aug_op is not None
            or len(stmt.target) != 1
            or not isinstance(stmt.target[0], Name)
            or stmt.target[0].sym is not sym {
            return False;
        }
        return len(mentions) == 1;
    }
    return False;
}

impl frame_owns(frame: UniNode, sym: Symbol) -> bool {
    owner = sym.parent_tab;
    while owner is not None and not UniScopeNode.is_python_scoping(owner) {
        if isinstance(owner, (ListCompr, DictCompr, InnerCompr)) {
            return False;
        }
        owner = owner.parent_scope;
    }
    return owner is not None and owner is frame;
}

impl is_plain_variable(sym: Symbol) -> bool {
    return sym.sym_type in (SymbolType.VAR, SymbolType.MOD_VAR, SymbolType.IMM_VAR);
}

impl owned_within(sym: Symbol, scope: UniNode) -> bool {
    owner = sym.parent_tab;
    return owner is not None and owner.is_within(scope);
}

impl binding_sites(sym: Symbol) -> list[UniNode] {
    sites: list[UniNode] = list(sym.defn);
    for use in sym.uses {
        if use.expr_ctx != ExprCtx.LOAD {
            sites.append(use);
        }
    }
    return sites;
}
